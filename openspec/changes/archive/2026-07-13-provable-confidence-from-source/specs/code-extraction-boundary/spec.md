## ADDED Requirements

### Requirement: Pass 4 preserves source confidence via sourceLocation reconciliation

Pass 4 SHALL determine each emitted element's confidence by reconciling all extraction entries that share its `sourceLocation` and taking the strongest source claim, rather than from the LLM's own reading. A `sourceLocation` that any deterministic source reports as `PROVABLE` SHALL be emitted `#provable`, even when an LLM source also describes the same location as `INFERRED`.

#### Scenario: A tsserver-resolved element renders provable

- **WHEN** `tsserver` reports a component/contract at a `sourceLocation` as `PROVABLE` and `llm-assessment` also describes the same `sourceLocation` as `INFERRED`
- **THEN** the emitted element carries `#provable`
- **AND** it is not tagged `#inferred`

#### Scenario: A provable tag is backed by evidence

- **WHEN** an element is emitted `#provable`
- **THEN** the deterministic source's `file:line` evidence for that `sourceLocation` is available on the element's metadata/reasoning trail
- **AND** no `#provable` element is emitted without such evidence

### Requirement: Strongest claim wins when sources overlap on a location

When multiple sources report the same `sourceLocation` (node identity overlap, which the edge-level disjointness contract does not cover), Pass 4 SHALL resolve confidence to the strongest claim in precedence `PROVABLE` > `INFERRED`, and MUST NOT let an `INFERRED` description downgrade a `PROVABLE` resolution of the same location.

#### Scenario: INFERRED does not downgrade PROVABLE

- **WHEN** the same `sourceLocation` appears from a deterministic source (`PROVABLE`) and an LLM source (`INFERRED`)
- **THEN** the reconciled confidence is `PROVABLE`
- **AND** the element is emitted once (matched on `sourceLocation`), not duplicated per source

#### Scenario: A location with no deterministic source stays inferred

- **WHEN** a `sourceLocation` is reported only by LLM/convention sources
- **THEN** the emitted element is tagged `#inferred`
- **AND** it is not promoted to `#provable`
