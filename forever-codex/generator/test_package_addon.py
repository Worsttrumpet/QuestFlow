import hashlib
import sys
import zipfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import package_addon as P  # noqa: E402


def test_package_is_deterministic_and_complete(tmp_path):
    a = P.build(tmp_path / "a")
    b = P.build(tmp_path / "b")
    assert hashlib.sha256(a.read_bytes()).hexdigest() == hashlib.sha256(b.read_bytes()).hexdigest()
    names = zipfile.ZipFile(a).namelist()
    assert names == sorted(names)
    assert all(n.startswith("ForeverCodex/") for n in names)
    assert "ForeverCodex/ForeverCodex.toc" in names and "ForeverCodex/Core.lua" in names
    toc = zipfile.ZipFile(a).read("ForeverCodex/ForeverCodex.toc").decode()
    for line in toc.splitlines():
        if line.strip() and not line.startswith("#"):
            assert "ForeverCodex/" + line.strip().replace("\\", "/") in names, line
    assert not any(n.endswith((".pyc", ".bak", "~")) for n in names)


def test_version_is_patch_style_and_single_sourced():
    assert P.VERSION_RE.match(P.toc_version()), P.toc_version()
    assert P.code_version() == P.toc_version()
    assert P.version() == P.toc_version()


def test_a_zip_name_is_never_reused_for_different_contents(tmp_path):
    first = P.build(tmp_path)
    assert first.name == f"ForeverCodex-{P.version()}.zip"
    assert P.build(tmp_path) == first                      # the same contents: fine, nothing changes
    first.write_bytes(first.read_bytes() + b"x")           # a stale zip of this version
    try:
        P.build(tmp_path)
    except SystemExit as e:
        assert "bump the version" in str(e)
    else:
        raise AssertionError("an existing zip with different contents must not be overwritten")


def test_older_zips_are_left_alone(tmp_path):
    old = tmp_path / "ForeverCodex-0.0.1.zip"
    old.write_bytes(b"old build")
    P.build(tmp_path)
    assert old.read_bytes() == b"old build"


def test_committed_package_matches_the_addon_folder():
    dist = P.default_out() / f"ForeverCodex-{P.version()}.zip"
    if not dist.exists():
        return
    z = zipfile.ZipFile(dist)
    for p in sorted(P.ADDON.rglob("*")):
        if p.is_file():
            assert z.read("ForeverCodex/" + p.relative_to(P.ADDON).as_posix()) == p.read_bytes(), p.name


def test_default_output_is_a_folder_per_minor_version():
    assert P.default_out().name == ".".join(P.version().split(".")[:2])
    assert P.default_out().parent == P.HERE.parent / "dist"
