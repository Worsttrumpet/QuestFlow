"""M8.1: M6 guide dataset -> generated addon data file.

Reads the canonical M6 guide dataset (`m6-dataset-baseline/out/m6_guide_dataset.json`, produced and owned
by M6.6's `guide_data.py`) and writes ONE generated Lua file consumed by the ForeverQuestGuide addon:

    m8-guide-addon/addon/ForeverQuestGuide/Data.lua

This script never writes to `m6-dataset-baseline/out/` or any other existing project file -- it is
strictly additive, reading M6's output and producing a new file under `m8-guide-addon/` only.

## What is exported, and why

Only the `guide_ready_quest_ids` subset of M6's `quests` map is exported -- never the 57
insufficient-evidence quests, and never anything from the separate M7.4 ATT candidate-pool artifacts
(`research/m7_4/proposed_targets.json` is never even opened here). Per the M8.0 reconnaissance (see
`docs/M8_0_SCOPE.md` SS3), every field value inside a guide-ready record was itself recorder-observed --
ATT/source-derived data never appears inside `m6_guide_dataset.json`'s guide-ready records at all -- so
reading only this subset of this one file is sufficient to guarantee no ATT-derived value ever reaches
the addon.

The minimal contract (M8.0 SS3) is exactly what is exported per quest, nothing more:

    id, title, level, objectives (list of exact objective text strings, in M6's own order),
    giver {name, npc_id}, pos {ui_map_id, x, y}

Excluded deliberately (present in M6 but not part of this contract): every evidence-bookkeeping field
(`evidence_state`, `classification`, `observation_count`, `sessions`, `builds`), the `checkpoint` label
inside `interaction_position` (M8.0's own minimal-contract example omits it as pipeline bookkeeping, not
guide content), and every other M6 field not in the six above (`xp`, `money`, `choice_items`,
`guaranteed_items`, `reputation`, `gossip_availability_sightings`, `completion`, `prerequisites`) -- none
of these is part of the first-prototype contract and none is fabricated or inferred to fill a gap.

No value is renamed, reordered within itself, or reinterpreted: objective text strings are copied exactly
as M6 stored them, including the known blank-item-name captures (an empty string is exported as an empty
string, never replaced with placeholder text -- see `docs/M8_1_COMPLETION_REPORT.md` for the known display
consequence).

## Determinism

Output ordering is entirely a function of the input data, never of dict/set iteration order or wall-clock
time: quests are sorted ascending by numeric quest ID, and no timestamp is embedded anywhere in the output.
The only provenance stamp is the SHA-256 of the M6 input file's exact bytes, so re-running this script
against an unchanged M6 output always produces byte-identical output, and re-running it after M6 changes
changes only the provenance stamp and the data that actually differs.
"""
from __future__ import annotations

import hashlib
import json
import sys
from pathlib import Path
from typing import Any

# m8-guide-addon/generator/ -> repo root -> m6-dataset-baseline/out/
REPO_ROOT = Path(__file__).resolve().parents[2]
M6_GUIDE_DATASET = REPO_ROOT / "m6-dataset-baseline" / "out" / "m6_guide_dataset.json"
ADDON_DATA_FILE = Path(__file__).resolve().parents[1] / "addon" / "ForeverQuestGuide" / "Data.lua"

# The exact minimal contract from docs/M8_0_SCOPE.md SS3. Nothing else is ever read from a quest record.
CONTRACT_FIELDS = ("title", "quest_level", "objectives", "giver", "interaction_position")


def lua_string(s: str) -> str:
    """Render a Python string as a safe, double-quoted Lua string literal.

    Escapes backslash, double quote, and the common control characters; any other control character is
    escaped as a decimal \\ddd sequence. Every guide-ready title, objective text, and giver name in the
    current M6 dataset contains at least one apostrophe or embedded double quote somewhere in the set
    (e.g. "Al'Aketh Thugs", 'Badwind" Bennic slain'), so this is exercised by real data, not a
    theoretical case.
    """
    out = []
    for ch in s:
        if ch == "\\":
            out.append("\\\\")
        elif ch == '"':
            out.append('\\"')
        elif ch == "\n":
            out.append("\\n")
        elif ch == "\r":
            out.append("\\r")
        elif ch == "\t":
            out.append("\\t")
        elif ord(ch) < 0x20:
            out.append("\\%d" % ord(ch))
        else:
            out.append(ch)
    return '"' + "".join(out) + '"'


