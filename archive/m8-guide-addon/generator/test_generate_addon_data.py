import json
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
sys.dont_write_bytecode = True
import pytest
import generate_addon_data as G

M6_PATH = G.M6_GUIDE_DATASET
GUIDE_DATASET = json.loads(M6_PATH.read_bytes())


# ---------------------------------------------------------------- generator tests

def test_correct_input_file_is_used():
    assert G.M6_GUIDE_DATASET.name == "m6_guide_dataset.json"
    assert G.M6_GUIDE_DATASET.parent.name == "out"
    assert G.M6_GUIDE_DATASET.parent.parent.name == "m6-dataset-baseline"
    assert G.M6_GUIDE_DATASET.exists()


def test_only_guide_ready_quests_are_exported():
    _, quests, _ = G.generate()
    exported_ids = {q["id"] for q in quests}
    assert exported_ids == set(GUIDE_DATASET["guide_ready_quest_ids"])
    insufficient_ids = set(GUIDE_DATASET["insufficient_evidence_quest_ids"])
    assert not (exported_ids & insufficient_ids)


def test_required_fields_are_preserved():
    _, quests, _ = G.generate()
    for q in quests:
        assert set(q) == {"id", "title", "level", "objectives", "giver", "pos"}
        assert isinstance(q["id"], int)
        assert isinstance(q["title"], str) and q["title"]
        assert isinstance(q["level"], int)
        assert isinstance(q["objectives"], list)
        assert set(q["giver"]) == {"name", "npc_id"}
        assert set(q["pos"]) == {"ui_map_id", "x", "y"}


def test_att_only_fields_are_not_exported():
    """The generator must never open the M7.4 candidate-pool artifact, and the generated data must never
    carry any of ATT's own field names. Checked functionally (no import, no path reference in actual code)
    rather than by banning the substring everywhere, since the module's own docstring legitimately explains
    -- in prose -- that it does NOT touch that file."""
    src = Path(G.__file__).read_text(encoding="utf-8")
    code_lines = [ln for ln in src.splitlines() if not ln.strip().startswith("#")]
    code_text = "\n".join(code_lines)
    # Strip the leading module docstring (everything from the opening \"\"\" to the closing one) before checking.
    code_text = re.sub(r'^""".*?"""', "", code_text, count=1, flags=re.S)
    assert "proposed_targets" not in code_text
    assert "m7_4" not in code_text
    assert "AllTheThings" not in code_text
    lua_text, _, _ = G.generate()
    for banned in ("att_lvl_unverified", "att_coord", "att.restriction", "candidate_coordinates", "att.flag"):
        assert banned not in lua_text


def test_no_evidence_bookkeeping_leaks_into_output():
    lua_text, _, _ = G.generate()
    for banned in ("evidence_state", "classification", "observation_count", "\"sessions\"", "\"builds\""):
        assert banned not in lua_text


def test_quest_ids_are_sorted_ascending():
    _, quests, _ = G.generate()
    ids = [q["id"] for q in quests]
    assert ids == sorted(ids)
    lua_text, _, _ = G.generate()
    order_block = re.search(r"ns\.QuestOrder = \{(.*?)\n\}", lua_text, re.S).group(1)
    order_ids = [int(x) for x in re.findall(r"\d+", order_block)]
    assert order_ids == ids


@pytest.mark.parametrize("raw,expected", [
    ("Al'Aketh Thugs", '"Al\'Aketh Thugs"'),          # apostrophe: passes through unescaped in a double-quoted string
    ('1/1 "Badwind" Bennic slain', '"1/1 \\"Badwind\\" Bennic slain"'),
    ("back\\slash", '"back\\\\slash"'),
    ("line\nbreak", '"line\\nbreak"'),
    ("", '""'),
])
def test_strings_are_correctly_escaped_for_lua(raw, expected):
    assert G.lua_string(raw) == expected


def test_escaping_handles_every_real_guide_ready_string():
    """Every title, objective text, and giver name in the CURRENT real dataset round-trips through the
    escaper without producing an unterminated or malformed literal (checked via a minimal, real Lua-string
    tokenizer, not just 'it ran')."""
    _, quests, _ = G.generate()
    tok = re.compile(r'^"(?:[^"\\]|\\.)*"$')
    for q in quests:
        for s in (q["title"], q["giver"]["name"], *q["objectives"]):
            literal = G.lua_string(s)
            assert tok.match(literal), f"malformed Lua string literal for {s!r}: {literal!r}"


