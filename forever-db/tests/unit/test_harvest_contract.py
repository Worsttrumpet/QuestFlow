import copy
import json
import re
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[2]
SCHEMA = json.loads((ROOT / "schemas" / "harvest_observation.v0.schema.json").read_text())
EXAMPLE = json.loads((ROOT / "docs" / "examples_harvest_v0.json").read_text())


def validate(inst, sch, root=SCHEMA):
    """Minimal validator for the subset of JSON Schema this contract uses. Returns a list of errors."""
    errs = []
    if "$ref" in sch:
        node = root
        for part in sch["$ref"][2:].split("/"):
            node = node[part]
        return validate(inst, node, root)
    t = sch.get("type")
    py = {"object": dict, "array": list, "string": str, "integer": int, "number": (int, float)}
    if t and not (isinstance(inst, py[t]) and not (t in ("integer", "number") and isinstance(inst, bool))):
        return [f"expected {t}"]
    if "const" in sch and inst != sch["const"]:
        errs.append("const")
    if "enum" in sch and inst not in sch["enum"]:
        errs.append(f"enum {inst!r}")
    if "pattern" in sch and isinstance(inst, str) and not re.search(sch["pattern"], inst):
        errs.append("pattern")
    if isinstance(inst, dict):
        errs += [f"missing {k}" for k in sch.get("required", []) if k not in inst]
        if sch.get("additionalProperties") is False:
            errs += [f"extra {k}" for k in inst if k not in sch.get("properties", {})]
        for k, sub in sch.get("properties", {}).items():
            if k in inst:
                errs += validate(inst[k], sub, root)
    if isinstance(inst, list) and "items" in sch:
        for it in inst:
            errs += validate(it, sch["items"], root)
    for cond in sch.get("allOf", []):
        if not validate(inst, cond["if"], root):
            errs += validate(inst, cond["then"], root)
    return errs


def test_example_validates():
    assert validate(EXAMPLE, SCHEMA) == []


def test_example_is_obviously_synthetic():
    text = json.dumps(EXAMPLE)
    assert "EXAMPLE" in text and "9999990" in text


@pytest.mark.parametrize("mutate", [
    lambda d: d.pop("client"),
    lambda d: d["client"].update(game_build="latest"),
    lambda d: d["client"].update(build_source="guess"),
    lambda d: d["observations"][0].update(kind="mystery"),
    lambda d: d["observations"][0]["data"].pop("quest_id"),
    lambda d: d["observations"][1]["data"].pop("position"),
    lambda d: d["observations"][2]["data"].pop("payload_sha256"),
    lambda d: d.update(character_name="Someone"),
])
def test_invalid_exports_are_rejected(mutate):
    bad = copy.deepcopy(EXAMPLE)
    mutate(bad)
    assert validate(bad, SCHEMA) != []


def test_kinds_in_schema_match_documented_kinds():
    kinds = set(SCHEMA["$defs"]["observation"]["properties"]["kind"]["enum"])
    doc = (ROOT / "docs" / "HARVEST_CONTRACT.md").read_text()
    for k in kinds:
        assert k in doc, f"{k} undocumented"
