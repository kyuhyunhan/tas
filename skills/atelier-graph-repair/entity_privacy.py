#!/usr/bin/env python3
"""Deterministic entity privacy reclassification over graph/atomic/.

NO LLM judgment. Privacy is propagated from claims to the entities they are
about, using only the graph's own edges plus an OPTIONAL out-of-tree rules file.
Three passes + a flag-for-review file:

  1) CLOSURE (sensitivity flows from claims to entities).
     An entity referenced by >=1 claim where EVERY referencing claim is
     ``sensitivity: private`` becomes ``sensitivity: private`` +
     ``in_scheme: [personal]`` — UNLESS the entity is already explicitly
     classified ``public`` + ``in_scheme: [knowledge]``. Closure never
     downgrades a deliberate public/knowledge classification (a public concept
     can legitimately appear only in private notes, e.g. a public figure cited in
     a private note); that decision is made by the hard rules / human review in passes 2
     and 3, and closure must respect it to stay idempotent on a settled graph.
     An entity referenced by >=1 *public* claim is likewise never privatized by
     closure (most-restrictive-wins from the claim side).

  2) HARD RULES (optional, out-of-tree).
     If ``--rules <file.json>`` is given, labels it lists are forced:
       { "pii":    ["label", ...],   # -> private + in_scheme:[personal]
         "public": ["label", ...] }  # -> public  + in_scheme:[knowledge]
     A PII rule overrides closure. A public rule is refused for any entity that
     has >=1 private referencing claim (it would downgrade a privately-
     referenced entity) — such conflicts are flagged for review instead.
     Labels resolve via pref_label, alt_label, then file stem. The rules file
     lives OUTSIDE this repo (e.g. ~/.atelier/...); it is never committed here.

  3) FLAG AMBIGUOUS (write-only, no mutation).
     Entities needing human/LLM judgment are written to
     ``graph/_entity_flagged.json``:
       (a) Person/Organization that are public yet referenced by >=1 private
           claim;
       (b) any entity whose in_scheme conflicts with its sensitivity;
       (c) any ``public`` rule refused in pass 2 (would-be downgrade).

read  = runtime.index.parse.split_frontmatter (engine = parse authority)
write = yaml.safe_dump(sort_keys=True, allow_unicode=True)
hash  = 'sha256:' + sha256(json.dumps(fm-minus-content_hash, sort_keys=True,
                                      ensure_ascii=False))

IDEMPOTENT: an already-correct graph yields 0 mutations on re-run.

Run:  python entity_privacy.py --dry-run            (report only; default)
      python entity_privacy.py --apply              (write changes)
      python entity_privacy.py --apply --rules R    (with out-of-tree hard rules)

Vault root resolves from the atelier engine config (``cfg.vault.local``) unless
``--vault-root`` is given. Requires the engine importable:
    PYTHONPATH=/path/to/atelier python entity_privacy.py --dry-run
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


def resolve_vault_root(cli_value: Optional[str]) -> Path:
    if cli_value:
        return Path(cli_value).expanduser()
    cfg = config.load()
    if cfg.vault is None:
        raise SystemExit("config has no `vault:` block; pass --vault-root")
    return Path(cfg.vault.local).expanduser()


def content_hash(fm: dict) -> str:
    payload = {k: v for k, v in fm.items() if k != "content_hash"}
    blob = json.dumps(payload, sort_keys=True, ensure_ascii=False)
    return "sha256:" + hashlib.sha256(blob.encode("utf-8")).hexdigest()


def dump_node(fm: dict, body: str) -> str:
    fm = dict(fm)
    fm.pop("content_hash", None)
    fm["content_hash"] = content_hash(fm)
    head = yaml.safe_dump(fm, sort_keys=True, allow_unicode=True,
                          default_flow_style=False)
    return f"---\n{head}---\n{body}"


def read_node(path: Path):
    fm, body = split_frontmatter(path.read_text(encoding="utf-8"))
    return fm, body


def norm_label(label) -> str:
    return str(label).strip() if label is not None else ""


def load_rules(rules_path: Optional[str]) -> Dict[str, List[str]]:
    if not rules_path:
        return {"pii": [], "public": []}
    data = json.loads(Path(rules_path).expanduser().read_text(encoding="utf-8"))
    return {"pii": list(data.get("pii") or []),
            "public": list(data.get("public") or [])}


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--vault-root", default=None,
                    help="vault root (default: cfg.vault.local from engine config)")
    ap.add_argument("--rules", default=None,
                    help="optional out-of-tree JSON: {pii:[...], public:[...]}")
    ap.add_argument("--apply", action="store_true",
                    help="write changes; otherwise dry-run (default)")
    ap.add_argument("--dry-run", action="store_true",
                    help="report only, no writes (the default; accepted for clarity)")
    args = ap.parse_args()
    dry_run = not args.apply

    vault_root = resolve_vault_root(args.vault_root)
    atomic = vault_root / "graph" / "atomic"
    entities_dir = atomic / "entities"
    claims_dir = atomic / "claims"
    flagged_path = atomic.parent / "_entity_flagged.json"

    rules = load_rules(args.rules)

    # --- Load entities, index by entry_id; build label resolvers -------------
    entities: Dict[str, Dict[str, Any]] = {}
    pref_to_eid: Dict[str, str] = {}
    alt_to_eid: Dict[str, str] = {}
    stem_to_eid: Dict[str, str] = {}
    for p in sorted(entities_dir.glob("*.md")):
        fm, body = read_node(p)
        eid = fm.get("entry_id")
        if not eid:
            continue
        entities[eid] = {"path": p, "fm": fm, "body": body}
        pref_to_eid.setdefault(norm_label(fm.get("pref_label")), eid)
        stem_to_eid.setdefault(p.stem, eid)
        for a in (fm.get("alt_label") or []):
            alt_to_eid.setdefault(norm_label(a), eid)

    def resolve_eid(label: str) -> Optional[str]:
        for table in (pref_to_eid, alt_to_eid, stem_to_eid):
            if label in table:
                return table[label]
        return None

    # --- Index claim sensitivity per entity via is_about --------------------
    priv_refs = {eid: 0 for eid in entities}
    pub_refs = {eid: 0 for eid in entities}
    for p in sorted(claims_dir.glob("*.md")):
        fm, _ = read_node(p)
        sens = fm.get("sensitivity")
        about = fm.get("is_about") or []
        if not isinstance(about, list):
            about = [about]
        for ref in about:
            if ref in entities:
                if sens == "private":
                    priv_refs[ref] += 1
                elif sens == "public":
                    pub_refs[ref] += 1

    closure_privatized = 0
    hard_pii = 0
    hard_public = 0
    refused_public_downgrade: List[Dict[str, Any]] = []

    # --- Pass 1: CLOSURE -----------------------------------------------------
    for eid, ent in entities.items():
        total = priv_refs[eid] + pub_refs[eid]
        if total >= 1 and pub_refs[eid] == 0:
            fm = ent["fm"]
            # Never downgrade a deliberate public/knowledge classification.
            already_public = (fm.get("sensitivity") == "public"
                              and fm.get("in_scheme") == ["knowledge"])
            if already_public:
                continue
            changed = False
            if fm.get("sensitivity") != "private":
                fm["sensitivity"] = "private"
                changed = True
            if fm.get("in_scheme") != ["personal"]:
                fm["in_scheme"] = ["personal"]
                changed = True
            if changed:
                ent["dirty"] = True
                closure_privatized += 1

    # --- Pass 2: HARD RULES (override closure) ------------------------------
    hard_eids: set = set()
    unresolved_pii: List[str] = []
    unresolved_pub: List[str] = []
    for label in rules["pii"]:
        eid = resolve_eid(label)
        if not eid:
            unresolved_pii.append(label)
            continue
        fm = entities[eid]["fm"]
        before = (fm.get("sensitivity"), fm.get("in_scheme"))
        fm["sensitivity"] = "private"
        fm["in_scheme"] = ["personal"]
        if before != ("private", ["personal"]):
            entities[eid]["dirty"] = True
        hard_pii += 1
        hard_eids.add(eid)

    for label in rules["public"]:
        eid = resolve_eid(label)
        if not eid:
            unresolved_pub.append(label)
            continue
        # GUARD: never downgrade a privately-referenced entity to public.
        if priv_refs[eid] >= 1:
            refused_public_downgrade.append({
                "entry_id": eid,
                "pref_label": norm_label(entities[eid]["fm"].get("pref_label")),
                "priv_refs": priv_refs[eid],
                "reason": "public_rule_refused_private_ref",
            })
            continue
        fm = entities[eid]["fm"]
        before = (fm.get("sensitivity"), fm.get("in_scheme"))
        fm["sensitivity"] = "public"
        fm["in_scheme"] = ["knowledge"]
        if before != ("public", ["knowledge"]):
            entities[eid]["dirty"] = True
        hard_public += 1
        hard_eids.add(eid)

    # --- Write dirty entities -----------------------------------------------
    written = 0
    for eid, ent in entities.items():
        if ent.get("dirty"):
            written += 1
            if not dry_run:
                ent["path"].write_text(dump_node(ent["fm"], ent["body"]),
                                       encoding="utf-8")

    # --- Pass 3: FLAG AMBIGUOUS ---------------------------------------------
    flagged: List[Dict[str, Any]] = []
    for eid, ent in entities.items():
        fm = ent["fm"]
        if eid in hard_eids:
            continue
        etype = fm.get("type")
        sens = fm.get("sensitivity")
        scheme = fm.get("in_scheme") or []
        if not isinstance(scheme, list):
            scheme = [scheme]
        scheme_set = set(scheme)

        reasons = []
        if etype in ("Person", "Organization") and sens == "public" \
                and priv_refs[eid] >= 1:
            reasons.append("public_person_org_with_private_ref")
        conflict = (
            (sens == "public" and "personal" in scheme_set
             and "knowledge" not in scheme_set)
            or (sens == "private" and "knowledge" in scheme_set
                and "personal" not in scheme_set)
        )
        if conflict:
            reasons.append("scheme_sensitivity_conflict")

        if reasons:
            flagged.append({
                "file": str(ent["path"]),
                "pref_label": norm_label(fm.get("pref_label")),
                "type": etype,
                "in_scheme": scheme,
                "sensitivity": sens,
                "priv_refs": priv_refs[eid],
                "pub_refs": pub_refs[eid],
                "reasons": reasons,
            })

    for r in refused_public_downgrade:
        flagged.append({**r, "reasons": [r["reason"]]})

    if not dry_run:
        flagged_path.write_text(
            json.dumps(flagged, ensure_ascii=False, indent=2, sort_keys=True),
            encoding="utf-8",
        )

    print(json.dumps({
        "summary": {
            "closure_privatized": closure_privatized,
            "hard_pii": hard_pii,
            "hard_public": hard_public,
            "refused_public_downgrade": len(refused_public_downgrade),
            "flagged_count": len(flagged),
            "entities_written": written,
        },
        "flagged_path": str(flagged_path),
        "entities_total": len(entities),
        "claims_indexed_priv_refs": sum(priv_refs.values()),
        "unresolved_pii_labels": sorted(unresolved_pii),
        "unresolved_public_labels": sorted(unresolved_pub),
        "dry_run": dry_run,
    }, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
