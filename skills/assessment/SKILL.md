# Assessment Skill

Read the actual system state in four passes, propose a LikeC4 model with confidence-tiered elements, and confirm with the developer before committing anything.

## Invocation

```
/assessment [path]
```

`path` defaults to `.` (project root). Pass any local path to assess a different target.

**Every run is fresh from the codebase.** No reuse of prior assessments, backups, or extraction caches. If you want to restore an old model, use `blueprint/.backup/` manually.

---

## Tooling Conventions

**No CLI validation during Passes 1–3 or mid-synthesis. None.** Do not run `likec4 validate` (or `likec4 serve`, `likec4 build`, etc.) against any scratch file, test snippet, or partial draft while working through the passes — not to "check a construct works," not to "confirm base syntax," not for any reason. There is exactly one validation point in this skill: after Pass 4 produces the complete proposed `.c4` diff, write it into the real target files (`blueprint/model/system.c4` / `views.c4`) through your normal file-editing capability, and run `likec4 validate` against that real path once. If it fails, fix the file in place and validate again — still never a scratch file, never a heredoc.

This means no `/tmp/*.c4` files, ever, for any purpose, at any point in this skill.

Syntax questions get answered by reading, not by running anything: `blueprint/model/system.c4`, `blueprint/model/views.c4`, and the worked examples in `skills/*/SKILL.md` cover element declarations, nesting, relationships, and tag usage (`#tagName` as the first statement inside an element's body, declared once in `specification`, never inline after the title and never a `tags` keyword). If those don't answer it, check `AGENTS.md`'s LikeC4 Syntax Quick Reference. If none of that answers it, make your best-effort attempt in the real proposed diff and let the single end-of-Pass-4 validation catch it — do not spin up a side experiment to find out first.

---

## Confidence Tiers

Every proposed element and relationship carries a confidence tier.

| Tier | Meaning | Examples |
|------|---------|---------|
| `STRUCTURAL` | Directly observable — artifact exists | Table exists, file exists, bucket exists, route defined |
| `PROVABLE` | Derivable with certainty from artifacts | FK relationship, Python import statement, `depends_on` in compose |
| `INFERRED` | Pattern-matched from name + context | "module likely transforms data based on imports and directory name" |
| `AMBIGUOUS` | Cannot determine without domain knowledge | Business purpose, data classification, system boundary ownership |

STRUCTURAL and PROVABLE → auto-stageable. INFERRED → brief confirmation. AMBIGUOUS → explicit developer input. Never ask about STRUCTURAL items — they are ground truth.

---

## What This Skill Does NOT Do

- Execute any application code
- Guess business logic or domain rules
- Infer behavior that has no artifact backing it
- Assign `dataClassification` or `auth` without developer confirmation (always AMBIGUOUS)
- Read, restore from, or otherwise use `blueprint/.backup/` (or any prior `.c4` backup) as source material. It exists solely so a human can manually recover an old model after `install.sh --clean` — it is not an assessment shortcut. Every run derives elements from the current codebase only, from scratch, even if a backup looks "more thorough." If the developer wants an old backup restored, that is their call to make explicitly, not something to decide mid-assessment.

---

## The Four Passes

Each pass builds on findings from the previous. Stop a pass early and record what's missing rather than guessing.

```
Pass 1: Discover   →  what exists, where it lives, what's running
Pass 2: Extract    →  schema, storage, API surface
Pass 3: Analyze    →  module graph, orchestration, data flow signals
Pass 4: Synthesize →  merge all passes, assign tiers, propose .c4
```

After the four passes: **Confirm** — present only INFERRED and AMBIGUOUS items to the developer.

---

## Code-Level Extraction Format

Pass 3c produces a language-neutral intermediate extraction document (JSON) that decouples *how structure is discovered* (LLM reading, deterministic AST tools, framework recipes) from *how it is modeled* (in .c4 elements). This format is the swap point: when deterministic extractors arrive, they emit the same format with PROVABLE confidence, and no downstream changes are needed.

**Multiple sources**: When multiple extraction sources run (e.g., `tsserver` for deterministic TypeScript resolution + `llm-nextjs` for framework-implicit Next.js wiring), each produces its own extraction JSON. They are unioned (AND, not OR — all sources run, not fallback) over *disjoint fact sets*. The `source` field records provenance so Pass 4 can attribute every fact.

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

**No-leak rule**: Source-specific richness (tsserver's quickinfo, type strings, URI/range objects; LLM confidence hints; recipe reasoning traces) is mapped to format fields or dropped entirely. Nothing past the JSON boundary reaches Pass 4 or the `.c4` model.

**Pass 4 synthesis** reads the extraction format, unions all sources, matches entries by `sourceLocation` (file + symbol), and generates `.c4` elements with `#provable` (for tsserver) or `#inferred` (for recipes) tags.

---

## Pass 1 — Discover

**Goal:** Build the map before reading anything deeply. Establishes service boundaries, stack identity, and what later passes can find.

**Steps:**

**If `TARGET_PATH` is inside a git repo, prefer this form** — it avoids escaped-paren shell grouping (`\( \)`) entirely, which some tool-call/permission parsers choke on when the command is long or multi-line:

```bash
git -C TARGET_PATH ls-files | grep -E '\.(py|ts|tsx|toml|cfg)$|(^|/)(docker-compose.*\.yml|Makefile|pyproject\.toml|requirements.*\.txt|Procfile|package\.json|go\.mod|Cargo\.toml|\.env.*)$' | sort
```

**Otherwise (no git repo), fall back to `find`:**

```bash
find TARGET_PATH -maxdepth 4 \( -name "*.py" -o -name "docker-compose*.yml" -o -name "Makefile" -o -name "*.toml" -o -name "pyproject.toml" -o -name "*.cfg" -o -name "requirements*.txt" -o -name "Procfile" -o -name "*.env" -o -name ".env*" \) -not -path "*/.*" -not -path "*/__pycache__/*" -not -path "*/node_modules/*" | sort
```

Adapt the file extensions and config filenames to your stack (e.g. add `*.ts`, `go.mod`, `Cargo.toml`, `package.json` as appropriate).

**Always keep the actual tool-call command on a single line, whichever form you use.** Backslash line-continuations are for human readability in this doc only — carrying them verbatim into a tool-call argument, especially combined with escaped parens, can trip a permission/safety parser into an unclassifiable "parse error" prompt even though the shell syntax is valid. Expand any pattern list inline on one line instead.

From the layout, determine:
- **Service count** — multiple `main.py` / `app.py` / `index.ts` / `main.go` at different directory levels = multiple services (STRUCTURAL)
- **Pipeline shape** — directory names like `ingest/`, `process/`, `transform/`, `export/`, `load/` signal a pipeline structure (INFERRED)
- **Stack identity** — presence of `docker-compose.yml`, `pyproject.toml`, `package.json`, `go.mod`, `Cargo.toml`, `Makefile`, `Procfile`
- **Orchestrator presence** — Prefect, Airflow, Celery, Luigi, Temporal, BullMQ files found? (gates what Pass 3 looks for)

**Output of Pass 1:** a map of `{ service_roots, pipeline_dirs, stack_signals, orchestrator_type }`. This drives what Passes 2 and 3 actually read.

---

## Pass 2 — Extract

**Goal:** Read the infrastructure layer — running schema, storage, service topology. No code execution beyond DB introspection.

Run all three sub-steps. Each is independent and can fail without blocking the others.

### 2a — Database Schema

> **Stack-specific probe — adapt to your database.**
> The example below targets PostgreSQL + PostGIS (Python/SQLAlchemy).
> For other databases: MySQL → use `information_schema.columns`; MongoDB → use `db.getCollectionInfos()`; SQLite → use `.schema`; Prisma → read `schema.prisma`; etc.

```python
import os, sqlalchemy as sa
from sqlalchemy import inspect

engine = sa.create_engine(os.environ.get('DATABASE_URL', 'postgresql://localhost/app'))
inspector = inspect(engine)

for table_name in inspector.get_table_names():
    columns   = inspector.get_columns(table_name)
    fks       = inspector.get_foreign_keys(table_name)
    indexes   = inspector.get_indexes(table_name)
    pk        = inspector.get_pk_constraint(table_name)
```

```sql
-- PostGIS geometry detail (run only if PostGIS detected in Pass 1)
SELECT f_table_schema, f_table_name, f_geometry_column, type, srid
FROM geometry_columns
ORDER BY f_table_schema, f_table_name;
```

Confidence: tables / columns / FKs = STRUCTURAL. Table *purpose* = AMBIGUOUS.

### 2b — Object Storage

> **Stack-specific probe — adapt to your object storage.**
> The example below targets S3-compatible storage (AWS S3 or local S3-compatible like MinIO).
> For GCS → use `google-cloud-storage`; for Azure Blob → use `azure-storage-blob`; skip if no object storage.

```python
import boto3, os

endpoint = os.environ.get('S3_ENDPOINT_URL', None)  # None = real AWS S3
s3 = boto3.client('s3', endpoint_url=endpoint)

for bucket in s3.list_buckets()['Buckets']:
    objects = s3.list_objects_v2(Bucket=bucket['Name'], MaxKeys=100)
    # Collect top-level prefixes from object keys
    prefixes = set(k['Key'].split('/')[0] for k in objects.get('Contents', []))
```

Confidence: bucket exists = STRUCTURAL. Purpose inferred from prefixes = INFERRED.

### 2c — Container / Service Topology

```python
import yaml

with open('TARGET_PATH/docker-compose.yml') as f:
    compose = yaml.safe_load(f)

for name, svc in compose['services'].items():
    image    = svc.get('image') or svc.get('build')
    ports    = svc.get('ports', [])
    env      = svc.get('environment', {})
    deps     = svc.get('depends_on', [])
```

`depends_on` → PROVABLE dependency edges. Exposed ports → STRUCTURAL API surface. Image/build context → STRUCTURAL technology metadata.

If no `docker-compose.yml` exists, look for `kubernetes/`, `helm/`, `fly.toml`, `render.yaml`, `railway.toml`, or `Procfile` for topology signals.

**Output of Pass 2:** `{ tables, foreign_keys, geometry_columns, buckets, bucket_prefixes, services, service_deps }`.

---

## Pass 3 — Analyze

**Goal:** Read the code layer — module relationships, data flow signals, pipeline sequencing. Pure static analysis, no execution.

Use findings from Pass 1 (service roots, orchestrator type) to scope what's read.

### 3a — Module Graph

> **Stack-specific — adapt import extraction to your language.**
> The example below is Python. For TypeScript: parse `import` statements; for Go: read `import ()` blocks; for Rust: read `use` declarations; etc.

```python
import ast
from pathlib import Path

def extract_imports(py_file: Path) -> list[str]:
    try:
        tree = ast.parse(py_file.read_text())
    except SyntaxError:
        return []
    imports = []
    for node in ast.walk(tree):
        if isinstance(node, ast.Import):
            imports += [a.name for a in node.names]
        elif isinstance(node, ast.ImportFrom) and node.module:
            imports.append(node.module)
    return imports

def extract_table_refs(py_file: Path) -> dict[str, list[str]]:
    """Find tables read from and written to via ORM or raw SQL."""
    src = py_file.read_text()
    reads, writes = [], []
    tree = ast.parse(src)
    for node in ast.walk(tree):
        if isinstance(node, ast.ClassDef):
            for item in node.body:
                if isinstance(item, ast.Assign):
                    for t in item.targets:
                        if isinstance(t, ast.Name) and t.id == '__tablename__':
                            if isinstance(item.value, ast.Constant):
                                reads.append(item.value.value)
    import re
    reads  += re.findall(r'(?i)FROM\s+([a-z_][a-z0-9_]*)', src)
    writes += re.findall(r'(?i)(?:INSERT INTO|UPDATE|DELETE FROM)\s+([a-z_][a-z0-9_]*)', src)
    return {'reads': list(set(reads)), 'writes': list(set(writes))}
```

For each source file:
- Intra-project imports → PROVABLE edges between components
- ORM model / table definitions → STRUCTURAL link to schema table
- SQL `FROM` / `INSERT INTO` patterns → PROVABLE read/write relationships to tables
- Route decorators (FastAPI `@app.get`, Express `router.get`, etc.) → STRUCTURAL API surface

### 3b — Orchestration Discovery

Run only for the orchestrator type detected in Pass 1. If none was detected, fall through to import-graph ordering.

**Prefect** (`@flow`, `@task` decorators):
```bash
grep -rn "@flow\|@task" TARGET_PATH --include="*.py"
```

**Airflow** (DAG definitions, `>>` operator):
```bash
grep -rn "DAG\|>>" TARGET_PATH --include="*.py"
```

**Celery** (`@app.task`, `.delay()`, `.apply_async()`):
```bash
grep -rn "@app\.task\|@shared_task\|\.delay(\|\.apply_async(" TARGET_PATH --include="*.py"
```

**BullMQ / queue-based (Node)**:
```bash
grep -rn "new Worker\|new Queue\|processor" TARGET_PATH --include="*.ts" --include="*.js"
```

**Temporal**:
```bash
grep -rn "@workflow.defn\|@activity.defn" TARGET_PATH --include="*.py"
grep -rn "proxyActivities\|defineSignal" TARGET_PATH --include="*.ts"
```

**Makefile** (phony targets with dependencies):
```bash
grep -E "^[a-zA-Z_-]+:" TARGET_PATH/Makefile
```

**Fallback — import graph ordering** (no orchestrator, no schedule):
If module A imports module B, A is downstream of B. Derive a soft DAG from import depth. Confidence = INFERRED.

### 3c — Component and Contract Discovery

**Goal:** Within each service/module found in Pass 1, identify the structural units (components) and the typed interfaces that cross module boundaries (contracts). Emit the code-level extraction format (JSON), defaulting LLM-derived entries to INFERRED and requiring quoted file:line evidence for PROVABLE.

**What counts as a component (language-neutral):** A `component` is an exported **class** *or* a cohesive **functional module** — a single source file whose exported functions, constants, and types form one structural unit. The presence or absence of a class does not decide whether a module is emitted. Emit the *module* as one component (named after a dominant exported symbol — a reducer, a class — or the file), not each function as its own node.

**What decides structural significance (language-neutral):** cross-module **import evidence**, not export shape. A module is structural if at least one of its exports is imported by a *different* module — regardless of whether those exports look like "helpers" or "utilities." A cohesive domain directory (many mutually-referencing modules under one path) *reinforces* significance and can drive grouping, but is a secondary signal only, never hardcoded to a project's paths. Modules whose exports are never imported outside themselves are internal detail — skip them.

**What counts as a contract (language-neutral):** an exported **interface** *or* an exported **type alias** (including discriminated-union types) imported across module boundaries. A union type imported by another module is a contract exactly the way an interface is; record `kind` as `"type"` or `"interface"`.

**Language-specific extraction rules:**

#### Python

**Components** (exported classes *or* cohesive functional modules):
- Classes and functions listed in `__all__` are exported.
- Classes/functions imported by other modules (detected via cross-module `from X import Y` patterns) are exported.
- A module of exported functions (no class) that is imported by another module is a component — emit the *module*, not each function. Do **not** skip it for lacking a class or for looking like a "utility"; the import evidence is what makes it structural.

```bash
grep -rnE "^(class |def |async def )" TARGET_PATH --include="*.py" | grep -v "test_\|Test" | sort
```

Read each candidate and check:
1. Is it in `__all__`? → `exported: true`, confidence `INFERRED`.
2. Is it imported by another module? → `exported: true`, confidence `PROVABLE` (quote the import line).
3. Are its exports only used within the module? → skip (internal detail).

**Contracts** (typed interfaces crossing module boundaries):
- `typing.Protocol`, `abc.ABC`, `dataclass` types used across modules.
- Interface/type definition files: `protocols.py`, `types.py`, `interfaces.py`.

```bash
find TARGET_PATH -name "protocols.py" -o -name "types.py" -o -name "interfaces.py" | sort
grep -rn "^class.*Protocol\|^class.*ABC\|^@dataclass" TARGET_PATH --include="*.py" | sort
```

Read each definition. For each protocol, ABC, or dataclass:
- If consumed by a different module than the one that defines it → it's a cross-module contract.
  - Add to `contracts[]` with `kind: "protocol"`, `"abc"`, or `"dataclass"`.
  - If you can quote an import or type-hint usage in another module → confidence `PROVABLE`, include `evidence`.
  - Otherwise → confidence `INFERRED`.
- If only used internally → skip.

**Spec contracts** (design-time interface layers):

If `specs/*/contracts/` directories exist (e.g. `specs/001-mapper/contracts/`), treat them as specification-layer contracts. This is conditional emission: detect the directories but do not require them. Include in the extraction format only if found.

```bash
find TARGET_PATH/specs -type d -name contracts | sort
```

For each spec directory found:
- Spec is a design-time constraint layer distinct from runtime `component` and `contract` elements.
- Confidence: directory existence = STRUCTURAL.
- Do not fail Pass 3c if no specs are found; defer spec emission to Pass 4 conditional logic.

#### Next.js Framework Discovery (if project is detected as Next.js)

If Pass 1 detected Next.js (via `next.config.js`, `package.json` with `next` dependency, or `app/` directory structure), run this LLM recipe to extract framework-implicit wiring the type system cannot resolve.

**File-system routes** (`app/**/page.tsx` → route path):
- Walk the `app/` directory hierarchy.
- For each `page.tsx` file, infer the HTTP route path from the directory structure.
  - `app/game/[id]/page.tsx` → `/game/:id`
  - `app/api/rooms/route.ts` is handled separately (see route handlers below).
- Emit as components with `kind: "route"` and `confidence: INFERRED`.

**Route handlers** (`route.ts` → HTTP endpoint):
- Find all `route.ts` files in the `app/` tree.
- Each `route.ts` file defines an HTTP endpoint at the path corresponding to its directory.
  - `app/api/rooms/route.ts` → `POST /api/rooms`, `GET /api/rooms` (handler defines which methods).
- Extract the HTTP methods defined in the file (`export async function GET(...)`, `export async function POST(...)`, etc.).
- Emit as components with `kind: "handler"` and `confidence: INFERRED`.

**Client→API edges** (client `fetch('/api/...')` → handler):
- Scan for `fetch(...)` and `fetch.post(...)` calls in client components.
- Extract the URL string (e.g., `fetch('/api/rooms')`).
- Match against the routes from the handler extraction step.
- Emit an edge from the caller to the matching handler with `kind: "fetches"` and `confidence: INFERRED`.

**Server/client boundary** (`'use client'` directives):
- Identify files with `'use client'` at the top level.
- For each such file, track modules and components as client-side.
- Identify which components are used by both client and server contexts (cross-boundary usage).
- Emit boundary-crossing facts with `kind: "crosses"` and `confidence: INFERRED`.

**Auth wiring** (next-auth integration):
- Scan for `next-auth` usage (presence of `auth.ts`, `route.ts` in `app/api/auth/[...nextauth]/`, NextAuth imports).
- Identify API route handlers that check auth (via `getSession()`, `useSession()`, middleware patterns).
- Emit auth-related edges with `kind: "authenticates"` and `confidence: INFERRED`.

**Disjointness enforcement**: The recipe MUST NOT emit any edge that is compiler-resolvable (plain imports, direct function calls, `implements` relationships). Those belong to the `tsserver` source. If an edge could plausibly be resolved by the type system, exclude it from the recipe output.

**Output of Next.js recipe**:

Emit a JSON file following the extraction format with `source: "llm-nextjs"`:

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

**Orchestration wiring** (component-level relationships):

Look for the runtime wiring class: `Pipeline`, `Coordinator`, `Runner`, `Orchestrator`, `App`, `Integration`.

```bash
grep -rln "class.*Pipeline\|class.*Coordinator\|class.*Runner\|class.*Orchestrator" TARGET_PATH --include="*.py"
```

Read the found file. Map which components call which methods on which other components:
- Extract edges from instantiation calls, method calls, and attribute assignments.
- For each edge, determine the kind: `implements`, `calls`, `instantiates`, etc.
- Quote the file:line of the relationship (e.g., `src/pipeline/runner.py:42`).
- Confidence: `PROVABLE` if the call is explicit in the code, `INFERRED` if inferred from naming patterns.

#### Reducer / Command Discovery (if a discriminated-union + reducer shape is detected)

Command-driven and event-sourced codebases (Redux, CQRS/event-sourcing, Elm/TEA, state machines, hand-rolled reducers) encode their whole behavioral grammar as a **discriminated-union of action/command/event types dispatched by a reducer**. That union is the most valuable behavioral artifact in the system — it enumerates every verb the domain supports. This recipe surfaces that grammar as `command` elements. It is a source-agnostic *shape* recipe, not tied to any framework.

**Gate — detect the shape first (skip the recipe if absent):** a union type whose members share a discriminant field (e.g. `kind`/`type`), consumed by a `switch`/dispatch function over that discriminant. A discriminated union with **no** reducer/dispatch consumer is *not* a command set — do not emit commands for it.

```bash
# candidate reducers: a switch over a discriminant inside an exported dispatch fn
grep -rnE "switch \(\w+\.(kind|type)\)" TARGET_PATH --include="*.ts" --include="*.tsx"
# candidate command unions: an exported union type of *Action / *Command / *Event
grep -rnE "^export type \w+(Action|Command|Event) =" TARGET_PATH --include="*.ts"
```

**Emit at category granularity — not leaves.** These unions are usually already a two-level tree (top union → mid-level categories → leaf variants). Emit the **mid-level categories** as `command` nodes (`kind: "command"`, `confidence: INFERRED`); treat the leaf variants as internal detail. Do **not** emit every leaf (a 37-leaf union becomes ~10 command nodes, not 37). Never invent a category absent from the type tree.

- **Fallback for a flat union** (no mid-level categories): group members by discriminant prefix (e.g. `add-token`/`move-token` → `Token`) or, if no natural grouping, emit the single top-level union as one command. Still never one node per leaf.

**Link the reducer to the grammar:** emit a `handles` edge from the reducer/dispatch element to each command category.

**Disjointness (preserve the union contract):** this recipe owns *only* the semantic decomposition of the union into a verb taxonomy. It MUST NOT emit facts the `tsserver` source owns — the union *type* node, the reducer *module* node, or the plain import/call edge between them. Those come from the deterministic source; if a fact is compiler-resolvable, leave it out here.

**Output of the reducer recipe** — a single JSON tagged `source: "llm-reducer"`, no format change (`command` rides `components[]` with `kind: "command"`; edge kinds ride the free-string `edges[].kind`):

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

#### TypeScript / JavaScript

**Components** (exported classes *or* cohesive functional modules):
- A source file is a component if any of its exports (`export class`, `export function`, `export const`, `export default`) is imported by a *different* module. Emit the module as one component; do not split it per function.
- Do **not** skip a module for lacking a class or for looking like a "utility." A class-free module of functions imported cross-module (e.g. a reducer, a rules module) is a first-class component — that is exactly the case the old class-only grep dropped.

```bash
# candidate exports — classes AND functional exports, not classes alone
grep -rnE "^export (class|(async )?function|const|default) " TARGET_PATH --include="*.ts" --include="*.tsx" | sort
# who imports whom (cross-module evidence: the significance test)
grep -rnE "^import .* from ['\"]" TARGET_PATH --include="*.ts" --include="*.tsx" | sort
```

Read each candidate module. Confidence:
- If explicitly exported and LLM-identified → `INFERRED`.
- If imported and used by another module → `PROVABLE` (quote the import line).

**Contracts** (exported interfaces *or* type aliases crossing module boundaries):
- `export interface` **and** `export type` declarations, including discriminated-union types (`export type X = A | B | ...`).
- Types/interfaces referenced in imports across modules.

```bash
grep -rnE "^export (interface|type) " TARGET_PATH --include="*.ts" --include="*.tsx" | sort
grep -rnE "^import (type )?\{ [A-Z]" TARGET_PATH --include="*.ts" --include="*.tsx" | sort
```

Read each interface/type:
- If consumed by a different module → it's a cross-module contract.
  - Add to `contracts[]` with `kind: "interface"` or `"type"`.
  - A union type imported by another module is a contract exactly like an interface — do not drop it for being a `type` rather than an `interface`.
  - If you can quote an import in another module → confidence `PROVABLE`, include `evidence`.
  - Otherwise → confidence `INFERRED`.
- If only used internally → skip.

**Orchestration wiring** (same as Python):
Look for the runtime wiring class by name and read its full method bodies to extract edges.

#### Output of Pass 3c

Each extraction source emits its own JSON file conforming to the format above, with `source` set to the extraction tool's identifier. The skill's internal logic unions all available sources:
- Always run the default LLM extraction (`source: "llm-assessment"`).
- If the project is warm (has a type system installed), run deterministic extractors (e.g., `source: "tsserver"` for TypeScript).
- If the project is detected as a Next.js app, run the framework recipe (`source: "llm-nextjs"`).
- If a discriminated-union + reducer-dispatch shape is detected, run the reducer/command recipe (`source: "llm-reducer"`).

The union is over disjoint fact sets (AND, not OR — all present sources contribute, no fallback). **Pass 4 consumes the complete unioned output.**

Individual source outputs may be saved as intermediate artifacts (e.g., `_extraction_tsserver.json`, `_extraction_recipe.json`), but the definitive input to Pass 4 is their union.

**Specification-layer contracts** (conditional):

If `specs/*/contracts/` directories are detected, extract them as a separate part of the code-level extraction (or as a parallel output). Do not fail if not found.

```bash
find TARGET_PATH/specs -type d -name contracts | sort
```

For each spec directory found:
- Extract the module name from the path pattern (e.g., `specs/001-mapper/contracts/` → module `mapper`).
- Spec is a design-time constraint layer distinct from runtime `component` and `contract` elements.
- Add to the extraction format (or note separately) for Pass 4 conditional emission.

**Output of Pass 3:** `{ module_edges, table_reads, table_writes, pipeline_dag, pipeline_confidence, codeLevelExtraction, specLayerExtraction? }`.

---

## Pass 4 — Synthesize

**Goal:** Merge all pass outputs into a proposed `.c4` diff, grouped by confidence tier. For code-level elements, consume the extraction format from Pass 3c, match on `sourceLocation`, and emit with metadata and tags.

### Code-level element synthesis (from extraction format)

**Input:** Unioned extraction JSON from Pass 3c containing contributions from all available sources (e.g., `source: "tsserver"`, `source: "llm-nextjs"`, `source: "llm-reducer"`, `source: "llm-assessment"`).

**Processing:**

> **PROVABLE facts are ground truth — do not curate them out.** A component or contract that a deterministic source (`tsserver`) reports with cross-module import evidence is `PROVABLE`, and (per the Confidence Tiers table) PROVABLE ranks with STRUCTURAL as auto-stageable. Every such module MUST be represented by a component, and every such cross-module type (interface *or* discriminated-union `type`, e.g. an action/command union) MUST be represented by a contract. **Do not drop a PROVABLE cross-module component or contract on "primary / significant / it's just a helper" grounds** — that "keep only the important ones" curation applies **only to INFERRED items**, never to PROVABLE ones. The load-bearing seams of a functional codebase (a reducer like `applyAction`, the action/command union it dispatches) are exactly the PROVABLE facts most easily lost to over-curation; they are not optional. You may still choose naming, nesting, descriptions, and which INFERRED items to include — you may not choose to omit a PROVABLE cross-module fact.

1. **Reconcile by sourceLocation first (match, then model — not model, then guess)**: Before synthesizing any element, build a reconciliation map from the *complete unioned* extraction, keyed by `sourceLocation` (`file#Symbol`): `sourceLocation → { sources, strongest-confidence, evidence }`. For each `sourceLocation`, collect every extraction entry that reports it (across `tsserver`, `llm-nextjs`, `llm-assessment`, recipes, …), take the **strongest** confidence in precedence `PROVABLE` > `INFERRED` (developer-confirmed AMBIGUOUS is a separate later human step and is not overridden here), and record the `file:line` evidence from whichever deterministic source supplied the strongest claim. Node identity is *not* disjoint — the same class/module/type legitimately appears from an LLM source and a deterministic source at once — so this map, not synthesis order, decides confidence. Everything below reads the tag from this map; the LLM may author an element's title/description but never its confidence tag.

2. **Match on sourceLocation**: For each component/contract in the extraction, check if an element with matching `sourceLocation` metadata already exists in the model. If it does, update it (re-assessment scenario, no duplication). If it doesn't, add it. A `sourceLocation` reported by several sources reconciles (step 1) to a **single** element — never one element per source.

3. **Source attribution**: Each element carries provenance in its `source` field. Use this to determine which source supplied the reconciled confidence and to debug overlaps. Edge fact sets are disjoint (overlapping *edges* are errors to investigate); node identity overlap on the *same* `sourceLocation` is expected and is resolved by the step-1 map, not treated as an error.

4. **Nesting**: Nest all `component`, `contract`, and `command` elements under their parent `service` (inferred from Pass 1's service mapping). A `command` from the reducer recipe nests under the service that owns its reducer.

5. **Confidence → tags**: The tag is derived from the step-1 reconciliation map's **strongest** confidence for the element's `sourceLocation` — never from the LLM's own confidence impression (confidence is a property of the best available evidence for a location, not a value an LLM self-reports). For each element:
   - If the reconciled strongest confidence is `PROVABLE` → add `#provable` tag. This holds even when an LLM source (`llm-assessment`) also described the same `sourceLocation` as `INFERRED`: an INFERRED description MUST NOT downgrade a PROVABLE resolution of the same location.
   - If the reconciled confidence is `INFERRED` (only LLM/convention sources report the location; no deterministic source covers it) → add `#inferred` tag. Such a location is never promoted to `#provable`.
   - Do not tag unconfirmed items; those stay for developer review.
   - Every `#provable` element MUST carry the deterministic source's `file:line` evidence from the map on its metadata/reasoning trail — no bare `#provable`.
   - Tag syntax: `#tagName` must be the *first* statement(s) inside the element's brace body, one per line (or comma-separated) — never inline after the title, and never after `description`/`metadata`. There is no `tags` keyword. E.g. `component pipeline "Pipeline" { #provable ... }`, not `component pipeline "Pipeline" #provable { ... }`.

6. **Metadata**: Add `sourceLocation` metadata: `metadata { sourceLocation '<repo-relative-path>#<SymbolName>' }`. Include source attribution if debugging: `metadata { sourceLocation '<repo-relative-path>#<SymbolName>', source '<source-id>' }`. For a `#provable` element, keep the deterministic source's `file:line` evidence (from the step-1 map) here so the tag is always backed by the evidence that justifies it.

7. **Cross-module evidence filter**: The filter tests **import evidence, not export shape.** Keep any component or contract whose exports are imported by a *different* module — this includes class-free functional modules (e.g. a reducer, a rules module) and type-alias/discriminated-union contracts, which earlier class-only heuristics wrongly dropped as "utilities." Drop only entries with no cross-module evidence (exports never imported outside their own module) — those are implementation detail. Granularity stays **module-level**: one `component` per functional module (named after a dominant export or the file), never one per function. This adds no new element kinds and no format change — functional modules are `component`s and union types are `contract`s exactly like classes and interfaces.

**Example output (from extraction):**

```
// ── From Pass 3c extraction (codeLevelExtraction.json) ───
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

### Architecture-level cross-validation rules

| Finding | If also supported by | Promote to |
|---------|---------------------|------------|
| INFERRED bucket purpose | Prefix pattern + module that references that bucket name | PROVABLE |
| INFERRED pipeline stage | Import graph ordering agrees with orchestrator DAG | PROVABLE |
| INFERRED service boundary | `depends_on` in compose + module import confirms direction | PROVABLE |

### Proposed `.c4` Output

The specification block must declare all element kinds used. The base specification (from `blueprint/model/system.c4`) now includes `component`, `contract`, and `spec` unconditionally. Re-run `install.sh` or manually update existing projects.

Group proposed elements by tier. AMBIGUOUS items are commented stubs with explicit questions.

```
// ── STRUCTURAL (auto-stageable) ──────────────────────────────────
system acme "Acme" {
  service ingestor "Ingestor" {
    technology "Python"

    component pipeline "Pipeline" {
      #provable
      description "Orchestrates the ingest cycle."
      metadata { sourceLocation "src/pipeline/runner.py#Pipeline" }
    }

    contract recordPacket "RecordPacket" {
      #provable
      description "Typed payload emitted after each ingest step."
      metadata { sourceLocation "src/types.py#RecordPacket" }
    }
  }

  datastore db "PostgreSQL" {
    technology "PostgreSQL 15"
  }
}

// ── PROVABLE (auto-stageable) ─────────────────────────────────────
// RecordPacket is imported by transformer.py line 8
ingestor.recordPacket -> transformer "consumed by"

// ── INFERRED (confirm before staging) ────────────────────────────
// confidence: 0.75 — directory named 'transform/' imports from 'ingest/'
// Confirm: is transform/ a separate service or part of the same process?
service transformer "Transform Service" { ... }

// ── AMBIGUOUS (needs your input) ─────────────────────────────────
// Q: What is the data classification for the records table?
// Q: Who owns the ingestor service?
```

### Specification-layer element emission (conditional)

**Conditional on Pass 3's detection of `specs/*/contracts/` directories:**

If `specs/*/contracts/` directories were found during Pass 3c:
- Add `spec` and `defines` element/relationship kinds to the specification block (already unconditional in `blueprint/model/system.c4`, so no change needed).
- Emit one `spec` element per detected module (e.g., `spec mapperSpec "Mapper Specification"`).
- Nest each spec under a `contractSpecs` container: `contractSpecs.mapperSpec`.
- Link each spec to its governed service with `defines` relationship (e.g., `contractSpecs.mapperSpec -> mapper "defines"`).

If no `specs/*/contracts/` directories were found:
- Do not emit `spec` elements; the kinds remain in the specification but unused.
- This is harmless and forward-compatible: a project can add spec contracts later without modifying the specification.

### Code-level views

For each service with components, generate a `codeStructure` view. This is where `command` elements belong — the code-structure (or a dedicated engine/domain) view shows the reducer and the command taxonomy it `handles`:

```
view codeStructure_ingestor {
  title "Ingestor — Code Structure"
  include ingestor.**  // all nested components, contracts, and commands
  autoLayout LeftRight
}
```

Keep `command` elements **out of the top-level architecture views** (`index`, `context`, `services`) by default — the verb taxonomy is code-level detail, not system topology. If those views would pull commands in via a broad `include`, exclude them (e.g. `exclude command`).

### Views to Propose

Always propose these four views. Add extras for any focused concern worth isolating.

```
view index {
  title "[system] — System Overview"
  include *                          // top-level only: actors, external systems, the system boundary
  include system.*                   // one level of children inside the system (services, datastores, etc.)
                                      // NOTE: unscoped `include *` does NOT descend into nested elements —
                                      // it must be paired with an explicit `<system>.*` (or `.**`) to show internals.
}

view context {
  title "[system] — Context"
  include actor, system              // system as opaque box; no services or components
  exclude system.*
  autoLayout LeftRight
}

view services {
  title "[system] — Services"
  include system, system.serviceA, system.serviceB, ...   // services only, no components
  autoLayout TopBottom
}

view pipeline {
  title "[system] — Runtime Pipeline"
  // show the orchestration component and what it calls
  include system.integration.pipeline
  include system.moduleA.contract
  include system.moduleB.impl
  ...
  autoLayout LeftRight
}
```

If contracts were found, also propose:

```
view contracts {
  title "[system] — Cross-Module Contracts"
  include system.moduleA.contractX, system.moduleB.contractY, ...
  autoLayout TopBottom
}
```

If spec contracts were found (`specs/*/contracts/` directories), also propose:

```
view specLayer {
  title "[system] — Specification Layer"
  include system.contractSpecs
  include system.contractSpecs.*
  include system.service1, system.service2, ...  // all governed services
  autoLayout TopBottom
}

view service1Spec {
  title "[system] — Service1 Spec Blast Radius"
  include system.contractSpecs.service1Spec
  include system.service1
  include system.service1.contractA
  include system.service2.component  // consuming component example
  autoLayout TopBottom
}

// Repeat per-spec view for each module spec
```

---

## Confirm

Present the proposed `.c4` and ask only about INFERRED and AMBIGUOUS items:

1. **INFERRED check** — list each inferred relationship with its evidence. "We inferred X because Y — is that right?"
2. **Gap check** — "What does this miss that the code doesn't make visible?" (business logic, external integrations, user actors)
3. **Metadata** — "What `owner`, `dataClassification`, and `auth` values should be added?"

When the developer confirms, commit the `.c4` model.
