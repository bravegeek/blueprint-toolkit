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

## The One Rule

Never write `.c4` files directly. All model changes go through `/blueprint-change` so the human sees the diagram before anything is implemented.
