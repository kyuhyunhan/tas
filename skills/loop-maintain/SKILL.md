---
name: loop-maintain
description: End-to-end maintenance procedure for the developer agent — Plan → Implement → Test → Verify → Commit. Internalized as an autonomous loop when the developer receives a feature, fix, or refactor request that spans more than a single focused behavior. For a single focused behavior with a writable failing test up front, use loop-tdd instead.
---

# Loop Maintain

Developer-attached procedure. When you (developer) receive end-to-end feature, fix, or refactor work, follow this loop **autonomously** — the master delegates the whole task; you return when committed and ready for the master's next call.

## When to use

- The change touches >2 files.
- The change mixes multiple behaviors.
- The change is configuration-only.
- The change cannot be expressed as a single failing test up front.

For a single observable behavior with a writable failing test → use `loop-tdd`.

## Phase sequence

The forge declares the phase list in `$FORGE_ROOT/.claude/resolve/workflows/maintain-loop.yaml`. Resolve it:

```bash
$TAS_ROOT/scripts/resolve.sh maintain-loop --forge $FORGE_ROOT
```

The output is the **canonical phase sequence**. Execute phases in printed order. Honor `when:` conditions exactly (skip a phase iff the condition is false).

After each phase, run its `post_gates`:

```bash
$TAS_ROOT/scripts/phase-advance.sh <phase-id> --forge $FORGE_ROOT
```

A non-zero gate exit halts the loop. Fix the issue and re-run the gate before proceeding.

## Phase shape (canonical)

| Phase | Action |
|---|---|
| plan | State the change in 1–3 sentences. List files to touch. Read `CLAUDE.md` and neighbor files. Declare `server_changes`/`client_changes` lists when forge has split deployment |
| implement | Touch only the planned files. Mirror existing patterns. No opportunistic cleanup |
| test | Write or update tests for new behavior. Use the stack's test framework |
| verify | Run tests via Bash. Iterate until green |
| commit | Stage explicit paths (never `git add -A`). Conventional prefix (feat / fix / chore / refactor / docs / test). HEREDOC message with Co-Authored-By trailer |

Forge-declared variations (e.g., split server-vs-client implement phases, deploy phases) follow the same shape — read `resolve.sh` output for the exact list.

## Hard rules

1. Honor the forge's `manifest.yaml#hard_rules` — surfaced in your prompt by the dispatch wrapper. Never violate silently.
2. Honor layer / dependency-direction rules from `CLAUDE.md`.
3. Bug fixes target source, not config — confirm before editing build/deploy yaml.
4. Never mix unrelated changes in one commit. Smaller diffs review faster.
5. Never call `reviewer` yourself — return to master with results; master decides on review.

## Output to master

Before starting: quote the `resolve.sh` output verbatim so the user can see the phase list.

After each phase: "Phase X complete; running gate(s): …" — never claim a phase is done without running its gates.

When the loop completes, return with:
- Files touched (paths).
- Tests added (paths).
- Gate results (passed / failed).
- Commit SHA(s).

The master decides next steps (review, deploy, harden, etc.).
