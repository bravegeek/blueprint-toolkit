# installer-cli

## Purpose

Defines the toolkit installer's CLI surface: three subcommands (`init`, `add-skill <name>`, `doctor`) mapping to the onboarding flow of installing the base substrate, adding a skill, and verifying the toolchain — replacing prose-driven install steps with a decidable, scriptable interface while preserving existing `--clean`/`--force` behavior.

## Requirements

### Requirement: Three-verb install CLI

The installer SHALL expose three subcommands — `init`, `add-skill <name>`, and `doctor` — corresponding to the onboarding flow "install the base, add a skill, verify the toolchain." Invoking the installer with no recognized subcommand SHALL print usage listing these verbs and exit non-zero.

#### Scenario: init installs the base substrate

- **WHEN** a user runs `init` against a target project
- **THEN** the base substrate (`blueprint/model/`, `blueprint/bin/likec4`, `AGENTS.md`, `.mcp.json`) is installed
- **AND** no skill directory is installed by `init` alone
- **AND** `doctor` runs automatically at the end and its result is shown

#### Scenario: add-skill installs one skill and its wrapper

- **WHEN** a user runs `add-skill assessment` against a target that already has the base
- **THEN** the whole `skills/assessment/` directory is installed
- **AND** the agent discovery-path wrapper for that skill is created as a thin symlink

#### Scenario: Unknown invocation prints usage

- **WHEN** the installer is invoked with no recognized subcommand
- **THEN** it prints usage naming `init`, `add-skill`, and `doctor`
- **AND** exits with a non-zero status

### Requirement: add-skill requires the base to be present

`add-skill` SHALL verify the base substrate exists in the target before installing a skill, and SHALL fail with a clear, actionable message when it does not, rather than leaving a skill with no model or wrapper to bind to.

#### Scenario: add-skill without a base fails clearly

- **WHEN** a user runs `add-skill assessment` in a target that has no `blueprint/model/system.c4`
- **THEN** the command fails with a message instructing the user to run `init` first
- **AND** installs nothing

### Requirement: Doctor verifies the toolchain up front

`doctor` SHALL check, and report per-check pass/fail with a remediation hint on failure: Node ≥ 20, `npx` availability, that `blueprint/bin/likec4` launches, that the wrapper is executable, and that the model and `.mcp.json` are present. It SHALL exit non-zero if any check fails.

#### Scenario: A broken toolchain is caught before assessment

- **WHEN** `doctor` runs on a target where `blueprint/bin/likec4` cannot launch
- **THEN** that check reports FAIL with a remediation hint
- **AND** the overall command exits non-zero

#### Scenario: A healthy toolchain reports all green

- **WHEN** `doctor` runs on a correctly installed target with Node ≥ 20 and a bootable wrapper
- **THEN** every check reports ok
- **AND** the command exits zero

### Requirement: Preserve existing clean/force behavior

The refactor SHALL preserve the existing `--clean` and `--force` behavior as compatible flags or aliases so that projects and docs relying on `install.sh --clean` continue to work unchanged.

#### Scenario: --clean still resets and refreshes

- **WHEN** a user runs the installer with `--clean` after the refactor
- **THEN** the model files are backed up and reset from template and non-model toolkit files are refreshed, exactly as before
