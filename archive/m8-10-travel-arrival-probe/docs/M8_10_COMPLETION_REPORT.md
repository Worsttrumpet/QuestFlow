# M8.10 Completion Report: TRAVEL Destination and Arrival Investigation

**Result: PASS**, by the first PASS route in `M8_10_SCOPE.md` §6: a waypoint's map and coordinates can be read
back exactly, and an addon-computed distance from the player tracks movement predictably on the same map and
across zones of one continent. The game's own arrival event also exists (≈ 10 yd, 3 of 3), but it follows
whatever the game is navigating to, which an addon cannot reliably control. Cross-continent distance is not
measurable (correctly). No production code, route data, recorder, or M8.7–M8.9 file was touched.

## Validation record

| | |
|---|---|
| Real-client test date | 2026-09-30 |
| Client | `1.60.1`, build **70124** (Sep 29 2026), interface `16001` |
| Zone | Silverpine Forest (uiMapID 1421) |
| Movement | Three short walks toward/away from pins; no zone travel |
| Raw evidence | `evidence/ForeverProbeM810.lua` — SavedVariables, 2 sessions, 1,427 records, 983 samples, saved via `/reload`; SHA-256 `f65c8fbda3a2c6b33fd37ab6b1e9002268134fbf58869dc63e6fcd1e2f6e5a48` |
| Other evidence | Operator screenshots, including the Tirisfal pin shown on the world map at Brill |
| Lua errors | None reported by the operator |
| Operator verdict | Confirmed complete and passed (2026-09-30) |

## Final findings (locked)

1. `C_Map.GetUserWaypoint()` reliably returns the waypoint's map and coordinates (exact on every read; same map,
   other zone, other continent).
2. Addon-computed same-continent distance is reliable: world-position and map-size methods agreed on every
   same-map sample and tracked movement precisely.
3. Same-map and same-continent distance can be calculated without relying on the game's navigation, arrow, or
   waypoint state (player position + `GetWorldPosFromMapPos`).
4. Cross-continent distance is not available through the tested map/world-position methods.
5. `NAVIGATION_DESTINATION_REACHED` exists but follows the game's current navigation target, and is therefore
   unsuitable as the primary TRAVEL progression signal.
6. `C_Navigation.GetDistance()` is unsuitable as the primary TRAVEL signal: it can follow quests, become stale, or
   return `0.0`.
7. The user waypoint and super-tracking can be reclaimed by quests.
8. Waypoint clearing is not a reliable arrival signal (the pin stays after arrival; one unexplained removal).
9. The observed game arrival radius was approximately 10 yards (3 of 3). An addon-controlled TRAVEL radius will
   need to be an explicit route/design value.

**Two remaining issues, kept separate:**

- **Client capability** is sufficient for same-continent automatic TRAVEL detection.
- **Our current route data** has no TRAVEL destination and no radius.

## Findings by capability

| Capability | Finding |
|---|---|
| **Waypoint display** | Proven again (8 pins set; pins and arrow visible) |
| **Destination retrieval** | **Works.** `C_Map.GetUserWaypoint` returned the exact map and coordinates every time: same map (1421), other zone (1420 Tirisfal Glades, confirmed on the map at Brill), other continent (1413 The Barrens). `HasUserWaypoint` accurate throughout |
| **Distance (addon-computed)** | **Works on the same map and same continent.** World-position and map-size methods agreed on every same-map sample (to 0.1 yd; first reading after `near` exactly 30.0 yd). Tirisfal pin: 2,121.5 yd by world position. Other continent: correctly no value |
| **Distance (game, `C_Navigation.GetDistance`)** | **Not a safe proxy.** Matches the addon's distance only while the game's navigation is actually targeting the pin; otherwise reports the distance to a quest, a stale value, or `0.0` |
| **Arrival (game signal)** | **Exists, conditionally.** `NAVIGATION_DESTINATION_REACHED` fired 3 times, each at ≈ 10 yd (10.1, 10.0, 10.0): twice for a super-tracked quest, once for the user waypoint. It fires only for the current navigation target |
| **Arrival (waypoint clearing)** | **Does not happen.** After arrival the pin stayed; the player stood at 1.9 yd with no further event and no clearing |
| **Cross-map** | Other zone: readback, projection onto the player's map, and world distance all available. Other continent: readback only |

## Answers to the ten questions

1. **Retrieve the waypoint after setting it?** Yes: `HasUserWaypoint` + `GetUserWaypoint` (map, x, y; `z` nil).
2. **What the waypoint API exposes:** map ID and coordinates, plus `GetUserWaypointPositionForMap` (projection onto
   another map). No distance or arrival field.
3. **`C_SuperTrack` beyond drawing:** `IsSuperTrackingUserWaypoint`, `IsSuperTrackingAnything`,
   `GetSuperTrackedQuestID` all work and report what is super-tracked, but see finding 2 below — the flag can
   disagree with where navigation actually points.
4. **Same-map comparison?** Yes.
5. **Reliable distance?** Yes, computed by the addon (two methods, always agreeing). Not from `C_Navigation`.
6. **Built-in arrival signal?** `NAVIGATION_DESTINATION_REACHED`, at ≈ 10 yd, fired once per arrival, for the
   current navigation target only. The waypoint is not cleared.
