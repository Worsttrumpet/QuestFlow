from pathlib import Path

from conftest import write_csv
from foreverdb import manifest as M

SPECS = [M.TableSpec("A", "a", 1), M.TableSpec("B", "b", 1), M.TableSpec("C", "c", 2)]


def _src(d: Path, label="s1", build="1.0.0.1", origin="mirror"):
    return M.SourceSet(label, "git", "u", "r" * 40, d, "w", build, "filename label", origin, "wago.tools" if origin == "mirror" else None)


def test_probe_counts_rows_and_columns_with_bom(tmp_path):
    p = write_csv(tmp_path / "A.1.0.0.1.csv", ["ID", "Name"], [[1, "x"], [2, "y"]], bom=True)
    pr = M.probe_csv(p)
    assert (pr.table, pr.row_count, pr.columns) == ("A", 2, ("ID", "Name")) and len(pr.sha256) == 64


def test_manifest_read_missing_extra_and_locale_exclusion(tmp_path):
    write_csv(tmp_path / "A.1.0.0.1.csv", ["ID"], [[1]])
    write_csv(tmp_path / "B.1.0.0.1.csv", ["ID"], [[1], [2], [3]])
    write_csv(tmp_path / "A.deDE.1.0.0.1.csv", ["ID"], [[9]])
    write_csv(tmp_path / "D.1.0.0.1.csv", ["ID"], [[1]])
    write_csv(tmp_path / "A.9.9.9.9.csv", ["ID"], [[1]])          # other build: ignored
    m = M.build_manifest(SPECS, _src(tmp_path))
    by = {t["table"]: t for t in m["tables"]}
    assert by["A"]["status"] == "read" and by["A"]["row_count"] == 1
    assert by["B"]["row_count"] == 3
    assert by["C"]["status"] == "not_probed" and by["C"]["exists"] is None      # unknown, NOT false
    assert [t["table"] for t in m["extra_tables_present"]] == ["D"]
    s = m["source"]
    assert s["read_first_hand"] is True and s["build_claim_verified"] is False and s["origin"] == "mirror"


def test_diff_flags_identical_content_across_mirrored_labels(tmp_path):
    a, b = tmp_path / "a", tmp_path / "b"
    for d, build in ((a, "1.0.0.1"), (b, "1.0.0.2")):
        write_csv(d / f"A.{build}.csv", ["ID"], [[1]])
        write_csv(d / f"B.{build}.csv", ["ID"], [[1]] if d is a else [[1], [2]])
    write_csv(b / "C.1.0.0.2.csv", ["ID", "New"], [[1, 1]])
    ma = M.build_manifest(SPECS, _src(a, "a", "1.0.0.1"))
    mb = M.build_manifest(SPECS, _src(b, "b", "1.0.0.2"))
    d = M.diff_manifests(ma, mb)
    assert d["identical_content"] == ["A"]
    assert d["changed"][0]["table"] == "B" and d["changed"][0]["row_count"] == [1, 2]
    assert d["added"] == ["C"] and d["removed"] == []
    assert d["warnings"] and "byte-identical" in d["warnings"][0]


def test_diff_no_warning_for_direct_sources(tmp_path):
    a, b = tmp_path / "a", tmp_path / "b"
    write_csv(a / "A.1.0.0.1.csv", ["ID"], [[1]])
    write_csv(b / "A.1.0.0.2.csv", ["ID"], [[1]])
    d = M.diff_manifests(M.build_manifest(SPECS, _src(a, "a", "1.0.0.1", "direct")), M.build_manifest(SPECS, _src(b, "b", "1.0.0.2", "direct")))
    assert d["identical_content"] == ["A"] and d["warnings"] == []


def test_column_changes_are_reported(tmp_path):
    a, b = tmp_path / "a", tmp_path / "b"
    write_csv(a / "A.1.0.0.1.csv", ["ID", "Old"], [[1, 1]])
    write_csv(b / "A.1.0.0.2.csv", ["ID", "New"], [[1, 1]])
    d = M.diff_manifests(M.build_manifest(SPECS, _src(a, "a", "1.0.0.1")), M.build_manifest(SPECS, _src(b, "b", "1.0.0.2")))
    ch = d["changed"][0]
    assert ch["columns_added"] == ["New"] and ch["columns_removed"] == ["Old"]


def test_table_config_loads():
    specs = M.load_table_specs(Path(__file__).resolve().parents[2] / "config" / "tables.toml")
    names = {s.name for s in specs}
    assert {"QuestV2", "UiMapAssignment", "TaxiNodes", "QuestObjective"} <= names
