## Why

The boundary contract already says confidence is set by the producing tool (confidence-by-construction): `tsserver` facts are `PROVABLE` with `file:line` evidence. But Pass 4 synthesis does not honor that on the way into the `.c4` model. On the VTT, `applyAction` and `CampaignAction` were resolved by `tsserver` as `PROVABLE`, yet the emitted elements came out tagged `#inferred` — Pass 4 evidently modeled them from the LLM (`llm-assessment`) reading and never reconciled with the deterministic extraction that covers the same symbols.

The root cause is an unstated reconciliation gap. Disjointness was specified for **edges**, but component/contract **identity** is not disjoint: the same class/module/type can be reported by both `llm-assessment` (INFERRED) and `tsserver` (PROVABLE). When both describe the same `sourceLocation`, Pass 4 currently keeps whichever it synthesized from — and that has been the INFERRED one. The effect is a `#provable` seam masquerading as a guess, which quietly defeats confidence-by-construction: a reviewer can no longer trust the tag.

## What Changes

- Require Pass 4 to **match extraction entries by `sourceLocation`** (`file#Symbol`) across all sources before emitting an element, and to **carry the source's confidence into the tag**: a `sourceLocation` that any deterministic source (`tsserver`) reports as `PROVABLE` is emitted `#provable`, regardless of whether an LLM source also described it as INFERRED.
- State the reconciliation rule explicitly: when multiple sources report the **same `sourceLocation`**, confidence is the **strongest** claim (PROVABLE wins over INFERRED). This closes the identity-overlap gap that disjointness (defined for edges) never covered.
- Update `skills/assessment/SKILL.md` Pass 4: the "Confidence → tags" step and the sourceLocation-match step must derive the tag from the reconciled source confidence, not from the LLM's own reading.

Scope guardrail: no change to the extraction format, to what each source emits, or to edge disjointness. This is purely how Pass 4 **consumes** the union — matching on `sourceLocation` and honoring the strongest source confidence.

## Capabilities

### New Capabilities
<!-- None. This tightens the existing boundary capability's confidence guarantee at the consumption point. -->

### Modified Capabilities
- `code-extraction-boundary`: The confidence-by-construction guarantee is extended to Pass 4 consumption — elements are matched across sources by `sourceLocation`, and the emitted confidence/tag is the strongest source claim for that location (a `tsserver`-PROVABLE location renders `#provable` even if an LLM source also reported it).

## Impact

- **Skill guidance**: `skills/assessment/SKILL.md` Pass 4 "Match on sourceLocation" and "Confidence → tags" steps updated to reconcile-then-tag.
- **Behavior**: deterministically-resolved components/contracts (e.g. `applyAction`, `CampaignAction`) render `#provable`, matching the evidence the extractor already produced.
- **No format or source change.** Pure synthesis-time reconciliation.
- **Validation target**: `fractal-table-vtt` — after re-assessment, `actions 'Action Reducer'` and `campaignAction` carry `#provable` (their `tsserver` evidence), not `#inferred`.
