---
name: vault-ingest
description: >-
  Ingest a knowledge source into the gorae vault — optionally extracting one or
  more YouTube transcripts first, then authoring the wiki (graph/sources +
  graph/entities) as the librarian, deferring to the atelier engine as schema
  authority. Invoke when the user gives a YouTube link (or list) to ingest, says
  "이 영상/자료 적재해줘", "wiki에 넣어줘", "new/에 자료 있다", or runs
  /vault-ingest. With no link argument it ingests files already staged in
  provenance/knowledge/_new/ (e.g. Web Clipper). Do NOT use for personal sources
  (diary, faith, writings — those are human-only provenance), to edit an
  already-ingested page, or for non-knowledge content.
---

# vault-ingest

Turns a knowledge source — a YouTube URL, or a file already staged in
`provenance/knowledge/_new/` — into committed wiki pages in the gorae vault,
running every operation through the **atelier engine** and authoring the wiki
markdown as the librarian.

This skill **ingests one source into the vault**. It does NOT:
- assert vault structure from memory — it **reads the live atelier schema first**
- write or migrate `provenance/` content (raw is human-only and immutable)
- create retired page types (`digest`, `theme`, `synthesis` — see Authority)
- ingest personal sources (diary/faith/writings) or edit already-ingested pages

## Authority — defer, don't assert

The gorae vault is **content only**; the engine is **atelier**
(`~/workspaces/atelier`). Schema, page types, entity categories, thresholds, and
lint rules live there, not in this skill. **Read them at the start of every run**
— this is the discipline that prevents schema drift (a prior standalone skill
hard-coded a `synthesis/` layer that had been retired, and a `raw/` path that had
moved to `provenance/`):

| Need | Location |
|---|---|
| Page types + entity categories + thresholds | `~/workspaces/atelier/schema/data/gorae.overlay.yaml` |
| Schema spec (human) | `~/workspaces/atelier/docs/SCHEMA_V4.md` |
| Architecture / ingest data flow | `~/workspaces/atelier/docs/ARCHITECTURE.md` |

Ground truth precedence: **live `graph/` pages → atelier schema → this skill.**
If this skill and the filesystem disagree, the filesystem wins.

## Tool ownership

- **atelier MCP** (everything structural): `atelier_youtube`,
  `atelier_fix_pending`, `atelier_prepare_commit`, `atelier_validate`,
  `atelier_reindex`, `atelier_lint`, `atelier_links`, `atelier_search`,
  `atelier_sync`. "Markdown is truth; the SQLite DB is a projection rebuilt by
  `atelier_reindex`."
- **direct markdown edit**: `graph/sources/*.md`, `graph/entities/*.md`
  (librarian role).
- There is **no `gorae` CLI** — the vault is pure content. Do not look for one.

## Scope

**In scope**: YouTube talks/lectures/interviews/podcasts; Web Clipper articles
staged in `provenance/knowledge/_new/`; domain knowledge that earns a wiki
source page.

**Out of scope**: personal diary/faith/writings (human-only `provenance`);
editing pages already ingested; non-YouTube video; "just summarize, don't
ingest" requests (answer normally).

## Input

Zero or more YouTube URLs as arguments.
- **URLs given** → extract each, then ingest.
- **none given** → ingest whatever is already in `provenance/knowledge/_new/`.
- If `_new/` is empty and no URLs are given, ask the user what to ingest.

## Process

### Phase 1 — Extraction (only if URLs were given)

For each YouTube URL:

1. **`atelier_youtube`** with the URL. It writes
   `provenance/knowledge/_new/<slug>.md` (original-language verbatim, inline
   `[mm:ss]` timestamps).
   - **Locale gotcha**: if `detected_language` is a locale tag (`en-US`, `pt-BR`)
     but only bare-code subtitle tracks exist (`en`), pass `lang` as the bare
     ISO-639-1 code, else extraction falls through to STT and fails.
   - `auto_subs` = ASR output → flag proper nouns as unreliable (e.g. a name may
     be mis-transcribed); correct only at the wiki layer, never the raw file.
   - Dedup is content-hash; a re-import is rejected — report and skip.
   - Keep the raw filename faithful to the source (typos included); the raw
     transcript is immutable.
2. Report each result (title / channel / duration / `transcript_source`).

### Phase 2 — Ingest (one file per run)

Process exactly one staged file per pass; if several are in `_new/`, name the
specific slug and leave the others.

3. **Read authority** — `gorae.overlay.yaml` + `SCHEMA_V4.md`. Confirm the
   current page types, entity `category` enum, and creation thresholds. Never
   skip this.
4. **STOP — decide with the user**: (a) domain (existing vs new), (b) angle/
   focus, (c) depth. Wait for the user; do not guess the domain.
5. **Place the raw source**: `git mv provenance/knowledge/_new/<slug>.md
   provenance/knowledge/<domain>/`.
6. **Normalize**: `atelier_fix_pending` → `atelier_prepare_commit` (pass the
   explicit path) → `atelier_validate`.
7. **Author `graph/sources/<slug>.md`** (librarian): a short summary on the
   author's own spine; Key Insights with `[mm:ss](youtube-deep-link)` for video
   sources; canonical `[[graph/...]]` / `[[provenance/...]]` wikilinks;
   frontmatter matching the live schema (e.g. `provenance: knowledge`).
8. **Author/update `graph/entities/*.md`** per the thresholds read in step 3 —
   typically: domain person (low threshold) → create; the domain hub entity
   (`category: domain`) → bump `source_count`, extend sub-themes / Key Insights /
   cross-refs; a domain concept that does not yet meet its source threshold →
   **mention in the source page, do not pre-create**. Cross-link existing related
   entities. Create **no** digest/theme/synthesis pages.
9. **Project**: `atelier_reindex --space gorae`.
10. **Log**: append a line to `graph/log.md` (`## [YYYY-MM-DD] ingest | {summary}`).
11. **Lint**: `atelier_lint` (auto: L1 broken-links, L3 source-count, L5 orphan,
    L6 stale). Review L2 (hallucination) and L7 (gap) manually.
12. **Commit**: `atelier_sync` with a semantic message (a deliberate commit
    beats the background 30s auto-commit poller, which would otherwise sweep the
    change under a generic message).

## Constraints

- Do NOT edit `provenance/` content — raw is immutable; corrections live in the
  wiki layer only.
- Do NOT inject facts not present in the source (atelier lint L2). Mark the
  author's quantitative/personal claims as "X's claim", do not endorse them.
- Do NOT `rmdir provenance/knowledge/_new/` — it is the Web Clipper staging dir;
  leave it even when empty.
- Do NOT create digest/theme/synthesis pages — retired (RFC 0003); synthesis is
  query-time via `atelier_think`, theme hubs are `category: domain` entities.
- One source per ingest pass.

## Stop conditions

- The source is committed via `atelier_sync`, reindexed, and lint-clean (L1/L3
  pass; L2/L7 reviewed). For multiple staged files, the skill is done with the
  named one and reports the others as still staged.
