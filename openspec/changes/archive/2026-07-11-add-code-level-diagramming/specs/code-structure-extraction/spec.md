# code-structure-extraction

## ADDED Requirements

### Requirement: Defined intermediate extraction format
Pass 3c of the assessment skill SHALL produce its findings as a JSON document with top-level fields `source`, `language`, `components[]`, `contracts[]`, and `edges[]`. Each component and contract entry MUST include `symbol`, `file`, and `confidence`; each edge MUST include `from`, `to`, `kind`, `confidence`, and `evidence` (a `file:line` citation). Pass 4 synthesis SHALL consume only this format when generating code-level `.c4` elements.

#### Scenario: LLM extraction emits the format
- **WHEN** Pass 3c completes on a service
- **THEN** its output is a JSON document with `source: "llm-assessment"` conforming to the format, not free-form prose findings

#### Scenario: Alternate extractor is a drop-in
- **WHEN** an extraction document with `source` other than `llm-assessment` (e.g., a future AST tool) is supplied to Pass 4
- **THEN** synthesis produces code-level elements without any change to synthesis rules

### Requirement: Python extraction rules
For Python code, the skill SHALL identify as components the classes exported via `__all__` or imported by other modules, and as contracts the `typing.Protocol` classes, ABCs, and dataclasses referenced across module boundaries.

#### Scenario: Protocol used across modules
- **WHEN** `storage/base.py` defines `class StorageBackend(Protocol)` and `pipeline/runner.py` type-hints a parameter as `StorageBackend`
- **THEN** the extraction document contains a `StorageBackend` contract and an edge from `PipelineRunner` to `StorageBackend` with `file:line` evidence

#### Scenario: Module-private class excluded
- **WHEN** a class is defined in a module but never exported or imported elsewhere
- **THEN** it does not appear in the extraction document

### Requirement: TypeScript/JavaScript extraction rules
For TypeScript/JavaScript code, the skill SHALL identify as components the `export`ed classes, and as contracts the `export`ed `interface` and `type` declarations referenced across module boundaries.

#### Scenario: Exported interface consumed by another module
- **WHEN** `src/storage/types.ts` exports `interface StorageBackend` and `src/pipeline/runner.ts` imports and implements it
- **THEN** the extraction document contains a `StorageBackend` contract and an `implements` edge from the runner class with evidence

### Requirement: Exported-surface-only cap
The extraction SHALL include only exported/public classes and contracts with cross-module evidence. At synthesis, any entry lacking cross-module evidence SHALL be dropped from the proposed model, not demoted to a lower confidence tier.

#### Scenario: Entry without cross-module evidence
- **WHEN** an extraction entry has no edge connecting it to a symbol in another module
- **THEN** Pass 4 omits it from the proposed `.c4` output

### Requirement: Confidence tiers for LLM-derived code elements
LLM-derived components, contracts, and edges SHALL default to `INFERRED`. An entry SHALL be tiered `PROVABLE` only when backed by quoted direct evidence (an inheritance/`implements` declaration, or an import plus call site). `STRUCTURAL` SHALL be reserved for non-LLM (deterministic) sources.

#### Scenario: Role identified by naming pattern only
- **WHEN** a class is identified as an orchestrator based on its name and directory
- **THEN** its extraction entry carries `confidence: "INFERRED"` and is routed to developer confirmation

#### Scenario: Explicit implements declaration
- **WHEN** the extraction quotes `class S3Backend(StorageBackend)` at a cited `file:line`
- **THEN** the `implements` edge carries `confidence: "PROVABLE"` and is auto-stageable
