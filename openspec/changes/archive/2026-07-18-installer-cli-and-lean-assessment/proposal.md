## Why

Before the toolkit's first real-project trial, two kinds of friction would confound the experiment: onboarding a new user takes several manual steps (clone, run a monolithic installer, hand-edit stack probes) instead of a clean "install → add a skill → assess" flow, and the assessment skill is an 823-line prose file that mixes runtime procedure with reference material — so when a run goes wrong there is no way to tell whether the *design* is wrong or the agent simply read the prose differently. Tight, decidable steps and a frictionless install turn the trial into a controlled experiment instead of an ambiguous one. This change also revives a headline capability that is currently inert: the deterministic extractors (`tsserver`, `llm-nextjs`) ship in the repo and are described in the skill, but no live instruction ever invokes them, so every assessment silently runs LLM-only.

## What Changes

- Refactor `install.sh` into a three-verb CLI matching the intended onboarding flow: `init` (base substrate + runs doctor), `add-skill <name>` (one skill dir + wrapper; fails clearly if the base is missing), and `doctor` (environment/toolchain checks). The existing `--clean`/`--force` behavior is preserved as compatible flags/aliases so no current capability regresses.
- Add a `doctor` preflight that verifies Node ≥ 20, `npx` presence, that `blueprint/bin/likec4` actually boots, wrapper executability, and presence of the model and `.mcp.json` — surfacing toolchain failures up front instead of mid-assessment.
- Add a one-command remote bootstrap (`curl … | bash -s -- init .`) so a new user installs without cloning first. (npx-package distribution is noted as a future follow-up, out of scope here.)
- Split the assessment skill: a lean, imperative `SKILL.md` (procedure only — each pass as input → do → output → done-when) plus a `reference/` directory holding the confidence tiers, extraction format, disambiguation and domain-rule guidance, and stack-specific probes lifted out of the procedure body. Collapse the repeated "don't curate out PROVABLE" warnings to a single canonical statement.
- **Wire the deterministic extractors into the Extraction step**: the assessment skill SHALL explicitly invoke `tsserver-extractor.mjs` (when `tsconfig.json` is present) and `nextjs-recipe-extractor.mjs` (when Next.js is detected), always run `llm-assessment`, union the outputs via `union-extraction.mjs`, and feed the union to Model. This closes the gap between what the skill claims and what it does.

## Capabilities

### New Capabilities
- `installer-cli`: The `init` / `add-skill` / `doctor` verb decomposition, base-vs-skill install split, the `add-skill` base-present guard, and the doctor's toolchain checks.
- `one-command-bootstrap`: A remote curl-pipe bootstrap that fetches the toolkit and runs `init` without a prior clone.
- `assessment-skill-structure`: The requirement that the assessment skill keep a lean runtime procedure (decidable steps with explicit input/output/done contracts) separate from on-demand `reference/` material, with no behavioral rule stated more than once.
- `deterministic-extractor-invocation`: The requirement that the assessment skill actually invoke the deterministic and framework extractors under their preconditions, union all present sources, and consume the union in Model — never silently degrading to LLM-only when a deterministic source is available.

### Modified Capabilities
<!-- install-clean-semantics is intentionally preserved, not modified: `--clean` remains a working alias with identical behavior, so its requirements continue to hold. -->

## Impact

- **`install.sh`**: refactored into subcommands; new `doctor` function; new base/skill install split. Backward-compatible `--clean`/`--force` retained.
- **New file**: a bootstrap script (e.g. `bootstrap.sh`) hosted in the repo for the curl one-liner.
- **`skills/assessment/`**: `SKILL.md` rewritten lean; new `reference/` subtree; `*.mjs` extractors relocated under `extractors/` and now referenced by the procedure.
- **Dependencies**: none added. Bootstrap relies on the toolkit's existing Node/`npx` requirement.
- **Docs**: `README.md`, `QUICKSTART.md`, and `AGENTS.md` updated to describe the new onboarding commands and the lean skill layout.
- **No runtime application code in target projects is affected** — this is toolkit-authoring and installer surface only.
