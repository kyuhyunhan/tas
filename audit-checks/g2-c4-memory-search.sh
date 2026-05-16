#!/bin/bash
# G2-C4 — memory-search.sh exists and ranks results
set -uo pipefail
SEARCH="$FORGE_ROOT/.claude/scripts/memory-search.sh"
[[ -x "$SEARCH" ]] || exit 0
# Detect ranking sophistication
if grep -q 'embedding\|vector\|cosine' "$SEARCH"; then
    exit 3
fi
if grep -q 'sort\|rank\|score' "$SEARCH"; then
    exit 2
fi
exit 1
