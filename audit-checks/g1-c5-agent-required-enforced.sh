#!/bin/bash
# G1-C5 — agent_required is enforced (not just declared)
set -uo pipefail
# Check if any pre-* hook reads agent_required
HOOKS_DIR="$FORGE_ROOT/.claude/hooks"
ENFORCED=$(grep -rl 'agent_required' "$HOOKS_DIR" 2>/dev/null | wc -l | tr -d ' ')
if [[ "$ENFORCED" == "0" ]]; then
    exit 0
fi
# Check for blocking (vs warning) — emit `"decision":"block"` somewhere conditional
if grep -rq '"decision":\s*"block"' "$HOOKS_DIR" && grep -rq 'agent_required' "$HOOKS_DIR"; then
    # Default-on check: settings.json env has the related flag default-on
    if grep -q 'FORGE_ENFORCE_AGENT_REQUIRED' "$FORGE_ROOT/.claude/settings.json" 2>/dev/null; then
        exit 3
    fi
    exit 2
fi
exit 1
