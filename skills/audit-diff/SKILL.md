---
name: audit-diff
description: >-
  Read-only audit of a code diff. Categorizes every finding as [MUST] /
  [SHOULD] / [NIT] / [Q] / [PRAISE] with file:line references. Invoke when
  reviewing a diff or PR — directly, or as the rubric the reviewer subagent
  follows (e.g. from ship-pr). Do NOT use to author code, apply fixes, or merge
  — findings are advisory; the caller decides.
---

# audit-diff

A review **rubric + procedure**. Given a diff, produce categorized, actionable
findings. The value here is not "how to review" (the model knows that) — it is
the **fixed severity vocabulary** below, so findings are triaged consistently
and a caller (human or the `ship-pr` loop) can act on them mechanically.

This skill **audits**. It does not:
- apply fixes (delegate the fix back to the author)
- approve or merge (findings are advisory; the caller decides)
- run tests as an end in itself (test execution only as evidence for a finding)

## Procedure

1. **Inventory** — establish the diff range and confirm it with the caller:
   ```bash
   git -C "$WORKDIR" status --short
   git -C "$WORKDIR" diff <range>        # uncommitted, staged, a commit range, or main...HEAD
   ```
2. **Gather invariants** — read the project's `CLAUDE.md` / architecture docs for
   the rules a reviewer must enforce (layering, security posture, "no X in Y").
   The caller may also pass invariants directly (ship-pr does).
3. **Verify** — run the tests touching the diff. Missing tests for new behavior
   is itself a `[MUST]` or `[SHOULD]` finding.
4. **Audit** the diff against: correctness, the gathered invariants, security,
   readability, and test coverage. Quote `file:line` for every finding.
5. **Report** — group findings by severity; recommend a disposition per item.

## Finding-severity vocabulary

| Prefix | Meaning | Disposition |
|---|---|---|
| `[MUST]` | Apply before merge — correctness, security, invariant violation | apply |
| `[SHOULD]` | Apply unless explicitly deferred — readability, pattern, future-pain | apply or defer-with-reason |
| `[NIT]` | Surface only — taste / micro-cleanup | surface |
| `[Q]` | Question for the author — an assumption needs confirming | answer first |
| `[PRAISE]` | A particularly good choice — reinforcement | include in summary |

## Output

Findings grouped by severity. Per item: `file:line`, the finding, the suggested
change (when applicable), and the disposition. Include at least one `[PRAISE]`
when warranted. Be adversarial about `[MUST]` — prefer a real bug over a nit.
