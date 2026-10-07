#!/usr/bin/env python3
"""Forever Codex data generator (First Light).

Reads, READ-ONLY:
  * the local ATT `forever` database (through the existing, frozen foreverdb ATT parser), and
  * the observed-quest table shipped in the M8.13 addon, copied byte for byte to generator/inputs/observed_m6_data.lua,
and writes deterministic Lua data packs under ForeverCodex/Data/.

Provenance rules (see docs/CODEX_ARCHITECTURE.md):
  * ATT data is written to its own packs with src="att", verified=false. It is never described as a confirmed
    Forever fact: ATT's coordinates have unresolved upstream provenance (forever-db/docs/LICENSING.md) and ATT's
    `lvl` is a REQUIRED level, not a quest level (it is stored as `req`).
  * Observed data is written to its own pack with src="observed", verified=true. The engine merges the layers at
    read time; nothing is merged or overwritten here.
  * Output is deterministic: sorted keys/ids, no timestamps, fixed number formatting, input SHA-256s in headers.
  * Nothing under forever-db/ or archive/m8-13-progression/ is modified; ATT files are only read.

Usage:  python3 build_codex_data.py [--att-root DIR] [--observed FILE] [--out DIR] [--check]
"""
from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
from collections import Counter
from pathlib import Path

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[1]
FOREVERDB_SRC = REPO / "forever-db" / "src"
DEFAULT_ATT_ROOT = REPO / "forever-db" / "data" / "raw" / "att-head" / ".contrib" / ".db" / "forever"
DEFAULT_OBSERVED = HERE / "inputs" / "observed_m6_data.lua"      # a byte-for-byte copy of the M8.13 observed table (see inputs/README.md); the legacy addon is not needed
DEFAULT_OUT = REPO / "forever-codex" / "ForeverCodex" / "Data"
SOURCES_TOML = REPO / "forever-db" / "config" / "sources.toml"

GENERATOR_VERSION = "codex-data-1"
REPEAT_FLAGS = ("repeatable", "isYearly", "isMonthly", "isWeekly", "isDaily")
PACK_FILES = {  # continent folder (or file) in ATT's zones/ -> (output file stem, pack name, label)
    "kalimdor": ("Pack_ATT_Kalimdor", "att:kalimdor", "ATT Kalimdor"),
    "eastern kingdoms": ("Pack_ATT_EasternKingdoms", "att:eastern-kingdoms", "ATT Eastern Kingdoms"),
}
OTHER = ("Pack_ATT_Other", "att:other-zones", "ATT other zones")


# ------------------------------------------------------------------ small helpers

def sha256_file(p: Path) -> str:
    return hashlib.sha256(p.read_bytes()).hexdigest()


def slug(s: str) -> str:
    return re.sub(r"[^a-z0-9]+", "-", s.lower()).strip("-")


def zone_label(stem: str) -> str:
    stem = re.sub(r"^\d+\s*-\s*", "", stem)
    small = {"of", "the", "and"}
    words = stem.split()
    return " ".join(w if (i and w in small) else w[:1].upper() + w[1:] for i, w in enumerate(words))


def lua_str(s: str) -> str:
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n").replace("\r", "") + '"'


def lua_num(v: float | int) -> str:
    if isinstance(v, int):
        return str(v)
    return ("%.4f" % v).rstrip("0").rstrip(".")


def lua_value(v) -> str:
    if v is None:
        return "nil"
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, (int, float)):
        return lua_num(v)
    if isinstance(v, str):
        return lua_str(v)
    if isinstance(v, (list, tuple)):
        return "{" + ", ".join(lua_value(x) for x in v) + "}"
    if isinstance(v, dict):
        return "{" + ", ".join(f"{k} = {lua_value(v[k])}" for k in sorted(v)) + "}"
    raise TypeError(type(v))


def load_att_parser():
    sys.path.insert(0, str(FOREVERDB_SRC))
    from foreverdb.att import importer as I  # noqa: E402  (frozen, read-only use)
    from foreverdb.att.dsl import parse_source, walk_calls  # noqa: E402
    return I, parse_source, walk_calls


def att_pin() -> dict:
    """The pinned ATT snapshot recorded in forever-db/config/sources.toml (read-only)."""
    import tomllib
    cfg = tomllib.loads(SOURCES_TOML.read_text(encoding="utf-8"))
    for s in cfg["snapshot"]:
        if s["key"] == "att-head":
            return {"repo": s["repo"], "sha": s["sha"], "license": s["license_id"]}
    raise SystemExit("att-head not found in sources.toml")


