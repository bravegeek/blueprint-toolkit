#!/usr/bin/env bash
# Install the blueprint toolkit into a target project.
#
# Usage:
#   ./install.sh [--force] [target-dir] [project-name]
#   ./install.sh --clean [--yes] [target-dir]
#
#   --force       Overwrite existing toolkit files (skills, AGENTS.md,
#                 .mcp.json, blueprint/bin/likec4) with the versions from
#                 this checkout. Model files (system.c4, views.c4,
#                 .likec4rc) are never overwritten, even with --force,
#                 since they hold your project's own content.
#   --clean       Reset system.c4 and views.c4 to the blank toolkit templates,
#                 so you can re-run /assessment from scratch. The existing
#                 files are backed up first (see below), never just deleted.
#                 Prompts for confirmation unless --yes is also passed.
#                 .likec4rc (project name) is left untouched.
#   --yes         Skip the confirmation prompt for --clean.
#   target-dir    Project to install into (default: current directory)
#   project-name  LikeC4 project name written to .likec4rc
#                 (prompted for if omitted and running interactively)
#
# Portable across bash and zsh (`bash install.sh` / `zsh install.sh` both work).
# Existing files in the target are never overwritten by default — they are
# skipped with a warning so re-running is safe. Pass --force to pull in
# updated toolkit files (see above for what's exempt).
#
# Upgrading an existing project:
# Re-run this script (optionally with --force) to install new or updated
# skills. `system.c4` and `views.c4` are always skipped if present — you must
# manually merge new specification blocks (new element/relationship kinds,
# tags, views) or accept the current file and re-run only the skills.
#
# For additive upgrades (e.g., adding code-level element kinds), the specification
# changes are backward-compatible: existing elements and views remain valid, and
# new kinds are immediately available to use.

set -eu

SRC_DIR=$(cd "$(dirname "$0")" && pwd)

fail() {
  printf 'error: %s\n' "$1" >&2
  exit 1
}

FORCE=0
CLEAN=0
YES=0
while [ $# -gt 0 ]; do
  case "$1" in
    --force) FORCE=1; shift ;;
    --clean) CLEAN=1; shift ;;
    --yes) YES=1; shift ;;
    *) break ;;
  esac
done
[ "$CLEAN" -eq 0 ] || [ "$FORCE" -eq 0 ] || fail "--force and --clean cannot be combined"

TARGET_DIR=${1:-$PWD}
PROJECT_NAME=${2:-}

[ -d "$TARGET_DIR" ] || fail "target directory does not exist: $TARGET_DIR"
TARGET_DIR=$(cd "$TARGET_DIR" && pwd)
[ "$TARGET_DIR" != "$SRC_DIR" ] || fail "target is the toolkit repo itself; run this from your project or pass its path"
[ -f "$SRC_DIR/AGENTS.md" ] && [ -d "$SRC_DIR/blueprint/model" ] || fail "toolkit files not found next to install.sh (incomplete checkout?)"

if [ "$CLEAN" -eq 1 ]; then
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

  # Must live outside blueprint/model/ — that's the LikeC4 workspace root, and
  # a backup .c4 file left inside it gets globbed too, causing duplicate
  # element definitions on the next `likec4 validate`.
  BACKUP_DIR="$TARGET_DIR/blueprint/.backup/$(date +%Y%m%d-%H%M%S)"
  mkdir -p "$BACKUP_DIR"
  cp "$SYS_C4" "$BACKUP_DIR/system.c4"
  [ -f "$VIEWS_C4" ] && cp "$VIEWS_C4" "$BACKUP_DIR/views.c4"
  printf 'Backed up current model files to %s\n' "$BACKUP_DIR"

  cp "$SRC_DIR/blueprint/model/system.c4" "$SYS_C4"
  cp "$SRC_DIR/blueprint/model/views.c4" "$VIEWS_C4"
  printf 'Reset system.c4 and views.c4 to blank templates.\n\n'
  printf 'Next step: run /assessment . to model the existing system from scratch.\n'
  exit 0
fi

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
