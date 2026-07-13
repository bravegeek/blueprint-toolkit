## 1. Pass 4 synthesis guidance

- [x] 1.1 In `skills/assessment/SKILL.md` Pass 4, add a reconciliation-first step: build a `sourceLocation → { sources, strongest-confidence, evidence }` map from the union before synthesizing elements
- [x] 1.2 Rewrite the "Confidence → tags" step to derive the tag from the reconciled strongest confidence (`PROVABLE` > `INFERRED`), never from the LLM's own confidence impression
- [x] 1.3 State the identity-overlap rule: the same `sourceLocation` from multiple sources reconciles to the strongest claim; INFERRED never downgrades PROVABLE
- [x] 1.4 Require every `#provable` element to carry the deterministic source's `file:line` evidence (no bare `#provable`)
- [x] 1.5 Confirm sourceLocation match still yields a single element (no per-source duplication)

## 2. Validation

- [ ] 2.1 Re-run `/assessment` on `fractal-table-vtt` (deferred to the user's next /assessment run)
- [ ] 2.2 Confirm `actions 'Action Reducer'` (`lib/vtt/actions.ts#applyAction`) and `campaignAction` render `#provable`, not `#inferred`
- [ ] 2.3 Confirm an INFERRED-only element (no deterministic source, e.g. a Next.js route) stays `#inferred`
- [ ] 2.4 Confirm no duplicate elements for locations reported by both `tsserver` and `llm-assessment`
- [ ] 2.5 `likec4 validate` passes once against the real target files after Pass 4
