#!/usr/bin/env python3
"""Duplicate-entry_id entity dedup (deterministic, idempotent).

Some entities exist as TWO (or more) files sharing one ``entry_id``: the same
content-addressed id written by different passes under different slugified
filenames (e.g. ``<slug>.md`` vs ``<slug>-<id8>.md``; ``a b.md`` vs ``a-b.md``).
This collapses each such group into ONE canonical file.

Per group (entry_id with >1 file):
  * canonical filename = id-suffixed form ``<slug>-<entry_id[:8]>.md`` where
    ``slug = slugify(pref_label)`` (the engine's entity slug rule). Collision-
    free by construction (the 8-char id suffix). If no copy is already in that
    form, the surviving file is renamed to it.
  * merge frontmatter:
      - union ``alt_label[]`` (dedup, order-stable)
      - union ``links[]`` (dedup by ``(to, rel)``, first occurrence wins)
      - prefer a non-empty ``gloss``
      - keep ``type`` / ``pref_label`` / ``in_scheme`` (from the canonical seed)
      - carry any other scalar/list keys; first non-empty value wins, canonical
        seed first
      - ``sensitivity`` = most-restrictive across copies (private > internal >
        public)
      - recompute ``content_hash``
  * keep the merged body (longest non-empty body across copies; canonical seed
    wins ties), write the canonical file, delete the others.

entry_id is unchanged, so NO reference elsewhere needs rewriting — only
filenames are consolidated. Idempotent: a single canonical file per entry_id is
a fixed point (0 changes on a clean graph).

Run:  python entity_dedup.py --dry-run   (report only; default)
      python entity_dedup.py --apply     (write changes)

Vault root resolves from the atelier engine config (``cfg.vault.local``) unless
``--vault-root`` / ``--entities-dir`` is given. Requires the engine importable:
    PYTHONPATH=/path/to/atelier python entity_dedup.py --dry-run
"""
from __future__ import annotations

import argparse
import hashlib
import json
import re
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple

import yaml

from runtime.index.parse import split_frontmatter  # engine = parse authority
from runtime.util import config

# Most-restrictive-wins ordering for sensitivity.
_SENS_RANK = {"public": 0, "internal": 1, "private": 2}


def resolve_entities_dir(entities_dir: Optional[str],
                         vault_root: Optional[str]) -> Path:
    if entities_dir:
        return Path(entities_dir).expanduser()
    if vault_root:
        root = Path(vault_root).expanduser()
    else:
        cfg = config.load()
        if cfg.vault is None:
            raise SystemExit("config has no `vault:` block; pass --vault-root")
        root = Path(cfg.vault.local).expanduser()
    return root / "graph" / "atomic" / "entities"


def slugify(value: str) -> str:
    """concept/label string -> entity-file basename slug (engine slug rule):
    lowercase, separators->hyphen, keep word chars (incl. CJK), collapse hyphens."""
    s = (value or "").strip().lower()
    s = re.sub(r"[\s_/]+", "-", s)
    s = re.sub(r"[^\w\-]", "", s, flags=re.UNICODE)
    s = re.sub(r"-+", "-", s).strip("-")
    return s or "concept"


def canonical_name(fm: Dict[str, Any], entry_id: str) -> str:
    slug = slugify(str(fm.get("pref_label") or ""))
    return f"{slug}-{entry_id[:8]}.md"


def _is_empty(v: Any) -> bool:
    return v is None or v == "" or v == [] or v == {}


def _link_key(link: Any) -> Tuple[Any, Any]:
    if isinstance(link, dict):
        return (link.get("to"), link.get("rel"))
    return (repr(link), None)


def split_file(path: Path) -> Tuple[Dict[str, Any], str]:
    fm, body = split_frontmatter(path.read_text(encoding="utf-8"))
    return dict(fm), body


def compute_content_hash(fm: Dict[str, Any]) -> str:
    sub = {k: v for k, v in fm.items() if k != "content_hash"}
    payload = json.dumps(sub, sort_keys=True, ensure_ascii=False)
    return "sha256:" + hashlib.sha256(payload.encode("utf-8")).hexdigest()


