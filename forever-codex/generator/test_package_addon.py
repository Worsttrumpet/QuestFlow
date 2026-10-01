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


def test_committed_package_matches_the_addon_folder():
    dist = P.HERE.parent / "dist" / f"ForeverCodex-{P.version()}.zip"
    if not dist.exists():
        return
    z = zipfile.ZipFile(dist)
    for p in sorted(P.ADDON.rglob("*")):
        if p.is_file():
            assert z.read("ForeverCodex/" + p.relative_to(P.ADDON).as_posix()) == p.read_bytes(), p.name
