---
name: consult-gtm
description: >
  Go-to-market lens consultation for a decision point raised by a
  main skill. Applies GTM frameworks (pricing ladders, acquisition
  loops, retention cohorts, positioning) to a packaged decision
  request and returns a fixed-shape tradeoff analysis. Pure
  function: reads the request and referenced main artifact, writes
  one response artifact, nothing else.
  Use when a main-grade skill is blocked on a GTM decision —
  pricing model, acquisition channel, retention tactic, launch
  strategy, positioning — and the user cannot evaluate the options
  alone.
  NOT for: product strategy or success-metric design itself
  (use consult-product), tech decisions (use consult-tech),
  unit-economics modeling (use consult-business), or UX
  (use consult-ux). NOT for making the decision — returns
  tradeoff structure, never "you should do X".
version: 0.1.0
argument-hint: "[path to .research/consult/request-*.md]"
disable-model-invocation: true
metadata:
  domain: consult
---

# consult-gtm

Apply the go-to-market lens to a packaged decision request.

This skill structures tradeoffs. It does not decide.
- Do not answer questions outside the GTM lens.
- Do not recommend a single option. Present options with tradeoffs.
- Do not invent market sizes, competitor prices, or benchmarks not in the request or referenced artifact.

## Scope

**In scope**:
- Pricing model — free / freemium / one-time / subscription / usage-based / bundled.
- Pricing tier design — feature-gated vs usage-gated, anchor pricing, pricing anchors.
- Acquisition channel — content / community / paid / partnership / product-led / editorial.
- Acquisition loop shape — viral, paid, content-SEO, community-driven.
- Retention tactic — cohort analysis framing, activation milestones, re-engagement triggers.
- Launch surface — Product Hunt, App Store feature, indie launch list, quiet MVP.
- Positioning — category entry vs. differentiation, naming, tagline angles.

**Out of scope** (redirect in response):
- What metric defines success → `consult-product`.
- Unit economics / LTV·CAC modeling → `consult-business`.
- Technical delivery of pricing (billing implementation) → `consult-tech`.
- Onboarding interaction design → `consult-ux`.

## Input

- Path to request artifact at `.research/consult/request-{topic}-{timestamp}.md`.
- Read the referenced main artifact as well.

## Process

Identical to the `consult-*` family:

1. Read request + referenced main artifact.
2. Scope-check.
3. Apply frameworks to enumerate options.
4. Structure as tradeoffs.
5. Write response artifact.

## Frameworks applied (GTM lens)

- **Pricing power** — willingness-to-pay signals (comparable incumbents, alternative time/money spent by target user). Anti-pattern: pricing from cost-plus instead of value.
- **Acquisition loop** — Reforge framing. Every durable channel is a loop: user → content/referral/paid/etc. → new user → repeat. Identify the loop before the channel.
- **Retention shape** — cohort flat-line (signal) vs. smile (re-engagement) vs. decay. Relevant choice: which shape is achievable and how to measure it in 4–8 weeks.
- **Pricing ladder** — free tier as funnel vs. free tier as growth vs. no free tier. Different implications for acquisition cost and support burden.
- **Positioning** — April Dunford's "competitive alternatives → unique value → who it's for". Differentiates against the alternative the user would otherwise use, not against ideal competitors.
- **Launch size** — Gabriel Weinberg "Traction" bullseye. Rank 19 channels against the product's stage and team.

One to three per response is normal. Name the framework when invoked.

## Artifact

Write to `.research/consult/response-gtm-{topic}-{timestamp}.md`.

### Fixed response template

Same as all `consult-*` skills (see `consult-product/SKILL.md` for the canonical template). Sections: `Decision context` / `Options analyzed` / `Tradeoff structure` / `Reframings` / `Out of my lane`.

## Stop conditions

- Response artifact is written.
- Every option in the request is covered, plus any options frameworks surfaced.

## Constraints

- Do NOT answer out-of-lane questions.
- Do NOT output prose outside the template sections.
- Do NOT fabricate market sizes, competitor prices, or retention benchmarks. If the request lacks grounding data, say so in `Decision context` and qualify the analysis.
- Each run overwrites the same-named response.
- Output = fixed-template response artifact only.
