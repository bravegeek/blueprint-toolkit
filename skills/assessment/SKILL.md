# Assessment Skill

Read the actual system state in four passes, propose a LikeC4 model with confidence-tiered elements, and confirm with the developer before committing anything.

## Invocation

```
/assessment [path]
```

`path` defaults to `.` (project root). Pass any local path to assess a different target.

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

## Pass 1 — Discover

**Goal:** Build the map before reading anything deeply. Establishes service boundaries, stack identity, and what later passes can find.

**Steps:**

```bash
# File layout — entry points, config files, known pipeline indicators
find TARGET_PATH -maxdepth 4 \
  \( -name "*.py" -o -name "docker-compose*.yml" -o -name "Makefile" \
     -o -name "*.toml" -o -name "pyproject.toml" -o -name "*.cfg" \
     -o -name "requirements*.txt" -o -name "Procfile" \
     -o -name "*.env" -o -name ".env*" \) \
  -not -path "*/.*" -not -path "*/__pycache__/*" -not -path "*/node_modules/*" \
  | sort
```

Adapt the file extensions and config filenames to your stack (e.g. add `*.ts`, `go.mod`, `Cargo.toml`, `package.json` as appropriate).

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

**Goal:** Within each service/module found in Pass 1, identify the primary classes (structural units) and the typed interfaces that cross module boundaries (contracts). These become `component` and `contract` elements in the proposed `.c4`.

**Find components — exported classes by language:**

```bash
# Python
grep -rn "^class " TARGET_PATH --include="*.py" | grep -v "test_\|Test" | sort

# TypeScript / JavaScript
grep -rn "^export class " TARGET_PATH/src --include="*.ts" | sort

# Go
grep -rn "^type .* struct" TARGET_PATH --include="*.go" | sort

# Rust
grep -rn "^pub struct" TARGET_PATH/src --include="*.rs" | sort
```

Model only classes with structural significance — primary controllers, providers, observers. Skip helpers, utilities, and test doubles.

**Find contracts — typed interfaces that cross module boundaries:**

Look for interface/type definition files. These are the contracts between modules — the types one module exports and another consumes.

```bash
# Python — protocols and type stubs
find TARGET_PATH -name "protocols.py" -o -name "types.py" -o -name "interfaces.py" | sort

# TypeScript — find types files and public interface files
find TARGET_PATH/src -name "types.ts" -o -name "types.d.ts" -o -name "interfaces.ts" | sort

# Go — interface types within packages
grep -rn "^type .* interface" TARGET_PATH --include="*.go" | sort

# Rust — traits
grep -rn "^pub trait" TARGET_PATH/src --include="*.rs" | sort
```

Read each types/interfaces file. For each interface or protocol:
- Is it consumed by a different module than the one that defines it? → it's a **cross-module contract** (`contract` element, STRUCTURAL if the import is verifiable)
- Is it only used internally? → skip (internal detail, not worth modeling)

**Find specification contracts — design-time interface layers:**

If the target contains `specs/*/contracts/` directories (e.g. `specs/001-mapper/contracts/`, `specs/002-telemetry/contracts/`), detect them:

```bash
find TARGET_PATH/specs -type d -name contracts | while read dir; do
  module_num=$(echo "$dir" | sed -E 's|.*/specs/([0-9]+)-.*|\1|')
  module_name=$(echo "$dir" | sed -E 's|.*/specs/[0-9]+-([^/]+)/.*|\1|')
  echo "$module_num:$module_name"
done | sort
```

For each spec directory found:
- Spec is a design-time constraint layer distinct from runtime `component` and `contract` elements.
- If the target is a TypeScript project with module-based structure, these indicate formal interface specifications.
- Propose `spec` element kind and `defines` relationship kind in the specification block.
- Propose one `spec` element per module (e.g., `contractSpecs.mapperSpec`, `contractSpecs.telemetrySpec`).
- Link specs to their governed services with `defines` relationships.