def symbols(value) -> list[str]:
    """ATT restriction values -> a flat list of plain symbol names; None if the form is not a simple symbol list."""
    items = value if isinstance(value, list) else [value]
    out = []
    for it in items:
        if isinstance(it, dict) and set(it) == {"symbol"}:
            out.append(it["symbol"])
        else:
            return None
    return out


# ------------------------------------------------------------------ ATT extraction

NPC_NAME_RE = re.compile(r'\["qg"\]\s*=\s*(\d+)\s*,\s*--\s*(.+?)\s*$')


def npc_names(files: list[Path]) -> dict[int, str]:
    names: dict[int, str] = {}
    for f in files:
        for line in f.read_text(encoding="utf-8-sig", errors="replace").splitlines():
            m = NPC_NAME_RE.search(line)
            if m and int(m.group(1)) not in names:
                names[int(m.group(1))] = m.group(2)
    return names


def extract_att(att_root: Path) -> dict:
    I, parse_source, walk_calls = load_att_parser()
    consts = I.read_constants(att_root / ".config" / "constants" / "maps.lua")
    report = I.ImportReport()
    zone_files = sorted((att_root / "zones").rglob("*.lua"), key=lambda p: p.relative_to(att_root).as_posix())
    names = npc_names(zone_files)
    zones: dict[str, dict] = {}
    quests: dict[int, dict] = {}
    flights: dict[int, dict] = {}
    file_hashes: dict[str, str] = {}
    for f in zone_files:
        rel = f.relative_to(att_root).as_posix()
        parts = rel.split("/")
        cont = parts[1] if len(parts) > 2 else None
        label = zone_label(f.stem)
        zkey = slug(re.sub(r"^\d+\s*-\s*", "", f.stem))
        file_hashes[rel] = sha256_file(f)
        parsed = parse_source(f.read_text(encoding="utf-8-sig", errors="replace"))
        z = zones.setdefault(zkey, {"key": zkey, "label": label, "continent": cont, "maps": Counter(), "quests": 0, "no_coord": 0})
        for call in walk_calls(parsed.calls):
            if call.name == "q" and call.args and isinstance(call.args[0], int):
                rec = quest_record(I, call, consts, report, names, zkey)
                rec["_cont"] = cont
                prev = quests.get(rec["id"])
                if prev is None or better(rec, prev):
                    quests[rec["id"]] = rec
            elif call.name == "fp" and call.args and isinstance(call.args[0], int):
                fp = flight_record(I, call, consts)
                if fp and call.args[0] not in flights:
                    fp["_cont"] = cont
                    flights[call.args[0]] = fp
    for q in quests.values():
        z = zones[q["zone"]]
        z["quests"] += 1
        if "map" in q:
            z["maps"][q["map"]] += 1
        else:
            z["no_coord"] += 1
    for z in zones.values():
        z["map"] = min(z["maps"], key=lambda m: (-z["maps"][m], m)) if z["maps"] else None
        del z["maps"]
    return {"quests": quests, "flights": flights, "zones": zones, "files": file_hashes,
            "parse_errors": len(report.parse_errors), "constants": len(consts)}


def better(a: dict, b: dict) -> bool:
    """Deterministic duplicate resolution: more populated record wins; ties keep the first (sorted-path) one."""
    return (("map" in a) + ("giverNpc" in a) + len(a)) > (("map" in b) + ("giverNpc" in b) + len(b))