7. **Other maps:** other zone — full readback and distance; other continent — readback only, no distance
   (`C_Navigation.GetDistance` returns `0.0`, which must never be read as "arrived").
8. **Arrival radius:** the game's own is ≈ 10 yd (3 of 3). An addon radius is a design choice; the addon distance
   is accurate enough to support one.
9. **TRAVEL from player/map state alone?** Yes, on the same continent: player position
   (`GetBestMapForUnit` + `GetPlayerMapPosition`) converted with `GetWorldPosFromMapPos`, compared with a
   destination coordinate — no waypoint, super-track, or navigation state needed.
10. **What route data would need:** see §Route data.

## Additional findings

1. **The game's navigation follows its own target, not the flag.** After `near`, `IsSuperTrackingUserWaypoint`
   became `true` at once, yet `C_Navigation.GetDistance` kept reporting a quest's distance for 89 s (185 samples)
   until that quest's destination was reached. `NAVIGATION_DESTINATION_REACHED` fired for the quest during that
   time, with the flag still saying "user waypoint".
2. **Super-tracking is contested.** Quests repeatedly reclaimed super-tracking from the user waypoint (quests 516,
   95884, and a run of eight in 7 s). The operator needed six `near` attempts before the arrow held the pin.
   An addon cannot assume `SetSuperTrackedUserWaypoint(true)` keeps the arrow on its pin.
3. **A waypoint disappeared without any command.** Session 2, t = 125.56 s: `USER_WAYPOINT_UPDATED` and the pin was
   gone, 215 yd away from it, 2.5 s after a burst of `SUPER_TRACKING_CHANGED` events cycling through eight quests
   (478, 440, 478, 443, 423, 450, 493, 516). Whether the operator clicked anything was asked and not answered;
   the cause is recorded as **unconfirmed**. Either way, a user waypoint set by an addon can be removed by
   ordinary quest-tracking activity.
4. **Stale game distance.** After a pin was replaced, `C_Navigation.GetDistance` still read 2.1 yd (the old pin)
   while the new pin was 2,784.6 yd away; after a teleport to The Sepulcher it read ≈ 425 yd high until the
   navigation frame was destroyed.
5. **Projection can fall outside the map.** The Tirisfal pin projected onto Silverpine at (0.756, −0.216): valid
   for direction, but not a point on the player's map.
6. **Probe labelling note:** the operator's final `clear` is recorded with reason `event:USER_WAYPOINT_UPDATED`
   because the game fired that event inside `ClearUserWaypoint`, before the probe's own post-clear reading. The
   `clear` command record at the same timestamp identifies it; the t = 125.56 disappearance has no command record.
7. All 23 APIs probed exist on Forever; `C_Navigation.GetTargetState` always returned `0`.

## Route data (inspected, unchanged)

The only TRAVEL step (`thunder-lizards-test-route` / `s2`) has `destination = nil`, `npc = nil`, and text stating
that no objective-area coordinate exists for quest 907. The step schema already supports
`destination = { kind, ui_map_id, x, y }` (used by TURN_IN step `s4`), but has no radius field.

The two problems, kept separate:

1. **Client capability:** sufficient for same-continent TRAVEL detection by addon-computed distance (this report).
2. **Our route data:** contains no TRAVEL destination, and no radius. This is a data task; no client finding
   changes it.

For automatic detection, a TRAVEL step would need at minimum a destination map and coordinate (the schema has
the shape), a stated provenance (as existing destinations do), and an arrival radius (not in the schema).

## M8.2 addendum (for later incorporation into `docs/M8_2_SCOPE.md` §9/§15; not applied here)

| M8.2 deferred item | Status after M8.10 |
|---|---|
| Map / minimap marker | Resolved (M8.6-B) |
| Directional arrow | **Game arrow works but is contested:** quests reclaim super-tracking; the arrow cannot be relied on to point at an addon's pin |
| Progression — ACCEPT | Signal proven (M8.7) |
| Progression — TURN_IN | Signal proven (M8.8) |
| Progression — OBJECTIVE | Detection proven (M8.9); objective-index mapping open |
| Progression — TRAVEL | **Client-side detection possible (M8.10)** by addon-computed distance on the same continent; blocked by route data, which has no TRAVEL destination or radius. Cross-continent not measurable |

The §9 manual-vs-semi-automatic decision remains open. All four step kinds now have client-side evidence.

## What this enables later (not designed here)

A TRAVEL step with a destination could be detected by the addon's own distance from player to destination, on
the same continent, without depending on the game's waypoint, arrow, or navigation state. The game's
`NAVIGATION_DESTINATION_REACHED` and `C_Navigation.GetDistance` are unsuitable as primary signals because they
follow the game's navigation target, which quests can take over, and because of the `0.0` / stale readings.

## Scope kept

No change to ForeverQuestGuide v0.6, route data, route schema, ForeverRecorder, or any M8.7–M8.9 file. The probe
set and cleared the game's waypoint only on operator commands. No zone travel.

```text
M8.10 STATUS: COMPLETE AND LOCKED — PASS (real-client validated, build 70124, 2026-09-30)
```
