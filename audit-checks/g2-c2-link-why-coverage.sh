#!/bin/bash
# G2-C2 — Every links: entry has why:
set -uo pipefail
python3 - "$FORGE_ROOT/memory" <<'PY'
import os, sys, re
root = sys.argv[1]
total_links = 0
links_with_why = 0
for dp, dn, fn in os.walk(root):
    if '_legacy' in dp: continue
    for f in fn:
        if not f.endswith('.md'): continue
        path = os.path.join(dp, f)
        try:
            txt = open(path).read()
        except OSError:
            continue
        # crude scan: count `- to:` and check if next non-blank line is `why:`
        lines = txt.splitlines()
        i = 0
        while i < len(lines):
            line = lines[i].strip()
            if line.startswith('- to:'):
                total_links += 1
                # look ahead for why: within 3 lines
                for j in range(i+1, min(i+4, len(lines))):
                    if lines[j].strip().startswith('why:'):
                        links_with_why += 1
                        break
            i += 1
if total_links == 0:
    sys.exit(2)  # vacuously met
ratio = links_with_why / total_links
print(f"# links={total_links} with_why={links_with_why} ratio={ratio:.2%}", file=sys.stderr)
if ratio < 0.5: sys.exit(0)
if ratio < 0.9: sys.exit(1)
if ratio < 0.95: sys.exit(1)
if ratio < 0.99: sys.exit(2)
sys.exit(3)
PY
