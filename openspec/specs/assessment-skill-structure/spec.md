# assessment-skill-structure

## Purpose

Defines the structure of the assessment skill's `SKILL.md`: a lean, decidable runtime procedure with reference material split out into a `reference/` subtree, so the skill is followable step-by-step without prose interpretation and without duplicated normative rules.

## Requirements

### Requirement: Lean runtime procedure separated from reference material

The assessment skill's `SKILL.md` SHALL contain the runtime procedure only, with reference material (confidence-tier definitions, the extraction-format spec, disambiguation and domain-rule guidance, and stack-specific probe code) held in a `reference/` subtree consulted on demand. `SKILL.md` SHALL link to that material rather than inlining it.

#### Scenario: Procedure body does not inline reference detail

- **WHEN** `SKILL.md` is reviewed after the split
- **THEN** stack-specific probe code, the extraction-format JSON spec, and the confidence-tier table live under `reference/`
- **AND** `SKILL.md` references them by path instead of embedding them

#### Scenario: Reference material remains reachable

- **WHEN** the agent needs a confidence-tier definition or a stack probe while running a pass
- **THEN** `SKILL.md` names the exact `reference/` file to consult

### Requirement: Each pass is a decidable step with explicit contracts

Every pass in `SKILL.md` SHALL be expressed as an imperative step stating its input, the action to run, the output it produces, and a done-when condition, so that following it (or failing to) is observable rather than a matter of prose interpretation.

#### Scenario: A pass states its output contract and done condition

- **WHEN** a reader examines any of the four passes
- **THEN** the pass names the input it consumes, the command(s) to run, the structured output it must produce, and the condition under which the pass is complete

### Requirement: No behavioral rule is stated more than once

Each normative rule in the assessment skill SHALL appear exactly once as a single canonical statement; the previously repeated warnings (e.g. "do not curate out PROVABLE facts") SHALL be consolidated.

#### Scenario: A previously repeated warning appears once

- **WHEN** `SKILL.md` is searched for the "do not curate out PROVABLE" rule
- **THEN** it appears as a single canonical statement, not repeated across multiple sections
