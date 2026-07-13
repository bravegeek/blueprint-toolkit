## Why

`install.sh --clean` backs up the model to `blueprint/.backup/<timestamp>/system.c4` (and `views.c4`), on the assumption — stated in a code comment — that this is "outside the LikeC4 workspace root." It is not. LikeC4 globs `.c4` files recursively across the project (it swept `blueprint/.backup/**/*.c4` on `fractal-table-vtt`), so every backup is pulled into the workspace. Because a backup is a full model with its own `specification` block, the duplicate element/kind definitions collide with the live model, and `likec4 validate` fails — 70 errors on the VTT, none of them in the actual model. Each `--clean` adds another poisoned backup, so the problem compounds over time (four backup dirs had accumulated).

The confusion is real and recurring: a user backs up, re-assesses, then sees validation "fail" with errors that have nothing to do with their model.

## What Changes

- Store model backups with a **non-`.c4` filename** (e.g. `system.c4.bak` / `views.c4.bak`), so LikeC4's `*.c4` glob can never match them — a location-independent fix that holds regardless of where the workspace root actually is.
- Fix the incorrect comment in `install.sh` that asserts `blueprint/model/` is the workspace root; state the real reason backups are inert (they are not `.c4` files).
- Provide a one-time **migration for pre-existing poisoned backups**: on `--clean` (or a documented manual step), rename any existing `blueprint/.backup/**/*.c4` to the `.bak` form so an already-broken target returns to a clean `likec4 validate` without the user hand-deleting files.
- Keep backups recoverable: the rename is mechanical and reversible; a human restoring an old model renames `.c4.bak` back to `.c4` (documented next to the backup, and consistent with the existing "backups exist for manual recovery" contract).

Scope guardrail: no change to what `--clean` resets, to model protection, or to the assessment skill. This only changes the **filename/format** of backup copies so they leave the LikeC4 glob, plus a migration for already-written backups.

## Capabilities

### New Capabilities
- `model-backup-isolation`: Model backups written by `install.sh` are stored in a form LikeC4 does not glob (non-`.c4` filenames), so a backup can never pollute `likec4 validate`; pre-existing `.c4` backups are migrated to that form.

### Modified Capabilities
<!-- None. install-clean-semantics still governs what --clean refreshes/resets; this only changes backup file naming. -->

## Impact

- **`install.sh`**: backup copy step writes `system.c4.bak`/`views.c4.bak` (not `.c4`); the misleading workspace-root comment corrected; a migration pass renames existing `blueprint/.backup/**/*.c4` to `.bak`.
- **Behavior**: `likec4 validate` on a target that has been `--clean`ed no longer reports errors from backup files.
- **Recovery docs**: note that restoring a backup means renaming `.bak` → `.c4`.
- **No dependency or format changes.** Pure shell + file-naming.
- **Validation target**: `fractal-table-vtt` — it currently has four poisoned backup dirs; after the migration, `likec4 validate` from the project root is clean with backups still present on disk.
