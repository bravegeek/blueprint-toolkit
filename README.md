# Blueprint Toolkit

A blueprint layer that sits between a ticket and the code.

## The Idea

Before any code is written, an AI generates a structural diagram of the proposed change. The human reviews the diagram, not the code. If it's wrong, the fix is a conversation — not a revert.

```
ticket → EARS requirements → .c4 diff → human reviews diagram → code
```

The model lives in `model/*.c4` (LikeC4). Every model change is committed as a spec entry with a decision record. The git log is the intent log.

## Structure

```
blueprint-toolkit/
├── skills/                    # Agent skills (tool-neutral)
│   ├── assessment/            #   Read system → propose .c4 model
│   ├── blueprint-change/      #   Ticket → EARS → .c4 diff → review gate
│   ├── openspec-propose/      #   Scaffold proposal + design + tasks
│   ├── openspec-apply/        #   Implement tasks
│   ├── openspec-archive/      #   Archive completed changes
│   └── openspec-explore/      #   Thinking-partner / exploration mode
├── model/
│   ├── system.c4              #   Specification block + model (fill via /assessment)
│   ├── views.c4               #   View definitions
│   └── .likec4rc              #   LikeC4 project config
├── openspec/
│   └── config.yaml            #   OpenSpec project context + EARS rules
├── AGENTS.md                  #   Skill registry + workflow (all agents read this)
├── constitution.md            #   Intent-log convention + blueprint diff convention
├── .mcp.json                  #   LikeC4 MCP server (read-only model query)
└── QUICKSTART.md              #   Start here
```

## How It Works

**Two repos, same parent directory:**
- `blueprint-toolkit/` — this repo: the engine
- `<your-system>/` — sibling: the system being modeled

The assessment skill reads the sibling by default (`/assessment ../your-system`).

## Key Principles

1. **Model is derived, not authored.** The assessment skill reads the running system. The developer confirms. The model is never updated without ground truth verification.
2. **No code before diagram approval.** The blueprint-change skill proposes a `.c4` diff. The human approves the rendered diagram first.
3. **The git log is the intent log.** Every `.c4` change is a spec entry with a decision record. Spec entries are append-only.
4. **MCP is read-only.** Agents query the model via `likec4 mcp`. They never write `.c4` files through MCP.
