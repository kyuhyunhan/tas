---
name: loop-tdd
description: Red → Green → Refactor TDD for a single focused behavior. Internalized by the developer agent when the change is one observable behavior (single ViewModel state, single service method, single bug fix) and a failing test can be written before implementation. For larger or multi-file changes, use loop-maintain instead.
---

# Loop TDD

Developer-attached procedure. When you (developer) receive single-behavior work, drive it through this loop **autonomously**.

## When to use

- One observable behavior change.
- A failing test can be authored before implementation.
- The change is isolated (≤2 files typically).

Do NOT use for:
- Configuration-only changes (use `loop-maintain`).
- Multi-file refactors (use `loop-maintain`).
- Changes requiring coordinated server + client work (use `loop-maintain`).

## Phase sequence

```bash
$TAS_ROOT/scripts/resolve.sh tdd --forge $FORGE_ROOT
```

## Procedure

**Step 1 — Confirm the behavior in one sentence.** Ask the master if ambiguous.

**Step 2 (Red) — Author a FAILING test.**

- Use the stack's test framework (declared in `$FORGE_ROOT/.claude/resolve/gates.yaml`).
- Run the unit gate. A non-zero exit at Red is the GOAL. State this explicitly before running.

```bash
$TAS_ROOT/scripts/phase-advance.sh red --forge $FORGE_ROOT
# Non-zero exit expected at this phase.
```

**Step 3 (Green) — Minimal implementation.**

- Smallest possible code change to pass the failing test.
- No refactoring in this phase.
- No unrelated changes.
- Run gates: build, unit, architecture — all must pass.

```bash
$TAS_ROOT/scripts/phase-advance.sh green --forge $FORGE_ROOT
```

**Step 4 (Refactor, optional) — Improve while keeping green.**

- Re-run all post-gates after each refactor pass.
- Stop when the code is acceptable, not perfect.

**Step 5 (Commit).** Single commit, or Red + Green/Refactor split. Conventional prefix. HEREDOC message with Co-Authored-By trailer.

## Hard rules

- Red must be a *real* failure (assertion failed), not a syntax or compile error.
- Green is *minimum-viable* — do not over-implement.
- Refactor is *optional and bounded* — no scope creep into adjacent files.
- Layer / pattern rules from `ref-code-standards` and the attached stack-patterns ref always apply.
- Never call `reviewer` yourself — return to master.

## Output to master

Return with: failing-test path, implementation file paths, gate results per phase, commit SHA(s). The master decides next steps.
