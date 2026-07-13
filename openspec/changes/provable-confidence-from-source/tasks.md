## 1. Pass 4 synthesis guidance

- [x] 1.1 In `skills/assessment/SKILL.md` Pass 4, add a reconciliation-first step: build a `sourceLocation → { sources, strongest-confidence, evidence }` map from the union before synthesizing elements
- [x] 1.2 Rewrite the "Confidence → tags" step to derive the tag from the reconciled strongest confidence (`PROVABLE` > `INFERRED`), never from the LLM's own confidence impression
- [x] 1.3 State the identity-overlap rule: the same `sourceLocation` from multiple sources reconciles to the strongest claim; INFERRED never downgrades PROVABLE
- [x] 1.4 Require every `#provable` element to carry the deterministic source's `file:line` evidence (no bare `#provable`)
- [x] 1.5 Confirm sourceLocation match still yields a single element (no per-source duplication)

## 2. Validation

- [x] 2.1 Re-ran `/assessment` on `fractal-table-vtt`
- [x] 2.2 `actionsReducer` (`lib/vtt/actions.ts#applyAction`) and `campaignActionContract` (`#CampaignAction`) now render `#provable` (were `#inferred`)
- [x] 2.3 INFERRED-only elements stayed `#inferred` (19 remain: routes, pages, recipe-sourced commands) — no blanket promotion
- [x] 2.4 No duplicate elements; model has single elements per sourceLocation and validates
- [x] 2.5 `likec4 validate` → `✓ Valid (2 files)` on the real model (backups excluded; see backup-glob note)
