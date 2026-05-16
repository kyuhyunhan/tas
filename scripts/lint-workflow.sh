#!/bin/bash
# lint-workflow.sh — sanity-check the resolve system itself.
#
# Validates:
#   1. Every workflow referenced in manifest.yaml has a spec file.
#   2. Every agent referenced in a workflow phase is in agents.yaml.
#   3. Every gate referenced in a workflow phase is in gates.yaml.
#   4. Every skill referenced in skills.yaml.local has a SKILL.md.
#   5. Every triggers list is non-empty.
#
# Exit 0 → system is consistent.
# Exit 1 → at least one violation; details printed.
#
# Intended for: CI on the forge, or manual `lint-workflow.sh` before commit.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FORGE_ROOT="${FORGE_ROOT:?FORGE_ROOT must be set; bind a forge first (/forge <product>)}"
RESOLVE_DIR="$FORGE_ROOT/.claude/resolve"
SKILLS_DIR="$FORGE_ROOT/.claude/skills"

VIOLATIONS=0
violate() {
    echo "  ✗ $1" >&2
    VIOLATIONS=$((VIOLATIONS + 1))
}
ok() {
    echo "  ✓ $1"
}

echo "── lint-workflow ───────────────────────────────"

# Run the heavy parsing in a single python pass — bash YAML loops are slow.
python3 - "$RESOLVE_DIR" "$SKILLS_DIR" <<'PY'
import os, sys, yaml

resolve_dir, skills_dir = sys.argv[1], sys.argv[2]
violations = 0
def violate(msg):
    global violations
    print(f"  ✗ {msg}")
    violations += 1
def ok(msg):
    print(f"  ✓ {msg}")

manifest_path = os.path.join(resolve_dir, "manifest.yaml")
with open(manifest_path) as f:
    manifest = yaml.safe_load(f)

agents_path = os.path.join(resolve_dir, "agents.yaml")
gates_path = os.path.join(resolve_dir, "gates.yaml")
skills_yaml_path = os.path.join(resolve_dir, "skills.yaml")
with open(agents_path) as f:
    agents = yaml.safe_load(f)["agents"]
with open(gates_path) as f:
    gates = yaml.safe_load(f)["gates"]
with open(skills_yaml_path) as f:
    skills_index = yaml.safe_load(f)["skills"]

allowed_agents = set(agents.keys())
allowed_gates = set(gates.keys())

# 1. Every workflow has a spec file and triggers
for wf_id, wf in manifest.get("workflows", {}).items():
    spec_rel = wf.get("spec")
    if not spec_rel:
        violate(f"workflow {wf_id}: missing `spec` field")
        continue
    spec_path = os.path.join(resolve_dir, spec_rel)
    if not os.path.isfile(spec_path):
        violate(f"workflow {wf_id}: spec file missing at {spec_path}")
        continue
    ok(f"workflow {wf_id}: spec present")

    triggers = wf.get("triggers") or []
    if not triggers:
        violate(f"workflow {wf_id}: empty triggers list")

    # 2 & 3. Validate agents and gates in phases
    with open(spec_path) as f:
        spec = yaml.safe_load(f)
    for phase in spec.get("phases", []):
        pid = phase.get("id")
        a = phase.get("agent")
        if a and a not in allowed_agents:
            violate(f"workflow {wf_id}, phase {pid}: agent '{a}' not in agents.yaml")
        for g in (phase.get("pre_gates") or []) + (phase.get("post_gates") or []):
            if g not in allowed_gates:
                violate(f"workflow {wf_id}, phase {pid}: gate '{g}' not in gates.yaml")

# 4. Every local skill in skills.yaml has a SKILL.md
for name, meta in skills_index.get("local", {}).items():
    rel = meta.get("path")
    if not rel:
        violate(f"local skill {name}: missing `path` field")
        continue
    full = os.path.join(os.path.dirname(skills_dir), rel)
    # path is relative to .claude/, so resolve as resolve_dir/../<path>
    full = os.path.join(resolve_dir, "..", rel)
    full = os.path.normpath(full)
    if not os.path.isfile(full):
        violate(f"local skill {name}: SKILL.md missing at {rel}")
    else:
        ok(f"local skill {name}: SKILL.md present")

print("")
print(f"Violations: {violations}")
sys.exit(1 if violations else 0)
PY
EXIT=$?

echo "────────────────────────────────────────────────"
exit $EXIT
