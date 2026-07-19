## 1. Installer CLI refactor

- [x] 1.1 Add a subcommand dispatcher to `install.sh` recognizing `init`, `add-skill`, `doctor` (and preserving `--clean`/`--force`); unknown invocation prints usage naming the verbs and exits non-zero.
- [x] 1.2 Implement `doctor()`: checks for Node ≥ 20, `npx` present, `blueprint/bin/likec4` boots, wrapper executable, model present, `.mcp.json` present; per-check ok/FAIL + remediation hint; non-zero exit on any failure.
- [x] 1.3 Implement `init`: install the base substrate only (`AGENTS.md`, `.mcp.json`, `blueprint/model/*`, `blueprint/bin/likec4`), run the project-name step, then call `doctor` and show its result.
- [x] 1.4 Implement `add-skill <name>`: guard that `blueprint/model/system.c4` exists (else fail with "run init first" and install nothing), then `install_skill` + `link_skill_wrapper` for that name.
- [x] 1.5 Wire `--clean`/`--force` into the new dispatcher so existing behavior (model backup + reset, non-model refresh, model protection) is unchanged.
- [x] 1.6 Verify: fresh `init` then `add-skill assessment` on a scratch target produces the same file set the old monolith did, `doctor` passes, and `add-skill` on a base-less dir fails cleanly.

## 2. One-command bootstrap

- [x] 2.1 Add `bootstrap.sh` that fetches the toolkit source into a temp dir (shallow clone or tarball — pick the smaller/dependency-free option) and execs the installer's `init`, forwarding args after `--`.
- [x] 2.2 Ensure the bootstrap requires nothing beyond POSIX shell + `curl` + the toolkit's existing Node/`npx` prerequisite. (`tar` is also required to unpack the GitHub tarball — checked explicitly with a clear error.)
- [x] 2.3 Verify the documented `curl -fsSL <raw-url>/bootstrap.sh | bash -s -- init .` onboards a cloneless target end-to-end (base installed, doctor run). Verified the fetch/extract/arg-forwarding mechanics against the live GitHub tarball (codeload fetch succeeded, `install.sh` located, args forwarded correctly with `argc=3`) and the `init` verb itself end-to-end locally; full remote round-trip against the *new* CLI will pass once this branch is pushed, since `main` still serves the pre-refactor `install.sh` today.

## 3. Wire deterministic extractors into the Extraction step

- [x] 3.1 Relocate the `.mjs` extractors to `skills/assessment/extractors/`; grep the repo for stale path references and update them.
- [x] 3.2 Add an explicit Extraction-step run block: `tsserver-extractor.mjs` when `tsconfig.json` present, `nextjs-recipe-extractor.mjs` when Next.js detected, always `llm-assessment`, then `union-extraction.mjs` over all produced sources.
- [x] 3.3 State that Model consumes the union (never a single source) and that the skill must not complete on LLM-only when a deterministic source's preconditions hold.
- [x] 3.4 Verify on a TypeScript+tsconfig fixture that the named commands resolve to real scripts and produce a union document Model can read. Verified: `extractors/tsserver-extractor.mjs` against a fixture (`tsconfig.json` + `pipeline.ts` importing `storage.ts`'s `StorageBackend` interface) produced a valid PROVABLE extraction; `extractors/union-extraction.mjs` merged it with a synthetic `llm-assessment` output into a single consumable document.

## 4. Split the assessment skill

- [x] 4.1 Create `skills/assessment/reference/` and move out: `confidence-tiers.md`, `extraction-format.md`, `disambiguation.md`, `domain-rules.md`, and `stack-probes/` (python-postgres-s3, node-docker) lifted from the current inline probe code.
- [x] 4.2 Rewrite `SKILL.md` as procedure-only: invocation, ~5-line operating rules, the four passes each as Input → Run → Output → Done-when, and Confirm — linking to `reference/` files by path at the point of need.
- [x] 4.3 Consolidate every repeated normative rule (e.g. "don't curate out PROVABLE") to a single canonical statement.
- [x] 4.4 Confirm the whole-directory installer copies `reference/` and `extractors/` into a target on `add-skill assessment` (no enumerated-list edit needed) and the wrapper symlink still resolves. Found and fixed a real bug surfaced by this: `install_skill`/`install_file` only handled one directory level (`cp` without `-r`), so the new nested `extractors/`/`reference/`/`reference/stack-probes/` subdirectories were silently dropped. Fixed by recursing with `find -type f` and a non-subshell `while read` loop (process substitution) so the `copied`/`skipped` counters stay accurate; verified against a scratch target — all 12 files land, wrapper symlink resolves through the subdirectories, `--clean` still refreshes everything.
- [x] 4.5 Verify `SKILL.md` no longer inlines probe code / the extraction-format JSON / the tier table, and that each pass names the reference file it needs.
- [x] 4.6 Rename the passes to **Census / Infrastructure / Code / Model**, name the Code sub-steps (Module graph · Orchestration · Extraction) and retire the a/b/c letters — "Pass 3c" becomes "the Extraction step". Sweep every live reference (SKILL.md, this change's specs/tasks/design, `code-extraction-boundary` + `functional-module-extraction` specs, `scan.sh`, `pass4-converter.mjs`, AGENTS.md, QUICKSTART.md, project.md); leave `openspec/changes/archive/**` untouched as history.

## 5. Docs and validation

- [x] 5.1 Update `README.md`, `QUICKSTART.md`, and `AGENTS.md` to lead with the `init` / `add-skill` / assess flow and the bootstrap one-liner, and to reflect the lean skill layout.
- [x] 5.2 Run `openspec validate installer-cli-and-lean-assessment` (or the change's validation) and resolve any spec/scenario issues. `openspec validate installer-cli-and-lean-assessment` → "Change 'installer-cli-and-lean-assessment' is valid".
- [x] 5.3 Sanity-run `blueprint doctor` against this repo's own `blueprint/` to confirm the check logic works against a real install. Required loosening `resolve_target_dir`'s toolkit-repo self-target guard: it unconditionally rejected `TARGET_DIR == SRC_DIR`, which made `doctor` (read-only, safe to dogfood) inherit a restriction meant for `init`/`add-skill`/`--clean` (which write files). Added an `allow-self` opt-in used only by `cmd_doctor`. `./install.sh doctor .` from the toolkit repo root now reports all six checks ok.
