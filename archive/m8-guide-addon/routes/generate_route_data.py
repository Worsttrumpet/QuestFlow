"""M8.3: hand-authored route JSON -> generated RouteData.lua.

Reads every `*_route.json` file under this directory (each hand-authored, never generated), validates each
against the CURRENT M6 guide-ready quest set via `route_schema.validate_route`, and writes one generated Lua
file:

    m8-guide-addon/addon/ForeverQuestGuide/RouteData.lua

This script never writes to `m6-dataset-baseline/out/`, never modifies a route `*.json` file, and never
touches M8.1's `Data.lua` or its generator. It reuses M8.1's own `generate_addon_data` module (unmodified,
imported, not copied) to read the same M6 guide dataset and the same minimal-contract extraction, so route
validation checks quest IDs against exactly the same guide-ready set the quest browser itself uses -- never
a second, possibly-divergent copy of that logic.

## What is generated, and why so little

A `RouteStep` in the output carries ONLY the fields `route_schema.py`'s docstring says it may: id, kind,
quest_id, objective_index, npc, destination, display_text, next_step_id, provenance. No quest title, giver
name (beyond what the route author explicitly chose to record for a NPC field, itself never copied from
Data.lua -- see below), or objective text is duplicated here; the addon's UI layer looks those up live from
`Data.lua`'s `ns.QuestData` at render time. This is the direct implementation of
`docs/M8_2_SCOPE.md` SS14's requirement that route data never embeds a copy of quest content.

The one field this generator DOES copy verbatim from the route JSON's own `npc` entries is exactly what the
route author wrote there -- it is not looked up from M6 at generation time, specifically so a `TURN_IN`/
`ACCEPT` step's NPC is traceable to what the author asserted, not silently re-derived. Every referenced
`quest_id`'s `npc` in the current M6 dataset is cross-checked against the route's own `npc` at validation
time (see `_check_npc_matches_m6`) so a route can never silently drift from M6's own giver record without
the generator refusing to run.

## Determinism

Same guarantee as `generate_addon_data.py`: no timestamp anywhere in the output; the only provenance stamp
is the SHA-256 of each route JSON file's exact bytes plus the M6 guide dataset's own SHA-256 (both already
used as the trust anchor by M8.1's generator). Route files are processed in a sorted-by-filename order, and
each route's steps are emitted in the route's own explicit `next_step_id` walk order (from
`route_schema.validate_route`'s return value) -- never JSON dict iteration order, never quest ID order.
"""
from __future__ import annotations

import hashlib
import json
import sys
from pathlib import Path
from typing import Any

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "generator"))
import generate_addon_data as QUEST_GEN  # noqa: E402 -- M8.1's own, unmodified generator module
import route_schema  # noqa: E402

ROUTES_DIR = Path(__file__).resolve().parent
ROUTE_DATA_FILE = Path(__file__).resolve().parents[1] / "addon" / "ForeverQuestGuide" / "RouteData.lua"


def load_guide_ready_quests() -> dict[int, dict]:
    """Return {quest_id: minimal-contract dict}, reusing M8.1's own generator/validation, unmodified.
    This is the SAME quest set (and the same field shapes) the addon's own Data.lua is generated from."""
    _, quests, _ = QUEST_GEN.generate()
    return {q["id"]: q for q in quests}


def _check_npc_matches_m6(route_id: str, step: dict, quests_by_id: dict[int, dict]) -> None:
    """A step's own asserted `npc` must equal the current M6 giver for that quest_id, when both are
    present. This is not part of route_schema's shape validation (that module knows nothing about M6's
    content, only about route shape) -- it is this generator's own extra guard against a route silently
    drifting from the observed giver record it references."""
    npc, quest_id = step.get("npc"), step.get("quest_id")
    if npc is None or quest_id is None:
        return
    m6_giver = quests_by_id[quest_id]["giver"]
    if npc != m6_giver:
        raise route_schema.RouteValidationError(
            f"route {route_id!r} step {step['id']}: npc {npc!r} does not match M6's own giver "
            f"{m6_giver!r} for quest {quest_id}"
        )


