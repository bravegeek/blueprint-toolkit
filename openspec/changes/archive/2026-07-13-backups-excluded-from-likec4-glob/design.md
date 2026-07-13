## Context

The `--clean` block in `install.sh` does:

```
BACKUP_DIR="$TARGET_DIR/blueprint/.backup/<ts>"
cp "$SYS_C4"  "$BACKUP_DIR/system.c4"
cp "$VIEWS_C4" "$BACKUP_DIR/views.c4"
```

with a comment claiming `blueprint/.backup/` is safe because it sits outside `blueprint/model/` (the presumed workspace root). Observed reality on `fractal-table-vtt`: `likec4 validate` reported `found 6 source files` including `blueprint/.backup/<ts>/system.c4` — i.e. the glob root is at least `blueprint/`, and plausibly the project root. Moving the backup one directory up would not reliably help if the glob root is the project root. The only assumption-free fix is to make the backup **not a `.c4` file**.

## Goals / Non-Goals

**Goals**
- A backup can never be picked up by LikeC4's `*.c4` glob, wherever it lives.
- Existing poisoned targets become clean without manual file surgery by the user.
- Backups remain human-recoverable.

**Non-Goals**
- Changing the backup *location* (kept at `blueprint/.backup/<ts>/` for continuity).
- Changing what `--clean` resets or refreshes (that is `install-clean-semantics`).
- Teaching LikeC4 to ignore paths (out of our control; the filename fix is under ours).

## Decisions

### Non-`.c4` extension, not relocation
Rename backup copies to `system.c4.bak` / `views.c4.bak`. LikeC4 matches `*.c4`; `*.c4.bak` does not match, so the file is inert regardless of glob root. This is strictly more robust than relocating, because it does not depend on knowing where LikeC4 roots its search. Keep the `.c4.bak` suffix (rather than `.txt`) so the original type is obvious and restoration is a trivial suffix strip.

### Migrate existing backups on --clean
Before (or as part of) writing a new backup, sweep `blueprint/.backup/**/*.c4` and rename each to `<name>.bak`. This repairs targets already poisoned by earlier runs (like the VTT's four dirs) the next time `--clean` runs, with no user action. The sweep is idempotent (already-`.bak` files are skipped).

### Recovery is a documented suffix strip
Restoring an old model becomes: copy `blueprint/.backup/<ts>/system.c4.bak` back to `blueprint/model/system.c4` (strip `.bak`). Note this in the backup dir (a short `RESTORE.txt`) and/or the install output, consistent with the existing "backups exist for manual human recovery" contract in the assessment skill.

## Risks / Trade-offs

- **A user's external tooling expected `.c4` backups** → unlikely; backups are an internal recovery aid, and the `.c4.bak` name is self-describing.
- **Migration renames files the user placed there manually** → acceptable and desirable: any `.c4` under `.backup/` is exactly what breaks validation; renaming it fixes that while preserving content.
- **Glob root could differ across LikeC4 versions** → the filename fix is immune to that variance, which is the reason to prefer it over relocation.

## Migration

Mechanical and reversible. On the next `--clean`, existing `blueprint/.backup/**/*.c4` are renamed to `.c4.bak`; new backups are written as `.c4.bak` from the start. No model content changes. For an immediate fix without waiting for `--clean`, the same rename can be run by hand (documented).
