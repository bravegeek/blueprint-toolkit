## 1. Ontology

- [ ] 1.1 Add `rule` element kind to `blueprint/model/system.c4` specification (with a comment describing it as a developer-authored domain rule/policy/invariant)
- [ ] 1.2 Add `governs` relationship kind (rule → enforcing component/contract/command)
- [ ] 1.3 Confirm `install.sh` propagates the new kind + relationship into target projects' base specification

## 2. Elicitation (Confirm step)

- [ ] 2.1 In `skills/assessment/SKILL.md` Confirm step, add rule-slot proposal from structural signals (redaction-shaped modules, command groups, etc.)
- [ ] 2.2 Specify that rules are emitted ONLY from developer input, never inferred; no `#provable`/`#inferred` tag on `rule` elements
- [ ] 2.3 Record developer-supplied rule text verbatim in intent; attach via `governs` to each enforcing element

## 3. Disambiguation clarity

- [ ] 3.1 In the Confirm step (and any INFERRED/AMBIGUOUS question elsewhere in the skill), require each question to state: what is being decided, why it matters, and each option's implication
- [ ] 3.2 Require questions to avoid internal modeling jargon (or define it inline)
- [ ] 3.3 Preserve explicit option lists and a clearly marked default on every question
- [ ] 3.4 Add a worked before/after example question to the skill so the phrasing bar is concrete

## 4. Views

- [ ] 4.1 Add a `domainRules` view proposal to Pass 4 (includes `rule` elements + governed elements)
- [ ] 4.2 Ensure `index`/`context`/`services` views exclude `rule` elements

## 5. Validation

- [ ] 5.1 On `fractal-table-vtt`, elicit a `fateEconomy` rule (governs the economy commands) and a `secrecyRedaction` rule (governs `redaction.ts`)
- [ ] 5.2 Confirm rules appear only in `domainRules`, not in architecture views
- [ ] 5.3 Confirm each disambiguation question meets the clarity requirement (decision/stakes/options/default)
- [ ] 5.4 `likec4 validate` passes once against the real target files after Pass 4
