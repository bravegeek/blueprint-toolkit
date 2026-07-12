# code-extraction-boundary Specification

## Purpose
TBD - created by archiving change nextjs-tsserver-extractor. Update Purpose after archive.
## Requirements
### Requirement: Extractors emit only the shared extraction format

Every code-level extraction source SHALL emit its output using only the Pass 3c extraction JSON already defined in `skills/assessment/SKILL.md` — the `{ source, language, components[], contracts[], edges[] }` shape with per-entry `confidence` and `evidence`. A source MUST NOT introduce source-specific fields, and MUST NOT emit any downstream artifact other than this JSON.

#### Scenario: A new source produces standard JSON

- **WHEN** any extraction source (deterministic or LLM) runs during Pass 3c
- **THEN** its entire output is a document conforming to the existing extraction format
- **AND** no field outside the documented format (`source`, `language`, `components`, `contracts`, `edges`, and their documented sub-fields) is present

#### Scenario: Tool-specific richness does not leak past the boundary

- **WHEN** a source's underlying tool exposes richer data than the format captures (e.g. type strings, tool-native URI/range shapes, quickinfo)
- **THEN** that data is mapped down to the format's fields or dropped
- **AND** it never reaches Pass 4 synthesis or the `.c4` model

### Requirement: Provenance is recorded per output

Each extraction output SHALL set `source` to a stable identifier of the tool that produced it (e.g. `tsserver`, `llm-nextjs`, `llm-assessment`), so provenance is auditable and Pass 4 can attribute every fact.

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

