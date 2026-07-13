## ADDED Requirements

### Requirement: Domain rules are a first-class, developer-authored element

The model SHALL support a `rule` element kind representing a domain rule, mechanic, policy, or invariant, and a `governs` relationship from a rule to the component(s), contract(s), or command(s) that enforce it. A `rule` is authored from developer input only.

#### Scenario: A rule attaches to its enforcing code

- **WHEN** a developer states a domain rule and identifies the code that enforces it
- **THEN** a `rule` element is emitted with the developer's description
- **AND** a `governs` relationship links it to each enforcing element

#### Scenario: A rule can span multiple enforcing elements

- **WHEN** one rule is enforced across several modules or commands
- **THEN** the single `rule` element carries a `governs` edge to each of them

### Requirement: The skill never infers rule content

The assessment SHALL NOT fabricate, infer, or LLM-author the content of a rule. It may only propose candidate *slots* from structural signals and record what the developer states. A `rule` element MUST NOT be emitted for a rule the developer did not confirm.

#### Scenario: A candidate slot is proposed, not filled

- **WHEN** the skill detects a structural signal suggesting a rule (e.g. a redaction module, an economy command group)
- **THEN** it presents the slot to the developer as a question
- **AND** emits no `rule` element until the developer supplies the rule

#### Scenario: Rules carry no confidence tag

- **WHEN** a `rule` element is emitted
- **THEN** it carries neither `#provable` nor `#inferred`
- **AND** is treated as developer-confirmed (`AMBIGUOUS`-tier) content

### Requirement: Rules render only in opt-in views

Rule elements SHALL appear only in views that explicitly include them (e.g. a `domainRules` view). Architecture views (`index`, `context`, `services`) MUST NOT include `rule` elements, so adding rules cannot alter existing diagrams.

#### Scenario: Architecture views are unaffected

- **WHEN** rules exist in the model
- **THEN** the `index`, `context`, and `services` views render exactly as they did without rules

#### Scenario: A dedicated view shows the domain layer

- **WHEN** a `domainRules` view is generated
- **THEN** it includes `rule` elements and the elements they `govern`
