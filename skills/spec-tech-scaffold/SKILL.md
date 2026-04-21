---
name: spec-tech-scaffold
description: >
  Scaffold a language/domain/system-specific tech spec document
  from an acceptance-criteria artifact and optional idea-exploration
  context. Produces a fixed-section draft covering target platforms,
  language and runtime, test framework, CI system, external
  services, deployment target, and architecture posture. Pure
  function: reads upstream artifacts, writes one tech-spec artifact.
  Use after spec-acceptance-criteria-derive and before
  spec-ci-gates-scaffold — the tech spec is the formal input the
  gates skill consumes instead of informal stack notes.
  NOT for: making tech decisions on the user's behalf, installing
  tools, generating code, or locking in choices without user review.
  The skill drafts options with rationale; the user decides.
version: 0.1.0
argument-hint: "[path to AC artifact] [optional: path to idea-exploration doc]"
disable-model-invocation: true
metadata:
  domain: spec
---

# spec-tech-scaffold

Draft a language/domain/system-specific tech spec from an AC artifact and optional idea-exploration context.

This skill scaffolds. It does not decide.
- Do not install tools, run scripts, or write code.
- Do not lock in a single choice without listing plausible alternatives and a rationale.
- Do not invent constraints not present in the upstream artifacts. If the AC does not imply a constraint, say so.

## Scope

**In scope**:
- Drafting a fixed-section tech spec document informed by AC behaviors and, when available, idea-exploration platform/framework notes.
- Enumerating plausible options per section with short rationale.
- Flagging open decisions that require consult-fan-out or user input.

**Out of scope**:
- Derive ACs from a PRD → `spec-acceptance-criteria-derive`.
- Scaffold CI gates from AC + tech spec → `spec-ci-gates-scaffold`.
- Consultation on which option to pick when the user cannot evaluate → `consult-tech`, `consult-tech-apple` via `consult-fan-out`.
- Actual implementation, tooling install, repo init.

## Input

Required:
- Path to an AC artifact at `.research/spec/ac-{slug}-{YYYY-MM-DD}.md`.

Optional:
- Path to an idea-exploration doc at `.research/ios-macos-app/idea-exploration-{slug}-{YYYY-MM-DD}.md` (or equivalent). When present, read the `Platform strategy` and any `Apple framework leverage` sections to inform platform/framework sections.

If the AC artifact is missing, stop and ask the caller. Do not proceed with pure idea-exploration input — AC behaviors are the anchor that keeps tech decisions honest.

## Process

Five steps:

1. **Read** the AC artifact + optional idea-exploration doc.
2. **Extract constraints** — for each section of the template (see below), identify which ACs imply a constraint. Example: an AC that writes to a database implies a persistence decision; an AC that runs in the browser implies a client runtime.
3. **Enumerate options** — per section, list 1–3 plausible choices grounded in extracted constraints + idea-exploration context.
4. **Rationalize** — for each option, a one-line why. Flag sections where the user cannot choose without consult input.
5. **Write** the artifact.

## Artifact

Write to `.research/spec/tech-{slug}-{YYYY-MM-DD}.md`. Overwrite if same-named file exists. Slug matches the AC artifact slug.

### Fixed tech-spec template

```markdown
# Tech Spec: {feature / project name}
Date: {YYYY-MM-DD}
Source AC: {path}
Source idea-exploration: {path or "none"}

## Target platforms
- Primary: {e.g., macOS 14+, web browser, iOS 17+}
- Secondary: {if any}
- Rationale: {which ACs / idea-exploration notes drive this}

## Language & runtime
- Language: {e.g., Swift 5.9, TypeScript 5, Python 3.12}
- Runtime: {e.g., native binary, Node 20, Bun, Lambda}
- Rationale: {...}
- Alternatives considered: {1–2, with why not}

## Test framework
- Unit: {e.g., Swift Testing, vitest, pytest}
- Integration: {if applicable}
- E2E: {if applicable, e.g., Playwright, XCUITest}
- Rationale: {...}

## CI system
- Host: {e.g., GitHub Actions, GitLab CI, self-hosted}
- Notable constraints: {e.g., macOS runners required, private runner needed}

## Key external services
- {Service category}: {choice} — {rationale}
  (e.g., DB: PostgreSQL, Auth: Supabase, LLM: OpenAI API proxy, Storage: S3)
- List only services implied by ACs. If an AC implies a service category
  but no specific choice is obvious, mark as OPEN and name the consult
  lens most likely to resolve (`consult-tech`, `consult-business` for
  cost-dominant picks).

## Deployment target
- {e.g., Mac App Store, TestFlight, AWS Lambda + API Gateway,
  Vercel, Fly.io, self-hosted VPS}
- Rationale: {...}

## Architecture posture
- Primary pattern: {e.g., 3-layer client, modular monolith server,
  event-driven with queue, serverless functions}
- Key invariants: {e.g., "no business logic in route handlers",
  "persistence only in repository files"}
- Rationale: {...}

## Open decisions
- {section name}: {the undecided question} → likely consult lens
- ...
  (This section lists items the user must resolve before
  spec-ci-gates-scaffold can produce concrete thresholds. If empty,
  the tech spec is ready for gates scaffolding.)
```

## Stop conditions

- Every template section is populated or explicitly marked `N/A` with justification.
- Every option has a one-line rationale.
- `Open decisions` is either empty or lists concrete items with lens suggestions.
- Artifact is written.

Stop there. Do NOT proceed to scaffold gates, install tools, or write code.

## Decision-point escape — when the user cannot choose a section's option

If the user cannot evaluate the enumerated options for a section (e.g., "PostgreSQL vs. DynamoDB — I don't know which is right here"), do not force a pick. Leave the section as OPEN in the artifact with the enumerated alternatives preserved, add the item to `Open decisions` with the likely consult lens, and point the user to the [`consult-fan-out`](../../recipes/consult-fan-out.md) recipe.

Typical mapping:

| Section | Likely consult lens(es) |
|---------|-------------------------|
| Target platforms | `consult-tech-apple`, `consult-tech` |
| Language & runtime | `consult-tech` |
| Test framework | `consult-tech` |
| CI system | `consult-tech` |
| Key external services | `consult-tech` (architecture), `consult-business` (cost) |
| Deployment target | `consult-tech`, `consult-business` |
| Architecture posture | `consult-tech`, `consult-tech-apple` (if Apple) |

When the user returns with consult `response-*` artifacts, re-read this tech-spec artifact plus the responses, resolve the OPEN items by updating the relevant sections, and remove them from `Open decisions`.

## Constraints

- Do NOT pick an option unilaterally when the user cannot evaluate.
- Do NOT invent services/frameworks not grounded in AC constraints or idea-exploration notes.
- Do NOT output prose outside the template sections.
- Do NOT write code, config files, or tool-specific manifests.
- Each run overwrites the same-named artifact. No versioned copies.
- Output = fixed-template tech-spec artifact only.
