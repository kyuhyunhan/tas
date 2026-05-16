#!/bin/bash
# G2-C1 — pre-memory-write.sh enforces frontmatter + DRAFT marker
set -uo pipefail
HOOK="$FORGE_ROOT/.claude/hooks/pre-memory-write.sh"
[[ -x "$HOOK" ]] || exit 0
grep -q 'DRAFT' "$HOOK" || exit 1
# Check for frontmatter required fields
if grep -qE 'id|title|when|layer|status' "$HOOK"; then
    exit 2
fi
exit 1
