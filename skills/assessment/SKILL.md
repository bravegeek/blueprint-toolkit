# Assessment Skill

Read the actual system state in four passes, propose a LikeC4 model with confidence-tiered elements, and confirm with the developer before committing anything.

## Invocation

```
/assessment [path]
```

`path` defaults to `.` (project root). Pass any local path to assess a different target.

---

## Tooling Conventions

Create or edit `.c4` file content directly (whatever your file-write capability is), never by piping a shell heredoc into `cat`/`tee`. LikeC4 syntax is full of `{ }` blocks and quoted strings, and shell heredocs of that shape routinely (and falsely) get flagged as command obfuscation, forcing a manual approval per file. A shell command should only ever be `likec4 validate <path>` or similar — never the thing creating the `.c4` content.

**Wrong:**
```
cat > /tmp/test.c4 <<'EOF'
specification { element system }
model { system sys { title 'Sys' } }
EOF
likec4 validate /tmp/test.c4
```

**Right:** write the file directly through your editing capability, then shell out only to validate:
```
likec4 validate /tmp/test.c4
```

**Don't empirically test syntax at all if you can avoid it.** Before writing any throwaway file to "check" how a construct works, look at `blueprint/model/system.c4`, `blueprint/model/views.c4`, and the worked examples already in `skills/*/SKILL.md` — they cover element declarations, nesting, relationships, and tag usage (`#tagName` as the first statement inside an element's body, declared once in `specification`, never inline after the title and never a `tags` keyword). If the answer isn't there, check `AGENTS.md`'s LikeC4 Syntax Quick Reference. Only fall back to a scratch-file experiment if none of the above answers it, and even then write the file directly rather than through a heredoc.

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

Pass 3c produces a language-neutral intermediate extraction document (JSON) that decouples *how structure is discovered* (LLM reading, future AST tools) from *how it is modeled* (in .c4 elements). This format is the swap point: when a deterministic AST extractor arrives, it emits the same format with STRUCTURAL/PROVABLE confidence, and no downstream changes are needed.

**Format (JSON):**

```json
{
  "source": "llm-assessment",      // or "ast-<tool>" for future extractors
  "language": "python",             // language analyzed
  "components": [
    {
      "symbol": "PipelineRunner",
      "file": "src/pipeline/runner.py",
      "module": "pipeline",
      "exported": true,             // exported/public
      "confidence": "INFERRED"       // INFERRED from LLM reading, STRUCTURAL for AST
    }
  ],
  "contracts": [
    {
      "symbol": "StorageBackend",
      "file": "src/storage/base.py",
      "kind": "protocol",            // protocol, interface, abc, or type
      "confidence": "PROVABLE",
      "evidence": "src/storage/client.py:42 imports StorageBackend"  // quoted evidence for PROVABLE
    }
  ],
  "edges": [
    {
      "from": "PipelineRunner",
      "to": "StorageBackend",
      "kind": "implements",          // implements, calls, instantiates, etc.
      "confidence": "PROVABLE",
      "evidence": "src/pipeline/runner.py:42 instantiates StorageBackend"
    }
  ]
}
```

**Confidence rules:**
- INFERRED: LLM-identified components and patterns (default for LLM reading). Requires developer confirmation.
- PROVABLE: Direct code evidence (inheritance, type annotation, import + usage, instantiation). Requires quoted file:line in `evidence` field.
- STRUCTURAL: Reserved for AST extractors; not used by LLM assessment.
- All untagged entries must have an explicit confidence tier.

**Pass 4 synthesis** reads this format, matches entries by `sourceLocation` (file + symbol), and generates `.c4` elements with `#inferred` or `#provable` tags.

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

**Goal:** Within each service/module found in Pass 1, identify the primary classes (structural units) and the typed interfaces that cross module boundaries (contracts). Emit the code-level extraction format (JSON), defaulting LLM-derived entries to INFERRED and requiring quoted file:line evidence for PROVABLE.

