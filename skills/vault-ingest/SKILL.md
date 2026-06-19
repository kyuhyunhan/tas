---
name: vault-ingest
description: >-
  Ingest a knowledge source into the gorae vault as an atomic graph —
  optionally extracting one or more YouTube transcripts first, landing the raw
  Source in raw/<domain>/, then ATOMIZING it into Entity + Claim nodes under
  graph/atomic/ (deferring to the atelier engine as schema authority). Invoke
  when the user gives a YouTube link (or list) to ingest, says "이 영상/자료
  적재해줘", "wiki에 넣어줘", "이 source atomize 해줘", or runs /vault-ingest.
  With no link argument it atomizes a raw Source that has no derived Claim yet
  (the engine's atomize nudge counts them). Do NOT use for personal sources
  (diary, faith, writings — those stay private, human-only), to re-edit a Claim
  already minted, or for non-knowledge content.
---

# vault-ingest

Turns a knowledge source — a YouTube URL, or a raw document already in
`raw/<domain>/` — into an **atomic graph** in the gorae vault: an immutable
**Source** node, plus the **Entity** and **Claim** nodes atomized from it. Every
structural decision is read from the **atelier engine**; the agent supplies only
the atomization judgement (which assertions, which subjects).

This skill **atomizes one Source per run**. It does NOT:
- assert vault structure from memory — it **reads the live atelier schema first**
- write per-source summary *pages* — the v7 model retired the legacy
  `graph/sources/*.md` summary page; a Source's knowledge lives in its derived
  Claims, not a prose mirror (the thin v7 Source node is provenance only)
- mutate a raw Source (it is immutable; atomization is purely *additive* on top)
- atomize personal sources without gating them `sensitivity: private`

## The model (RFC 0005 — atomic knowledge graph)

Three layers, all classification in **frontmatter fields**, never the path:

```
raw/<domain>/        (L1)  Source — immutable artifact + provenance
graph/atomic/        (L2)  Entity + Claim nodes (flat; dirs are cosmetic shards)
  ├ sources/                 the v7 Source node (mirrors the raw artifact's metadata)
  ├ entities/                canonical subjects (resolve-or-create, content-addressed)
  └ claims/                  one atomic assertion each
~/.atelier/cache     (L3)  SQLite + vectors — derived by reindex
```

- **No `_new/` staging dir.** A raw Source lands **directly** in its domain dir.
  "Awaiting atomization" is a *derived state* — a Source node with **no Claim
  `derived_from` it** — not a place. (The Web Clipper now writes to
  `raw/knowledge/`, superseding the old `_new/` convention.)
- The graph is **self-contained by `entry_id`**: `links[].to`, `is_about`, and
  `derived_from` all reference content-addressed `entry_id`s, never slugs/paths
  — so nodes are rename- and shard-safe.

## Authority — defer, don't assert

The gorae vault is **content only**; the engine is **atelier**
(`~/workspaces/atelier`). The v7 node schema, `entry_id` derivation, domains,
sensitivity, and surfacing tiers live there, not in this skill. **Read them at
the start of every run** — this discipline is what prevents schema drift:

| Need | Location |
|---|---|
| v7 node spec (source / entity / claim fields) | `~/workspaces/atelier/docs/rfc/0005-atomic-knowledge-graph.md` §4 |
| Canonical structure (paths + `entry_id` templates) | `~/workspaces/atelier/schema/data/structure.yaml` |
| `entry_id` derivation (the authority) | `~/workspaces/atelier/runtime/structure/resolver.py` → `entry_id()` |
| Architecture / ingest data flow | `~/workspaces/atelier/docs/ARCHITECTURE.md` |

Ground-truth precedence: **live `graph/atomic/` nodes → atelier resolver/schema
→ this skill.** If this skill and the engine disagree, the engine wins.

## Tool ownership

- **atelier MCP** (structural): `atelier_youtube` (extract transcript),
  `atelier_search` / `atelier_recall` (find existing entities/claims to dedup
  against), `atelier_reindex`, `atelier_doctor`, `atelier_lint`, `atelier_sync`.
  "Markdown is truth; the SQLite DB is a projection rebuilt by `atelier_reindex`."
- **engine resolver** (read-only, for the agent to compute deterministic ids):
  `~/workspaces/atelier/.venv/bin/python -c "from runtime.structure import
  resolver as r; print(r.entry_id(...))"` — run from the atelier repo root.
- **direct markdown write**: the v7 nodes under `graph/atomic/{sources,entities,
  claims}/` (the atomizer role).
- There is **no `gorae` CLI** and **no engine LLM on the write path** — the agent
  does the atomization judgement; the engine supplies ids, schema, and projection.

## Scope

**In scope**: YouTube talks/lectures/interviews/podcasts; Web Clipper articles
in `raw/knowledge/`; domain knowledge that earns Claims in the graph.

**Out of scope**: personal diary/faith/writings (private, human-only — never
push proactively); re-editing a Claim already minted; non-YouTube video; "just
summarize, don't ingest" requests (answer normally).

## Input

Zero or more YouTube URLs as arguments.
- **URLs given** → extract each (Phase 1), then atomize one (Phase 2).
- **none given** → atomize an existing un-atomized raw Source (a Source node with
  no derived Claim). Ask the engine which ones are pending if unsure.
- If nothing is pending and no URLs are given, ask the user what to ingest.

## Process

### Phase 1 — Extraction (only if URLs were given)

For each YouTube URL:

1. **`atelier_youtube`** with the URL. It lands the **raw transcript artifact
   directly in `raw/knowledge/<subdomain>/`** (original-language verbatim, inline
   `[mm:ss]` timestamps, no `_new/` staging). This is the immutable L1 artifact.
   The **v7 Source node** under `graph/atomic/sources/` (and the Entity/Claim
   nodes) is minted in Phase 2 — `atelier_youtube` does NOT create it.
   - **Locale gotcha**: if `detected_language` is a locale tag (`en-US`, `pt-BR`)
     but only bare-code subtitle tracks exist (`en`), pass `lang` as the bare
     ISO-639-1 code, else extraction falls through to STT and fails.
   - `auto_subs` = ASR output → proper nouns may be mis-transcribed; correct them
     **only in the Claim layer**, never in the raw artifact.
   - Dedup is content-hash; a re-import is rejected — report and skip.
2. Report each result (title / channel / duration / `transcript_source`).

### Phase 2 — Atomize (one Source per run)

Atomize exactly one Source per pass; if several are un-atomized, name the one you
take and leave the rest.

3. **Read authority** — RFC 0005 §4 (node fields) + `structure.yaml` (`entry_id`
   templates) + the resolver. Confirm the current `domain` values, `sensitivity`
   values, `surfacing` tiers, and SKOS/PROV relation vocab. Never skip this.

4. **STOP — decide with the user** (knowledge only): (a) domain/subdomain,
   (b) angle/depth (how finely to atomize). Wait for the user; do not guess the
   domain. For personal material: do not atomize unless the user explicitly asks,
   and atomize it **`sensitivity: private`** (never pushed proactively).

5. **Mint the v7 Source node** under `graph/atomic/sources/` from the raw
   artifact's metadata (the raw doc itself is the immutable L1 artifact; this is
   its L2 node — a thin provenance anchor, NOT a summary page):
   - `entry_id` = `resolver.entry_id("source", created_at=<iso>,
     discriminator=<video_id|url|content-hash>)`;
   - `kind: source`, `schema_version: 7`, `created_at`, `content_hash`, `title`,
     `domain` (knowledge / personal / …), `sensitivity`, `attributed_to`
     (the authoring channel, PROV-O `wasAttributedTo`);
   - source-type extension: youtube → `source_type`, `source_url`, `channel`,
     `channel_url`, `duration_sec`, `language`, `transcript_source`; web_clipper →
     `source_type`, `source_url`.

