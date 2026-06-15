---
name: skillify
description: >-
  Turn a workflow you just performed (or a recurring failure) into a durable
  skill — extract the repeatable procedure, gate it against the bar, author the
  SKILL.md, install it, verify it routes, and (when atelier is connected) file it
  to the brain. Invoke when the user says "skillify this", "skillify it", "make
  this a skill", or after a multi-step workflow that will recur. Do NOT use to
  create a skill that restates what the model already does by default (the bar
  gate refuses), to duplicate an existing skill, or to edit one that exists (edit
  it directly).
---

# skillify

The meta-skill: it builds skills. Adapted from Garry Tan's *skillify* — *"every
failure becomes a skill; the bug becomes structurally impossible to repeat"* —
with one addition required up front: **the bar gate.** gbrain assumes a failure
justifies the skill; here we also demand the skill not merely restate base
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

## Environment — detect the install model first

This skill runs in two environments. Detect which **before** authoring, and
adapt steps 2, 4, and 5:

- **TAS repo** — a `skills/` tree with `skills/skill.md.tmpl` and a `./setup`
  script that installs each `skills/{name}/` as a symlink into `~/.claude/skills`,
  plus `resolver-eval` / `check-resolvable` tooling. Use the tooling paths.
- **Plain global skills** — `~/.claude/skills/{name}/SKILL.md` directories, each
  just a `SKILL.md` (no template, no `./setup`, no resolver scripts). Authoring
  *is* the install: writing the file in the right dir is all it takes. Use the
  fallback paths.

A quick check: if `skills/skill.md.tmpl` and `./setup` exist at the repo root,
you are in TAS; otherwise treat it as a plain global setup.

## Procedure

### Gate 0 — the bar (refuse here, loudly, if it fails)
Name which thing the candidate is, or stop:
- an **operational guardrail**, an **org-specific convention**, a **non-obvious
  procedure**, or a **gotcha** unavailable in base training; and
- which single [Anthropic category](https://claude.com/blog/lessons-from-building-claude-code-how-we-use-skills)
  it fits cleanly.
If the honest answer is "the model already does this" → **refuse**, explain why,
and suggest a note or a `CLAUDE.md` line instead. This gate is the whole reason
the skill set stays clean; do not wave it through.

### 1 — Extract the pattern
Examine what just happened. State the repeatable procedure in steps. Split it:
- **deterministic** (same input → same output: a grep, a parse, a diff range, an
  API call) → belongs in a companion script, not in model reasoning;
- **judgment** (latent: triage, design, wording) → stays as markdown procedure.
Doing deterministic work in latent space is the bug skillify exists to kill.

### 2 — Author the contract
**If a template exists** (TAS: `skills/skill.md.tmpl`), copy it →
`skills/{name}/SKILL.md`. **Otherwise** (plain global) author
`~/.claude/skills/{name}/SKILL.md` directly using the frontmatter shape below.
Either way, `name` matches the dir.

**Naming convention** — lowercase kebab-case, and `name:` equals the directory.
Pick one of two shapes:
- **Area-scoped** (the skill operates on one product/engine/domain): `<area>-<action>`,
  so related skills cluster in the list — e.g. `atelier-setup`, `atelier-consolidate`.
- **Cross-cutting** (a general dev action, no single domain): `<action>-<object>`,
  imperative verb first — e.g. `ship-pr`, `maintain-app-fe`.

Use area-first only when the area is a clean noun other skills will share;
otherwise default to verb-object. Established coined verbs are allowed when
idiomatic and unambiguous (e.g. `skillify`). Avoid noun-`-er` agent nouns
(`docs-syncer` → `sync-docs`) and vague single words.

The `description` is the resolver — sharp triggers + clear anti-indicators, since
its quality decides whether the skill ever routes. Keep the body lean; state what
it does NOT do.

Minimal frontmatter shape (when there is no template):

```yaml
---
name: skill-name        # matches the directory name
description: >-
  When to invoke AND when NOT to invoke. This field is the resolver — its
  quality determines whether Claude routes here. State the purpose, the
  trigger phrases, and the clear anti-indicators.
---
```

Body skeleton: a one-line statement of the transformation; a "does NOT do" list;
the numbered procedure (each step a deterministic transform or an explicit STOP
gate); and explicit constraints. (TAS frontmatter additionally carries
`version`, `argument-hint`, `disable-model-invocation`, and `metadata.domain` —
include those only in the TAS environment, where the resolver consumes them.)

### 3 — Companion code (only if there is deterministic work)
If step 1 found precision work, write the script as a companion file the skill
alone uses. In TAS it travels via the symlink; in a plain global setup it lives
beside the `SKILL.md` in the same dir. The skill then *instructs the model to run
it* rather than reason about it. Most procedural skills need none — do not invent
one.

### 4 — Validate (tooling-optional)
Run the strongest validation the environment offers; do not skip the *intent* of
any check just because its tool is absent.

- **Install / make discoverable.**
  - TAS: `./setup` — install the symlink.
  - Plain global: no step needed — the file at `~/.claude/skills/{name}/SKILL.md`
    is already discoverable. Confirm the dir name equals `name`.
- **Resolver eval** — would it route on its trigger phrases (not a "dark"
  orphan)?
  - TAS: run `resolver-eval`.
  - Plain global: no resolver tool. Manually confirm the `description`'s triggers
    are sharp and unambiguous, and that the anti-indicators steer away the cases
    that should NOT route here. Read it as the router would.
- **DRY / check-resolvable** — does anything already cover this, and is it base
  capability (Gate 0, re-checked against the live skill list)?
  - TAS: run `check-resolvable`.
  - Plain global: list `~/.claude/skills/` and read each neighbor's
    `description`; confirm none already covers this candidate. If one does,
    extend it instead (see Edge cases).
- **Smoke test** — walk the procedure once against a real input; fix what breaks.
  This one is environment-independent and is never skipped.

### 5 — Install + commit
- TAS: `./setup` (done above) and commit Conventional: `feat(skills): add
  {name}`.
- Plain global: the file is already in place. Commit only if
  `~/.claude/skills` is a tracked repo; otherwise there is nothing to commit —
  authoring the file completed the install.

### 6 — File to the brain (the constellation touchpoint)
**Only if atelier is connected.** Record the new skill so the vault remembers it:
call `atelier_learning_capture` with the observation (what the skill is + when it
triggers), a real why, and a rule. This is gbrain's "brain filing" step — here it
is literally the atelier engine. Skip silently if atelier is not connected.

## Edge cases

- **Fails the bar** → refuse + explain; offer a `CLAUDE.md` line or a note.
- **Duplicates an existing skill** → extend that skill; do not mint a sibling.
- **Pure judgment, no repeatable procedure** → it is not a skill — leave it as a
  note or a `CLAUDE.md` convention.
- **Mixed/straddles categories** → split it; the best skills fit one category.
- **Would ship it** → if `ship-pr` is available and the change lives in a repo,
  hand off once the smoke test is green.