**Language-specific extraction rules:**

#### Python

**Components** (exported classes):
- Classes listed in `__all__` are exported.
- Classes imported by other modules (detected via cross-module `from X import Y` patterns) are exported.
- Model only classes with structural significance — primary controllers, providers, repositories. Skip helpers, utilities, and test doubles.

```bash
grep -rn "^class " TARGET_PATH --include="*.py" | grep -v "test_\|Test" | sort
```

Read each class and check:
1. Is it in `__all__`? → `exported: true`, confidence `INFERRED`.
2. Is it imported by another module? → `exported: true`, confidence `PROVABLE` (quote the import line).
3. Is it only used internally? → skip (internal detail).

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

#### TypeScript / JavaScript

**Components** (exported classes):
- Classes with `export` keyword are exported.
- Model only classes with structural significance — primary controllers, providers, repositories.

```bash
grep -rn "^export class " TARGET_PATH/src --include="*.ts" | sort
```

Read each class. Confidence:
- If explicitly exported → `INFERRED` (LLM identified it).
- If imported and used by another module → `PROVABLE` (quote the import line).

**Contracts** (exported interfaces/types crossing module boundaries):
- `export interface` and `export type` declarations.
- Types/interfaces referenced in imports across modules.

```bash
grep -rn "^export interface\|^export type" TARGET_PATH/src --include="*.ts" | sort
grep -rn "import.*{ [A-Z]" TARGET_PATH/src --include="*.ts" | sort
```

Read each interface/type:
- If consumed by a different module → it's a cross-module contract.
  - Add to `contracts[]` with `kind: "interface"` or `"type"`.
  - If you can quote an import in another module → confidence `PROVABLE`, include `evidence`.
  - Otherwise → confidence `INFERRED`.
- If only used internally → skip.

**Orchestration wiring** (same as Python):
Look for the runtime wiring class by name and read its full method bodies to extract edges.

#### Output of Pass 3c

Emit a single JSON file containing the extracted format:

```json
{
  "source": "llm-assessment",
  "language": "python",
  "components": [ ... ],
  "contracts": [ ... ],
  "edges": [ ... ]
}
```

Save this as `_codeLevelExtraction.json` in the project root or as an intermediate artifact. **Pass 4 consumes only this format.**

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

**Input:** `_codeLevelExtraction.json` from Pass 3c (or an empty extraction if no components/contracts found).

**Processing:**

1. **Match on sourceLocation**: For each component/contract in the extraction, check if an element with matching `sourceLocation` metadata already exists in the model. If it does, update it (re-assessment scenario, no duplication). If it doesn't, add it.

2. **Nesting**: Nest all `component` and `contract` elements under their parent `service` (inferred from Pass 1's service mapping).

3. **Confidence → tags**: For each element:
   - If confidence is `INFERRED` → add `#inferred` tag.
   - If confidence is `PROVABLE` → add `#provable` tag.
   - Do not tag unconfirmed items; those stay for developer review.
   - Tag syntax: `#tagName` must be the *first* statement(s) inside the element's brace body, one per line (or comma-separated) — never inline after the title, and never after `description`/`metadata`. There is no `tags` keyword. E.g. `component pipeline "Pipeline" { #provable ... }`, not `component pipeline "Pipeline" #provable { ... }`.

4. **Metadata**: Add `sourceLocation` metadata: `metadata { sourceLocation '<repo-relative-path>#<SymbolName>' }`.

5. **Cross-module evidence filter**: Drop any component or contract entry from the extraction if it has no cross-module evidence (e.g., a component that is never imported outside its module, a protocol only used internally). These are implementation details, not structural elements.

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

For each service with components, generate a `codeStructure` view:

```
view codeStructure_ingestor {
  title "Ingestor — Code Structure"
  include ingestor.**  // all nested components and contracts
  autoLayout LeftRight
}
```

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
