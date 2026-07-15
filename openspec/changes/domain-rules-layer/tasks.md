## 1. Ontology

- [x] 1.1 Add `rule` element kind to `blueprint/model/system.c4` specification (with a comment describing it as a developer-authored domain rule/policy/invariant)
- [x] 1.2 Add `governs` relationship kind (rule → enforcing component/contract/command)
- [x] 1.3 `install.sh` propagates it — `blueprint/model/system.c4` is copied whole as the base template on fresh/`--clean` installs

## 2. Elicitation (Confirm step)

- [x] 2.1 Added rule-slot proposal from structural signals (redaction/authorization/policy modules, command/economy groups) to the Confirm step
- [x] 2.2 Rules emitted ONLY from developer input, never inferred; `rule` elements carry no `#provable`/`#inferred` tag
- [x] 2.3 Record developer rule text verbatim in intent; attach via `governs` to each enforcing element; emit nothing for rejected slots

## 3. Disambiguation clarity

- [x] 3.1 Confirm step now requires every INFERRED/AMBIGUOUS question to state what's decided, why it matters, and each option's implication
- [x] 3.2 Questions must avoid internal modeling jargon (or define it inline)
- [x] 3.3 Explicit options + clearly marked default preserved on every question; default framed as an informed choice
- [x] 3.4 Added a worked before/after example (the `CampaignAction` question) as the phrasing bar

## 4. Views

- [x] 4.1 Added a `domainRules` view proposal (`include rule` + `rule -> *` governed elements) — the only view that shows rules
- [x] 4.2 `index`/`context`/`services` exclude `rule` elements (`context` already excludes `system.*`; added `exclude rule` to `index`/`services`)

## 5. Validation

- [ ] 5.1 On `fractal-table-vtt`, elicit a `fateEconomy` rule (governs the economy commands) and a `secrecyRedaction` rule (governs `redaction.ts`) — needs an interactive `/assessment` run (developer input); deferred to the user
- [ ] 5.2 Confirm rules appear only in `domainRules`, not in architecture views — deferred to that run
- [ ] 5.3 Confirm each disambiguation question meets the clarity requirement — deferred to that run
- [x] 5.4 `likec4 validate` passes with the new `rule`/`governs` kinds — base model `✓ Valid (2 files)`; per-project validation runs at the end of Pass 4 on the next assessment
