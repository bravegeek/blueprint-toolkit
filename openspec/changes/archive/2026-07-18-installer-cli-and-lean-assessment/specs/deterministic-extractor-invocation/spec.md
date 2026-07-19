## ADDED Requirements

### Requirement: The Extraction step invokes deterministic and framework extractors under their preconditions

The assessment skill's Extraction step SHALL contain explicit run instructions that invoke the deterministic extractor (`tsserver-extractor.mjs`) when the target has a resolvable TypeScript project (a `tsconfig.json` is present), and the framework extractor (`nextjs-recipe-extractor.mjs`) when Next.js is detected. These instructions SHALL name the concrete command to run, not merely describe the source conceptually.

#### Scenario: TypeScript project triggers the deterministic extractor

- **WHEN** the Extraction step runs on a target containing a `tsconfig.json`
- **THEN** the procedure instructs invoking `tsserver-extractor.mjs` against the target and capturing its JSON output

#### Scenario: Next.js project triggers the framework extractor

- **WHEN** the Extraction step runs on a target detected as Next.js
- **THEN** the procedure instructs invoking `nextjs-recipe-extractor.mjs` and capturing its JSON output

### Requirement: Available sources are unioned, never silently degraded

When a deterministic or framework source's preconditions hold, the Extraction step SHALL run it in addition to `llm-assessment` and union all present sources (via `union-extraction.mjs`) into the single document Model consumes. The skill MUST NOT fall back to LLM-only when a deterministic source is available for the stack.

#### Scenario: Deterministic and LLM sources are combined, not chosen between

- **WHEN** both `tsserver` preconditions hold and `llm-assessment` runs
- **THEN** both source outputs are produced and unioned
- **AND** the unioned document — not either source alone — is what Model reads

#### Scenario: No silent LLM-only degradation

- **WHEN** a TypeScript target has `tsconfig.json` present
- **THEN** an assessment run does not complete on LLM-only extraction while skipping the available deterministic source

### Requirement: Extractors are locatable by the invocation instructions

The extractor scripts SHALL reside at the paths named by the Extraction step's run instructions so the commands resolve as written, keeping the scripts and their invocation in sync.

#### Scenario: Named command path resolves to a real script

- **WHEN** the Extraction step names the command to run an extractor
- **THEN** a script exists at that path in the installed skill directory
