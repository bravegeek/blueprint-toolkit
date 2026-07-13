## MODIFIED Requirements

### Requirement: Extract the explicit graph at PROVABLE confidence

The extractor SHALL produce components, contracts, and edges that the type system can resolve — symbols, cross-file imports, call hierarchy, and interface/`implements` conformance — emitting each at `PROVABLE` confidence with `evidence` containing the resolved `file:line`. Enumeration SHALL include exported **functions and type aliases**, not only classes and interfaces, so that cohesive functional modules and cross-module union types are emitted as components/contracts.

#### Scenario: A resolved edge carries authoritative evidence

- **WHEN** tsserver resolves a reference, call, or implementation relationship between two symbols
- **THEN** the corresponding edge is emitted with `confidence: PROVABLE`
- **AND** `evidence` contains the `file:line` Location returned by tsserver

#### Scenario: Exported symbols become components/contracts

- **WHEN** tsserver reports an exported class/interface/type/function used across module boundaries
- **THEN** it is emitted as a `component` or `contract` entry with its resolved source `file` and `symbol`

#### Scenario: A cross-module function import is a PROVABLE edge

- **WHEN** a module imports and calls an exported function from another module (e.g. a reducer imported by a server module)
- **THEN** tsserver resolves the reference and the edge is emitted at `PROVABLE` confidence with `file:line` evidence
- **AND** the imported module is emitted as a component even though it declares no class

#### Scenario: Unresolvable references are not faked

- **WHEN** tsserver cannot resolve a reference (e.g. dynamic dispatch, unavailable type)
- **THEN** the extractor does NOT emit a PROVABLE edge for it
- **AND** does not fabricate `file:line` evidence
