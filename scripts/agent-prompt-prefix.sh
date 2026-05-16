#!/bin/bash
# agent-prompt-prefix.sh — emit the forge-supplied hard-rules + layering
# preamble that sub-agent Task prompts should be prepended with.
#
# The content itself is forge-specific (hard rules, layering paths,
# inventory discipline phrasing). This script just reads the file the
# forge supplies at $FORGE_ROOT/.claude/agent-prompt-prefix.md and
# emits it verbatim. Centralising the read here lets the
# dispatch-agent wrapper stay generic and lets prompt-caching work
# uniformly across forges.
#
# Usage:
#   PREFIX=$(agent-prompt-prefix.sh)
#   echo "$PREFIX\n\n$task_specific_prompt"

set -uo pipefail

FORGE_ROOT="${FORGE_ROOT:?FORGE_ROOT must be set; bind a forge first (/forge <product>)}"

PREFIX_FILE="$FORGE_ROOT/.claude/agent-prompt-prefix.md"

if [ ! -f "$PREFIX_FILE" ]; then
    echo "Error: $PREFIX_FILE not found." >&2
    echo "Each forge must supply its agent prompt preamble at this path." >&2
    exit 1
fi

cat "$PREFIX_FILE"
