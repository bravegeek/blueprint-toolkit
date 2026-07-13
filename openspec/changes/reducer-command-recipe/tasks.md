## 1. Ontology

- [ ] 1.1 Add `command` element kind to `blueprint/model/system.c4` specification (the app's/domain's verbs)
- [ ] 1.2 Confirm `install.sh` propagates it into target base specifications

## 2. Recipe (Pass 3c source)

- [ ] 2.1 Add a `reducer-command` recipe to `skills/assessment/SKILL.md` Pass 3c, gated on discriminated-union + reducer-dispatch detection
- [ ] 2.2 Detect the shape: union members sharing a discriminant, consumed by a `switch`/dispatch function
- [ ] 2.3 Emit mid-level categories as `command` nodes (INFERRED); treat leaves as internal
- [ ] 2.4 Fallback: flat union → group by discriminant prefix or single top-level command
- [ ] 2.5 Emit `handles` edges from the reducer/dispatch element to each category
- [ ] 2.6 Enforce disjointness from `tsserver` (no union-type node, reducer-module node, or import edges)
- [ ] 2.7 Emit a single JSON tagged `source: "llm-reducer"`; no format change (command edge kinds ride `edges[].kind`)

## 3. Views

- [ ] 3.1 Include `command` nodes in the code-structure / game-engine view
- [ ] 3.2 Keep `command` nodes out of top-level architecture views by default

## 4. Validation

- [ ] 4.1 On `fractal-table-vtt`, emit the ~10 `*Action` categories as `command` nodes (not the 37 leaves)
- [ ] 4.2 Confirm `applyAction` links to each category via `handles`
- [ ] 4.3 Confirm no overlap with `tsserver` facts (union type + reducer module come from Layer 1/tsserver, not this recipe)
- [ ] 4.4 Confirm the recipe is silent on a non-reducer project (regression: no spurious commands)
- [ ] 4.5 `likec4 validate` passes once against the real target files after Pass 4
