#!/bin/bash
# resolve.sh — given a workflow ID, print its deterministic phase sequence.
#
# Usage:
#   resolve.sh <workflow-id>            # human-readable phase sequence
#   resolve.sh --list                   # list all workflows
#   resolve.sh --agents                 # list allowed agents
#   resolve.sh --gates                  # list gates
#   resolve.sh <workflow-id> --json     # machine-readable phase array
#
# Output is the source of truth the model uses to decide what to do next.
# Skills MUST invoke this script and follow its output verbatim.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FORGE_ROOT="${FORGE_ROOT:?FORGE_ROOT must be set; bind a forge first (/forge <product>)}"
RESOLVE_DIR="$(cd "$FORGE_ROOT/.claude/resolve" && pwd)"
MANIFEST="$RESOLVE_DIR/manifest.yaml"

source "$SCRIPT_DIR/lib/read-yaml.sh"

# ── Subcommands ────────────────────────────────────────────────────

if [[ "${1:-}" == "--list" ]]; then
    echo "=== Forge Workflows ==="
    for wf in $(read_yaml_keys "$MANIFEST" "workflows"); do
        skill=$(read_yaml "$MANIFEST" "workflows.${wf}.skill")
        desc=$(read_yaml "$MANIFEST" "workflows.${wf}.description")
        printf "  %-16s skill=%-26s %s\n" "$wf" "$skill" "$desc"
    done
    exit 0
fi

if [[ "${1:-}" == "--agents" ]]; then
    AGENTS_YAML="$RESOLVE_DIR/agents.yaml"
    echo "=== Allowed agents ==="
    for a in $(read_yaml_keys "$AGENTS_YAML" "agents"); do
        when=$(read_yaml "$AGENTS_YAML" "agents.${a}.when")
        printf "  %-26s %s\n" "$a" "$when"
    done
    exit 0
fi

if [[ "${1:-}" == "--gates" ]]; then
    GATES_YAML="$RESOLVE_DIR/gates.yaml"
    echo "=== Gates ==="
    for g in $(read_yaml_keys "$GATES_YAML" "gates"); do
        desc=$(read_yaml "$GATES_YAML" "gates.${g}.description")
        printf "  %-22s %s\n" "$g" "$desc"
    done
    exit 0
fi

if [[ -z "${1:-}" ]]; then
    echo "Usage: resolve.sh <workflow-id|--list|--agents|--gates>" >&2
    exit 1
fi

WORKFLOW="$1"
SPEC_REL=$(read_yaml "$MANIFEST" "workflows.${WORKFLOW}.spec")
if [[ -z "$SPEC_REL" ]]; then
    echo "ERROR: unknown workflow '$WORKFLOW'" >&2
    echo "Run resolve.sh --list to see available workflows." >&2
    exit 2
fi

SPEC="$RESOLVE_DIR/$SPEC_REL"
if [[ ! -f "$SPEC" ]]; then
    echo "ERROR: workflow spec missing: $SPEC" >&2
    exit 2
fi

# ── Render phase sequence ──────────────────────────────────────────

if [[ "${2:-}" == "--json" ]]; then
    python3 - "$SPEC" <<'PY'
import sys, yaml, json
with open(sys.argv[1]) as f:
    spec = yaml.safe_load(f)
print(json.dumps(spec.get("phases", []), indent=2))
PY
    exit 0
fi

NAME=$(read_yaml "$SPEC" "name")
echo "=== $NAME ==="
echo ""

python3 - "$SPEC" <<'PY'
import sys, yaml
with open(sys.argv[1]) as f:
    spec = yaml.safe_load(f)

for i, phase in enumerate(spec.get("phases", []), 1):
    pid = phase.get("id", "?")
    pname = phase.get("name", pid)
    ptype = phase.get("type", "action")
    required = phase.get("required", False)
    when = phase.get("when")
    pre = phase.get("pre_gates") or []
    post = phase.get("post_gates") or []
    agent = phase.get("agent")
    skill = phase.get("skill")
    marker = phase.get("requires_marker")

    flags = []
    if required: flags.append("required")
    if when:     flags.append(f"when: {when}")
    if agent:    flags.append(f"agent={agent}")
    if skill:    flags.append(f"skill={skill}")
    if marker:   flags.append(f"requires_marker={marker!r}")
    if pre:      flags.append(f"pre_gates={pre}")
    if post:     flags.append(f"post_gates={post}")

    print(f"Phase {i}: {pid} — {pname}  [{ptype}]")
    for f in flags:
        print(f"  · {f}")
    procedure = phase.get("procedure") or []
    for step in procedure:
        print(f"    - {step}")
    print()

print("Skip rules:")
for rule in spec.get("skip_rules") or []:
    print(f"  · {rule}")
PY
