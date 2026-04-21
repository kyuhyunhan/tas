---
name: spec-ci-gates-scaffold
description: >
  Scaffold a CI quality gate set from an acceptance-criteria artifact
  and a tech-spec artifact. Produces a gates document ordered
  fast-to-slow, no-infra-first, with threshold drafts the user can
  tune. Pure transformation: reads both artifacts, writes one gates
  artifact.
  Use when AC artifact (from spec-acceptance-criteria-derive) and
  tech-spec artifact (from spec-tech-scaffold) both exist, and a
  deterministic evaluation frame is needed before writing tests.
  NOT for: writing actual CI YAML (GitHub Actions, GitLab CI, etc.),
  installing tools, running tests, or deriving ACs / tech spec
  themselves. The skill proposes a gate specification; translating
  it to a concrete CI system is a downstream step the user owns.
version: 0.3.0
argument-hint: "[path to AC artifact] [path to tech-spec artifact]"
disable-model-invocation: true
metadata:
  domain: spec
---

# spec-ci-gates-scaffold

Transform an acceptance-criteria list plus tech-stack context into a draft CI quality-gate specification.

This skill scaffolds. It does not execute.
- Do not write CI YAML, shell scripts, or tool configs.
- Do not install or run anything.
- Do not invent thresholds with false precision — mark drafts explicitly.
- Output is a structured gates document, not a working pipeline.

## Scope

**In scope**:
- Projects with any language, any test runner, any CI system. Gate categories are universal; threshold drafts are informed by the tech spec.
- Any set of ACs expressed in Given/When/Then form — typically output of `spec-acceptance-criteria-derive` but any equivalent input works.

**Out of scope**:
- Writing GitHub Actions / GitLab CI / CircleCI YAML. This skill proposes the gate set; the user wires it into their CI.
- Deriving ACs from specs — that is `spec-acceptance-criteria-derive`.
- Deciding the tech stack itself — that is `spec-tech-scaffold`.
- Auditing whether existing tests actually cover ACs — future `effect-verb-audit` skill.
- Tuning thresholds against a live repo. Thresholds here are drafts.

## Input

The user provides:
1. A path to an AC artifact (from `spec-acceptance-criteria-derive` or equivalent).
2. A path to a tech-spec artifact (from `spec-tech-scaffold`) — read for `Language & runtime`, `Test framework`, `CI system`, `Deployment target`, `Architecture posture`.

If the tech-spec artifact is missing, stop and ask the caller to run `spec-tech-scaffold` first. Do NOT accept informal stack notes — the tech-spec artifact is the formal input, and using free-form text instead reintroduces the ambiguity this input change was meant to remove.

If the tech-spec artifact has unresolved items in its `Open decisions` section, proceed but mark the affected gates as `TBD — blocked on tech-spec Open decision: {item}`.

## Gate categories

Gates are ordered **fast-to-slow, no-infra-first** so that cheap checks reject bad changes before expensive checks run.

| Order | Gate            | What it enforces                                                        | Infra? |
|-------|-----------------|-------------------------------------------------------------------------|--------|
| 1     | `static`        | Type check, lint, formatting, duplication, secrets scan                 | no     |
| 2     | `unit`          | Unit tests pass + coverage + assertion density                          | no     |
| 3     | `contracts`     | Every AC ID appears in at least one test describe/it block              | no     |
| 4     | `build`         | Production build succeeds + bundle size ceiling                         | no     |
| 5     | `supply-chain`  | Dependency vulnerability scan + license allowlist                       | no     |
| 6     | `integration`   | Integration tests pass (DB, cache, real adapters)                       | yes    |
| 7     | `e2e`           | End-to-end tests pass (browser, full app)                               | yes    |

A project does not need every gate. Omit any gate that does not apply (e.g., no frontend bundle → drop `build` bundle-size check but keep build itself).

## Process

### Step 1 — Read inputs

Read the AC artifact. Count ACs. Note feature ID(s), any `Open questions`.
Read the tech-spec artifact. Extract: `Language & runtime`, `Test framework` (unit/integration/e2e), `CI system`, `Deployment target`, `Architecture posture`, and any `Open decisions`.

### Step 2 — Select applicable gates

