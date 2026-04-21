---
name: recipe-name
description: One-line — the problem this recipe solves and its shape
uses:
  - skill-name-a
  - skill-name-b
version: 0.1.0
---

# Recipe: {name}

## When to use

{The specific situation this recipe is made for. Be concrete.
Include anti-indicators — situations where this recipe is the
wrong tool, and what to use instead.}

## Prerequisites

{Everything the human or agent must have in hand before step 1:
inputs, access, written artifacts, stack knowledge. If a
prerequisite is a skill output, name the skill.}

## Flow

1. **{Short step name}** — call `/skill-name-a` with `{inputs}`
   - Output: `{artifact path or observation}`
   - Review: `{what to check before continuing}`
2. **{Short step name}** — out-of-band human step, if any
   - ...
3. **{Short step name}** — call `/skill-name-b` with `{inputs from step 1}`
   - Output: `{artifact path}`
   - Review: ...

Steps should be numbered. Mixing skill calls with human steps is
expected — recipes are not required to be pure skill chains.

## Failure modes

{What can go wrong at each step and how to recover.
One bullet per failure, not a narrative.}

- **{step} produces {symptom}** → {remediation}
- **{step} output is {symptom}** → {remediation}

## Examples

(Optional) Short narrative of a real or representative run.

## Variants

(Optional) Named deviations — e.g., "fast path for small specs",
"heavy path when AC list exceeds N items".
