## Context

Pass 3c's extraction rules use grep-shaped heuristics keyed on `^export class` / `^export interface`. Pass 4 then drops anything "without cross-module evidence" and anything that looks like a "helper/utility." Two shape assumptions are baked in: (1) the unit of a component is a class, and (2) significance is judged by what a symbol *looks like*. Both fail on functional code, where the product is functions + discriminated-union types and everything superficially resembles a utility.

The join key already in place — `sourceLocation` (`file#Symbol`) — and the confidence-by-construction contract are untouched. This change only widens *what gets emitted*.

## Goals / Non-Goals

**Goals**
- Emit cohesive functional modules and cross-module type aliases as components/contracts.
- Make cross-module import evidence the primary significance test, language-neutral.
- Keep class-oriented projects behaving exactly as before.

**Non-Goals**
- Modeling behavior/semantics inside those modules (that is the `domain-rules-layer` change).
- New element kinds or format changes.
- Per-function nodes as the default (see granularity decision below).

## Decisions

### Unit of component: module, not function
A functional file (e.g. `lib/vtt/dice.ts`) becomes **one** `component` whose `sourceLocation` is the file, even when it exports many functions. Per-function nodes would explode the model (the VTT's `lib/vtt/` alone would emit dozens). The module is the cohesive structural unit; individual functions are internal detail. A single dominant exported symbol (a reducer like `applyAction`, a class) may name the component; otherwise the module path names it.

### Significance = cross-module import, not shape
A module is structural iff at least one of its exports is imported by a different module. This is the same evidence tier that already promotes edges to `PROVABLE`, now also gating *whether a node exists*. It is language-neutral: imports exist in every language the skill targets. The old "skip helpers, utilities" rule is replaced by "skip modules with no cross-module import evidence" — which correctly keeps genuine single-use helpers out while admitting imported domain modules.

### Directory intent is advisory only
A cohesive domain directory (many mutually-referencing modules under one path) *reinforces* significance and can drive grouping, but is never the primary test and is never hardcoded to a project path. This keeps the rule general — the skill must be able to state it without naming any project's directories.

### Type-alias unions are contracts
`export type X = A | B | ...` imported across modules is a cross-module contract, the same way an `interface` is. `kind` on the contract entry records `"type"` vs `"interface"`. This is what lets `CampaignAction` (a union imported by another service) become a `contract` node rather than vanishing.

### tsserver does the functional graph deterministically
tsserver's `references` + call hierarchy already resolve function-to-function and import edges. The driver was simply not asked for non-class symbols. Widening `navto`/`documentSymbol` enumeration to include functions and type aliases yields these at `PROVABLE` with real `file:line`, disjoint from the recipe sources.

## Risks / Trade-offs

- **Node-count growth** on large functional repos → mitigated by module-level (not function-level) granularity and the cross-module-import gate.
- **Over-inclusion of shared internal utils that happen to be imported widely** → acceptable; a widely-imported module is structurally real. Views can exclude a `utils` grouping if noise appears.
- **Language coverage**: the deterministic path is TS-only (tsserver); other languages get the widened rule at `INFERRED` via `llm-assessment` until their own deterministic sources exist. Consistent with the current staged approach.

## Migration

No model migration. Re-running `/assessment` on a functional project produces additional nodes; `sourceLocation` matching updates in place, so existing class-based nodes are unchanged.
