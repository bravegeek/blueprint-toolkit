#!/usr/bin/env bash
# Install the blueprint toolkit into a target project.
#
# Usage:
#   ./install.sh init [--force] [target-dir] [project-name]
#   ./install.sh add-skill <name> [--force] [target-dir]
#   ./install.sh doctor [target-dir]
#   ./install.sh --clean [--yes] [target-dir]
#
#   init          Install the base substrate only (AGENTS.md, .mcp.json,
#                 blueprint/model/*, blueprint/bin/likec4), set the project
#                 name, then run `doctor` and show its result.
#   add-skill     Install one skill (skills/<name>/ + its agent-discovery
#                 wrapper symlink). Fails if the base substrate isn't
#                 installed yet — run `init` first.
#   doctor        Check the toolchain: Node >= 20, npx, that
#                 blueprint/bin/likec4 boots, wrapper executable, model and
#                 .mcp.json present. Non-zero exit on any failure.
#   --clean       Reset system.c4 and views.c4 to the blank toolkit templates
#                 AND refresh the toolkit's skill/machinery files (skills,
#                 AGENTS.md, .mcp.json, wrappers, blueprint/bin) to their
#                 current versions, so you can re-run /assessment from scratch
#                 with up-to-date logic. The existing model files are backed
#                 up first (see below), never just deleted. Prompts for
#                 confirmation unless --yes is also passed. .likec4rc
#                 (project name) is left untouched.
#
#   --force       (init / add-skill) Overwrite existing toolkit files with
#                 the versions from this checkout, and replace any stale real
#                 skill dir sitting in an agent's discovery path with the
#                 wrapper symlink. Model files (system.c4, views.c4,
#                 .likec4rc) are never overwritten, even with --force, since
#                 they hold your project's own content.
#   --yes         (--clean) Skip the confirmation prompt.
#   target-dir    Project to install into (default: current directory)
#   project-name  LikeC4 project name written to .likec4rc
#                 (prompted for if omitted and running interactively; init
#                 only)
#
# Portable across bash and zsh (`bash install.sh` / `zsh install.sh` both work).
# Existing files in the target are never overwritten by default — they are
# skipped with a warning so re-running is safe. Pass --force to pull in
# updated toolkit files (see above for what's exempt).
#
# Upgrading an existing project:
# Re-run `init --force` (and `add-skill <name> --force` per skill) to pull in
# updated toolkit files. `system.c4` and `views.c4` are always skipped if
# present — you must manually merge new specification blocks (new
# element/relationship kinds, tags, views) or accept the current file and
# re-run only the skills.
#
# For additive upgrades (e.g., adding code-level element kinds), the specification
# changes are backward-compatible: existing elements and views remain valid, and
# new kinds are immediately available to use.
#
# Agent-agnostic layout (see openspec/project.md):
# The canonical skill is the vendor-neutral directory skills/<name>/ (SKILL.md
# plus every supporting script). Each skill directory is copied WHOLE — never an
# enumerated file list — so a new supporting file reaches the target without any
# edit here. An agent's skill-discovery path (e.g. .claude/skills/<name>) is set
# up as a THIN WRAPPER: a relative symlink to skills/<name>/, never a copy, so it
# can neither drift nor lose files.

set -eu

SRC_DIR=$(cd "$(dirname "$0")" && pwd)

fail() {
  printf 'error: %s\n' "$1" >&2
  exit 1
}

usage() {
  cat <<'EOF' >&2
Usage:
  install.sh init [--force] [target-dir] [project-name]
  install.sh add-skill <name> [--force] [target-dir]
  install.sh doctor [target-dir]
  install.sh --clean [--yes] [target-dir]

Verbs: init, add-skill, doctor. See the comment header in install.sh for details.
EOF
}

# ── Shared state / helpers ─────────────────────────────────────────────────

copied=0
skipped=0
FORCE=0

is_protected() {
  case "$1" in
    blueprint/model/system.c4 | blueprint/model/views.c4 | blueprint/model/.likec4rc) return 0 ;;
    *) return 1 ;;
  esac
}

install_file() {
  src="$SRC_DIR/$1"
  dst="$TARGET_DIR/$1"
  if [ -e "$dst" ]; then
    if [ "$FORCE" -eq 1 ] && ! is_protected "$1"; then
      mkdir -p "$(dirname "$dst")"
      cp "$src" "$dst"
      printf 'force %s (overwritten)\n' "$1"
      copied=$((copied + 1))
    else
      printf 'skip  %s (already exists)\n' "$1"
      skipped=$((skipped + 1))
    fi
  else
    mkdir -p "$(dirname "$dst")"
    cp "$src" "$dst"
    printf 'copy  %s\n' "$1"
    copied=$((copied + 1))
  fi
}

