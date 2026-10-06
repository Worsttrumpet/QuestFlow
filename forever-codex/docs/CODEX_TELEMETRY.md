# Forever Codex: telemetry foundation

A small, quiet recorder of **raw gameplay observations**, so a future Fast route strategy can compare questing with
grinding using this character's actual performance instead of static assumptions.

**It records. It never decides.** Nothing in the route engine, `Strategies.lua`, the UI or navigation reads it or is
read by it (a test enforces both directions). No recommendation changes because of it. There is no analytics UI.

## Where it lives

| File | Role |
|---|---|
| `ForeverCodex/Telemetry.lua` | the recorder: its own event frame, a capped log in `ForeverCodexDB.telemetry`, a 1 Hz poll |
| `ForeverCodex/TelemetryMetrics.lua` | **pure** calculators over the log (no client calls, no state), labelled observed / calculated / estimated |
| `Diag.lua`, `Slash.lua` | thin hooks only: `/codex diag` lines and `/codex telemetry ...` |

Both telemetry files depend only on the Lua/WoW globals (not on any Codex module except `ns.Safe`-style error
recording via `ns.RecordError`). They use their own tiny position/quest-log readers on purpose, to stay independent
of the engine and navigation code.

## What is captured (all OBSERVED values)

`t` = `GetTime()` seconds (2 decimals), `w` = `time()` epoch seconds. Durations and rates only span **one session**
(`GetTime()` restarts each login); a `SESSION` marker separates sessions.

