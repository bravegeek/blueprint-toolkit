## ADDED Requirements

### Requirement: Single-command remote bootstrap

The toolkit SHALL provide a bootstrap entry point runnable as a single piped command (`curl -fsSL <url> | bash -s -- init <target>`) that fetches the toolkit and then runs `init` against the target, so a new user onboards without cloning the repository first.

#### Scenario: Fresh machine onboards in one command

- **WHEN** a user with no local checkout runs the documented `curl … | bash -s -- init .` command
- **THEN** the toolkit source is fetched
- **AND** `init` runs against the current directory, installing the base substrate and running `doctor`

#### Scenario: Bootstrap forwards arguments to the CLI

- **WHEN** the bootstrap is invoked with arguments after `--` (e.g. `init /path/to/proj name`)
- **THEN** those arguments are passed through to the installer verb unchanged

### Requirement: Bootstrap adds no hidden dependency

The bootstrap SHALL rely only on tools a user running this toolkit already needs (a POSIX shell, `curl`, and the Node/`npx` the toolkit already requires) and MUST NOT require a package manager or a global install to run `init`.

#### Scenario: No extra prerequisite beyond the toolkit's own

- **WHEN** the bootstrap runs on a machine that already meets the toolkit's stated prerequisites
- **THEN** it completes without asking the user to install any additional tooling
