## 1. install.sh backup naming

- [ ] 1.1 Change the `--clean` backup copy step to write `system.c4.bak` / `views.c4.bak` (non-`.c4` names)
- [ ] 1.2 Correct the misleading "outside blueprint/model/ = workspace root" comment to state backups avoid the `*.c4` glob by filename
- [ ] 1.3 Emit a short recovery note (e.g. `RESTORE.txt` in the backup dir, or install output) explaining that restoring = rename `.c4.bak` → `.c4`

## 2. Migration of existing backups

- [ ] 2.1 On `--clean`, sweep `blueprint/.backup/**/*.c4` and rename each to `<name>.bak` before writing the new backup
- [ ] 2.2 Make the sweep idempotent (skip files already ending in `.bak`; never create `.bak.bak`)

## 3. Validation

- [ ] 3.1 On a target with a poisoned backup (a `.c4` file under `blueprint/.backup/`), run `install.sh --clean` and confirm the backup is renamed to `.bak`
- [ ] 3.2 Confirm `likec4 validate` on that target is clean (backup no longer globbed/errored) with the backup still on disk
- [ ] 3.3 Confirm a fresh `--clean` writes new backups as `.c4.bak` from the start
- [ ] 3.4 Confirm re-running `--clean` does not produce `.bak.bak` files
- [ ] 3.5 Repair `fractal-table-vtt`'s four existing backup dirs and confirm `likec4 validate` from the project root is clean
