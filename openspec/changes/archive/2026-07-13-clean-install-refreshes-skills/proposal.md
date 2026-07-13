## Why

`install.sh --clean` is meant to give you a fresh, from-scratch assessment: it backs up the model, resets `system.c4`/`views.c4` to blank templates, and tells you to run `/assessment`. But it does this and immediately `exit 0`s — it never (re)installs the skills. Worse, `--clean` and `--force` are declared mutually exclusive (`fail "--force and --clean cannot be combined"`), so you cannot even ask for "reset the model **and** refresh the skills" in one command.

The consequence is a silent trap: a user runs `install --clean`, then `/assessment`, and the assessment executes whatever **stale** `SKILL.md`/extractor happened to be installed previously — because a plain re-install skips already-existing skill files unless `--force`. Fresh model, stale logic. This exact confusion has now bitten twice (project.md documents a prior stale-skill drift incident). "Clean" reads as "fresh everything"; it should behave that way.

## What Changes

- `--clean` SHALL also **refresh the toolkit's skill/machinery files** (skills, `AGENTS.md`, wrappers, `blueprint/bin`, `.mcp.json`) to their current versions — i.e. it implies a force-overwrite for all **non-model** files — in addition to resetting the model. A from-scratch assessment therefore always runs current logic.
- The **model stays protected**: `system.c4`/`views.c4`/`.likec4rc` continue to be backed up and reset from template by `--clean`'s own logic, and are never force-overwritten by the file installer (`is_protected` still holds).
- Remove the `--force`/`--clean` mutual-exclusion. `--clean` implying force makes the combination redundant, not contradictory; passing both is harmless.
- Update the `--clean` help text to say it refreshes skills as well as resetting the model.

Scope guardrail: no change to what `--force` means on its own, to model protection, or to the wrapper-symlink logic. This only makes `--clean` stop exiting early and run the (force) install flow for non-model files.

## Capabilities

### New Capabilities
- `install-clean-semantics`: `--clean` performs a from-scratch refresh — it resets the model (with backup) **and** force-refreshes all non-model toolkit files — so the subsequent assessment always runs current skill logic, while model files remain protected.

### Modified Capabilities
<!-- None. No existing OpenSpec spec governs install behavior. -->

## Impact

- **`install.sh`**: `--clean` no longer `exit 0`s after the model reset; it falls through to the install flow with force semantics for non-model files. The `--force`+`--clean` guard is removed. Help text updated.
- **Behavior**: `install --clean` now overwrites stale `skills/*/SKILL.md` and supporting scripts; still skips `system.c4`/`views.c4`/`.likec4rc` (backed up and template-reset separately).
- **No new dependencies.** Pure shell change.
- **Validation**: on a target with a deliberately stale `skills/assessment/SKILL.md`, `install --clean` must overwrite it and must leave the (reset) model in place.
