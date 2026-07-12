# Add Code-Level Diagramming

## Why

The toolkit's core thesis — humans review a structural diagram before any code is written — currently stops at the service/datastore level (C4 level 2). The assessment skill's Pass 3c already *discovers* components and contracts, but there is no first-class way to model, view, or diff structures inside a service: classes, the typed interfaces that cross module boundaries, and how a proposed change reshapes them. Structural mistakes at class level are exactly as expensive to catch in code as architectural ones, and the toolkit is blind to them today.

## What Changes

- Promote `component`, `contract`, `spec`, and `defines` from "added by assessment when found" to first-class kinds in the canonical element specification (`blueprint/model/system.c4`), each carrying `sourceLocation` metadata (file path + symbol name) as the join key for future deterministic extraction.
- Add a per-service `codeStructure` view template to `blueprint/model/views.c4`.
- Define a language-neutral intermediate extraction format (JSON: `components[]`, `contracts[]`, `edges[]`, each with file, symbol, and confidence tier) that decouples *how structure is discovered* from *how it is modeled*. LLM-based reading (assessment Pass 3c) produces it now; a future AST extractor produces the same format with STRUCTURAL/PROVABLE confidence, requiring no downstream changes.
- Extend the assessment skill's Pass 3c with explicit extraction rules for the first two supported languages: Python (exported classes, `Protocol`s and type hints as contracts) and TypeScript/JavaScript (exported classes, `interface` types as contracts). Granularity is capped at exported/public classes and cross-module contracts; private helpers are permanently out of scope.
- Extend the blueprint-change skill so proposed changes include a code-level diff (new/modified components, the contracts they implement, and their call edges) that the human reviews before implementation.

Out of scope for this change (future work): the deterministic AST extractor itself, CI-driven regeneration, and languages beyond Python and TypeScript/JavaScript.

## Capabilities

### New Capabilities

- `code-level-model`: First-class `component`, `contract`, `spec`, and `defines` kinds in the canonical model specification, with `sourceLocation` metadata and per-service code-structure views.
- `code-structure-extraction`: The intermediate extraction format and the assessment-skill rules that populate it for Python and TypeScript/JavaScript, with confidence tiers preserved end to end.
- `code-level-change-diffs`: Blueprint-change proposals that include a reviewable class/contract-level structural diff of the proposed change.

### Modified Capabilities

<!-- No existing specs in openspec/specs/ — this is the first OpenSpec change in the repo. -->

## Impact

- `blueprint/model/system.c4` — new element and relationship kinds, metadata conventions.
- `blueprint/model/views.c4` — new `codeStructure` view template.
- `skills/assessment/SKILL.md` — Pass 3c gains a defined output format and per-language extraction rules; Pass 4 synthesis consumes the format instead of ad-hoc findings.
- `skills/blueprint-change/SKILL.md` — proposal flow gains the code-level diff step and its review gate.
- Model size risk: class-level elements churn faster and multiply quickly; the exported-classes-only cap is the mitigation and is a hard rule, not a default.
- No new runtime dependencies; the LikeC4 wrapper and MCP setup are unchanged.