6. **Two-pass atomization** — deterministic entity carry first, then LLM claims:

   **Pass A — entity recognition + resolve-or-create (closed to the source).**
   Identify the subjects the source actually references — do NOT invent subjects
   the source does not mention. For each subject, **resolve-or-create** its Entity:
   - compute its id with the resolver: `entry_id("entity", type=<Type>,
     pref_label=<label>)` — `pref_label` is normalized (`strip().lower()`) before
     hashing, so the **same subject → same id = dedup** (this is what links the
     graph across sources);
   - if that id already exists under `graph/atomic/entities/`, **reuse it**
     (optionally extend `alt_label[]` / `gloss` / SKOS `links[]` — broader /
     narrower / related); otherwise **create** the Entity node
     (`kind: entity`, `schema_version: 7`, `type`, `pref_label`,
     `in_scheme: [<domain>]`).
   The carry is deterministic in that ids and dedup are mechanical (the resolver);
   the recognition itself is the agent's read of the source.

   **Pass B — LLM claim extraction (the agent's judgement).** Read the raw
   artifact and decompose it into **atomic assertions**. For each, write a Claim
   node under `graph/atomic/claims/`:
   - `statement` — one atomic assertion (correct ASR proper-noun errors here);
   - `entry_id` = `resolver.entry_id("claim", statement=<statement>,
     derived_from=<source entry_id>)` (statement normalized → content-addressed,
     idempotent);
   - `kind: claim`, `schema_version: 7`, `created_at`, `content_hash`;
   - `derived_from: [<source entry_id>]` (PROV-O `wasDerivedFrom` — the Pass-5 Source);
   - `is_about: [<entity entry_id>…]` — the Pass-A entities this claim asserts of;
   - `attributed_to` — the author/speaker of the claim (not the channel);
   - `generated_by: atomize`;
   - `links: [{to, rel, why}]` where `rel ∈ supports | refutes | refines` for
     claim↔claim relations (only when a real relation exists);
   - `context?` — a short grounding note that prevents context-loss;
   - `domain` (e.g. `knowledge` / `personal`), `sensitivity`
     (`public` for knowledge; **`private` for personal**), `surfacing: query`
     (knowledge defaults to on-query; promotion to `proactive` is the
     consolidate skill's job, not ingest's).

   Mark the author's quantitative/personal claims as *their* claim in the
   `statement` ("X argues that…"), not as endorsed fact.

7. **Idempotency** — sources dedup by their content-addressed id, entities dedup
   by content-id, claims dedup by `content_hash` over the normalized statement.
   Re-atomizing the same Source is safe (same ids → same files). If a target
   entity/source id already resolves, do NOT create a duplicate.

8. **Project**: `atelier_reindex` (the changed atomic nodes; `--full` only if a
   broad re-link occurred). The 30s autosync poller also reindexes changed files,
   so a manual reindex is mostly for an immediate read-back.

9. **Verify**: `atelier_doctor` (must stay v7-green) and `atelier_lint`
   (broken-link / orphan / stale). Resolve any **dangling edge** — a `links[].to`
   / `is_about` / `derived_from` pointing at a non-existent `entry_id`. (The
   `_legacy` breadcrumbs and slug mentions inside `why` text are benign historical
   metadata, not live edges — leave them.)

10. **Commit**: `atelier_sync` with a semantic message, or let the autosync poller
   sweep it under a generic message (acceptable — changes land + push).

## Hardening (verified facts the engine enforces)

- **Self-containment by `entry_id`.** Every live edge (`links[].to`, `is_about`,
  `derived_from`) is a content-addressed `entry_id` — **never a path or slug**.
  Compute ids only via the resolver; never hand-write a uuid.
- **Entity id IS the dedup key.** `entry_id("entity", type, pref_label)` with the
  normalized `pref_label` is the canonicalization mechanism. Two sources naming
  the same subject converge on one Entity — that is what links the graph across
  sources. Always resolve-before-create.
- **Source is immutable; atomization is additive.** Claims sit *on top of* the
  raw Source; the raw artifact and the Source node are never rewritten. An
  imperfectly atomized narrative still loses nothing — the original remains,
  indexed and on-query.
- **No legacy `graph/sources/*.md` summary page.** The retired v5 layer wrote ONE
  prose summary page per source mirroring the input document. Do not author or
  look for it. The v7 **Source node** under `graph/atomic/sources/` is a different
  thing — a thin provenance anchor (no summary prose); a source's *knowledge*
  lives in its derived Claims + the Entities they are about.
- **Personal = private.** Atomized personal Claims carry `sensitivity: private`
  and are reachable **only by explicit on-query** — never pushed proactively.
- **Quote dates as strings** in YAML frontmatter (`created_at: "2026-06-18T…"`),
  else YAML parses a date object and validation fails.

## Constraints

- Do NOT mutate the raw artifact — corrections (ASR, framing) live in the Claim
  layer only.
- Do NOT inject assertions absent from the source. Atomize what is *there*.
- Do NOT create the retired `graph/sources/*.md` / `graph/entities/*.md` legacy
  wiki pages — only v7 nodes under `graph/atomic/`.
- Do NOT hand-mint `entry_id`s — derive every id through the resolver.
- One Source per atomize pass.

## Stop conditions

- The Source is atomized: its Entities are resolved-or-created, its Claims are
  written `derived_from` it, reindexed, and lint/doctor clean (no dangling
  `entry_id` edges). For multiple un-atomized Sources, the skill is done with the
  named one and reports the others as still pending atomization.