def _forbid_source_derived(route_id: str, step: dict) -> None:
    """M8.3's own scope (not route_schema's, which permits the shape for future use) forbids any
    SOURCE_DERIVED_ATT destination in an actual M8.3 route: no ATT coordinate may be packaged here."""
    dest = step.get("destination")
    if isinstance(dest, dict) and dest.get("kind") == "SOURCE_DERIVED_ATT":
        raise route_schema.RouteValidationError(
            f"route {route_id!r} step {step['id']}: SOURCE_DERIVED_ATT destinations are not permitted in an M8.3 route"
        )


def load_and_validate_route(path: Path, quests_by_id: dict[int, dict]) -> tuple[dict, list[str], str]:
    """Load one route JSON file, validate it, and return (route_dict, ordered_step_ids, source_sha256)."""
    raw = path.read_bytes()
    route = json.loads(raw)
    order = route_schema.validate_route(route, quests_by_id)
    for step_id in order:
        step = route["steps"][step_id]
        _check_npc_matches_m6(route["id"], step, quests_by_id)
        _forbid_source_derived(route["id"], step)
    return route, order, hashlib.sha256(raw).hexdigest()


def find_route_files() -> list[Path]:
    return sorted(ROUTES_DIR.glob("*_route.json"))


def lua_string(s: str) -> str:
    return QUEST_GEN.lua_string(s)  # reuse M8.1's already-tested, real-data-exercised escaper verbatim


def lua_number(n) -> str:
    return QUEST_GEN.lua_number(n)


def _render_destination(dest: dict | None, indent: str) -> list[str]:
    if dest is None:
        return [f"{indent}destination = nil,"]
    lines = [f"{indent}destination = {{"]
    lines.append(f"{indent}  kind = {lua_string(dest['kind'])},")
    if dest["kind"] in ("OBSERVED_PLAYER_POSITION", "SOURCE_DERIVED_ATT"):
        lines.append(f"{indent}  ui_map_id = {lua_number(dest['ui_map_id'])},")
        lines.append(f"{indent}  x = {lua_number(dest['x'])},")
        lines.append(f"{indent}  y = {lua_number(dest['y'])},")
    elif dest["kind"] == "ROUTE_AUTHORED":
        lines.append(f"{indent}  text = {lua_string(dest['text'])},")
    lines.append(f"{indent}}},")
    return lines


def _render_npc(npc: dict | None, indent: str) -> list[str]:
    if npc is None:
        return [f"{indent}npc = nil,"]
    return [f"{indent}npc = {{ name = {lua_string(npc['name'])}, npc_id = {lua_number(npc['npc_id'])} }},"]


