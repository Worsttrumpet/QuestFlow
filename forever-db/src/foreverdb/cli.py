"""Command line: `python -m foreverdb <command>`. Every command is explicit; nothing runs implicitly."""
from __future__ import annotations

import argparse
import json
import re
import sqlite3
import tomllib
from pathlib import Path
from typing import Any

from . import acquire, client_tables, coords, db, manifest, quests, registry
from .att import importer
from .provenance import utc_now

ROOT = Path(__file__).resolve().parents[2]
BUILD_LABEL_RE = re.compile(r"\.(\d+\.\d+\.\d+\.\d+)\.csv$")
VALIDATION_UI_MAPS = {1412: "Mulgore", 1423: "Eastern Plaguelands", 1433: "Redridge Mountains", 1453: "Stormwind City"}
# The client names nodes "Lakeshire, Redridge" / "Stormwind, Elwynn", so the UI-map name alone under-matches.
NAME_ALIASES = {1433: ["Redridge"], 1453: ["Stormwind"]}


def load_sources(path: Path) -> dict[str, dict[str, Any]]:
    raw = tomllib.loads(path.read_text(encoding="utf-8"))
    return {s["key"]: s for s in raw["snapshot"]}


def snapshot_info(root: Path, key: str, raw_dir: Path) -> tuple[acquire.SnapshotInfo, dict[str, Any]]:
    cfg = load_sources(root / "config" / "sources.toml")[key]
    info = acquire.SnapshotInfo(key, cfg["repo"], cfg["sha"], raw_dir / key, cfg["license_id"], cfg["license_status"],
                                cfg["upstream_provenance"], bool(cfg["mirrors_blizzard_csv"]))
    return info, cfg


def snapshot_source_set(info: acquire.SnapshotInfo, cfg: dict[str, Any]) -> manifest.SourceSet:
    d = info.root / cfg["wago_dir"]
    builds = sorted({m.group(1) for p in d.glob("*.csv") if (m := BUILD_LABEL_RE.search(p.name))})
    if len(builds) != 1:
        raise SystemExit(f"expected exactly one build label in {d}, found {builds}")
    return manifest.SourceSet(
        label=info.key, kind="git", uri=info.repo_url, ref=info.sha, directory=d, rel_dir=cfg["wago_dir"],
        build_claim=builds[0], claim_basis="filename label in third-party repo", origin="mirror", mirror_of="wago.tools")


def cmd_registry_show(a: argparse.Namespace) -> int:
    reg = registry.effective_registry(registry.load_registry(a.root / "registry" / "builds.toml"), a.root / "registry" / "verification_log.jsonl")
    print(f"product {reg.product}; Blizzard version service: {reg.version_service.status} ({reg.version_service.detail})")
    for b in reg.builds:
        print(f"  {b.id}  {b.verification:16s}  {len(b.evidence)} evidence item(s)")
    return 0


def cmd_registry_verify(a: argparse.Namespace) -> int:
    reg = registry.load_registry(a.root / "registry" / "builds.toml")
    res = registry.check_version_service(reg)
    registry.append_log(a.root / "registry" / "verification_log.jsonl", res)
    print(f"{res.status}: {res.detail}")
    if res.status == "checked":
        print(f"current build per Blizzard: {res.current_build} (in registry: {res.registered})")
    else:
        print("Registry unchanged: builds remain 'unverified'.")
    return 0


def cmd_acquire(a: argparse.Namespace) -> int:
    for key in a.snapshots:
        info, _ = snapshot_info(a.root, key, a.raw)
        acquire.acquire_git_snapshot(info.repo_url, info.sha, info.root)
        print(f"acquired {key} @ {info.sha[:12]} -> {info.root}")
    return 0


def cmd_manifest(a: argparse.Namespace) -> int:
    specs = manifest.load_table_specs(a.root / "config" / "tables.toml")
    info, cfg = snapshot_info(a.root, a.snapshot, a.raw)
    m = manifest.build_manifest(specs, snapshot_source_set(info, cfg))
    out = a.root / "manifests" / f"db2_manifest.{a.snapshot}.json"
    manifest.write_json(out, m)
    read = sum(1 for t in m["tables"] if t["status"] == "read")
    print(f"{out.relative_to(a.root)}: {read}/{len(m['tables'])} configured tables read; {len(m['extra_tables_present'])} extra tables present")
    return 0