def merge_group(files: List[Path]) -> Tuple[Dict[str, Any], str, Path, List[Path]]:
    """Return (merged_fm, merged_body, canonical_path, files_to_delete)."""
    parsed = [(p, *split_file(p)) for p in sorted(files, key=lambda x: x.name)]
    entry_id = str(parsed[0][1].get("entry_id"))

    seeded = sorted(
        parsed,
        key=lambda t: (0 if t[0].name == canonical_name(t[1], entry_id) else 1,
                       t[0].name),
    )

    merged: Dict[str, Any] = {}
    alt_labels: List[Any] = []
    seen_alt: set = set()
    links: List[Any] = []
    seen_link: set = set()
    gloss = ""
    sensitivity_rank = -1
    sensitivity_val = None

    for _p, fm, _b in seeded:
        for k, v in fm.items():
            if k in ("content_hash", "alt_label", "links", "gloss",
                     "sensitivity"):
                continue
            if k not in merged or _is_empty(merged.get(k)):
                if not _is_empty(v) or k not in merged:
                    merged[k] = v

        for a in (fm.get("alt_label") or []):
            key = json.dumps(a, sort_keys=True, ensure_ascii=False) \
                if not isinstance(a, str) else a
            if key not in seen_alt:
                seen_alt.add(key)
                alt_labels.append(a)

        for ln in (fm.get("links") or []):
            key = _link_key(ln)
            if key not in seen_link:
                seen_link.add(key)
                links.append(ln)

        g = fm.get("gloss")
        if isinstance(g, str) and g.strip() and not gloss:
            gloss = g.strip()

        s = fm.get("sensitivity")
        if isinstance(s, str):
            rank = _SENS_RANK.get(s, -1)
            if rank > sensitivity_rank:
                sensitivity_rank = rank
                sensitivity_val = s

    merged["alt_label"] = alt_labels
    merged["links"] = links
    if gloss:
        merged["gloss"] = gloss
    if sensitivity_val is not None:
        merged["sensitivity"] = sensitivity_val

    merged_body = ""
    best_len = -1
    for _p, _fm, b in seeded:
        bl = len(b.strip())
        if bl > best_len:
            best_len = bl
            merged_body = b

    merged["content_hash"] = compute_content_hash(merged)

    cdir = seeded[0][0].parent
    canonical_path = cdir / canonical_name(merged, entry_id)
    delete = [p for (p, _f, _b) in seeded if p != canonical_path]
    return merged, merged_body, canonical_path, delete


def render(fm: Dict[str, Any], body: str) -> str:
    fm_text = yaml.safe_dump(fm, sort_keys=True, allow_unicode=True)
    return f"---\n{fm_text}---\n\n{body.lstrip(chr(10))}"


def group_by_entry_id(entities_dir: Path) -> Dict[str, List[Path]]:
    groups: Dict[str, List[Path]] = {}
    for p in sorted(entities_dir.glob("*.md")):
        fm, _ = split_file(p)
        eid = fm.get("entry_id")
        if not eid:
            continue
        groups.setdefault(str(eid), []).append(p)
    return groups


def run(entities_dir: Path, apply: bool) -> Tuple[int, int]:
    groups = group_by_entry_id(entities_dir)
    pairs_merged = 0
    files_deleted = 0

    for eid, files in sorted(groups.items()):
        if len(files) <= 1:
            continue
        merged_fm, body, canonical_path, delete = merge_group(files)
        pairs_merged += 1
        rendered = render(merged_fm, body)

        action = "rewrite" if canonical_path.exists() else "create"
        print(f"[group] entry_id={eid}")
        print(f"  files: {[p.name for p in sorted(files, key=lambda x: x.name)]}")
        print(f"  canonical -> {canonical_path.name} ({action})")
        for d in delete:
            print(f"  delete    -> {d.name}")

        if apply:
            canonical_path.write_text(rendered, encoding="utf-8")
            for d in delete:
                if d != canonical_path:
                    d.unlink()
        files_deleted += len([d for d in delete if d != canonical_path])

    return pairs_merged, files_deleted


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--vault-root", default=None,
                    help="vault root (default: cfg.vault.local from engine config)")
    ap.add_argument("--entities-dir", default=None,
                    help="override the entities dir directly")
    ap.add_argument("--apply", action="store_true",
                    help="write changes; otherwise dry-run (default)")
    ap.add_argument("--dry-run", action="store_true",
                    help="report only, no writes (the default; accepted for clarity)")
    args = ap.parse_args()

    entities_dir = resolve_entities_dir(args.entities_dir, args.vault_root)
    pairs_merged, files_deleted = run(entities_dir, args.apply)
    mode = "APPLY" if args.apply else "DRY-RUN"
    print(f"\n[{mode}] pairs_merged={pairs_merged} files_deleted={files_deleted}")


if __name__ == "__main__":
    main()
