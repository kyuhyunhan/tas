---
name: forge-harden
description: Single-process meta-loop on the forge's holds.yaml — observe session → triage findings → inner loop over one pending hold at a time (select → classify → implement → demonstrate → catalog → commit → resolve → re-baseline → loop or exit). Invoke when the user says "harden" / "process improve" / "pick a hold" / "work on holds" / "retrospective" / "reflect on this session", or after a non-trivial workflow run completes.
---

# Forge Harden

Master-direct meta-loop. Hardens the forge's *process* (not the product). Acts on `$FORGE_ROOT/.claude/holds.yaml` as persistent state.

## When to use

- After a non-trivial workflow run completes.
- When the user says "retrospective" / "harden" / "pick a hold" / "process improve".
- When `holds.yaml` has standing `status: pending` entries.
- After a session where a workflow phase visibly slipped (out-of-order, gate skipped, post-hoc fix).

Do NOT use:
- Mid-task during product feature work — meta-loop is *between* product work, not *during*.
- For product feature work — that is the developer agent.
- For a single bug fix — that is `loop-tdd` (developer-internal).

## Procedure (outer + inner shape)

```
observe (optional) → triage (optional) → INNER LOOP × N → exit
```

Resolve the phase sequence first:

```bash
$TAS_ROOT/scripts/resolve.sh harden --forge $FORGE_ROOT
```

### Phase 1 (observe) — optional

Skip when the user explicitly says "process existing holds". Otherwise:

- List Task tool invocations + their `subagent_type`.
- List files written under `$FORGE_ROOT/memory/`.
- List git commits on workdir + forge.
- Note hook-block events.
- Note `phase-advance.sh` invocations and outcomes.

### Phase 2 (triage) — optional, DRAFT-gated

For each new finding **not already** in `holds.yaml`:

```yaml
DRAFT (holds.yaml entry):
- id: <slug>
  title: <one-line>
  category: 4-a-doc | 4-b-inventory | 4-c-mechanism | 4-d-refactor
  discovered: YYYY-MM-DD
  severity: low | medium | high
  leverage: low | medium | high
  recurrence_risk: low | medium | high
  status: pending
  notes: |
    <multi-line context>
```

Wait for user sign-off per finding. Append approved ones via precise `Edit` (preserves comments).

### Phase 3 — INNER LOOP entry: `select`

List pending entries by score `leverage × recurrence_risk` (low=1, medium=2, high=3). Use `AskUserQuestion` for the explicit pick. **Never auto-select** — the confirmation IS the contract.

If `holds.yaml` has zero pending entries: jump to `exit` with a "stable state" message.

### Phases 4–10 — per-hold work (inner body)

| Phase | Action | Note |
|---|---|---|
| 4 classify | Read category → pick sub-pipeline | 4-a/b/c/d, ask user if ambiguous |
| 5 risk-decompose | Order sub-steps low-risk first | Surface ONE; defer rest |
| 6 implement | Touch only files needed | No opportunistic cleanup |
| 7 demonstrate | Run mechanism on REAL recent work | Self-referential when possible |
| 8 catalog | New surfaces → new pending entries | DRAFT + sign-off, never silent |
| 9 commit | Conventional commit citing hold id | Explicit paths, no `-A` |
| 10 resolve | Mark hold `status: resolved` with commit ref | Preserve other fields |

#### Sub-pipeline dispatch (Phase 4)

| Category | Sub-pipeline |
|---|---|
| `4-a-doc` | Memory note via `forge-memory` (DRAFT + sign-off; append-only) |
| `4-b-inventory` | Create/fix missing artifact. Validation = re-run original surfacing command |
| `4-c-mechanism` | New semantics. **Stage passive → advisory → blocking** across iterations. NEVER straight to blocking on first iteration |
| `4-d-refactor` | Touch boundary preserved. Before/after invariants identical; gates pass identically across the cut |

### Phase 11 — re-baseline & loop decision

List remaining pending entries grouped by category. Use `AskUserQuestion` with three options:

| Option | Effect |
|---|---|
| Yes, pick next | Loop back to Phase 3 |
| No, exit | Skip to Phase 13 |
| Quit and capture lessons | Run Phase 12 then exit |

**Never auto-continue.** Convergence is user-driven.

### Phase 12 — capture (optional)

If user chose "quit and capture" OR a durable cross-cutting lesson clearly emerged across multiple iterations, draft a memory note under `memory/cross-cutting/` via `forge-memory`.

### Phase 13 — exit

Summarize: holds resolved this session, new holds cataloged, current pending count, one-line invitation for future invocation.

## Discipline invariants (what this skill protects against)

These anti-patterns are what this skill exists to block. Violating any of them is a regression — catch it at Phase 8 and make it a new pending hold.

1. **Silent decision** — never make an architectural choice without surfacing the trade-off to the user.
2. **Sweep mentality** — process ONE hold per iteration. The loop is the multiplier.
3. **Opportunistic cleanup** — catalog adjacent issues; do not fix.
4. **Synthetic demonstration** — run on REAL recent work, not a contrived test.
5. **Auto-chaining** — never proceed past re-baseline without explicit user choice.
6. **Premature blocking** — never promote a 4-c-mechanism to blocking enforcement on its first iteration.
7. **Mutation of resolved holds** — once `status: resolved`, the entry is frozen. Add new holds instead.
8. **Memory-note rewriting** — memory notes are append-only. `holds.yaml` is the mutable artifact; `memory/` is not.

## Self-reference invariant

When this skill modifies itself (e.g., extending a phase based on a prior finding), Phase 7's validation should use the prior version's mechanism on the new version's artifact when possible. If circular, defer Phase 7 to the next session's first invocation.

## References

- `$FORGE_ROOT/.claude/holds.yaml` — state file (mutable, but each entry is single-write until resolve).
- `$TAS_ROOT/scripts/phase-advance.sh` — most common demonstration tool.
