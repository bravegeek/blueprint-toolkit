## Why

Assessment Pass 3c treats "a component" as "an exported class." That was a reasonable default for class-oriented stacks, but it silently under-reports on the large fraction of real codebases whose domain logic is written as exported **functions and types**, not classes. The gap is not theoretical: assessing a functional TypeScript app (`fractal-table-vtt`) captured the class-shaped infrastructure spine (`Room`, `Store`, HTTP handler, auth) and dropped an entire domain tier (`lib/vtt/` — dice, aspects, actions, redaction) that contains **zero classes**. That tier carried the single strongest import edge in the system — `server/sync/room.ts` imports `applyAction` and `CampaignAction` from it — and it evaporated because the unit-of-component grep only matches `class`.

This is a general defect, not a VTT quirk. Modern TS/JS, functional-style Python, and much Go keep product logic in modules of functions + types. The fix makes the assessment see them.

## What Changes

- Broaden the definition of a **component** from "exported class" to "exported class **or** cohesive functional module" — a source file whose exported functions/consts/types form one structural unit. Broaden **contract** correspondingly to include exported `type`/`type`-alias unions crossing module boundaries, not only `interface`.
- Make **structural significance a function of cross-module import evidence**, not export shape. If a module's exports are imported by another module, the module is structural — regardless of whether those exports are classes. This replaces the shape-based "skip helpers, utilities" heuristic that mistakes functional domain code for utilities.
- Keep **directory intent** as a *soft, secondary* signal (a cohesive domain directory reinforces significance) but never the primary test and never hardcoded to any project's paths. The primary, language-neutral signal is the import edge.
- Update `skills/assessment/SKILL.md` Pass 3c language-specific extraction rules (TS/JS and Python) and the Pass 4 "cross-module evidence filter" so functional modules and type-alias contracts are emitted, not dropped.
- Extend the `tsserver` deterministic source to emit exported **functions and type aliases** resolved across module boundaries (call hierarchy + references already give this deterministically), not only classes/interfaces — so the highest-value functional edges land at `PROVABLE` confidence.

Scope guardrail: this changes *what qualifies as a component*, not the extraction format, the union contract, or Pass 4's tier machinery. No new element kinds. It is charter-safe — it models the modules that implement behavior, never the behavior itself.

## Capabilities

### New Capabilities
- `functional-module-extraction`: The language-neutral rule for what counts as a code-level component/contract — an exported class **or** a cohesive functional module (functions + types), with structural significance decided by cross-module import evidence rather than export shape.

### Modified Capabilities
- `tsserver-extraction`: The deterministic TypeScript source additionally emits exported functions and type aliases (not only classes/interfaces) as components/contracts when the type system resolves them across module boundaries, at `PROVABLE` confidence with `file:line` evidence.

## Impact

- **Skill guidance**: `skills/assessment/SKILL.md` Pass 3c (TS/JS and Python component/contract rules) and Pass 4 (cross-module evidence filter) updated to admit functional modules and type-alias contracts.
- **tsserver driver**: `skills/assessment/tsserver-extractor.mjs` widened to enumerate exported functions/type aliases and resolve their cross-module edges.
- **Format**: unchanged. Same `{ source, language, components[], contracts[], edges[] }`; functional modules populate existing fields.
- **Downstream**: Pass 4 emits more `component`/`contract` nodes for functional codebases; class-oriented projects are unaffected (a class is still a cohesive module).
- **Validation target**: `fractal-table-vtt` — the `lib/vtt/` tier and the `room.ts → applyAction` edge must appear in the proposed `.c4` after this change.