def render_lua(routes: list[tuple[dict, list[str], str]], m6_sha256: str) -> str:
    lines = [
        "-- ForeverQuestGuide/RouteData.lua",
        "-- GENERATED FILE -- do not hand-edit. Edit the *_route.json files under m8-guide-addon/routes/",
        "-- instead, then re-run m8-guide-addon/routes/generate_route_data.py.",
        "--",
        "-- Every route here is HAND-AUTHORED data (see the *_route.json source files). No step's",
        "-- existence, ordering, or instruction text was derived from quest ID, ATT, or any inferred",
        "-- relationship -- provenance = 'route-authored' on every route and every step says so explicitly.",
        "-- A step's quest_id/objective_index are references into ns.QuestData (Data.lua); no quest title,",
        "-- giver name, or objective text is duplicated here -- the UI looks those up live.",
        "-- 'why' and 'required' (M8.6-A) are also route-authored, optional (nil when the author omitted",
        "-- them), and never inferred from quest data, ATT, or anything else.",
        f"-- M6 guide dataset SHA-256 this was validated against: {m6_sha256}",
    ]
    for route, order, route_sha in routes:
        lines.append(f"-- Route {route['id']!r} source SHA-256: {route_sha}")
    lines += ["", "local _, ns = ...", "", "ns.Routes = {"]
    for route, order, _ in routes:
        lines.append(f"  [{lua_string(route['id'])}] = {{")
        lines.append(f"    id = {lua_string(route['id'])},")
        lines.append(f"    title = {lua_string(route['title'])},")
        lines.append(f"    provenance = {lua_string(route['provenance'])},")
        lines.append(f"    first_step = {lua_string(route['first_step'])},")
        lines.append("    steps = {")
        for step_id in order:
            step = route["steps"][step_id]
            lines.append(f"      [{lua_string(step_id)}] = {{")
            lines.append(f"        id = {lua_string(step['id'])},")
            lines.append(f"        provenance = {lua_string(step['provenance'])},")
            lines.append(f"        kind = {lua_string(step['kind'])},")
            lines.append(f"        quest_id = {lua_number(step['quest_id']) if step.get('quest_id') is not None else 'nil'},")
            lines.append(f"        objective_index = {lua_number(step['objective_index']) if step.get('objective_index') is not None else 'nil'},")
            lines.extend(f"        {ln}" for ln in _render_npc(step.get("npc"), ""))
            lines.extend(f"        {ln}" for ln in _render_destination(step.get("destination"), ""))
            lines.append(f"        display_text = {lua_string(step['display_text'])},")
            lines.append(f"        next_step_id = {lua_string(step['next_step_id']) if step.get('next_step_id') is not None else 'nil'},")
            # M8.6-A: both optional route-authored fields; omitted from the JSON means nil here too --
            # never defaulted to a value the author didn't actually write (see route_schema.py's docstring).
            why = step.get("why")
            lines.append(f"        why = {lua_string(why) if why is not None else 'nil'},")
            required = step.get("required")
            lines.append(f"        required = {('true' if required else 'false') if required is not None else 'nil'},")
            lines.append("      },")
        lines.append("    },")
        lines.append(f"    step_order = {{ {', '.join(lua_string(s) for s in order)} }},")
        lines.append("  },")
    lines.append("}")
    lines.append("")
    lines.append("-- Deterministic route display order (the order route files were found in, sorted by filename).")
    lines.append("ns.RouteOrder = { " + ", ".join(lua_string(r["id"]) for r, _, _ in routes) + " }")
    lines.append("")
    return "\n".join(lines)


def generate() -> tuple[str, list[tuple[dict, list[str], str]], str]:
    """Pure function: reads M6 + every route JSON file, validates, returns (lua_text, routes, m6_sha256)."""
    quests_by_id = load_guide_ready_quests()
    m6_sha256 = hashlib.sha256(QUEST_GEN.M6_GUIDE_DATASET.read_bytes()).hexdigest()
    routes = [load_and_validate_route(p, quests_by_id) for p in find_route_files()]
    if not routes:
        raise route_schema.RouteValidationError("no *_route.json files found under m8-guide-addon/routes/")
    lua_text = render_lua(routes, m6_sha256)
    return lua_text, routes, m6_sha256


if __name__ == "__main__":
    lua_text, routes, m6_sha256 = generate()
    ROUTE_DATA_FILE.parent.mkdir(parents=True, exist_ok=True)
    ROUTE_DATA_FILE.write_text(lua_text, encoding="utf-8", newline="\n")
    print(f"wrote {ROUTE_DATA_FILE} ({ROUTE_DATA_FILE.stat().st_size} bytes)")
    for route, order, sha in routes:
        print(f"  route {route['id']!r}: {len(order)} steps, source sha256 {sha}")
    lua_text_2, _, _ = generate()
    if lua_text_2 != lua_text:
        print("DETERMINISM CHECK FAILED: re-running produced different output", file=sys.stderr)
        sys.exit(1)
    print("determinism self-check: OK (re-run produced byte-identical output)")
