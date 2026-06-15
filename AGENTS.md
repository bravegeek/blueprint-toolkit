# Blueprint Toolkit — Agent Instructions

## What This Is

A tool that generates a structural diagram of a proposed change before any code is written. The human reviews the diagram, not the code. If the structure is wrong, the fix is a conversation.

## Skills

All skills live at `skills/<name>/SKILL.md`. Invoke them by name.

| Skill | Invocation | When to use |
|-------|-----------|-------------|
| `assessment` | `/assessment [path]` | Read a running system's artifacts and propose an initial `.c4` model. Pass the path to the system (e.g. `/assessment .` from the project root). Never infers — only reads what exists. |
| `blueprint-change` | `/blueprint-change [description]` | Turn a ticket or description into EARS requirements and a proposed `.c4` diff. Human reviews the rendered diagram before any code is written. |

## The Loop

```
describe the change or ticket
  → /blueprint-change        # EARS requirements + proposed .c4 diff
  → human reviews diagram    # approve or correct via conversation
  → commit the .c4 diff
  → implement
```

**No code before the diagram is approved.**

## One Rule

Never write `.c4` files directly. All model changes go through `/blueprint-change` so the human reviews the rendered diagram first.

## Key Files

| Path | What it is |
|------|-----------|
| `blueprint/model/system.c4` | Element specification + model |
| `blueprint/model/views.c4` | LikeC4 view definitions |
| `blueprint/model/.likec4rc` | LikeC4 project config |
| `.mcp.json` | LikeC4 MCP server — read-only model query |
