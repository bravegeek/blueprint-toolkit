## Context

The confidence-tier machinery already has the right slot for this: `AMBIGUOUS` = "cannot determine without domain knowledge → explicit developer input." Domain rules are the archetypal AMBIGUOUS content. What's missing is (a) an element kind to hold a rule, (b) a relationship to attach it to enforcing code, and (c) discipline that the skill only ever *asks*, never authors. The current model already gropes toward this with dangling comments like `// Should role-based redaction be visible?` — this change turns that groping into a first-class, view-scoped layer.

## Goals / Non-Goals

**Goals**
- A charter-safe home for developer-known rules that structure can't reveal.
- Zero risk to existing architecture views (view-scoped rendering).
- Disambiguation questions a non-expert can answer without misfiring into the default.

**Non-Goals**
- Inferring rule content from code. Never.
- Formal rule semantics / executable constraints. A rule is prose + attachment points.
- Depending on the verb taxonomy — rules attach directly to Layer 1 modules; the `reducer-command-recipe` change enriches attachment points but is not required here.

## Decisions

### `rule` is an element, not metadata
A rule needs its own view, and one rule can span multiple enforcing elements (e.g. fate economy touches several commands). Metadata on a component can do neither. So `rule` is a first-class element kind with a `governs` relationship (rule → enforcing element).

### Rules never carry `#provable`/`#inferred`
Rules are `AMBIGUOUS` tier by construction — developer-authored. They carry no confidence tag (matching the existing "no tag = developer-confirmed" convention). The skill MUST NOT emit a rule the developer did not state.

### View-scoped, not model-scoped
Adding rule nodes cannot clutter architecture diagrams because those diagrams are separate views that don't include `rule`. A dedicated `domainRules` view opts in. This is what makes "try it and see" cheap: the experiment is a view block; deleting it leaves the model intact.

### Elicitation from candidate slots
The skill proposes rule *slots* from structural signals it already has — a module named/shaped like redaction, a command category like the economy actions — and asks the developer to fill or reject them. It presents the slot, never a guessed rule body.

### Question clarity is a standing requirement, not a rules-only nicety
The `disambiguation-clarity` capability governs *every* developer-facing INFERRED/AMBIGUOUS question in the skill, not just rule elicitation. It codifies the shape of a good question (decision / stakes / per-option implication / explicit options / marked default) so a developer never takes the default for lack of understanding. The option list stays — clarity wraps it, does not replace it.

## Risks / Trade-offs

- **Rule sprawl** if developers over-author → mitigated by view-scoping (invisible unless opted in) and by attaching rules to concrete elements rather than free-floating.
- **Elicitation fatigue** (too many slot questions) → the skill proposes only high-signal slots and batches them; clarity requirement keeps each answerable quickly.
- **Overlap with spec-layer contracts** (`spec` kind already exists) → `spec` is a design-time document reference; `rule` is a runtime domain invariant. Kept distinct; a rule may later reference a spec.

## Migration

Additive. Existing models gain nothing until a developer authors rules. `install.sh` adds the `rule` kind + `governs` relationship to the base `system.c4` specification; existing target models remain valid (unused kinds are harmless, as with `spec`).
