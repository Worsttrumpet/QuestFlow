# Forever Codex: performance audit (investigation only)

Scope: read the code, trace every timer / event / recompute path, and measure the pure-Lua cost in the STUB client. No addon code was changed.
Stub timings (`os.clock`, Lua 5.1 on a Linux container) are relative cost only: they are NOT real-client timings. Labels: NORMAL / WATCH (expected, monitor) /
POTENTIAL / CONFIRMED. The scratch benchmark lived outside the repo (a copy of `planner_eval.lua` with 4,357 synthetic quests, 20 in the log).

## 1. Executive summary
* Codex is healthy enough to build on. Nothing grows without bound; all persistent structures are capped; events mark state dirty and a throttled recompute does the work.
* ONE CONFIRMED inefficiency: `Providers/Quest.lua` calls `P.IsSkipped(...)` once per quest per recompute. `P.IsSkipped` calls `P.Char()`, and `P.Char()` re-runs
  `ensureChar` (defaults + `R.Systems()`, which builds a fresh table) on every call. In the stub that is 16.5 of 20.5 ms and 1.37 of 2.05 MB of garbage in the quest scan.
* The planner itself is cheap (about 2-7 ms for 93-380 candidates). The recompute cost is dominated by the quest scan over ALL known ids, not by the search.
* The 33 -> 64 -> 57 MB movement is plausibly normal: a one-time cold build of every quest record (+9 MB in the stub) and garbage that the collector reclaims once the heap doubles (the default pause is 200%). Plausible, NOT proven.
* The GPU number is not something an addon can meaningfully cause or that this repo can explain (section 7).

## 2. CPU findings (recurring work)
| Work | Trigger | Rate | Cost shape | Class |
|---|---|---|---|---|
| `State.Tick` (Boot OnUpdate) | every frame | cheap compare of two numbers | O(1) | NORMAL |
| Recompute (Context.Build + Quest scan + Planner + UI.Refresh) | dirty (after 0.4 s) or window open (every 3 s) | event-driven plus 0.33 Hz while the window is open | O(all known quest ids) + O(candidates x stops) | see 3 |
| `Telemetry.Tick` | OnUpdate, gated to 1 s | 1 Hz: XP poll, position sample, quest-log diff only when dirty | O(log size) when dirty | NORMAL |
| `Navigation.Tick` | OnUpdate, gated to 1 s | 1 Hz, only when a destination exists | O(1) | NORMAL |
| `Arrow.Tick` | OnUpdate, gated 0.1 s with a target, 0.25 s idle | 4-10 Hz | a few table/string allocations per update (`prev`, `worldOf` keys); calibration learning | WATCH (tiny) |
| UI window OnUpdate | frame, gated 0.5 s | 2 Hz, one comparison | O(1) | NORMAL |
| Minimap button OnUpdate | only while dragging | | | NORMAL |
| ItemProbe / Gear / Evidence | events only; bag changes only set a dirty flag; GET_ITEM_INFO_RECEIVED does work only when items are pending | event-driven | bounded | NORMAL |
| Report generation (`/codex report`, diag) | on demand | | string building | NORMAL (not measured) |
There is no `C_Timer` ticker, no per-frame scan of anything, no addon-integration polling (none exist yet).

## 3. Planner recomputation
Triggers (all call `State.MarkDirty` only): UNIT_QUEST_LOG_CHANGED (player), QUEST_LOG_UPDATE, QUEST_ACCEPTED, QUEST_TURNED_IN, PLAYER_ENTERING_WORLD, PLAYER_LEVEL_UP, ZONE_CHANGED x3,
USER_WAYPOINT_UPDATED, GROUP_ROSTER_UPDATE; player choices (skip, add, style, route zone) and `/codex` commands recompute directly; opening the tracker recomputes; the window being open adds a 3 s periodic recompute.
* Coalesced: yes. `MarkDirty` sets a flag; `Tick` recomputes at most once per 0.4 s. A burst of quest-log events costs one run.
* Recursion: none found. A recompute never marks itself dirty (the dirty flag is cleared at the start).
* Movement: does NOT recompute by itself. Only the window-open 3 s periodic refresh (and ZONE_CHANGED) picks up position. With the window closed, movement costs nothing in the planner.
* Inventory / equipment: do not recompute the plan (Gear marks its own snapshot dirty; the planner does not read bags).
* UI open/close: recomputes once on open; while open, every 3 s even if nothing changed (POTENTIAL, section 11).
* Complexity: Quest scan O(N ids) cheap rejects; the sequence search is bounded (beam 8, depth 3, 400 sequences in the latest report), so it is nearly flat in the number of ids.
* "5 recomputes" in the real report: with a window open for minutes the 3 s refresh alone would exceed 5, so that session most likely had a closed window or a fresh reload. Unproven; it also means the 3% average cannot be blamed on recomputes.

