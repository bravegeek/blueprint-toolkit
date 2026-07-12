# Design: Add Code-Level Diagramming

## Context

The toolkit models systems in LikeC4 at architecture altitude: `service`, `datastore`, `queue`, etc. The assessment skill reads a codebase in four passes and proposes a model with confidence-tiered elements (STRUCTURAL / PROVABLE / INFERRED / AMBIGUOUS). Pass 3c already looks for primary classes ("components") and typed cross-module interfaces ("contracts"), and Pass 4 conditionally emits `component`/`contract` kinds — but these kinds are not in the base specification, there are no code-level views, no defined shape for Pass 3c's findings, and the blueprint-change skill's diffs stop at service level.

The user's direction (from the roadmap discussion): all three purposes eventually (change review, exploration, living documentation); classes + contracts granularity; LLM extraction first with the architecture explicitly accommodating a later AST extractor; Python and TypeScript/JavaScript first.

## Goals / Non-Goals

**Goals:**
- One canonical model that spans architecture down to exported classes and cross-module contracts.
- A single swap point where a future AST extractor can replace or augment LLM reading with zero downstream changes.
- Code-level structural diffs in blueprint-change proposals, reviewable before implementation.
- Preserve the confidence-tier discipline end to end: every code-level element knows how it was derived.

**Non-Goals:**
- The AST extractor itself, CI regeneration, and staleness detection (future change).
- Method/function-level granularity.
- Private/internal helper classes in the model, ever.
- Languages beyond Python and TS/JS.

## Decisions

### D1 — Promote code-level kinds into the base specification (vs. conditional emission)

`component`, `contract`, `spec` element kinds and the `defines` and `implements` relationship kinds move into `blueprint/model/system.c4` permanently. Today the assessment skill injects them only when Pass 3c finds something, which means two projects can have incompatible specifications and blueprint-change cannot rely on the kinds existing. Alternative considered: keep conditional emission and have blueprint-change inject kinds on demand — rejected because the specification is the shared contract between both skills and the human reviewer; it should not be a moving target.

### D2 — `sourceLocation` metadata is mandatory on code-level elements

Every `component`/`contract` element carries `metadata { sourceLocation '<repo-relative-path>#<SymbolName>' }`. This is the join key that lets a future AST extractor reconcile its output with existing LLM-proposed elements (match on sourceLocation, not on title or id). Alternative: encode location in the element id — rejected because ids are hierarchical LikeC4 identifiers and file paths churn under refactoring; metadata can be updated without breaking view predicates and relationships.

### D3 — A language-neutral intermediate extraction format (the AST swap point)

Pass 3c's output becomes a defined JSON document rather than prose findings:

```json
{
  "source": "llm-assessment",        // or "ast-<tool>" later
  "language": "python",
  "components": [
    { "symbol": "PipelineRunner", "file": "src/pipeline/runner.py",
      "module": "pipeline", "exported": true, "confidence": "INFERRED" }
  ],
  "contracts": [
    { "symbol": "StorageBackend", "file": "src/storage/base.py",
      "kind": "protocol", "confidence": "PROVABLE" }
  ],
  "edges": [
    { "from": "PipelineRunner", "to": "StorageBackend",
      "kind": "implements|calls", "confidence": "PROVABLE",
      "evidence": "src/pipeline/runner.py:42" }
  ]
}
```

Pass 4 synthesis consumes only this format. When the AST extractor arrives, it emits the same format with `source: "ast-..."` and STRUCTURAL/PROVABLE confidence, and nothing downstream changes. Alternative: have the extractor emit `.c4` directly — rejected because it would duplicate Pass 4's synthesis logic (grouping, naming, view assignment, confirmation routing) in every extractor.

When translating this format to `.c4`, `symbol`/`file` map to `sourceLocation` metadata and `edges[].kind` maps to declared relationship kinds — both validated against the repo's pinned LikeC4. Confidence, however, maps to a **tag** (`#inferred`, `#provable`), not metadata: LikeC4 view predicates can filter on tags but not on metadata values, and a "show everything unconfirmed" view is exactly the kind of review aid the tiers exist for. The tags must be declared in the base specification alongside the new element kinds.

### D4 — Extraction rules per language, exported surface only

Python: classes exported via `__all__` or imported by other modules are components; `typing.Protocol`, ABCs, and dataclasses used across module boundaries are contracts. TS/JS: `export`ed classes are components; `export`ed `interface`/`type` referenced across module boundaries are contracts. The exported-only cap is a hard rule (model-size control), enforced in the skill instructions and re-checked at synthesis: any element without cross-module evidence is dropped, not tiered down.

### D5 — Code-level diffs in blueprint-change reuse the same format

The blueprint-change skill produces a *proposed* extraction document (the to-be state of touched modules) and renders the diff against the current model as part of the existing review gate — one new section in the diagram the human already reviews, not a second gate. Alternative: a separate `/diagram` skill for change diffs — rejected because it would split the review into two artifacts and two conversations.

### D6 — LLM-derived code elements default to INFERRED

Unlike architecture-level PROVABLE import edges, class-role identification by LLM reading is pattern matching; defaulting to INFERRED keeps the confirmation gate honest. Direct evidence (an actual `implements`/inheritance statement, an explicit import + call site the skill quotes) upgrades an item to PROVABLE. STRUCTURAL is reserved for the future AST source.

## Risks / Trade-offs

- [Model bloat: class-level elements multiply and churn] → Exported-only hard cap (D4); components nest under their parent service so views stay scoped; `codeStructure` views are per-service, never global.
- [Staleness: code-level model drifts from code faster than architecture does] → Accepted for this change; `sourceLocation` (D2) and the intermediate format (D3) are specifically designed so the future AST extractor can cheaply detect and repair drift. Until then, re-running `/assessment` on a service refreshes it.
- [LLM extraction is non-repeatable: two runs may name or group classes differently] → `sourceLocation` is the identity anchor; synthesis must match on it before creating new elements, so re-runs update rather than duplicate.
- [Review fatigue: code-level diffs make blueprint-change diagrams bigger] → The diff shows only touched modules' components (D5), not the whole code model.

## Migration Plan

Existing installed projects (via `install.sh`) have a `system.c4` without the new kinds. The kinds are additive — re-running `install.sh` or manually copying the specification block upgrades a project without breaking existing elements or views. No rollback complexity: removing the kinds is only unsafe after a project has used them.

## Open Questions

- Should `spec`/`defines` (the design-time spec layer from commit ff4b70b) stay conditional on `specs/*/contracts/` detection, or also become unconditional in the base spec? Current lean: include the kinds unconditionally (harmless when unused) but keep spec-element *emission* conditional.
- Naming collision handling when two services export a same-named class: proposed convention is nesting (`service.component`) which LikeC4 scopes naturally — verify Pass 4 instructions make this explicit.
