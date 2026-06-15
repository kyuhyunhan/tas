---
name: atelier-setup
description: >-
  Connect atelier — the personal memory/knowledge engine — to Claude Code by
  registering its MCP server, so any session can recall vault learnings and
  search the wiki. Invoke when the user says "set up atelier", "connect
  atelier", "register the atelier MCP", or is on a new machine / fresh checkout
  and atelier's tools aren't available yet. Do NOT use to author skills, operate
  the vault, or run a review loop — this skill only wires the connection.
---

# atelier-setup

Registers atelier's MCP server with Claude Code, the way gstack's `setup-gbrain`
wires gbrain in. atelier is the **engine** (a loopback MCP server over the
markdown vault); TAS is the **skills**. The connection is one-directional —
TAS → atelier, over MCP — and atelier never references TAS (it stays a
harness-agnostic brain, exactly like gbrain).

This skill **registers a connection**. It does not:
- install atelier, manage its Python env, or start long-running processes for you
- read, write, or migrate the vault (that is atelier's own tooling)
- store or print the bearer token anywhere outside the registration call

## Scope

**In scope**
- Verify atelier is installed and its server is reachable.
- Register the MCP server in Claude Code idempotently.
- Verify the tools resolve (`atelier_recall`, `atelier_search`, …).

**Out of scope**: authoring skills, the review/merge loop (`ship-pr`), vault
content, principle/learning curation, OAuth (atelier uses loopback + bearer).

## The connection (what atelier exposes)

- Transport: **HTTP MCP on loopback** — `http://127.0.0.1:7322/mcp`.
- Auth: a **static bearer token** in `~/.atelier/secrets/.env` (chmod 600),
  validated by atelier's `auth.authenticate_bearer`. Loopback-only by design.
- Server: launched by `atelier serve` (the `[serve]` extra). The server must be
  running for the tools to resolve.

## Procedure

1. **Preflight.** Confirm atelier is installed (`atelier --version` or the repo
   is checked out and its venv active). If not, stop and tell the user how to
   install it — this skill connects, it does not install.
2. **Ensure the server is up.** Check `http://127.0.0.1:7322/mcp` is reachable;
   if not, instruct the user to start it (`atelier serve --http`, typically left
   running under the engine's supervisor). Do not daemonize it yourself.
3. **Read the bearer at runtime.** Source the token from `~/.atelier/secrets/.env`
   in the registration command itself — never echo it, never copy it into a
   file, never commit it. (TAS is public.)
4. **Register, idempotently.** If an `atelier` MCP server is already registered
   (`claude mcp list`), skip. Otherwise:
   ```bash
   claude mcp add atelier --transport http \
     --url http://127.0.0.1:7322/mcp \
     --header "Authorization: Bearer $(grep -m1 '^ATELIER_MCP_HTTP_TOKEN=' ~/.atelier/secrets/.env | cut -d= -f2-)"
   ```
   The bearer's env key is `ATELIER_MCP_HTTP_TOKEN` (atelier's
   `service.mcp_http.token_env`, default `ATELIER_MCP_HTTP_TOKEN`). The value is
   read at call time and never persisted by this skill.
5. **Verify.** Confirm the `atelier_*` tools resolve in a new session (e.g.
   `atelier_recall` is callable). Report the registered URL and that the token
   was sourced, not stored.

## Keeping current

atelier owns its own freshness: `atelier reindex` rebuilds the derived DB from
the markdown vault, and vault auto-sync handles git. There is no `sync-atelier`
skill — unlike gstack/gbrain's code-index sync, atelier's projection is
self-healing (`rm -rf cache && atelier reindex`). Point the user at atelier's
own tooling rather than duplicating it here.

## Edge cases

- **Server not running** → the tools won't resolve; registration still succeeds
  but is inert until `atelier serve` is up. Say so explicitly.
- **Already registered** → no-op; report the existing registration.
- **Token missing** (`~/.atelier/secrets/.env` absent) → stop; atelier's own
  `./scripts/setup` provisions it. Do not fabricate a token.
- **Non-loopback / multi-machine** → out of scope; atelier is loopback-only by
  design (no OAuth until a later atelier version).
