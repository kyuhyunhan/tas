# TAS Development

## Language

All files and documents must be written in English.

## Project structure

```
tas/
├── ETHOS.md              # Foundational spirit behind the skill set
├── CLAUDE.md             # Project governance
├── README.md             # Project identity, skill and recipe catalog
├── setup                 # Install script (symlinks skills into ~/.claude/skills/)
├── scripts/              # Companion scripts (mechanical eval, etc.) invoked by skills
├── skills/
│   ├── skill.md.tmpl     # Authoring starter — copy into a new skill directory
│   └── {domain}-{action}/
│       └── SKILL.md      # Skill definition (pure function — atomic)
└── recipes/
    ├── recipe.md.tmpl    # Authoring starter — copy to a new recipe file
    └── {name}.md         # Recipe definition (composition — chains skills)
```

## Skill vs. recipe

TAS has two document types for behavior:

- **Skill** (`skills/{name}/SKILL.md`) — a pure function. Executes a single, well-scoped transformation. Has no knowledge of its caller. Installed as a symlink so Claude can invoke it via `/skill-name`.
- **Recipe** (`recipes/{name}.md`) — a composition pattern. Describes how to chain skills (and any out-of-band steps) to accomplish a larger goal. Read by a human (or orchestrating agent); not auto-invoked. Never symlinked.

If a new piece of work is itself atomic, it becomes a skill. If it only exists as the combination of other skills plus judgment, it becomes a recipe. When a skill grows workflow-like branches, split the workflow into a recipe and let the skill shrink back to a pure function.

## Decision-point escape clause (main-grade skills)

Main-grade skills (those that interview, crystallize, or otherwise drive a user through multi-round judgment) often reach points where the user lacks the domain knowledge to evaluate the options. When this happens:

- Do NOT push the user to guess.
- Do NOT paraphrase expert perspectives yourself — that outsources the user's thinking to the skill.
- Pause the current skill, point the user to the [`consult-fan-out`](recipes/consult-fan-out.md) recipe, and resume by re-reading the skill's artifact plus any `.research/consult/response-*` artifacts the user brought back.

Main skills must carry a short section that names this escape and names the `consult-*` lenses most likely to apply for that skill's decision points. See `skills/ios-macos-app-idea-explore/SKILL.md` for the canonical example.

## Skill format

Each skill lives in `skills/{name}/SKILL.md` with YAML frontmatter.
Start from [`skills/skill.md.tmpl`](skills/skill.md.tmpl) — copy it into a new skill directory and fill in.

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

Each recipe lives in `recipes/{name}.md` with YAML frontmatter.
Start from [`recipes/recipe.md.tmpl`](recipes/recipe.md.tmpl) — copy it to a new recipe file and fill in.

Required fields:
- `name` must match the filename (without `.md`) exactly.
- `description` states when this recipe is the right tool.
- `uses` lists the skills referenced by the recipe. Recipes may reference skills that are not yet authored (sketch mode) but the catalog should prefer recipes whose `uses` are all installable.
- `version` tracks recipe evolution.

Required sections (body): `## When to use`, `## Prerequisites`, `## Flow`, `## Failure modes`.
Optional sections: `## Examples`, `## Variants`.

## Recipe naming

Describe the **transformation**, not the mechanism. `{input}-to-{output}` is the default pattern when a recipe has a clear directional shape (`spec-to-gates`, `bug-to-fix`). Other shapes are allowed when the transformation is not directional. Recipes carry no domain prefix — composition crosses domains by nature.

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
