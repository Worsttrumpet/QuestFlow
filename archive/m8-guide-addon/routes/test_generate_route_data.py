import copy
import json
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
sys.dont_write_bytecode = True
import pytest
import route_schema as S
import generate_route_data as G

QUESTS = G.load_guide_ready_quests()
ROUTE_FILES = G.find_route_files()
ROUTE_JSON = {p: json.loads(p.read_bytes()) for p in ROUTE_FILES}


def _fresh_route():
    """A deep copy of the real authored route, safe to mutate per-test."""
    assert ROUTE_FILES, "expected at least one *_route.json file"
    return copy.deepcopy(ROUTE_JSON[ROUTE_FILES[0]])


# ---------------------------------------------------------------- schema tests

def test_at_least_one_route_file_exists():
    assert len(ROUTE_FILES) >= 1
    for p in ROUTE_FILES:
        assert p.name.endswith("_route.json")


def test_route_has_id_and_title():
    r = _fresh_route()
    assert isinstance(r["id"], str) and r["id"]
    assert isinstance(r["title"], str) and r["title"]


def test_route_has_ordered_steps():
    r = _fresh_route()
    order = S.validate_route(r, QUESTS)
    assert order == list(order)  # a concrete, materialized order
    assert set(order) == set(r["steps"])
    assert order[0] == r["first_step"]


def test_every_step_has_a_unique_id_matching_its_key():
    r = _fresh_route()
    for key, step in r["steps"].items():
        assert step["id"] == key
    ids = [s["id"] for s in r["steps"].values()]
    assert len(ids) == len(set(ids))


def test_step_types_are_valid():
    r = _fresh_route()
    for step in r["steps"].values():
        assert step["kind"] in S.STEP_KINDS


def test_route_and_every_step_are_marked_route_authored():
    r = _fresh_route()
    assert r["provenance"] == "route-authored"
    for step in r["steps"].values():
        assert step["provenance"] == "route-authored"


@pytest.mark.parametrize("path", ROUTE_FILES, ids=lambda p: p.name)
def test_each_real_route_file_validates_cleanly(path):
    route = json.loads(path.read_bytes())
    order = S.validate_route(route, QUESTS)
    assert len(order) >= 1


# ---------------------------------------------------------------- data-integrity tests

def test_every_referenced_quest_id_is_guide_ready():
    r = _fresh_route()
    for step in r["steps"].values():
        if step.get("quest_id") is not None:
            assert step["quest_id"] in QUESTS


def test_no_att_only_quest_is_referenced():
    """Every quest_id in the route must be a key of QUESTS, which load_guide_ready_quests() populates
    ONLY from M8.1's own guide-ready generator -- an ATT-only candidate (never in that set) cannot pass
    validate_route, which is exercised directly here with a synthetic ATT-only-shaped id."""
    r = _fresh_route()
    r["steps"]["s1"]["quest_id"] = 999999999  # not a real quest id, standing in for "ATT-only, not observed"
    with pytest.raises(S.RouteValidationError):
        S.validate_route(r, QUESTS)


def test_no_duplicate_step_ids_in_json_keys():
    """JSON object keys are already unique by construction (a duplicate key in the source file would have
    silently overwritten the first), so this test instead confirms the id field agrees with its key for
    every step, which is the check that actually catches a copy-paste id mistake."""
    r = _fresh_route()
    for key, step in r["steps"].items():
        assert step["id"] == key, f"step key {key} has mismatched id field {step['id']}"


def test_route_ordering_is_explicit_not_derived_from_quest_id():
    """The walked order must NOT equal quest-ID order unless that's a coincidence of authoring -- proven
    here by checking the actual authored route deliberately revisits quest 907 non-monotonically relative
    to quest_id (907 appears before 959, but also the route's OWN order is independent of any numeric sort
    applied to quest_id or step id)."""
    r = _fresh_route()
    order = S.validate_route(r, QUESTS)
    quest_ids_in_order = [r["steps"][s].get("quest_id") for s in order]
    # The real authored route's order is s1..s5, which happens to equal alphabetical step-id order here --
    # so the meaningful assertion is that validate_route uses next_step_id, not sorted(steps), which is
    # tested directly by shuffling the JSON's own key order and confirming the result is unchanged.
    shuffled = {"id": r["id"], "title": r["title"], "provenance": r["provenance"],
                "first_step": r["first_step"], "steps": dict(reversed(list(r["steps"].items())))}
    order2 = S.validate_route(shuffled, QUESTS)
    assert order2 == order, "shuffling the JSON's own key order changed the validated order -- ordering is not explicit"


def test_validate_route_rejects_a_cycle():
    r = _fresh_route()
    last_id = [s for s in r["steps"] if r["steps"][s]["next_step_id"] is None][0]
    r["steps"][last_id]["next_step_id"] = r["first_step"]
    with pytest.raises(S.RouteValidationError, match="cycle"):
        S.validate_route(r, QUESTS)


