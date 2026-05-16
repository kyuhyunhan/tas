#!/bin/bash
# G1-C3 — HYPOTHESIS marker required on Explore/Plan
set -uo pipefail
AGENTS="$FORGE_ROOT/.claude/resolve/agents.yaml"
[[ -f "$AGENTS" ]] || exit 0
grep -q 'HYPOTHESIS' "$AGENTS" || exit 0
# Check both Explore and Plan have it
EXP=$(awk '/^  Explore:/,/^  [A-Z]:/' "$AGENTS" | grep -c HYPOTHESIS)
PLAN=$(awk '/^  Plan:/,/^[a-z]|^$/' "$AGENTS" | grep -c HYPOTHESIS)
if [[ $EXP -gt 0 && $PLAN -gt 0 ]]; then
    exit 2
fi
exit 1
