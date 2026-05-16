#!/bin/bash
# G4-C5 — memory-search.sh RAG
set -uo pipefail
SEARCH="$FORGE_ROOT/.claude/scripts/memory-search.sh"
[[ -x "$SEARCH" ]] || exit 0
if grep -q 'embedding\|vector\|cosine\|semantic' "$SEARCH"; then
    exit 3
fi
if grep -q 'sort\|rank\|score' "$SEARCH"; then
    exit 2
fi
exit 0
