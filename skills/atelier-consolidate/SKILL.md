---
name: atelier-consolidate
description: >-
  Consolidate the atelier memory vault end-to-end in the background on the
  atomic-graph (v7) tier-transition model: PROMOTE eligible claims from
  surfacing:query → proactive behind the acceptance gate, run a DREAM pass that
  distills proactive → always (the capped T0 budget) and synthesizes new
  cross-claim generalizations — all behind an adversarial proposer/critic loop —
  then reindex and verify the projection. Invoke when the user says "consolidate
  atelier", "run the atelier consolidation", "promote and dream and reindex",
  "make the vault consistent / consolidate my memory", or after a capture/atomize
  session that left query-tier claims or a stale projection behind. Do NOT use
  for a single capture, a read-only recall/search query, atomizing a new source
  (use vault-ingest), or when the atelier MCP server is not connected.
---

# atelier-consolidate

Runs the **promote → dream → project** pipeline as a background Workflow on the
RFC 0005 **atomic graph**. In v7 there are no candidate/note/principle
*directories* to move between — `candidate` / `note` / `principle` are one Claim
at different **surfacing tiers** (`query ⊂ proactive ⊂ always`) plus an
acceptance state. Consolidation is therefore a set of **field transitions on
Claim nodes**, never a file move.

The human approval gates are replaced by an **adversarial proposer/critic loop**
that enforces explicit acceptance criteria, so it converges to quality without
you and only applies what clears the bar.

## The tier-transition model (what consolidation actually does)

| edge | transition | engine call shape |
|---|---|---|
| **promote** | `surfacing: query → proactive`, **behind the acceptance gate** (only `ac_status: passed` claims are eligible) | `atelier_promote_propose` → edit proposal → `atelier_promote_apply` |
| **dream ① distill** | `surfacing: proactive → always` (the capped **T0** budget) | `atelier_dream_distill(claim_ids)` |
| **dream ② synthesize** | mint NEW Claims that generalize a cluster, linked `refines`/`supports`, `derived_from` the source claims | `atelier_dream_plan` → `atelier_dream_synthesize(...)` |

The engine prepares deterministic call shapes (eligibility lists, clusters,
ready-to-fill calls) and writes the nodes; **no engine LLM** is on the write
path. The agent supplies only judgement (which gated claims earn proactive, which
clusters generalize, the synthesis text).

## What it does NOT do
- does not move files between candidate/note/principle directories — those are
  retired; everything is a surfacing-field transition on a Claim
- does not run in the foreground or block your session — it is a background Workflow
- does not promote claims that fail the critic's rubric, nor synthesize/distill
  past the bar
- does not write outside the vault; markdown stays the source of truth, the DB is
  reprojected from it
- does not atomize new sources (that is `vault-ingest`) or proceed if atelier MCP
  is unavailable — stop and say so

## Procedure (when triggered)
1. **Preflight** — ToolSearch for `atelier_doctor`; if the atelier MCP tools are
   not reachable, STOP and tell the user to connect atelier (see `atelier-setup`).
2. **Launch the background Workflow** (skill-invocation = explicit Workflow opt-in):
   ```
   Workflow({ scriptPath: "/Users/kyuhyunhan/.claude/skills/atelier-consolidate/consolidate.workflow.js" })
   ```
   It returns immediately; a task-notification arrives on completion.
3. **Relay the report** — claims promoted (query→proactive), claims distilled
   (proactive→always), claims synthesized (+ critic rounds), and the final drift
   status (`doctor` must be v7-green).

## The gate that replaces you (acceptance criteria)
The critic enforces two rubrics, defined transparently at the top of
`consolidate.workflow.js`:
- **PROMOTION_RUBRIC** — the claim is a real, reusable assertion (not status/
  trivia/dup); generalizes beyond its source; its `ac_status` is genuinely
  `passed`; promoting it to per-turn proactive push is warranted.
- **SYNTHESIS_RUBRIC** — the generalization is a true cross-claim "when X, Y"
  pattern (not a restatement of one member); novel vs existing `always` claims;
  every `source_claim_id` resolves; the relation (`refines`/`supports`) is sound.
Edit those constants to tune the bar.

## Phases (in the workflow)
`Survey` (read promote-eligible claims + the dream plan + drift) → `Promote`
(propose which eligible claims to elevate → critic gate → edit proposal →
`promote_apply`) → `Dream` (proposer/critic ping-pong over clusters →
`dream_synthesize` + `dream_distill` → `dream_complete`) → `Project`
(`atelier_reindex --full` + `atelier_doctor`).

## Notes
- Autonomy is by design: the user delegated approval to the proposer/critic loop.
- `reindex --full` is used because surfacing transitions rewrite frontmatter
  (and `content_hash`) in place; a full pass guarantees the projection reflects
  every tier change and any newly synthesized claim.
- After it runs, recall (`atelier_recall` at tier `proactive`/`always`) sees the
  newly elevated and synthesized claims — closing the markdown→DB consistency gap.