Measured in the stub (4,357 quests, ~93-380 eligible; per recompute):
| Eligible | Quest scan (Engine.Candidates) | Planner.Compute | Whole Recompute | Garbage per recompute |
|---|---|---|---|---|
| 0 | 20 ms | 0.06 ms | 23 ms | 1.6 MB |
| 113 (93 candidates) | 24 ms | 2-3 ms | 28 ms | 2.6 MB |
| 400 (380 candidates) | 32 ms | 7 ms | 50 ms | 5.1 MB |
Cold first build: ~55-80 ms and +9 to +11 MB retained (all merged quest views are cached for the session).

## 4. Memory (persistent structures)
| Structure | Session | Saved | Bounded | Notes |
|---|---|---|---|---|
| QuestieDB data | owned by QuestieDB, not Codex | no | n/a | Codex only reads it |
| `QB.recCache` (normalized record per id) and `Registry cache.q` (merged view per id) | yes | no | by number of ids (4,357) | the same facts are held TWICE (record and merged view); WATCH |
| `npcCache` | yes | no | by NPC count touched | NORMAL |
| ATT / observed packs | yes | no | static | NORMAL |
| Telemetry events | yes | yes | cap 300 (oldest dropped) | NORMAL; counters `seen` bounded by event types |
| Reward observations | yes | yes | 500 | NORMAL |
| Evidence observations | yes | yes | 2,000, deduplicated by fingerprint | NORMAL; the largest SavedVariables list |
| Journey entries | yes | yes | 150 | NORMAL |
| Stored diagnostic reports | yes | yes | 5 | NORMAL |
| `ns.errors` | yes | no | capped | NORMAL |
| Gear snapshot | yes | no | 11 + <= 5 bags | NORMAL |
| Plan / candidates / sequences | replaced each recompute | no | the old plan becomes garbage | NORMAL |
| Arrow samples | yes | calibration only | MAX_SAMPLES | NORMAL |
Nothing found that grows forever in normal play.

## 5. Garbage collection / allocation
* MEANINGFUL: the per-quest `P.IsSkipped("Q:" .. id)` pair (string concat plus the `P.Char()` table), 1.37 MB per recompute.
* Moderate: each eligible quest builds an action with lines/targets (rebuilt every recompute): ~400 KB/114 candidates; `Planner.Compute` 0.4-0.8 MB per run (stops, sequences).
* Small: `Context.Build` (~17 KB), Arrow per update, `{...}` per telemetry event, `ctx.worldOf` key strings.
* Memory 33 -> 64 -> 57 MB: at ~2.6 MB per recompute and one recompute per 3 s with the window open, the heap grows ~50 MB/min of garbage until the collector's threshold (about twice the live size) fires; the cold quest-record build adds a one-time jump. A sawtooth with a flat floor is normal collector behaviour; a leak would show a rising FLOOR after full collections. Not proven from one reading.

## 6. Events
Registered (Boot): PLAYER_ENTERING_WORLD, PLAYER_LEVEL_UP, QUEST_ACCEPTED, QUEST_TURNED_IN, UNIT_QUEST_LOG_CHANGED, QUEST_LOG_UPDATE, ZONE_CHANGED(+INDOORS, +NEW_AREA), USER_WAYPOINT_UPDATED, GROUP_ROSTER_UPDATE, CHAT_MSG_ADDON.
Telemetry: XP, level, accept/turn-in, log changes, REGEN_DISABLED/ENABLED. ItemProbe: QUEST_DETAIL/COMPLETE/ITEM_UPDATE, GET_ITEM_INFO_RECEIVED, PLAYER_EQUIPMENT_CHANGED, BAG_UPDATE_DELAYED, SKILL_LINES_CHANGED.
* Heavy handler: none directly. They all mark dirty (State, Telemetry, Gear). The one non-deferred item: CHAT_MSG_ADDON calls `UI.Refresh` directly (only when a party member sends a Codex message).
* QUEST_LOG_UPDATE fires in clusters on the real client; coalescing makes that cost one recompute per 0.4 s at most. Worth a real count (section 15).
* The preferred model (event -> dirty -> recompute when needed -> present) is ALREADY how Codex works. The one deviation is the 3 s periodic recompute while the window is open.

