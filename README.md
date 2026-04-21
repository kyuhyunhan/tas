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

Pure-function units. Invoked as `/skill-name`.

| Name | Domain | Purpose |
|------|--------|---------|
| `ios-macos-app-market-research` | ios-macos-app | Conversational researcher for iOS and macOS desktop app markets |
| `ios-macos-app-idea-explore` | ios-macos-app | Iteratively crystallize an iOS or macOS app concept through Socratic interview |
| `spec-acceptance-criteria-derive` | spec | Derive Given/When/Then acceptance criteria from a PRD or written spec |
| `spec-ci-gates-scaffold` | spec | Scaffold a fast-to-slow CI quality-gate set from an AC list and stack notes |

## Recipes

Composition patterns. Read by a human (or orchestrating agent); not symlinked.

| Name | Uses | Purpose |
|------|------|---------|
| [`spec-to-gates`](recipes/spec-to-gates.md) | `spec-acceptance-criteria-derive`, `spec-ci-gates-scaffold` | Turn a PRD into AC list + CI gates, ready for TDD + eval iteration |

## Authoring a new skill or recipe

See [CLAUDE.md](CLAUDE.md) for skill/recipe format specs, naming conventions, artifact directory rules, and commit conventions.

## Inspiration

The architecture follows the "Thin Harness, Fat Skills" principle
described in [Garry Tan's essay](https://github.com/garrytan/gbrain/blob/master/docs/ethos/THIN_HARNESS_FAT_SKILLS.md).

## Philosophy

See [ETHOS.md](ETHOS.md).
