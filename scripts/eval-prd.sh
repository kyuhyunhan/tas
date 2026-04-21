#!/usr/bin/env bash
# eval-prd.sh — mechanical completeness check for a spec-prd-compose artifact.
#
# Usage:
#   scripts/eval-prd.sh path/to/.research/spec/prd-{slug}-{date}.md
#
# Exit codes:
#   0  all mechanical checks passed
#   1  one or more mechanical checks failed (details on stdout)
#   2  invocation error (missing file, wrong args)

set -euo pipefail

if [ "$#" -ne 1 ]; then
  echo "usage: $0 <path-to-prd.md>" >&2
  exit 2
fi

PRD="$1"

if [ ! -f "$PRD" ]; then
  echo "error: file not found: $PRD" >&2
  exit 2
fi

FAILS=0
report() {
  local status="$1"
  local label="$2"
  local detail="${3:-}"
  if [ "$status" = "FAIL" ]; then
    FAILS=$((FAILS + 1))
    printf "FAIL  %s" "$label"
    [ -n "$detail" ] && printf "  — %s" "$detail"
    printf "\n"
  else
    printf "PASS  %s\n" "$label"
  fi
}

# ─── 1. Required sections present ──────────────────────────────
REQUIRED_SECTIONS=(
  "## Overview"
  "## Problem statement"
  "## Target user"
  "## Functional requirements"
  "## Non-functional requirements"
  "## Dependencies"
  "## Success metrics"
  "## Out of scope"
)
for section in "${REQUIRED_SECTIONS[@]}"; do
  if grep -qF "$section" "$PRD"; then
    report PASS "section present: $section"
  else
    report FAIL "section missing: $section"
  fi
done

# ─── 2. Each functional requirement has Trigger + Effect + Edge cases ──
# Functional requirements are ### FR-N blocks.
FR_COUNT=$(grep -cE '^### FR-[0-9]+' "$PRD" || true)
if [ "$FR_COUNT" -eq 0 ]; then
  report FAIL "functional requirements present" "zero FR-N entries found"
else
  report PASS "functional requirements count: $FR_COUNT"

  # For each FR block, check subsections exist within.
  awk '
    /^### FR-/ {
      if (fr != "") {
        printf "%s|%d|%d|%d\n", fr, has_trigger, has_effect, has_edge
      }
      fr=$0; has_trigger=0; has_effect=0; has_edge=0; next
    }
    /^### / && !/^### FR-/ { if (fr != "") { printf "%s|%d|%d|%d\n", fr, has_trigger, has_effect, has_edge; fr="" } ; next }
    /^## / { if (fr != "") { printf "%s|%d|%d|%d\n", fr, has_trigger, has_effect, has_edge; fr="" } ; next }
    /\*\*Trigger\*\*/ { if (fr != "") has_trigger=1 }
    /\*\*Effect\*\*/  { if (fr != "") has_effect=1 }
    /\*\*Edge cases\*\*/ { if (fr != "") has_edge=1 }
    END { if (fr != "") { printf "%s|%d|%d|%d\n", fr, has_trigger, has_effect, has_edge } }
  ' "$PRD" | while IFS='|' read -r fr t e edge; do
    if [ "$t" = "1" ] && [ "$e" = "1" ] && [ "$edge" = "1" ]; then
      report PASS "FR subsections: $fr"
    else
      missing=""
      [ "$t" = "0" ]    && missing="${missing}Trigger "
      [ "$e" = "0" ]    && missing="${missing}Effect "
      [ "$edge" = "0" ] && missing="${missing}Edge-cases "
      report FAIL "FR subsections: $fr" "missing: $missing"
    fi
  done
fi

# ─── 3. Effect verb precision — reject vague verbs in Effect fields ─
VAGUE_VERBS='(handles|works|supports|processes|manages)'
VAGUE_HITS=$(grep -nE "^- \*\*Effect\*\*.*$VAGUE_VERBS" "$PRD" || true)
if [ -z "$VAGUE_HITS" ]; then
  report PASS "effect verbs: no vague verbs in Effect fields"
else
  report FAIL "effect verbs: vague verbs present" "$(echo "$VAGUE_HITS" | head -3 | tr '\n' ';')"
fi

# ─── 4. Out of scope enumerates >= 3 items ─────────────────────
OOS_COUNT=$(awk '
  /^## Out of scope/ { inside=1; next }
  /^## / && inside { inside=0 }
  inside && /^- / { count++ }
  END { print count+0 }
' "$PRD")
if [ "$OOS_COUNT" -ge 3 ]; then
  report PASS "out-of-scope enumeration: $OOS_COUNT items"
else
  report FAIL "out-of-scope enumeration" "only $OOS_COUNT items (need ≥3)"
fi

# ─── 5. Success metrics have measurable value + time horizon ────
# Heuristic: each metric bullet under ## Success metrics should contain
# a digit (measurable value) AND a time indicator (week/month/day/quarter/hour/year).
METRIC_FAILS=$(awk '
  /^## Success metrics/ { inside=1; next }
  /^## / && inside { inside=0 }
  inside && /^- / {
    line=$0
    has_digit=(line ~ /[0-9]/)
    has_time=(line ~ /(second|minute|hour|day|week|month|quarter|year)/)
    if (!(has_digit && has_time)) print NR": "line
  }
' "$PRD")
if [ -z "$METRIC_FAILS" ]; then
  report PASS "success metrics: each has measurable value + time horizon"
else
  report FAIL "success metrics: missing measurable value and/or time horizon" \
    "$(echo "$METRIC_FAILS" | head -3 | tr '\n' ';')"
fi

# ─── Summary ────────────────────────────────────────────────────
echo ""
if [ "$FAILS" -eq 0 ]; then
  echo "eval-prd: all mechanical checks passed."
  exit 0
else
  echo "eval-prd: $FAILS mechanical check(s) failed."
  exit 1
fi
