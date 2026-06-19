#!/usr/bin/env python3
"""Deterministic content_hash recompute over graph/atomic/.

Recompute ``content_hash`` for EVERY atomic node (claims / sources / entities)
using the canonical algorithm, fixing any node whose stored hash drifted from
the canonical convention (e.g. written by a pass that serialized the payload
differently).

CANONICAL ALGORITHM (single source of truth):

    content_hash = "sha256:" + sha256(
        json.dumps(<frontmatter minus content_hash>,
                   sort_keys=True, ensure_ascii=False)
    ).hexdigest()

The read path uses runtime.index.parse.split_frontmatter (the engine's parse
authority). The write path is yaml.safe_dump(sort_keys=True, allow_unicode=True).
The hash covers the frontmatter dict with ``content_hash`` removed — the body is
NOT part of the hash (the canonical spec hashes frontmatter only).

IDEMPOTENT: a node already carrying the canonical hash is left byte-untouched;
re-running yields zero ``hashes_recomputed`` and zero file writes.

Run:  python rehash.py --dry-run   (report only; default)
      python rehash.py --apply     (write changes)

Vault root resolves from the atelier engine config (``cfg.vault.local``) unless
``--vault-root`` is given. Requires the engine importable:
    PYTHONPATH=/path/to/atelier python rehash.py --dry-run
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
from typing import Any, Dict, List, Optional

import yaml

from runtime.index.parse import split_frontmatter  # engine = parse authority
from runtime.util import config

NODE_DIRS = ("claims", "sources", "entities")


def resolve_vault_root(cli_value: Optional[str]) -> Path:
    if cli_value:
        return Path(cli_value).expanduser()
    cfg = config.load()
    if cfg.vault is None:
        raise SystemExit("config has no `vault:` block; pass --vault-root")
    return Path(cfg.vault.local).expanduser()


def canonical_hash(fm: Dict[str, Any]) -> str:
    payload = {k: v for k, v in fm.items() if k != "content_hash"}
    body = json.dumps(payload, sort_keys=True, ensure_ascii=False)
    return "sha256:" + hashlib.sha256(body.encode("utf-8")).hexdigest()


def emit_md(fm: Dict[str, Any], body: str) -> str:
    dumped = yaml.safe_dump(
        fm, sort_keys=True, allow_unicode=True, default_flow_style=False)
    return f"---\n{dumped}---\n\n{body.rstrip()}\n"


def node_files(atomic: Path) -> List[Path]:
    out: List[Path] = []
    for d in NODE_DIRS:
        base = atomic / d
        if base.exists():
            out.extend(sorted(base.glob("*.md")))
    return out


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--vault-root", default=None,
                    help="vault root (default: cfg.vault.local from engine config)")
    ap.add_argument("--apply", action="store_true",
                    help="write changes; otherwise dry-run (default)")
    ap.add_argument("--dry-run", action="store_true",
                    help="report only, no writes (the default; accepted for clarity)")
    args = ap.parse_args()
    dry_run = not args.apply

    vault_root = resolve_vault_root(args.vault_root)
    atomic = vault_root / "graph" / "atomic"

    total = 0
    recomputed = 0
    missing_field = 0

    for p in node_files(atomic):
        text = p.read_text(encoding="utf-8")
        fm, body = split_frontmatter(text)
        if not fm:
            continue
        total += 1
        old = fm.get("content_hash")
        new = canonical_hash(fm)
        if old == new:
            continue
        if old is None:
            missing_field += 1
        recomputed += 1
        fm["content_hash"] = new
        if not dry_run:
            p.write_text(emit_md(fm, body), encoding="utf-8")

    report = {
        "total_nodes": total,
        "hashes_recomputed": recomputed,
        "missing_field_filled": missing_field,
        "dry_run": dry_run,
    }
    print(json.dumps(report, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
