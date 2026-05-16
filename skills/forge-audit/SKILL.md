---
name: forge-audit
description: Run the forge's audit-axis rubric and emit a multi-axis score report. Invoke when the user asks for axis status, rubric measurement, or where the forge sits on its audit criteria. Read-only — does NOT modify any files. The rubric definition (axes, criteria, thresholds) lives in the forge's resolve/audit.yaml; this skill drives the runner.
---

# Forge Audit

Master-direct skill. Measures the current forge's state against the rubric declared in `$FORGE_ROOT/.claude/resolve/audit.yaml`.

## What this skill measures

The forge's `audit.yaml` defines:
- A set of axes (typically 3–5 per forge).
- Per-axis criteria scored on a 4-level rubric (0=NOT_STARTED, 1=PARTIAL, 2=MET, 3=EXCEEDED).
- A per-axis threshold (e.g., mean ≥ 2.0 for the axis to PASS). All axes must PASS for overall GREEN.

This skill is **read-only**. It does not modify any forge files. Acting on findings is `forge-harden`.

## Procedure

**Full report**:

```bash
$TAS_ROOT/scripts/audit.sh --forge $FORGE_ROOT
```

Render the box-drawn output verbatim. Highlight axes < threshold as the focus for the next sprint.

**Single axis**:

```bash
$TAS_ROOT/scripts/audit.sh --forge $FORGE_ROOT --axis <axis-id>
```

**Rubric for one criterion** — definitions of 0/1/2/3 for that criterion:

```bash
$TAS_ROOT/scripts/audit.sh --forge $FORGE_ROOT --rubric <criterion-id>
```

**Machine-readable** (for diffing or scripting):

```bash
$TAS_ROOT/scripts/audit.sh --forge $FORGE_ROOT --json
```

**Non-interactive / CI** (skips manual-mode criteria):

```bash
$TAS_ROOT/scripts/audit.sh --forge $FORGE_ROOT --auto-only
```

## After running

If overall is RED:

1. Identify the lowest-scoring axis.
2. Within that axis, identify the lowest-scoring criterion.
3. Read its rubric via `--rubric <id>` to know the level-2 target.
4. Suggest the work to bump that criterion — either via `forge-harden` (process holds) or by delegating product changes to the developer agent.
5. Re-run after the work to verify the score moved.

## Not to be confused with

- `audit-diff` — reviewer's diff audit. Different scope (a code diff, not the forge).
- `forge-harden` — acts on findings via the holds loop.
- `forge-audit` is **measurement only**.
