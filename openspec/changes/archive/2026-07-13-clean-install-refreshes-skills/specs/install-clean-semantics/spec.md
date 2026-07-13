## ADDED Requirements

### Requirement: `--clean` refreshes non-model toolkit files

`install.sh --clean` SHALL refresh all non-model toolkit files (skills and their supporting scripts, `AGENTS.md`, vendor wrappers, `blueprint/bin`, `.mcp.json`) to their current versions in the same run, overwriting stale existing copies. It MUST NOT exit after the model reset without performing this refresh.

#### Scenario: A stale installed skill is overwritten

- **WHEN** a target already has an out-of-date `skills/assessment/SKILL.md` and the user runs `install.sh --clean`
- **THEN** the installed `SKILL.md` (and its supporting scripts) are overwritten with the current toolkit versions
- **AND** the run does not stop before refreshing them

#### Scenario: A subsequent assessment runs current logic

- **WHEN** `install.sh --clean` completes and the user then runs `/assessment`
- **THEN** the assessment executes the current skill logic, not a previously installed stale copy

### Requirement: `--clean` still protects the model

While refreshing non-model files, `--clean` SHALL continue to protect the project's model files: `system.c4`, `views.c4`, and `.likec4rc` are backed up and reset from the blank template by `--clean`'s own logic, and are never force-overwritten by the general file installer.

#### Scenario: Model is reset from template, not from the installer

- **WHEN** `install.sh --clean` runs
- **THEN** `system.c4` and `views.c4` are backed up and replaced with the blank templates
- **AND** the general file-install step does not overwrite those protected paths

### Requirement: `--clean` and `--force` are not mutually exclusive

Because `--clean` implies a force-refresh of non-model files, passing `--force` alongside `--clean` SHALL be accepted as redundant rather than rejected as a conflict.

#### Scenario: Combining the flags is harmless

- **WHEN** the user runs `install.sh --clean --force`
- **THEN** the command is accepted and behaves the same as `install.sh --clean`
- **AND** no "cannot be combined" failure is raised
