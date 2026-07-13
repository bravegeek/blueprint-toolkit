## 1. Extraction guidance (Pass 3c)

- [x] 1.1 In `skills/assessment/SKILL.md` Pass 3c, redefine `component` as "exported class OR cohesive functional module (one file of exported functions/consts/types)"
- [x] 1.2 Redefine `contract` to include exported type aliases / discriminated unions crossing module boundaries, with `kind` `"type"` or `"interface"`
- [x] 1.3 Replace the shape-based "skip helpers, utilities" rule with "skip modules with no cross-module import evidence"
- [x] 1.4 State directory intent as a secondary, project-neutral signal (no hardcoded paths)
- [x] 1.5 Update the TS/JS rules (currently grep `^export class` / `^export interface`) and the Python rules symmetrically

## 2. Pass 4 synthesis

- [x] 2.1 Update the "cross-module evidence filter" so functional modules and type-alias contracts survive when imported cross-module
- [x] 2.2 Confirm module-level (not function-level) granularity in the emitted `.c4` (documented in the filter; extractor emits raw symbol-level facts, Pass 4 collapses to one component per module)
- [x] 2.3 Confirm no new element kinds and no format change are required
- [x] 2.4 Add a "PROVABLE is ground truth" non-curation rule to Pass 4: a deterministic (`tsserver`) cross-module component/contract MUST be emitted; "primary/significant" curation applies only to INFERRED items, never to PROVABLE facts
- [x] 2.5 Re-verified on the VTT: `applyAction` lands as component `actions 'Action Reducer'` (sourceLocation `lib/vtt/actions.ts#applyAction`) and `CampaignAction` lands as contract `campaignAction`; whole `lib/vtt` game-engine tier now modeled

## 3. tsserver driver

- [x] 3.1 Widen enumeration in `skills/assessment/tsserver-extractor.mjs` to include exported functions and type aliases (also `export const`, `export default`)
- [x] 3.2 Resolve cross-module function/type edges → `PROVABLE` edges with `file:line` (fixed the `from: 'unknown'` bug; added multi-line import parsing)
- [x] 3.3 Emit class-free imported modules as components; keep single-use modules out (significance = cross-module import evidence)

## 4. Validation

- [x] 4.1 Confirmed `lib/vtt/` domain modules appear as components — 20 modules / 69 functional exports surfaced (was zero) via the tsserver source that feeds `/assessment`
- [x] 4.2 Confirmed the `server/sync/room.ts → applyAction` PROVABLE edge (evidence `server/sync/room.ts:1`) and the `CampaignAction` contract (`kind: "type"`) appear
- [x] 4.3 Regression: `Room` class still emitted as a component; `unknown`-from edges eliminated (the old model's "Store" was a class-shaped fiction — `store.ts` is functional and its real exports are now captured)
- [x] 4.4 `likec4 validate` passes against the regenerated VTT model after a manual `/assessment` run — `✓ Valid (4 files)`
