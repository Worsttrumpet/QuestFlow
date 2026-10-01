"""Tests for the Forever Codex data generator.

Covers: deterministic output, provenance in every output, ATT/observed separation, parser fidelity on the real
sources when they are present locally (auto-skipped otherwise), and that the generator never modifies its inputs
(the frozen ATT files and the M8.13 observed table).

Run:  PYTHONDONTWRITEBYTECODE=1 python3 -m pytest forever-codex/generator -q
"""
import hashlib
import re
import sys
import textwrap
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parent))
import build_codex_data as G  # noqa: E402

HAVE_ATT = (G.DEFAULT_ATT_ROOT / "zones").is_dir()
needs_att = pytest.mark.skipif(not HAVE_ATT, reason="local ATT snapshot not present (gitignored data)")


# ---------------------------------------------------------------- pure helpers

def test_slug_and_labels():
    assert G.slug("The Barrens") == "the-barrens"
    assert G.slug("1 - Stormwind City".split("- ")[-1]) == "stormwind-city"
    assert G.zone_label("1 - stormwind city") == "Stormwind City"
    assert G.zone_label("the barrens") == "The Barrens"
    assert G.zone_label("alterac mountains") == "Alterac Mountains"


def test_lua_value_is_stable_and_escaped():
    assert G.lua_value({"b": 1, "a": "x"}) == '{a = "x", b = 1}'            # sorted keys
    assert G.lua_value([3, 1]) == "{3, 1}"
    assert G.lua_value(0.4486) == "0.4486" and G.lua_value(0.5) == "0.5" and G.lua_value(1.0) == "1"
    assert G.lua_value('say "hi"\\') == '"say \\"hi\\"\\\\"'
    assert G.lua_value(True) == "true" and G.lua_value(False) == "false"


def test_symbols_only_accepts_plain_symbol_lists():
    assert G.symbols({"symbol": "HORDE_ONLY"}) == ["HORDE_ONLY"]
    assert G.symbols([{"symbol": "DWARF"}, {"symbol": "GNOME"}]) == ["DWARF", "GNOME"]
    assert G.symbols({"call": "exclude", "args": []}) is None


OBS_SAMPLE = textwrap.dedent('''\
    local _, ns = ...

    ns.QuestData = {
      [788] = {
        id = 788,
        title = "Cutting Teeth",
        level = 2,
        objectives = {
          "10/10 Mottled Boar slain",
        },
        giver = { name = "Gornek", npc_id = 3143 },
        pos = { ui_map_id = 1411, x = 0.4209417700767517, y = 0.6838774681091309 },
      },
      [815] = {
        id = 815,
        title = "Break a \\"Few\\" Eggs",
        level = 8,
        objectives = {
          "0/3  ",
        },
      },
    }
    ''')


def test_observed_parser(tmp_path):
    f = tmp_path / "Data.lua"
    f.write_text(OBS_SAMPLE, encoding="utf-8")
    obs = G.extract_observed(f)
    assert sorted(obs) == [788, 815]
    assert obs[788]["name"] == "Cutting Teeth" and obs[788]["level"] == 2
    assert obs[788]["giverNpc"] == 3143 and obs[788]["giverName"] == "Gornek"
    assert obs[788]["pos"] == {"map": 1411, "x": 0.4209, "y": 0.6839}
    assert obs[815]["name"] == 'Break a "Few" Eggs' and "giverNpc" not in obs[815] and "pos" not in obs[815]


def test_observed_pack_text_declares_provenance(tmp_path):
    f = tmp_path / "Data.lua"
    f.write_text(OBS_SAMPLE, encoding="utf-8")
    text = G.write_observed_pack(G.extract_observed(f), "x/Data.lua", "ab" * 32)
    assert "src=observed, verified=true" in text
    assert 'src = "observed"' in text and "verified = true" in text and "priority = 100" in text
    assert "att" not in text.split("PROVENANCE:")[1].split("\n")[0].replace("player position", "").lower().replace("attempt", "")  # no ATT claims
    assert "do not hand-edit" in text


def test_att_pack_text_declares_provenance_and_never_verified():
    pin = {"repo": "https://example/att.git", "sha": "0" * 40, "license": "MIT"}
    quests = [{"id": 5, "name": "B", "zone": "z", "map": 1, "x": 0.1, "y": 0.2, "req": 3},
              {"id": 2, "name": "A", "zone": "z", "map": 1, "x": 0.3, "y": 0.4}]
    text = G.write_att_pack(Path("."), "Pack_T", "att:t", "T", quests, [{"key": "z", "label": "Z", "map": 1, "quests": 2, "no_coord": 0}], pin, {"a.lua": "ff"})
    assert "src=att, verified=false" in text
    assert 'src = "att"' in text and "verified = false" in text and "verified = true" not in text
    assert "REQUIRED level" in text and "Nothing here is a confirmed Forever fact" in text and "undecided licensing question" in text
    assert text.index("[2] =") < text.index("[5] =")                       # sorted by id
    assert "sourceRef = " + G.lua_str("0" * 40) in text


# ---------------------------------------------------------------- the real sources

