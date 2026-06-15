---
name: atelier-consolidate
description: >-
  Consolidate the atelier memory vault end-to-end in the background: promote
  eligible candidate learnings, run a dream pass (cluster → synthesize) behind an
  adversarial proposer/critic loop, then reindex --full and verify the DB
  projection so every artifact is consistent and queryable. Invoke when the user
  says "consolidate atelier", "run the atelier consolidation", "promote and dream
  and reindex", "make the vault consistent / consolidate my memory", or after a
  capture/learning session that left candidates or stale projection behind. Do
  NOT use for a single capture, a read-only recall/search query, or when the
  atelier MCP server is not connected.
---

# atelier-consolidate

Runs the full **capture → accept → dream → project** pipeline as a background
Workflow. The human approval gates (candidate acceptance, principle approval) are
replaced by an **adversarial proposer/critic loop** that enforces explicit
acceptance criteria — so it converges to quality without needing you, and only
applies what clears the bar.

## What it does NOT do
- does not run in the foreground or block your session — it is a background Workflow
- does not accept candidates or approve principles that fail the critic's rubric
- does not write outside the vault; markdown stays the source of truth, the DB is reprojected from it
- does not proceed if atelier MCP is unavailable — stop and say so

## Procedure (when triggered)
1. **Preflight** — ToolSearch for `atelier_doctor`; if the atelier MCP tools are
   not reachable, STOP and tell the user to connect atelier (see `atelier-setup`).
2. **Launch the background Workflow** (skill-invocation = explicit Workflow opt-in):
   ```
   Workflow({ scriptPath: "/Users/kyuhyunhan/.claude/skills/atelier-consolidate/consolidate.workflow.js" })
   ```
   It returns immediately; a task-notification arrives on completion.
3. **Relay the report** — promoted candidates, principles approved (+ critic
   rounds), and the final drift status (`doctor` D2 must be OK).

## The gate that replaces you (acceptance criteria)
The critic enforces two rubrics, defined transparently at the top of
`consolidate.workflow.js`:
- **PROMOTION_RUBRIC** — real why, actionable/generalizable, not status/trivia/dup, sound topic.
- **PRINCIPLE_RUBRIC** — clear "when X do Y", evidence across ≥3 projects, novel vs
  existing always-inject principles, every source_slug resolves.
Edit those constants to tune the bar. New principles are created at
`on-relevant-prompt` priority (not `always-inject`) by default.

## Phases (in the workflow)
`Survey` (read candidates + principles) → `Promote` (propose topics → critic gate
→ accept) → `Dream` (dream_plan → proposer/critic ping-pong, ≤3 rounds →
synthesize + approve) → `Project` (`atelier_reindex --full` + `atelier_doctor`).

## Notes
- Autonomy is by design: the user delegated approval to the proposer/critic loop.
- `reindex --full` is required because candidate→notes promotion *moves* files;
  incremental alone would leave the stale candidate slug in the DB.
- After it runs, retrieval (`recall`/`search`/`think`/principles) sees the new
  artifacts — closing the markdown→DB eventual-consistency gap.
