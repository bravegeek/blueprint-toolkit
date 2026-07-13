## Context

The extraction format keys every component/contract to a `sourceLocation` (`file#Symbol`), and Pass 4 already uses it as the join key for re-assessment (update-in-place, no duplication). The confidence gap is that Pass 4 tags from whatever source it happened to synthesize the element from, rather than from the reconciled set of sources that describe that `sourceLocation`.

The union contract guaranteed disjointness for **edges** (tsserver owns compiler-resolvable edges; recipes own framework-implicit edges). It never claimed disjointness for **node identity** — and it can't, because `llm-assessment` reads a class/module that `tsserver` also resolves. So the same `sourceLocation` legitimately appears from two sources with two confidences. That overlap is expected; the missing rule is how to tag it.

## Goals / Non-Goals

**Goals**
- A `#provable` element is only ever one a deterministic source actually resolved — and every such element is tagged `#provable`.
- Deterministic confidence is not lost when an LLM source also describes the same symbol.

**Non-Goals**
- Changing edge disjointness or the extraction format.
- Changing what any source emits.
- Promoting INFERRED-only facts (no deterministic source ⇒ stays `#inferred`).

## Decisions

### Reconcile by sourceLocation, tag by strongest claim
Before emitting an element, gather every extraction entry sharing its `sourceLocation` and take the **strongest** confidence: `PROVABLE` (from any deterministic source) beats `INFERRED`. Tag from that. This makes tags a property of the *best available evidence for a location*, which is what confidence-by-construction always intended.

Precedence: `PROVABLE` > `INFERRED` > untagged(developer-confirmed AMBIGUOUS is a separate, later human step and is not overridden here).

### Match, then model — not model, then guess
Reframe the Pass 4 step order: first build the `sourceLocation → {sources, strongest-confidence, evidence}` reconciliation map from the union, *then* synthesize elements against it. The LLM may still author the human-readable title/description, but the **tag** is taken from the map, never from the LLM's own confidence impression.

### Evidence follows the provable claim
When a location is PROVABLE via `tsserver`, carry that source's `file:line` into the element's reasoning/metadata trail so a `#provable` tag is always backed by the evidence that justifies it (no bare `#provable`).

## Risks / Trade-offs

- **Over-promotion** if a source mislabels confidence → mitigated because only *deterministic* sources emit PROVABLE by construction; the reconciliation trusts source type, not LLM self-report (consistent with the existing "not a value an LLM self-reports" rule).
- **Ordering dependence** in the synthesis prose → mitigated by making the reconciliation map an explicit first step, so tagging is deterministic regardless of narration order.

## Migration

None. Re-running `/assessment` re-tags via the reconciliation; existing `#inferred` elements that a deterministic source covers become `#provable` on the next run. sourceLocation match means in-place update, no duplication.
