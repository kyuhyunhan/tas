#!/bin/bash
# G1-C2 — Every agent declares auto_loads
set -uo pipefail
AGENTS="$FORGE_ROOT/.claude/resolve/agents.yaml"
[[ -f "$AGENTS" ]] || exit 0
python3 - "$AGENTS" <<'PY'
import sys, yaml, os
cfg = yaml.safe_load(open(sys.argv[1]))
agents = cfg.get('agents', {}) or {}
if not agents:
    sys.exit(0)
total = len(agents)
# Presence test: `auto_loads:` key present (empty list IS valid — explicit "no skills needed").
with_field = sum(1 for a in agents.values() if 'auto_loads' in a)
ratio = with_field / total
if with_field == 0:
    sys.exit(0)
if ratio < 0.5:
    sys.exit(1)
if ratio < 1.0:
    sys.exit(1)
# All agents declare the field — now check EXCEEDED: every non-empty entry resolves to an installed skill.
skills_dir = os.path.expanduser('~/.claude/skills')
declared = set()
for a in agents.values():
    for s in (a.get('auto_loads') or []):
        declared.add(s)
if not declared:
    sys.exit(2)  # all empty — MET (presence) but nothing to resolve
resolved = sum(1 for s in declared if os.path.exists(os.path.join(skills_dir, s)) or os.path.exists(os.path.join(skills_dir, f'{s}.md')))
if resolved == len(declared):
    sys.exit(3)
sys.exit(2)
PY
