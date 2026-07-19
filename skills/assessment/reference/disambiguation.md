# Disambiguation Clarity

Applies to every question put to the developer about an INFERRED or AMBIGUOUS item during Confirm.

Every such question MUST be answerable by someone who does not know this skill's internal modeling vocabulary. For each question, state three things plainly:

1. **What is being decided** — the concrete thing, in the developer's terms (a file, a module, a behavior), not in modeling jargon.
2. **Why it matters** — what the choice changes in the resulting model/diagram.
3. **What each option implies** — spell out the consequence of each choice so the options are distinguishable without inference.

Always present the **explicit options** and **clearly mark the default**. Clarity augments the options; it never replaces them. A developer who accepts the default should be making an informed choice, not defaulting because the question was unclear. If a modeling term is unavoidable, define it inline.

**Before / after (the phrasing bar):**

> ❌ *"Should we model `CampaignAction` and `CampaignState` as contracts?"*
> — assumes the reader knows what "contract" means here and what modeling-vs-not changes.
>
> ✅ *"`CampaignAction` is the list of every action players can take (move token, spend fate, …), and `Room` on the server applies them. Do you want it shown in the diagram as a labelled boundary between the game rules and the server?*
> *• **Yes (default)** — adds one `CampaignAction` box the server and client both point at; makes the rules↔server seam visible.*
> *• No — leaves it out; the diagram stays smaller but the seam is implicit."*
