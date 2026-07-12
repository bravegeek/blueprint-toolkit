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
  → load current model (via MCP or by reading blueprint/model/*.c4)
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

**Fallback (if MCP unavailable):** read `blueprint/model/system.c4` and `blueprint/model/views.c4` directly.

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

### 4.5 — Code-structure-impact check (new step)

**Goal:** Determine whether the proposed change adds, removes, or rewires components or contracts within any touched services.

**Process:**

1. Identify the services/modules affected by the change (from the EARS requirements and ticket description).
2. For each affected service, ask: "Does this change add or modify exported classes (components)?" or "Does this change define or modify typed interfaces crossing module boundaries (contracts)?"
3. If the answer is **no** to both: skip the code-level diff (steps 4.6 and 4.7) and proceed directly to step 5.
4. If the answer is **yes** to either: proceed to step 4.6 (code-level extraction) and step 4.7 (code-level diff rendering).

**When to skip code-level diffs:**
- The change only modifies internal/private implementation (helpers, internal utilities).
- The change only adds new fields to a datastore or queues.
- The change only rewires existing components or contracts (no structural change).
- The change is purely architectural (adds a new service, but no code is written yet).

**When to include code-level diffs:**
- The change adds a new exported class (component) to a service.
- The change adds or modifies a cross-module interface (contract).
- The change removes a component or contract.
- The change significantly rewires component relationships.

### 4.6 — To-be code extraction (if code-structure-impact is yes)

**Goal:** Produce a proposed extraction document for the touched modules only, plus the direct endpoints of edges leading into untouched modules.

**Process:**

1. Query or read the current code-level extraction (if it exists in the model metadata or a cached extraction file).
2. For each touched module, produce a *to-be* extraction showing:
   - Components (exported classes) that will exist after the change.
   - Contracts (typed interfaces) that will be defined or modified.
   - Edges between components and contracts, including those leading to untouched modules.
3. Format: use the same intermediate extraction format from the assessment skill (`source`, `language`, `components[]`, `contracts[]`, `edges[]`).
4. Mark entries as `"planned": true` to distinguish them from current-state extraction (optional, for UX clarity).
5. Scope: include only touched modules and their direct outbound edges (do not extract unchanged modules).

### 4.7 — Code-level diff rendering (if code-structure-impact is yes)

**Goal:** Render the code-level structural diff as a diagram section within the existing review view.

**Process:**

1. Diff the to-be extraction (from step 4.6) against the current extraction (if it exists).
2. Identify adds, removes, and modifications:
   - New components or contracts.
   - Removed components or contracts (if the change includes cleanup).
   - Modified relationships (added/removed edges, updated implementations).
3. Render the diff as a new section in the proposed `.c4` diff (still under the same review gate as architecture-level changes):

```
// ── CODE-LEVEL STRUCTURAL DIFF ────────────────────────────────────
// (Only touched modules shown; components/contracts with cross-module evidence)
//
// In service [service_name]:
//   + new component [name] — [description]
//   - removed component [name] (or mark as deprecated)
//   ↻ modified relationship [from] → [to]

// Example:
// In service transformer:
//   + new component enricher "Data Enricher" #planned {
//       description "Adds contextual metadata to records."
//       metadata { sourceLocation "src/transformer/enricher.py#Enricher" }
//     }
//   ↻ modified relationship pipeline -> enricher "calls" (was: not present)
```

Keep the code-level diff to a summary (1–3 lines per touched service); the full `.c4` elements will be staged into the model only on approval (step 6).

### 5 — Direct the developer to the diagram

Tell the developer:

```
Run `../bin/likec4 serve` from the blueprint/model/ directory (or it may already be running).
Open the browser and look at the [view name] view.
Changed elements are highlighted.

[If code-level diff was included:]
This proposal also includes a code-level structural diff (new components or contracts in [service names]).
Review both the architecture-level changes and the code structure in the diagram.

Does the diagram look right?
  - Approve → commit the `.c4` diff and implement.
  - Correct → Tell me what's wrong and we'll revise.
```

### 6 — Wait for approval or correction

**If approved:** 

1. Confirm which EARS requirements are satisfied.
2. If a code-level diff was included:
   - Extract the to-be components and contracts from the proposed extraction.
   - Stage them into the model with planned `sourceLocation` metadata through the same update path as architecture-level elements (match on sourceLocation, update-in-place, or add new).
   - Ensure each code-level element has:
     - `sourceLocation` metadata (`file#Symbol`).
     - Confidence tag (`#planned`, or `#inferred`/`#provable` if derived from current code).
   - Generate `codeStructure` views for each touched service.
3. Say:
> "Commit the `.c4` diff and implement."

**If corrected:** revise the EARS requirements, proposed extraction (if any), and `.c4` diff based on the developer's feedback. Repeat from step 4. Never commit anything until approval.

---

## Guardrails

- EARS requirements MUST appear before the `.c4` diff. Never skip this step.
- Never invent elements not in the current model or the ticket. If uncertain, mark as `[unverified]`.
- Never write `blueprint/model/*.c4` files directly. The diff is a proposal only — the developer commits it.
- Never generate `design.md`, `tasks.md`, or code before approval.
- `dataClassification` and `auth` are always AMBIGUOUS — always leave as `?` for developer input.
- If the MCP server is unavailable and `blueprint/model/system.c4` is empty, say so and suggest running `/assessment` first.
