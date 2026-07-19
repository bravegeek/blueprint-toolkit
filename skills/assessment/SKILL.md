# Assessment Skill

Read the actual system state in four passes, propose a LikeC4 model with confidence-tiered elements, and confirm with the developer before committing anything.

## Invocation

```
/assessment [path]
```

`path` defaults to `.` (project root). Pass any local path to assess a different target.

**Every run is fresh from the codebase.** No reuse of prior assessments, backups, or extraction caches. If you want to restore an old model, use `blueprint/.backup/` manually — never as assessment source material.

## Operating Rules

- **One validation point.** No `likec4 validate` (or `serve`/`build`) against any scratch file, test snippet, or partial draft during Census/Infrastructure/Code. Validate exactly once: after Model writes the real target files (`blueprint/model/system.c4` / `views.c4`), run `likec4 validate` against that real path. Fix in place and re-validate if it fails. Never a scratch `.c4` file, never a heredoc, at any point in this skill.
- **PROVABLE facts are never curated out** — see [reference/confidence-tiers.md](reference/confidence-tiers.md) for the full tier table and this rule's one canonical statement.
- **Domain rules are elicited, never inferred** — see [reference/domain-rules.md](reference/domain-rules.md).
- **Every question to the developer follows the disambiguation-clarity bar** — see [reference/disambiguation.md](reference/disambiguation.md).
- Do not execute application code, guess business logic, or assign `dataClassification`/`auth` without developer confirmation (always AMBIGUOUS).

Syntax questions get answered by reading, not by running anything: `blueprint/model/system.c4`, `blueprint/model/views.c4`, and the worked examples in `skills/*/SKILL.md`. If those don't answer it, check `AGENTS.md`'s LikeC4 Syntax Quick Reference. If still unanswered, make your best-effort attempt in the real proposed diff and let the single end-of-Model validation catch it.

## The Four Passes

```
Census         →  what exists, where it lives, what's running
Infrastructure →  schema, storage, API surface
Code           →  module graph, orchestration, extraction
Model          →  merge all passes, assign tiers, propose .c4
```

Each pass builds on findings from the previous. Stop a pass early and record what's missing rather than guessing. After the four passes: **Confirm** — present only INFERRED and AMBIGUOUS items to the developer.

---

## Census

**Input:** `TARGET_PATH` (the path argument, default `.`).

**Run:**

```bash
bash skills/assessment/scan.sh TARGET_PATH 1
```

One call, not ad-hoc `find`/`grep`. Emits `FILE_INVENTORY`, `STACK_SIGNALS`, `SERVICE_ROOTS`, `ORCHESTRATOR`, and `FRAMEWORK` sections. Read-only, executes no application code. It surfaces **candidates and signals**, never final facts — read the files it points at to confirm. Only drop to a raw one-off `find`/`grep` for something the scanner doesn't cover, and keep it on one line (escaped parens plus line-continuations can trip a permission parser).

From the output, determine:
- **Service count** — multiple `main.py`/`app.py`/`index.ts`/`main.go` at different directory levels = multiple services (STRUCTURAL)
- **Pipeline shape** — directory names like `ingest/`, `process/`, `transform/`, `export/`, `load/` (INFERRED)
- **Stack identity** — `docker-compose.yml`, `pyproject.toml`, `package.json`, `go.mod`, `Cargo.toml`, `Makefile`, `Procfile`
- **Orchestrator presence** — gates what the Code pass's Orchestration step looks for

**Output:** `{ service_roots, pipeline_dirs, stack_signals, orchestrator_type }`.