def test_generator_is_deterministic_across_runs():
    lua1, quests1, sha1 = G.generate()
    lua2, quests2, sha2 = G.generate()
    assert lua1 == lua2
    assert quests1 == quests2
    assert sha1 == sha2


def test_generator_output_file_matches_a_fresh_render():
    """The committed Data.lua (if present) is exactly what generate() produces right now against the
    current M6 file -- i.e. no one hand-edited it after the last generation."""
    lua_text, _, _ = G.generate()
    if G.ADDON_DATA_FILE.exists():
        assert G.ADDON_DATA_FILE.read_text(encoding="utf-8") == lua_text


def test_no_duplicate_quest_ids_generated():
    _, quests, _ = G.generate()
    ids = [q["id"] for q in quests]
    assert len(ids) == len(set(ids))


def test_empty_and_blank_fields_are_handled_safely_not_fabricated():
    """The current dataset's blank-objective-text quests (M6.4/M7.9's documented pattern) must round-trip
    as an exact empty string, never replaced with placeholder text."""
    _, quests, _ = G.generate()
    blank_holders = [q for q in quests if any(t == "" for t in q["objectives"])]
    assert blank_holders, "expected at least one known blank-objective-text quest in the current dataset"
    for q in blank_holders:
        rec = GUIDE_DATASET["quests"][str(q["id"])]["fields"]["objectives"]["value"]
        assert q["objectives"] == [o.get("text", "") or "" for o in rec]


def test_extract_quest_rejects_a_record_with_a_missing_contract_field():
    fake = {"fields": {"title": {"value": "x"}, "quest_level": {"value": 1}, "objectives": {"value": []},
                        "giver": {"value": {"name": "n", "npc_id": 1}}}}  # interaction_position missing
    with pytest.raises(ValueError):
        G.extract_quest(999999, fake)


def test_build_addon_dataset_rejects_duplicate_ids():
    fake_dataset = {"guide_ready_quest_ids": [1, 1], "quests": {"1": {
        "quest_id": 1, "guide_ready": True,
        "fields": {"title": {"value": "x"}, "quest_level": {"value": 1}, "objectives": {"value": []},
                   "giver": {"value": {"name": "n", "npc_id": 1}},
                   "interaction_position": {"value": {"ui_map_id": 1, "x": 0.0, "y": 0.0}}}}}}
    with pytest.raises(ValueError):
        G.build_addon_dataset(fake_dataset)


def test_build_addon_dataset_rejects_a_non_guide_ready_record_listed_as_ready():
    fake_dataset = {"guide_ready_quest_ids": [1], "quests": {"1": {
        "quest_id": 1, "guide_ready": False,
        "fields": {"title": {"value": "x"}, "quest_level": {"value": 1}, "objectives": {"value": []},
                   "giver": {"value": {"name": "n", "npc_id": 1}},
                   "interaction_position": {"value": {"ui_map_id": 1, "x": 0.0, "y": 0.0}}}}}}
    with pytest.raises(ValueError):
        G.build_addon_dataset(fake_dataset)


def test_lua_number_rejects_bool():
    with pytest.raises(TypeError):
        G.lua_number(True)


# ---------------------------------------------------------------- data-contract tests: generated vs M6, field by field

@pytest.fixture(scope="module")
def generated_by_id():
    _, quests, _ = G.generate()
    return {q["id"]: q for q in quests}


@pytest.mark.parametrize("quest_id", GUIDE_DATASET["guide_ready_quest_ids"])
def test_generated_quest_matches_m6_exactly(quest_id, generated_by_id):
    gen = generated_by_id[quest_id]
    m6 = GUIDE_DATASET["quests"][str(quest_id)]["fields"]
    assert gen["id"] == quest_id
    assert gen["title"] == m6["title"]["value"]
    assert gen["level"] == m6["quest_level"]["value"]
    assert gen["objectives"] == [o.get("text", "") or "" for o in m6["objectives"]["value"]]
    assert gen["giver"] == {"name": m6["giver"]["value"]["name"], "npc_id": m6["giver"]["value"]["npc_id"]}
    m6_pos = m6["interaction_position"]["value"]
    assert gen["pos"] == {"ui_map_id": m6_pos["ui_map_id"], "x": m6_pos["x"], "y": m6_pos["y"]}


def test_every_guide_ready_quest_was_generated_and_nothing_extra():
    _, quests, _ = G.generate()
    assert {q["id"] for q in quests} == set(GUIDE_DATASET["guide_ready_quest_ids"])
    assert len(quests) == GUIDE_DATASET["guide_ready_count"]
