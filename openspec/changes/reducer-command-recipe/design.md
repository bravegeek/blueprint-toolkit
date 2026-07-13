## Context

The toolkit already has the extension seam for this: `nextjs-discovery-recipe` is a source-specific LLM recipe that emits framework-implicit facts through the shared boundary, disjoint from `tsserver`. A reducer/command recipe is the same pattern applied to a different, equally common shape — the discriminated-union-plus-reducer. `tsserver` can resolve that the union type exists and that the reducer imports it, but it cannot decide that the union's members form a *verb taxonomy* worth surfacing at category granularity. That semantic grouping is the recipe's job.

## Goals / Non-Goals

**Goals**
- Surface the command/action/event taxonomy of reducer-driven apps at legible (category) granularity.
- Reuse the boundary and format unchanged; stay disjoint from `tsserver`.
- Give the rules layer concrete attachment points.

**Non-Goals**
- Modeling leaf variants (37 for the VTT) — too granular.
- Inventing verbs not present in the type tree.
- Rules/semantics about the commands (that is `domain-rules-layer`).
- Forcing this recipe on non-reducer apps.

## Decisions

### Trigger on shape, not on framework
The recipe activates when it detects a discriminated union (members sharing a discriminant field like `kind`/`type`) consumed by a `switch`/dispatch function (a reducer). This shape — not a package name — is the signal. It generalizes across Redux, CQRS, Elm-style, and hand-rolled reducers.

### Category granularity, from the union's own tree
The union is typically already two-level (`CampaignAction` → `TokenAction | AspectAction | …` → leaves). The recipe emits the **mid-level categories** as `command` nodes and treats leaves as internal. If a union is flat (no mid-level), the recipe may group by discriminant prefix or emit the single top-level command. Never emit all leaves by default.

### `command` is its own kind
The taxonomy reads as "the verbs the domain supports." `contract` (typed interface crossing a boundary) is the wrong label; a dedicated `command` kind makes the intent legible and lets views target it. The union *type* may still exist as a `contract` (from Layer 1); the `command` nodes are its semantic decomposition.

### Disjoint from tsserver
`tsserver` owns: the union type node, the reducer module node, the import edge reducer→union. The recipe owns: the decomposition of the union into category `command` nodes and the `handles` edges reducer→category. No edge is claimed by both, preserving the union-not-fallback contract.

### Emit through the boundary, `source: "llm-reducer"`
Standard extraction JSON; `command` nodes in `components[]` (with `kind: "command"`); edges use free-string `kind` (`handles`, `implements`). No format change.

## Risks / Trade-offs

- **Mis-detection** of a non-reducer union as a command set → gated on the reducer/dispatch consumer; a union with no switch consumer is not treated as commands.
- **Granularity mismatch** for flat unions → fallback to discriminant-prefix grouping; documented, not silent.
- **Narrow applicability** → accepted by design; it is a recipe, silent where the shape is absent. This is the experimental layer.
- **Overlap with Layer 1's type-alias contract** → intentional and disjoint: Layer 1 emits the union *as a type*; this emits its *verb decomposition*. Same source symbol, different modeled aspect, different node kind.

## Migration

Additive and gated. Projects without the reducer shape get nothing. `install.sh` adds the `command` kind to the base specification; unused kinds are harmless.
