#!/bin/bash
# G2-C3 — session-init surfaces recent memory
set -uo pipefail
INIT="$FORGE_ROOT/.claude/hooks/session-init.sh"
[[ -x "$INIT" ]] || exit 0
if grep -q 'Recent memory' "$INIT" && grep -q 'top 10' "$INIT"; then
    # check for layer grouping (bonus)
    if grep -q 'layer-grouped\|by layer' "$INIT"; then
        exit 3
    fi
    exit 2
fi
exit 0