## 7. GPU / UI
An addon runs Lua on the CPU and drives the client's UI through frames, textures and font strings; the client does the drawing. Codex has no custom rendering: a few frames, one rotating arrow texture (`SetRotation`), text rows; no animations, no map overlay textures, no per-frame texture swaps. Updating text rows can cost client-side layout, but nothing here is rendering-heavy.
The addon panel's CPU/memory numbers are per addon; a GPU reading, if the panel shows one, is almost certainly a client/system figure (the repo cannot say what the panel reports and no Codex code reads GPU). Treat the 1% -> 18% swings as unrelated to Codex unless a Codex-off comparison shows otherwise. Cannot be determined from the code.

## 8. Existing instrumentation
Present: recompute count, quest-bridge build time (`QB.Stats().ms`), telemetry counts and anomalies, Gear refresh counters, ItemProbe pending count.
Missing: time per recompute, planner time, event counts per event name, report generation time, memory, and the CPU/memory profiler reading (`GetAddOnMemoryUsage` / `GetAddOnCPUUsage` are unused; CPU numbers need the client's script-profiling setting on).

## 9. Scaling analysis
Numbers that matter: number of known quest ids (every recompute walks all of them), number of candidates (action objects, stops), and recompute frequency. Numbers that do not: telemetry 300, evidence 2,000 (saved, not scanned per recompute), 71 stops (the beam is capped), inventory size (not in the recompute path).
Future systems, relative to this baseline:
* A new optional-action source adds O(items) per recompute: fine if the source is a small pre-filtered list (flight nodes, trainers: tens). A gathering source with thousands of node positions is a trap if it is scanned every recompute: it must be spatially indexed or filtered once per map change.
* Item / future-requirement / profession opportunities should be computed on item or log change events, cached against a version number, and read by the planner, not rebuilt per recompute.
* Activity alignment must be derived from telemetry events as they arrive (O(1) per event), never by scanning the log per recompute.
* Optional addon facts: read when the addon is detected or reports a change, store normalized facts, never call into another addon from the tick.
* If the quest scan is not fixed first, every new per-recompute cost is added on top of a 20+ ms floor.

## 10. Confirmed issue
C1. `P.Char()` is not cheap and the quest provider calls it ~4,357x per recompute through `P.IsSkipped` (`Preferences.lua` `ensureChar` rebuilds defaults and a `R.Systems()` table on every call; `Providers/Quest.lua` Generate lines 323-365).
Evidence: stub piece timing 16.5 ms / 1.37 MB per pass out of 20.5 ms / 2.05 MB for the entire scan. Smallest safe fix (not applied): in `Q.Generate` read `local skipped = ctx.prefs.skipped` once (it is the same table `Context.Build` already took from `P.Char()`), and look keys up directly. Prototype in a scratch copy: scan 20.5 -> 6.1 ms, garbage 2.05 -> 0.68 MB, same candidates. Behaviour is identical; no planner change. (A second, optional step: make `ensureChar` skip its work after the first call per session.) Other `P.Char()` callers (Arrow ticks, UI) are low-frequency and not worth touching.

## 11. Potential issues
P1. Window-open 3 s periodic recompute even with no change: confirm by counting recomputes with the window open and stationary (`computeCount` over 60 s). A cheaper design (recompute only when the player moved a threshold or the state is dirty) would change behaviour, so it needs a decision.
P2. Whole-registry scan per recompute scales with all known quests: confirm/reject with a recompute timer on the real client. A version-stamped candidate cache is the later answer, only if the timer shows a problem.
P3. Double caching of quest facts (`recCache` and `cache.q`): measure Codex's own memory (`GetAddOnMemoryUsage`) before and after the first recompute.
P4. The 41% CPU peak: most likely the cold first build (about 60-80 ms in the stub) or a recompute burst; unknown. The panel's peak is per-frame, so a single 60 ms hitch reads as a very large number. Needs the profiler reading.

## 12. Completely normal, do not optimize
The 1 Hz telemetry and navigation ticks; the cap-and-drop lists; Gear/Evidence event handling; the planner search; `Context.Build`; the Arrow tick at its current rate; the report generators; saved-variable sizes.

## 13. Smallest recommended fixes
1. C1 as above (one local variable in one function). Everything else: wait for measurement.
2. Instrumentation (section 14 of the output below), because P1-P4 cannot be settled without it.

## 14. Performance budget for the Opportunity System
* No new OnUpdate and no polling. New sources are event-driven and mark dirty; discovery results are cached against a version and rebuilt only on their own events.
* Per-recompute budget: opportunity work adds at most O(extras) (tens), with the interruption cost computed only for the first N extras by solo net; nothing in a recompute may scan an unbounded external list.
* Allocation: no per-quest or per-node temporary tables inside the scan; reuse; avoid string concatenation as a lookup key inside loops over all ids.
* Cold start: build lazily on first use, never at login for everything.
* Every new cache is bounded and its size appears in the report.

## 15. Minimal real-client validation
No grinding. During normal play: (a) `/codex report` once after a few minutes with the window OPEN and once with it CLOSED, comparing the recompute counter and (when added) planner time; (b) the addon panel Codex memory/CPU just after `/reload`, after the first recompute, and after a few minutes; (c) with script profiling enabled, one reading with Codex disabled vs enabled.

## 16. Files involved
`Providers/Quest.lua` (C1), `Preferences.lua` (optional), `State.lua` (timing), `Diag.lua` (PERFORMANCE block), `Telemetry.lua` (none), `Planner.lua` (none).
Smallest instrumentation: in `State.Recompute` wrap with `debugprofilestop` and keep count / total / worst / last, plus per-event counters in `Boot.onEvent`; add `GetAddOnMemoryUsage("ForeverCodex")` current and first-seen, and print a PERFORMANCE block in the report. About 30 lines; opt-in timing only in the report, no new timers.

## 17. Do not change
The planner core and constants, the golden baselines, the Reward Advisor and Eligibility, the telemetry cadence, the event-to-dirty design, the caps.

## Testing with the stub
Testable: recompute count under event bursts (coalescing), dirty-flag behaviour, bounded lists (telemetry, evidence, rewards, journey, errors), repeated planner calls growing no state (`collectgarbage("count")` floor after repeated recomputes), repeated report generation. Not trustworthy: absolute timings (use ratios only), GC behaviour of the real client.

## Follow-up: what 0.5.3 changed (maintenance release)
* `Providers/Quest.lua`: `Q.Generate` reads `ctx.prefs.skipped` (the table `Context.Build` already took from `P.Char()`) once and looks up `"Q:"/"QT:" .. id` directly instead of calling `P.IsSkipped` per quest; the per-candidate `P.QuestSkipState(id)` in `attach` became `K.SkipState(ctx.prefs.skipped, id)` (the same function `P.QuestSkipState` wraps). Same table, same keys, same results.
* Equivalence check (scratch, 4,357 synthetic quests, 113 eligible): 93 candidates, identical id hash and identical NOW before and after. Stub scan 20.9 -> 10.7 ms and 2.04 -> 0.64 MB garbage per recompute (stub ratios only; the remainder is the per-candidate action construction and the `"Q:" .. id` key strings). No real-client number is claimed.
* Instrumentation (no timer, no OnUpdate, no polling): `State.perf` counts recomputes by cause (`dirty`, `periodic`, `direct`, `report`), last/worst/total milliseconds from `debugprofilestop` (skipped when the client lacks it), and which events marked the plan stale (`State.MarkDirty(event)`, called from `Boot.onEvent`; callers that pass nothing count as `other`). Codex memory is read with `GetAddOnMemoryUsage` when present: once after the first recompute and again when the report is made. `/codex report` has a PERFORMANCE section, including periodic recomputes per minute since load against the 20/min the 3 s rule allows.
* NOT changed: the 3 s window-open refresh (P1 stays open until the real-client report shows its rate), the 0.4 s dirty delay, event registration, telemetry cadence, caps, planner, Reward Advisor, Eligibility.
* Real-client question that remains: how many `periodic` recomputes per minute occur with the window open, their real millisecond cost, and Codex memory floor over a few minutes.

## 0.6.0 real-client report: the 462 ms outlier (0.6.1)
Report: 29 recomputes, last 28.7 ms, average 44.5 ms, worst 462.0 ms with cause `direct`, periodic 15 in 57 s (15.9/min), QuestieDB "4359 records read so far".
* FACT: the worst was a `direct` recompute (two happened: the login recompute in `Boot.onLogin`, and one from opening / a command). Periodic, dirty and report recomputes were not the worst.
* FACT: the QuestieDB bridge caches each quest record the first time a recompute asks for it, and the registry caches the merged view. All 4,357 ids are read on the first scan, and the report shows ~all were read. The cache is only dropped when a quest pack is registered or removed (login, `/reload`, or another addon registering a pack), so it cannot recur during normal play.
* FACT: the stub shows the first scan at 55-80 ms against 20-30 ms warm; the real client reads each record through the QuestieDB API, so a several-fold larger real cold cost is expected.
* The 0.6.0 opportunity work is not the cause: its stub cost is about +0.75 ms per recompute, against a warm total of ~29 ms and a worst of 462 ms.
* NOT PROVEN: which stage of that recompute took the time, because 0.6.0 recorded only the total. 0.6.1 adds the smallest diagnostic: four clock reads per recompute (context / quest scan / planner, the rest by subtraction), kept only for the worst recompute, plus which recompute number it was, the first recompute's time, and the QuestieDB records-built count and total build ms. No timer, no polling. The next real report will say where the 462 ms went.
