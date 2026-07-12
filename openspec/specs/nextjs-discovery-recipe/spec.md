# nextjs-discovery-recipe Specification

## Purpose
TBD - created by archiving change nextjs-tsserver-extractor. Update Purpose after archive.
## Requirements
### Requirement: Extract Next.js framework-implicit wiring

The recipe SHALL extract architectural edges that Next.js wires by convention and that the type system cannot resolve, including at minimum: file-system routes (`app/**/page.tsx` → route path), route handlers (`route.ts` → HTTP endpoint), client-to-API edges (client `fetch('/api/...')` → the handler that serves that path), the server/client boundary (`'use client'`), and auth wiring (next-auth). Each fact is emitted at `INFERRED` confidence.

#### Scenario: A page file maps to a route

- **WHEN** the recipe encounters `app/game/[id]/page.tsx`
- **THEN** it emits a fact representing the `/game/:id` route for that page
- **AND** the fact's `confidence` is `INFERRED`

#### Scenario: A client fetch maps to its handler

- **WHEN** a client component calls `fetch('/api/rooms')` and a `route.ts` handles `/api/rooms`
- **THEN** the recipe emits an edge from the caller to the handler with a framework edge kind (e.g. `fetches`)
- **AND** the edge's `confidence` is `INFERRED`

#### Scenario: Server/client boundary is captured

- **WHEN** a module declares `'use client'`
- **THEN** the recipe records the server/client boundary crossing where that module is used

### Requirement: Stay within framework-implicit wiring only

The recipe SHALL restrict itself to framework-implicit facts and MUST NOT emit edges that the deterministic tsserver extractor already owns (compiler-resolvable imports, calls, and `implements` relationships), preserving the disjoint-set contract.

#### Scenario: Recipe does not duplicate compiler-resolvable edges

- **WHEN** an edge is a plain cross-file import or direct call resolvable by the type system
- **THEN** the recipe does NOT emit it
- **AND** leaves it to the `tsserver` source

### Requirement: Emit through the shared boundary only

The recipe's output SHALL conform to the shared extraction format tagged `source: "llm-nextjs"`, using the existing free-string `edges[].kind` for framework edge kinds (`routes`, `fetches`, `handles`, `authenticates`) with no format change.

#### Scenario: Output is the standard format

- **WHEN** the recipe finishes
- **THEN** it emits a single extraction JSON with `source: "llm-nextjs"`
- **AND** framework edge kinds populate the existing `edges[].kind` field with no schema change

