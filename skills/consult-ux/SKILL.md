---
name: consult-ux
description: >
  UX lens consultation for a decision point raised by a main skill.
  Applies user-research, interaction-design, and accessibility
  frameworks to a packaged decision request and returns a
  fixed-shape tradeoff analysis. Pure function: reads the request
  and referenced main artifact, writes one response artifact.
  Use when a main-grade skill is blocked on a UX decision —
  interaction flow, information density, accessibility trade,
  research methodology — and the user cannot evaluate the options
  alone.
  NOT for: product strategy (use consult-product), technical
  implementation of UI (use consult-tech or consult-tech-apple),
  pricing/onboarding GTM (use consult-gtm). NOT for making the
  decision — returns tradeoff structure, never "you should do X".
version: 0.1.0
argument-hint: "[path to .research/consult/request-*.md]"
disable-model-invocation: true
metadata:
  domain: consult
---

# consult-ux

Apply the UX lens to a packaged decision request.

This skill structures tradeoffs. It does not decide.
- Do not answer questions outside the UX lens.
- Do not produce wireframes, mockups, or concrete copy. Return tradeoffs only.
- Do not invoke accessibility rules loosely; when you cite WCAG, cite the specific criterion.

## Scope

**In scope**:
- Interaction flow shape — modal vs inline, one-screen vs progressive disclosure, reversibility.
- Information density — when to compress, when to expand, when to chunk.
- Mental-model alignment — does the proposed flow match how users already think about this task?
- User-research methodology — how to validate the proposed design cheaply (5-user tests, diary study, concept test).
- Accessibility tradeoffs — WCAG 2.x levels, touch target sizing, contrast, motion sensitivity.
- Cognitive load — Miller's 7±2, Hick's law, Fitts's law as they apply to the decision.

**Out of scope** (redirect in response):
- Strategic prioritization of which feature first → `consult-product`.
- Platform-specific UI idioms on Apple → `consult-tech-apple`.
- Cross-platform UI technology choice → `consult-tech`.
- Pricing page layout as GTM artifact → `consult-gtm`.

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

## Frameworks applied (UX lens)

- **Nielsen's 10 usability heuristics** — name which heuristic each option preserves or violates.
- **Cognitive load principles** — Miller 7±2, Hick's law (decision time grows with option count), Fitts's law (target size × distance).
- **JTBD interview methodology** — when research is requested, prefer JTBD-style "tell me about the last time you …" over satisfaction scales.
- **WCAG 2.2** — cite specific success criteria (e.g., 1.4.3 Contrast, 2.5.5 Target Size) rather than "accessibility".
- **Progressive disclosure** — default to the 80% path, reveal the long tail on demand. Used for density decisions.
- **Error prevention vs. recovery** — prefer prevention (constraint) when the action is destructive, prefer recovery (undo) when reversible.
- **Mental model mapping** — Norman's conceptual model vs. system model. Flag where the proposed flow forces a user mental-model switch.

One to three per response. Name the framework when invoked.

## Artifact

Write to `.research/consult/response-ux-{topic}-{timestamp}.md`.

### Fixed response template

Same 5-section template as the `consult-*` family (see `consult-product/SKILL.md`). Sections: `Decision context` / `Options analyzed` / `Tradeoff structure` / `Reframings` / `Out of my lane`.

## Stop conditions

- Response artifact is written.
- Every option in the request is covered.

## Constraints

- Do NOT answer out-of-lane questions.
- Do NOT produce visual mockups or UI copy.
- Do NOT output prose outside the template.
- Cite WCAG success criteria by number, not generic "accessibility".
- Each run overwrites the same-named response.
- Output = fixed-template response artifact only.