# Copy an entire canonical skill directory (SKILL.md + every supporting file,
# at any depth — e.g. extractors/, reference/, reference/stack-probes/) into
# TARGET/skills/<name>/. Per-file, so --force and the existing-file skip apply
# to each file — and, crucially, so no file (e.g. an extractor script or a
# reference doc) can be left behind by an out-of-date list. Adding a file (or
# a whole subdirectory) to a skill needs no edit here.
install_skill() {
  name="$1"
  skill_dir="$SRC_DIR/skills/$name"
  [ -d "$skill_dir" ] || fail "unknown skill: $name (no skills/$name/ in toolkit checkout)"
  # Process-substitution (not `find ... | while read`) so the loop body runs
  # in *this* shell, not a subshell — install_file's copied/skipped counter
  # updates would otherwise vanish when a piped subshell exits. Works in both
  # bash and zsh (this script targets both, per the header).
  while IFS= read -r rel; do
    [ -n "$rel" ] || continue
    install_file "skills/$name/${rel#./}"
  done < <(cd "$skill_dir" && find . -type f)
}

# Point an agent's skill-discovery path at the canonical skills/<name>/ with a
# relative symlink — the "thin wrapper" rule. vendor_dir is relative to TARGET
# (e.g. .claude/skills). A real dir/file squatting there is stale drift: skipped
# with a warning unless --force, which replaces it with the symlink.
link_skill_wrapper() {
  vendor_dir="$1"
  name="$2"
  link="$TARGET_DIR/$vendor_dir/$name"
  target="../../skills/$name" # from $vendor_dir/$name back to TARGET/skills/$name
  mkdir -p "$TARGET_DIR/$vendor_dir"
  if [ -L "$link" ]; then
    if [ "$(readlink "$link")" = "$target" ]; then
      printf 'ok    %s/%s -> %s (wrapper)\n' "$vendor_dir" "$name" "$target"
      return
    fi
    rm -f "$link"
  elif [ -e "$link" ]; then
    if [ "$FORCE" -eq 1 ]; then
      rm -rf "$link"
    else
      printf 'skip  %s/%s (real dir/file, not a wrapper — pass --force to replace)\n' "$vendor_dir" "$name"
      skipped=$((skipped + 1))
      return
    fi
  fi
  ln -s "$target" "$link"
  printf 'link  %s/%s -> %s (wrapper)\n' "$vendor_dir" "$name" "$target"
  copied=$((copied + 1))
}

resolve_target_dir() {
  # $1: raw target dir arg (default: $PWD)
  # $2: "allow-self" to permit target == the toolkit checkout itself — only
  #     doctor uses this, since it's read-only and dogfooding the toolkit's
  #     own blueprint/ install is a legitimate check, unlike init/add-skill/
  #     --clean which write files and would otherwise overwrite the checkout.
  dir=${1:-$PWD}
  [ -d "$dir" ] || fail "target directory does not exist: $dir"
  dir=$(cd "$dir" && pwd)
  if [ "${2:-}" != "allow-self" ]; then
    [ "$dir" != "$SRC_DIR" ] || fail "target is the toolkit repo itself; run this from your project or pass its path"
  fi
  [ -f "$SRC_DIR/AGENTS.md" ] && [ -d "$SRC_DIR/blueprint/model" ] || fail "toolkit files not found next to install.sh (incomplete checkout?)"
  printf '%s' "$dir"
}

BASE_FILES="AGENTS.md .mcp.json blueprint/model/system.c4 blueprint/model/views.c4 blueprint/model/.likec4rc blueprint/bin/likec4"
SKILLS="assessment blueprint-change"

install_base_files() {
  for f in $BASE_FILES; do
    install_file "$f"
  done
  chmod +x "$TARGET_DIR/blueprint/bin/likec4" 2>/dev/null || true
}

set_project_name() {
  # $1: desired project name, or empty to prompt/derive
  name=${1:-}
  if [ -z "$name" ]; then
    if [ -t 0 ]; then
      printf 'LikeC4 project name (default: %s): ' "$(basename "$TARGET_DIR")"
      read -r name || true
    fi
    [ -n "$name" ] || name=$(basename "$TARGET_DIR")
  fi
  # Sanitize: lowercase, spaces to hyphens, strip anything else.
  name=$(printf '%s' "$name" | tr '[:upper:] ' '[:lower:]-' | tr -cd 'a-z0-9._-')
  [ -n "$name" ] || fail "project name is empty after sanitizing"

  rc="$TARGET_DIR/blueprint/model/.likec4rc"
  if grep -q 'my-system-model' "$rc" 2>/dev/null; then
    tmp="$rc.tmp.$$"
    sed "s/my-system-model/$name/" "$rc" > "$tmp" && mv "$tmp" "$rc"
    printf '\nSet LikeC4 project name to "%s"\n' "$name"
  fi
}

