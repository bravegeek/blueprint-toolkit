# Blueprint Toolkit — Agent Instructions

## What This Is

A tool that generates a structural diagram of a proposed change before any code is written. The human reviews the diagram, not the code. If the structure is wrong, the fix is a conversation.

## Skills

All skills live at `skills/<name>/SKILL.md`. Invoke them by name.

| Skill | Invocation | When to use |
|-------|-----------|-------------|
| `assessment` | `/assessment [path]` | Read a running system's artifacts and propose an initial `.c4` model. Pass the path to the system (e.g. `/assessment .` from the project root). Never infers — only reads what exists. |
| `blueprint-change` | `/blueprint-change [description]` | Turn a ticket or description into EARS requirements and a proposed `.c4` diff. Human reviews the rendered diagram before any code is written. |
| `guided-brainstorm` | `/guided-brainstorm` | Guide users through structured brainstorming sessions using the Situation -> Advisor -> Conversation -> Plan framework. |

## The Loop

```
describe the change or ticket
  → /blueprint-change        # EARS requirements + proposed .c4 diff
  → human reviews diagram    # approve or correct via conversation
  → commit the .c4 diff
  → implement
```

**No code before the diagram is approved.**

## One Rule

Never write `.c4` files directly. All model changes go through `/blueprint-change` so the human reviews the rendered diagram first.

## Element and Relationship Kinds

The base specification includes code-level modeling alongside architecture-level elements:

**Architecture-level (C4 level 2):**
- `actor`, `system`, `service`, `script`, `datastore`, `bucket`, `queue`, `externalSystem`, `infrastructure`

**Code-level (C4 level 3):**
- `component` — an exported class or primary construct within a service
- `contract` — a typed interface (protocol, abstract base, interface) crossing module boundaries
- `spec` — a design-time specification-layer contract (optional, conditional on `specs/*/contracts/` directories)

**Relationship kinds:**
- Architecture-level: `calls`, `reads`, `writes`, `triggers`, `fetches`, `uploads`, `claims`
- Code-level: `defines` (spec → service/contract), `implements` (component → contract)

**Confidence tags:**
- `#provable` — derivable with certainty from code artifacts (import statements, type hints, inheritance)
- `#inferred` — pattern-matched by LLM (no direct code evidence)
- No tag → confirmed by developer (no uncertainty)

## Code-Level Extraction Format

The `/assessment` skill's Code pass (Extraction step) emits a JSON intermediate extraction format (the swap point for future AST extractors):

```json
{
  "source": "llm-assessment",  // or "ast-<tool>" for future extractors
  "language": "python",
  "components": [
    {
      "symbol": "PipelineRunner",
      "file": "src/pipeline/runner.py",
      "module": "pipeline",
      "exported": true,
      "confidence": "INFERRED"
    }
  ],
  "contracts": [
    {
      "symbol": "StorageBackend",
      "file": "src/storage/base.py",
      "kind": "protocol",
      "confidence": "PROVABLE",
      "evidence": "src/storage/client.py:42 imports StorageBackend"
    }
  ],
  "edges": [
    {
      "from": "PipelineRunner",
      "to": "StorageBackend",
      "kind": "implements",
      "confidence": "PROVABLE",
      "evidence": "src/pipeline/runner.py:42 instantiates StorageBackend"
    }
  ]
}
```

The Model pass's synthesis step reads this format and generates `.c4` elements with `sourceLocation` metadata and confidence tags.

## SourceLocation Metadata Convention

Every code-level element carries a `sourceLocation` metadata field in the format `<repo-relative-path>#<SymbolName>`:

```
component pipeline "Pipeline" {
  #provable
  metadata { sourceLocation "src/pipeline/runner.py#Pipeline" }
}

contract storageBackend "StorageBackend" {
  #inferred
  metadata { sourceLocation "src/storage/base.py#StorageBackend" }
}
```

This is the join key for deterministic extraction: when a future AST extractor or re-assessment run arrives, it matches on sourceLocation instead of title, ensuring update-in-place (no duplication) and stable identity across refactors.

## Key Files

| Path | What it is |
|------|-----------|
| `blueprint/model/system.c4` | Element specification (architecture + code-level kinds) + model |
| `blueprint/model/views.c4` | LikeC4 view definitions (includes `codeStructure` template) |
| `blueprint/model/.likec4rc` | LikeC4 project config |
| `blueprint/bin/likec4` | Wrapper CLI — always use this instead of a bare `likec4`/`npx likec4` |
| `.mcp.json` | LikeC4 MCP server — read-only model query |
| `skills/assessment/SKILL.md` | Lean, procedure-only four-pass system analysis (Census/Infrastructure/Code/Model) with code-level extraction |
| `skills/assessment/reference/` | Confidence tiers, extraction format, disambiguation, domain-rule guidance, stack-specific probes |
| `skills/assessment/extractors/` | Deterministic (`tsserver`) and framework (`llm-nextjs`) extraction scripts wired into the Code pass's Extraction step |
| `skills/assessment/scan.sh` | Read-only discovery scanner for the Census and Code passes. One portable call — `bash skills/assessment/scan.sh <target> [1\|3\|all]` — replacing the ad-hoc find/grep sweeps. Emits sectioned plain text; surfaces candidates, never final facts. Any agent with a shell can run it. |
| `skills/blueprint-change/SKILL.md` | Ticket → EARS → .c4 diff (includes code-level impact check) |

## LikeC4 Syntax Quick Reference

Confidence and other cross-cutting tags are applied with `#tagName` as the *first* statement(s) inside the element's body — there is no `tags` keyword, no comma-separated inline form after the title, and tags cannot come after other properties like `description`:

```
component pipeline "Pipeline" {
  #provable
  description "Orchestrates the ingest cycle."
  metadata { sourceLocation "src/pipeline/runner.py#Pipeline" }
}
```

Tags are declared once in the `specification` block (`tag provable { color #90EE90 }` in `blueprint/model/system.c4`) and referenced by name with `#` at the point of use, never redeclared per-element.

Do not empirically test LikeC4 syntax by writing throwaway files and running the CLI against them. The existing `.c4` files (`blueprint/model/system.c4`, `blueprint/model/views.c4`) and the examples throughout `skills/*/SKILL.md` are the first reference — check those before anything else. If a construct genuinely isn't demonstrated anywhere in this repo, the language grammar is documented at https://likec4.dev/dsl/ (fetch it if you have web access); there is no full syntax reference bundled locally, only a short install-focused `README.md` in the npm package.

## Running LikeC4

Always launch LikeC4 via `blueprint/bin/likec4` (e.g. `blueprint/bin/likec4 serve` from the project root, or `../bin/likec4 serve` from `blueprint/model/`), never a bare `likec4` or `npx likec4`. The wrapper strips AI-provider env vars (which would otherwise auto-enable an unused, version-fragile AI chat panel) and pins a known-good `vite` version (newer patches have a dependency pre-bundling bug that breaks rendering — see the wrapper's comments). This applies to agents running LikeC4 on the user's behalf too.
