## ADDED Requirements

### Requirement: Disambiguation questions state the decision, stakes, and per-option implications

Whenever the assessment asks the developer to resolve an `INFERRED` or `AMBIGUOUS` item, each question SHALL state plainly, in developer-facing language: (1) what is being decided, (2) why it matters — what it changes in the resulting model, and (3) what each option implies. Questions MUST NOT assume the developer already knows the internal modeling vocabulary.

#### Scenario: A question is understandable without modeling expertise

- **WHEN** the skill surfaces an INFERRED or AMBIGUOUS item for developer input
- **THEN** the question names the concrete thing being decided and the consequence of the choice
- **AND** does not require the developer to know internal terms to answer correctly

#### Scenario: Each option carries its implication

- **WHEN** options are presented
- **THEN** each option states what choosing it will do to the model (e.g. "adds a contract node X", "leaves it out")
- **AND** the developer can tell the options apart without inferring the difference

### Requirement: Options and a marked default are always presented

The clarity requirement SHALL augment, not replace, the existing option-presentation. Every disambiguation question SHALL still present the explicit options and clearly mark which one is the default if the developer does not choose.

#### Scenario: Options remain explicit

- **WHEN** a disambiguation question is asked
- **THEN** the discrete options are listed explicitly
- **AND** the default option is clearly marked as the default

#### Scenario: The default is a deliberate choice, not a fallback for confusion

- **WHEN** a developer accepts the default
- **THEN** the question has already made clear what accepting the default means
- **AND** taking the default is an informed choice, not a consequence of an unclear question
