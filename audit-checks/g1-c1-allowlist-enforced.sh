#!/bin/bash
# G1-C1 — Agent allowlist exists & pre-task.sh blocks unlisted Task calls
# Exit code = score (0/1/2/3).
set -uo pipefail
AGENTS="$FORGE_ROOT/.claude/resolve/agents.yaml"
HOOK="$FORGE_ROOT/.claude/hooks/pre-task.sh"
[[ -f "$AGENTS" && -x "$HOOK" ]] || exit 0
# Smoke test: feed unlisted agent → expect non-zero exit
SMOKE=$(echo '{"tool_input":{"subagent_type":"nonexistent-agent-xyz"}}' | bash "$HOOK" 2>&1)
SMOKE_EXIT=$?
if [[ $SMOKE_EXIT -eq 0 ]]; then
    exit 1  # hook exists but doesn't block
fi
# Bonus: check for phase-gate extension
if grep -q 'FORGE_BLOCKING_PHASE_GATE' "$HOOK"; then
    # Check if default-on via settings.json env
    if grep -q '"FORGE_BLOCKING_PHASE_GATE"' "$FORGE_ROOT/.claude/settings.json" 2>/dev/null; then
        exit 3
    fi
fi
exit 2
