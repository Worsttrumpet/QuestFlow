"""Frozen inputs and frozen copies, pinned by hash so Codex's tests no longer need the legacy M8.13 addon in the tree.

* generator/inputs/observed_m6_data.lua is the observed-quest table copied byte for byte from the M8.13 addon.
* ForeverCodex/MapPin.lua and ForeverCodex/ProgressionEval.lua are COPIES of real-client-validated M8.13 modules ("the logic is untouched").
  They are pinned: a change must be deliberate (update the pin and say why in the commit), exactly what the old copy-fidelity test enforced against the original.
* When the legacy addon IS present, the original hashes are also checked (traceability); when it is not, nothing is skipped silently: the pins above still hold."""
import hashlib
from pathlib import Path

import pytest

FC = Path(__file__).resolve().parent.parent
LEGACY = FC.parent / "m8-13-progression" / "ForeverQuestGuide"


def sha(p: Path) -> str:
    return hashlib.sha256(p.read_bytes()).hexdigest()


OBSERVED_SHA = "636f854cde38fa3811aa6d78640a55d85d42fe8b78692e280e8d2e7a4d2568d3"
FROZEN_COPIES = {
    # Codex copy -> (sha256 of the Codex copy, sha256 of the M8.13 original it was made from)
    "ForeverCodex/MapPin.lua": ("f847c31155e7493e53d1d81dc9e670f0aeb95ab727aacce579d5f831556f2363", "e56dafc487e4fd77e6a36bda42a34947ad4f15b00dbfe60d8724707f2c27bed0", "MapPin.lua"),
    "ForeverCodex/ProgressionEval.lua": ("59ded7ff990506af74889e0e20fcacc1925abda6e53e4ce868e3250aa0a0a46c", "3ec61a27e29a09cdd100b7fc4782a7693c6e18f575f3edd800e2b26b3db7b31c", "ProgressionEval.lua"),
}


def test_observed_input_is_the_frozen_table():
    assert sha(FC / "generator" / "inputs" / "observed_m6_data.lua") == OBSERVED_SHA


@pytest.mark.parametrize("rel", sorted(FROZEN_COPIES))
def test_copied_modules_are_unchanged(rel):
    assert sha(FC / rel) == FROZEN_COPIES[rel][0], rel + " changed: these are copies of validated M8.13 modules; if the change is deliberate update the pin and say why"
    head = (FC / rel).read_text(encoding="utf-8").splitlines()[:3]
    assert head[0].startswith("-- COPIED from m8-13-progression/"), "the COPIED banner must stay"


def test_originals_still_match_when_the_legacy_addon_is_present():
    if not LEGACY.exists():
        pytest.skip("legacy addon not in the tree (no longer required)")
    assert sha(LEGACY / "Data.lua") == OBSERVED_SHA
    for rel, (_, original_sha, name) in FROZEN_COPIES.items():
        assert sha(LEGACY / name) == original_sha, name + ": the frozen original changed"
