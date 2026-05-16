#!/bin/bash
# G3-C7 — contracts/<feature-id>.yaml coverage
set -uo pipefail
DIR="$FORGE_ROOT/contracts"
[[ -d "$DIR" ]] || exit 0
CONTRACT_COUNT=$(find "$DIR" -name '*.yaml' 2>/dev/null | wc -l | tr -d ' ')
if [[ "$CONTRACT_COUNT" -lt 1 ]]; then exit 0; fi
# crude estimate of "features shipped": count of feat()/feature commits in lexio repo
FEATURE_COMMITS=$(git -C "$WORKDIR" log --grep='^feat(' --oneline 2>/dev/null | wc -l | tr -d ' ')
[[ "$FEATURE_COMMITS" -eq 0 ]] && exit 1
RATIO=$(awk -v c="$CONTRACT_COUNT" -v f="$FEATURE_COMMITS" 'BEGIN{print c/f}')
echo "# contracts=$CONTRACT_COUNT feature_commits=$FEATURE_COMMITS" >&2
awk -v r="$RATIO" 'BEGIN{
    if (r < 0.5) exit 1;
    if (r < 0.9) exit 1;
    exit 2;
}'
