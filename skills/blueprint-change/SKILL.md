# Blueprint Change Skill

Given a ticket or change description, produce EARS requirements and a proposed `.c4` diff for human review. **No code is generated until the developer approves the diagram.**

## Invocation

```
/blueprint-change [description or ticket reference]
```

---

## The Core Act

The blueprint layer exists so a human reviews a *diagram*, not code. This skill encodes steps 2–4 of the change loop:

```
ticket / description
  → load current model (via MCP or by reading model/*.c4)
  → EARS requirements
  → proposed .c4 diff
  → human reviews the rendered diagram
  → approve or correct via conversation
```

If the developer approves: they commit the `.c4` diff and implement.
If the developer corrects: revise the EARS and diff in conversation, repeat.

---

## Steps

### 1 — Understand the change

If no description was provided, ask:
> "What change do you want to blueprint? Describe the ticket or the intent."

Derive a short kebab-case name for the change (e.g. "add rate export endpoint" → `add-rate-export`).

### 2 — Load the current model

**Preferred:** query via the LikeC4 MCP server (configured in `.mcp.json`). Ask for:
- All elements and their kinds, titles, technologies
- All relationships
- Existing views

**Fallback (if MCP unavailable):** read `model/system.c4` and `model/views.c4` directly.

Build a mental map: what elements exist, what relationships are defined, what views are present. This is ground truth — never invent elements that aren't in the model.

### 3 — Write EARS requirements

Produce requirements in EARS notation **before** touching the `.c4` diff:

```
WHEN [trigger or condition]
THE SYSTEM SHALL [behavior]
```

One requirement per distinct behavior. If a requirement has multiple conditions, split it. List every requirement you intend the `.c4` diff to satisfy.

**Greenfield note:** if the model is empty (no elements yet), write the EARS requirements from the ticket alone. Mark any element whose existence you cannot confirm from an artifact as `[unverified — confirm with /assessment]`.

### 4 — Emit the proposed `.c4` diff

Show only the additions and changes needed. Group by change type:

```
// ── NEW ELEMENTS ──────────────────────────────────────────────────
// Added to satisfy: WHEN developer requests export THE SYSTEM SHALL ...
service rate_exporter {
  title 'Rate Export Service'
  technology '<fill in>'
  // owner: ? (confirm)
  // dataClassification: ? (confirm)
}

// ── NEW RELATIONSHIPS ─────────────────────────────────────────────
rate_exporter -> database.rate 'reads'

// ── MODIFIED ELEMENTS ────────────────────────────────────────────
// Change to existing element — show full updated block
service api {
  title 'API Service'
  technology 'Node, Express'
  // + new route: GET /export
}

// ── NEW / UPDATED VIEW ───────────────────────────────────────────
view export_flow {
  title 'Rate Export Flow'
  include rate_exporter, database.rate, actor.developer
  autoLayout LeftRight
}
```

Leave `owner`, `dataClassification`, and `auth` as comments with `?` if they cannot be determined. These are always AMBIGUOUS.

### 5 — Direct the developer to the diagram

Tell the developer:

```
Run `likec4 serve` in the model/ directory (or it may already be running).
Open the browser and look at the [view name] view.
Changed elements are highlighted.

Does the diagram look right?
  - Approve → commit the `.c4` diff and implement.
  - Correct → Tell me what's wrong and we'll revise.
```

### 6 — Wait for approval or correction

**If approved:** confirm which EARS requirements are satisfied, then say:
> "Commit the `.c4` diff and implement."

**If corrected:** revise the EARS requirements and diff based on the developer's feedback. Repeat from step 4. Never commit anything until approval.

---

## Guardrails

- EARS requirements MUST appear before the `.c4` diff. Never skip this step.
- Never invent elements not in the current model or the ticket. If uncertain, mark as `[unverified]`.
- Never write `blueprint/model/*.c4` files directly. The diff is a proposal only — the developer commits it.
- Never generate `design.md`, `tasks.md`, or code before approval.
- `dataClassification` and `auth` are always AMBIGUOUS — always leave as `?` for developer input.
- If the MCP server is unavailable and `model/system.c4` is empty, say so and suggest running `/assessment` first.
