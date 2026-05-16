#!/bin/bash
# G2-C5 — dispatch-agent.sh injects layer-matched memory
set -uo pipefail
WRAP="$FORGE_ROOT/.claude/scripts/dispatch-agent.sh"
[[ -x "$WRAP" ]] || exit 0
if grep -q 'memory-search\|RAG\|keyword.*relevance' "$WRAP"; then
    exit 3
fi
if grep -qE 'memory/(client|server|cross-cutting|product)' "$WRAP"; then
    exit 2
fi
if grep -q 'memory/' "$WRAP"; then
    exit 1
fi
exit 0
