#!/bin/bash
# G4-C6 — CLAUDE.md aggregate size
set -uo pipefail
# Rough token count: 1 token ≈ 4 chars
TOTAL_CHARS=0
for f in \
    "$HOME/.claude/CLAUDE.md" \
    "$TAF_ROOT/CLAUDE.md" \
    "$FORGE_ROOT/CLAUDE.md"; do
    if [[ -f "$f" ]]; then
        chars=$(wc -c < "$f" | tr -d ' ')
        TOTAL_CHARS=$((TOTAL_CHARS + chars))
    fi
done
TOKENS=$((TOTAL_CHARS / 4))
echo "# total_chars=$TOTAL_CHARS approx_tokens=$TOKENS" >&2
if [[ "$TOKENS" -gt 5000 ]]; then exit 0; fi
if [[ "$TOKENS" -gt 3000 ]]; then exit 1; fi
if [[ "$TOKENS" -gt 2000 ]]; then exit 2; fi
exit 3
