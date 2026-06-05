# TAS Development

## Language

All files and documents must be written in English.

## Identity

TAS is the **skills layer of the atelier constellation** (engine = `atelier`,
content = vault, skills = TAS). It holds *only* skills — no engine, no
orchestration runtime, no cross-repo tooling. Connection to atelier lives
entirely on this side via `setup-atelier` + `USING_ATELIER_WITH_TAS.md`; atelier
itself never references TAS.

## The bar — what earns a skill

> Claude already knows how to code and reason. A skill that restates what the
> model would do by default adds context without adding value.
> — [Anthropic, *how we use skills*](https://claude.com/blog/lessons-from-building-claude-code-how-we-use-skills)

A skill is justified **only** when it pushes the model out of its default
behavior: an operational guardrail, an org-specific convention, a non-obvious
procedure, or a gotcha unavailable in base training. Before adding a skill, name
which of those it is. If the answer is "the model already does this" — do not add
it. Generic lenses (product/UX/GTM strategy) and reference knowledge (language
patterns, coding standards) are base capability and belong nowhere here.

The best skills fit cleanly into one of the
[Anthropic categories](https://claude.com/blog/lessons-from-building-claude-code-how-we-use-skills):
library/API reference · product verification · data fetching/analysis ·
business-process automation · code scaffolding/templates · code quality &
review · CI/CD & deployment · runbooks · infrastructure operations.

## Project structure

```
tas/
├── ETHOS.md  CLAUDE.md  README.md     # spirit · governance · catalog
├── setup                              # symlinks skills into ~/.claude/skills/
└── skills/
    ├── skill.md.tmpl                  # authoring starter
    └── {name}/
        ├── SKILL.md                   # the skill (pure function — atomic)
        └── {companion}                # optional: scripts/data only this skill uses
```

A skill directory may carry companion files (scripts, fixtures) it alone uses;
they travel with the skill via the symlink. Promote a companion to a shared
location only when a second skill needs it.

## Skill format

Each skill is `skills/{name}/SKILL.md` with YAML frontmatter. Start from
[`skills/skill.md.tmpl`](skills/skill.md.tmpl).

- `name` — must match the directory name exactly.
- `description` — when to invoke and when NOT to. This is the resolver input;
  its quality determines routing. State purpose, inputs, outputs, anti-indicators.
- Optional Claude Code fields: `argument-hint`, `disable-model-invocation`.
- Optional `metadata.category` — the Anthropic category, for grouping.

## Skill naming

Name by **function**, concisely — `ship-pr`, `audit-diff`, `setup-atelier`. No
mandatory domain prefix; the category lives in `metadata.category` and the README
grouping, not in a verbose name.

## Artifact convention

Skills that produce working documents write to
`{project-root}/.research/{topic}/`, named `{type}-{keyword}-{YYYY-MM-DD}.md`
(sortable, glob-friendly). `.research/` is gitignored — working documents, not source.

## Installation

```bash
./setup            # install/refresh all skills
./setup --sync     # git pull + refresh + prune dangling
./setup --list     # status per skill
```

Editing `skills/{name}/SKILL.md` takes effect immediately — the symlink points to
the live repo.

## Commit conventions

Conventional Commits. Scope `skills` for skill changes; `docs`/`chore` for meta.

```
feat(skills): add ship-pr
fix(skills): setup-atelier reads the real bearer key
docs: regenerate the skill catalog
```
