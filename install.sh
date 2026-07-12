#!/usr/bin/env bash
# Install the blueprint toolkit into a target project.
#
# Usage:
#   ./install.sh [target-dir] [project-name]
#
#   target-dir    Project to install into (default: current directory)
#   project-name  LikeC4 project name written to .likec4rc
#                 (prompted for if omitted and running interactively)
#
# Portable across bash and zsh (`bash install.sh` / `zsh install.sh` both work).
# Existing files in the target are never overwritten — they are skipped
# with a warning so re-running is safe.
#
# Upgrading an existing project:
# Re-run this script to install new or updated skills. If your project already
# has `system.c4` and `views.c4`, they are skipped — you must manually merge
# new specification blocks (new element/relationship kinds, tags, views) or
# accept the current file and re-run only the skills.
#
# For additive upgrades (e.g., adding code-level element kinds), the specification
# changes are backward-compatible: existing elements and views remain valid, and
# new kinds are immediately available to use.

set -eu

SRC_DIR=$(cd "$(dirname "$0")" && pwd)
TARGET_DIR=${1:-$PWD}
PROJECT_NAME=${2:-}

fail() {
  printf 'error: %s\n' "$1" >&2
  exit 1
}

[ -d "$TARGET_DIR" ] || fail "target directory does not exist: $TARGET_DIR"
TARGET_DIR=$(cd "$TARGET_DIR" && pwd)
[ "$TARGET_DIR" != "$SRC_DIR" ] || fail "target is the toolkit repo itself; run this from your project or pass its path"
[ -f "$SRC_DIR/AGENTS.md" ] && [ -d "$SRC_DIR/blueprint/model" ] || fail "toolkit files not found next to install.sh (incomplete checkout?)"

# Ask for the project name if not given and we have a terminal.
if [ -z "$PROJECT_NAME" ]; then
  if [ -t 0 ]; then
    printf 'LikeC4 project name (default: %s): ' "$(basename "$TARGET_DIR")"
    read -r PROJECT_NAME || true
  fi
  [ -n "$PROJECT_NAME" ] || PROJECT_NAME=$(basename "$TARGET_DIR")
fi
# Sanitize: lowercase, spaces to hyphens, strip anything else.
PROJECT_NAME=$(printf '%s' "$PROJECT_NAME" | tr '[:upper:] ' '[:lower:]-' | tr -cd 'a-z0-9._-')
[ -n "$PROJECT_NAME" ] || fail "project name is empty after sanitizing"

copied=0
skipped=0

install_file() {
  src="$SRC_DIR/$1"
  dst="$TARGET_DIR/$1"
  if [ -e "$dst" ]; then
    printf 'skip  %s (already exists)\n' "$1"
    skipped=$((skipped + 1))
  else
    mkdir -p "$(dirname "$dst")"
    cp "$src" "$dst"
    printf 'copy  %s\n' "$1"
    copied=$((copied + 1))
  fi
}

printf 'Installing blueprint toolkit into %s\n\n' "$TARGET_DIR"

for f in \
  AGENTS.md \
  .mcp.json \
  blueprint/model/system.c4 \
  blueprint/model/views.c4 \
  blueprint/model/.likec4rc \
  blueprint/bin/likec4 \
  skills/assessment/SKILL.md \
  skills/blueprint-change/SKILL.md
do
  install_file "$f"
done
chmod +x "$TARGET_DIR/blueprint/bin/likec4" 2>/dev/null || true

# Also pick up any supporting files the skills ship beyond SKILL.md.
for src in "$SRC_DIR"/skills/*/*; do
  rel=${src#"$SRC_DIR"/}
  case "$rel" in
    */SKILL.md) ;; # handled above
    *) [ -f "$src" ] && install_file "$rel" ;;
  esac
done

# Set the project name in .likec4rc (only if we just created it).
rc="$TARGET_DIR/blueprint/model/.likec4rc"
if grep -q 'my-system-model' "$rc" 2>/dev/null; then
  tmp="$rc.tmp.$$"
  sed "s/my-system-model/$PROJECT_NAME/" "$rc" > "$tmp" && mv "$tmp" "$rc"
  printf '\nSet LikeC4 project name to "%s"\n' "$PROJECT_NAME"
fi

printf '\nDone: %d copied, %d skipped.\n\n' "$copied" "$skipped"
printf 'Next steps:\n'
printf '  1. cd %s/blueprint/model && ../bin/likec4 serve\n' "$TARGET_DIR"
printf '  2. Run /assessment . from your project root to model the existing system\n'
printf '     (or /blueprint-change for greenfield). See QUICKSTART.md in the toolkit repo.\n'
