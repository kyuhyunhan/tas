#!/bin/bash
# G1-C4 — agent_required:true on production-code phases
set -uo pipefail
WF="$FORGE_ROOT/.claude/resolve/workflows/maintain-loop.yaml"
[[ -f "$WF" ]] || exit 0
COUNT=$(grep -c '^\s*agent_required:\s*true' "$WF")
case "$COUNT" in
    0) exit 0 ;;
    1|2) exit 1 ;;
    *) exit 2 ;;
esac