def cmd_manifest_diff(a: argparse.Namespace) -> int:
    ma = json.loads((a.root / "manifests" / f"db2_manifest.{a.a}.json").read_text())
    mb = json.loads((a.root / "manifests" / f"db2_manifest.{a.b}.json").read_text())
    d = manifest.diff_manifests(ma, mb)
    manifest.write_json(a.root / "manifests" / "db2_manifest_diff.json", d)
    print(f"identical: {len(d['identical_content'])}  changed: {len(d['changed'])}  added: {len(d['added'])}  removed: {len(d['removed'])}")
    for w in d["warnings"]:
        print("WARNING:", w)
    return 0


def cmd_build_db(a: argparse.Namespace) -> int:
    reg = registry.effective_registry(registry.load_registry(a.root / "registry" / "builds.toml"), a.root / "registry" / "verification_log.jsonl")
    info, cfg = snapshot_info(a.root, a.snapshot, a.raw)
    conn = db.connect(a.out)
    db.init_schema(conn)
    db.insert_registry(conn, reg)
    src = snapshot_source_set(info, cfg)
    build = src.build_claim
    for table, loader in (("UiMapAssignment", None), ("TaxiNodes", client_tables.load_taxi_nodes), ("UiMap", client_tables.load_ui_maps)):
        rel = f"{cfg['wago_dir']}/{table}.{build}.csv"
        rec = acquire.mirrored_csv_record(info, rel, build)
        ds = db.insert_dataset(conn, rec)
        if table == "UiMapAssignment":
            coords.load_assignments_into_db(conn, coords.read_assignments(info.root / rel), ds)
            transform_ds = ds
        else:
            loader(conn, info.root / rel, ds)
    if a.questv2:
        rec = acquire.user_file_record(Path(a.questv2), a.questv2_build, "user-declared build for a file they supplied")
        ds = db.insert_dataset(conn, rec)
        n = quests.load_client_questv2(conn, quests.read_questv2(Path(a.questv2)), ds, a.questv2_build)
        print(f"loaded {n} QuestV2 ids from {a.questv2}")
    if a.era_questv2:
        rec = acquire.user_file_record(Path(a.era_questv2), a.era_build, "user-declared Era build for a file they supplied")
        ds = db.insert_dataset(conn, rec)
        n = quests.load_era_baseline(conn, [q for q, _, _ in quests.read_questv2(Path(a.era_questv2))], ds)
        print(f"loaded {n} Era baseline ids")
    rep = importer.import_att_snapshot(conn, info, cfg["forever_root"], cfg["constants"], cfg["config"])
    counts = coords.derive_coordinates(conn, transform_ds)
    summary = {"snapshot": info.key, "ref": info.sha, "att_import": rep.summary(), "derived_coordinates": counts,
               "parse_error_samples": rep.parse_errors[:10],
               "id_crosscheck": importer.crosscheck_ids(info.root / cfg["forever_root"])}
    manifest.write_json(a.root / "manifests" / f"att_import_report.{info.key}.json", summary)
    print(json.dumps({k: summary[k] for k in ("att_import", "derived_coordinates")}, indent=2)[:1800])
    flags = conn.execute("SELECT client_id_observed c, era_baseline e, att_observed a, COUNT(*) n FROM v_quest_shell GROUP BY 1,2,3").fetchall()
    print("quest shell flag combinations (NULL = source not loaded):", [dict(r) for r in flags])
    return 0


def limitations(contain: dict[str, Any], accuracy: dict[str, Any]) -> list[str]:
    """Limitations are computed from the counts, never hard-coded, so they cannot contradict the data."""
    none = [e["ui_map_name"] for e in contain.values() if e["accuracy_points"] == 0]
    thin = [f"{e['ui_map_name']} ({e['accuracy_points']})" for e in contain.values() if 0 < e["accuracy_points"] < 3]
    out = [f"Accuracy is validated only where an independent map-percentage observation exists: {accuracy['n']} ATT flight paths "
           f"across {len(accuracy['points_per_ui_map'])} UI maps."]
    if none:
        out.append("No accuracy observation exists in the accessible sources for: " + ", ".join(none) +
                   ". Their accuracy is NOT validated; the containment check is weak (node names vs region rectangle).")
    if thin:
        out.append("Too few accuracy points to establish accuracy (count in brackets): " + ", ".join(thin) + ".")
    out.append("All points come from one third-party source (ATT, coordinates given to 0.1 map-% precision); client positions come "
               "from a mirrored CSV whose build label is unverified.")
    return out


