import tomllib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SKIP = {"data", ".git", "__pycache__", ".pytest_cache", ".venv"}


def tracked_candidates():
    for p in ROOT.rglob("*"):
        if p.is_file() and not (SKIP & set(p.relative_to(ROOT).parts)):
            yield p


def test_no_blizzard_derived_or_generated_data_in_the_tree():
    bad = [p for p in tracked_candidates() if p.suffix.lower() in {".csv", ".sqlite", ".db", ".lua", ".wdb", ".db2"} or ".sqlite" in p.name]
    assert bad == [], f"data files must live under data/ (gitignored): {bad}"


def test_no_large_files():
    big = [p for p in tracked_candidates() if p.stat().st_size > 1_000_000]
    assert big == []


def test_gitignore_protects_data():
    lines = (ROOT / ".gitignore").read_text().splitlines()
    assert "data/" in lines and "*.sqlite" in lines and "*.csv" in lines


def test_excluded_sources_are_not_configured_or_imported():
    src = tomllib.loads((ROOT / "config" / "sources.toml").read_text())
    urls = " ".join(s["repo"].lower() for s in src["snapshot"])
    for banned in ("foreverguide", "questie", "wowhead", "restedxp"):
        assert banned not in urls
    code = "\n".join(p.read_text() for p in (ROOT / "src").rglob("*.py")).lower()
    for banned in ("wowhead.com", "foreverguide/", "questiedb/"):
        assert banned not in code, banned


def test_nothing_is_redistributable_by_default():
    from foreverdb.provenance import DatasetRecord
    import inspect
    sig = inspect.signature(DatasetRecord)
    assert sig.parameters["redistributable"].default is inspect.Parameter.empty      # must always be stated
    assert "redistributable" in DatasetRecord.__dataclass_fields__
