# Code-Level Extraction Format

The Extraction step (part of the Code pass) produces a language-neutral intermediate extraction document (JSON) that decouples *how structure is discovered* (LLM reading, deterministic AST tools, framework recipes) from *how it is modeled* (in `.c4` elements). This format is the swap point: a deterministic extractor emits the same format with PROVABLE confidence, and no downstream changes are needed.

**Multiple sources**: When multiple extraction sources run (e.g., `tsserver` for deterministic TypeScript resolution + `llm-nextjs` for framework-implicit Next.js wiring), each produces its own extraction JSON. They are unioned (AND, not OR — all sources run, not fallback) over *disjoint fact sets*. The `source` field records provenance so Model synthesis can attribute every fact.

**Format (JSON):**

```json
{
  "source": "tsserver",             // provenance: "tsserver" | "llm-nextjs" | "llm-assessment" | other
  "language": "typescript",          // language analyzed
  "components": [
    {
      "symbol": "ApiHandler",
      "file": "src/pages/api/rooms.ts",
      "module": "api",
      "exported": true,             // exported/public
      "confidence": "PROVABLE"      // PROVABLE from deterministic resolution, INFERRED from LLM reading
    }
  ],
  "contracts": [
    {
      "symbol": "StorageBackend",
      "file": "src/storage/base.ts",
      "kind": "interface",           // interface, protocol, type, etc.
      "confidence": "PROVABLE",
      "evidence": "src/storage/client.ts:42 imports StorageBackend"  // file:line for PROVABLE
    }
  ],
  "edges": [
    {
      "from": "ApiHandler",
      "to": "StorageBackend",
      "kind": "instantiates",        // implements, calls, instantiates, fetches, routes, handles, etc.
      "confidence": "PROVABLE",
      "evidence": "src/pages/api/rooms.ts:18 new StorageBackend()"
    }
  ]
}
```

**Confidence by construction**:
- `tsserver` source → all facts are `PROVABLE` (compiler resolved them) with `evidence` containing `file:line`.
- `llm-nextjs`, `llm-reducer`, and `llm-assessment` sources → all facts are `INFERRED` (convention-based or LLM inference) and may lack `evidence`.
- Confidence is a property of the *source* that produced a fact, not self-reported per-fact.

**Disjoint fact sets**:
- `tsserver` owns compiler-resolvable edges: imports, call hierarchy, `implements` relationships.
- `llm-nextjs` owns framework-implicit edges: file-system routes, route handlers, client→API fetches, `'use client'` boundaries, auth wiring.
- `llm-reducer` owns the semantic decomposition of a reducer's action/command/event union into a `command` verb taxonomy (`handles` edges) — never the union *type* node, reducer *module* node, or import/call edge between them (those are `tsserver`'s).
- Each recipe is scoped to prevent emitting facts `tsserver` already owns, so the union has no overlap.