| Event | Fields | Source | Status on Forever |
|---|---|---|---|
| `SESSION` | `w`, `v` (schema), `lvl`, `xp`, `max`, `build` | login | n/a |
| `XP_GAIN` | `d`, `xp`, `max`, `lvl`, `src` (`event`/`poll`/`level_event`), `sk` (s since last kill, if <= 10 s), `lvlup`, `multi` | `PLAYER_XP_UPDATE`, plus a 1 Hz `UnitXP`/`UnitXPMax` poll as fallback | **UNPROVEN**: never probed here |
| `MOB_KILL` | (never recorded) | **REMOVED in the audit hardening pass.** Forever refuses an addon's registration of `COMBAT_LOG_EVENT_UNFILTERED`; the dead handler and the `sk` (seconds since kill) field on `XP_GAIN` are gone. The capability list still names it as UNAVAILABLE so reports are honest. | **UNAVAILABLE** |
| `LEVEL_UP` | `lvl`, `src` | `PLAYER_LEVEL_UP`, plus `UnitLevel` change in the poll | **UNPROVEN** (`UnitLevel` itself is proven) |
| `QUEST_ACCEPT` | `q`, `w` | `QUEST_ACCEPTED(questID)` | **proven** (M8.7) |
| `QUEST_COMPLETE` | `q`, `dur` (wall seconds since accept, only if the accept was seen) | quest-log diff on `UNIT_QUEST_LOG_CHANGED`/`QUEST_LOG_UPDATE` + `C_QuestLog.IsComplete`. Means **objectives complete**, not turn-in | **proven** (M8.9: the events carry no quest id, so the diff finds it) |
| `QUEST_TURNIN` | `q`, `xp`, `money`, `dur` | `QUEST_TURNED_IN(questID, xp, money)` | **proven** (M8.8, XP matched the client's line) |
| `PLAYER_MOVE` | one movement **segment**: `dur`, `dist` (yd), `map`, `x0,y0,x1,y1`, `approx` | `C_Map` position sampled at 1 Hz, segmented by Codex | position API **proven** (M8.10); the segmenting is Codex's own and untested on the client |
| `COMBAT_START` / `COMBAT_END` | `dur` on end | `PLAYER_REGEN_DISABLED` / `ENABLED` | **UNPROVEN** |

"Proven" means observed working on the real Forever client in an earlier milestone (evidence cited in
`Telemetry.lua`'s `EVENT_DEFS`). **Unproven** events are standard Classic events this project has never seen fire on
Forever; they may not exist or may behave differently. `/codex telemetry` shows, per event type, whether its client
event registered and how many events were actually recorded this session, so the first real-client run answers it.

### Movement rules (Codex's own, documented so they can be challenged)

A sample every second. Moving = at least 2 yd since the previous sample. A segment ends after 2 still samples, when
position is lost, or at 120 s (long trips are split). A jump over 120 yd in one second (flight path, teleport, loading
screen) or a map/continent change is **not** travel: it ends the segment and counts as an anomaly. If world
coordinates are unavailable, distance falls back to map fractions and the event is flagged `approx`.

### Quest durations

Wall-clock seconds from the observed accept to the observed completion/turn-in. Only when the accept was seen
(accept times are remembered, max 60). These include travel and everything else done in between, so they are an
**upper bound on effort**, never "time spent on the quest".

## What is calculated (`TelemetryMetrics.Summary(events, {span=600})`)

Every metric is `{ kind, value, unit, n, basis }`, or `{ value = nil, reason = ... }` when there is not enough
evidence. It never guesses. Default window: the last 600 s of the latest session; a rate needs at least 60 s.

| Metric | Kind | Definition |
|---|---|---|
| `xp.total` | observed | sum of `XP_GAIN.d` |
| `xp.perMinute`, `xp.perHour` | calculated | total XP / window wall time (includes downtime) |
| `xp.perActiveMinute` | calculated | total XP / (observed combat + movement seconds), needs >= 30 s |
| `kills.count` | observed | `MOB_KILL` events |
| `kills.perMinute` | calculated | kills / window |
| `kills.avgXpPerKill` | **estimated** | mean XP of gains within 1.5 s after a kill (timing pairing; not proven to be that kill's XP; level-up gains excluded) |
| `kills.avgCombatSeconds` | calculated | mean fight length |
| `timing.combatSeconds` / `moveSeconds` / `moveDistance` | observed | sums of `COMBAT_END.dur` / `PLAYER_MOVE.dur` / `.dist` |
| `timing.downtimeSeconds` / `downtimeShare` | calculated | window minus combat and movement: "not fighting and not moving" (does not separate AFK from reading from inventory) |
| `timing.combatShare` / `moveShare` | calculated | seconds / window |
| `quests.accepted/completed/turnedIn/xp` | observed | counts; sum of turn-in XP |
| `quests.avgSecondsToComplete` | calculated | mean accept -> objectives-complete wall time |
| `quests.xpPerQuestMinute` | calculated | turn-in XP / accept -> turn-in wall time (upper bound on effort) |
| `levelUps` | observed | count |

A future Fast strategy would ask, for example: `local s = ns.TelemetryMetrics.Summary(ns.Telemetry.Events())`, then
compare `s.xp.perMinute.value` (if not nil) with a quest's expected XP and time. **Not implemented**: that comparison,
and any recommendation use.

## What is not captured (unavailable, or deliberately out of scope)

DPS / damage / healing (not a goal: XP efficiency matters more); combat-log parsing beyond `PARTY_KILL`; loot and
money income outside quest rewards; AFK vs reading vs inventory idle; mounted/flying state; rested XP; XP source
beyond timing; deaths and repair/downtime causes; group XP sharing; per-mob level and mob names. Anything needing a
GUID keeps only the numeric creature id: **raw GUIDs, character names, chat and account data are never stored**.

## Size, persistence, controls

* The log is capped (300 events, newest kept) and lives directly in `ForeverCodexDB.telemetry` (`events`,
  `accepted`, `enabled`, `cap`, `v`), so `/reload` saves it with no copying. A full log is a few KB.
* `/reload` saves reliably on Forever; logout saves have failed intermittently (M8.0). Telemetry is advisory data.
* `/codex telemetry [status | summary [seconds] | events [n] | on | off | reset]`. Default: on. A saved "off" is
  respected after a reload. `/codex diag` includes a telemetry section.
* Cost: a 1 Hz poll plus event handlers. The combat-log handler returns immediately unless the subevent is
  `PARTY_KILL` (the event can fire often in busy combat; that is the one performance unknown to watch on the client).

## How to extend later (no rewrite)

Add an event type: one `EVENT_DEFS` entry (with its evidence status) + a handler that calls `T.Record(type, fields)`.
Add a metric: one pure function/field in `TelemetryMetrics.Summary`, labelled with its kind. Teach the engine to
use it: add a reader in `Strategies`/`Engine` that calls `Summary`; telemetry itself stays decision-free.


## Storage (audit hardening pass)
The log is **per character**: the live table `ForeverCodexDB.telemetry` carries an `owner` (the character key) and another character's log is parked under `chars[owner].parked`. See `CODEX_SAVED_DATA.md`. "Codex learned N observations from this character" is therefore accurate.
