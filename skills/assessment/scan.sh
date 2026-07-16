#!/usr/bin/env bash
#
# Assessment directory scanner — Passes 1 & 3 discovery, one pre-approvable call.
#
# Usage: scan.sh <target-path> [section]
#
#   target-path   Root of the project to assess (default: .)
#   section       1 | 3 | all   Which pass's discovery to emit (default: all)
#
# Replaces the ad-hoc grep/find/git-ls-files invocations that Passes 1 and 3 of the
# assessment skill would otherwise run one at a time — each of which triggers its own
# permission prompt because the pattern text changes every run. This is a single, stable
# command surface: allowlist it once (Bash(bash .../scan.sh:*)) and the whole discovery
# phase runs prompt-free, in any harness that can run a shell.
#
# Output is a sectioned plain-text report on stdout (=== SECTION: NAME ===). It is read
# by the LLM as evidence for Pass 1 (Discover) and the grep-based signals of Pass 3
# (Analyze). It is deliberately NOT the Pass 3c extraction JSON — the deterministic
# extractors (tsserver-extractor.mjs, nextjs-recipe-extractor.mjs, reducer recipe) still
# own that format. This scanner surfaces *candidates and signals*, never final facts.
#
# Portability: pure bash + POSIX-ish grep/find/git. No Node, no jq. Nothing here executes
# application code — read-only static inspection only.
#
# Adapt the extension / config / pattern lists below to your stack; the defaults cover
# Python + TypeScript/Next.js, matching the skill's worked examples.

set -uo pipefail

TARGET="${1:-.}"
SECTION="${2:-all}"

if [ ! -d "$TARGET" ]; then
  echo "scan.sh: target path not found: $TARGET" >&2
  exit 2
fi

# Normalise to an absolute path so downstream file:line references are unambiguous.
TARGET="$(cd "$TARGET" && pwd)"

# ── Tunables (adapt per stack) ──────────────────────────────────────────────────────
SRC_EXT_RE='\.(py|ts|tsx|js|jsx|go|rs|toml|cfg)$'
CONFIG_RE='(^|/)(docker-compose.*\.ya?ml|Makefile|pyproject\.toml|requirements.*\.txt|Procfile|package\.json|go\.mod|Cargo\.toml|next\.config\.[jt]s|tsconfig\.json|\.env.*)$'
PRUNE_DIRS='node_modules|\.git|__pycache__|dist|build|\.next|\.venv|venv|\.turbo|coverage'

# Directories grep should skip (GNU/BSD grep --exclude-dir, repeated).
EXCLUDE_DIRS=(node_modules .git __pycache__ dist build .next .venv venv .turbo coverage)
grep_excludes=()
for d in "${EXCLUDE_DIRS[@]}"; do grep_excludes+=(--exclude-dir="$d"); done

# ── Helpers ─────────────────────────────────────────────────────────────────────────
section() { printf '\n=== SECTION: %s ===\n' "$1"; }

# Filtered file inventory — git if available (respects .gitignore, fast), else find.
list_files() {
  if git -C "$TARGET" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    git -C "$TARGET" ls-files | grep -E "$SRC_EXT_RE|$CONFIG_RE"
  else
    find "$TARGET" -type f 2>/dev/null \
      | grep -Ev "/($PRUNE_DIRS)/" \
      | grep -E "$SRC_EXT_RE|$CONFIG_RE" \
      | sed "s#^$TARGET/##"
  fi | sort
}

# grep across the tree. Returns grep's own exit status (1 = no matches) so callers can
# chain `|| echo "(none)"`. The script does not use `set -e`, so a no-match never aborts it.
scan() { grep -rnE "${grep_excludes[@]}" "$@" "$TARGET" 2>/dev/null; }

want() { [ "$SECTION" = "all" ] || [ "$SECTION" = "$1" ]; }

# ── Report header ───────────────────────────────────────────────────────────────────
printf '=== ASSESSMENT SCAN ===\n'
printf 'target: %s\n' "$TARGET"
if git -C "$TARGET" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  printf 'git: yes\n'
else
  printf 'git: no\n'
fi
printf 'section: %s\n' "$SECTION"

