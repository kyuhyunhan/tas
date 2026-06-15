---
name: ship-pr
description: >-
  Ship a completed, tested change through the full review-to-merge loop: push,
  open a PR, review with an independent review subagent (general-purpose running
  the review rubric below), iterate fixes until the
  acceptance bar (zero [MUST] + [SHOULD]s triaged + tests green), then
  auto-merge. Invoke when the user says "ship this", "ship the PR", "open a PR
  and review it", "run the review loop", or has finished a feature with tests
  green and wants it reviewed and merged. Do NOT use mid-implementation, when
  tests are failing, or when the user only wants a review (not a merge).
---

# ship-pr

Drives a finished, tested change through **push → PR → adversarial review loop →
merge**, turning a one-off workflow into one invocation. The author and the
reviewer are deliberately different agents: an independent review subagent
(`general-purpose` running the **review rubric** below) audits the diff, and the
change does not merge until it clears an explicit bar.

This skill **ships finished work**. It does not:
- finish or write the work (arrive with the change complete and tests green)
- decide the change is good — the review subagent does, against the bar below
- merge a PR that has not cleared the acceptance bar

## Scope

**In scope**: pushing a branch, opening the PR, running the reviewer loop,
applying [MUST] + agreed [SHOULD] fixes (TDD when logic changes), auto-merging
once the bar is met, post-merge sync.

**Out of scope**: implementing the feature, product/spec decisions, a
review-only pass (just apply the review rubric below directly), shipping with red tests.

## Acceptance bar (the gate)

Auto-merge only when ALL hold:
1. zero **[MUST]** findings in the latest round,
2. every **[SHOULD]** fixed, or deferred with a one-line reason,
3. full test suite green,
4. CI passes (if any) and the PR is mergeable (no conflicts).

`[NIT]`/`[Q]` never block. If the bar is not met after **3 rounds**, STOP and
escalate with the open findings — never merge a non-converged PR.

## Procedure

1. **Preflight** — work complete + suite green; on a feature branch (branch off
   the default first if not); tree committed; a GitHub remote exists (else stop).
   Push: `git push -u origin <branch>`.
2. **Open the PR** — `gh pr create` with a body stating intent + a concise
   summary of what changed.
3. **Review loop** (max 3 rounds):
   - read the project's `CLAUDE.md` / arch docs for the invariants a reviewer
     must enforce;
   - spawn an independent review subagent — `general-purpose` running the
     **review rubric** below (read-only) — on `git diff <default>...HEAD` with the
     intent + invariants; require findings tagged
     `[MUST]/[SHOULD]/[NIT]/[Q]/[PRAISE]` with `file:line`;
   - fix [MUST] + accepted [SHOULD] (TDD when logic changes); suite green;
   - commit (Conventional, no AI co-author) + push; re-review.
4. **Gate & auto-merge** — when the bar is met, verify mergeability/CI
   (`gh pr view <n> --json mergeable,mergeStateStatus,statusCheckRollup`); if
   clean, **merge** (merge commit matching repo style, `--delete-branch`). This
   is automatic — no extra prompt.
5. **Post-merge** — `git checkout <default>` · `git pull --ff-only` · run the
   suite green · report the merge commit, rounds run, and findings resolved.

## Review rubric (what the review subagent applies)

A read-only audit of `git diff <default>...HEAD`. The value is the **fixed
severity vocabulary**, so findings triage consistently and the loop can act on
them mechanically.

1. **Inventory** the diff range; **gather invariants** from the project's
   `CLAUDE.md` / arch docs (plus the invariants passed in); **verify** by running
   the tests touching the diff — missing tests for new behavior is itself a
   `[MUST]`/`[SHOULD]`.
2. **Audit** against correctness, the invariants, security, readability, and test
   coverage. Quote `file:line` for every finding. Be adversarial about `[MUST]` —
   prefer a real bug over a nit.

| Prefix | Meaning | Disposition |
|---|---|---|
| `[MUST]` | Apply before merge — correctness, security, invariant violation | apply |
| `[SHOULD]` | Apply unless explicitly deferred — readability, pattern, future-pain | apply or defer-with-reason |
| `[NIT]` | Surface only — taste / micro-cleanup | surface |
| `[Q]` | Question for the author — an assumption needs confirming | answer first |
| `[PRAISE]` | A particularly good choice — reinforcement | include in summary |

## Edge cases

- **On the default branch** → branch first; never PR from `main`.
- **CI pending** → wait/poll; never merge on an unknown state.
- **CI red / merge conflict** → escalate, do not merge.
- **Review finds a real bug late** → fix it TDD; the bug leaves a test behind
  so it cannot recur.
- **Non-convergence** (still [MUST] after 3 rounds) → escalate with open findings.
- **Local-only repo** (no remote) → stop at preflight; this skill needs a PR.
- **Recurring finding** across runs → fold it into the project's invariants or
  this skill so it is caught up front next time.

## Definition of done

A merge commit on the default branch, branch deleted, local default synced and
the suite green, and a one-paragraph report (PR number, rounds, findings
resolved/deferred, final test count) — or a clear escalation explaining why the
bar was not met. Never a silent stop.
