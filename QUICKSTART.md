# Quickstart

## Prerequisites

```bash
# Node 20+
node --version   # must be >= 20

# LikeC4 CLI
npm install -g likec4
likec4 --version
```

You also need an agent that reads `AGENTS.md` — Claude Code, Cursor, opencode, Amp, or any compatible tool. Add whatever config file your tool needs (e.g. `CLAUDE.md`) pointing at `AGENTS.md`.

## Setup

**1. Copy this toolkit into your project:**

```
your-project/
├── src/                  ← your code
├── blueprint/            ← paste here
│   └── model/
│       ├── system.c4
│       ├── views.c4
│       └── .likec4rc
├── skills/               ← paste here
│   ├── assessment/
│   └── blueprint-change/
├── AGENTS.md             ← paste here
└── .mcp.json             ← paste here
```

**2. Update `blueprint/model/.likec4rc`** — set `name` to something meaningful for your project.

**3. Preview the empty model:**

```bash
cd blueprint/model && likec4 serve
```

Open the URL it prints. An empty diagram means it's working.

## Bootstrap: model an existing system

Run the assessment skill from your project root:

```
/assessment .
```

The skill reads your system in four passes (file layout → schema/storage → module graph → synthesis) and proposes a `.c4` model with every element confidence-tiered. Review the proposed output, then commit the confirmed model.

> **Stack-specific probes:** the assessment skill ships with Python/Postgres/S3 probe examples. The `## Pass 2` and `## Pass 3` sections in `skills/assessment/SKILL.md` are annotated — adapt the probe code to your stack before running.

## Standard Assessment Layers

| Layer | What it captures | Probe patterns |
|-------|-----------------|----------------|
| **Interface** | How the outside talks to the system | CLI entry points, web server routes, scrape targets |
| **Application** | Business logic that runs | Services, scripts, pipelines, workers |
| **Data** | What the system persists | DB tables, object storage buckets, queues, migrations |
| **Integration** | External systems depended on | HTTP clients, API keys, import analysis |
| **Infrastructure** | How everything runs | Docker Compose services, env config, Makefile |

## The Loop

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
4. Commit the approved .c4 diff
      ↓
5. Implement
```

**No code before step 3 approval.**

## Greenfield (no running system yet)

Skip `/assessment`. Run `/blueprint-change` with a description of the system. The skill authors model elements from the description and marks anything unverified. Once you build the system, run `/assessment` to ground-truth the model.

## Tips

- `likec4 serve` watches for file changes — leave it running while you work.
- The MCP server (`.mcp.json`) lets agents query the model without reading files directly.
