---
name: skillify
description: >-
  Turn a workflow you just performed (or a recurring failure) into a durable TAS
  skill — extract the repeatable procedure, gate it against the bar, author the
  SKILL.md, install it, verify it routes, and file it to the brain. Invoke when
  the user says "skillify this", "skillify it", "make this a skill", or after a
  multi-step workflow that will recur. Do NOT use to create a skill that restates
  what the model already does by default (the bar gate refuses), to duplicate an
  existing skill, or to edit one that exists (edit it directly).
---

# skillify

The meta-skill: it builds skills. Adapted from Garry Tan's *skillify* — *"every
failure becomes a skill; the bug becomes structurally impossible to repeat"* —
with one addition TAS requires up front: **the bar gate.** gbrain assumes a
failure justifies the skill; TAS also demands the skill not merely restate base
capability.

The loop to preserve: **latent space builds the deterministic tool, then the
deterministic tool constrains the latent space.** A skill's job is to move
*precision* work out of model reasoning and into a procedure (or a script) the
model is then disciplined to follow.

This skill **creates a skill.** It does not:
- create a skill that restates base capability — **Gate 0 refuses it**
- duplicate an existing skill (extend that one instead)
- edit an existing skill (do that directly)
- skip the resolver/DRY/smoke checks ("works today" ≠ a skill)

## Procedure

### Gate 0 — the bar (refuse here, loudly, if it fails)
Name which thing the candidate is, or stop:
- an **operational guardrail**, an **org-specific convention**, a **non-obvious
  procedure**, or a **gotcha** unavailable in base training; and
- which single [Anthropic category](https://claude.com/blog/lessons-from-building-claude-code-how-we-use-skills)
  it fits cleanly.
If the honest answer is "the model already does this" → **refuse**, explain why,
and suggest a note or a `CLAUDE.md` line instead. This gate is the whole reason
TAS stays clean; do not wave it through.

### 1 — Extract the pattern
Examine what just happened. State the repeatable procedure in steps. Split it:
- **deterministic** (same input → same output: a grep, a parse, a diff range, an
  API call) → belongs in a companion script, not in model reasoning;
- **judgment** (latent: triage, design, wording) → stays as markdown procedure.
Doing deterministic work in latent space is the bug skillify exists to kill.

### 2 — Author the contract
Copy `skills/skill.md.tmpl` → `skills/{name}/SKILL.md`. `name` matches the dir.
The `description` is the resolver — sharp triggers + clear anti-indicators, since
its quality decides whether the skill ever routes. Keep the body lean; state what
it does NOT do.

### 3 — Companion code (only if there is deterministic work)
If step 1 found precision work, write the script as a companion file the skill
alone uses (it travels via the symlink). The skill then *instructs the model to
run it* rather than reason about it. Most procedural skills need none — do not
invent one.

### 4 — Validate (gbrain's resolver-eval + check-resolvable)
- `./setup` — install the symlink.
- **Resolver eval**: confirm the skill appears in the resolver and would route on
  its trigger phrases (not a "dark" orphan).
- **DRY / check-resolvable**: confirm no existing skill already covers it and it
  is not base capability (Gate 0, re-checked against the live skill list).
- **Smoke test**: walk the procedure once against a real input; fix what breaks.

### 5 — Install + commit
`./setup` (done) and commit Conventional: `feat(skills): add {name}`.

### 6 — File to the brain (the constellation touchpoint)
Record the new skill so the vault remembers it: call `atelier_learning_capture`
with the observation (what the skill is + when it triggers), a real why, and a
rule. This is gbrain's "brain filing" step — here it is literally the atelier
engine. Skip only if atelier is not connected.

## Edge cases

- **Fails the bar** → refuse + explain; offer a `CLAUDE.md` line or a note.
- **Duplicates an existing skill** → extend that skill; do not mint a sibling.
- **Pure judgment, no repeatable procedure** → it is not a skill (and TAS has no
  recipes) — leave it as a note or a `CLAUDE.md` convention.
- **Mixed/straddles categories** → split it; the best skills fit one category.
- **Would ship it** → hand off to `ship-pr` once the smoke test is green.
