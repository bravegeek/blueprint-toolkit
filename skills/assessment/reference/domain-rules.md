# Domain Rules — Elicit, Never Infer

The code shows *that* `applyAction` runs and *that* `redaction.ts` is imported; it cannot show the **rules** — "invoking an aspect costs a fate point", "GM secrets are redacted before reaching players". These are `rule` elements, and they are **`AMBIGUOUS` tier: developer-authored only.** You MUST NOT invent, infer, or LLM-author the content of a rule.

What you *may* do is propose **candidate rule slots** from structural signals you already have, and ask the developer to fill or reject them:

- a module named/shaped like redaction, authorization, or a policy check → "there may be a secrecy/permission rule here — what is it?"
- a `command` category or component group that clearly implements an economy/lifecycle/permission concern → "what rule governs these actions?"

For each slot the developer confirms:
- Record their rule text **verbatim in intent** as the `rule` element's description — do not paraphrase it into a guess.
- Emit the `rule` element with **no `#provable`/`#inferred` tag** (rules are developer-confirmed, not source-derived).
- Attach it with a `governs` relationship to **each** enforcing element (component, contract, or command).
- If the developer rejects a slot or has no rule, emit nothing for it.

Every rule-slot question follows the [disambiguation clarity](disambiguation.md) rules — state what's being decided, why it matters, and what each option implies.
