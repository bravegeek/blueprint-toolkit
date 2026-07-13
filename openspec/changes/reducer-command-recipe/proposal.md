## Why

Command-driven and event-sourced apps encode their entire behavioral grammar as a **discriminated union of action/command/event types dispatched by a reducer**. This is the shape of Redux, CQRS/event-sourcing, Elm/TEA, and state-machine codebases. That union is the most valuable behavioral artifact in the system — it enumerates every verb the domain supports — yet it is invisible in the architecture model, which sees only the module that holds it.

Concretely, `fractal-table-vtt` defines its whole ruleset as a two-level union (`CampaignAction` → ~10 categories → 37 leaf variants) dispatched by one `switch` in `applyAction`. The categories (`TokenAction`, `AspectAction`, `EconomyAction`, …) are the game's grammar. Surfacing them gives the `domain-rules-layer` concrete attachment points ("what rule governs `EconomyAction`?") instead of free-floating prose.

This is packaged as an **optional recipe** — a sibling to `nextjs-discovery-recipe` — general to the class of reducer/command-driven apps, triggered only when the shape is detected. It is deliberately the experimental layer: valuable where it applies, silent where it doesn't.

## What Changes

- Add a `reducer-command-recipe` extraction source (LLM) that detects a discriminated-union + reducer-dispatch shape (a union type whose members share a discriminant, consumed by a `switch`/dispatch function) and emits the **command taxonomy** — the mid-level categories, not the leaf variants — as `command` nodes at `INFERRED` confidence, with `implements`/`handles` edges from the reducer/module to the taxonomy.
- Model at **category granularity** (~10 nodes for the VTT), not leaf granularity (37 nodes). The union's own type tree defines the categories; leaves are internal detail.
- Add a `command` element kind (the game's/app's verbs), distinct from `contract`, so the taxonomy reads as "the actions the domain supports" rather than "typed interfaces."
- Emit through the **shared extraction boundary** only, tagged `source: "llm-reducer"`, over a **disjoint** fact set from `tsserver` (which owns the plain import/call edges) — the recipe owns the semantic grouping of the union into a verb taxonomy.
- Render commands in the code-structure / domain views; keep them out of the top-level architecture views by default.

Scope guardrail: the recipe extracts the *taxonomy of verbs* (structure of the union), not the *rules* about them (that is `domain-rules-layer`). It emits categories present in the type tree; it does not invent verbs.

## Capabilities

### New Capabilities
- `reducer-command-recipe`: LLM extraction of the command/action/event taxonomy from a discriminated-union + reducer-dispatch shape, emitted at category granularity as `command` nodes at `INFERRED` confidence through the shared boundary, disjoint from the deterministic source.

### Modified Capabilities
<!-- None. Extraction format and boundary contract are reused unchanged; command edge kinds ride the free-string edges[].kind. -->

## Impact

- **Base ontology**: `blueprint/model/system.c4` gains a `command` element kind.
- **New source**: a `reducer-command` recipe added to Pass 3c, gated on discriminated-union + reducer detection (analogous to the Next.js gate).
- **Format**: unchanged. `command` populates `components[]` (or a documented taxonomy area); edge kinds (`handles`, `implements`) ride existing free-string `edges[].kind`.
- **Depends on**: `functional-module-components` (Layer 1) for the reducer module and the union contract to exist as nodes the taxonomy attaches to. Enriches `domain-rules-layer` (Layer 3) by providing attachment points, but that change does not require this one.
- **Validation target**: `fractal-table-vtt` — the ~10 `*Action` categories emitted as `command` nodes under the game engine, dispatched by `applyAction`, with leaves omitted.
