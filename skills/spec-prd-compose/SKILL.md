---
name: spec-prd-compose
description: >
  Compose a complete PRD through iterative Q&A with a built-in
  eval gate. Reads an optional idea-exploration doc as starter
  context and drills with the user until every criterion in the
  completeness checklist passes. Output is a fully-formed PRD
  that is ready for spec-acceptance-criteria-derive to consume
  at abt-contract-level granularity.
  Use after ios-macos-app-idea-explore (or equivalent idea
  crystallization) when the product direction is fixed but a
  testable PRD does not yet exist.
  NOT for: idea crystallization (that is ios-macos-app-idea-
  explore), AC extraction (that is spec-acceptance-criteria-
  derive), tech-spec scaffolding (that is spec-tech-scaffold),
  or writing acceptance tests directly. The artifact is a PRD
  — features + behaviors + constraints — not tests or code.
version: 0.1.0
argument-hint: "[optional: path to idea-exploration doc]"
disable-model-invocation: true
metadata:
  domain: spec
---

# spec-prd-compose

Compose a complete PRD through iterative Q&A gated by a completeness checklist.

This skill composes. It asks, evaluates, and iterates — it does not draft and stop.
- Do not write a partial PRD and call it done. The eval gate decides doneness.
- Do not invent behaviors the user has not described.
- Do not paraphrase the user's language when they speak precisely; use their words in the PRD.

## Scope

**In scope**:
- Producing a fully-formed PRD as a `.research/spec/prd-{slug}-{YYYY-MM-DD}.md` artifact.
- Iterative Q&A to fill gaps, disambiguate vague behavior, and drill into edge cases.
- Mechanical + semantic eval against a fixed completeness checklist.
- Reading an idea-exploration doc as starter context when present.

**Out of scope**:
- Idea crystallization (should this exist? for whom?) → `ios-macos-app-idea-explore`.
- AC extraction from the PRD → `spec-acceptance-criteria-derive`.
- Tech-stack decisions → `spec-tech-scaffold`.
- Writing tests or code.

## Input

- (Optional) Path to an idea-exploration doc at `.research/ios-macos-app/idea-exploration-{slug}-{YYYY-MM-DD}.md`. If provided, pre-fill Overview / Problem statement / Target user / Out of scope from the doc.
- If no idea-exploration doc, open by asking the user the feature name and a 2-line description; everything else comes from Q&A.

## Process — convergence loop

```
Phase 1: Initial fill
  │  (from idea-exploration doc + minimum user input)
  ▼
Phase 2: Iterative Q&A drill
  │  ◄──── eval gate reports missing / weak items
  │  │
  │  (ask one question at a time,
  │   record answer into the PRD draft,
  │   drill into Functional requirements
  │   with trigger / effect / edge-case structure)
  │  ▼
Phase 3: Eval gate
  │  - run scripts/eval-prd.sh (mechanical)
  │  - run the 8-criterion semantic checklist
  │  ▼
  ├─── all pass → Phase 4 (finalize)
  └─── any fail → Phase 2 (targeted drill on the failed criterion only)

Maximum 5 iterations hard cap.
```

### Phase 1 — Initial fill

Read the idea-exploration doc if one is provided. Pre-fill:

- `Overview` ← from `Idea in one sentence`
- `Problem statement` ← from `Problem statement` (preserve user's words)
- `Target user` ← from `Target user`
- `Out of scope` ← from `Scope boundaries.Out` + `Deferred to future phases`
- `Open questions` ← from `Open questions`

Leave `Functional requirements`, `Non-functional requirements`, `Success metrics`, `Dependencies` empty — these need user Q&A.

If no idea-exploration doc, ask two opening questions only:
1. "One-line description of the feature / product?"
2. "Who is the target user, in one line?"

Everything else comes from Phase 2.

### Phase 2 — Iterative Q&A drill

Rules:
- Ask ONE question at a time. Wait for the user's response before asking the next.
- After each answer, update the PRD draft in memory and announce which section got filled.
- Prioritize `Functional requirements` — this is where abt-contract-level granularity lives.

For each functional requirement, drill until it has **all three**:
1. **Trigger** — the exact condition / user action / system event that initiates
2. **Effect** — the observable result using an asserted verb (`created`, `sent`, `rejected`, `updated`, `deleted`), not a vague verb (`handles`, `works`, `supports`)
3. **Edge cases** — at least TWO of: empty state, boundary values, concurrent conflict, duplicate submission, cross-user access, cascade on delete/update

If the user gives a vague answer, ask a **drilling follow-up**:
- "What exact HTTP status?" / "What does the user see?" / "What happens to the DB record?"
- "What if the input is empty?" / "What if the same request arrives twice?" / "What if another user triggers it simultaneously?"

### Phase 3 — Eval gate

Run both mechanical and semantic checks.

**Mechanical** (via `scripts/eval-prd.sh {prd-path}`):
- All required sections present and non-empty
- Each functional requirement has `Trigger`, `Effect`, `Edge cases` subsections
- Each success metric contains a measurable value AND a time horizon
- `Out of scope` section has at least 3 items

**Semantic** (agent-evaluated 8-criterion checklist, adapted from abt `scope-checklist.yaml` for PRD context):

| # | Criterion | Pass when |
|---|-----------|-----------|
| 1 | Terminology consistency | Product/domain terms used consistently across sections; industry-standard terms (CRUD, REST, auth, idempotent) used correctly |
| 2 | Feature specification granularity | Every functional requirement has Trigger + Effect(asserted verb) + ≥2 edge cases |
| 3 | Input validation enumeration | For every user-facing input, invalid values are enumerated BEFORE valid values |
| 4 | Behavior coverage matrix | Each feature covers happy path + error paths + idempotency + authorization scoping |
| 5 | Effect verb precision | No vague verbs (`handles`, `works`, `supports`, `processes`) in `Effect` fields — only asserted verbs |
| 6 | Non-goals explicit | `Out of scope` enumerates ≥3 concrete exclusions, not "other stuff" |
| 7 | Success metrics measurability | Each success metric has a measurable value + a time horizon + a data source |
| 8 | Internal consistency | Cross-section references resolve: "depends on X" references exist, "see section Y" actually has Y populated |

Output of Phase 3 is a table:

```
| # | Criterion | Status | Gap |
|---|-----------|--------|-----|
| 1 | Terminology consistency       | PASS | — |
| 2 | Feature specification granularity | FAIL | FR-3 has no edge cases |
| ...
```

If all 8 + all mechanical checks pass → Phase 4.
If any fail → Phase 2 with targeted questions for the failed criteria only. Do NOT re-ask answered questions.

### Phase 4 — Finalize

Write the final PRD to `.research/spec/prd-{slug}-{YYYY-MM-DD}.md` with the eval result appended as a trailer:

```markdown
## Eval result
Date: {YYYY-MM-DD HH:mm}
Iterations: {N}
Mechanical script: PASS
Semantic checklist: 8/8 PASS

This PRD meets the spec-prd-compose completeness gate.
```

Point the user to `spec-acceptance-criteria-derive` as the natural next step.

## Document template

```markdown
# PRD: {feature / product name}
Date: {YYYY-MM-DD}
Source idea-exploration: {path or "none"}

## Overview
{2–4 line summary of what this product/feature does.}

## Problem statement
{User's own words — preserve phrasing.}

## Target user
{Primary + secondary, with distinguishing traits.}

## Functional requirements

### FR-1 — {short title}
- **Trigger**: {condition or event}
- **Effect**: {asserted verb + observable outcome}
- **Edge cases**:
  - Empty: {behavior}
  - Boundary: {behavior}
  - Concurrent: {behavior} — if applicable
  - Duplicate: {behavior} — if applicable
  - Cross-user: {behavior} — if applicable
- **Error paths**: {each error condition → structured response + user-visible behavior}

### FR-2 — ...
...

## Non-functional requirements
- Performance: {e.g., initial render < 3s on 4G}
- Security: {e.g., Keychain storage only, no plaintext secrets}
- Accessibility: {e.g., WCAG 2.2 AA for public pages}
- Privacy: {e.g., no PII in logs}

## Dependencies
- Internal: {features / services within this product}
- External: {APIs, SaaS services, SDKs}

## Success metrics
- {Measurable value} over {time horizon} via {data source}
- e.g., "70% of beta users complete onboarding within 5 minutes, measured via analytics event onboarding_completed, over the first 8 weeks of beta"

## Out of scope
- {Concrete exclusion 1}
- {Concrete exclusion 2}
- {Concrete exclusion 3}

## Open questions
- {Unresolved — should shrink with iterations}

## Eval result
{Populated by Phase 4 trailer; present only in final artifact.}
```

## Decision-point escape — when the user cannot evaluate a drill question

If the user cannot answer a functional-requirement drill question because of missing domain knowledge (e.g., "what HTTP status should a quota-exceeded request return?"), do NOT guess. Mark the requirement as OPEN with the specific gap, add it to `Open questions`, and point the user to [`consult-fan-out`](../../recipes/consult-fan-out.md) with the likely lens (`consult-tech` for API conventions, `consult-product` for UX of error states). Resume the loop when the user returns with a consult response.

## Stop conditions

- All 8 semantic criteria PASS.
- Mechanical script PASS.
- User explicitly accepts partial completion with specific items deferred to `Open questions` (escape hatch — note it in Eval result).
- Hard cap: 5 iterations. If not converged, stop with best-effort PRD + list of items that resisted closure.

## Constraints

- Do NOT draft then stop. Iterate until the eval gate passes or the hard cap triggers.
- Do NOT ask multiple questions per turn. One at a time.
- Do NOT rewrite the user's words for functional requirements they stated precisely.
- Do NOT invent features, metrics, or edge cases the user did not describe.
- Do NOT skip the mechanical script — it catches vague verbs and missing subsections that the semantic eval might excuse.
- Each run overwrites the same-named PRD artifact. No versioned copies.
- Output = one complete PRD artifact + Eval result trailer.