# ── PASS 1 — Discover ───────────────────────────────────────────────────────────────
if want 1; then
  section "FILE_INVENTORY"
  list_files

  section "STACK_SIGNALS"
  # Which stack-identifying config files actually exist.
  list_files | grep -E "$CONFIG_RE" || echo "(none)"

  section "SERVICE_ROOTS"
  # Entry-point files at any depth — multiple = multiple services (STRUCTURAL signal).
  list_files | grep -E '(^|/)(main|app|index|server|__main__)\.(py|ts|tsx|js|go|rs)$' || echo "(none)"

  section "ORCHESTRATOR"
  # Signature greps per orchestrator; presence gates what Pass 3b looks for.
  printf -- '--- prefect ---\n';  scan --include='*.py' '@flow|@task'
  printf -- '--- airflow ---\n';  scan --include='*.py' 'airflow|DAG\(|>>'
  printf -- '--- celery ---\n';   scan --include='*.py' '@app\.task|@shared_task|\.delay\(|\.apply_async\('
  printf -- '--- temporal ---\n'; scan --include='*.py' --include='*.ts' '@workflow\.defn|@activity\.defn|proxyActivities|defineSignal'
  printf -- '--- bullmq ---\n';   scan --include='*.ts' --include='*.js' 'new Worker|new Queue'
  printf -- '--- makefile ---\n'; if [ -f "$TARGET/Makefile" ]; then grep -nE '^[a-zA-Z0-9_-]+:' "$TARGET/Makefile" || true; fi

  section "FRAMEWORK"
  # Next.js detection (config file, dependency, or app/ router dir).
  if list_files | grep -qE '(^|/)next\.config\.[jt]s$' \
     || grep -qE '"next"[[:space:]]*:' "$TARGET/package.json" 2>/dev/null \
     || [ -d "$TARGET/app" ] || [ -d "$TARGET/src/app" ]; then
    echo "nextjs: detected"
  else
    echo "nextjs: not detected"
  fi
fi

# ── PASS 3 — Analyze (candidate signals) ────────────────────────────────────────────
if want 3; then
  section "PY_COMPONENTS"
  # Exported classes / functions (candidates; cross-module import evidence decides).
  scan --include='*.py' '^(class |def |async def )' | grep -Ev 'test_|/Test' || echo "(none)"

  section "PY_CONTRACTS"
  # Protocol / ABC / dataclass definitions + dedicated interface files.
  scan --include='*.py' '^class .*(Protocol|ABC)|^@dataclass' || echo "(none)"
  printf -- '--- interface files ---\n'
  find "$TARGET" \( -name protocols.py -o -name types.py -o -name interfaces.py \) 2>/dev/null \
    | grep -Ev "/($PRUNE_DIRS)/" | sed "s#^$TARGET/##" | sort || echo "(none)"

  section "TS_EXPORTS"
  # Exported classes AND functional exports (const/function/default) — not classes alone.
  scan --include='*.ts' --include='*.tsx' '^export (class|(async )?function|const|default) ' || echo "(none)"

  section "TS_IMPORTS"
  # Cross-module import evidence — the significance test for TS components/contracts.
  scan --include='*.ts' --include='*.tsx' "^import .* from ['\"]" || echo "(none)"

  section "TS_CONTRACTS"
  # Exported interfaces AND type aliases (incl. discriminated unions).
  scan --include='*.ts' --include='*.tsx' '^export (interface|type) ' || echo "(none)"

  section "REDUCER_SHAPE"
  # Gate for the reducer/command recipe: a switch over a discriminant + a *Action/Command/Event union.
  printf -- '--- dispatch switches ---\n'
  scan --include='*.ts' --include='*.tsx' 'switch \(\w+\.(kind|type)\)'
  printf -- '--- command unions ---\n'
  scan --include='*.ts' '^export type \w+(Action|Command|Event) ='

  section "SPEC_CONTRACTS"
  # Design-time contract dirs (specs/*/contracts/) — conditional emission in Pass 4.
  find "$TARGET" -type d -name contracts 2>/dev/null \
    | grep -E '/specs/' | sed "s#^$TARGET/##" | sort || echo "(none)"
fi

printf '\n=== END SCAN ===\n'
