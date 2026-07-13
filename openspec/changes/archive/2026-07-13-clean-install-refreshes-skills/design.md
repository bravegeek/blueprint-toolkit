## Context

Current `install.sh` control flow:

- Flag parse sets `FORCE`/`CLEAN`; line ~67 fails if both are set.
- If `CLEAN=1`: back up model → copy blank templates over `system.c4`/`views.c4` → print next-step → **`exit 0`** (never reaches skill install).
- Otherwise: run the normal install (`install_skill` → `install_file`), where an existing file is overwritten only when `FORCE=1 && ! is_protected`.

`is_protected` covers `blueprint/model/system.c4`, `views.c4`, `.likec4rc`. So force never touches the model; the model is handled exclusively by the `--clean` block.

## Goals / Non-Goals

**Goals**
- `--clean` yields fresh skills *and* a fresh model in one run.
- Model files stay protected from the file installer (backed up + template-reset only).
- Minimal, obvious shell change.

**Non-Goals**
- Changing `--force`'s standalone meaning.
- Changing wrapper-symlink handling or model protection.
- Adding new flags.

## Decisions

### `--clean` implies force for non-model files
The cleanest expression of intent: `--clean` sets `FORCE=1` and then continues into the normal install flow instead of exiting. Because `is_protected` still guards the model, forcing all other files refreshes skills/AGENTS/wrappers while leaving `system.c4`/`views.c4` untouched by `install_file` — the `--clean` block already reset those from template moments earlier.

### Reorder, don't duplicate
Keep the model backup+reset logic where it is, but replace its `exit 0` with a fall-through, and set `FORCE=1` before entering `install_file`. This reuses the entire existing install path rather than copying skill-install logic into the clean branch.

### Drop the mutual-exclusion guard
With `--clean` implying force, `--force --clean` is redundant, not contradictory. Removing the `fail` line means both existing invocations (`--clean`, and the now-harmless `--clean --force`) work.

### Ordering: model reset before skill force-install
The model reset must run before the fall-through install so that the freshly reset template is what remains. Since `install_file` skips protected model paths regardless, ordering only matters for the human-readable log; keep model reset first for a clear narrative ("reset model, then refreshed skills").

## Risks / Trade-offs

- **A user who wanted "reset model but keep my current (older) skills"** loses that option. That combination is incoherent with `--clean`'s stated purpose (from-scratch assessment needs current logic), so removing it is correct, not a regression.
- **Force now touches AGENTS.md/.mcp.json/bin under `--clean`.** Intended — these are toolkit machinery, not user content; user content lives only in the protected model files.

## Migration

None. Existing `--clean` users get the additionally-correct behavior automatically. No flags removed from the public surface (only the internal guard).
