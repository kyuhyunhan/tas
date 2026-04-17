# TAS Development

## Language

All files and documents must be written in English.

## Project structure

```
tas/
├── ETHOS.md           # Foundational spirit behind the skill set
├── CLAUDE.md          # Project governance
├── README.md          # Project identity and skill catalog
├── setup              # Install script (symlinks skills into ~/.claude/skills/)
└── skills/
    └── {domain}-{action}/
        └── SKILL.md   # Skill definition
```

## Skill format

Each skill lives in `skills/{name}/SKILL.md` with YAML frontmatter:

```yaml
---
name: skill-name
description: >
  When to invoke and when NOT to invoke.
  This field is the resolver — it determines
  whether Claude routes the user here.
version: 0.1.0
argument-hint: "[optional args hint]"
disable-model-invocation: true
metadata:
  domain: apple-app
---
```

Required fields:
- `name` must match the directory name exactly.
- `description` specifies when to invoke and when NOT to invoke. This is the built-in resolver input — its quality determines routing quality.
- `version` tracks skill evolution.

Optional fields:
- `argument-hint`: Claude Code native field. One-line hint shown to the user when invoking the skill.
- `disable-model-invocation`: Claude Code native field. Set `true` when a skill should be invoked explicitly by the user, not auto-routed by the model.
- `metadata`: Custom namespace for TAS-specific fields. Current conventions:
  - `metadata.domain`: domain prefix grouping skills that share artifacts (e.g., `apple-app` for `apple-app-market-scan`, `apple-app-idea-explore`).
  - `metadata.pipeline-position`, `metadata.upstream`, `metadata.downstream`: pipeline wiring hints when a skill chains with others.

## Skill naming

Prefix skills with their domain: `{domain}-{action}`. Example: `apple-app-market-scan`, `apple-app-idea-explore`. Domain prefixes prevent collisions when TAS later adds new domains (`web-saas-`, `hardware-`, etc.).

## Artifact convention

Skills that produce working documents write to `{project-root}/.research/{domain}/`. File naming: `{type}-{keyword}-{YYYY-MM-DD}.md` — predictable, sortable, glob-friendly. Downstream skills discover artifacts via glob; most recent by filename date wins. `.research/` is gitignored — it holds working documents, not source.

## Installation

Skills are installed via symlinks from the repo into `~/.claude/skills/`:

```bash
./setup           # install or refresh all skills
./setup --sync    # git pull + refresh + prune dangling
./setup --list    # status per skill
./setup --help    # all flags
```

Editing `skills/{name}/SKILL.md` takes effect immediately — the symlink points to the live repo.

## Commit conventions

```
skill(name): description       # Skill add, modify, or remove
harness: description           # Meta documents, structure, format rules
```

Examples:
```
skill(pre-deploy): add App Store submission checklist
skill(pre-deploy): tighten scope to exclude simulator builds
skill(investigate): add gotchas table from debugging session
harness: define frontmatter format spec
harness: initialize project structure
```
