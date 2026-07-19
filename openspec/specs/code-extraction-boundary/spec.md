# code-extraction-boundary Specification

## Purpose
TBD - created by archiving change nextjs-tsserver-extractor. Update Purpose after archive.
## Requirements
### Requirement: Extractors emit only the shared extraction format

Every code-level extraction source SHALL emit its output using only the Extraction step's extraction JSON already defined in `skills/assessment/SKILL.md` — the `{ source, language, components[], contracts[], edges[] }` shape with per-entry `confidence` and `evidence`. A source MUST NOT introduce source-specific fields, and MUST NOT emit any downstream artifact other than this JSON.

#### Scenario: A new source produces standard JSON

- **WHEN** any extraction source (deterministic or LLM) runs during the Extraction step
- **THEN** its entire output is a document conforming to the existing extraction format
- **AND** no field outside the documented format (`source`, `language`, `components`, `contracts`, `edges`, and their documented sub-fields) is present

#### Scenario: Tool-specific richness does not leak past the boundary

- **WHEN** a source's underlying tool exposes richer data than the format captures (e.g. type strings, tool-native URI/range shapes, quickinfo)
- **THEN** that data is mapped down to the format's fields or dropped
- **AND** it never reaches Model synthesis or the `.c4` model

### Requirement: Provenance is recorded per output

Each extraction output SHALL set `source` to a stable identifier of the tool that produced it (e.g. `tsserver`, `llm-nextjs`, `llm-assessment`), so provenance is auditable and Model can attribute every fact.

#### Scenario: tsserver output is attributed

- **WHEN** the deterministic TypeScript extractor emits its JSON
- **THEN** `source` equals `"tsserver"`

#### Scenario: Recipe output is attributed

- **WHEN** the Next.js discovery recipe emits its JSON
- **THEN** `source` equals `"llm-nextjs"`

### Requirement: Confidence is set by the producing tool

Confidence SHALL be a property of the source that produced a fact (confidence-by-construction), not a value an LLM self-reports per fact. Deterministic resolution produces `PROVABLE` facts (with `file:line` evidence); convention/inference-based extraction produces `INFERRED` facts.

#### Scenario: Deterministic facts are provable

- **WHEN** a fact is produced by resolving code with the type engine
- **THEN** its `confidence` is `PROVABLE`
- **AND** it carries `evidence` with a `file:line` reference

#### Scenario: Inferred facts are marked as such

- **WHEN** a fact is produced by convention-based or inferred reasoning
- **THEN** its `confidence` is `INFERRED`

### Requirement: Multiple sources are unioned over disjoint fact sets

When more than one source runs, their outputs SHALL be combined by union, not by fallback. Sources are responsible for disjoint fact sets so the union requires no reconciliation of conflicting claims about the same edge.

#### Scenario: Two present sources both contribute

- **WHEN** both a deterministic source and an LLM recipe run on a warm project
- **THEN** both outputs are produced and combined into a single union
- **AND** neither source is skipped because the other succeeded

#### Scenario: Sources do not both claim the same edge

- **WHEN** responsibilities are assigned across sources
- **THEN** each source emits only facts within its own domain (deterministic sources: compiler-resolvable edges; framework recipes: framework-implicit edges)
- **AND** the union does not depend on resolving contradictory claims about a single edge

### Requirement: The format is unchanged by adding sources

Adding a new source SHALL NOT require changing the extraction format. Free-string fields (such as `edges[].kind`) MUST absorb source-specific vocabulary without schema changes.

#### Scenario: Framework edge kinds need no schema change

- **WHEN** the Next.js recipe emits edges of kind `routes`, `fetches`, `handles`, or `authenticates`
- **THEN** they populate the existing free-string `edges[].kind` field
- **AND** no change to the extraction format is required

### Requirement: Model preserves source confidence via sourceLocation reconciliation

Model SHALL determine each emitted element's confidence by reconciling all extraction entries that share its `sourceLocation` and taking the strongest source claim, rather than from the LLM's own reading. A `sourceLocation` that any deterministic source reports as `PROVABLE` SHALL be emitted `#provable`, even when an LLM source also describes the same location as `INFERRED`.

#### Scenario: A tsserver-resolved element renders provable

- **WHEN** `tsserver` reports a component/contract at a `sourceLocation` as `PROVABLE` and `llm-assessment` also describes the same `sourceLocation` as `INFERRED`
- **THEN** the emitted element carries `#provable`
- **AND** it is not tagged `#inferred`

#### Scenario: A provable tag is backed by evidence

- **WHEN** an element is emitted `#provable`
- **THEN** the deterministic source's `file:line` evidence for that `sourceLocation` is available on the element's metadata/reasoning trail
- **AND** no `#provable` element is emitted without such evidence

### Requirement: Strongest claim wins when sources overlap on a location

When multiple sources report the same `sourceLocation` (node identity overlap, which the edge-level disjointness contract does not cover), Model SHALL resolve confidence to the strongest claim in precedence `PROVABLE` > `INFERRED`, and MUST NOT let an `INFERRED` description downgrade a `PROVABLE` resolution of the same location.

#### Scenario: INFERRED does not downgrade PROVABLE

- **WHEN** the same `sourceLocation` appears from a deterministic source (`PROVABLE`) and an LLM source (`INFERRED`)
- **THEN** the reconciled confidence is `PROVABLE`
- **AND** the element is emitted once (matched on `sourceLocation`), not duplicated per source

#### Scenario: A location with no deterministic source stays inferred

- **WHEN** a `sourceLocation` is reported only by LLM/convention sources
- **THEN** the emitted element is tagged `#inferred`
- **AND** it is not promoted to `#provable`

