---
name: forge-memory
description: Memory operations on the forge — surface candidate notes from the current session AND/OR write one approved note to memory/<layer>/. Invoke when the user says "remember this", "record this decision", "memory note", "what should we remember from this session", or at session end before a retrospective. STRICT append-only — drafts require user sign-off (pre-memory-write.sh enforces DRAFT marker).
---

# Forge Memory

Master-direct skill. Two modes — both end in `pre-memory-write.sh`-gated append to `$FORGE_ROOT/memory/<layer>/<id>-<slug>.md`.

## Mode A — Surface candidates

Use when: session is about to end, or the user asks "what should we remember from this?"

### Step 1 — Source scan

Pull material from three sources:

```bash
# (a) git log since session start (forge + workdir)
git -C $FORGE_ROOT log --since="$(date -u -d '8 hours ago' '+%Y-%m-%d %H:%M:%S' 2>/dev/null || date -u -v-8H '+%Y-%m-%d %H:%M:%S')" --oneline
git -C $WORKDIR  log --since="$(date -u -d '8 hours ago' '+%Y-%m-%d %H:%M:%S' 2>/dev/null || date -u -v-8H '+%Y-%m-%d %H:%M:%S')" --oneline
```

```text
(b) transcript scan — phrases signalling a durable decision:
    "decided", "chose X over Y", "picked", "settled on", "rationale",
    "trade-off", "because", "going forward", "from now on"

(c) recent changes to .claude/hooks/, .claude/scripts/, .claude/resolve/
    — process / governance changes that future sessions will need to discover
```

### Step 2 — Filter

Drop candidates that are:
- Already captured in an existing memory note (grep for the topic first).
- Derivable from code or commit history alone (e.g., "renamed X to Y" — git blame covers this).
- Ephemeral session state (in-progress work, "we'll come back to this").

### Step 3 — Cap

5 candidates max per session. Quality over quantity. For each accepted candidate, emit a DRAFT per Mode B Step 3.

## Mode B — Write one approved note

Use when: user signals a specific fact to record, or after Mode A surfacing.

### Step 1 (Classify) — pick a layer

Layers are declared in `$FORGE_ROOT/memory/TAXONOMY.md` (or `.yaml`). Pick the most specific match.

### Step 2 (ID + slug)

- ID = `YYYYMMDDTHHMM` of the decision/observation. Same-minute → append seconds.
- Slug = short kebab-case noun phrase.
- Path = `memory/<layer>/<id>-<slug>.md`.

### Step 3 (Draft)

Emit the full content to the transcript, prefixed by the literal marker `DRAFT:` on its own line. Required frontmatter:

```yaml
---
id: YYYYMMDDTHHMM
title: One-line title
when: YYYY-MM-DD
layer: <layer>
status: standing
# optional:
also_in: []
links:
  - to: <other-id>
    why: <one-sentence relation>
supersedes: <old-id>
legacy_id: <prior-id-system>
---
```

Body covers: **what** (the rule/fact), **why** (motivation, often a past incident or constraint), **how to apply** (when/where this kicks in). Lead with the rule/fact; cite paths with line numbers.

### Step 4 (Approve)

Wait for explicit user approval. If the user amends, re-emit the DRAFT and ask again. Do not edit a previously-emitted DRAFT in place — emit a fresh one.

### Step 5 (Write)

Write the approved content verbatim. `pre-memory-write.sh` will block the Write if no DRAFT marker appears in the recent transcript.

## Immutability (hard rule)

- A note is **never** edited after first write — not its body, not its frontmatter, not its status field.
- Supersession is declared in the NEW note via `supersedes:`. The old note's status stays as written.
- Reverse links are never added retroactively.
- Retroactive cross-references → write a bridging note.

This mirrors git: a commit is never edited; history changes only by adding new commits.

## Output discipline (Mode A)

- Cite file paths with line numbers when proposing a note.
- Distinguish OBSERVATION (cite-grounded) from INFERENCE (logical extension).
- Mark uncertain candidates as `[UNCERTAIN]` so the user weighs them separately.

## References

- `$FORGE_ROOT/memory/README.md` — full memory rules per forge.
- `$FORGE_ROOT/memory/TAXONOMY.md` — layer dictionary.
- `$TAS_ROOT/scripts/memory-search.sh` — search across the corpus.
