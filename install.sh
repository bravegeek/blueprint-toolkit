#!/usr/bin/env bash
# Install the blueprint toolkit into a target project.
#
# Usage:
#   ./install.sh [--force] [target-dir] [project-name]
#   ./install.sh --clean [--yes] [target-dir]
#
#   --force       Overwrite existing toolkit files (skills, AGENTS.md,
#                 .mcp.json, blueprint/bin/likec4) with the versions from
#                 this checkout, and replace any stale real skill dir sitting
#                 in an agent's discovery path with the wrapper symlink. Model
#                 files (system.c4, views.c4, .likec4rc) are never overwritten,
#                 even with --force, since they hold your project's own content.
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

# Copy an entire canonical skill directory (SKILL.md + every supporting file)
# into TARGET/skills/<name>/. Per-file, so --force and the existing-file skip
# apply to each file — and, crucially, so no file (e.g. an extractor script) can
# be left behind by an out-of-date list. Adding a file to a skill needs no edit
# here; adding a whole skill only means naming it in SKILLS below.
install_skill() {
  name="$1"
  for src in "$SRC_DIR/skills/$name"/*; do
    [ -e "$src" ] || continue
    install_file "skills/$name/${src##*/}"
  done
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

printf 'Installing blueprint toolkit into %s\n\n' "$TARGET_DIR"

for f in \
  AGENTS.md \
  .mcp.json \
  blueprint/model/system.c4 \
  blueprint/model/views.c4 \
  blueprint/model/.likec4rc \
  blueprint/bin/likec4
do
  install_file "$f"
done
chmod +x "$TARGET_DIR/blueprint/bin/likec4" 2>/dev/null || true

# Skills: copy each canonical directory whole, then point the agent's discovery
# path at it via a thin wrapper symlink. To install a new skill, add its name.
SKILLS="assessment blueprint-change"
for name in $SKILLS; do
  install_skill "$name"
  link_skill_wrapper ".claude/skills" "$name"
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
