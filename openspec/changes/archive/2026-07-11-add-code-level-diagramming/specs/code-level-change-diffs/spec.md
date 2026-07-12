# code-level-change-diffs

## ADDED Requirements

### Requirement: Blueprint-change proposals include a code-level structural diff
When a proposed change touches code structure (adds, removes, or reshapes classes or cross-module contracts), the blueprint-change skill SHALL produce a to-be extraction document for the touched modules and render its diff against the current model as part of the existing `.c4` diff the human reviews. The diff SHALL be presented within the single existing review gate, not as a separate approval step.

#### Scenario: Change introduces a new component implementing an existing contract
- **WHEN** a proposed change adds a class `S3Backend` implementing the existing `StorageBackend` contract
- **THEN** the review diagram shows `S3Backend` as an added component with an `implements` edge to `StorageBackend`, before any code is written

#### Scenario: Change with no code-structure impact
- **WHEN** a proposed change modifies behavior without adding, removing, or rewiring components or contracts
- **THEN** no code-level diff section is produced and the review proceeds at architecture level as today

### Requirement: Diff scope is limited to touched modules
The code-level diff SHALL include only components and contracts in modules the change touches, plus the direct endpoints of edges crossing into untouched modules. It SHALL NOT render the full code-level model.

#### Scenario: Large model, small change
- **WHEN** the model contains components across ten services and a change touches one module in one service
- **THEN** the code-level diff shows only that module's components/contracts and the immediate endpoints of its cross-module edges

### Requirement: Approved diffs update the canonical model
When the human approves a change whose diff includes code-level elements, the resulting model update SHALL write those `component`/`contract` elements (with `sourceLocation` metadata reflecting the planned file paths) through the same mechanism as architecture-level updates, preserving the toolkit's one rule that `.c4` files are never edited directly.

#### Scenario: Approval stages code-level elements
- **WHEN** the reviewer approves a diff containing a new component
- **THEN** the component is added to the model with its planned `sourceLocation`, and implementation can begin against the approved structure
