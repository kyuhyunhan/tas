# Using atelier with TAS

TAS is the **skills**. atelier is the **engine**. They are wired the way
[gstack](https://github.com/garrytan/gstack) is wired to
[gbrain](https://github.com/garrytan/gbrain): a loosely-coupled, one-directional
connection over MCP, owned entirely by the skills side.

```
   TAS  (skills / harness)            atelier  (engine / brain)         vault (content)
   ─────────────────────             ──────────────────────           ──────────────
   /setup-atelier   ───────MCP──────▶  atelier serve  ──reads/writes──▶  markdown
   /ship-pr  /audit-diff               (HTTP, loopback,                  (truth;
   …pure-function skills               bearer)                            DB is a
   that call atelier's tools           atelier_recall/search/…           projection)
```

## Responsibility division (the gstack ↔ gbrain analogy)

| | gstack | **TAS** | gbrain | **atelier** |
|---|---|---|---|---|
| role | workflow harness + skills | workflow skills | knowledge layer (MCP) | engine + vault projection (MCP) |
| knows the other? | yes — ships `/setup-gbrain` | yes — ships `/setup-atelier` | **no** (agnostic) | **no** (agnostic) |
| connection | MCP registration | MCP registration | exposes tools | exposes `atelier_*` tools |

The asymmetry is the point: **atelier never references TAS**, exactly as gbrain
never references gstack. atelier is a harness-agnostic brain that any client
(Claude Code, another harness, a future agent) can wire into via MCP. TAS holds
the connection so atelier can stay culture-neutral and distributable.

## How the connection works

- atelier runs `atelier serve` → an **HTTP MCP server on loopback**
  (`http://127.0.0.1:7322/mcp`), authenticated by a **static bearer** in
  `~/.atelier/secrets/.env` (chmod 600, loopback-only — no OAuth needed for the
  single-user case).
- TAS's **`/setup-atelier`** skill registers that server with Claude Code
  (`claude mcp add atelier …`), reading the bearer at call time and never
  persisting it. This is the analog of gstack's `/setup-gbrain`.
- Once registered, any session can call `atelier_recall`, `atelier_search`,
  `atelier_learning_*`, `atelier_principle_*`, etc. — the vault's memory becomes
  available to every TAS skill without TAS embedding any atelier internals.

## Privacy / trust

- **Loopback + bearer only.** atelier binds to `127.0.0.1`; the token authorizes
  local callers. The token is never copied into TAS (TAS is a **public** repo).
- **No secrets in this repo.** `/setup-atelier` sources the token from
  `~/.atelier/secrets/.env` at registration time.

## Keeping current

atelier owns its own freshness — `atelier reindex` rebuilds the derived DB from
the markdown vault (`rm -rf cache && atelier reindex` is always safe), and vault
auto-sync handles git. Unlike gstack's `/sync-gbrain` (which re-indexes a
codebase), atelier's projection is self-healing, so TAS ships **no**
`sync-atelier` skill — it would only duplicate atelier's own tooling.

## Setup, end to end

```bash
# 1. atelier (engine) — install + run its MCP server (see the atelier repo)
atelier serve --http            # loopback HTTP MCP on :7322

# 2. TAS (skills) — install the skill set, then connect
cd tas && ./setup               # symlink skills into ~/.claude/skills
# then, in a Claude Code session:
/setup-atelier                  # register atelier's MCP server
```

After that, `atelier_*` tools resolve in every session, and TAS skills (e.g.
`/ship-pr`) can lean on the vault's memory.
