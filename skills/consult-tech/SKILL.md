---
name: consult-tech
description: >
  General technology lens consultation for a decision point raised
  by a main skill. Applies architecture, stack selection, and
  build-vs-buy frameworks to a packaged decision request and
  returns a fixed-shape tradeoff analysis. Platform-agnostic
  (non-Apple-specific). Pure function: reads the request and
  referenced main artifact, writes one response artifact.
  Use when a main-grade skill is blocked on a general tech
  decision — language/framework choice, data model, sync/async
  boundary, native vs web vs cross-platform — and the user cannot
  evaluate the options alone.
  NOT for: Apple-platform framework specifics (use
  consult-tech-apple), product strategy (use consult-product),
  UX pattern (use consult-ux), unit economics of a tech pick
  (use consult-business). NOT for making the decision — returns
  tradeoff structure, never "you should do X".
version: 0.1.0
argument-hint: "[path to .research/consult/request-*.md]"
disable-model-invocation: true
metadata:
  domain: consult
---

# consult-tech

Apply the general-technology lens to a packaged decision request.

This skill structures tradeoffs. It does not decide.
- Do not answer Apple-platform-specific questions — those are `consult-tech-apple`'s.
- Do not recommend a single option.
- Do not write code, config, or architecture diagrams.

## Scope

**In scope**:
- Language and framework selection across platforms.
- Native vs. web vs. cross-platform (Flutter / React Native / Electron / Tauri) for a given product shape.
- Client/server architecture — monolith / modular monolith / service-oriented / edge / serverless.
- Data model choices — relational vs. document vs. key-value, schema migration posture, event-sourcing vs CRUD.
- Sync vs. async boundaries — queue placement, eventual consistency posture.
- Build vs. buy for infrastructure components (auth, payments, search, observability).
- Testing topology — where unit / integration / e2e boundaries sit.

**Out of scope** (redirect in response):
- Apple-specific frameworks (HealthKit, App Intents, SwiftUI vs AppKit, Mac Catalyst) → `consult-tech-apple`.
- Which feature to build at all → `consult-product`.
- UI interaction patterns → `consult-ux`.
- Pricing impact of hosted vs. self-hosted → `consult-business`.

## Input

- Path to request artifact at `.research/consult/request-{topic}-{timestamp}.md`.
- Read the referenced main artifact.

## Process

Identical to the `consult-*` family:

1. Read request + referenced main artifact.
2. Scope-check.
3. Apply frameworks.
4. Structure as tradeoffs.
5. Write response artifact.

## Frameworks applied (general tech lens)

- **CAP and PACELC** — for distributed data decisions, name the explicit partition/latency/consistency tradeoff.
- **Two-way vs one-way doors** — Bezos framing. Reversible choices get fast, irreversible choices get careful.
- **Architecture Decision Record (ADR) heuristics** — context, options, consequences. Shape the options table accordingly.
- **Conway's law** — system shape mirrors team/ownership shape. Flag when a proposed architecture implies a team structure the user doesn't have.
- **Build vs. buy cost axes** — total cost = license + integration + maintenance + switch cost + opportunity. Don't let license price dominate.
- **Maturity vs. leverage** — pick boring technology for the core, novel technology where differentiation lives (Dan McKinley "choose boring technology").
- **Failure domain sizing** — a good architecture keeps blast radius per failure small. Name the domains.

One to three frameworks per response. Name them when invoked.

## Artifact

Write to `.research/consult/response-tech-{topic}-{timestamp}.md`.

### Fixed response template

Same 5-section template as the `consult-*` family. Sections: `Decision context` / `Options analyzed` / `Tradeoff structure` / `Reframings` / `Out of my lane`.

## Stop conditions

- Response artifact is written.
- Every option in the request is covered.

## Constraints

- Do NOT address Apple-specific platform questions. Redirect to `consult-tech-apple`.
- Do NOT write code or architecture diagrams.
- Do NOT output prose outside the template.
- Do NOT inflate effort estimates beyond S/M/L categories unless the request provides concrete team/time context.
- Each run overwrites the same-named response.
- Output = fixed-template response artifact only.
