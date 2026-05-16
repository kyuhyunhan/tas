#!/bin/bash
# G2-C7 — dead note ratio < 40%
set -uo pipefail
python3 - "$FORGE_ROOT/memory" <<'PY'
import os, sys, re
root = sys.argv[1]
notes = []
ids = set()
for dp, dn, fn in os.walk(root):
    if '_legacy' in dp: continue
    for f in fn:
        if not f.endswith('.md'): continue
        if f in ('README.md', 'TAXONOMY.md'): continue
        path = os.path.join(dp, f)
        m = re.search(r'(\d{8}T\d{4}\d*)', f)
        if m:
            nid = m.group(1)
            ids.add(nid)
            notes.append((nid, path))
# count references: for each note, scan all OTHER notes for its id mentioned
referenced = set()
for nid, _ in notes:
    for _, other in notes:
        if other == _: continue
        try:
            with open(other) as fh:
                if nid in fh.read():
                    # not self-reference; check link form `to: <id>`
                    pass
        except OSError:
            continue
# simpler: iterate corpus, collect every `to: <id>` and `[[id]]` mention
mentions = set()
for _, path in notes:
    try:
        txt = open(path).read()
    except OSError:
        continue
    for m in re.finditer(r'(?:to:\s*|\[\[)(\d{8}T\d{4}\d*)', txt):
        mentions.add(m.group(1))
referenced = mentions & ids
total = len(notes)
dead = total - len(referenced)
if total == 0:
    sys.exit(2)
ratio = dead / total
print(f"# total={total} referenced={len(referenced)} dead={dead} ratio={ratio:.2%}", file=sys.stderr)
if ratio >= 0.6: sys.exit(0)
if ratio >= 0.4: sys.exit(1)
if ratio >= 0.2: sys.exit(2)
sys.exit(3)
PY
