## 1. Ontology

- [x] 1.1 Add `command` element kind to `blueprint/model/system.c4` specification (the app's/domain's verbs) — also added `handles` relationship kind the recipe's edges need
- [x] 1.2 Confirm `install.sh` propagates it — `install.sh` copies `blueprint/model/system.c4` whole as the base template on fresh/`--clean` installs, so the new kind reaches targets with no install-list edit

## 2. Recipe (Pass 3c source)

- [x] 2.1 Add a `reducer-command` recipe to `skills/assessment/SKILL.md` Pass 3c, gated on discriminated-union + reducer-dispatch detection
- [x] 2.2 Detect the shape: union members sharing a discriminant, consumed by a `switch`/dispatch function (with detection greps)
- [x] 2.3 Emit mid-level categories as `command` nodes (INFERRED); treat leaves as internal
- [x] 2.4 Fallback: flat union → group by discriminant prefix or single top-level command
- [x] 2.5 Emit `handles` edges from the reducer/dispatch element to each category
- [x] 2.6 Enforce disjointness from `tsserver` (no union-type node, reducer-module node, or import edges) — stated in the recipe and the format-boundary "Disjoint fact sets" bullets
- [x] 2.7 Emit a single JSON tagged `source: "llm-reducer"`; no format change (command edge kinds ride `edges[].kind`)

## 3. Views

- [x] 3.1 Include `command` nodes in the code-structure / engine view (`codeStructure` view guidance)
- [x] 3.2 Keep `command` nodes out of top-level architecture views by default (`index`/`context`/`services` exclude commands)

## 4. Validation

- [ ] 4.1 On `fractal-table-vtt`, emit the ~10 `*Action` categories as `command` nodes (not the leaves) — detection gate CONFIRMED (`lib/vtt/actions.ts:555 switch(action.kind)` + `*Action` union present); category-only emission deferred to the user's next `/assessment` run
- [ ] 4.2 Confirm `applyAction` links to each category via `handles`
- [ ] 4.3 Confirm no overlap with `tsserver` facts (union type + reducer module come from Layer 1/tsserver, not this recipe)
- [ ] 4.4 Confirm the recipe is silent on a non-reducer project (regression: no spurious commands)
- [ ] 4.5 `likec4 validate` passes once against the real target files after Pass 4