base_present() {
  [ -f "$TARGET_DIR/blueprint/model/system.c4" ]
}

# ── doctor ──────────────────────────────────────────────────────────────────

doctor_checks() {
  # Runs every check against $TARGET_DIR; prints ok/FAIL per check; returns
  # non-zero if any check failed.
  status=0

  node_version=$(node --version 2>/dev/null || true)
  if [ -z "$node_version" ]; then
    printf 'FAIL  node: not found (need Node >= 20) — install Node.js 20 or newer\n'
    status=1
  else
    major=$(printf '%s' "$node_version" | sed -E 's/^v?([0-9]+).*/\1/')
    if [ "$major" -ge 20 ] 2>/dev/null; then
      printf 'ok    node: %s\n' "$node_version"
    else
      printf 'FAIL  node: %s (need >= 20) — upgrade Node.js\n' "$node_version"
      status=1
    fi
  fi

  if command -v npx >/dev/null 2>&1; then
    printf 'ok    npx: present\n'
  else
    printf 'FAIL  npx: not found — install Node.js 20+ (bundles npx) or npm\n'
    status=1
  fi

  wrapper="$TARGET_DIR/blueprint/bin/likec4"
  if [ -x "$wrapper" ]; then
    printf 'ok    blueprint/bin/likec4: executable\n'
  elif [ -f "$wrapper" ]; then
    printf 'FAIL  blueprint/bin/likec4: exists but is not executable — run: chmod +x %s\n' "$wrapper"
    status=1
  else
    printf 'FAIL  blueprint/bin/likec4: missing — run: install.sh init --force %s\n' "$TARGET_DIR"
    status=1
  fi

  if [ -x "$wrapper" ]; then
    if ( cd "$TARGET_DIR/blueprint/model" 2>/dev/null && "$wrapper" --version >/dev/null 2>&1 ); then
      printf 'ok    likec4 boots\n'
    else
      printf 'FAIL  likec4 boots: failed to run — check network access (first run fetches via npx) and Node version\n'
      status=1
    fi
  else
    printf 'FAIL  likec4 boots: skipped — wrapper not executable\n'
    status=1
  fi

  if [ -f "$TARGET_DIR/blueprint/model/system.c4" ]; then
    printf 'ok    model: blueprint/model/system.c4 present\n'
  else
    printf 'FAIL  model: blueprint/model/system.c4 missing — run: install.sh init %s\n' "$TARGET_DIR"
    status=1
  fi

  if [ -f "$TARGET_DIR/.mcp.json" ]; then
    printf 'ok    .mcp.json: present\n'
  else
    printf 'FAIL  .mcp.json: missing — run: install.sh init --force %s\n' "$TARGET_DIR"
    status=1
  fi

  return $status
}

cmd_doctor() {
  TARGET_DIR=$(resolve_target_dir "${1:-}" allow-self)
  printf 'Running doctor against %s\n\n' "$TARGET_DIR"
  if doctor_checks; then
    printf '\ndoctor: all checks passed\n'
    return 0
  else
    printf '\ndoctor: one or more checks failed\n'
    return 1
  fi
}

# ── init ─────────────────────────────────────────────────────────────────

cmd_init() {
  while [ $# -gt 0 ]; do
    case "$1" in
      --force) FORCE=1; shift ;;
      *) break ;;
    esac
  done
  TARGET_DIR=$(resolve_target_dir "${1:-}")
  PROJECT_NAME=${2:-}

  printf 'Installing blueprint toolkit base into %s\n\n' "$TARGET_DIR"
  install_base_files
  set_project_name "$PROJECT_NAME"

  printf '\nDone: %d copied, %d skipped.\n\n' "$copied" "$skipped"

  printf 'Running doctor...\n\n'
  doctor_status=0
  doctor_checks || doctor_status=$?

  printf '\nNext steps:\n'
  printf '  1. ./install.sh add-skill assessment %s\n' "$TARGET_DIR"
  printf '  2. cd %s/blueprint/model && ../bin/likec4 serve\n' "$TARGET_DIR"
  printf '  3. Run /assessment . from your project root to model the existing system\n'
  printf '     (or /blueprint-change for greenfield). See QUICKSTART.md in the toolkit repo.\n'

  return $doctor_status
}

# ── add-skill ────────────────────────────────────────────────────────────

