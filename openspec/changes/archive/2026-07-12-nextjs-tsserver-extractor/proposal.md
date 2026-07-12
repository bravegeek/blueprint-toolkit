## Why

Assessment Pass 3c currently discovers code-level components and edges by having the LLM read source files, so every code fact lands at `INFERRED` confidence and every edge is a best-effort guess. For a warm project — one already set up with a working type system — the authoritative resolution engine is sitting in `node_modules` and can produce the explicit graph deterministically, with real `file:line` evidence, at `PROVABLE` confidence. This change captures that for the one warm stack in front of us (a Next.js/TypeScript app) without disturbing anything upstream or downstream of Pass 3c.

## What Changes

- Add a **deterministic explicit-graph extractor** driven by `tsserver` (already present in `node_modules/typescript`, zero install). It enumerates symbols and resolves imports, call hierarchy, and interface conformance into the existing extraction JSON, tagged `source: "tsserver"`, at `PROVABLE` confidence with `Location` (`file:line`) evidence.
- Add a **Next.js discovery recipe** (LLM) that extracts framework-implicit wiring the type system structurally cannot see — `app/**/page.tsx` → route, `route.ts` → HTTP endpoint, client `fetch('/api/...')` → handler, `'use client'` server/client boundary, next-auth wiring — into the same JSON, tagged `source: "llm-nextjs"`, at `INFERRED` confidence.
- Establish the **union-behind-the-boundary contract**: the two extractors run on *disjoint* edge sets (AND, not OR — no fallback, no merge conflict), and both emit only the extraction format already spec'd in `skills/assessment/SKILL.md`. `source` records provenance; confidence is set by the tool that produced the fact (confidence-by-construction). The `tsserver` driver's implementation is disposable; the JSON boundary is the protected investment.
- **No change** to the extraction format itself — `edges[].kind` is a free string, so framework edge kinds (`routes`, `fetches`, `handles`, `authenticates`) fit as-is.
- **No change** to assessment Passes 1–2 or Pass 4 (`.c4` synthesis). This work nests entirely inside Pass 3c.
- Scope guardrail: honor the assessment skill's "does not execute application code" rule — tsserver usage must stay static analysis and must not trigger builds/codegen.

Scope is deliberately narrow: **this Next.js/TypeScript app only**. Other languages and a generic LSP driver are explicitly deferred; the boundary contract is what makes that future iteration cheap.

## Capabilities

### New Capabilities
- `code-extraction-boundary`: The multi-source union contract for Pass 3c — every extractor emits only the shared extraction JSON, `source` records provenance, confidence is set by the producing tool (confidence-by-construction), sources cover disjoint fact sets and are unioned, and no source-specific detail leaks past the JSON.
- `tsserver-extraction`: Deterministic extraction of the explicit TypeScript graph (symbols, imports, call hierarchy, interface conformance) via `tsserver`, emitted at `PROVABLE` confidence with `file:line` evidence, under the no-code-execution guardrail.
- `nextjs-discovery-recipe`: LLM extraction of Next.js framework-implicit wiring (file-system routes, route handlers, client→API fetch edges, server/client boundary, auth wiring) that the type system cannot resolve, emitted at `INFERRED` confidence.

### Modified Capabilities
<!-- None. Pass 3c's JSON format and Pass 4 synthesis are unchanged; this adds sources behind the existing boundary. No existing OpenSpec specs exist to modify. -->

## Impact

- **New extractor artifact**: a `tsserver` driver (open project → enumerate → resolve → emit JSON). Bespoke and TS-only for now by design.
- **Skill guidance**: `skills/assessment/SKILL.md` Pass 3c gains the tsserver + Next.js-recipe sources and the union rule; the format block and Pass 4 stay as-is.
- **Dependencies**: none added — `tsserver` ships inside the target project's existing `typescript` dependency.
- **Target for validation**: `fractal-table-vtt` (Next.js, TS, `typescript` in `node_modules`, pnpm workspace). Walking skeleton proves the spine on a single service directory before widening coverage.
- **Downstream**: Pass 4 `.c4` synthesis consumes the unioned JSON unchanged; code elements gain `#provable` tags (from tsserver) alongside `#inferred` (from the recipe).
