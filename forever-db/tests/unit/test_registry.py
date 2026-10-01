import json
from pathlib import Path

import pytest

from foreverdb import registry as R

ROOT = Path(__file__).resolve().parents[2]
FEED = """Region!STRING:0|BuildConfig!HEX:16|CDNConfig!HEX:16|KeyRing!HEX:16|BuildId!DEC:4|VersionsName!String:0|ProductConfig!HEX:16
## seqn = 1
us|aaaa|bbbb||69913|1.60.1.69913|cccc
eu|aaaa|bbbb||69913|1.60.1.69913|cccc
"""


def test_real_registry_has_three_unverified_builds():
    reg = R.load_registry(ROOT / "registry" / "builds.toml")
    assert reg.ids() == ["1.60.1.69876", "1.60.1.69893", "1.60.1.69913"]
    assert all(b.verification == "unverified" for b in reg.builds)
    assert all(b.evidence for b in reg.builds)


def test_feed_parsing():
    rows = R.parse_versions_feed(FEED)
    assert [(r.region, r.build_id, r.versions_name) for r in rows] == [("us", 69913, "1.60.1.69913"), ("eu", 69913, "1.60.1.69913")]
    with pytest.raises(ValueError):
        R.parse_versions_feed("")
    with pytest.raises(ValueError):
        R.parse_versions_feed("Region!STRING:0|Nope!DEC:4\nus|1")
    with pytest.raises(ValueError):
        R.parse_versions_feed("Region!STRING:0|BuildId!DEC:4|VersionsName!String:0\nus|1")


def _reg():
    return R.load_registry(ROOT / "registry" / "builds.toml")


def test_unreachable_service_verifies_nothing(tmp_path):
    def boom(url):
        raise OSError("HTTP Error 403")
    res = R.check_version_service(_reg(), fetch=boom)
    assert res.status == "unreachable" and "403" in res.detail and res.current_build is None
    log = tmp_path / "log.jsonl"
    R.append_log(log, res)
    eff = R.effective_registry(_reg(), log)
    assert all(b.verification == "unverified" for b in eff.builds)


def test_successful_check_verifies_only_the_current_build(tmp_path):
    res = R.check_version_service(_reg(), fetch=lambda url: FEED)
    assert res.status == "checked" and res.current_build == "1.60.1.69913" and res.registered is True
    log = tmp_path / "log.jsonl"
    R.append_log(log, res)
    eff = R.effective_registry(_reg(), log)
    assert {b.id: b.verification for b in eff.builds} == {
        "1.60.1.69876": "unverified", "1.60.1.69893": "unverified", "1.60.1.69913": "blizzard_current"}


def test_failed_check_after_success_does_not_undo_or_invent(tmp_path):
    log = tmp_path / "log.jsonl"
    R.append_log(log, R.check_version_service(_reg(), fetch=lambda u: FEED))
    def boom(url):
        raise OSError("down")
    R.append_log(log, R.check_version_service(_reg(), fetch=boom))
    eff = R.effective_registry(_reg(), log)
    assert eff.get("1.60.1.69913").verification == "blizzard_current"


def test_unregistered_current_build_is_reported_not_added(tmp_path):
    feed = FEED.replace("69913", "70000").replace("1.60.1.70000", "1.60.2.70000")
    res = R.check_version_service(_reg(), fetch=lambda u: feed)
    assert res.status == "checked" and res.registered is False
    log = tmp_path / "log.jsonl"
    R.append_log(log, res)
    eff = R.effective_registry(_reg(), log)
    assert all(b.verification == "unverified" for b in eff.builds) and len(eff.builds) == 3


def test_garbage_feed_counts_as_unreachable():
    res = R.check_version_service(_reg(), fetch=lambda u: "<html>nope</html>")
    assert res.status == "unreachable"
    assert json.dumps(res.__dict__)  # log-serialisable