def quest_record(I, call, consts, report, names, zkey) -> dict:
    facts = I.quest_facts(call, consts, report)
    rec: dict = {"id": call.args[0], "zone": zkey}
    name = None
    prereq: set[int] = set()
    for field, val, _line, _m in facts:
        if field == "name.att_comment":
            name = val["normalized"]
        elif field == "giver.npc" and "giverNpc" not in rec:
            rec["giverNpc"] = val["npc_id"]
            if val["npc_id"] in names:
                rec["giverName"] = names[val["npc_id"]]
        elif field == "location.att_coord" and "map" not in rec and val.get("ui_map_id") is not None:
            rec["map"], rec["x"], rec["y"] = val["ui_map_id"], round(val["x"] / 100.0, 4), round(val["y"] / 100.0, 4)
        elif field == "level.att_lvl_unverified" and isinstance(val, int) and not isinstance(val, bool):
            rec["req"] = val  # REQUIRED level (ATT `lvl`); not the quest level
        elif field in ("relation.att_source_quest",):
            prereq.add(val["quest_id"])
        elif field == "att.restriction.races":
            s = symbols(val)
            if s is None:
                rec["restrictionUnparsed"] = True
            else:
                fac = [x for x in s if x in ("ALLIANCE_ONLY", "HORDE_ONLY")]
                races = sorted(x for x in s if x not in ("ALLIANCE_ONLY", "HORDE_ONLY"))
                if fac:
                    rec["faction"] = "Alliance" if fac[0] == "ALLIANCE_ONLY" else "Horde"
                if races:
                    rec["races"] = races
        elif field == "att.restriction.classes":
            s = symbols(val)
            if s is None or any(x not in CLASS_TOKENS for x in s):
                rec["restrictionUnparsed"] = True
            else:
                rec["classes"] = sorted(set(s))
        elif field.startswith("att.flag."):
            key = field[len("att.flag."):]
            if val is True and key in REPEAT_FLAGS:
                rec["repeatable"] = True
            if val is True and key == "isBreadcrumb":
                rec["breadcrumb"] = True
        elif field == "objective.att":
            coords = [c for c in val.get("coords", []) if c.get("ui_map_id") is not None]
            if coords:
                rec.setdefault("objCoords", [])
                for c in coords[:2]:
                    if len(rec["objCoords"]) < 3:
                        rec["objCoords"].append({"map": c["ui_map_id"], "x": round(c["x"] / 100.0, 4), "y": round(c["y"] / 100.0, 4)})
    rec["name"] = name or "Quest %d" % call.args[0]
    if not name:
        rec["nameMissing"] = True
    if prereq:
        rec["prereq"] = sorted(prereq)
    return rec