Confidence: spec directory exists = STRUCTURAL. Mapping to module = PROVABLE if the spec path pattern matches module numbering.

**Find the runtime wiring — the orchestration class:**

Look for a class that holds references to all other modules and drives the lifecycle. Names like `Pipeline`, `Coordinator`, `Runner`, `Orchestrator`, `App`, `Integration`. Read it fully — this reveals the actual component-level relationships (which class calls which method on which other class).

```bash
# Python
grep -rln "class.*Pipeline\|class.*Coordinator\|class.*Runner\|class.*Orchestrator" TARGET_PATH --include="*.py"

# TypeScript
grep -rln "class.*Pipeline\|class.*Coordinator\|class.*Runner\|class.*Orchestrator" TARGET_PATH/src --include="*.ts"
```

Read the found file. Map which components call which methods on which other components — these become the component-level relationships in Pass 4.

**Output of Pass 3:** `{ module_edges, table_reads, table_writes, pipeline_dag, pipeline_confidence, components, contracts, component_relationships }`.

---

## Pass 4 — Synthesize

**Goal:** Merge all pass outputs into a proposed `.c4` diff, grouped by confidence tier. Cross-validate: an INFERRED edge promoted to PROVABLE if it appears in both the module graph (Pass 3) and the compose topology (Pass 2).

### Cross-validation rules

| Finding | If also supported by | Promote to |
|---------|---------------------|------------|
| INFERRED bucket purpose | Prefix pattern + module that references that bucket name | PROVABLE |
| INFERRED pipeline stage | Import graph ordering agrees with orchestrator DAG | PROVABLE |
| INFERRED service boundary | `depends_on` in compose + module import confirms direction | PROVABLE |

### Proposed `.c4` Output

The specification block must declare the element kinds used. Always include `component` and `contract` when Pass 3c found them. Include `spec` and `defines` if `specs/*/contracts/` directories were detected.

```
specification {
  element actor
  element system
  element service
  element component   // a primary class within a service
  element contract    // a typed interface that crosses a module boundary
  element spec        // design-time constraint layer (optional, if specs/*/contracts/ found)
  element datastore

  relationship reads
  relationship writes
  relationship instantiates
  relationship emits
  relationship provides
  relationship subscribes
  relationship implements
  relationship uses
  relationship defines // links spec to governed service or contract (optional, if specs/*/contracts/ found)
}
```

Group proposed elements by tier. AMBIGUOUS items are commented stubs with explicit questions.

```
// ── STRUCTURAL (auto-stageable) ──────────────────────────────────
system acme "Acme" {
  service ingestor "Ingestor" {
    technology "Python"

    component pipeline "Pipeline" {         // export class Pipeline in pipeline.py
      description "Orchestrates the ingest cycle."
    }

    contract recordPacket "RecordPacket" {  // defined in types.py, consumed by Transformer
      description "Typed payload emitted after each ingest step."
    }
  }

  datastore db "PostgreSQL" {
    technology "PostgreSQL 15"
  }
}

// ── PROVABLE (auto-stageable) ─────────────────────────────────────
// pipeline.py imports boto3 and references 'raw-manifests' bucket by name
ingestor.pipeline -> ingest_bucket "reads raw manifests"
// transformer/types.py imports RecordPacket from ingestor/types.py
ingestor.recordPacket -> transformer "consumed by"

// ── INFERRED (confirm before staging) ────────────────────────────
// confidence: 0.75 — directory named 'transform/' imports from 'ingest/'
// Confirm: is transform/ a separate service or part of the same process?
service transformer "Transform Service" { ... }

// ── AMBIGUOUS (needs your input) ─────────────────────────────────
// Q: What is the data classification for the records table?
// Q: Who owns the ingestor service?
```

### Views to Propose

Always propose these four views. Add extras for any focused concern worth isolating.

```
view index {
  title "[system] — System Overview"
  include *                          // all elements, components nested inside services
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
