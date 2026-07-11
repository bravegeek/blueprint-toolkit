# Quickstart

## Prerequisites

```bash
# Node 20+
node --version   # must be >= 20
```

You don't need to install the LikeC4 CLI yourself — `blueprint/bin/likec4` (installed below) runs it via `npx` with a pinned, known-good version, and no other setup.

You also need an agent that reads `AGENTS.md` — Claude Code, Cursor, opencode, Amp, or any compatible tool. Add whatever config file your tool needs (e.g. `CLAUDE.md`) pointing at `AGENTS.md`.

## Setup

**1. Install the toolkit into your project:**

```bash
./install.sh /path/to/your-project [project-name]
```

The script copies everything below into the target, sets the project name in `.likec4rc` (prompting if you didn't pass one), and never overwrites existing files — re-running is safe.

```
your-project/
├── src/                  ← your code
├── blueprint/
│   ├── model/
│   │   ├── system.c4
│   │   ├── views.c4
│   │   └── .likec4rc
│   └── bin/
│       └── likec4        ← always run LikeC4 through this, not a bare `likec4`
├── skills/
│   ├── assessment/
│   └── blueprint-change/
├── AGENTS.md
└── .mcp.json
```

**2.** (Manual install only) Copy the tree above yourself, set `name` in `blueprint/model/.likec4rc`, and `chmod +x blueprint/bin/likec4`.

**3. Preview the empty model:**

```bash
cd blueprint/model && ../bin/likec4 serve
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
3. Review the diagram (blueprint/bin/likec4 serve is already running)
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

- `blueprint/bin/likec4 serve` watches for file changes — leave it running while you work.
- Always run LikeC4 via `blueprint/bin/likec4`, not a bare `likec4`/`npx likec4` — see the comments in that script for why (an AI-chat auto-enable footgun and a vite dependency pre-bundling bug in newer patch versions).
- The MCP server (`.mcp.json`) lets agents query the model without reading files directly.
