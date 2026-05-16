#!/bin/bash
# G4-C7 — per-session token telemetry
set -uo pipefail
LOG="$FORGE_ROOT/.claude/.session-token-log.jsonl"
[[ -f "$LOG" ]] || exit 0
# logged AND surfaced at session-init?
if grep -q '.session-token-log\|session-token' "$FORGE_ROOT/.claude/hooks/session-init.sh" 2>/dev/null; then
    # Regression alarm?
    if grep -q 'avg.*30%\|regression' "$FORGE_ROOT/.claude/hooks/session-init.sh"; then
        exit 3
    fi
    exit 2
fi
exit 1
