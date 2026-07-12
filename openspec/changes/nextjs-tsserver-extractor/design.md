## Context

Assessment Pass 3c (`skills/assessment/SKILL.md`) already defines a language-neutral extraction JSON — `{ source, language, components[], contracts[], edges[] }` with per-entry `confidence` and `evidence`. It was explicitly designed as a swap point: "when a deterministic AST extractor arrives, it emits the same format... and no downstream changes are needed." Today only one source exists (`llm-assessment`), so every code fact is `INFERRED`.

The target is a warm project: `fractal-table-vtt`, a Next.js/TypeScript app with `typescript@5.7.3` in `node_modules` (so `node_modules/typescript/lib/tsserver.js` is present), a pnpm workspace, and next-auth. "Warm" means the exact semantic engine the developer's editor uses is already installed and indexable — the expensive part of any language-server approach is pre-paid.

This design implements two extractors behind the existing boundary and formalizes how multiple sources coexist. It does not touch Passes 1–2 or Pass 4.

## Goals / Non-Goals

**Goals:**
- Produce `PROVABLE` code facts (with `file:line` evidence) for the explicit TypeScript graph, replacing today's `INFERRED`-only output where the type system can resolve.
- Capture Next.js framework-implicit wiring the compiler cannot see, at `INFERRED`.
- Keep both extractors behind the existing extraction JSON with zero format changes; make the tsserver driver disposable and the boundary the durable investment.
- Prove the full spine end-to-end on one service directory of `fractal-table-vtt`.

**Non-Goals:**
- Any language other than TypeScript. No Python/Go/Rust adapters.
- A generic LSP driver or `typescript-language-server` dependency. We drive `tsserver` directly, in-repo.
- Tree-sitter. A warm project makes syntactic-only parsing redundant.
- Changes to the extraction format, Pass 4 synthesis, or the `.c4` model shape.
- A fallback/degradation ladder. This change assumes the project is warm; absence handling is deferred.

## Decisions

### D1 — tsserver, not tree-sitter, not a generic LSP driver
**Choice:** Drive `tsserver` from the target's own `node_modules/typescript`.
**Why:** The project is warm, so the resolution engine is already installed with zero setup. tsserver does full cross-file name resolution (the exact thing tree-sitter cannot do without a hand-rolled resolver) and returns authoritative `Location`s usable directly as PROVABLE evidence. It ships inside the `typescript` dep, so no new dependency.
**Alternatives:**
- *tree-sitter* — syntactic only; would require building a bespoke cross-file resolver to reach PROVABLE. Rejected: redundant when a real type engine is warm.
- *typescript-language-server (generic LSP)* — standard protocol, reusable across languages, but adds an install and buys nothing extra for a single TS target now. Deferred to the multi-language iteration.

### D2 — AND, not OR: two extractors on disjoint edge sets
**Choice:** tsserver and the Next.js recipe both always run and their outputs are unioned; they are not fallbacks for each other.
**Why:** They cover structurally disjoint facts. tsserver owns edges the compiler can prove (imports, call hierarchy, `implements`). The recipe owns edges the framework wires by convention and the compiler is blind to (file-system routes, `fetch('/api/...')` → handler, `'use client'` boundary, auth). Because the fact sets don't overlap, the union has no merge conflict and needs no reconciliation.
**Alternative:** OR/degradation ladder (best-available source wins). Rejected for the warm case — it models absence, which is out of scope here; both sources are present and complementary.

### D3 — Confidence-by-construction
**Choice:** The producing tool sets the confidence ceiling; confidence is not self-reported per fact by an LLM.
**Why:** tsserver facts are provable by construction (the resolver said so, here is the `Location`); recipe facts are inferred by construction (convention-based judgment). This makes confidence an auditable property of provenance rather than a guess. `source` records which tool produced each fact.

### D4 — The JSON boundary is sacred; the driver is disposable
**Choice:** tsserver output is mapped down to exactly the existing fields (`symbol`, `file`, `module`, `exported`, `kind`, `confidence`, `evidence`, edge `from/to/kind`). None of tsserver's richer payload (quickinfo, type strings, its own URI/range shapes) is allowed past the mapping.
**Why:** The only thing that must survive future iteration (Python, generic LSP) is the format. If tool-specific detail leaks into Pass 4 or the `.c4`, the model couples to tsserver and the next adapter becomes a rewrite. Framework edge kinds (`routes`, `fetches`, `handles`, `authenticates`) use the existing free-string `edges[].kind` — no format change.

