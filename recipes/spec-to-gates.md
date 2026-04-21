---
name: spec-to-gates
description: >
  Turn a PRD (or equivalent written spec) into a test-grounded
  acceptance-criteria list and a deterministic CI quality-gate set,
  ready to drive TDD + eval iteration.
uses:
  - spec-acceptance-criteria-derive
  - spec-ci-gates-scaffold
version: 0.1.0
---

# Recipe: spec-to-gates

## When to use

- Starting a greenfield feature or module and wanting TDD rails before writing code.
- Hardening an existing feature whose tests are implicit, informal, or absent.
- Preparing for an `eval`-driven iteration loop: every change must pass a deterministic gate set grounded in named ACs.

**Do not use this recipe when:**
- There is no written spec. The recipe starts at a document, not an idea. For idea crystallization, use `/ios-macos-app-idea-explore` (or its future successor in your domain) first.
- The feature is throwaway or exploratory. Gate scaffolding has a cost; pay it only when the feature earns repeated iteration.
- You only want AC extraction without gates. Call `/spec-acceptance-criteria-derive` directly and stop after step 2 below.

## Prerequisites

- A written spec: PRD, RFC, feature doc, or user-story collection. Ink-on-page, not a verbal pitch.
- Brief tech-stack context you can hand to step 3: primary language, test runner, CI system.
- Write access to `.research/spec/` in the project root.

## Flow

1. **Derive acceptance criteria** — call `/spec-acceptance-criteria-derive` with the spec path.
   - Output: `.research/spec/ac-{feature-slug}-{YYYY-MM-DD}.md`
   - Review:
     - Every AC has a concrete `when` trigger and an asserted-verb `then` effect.
     - `Open questions` section lists any spec gaps — resolve these with product before moving on, or accept them and proceed knowing those ACs will be missing.

2. **Reject and refine** — human step.
   - Read each AC critically. Drop ACs that duplicate, merge ACs that split an atomic behavior artificially, split ACs that bundle multiple effect verbs.
   - Re-run step 1 if the revision is large. The skill overwrites the same file.

3. **Scaffold CI gates** — call `/spec-ci-gates-scaffold` with the AC artifact path plus your stack notes.
   - Output: `.research/spec/gates-{feature-slug}-{YYYY-MM-DD}.md`
   - Review:
     - Every AC is mapped to a primary gate layer.
     - Thresholds marked as drafts are realistic for your project's scale.
     - `Open thresholds` section lists decisions you need to make before wiring gates in.

4. **Implement TDD-style** — human / agent loop.
   - For each AC, write a failing test whose `describe` or `it` block contains the AC ID (e.g., `describe("LOGIN-C1: ...")`).
   - Make the test pass. Refactor. Move to the next AC.

5. **Wire gates into CI** — human step.
   - Translate the gates document into your CI system's concrete config (GitHub Actions workflow, GitLab CI, etc.).
   - Resolve `TBD` thresholds against your actual build.
   - Add a gate-failure script that enumerates uncovered AC IDs — the `contracts` gate in the document.

## Failure modes

- **AC list is too abstract (every `then` says "works correctly")** → the source spec is vague. Either ask product to tighten the spec, or scope this recipe to a narrower sub-feature where the spec has concrete verbs.
- **AC list is too long (30+ ACs)** → the feature is probably multiple features bundled. Split the spec and run the recipe per sub-feature.
- **Gates draft blocks developer flow in practice** → tune thresholds, never remove gates. If `unit` coverage at 70% is blocking, lower to 60% with a written note in the gates artifact; do not silently delete the check.
- **Tests pass but feature is broken in production** → AC set had a gap. Add an AC, re-run step 1 or edit the artifact directly, add the corresponding test, re-run gates. Prefer the regenerate-AC path when the spec itself was updated.
- **AC IDs drift between tests and artifact** → treat the AC artifact as source-of-truth. Rename tests, do not rename ACs.

## Examples

A team spec'd a "team invitation" feature:
- `/spec-acceptance-criteria-derive` produced 8 ACs (`INVITE-C1..C8`) including invite sent, invite accepted, expired invite rejection, duplicate invite rejection.
- Review dropped 1 duplicate AC, split 1 AC into two (send-email effect + DB-record effect).
- `/spec-ci-gates-scaffold` proposed `static + unit + contracts + integration + e2e`. Build/supply-chain gates skipped; the feature had no new dependencies.
- TDD loop used AC IDs in describe blocks. CI contracts gate failed until all 9 IDs appeared in at least one test.
- Total time from spec to passing CI: under one day for an experienced engineer.

## Variants

- **Fast path** — if the spec is a single-screen feature with < 5 behaviors, skip step 2 (review) and iterate directly in step 4; the AC-vs-test alignment will surface problems fast.
- **No integration infra** — pure library / CLI projects skip `integration` and `e2e` gates; the scaffolding will already omit them if the stack notes say so.
- **Audit-only** — if tests already exist, skip step 4 and run a future `effect-verb-audit` skill against the AC artifact to find misalignments.
