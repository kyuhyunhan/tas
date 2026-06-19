#!/usr/bin/env python3
"""Deterministic referential-integrity cleanup over graph/atomic/.

LOSSLESSNESS is the invariant: this script never *deletes* a dangling target,
and never drops a resolvable edge. For every reference (``links[].to``,
``is_about[]``, ``derived_from[]``) that points at a string which is NOT an
existing node id, it either REMAPS the stale reference to the real node id, or
QUARANTINES the genuinely dangling target string under an ``unresolved_refs: []``
field on its node — moving it out of the live edge array, never destroying it.

Three reference shapes are normalized:

  CLASS 1 — typed link maps (``{to: …, rel: …, why: …}``).
    A ``to`` that resolves to no node is remapped when the target is a stale
    short id that an upstream pass copied verbatim (short id -> canonical
    ``entry_id`` map, built from any preserved short ids in the vault). If no
    remap is found, the original target string is quarantined (rel/why dropped
    with it into ``unresolved_refs``).

  CLASS 2 — scalar ref arrays (``is_about[]`` / ``derived_from[]``).
    These hold bare ``entry_id`` scalars. A scalar that resolves to no node is
    a genuinely dangling reference: quarantined into ``unresolved_refs`` and
    dropped from the live array. No short-id remap is attempted here — these
    arrays are written with canonical entry_ids, so a non-resolving id is a
    never-written node, not a stale short id.

  CLASS 3 — bare-scalar ``links[]`` items (a plain string, not a map).
    An un-normalized cross-link. Resolved to its canonical ``entry_id`` (a node
    id is wrapped into typed form; a stale short id is remapped) and NORMALIZED
    into the typed ``{to: …, rel: related, why: …}`` form. A bare scalar that
    resolves to no node is quarantined, exactly like CLASS 1/2.

RESULT: after this runs, every ``links[].to`` (and ``is_about``,
``derived_from``) resolves to an existing node; every ``links[]`` entry is in
typed ``{to: …}`` form; every dangling / raw ref is preserved under
``unresolved_refs``. Idempotent: a clean graph is a fixed point (0 changes).

Run:  python refclean.py --dry-run   (report only, no writes; default)
      python refclean.py --apply     (write changes)

Vault root resolves from the atelier engine config (``cfg.vault.local``) unless
``--vault-root`` is given. Requires the engine importable:
    PYTHONPATH=/path/to/atelier python refclean.py --dry-run
"""
from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple

import yaml

from runtime.index.parse import split_frontmatter  # engine = parse authority
from runtime.util import config

NODE_DIRS = ("claims", "sources", "entities")
SKIP_BASENAMES = {"log.md", "INDEX.md"}

# Shape detectors for genuinely-dangling noise (timestamps, slug paths).
RE_TS = re.compile(r"^\d{1,2}:\d{2}$")          # 02:26
RE_TS_H = re.compile(r"^\d{1,2}:\d{2}:\d{2}$")  # 1:07:06
RE_SLUG_PATH = re.compile(r"^(entities|digests|themes|claims|sources)/")
# A short-id-shaped ref (a compact id an upstream pass may have copied verbatim).
RE_SHORT_ID = re.compile(r"^\d{8}T\d{4}")


# --------------------------------------------------------------------------
# vault resolution
# --------------------------------------------------------------------------
def resolve_vault_root(cli_value: Optional[str]) -> Path:
    if cli_value:
        return Path(cli_value).expanduser()
    cfg = config.load()
    if cfg.vault is None:
        raise SystemExit("config has no `vault:` block; pass --vault-root")
    return Path(cfg.vault.local).expanduser()


# --------------------------------------------------------------------------
# io helpers
# --------------------------------------------------------------------------
def content_hash(payload: Dict[str, Any]) -> str:
    body = json.dumps(payload, sort_keys=True, ensure_ascii=False)
    return "sha256:" + hashlib.sha256(body.encode("utf-8")).hexdigest()


def emit_md(frontmatter: Dict[str, Any], body: str) -> str:
    fm = yaml.safe_dump(
        frontmatter, sort_keys=True, allow_unicode=True, default_flow_style=False
    )
    return f"---\n{fm}---\n\n{body.rstrip()}\n"


def node_files(atomic: Path) -> List[Path]:
    out: List[Path] = []
    for d in NODE_DIRS:
        base = atomic / d
        if base.exists():
            out.extend(sorted(base.glob("*.md")))
    return out


# --------------------------------------------------------------------------
# index builders
# --------------------------------------------------------------------------
def build_node_ids(atomic: Path) -> set:
    ids: set = set()
    for p in node_files(atomic):
        fm, _ = split_frontmatter(p.read_text(encoding="utf-8"))
        eid = fm.get("entry_id")
        if eid:
            ids.add(eid)
    return ids


def build_short_map(vault_root: Path) -> Tuple[Dict[str, str], Dict[str, str]]:
    """Return (short_id -> entry_id, file-stem -> entry_id) for any preserved
    legacy short ids under provenance/raw. Empty if those dirs are absent —
    a clean graph never needs a remap, so empty maps are correct."""
    short_map: Dict[str, str] = {}
    stem_map: Dict[str, str] = {}
    for root_name in ("provenance", "raw"):
        root = vault_root / root_name
        if not root.exists():
            continue
        for p in root.rglob("*.md"):
            if p.name in SKIP_BASENAMES:
                continue
            fm, _ = split_frontmatter(p.read_text(encoding="utf-8"))
            sid, eid = fm.get("id"), fm.get("entry_id")
            if eid:
                stem_map.setdefault(p.stem, eid)
                if sid:
                    short_map.setdefault(str(sid), eid)
    return short_map, stem_map


