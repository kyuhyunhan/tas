#!/bin/bash
# audit.sh — Forge audit-axis rubric runner.
#
# Usage:
#   audit.sh                          # full report (box-drawn)
#   audit.sh --json                   # machine-readable
#   audit.sh --axis axis-1-...        # single axis
#   audit.sh --criterion G1-C5        # single criterion
#   audit.sh --rubric G1-C5           # show rubric levels for criterion
#   audit.sh --auto-only              # skip manual criteria (CI-friendly)
#
# Exit codes:
#   0 — all axes >= threshold (GREEN)
#   1 — at least one axis < threshold (RED)
#   2 — usage error
#
# Each criterion's `check.command` (mode=auto) is run with FORGE_ROOT
# exported. The sub-script's exit code IS the score (0/1/2/3). The
# rubric definitions in audit.yaml are documentation only — the script
# is the source of truth for what score each level corresponds to.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FORGE_ROOT="${FORGE_ROOT:?FORGE_ROOT must be set; bind a forge first (/forge <product>)}"
export FORGE_ROOT
export WORKDIR="${WORKDIR:-$(awk "/^workdir:/{print \$2}" "$FORGE_ROOT/profile.yaml")}"

AUDIT_YAML="$FORGE_ROOT/.claude/resolve/audit.yaml"

if [[ ! -f "$AUDIT_YAML" ]]; then
    echo "goal-check: $AUDIT_YAML not found" >&2
    exit 2
fi

python3 - "$AUDIT_YAML" "$@" <<'PY'
import sys
import yaml
import subprocess
import os
import json

goals_yaml = sys.argv[1]
args = sys.argv[2:]

def flag_value(name):
    if name in args:
        i = args.index(name)
        return args[i + 1] if i + 1 < len(args) else None
    return None

axis_filter   = flag_value('--axis')
crit_filter   = flag_value('--criterion')
rubric_only   = flag_value('--rubric')
emit_json     = '--json' in args
auto_only     = '--auto-only' in args

with open(goals_yaml) as f:
    goals = yaml.safe_load(f)

# Rubric-only mode: just print the rubric levels for a single criterion.
if rubric_only:
    for axis_id, axis in goals.get('axes', {}).items():
        for c in axis.get('criteria', []):
            if c['id'] == rubric_only:
                print(f"\n  Criterion {c['id']}: {c['title']}")
                print(f"  Check mode: {c['check']['mode']}")
                if c['check']['mode'] == 'auto':
                    print(f"  Command: {c['check'].get('command', '')}")
                else:
                    print(f"  Manual criteria: {c['check'].get('criteria', '')}")
                print("  Rubric levels:")
                for lvl in sorted(c.get('rubric', {}).keys()):
                    label = ['NOT_STARTED', 'PARTIAL', 'MET', 'EXCEEDED'][lvl]
                    print(f"    {lvl} {label:<12}  {c['rubric'][lvl]}")
                sys.exit(0)
    print(f"goal-check: criterion '{rubric_only}' not found", file=sys.stderr)
    sys.exit(2)


def run_check(check):
    """Run a check spec, return integer score 0-3."""
    mode = check.get('mode', 'auto')
    if mode == 'manual':
        if auto_only:
            return None  # skip in --auto-only
        # Render prompt for operator. Default to PARTIAL when run non-interactively.
        if not sys.stdin.isatty():
            return 1  # conservative default for non-interactive manual checks
        print(f"\n  MANUAL CHECK:")
        print(f"  {check.get('criteria', '(no criteria)')}")
        ans = input("  Score (0=NOT_STARTED / 1=PARTIAL / 2=MET / 3=EXCEEDED): ").strip()
        try:
            n = int(ans)
            return max(0, min(3, n))
        except ValueError:
            return 0

    # auto mode
    cmd = check.get('command', '')
    if not cmd:
        return 0
    # Resolve relative paths against FORGE_ROOT
    if cmd.startswith('.claude/'):
        cmd = os.path.join(os.environ.get('FORGE_ROOT', ''), cmd[len('.claude/'):])
    elif cmd.startswith('$FORGE_ROOT/'):
        cmd = cmd.replace('$FORGE_ROOT/', os.environ.get('FORGE_ROOT', '') + '/')
    elif cmd.startswith('$WORKDIR/'):
        cmd = cmd.replace('$WORKDIR/', os.environ.get('WORKDIR', '') + '/')
    try:
        result = subprocess.run(['bash', '-c', cmd], capture_output=True, timeout=30)
        return max(0, min(3, result.returncode))
    except subprocess.TimeoutExpired:
        return 0
    except Exception as e:
        return 0


report = {"axes": {}, "overall_passed": True}
total_mean = 0.0
total_axes = 0

for axis_id, axis in goals.get('axes', {}).items():
    if axis_filter and axis_id != axis_filter:
        continue
    crit_scores = []
    crit_report = []
    for c in axis.get('criteria', []):
        if crit_filter and c['id'] != crit_filter:
            continue
        score = run_check(c['check'])
        if score is None:
            continue  # skipped manual
        crit_scores.append(score)
        crit_report.append({
            "id": c['id'],
            "title": c['title'],
            "score": score,
            "label": ['NOT_STARTED', 'PARTIAL', 'MET', 'EXCEEDED'][score],
            "mode": c['check'].get('mode'),
        })
    if not crit_scores:
        continue
    mean = sum(crit_scores) / len(crit_scores)
    passed = mean >= axis.get('threshold', 2.0)
    report["axes"][axis_id] = {
        "title": axis.get('title', axis_id),
        "threshold": axis.get('threshold', 2.0),
        "mean_score": round(mean, 2),
        "n_criteria": len(crit_scores),
        "passed": passed,
        "criteria": crit_report,
    }
    if not passed:
        report["overall_passed"] = False
    total_mean += mean
    total_axes += 1

report["overall_mean"] = round(total_mean / max(total_axes, 1), 2)

if emit_json:
    print(json.dumps(report, indent=2))
    sys.exit(0 if report["overall_passed"] else 1)

# Box-drawn human report
overall_marker = "GREEN" if report["overall_passed"] else "RED"
print(f"\n╔══════════════════════════════════════════════════════════════════")
print(f"║ Forge audit goals — overall: {overall_marker}  (mean {report['overall_mean']:.2f}/3.00)")
print(f"╠══════════════════════════════════════════════════════════════════")

for axis_id, ax in report["axes"].items():
    marker = "✓ PASS" if ax["passed"] else "✗ FAIL"
    print(f"║ {marker}  {axis_id}  (mean {ax['mean_score']:.2f} / threshold {ax['threshold']})")
    print(f"║   {ax['title']}")
    for cr in ax["criteria"]:
        score_icon = ['·', '◐', '●', '★'][cr['score']]
        manual_marker = " [manual]" if cr['mode'] == 'manual' else ""
        print(f"║     {score_icon} {cr['score']} {cr['label']:<12} {cr['id']:<7} {cr['title']}{manual_marker}")
    print(f"║")

print(f"╚══════════════════════════════════════════════════════════════════")

sys.exit(0 if report["overall_passed"] else 1)
PY
