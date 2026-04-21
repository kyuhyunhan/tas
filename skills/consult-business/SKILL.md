---
name: consult-business
description: >
  Business-model and unit-economics lens consultation for a
  decision point raised by a main skill. Applies revenue model,
  LTV/CAC, and pricing-power frameworks to a packaged decision
  request and returns a fixed-shape tradeoff analysis. Pure
  function: reads the request and referenced main artifact, writes
  one response artifact.
  Use when a main-grade skill is blocked on a business decision —
  revenue model shape, unit economics viability, pricing power,
  funding implication — and the user cannot evaluate the options
  alone.
  NOT for: which channel to use for acquisition or which pricing
  tier to design as GTM artifact (use consult-gtm), product scope
  prioritization (use consult-product), tech stack selection
  (use consult-tech). NOT for making the decision — returns
  tradeoff structure, never "you should do X".
version: 0.1.0
argument-hint: "[path to .research/consult/request-*.md]"
disable-model-invocation: true
metadata:
  domain: consult
---

# consult-business

Apply the business-model and unit-economics lens to a packaged decision request.

This skill structures tradeoffs. It does not decide.
- Do not answer questions outside the business-model lens.
- Do not fabricate numbers. If the request lacks the inputs a calculation needs, state that explicitly and qualify the output.
- Do not recommend a single option.

## Scope

**In scope**:
- Revenue model shape — subscription, one-time, transactional, usage-based, marketplace, bundled.
- Unit economics — contribution margin per user, payback period, LTV / CAC.
- Pricing power — willingness-to-pay signals, anchor effects, price elasticity posture.
- Funding implication — self-funded vs. seed vs. revenue-funded, what a given revenue model makes possible or impossible.
- Revenue-mix risk — concentration (one customer, one channel) vs. distribution.
- Switching cost and moat shape — where the durability of revenue comes from.

**Out of scope** (redirect in response):
- Specific price points or tier feature splits as GTM artifacts → `consult-gtm`.
- Product-feature prioritization → `consult-product`.
- Cost of specific tech choices (hosting, licenses) → `consult-tech`.
- Accounting, tax, entity structure — outside TAS scope entirely; advise the user to consult a real accountant.

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

## Frameworks applied (business lens)

- **LTV / CAC** — lifetime value over customer-acquisition cost. Healthy starts at 3:1; payback period < 12 months for most consumer, < 18 months for SMB SaaS.
- **Contribution margin** — revenue per user minus direct variable cost. If negative at steady state, the model does not work without structural change.
- **Pricing power** — Warren Buffett's "if you have to pray before a price increase, you have no pricing power." Signals: switching cost, category inertia, unique value.
- **Revenue model fit to product shape** — transactional for one-shot value; subscription for recurring use; usage-based for variable consumption; marketplace when two-sided network value exists.
- **Revenue-mix risk** — concentration axes (customer, channel, geography). Flag when concentration is > 30% on one axis.
- **Moat typology** — Hamilton Helmer's 7 Powers. Which power, if any, applies here.
- **Funding implication** — bootstrapped viability depends on contribution margin × payback; VC fit depends on market size × growth rate × moat durability.

One to three frameworks per response.

## Artifact

Write to `.research/consult/response-business-{topic}-{timestamp}.md`.

### Fixed response template

Same 5-section template as the `consult-*` family. Sections: `Decision context` / `Options analyzed` / `Tradeoff structure` / `Reframings` / `Out of my lane`.

## Stop conditions

- Response artifact is written.
- Every option in the request is covered.

## Constraints

- Do NOT answer out-of-lane questions.
- Do NOT fabricate LTV, CAC, retention, or revenue numbers. If the request lacks inputs, qualify the analysis.
- Do NOT give tax, accounting, or legal advice. Redirect those to a real professional.
- Do NOT output prose outside the template.
- Each run overwrites the same-named response.
- Output = fixed-template response artifact only.
