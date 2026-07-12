# Tasks: Add Code-Level Diagramming

## 1. Base model specification (code-level-model)

- [x] 1.1 Add `component`, `contract`, and `spec` element kinds to `blueprint/model/system.c4` with descriptive comments matching the existing style
- [x] 1.2 Add `defines` and `implements` relationship kinds to the specification
- [x] 1.3 Add `inferred` and `provable` confidence tags (with colors) alongside the existing `deprecated` tag, and decide/document whether untagged means confirmed or a third explicit tag is required
- [x] 1.4 Document the `sourceLocation` metadata convention (`<repo-relative-path>#<SymbolName>`) in the specification comments
- [x] 1.5 Add a `codeStructure` per-service view template to `blueprint/model/views.c4` (components, contracts, cross-boundary edges; no global code view)
- [x] 1.6 Validate the updated model files with `blueprint/bin/likec4 validate`

## 2. Extraction format and assessment skill (code-structure-extraction)

- [x] 2.1 Write the intermediate extraction format definition (JSON: `source`, `language`, `components[]`, `contracts[]`, `edges[]` with required fields) into the assessment skill as a normative section
- [x] 2.2 Rewrite Pass 3c to emit the extraction format instead of prose findings, defaulting LLM-derived entries to INFERRED and requiring quoted `file:line` evidence for PROVABLE
- [x] 2.3 Add Python extraction rules to Pass 3c (`__all__`/imported classes as components; cross-module Protocols, ABCs, dataclasses as contracts)
- [x] 2.4 Add TypeScript/JavaScript extraction rules to Pass 3c (exported classes as components; cross-module exported `interface`/`type` as contracts)
- [x] 2.5 Update Pass 4 synthesis to consume only the extraction format: match on `sourceLocation` before creating elements (update-in-place on re-assessment), nest components under their parent service, drop entries without cross-module evidence
- [x] 2.6 Update Pass 4 to emit `sourceLocation` metadata and confidence tags on generated elements, and generate the `codeStructure` view for each service with components
- [x] 2.7 Reconcile the existing spec-layer detection (Pass 3c specs/*/contracts/) with the new format: kinds unconditional in base spec, spec-element emission still conditional

## 3. Blueprint-change code-level diffs (code-level-change-diffs)

- [x] 3.1 Add a code-structure-impact check to the blueprint-change skill: determine whether a proposed change adds/removes/rewires components or contracts; skip the code-level diff entirely when it doesn't
- [x] 3.2 Add the to-be extraction step: produce a proposed extraction document scoped to touched modules only, plus direct endpoints of edges into untouched modules
- [x] 3.3 Render the code-level diff as a section of the existing review diagram (single review gate, no second approval step)
- [x] 3.4 On approval, stage code-level elements into the model with planned `sourceLocation` metadata through the same update path as architecture-level elements

## 4. Docs, install, and verification

- [x] 4.1 Update README.md and QUICKSTART.md: code-level modeling scope, the exported-surface-only rule, and the confidence-tag vocabulary
- [x] 4.2 Update AGENTS.md so agents know about the new kinds, the extraction format, and the sourceLocation convention
- [x] 4.3 Verify `install.sh` upgrades an existing installed project additively (new kinds available, existing elements/views still valid)
- [x] 4.4 End-to-end dry run: run `/assessment` against a small Python or TS sample project, confirm extraction JSON → `.c4` elements → `codeStructure` view renders, and re-run to confirm update-in-place (no duplicates)
