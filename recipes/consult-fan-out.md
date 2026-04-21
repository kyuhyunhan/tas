---
name: consult-fan-out
description: >
  Spawn one or more consult-* lens skills in parallel when a
  main-grade skill reaches a decision point the user cannot
  evaluate alone. Collect their fixed-shape responses, display
  them verbatim to the user, and hand synthesis back to the main
  skill so it can re-pose the decision with added context.
uses:
  - consult-product
  - consult-gtm
  - consult-ux
  - consult-tech
  - consult-business
  - consult-tech-apple
version: 0.1.0
---

# Recipe: consult-fan-out

## When to use

- A main-grade skill (e.g., `ios-macos-app-idea-explore`) has asked the user to evaluate options at a decision point.
- The user signals they do not have the domain knowledge to evaluate the options alone — explicitly ("I don't know how to judge this") or implicitly (silence, guessing, or asking the skill for the answer).
- The question clearly lies in one or more of the `consult-*` lenses.

**Do not use this recipe when:**
- The user can evaluate the options and simply wants the skill to wait — no consult needed.
- The question is outside every `consult-*` lens's scope (tax, legal, regulated domains). Redirect to a real professional.
- The main skill is itself a `consult-*` skill. Consult skills do not recursively consult; they return `Out of my lane` and let the caller choose.

## Prerequisites

- The main skill is paused at a specific decision point with options enumerated.
- The main skill has an artifact at a known path (typically `.research/{domain}/...`).
- `.research/consult/` exists or can be created.

## Flow

1. **Identify lenses** — read the decision point and list which `consult-*` lenses plausibly apply. Usually 1–3. Prefer too few over too many; extra consults dilute attention.

2. **Package the request** — write one request artifact at
   `.research/consult/request-{topic-slug}-{YYYY-MM-DD-HHmm}.md` with this shape:

   ```markdown
   # Consult request
   Date: {YYYY-MM-DD HH:mm}
   From main skill: {skill name}
   Main artifact: {absolute or repo-relative path}

   ## Decision point
   {The exact question from the main skill, verbatim.}

   ## Options enumerated so far
   - (a) ...
   - (b) ...
   - ...

   ## Relevant snippet from main artifact
   {The passage from the main artifact that sets context. Paste or excerpt.}

   ## Lenses requested
   - consult-product
   - consult-tech-apple

   ## Explicit NON-scope
   {What the consult skills should NOT evaluate — e.g., "do not
   propose new options outside (a)-(f); analyze only these."}
   ```

3. **Fan out** — spawn each named `consult-*` skill as a subagent, each pointed at the same request artifact path. Run them in parallel (single message with multiple subagent invocations).

4. **Collect responses** — each subagent writes to
   `.research/consult/response-{lens}-{topic-slug}-{YYYY-MM-DD-HHmm}.md`. Wait for all.

5. **Display verbatim to the user** — paste each response's body into the main conversation under a clear header per lens. Do NOT summarize, do NOT paraphrase. The user learns the tradeoff structure by reading the frameworks as the consult skill applied them.

6. **Hand back to main skill** — the main skill re-reads its own artifact plus the new `response-*` files, updates its Open Questions / Progress Ledger to absorb the tradeoff structure, and re-poses the decision with the added context. The decision stays with the user.

## Failure modes

- **All consults return mostly `Out of my lane`** → wrong lenses picked. Re-read the decision point, re-select lenses, re-run step 2–5.
- **Consult responses contradict each other** → this is a feature, not a bug. Display both verbatim; the contradiction itself is information. Name the contradiction explicitly when handing back to the main skill.
- **Consult fabricates numbers (market sizes, benchmarks)** → constraint violation. Reject the response, note the issue, and either re-run with tighter request scope or accept the response qualified as "no grounded data".
- **User still cannot decide after seeing tradeoffs** → the decision is genuinely premature. Main skill should note the decision as OPEN in its artifact and advance on tracks that do not depend on it, rather than force closure.
- **Consult response drifts into recommending** ("you should do B") → violates all `consult-*` skills' Constraints. Flag and re-run. Recommending is the user's job.

## Examples

Lexio Q6 (success metric), Q7 (platform), Q8 (Apple framework) from `ios-macos-app-idea-explore`:

- Q6 → request lists lenses `consult-product` + `consult-gtm`. Responses surface that option (a) (dogfooding) measures retention, (b) (beta retention) measures fit, and (e) (MRR) measures willingness-to-pay — three distinct JTBD axes the original question collapsed.
- Q7 → `consult-tech-apple` + `consult-tech`. Apple lens evaluates iOS-vs-macOS capability gate; general tech lens evaluates whether native is even required (web vs native tradeoff).
- Q8 → `consult-tech-apple` alone. Requests concrete framework tradeoffs per the enumerated list (PDFKit, App Intents, CoreML, etc.).

## Variants

- **Single-lens consult** — when only one lens applies, fan-out collapses to a single subagent call. Keep the recipe structure anyway; it preserves the artifact trail.
- **Sequential consult** — when one lens's output is an input to another's (e.g., `consult-product` defines the metric, then `consult-gtm` evaluates channels to move that metric). Run step 3 in two passes instead of parallel.
- **Consult-with-research** — when the decision requires external market data the consult skill would otherwise fabricate, pair fan-out with `/ios-macos-app-market-research` (isolated researcher) *before* the consults. The researcher's observations become part of the `Relevant snippet` in step 2.
