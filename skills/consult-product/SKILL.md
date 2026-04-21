---
name: consult-product
description: >
  Product-lens consultation for a decision point raised by a main
  skill. Applies product-strategy frameworks (JTBD, North Star
  metric, prioritization rubrics) to a packaged decision request
  and returns a fixed-shape tradeoff analysis. Pure function: reads
  the request artifact and any referenced main artifact, writes
  one response artifact, nothing else.
  Use when a main-grade skill is blocked on a product-strategy
  decision — success metrics, target user, scope prioritization,
  positioning relative to adjacent products — and the user cannot
  evaluate the options alone.
  NOT for: technical architecture (use consult-tech),
  go-to-market / pricing (use consult-gtm), UX detail
  (use consult-ux), or Apple-specific platform picks
  (use consult-tech-apple). NOT for making the decision —
  returns tradeoff structure, never "you should do X".
version: 0.1.0
argument-hint: "[path to .research/consult/request-*.md]"
disable-model-invocation: true
metadata:
  domain: consult
---

# consult-product

Apply the product-strategy lens to a packaged decision request.

This skill structures tradeoffs. It does not decide.
- Do not answer questions outside the product-strategy lens.
- Do not recommend a single option. Present options with tradeoffs.
- Do not invent assumptions about the user's business beyond what the request and referenced artifact say.

## Scope

**In scope**:
- North Star / success-metric design — which single number reflects value delivered.
- Target user segmentation — who first, who later, who not.
- Scope prioritization — what to build, drop, defer.
- Positioning against adjacent products — where to compete on feature, where on distribution.
- Job-to-be-Done framing — the underlying job users hire the product for.

**Out of scope** (redirect in response):
- Pricing model, acquisition channel, retention tactics → `consult-gtm`.
- Tech stack, architecture, build-vs-buy → `consult-tech`.
- Interaction patterns, accessibility, user-research methodology → `consult-ux`.
- Unit economics, revenue model, LTV/CAC → `consult-business`.
- Apple-platform framework picks → `consult-tech-apple`.

## Input

- Path to a request artifact at `.research/consult/request-{topic}-{timestamp}.md`.
- The request references the main artifact (e.g., an exploration doc). Read both.

If the request is missing, malformed, or the referenced main artifact is unreadable, stop and ask the caller.

## Process

Five steps, identical across the `consult-*` family:

1. **Read** the request + the referenced main artifact.
2. **Scope-check**: is the question within the product-strategy lens? If partially, note the out-of-lane portion and continue on the in-lane portion. If entirely out of lane, write a minimal response with only `## Out of my lane` populated and stop.
3. **Apply frameworks** (see below) to enumerate options — surface options the request lists, plus any the request missed that the frameworks reveal.
4. **Structure as tradeoffs** — for each option, what it assumes, when it works, when it breaks, rough effort.
5. **Write** the response artifact.

## Frameworks applied (product lens)

- **Jobs-to-be-Done (JTBD)** — Christensen. What job is the user hiring the product for? What job would they fire the product from?
- **North Star metric + input metrics** — single outcome metric with 3–5 leading inputs. Anti-pattern: vanity metrics (downloads, signups without retention).
- **Prioritization** — RICE (Reach × Impact × Confidence / Effort), ICE, or Kano (must-have / performance / delighter). Pick one based on request context.
- **Segmentation** — narrow before broad. First user archetype should be someone the builder can observe directly (dogfooding, close network).
- **Competitive positioning** — Porter's "differentiation vs. cost" or Christensen's "jobs not being done" gap.
- **Retention shape** — flat retention curve after early dropoff indicates product-market signal; ever-declining indicates no signal.

Invoke frameworks by name in the response when relevant; do not dump all of them. One to three per response is normal.

## Artifact

Write to `.research/consult/response-product-{topic}-{timestamp}.md`. Overwrite if same-named file exists. The `{topic}` and `{timestamp}` match the request.

### Fixed response template

```markdown
# Consult response: product lens
Date: {YYYY-MM-DD}
Request: {path to request artifact}
Main artifact: {path referenced by request}

## Decision context
{My read of the situation in ≤ 3 lines.}

## Options analyzed
| Option | Assumes | Works if | Breaks if | Rough effort |
|--------|---------|----------|-----------|--------------|
| A — {label} | {implicit assumption} | {precondition for success} | {failure mode} | {S/M/L} |
| B — ... | ... | ... | ... | ... |

## Tradeoff structure
{The axis along which these options actually differ, in 2–3 lines.
Name the framework invoked: e.g., "JTBD framing: A hires on speed,
B on comprehension."}

## Reframings
{If the request poses the question wrong, restate it here. Optional;
omit if the question is well-framed.}

## Out of my lane
{Portions of the decision that belong to another consult-* skill.
Name the skill. Optional; omit if none.}
```

## Stop conditions

- Response artifact is written.
- Every option in the request is covered in the table, plus any options frameworks surfaced.

Stop there. Do NOT recommend a final pick. Do NOT loop back to ask the main skill for more context; if information is insufficient, write that into the `Decision context` section and proceed with qualified analysis.

## Constraints

- Do NOT answer out-of-lane questions. Redirect via `Out of my lane`.
- Do NOT output free-form prose outside the template sections.
- Do NOT invent numbers, benchmarks, or competitor data that are not in the request or referenced artifact.
- Each run overwrites the same-named response. No versioned copies.
- Output = fixed-template response artifact only.
