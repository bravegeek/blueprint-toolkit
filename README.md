# Blueprint Toolkit

A tool that generates a structural diagram of a proposed change before any code is written. The human reviews the diagram, not the code.

## The Idea

```
ticket → EARS requirements → .c4 diff → human reviews diagram → code
```

Catching a wrong structure in a diagram takes a conversation. Catching it in code takes a revert, a review, and a re-implementation.

## What's In Here

```
blueprint-toolkit/
├── skills/
│   ├── assessment/        # Read system → propose .c4 model
│   └── blueprint-change/  # Ticket → EARS → .c4 diff → review gate
├── blueprint/
│   ├── model/
│   │   ├── system.c4      # Element specification + model
│   │   ├── views.c4       # View definitions
│   │   └── .likec4rc      # LikeC4 project config
│   └── bin/
│       └── likec4         # Wrapper: run this instead of `likec4` directly
├── AGENTS.md              # What agents read
├── .mcp.json              # LikeC4 MCP (read-only)
├── install.sh             # Copies the above into your project
└── QUICKSTART.md
```

## How To Use It

```bash
./install.sh /path/to/your-project
```

Then point it at your code. See `QUICKSTART.md`.

To reset `system.c4`/`views.c4` back to blank templates and re-run `/assessment` from scratch (backing up the current model first), use `./install.sh --clean /path/to/your-project`.

## The One Rule

Never write `.c4` files directly. All model changes go through `/blueprint-change` so the human sees the diagram before anything is implemented.

## Code-Level Modeling

The toolkit models systems at two altitudes:

- **Architecture level (C4 level 2):** services, datastores, queues, external systems.
- **Code level:** exported classes (components) and typed interfaces crossing module boundaries (contracts) *within* each service.

Code-level elements use `sourceLocation` metadata (`file#Symbol`) to map back to code. The `/assessment` skill extracts components and contracts in four passes, defaulting LLM-derived entries to INFERRED and requiring quoted evidence for PROVABLE. Proposed changes via `/blueprint-change` include a code-level diff when they add or modify components or contracts.

**Scope:** only exported/public classes and cross-module contracts. Private helpers are permanently out of scope. This keeps the model size tractable and focused on structural integrity.