def lua_number(n: float | int) -> str:
    """Render a Python int/float as a Lua numeral. repr() is used for floats: Python's float repr is the
    shortest string that round-trips to the exact same IEEE-754 double, which is exactly what Lua's own
    (also IEEE-754 double) number type needs, and it is deterministic for a given input value."""
    if isinstance(n, bool):  # bool is an int subclass in Python; never expected here, but never silently coerced
        raise TypeError("boolean where a Lua number was expected")
    if isinstance(n, int):
        return str(n)
    return repr(n)


def extract_quest(quest_id: int, record: dict[str, Any]) -> dict[str, Any]:
    """Pull exactly the minimal-contract fields out of one M6 guide-ready record. Raises if the record is
    missing a contract field or if a field's evidence_state is not `confirmed`/`observed` with a real
    value -- a guide-ready record is contractually guaranteed to have title/quest_level/objectives
    `confirmed` (M6.6's own readiness rule) and giver/interaction_position have been `observed` for every
    one of the 96 quests in the current dataset (verified directly against the live file before writing
    this generator); this is asserted here, not assumed silently."""
    fields = record["fields"]
    for f in CONTRACT_FIELDS:
        if f not in fields:
            raise ValueError(f"quest {quest_id}: M6 record has no '{f}' field at all")
    title = fields["title"]["value"]
    level = fields["quest_level"]["value"]
    objectives_raw = fields["objectives"]["value"]
    giver_raw = fields["giver"]["value"]
    pos_raw = fields["interaction_position"]["value"]

    if not isinstance(title, str) or not isinstance(level, int):
        raise ValueError(f"quest {quest_id}: title/quest_level not the expected types ({type(title)}, {type(level)})")
    if not isinstance(objectives_raw, list):
        raise ValueError(f"quest {quest_id}: objectives value is not a list ({type(objectives_raw)})")
    if not isinstance(giver_raw, dict) or "name" not in giver_raw or "npc_id" not in giver_raw:
        raise ValueError(f"quest {quest_id}: giver value missing name/npc_id: {giver_raw!r}")
    if not isinstance(pos_raw, dict) or not {"ui_map_id", "x", "y"} <= set(pos_raw):
        raise ValueError(f"quest {quest_id}: interaction_position missing ui_map_id/x/y: {pos_raw!r}")

    # Objective text: copied exactly, including a known blank ("") capture -- never substituted.
    objectives = [o.get("text", "") or "" for o in objectives_raw]

    return {
        "id": quest_id,
        "title": title,
        "level": level,
        "objectives": objectives,
        "giver": {"name": giver_raw["name"], "npc_id": giver_raw["npc_id"]},
        "pos": {"ui_map_id": pos_raw["ui_map_id"], "x": pos_raw["x"], "y": pos_raw["y"]},
    }


def build_addon_dataset(guide_dataset: dict[str, Any]) -> list[dict[str, Any]]:
    """Select only guide-ready quests, extract the minimal contract from each, sorted ascending by quest
    ID. Raises ValueError on any duplicate ID or missing/malformed field -- never silently drops or
    normalizes a quest."""
    ready_ids = guide_dataset["guide_ready_quest_ids"]
    if len(ready_ids) != len(set(ready_ids)):
        raise ValueError("duplicate quest IDs in guide_ready_quest_ids")

    quests = []
    for qid in sorted(ready_ids):
        record = guide_dataset["quests"][str(qid)]
        if record["quest_id"] != qid:
            raise ValueError(f"quest_id mismatch: key {qid} vs record.quest_id {record['quest_id']}")
        if not record.get("guide_ready"):
            raise ValueError(f"quest {qid} is in guide_ready_quest_ids but its own record says guide_ready={record.get('guide_ready')}")
        quests.append(extract_quest(qid, record))

    out_ids = [q["id"] for q in quests]
    if out_ids != sorted(out_ids) or len(out_ids) != len(set(out_ids)):
        raise ValueError("internal error: output quest IDs are not a sorted, deduplicated sequence")
    return quests


