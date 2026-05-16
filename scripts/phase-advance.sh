#!/bin/bash
# phase-advance.sh — Phase boundary enforcer.
#
# Usage:
#   .claude/scripts/phase-advance.sh <phase-id>
#
# Effect:
#   1. Reads workflows/maintain-loop.yaml.
#   2. Locates the phase with the given id.
#   3. Runs every gate listed under that phase's `post_gates`.
#   4. Exits 0 if all REQUIRED gates pass (optional gates are surfaced but
#      do not block). Exits 1 if any required gate fails. Exits 2 if the
#      phase id is unknown.
#   5. On a passing (or vacuous) phase exit, delegates auto-commit to
#      `auto-commit-repos.sh <phase-id>`. Single source of truth for the
#      commit-message template lives in that script — both phase
#      boundaries and SessionEnd reuse it.
#
# Why this exists (diagnostic L-2):
#   The maintain-loop spec declares post_gates per phase, but nothing fires
#   them at phase boundaries. As a result, implement-server and
#   implement-client routinely interleave with no gate enforcement between
#   them. Callers (the model, a human, CI) MUST invoke this script after
#   each phase before starting the next; the failure surface is then loud
#   and located, instead of a silent drift that surfaces in review hours
#   later.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FORGE_ROOT="${FORGE_ROOT:?FORGE_ROOT must be set; bind a forge first (/forge <product>)}"
RESOLVE_DIR="$FORGE_ROOT/.claude/resolve"
GATES_DIR="$SCRIPT_DIR/gates"
AUTO_COMMIT_SCRIPT="$SCRIPT_DIR/auto-commit-repos.sh"
PHASE_STATE_FILE="$FORGE_ROOT/.claude/.phase-state.json"

source "$SCRIPT_DIR/lib/read-yaml.sh"

# Write the phase-state record consumed by pre-task.sh's blocking gate.
# Called from BOTH success and required-failure branches so the state
# always reflects the most recent phase-advance invocation.
write_phase_state() {
    local outcome="$1"  # "passed" or "failed"
    shift
    local failed_gates_json="[]"
    if [ "$#" -gt 0 ]; then
        # Build a JSON array from the remaining positional args (failed gate names).
        failed_gates_json=$(python3 -c "
import json, sys
print(json.dumps(sys.argv[1:]))
" "$@")
    fi
    local ts
    ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    cat >"$PHASE_STATE_FILE" <<EOF
{
  "phase_id": "$PHASE_ID",
  "outcome": "$outcome",
  "advanced_at": "$ts",
  "failed_required_gates": $failed_gates_json
}
EOF
}

PHASE_ID="${1:-}"
if [ -z "$PHASE_ID" ]; then
    echo "usage: phase-advance.sh <phase-id>" >&2
    echo "  example: phase-advance.sh implement-client" >&2
    exit 2
fi

WORKFLOW_YAML="$RESOLVE_DIR/workflows/maintain-loop.yaml"
GATES_YAML="$RESOLVE_DIR/gates.yaml"

if [ ! -f "$WORKFLOW_YAML" ]; then
    echo "phase-advance: $WORKFLOW_YAML not found" >&2
    exit 2
fi

# Resolve the phase's post_gates list. The read-yaml helper does not
# support list-of-objects indexing by field, so we shell out to python
# inline for this one query.
POST_GATES=$(python3 - "$WORKFLOW_YAML" "$PHASE_ID" <<'PY'
import sys, yaml
yaml_path, phase_id = sys.argv[1], sys.argv[2]
with open(yaml_path) as f:
    spec = yaml.safe_load(f)
for phase in spec.get('phases', []):
    if phase.get('id') == phase_id:
        for gate in phase.get('post_gates', []) or []:
            print(gate)
        sys.exit(0)
sys.exit(99)
PY
)
rc=$?
if [ "$rc" -eq 99 ]; then
    echo "phase-advance: unknown phase id '$PHASE_ID'" >&2
    echo "  valid phase ids: $(python3 -c "
import yaml
with open('$WORKFLOW_YAML') as f:
    spec = yaml.safe_load(f)
print(', '.join(p.get('id','?') for p in spec.get('phases', [])))
")" >&2
    exit 2
fi

echo "╔═══ phase-advance: $PHASE_ID ═════════════════"

run_auto_commit() {
    if [ -x "$AUTO_COMMIT_SCRIPT" ]; then
        "$AUTO_COMMIT_SCRIPT" "$PHASE_ID" || echo "║ (auto-commit returned non-zero — see above)"
    else
        echo "║ auto-commit script not found at $AUTO_COMMIT_SCRIPT — skipped"
    fi
}

if [ -z "$POST_GATES" ]; then
    echo "║ no post_gates declared — phase passes vacuously"
    write_phase_state "passed"
    run_auto_commit
    echo "╚═══════════════════════════════════════════════"
    exit 0
fi

FAIL_COUNT=0
SKIP_COUNT=0
PASS_COUNT=0
FAILED_REQUIRED=()

for gate in $POST_GATES; do
    gate_script="$GATES_DIR/$gate.sh"
    optional=$(read_yaml "$GATES_YAML" "gates.${gate}.optional")

    if [ ! -x "$gate_script" ]; then
        echo "║ gate '$gate' has no executable script at $gate_script"
        if [ "$optional" = "True" ] || [ "$optional" = "true" ]; then
            SKIP_COUNT=$((SKIP_COUNT + 1))
            echo "║   → skipped (optional)"
        else
            FAIL_COUNT=$((FAIL_COUNT + 1))
            FAILED_REQUIRED+=("$gate (missing script)")
        fi
        continue
    fi

    if bash "$gate_script" >/tmp/phase-advance-$gate.log 2>&1; then
        PASS_COUNT=$((PASS_COUNT + 1))
        echo "║ ✓ $gate"
    else
        if [ "$optional" = "True" ] || [ "$optional" = "true" ]; then
            SKIP_COUNT=$((SKIP_COUNT + 1))
            echo "║ ⚠ $gate (optional — surfaced, not blocking)"
            echo "║   tail of /tmp/phase-advance-$gate.log:"
            tail -5 /tmp/phase-advance-$gate.log | sed 's/^/║     /'
        else
            FAIL_COUNT=$((FAIL_COUNT + 1))
            FAILED_REQUIRED+=("$gate")
            echo "║ ✗ $gate (REQUIRED)"
            echo "║   tail of /tmp/phase-advance-$gate.log:"
            tail -8 /tmp/phase-advance-$gate.log | sed 's/^/║     /'
        fi
    fi
done

echo "╠══════════════════════════════════════════════"
echo "║ summary: $PASS_COUNT passed, $SKIP_COUNT skipped/optional-failed, $FAIL_COUNT required-failed"

if [ "$FAIL_COUNT" -gt 0 ]; then
    echo "║ ✗ phase '$PHASE_ID' BLOCKED — required gate(s) failed: ${FAILED_REQUIRED[*]}"
    write_phase_state "failed" "${FAILED_REQUIRED[@]}"
    echo "╚═══════════════════════════════════════════════"
    exit 1
fi

echo "║ ✓ phase '$PHASE_ID' may advance"
write_phase_state "passed"
run_auto_commit
echo "╚═══════════════════════════════════════════════"
exit 0