**Done-when:** every section of the scanner output has been read and the four fields above are populated (a field may be empty/none — that's a valid, recorded answer, not a skipped step).

---

## Infrastructure

**Input:** `TARGET_PATH`, `stack_signals` from Census.

**Run:** all three sub-steps below. Each is independent and can fail without blocking the others. Probe code is stack-specific — worked examples for Python/PostgreSQL/S3 and Node/Docker are in [reference/stack-probes/](reference/stack-probes/); adapt to the actual stack detected in Census.

1. **Database schema** — introspect the schema (tables, columns, FKs, indexes). Confidence: structure = STRUCTURAL, table *purpose* = AMBIGUOUS.
2. **Object storage** — enumerate buckets and top-level key prefixes, if any storage is detected. Confidence: bucket exists = STRUCTURAL, purpose from prefixes = INFERRED.
3. **Container/service topology** — read `docker-compose.yml` (or `kubernetes/`, `helm/`, `fly.toml`, `render.yaml`, `railway.toml`, `Procfile` if absent). `depends_on` → PROVABLE dependency edges; exposed ports → STRUCTURAL API surface; image/build → STRUCTURAL technology metadata.

**Output:** `{ tables, foreign_keys, geometry_columns, buckets, bucket_prefixes, services, service_deps }`.

**Done-when:** all three sub-steps have been attempted and their results (including failures/absences) are recorded in the output map.

---

## Code

**Input:** `TARGET_PATH`, `service_roots` and `orchestrator_type` from Census.

**Run:** get this pass's discovery signals from the scanner in one call:

```bash
bash skills/assessment/scan.sh TARGET_PATH 3
```

Its sections map onto the sub-steps below: `PY_COMPONENTS`/`TS_EXPORTS` → component candidates, `PY_CONTRACTS`/`TS_CONTRACTS` → contract candidates, `TS_IMPORTS` → cross-module import evidence, `REDUCER_SHAPE` → the reducer/command recipe gate, `SPEC_CONTRACTS` → spec-layer detection. The `ORCHESTRATOR` section from Census covers Orchestration below. Read the candidate lines the scanner returns, open the files, and confirm — the scanner finds, it does not decide.

### Module graph

Language-specific extraction rules (what counts as a component/contract, per-language candidate scans) are in [reference/extraction-format.md](reference/extraction-format.md#language-specific-extraction-rules). For each source file: intra-project imports → PROVABLE edges; ORM/table definitions → STRUCTURAL link to schema; SQL read/write patterns → PROVABLE table relationships; route decorators → STRUCTURAL API surface.

### Orchestration

Run only for the orchestrator type Census detected; fall through to import-graph ordering (INFERRED soft DAG) if none was detected. Orchestrator-specific signatures (Prefect/Airflow/Celery/BullMQ/Temporal/Makefile) are in [reference/stack-probes/](reference/stack-probes/).

### Extraction

**Goal:** produce the code-level extraction JSON defined in [reference/extraction-format.md](reference/extraction-format.md) — the format that decouples *how structure is discovered* from *how it is modeled*. Multiple sources run and are **unioned** (AND, not OR — never a fallback):

```bash
# Always run the LLM baseline (no script — you read the code per the language-specific
# rules in reference/extraction-format.md and author its findings as source: "llm-assessment").

# If TARGET_PATH/tsconfig.json is present, run the deterministic TypeScript extractor:
node skills/assessment/extractors/tsserver-extractor.mjs TARGET_PATH > _extraction_tsserver.json

# If Census's FRAMEWORK section detected Next.js, run the framework recipe:
node skills/assessment/extractors/nextjs-recipe-extractor.mjs TARGET_PATH > _extraction_nextjs.json

# Union every source that actually ran (2 or more files; list only the ones present):
node skills/assessment/extractors/union-extraction.mjs _extraction_llm-assessment.json _extraction_tsserver.json _extraction_nextjs.json > _extraction_union.json
```

If a discriminated-union + reducer-dispatch shape is detected (`REDUCER_SHAPE` scanner section), also run the reducer/command recipe (`source: "llm-reducer"`, no separate script — author it per [reference/extraction-format.md](reference/extraction-format.md#reducer--command-discovery-llm-reducer-when-a-discriminated-union--reducer-shape-is-detected)) and include its output file in the union command above.

**Never silently degrade to LLM-only.** If `tsconfig.json` is present, `tsserver-extractor.mjs` MUST run and its output MUST be in the union — do not complete the Extraction step on `llm-assessment` alone when a deterministic source's preconditions hold. Same for the Next.js recipe when Next.js is detected.

Spec-layer contracts (`specs/*/contracts/` directories, from the scanner's `SPEC_CONTRACTS` section) are conditional — include if found, don't fail if absent; deferred to Model for emission.

**Output of Code:** `{ module_edges, table_reads, table_writes, pipeline_dag, pipeline_confidence, codeLevelExtraction, specLayerExtraction? }`, where `codeLevelExtraction` is the unioned document from `_extraction_union.json` — **the union, never a single source** — and is what Model consumes.

**Done-when:** the union file has been produced from every source whose preconditions held (at minimum `llm-assessment`), and Model reads only that unioned document.

---

## Model

**Input:** Census + Infrastructure outputs, and Code's unioned `codeLevelExtraction`.

**Run:** merge all pass outputs into a proposed `.c4` diff grouped by confidence tier. For code-level elements, apply the synthesis algorithm in [reference/extraction-format.md](reference/extraction-format.md#model-synthesis-from-the-extraction-format) (reconcile by `sourceLocation`, match, nest under services, tag confidence, attach metadata, filter on cross-module evidence).

Architecture-level cross-validation (promote INFERRED → PROVABLE when corroborated):

| Finding | If also supported by | Promote to |
|---------|---------------------|------------|
| INFERRED bucket purpose | Prefix pattern + module that references that bucket name | PROVABLE |
| INFERRED pipeline stage | Import graph ordering agrees with orchestrator DAG | PROVABLE |
| INFERRED service boundary | `depends_on` in compose + module import confirms direction | PROVABLE |

Group proposed elements by tier (STRUCTURAL/PROVABLE auto-stageable; INFERRED needs confirmation; AMBIGUOUS is commented stubs with explicit questions). The specification block must declare all element kinds used (`component`, `contract`, `spec` are unconditional in the base `system.c4`).

**Spec-layer elements** (conditional on `specs/*/contracts/` detection in Code): emit one `spec` element per detected module, nested under `contractSpecs`, linked to its governed service with `defines`.

**Views to propose** — always: `index` (system overview, top-level + one level of children, `exclude rule`), `context` (system as opaque box), `services` (services only, no components, `exclude rule`), `pipeline` (orchestration wiring). Also propose: `codeStructure_<service>` per service with components (`include <service>.**`; keep `command` elements out of the four architecture views above — `exclude command` there if a broad `include` would pull them in); `contracts` if contracts were found; `domainRules` (`include rule` + `include rule -> *`) if any `rule` elements were elicited — the only view that shows rules; `specLayer` + per-spec blast-radius views if spec contracts were found.

**Done-when:** the complete diff is written into the real target files and `likec4 validate` passes against them (the skill's one validation point).

---

## Confirm

Present the proposed `.c4` and ask only about INFERRED and AMBIGUOUS items, following [reference/disambiguation.md](reference/disambiguation.md) for every question.

**The checks:**
1. **INFERRED check** — list each inferred relationship with its evidence: "We inferred X because Y — is that right? (Yes keeps the edge; No removes it.)"
2. **Rule slots** — present each candidate domain-rule slot per [reference/domain-rules.md](reference/domain-rules.md); capture confirmed rules as `rule` elements, verbatim in intent, tagless, linked via `governs`.
3. **Gap check** — "What does this miss that the code doesn't make visible?" (business logic, external integrations, user actors)
4. **Metadata** — "What `owner`, `dataClassification`, and `auth` values should be added, and to which elements?"

When the developer confirms, commit the `.c4` model.