def slug_stem(to: str) -> str:
    ts = str(to).rstrip("/")
    last = ts.rsplit("/", 1)[-1]
    if last.endswith(".md"):
        last = last[:-3]
    return last


def resolve_remap(
    to: str,
    short_map: Dict[str, str],
    stem_map: Optional[Dict[str, str]] = None,
) -> Optional[str]:
    """Return the canonical entry_id this stale ref should remap to, or None."""
    ts = str(to)
    if ts in short_map:
        return short_map[ts]
    if RE_SHORT_ID.match(ts):
        base = ts.split("-", 1)[0]
        if base in short_map:
            return short_map[base]
    if stem_map is not None:
        stem = slug_stem(ts)
        if stem in stem_map:
            return stem_map[stem]
    return None


def is_noise(to: str) -> bool:
    ts = str(to)
    return bool(RE_TS.match(ts) or RE_TS_H.match(ts) or RE_SLUG_PATH.match(ts))


# --------------------------------------------------------------------------
# main
# --------------------------------------------------------------------------
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

    node_ids = build_node_ids(atomic)
    short_map, stem_map = build_short_map(vault_root)

    remapped = 0
    normalized_bare = 0
    quarantined = 0
    files_touched = 0
    q_is_about = 0
    q_derived_from = 0
    q_links = 0

    for p in node_files(atomic):
        text = p.read_text(encoding="utf-8")
        fm, body = split_frontmatter(text)
        unresolved: List[str] = list(fm.get("unresolved_refs") or [])
        changed = False

        # --- CLASS 2: scalar ref arrays ---
        for arr_name in ("is_about", "derived_from"):
            arr = fm.get(arr_name)
            if not isinstance(arr, list) or not arr:
                continue
            kept: List[Any] = []
            arr_changed = False
            for ref in arr:
                if isinstance(ref, str) and ref not in node_ids:
                    unresolved.append(ref)
                    quarantined += 1
                    changed = True
                    arr_changed = True
                    if arr_name == "is_about":
                        q_is_about += 1
                    else:
                        q_derived_from += 1
                else:
                    kept.append(ref)
            if arr_changed:
                fm[arr_name] = kept

        links = fm.get("links")
        if not isinstance(links, list) or not links:
            if changed:
                _persist(p, fm, body, unresolved, dry_run)
                files_touched += 1
            continue

        new_links: List[Any] = []
        for link in links:
            # --- CLASS 3: bare-scalar list item ---
            if isinstance(link, str):
                bare = link
                if bare in node_ids:
                    new_links.append({"to": bare, "rel": "related",
                                      "why": "normalized from bare link"})
                    normalized_bare += 1
                    changed = True
                    continue
                bid = resolve_remap(bare, short_map, stem_map)
                if bid is not None:
                    new_links.append({"to": bid, "rel": "related",
                                      "why": f"normalized from bare ref {bare!s}"})
                    normalized_bare += 1
                    changed = True
                    continue
                unresolved.append(str(bare))
                quarantined += 1
                q_links += 1
                changed = True
                continue

            if not isinstance(link, dict) or "to" not in link:
                new_links.append(link)
                continue
            to = link.get("to")
            if to is None or to in node_ids:
                new_links.append(link)
                continue

            # --- CLASS 1: dangling typed link ---
            remap_id = resolve_remap(to, short_map, stem_map)
            if remap_id is not None:
                fixed = dict(link)
                fixed["to"] = remap_id
                new_links.append(fixed)
                remapped += 1
                changed = True
                continue
            unresolved.append(str(to))
            quarantined += 1
            q_links += 1
            changed = True

        if not changed:
            continue

        fm["links"] = new_links
        _persist(p, fm, body, unresolved, dry_run)
        files_touched += 1

    report = {
        "remapped": remapped + normalized_bare,
        "quarantined": quarantined,
        "files_touched": files_touched,
        "is_about_quarantined": q_is_about,
        "derived_from_quarantined": q_derived_from,
        "links_quarantined": q_links,
        "detail": {
            "class1_remapped_refs": remapped,
            "class3_normalized_bare_refs": normalized_bare,
        },
        "dry_run": dry_run,
    }
    print(json.dumps(report, ensure_ascii=False, indent=2))


def _persist(p: Path, fm: Dict[str, Any], body: str,
             unresolved: List[str], dry_run: bool) -> None:
    if unresolved:
        seen: set = set()
        deduped: List[str] = []
        for u in unresolved:
            if u not in seen:
                seen.add(u)
                deduped.append(u)
        fm["unresolved_refs"] = deduped
    if "content_hash" in fm:
        fm["content_hash"] = content_hash(
            {k: v for k, v in fm.items() if k != "content_hash"})
    if not dry_run:
        p.write_text(emit_md(fm, body), encoding="utf-8")


if __name__ == "__main__":
    main()
