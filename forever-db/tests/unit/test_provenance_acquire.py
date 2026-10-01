import hashlib
import subprocess
from pathlib import Path

import pytest

from foreverdb import acquire
from foreverdb.provenance import DatasetRecord, sha256_file

from conftest import git, make_repo


def _rec(**kw):
    base = dict(source_kind="git", source_uri="u", source_ref="r" * 40, path_in_source="p", retrieved_at="2026-01-01T00:00:00Z",
                sha256="a" * 64, content_id=None, size_bytes=1, first_hand=True, origin="direct", mirror_of=None,
                license_id="MIT", license_status="verified", redistributable=None, claimed_build_id=None, claim_basis=None)
    base.update(kw)
    return DatasetRecord(**base)


def test_sha256(tmp_path):
    p = tmp_path / "f"
    p.write_bytes(b"abc")
    assert sha256_file(p) == hashlib.sha256(b"abc").hexdigest()


def test_record_validation_and_defaults():
    r = _rec()
    assert r.redistributable is None and r.may_commit() is False and r.build_claim_verified is False
    assert _rec(redistributable=True).may_commit() is True
    with pytest.raises(ValueError):
        _rec(sha256=None, content_id=None)
    with pytest.raises(ValueError):
        _rec(origin="mirror", mirror_of=None)
    with pytest.raises(ValueError):
        _rec(source_kind="scrape")


def test_dataset_id_is_deterministic_and_time_independent():
    a, b = _rec(retrieved_at="2026-01-01T00:00:00Z"), _rec(retrieved_at="2027-05-05T00:00:00Z")
    assert a.dataset_id == b.dataset_id
    assert _rec(sha256="c" * 64).dataset_id != a.dataset_id


def test_wago_fetcher_is_disabled_by_default():
    calls = []
    f = acquire.WagoFetcher(fetch=lambda u: calls.append(u) or b"")
    with pytest.raises(acquire.WagoDisabled):
        f.fetch_table("QuestV2", "1.60.1.69913", Path("/nonexistent"))
    assert calls == []


def test_wago_fetcher_enabled_records_provenance(tmp_path):
    f = acquire.WagoFetcher(enabled=True, fetch=lambda u: b"ID,X\n1,2\n")
    rec = f.fetch_table("QuestV2", "1.60.1.69913", tmp_path)
    assert (tmp_path / "QuestV2.1.60.1.69913.csv").read_bytes() == b"ID,X\n1,2\n"
    assert rec.origin == "direct" and rec.redistributable is None and rec.build_claim_verified is False
    assert rec.sha256 == hashlib.sha256(b"ID,X\n1,2\n").hexdigest() and "QuestV2" in rec.source_uri


@pytest.mark.parametrize("body", [b"", b"<!DOCTYPE html><html>", b"  <html>error"])
def test_wago_fetcher_rejects_non_csv(tmp_path, body):
    with pytest.raises(RuntimeError):
        acquire.WagoFetcher(enabled=True, fetch=lambda u: body).fetch_table("T", "1.0.0.1", tmp_path)


def test_git_snapshot_acquire_is_pinned_and_idempotent(tmp_path):
    src = tmp_path / "src"
    sha = make_repo(src, {"a.txt": "one"})
    (src / "a.txt").write_text("two")
    git(src, "commit", "-aqm", "second")
    dest = tmp_path / "dest"
    acquire.acquire_git_snapshot(str(src), sha, dest)
    assert git(dest, "rev-parse", "HEAD") == sha and (dest / "a.txt").read_text() == "one"
    acquire.acquire_git_snapshot(str(src), sha, dest)  # idempotent
    with pytest.raises(subprocess.CalledProcessError):
        acquire.acquire_git_snapshot(str(src), "0" * 40, tmp_path / "other")


def test_mirrored_csv_build_label_is_only_a_claim(tmp_path):
    root = tmp_path / "snap"
    sha = make_repo(root, {"w/T.1.60.1.69913.csv": "ID\n1\n"})
    info = acquire.SnapshotInfo("k", "https://example.invalid/r.git", sha, root, "MIT", "verified", "unresolved", True)
    rec = acquire.mirrored_csv_record(info, "w/T.1.60.1.69913.csv", "1.60.1.69913")
    assert (rec.origin, rec.mirror_of, rec.first_hand) == ("mirror", "wago.tools", True)
    assert rec.build_claim_verified is False and rec.redistributable is None and rec.license_status == "unresolved"
    snap = acquire.snapshot_record(info)
    assert snap.content_id and snap.sha256 is None
