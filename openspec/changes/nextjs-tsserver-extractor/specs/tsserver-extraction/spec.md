## ADDED Requirements

### Requirement: Drive the in-repo tsserver

The extractor SHALL resolve the TypeScript graph by driving `tsserver` from the target project's own `node_modules/typescript`, opened against the project's `tsconfig.json`. It MUST NOT add a new dependency and MUST NOT require installing a separate language server.

#### Scenario: tsserver present in the target

- **WHEN** the target project has `typescript` installed (so `node_modules/typescript/lib/tsserver.js` exists)
- **THEN** the extractor drives that tsserver instance
- **AND** opens the project via its `tsconfig.json` so workspace/project-reference resolution applies

#### Scenario: No new dependency introduced

- **WHEN** the extractor runs
- **THEN** it uses only the `typescript` package already present in the target
- **AND** installs nothing

### Requirement: Extract the explicit graph at PROVABLE confidence

The extractor SHALL produce components, contracts, and edges that the type system can resolve — symbols, cross-file imports, call hierarchy, and interface/`implements` conformance — emitting each at `PROVABLE` confidence with `evidence` containing the resolved `file:line`.

#### Scenario: A resolved edge carries authoritative evidence

- **WHEN** tsserver resolves a reference, call, or implementation relationship between two symbols
- **THEN** the corresponding edge is emitted with `confidence: PROVABLE`
- **AND** `evidence` contains the `file:line` Location returned by tsserver

#### Scenario: Exported symbols become components/contracts

- **WHEN** tsserver reports an exported class/interface/type used across module boundaries
- **THEN** it is emitted as a `component` or `contract` entry with its resolved source `file` and `symbol`

#### Scenario: Unresolvable references are not faked

- **WHEN** tsserver cannot resolve a reference (e.g. dynamic dispatch, unavailable type)
- **THEN** the extractor does NOT emit a PROVABLE edge for it
- **AND** does not fabricate `file:line` evidence

### Requirement: Stay within static-analysis-only requests

The extractor SHALL use only read-only tsserver requests that perform static analysis (such as `open`, `navto`, `references`, `definitionAndBoundSpan`, `implementation`, `documentSymbol`). It MUST NOT invoke operations that trigger a build, code generation, or execution of project code or config, honoring the assessment skill's no-code-execution rule.

#### Scenario: Only read-only queries are issued

- **WHEN** the extractor interacts with tsserver
- **THEN** every request is a static read-only query
- **AND** no build, codegen, or application-code execution is triggered

### Requirement: Emit through the shared boundary only

The extractor's output SHALL conform to the shared extraction format tagged `source: "tsserver"`, and MUST NOT leak tsserver-native shapes (URI/range objects, quickinfo, type strings) past the JSON.

#### Scenario: Output is the standard format

- **WHEN** the extractor finishes
- **THEN** it emits a single extraction JSON with `source: "tsserver"`
- **AND** contains only documented format fields, with tsserver Locations reduced to `file:line` strings in `evidence`
