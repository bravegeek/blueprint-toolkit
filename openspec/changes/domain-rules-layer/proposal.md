## Why

The assessment charter rightly forbids *inferring* business logic — but that leaves domain rules with **nowhere to live in the model, even when the developer knows them cold.** Structure can show that `applyAction` exists and that `redaction.ts` is imported by the sync server; it cannot show "invoking an aspect costs a fate point" or "GM secrets are redacted before reaching players." Every non-trivial system has such rules (pricing, auth policy, rate limits, compliance, domain invariants), and today they are simply absent from the diagram.

This change gives those rules a **charter-safe home**: a dedicated layer the developer authors (never the LLM infers), attached to the code that enforces it, and rendered only in views that opt in — so it can never clutter the architecture diagrams.

It also fixes a real defect in how the assessment *asks*: when the current Confirm step surfaces `INFERRED`/`AMBIGUOUS` items, the questions are terse enough that a developer can fail to understand what is being decided and fall through to the default without meaning to. A rules layer is only as good as the questions that elicit it, so clarity of disambiguation is in scope here.

## What Changes

- Add a `rule` element kind (a developer-authored domain rule / mechanic / policy / invariant) and a `governs` relationship linking a rule to the component(s), contract(s), or command(s) that enforce it.
- Rules are strictly **`AMBIGUOUS` tier**: the skill NEVER infers or fabricates a rule. It may only *ask* about candidate slots (a redaction module, a fate-economy command) and record what the developer states, verbatim in intent.
- Rules render in **dedicated views only** (e.g. a `domainRules` view). Architecture views (`index`, `context`, `services`) MUST NOT include rule elements. The model is additive; views are the filter — adding rules cannot regress existing diagrams.
- Make disambiguation questions **legible**: whenever the assessment asks the developer to resolve an `INFERRED` or `AMBIGUOUS` item, each question states plainly (1) what is being decided, (2) why it matters / what it changes in the model, and (3) what each option implies — while still presenting the explicit options and marking a default. Clarity is added; the option-presentation is preserved, not replaced.

Scope guardrail: no auto-inference of rule content. The extraction passes are unchanged; this lives in the base ontology (element kinds), the Confirm step (how rules are elicited and how questions are phrased), and the view layer.

## Capabilities

### New Capabilities
- `domain-rules-layer`: A developer-authored layer of domain rules (`rule` kind + `governs` relationship), captured at `AMBIGUOUS` tier only, attached to enforcing code elements, and rendered exclusively in opt-in views.
- `disambiguation-clarity`: A requirement on every developer-facing disambiguation question — state what is being decided, why it matters, and what each option implies, while still presenting explicit options and a marked default.

### Modified Capabilities
<!-- None. Extraction sources and the boundary contract are untouched. -->

## Impact

- **Base ontology**: `blueprint/model/system.c4` specification gains `rule` element kind and `governs` relationship (installed into targets via `install.sh`).
- **Skill guidance**: `skills/assessment/SKILL.md` Confirm step gains (a) rule-elicitation from candidate slots and (b) the question-clarity requirement; Pass 4 gains a `domainRules` view proposal.
- **Views**: new `domainRules` view; architecture views explicitly exclude `rule` elements.
- **Charter**: preserved and strengthened — rules are developer-supplied only; the LLM never authors rule content.
- **Validation target**: `fractal-table-vtt` — a `fateEconomy` rule governing the economy commands and a `secrecyRedaction` rule governing `redaction.ts`, visible only in the `domainRules` view.
