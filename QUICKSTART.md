# Quickstart

## Prerequisites

```bash
# Node 20+
node --version   # must be >= 20

# LikeC4 CLI
npm install -g likec4
likec4 --version

# OpenSpec CLI
npm install -g openspec
openspec --version
```

You also need an agent that reads `AGENTS.md` — Claude Code, Cursor, opencode, Amp, or any compatible tool.

## Setup

**1. Clone the toolkit next to your system:**

```
parent-dir/
├── blueprint-toolkit/    ← this repo
└── your-system/          ← the system to blueprint
```

**2. Update `model/.likec4rc`** — set `name` to something meaningful for your project.

**3. Update `openspec/config.yaml`** — replace the placeholder in `context:` with your actual stack (language, database, infrastructure).

**4. Preview the empty model:**

```bash
cd model && likec4 serve
```

Open the URL it prints. You should see an empty diagram — that's correct.

## Bootstrap: model an existing system

Run the assessment skill against your system:

```
/assessment ../your-system
```

The skill reads the running system in four passes (file layout → schema/storage → module graph → synthesis) and proposes a `.c4` model with every element confidence-tiered. You review INFERRED and AMBIGUOUS items, then commit the confirmed model as the first spec entry:

```
decision: initial model derived from system assessment — confirmed accurate as of YYYY-MM-DD
```

> **Stack-specific probes:** the assessment skill ships with Python/Postgres/S3 probe examples. The `## Pass 2` and `## Pass 3` sections in `skills/assessment/SKILL.md` are annotated — adapt the probe code to your database, object storage, and language before running.

## Standard Assessment Layers

The assessment skill maps your system into these layers:

| Layer | What it captures | Probe patterns |
|-------|-----------------|----------------|
| **Interface** | How the outside talks to the system | CLI entry points, web server routes, scrape targets |
| **Application** | Business logic that runs | Services, scripts, pipelines, workers |
| **Data** | What the system persists | DB tables, object storage buckets + prefixes, queues, migrations |
| **Integration** | External systems depended on | HTTP clients, API keys, import analysis |
| **Infrastructure** | How everything runs | Docker Compose services, env config, Makefile, CI |

## The Change Loop

Once you have a model, every change follows this loop:

```
1. Ticket or intent
      ↓
2. /blueprint-change <description>
      AI loads model → writes EARS requirements → proposes .c4 diff
      ↓
3. Review the diagram (likec4 serve is already running)
      Approve → continue   |   Correct → revise in conversation
      ↓
4. Commit the approved .c4 diff as a spec entry
      git add model/ && git commit
      (message format: see constitution.md)
      ↓
5. /openspec-propose
      Scaffolds proposal.md + design.md + tasks.md
      ↓
6. Implement + test
      ↓
7. Commit build entry
      build: <what was built>
      spec-ref: <git ref of step 4 commit>
```

**No code is generated before step 3 approval.** This is the invariant.

## Greenfield (no running system yet)

Skip `/assessment`. Run `/blueprint-change` with the system description as input. The skill authors model elements from the ticket and marks anything unverified as `[unverified — confirm before committing]`. Once you build the system, run `/assessment` to ground-truth the model.

## Tips

- `likec4 serve` watches for file changes — leave it running while you work.
- The MCP server (`.mcp.json`) lets agents query the model. Start it with `likec4 mcp --workspace model/`.
- Spec entries are append-only — never amend or rebase `model/*.c4` commits.
- `openspec-explore` is useful before `/blueprint-change` when the intent isn't clear yet.
