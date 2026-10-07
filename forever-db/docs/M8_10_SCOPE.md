# M8.10: TRAVEL Destination and Arrival Investigation

**Status: COMPLETE AND LOCKED — PASS (real-client validated on build 70124, 2026-09-30); see
`M8_10_COMPLETION_REPORT.md`. The scope text below is preserved as originally written.** No production addon, route
data, route logic, recorder, or M8.7–M8.9 file is created or modified. ForeverQuestGuide v0.6 is frozen.

**Scope date:** 2026-09-30. Intended destination: `forever-db/docs/M8_10_SCOPE.md`.

## 1. The question

> Can TRAVEL steps be detected reliably on WoW Forever?

1. Can the addon retrieve the current waypoint after setting one?
2. Does the waypoint API expose destination coordinates, map ID, distance, or arrival information?
3. Does `C_SuperTrack` expose useful state beyond drawing the arrow?
4. Can player and waypoint positions be compared on the same map?
5. Can distance be calculated reliably when both are available?
6. Is there a built-in "arrived at waypoint" signal?
7. Does behaviour differ when the destination is on another map?
8. Can an arrival radius be established empirically?
9. Without enough waypoint information, can TRAVEL be detected from player/map state alone?
10. What would a TRAVEL step need to contain in route data for automatic detection?

Designing or implementing progression is out of scope.

## 2. Five separate capabilities

| Capability | Status before M8.10 |
|---|---|
| Waypoint **display** | Proven (M8.6-B): `SetUserWaypoint` + `C_SuperTrack.SetSuperTrackedUserWaypoint` drew a pin and arrow on 1413 and 1411 |
| Waypoint **destination retrieval** | Unknown |
| **Distance** calculation | Unknown |
| **Arrival** detection | Unknown |
| **Cross-map** travel | Unknown |

The arrow appearing does not show that an addon can read the same destination back.

## 3. Route data today (inspected, not changed)

The only route, `thunder-lizards-test-route`, has one TRAVEL step:

| Field | `s2` (TRAVEL) value |
|---|---|
| `kind` | `"TRAVEL"` |
| `quest_id` | `907` |
| `objective_index` | `nil` |
| `npc` | `nil` |
| **`destination`** | **`nil`** |
| `display_text` | "Head out to find Thunder Lizards. No objective-area coordinate exists anywhere in this project for this quest -- follow the objective text below." |
| `why` / `required` | `nil` / `true` |

The step schema **can** carry a destination — `{ kind, ui_map_id, x, y }`, used by the TURN_IN step `s4`
(`kind = "OBSERVED_PLAYER_POSITION"`); the UI also recognizes `kind = "SOURCE_DERIVED_ATT"`. There is **no**
radius, tolerance, continent, or z field in the schema.

Two different problems, kept separate throughout:

1. **Our route data does not contain a TRAVEL destination.** Confirmed now, from the file. No client test can
   change this.
2. **Whether the client can provide destination/distance/arrival information.** Unknown; this milestone.

## 4. What is tested