@needs_att
def test_generation_is_deterministic():
    a = G.build(G.DEFAULT_ATT_ROOT, G.DEFAULT_OBSERVED)
    b = G.build(G.DEFAULT_ATT_ROOT, G.DEFAULT_OBSERVED)
    assert a == b
    assert sorted(a) == ["MANIFEST.txt", "Pack_ATT_EasternKingdoms.lua", "Pack_ATT_FlightPaths.lua", "Pack_ATT_Kalimdor.lua",
                         "Pack_ATT_Other.lua", "Pack_Observed.lua"]


@needs_att
def test_committed_data_matches_a_fresh_render():
    fresh = G.build(G.DEFAULT_ATT_ROOT, G.DEFAULT_OBSERVED)
    for name, text in fresh.items():
        on_disk = (G.DEFAULT_OUT / name).read_text(encoding="utf-8")
        assert on_disk == text, f"{name} differs from a fresh render; re-run build_codex_data.py"


@needs_att
def test_output_has_no_timestamps_or_absolute_paths():
    for name, text in G.build(G.DEFAULT_ATT_ROOT, G.DEFAULT_OBSERVED).items():
        assert not re.search(r"\b20\d\d-\d\d-\d\d", text), name
        assert "/home/" not in text and "C:\\" not in text and "/root/" not in text, name


@needs_att
def test_att_extraction_properties():
    att = G.extract_att(G.DEFAULT_ATT_ROOT)
    q = att["quests"]
    assert att["parse_errors"] == 0
    assert 1000 <= len(q) <= 1100
    assert all("name" in r and "zone" in r for r in q.values())
    # ATT lvl is a REQUIRED level: stored as `req`, never as a quest `level`
    assert not any("level" in r for r in q.values())
    assert q[907]["name"] == "Enraged Thunder Lizards" and q[907]["req"] == 10 and q[907]["prereq"] == [882]
    assert q[907]["faction"] == "Horde" and q[907]["giverNpc"] == 3387 and q[907]["giverName"] == "Jorn Skyseer"
    assert (q[907]["map"], q[907]["x"], q[907]["y"]) == (1413, 0.4486, 0.5913)
    for r in q.values():
        if "x" in r:
            assert 0 <= r["x"] <= 1 and 0 <= r["y"] <= 1, r["id"]
        assert not r.get("races") or all(s.isupper() for s in r["races"])
    assert sum(1 for r in q.values() if r.get("faction") == "Alliance") > 100
    assert sum(1 for r in q.values() if r.get("faction") == "Horde") > 100
    assert len(att["flights"]) == 14 and all("map" in f for f in att["flights"].values())
    assert any(z["label"] == "The Barrens" and z["map"] == 1413 for z in att["zones"].values())


@needs_att
def test_observed_extraction_matches_the_m813_table():
    obs = G.extract_observed(G.DEFAULT_OBSERVED)
    assert len(obs) == 96
    assert obs[907]["level"] == 18 and obs[907]["objectives"] == ["0/3 Thunder Lizard Blood"]
    assert all("name" in r for r in obs.values())


@needs_att
def test_layers_are_separate_files_not_merged():
    out = G.build(G.DEFAULT_ATT_ROOT, G.DEFAULT_OBSERVED)
    for name, text in out.items():
        if name.startswith("Pack_ATT"):
            assert 'src = "observed"' not in text, name
        if name == "Pack_Observed.lua":
            assert 'src = "att"' not in text
    obs_ids = set(map(int, re.findall(r"^  \[(\d+)\] = ", out["Pack_Observed.lua"], re.M)))
    att_ids = set()
    for n in ("Pack_ATT_Kalimdor.lua", "Pack_ATT_EasternKingdoms.lua", "Pack_ATT_Other.lua"):
        att_ids |= set(map(int, re.findall(r"^  \[(\d+)\] = \{ id = ", out[n], re.M)))
    assert len(obs_ids & att_ids) == 19            # overlap kept in BOTH layers; merged only at read time
    assert len(att_ids) == 1041 and len(obs_ids) == 96


@needs_att
def test_generator_does_not_modify_its_inputs():
    watched = list((G.DEFAULT_ATT_ROOT / "zones").rglob("*.lua")) + [G.DEFAULT_OBSERVED, G.SOURCES_TOML]
    before = {p: hashlib.sha256(p.read_bytes()).hexdigest() for p in watched}
    G.build(G.DEFAULT_ATT_ROOT, G.DEFAULT_OBSERVED)
    after = {p: hashlib.sha256(p.read_bytes()).hexdigest() for p in watched}
    assert before == after


def test_check_mode_reports_a_mismatch(tmp_path):
    (tmp_path / "Pack_Observed.lua").write_text("stale", encoding="utf-8")
    if HAVE_ATT:
        assert G.main(["--out", str(tmp_path), "--check"]) == 1


def test_manifest_hashes_match_the_files_on_disk():
    manifest = (G.DEFAULT_OUT / "MANIFEST.txt").read_text(encoding="utf-8")
    for h, name in re.findall(r"^([0-9a-f]{64})  (\S+)$", manifest, re.M):
        assert hashlib.sha256((G.DEFAULT_OUT / name).read_bytes()).hexdigest() == h, name
