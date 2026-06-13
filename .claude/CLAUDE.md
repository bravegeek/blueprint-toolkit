# Claude Code — Blueprint Toolkit

Read `AGENTS.md` first. Everything about the workflow, skills, and conventions is there.

## Claude-specific notes

- Skills are at `skills/<name>/SKILL.md`. Claude Code does not auto-discover these — invoke them by name (e.g. `/assessment`, `/blueprint-change`).
- The LikeC4 MCP server is configured in `.mcp.json`. Use it read-only to query the model. Never write `.c4` files via MCP.
- When the user mentions specs, proposals, tasks, or changes, load the relevant `openspec-*` skill before proceeding.
- Commit convention: see `constitution.md`. Spec entries are append-only — never amend.
