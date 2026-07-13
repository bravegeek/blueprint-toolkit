# Blueprint Toolkit

A tool that generates a structural diagram (LikeC4) of a proposed change *before* any code is written. The human reviews the diagram, not the code. If the structure is wrong, the fix is a conversation. Distributed as a set of skills installed into a target project via `install.sh`.

## Agent-Agnostic Architecture

**This toolkit is agent-agnostic. The canonical, authoritative form of every skill is a plain, vendor-neutral file — never a specific agent's copy.**

- **Source of truth:** skills live at top-level `skills/<name>/SKILL.md`, alongside any supporting scripts (e.g. `skills/assessment/*.mjs`). The agent-agnostic entry point is `AGENTS.md`. Both are readable by any agent (Claude, Gemini, Codex, …) and by a human.
- **Per-agent files are thin wrappers only.** Anything under a vendor directory — `.claude/`, `.gemini/`, `.codex/`, etc. — must be a *thin wrapper* (a symlink, or a stub that defers) pointing at the agent-agnostic `skills/<name>/` directory. It never holds an independent copy of a SKILL.md or a supporting script, and it is never the source of truth.
- **Why:** real copies drift. A vendor dir that holds its own SKILL.md silently goes stale while the canonical one moves forward, and a wrapper that copies only `SKILL.md` leaves the skill's supporting scripts behind. Both failure modes have already happened (see below). A symlink to the whole `skills/<name>/` directory can neither go stale nor lose files.
- **Rule of thumb:** if you find yourself editing a file under `.claude/` (or any vendor dir), stop — edit the agent-agnostic file under `skills/`/`AGENTS.md` and make the vendor path point at it.

### Consequence for installation

`install.sh` must place the *whole* `skills/<name>/` directory (SKILL.md **and** every supporting file) wherever the target agent discovers skills, and it must keep vendor-specific discovery paths as wrappers around that one canonical copy — not as parallel independent copies. When adding a supporting file to a skill, no install-list edit should be required for it to reach the target: the installer copies directory contents, not an enumerated file list.

> Known drift this principle exists to prevent: a target project once had `.claude/skills/assessment/` holding a *stale real copy* of `SKILL.md` and **none** of the `*.mjs` extractors, while the agent-agnostic `skills/assessment/` symlinked only `SKILL.md`. The agent loaded the stale vendor copy, ran LLM-only extraction, and missed everything the `tsserver` and `llm-nextjs` sources were built to capture.

## Skills

| Skill | Invocation | Purpose |
|-------|-----------|---------|
| `assessment` | `/assessment [path]` | Read a running system's artifacts, extract structure (multi-source: `tsserver` + `llm-nextjs` + `llm-assessment`, unioned over disjoint fact sets), propose an initial `.c4` model. Never infers — only reads what exists. |
| `blueprint-change` | `/blueprint-change [desc]` | Ticket/description → EARS requirements → proposed `.c4` diff. Human reviews the rendered diagram before any code is written. |
| `guided-brainstorm` | `/guided-brainstorm` | Structured brainstorming (Situation → Advisor → Conversation → Plan). |

## Binding Principles

1. **Diagram before code** — no code is written until the human approves the rendered `.c4` diagram.
2. **Never write `.c4` directly** — all model changes go through `/blueprint-change` so the human reviews the diagram first.
3. **Agent-agnostic first** — the canonical skill is vendor-neutral; per-agent files are thin wrappers (see above).
4. **Assessment reads, never infers** — `/assessment` derives elements from the current codebase only, from scratch each run. It does not reuse prior assessments or `blueprint/.backup/` as source material.
5. **One validation point** — no `likec4 validate` against scratch files mid-pass; validate once, against the real target files, after Pass 4.
6. **Confidence is explicit** — `#provable` (certain from code artifacts), `#inferred` (LLM pattern-match), no tag (developer-confirmed).

## Key Files

| Path | What it is |
|------|-----------|
| `AGENTS.md` | Agent-agnostic instructions and LikeC4 syntax reference — the entry point for any agent. |
| `install.sh` | Installs the toolkit into a target project. Copies whole skill directories; keeps model files (`system.c4`/`views.c4`/`.likec4rc`) protected. |
| `skills/<name>/` | Canonical, agent-agnostic skill directories (SKILL.md + supporting scripts). |
| `blueprint/model/system.c4` | Element specification (architecture + code-level kinds) + model. |
| `blueprint/model/views.c4` | LikeC4 view definitions. |
| `blueprint/bin/likec4` | Wrapper CLI — always use this, never a bare `likec4`/`npx likec4`. |
