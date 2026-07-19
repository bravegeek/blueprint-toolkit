# Stack Probes: Node/TypeScript + Docker Compose

Worked examples for the Infrastructure pass's Container/Service Topology step and the Code pass's TS-specific discovery, for a Node-based stack running under Docker Compose.

## Container / service topology (Docker Compose)

Language-neutral — read with whatever's convenient; the example below uses Python only because PyYAML is a common one-liner, not because the target stack is Python:

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

Equivalent in Node without a YAML parser present, using `docker compose config --format json` (Compose itself resolves the YAML):

```bash
docker compose -f TARGET_PATH/docker-compose.yml config --format json
```

`depends_on` → PROVABLE dependency edges. Exposed ports → STRUCTURAL API surface. Image/build context → STRUCTURAL technology metadata.

If no `docker-compose.yml` exists, look for `kubernetes/`, `helm/`, `fly.toml`, `render.yaml`, `railway.toml`, or `Procfile` for topology signals.

## Database access (Node)

- `pg` / `postgres.js` clients → connection strings in env; table names appear in raw SQL strings (`FROM`, `INSERT INTO`) exactly as in the Python case — same regex approach applies to `.ts`/`.js` source.
- Prisma → read `schema.prisma` directly for models/relations (STRUCTURAL, no query needed).
- Drizzle → read the schema module (`schema.ts` or similar) for table definitions (STRUCTURAL).

Confidence: schema-file-derived tables/columns = STRUCTURAL. Table *purpose* = AMBIGUOUS.

## Object storage (Node)

`@aws-sdk/client-s3` (`ListBucketsCommand`, `ListObjectsV2Command`) — same shape as the Python boto3 probe: bucket existence is STRUCTURAL, prefix-inferred purpose is INFERRED.

## Module graph, contracts, orchestration (TypeScript)

Covered in full in [extraction-format.md](../extraction-format.md) — the TypeScript/JavaScript section there is this stack's Module graph and Extraction-step guidance; nothing Node-specific beyond the Docker/DB/storage probes above.

**BullMQ / queue-based orchestration** (Node): `grep -rn "new Worker\|new Queue\|processor" TARGET_PATH --include="*.ts" --include="*.js"`
