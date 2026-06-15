# TAS — These Are Skills

A personal skill set for AI coding agents.

TAS is not a framework. It is not a toolkit you install.
It is one developer's collection of skills — built from real needs,
shaped by actual workflow, borrowed from good ideas elsewhere.

The point is not to use these skills. The point is to build your own.

TAS is the **skills layer of the atelier constellation**: `atelier` is the engine
(a memory/knowledge MCP server), the vault is the content, and TAS holds the
skills. It connects to atelier the way [gstack](https://github.com/garrytan/gstack)
connects to [gbrain](https://github.com/garrytan/gbrain) — over MCP, one-directional,
owned by the skills side. See [USING_ATELIER_WITH_TAS.md](USING_ATELIER_WITH_TAS.md).

## What earns a place here

> Claude already knows how to code and reason. A skill that restates what the
> model would do by default adds context without adding value.

So TAS stays small on purpose. A skill exists only when it **pushes the model
out of its default behavior** — an operational guardrail, an org-specific
convention, or a procedure the model would not assemble on its own. Generic
"lenses" and reference knowledge the base model already has are deliberately
*not* here.

## Skills

Pure-function units, installed as symlinks, invoked as `/skill-name`. Grouped by
the [Anthropic skill taxonomy](https://claude.com/blog/lessons-from-building-claude-code-how-we-use-skills).

| Skill | Category | Purpose |
|---|---|---|
| `ship-pr` | CI/CD & deployment | Drive a finished change through push → PR → reviewer loop → auto-merge. |
| `audit-diff` | Code quality & review | Audit a diff into `[MUST]/[SHOULD]/[NIT]/[Q]/[PRAISE]` findings; the rubric `ship-pr`'s reviewer follows. |
| `atelier-setup` | Infrastructure ops | Register atelier's MCP server so a session can recall the vault. |

## Installation

```bash
git clone git@github.com:kyuhyunhan/tas.git
cd tas
./setup           # symlink all skills into ~/.claude/skills/
./setup --sync    # pull latest + refresh + prune dangling
./setup --list    # status per skill
./setup --help    # all flags
```

Editing `skills/{name}/SKILL.md` takes effect immediately — the symlink points
to the live repo.

## Authoring

See [CLAUDE.md](CLAUDE.md) for the skill format, naming, and the bar a new skill
must clear. Philosophy: [ETHOS.md](ETHOS.md). Inspiration: Garry Tan's
"Thin Harness, Fat Skills."
