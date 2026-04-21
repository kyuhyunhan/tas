# TAS Development

## Language

All files and documents must be written in English.

## Project structure

```
tas/
├── ETHOS.md           # Foundational spirit behind the skill set
├── CLAUDE.md          # Project governance
├── README.md          # Project identity, skill and recipe catalog
├── setup              # Install script (symlinks skills into ~/.claude/skills/)
├── skills/
│   └── {domain}-{action}/
│       └── SKILL.md   # Skill definition (pure function — atomic)
└── recipes/
    └── {name}.md      # Recipe definition (composition — chains skills)
```

## Skill vs. recipe

TAS has two document types for behavior:

- **Skill** (`skills/{name}/SKILL.md`) — a pure function. Executes a single, well-scoped transformation. Has no knowledge of its caller. Installed as a symlink so Claude can invoke it via `/skill-name`.
- **Recipe** (`recipes/{name}.md`) — a composition pattern. Describes how to chain skills (and any out-of-band steps) to accomplish a larger goal. Read by a human (or orchestrating agent); not auto-invoked. Never symlinked.

If a new piece of work is itself atomic, it becomes a skill. If it only exists as the combination of other skills plus judgment, it becomes a recipe. When a skill grows workflow-like branches, split the workflow into a recipe and let the skill shrink back to a pure function.

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
  domain: ios-macos-app
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
  - `metadata.domain`: domain prefix grouping skills that share artifacts (e.g., `ios-macos-app` for `ios-macos-app-market-research`, `ios-macos-app-idea-explore`).
  - `metadata.pipeline-position`, `metadata.upstream`, `metadata.downstream`: pipeline wiring hints when a skill chains with others.

## Skill naming

Prefix skills with their domain: `{domain}-{action}`. Example: `ios-macos-app-market-research`, `ios-macos-app-idea-explore`. Domain prefixes prevent collisions when TAS later adds new domains (`web-saas-`, `hardware-`, etc.).

## Recipe format

Each recipe lives in `recipes/{name}.md` with YAML frontmatter:

```yaml
---
name: recipe-name
description: One-line — the problem this recipe solves and its shape
uses:
  - skill-name-a
  - skill-name-b
version: 0.1.0
---
```

Required fields:
- `name` must match the filename (without `.md`) exactly.
- `description` states when this recipe is the right tool.
- `uses` lists the skills referenced by the recipe. Recipes may reference skills that are not yet authored (sketch mode) but the catalog should prefer recipes whose `uses` are all installable.
- `version` tracks recipe evolution.

Required sections (body): `## When to use`, `## Prerequisites`, `## Flow`, `## Failure modes`.
Optional sections: `## Examples`, `## Variants`.

Recipe naming: kebab-case describing the transformation, not the tool (`spec-to-gates`, not `gate-generator`). Recipes carry no domain prefix — composition crosses domains by nature.

## Recipe naming

Describe the **transformation**, not the mechanism. `{input}-to-{output}` is the default pattern when a recipe has a clear directional shape (`spec-to-gates`, `bug-to-fix`). Other shapes are allowed when the transformation is not directional.

## Terminology

TAS leans on industry-standard terms wherever they exist. Use them as-is — do not reinvent.

| Concept                        | Standard term                          | Source                    |
| ------------------------------ | -------------------------------------- | ------------------------- |
| Testable behavior unit         | **acceptance criterion (AC)**          | Agile / BDD               |
| AC format                      | **Given / When / Then**                | BDD                       |
| Code style and structure rules | **coding standards**                   | common                    |
| Automated pass/fail checkpoint | **CI gate** / **quality gate**         | CI/CD                     |
| Product requirement document   | **PRD**                                | product                   |

TAS-specific primitives (these are not industry-standard, and that is intentional — they name TAS's own abstractions):

- **skill** — a pure-function unit of behavior, defined as a `SKILL.md` document.
- **recipe** — a composition pattern over skills, defined as a markdown document.
- **harness** — the repo-level scaffolding that hosts skills and recipes (`setup`, `CLAUDE.md`, etc.).
- **domain** — the prefix grouping skills that share artifacts or subject area.
- **artifact** — a working document produced by a skill, written to `.research/{domain}/`.

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
recipe(name): description      # Recipe add, modify, or remove
harness: description           # Meta documents, structure, format rules
```

Examples:
```
skill(pre-deploy): add App Store submission checklist
skill(pre-deploy): tighten scope to exclude simulator builds
skill(investigate): add gotchas table from debugging session
recipe(spec-to-gates): compose AC + gates skills into TDD-ready pipeline
harness: define frontmatter format spec
harness: initialize project structure
```
