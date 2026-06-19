---
name: atelier-graph-repair
description: >-
  Run the deterministic integrity sweep over the atelier atomic knowledge graph
  (graph/atomic/{claims,entities,sources}): repair dangling references, collapse
  duplicate entities, recompute drifted content_hash, and propagate entity
  privacy from claims. Invoke when the user says "repair the atelier graph",
  "fix dangling refs / duplicate entities / content_hash drift / entity
  privacy", "run integrity repair after atomize/capture/consolidate", or "clean
  up the atomic graph". Each utility is dry-run by default, lossless, and
  idempotent (a clean graph reports 0 changes). Do NOT use for promote/dream
  tier transitions (that is atelier-consolidate), for ingesting/atomizing a new
  source (that is vault-ingest), or for a read-only recall/search query — this
  skill mutates node frontmatter and is a write operation, not a query.
version: 0.1.0
argument-hint: "[--apply] [--vault-root PATH]"
disable-model-invocation: true
metadata:
  domain: atelier
---

# atelier-graph-repair

Sweeps the **atomic knowledge graph** for structural integrity, repairing it in
place via four deterministic, idempotent utilities — no LLM is on the write
path; every fix is a pure function of the graph's own data.

This skill **repairs**. It does not promote, ingest, or query.
- does not perform promote/dream tier transitions on claims (that is
  `atelier-consolidate`)
- does not ingest or atomize a new source into the graph (that is `vault-ingest`)
- does not answer a recall/search question — it mutates frontmatter, so it is a
  write, never a read-only query

## What it repairs

| script | repairs | invariant |
|---|---|---|
| `refclean.py` | dangling `links[].to` / `is_about[]` / `derived_from[]`; bare-scalar links | **lossless**: remap to the real node id, else QUARANTINE into `unresolved_refs` — never delete |
| `entity_dedup.py` | two+ entity files sharing one `entry_id` | collapse to one canonical `<slug>-<id8>.md`; most-restrictive `sensitivity` wins |
| `rehash.py` | `content_hash` drifted from the canonical convention | recompute over frontmatter-minus-hash; body excluded |
| `entity_privacy.py` | entity `sensitivity` / `in_scheme` out of step with the claims about them | closure flows private from claims to entities; never downgrade a publicly-referenced entity |

## Engine dependency

These utilities defer to the atelier engine as the parse/schema authority
(`from runtime.index.parse import split_frontmatter`, `from runtime.util import
config`). The engine must be importable — set `PYTHONPATH` to the engine root:

```bash
export PYTHONPATH=/Users/kyuhyunhan/workspaces/atelier
```

The vault root is resolved at runtime from the engine config
(`config.load().vault.local`); the atomic dirs are
`<vault>/graph/atomic/{claims,entities,sources}`. Override with `--vault-root
PATH` if config is unavailable. No private path is hard-coded.

## Procedure

Run the four scripts **in this order**, each `--dry-run` first (the default),
then `--apply` only after the dry-run report is understood. Order matters:
refclean fixes edges before dedup merges nodes; rehash runs after both so it
hashes the corrected frontmatter; privacy runs last over settled nodes.

```bash
export PYTHONPATH=/Users/kyuhyunhan/workspaces/atelier
cd ~/.claude/skills/atelier-graph-repair   # the installed symlink

# 1. referential integrity
python refclean.py --dry-run        # then: python refclean.py --apply
# 2. duplicate entities
python entity_dedup.py --dry-run    # then: python entity_dedup.py --apply
# 3. content_hash drift
python rehash.py --dry-run          # then: python rehash.py --apply
# 4. entity privacy (optional out-of-tree hard rules via --rules FILE)
python entity_privacy.py --dry-run  # then: python entity_privacy.py --apply
```

Each prints a JSON report. On an already-clean graph every script reports
**0 changes** — that is the success signal for a verification run.

## Constraints

- **dry-run by default** — writes happen only with `--apply`.
- **lossless** — `refclean` never deletes a dangling target; it quarantines into
  `unresolved_refs`. `entity_dedup` deletes only redundant duplicate *files* of
  one `entry_id`, never content (it merges first).
- **parse via the engine** — always `split_frontmatter` from
  `runtime.index.parse`; never a naive `'---'` string split (it mishandles
  `---` inside body or yaml).
- **most-restrictive sensitivity wins** — when merging or propagating, `private`
  beats `internal` beats `public`.
- **never downgrade a publicly-referenced entity** — `entity_privacy` refuses a
  `public` hard rule on any entity with a private referencing claim, and closure
  never makes a publicly-referenced entity private.
- **idempotent** — every script is a fixed point on clean input; re-running is
  safe and reports 0 changes.
- **PII stays out of tree** — `entity_privacy` hard lists (PII / public labels)
  load from an external `--rules` JSON (e.g. under `~/.atelier/`), never embedded
  in this repo.

## Stop conditions

- All four dry-runs report 0 changes → the graph is already clean; stop.
- A dry-run reports changes → relay the report, get the user's go-ahead, then
  re-run that script with `--apply`. After applying, run `atelier reindex` /
  `atelier_doctor` so the DB projection reflects the repaired markdown.