For each of the seven categories, decide: applicable or not applicable, based on the tech spec. A CLI tool with no server, no DB, no frontend (tech spec has no `Key external services` and deployment target is "binary distribution") skips `build` (bundle) and `e2e` entirely. If the tech-spec `Open decisions` block resolution of a gate, mark that gate `TBD — blocked on tech-spec Open decision: {item}`.

### Step 3 — Map ACs to gate layers

For each AC, propose the minimum gate that would verify it:
- Pure logic / validation AC → `unit`
- AC involving DB writes, external APIs → `integration`
- AC involving multi-step user flows → `e2e`

An AC may be verified at multiple layers; record the primary.

### Step 4 — Draft thresholds

For each applicable gate, draft thresholds. Explicitly mark every number as a draft. Reasonable starting points by stack:

- Lint errors: 0. Lint warnings: stack default.
- Coverage (lines/branches): 70% default; 90% for core modules that hold critical logic.
- Assertion density (unit): ≥ 2.0 assertions per test on average.
- Build time ceiling: project-specific — leave as `TBD` unless the user offers a number.
- Bundle size ceiling: project-specific — leave as `TBD`.
- Supply-chain: 0 high-severity vulnerabilities.

### Step 5 — Write the artifact

Write to `.research/spec/gates-{feature-slug}-{YYYY-MM-DD}.md`. Overwrite if same-named file exists.

## Artifact template

```markdown
# CI Gates: {feature name}
Date: {YYYY-MM-DD}
Source AC: {path to AC artifact}
Source tech spec: {path to tech-spec artifact}
Stack summary: {language, test runner, CI — pulled from tech-spec artifact}

## Gate set

Ordered fast-to-slow, no-infra-first.

### 1. static  —  applicable / N/A
**Enforces**: {what}
**Tools**: {e.g., tsc, eslint, prettier, jscpd, gitleaks}
**Thresholds (draft)**:
- lint_errors: 0
- lint_warnings: {N} (draft)
- type_check: pass
- formatting: strict
- duplication_max_rate: {N}% (draft)

### 2. unit
...

### 3. contracts
**Enforces**: every AC ID appears in at least one test `describe` or `it` block.
**Tools**: grep / ripgrep + custom script (or a dedicated AC-coverage library).
**Thresholds**: all AC IDs covered; 0 uncovered.

...

## AC → gate mapping

| AC ID        | Primary gate   | Notes                                   |
|--------------|----------------|-----------------------------------------|
| {FEATURE}-C1 | unit           | pure validation                         |
| {FEATURE}-C2 | integration    | DB write — requires real repository     |
| ...          | ...            | ...                                     |

## Open thresholds

Items the user must decide before the gate set is production-ready:
- Build time ceiling — TBD
- Bundle size ceiling — TBD
- Coverage for module X — TBD

## Not enforced (out of scope)

- {e.g., performance benchmarks, accessibility scans — list if relevant and note why deferred}
```

## Stop conditions

- Every AC is mapped to a primary gate layer.
- Every applicable gate has drafted thresholds (or explicit `TBD`).
- Artifact is written.

Stop there. Do NOT write CI config, install tools, or run anything.

## Decision-point escape — when the user cannot pick threshold values

Some threshold choices are judgment calls that trade off quality against delivery speed (e.g., coverage 70% vs 90%, build time ceiling 60s vs 300s, bundle size 400kb vs 800kb). If the user asks "which threshold should I pick?" and cannot evaluate the tradeoff alone, STOP on that threshold. Do NOT invent a number — leave the field as `TBD` in the artifact, and point the user to the [`consult-fan-out`](../../recipes/consult-fan-out.md) recipe with the likely lenses:

| Threshold type | Likely consult lens(es) |
|----------------|-------------------------|
| Coverage level | `consult-tech` (risk vs. effort), `consult-product` (quality vs. speed) |
| Build/bundle ceilings | `consult-tech` (architecture implications), `consult-ux` (if user-visible perf) |
| Supply-chain severity | `consult-tech` (security posture), `consult-business` (breach cost) |

When the user returns with `response-*` artifacts, re-read the AC artifact plus the consult responses, resolve the `TBD` entries in the gates document, and continue.

## Constraints

- Do NOT produce concrete CI YAML or scripts.
- Do NOT invent thresholds as if they were authoritative — mark drafts.
- Do NOT probe the codebase; stack notes are the only stack input.
- Do NOT re-derive or modify ACs. ACs are read-only input here.
- Each run overwrites the same-named file. No versioned copies.
- Output = structured gates document only.