**Destination retrieval:** `C_Map.HasUserWaypoint`, `C_Map.GetUserWaypoint` (map + x/y + z),
`C_Map.GetUserWaypointPositionForMap(playerMap)` (the waypoint projected onto the player's map), plus
`GetUserWaypointHyperlink` presence.

**Super-track / navigation state:** `C_SuperTrack.IsSuperTrackingUserWaypoint`, `IsSuperTrackingAnything`,
`GetSuperTrackedQuestID`; `C_Navigation.GetDistance` (the game's own yards-to-target), `GetFrame`,
`GetTargetState`, `WasClampedToScreen`.

**Player position:** `C_Map.GetBestMapForUnit("player")`, `C_Map.GetPlayerMapPosition`, `C_Map.GetMapInfo`,
`C_Map.GetMapWorldSize` (map size in yards), `C_Map.GetWorldPosFromMapPos` (continent + world yards),
`UnitPosition("player")`.

**Our own distances,** each labelled by method and never mixed:
- `map_fraction`: straight-line distance in map fractions (same map only; not yards);
- `yards_from_map_size`: map fractions scaled by `GetMapWorldSize` (same map only);
- `yards_from_world_pos`: world positions from `GetWorldPosFromMapPos` (same continent only).

**Events:** `USER_WAYPOINT_UPDATED`, `SUPER_TRACKING_CHANGED`, `NAVIGATION_FRAME_CREATED`,
`NAVIGATION_FRAME_DESTROYED`, **`NAVIGATION_DESTINATION_REACHED`**, `ZONE_CHANGED`, `ZONE_CHANGED_NEW_AREA`,
`ZONE_CHANGED_INDOORS`, `PLAYER_STARTED_MOVING`, `PLAYER_STOPPED_MOVING`.

**Arrival by clearing:** the probe also records the waypoint disappearing on its own, with the triggering event
and the last distances measured before it vanished — separately from the operator clearing it.

Every API is feature-checked and pcall'd; each reading records its status as `absent`, `error`, `nil`, or `ok`.

## 5. Probe

| | Value |
|---|---|
| Folder | `m8-10-travel-arrival-probe/addon/ForeverProbeM810` |
| SavedVariables | `ForeverProbeM810DB` (sessions appended) |
| Slash command | `/fprobe810` (summary), `state`, `near`, `pin <map> <x> <y>`, `clear` |
| Chat prefix | `[FProbeM810]` (orange) |
| Version | `m8-10-probe-0.1` |

- `near` sets a waypoint about 30 yards north of the player on the current map (yards via `GetMapWorldSize`;
  falls back to 0.01 of the map); `pin` sets one at given coordinates and reports the map's own name; `clear`
  removes it.
- While a waypoint exists: a reading every 0.5 s, stored when something changed or every 2 s; a distance line in
  chat every 3 s. Sampling stops when no waypoint exists. Cap: 2,000 records.
- Never calls a quest function. It sets or clears the game's user waypoint **only** on those three commands —
  the same call Show on Map already makes.

## 6. Result criteria (layered)

Each capability in §2 gets its own finding. The overall result:

**PASS** — either:
- a destination map and coordinate can be read back and compared with the player's position, giving a distance
  that changes predictably as the player moves; **or**
- the game provides a reliable arrival signal (`NAVIGATION_DESTINATION_REACHED`, or the waypoint clearing itself
  on arrival, consistently).

**PARTIAL:**
- display works but the destination cannot be read back;
- same-map distance works but cross-map arrival cannot be measured;
- some arrival state exists but would need route data we don't have (e.g. a radius).

**FAIL:** no waypoint destination data and no usable arrival signal, and player state alone cannot support a
reliable arrival rule.

**INCONCLUSIVE:** the probe could not observe the APIs/events (no session saved, timer never ran, waypoint could
not be set in the test).

**Arrival radius (Q8):** reported as an observation — the distance at which the game's own arrival signal fired,
if any, and the distance readings while standing on the pin. It is not a design choice made here.

## 7. What each result would mean later (not designed here)

- **Readback + distance works:** a TRAVEL step with a destination could be detected by distance; the route
  schema would need a destination (it lacks one today) and a radius field.
- **Game arrival signal works:** arrival could piggyback on the game's own waypoint; the radius is the game's.
- **Same-map only:** TRAVEL detection only for destinations on the player's current map; cross-map steps stay
  manual or need zone-change events.
- **Fail:** TRAVEL stays manual.
- In every case, the current route's TRAVEL step still has no destination (§3.1); that is a data task, not a
  client limitation.

## 8. Out of scope

Progression, route-schema changes, UI changes, production addon changes, `M8_2_SCOPE.md` edits, long journeys.

## 9. Files

```
m8-10-travel-arrival-probe/
  addon/ForeverProbeM810/ForeverProbeM810.toc
  addon/ForeverProbeM810/ForeverProbeM810.lua
  tests/run_probe_selftest.lua     -- 32 checks, lua5.1, stub environment only
  M8_10_GUIDE.md                    -- operator test procedure
  docs/M8_10_SCOPE.md               -- this document
  docs/M8_10_COMPLETION_REPORT.md   -- written after the real-client test
  evidence/ForeverProbeM810.lua     -- raw SavedVariables from the test (added at lock)
```

**M8.10 SCOPE DEFINED — probe ready for real-client test; no production code touched.**
