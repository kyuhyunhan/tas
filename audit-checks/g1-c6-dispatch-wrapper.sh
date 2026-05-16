#!/bin/bash
# G1-C6 — dispatch-agent.sh wrapper
set -uo pipefail
WRAP="$FORGE_ROOT/.claude/scripts/dispatch-agent.sh"
[[ -x "$WRAP" ]] || exit 0
# Wrapper exists — does it inject skills at runtime?
if grep -q 'auto_loads' "$WRAP" && grep -q 'agent-prompt-prefix' "$WRAP"; then
    exit 3
fi
if grep -q 'agent-prompt-prefix' "$WRAP"; then
    exit 2
fi
exit 1
