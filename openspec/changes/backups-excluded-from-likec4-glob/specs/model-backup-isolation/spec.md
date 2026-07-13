## ADDED Requirements

### Requirement: Model backups are not LikeC4-globbable

`install.sh` SHALL write model backups with a filename LikeC4 does not match with its `*.c4` glob (e.g. `system.c4.bak`, `views.c4.bak`). A backup MUST NOT be a bare `*.c4` file, so it can never be pulled into the LikeC4 workspace regardless of where the glob root is.

#### Scenario: A fresh backup is inert to validation

- **WHEN** `install.sh --clean` backs up the current model
- **THEN** the backup files are written with a non-`.c4` filename (e.g. `system.c4.bak`)
- **AND** a subsequent `likec4 validate` on the target does not include or error on the backup

#### Scenario: The backup remains identifiable and recoverable

- **WHEN** a backup is written as `system.c4.bak`
- **THEN** its content is the unchanged model file
- **AND** recovery is restoring it as `system.c4` (a suffix strip), documented for the user

### Requirement: Pre-existing globbable backups are migrated

On `--clean`, `install.sh` SHALL rename any existing `blueprint/.backup/**/*.c4` files to the non-globbable form, so a target already polluted by earlier runs returns to a clean `likec4 validate` without manual file deletion. The sweep MUST be idempotent (already-migrated files are left alone).

#### Scenario: An already-poisoned target is repaired

- **WHEN** `install.sh --clean` runs on a target that already has `blueprint/.backup/<ts>/system.c4` from earlier runs
- **THEN** those existing `.c4` backups are renamed to the non-globbable form
- **AND** `likec4 validate` no longer reports errors originating from backup files

#### Scenario: Re-running does not double-rename

- **WHEN** the migration runs again on backups already renamed to `.bak`
- **THEN** it leaves them unchanged
- **AND** does not create `.bak.bak` files

### Requirement: The workspace-root comment is corrected

The `install.sh` comment justifying the backup location SHALL state the accurate reason backups are inert (they are not `.c4` files), not the incorrect claim that `blueprint/model/` is the LikeC4 workspace root.

#### Scenario: Comment reflects the real mechanism

- **WHEN** a reader inspects the backup logic in `install.sh`
- **THEN** the comment explains that backups avoid the `*.c4` glob by filename
- **AND** does not assert that placing them outside `blueprint/model/` is what makes them safe
