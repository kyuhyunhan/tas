# TAS — These Are Skills

A personal skill set for AI coding agents.

TAS is not a framework. It is not a toolkit you install.
It is one developer's collection of skills — built from real needs,
shaped by actual workflow, borrowed from good ideas elsewhere.

The point is not to use these skills. The point is to build your own.

## Installation

```bash
git clone git@github.com:kyuhyunhan/tas.git
cd tas
./setup           # install or refresh all skills
./setup --sync    # pull latest + refresh + prune dangling
./setup --list    # status per skill
./setup --help    # all flags
```

Skills install as symlinks from the repo into `~/.claude/skills/`. Editing a skill in the repo takes effect immediately.

## Skills

| Name | Domain | Purpose |
|------|--------|---------|
| `apple-app-market-scan` | apple-app | Scan Apple app categories for market facts or discover underserved niches |
| `apple-app-idea-explore` | apple-app | Iteratively crystallize an Apple app concept through Socratic interview grounded in market research |

## Authoring a new skill

See [CLAUDE.md](CLAUDE.md) for the skill format spec, naming conventions, artifact directory rules, and commit conventions.

## Inspiration

The architecture follows the "Thin Harness, Fat Skills" principle
described in [Garry Tan's essay](https://github.com/garrytan/gbrain/blob/master/docs/ethos/THIN_HARNESS_FAT_SKILLS.md).

## Philosophy

See [ETHOS.md](ETHOS.md).
