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
