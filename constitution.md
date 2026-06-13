# Constitution — Blueprint Layer

## Intent Log Convention

Every commit in this repo is a **spec entry** (decision + model change), a **build entry** (implementation record), or a **merge entry** (branch integration).

The model is defined by all files matching `model/*.c4`. A spec entry must change at least one `.c4` file.

### Spec Entry

Commits that change the model. The commit message IS the decision; the diff IS the model change:

```
decision: <what was decided, in natural language>

---
ticket: <reference>
decisions:
  - <key decision>
assumptions:
  - <unverified assumption>
---
```

The subject line (`decision: ...`) is the authoritative human-readable record. The YAML body (between `---` fences) is machine-parseable.

Fields:
- `ticket` — required if the change originated from a ticket
- `decisions` — required. At least one entry capturing what was decided and why.
- `assumptions` — optional. Anything assumed without direct verification.

Timestamp and author are derived from git metadata — not duplicated in the body.

### Build Entry

Commits that record a completed implementation:

```
build: <concise description of what was built>

---
spec-ref: <git ref of the spec entry this build satisfies>
test-result: passing | failing | partial
binary: <path or reference, optional>
generator: <tool and version, optional>
---
```

### Append-only Rules

- Spec entries are append-only. Never amend, rebase, or force-push the intent log branch.
- To correct a mistake: commit a new spec entry that reverts or changes the model. The log records both the error and its correction.
- The current model state is always the head of the spec entries on the current branch — replay all entries in order to derive it.

### Merge Convention

When model changes flow through a feature branch:
- Each meaningful `.c4` change on the feature branch is a separate spec entry.
- The merge commit to main is not a spec entry. Use an empty message or `merge: <branch>`.
- This preserves linear decision history on main — individual decisions remain visible.

## Initial Model Commit

The first spec entry is the initial LikeC4 model, confirmed accurate by the assessment skill and developer review. Its commit message:

```
decision: initial model derived from system assessment — confirmed accurate as of YYYY-MM-DD
```

---

## Model Accuracy Principle

The model is derived from actual system state, not authored from memory. The assessment skill reads the running system and proposes a model. The developer confirms or corrects it. The model is never updated without ground truth verification.

---

## Blueprint Diff Convention

When a change is proposed, the workflow produces:
1. A **highlighted view** in LikeC4 — changed elements styled with `color: blue` and `border: dashed`
2. A **textual diff** from the `element-diff` MCP tool — structured comparison of properties, tags, metadata, relationships

The highlighted view is the quick orientation. The textual diff is the detail. Both are reviewed before committing.

---

## Tooling Stack

- LikeC4 — model, views, MCP server, file watcher
- Git — intent log
- Assessment skill — system → model derivation
- Blueprint-change skill — ticket → EARS → .c4 diff → review gate
