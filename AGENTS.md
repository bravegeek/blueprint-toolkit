# Blueprint Toolkit — Agent Instructions

## What This Is

A blueprint layer that sits between a ticket and the code. Before any code is written, an AI generates a structural diagram (`.c4` diff) of the proposed change. The human reviews the diagram, not the code. If it's wrong, the fix is a conversation.

Two repos, same parent directory:
- **`blueprint-toolkit/`** — this repo: skills, model scaffold, constitution, OpenSpec config
- **`<your-system>/`** — sibling: the actual system being modeled

## Skills

All skills live at `skills/<name>/SKILL.md`. Invoke them by name.

| Skill | Invocation | When to use |
|-------|-----------|-------------|
| `assessment` | `/assessment [path]` | Bootstrap a model from a running system. Reads the system's actual artifacts (schema, storage, compose) — never infers. Defaults to `../` (sibling directory). |
| `blueprint-change` | `/blueprint-change [description]` | Turn a ticket into EARS requirements + a proposed `.c4` diff. Human reviews the diagram before any code is written. |
| `openspec-propose` | `/openspec-propose` | Scaffold `proposal.md`, `design.md`, and `tasks.md` for an approved change. |
| `openspec-apply` | `/openspec-apply` | Implement tasks from an OpenSpec change. |
| `openspec-archive` | `/openspec-archive` | Archive a completed change. |
| `openspec-explore` | `/openspec-explore` | Thinking-partner mode — explore ideas before committing to a change. |

## The Change Loop

```
Ticket
  → /blueprint-change       # load model, write EARS, emit .c4 diff
  → human reviews diagram   # approve or correct via conversation
  → human commits .c4 diff  # spec entry (see constitution.md)
  → /openspec-propose       # scaffold proposal + design + tasks
  → implement + test
  → build entry committed   # with spec-ref
```

**No code before the diagram is approved.** This is the invariant the whole workflow depends on.

## Model Access

The LikeC4 model in `model/` is queryable via MCP (configured in `.mcp.json`). Use it read-only. Never write `.c4` files through MCP — all model changes are proposed via `blueprint-change` and committed as spec entries per the intent-log convention in `constitution.md`.

## Intent Log Convention

See `constitution.md` for the full spec entry / build entry / merge entry format. Short version:

```
decision: <what was decided>

---
decisions:
  - <key decision and why>
assumptions:
  - <unverified assumption>
---
```

Every `.c4` change is a spec entry. Spec entries are append-only — never amend or rebase.

## OpenSpec Config

`openspec/config.yaml` — update the `context:` field with your stack description before generating artifacts. EARS notation is mandatory for all specs.

## Key Files

| Path | What it is |
|------|-----------|
| `model/system.c4` | Element specification + model (start empty, fill via `/assessment`) |
| `model/views.c4` | LikeC4 view definitions |
| `model/.likec4rc` | LikeC4 project config (update `name`) |
| `constitution.md` | Intent-log convention, blueprint diff convention |
| `openspec/config.yaml` | OpenSpec project context and EARS rules |
| `.mcp.json` | LikeC4 MCP server config (read-only) |
