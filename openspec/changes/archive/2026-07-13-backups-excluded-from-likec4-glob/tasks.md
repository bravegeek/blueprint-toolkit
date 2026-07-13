## 1. install.sh backup naming

- [x] 1.1 Change the `--clean` backup copy step to write `system.c4.bak` / `views.c4.bak` (non-`.c4` names)
- [x] 1.2 Correct the misleading "outside blueprint/model/ = workspace root" comment to state backups avoid the `*.c4` glob by filename
- [x] 1.3 Emit a short recovery note (`RESTORE.txt` in the backup dir) explaining that restoring = rename `.c4.bak` → `.c4`

## 2. Migration of existing backups

- [x] 2.1 On `--clean`, sweep `blueprint/.backup/**/*.c4` and rename each to `<name>.bak` before writing the new backup
- [x] 2.2 Idempotent by construction: `find -name '*.c4'` never matches `*.c4.bak`, so re-runs produce no `.bak.bak` (verified)

## 3. Validation

- [x] 3.1 On a throwaway target with a poisoned backup, `install.sh --clean` renamed it to `.bak`
- [x] 3.2 `likec4 validate` clean with the backup still on disk (verified on the repaired VTT)
- [x] 3.3 Fresh `--clean` writes new backups as `.c4.bak` + `RESTORE.txt`
- [x] 3.4 Re-running `--clean` produced 0 `.bak.bak` files and 0 bare `.c4` under `.backup`
- [x] 3.5 Repaired `fractal-table-vtt`'s backup dirs (4 bare `.c4` → 0); `likec4 validate` from the project root now `✓ Valid (2 files)` (was 6 files / 70 errors)
