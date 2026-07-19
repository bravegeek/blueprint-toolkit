# Stack Probes: Python + PostgreSQL + S3

Worked examples for the Infrastructure pass's Database Schema and Object Storage steps. Adapt to your actual database/storage technology — see the notes under each probe.

## Database schema (PostgreSQL + PostGIS, via SQLAlchemy)

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
-- PostGIS geometry detail (run only if PostGIS detected in Census)
SELECT f_table_schema, f_table_name, f_geometry_column, type, srid
FROM geometry_columns
ORDER BY f_table_schema, f_table_name;
```

Confidence: tables / columns / FKs = STRUCTURAL. Table *purpose* = AMBIGUOUS.

## Object storage (S3-compatible)

> The example below targets S3-compatible storage (AWS S3 or local S3-compatible like MinIO). For GCS → use `google-cloud-storage`; for Azure Blob → use `azure-storage-blob`; skip if no object storage.

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

## Module graph (Python)

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
- Route decorators (FastAPI `@app.get`, etc.) → STRUCTURAL API surface

## Orchestration signatures (Python)

**Prefect** (`@flow`, `@task`): `grep -rn "@flow\|@task" TARGET_PATH --include="*.py"`
**Airflow** (DAGs, `>>`): `grep -rn "DAG\|>>" TARGET_PATH --include="*.py"`
**Celery** (`@app.task`, `.delay()`, `.apply_async()`): `grep -rn "@app\.task\|@shared_task\|\.delay(\|\.apply_async(" TARGET_PATH --include="*.py"`
**Temporal**: `grep -rn "@workflow.defn\|@activity.defn" TARGET_PATH --include="*.py"`
**Makefile** (phony targets): `grep -E "^[a-zA-Z_-]+:" TARGET_PATH/Makefile`

**Fallback — import graph ordering** (no orchestrator, no schedule): if module A imports module B, A is downstream of B. Derive a soft DAG from import depth. Confidence = INFERRED.
