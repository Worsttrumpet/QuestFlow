"""Provenance guard for the data that ships inside the addon (see docs/CODEX_DATA_SOURCES.md).

ATT-derived packs may ship only while the repository is private and only with their provenance intact. This test does not decide the licensing question; it makes sure nobody changes the data
set, or strips the provenance, by accident."""
import hashlib
import re
from pathlib import Path

ADDON = Path(__file__).resolve().parent.parent / "QuestFlow"
DATA = ADDON / "Data"
EXPECTED = {
    "MANIFEST.txt",
    "Pack_ATT_EasternKingdoms.lua",
    "Pack_ATT_FlightPaths.lua",
    "Pack_ATT_Kalimdor.lua",
    "Pack_ATT_Other.lua",
    "Pack_Observed.lua",
}


def test_only_the_documented_data_files_exist():
    assert {p.name for p in DATA.iterdir()} == EXPECTED, "a data file was added or removed: record it in docs/CODEX_DATA_SOURCES.md and update this test"


def test_att_packs_keep_their_provenance_header():
    for p in DATA.glob("Pack_ATT_*.lua"):
        head = "\n".join(p.read_text(encoding="utf-8").splitlines()[:24])
        assert "src=att, verified=false" in head, p.name
        assert "MIT" in head, p.name
        assert re.search(r"commit [0-9a-f]{40}", head), p.name + ": the ATT commit pin is missing"


def test_observed_pack_is_the_only_verified_one():
    obs = (DATA / "Pack_Observed.lua").read_text(encoding="utf-8")
    assert "src=observed, verified=true" in "\n".join(obs.splitlines()[:12])
    for p in DATA.glob("Pack_ATT_*.lua"):
        assert "verified = true" not in p.read_text(encoding="utf-8").split("local _, ns", 1)[0], p.name


def test_manifest_hashes_match_the_files():
    rows = [ln.split() for ln in (DATA / "MANIFEST.txt").read_text(encoding="utf-8").splitlines() if re.match(r"^[0-9a-f]{64}\s", ln)]
    assert {r[1] for r in rows} == {n for n in EXPECTED if n.startswith("Pack_")}
    for digest, name in rows:
        assert hashlib.sha256((DATA / name).read_bytes()).hexdigest() == digest, name + ": regenerate with generator/build_codex_data.py"


def test_no_questie_or_other_excluded_source_is_vendored():
    # Codex may CALL the QuestieDB addon at runtime; no file of the addon may be a copy of it, and no excluded source may be bundled.
    for p in ADDON.rglob("*"):
        assert "questie" not in p.name.lower() or p.name == "QuestieBridge.lua", p
        assert not p.name.lower().endswith((".csv", ".sqlite", ".db")), p
    toc = (ADDON / "QuestFlow.toc").read_text(encoding="utf-8")
    assert "OptionalDeps: QuestieDB" in toc and "Dependencies: QuestieDB" not in toc.replace("OptionalDeps", ""), "QuestieDB must stay an OPTIONAL dependency"