### D5 — Static-analysis-only guardrail
**Choice:** Use only tsserver requests that are pure static analysis (`open`, `navto`, `references`, `definitionAndBoundSpan`, `implementation`, `documentSymbol`). Do not invoke anything that triggers a build, codegen, or executes project config.
**Why:** The assessment skill forbids executing application code (SKILL.md line 42). tsserver indexing is static, but the driver must stay within the read-only query surface and must not, e.g., run build tasks or evaluate arbitrary config as code.

## Risks / Trade-offs

- **tsserver protocol is stateful and bespoke** → keep the driver a thin, throwaway adapter (open → query → emit → shutdown); never leak its shapes past the JSON boundary (D4), so its flakiness/quirks stay contained and swappable.
- **Monorepo / project-references resolution gaps** (pnpm workspace) → open the project via the target's `tsconfig.json` so project references resolve; anything tsserver cannot resolve simply isn't emitted as PROVABLE (no false evidence) and may be picked up by the recipe or left for developer confirmation.
- **Recipe over-reaches into edges tsserver already owns** → the recipe is scoped by written rule to framework-implicit wiring only; overlap would produce duplicate edges, not wrong ones, but the disjoint-set discipline (D2) is a spec requirement, not a convention.
- **Indexing cost on a large project** → assessment is one-shot, not a hot loop; pay the index once. Acceptable.
- **Anchor churn on re-assessment** (renamed files/symbols break `sourceLocation` match in Pass 4) → out of scope here; Pass 4 already matches on `sourceLocation` and this change doesn't alter that behavior.

## Migration Plan

Additive only. No existing behavior is removed:
1. Land the `code-extraction-boundary` union rules in Pass 3c guidance.
2. Add the tsserver driver + its Pass 3c source.
3. Add the Next.js recipe source.
4. Validate the walking skeleton on one `fractal-table-vtt` service dir: tsserver JSON (PROVABLE) ∪ recipe JSON (INFERRED) → Pass 4 → `.c4`.
Rollback is deletion of the two sources; `llm-assessment` remains the default and Pass 4 is untouched.

## Decisions Confirmed During Implementation

### D6 — Driver lives as a committed Node.js script
**Resolved:** The tsserver driver is a thin, committed script at `skills/assessment/tsserver-extractor.mjs`, invoked as `node tsserver-extractor.mjs <project-root>`. This keeps the driver isolated, testable, and replaceable without touching the skill agent code.

### D7 — Edge-kind vocabulary (empirically settled)
**From walking-skeleton validation on fractal-table-vtt:**
- `route`: File-system routes (app/path/page.tsx → route path)
- `handler`: HTTP request handlers (app/path/route.ts → method)
- `fetches`: Client component → handler edges (client fetch('/api/...') → handler)
- `authenticates`: Auth-related edges (next-auth wiring)
- `imports`: Compiler-resolvable imports (from tsserver)
- `instantiates`: Class/component instantiation (from tsserver)
- `implements`: Interface/protocol implementation (from tsserver)
- `calls`: Direct function calls (from tsserver)

This vocabulary fits entirely within the existing free-string `edges[].kind` field. No schema change needed.

## Deferred Scope (Future Iterations)

The following are **intentionally out of scope** for this iteration and documented as follow-ups:

1. **Other programming languages** (Python, Go, Rust, Java, etc.)
   - The tsserver driver is TypeScript-only. Future iterations can add language-specific extractors (e.g., Python AST, Go `go/types`, Rust `rust-analyzer`), each following the same extraction JSON boundary and disjoint-set contract.

2. **Generic LSP driver** (typescript-language-server, pyright, gopls, etc.)
   - A generic Language Server Protocol adapter would support multiple languages with one implementation. Deferred because: (a) adds a new dependency, (b) cold projects need fallback handling (out of scope), (c) language-specific extractors are more practical for warm projects.

3. **Degradation ladder** (fallback when a tool is unavailable)
   - This iteration assumes all required tools are present (TypeScript, Node.js, source code readable). Graceful degradation (e.g., "tsserver not available, skip deterministic extraction") is out of scope. Future iterations can add this after the multi-language foundation is in place.

4. **Confidence refinement** (per-fact confidence self-report)
   - This iteration uses confidence-by-construction (tool-level). Future iterations might add per-fact uncertainty metrics or confidence thresholds, but the boundary contract (format fields only, no metadata leakage) remains unchanged.
