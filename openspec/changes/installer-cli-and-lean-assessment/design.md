## Context

The toolkit is heading into its first real-project trial. Two sources of friction would make that trial's results ambiguous:

1. **Onboarding is multi-step and manual.** Today a user clones the repo and runs a monolithic `install.sh /path [name]` that installs everything at once, then must hand-edit stack-specific probes before assessment works. The intended experience is three clean commands — install the base, add a skill, run the assessment.
2. **The assessment skill is 823 lines of mixed procedure and reference.** Runtime steps, rationale, the extraction-format spec, and inline stack probes compete for the agent's attention. When a run goes wrong, there is no way to attribute the failure to design vs. interpretation.

A third issue is a latent bug rather than friction: `tsserver-extractor.mjs` and `nextjs-recipe-extractor.mjs` exist and are described in the skill, but no live instruction invokes them, so assessment silently runs LLM-only — the exact degradation `openspec/project.md` was written to prevent.

Constraints from the project's binding principles: agent-agnostic (canonical skill is vendor-neutral, per-agent paths are thin wrappers), no new runtime dependencies, and the model files (`system.c4`/`views.c4`/`.likec4rc`) stay protected across every install path.

## Goals / Non-Goals

**Goals:**
- A three-verb installer (`init`, `add-skill`, `doctor`) that matches the install → add-skill → assess flow.
- A single-command remote bootstrap for cloneless onboarding, suitable for the trial.
- A lean `SKILL.md` (procedure only) with reference material and probes moved under `reference/`.
- Deterministic/framework extractors actually invoked and unioned in the Extraction step.
- No regression of existing `--clean`/`--force` behavior or model protection.

**Non-Goals:**
- npx/npm package distribution (a later follow-up; bootstrap is enough for the trial).
- Multi-vendor wrapper support beyond the existing `.claude/skills` path (earn it after the loop is proven).
- A full test harness for the skills. This change makes steps decidable enough to *enable* golden-transcript testing later, but does not build it.
- Rewriting the extractor internals — only their invocation is added.
- Changing the assessment's analytical behavior (passes, tiers, outputs) beyond wiring the extractors and re-expressing steps.

## Decisions

### Decision: One `blueprint` CLI with subcommands, wrapping the existing install functions

`install.sh` already contains `install_file`, `install_skill`, and `link_skill_wrapper`. Rather than build a package manager, the refactor re-fronts these behind three verbs. `init` runs the base-file loop (`AGENTS.md`, `.mcp.json`, `blueprint/model/*`, `blueprint/bin/likec4`) plus the project-name step and a closing `doctor`. `add-skill <name>` runs `install_skill`/`link_skill_wrapper` for one name after a base-present guard. `doctor` is a standalone check function `init` also calls.

- **Alternative considered — keep the monolith, add flags:** rejected; it does not produce the "add a skill" verb the user's flow is built around, and it keeps base+skills coupled, which blocks the per-skill menu that helps OSS adoption.
- **Alternative considered — split into separate scripts:** rejected; three scripts to distribute and keep in sync is worse than one dispatcher, and the bootstrap only needs one entry point.

### Decision: Base vs. skill install split along the natural substrate seam

The base substrate is everything a skill depends on but isn't itself a skill: the model, the `bin/likec4` wrapper, `AGENTS.md`, `.mcp.json`. Skills (`skills/<name>/`) install separately via `add-skill`. `add-skill` fails fast if `blueprint/model/system.c4` is absent, since a skill with no model or wrapper to bind to is a confusing dead end.

### Decision: Bootstrap is a thin curl-piped shell script, not a package

`bootstrap.sh` (hosted in the repo, fetched via its raw URL) downloads the toolkit source (tarball or shallow clone into a temp dir) and execs the installer's `init` verb, forwarding any args after `--`. This gives the one-command experience without publishing anything.

- **Alternative considered — npx package now:** rejected for this change; requires packaging + publishing and is premature before the loop is validated. Recorded as the eventual distribution channel.

### Decision: `SKILL.md` becomes procedure-only; detail moves to `reference/`

Target layout:

```
skills/assessment/
  SKILL.md            # invocation, ~5-line operating rules, 4 passes as steps, confirm
  scan.sh
  reference/
    confidence-tiers.md
    extraction-format.md
    disambiguation.md
    domain-rules.md
    stack-probes/{python-postgres-s3.md, node-docker.md}
  extractors/{tsserver-extractor.mjs, nextjs-recipe-extractor.mjs, union-extraction.mjs, pass4-converter.mjs}
```

Each pass is written as `Input → Run → Output → Done-when`. Reference files are named inline at the point of need. The repeated "don't curate out PROVABLE" warnings collapse to one canonical line — and become largely redundant once the deterministic source's facts no longer pass through LLM judgment.

- **Alternative considered — renumber the 823 lines into steps in place:** rejected; same volume, and every caveat then reads as a mandatory step. The problem is volume + mixed audience, not prose vs. list.

### Decision: Wire extractors in the Extraction step with concrete commands, gated by preconditions

The Extraction step gains an explicit block: run `tsserver-extractor.mjs` when `tsconfig.json` is present, `nextjs-recipe-extractor.mjs` when Next.js is detected, always run `llm-assessment`, then `union-extraction.mjs` over whatever was produced; Model consumes the union. Confidence stays a property of the source. The `install.sh` whole-directory skill copy already carries any new `extractors/` and `reference/` files without an install-list edit, so relocating the `.mjs` files is safe.

## Risks / Trade-offs

- **Bootstrap hosting assumes the repo is reachable at a stable raw URL** → For the trial, point at the repo's default branch raw URL; document that a tag/pin can replace it later. Acceptable because the trial audience is the author's buddy, not the public yet.
- **Relocating the `.mjs` extractors under `extractors/` could strand references** → The only live references are the ones this change adds in the Extraction step; the whole-directory installer copies them regardless. Grep for old paths after the move.
- **Splitting one skill into many files raises the chance the installer leaves one behind** → Mitigated by the existing whole-directory copy (`install_skill` iterates directory contents, not an enumerated list); verify `reference/` and `extractors/` land in the target after `add-skill`.
- **Doctor's "likec4 boots" check runs `npx` and may be slow or need network on first run** → It is a one-time preflight, and catching that latency/failure at install time is the point; keep the check's failure message explicit about network/npx.
- **Over-investing in installer polish is itself the "polish before validate" trap** → Scope is fixed to the three verbs + bootstrap + doctor; uninstall, multi-vendor wrappers, and npx are explicit Non-Goals.

## Migration Plan

- Existing installs keep working: `--clean`/`--force` are retained, and `init`/`add-skill` produce the same files the monolith did.
- Rollback is `git revert` of the toolkit change; installed target projects are unaffected because their model files are never touched by this change.
- After merge, update `README.md`/`QUICKSTART.md`/`AGENTS.md` to lead with the three-command flow.

## Open Questions

- Bootstrap fetch mechanism: shallow `git clone` vs. tarball download — decide during implementation based on what keeps the script smallest and dependency-free.
- Which stack-probe reference packs to ship first beyond Python/Postgres/S3 and Node/Docker (driven by the trial project's stack).
