## 1. install.sh

- [x] 1.1 Remove the `--force`/`--clean` mutual-exclusion `fail` guard
- [x] 1.2 In the `--clean` block, replace the early `exit 0` (after model backup + template reset) with a fall-through into the normal install flow
- [x] 1.3 Set `FORCE=1` under `--clean` so existing non-model files are overwritten (skills, `AGENTS.md`, wrappers, `blueprint/bin`, `.mcp.json`)
- [x] 1.4 Confirm `is_protected` still shields `system.c4`/`views.c4`/`.likec4rc` from the file installer during the `--clean` fall-through
- [x] 1.5 Update `--clean` help text and header comments to state it refreshes skills as well as resetting the model

## 2. Validation

- [x] 2.1 On a test target with a deliberately stale `skills/assessment/SKILL.md`, run `install.sh --clean` and confirm the file is overwritten with the current version
- [x] 2.2 Confirm the model is reset from template and backed up (not force-overwritten by the installer)
- [x] 2.3 Confirm `install.sh --clean --force` is accepted (no "cannot be combined" failure) and behaves identically to `--clean`
- [x] 2.4 Confirm a normal `install.sh` (no flags) still skips existing files as before (no behavior change off the `--clean` path)
