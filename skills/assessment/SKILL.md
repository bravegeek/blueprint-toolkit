# Assessment Skill

Read the actual system state in four passes, propose a LikeC4 model with confidence-tiered elements, and confirm with the developer before committing anything.

## Invocation

```
/assessment [path]
```

`path` defaults to `../` (sibling directory). Pass any local path to assess a different target.

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

**Output of Pass 3:** `{ module_edges, table_reads, table_writes, pipeline_dag, pipeline_confidence }`.

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

Group by tier. AMBIGUOUS items are commented stubs with explicit questions.

```
// ── STRUCTURAL (auto-stageable) ──────────────────────────────────
softwareSystem acme "Acme Platform" {
  container db "PostgreSQL" "Stores pricing records" {
    technology "PostgreSQL 15"
  }
  container ingest_bucket "S3: raw-manifests" {
    technology "S3"
  }
}

// ── PROVABLE (auto-stageable) ─────────────────────────────────────
// ingestor imports boto3 and references 'raw-manifests' bucket by name
relationship ingestor -> ingest_bucket "reads raw manifests from"

// ── INFERRED (confirm before staging) ────────────────────────────
// confidence: 0.75 — directory named 'transform/' imports from 'ingest/'
// suggesting downstream processing. Confirm: is transform/ a separate service
// or part of the same process?
container transformer "Transform Service" {
  ...
}

// ── AMBIGUOUS (needs your input) ─────────────────────────────────
// Q: What is the data classification for the records table?
// Q: Who owns the api container?
// Q: Is there a user-facing API, or is this pipeline internal-only?
```

### Pipeline View

If a pipeline DAG was found or inferred, propose a dedicated LikeC4 view:

```
view pipeline_flow {
  title "Data Pipeline — [stage count] stages"
  include ingestor, transformer, loader, db, ingest_bucket
  // stage ordering derived from [orchestrator type / import graph]
}
```

---

## Confirm

Present the proposed `.c4` and ask only about INFERRED and AMBIGUOUS items:

1. **INFERRED check** — list each inferred relationship with its evidence. "We inferred X because Y — is that right?"
2. **Gap check** — "What does this miss that the code doesn't make visible?" (business logic, external integrations, user actors)
3. **Metadata** — "What `owner`, `dataClassification`, and `auth` values should be added?"

When the developer confirms, commit as a spec entry following the intent log convention in `constitution.md`.
