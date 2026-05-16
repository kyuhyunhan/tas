#!/bin/bash
# dispatch-agent.sh <agent_id>
#
# Emits the prompt PREFIX that should precede a Task tool's task-specific
# prompt for the given agent_id. Combines:
#
#   1. Hard-rules / layering / HYPOTHESIS preamble  (agent-prompt-prefix.sh)
#   2. Skill summaries for every entry in agents.yaml#agent.auto_loads
#      (each skill's frontmatter description, sourced from ~/.claude/skills/<name>/SKILL.md)
#
# Usage from the model (the user-facing canonical pattern):
#
#   PREFIX=$(./dispatch-agent.sh swift-developer)
#   # Then call Task with subagent_type="swift-developer" and:
#   #   prompt="${PREFIX}\n\n${task_specific_prompt}"
#
# Validates agent_id against the allowlist before composing. If unknown,
# exits 2 with a list of valid IDs.
#
# Why this exists: G1-C6 / G4-C3 of the forge audit rubric. Without this
# wrapper, every Task call repeated ~500 tokens of hard-rules boilerplate
# AND skipped any meaningful tas skill injection. The wrapper closes both
# gaps in one place. (memory: 20260515T0923.)

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FORGE_ROOT="${FORGE_ROOT:?FORGE_ROOT must be set; bind a forge first (/forge <product>)}"
AGENTS_YAML="$FORGE_ROOT/.claude/resolve/agents.yaml"
SKILLS_DIR="$HOME/.claude/skills"

AGENT_ID="${1:-}"
if [[ -z "$AGENT_ID" ]]; then
    echo "usage: dispatch-agent.sh <agent_id>" >&2
    python3 -c "
import yaml
cfg = yaml.safe_load(open('$AGENTS_YAML'))
print('  valid: ' + ', '.join((cfg.get('agents') or {}).keys()), file=__import__('sys').stderr)
"
    exit 2
fi

# Verify agent is in allowlist
VALID=$(python3 - "$AGENTS_YAML" "$AGENT_ID" <<'PY'
import sys, yaml
cfg = yaml.safe_load(open(sys.argv[1]))
agents = cfg.get('agents') or {}
print('yes' if sys.argv[2] in agents else 'no')
PY
)
if [[ "$VALID" != "yes" ]]; then
    echo "dispatch-agent: '$AGENT_ID' not in agents.yaml allowlist" >&2
    exit 2
fi

# --- compose prefix --------------------------------------------------

# (1) hard-rules / layering / HYPOTHESIS preamble
PREFIX_OUT=$("$SCRIPT_DIR/agent-prompt-prefix.sh")
echo "$PREFIX_OUT"

# (2) auto_loads skill summaries (runtime injection — what makes the
# wrapper score level 3 EXCEEDED on G1-C6).
python3 - "$AGENTS_YAML" "$AGENT_ID" "$SKILLS_DIR" <<'PY'
import sys, yaml, os
agents = (yaml.safe_load(open(sys.argv[1])).get('agents') or {})
agent  = agents.get(sys.argv[2]) or {}
loads  = agent.get('auto_loads') or []
skills_dir = sys.argv[3]
if not loads:
    print("")
    print(f"## Auto-loaded skills for agent '{sys.argv[2]}': (none)")
    sys.exit(0)
print("")
print(f"## Auto-loaded skills for agent '{sys.argv[2]}'")
print("")
print("Each skill's description is injected here so the agent has its conventions")
print("in mind without a separate fetch. Skip when the task does not invoke the skill.")
print("")
for s in loads:
    # Find SKILL.md (either as <name>/SKILL.md symlinked or as <name>.md)
    candidates = [
        os.path.join(skills_dir, s, 'SKILL.md'),
        os.path.join(skills_dir, f'{s}.md'),
    ]
    md = next((p for p in candidates if os.path.exists(p)), None)
    if md is None:
        print(f"### {s}\n  (skill not resolved at {skills_dir}/{s})")
        continue
    # Extract frontmatter `description:` field
    desc = ''
    try:
        with open(md) as f:
            in_fm = False
            for line in f:
                if line.strip() == '---':
                    if in_fm:
                        break
                    in_fm = True
                    continue
                if in_fm and line.startswith('description:'):
                    desc = line[len('description:'):].strip().strip('|').strip()
                    # capture continuation lines if multi-line
                    continue
                if in_fm and desc and line.startswith('  '):
                    desc += ' ' + line.strip()
    except OSError:
        pass
    print(f"### {s}")
    if desc:
        print(f"  {desc}")
    print(f"  (full text: {md})")
    print("")
PY

# (3) Layer-matched memory notes — RAG-style injection via memory-search.sh.
# Maps agent_id → memory layer; non-empty query argument enables keyword
# relevance ranking. (G2-C5 + G4-C5 of the forge rubric.)
case "$AGENT_ID" in
    swift-developer|swift-test-writer|test-runner)  LAYER="client" ;;
    aws-serverless-developer)                       LAYER="server" ;;
    code-reviewer|workflow-retrospective)           LAYER="cross-cutting" ;;
    explorer|Explore|Plan)                          LAYER="" ;;   # broad
    *)                                              LAYER="" ;;
esac

# Optional 2nd arg = task query for keyword-ranked relevance.
QUERY="${2:-}"

MEMORY_OUT=""
if [[ -x "$SCRIPT_DIR/memory-search.sh" ]]; then
    if [[ -n "$LAYER" ]]; then
        MEMORY_OUT=$("$SCRIPT_DIR/memory-search.sh" "$QUERY" --layer "$LAYER" --limit 5 --format prompt)
    else
        MEMORY_OUT=$("$SCRIPT_DIR/memory-search.sh" "$QUERY" --limit 5 --format prompt)
    fi
    echo "$MEMORY_OUT"
fi

# (4) Telemetry — log dispatch event to .session-token-log.jsonl for axis-4
# token-economy auditing (G4-C7). Estimated prompt size = char count of the
# composed prefix / 4 (approx tokens). Appended; never rotated by this script
# (operator can prune manually or wire a session-init pruner).
LOG="$FORGE_ROOT/.claude/.session-token-log.jsonl"
PREFIX_CHARS=$(printf '%s' "${PREFIX_OUT:-}" | wc -c | tr -d ' ')
MEMORY_CHARS=$(printf '%s' "${MEMORY_OUT:-}" | wc -c | tr -d ' ')
TOTAL_CHARS=$((PREFIX_CHARS + MEMORY_CHARS))
APPROX_TOKENS=$((TOTAL_CHARS / 4))
TS=$(date -u +%Y-%m-%dT%H:%M:%SZ)
echo "{\"timestamp\":\"$TS\",\"agent_id\":\"$AGENT_ID\",\"layer\":\"${LAYER:-broad}\",\"query\":\"${QUERY//\"/\\\"}\",\"prefix_tokens\":$((PREFIX_CHARS/4)),\"memory_tokens\":$((MEMORY_CHARS/4)),\"total_approx_tokens\":$APPROX_TOKENS}" >> "$LOG"
