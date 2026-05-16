#!/bin/bash
# G4-C1 — agent-prompt-prefix.sh
set -uo pipefail
SCRIPT="$FORGE_ROOT/.claude/scripts/agent-prompt-prefix.sh"
[[ -x "$SCRIPT" ]] || exit 0
# Used by dispatch-agent.sh?
WRAP="$FORGE_ROOT/.claude/scripts/dispatch-agent.sh"
if [[ -x "$WRAP" ]] && grep -q 'agent-prompt-prefix' "$WRAP"; then
    exit 3
fi
exit 2
