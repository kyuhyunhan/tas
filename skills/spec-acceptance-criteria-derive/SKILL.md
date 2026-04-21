---
name: spec-acceptance-criteria-derive
description: >
  Derive Given/When/Then acceptance criteria from a PRD, user story,
  RFC, or written product spec. Produces a structured AC document
  with stable IDs, one AC per observable behavior. Pure transformation:
  reads only the provided spec, writes only the AC artifact.
  Use when starting implementation of a new feature, hardening an
  existing feature that has no test-grounded AC list, or preparing
  input for downstream test and gate scaffolding.
  NOT for: proposing tests, writing code, suggesting architecture,
  evaluating whether the spec itself is good, or discovering specs
  in the codebase. The spec is the input; the skill does not hunt
  for it.
version: 0.1.0
argument-hint: "[path to spec file or pasted spec text]"
disable-model-invocation: true
metadata:
  domain: spec
---

# spec-acceptance-criteria-derive

Transform a product spec into a list of testable acceptance criteria in Given/When/Then form.

This skill extracts. It does not invent. Every AC must trace to text in the spec.
- Do not propose features the spec does not mention.
- Do not propose implementation details.
- Do not evaluate the spec as good or bad.
- Output is a structured AC document, not a recommendation.

## Scope

**In scope**:
- PRDs, feature specs, user stories, RFCs, design docs — any written description of intended product behavior.
- Any domain (web, mobile, embedded, data pipelines). AC format is language- and stack-agnostic.

**Out of scope**:
- Proposing tests, test frameworks, or test data.
- Proposing CI gates, coverage thresholds, or gate scripts — that is `spec-ci-gates-scaffold`.
- Auditing whether existing tests cover the ACs — that is a future `effect-verb-audit` skill.
- Deriving ACs from code that has no accompanying spec. If no written spec exists, ask the user to write or paste one.

## Input

The user provides one of:
- A path to a local spec document (markdown, plain text, PDF text extract).
- Pasted spec text inline.

If the input is missing or ambiguous, ask the user to provide the spec. Do not guess.

## Acceptance criterion format

Each AC has five fields:

| Field        | Purpose                                                                  |
|--------------|--------------------------------------------------------------------------|
| `id`         | Stable grep-able ID: `{FEATURE}-C{N}` (e.g., `LOGIN-C1`, `LOGIN-C2`)      |
| `given`      | Precondition — state of the world before the trigger                     |
| `when`       | Trigger — the action or event under test                                 |
| `then`       | Observable effect — what must be true after the trigger                  |
| `boundary`   | Conditions under which the AC applies (null = always). Optional.         |

The `then` field uses **effect verbs** that can be asserted directly in a test: `created`, `returned`, `rejected`, `updated`, `sent`, `deleted`. Avoid vague verbs like `supports`, `handles`, `works`.

## Process

### Step 1 — Feature framing

Read the spec end-to-end. Identify the **feature** being specified. Choose a short uppercase feature ID (e.g., `LOGIN`, `BOOKING`, `INVITE`) derived from the spec's own language.

If the spec covers multiple features, ask the user which feature to scope to, or confirm that all features should be processed. One feature per run is the default.

### Step 2 — Extract behaviors

Scan the spec for statements that describe observable product behavior. Candidates usually contain:
- Action verbs tied to a user or system actor.
- Conditional phrases ("if ...", "when ...", "on ...").
- State change language ("is created", "becomes visible", "is sent").
- Error conditions ("returns 400", "shows error", "rejects").

Each behavior becomes one candidate AC.

### Step 3 — Normalize to Given/When/Then

For each candidate behavior:
1. Name the **when** (the trigger) as a concrete event: API call, user action, scheduled job, etc.
2. Name the **then** (the effect) using an asserted verb.
3. Name the **given** (the precondition) as minimal context — the smallest state that makes the trigger meaningful.
4. If the behavior applies only under certain conditions, extract those into **boundary**.

If a single candidate splits into multiple effect verbs, split it into multiple ACs. One AC, one assertable effect.

### Step 4 — Coverage probe (one-pass Socratic)

Before finalizing, scan the AC list for common gaps. Ask the user **only** about gaps that are genuinely ambiguous in the spec — do not invent ACs. Typical probes:

- Error cases: does the spec mention what happens on invalid input? If silent, flag as OPEN.
- Boundary values: does the spec specify behavior at min/max values? If silent, flag as OPEN.
- Idempotency: for mutating actions, is repeat behavior specified? If silent, flag as OPEN.
- Ownership: for scoped data, is cross-user access specified? If silent, flag as OPEN.

Flagged OPEN items go into the `Open questions` section of the artifact, not into ACs.

### Step 5 — Write the artifact

Write to `.research/spec/ac-{feature-slug}-{YYYY-MM-DD}.md`. Overwrite if a file with the same name exists.

## Artifact template

```markdown
# Acceptance Criteria: {feature name}
Date: {YYYY-MM-DD}
Source: {spec path or "pasted inline"}
Feature ID: {FEATURE}

## Summary
{one paragraph — what this feature does, in the spec's own terms}

## Acceptance criteria

### {FEATURE}-C1 — {short description}
- **Given**: {precondition}
- **When**: {trigger}
- **Then**: {effect with asserted verb}
- **Boundary**: {condition or "always"}
- **Source**: {quote or paraphrase from the spec — line or section reference if possible}

### {FEATURE}-C2 — ...
...

## Open questions
- {spec is silent on X — confirm with product before writing test Y}
- ...

## Not in scope
- {behaviors the spec explicitly excludes, if any}
```

## Stop conditions

- All extracted behaviors are normalized into ACs.
- All gaps are either resolved by the user or flagged as OPEN.
- Artifact is written.

Stop there. Do NOT proceed to propose tests, gates, or implementation. The user decides what happens next — typically `spec-ci-gates-scaffold` (see `recipes/spec-to-gates.md`), but that is the user's choice.

## Constraints

- Do NOT invent behaviors not present in the spec.
- Do NOT propose implementation, architecture, or technology choices.
- Do NOT evaluate the spec's quality.
- Do NOT write tests or test code.
- Each run overwrites the same-named file. No versioned copies.
- One feature per run is the default.
- Output = structured AC document only.
