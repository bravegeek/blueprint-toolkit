# functional-module-extraction Specification

## Purpose
TBD - created by archiving change functional-module-components. Update Purpose after archive.
## Requirements
### Requirement: A component is a class or a cohesive functional module

Pass 3c SHALL treat a code-level `component` as either an exported class **or** a cohesive functional module — a single source file whose exported functions, constants, and types form one structural unit. The presence or absence of a class MUST NOT determine whether a module is emitted.

#### Scenario: A class-free module of functions is a component

- **WHEN** a source file exports functions/consts (and no class) that are imported by another module
- **THEN** the file is emitted as one `component` with `sourceLocation` set to the file
- **AND** it is not skipped for lacking a class

#### Scenario: The module, not each function, is the unit

- **WHEN** a functional module exports many functions
- **THEN** exactly one `component` is emitted for the module (optionally named after a dominant exported symbol)
- **AND** individual functions are not emitted as separate components by default

### Requirement: Cross-module import evidence, not export shape, decides significance

Structural significance SHALL be determined by cross-module import evidence: a module is structural if at least one of its exports is imported by a different module. The rule MUST NOT skip a module merely because its exports resemble helpers or utilities.

#### Scenario: An imported "utility-shaped" domain module is kept

- **WHEN** a module of pure functions is imported by another module
- **THEN** it is emitted as a component regardless of how utility-like its functions appear

#### Scenario: A genuinely single-use module is dropped

- **WHEN** a module's exports are never imported outside the module
- **THEN** it is not emitted (internal detail)

### Requirement: Cross-module type aliases are contracts

Pass 3c SHALL emit exported type aliases (including discriminated-union types) imported across module boundaries as `contract` entries, the same way exported interfaces are, recording `kind` as `"type"` or `"interface"`.

#### Scenario: A union type imported by another service is a contract

- **WHEN** `export type X = A | B | ...` is imported by a module in a different service
- **THEN** it is emitted as a `contract` with `kind: "type"`
- **AND** it is not dropped for being a type rather than an interface

### Requirement: Directory intent is a secondary signal only

The rule SHALL remain language- and project-neutral. A cohesive domain directory MAY reinforce significance or drive grouping, but MUST NOT be the primary significance test and MUST NOT be expressed as a hardcoded project-specific path in the skill.

#### Scenario: The rule is stated without naming a project directory

- **WHEN** the extraction guidance describes what qualifies as a component
- **THEN** it expresses the test in terms of cross-module imports (and optionally generic directory cohesion)
- **AND** it names no specific project's directory

