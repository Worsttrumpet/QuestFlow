"""M8.3: route schema and validator.

Implements the Route/RouteStep/Destination shapes recommended by `docs/M8_2_SCOPE.md` SS2-4 and SS12. A
route is hand-authored data (a JSON file under `m8-guide-addon/routes/`), never generated or inferred from
M6 or ATT. This module only validates a route dict against the rules M8.2 established; it does not author
one.

## Provenance, restated from docs/M8_2_SCOPE.md SS12

Three categories of information, kept explicitly distinct:

    observed        -- M6/recorder-pipeline evidence (title, level, objectives, giver, interaction_position)
    source-derived  -- ATT or other external, unverified data
    route-authored   -- a human explicitly decided this (step existence, ordering, instruction text, a
                        manually-confirmed destination)

Every `Route` and every `RouteStep` this module accepts MUST carry `provenance: "route-authored"` at its own
level -- not because the *quest* a step references is unobserved (it must be observed, see below), but
because the step's own existence and place in the sequence was never recorded by the recorder and was never
sourced from ATT. A `Destination`, when present, carries its own separate `kind` (see `DESTINATION_KINDS`)
because a destination can legitimately be `OBSERVED_PLAYER_POSITION` -- an M6 value copied in with its
provenance intact, not reinterpreted as authored.

## What a route step does NOT carry

Per docs/M8_2_SCOPE.md SS14 ("Route Data ... referencing quest IDs, never embedding a copy of quest
content"), a step never duplicates a quest's title, giver, or objective text. It carries only `quest_id`
(and, for an OBJECTIVE step, `objective_index`, a 1-based index into that quest's own `objectives` array) --
the addon looks up the live text from the generated quest data (`Data.lua`) at render time. This is enforced
here by construction: this schema has no field for any of that content, so a route author cannot accidentally
duplicate (and later silently diverge from) observed text.

## M8.6-A additions: `why` and `required`

Two new OPTIONAL step fields, both squarely `route-authored` (they inherit the step's own `provenance`, not
a field of their own -- there is no meaningful sense in which an explanation or a required/optional
judgment could be "observed" or "source-derived"):

    why        -- a short string, the route author's own explanation of why this step exists. Never
                  generated from quest_id, coordinates, proximity, or an ATT relationship -- if a route
                  omits it, the UI simply shows no explanation, never a fabricated one.
    required   -- true or false. Never inferred from quest level, reward, ATT data, or a missing objective.
                  If omitted, the UI shows no REQUIRED/OPTIONAL badge at all (omission is not the same as
                  "required" -- an author who hasn't made the call yet must not have `true` assumed for them).
"""
from __future__ import annotations

from typing import Any

STEP_KINDS = {"ACCEPT", "TRAVEL", "OBJECTIVE", "TURN_IN", "TALK"}
DESTINATION_KINDS = {"OBSERVED_PLAYER_POSITION", "SOURCE_DERIVED_ATT", "ROUTE_AUTHORED"}
ROUTE_AUTHORED = "route-authored"  # the one provenance value a Route/RouteStep's own `provenance` field may hold


class RouteValidationError(ValueError):
    """Raised with a human-readable reason; a route either validates cleanly or is rejected outright --
    never partially accepted or silently repaired."""


def _fail(msg: str) -> None:
    raise RouteValidationError(msg)


def validate_destination(dest: Any, step_id: str) -> None:
    if dest is None:
        return
    if not isinstance(dest, dict):
        _fail(f"step {step_id}: destination must be an object or null, got {type(dest)}")
    kind = dest.get("kind")
    if kind not in DESTINATION_KINDS:
        _fail(f"step {step_id}: destination.kind {kind!r} not one of {sorted(DESTINATION_KINDS)}")
    if kind == "OBSERVED_PLAYER_POSITION":
        for f in ("ui_map_id", "x", "y"):
            if f not in dest:
                _fail(f"step {step_id}: OBSERVED_PLAYER_POSITION destination missing '{f}'")
        if not isinstance(dest["ui_map_id"], int):
            _fail(f"step {step_id}: destination.ui_map_id must be an int")
        for f in ("x", "y"):
            if not isinstance(dest[f], (int, float)):
                _fail(f"step {step_id}: destination.{f} must be a number")
    elif kind == "ROUTE_AUTHORED":
        if not isinstance(dest.get("text"), str) or not dest["text"]:
            _fail(f"step {step_id}: ROUTE_AUTHORED destination needs a non-empty 'text'")
    elif kind == "SOURCE_DERIVED_ATT":
        # Permitted by the schema (M8.2 SS4), but M8.3's own scope explicitly forbids using one (no ATT
        # coordinate may be copied in and labeled anything other than what it is); no M8.3 route may
        # actually contain this kind. Enforced at the call site (validate_route), not here, so this
        # function stays a pure shape-checker.
        for f in ("ui_map_id", "x", "y"):
            if f not in dest:
                _fail(f"step {step_id}: SOURCE_DERIVED_ATT destination missing '{f}'")


