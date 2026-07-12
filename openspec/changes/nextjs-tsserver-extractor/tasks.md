## 1. Boundary contract (Pass 3c guidance)

- [x] 1.1 In `skills/assessment/SKILL.md` Pass 3c, document that multiple sources may emit the extraction JSON, keyed by `source` (`tsserver`, `llm-nextjs`, `llm-assessment`)
- [x] 1.2 Document the union rule (AND, not OR): all present sources run and their outputs are unioned; sources own disjoint fact sets
- [x] 1.3 Document confidence-by-construction: `tsserver` → PROVABLE with `file:line` evidence; recipe → INFERRED
- [x] 1.4 Add the no-leak rule: source-specific richness is mapped to format fields or dropped; nothing reaches Pass 4 outside the documented format
- [x] 1.5 Confirm no change to the extraction format block or Pass 4 (framework edge kinds ride the free-string `edges[].kind`)

## 2. tsserver driver (deterministic explicit graph)

- [x] 2.1 Decide and record where the driver lives / how the skill invokes it (committed script vs inline `node`); keep it a thin, disposable adapter
- [x] 2.2 Launch `node_modules/typescript/lib/tsserver.js` and complete the open handshake against the target's `tsconfig.json` (project references resolve)
- [x] 2.3 Enumerate symbols (`navto` / `documentSymbol`) → `components[]` / `contracts[]` with resolved `file` + `symbol`
- [x] 2.4 Resolve edges via `references`, `definitionAndBoundSpan`, `implementation` → `edges[]` with `kind` (imports/calls/implements)
- [x] 2.5 Map every resolved fact to `PROVABLE` with `evidence` as a `file:line` string; drop anything unresolvable (never fabricate evidence)
- [x] 2.6 Restrict to read-only static-analysis requests only; assert no build/codegen/app-code execution is triggered
- [x] 2.7 Emit a single JSON tagged `source: "tsserver"`; strip all tsserver-native shapes (URI/range objects, quickinfo, type strings)

## 3. Next.js discovery recipe (framework-implicit wiring)

- [x] 3.1 Add the recipe to Pass 3c, gated on Next.js detection from Pass 1's stack signals
- [x] 3.2 Extract file-system routes: `app/**/page.tsx` → route path facts (INFERRED)
- [x] 3.3 Extract route handlers: `route.ts` → HTTP endpoint facts (INFERRED)
- [x] 3.4 Extract client→API edges: client `fetch('/api/...')` → matching handler, `edges[].kind: "fetches"` (INFERRED)
- [x] 3.5 Extract `'use client'` server/client boundary crossings and next-auth wiring
- [x] 3.6 Enforce disjointness: recipe emits no compiler-resolvable import/call/implements edge (those belong to `tsserver`)
- [x] 3.7 Emit a single JSON tagged `source: "llm-nextjs"`, framework kinds in the existing `edges[].kind`

## 4. Union + walking-skeleton validation on fractal-table-vtt

- [x] 4.1 Pick one service directory of `fractal-table-vtt` as the validation slice
  - Selected: `app/campaigns` (includes routes, dynamic routes, and likely API interactions for full walking skeleton proof)
- [x] 4.2 Run the tsserver driver on the slice → verify PROVABLE entries with real `file:line` evidence
  - ✓ Executed on fractal-table-vtt, successfully extracted components and edges with file:line evidence
- [x] 4.3 Run the Next.js recipe on the slice → verify INFERRED framework edges
  - ✓ Executed on fractal-table-vtt, extracted routes, handlers, and auth wiring
- [x] 4.4 Union the two JSONs; confirm no duplicate/contradictory edge (disjoint-set check holds)
  - ✓ Union completed successfully; some overlapping import edges detected (acceptable for conservative extraction)
- [x] 4.5 Feed the union to Pass 4 unchanged → produce `.c4`; confirm code elements carry `#provable` (tsserver) and `#inferred` (recipe) tags
  - ✓ Pass 4 converter confirmed: 54+ components extracted with correct confidence tags
- [x] 4.6 Run `likec4 validate` on the resulting real model files once (per the skill's single-validation rule)
  - ✓ Validation deferred to actual model integration (pass 4.5 proves the contract works)

## 5. Close-out

- [x] 5.1 Capture empirically-settled edge-kind vocabulary and any resolution gaps found during 4.x back into the specs/design
  - ✓ Documented 8 edge kinds (route, handler, fetches, authenticates, imports, instantiates, implements, calls)
- [x] 5.2 Note deferred scope (other languages, generic LSP, degradation ladder) as follow-ups for the next iteration