**No-leak rule**: Source-specific richness (tsserver's quickinfo, type strings, URI/range objects; LLM confidence hints; recipe reasoning traces) is mapped to format fields or dropped entirely. Nothing past the JSON boundary reaches Model synthesis or the `.c4` model.

**Model synthesis** reads the extraction format, unions all sources, matches entries by `sourceLocation` (file + symbol), and generates `.c4` elements with `#provable` (for tsserver) or `#inferred` (for recipes) tags.

## What counts as a component / contract (language-neutral)

**Component**: an exported **class** *or* a cohesive **functional module** — a single source file whose exported functions, constants, and types form one structural unit. The presence or absence of a class does not decide whether a module is emitted. Emit the *module* as one component (named after a dominant exported symbol — a reducer, a class — or the file), not each function as its own node.

**What decides structural significance**: cross-module **import evidence**, not export shape. A module is structural if at least one of its exports is imported by a *different* module — regardless of whether those exports look like "helpers" or "utilities." A cohesive domain directory (many mutually-referencing modules under one path) *reinforces* significance and can drive grouping, but is a secondary signal only, never hardcoded to a project's paths. Modules whose exports are never imported outside themselves are internal detail — skip them.

**Contract**: an exported **interface** *or* an exported **type alias** (including discriminated-union types) imported across module boundaries. A union type imported by another module is a contract exactly the way an interface is; record `kind` as `"type"` or `"interface"`.

## Language-specific extraction rules

### Python

**Components**:
- Classes/functions listed in `__all__`, or imported by another module (via cross-module `from X import Y`), are exported.
- A module of exported functions (no class) imported by another module is a component — emit the *module*, not each function. Do **not** skip it for lacking a class or for looking like a "utility"; import evidence is what makes it structural.

Candidate scan: `grep -rnE "^(class |def |async def )" TARGET_PATH --include="*.py" | grep -v "test_\|Test" | sort` (the Census/Code scanner emits this as `PY_COMPONENTS`).

Read each candidate:
1. In `__all__`? → `exported: true`, confidence `INFERRED`.
2. Imported by another module? → `exported: true`, confidence `PROVABLE` (quote the import line).
3. Exports only used within the module? → skip (internal detail).

**Contracts**: `typing.Protocol`, `abc.ABC`, `dataclass` types used across modules; interface/type files (`protocols.py`, `types.py`, `interfaces.py`).

Candidate scan: `grep -rn "^class.*Protocol\|^class.*ABC\|^@dataclass" TARGET_PATH --include="*.py"` and `find TARGET_PATH -name "protocols.py" -o -name "types.py" -o -name "interfaces.py"` (scanner: `PY_CONTRACTS`).

For each protocol/ABC/dataclass: if consumed by a different module → cross-module contract (`kind: "protocol"|"abc"|"dataclass"`, `PROVABLE` + evidence if you can quote the import/usage, else `INFERRED`). If only used internally → skip.

**Spec contracts** (design-time interface layers): if `specs/*/contracts/` directories exist (e.g. `specs/001-mapper/contracts/`), treat as specification-layer contracts — conditional emission, detect but don't require. `find TARGET_PATH/specs -type d -name contracts` (scanner: `SPEC_CONTRACTS`). Directory existence = STRUCTURAL. Do not fail the Extraction step if none found; defer emission to Model synthesis.

### TypeScript / JavaScript

**Components**: a source file is a component if any of its exports (`export class`, `export function`, `export const`, `export default`) is imported by a *different* module. Emit the module as one component; do not split per function. Do **not** skip a class-free module of functions imported cross-module (e.g. a reducer, a rules module) — that is exactly the case a class-only heuristic wrongly drops.

Candidate scans (scanner: `TS_EXPORTS`, `TS_IMPORTS`):
```bash
grep -rnE "^export (class|(async )?function|const|default) " TARGET_PATH --include="*.ts" --include="*.tsx" | sort
grep -rnE "^import .* from ['\"]" TARGET_PATH --include="*.ts" --include="*.tsx" | sort
```

Confidence: explicitly exported + LLM-identified → `INFERRED`; imported and used by another module → `PROVABLE` (quote the import line).

**Contracts**: `export interface` and `export type` (including discriminated unions); types/interfaces referenced across modules.

Candidate scans (scanner: `TS_CONTRACTS`):
```bash
grep -rnE "^export (interface|type) " TARGET_PATH --include="*.ts" --include="*.tsx" | sort
grep -rnE "^import (type )?\{ [A-Z]" TARGET_PATH --include="*.ts" --include="*.tsx" | sort
```

If consumed by a different module → cross-module contract (`kind: "interface"|"type"`; a union type imported cross-module is a contract exactly like an interface — never dropped for being a `type`). `PROVABLE` + evidence if the import is quotable, else `INFERRED`. Internal-only → skip.

**Orchestration wiring** (same for Python and TS): look for the runtime wiring class — `Pipeline`, `Coordinator`, `Runner`, `Orchestrator`, `App`, `Integration`:

```bash
grep -rln "class.*Pipeline\|class.*Coordinator\|class.*Runner\|class.*Orchestrator" TARGET_PATH --include="*.py"
```

Read the found file; map which components call which methods on which other components. Extract edges from instantiation/method calls/attribute assignments; quote `file:line`; confidence `PROVABLE` if explicit in code, `INFERRED` if pattern-matched from naming.

## Next.js framework discovery (`llm-nextjs`, when Next.js is detected)

Extracts framework-implicit wiring the type system cannot resolve. Run this only when Pass Census (or the scanner's `FRAMEWORK` section) detected Next.js (`next.config.js`, `package.json` `next` dependency, or `app/` directory).

- **File-system routes** (`app/**/page.tsx` → route path): walk the `app/` hierarchy; `app/game/[id]/page.tsx` → `/game/:id`. Emit as components with `kind: "route"`, `confidence: INFERRED`.
- **Route handlers** (`route.ts` → HTTP endpoint): find all `route.ts` files; `app/api/rooms/route.ts` → `POST /api/rooms` / `GET /api/rooms` (per exported `GET`/`POST`/etc.). Emit as components with `kind: "handler"`, `confidence: INFERRED`.
- **Client→API edges**: scan `fetch(...)` calls in client components; match the URL against extracted handler routes; emit an edge `kind: "fetches"`, `confidence: INFERRED`.
- **Server/client boundary**: files with a top-level `'use client'` directive are client-side; components used by both client and server contexts get boundary-crossing facts, `kind: "crosses"`, `confidence: INFERRED`.
- **Auth wiring**: scan for `next-auth` usage (`auth.ts`, `app/api/auth/[...nextauth]/route.ts`, NextAuth imports); route handlers checking auth (`getSession()`, `useSession()`, middleware) get edges `kind: "authenticates"`, `confidence: INFERRED`.

**Disjointness enforcement**: MUST NOT emit any edge that is compiler-resolvable (plain imports, direct calls, `implements`) — those belong to `tsserver`.

**Output**, `source: "llm-nextjs"`:

```json
{
  "source": "llm-nextjs",
  "language": "typescript",
  "components": [
    { "symbol": "/game/:id", "file": "app/game/[id]/page.tsx", "kind": "route", "confidence": "INFERRED" },
    { "symbol": "POST /api/rooms", "file": "app/api/rooms/route.ts", "kind": "handler", "confidence": "INFERRED" }
  ],
  "contracts": [],
  "edges": [
    { "from": "components/GameBoard", "to": "POST /api/rooms", "kind": "fetches", "confidence": "INFERRED" }
  ]
}
```

## Reducer / command discovery (`llm-reducer`, when a discriminated-union + reducer shape is detected)

Command-driven and event-sourced codebases (Redux, CQRS/event-sourcing, Elm/TEA, state machines, hand-rolled reducers) encode their behavioral grammar as a **discriminated-union of action/command/event types dispatched by a reducer**. That union enumerates every verb the domain supports; this recipe surfaces it as `command` elements. Source-agnostic shape recipe, not tied to any framework.

**Gate — detect the shape first (skip if absent)**: a union type whose members share a discriminant field (e.g. `kind`/`type`), consumed by a `switch`/dispatch function over that discriminant. A discriminated union with **no** reducer/dispatch consumer is *not* a command set.

```bash
# candidate reducers: a switch over a discriminant inside an exported dispatch fn
grep -rnE "switch \(\w+\.(kind|type)\)" TARGET_PATH --include="*.ts" --include="*.tsx"
# candidate command unions: an exported union type of *Action / *Command / *Event
grep -rnE "^export type \w+(Action|Command|Event) =" TARGET_PATH --include="*.ts"
```
(scanner: `REDUCER_SHAPE`)

**Emit at category granularity — not leaves.** These unions are usually already a two-level tree (top union → mid-level categories → leaf variants). Emit the **mid-level categories** as `command` nodes (`kind: "command"`, `confidence: INFERRED`); treat leaf variants as internal detail. A 37-leaf union becomes ~10 command nodes, not 37. Never invent a category absent from the type tree.

- **Flat-union fallback** (no mid-level categories): group members by discriminant prefix (e.g. `add-token`/`move-token` → `Token`) or, absent a natural grouping, emit the single top-level union as one command. Still never one node per leaf.

**Link the reducer to the grammar**: emit a `handles` edge from the reducer/dispatch element to each command category.

**Disjointness**: this recipe owns *only* the semantic decomposition of the union into a verb taxonomy. It MUST NOT emit facts `tsserver` owns — the union *type* node, the reducer *module* node, or the plain import/call edge between them.

**Output**, `source: "llm-reducer"` (no format change — `command` rides `components[]` with `kind: "command"`; edge kinds ride the free-string `edges[].kind`):

```json
{
  "source": "llm-reducer",
  "language": "typescript",
  "components": [
    { "symbol": "TokenAction",   "file": "lib/vtt/actions.ts", "kind": "command", "confidence": "INFERRED" },
    { "symbol": "AspectAction",  "file": "lib/vtt/actions.ts", "kind": "command", "confidence": "INFERRED" },
    { "symbol": "EconomyAction", "file": "lib/vtt/actions.ts", "kind": "command", "confidence": "INFERRED" }
  ],
  "contracts": [],
  "edges": [
    { "from": "lib/vtt/actions.ts#applyAction", "to": "TokenAction",   "kind": "handles", "confidence": "INFERRED" },
    { "from": "lib/vtt/actions.ts#applyAction", "to": "EconomyAction", "kind": "handles", "confidence": "INFERRED" }
  ]
}
```

## Model synthesis from the extraction format

**Input:** the unioned extraction JSON containing contributions from all available sources (e.g. `tsserver`, `llm-nextjs`, `llm-reducer`, `llm-assessment`).

1. **Reconcile by sourceLocation first (match, then model — not model, then guess)**: before synthesizing any element, build a reconciliation map keyed by `sourceLocation` (`file#Symbol`): `sourceLocation → { sources, strongest-confidence, evidence }`. For each location, collect every entry reporting it (across all sources), take the **strongest** confidence in precedence `PROVABLE` > `INFERRED` (developer-confirmed AMBIGUOUS is a separate later human step, not overridden here), and record the `file:line` evidence from whichever deterministic source supplied the strongest claim. Node identity is *not* disjoint — the same class/module/type can legitimately appear from both an LLM source and a deterministic source — so this map, not synthesis order, decides confidence. The LLM may author an element's title/description but never its confidence tag.

2. **Match on sourceLocation**: for each component/contract in the extraction, check whether an element with matching `sourceLocation` metadata already exists in the model. Exists → update in place (re-assessment, no duplication). New → add. A `sourceLocation` reported by several sources reconciles (step 1) to a **single** element — never one per source.

3. **Source attribution**: each element carries provenance in its `source` field, used to debug overlaps. Edge fact sets are disjoint (overlapping *edges* are errors to investigate); node identity overlap on the *same* `sourceLocation` is expected, resolved by the step-1 map.

4. **Nesting**: nest `component`, `contract`, and `command` elements under their parent `service` (from Census's service mapping). A `command` from the reducer recipe nests under the service that owns its reducer.

5. **Confidence → tags**: tag from the step-1 map's strongest confidence for the element's `sourceLocation` — never from an LLM's own confidence impression.
   - Reconciled strongest = `PROVABLE` → `#provable`. Holds even when `llm-assessment` also described the same location as `INFERRED`: an INFERRED description MUST NOT downgrade a PROVABLE resolution of the same location.
   - Reconciled = `INFERRED` (only LLM/convention sources report it) → `#inferred`. Never promoted to `#provable`.
   - Unconfirmed items stay untagged for developer review.
   - Every `#provable` element MUST carry the deterministic source's `file:line` evidence on its metadata — no bare `#provable`.
   - Tag syntax: `#tagName` is the *first* statement(s) inside the element's brace body, one per line — never inline after the title, never after `description`/`metadata`. No `tags` keyword. E.g. `component pipeline "Pipeline" { #provable ... }`.

6. **Metadata**: `metadata { sourceLocation '<repo-relative-path>#<SymbolName>' }`; add `source '<source-id>'` if debugging. For `#provable` elements, keep the deterministic evidence here too.

7. **Cross-module evidence filter**: test import evidence, not export shape — keep any component/contract whose exports are imported by a *different* module (including class-free functional modules and type-alias/union contracts). Drop only entries with no cross-module evidence. Granularity stays module-level: one `component` per functional module, never one per function.

**Example output:**

```
// ── From Extraction step (codeLevelExtraction.json) ───
component pipeline "Pipeline" {
  #provable
  description "Orchestrates the ingest cycle."
  metadata { sourceLocation "src/pipeline/runner.py#Pipeline" }
}

contract storageBackend "StorageBackend" {
  #inferred
  description "Storage abstraction protocol."
  metadata { sourceLocation "src/storage/base.py#StorageBackend" }
}

// Edges from extraction:
pipeline -> storageBackend "implements"
```
