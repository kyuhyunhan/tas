#!/bin/bash
# G2-C6 — memory-record skill
set -uo pipefail
SKILL_DIR="$FORGE_ROOT/.claude/skills/forge-memory"
[[ -d "$SKILL_DIR" ]] || exit 0
SKILL="$SKILL_DIR/SKILL.md"
[[ -f "$SKILL" ]] || exit 1
if grep -q 'git log\|transcript' "$SKILL"; then
    if grep -q 'measure\|usage\|reference' "$SKILL"; then
        exit 3
    fi
    exit 2
fi
exit 1
