# code-level-model

## ADDED Requirements

### Requirement: Code-level element kinds are first-class in the base specification
The canonical element specification (`blueprint/model/system.c4`) SHALL declare `component`, `contract`, and `spec` element kinds, `defines` and `implements` relationship kinds, and `inferred` and `provable` confidence tags unconditionally, so that both the assessment and blueprint-change skills can rely on their existence in every installed project.

#### Scenario: Fresh install includes code-level kinds
- **WHEN** `install.sh` copies the toolkit into a project
- **THEN** the installed `system.c4` specification declares `component`, `contract`, `spec`, `defines`, and `implements` without any skill having run

#### Scenario: Existing project upgraded additively
- **WHEN** `install.sh` is re-run against a project whose model already contains elements
- **THEN** the new kinds are available and all pre-existing elements, relationships, and views remain valid

### Requirement: Code-level elements carry sourceLocation metadata
Every `component` and `contract` element SHALL carry a `sourceLocation` metadata field of the form `<repo-relative-path>#<SymbolName>` identifying the file and symbol it models.

#### Scenario: Component proposed by assessment
- **WHEN** the assessment skill proposes a `component` element for class `PipelineRunner` defined in `src/pipeline/runner.py`
- **THEN** the proposed element includes `metadata { sourceLocation 'src/pipeline/runner.py#PipelineRunner' }`

#### Scenario: sourceLocation is the identity anchor on re-assessment
- **WHEN** assessment runs again and finds a symbol whose `sourceLocation` matches an existing element
- **THEN** the existing element is updated in place rather than a duplicate being created

### Requirement: Components nest under their parent service
`component` elements SHALL be declared inside the `service` (or `script`) element they belong to, and `contract` elements inside the module or service that defines them, so identifiers are scoped and views stay bounded.

#### Scenario: Same class name in two services
- **WHEN** two services each export a class named `Client`
- **THEN** the model contains two distinct nested elements (e.g., `api.Client` and `worker.Client`) with no identifier collision

### Requirement: Per-service code-structure views
`blueprint/model/views.c4` SHALL provide a `codeStructure` view template scoped to a single service, showing its components, the contracts they define or implement, and cross-module edges. Global (all-services) code-level views SHALL NOT be generated.

#### Scenario: View generated for a service with components
- **WHEN** a service element contains one or more `component` children
- **THEN** a `codeStructure` view exists for that service showing only that service's components, their contracts, and edges crossing that service's boundary