def cmd_validate_coords(a: argparse.Namespace) -> int:
    conn = db.connect(a.db)
    ds = conn.execute("SELECT DISTINCT dataset_id FROM client_ui_map_assignment").fetchone()[0]
    assignments = coords.assignments_from_db(conn, ds)
    pts = coords.flight_path_points_from_db(conn)
    accuracy = coords.validate_flight_paths(pts, assignments)
    nodes = [dict(r) for r in conn.execute("SELECT node_id, name, continent_id, world_x, world_y FROM client_taxi_node")]
    names = {r["ui_map_id"]: r["name"] for r in conn.execute("SELECT ui_map_id, name FROM client_ui_map")}
    contain = coords.containment_check(nodes, assignments, names, list(VALIDATION_UI_MAPS), NAME_ALIASES)
    for ui, entry in contain.items():
        entry["accuracy_points"] = accuracy["points_per_ui_map"].get(ui, 0)
    report = {
        "transform_id": coords.TRANSFORM_ID,
        "assignments_total": len(assignments), "assignments_supported": sum(a_.supported for a_ in assignments),
        "flight_path_accuracy": accuracy,
        "changed_frame_maps": contain,
        "limitations": limitations(contain, accuracy),
    }
    manifest.write_json(a.root / "manifests" / "coord_validation.json", report)
    print(f"flight paths: n={accuracy['n']} mean={accuracy['mean_abs_err_map_pct']} max={accuracy['max_abs_err_map_pct']}")
    for ui, e in contain.items():
        print(f"  {ui} {e['ui_map_name']}: nodes by name={len(e['nodes'])} all_inside={e.get('all_inside')} accuracy_points={e['accuracy_points']}")
    return 0


def main(argv: list[str] | None = None) -> int:
    p = argparse.ArgumentParser(prog="foreverdb")
    p.add_argument("--root", type=Path, default=ROOT)
    p.add_argument("--raw", type=Path, default=None, help="raw data dir (default <root>/data/raw)")
    sub = p.add_subparsers(dest="cmd", required=True)
    r = sub.add_parser("registry"); rs = r.add_subparsers(dest="sub", required=True)
    rs.add_parser("show").set_defaults(fn=cmd_registry_show)
    rs.add_parser("verify").set_defaults(fn=cmd_registry_verify)
    ac = sub.add_parser("acquire"); ac.add_argument("snapshots", nargs="+"); ac.set_defaults(fn=cmd_acquire)
    mf = sub.add_parser("manifest"); mf.add_argument("--snapshot", required=True); mf.set_defaults(fn=cmd_manifest)
    md = sub.add_parser("manifest-diff"); md.add_argument("--a", required=True); md.add_argument("--b", required=True); md.set_defaults(fn=cmd_manifest_diff)
    bd = sub.add_parser("build-db")
    bd.add_argument("--snapshot", required=True); bd.add_argument("--out", type=Path, default=None)
    bd.add_argument("--questv2", default=None); bd.add_argument("--questv2-build", default=None)
    bd.add_argument("--era-questv2", default=None); bd.add_argument("--era-build", default=None)
    bd.set_defaults(fn=cmd_build_db)
    vc = sub.add_parser("validate-coords"); vc.add_argument("--db", type=Path, default=None); vc.set_defaults(fn=cmd_validate_coords)
    a = p.parse_args(argv)
    a.raw = a.raw or a.root / "data" / "raw"
    if getattr(a, "out", None) is None and a.cmd == "build-db":
        a.out = a.root / "data" / "build" / "forever.sqlite"
    if a.cmd == "validate-coords" and a.db is None:
        a.db = a.root / "data" / "build" / "forever.sqlite"
    if a.cmd == "build-db" and (bool(a.questv2) != bool(a.questv2_build) or bool(a.era_questv2) != bool(a.era_build)):
        p.error("--questv2 needs --questv2-build, and --era-questv2 needs --era-build (a build label is never guessed)")
    return a.fn(a)
