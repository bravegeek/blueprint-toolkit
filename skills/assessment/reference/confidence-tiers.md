# Confidence Tiers

Every proposed element and relationship carries a confidence tier.

| Tier | Meaning | Examples |
|------|---------|---------|
| `STRUCTURAL` | Directly observable — artifact exists | Table exists, file exists, bucket exists, route defined |
| `PROVABLE` | Derivable with certainty from artifacts | FK relationship, Python import statement, `depends_on` in compose |
| `INFERRED` | Pattern-matched from name + context | "module likely transforms data based on imports and directory name" |
| `AMBIGUOUS` | Cannot determine without domain knowledge | Business purpose, data classification, system boundary ownership |

STRUCTURAL and PROVABLE → auto-stageable. INFERRED → brief confirmation. AMBIGUOUS → explicit developer input. Never ask about STRUCTURAL items — they are ground truth.

## The one rule on PROVABLE facts

**PROVABLE facts are ground truth — do not curate them out.** A component or contract that a deterministic source (e.g. `tsserver`) reports with cross-module import evidence is `PROVABLE`, and PROVABLE ranks with STRUCTURAL as auto-stageable. Every such module MUST be represented by a component, and every such cross-module type (interface *or* discriminated-union `type`) MUST be represented by a contract.

Curating on "primary / significant / it's just a helper" grounds applies **only to INFERRED items** — never to PROVABLE ones. The load-bearing seams of a functional codebase (a reducer, the action/command union it dispatches) are exactly the PROVABLE facts most easily lost to over-curation; they are not optional. You may choose naming, nesting, descriptions, and which INFERRED items to include — you may not choose to omit a PROVABLE cross-module fact.

This is the single canonical statement of the rule; nowhere else in this skill restates it.
