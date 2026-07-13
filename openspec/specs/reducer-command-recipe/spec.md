# reducer-command-recipe Specification

## Purpose
TBD - created by archiving change reducer-command-recipe. Update Purpose after archive.
## Requirements
### Requirement: Detect the discriminated-union + reducer shape

The recipe SHALL activate when it detects a discriminated union (members sharing a discriminant field) consumed by a `switch`/dispatch function (a reducer). Detection SHALL key on this structural shape, not on any specific framework or package name.

#### Scenario: A reducer-dispatched union triggers the recipe

- **WHEN** a union type whose members share a discriminant is consumed by a `switch` over that discriminant in a dispatch function
- **THEN** the recipe activates for that union

#### Scenario: A union with no reducer consumer is not treated as commands

- **WHEN** a discriminated union exists but no reducer/dispatch consumer is found
- **THEN** the recipe does not emit `command` nodes for it

### Requirement: Emit the command taxonomy at category granularity

The recipe SHALL emit the union's mid-level categories as `command` nodes at `INFERRED` confidence, treating leaf variants as internal detail. It MUST NOT emit every leaf variant by default, and MUST NOT invent categories absent from the type tree.

#### Scenario: Categories, not leaves, are emitted

- **WHEN** a two-level union (top → categories → leaves) is detected
- **THEN** the mid-level categories are emitted as `command` nodes
- **AND** the leaf variants are not emitted as separate nodes by default

#### Scenario: A flat union falls back to discriminant grouping

- **WHEN** the union has no mid-level categories
- **THEN** the recipe groups members by discriminant prefix or emits the single top-level command
- **AND** does not emit all leaves individually

#### Scenario: The reducer is linked to the taxonomy

- **WHEN** command categories are emitted
- **THEN** an edge (kind `handles`) links the reducer/dispatch element to each category

### Requirement: Stay disjoint from the deterministic source

The recipe SHALL restrict itself to the semantic decomposition of the union into a verb taxonomy and MUST NOT emit facts the `tsserver` source owns (the union type node, the reducer module node, plain import/call edges), preserving the disjoint-set contract.

#### Scenario: The recipe does not duplicate compiler-resolvable facts

- **WHEN** the union type, the reducer module, or the import edge between them is resolvable by the type system
- **THEN** the recipe does NOT emit those facts
- **AND** leaves them to the `tsserver` source

### Requirement: Emit through the shared boundary only

The recipe's output SHALL conform to the shared extraction format tagged `source: "llm-reducer"`, using the existing free-string `edges[].kind` for command edge kinds (`handles`, `implements`) with no format change. `command` nodes populate the existing `components[]` with `kind: "command"`.

#### Scenario: Output is the standard format

- **WHEN** the recipe finishes
- **THEN** it emits a single extraction JSON with `source: "llm-reducer"`
- **AND** contains only documented format fields, with command edge kinds in the free-string `edges[].kind`

