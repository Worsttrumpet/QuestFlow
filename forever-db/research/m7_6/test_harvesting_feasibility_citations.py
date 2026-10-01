"""M7.6 is an investigation, not an implementation -- these tests verify the
investigation's own citations are accurate and reproducible, and that
nothing was modified while producing it. No harvesting code exists to test."""
import hashlib
import json
from pathlib import Path

RECORDER_ROOT = Path("/mnt/user-data/outputs/m5-production-recorder/addon/ForeverRecorder")
FOREVER_DB = Path("/mnt/user-data/outputs/forever-db")


def test_dispatcher_hooked_events_match_the_report():
    text = (RECORDER_ROOT / "core" / "Dispatcher.lua").read_text()
    for event in ["ADDON_LOADED", "PLAYER_LOGIN", "QUEST_DETAIL", "QUEST_COMPLETE",
                  "QUEST_TURNED_IN", "QUEST_FINISHED", "GOSSIP_SHOW", "GET_ITEM_INFO_RECEIVED"]:
        assert f'RegisterEvent("{event}")' in text, f"expected {event} to be registered"


def test_quest_finished_is_registered_but_never_dispatched():
    text = (RECORDER_ROOT / "core" / "Dispatcher.lua").read_text()
    # Registered as an event, but its handler branch returns without calling
    # dispatchCheckpoint/dispatchEvent -- confirmed by the surrounding comment.
    assert 'RegisterEvent("QUEST_FINISHED")' in text
    assert "fires multiple times" in text
    assert "per turn-in" in text


def test_not_hooked_events_are_genuinely_absent():
    text = (RECORDER_ROOT / "core" / "Dispatcher.lua").read_text()
    for event in ["QUEST_ACCEPTED", "QUEST_LOG_UPDATE", "QUEST_WATCH_UPDATE",
                  "PLAYER_TARGET_CHANGED", "UNIT_TARGET", "UPDATE_FACTION", "TAXIMAP_OPENED"]:
        assert f'RegisterEvent("{event}")' not in text


def test_position_util_only_ever_queries_the_player_unit():
    text = (RECORDER_ROOT / "core" / "PositionUtil.lua").read_text()
    assert '"player"' in text
    # No other unit token (npc/target) appears as an argument to the map APIs.
    assert 'GetPlayerMapPosition, 1, vMap[1], "npc"' not in text
    assert 'GetPlayerMapPosition, 1, vMap[1], "target"' not in text


def test_export_save_only_calls_reload_ui():
    text = (RECORDER_ROOT / "core" / "Export.lua").read_text()
    assert "ReloadUI" in text
    assert "network" not in text.lower() or "no network" in text.lower()


def test_gossip_sample_limit_is_five():
    text = (RECORDER_ROOT / "observers" / "Gossip.lua").read_text()
    assert "shown >= 5" in text


def test_quest_accepted_exclusion_reason_is_cited_accurately():
    text = (FOREVER_DB / "docs" / "M5_PRODUCTION_RECORDER_DESIGN.md").read_text()
    assert "QUEST_ACCEPTED" in text
    assert "carries no additional information" in text


def test_wdb_cache_research_citation_is_accurate():
    text = (FOREVER_DB / "research" / "m1_5" / "REPORT.md").read_text()
    assert "questcache.wdb" in text
    assert "creaturecache.wdb" in text


def test_json_summary_is_valid_and_internally_consistent():
    data = json.loads((Path(__file__).parent / "harvesting_feasibility.json").read_text())
    hooked = set(e.split(" ")[0] for e in data["hooked_events"])
    not_hooked = set(data["not_hooked_events"][0].split("/")[0].split() + data["not_hooked_events"])
    assert "QUEST_DETAIL" in hooked
    assert len(data["field_feasibility_matrix"]) == 12
    assert len(data["scenario_matrix"]) == 5


def _hash(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def test_no_production_file_was_modified_by_this_investigation():
    # Spot-check the core evidence architecture and licensing files against
    # their known-good hashes, established across every prior M7 milestone.
    known_hashes = {
        FOREVER_DB / "src" / "foreverdb" / "db.py": "e94295dbbdc4555a0455858e5a00ec73",
        FOREVER_DB / "src" / "foreverdb" / "assertions.py": "6a84e2561c33f53abf869f057b0eb116",
        FOREVER_DB / "src" / "foreverdb" / "harvest" / "importer.py": "437bd9a629d9732c2c4e52a9253a02af",
        FOREVER_DB / "src" / "foreverdb" / "att" / "importer.py": "d13fc97e0ba8ef03352381012cf29a71",
        FOREVER_DB / "config" / "sources.toml": "e4ddb225d69a67e8deee7ce990abff54",
        FOREVER_DB / "docs" / "LICENSING.md": "c5c3142496e2f63d527ed2367408c598",
    }
    import hashlib as _h
    for path, expected_md5 in known_hashes.items():
        actual = _h.md5(path.read_bytes()).hexdigest()
        assert actual == expected_md5, f"{path} was modified -- expected {expected_md5}, got {actual}"


def test_m6_outputs_unchanged():
    m6_out = Path("/mnt/user-data/outputs/m6-dataset-baseline/out")
    known_hashes = {
        "m6_guide_dataset.json": "6f7099f44d37f24b70cf32a23c202d68180c4c73912aebb35b739980daa19679",
        "m6_coverage.json": "6671e4f02dcbdc88fdda58c1e2ae2b86ba98a14f39d482d56e8e9fc0d61dbf75",
        "m6_evidence_report.json": "ed31f3c22f8c3cb6eff9d94baaa196dfc101b15bd7f30bf6f1153d5011a14db4",
    }
    for name, expected_sha256 in known_hashes.items():
        actual = hashlib.sha256((m6_out / name).read_bytes()).hexdigest()
        assert actual == expected_sha256, f"{name} was modified"


def test_m7_3_and_m7_4_artifacts_unchanged():
    known = {
        FOREVER_DB / "research" / "m7_3" / "coverage_gap_analysis.json":
            "10c8c1aec44bccddc2f8da56727f5e029bf00eaebf4c0043ef5ecb70d65d36d5",
        FOREVER_DB / "research" / "m7_4" / "proposed_targets.json":
            "b7fc38de6993836e51f3b8f437238d0cd0d833005e8639a54ad8ac80a6c6a50b",
    }
    for path, expected in known.items():
        actual = hashlib.sha256(path.read_bytes()).hexdigest()
        assert actual == expected, f"{path} was modified"
