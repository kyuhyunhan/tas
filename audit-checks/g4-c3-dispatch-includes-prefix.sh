#!/bin/bash
# G4-C3 — dispatch-agent.sh auto-applies prompt-prefix
set -uo pipefail
WRAP="$FORGE_ROOT/.claude/scripts/dispatch-agent.sh"
[[ -x "$WRAP" ]] || exit 0
grep -q 'agent-prompt-prefix' "$WRAP" || exit 1
# Bonus: cache_control marker
if grep -q 'cache_control\|cache-hit' "$WRAP"; then
    exit 3
fi
exit 2
