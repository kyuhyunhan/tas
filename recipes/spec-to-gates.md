---
name: spec-to-gates
description: >
  Turn a PRD (or equivalent written spec) into an acceptance-criteria
  list, a language/domain/system-specific tech spec, and a
  deterministic CI quality-gate set — ready to drive TDD + eval
  iteration.
uses:
  - spec-acceptance-criteria-derive
  - spec-tech-scaffold
  - spec-ci-gates-scaffold
version: 0.2.0
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
  - **If no PRD exists yet** but you have an idea-exploration doc, run `/spec-prd-compose` first to produce one. It iterates with Q&A + an eval gate until the PRD meets the completeness checklist.
- (Optional) An idea-exploration doc from `/ios-macos-app-idea-explore` in `.research/ios-macos-app/` — if present, `/spec-prd-compose` consumes it as starter context, and `/spec-tech-scaffold` consumes it for platform/framework context.
- Write access to `.research/spec/` in the project root.

## Flow

1. **Derive acceptance criteria** — call `/spec-acceptance-criteria-derive` with the spec path.
   - Output: `.research/spec/ac-{feature-slug}-{YYYY-MM-DD}.md`
   - Review:
     - Every AC has a concrete `when` trigger and an asserted-verb `then` effect.
     - `Open questions` section lists any spec gaps — resolve these with product before moving on, or accept them and proceed knowing those ACs will be missing.

2. **Reject and refine ACs** — human step.
   - Read each AC critically. Drop ACs that duplicate, merge ACs that split an atomic behavior artificially, split ACs that bundle multiple effect verbs.
   - Re-run step 1 if the revision is large. The skill overwrites the same file.

3. **Scaffold tech spec** — call `/spec-tech-scaffold` with the AC artifact path (and the idea-exploration doc path if one exists).
   - Output: `.research/spec/tech-{feature-slug}-{YYYY-MM-DD}.md`
   - Review:
     - Every template section (platforms, language, test framework, CI, services, deployment, architecture) is populated or explicitly `N/A`.
     - `Open decisions` section is empty, or every item has a consult-lens suggestion.
   - If open decisions exist and you cannot evaluate them, follow the [`consult-fan-out`](consult-fan-out.md) recipe before proceeding to step 5.

4. **Refine tech spec** — human step. Resolve `Open decisions` either by picking a listed option or by consulting. Update the artifact directly.

5. **Scaffold CI gates** — call `/spec-ci-gates-scaffold` with the AC artifact path plus the tech-spec artifact path.
   - Output: `.research/spec/gates-{feature-slug}-{YYYY-MM-DD}.md`
   - Review:
     - Every AC is mapped to a primary gate layer.
     - Thresholds marked as drafts are realistic for your project's scale.
     - `Open thresholds` section lists decisions you need to make before wiring gates in.

6. **Implement TDD-style** — human / agent loop.
   - For each AC, write a failing test whose `describe` or `it` block contains the AC ID (e.g., `describe("LOGIN-C1: ...")`).
   - Make the test pass. Refactor. Move to the next AC.

7. **Wire gates into CI** — human step.
   - Translate the gates document into your CI system's concrete config (GitHub Actions workflow, GitLab CI, etc.).
   - Resolve `TBD` thresholds against your actual build.
   - Add a gate-failure script that enumerates uncovered AC IDs — the `contracts` gate in the document.

## Failure modes

- **AC list is too abstract (every `then` says "works correctly")** → the source spec is vague. Either ask product to tighten the spec, or scope this recipe to a narrower sub-feature where the spec has concrete verbs.
- **AC list is too long (30+ ACs)** → the feature is probably multiple features bundled. Split the spec and run the recipe per sub-feature.
- **Tech spec picks a stack you cannot evaluate** → do not guess. Mark as OPEN and use `consult-fan-out` with `consult-tech` / `consult-tech-apple` / `consult-business` per the scaffold's suggestions.
- **Gates step complains that tech-spec is missing** → you skipped step 3. Gates now formally depends on the tech-spec artifact; there is no stack-notes fallback.
- **Gates draft blocks developer flow in practice** → tune thresholds, never remove gates. If `unit` coverage at 70% is blocking, lower to 60% with a written note in the gates artifact; do not silently delete the check.
- **Tests pass but feature is broken in production** → AC set had a gap. Add an AC, re-run step 1 or edit the artifact directly, add the corresponding test, re-run gates. Prefer the regenerate-AC path when the spec itself was updated.
- **AC IDs drift between tests and artifact** → treat the AC artifact as source-of-truth. Rename tests, do not rename ACs.

## Examples

A team spec'd a "team invitation" feature on top of an existing Node 20 + PostgreSQL + GitHub Actions stack:
- `/spec-acceptance-criteria-derive` produced 8 ACs (`INVITE-C1..C8`): invite sent, invite accepted, expired invite rejection, duplicate invite rejection, etc.
- Human review dropped 1 duplicate AC, split 1 AC into two (send-email effect + DB-record effect).
- `/spec-tech-scaffold` produced a tech spec confirming TypeScript + vitest + GitHub Actions + PostgreSQL + AWS SES (for email), with one `Open decision` on whether to queue email sends via SQS or invoke synchronously. Team used `consult-fan-out` with `consult-tech` + `consult-business` to resolve — chose SQS for cost stability under spikes.
- `/spec-ci-gates-scaffold` proposed `static + unit + contracts + integration + e2e`. Build/supply-chain gates kept (Node deps). Every threshold grounded in the tech spec — no informal input required.
- TDD loop used AC IDs in describe blocks. CI `contracts` gate failed until all 9 IDs appeared in at least one test.
- Total time from spec to passing CI: under a day for an experienced engineer.

## Variants

- **Starting from idea-exploration (no PRD yet)** — run `/spec-prd-compose` first with the idea-exploration doc path. When its eval gate passes, its output becomes the input to step 1. Then follow the recipe normally.
- **Fast path** — if the spec is a single-screen feature with < 5 behaviors, skip step 2 and step 4 reviews and iterate directly in step 6; the AC-vs-test alignment will surface problems fast.
- **Reuse existing tech spec** — on a second feature in the same project, skip step 3 and pass the existing `tech-{project}-{date}.md` path to `spec-ci-gates-scaffold`. Refresh the tech spec only when stack changes.
- **No integration infra** — pure library / CLI projects will have no `Key external services` in their tech spec, and the gates skill will drop `integration` and `e2e` automatically.
- **Audit-only** — if tests already exist, skip step 6 and run a future `effect-verb-audit` skill against the AC artifact to find misalignments.