CLASS_TOKENS = {"WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "SHAMAN", "MAGE", "WARLOCK", "DRUID"}


def flight_record(I, call, consts) -> dict | None:
    rec: dict = {"id": call.args[0]}
    if call.comment:
        rec["name"] = I.normalize_name(call.comment)
    for field, val, _l, _m in I.fp_facts(call, consts):
        if field == "location.att_coord" and "map" not in rec and val.get("ui_map_id") is not None:
            rec["map"], rec["x"], rec["y"] = val["ui_map_id"], round(val["x"] / 100.0, 4), round(val["y"] / 100.0, 4)
        elif field == "flight_master.att_cr":
            rec["npc"] = val["npc_id"]
        elif field == "att.restriction.races":
            s = symbols(val)
            fac = [x for x in (s or []) if x in ("ALLIANCE_ONLY", "HORDE_ONLY")]
            if fac:
                rec["faction"] = "Alliance" if fac[0] == "ALLIANCE_ONLY" else "Horde"
    return rec if "map" in rec else None


# ------------------------------------------------------------------ observed extraction (M8.13 Data.lua)

OBS_BLOCK = re.compile(r"^  \[(\d+)\] = \{\n(.*?)^  \},$", re.S | re.M)
LUA_STR = r'"((?:[^"\\]|\\.)*)"'


def unescape(s: str) -> str:
    return re.sub(r"\\(.)", lambda m: {"n": "\n", "t": "\t"}.get(m.group(1), m.group(1)), s)


def extract_observed(path: Path) -> dict[int, dict]:
    text = path.read_text(encoding="utf-8")
    out: dict[int, dict] = {}
    for m in OBS_BLOCK.finditer(text):
        qid, body = int(m.group(1)), m.group(2)
        rec: dict = {"id": qid}
        t = re.search(r"^    title = " + LUA_STR + ",$", body, re.M)
        lv = re.search(r"^    level = (\d+),$", body, re.M)
        if not t:
            continue
        rec["name"] = unescape(t.group(1))
        if lv:
            rec["level"] = int(lv.group(1))
        ob = re.search(r"^    objectives = \{\n(.*?)^    \},$", body, re.S | re.M)
        if ob:
            rec["objectives"] = [unescape(x) for x in re.findall(r"^      " + LUA_STR + ",$", ob.group(1), re.M)]
        g = re.search(r"^    giver = \{ name = " + LUA_STR + r", npc_id = (\d+) \},$", body, re.M)
        if g:
            rec["giverName"], rec["giverNpc"] = unescape(g.group(1)), int(g.group(2))
        p = re.search(r"^    pos = \{ ui_map_id = (\d+), x = ([\d.]+), y = ([\d.]+) \},$", body, re.M)
        if p:
            rec["pos"] = {"map": int(p.group(1)), "x": round(float(p.group(2)), 4), "y": round(float(p.group(3)), 4)}
        out[qid] = rec
    return out


# ------------------------------------------------------------------ Lua writers

HEADER = """-- ForeverCodex/Data/{file}.lua
-- GENERATED FILE -- do not hand-edit. Regenerate with forever-codex/generator/build_codex_data.py.
-- Generator: {gen}
{extra}--
-- PROVENANCE: {prov}
"""

ATT_PROV = ("src=att, verified=false. Source: ATT (AllTheThings, MIT) 'forever' database, commit {sha}. Coordinates have "
            "unresolved upstream provenance; `req` is a REQUIRED level (ATT `lvl`), not a quest level. Nothing here is a "
            "confirmed Forever fact. Public redistribution of this file is a separate, undecided licensing question.")
OBS_PROV = ("src=observed, verified=true. Quest title/level/objectives/giver were observed on the live Forever client by "
            "ForeverRecorder and passed the M6 guide-readiness rule. `pos` is the PLAYER's position at a recorder "
            "checkpoint, not a surveyed NPC location.")


def quest_lua(rec: dict, keys: list[str]) -> str:
    fields = ", ".join(f"{k} = {lua_value(rec[k])}" for k in keys if k in rec)
    return f"  [{rec['id']}] = {{ {fields} }},"


ATT_KEYS = ["id", "name", "zone", "giverNpc", "giverName", "map", "x", "y", "req", "prereq", "faction", "races", "classes",
            "repeatable", "breadcrumb", "objCoords", "restrictionUnparsed", "nameMissing"]


def write_att_pack(out: Path, stem: str, pack: str, label: str, quests: list[dict], zones: list[dict], pin: dict,
                   inputs: dict[str, str]) -> str:
    quests = sorted(quests, key=lambda q: q["id"])
    zones = sorted(zones, key=lambda z: z["key"])
    extra = "".join(f"-- input {rel} sha256={h}\n" for rel, h in sorted(inputs.items()))
    lines = [HEADER.format(file=stem, gen=GENERATOR_VERSION, extra=extra, prov=ATT_PROV.format(sha=pin["sha"]))]
    meta = {"src": "att", "verified": False, "label": label, "priority": 10, "source": pin["repo"], "sourceRef": pin["sha"],
            "license": pin["license"], "quests": len(quests)}
    lines.append("local _, ns = ...")
    lines.append("ForeverCodex.RegisterPack(\"quests\", %s, {" % lua_str(pack))
    lines.append("  meta = " + lua_value(meta) + ",")
    lines.append("  zones = {")
    for z in zones:
        lines.append("    " + lua_value({"key": z["key"], "label": z["label"], "map": z["map"], "quests": z["quests"],
                                        "noCoord": z["no_coord"]}) + ",")
    lines.append("  },")
    lines.append("  quests = {")
    lines += [quest_lua(q, ATT_KEYS).replace("\n", " ") for q in quests]
    lines.append("  },")
    lines.append("})")
    return "\n".join(lines) + "\n"


def write_flight_pack(out: Path, flights: list[dict], pin: dict) -> str:
    flights = sorted(flights, key=lambda f: f["id"])
    lines = [HEADER.format(file="Pack_ATT_FlightPaths", gen=GENERATOR_VERSION, extra="", prov=ATT_PROV.format(sha=pin["sha"]))]
    lines.append("local _, ns = ...")
    lines.append('ForeverCodex.RegisterPack("flight", "att:flight-paths", {')
    lines.append("  meta = " + lua_value({"src": "att", "verified": False, "label": "ATT flight paths", "priority": 10,
                                           "source": pin["repo"], "sourceRef": pin["sha"], "license": pin["license"],
                                           "nodes": len(flights)}) + ",")
    lines.append("  nodes = {")
    for f in flights:
        lines.append("  [%d] = { %s }," % (f["id"], ", ".join(f"{k} = {lua_value(f[k])}" for k in ("id", "name", "map", "x", "y", "npc", "faction") if k in f)))
    lines.append("  },")
    lines.append("})")
    return "\n".join(lines) + "\n"


def write_observed_pack(observed: dict[int, dict], source_rel: str, source_sha: str) -> str:
    keys = ["id", "name", "level", "objectives", "giverNpc", "giverName", "pos"]
    extra = f"-- input {source_rel} sha256={source_sha}\n"
    lines = [HEADER.format(file="Pack_Observed", gen=GENERATOR_VERSION, extra=extra, prov=OBS_PROV)]
    lines.append("local _, ns = ...")
    lines.append('ForeverCodex.RegisterPack("quests", "observed:m6", {')
    lines.append("  meta = " + lua_value({"src": "observed", "verified": True, "label": "Observed on Forever (ForeverRecorder, M6)",
                                           "priority": 100, "quests": len(observed)}) + ",")
    lines.append("  zones = {},")
    lines.append("  quests = {")
    lines += [quest_lua(observed[i], keys) for i in sorted(observed)]
    lines.append("  },")
    lines.append("})")
    return "\n".join(lines) + "\n"


# ------------------------------------------------------------------ driver

def build(att_root: Path, observed_path: Path) -> dict[str, str]:
    pin = att_pin()
    att = extract_att(att_root)
    observed = extract_observed(observed_path)
    outputs: dict[str, str] = {}
    by_pack: dict[str, list[dict]] = {}
    for q in att["quests"].values():
        stem = PACK_FILES.get(q["_cont"], OTHER)[0]
        by_pack.setdefault(stem, []).append(q)
    zone_by_pack: dict[str, list[dict]] = {}
    for z in att["zones"].values():
        stem = PACK_FILES.get(z["continent"], OTHER)[0]
        zone_by_pack.setdefault(stem, []).append(z)
    inputs_by_pack: dict[str, dict[str, str]] = {}
    for rel, h in att["files"].items():
        parts = rel.split("/")
        stem = PACK_FILES.get(parts[1] if len(parts) > 2 else None, OTHER)[0]
        inputs_by_pack.setdefault(stem, {})[rel] = h
    for key, (stem, pack, label) in list(PACK_FILES.items()) + [(None, OTHER)]:
        qs = [{k: v for k, v in q.items() if not k.startswith("_")} for q in by_pack.get(stem, [])]
        outputs[stem + ".lua"] = write_att_pack(Path("."), stem, pack, label, qs, zone_by_pack.get(stem, []), pin,
                                                inputs_by_pack.get(stem, {}))
    outputs["Pack_ATT_FlightPaths.lua"] = write_flight_pack(Path("."), [{k: v for k, v in f.items() if not k.startswith("_")} for f in att["flights"].values()], pin)
    outputs["Pack_Observed.lua"] = write_observed_pack(observed, observed_path.relative_to(REPO).as_posix() if observed_path.is_relative_to(REPO) else observed_path.name, sha256_file(observed_path))
    n_att = len(att["quests"])
    man = ["Forever Codex data manifest (generated; deterministic)", f"generator: {GENERATOR_VERSION}",
           f"att source: {pin['repo']} @ {pin['sha']} ({pin['license']})",
           f"att quests: {n_att} (with coordinates: {sum(1 for q in att['quests'].values() if 'map' in q)}, "
           f"with giver npc: {sum(1 for q in att['quests'].values() if 'giverNpc' in q)}, "
           f"with required level: {sum(1 for q in att['quests'].values() if 'req' in q)}, "
           f"repeatable/yearly: {sum(1 for q in att['quests'].values() if q.get('repeatable'))})",
           f"att flight paths: {len(att['flights'])}", f"att zones: {len(att['zones'])}",
           f"observed quests: {len(observed)} (of which also in ATT: {sum(1 for i in observed if i in att['quests'])})", ""]
    for name in sorted(outputs):
        man.append(f"{hashlib.sha256(outputs[name].encode('utf-8')).hexdigest()}  {name}")
    outputs["MANIFEST.txt"] = "\n".join(man) + "\n"
    return outputs


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--att-root", type=Path, default=DEFAULT_ATT_ROOT)
    ap.add_argument("--observed", type=Path, default=DEFAULT_OBSERVED)
    ap.add_argument("--out", type=Path, default=DEFAULT_OUT)
    ap.add_argument("--check", action="store_true", help="do not write; fail if the files on disk differ from a fresh render")
    a = ap.parse_args(argv)
    outputs = build(a.att_root, a.observed)
    if a.check:
        bad = [n for n, t in outputs.items() if not (a.out / n).exists() or (a.out / n).read_text(encoding="utf-8") != t]
        print("OK: data files match a fresh render" if not bad else "DIFFERS: " + ", ".join(bad))
        return 1 if bad else 0
    a.out.mkdir(parents=True, exist_ok=True)
    for name, text in outputs.items():
        (a.out / name).write_text(text, encoding="utf-8", newline="\n")
    print((a.out / "MANIFEST.txt").read_text(encoding="utf-8"))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
