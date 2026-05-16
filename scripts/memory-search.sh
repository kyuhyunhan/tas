#!/bin/bash
# memory-search.sh <query> [--layer <layer>] [--limit N] [--format text|json|prompt]
#
# Returns ranked memory notes from $FORGE_ROOT/memory matching the query.
# Designed to be the canonical retrieval entry point for sub-agent prompts
# (G2-C4 / G2-C5 / G4-C5 of the forge rubric).
#
# Ranking factors per note (sum of weighted signals):
#   - Layer match  (3.0 if --layer matches frontmatter `layer:`)
#   - Recency      (0..2 linear with file mtime over the corpus)
#   - Keyword hits (1.0 per occurrence of any query term in
#                   title + frontmatter description + first 600 chars of body,
#                   capped at 5.0)
#
# Output formats:
#   text   (default) — one line per result:
#                       <score>\t[layer]\t<id>\t<title>\t<path>
#   json             — list of result objects
#   prompt           — markdown frontmatter blocks suitable for direct prompt
#                      injection (used by dispatch-agent.sh in G2-C5 wiring)
#
# Empty query is allowed — falls back to recency only (acts as `recent --layer X`).
# Output is empty when no notes are found.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FORGE_ROOT="${FORGE_ROOT:?FORGE_ROOT must be set; bind a forge first (/forge <product>)}"
MEMORY_ROOT="$FORGE_ROOT/../memory"

QUERY=""
LAYER=""
LIMIT="5"
FORMAT="text"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --layer)  LAYER="$2"; shift 2 ;;
        --limit)  LIMIT="$2"; shift 2 ;;
        --format) FORMAT="$2"; shift 2 ;;
        --help|-h)
            echo "usage: memory-search.sh <query> [--layer L] [--limit N] [--format text|json|prompt]" >&2
            exit 0 ;;
        *) QUERY="${QUERY:+$QUERY }$1"; shift ;;
    esac
done

[[ ! -d "$MEMORY_ROOT" ]] && { echo "memory root not found: $MEMORY_ROOT" >&2; exit 2; }

python3 - "$MEMORY_ROOT" "$QUERY" "$LAYER" "$LIMIT" "$FORMAT" <<'PY'
import sys, os, re, json, time

memory_root, query, layer_filter, limit_str, fmt = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4], sys.argv[5]
limit = int(limit_str)
terms = [t.lower() for t in re.findall(r'\w+', query) if len(t) > 2]

# Collect notes
notes = []
for dp, dn, fn in os.walk(memory_root):
    if '_legacy' in dp: continue
    for f in fn:
        if not f.endswith('.md'): continue
        if f in ('README.md', 'TAXONOMY.md'): continue
        path = os.path.join(dp, f)
        try:
            mtime = os.path.getmtime(path)
            with open(path) as fh:
                txt = fh.read()
        except OSError:
            continue
        # Frontmatter parse
        fm = {}
        body = txt
        if txt.startswith('---'):
            end = txt.find('---', 3)
            if end > 0:
                fm_raw = txt[3:end]
                body = txt[end+3:]
                for line in fm_raw.splitlines():
                    m = re.match(r'^\s*(\w+):\s*(.*?)\s*$', line)
                    if m:
                        fm[m.group(1)] = m.group(2)
        nid = fm.get('id') or re.search(r'(\d{8}T\d{4}\d*)', f) and re.search(r'(\d{8}T\d{4}\d*)', f).group(1) or ''
        title = fm.get('title', f)
        nlayer = fm.get('layer', os.path.basename(dp))
        notes.append({
            'id': nid,
            'title': title,
            'layer': nlayer,
            'path': path,
            'mtime': mtime,
            'body_head': body[:600].lower(),
            'title_lower': title.lower(),
        })

if not notes:
    sys.exit(0)

# Recency range for normalization
mtimes = [n['mtime'] for n in notes]
oldest, newest = min(mtimes), max(mtimes)
span = max(newest - oldest, 1)

scored = []
for n in notes:
    score = 0.0
    if layer_filter and n['layer'] == layer_filter:
        score += 3.0
    # Recency contribution 0..2
    score += 2.0 * (n['mtime'] - oldest) / span
    # Keyword hits in title (weight x2) + body head (weight x1), capped at 5
    hits = 0
    for t in terms:
        hits += 2 * n['title_lower'].count(t)
        hits += n['body_head'].count(t)
    score += min(hits, 5.0)
    if score > 0:  # exclude completely irrelevant when query is non-empty
        scored.append((score, n))
    elif not terms and not layer_filter:
        scored.append((score, n))   # bare call → keep all

scored.sort(key=lambda r: r[0], reverse=True)
top = scored[:limit]

if fmt == 'json':
    out = []
    for score, n in top:
        out.append({
            'id': n['id'],
            'title': n['title'],
            'layer': n['layer'],
            'path': n['path'],
            'score': round(score, 2),
        })
    print(json.dumps(out, indent=2))
elif fmt == 'prompt':
    if not top:
        print("(no relevant memory notes)")
    else:
        print("## Relevant memory notes (auto-retrieved)")
        print("")
        for score, n in top:
            print(f"### [[{n['id']}]] — {n['title']}")
            print(f"  layer: {n['layer']}  score: {score:.2f}")
            print(f"  full: {n['path']}")
            print("")
else:
    for score, n in top:
        print(f"{score:.2f}\t[{n['layer']}]\t{n['id']}\t{n['title']}\t{n['path']}")
PY