def validate_step(step: dict, step_id_key: str, quests_by_id: dict[int, dict]) -> None:
    if step.get("id") != step_id_key:
        _fail(f"step key {step_id_key!r} does not match its own id field {step.get('id')!r}")
    if step.get("provenance") != ROUTE_AUTHORED:
        _fail(f"step {step_id_key}: provenance must be {ROUTE_AUTHORED!r}, got {step.get('provenance')!r}")
    kind = step.get("kind")
    if kind not in STEP_KINDS:
        _fail(f"step {step_id_key}: kind {kind!r} not one of {sorted(STEP_KINDS)}")
    if not isinstance(step.get("display_text"), str) or not step["display_text"]:
        _fail(f"step {step_id_key}: display_text must be a non-empty string")

    quest_id = step.get("quest_id")
    if quest_id is not None:
        if not isinstance(quest_id, int):
            _fail(f"step {step_id_key}: quest_id must be an int or null, got {type(quest_id)}")
        if quest_id not in quests_by_id:
            _fail(f"step {step_id_key}: quest_id {quest_id} is not a guide-ready quest in the current M6 dataset")

    objective_index = step.get("objective_index")
    if kind == "OBJECTIVE":
        if quest_id is None:
            _fail(f"step {step_id_key}: an OBJECTIVE step needs a quest_id")
        if not isinstance(objective_index, int) or objective_index < 1:
            _fail(f"step {step_id_key}: an OBJECTIVE step needs a 1-based integer objective_index, got {objective_index!r}")
        n = len(quests_by_id[quest_id]["objectives"])
        if objective_index > n:
            _fail(f"step {step_id_key}: objective_index {objective_index} out of range for quest {quest_id} ({n} objective(s))")
    elif objective_index is not None:
        _fail(f"step {step_id_key}: objective_index is only meaningful for kind=OBJECTIVE (got kind={kind!r})")

    npc = step.get("npc")
    if npc is not None:
        if not isinstance(npc, dict) or "name" not in npc or "npc_id" not in npc:
            _fail(f"step {step_id_key}: npc must be null or {{name, npc_id}}, got {npc!r}")

    validate_destination(step.get("destination"), step_id_key)

    next_id = step.get("next_step_id")
    if next_id is not None and not isinstance(next_id, str):
        _fail(f"step {step_id_key}: next_step_id must be a string or null")

    # M8.6-A: both optional, both route-authored presentation metadata (see this module's own docstring).
    why = step.get("why")
    if why is not None and (not isinstance(why, str) or not why.strip()):
        _fail(f"step {step_id_key}: why, if present, must be a non-empty string (omit the field entirely for no explanation)")

    required = step.get("required")
    if required is not None and not isinstance(required, bool):
        _fail(f"step {step_id_key}: required, if present, must be true or false, got {required!r}")


def validate_route(route: dict, quests_by_id: dict[int, dict]) -> list[str]:
    """Validate `route` (a parsed route JSON dict) against `quests_by_id` (quest_id -> minimal-contract dict,
    exactly the shape M8.1's generator produces -- see generate_route_data.load_guide_ready_quests()).

    Returns the ordered list of step IDs reached by walking next_step_id from first_step (the route's
    EXPLICIT order -- this function never sorts, never looks at quest_id, never infers order any other way).
    Raises RouteValidationError on any problem; never repairs or drops a bad step silently.
    """
    for f in ("id", "title", "provenance", "first_step", "steps"):
        if f not in route:
            _fail(f"route missing required field '{f}'")
    if route["provenance"] != ROUTE_AUTHORED:
        _fail(f"route provenance must be {ROUTE_AUTHORED!r}, got {route['provenance']!r}")
    if not isinstance(route["id"], str) or not route["id"]:
        _fail("route id must be a non-empty string")
    if not isinstance(route["title"], str) or not route["title"]:
        _fail("route title must be a non-empty string")
    steps = route["steps"]
    if not isinstance(steps, dict) or not steps:
        _fail("route.steps must be a non-empty object keyed by step id")

    for step_id_key, step in steps.items():
        validate_step(step, step_id_key, quests_by_id)

    if route["first_step"] not in steps:
        _fail(f"first_step {route['first_step']!r} is not a key in route.steps")

    # Walk the explicit next_step_id chain from first_step. This is the ONLY source of ordering used
    # anywhere in this module -- never dict iteration order, never quest_id, never the JSON file's own
    # key order (json.load does preserve insertion order in Python, but this function does not rely on
    # that; shuffling the JSON file's keys must not change the validated order).
    order = []
    seen = set()
    cur = route["first_step"]
    while cur is not None:
        if cur in seen:
            _fail(f"cycle detected in next_step_id chain at step {cur!r}")
        if cur not in steps:
            _fail(f"next_step_id points at unknown step {cur!r}")
        seen.add(cur)
        order.append(cur)
        cur = steps[cur].get("next_step_id")

    unreachable = set(steps) - seen
    if unreachable:
        _fail(f"step(s) not reachable from first_step via next_step_id: {sorted(unreachable)}")

    return order
