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


def test_release_zip_holds_only_what_a_player_needs(tmp_path):
    names = zipfile.ZipFile(P.build(tmp_path)).namelist()
    assert "ForeverCodex/LICENSE" in names and "ForeverCodex/THIRD_PARTY_NOTICES.md" in names
    bad = [n for n in names if not (n.endswith(tuple(P.ALLOWED_SUFFIXES)) or n.rsplit("/", 1)[-1] in P.ALLOWED_NAMES)]
    assert bad == []
    assert not any(part in ("tests", "docs", "generator", "dist", "__pycache__") or part.startswith(".") for n in names for part in n.split("/"))


def test_a_stray_file_stops_the_build(tmp_path):
    stray = P.ADDON / "screenshot.png"
    stray.write_bytes(b"x")
    try:
        try:
            P.build(tmp_path)
        except SystemExit as e:
            assert "screenshot.png" in str(e)
        else:
            raise AssertionError("an unexpected file type must stop the build")
    finally:
        stray.unlink()


def test_hidden_files_and_caches_are_left_out(tmp_path):
    junk = P.ADDON / ".DS_Store"
    junk.write_bytes(b"x")
    try:
        assert "ForeverCodex/.DS_Store" not in zipfile.ZipFile(P.build(tmp_path)).namelist()
    finally:
        junk.unlink()


def test_every_lua_file_is_loaded_and_every_texture_is_used():
    """No dead files ship: each .lua is listed in the .toc (the game loads nothing else) and each texture is named by some Lua file."""
    toc = (P.ADDON / "ForeverCodex.toc").read_text(encoding="utf-8")
    listed = {l.strip().replace("\\", "/") for l in toc.splitlines() if l.strip() and not l.startswith("#")}
    luas = {p.relative_to(P.ADDON).as_posix() for p in P.addon_files() if p.suffix == ".lua"}
    assert luas == listed, (sorted(luas - listed), sorted(listed - luas))
    code = "\n".join(p.read_text(encoding="utf-8") for p in P.addon_files() if p.suffix == ".lua" and not p.name.startswith("Pack_"))
    for tga in sorted(p.name for p in P.addon_files() if p.suffix == ".tga"):
        assert tga in code, f"{tga} is shipped but nothing uses it"


def test_licence_files_match_the_repository_root():
    root = P.ADDON.parent.parent
    for name in ("LICENSE", "THIRD_PARTY_NOTICES.md"):
        assert (P.ADDON / name).read_bytes() == (root / name).read_bytes(), f"{name}: the addon's copy must equal the repository root's"


def test_public_metadata_is_present():
    toc = (P.ADDON / "ForeverCodex.toc").read_text(encoding="utf-8")
    for key in ("## Interface:", "## Title: Forever Codex", "## Notes:", "## Author:", "## Version:", "## SavedVariables: ForeverCodexDB", "## X-License: MIT"):
        assert key in toc, key
    assert "development build" not in toc.lower() and "dev build" not in toc.lower()


def test_committed_package_matches_the_addon_folder():
    dist = P.default_out() / f"ForeverCodex-{P.version()}.zip"
    if not dist.exists():
        return
    z = zipfile.ZipFile(dist)
    for p in P.addon_files():
        assert z.read("ForeverCodex/" + p.relative_to(P.ADDON).as_posix()) == p.read_bytes(), p.name


def test_default_output_is_a_folder_per_minor_version():
    assert P.default_out().name == ".".join(P.version().split(".")[:2])
    assert P.default_out().parent == P.HERE.parent / "dist"