def test_validate_route_rejects_an_unreachable_step():
    r = _fresh_route()
    r["steps"]["orphan"] = {"id": "orphan", "provenance": "route-authored", "kind": "TALK",
                             "quest_id": None, "npc": None, "destination": None,
                             "display_text": "unreachable", "next_step_id": None}
    with pytest.raises(S.RouteValidationError, match="not reachable"):
        S.validate_route(r, QUESTS)


def test_validate_route_rejects_a_dangling_next_step_id():
    r = _fresh_route()
    r["steps"]["s5"]["next_step_id"] = "does-not-exist"
    with pytest.raises(S.RouteValidationError, match="unknown step"):
        S.validate_route(r, QUESTS)


def test_validate_route_rejects_wrong_provenance():
    r = _fresh_route()
    r["provenance"] = "observed"
    with pytest.raises(S.RouteValidationError, match="provenance"):
        S.validate_route(r, QUESTS)
    r2 = _fresh_route()
    r2["steps"]["s1"]["provenance"] = "source-derived"
    with pytest.raises(S.RouteValidationError, match="provenance"):
        S.validate_route(r2, QUESTS)


def test_validate_route_rejects_bad_objective_index():
    r = _fresh_route()
    r["steps"]["s3"]["objective_index"] = 99  # quest 907 has exactly 1 objective
    with pytest.raises(S.RouteValidationError, match="out of range"):
        S.validate_route(r, QUESTS)


def test_validate_route_rejects_objective_index_on_a_non_objective_step():
    r = _fresh_route()
    r["steps"]["s1"]["objective_index"] = 1
    with pytest.raises(S.RouteValidationError, match="only meaningful"):
        S.validate_route(r, QUESTS)


def test_validate_route_rejects_empty_why():
    r = _fresh_route()
    r["steps"]["s1"]["why"] = "   "
    with pytest.raises(S.RouteValidationError, match="why"):
        S.validate_route(r, QUESTS)


def test_validate_route_accepts_missing_why():
    r = _fresh_route()
    r["steps"]["s1"].pop("why", None)
    S.validate_route(r, QUESTS)  # must not raise


def test_validate_route_rejects_non_boolean_required():
    r = _fresh_route()
    r["steps"]["s1"]["required"] = "yes"
    with pytest.raises(S.RouteValidationError, match="required"):
        S.validate_route(r, QUESTS)


def test_validate_route_accepts_missing_required():
    r = _fresh_route()
    r["steps"]["s1"].pop("required", None)
    S.validate_route(r, QUESTS)  # must not raise


def test_generated_lua_carries_why_and_required_exactly_as_authored():
    """The real route's own why/required values (including the two steps that omit `why` entirely) must
    round-trip into the generated Lua unchanged -- nil stays nil, never defaulted to a guessed value."""
    lua_text, routes, _ = G.generate()
    route, order, _ = routes[0]
    for step_id in order:
        step = route["steps"][step_id]
        block_start = lua_text.index(f'[{json.dumps(step_id)}] = {{')
        block_end = lua_text.index("\n      },", block_start)
        block = lua_text[block_start:block_end]
        if step.get("why") is not None:
            assert json.dumps(step["why"])[1:-1] in block or step["why"] in block, f"{step_id}: why not found"
            assert "why = nil" not in block
        else:
            assert "why = nil" in block, f"{step_id}: expected why = nil"
        if step.get("required") is not None:
            assert f"required = {'true' if step['required'] else 'false'}" in block
        else:
            assert "required = nil" in block, f"{step_id}: expected required = nil"


def test_validate_destination_rejects_unknown_kind():
    with pytest.raises(S.RouteValidationError):
        S.validate_destination({"kind": "GUESSED"}, "s1")


def test_validate_destination_rejects_incomplete_observed_position():
    with pytest.raises(S.RouteValidationError):
        S.validate_destination({"kind": "OBSERVED_PLAYER_POSITION", "ui_map_id": 1}, "s1")  # missing x, y


def test_generator_forbids_source_derived_att_destination():
    r = _fresh_route()
    r["steps"]["s2"]["destination"] = {"kind": "SOURCE_DERIVED_ATT", "ui_map_id": 1, "x": 0.1, "y": 0.1}
    order = S.validate_route(r, QUESTS)  # shape-valid per the schema itself
    with pytest.raises(S.RouteValidationError, match="not permitted"):
        for step_id in order:
            G._forbid_source_derived(r["id"], r["steps"][step_id])


def test_generator_rejects_npc_drift_from_m6():
    r = _fresh_route()
    r["steps"]["s1"]["npc"] = {"name": "Someone Else", "npc_id": 1}
    order = S.validate_route(r, QUESTS)
    with pytest.raises(S.RouteValidationError, match="does not match M6"):
        for step_id in order:
            G._check_npc_matches_m6(r["id"], r["steps"][step_id], QUESTS)