cmd_add_skill() {
  NAME=${1:-}
  [ -n "$NAME" ] || fail "add-skill requires a skill name, e.g.: install.sh add-skill assessment"
  shift
  while [ $# -gt 0 ]; do
    case "$1" in
      --force) FORCE=1; shift ;;
      *) break ;;
    esac
  done
  TARGET_DIR=$(resolve_target_dir "${1:-}")

  base_present || fail "no blueprint/model/system.c4 found in $TARGET_DIR — run 'install.sh init' first"

  printf 'Installing skill "%s" into %s\n\n' "$NAME" "$TARGET_DIR"
  install_skill "$NAME"
  link_skill_wrapper ".claude/skills" "$NAME"

  printf '\nDone: %d copied, %d skipped.\n' "$copied" "$skipped"
}

# ── --clean (legacy full refresh) ───────────────────────────────────────

cmd_clean() {
  YES=0
  shift # drop the leading --clean
  while [ $# -gt 0 ]; do
    case "$1" in
      --yes) YES=1; shift ;;
      *) break ;;
    esac
  done
  TARGET_DIR=$(resolve_target_dir "${1:-}")

  SYS_C4="$TARGET_DIR/blueprint/model/system.c4"
  VIEWS_C4="$TARGET_DIR/blueprint/model/views.c4"
  [ -f "$SYS_C4" ] || fail "no blueprint/model/system.c4 found in $TARGET_DIR — nothing to clean"

  if [ "$YES" -ne 1 ]; then
    printf 'This will reset system.c4 and views.c4 in %s to blank templates.\n' "$TARGET_DIR"
    printf 'Current files will be backed up first, then overwritten.\n'
    if [ -t 0 ]; then
      printf 'Continue? [y/N] '
      read -r REPLY || true
      case "$REPLY" in
        y | Y | yes | YES) ;;
        *) fail "aborted" ;;
      esac
    else
      fail "refusing to clean without confirmation in a non-interactive shell; pass --yes"
    fi
  fi

  # Migrate any pre-existing globbable backups. Earlier runs wrote *.c4 files
  # here; LikeC4 globs *.c4 recursively across the project (the .backup dir is
  # NOT outside its workspace, contrary to what this comment used to claim), so
  # those backups get pulled in and their duplicate specification blocks break
  # `likec4 validate`. Rename them to *.c4.bak. Idempotent: *.c4.bak no longer
  # matches the *.c4 glob, and `find -name '*.c4'` does not re-match it.
  if [ -d "$TARGET_DIR/blueprint/.backup" ]; then
    find "$TARGET_DIR/blueprint/.backup" -type f -name '*.c4' | while IFS= read -r f; do
      mv "$f" "$f.bak"
    done
  fi

  # Store backups as *.c4.bak (not *.c4) so LikeC4's *.c4 glob never matches
  # them, wherever its workspace root actually is. The filename — not the
  # directory location — is what keeps a backup from polluting validation.
  BACKUP_DIR="$TARGET_DIR/blueprint/.backup/$(date +%Y%m%d-%H%M%S)"
  mkdir -p "$BACKUP_DIR"
  cp "$SYS_C4" "$BACKUP_DIR/system.c4.bak"
  [ -f "$VIEWS_C4" ] && cp "$VIEWS_C4" "$BACKUP_DIR/views.c4.bak"
  printf 'To restore a backup, rename system.c4.bak -> system.c4 (and views.c4.bak -> views.c4)\nand copy it back into blueprint/model/.\n' > "$BACKUP_DIR/RESTORE.txt"
  printf 'Backed up current model files to %s (as .c4.bak, inert to likec4)\n' "$BACKUP_DIR"

  cp "$SRC_DIR/blueprint/model/system.c4" "$SYS_C4"
  cp "$SRC_DIR/blueprint/model/views.c4" "$VIEWS_C4"
  printf 'Reset system.c4 and views.c4 to blank templates.\n\n'

  # Force-refresh the toolkit's skill/machinery files (base + every skill this
  # checkout ships) to their current versions — a from-scratch assessment must
  # run current logic, not whatever stale copy was installed before. The model
  # stays protected because is_protected still shields system.c4/views.c4/
  # .likec4rc, which were just reset from template above.
  FORCE=1
  install_base_files
  for name in $SKILLS; do
    install_skill "$name"
    link_skill_wrapper ".claude/skills" "$name"
  done

  printf '\nDone: %d copied, %d skipped.\n' "$copied" "$skipped"
}

# ── dispatch ────────────────────────────────────────────────────────────

CMD=${1:-}
case "$CMD" in
  init)
    shift
    cmd_init "$@"
    ;;
  add-skill)
    shift
    cmd_add_skill "$@"
    ;;
  doctor)
    shift
    cmd_doctor "$@"
    ;;
  --clean)
    cmd_clean "$@"
    ;;
  *)
    usage
    exit 1
    ;;
esac