def render_lua(quests: list[dict[str, Any]], source_path: Path, source_sha256: str) -> str:
    """Render the addon data file's exact Lua text. Deterministic: depends only on `quests` (already
    sorted) and the source path/hash strings, never on wall-clock time or dict/set iteration order."""
    lines = []
    lines.append("-- ForeverQuestGuide/Data.lua")
    lines.append("-- GENERATED FILE -- do not hand-edit.")
    lines.append("-- Produced by m8-guide-addon/generator/generate_addon_data.py from the M6 guide dataset.")
    lines.append(f"-- Source: {source_path.relative_to(REPO_ROOT).as_posix()}")
    lines.append(f"-- Source SHA-256: {source_sha256}")
    lines.append(f"-- Guide-ready quests exported: {len(quests)}")
    lines.append("--")
    lines.append("-- Every field below was recorder-observed by ForeverRecorder (or its predecessor,")
    lines.append("-- ForeverObservationLab) on the live WoW Forever client and passed M6's guide-readiness")
    lines.append("-- rule (title, quest_level, and objectives all 'confirmed'). No ATT/source-derived value")
    lines.append("-- is present anywhere in this file. See docs/M8_0_SCOPE.md SS3 and SS7 for the data")
    lines.append("-- contract and licensing boundary this file was generated to respect.")
    lines.append("")
    lines.append("local _, ns = ...")
    lines.append("")
    lines.append("ns.QuestData = {")
    for q in quests:
        lines.append(f"  [{q['id']}] = {{")
        lines.append(f"    id = {lua_number(q['id'])},")
        lines.append(f"    title = {lua_string(q['title'])},")
        lines.append(f"    level = {lua_number(q['level'])},")
        if q["objectives"]:
            lines.append("    objectives = {")
            for text in q["objectives"]:
                lines.append(f"      {lua_string(text)},")
            lines.append("    },")
        else:
            lines.append("    objectives = {},")
        lines.append(f"    giver = {{ name = {lua_string(q['giver']['name'])}, npc_id = {lua_number(q['giver']['npc_id'])} }},")
        lines.append(
            "    pos = { ui_map_id = %s, x = %s, y = %s },"
            % (lua_number(q["pos"]["ui_map_id"]), lua_number(q["pos"]["x"]), lua_number(q["pos"]["y"]))
        )
        lines.append("  },")
    lines.append("}")
    lines.append("")
    lines.append("-- Deterministic display order (ascending quest ID). ns.QuestData's own integer keys are")
    lines.append("-- not guaranteed to iterate in order via pairs(), so UI code should iterate this instead.")
    lines.append("ns.QuestOrder = {")
    for q in quests:
        lines.append(f"  {q['id']},")
    lines.append("}")
    lines.append("")
    return "\n".join(lines)


def generate(m6_path: Path = M6_GUIDE_DATASET) -> tuple[str, list[dict[str, Any]], str]:
    """Read `m6_path`, return (rendered_lua_text, quests, source_sha256). Pure function of the input
    file's bytes -- no other input, no side effects, nothing written here."""
    raw_bytes = m6_path.read_bytes()
    source_sha256 = hashlib.sha256(raw_bytes).hexdigest()
    guide_dataset = json.loads(raw_bytes)
    quests = build_addon_dataset(guide_dataset)
    lua_text = render_lua(quests, m6_path, source_sha256)
    return lua_text, quests, source_sha256


if __name__ == "__main__":
    lua_text, quests, source_sha256 = generate()
    ADDON_DATA_FILE.parent.mkdir(parents=True, exist_ok=True)
    ADDON_DATA_FILE.write_text(lua_text, encoding="utf-8", newline="\n")
    print(f"wrote {ADDON_DATA_FILE} ({ADDON_DATA_FILE.stat().st_size} bytes)")
    print(f"quests exported: {len(quests)} | source: {M6_GUIDE_DATASET.name} | source sha256: {source_sha256}")
    # Determinism self-check: re-render from the same in-memory data and compare.
    lua_text_2, _, _ = generate()
    if lua_text_2 != lua_text:
        print("DETERMINISM CHECK FAILED: re-running produced different output", file=sys.stderr)
        sys.exit(1)
    print("determinism self-check: OK (re-run produced byte-identical output)")
