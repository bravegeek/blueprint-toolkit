# Session Summary

**Topic**: Enhancing code-level detail extraction (C4 Level 3) for the `blueprint-toolkit`.
**Advisor Role**: Senior Staff Engineer (Architecture Tooling)

## Situation
The `blueprint-toolkit` currently generates solid high-level system diagrams (C4 Level 1/2) using LikeC4, but lacks detailed, deterministic analysis of the code itself. The goal is to build a system that can accurately extract code-level details (components, contracts, relationships) while retaining the flexibility and semantic understanding of an LLM.

## Conversation Insights
- **Architecture Selected**: A Hybrid Multi-Pass Pipeline.
  1. **Extraction Pass (Tree-sitter)**: Fast, deterministic AST parsing to map files, classes, exports, and imports.
  2. **Abstraction Pass (LLM Architect)**: Grouping the raw syntax nodes into cohesive C4 components.
  3. **Enrichment Pass (LLM Annotator)**: Writing descriptions, bounding contexts, and edge labels.
  4. **Discovery Pass (LLM Detective)**: Gap-filling implicit connections (events, APIs) that Tree-sitter couldn't catch.
- **Tooling Choice**: Tree-sitter (Option A) was chosen over Language Server Protocol (Option B) for the deterministic pass. This prioritizes speed, flexibility, and language-agnostic parsing over the heavy orchestration and project-readiness required by an LSP.

## Plan & Next Steps
- The plan will be fed into OpenSpec explore for further development.
- **Potential execution starting points:**
  1. **Parser Prototype**: Write a standalone Tree-sitter script to parse a target file and output the intermediate JSON extraction format.
  2. **Prompt Prototype**: Manually mock the Tree-sitter JSON output and focus on crafting the prompts for the Abstraction and Enrichment LLM passes.
  3. **Architecture Integration**: Update `skills/assessment/SKILL.md` to map out exactly how this hybrid Tree-sitter flow replaces/augments the current extraction logic.

## Resolution — Explore Session (2026-07-12)

Fed into `/opsx:explore`. Outcome: `openspec/changes/nextjs-tsserver-extractor/`.

Key shifts from the original plan:
- **Scope narrowed** to one warm project (`fractal-table-vtt`, Next.js/TS). Multi-language and a generic LSP driver are explicitly deferred.
- **Tree-sitter dropped in favor of `tsserver`.** The pipeline targets *existing* projects, which are "warm" — the type engine is already installed (`node_modules/typescript`), zero setup. tsserver does the cross-file name resolution tree-sitter can't, and returns authoritative `Location`s usable directly as PROVABLE evidence — the exact tension that killed tree-sitter's determinism.
- **The 4 LLM passes collapsed.** For a warm stack it's not a degradation ladder (LSP *or* tree-sitter *or* LLM) but **AND on disjoint edge sets**: tsserver owns the compiler-resolvable graph (PROVABLE); an LLM Next.js "discovery recipe" owns framework-implicit wiring the compiler can't see — routes, `fetch`→handler, `'use client'`, auth (INFERRED). Both always run; outputs are unioned.
- **Confidence-by-construction:** the tool that produced a fact sets its confidence ceiling.
- **The real investment is the boundary, not the driver.** Everything exits through the extraction JSON already spec'd in `skills/assessment/SKILL.md` (Pass 3c); the tsserver driver is disposable. This is what keeps future iteration (other languages, generic LSP) cheap. No format change needed — framework edge kinds ride the free-string `edges[].kind`.

See the change's `design.md` (D1–D5) for the decisions with alternatives, and `tasks.md` for the walking-skeleton validation on `fractal-table-vtt`.
