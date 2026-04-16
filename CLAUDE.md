# TAS Development

## Language

All files and documents must be written in English.

## Project structure

```
tas/
├── ETHOS.md           # Foundational spirit behind the skill set
├── CLAUDE.md          # Project governance
├── README.md          # Project identity and skill catalog
└── skills/
    └── {name}/
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
---
```

- `name` must match the directory name exactly.
- `description` specifies when to invoke and when NOT to invoke. This is the built-in resolver input — its quality determines routing quality.
- `version` tracks skill evolution.

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
