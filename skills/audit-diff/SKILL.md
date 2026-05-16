---
name: audit-diff
description: Read-only audit of a code diff. Categorizes findings as [MUST] / [SHOULD] / [NIT] / [Q] / [PRAISE]. Internalized by the reviewer agent when the master delegates "review the diff". The forge's review.yaml declares the review areas to assess.
---

# Audit Diff

Reviewer-attached procedure. When you (reviewer) receive a diff to audit, follow this procedure.

## Procedure

**Step 0 — Resolve review areas:**

```bash
$TAS_ROOT/scripts/resolve.sh review --forge $FORGE_ROOT
```

The forge's `resolve/workflows/review.yaml` lists the areas to assess (e.g., architecture, coding standards, stack patterns, security, test coverage — exact list is forge-specific).

**Step 1 (Inventory)** — Establish the diff range:

```bash
git -C $WORKDIR status --short
git -C $WORKDIR diff
```

Confirm with the master which range to audit (uncommitted, staged, specific commits, or a PR number).

**Step 2 (Verify)** — Run the relevant tests on the diff. If tests don't exist for the new behavior, that itself is a `[MUST]` or `[SHOULD]` finding depending on the forge's policy.

**Step 3 (Audit each area)** in the order declared by `review.yaml`. Quote file paths with line numbers. Cross-reference attached refs:
- `ref-code-review` for the checklist.
- `ref-code-standards` for project-agnostic standards.
- Stack-patterns ref (attached by forge) for stack-specific style.
- `ref-apple-security` (when attached) for Apple-platform security posture.

**Step 4 (Report)** — Group findings by severity. Recommend disposition per item.

## Finding-severity vocabulary

| Prefix | Meaning | Disposition recommendation |
|---|---|---|
| `[MUST]` | Apply before merge — correctness, security, hard-rule violation | apply |
| `[SHOULD]` | Apply unless explicitly deferred — readability, pattern adherence, future-pain | apply (or defer with note) |
| `[NIT]` | Surface; do not auto-apply — taste / micro-cleanup | surface only |
| `[Q]` | Question for the author / master — assumption needs confirmation | answer first |
| `[PRAISE]` | Note a particularly good choice — morale + reinforcement | include in summary |

## What this skill does NOT do

- Apply fixes. The master delegates the fix back to the developer if needed.
- Approve or merge PRs. Findings are advisory; the master decides.
- Run standalone tests divorced from a review context. That is not your role; the master invokes the gate runner directly if pure test execution is needed.

## Output to master

Findings grouped by severity. For each item: file path with line number(s), the finding, the suggested change (when applicable), and disposition. Include at least one `[PRAISE]` when warranted.