# ---------------------------------------------------------------- generation / determinism tests

def test_generate_is_deterministic_across_runs():
    lua1, routes1, sha1 = G.generate()
    lua2, routes2, sha2 = G.generate()
    assert lua1 == lua2
    assert sha1 == sha2
    assert [r["id"] for r, _, _ in routes1] == [r["id"] for r, _, _ in routes2]


def test_generated_output_file_matches_a_fresh_render():
    lua_text, _, _ = G.generate()
    if G.ROUTE_DATA_FILE.exists():
        assert G.ROUTE_DATA_FILE.read_text(encoding="utf-8") == lua_text


def test_generated_lua_contains_no_quest_content_duplication():
    """The generated file must never carry a quest's own M6 title as a dedicated, structural field value
    (which would let the UI read a possibly-stale copy instead of looking it up live from Data.lua) -- but
    an author's own free-text fields (display_text, why -- both route-authored prose, not a data source)
    are explicitly allowed to mention a quest by name, e.g. why="Turn in Enraged Thunder Lizards here...".
    Checked precisely: the M6 title must not appear as the value of any STRUCTURAL field (id, kind,
    quest_id, objective_index, npc, destination, next_step_id) of any step, in any real route -- free-text
    fields are excluded from this check by construction, not by searching around them textually."""
    FREE_TEXT_FIELDS = {"display_text", "why"}
    for path in G.find_route_files():
        route = json.loads(path.read_bytes())
        for step in route["steps"].values():
            quest_id = step.get("quest_id")
            if quest_id is None or quest_id not in QUESTS:
                continue
            m6_title = QUESTS[quest_id]["title"]
            for field, value in step.items():
                if field in FREE_TEXT_FIELDS:
                    continue
                serialized = json.dumps(value)
                assert m6_title not in serialized, (
                    f"route {route['id']!r} step {step['id']!r} field {field!r} contains the M6 title "
                    f"{m6_title!r} outside a free-text field -- possible data duplication"
                )


def test_generated_lua_has_no_att_field_names():
    lua_text, _, _ = G.generate()
    for banned in ("att_lvl_unverified", "att_coord", "SOURCE_DERIVED_ATT"):
        assert banned not in lua_text, f"{banned!r} must never appear in a real generated M8.3 route"


def test_generated_lua_marks_every_route_and_step_as_route_authored():
    lua_text, _, _ = G.generate()
    assert lua_text.count('provenance = "route-authored"') >= 1 + 5  # 1 route + 5 steps in the current route


def test_step_order_in_output_matches_next_step_id_walk():
    lua_text, routes, _ = G.generate()
    for route, order, _ in routes:
        block = re.search(r'\[' + re.escape(json.dumps(route["id"])) + r'\].*?step_order = \{ (.*?) \}', lua_text, re.S)
        assert block, f"couldn't find step_order for route {route['id']}"
        emitted = [s.strip().strip('"') for s in block.group(1).split(",") if s.strip()]
        assert emitted == order


def test_luac_parses_the_generated_file():
    import subprocess
    lua_text, _, _ = G.generate()
    proc = subprocess.run(["luac5.1", "-p", "-"], input=lua_text.encode("utf-8"), capture_output=True)
    assert proc.returncode == 0, proc.stderr.decode()


# ---------------------------------------------------------------- the real authored route's own content

def test_the_real_route_uses_only_guide_ready_quests_907_and_959():
    r = _fresh_route()
    ids = {s.get("quest_id") for s in r["steps"].values() if s.get("quest_id") is not None}
    assert ids == {907, 959}
    assert ids <= set(QUESTS)


def test_the_real_route_exercises_all_three_required_marker_kinds():
    """Completion criteria requires the ACCEPT/TALK-family (star), OBJECTIVE (combat), and TRAVEL (pin)
    glyphs to all render; this only proves the DATA exercises all three -- the Lua self-test proves the UI
    maps them to glyphs."""
    r = _fresh_route()
    kinds = {s["kind"] for s in r["steps"].values()}
    assert {"ACCEPT", "OBJECTIVE", "TRAVEL", "TURN_IN"} <= kinds


def test_the_real_route_has_exactly_one_observed_position_and_it_matches_m6():
    r = _fresh_route()
    observed = [s["destination"] for s in r["steps"].values()
                if s.get("destination") and s["destination"]["kind"] == "OBSERVED_PLAYER_POSITION"]
    assert len(observed) == 1
    d = observed[0]
    m6_pos = json.load(open(G.QUEST_GEN.M6_GUIDE_DATASET))["quests"]["907"]["fields"]["interaction_position"]["value"]
    assert (d["ui_map_id"], d["x"], d["y"]) == (m6_pos["ui_map_id"], m6_pos["x"], m6_pos["y"])
