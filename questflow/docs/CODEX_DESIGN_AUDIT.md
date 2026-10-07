# Forever Codex: Design Audit (pre-redesign checkpoint)

Status: design/documentation only. No addon code, data, tests, UI or telemetry was changed for this audit.
Supersedes nothing; extends `CODEX_PLANNING_MODEL.md` (the playtest-driven planning model) and
`CODEX_ARCHITECTURE.md`. Provenance rules stay as in `CODEX_PROVENANCE_DECISION.md`.

Method: read of the current addon (`forever-codex/ForeverCodex/`), the docs, the M3/M8 API evidence, the ATT
import code, plus one throwaway stub-harness probe (not committed) that logged which client APIs and widget
methods Codex calls at file load, ADDON_LOADED/PLAYER_LOGIN, window open, and Show on Map.

Vocabulary used per feature: **Decision** (design decision), **Exists** (existing capability),
**Missing**, **Investigate** (needs real-client evidence), **Later** (implementation, not now).

Evidence labels: **PROVEN** = observed working on Forever (M-series milestones / playtest);
**PRESENT** = function exists on Forever (M3) but behaviour untested; **UNPROVEN** = never probed.

---

## 1. Current architecture summary

Additive addon `ForeverCodex`, Lua 5.1, ~25 files, load order from the `.toc`:
Core, Registry, ProgressionEval, Preferences, Strategies, Providers (Planned, Quest, Flight), five Data packs,
Context, Engine, Route, State, Diag, Telemetry, TelemetryMetrics, MapPin, MinimapButton, UI (Widgets, Window),
Slash, Boot.

| Layer | Modules | Notes |
|---|---|---|
| Registry | `Registry.lua` | Extension points: packs, action types, systems, providers, strategies. Healthy; the best asset. |
| Data | `Data/Pack_*.lua` (generated, deterministic) | `src=att, verified=false` vs `src=observed, verified=true`; merged at read time by pack priority (observed 100, ATT 10), field by field. |
| Context | `Context.lua` | Snapshot of character, location, quest log, completions, group. Read-only. |
| Providers | `Quest`, `Flight`, `Planned` | Turn a pack + context into candidate actions. |
| Planner | `Engine.lua`, `Strategies.lua` | Stateless: collect, filter, score, greedy chain (`CHAIN_LENGTH` 8, `TRAVEL_MIN` 150 yd). Strategies are weight tables. |
| Adapter | `Route.lua` | Maps a plan onto the M8.13 step schema. |
| State | `State.lua` | Holds ctx + plan, recompute triggers. |
| Preferences | `Preferences.lua` | Per character: style, route zone, systems, skip/add overrides. `P.UI()` exists, unused for geometry. |
| Navigation | `MapPin.lua` (copy of M8.13) | `Place` only from the Show on Map button; `Clear` never called. |
| UI | `UI/Widgets`, `UI/Window`, `MinimapButton` | One fixed 500x668 window; not resizable; position not saved; minimap button not draggable. |
| Telemetry | `Telemetry.lua`, `TelemetryMetrics.lua` | Observation-only capped (300) event log + pure calculators labelled observed/calculated/estimated. Independent of the planner. |
| Diag | `Diag.lua`, `Slash.lua` | `/codex diag`, `/codex report`; API presence list. |

Size/health: Engine max 15 upvalues, Window 10, Telemetry 15 (limit 60). No giant module in Codex (the M8.13
UI at 37 upvalues / 1210 lines is the cautionary example and is not part of Codex). 316 stub-harness tests pass.

## 2. Current capabilities (what a player actually gets today)

- Detects name/class/race/faction/level, zone, map position (proven APIs).
- Player choices separated: race origin, route zone, strategy (Balanced, Fast, Questing, Completionist), systems toggles.
- Recommends NEXT plus an ordered sequence plus nearby actions from ATT-derived quests (and observed overlays),
  with TRAVEL insertion and flight-path hints.
- Skip / Add overrides per character.
- Show on Map: sets the built-in user waypoint and super-tracks it (proven M8.6-B).
- Telemetry recording of the nine event types, with `/codex telemetry`; Diag report.
- Future systems registered but disabled (no faked data).

Probe result (stub-level, not a client proof): at file load Codex creates one Frame and registers events. At
ADDON_LOADED/PLAYER_LOGIN it only does read calls (UnitLevel/Name/Class/Race/FactionGroup, GetZoneText,
GetSubZoneText, IsInGroup, GetNumGroupMembers, GetBuildInfo, GetTime, UnitXP/UnitXPMax, C_Map position calls,
C_QuestLog log reads) and creates one Button parented to Minimap. Waypoint calls
(`C_Map.SetUserWaypoint`, `C_SuperTrack.SetSuperTrackedUserWaypoint`) happen only on the Show on Map click.
No call in that list is an obviously protected one; see section 15 and the known-issue table.

## 3. Product vision summary

Codex is a character-aware progression companion that answers "what should I do now?" in one glance, with a
short-sequence planner (NOW / ALSO DO / THEN), one data and action model reshaped by strategy, a strict
attention system in the world (four markers), automatic navigation that follows NOW, a Questie-style quest map
built independently, tooltips that carry the depth, a compact UI, Appendices for reference, Journey history,
party awareness and an opt-in "Help Improve Codex". The player is always in control; unknown stays unknown.

## 4. Feature matrix

Legend: Exists / Partial / Missing / Blocked-unproven (needs client evidence before design can be final).

| Feature | State | Notes |
|---|---|---|
| Character detection | Exists | Class/race/faction/level proven. |
| Race origin vs route zone vs location separation | Exists | Preferences + Context. |
| Strategies as weights | Exists | Needs interruption/chain/batch terms. |
| NOW / next action | Partial | `plan.next` exists; "ALSO DO" is a nearby list, not a planner product. |
| ALSO DO (opportunistic) | Partial | `plan.nearby` (distance-based) only. |
| THEN | Partial | `sequence` exists but greedy, shown as "Coming up" players ignore. |
| Short-sequence planner | Missing | Greedy ranking; completed-quest 100 dominates. |
| Interruption cost / batching / density | Missing | Cluster bonus is a coarse stand-in. |
| Chain lookahead | Missing | No chain edges consumed in scoring. |
| Level breakpoints / trainers | Missing | No trainer data (ATT has none), no context for it. |
| Quest identity by ID | Partial | Provider keyed by ID; same-name collisions not stress-tested in UI. |
| Quest states (Available/In progress/Completed/Blocked/Skipped/Unknown) | Partial | Completed/in-progress/skipped exist; Blocked/Unknown not first-class. |
| Giver vs turn-in NPC | Missing | Turn-in assumed at giver (ATT has no turn-in field). |
| Multi-objective locations | Missing | One target per action. |
| Useful vs All Quests views | Missing | |
| World/Quest map layer | Missing | Blocked-unproven (canvas pin placement). |
| World markers (star/diamond/triangle/moon) | Blocked-unproven | No marker API evidence. |
| Automatic navigation tied to NOW | Missing | Built-in waypoint proven; lifecycle absent (stale waypoint bug). |
| Codex-owned arrow | Partial | M8.14 probe v0.2; real-client result outstanding. |
| Tooltips | Missing | Window shows raw text instead. |
| Compact player UI | Missing | Current UI exposes developer detail. |
| Movable/resizable/saved geometry | Partial | Movable; not saved/resizable. |
| Draggable minimap button | Missing | |
| First-run setup | Missing | |
| XP/hr display | Partial | TelemetryMetrics computes it; no display; XP events unproven. |
| Appendices | Missing | |
| Character knowledge (trainer/recipe/flight discovered) | Missing | APIs unprobed. |
| Journey | Missing | Telemetry log is a capped session buffer, not history. |
| Party awareness | Partial | Context reads group size only. |
| Telemetry foundation | Exists | Needs coverage additions (section 7). |
| "Help Improve Codex" UI | Missing | |
| Provenance model | Exists | |
| Diagnostics | Exists | Good; keep as the developer surface. |

## 5. Architecture conflicts

1. **Plan shape.** The engine returns `next + sequence + nearby`. The vision needs `now + alsoDo(0..3) + then(0..n)`
   with reasons structured as data (not display strings). Current `reasons` are free-text arrays and are
   rendered directly, which is why the UI shows scoring text.
2. **Greedy per-action scoring.** Base scores (`TURN_IN=100`, `OBJECTIVE=70`...) make a completed quest always beat
   nearby work. Cannot express "finish the objective on the way", "delay the turn-in to batch", "chain value".
3. **One target per action.** A quest with objectives in a cave and a turn-in elsewhere is one pin. Needs
   `targets[]` with a role (giver / objective / turn-in) and a current-target selector.
4. **Giver = turn-in assumption.** Baked into `Providers/Quest.lua`; the UI hides this by wording ("objective area").
5. **Presentation strings produced in providers.** Provider text such as "(ATT, unverified on Forever)" leaks
   provenance into player-facing copy. Presentation must move to a UI/tooltip layer that reads structured fields.
6. **Navigation is UI-driven.** `MapPin.Place` is called only from a button. Navigation must follow an action
   ID owned by the planner (this is also the stale-waypoint root cause: `Clear` is never called).
7. **Window is monolithic and fixed.** One 500x668 window holds NOW, pickers, systems grid, buttons, source and
   status lines. Settings, systems and diagnostics belong in separate surfaces.
8. **Telemetry log is a ring buffer.** Journey and "what Codex learned" need durable, compact, per-character
   records. The 300-event session buffer cannot be a history store. Do not replace it; add a sibling store.
9. **Context lacks state the planner now needs** (inventory, money, dead/ghost, trainer/known spells, discovered
   flight nodes, bind location, group members' quest state).
10. **Marker/map/navigation/tooltip responsibilities are not separated** because only one of them exists.
    Define the four roles now (section 9) so none of them absorbs another.

Classification: items 1, 2, 3, 4, 6 are **architecture blockers** for the redesign (they change data shape);
5, 7 are **refactors**; 8, 9 are **additive**.

## 6. Proposed module boundaries

Principle: no module over ~400 lines or ~30 upvalues; each layer only reads the layer above it in the list.

```
World/Data  ->  Character Context  ->  Candidate Actions + Knowledge  ->  Planner  ->
  Navigation / Markers  ->  UI / Tooltips / Journey / Appendices        (Telemetry observes independently)
```

| New / changed module | Responsibility | Status |
|---|---|---|
| `Data/*` packs | World facts with provenance | Exists; schema additions (section 7). |
| `Knowledge.lua` | Per-character observed knowledge: trainers seen, recipes/spells known, flight nodes discovered, quest states. Source-labelled. | New |
| `Context.lua` | Snapshot only; extended fields; no logic | Extend |
| `Providers/*` | Emit candidate actions with structured fields (no display text) | Change |
| `Planner/` (separate from `Engine.lua`) | Short-sequence planner producing `now / alsoDo / then` with structured reasons | New; Engine kept as the strategy-weighted candidate scorer and used as the "single-action scorer" the planner calls |
| `Planner/Sequence.lua`, `Planner/Cost.lua` | Sequence search and cost model (travel, interruption, batch) | New (small) |
| `Navigation.lua` | Owns active navigation target; follows `plan.now.id`; clears on completion/invalidity; backends: built-in waypoint (proven), Codex arrow (later) | New (wraps MapPin) |
| `Markers.lua` | Strict attention markers (star/diamond/triangle/moon) | New, gated on investigation |
| `QuestMap.lua` | Quest overlay on the world map | New, gated on investigation |
| `UI/Window` split | `UI/Now.lua` (NOW/ALSO DO/THEN/XP-hr), `UI/Settings.lua`, `UI/Appendix/*.lua`, `UI/Tooltip.lua`, `UI/Frame.lua` (geometry, saved size/position) | Split |
| `Journey.lua` | Durable per-character history store + readers | New |
| `Party.lua` | Group state tracking and notifications | New, gated |
| `Telemetry*` | Unchanged core; new event types registered through the existing `EVENT_DEFS` | Extend |
| `Diag.lua` | Developer surface; receives everything removed from the normal UI | Keep |

The Planner is a **separate module** (as concluded in the planning model). Engine.lua is not deleted; it becomes
the per-action scoring provider the planner consumes, so no working system is thrown away.

## 7. Proposed data-model additions

Packs (additive, backwards compatible, `src`/`verified` per field preserved):

- Quest: `giver = {npc, loc}`, `turnin = {npc, loc}` (turn-in may be `nil` = unknown), `objectives[] = {kind, target, loc[], count}`,
  `chain = {prev, next}`, `xp` (nil if unknown), `faction/class/race gates`, `breadcrumb`. Unknown fields are absent, never defaulted.
- NPC: `id`, `roles` (`giver`, `turnin`, `trainer`, `vendor`, `inn`, `flight`, `graveyard`), each role with its own provenance. ATT supplies essentially none of vendor/trainer/inn/graveyard (only 14 flight paths), so role data will come from observation.
- Quest identity: always numeric quest ID in keys, saved state, overrides, telemetry. Never name (Sarkoth, Simple Parchment).
- Action: `id`, `type`, `ref`, `targets[] = {role, map, x, y, src, verified}`, `state`, `xp`, `reasonCodes[]` (data, e.g. `{code="ON_THE_WAY", ...}`), no display text.
- Plan: `{ now, alsoDo[], thenList[], dropped[] (with reason codes), strategy, ctxStamp }`.
- Character knowledge (per character, SavedVariables): quest states by ID, discovered flight nodes, trainers visited (npc id + date), recipes/spells known, first-seen timestamps. Each entry carries `src=observed`.
- Journey (per character, durable, compact): milestone records only (level reached, quest turned in, flight node discovered, trainer found, recipe learned) with timestamp and level. Counts come from records; never invent metrics.
- Observed-location store: where Codex observed an NPC/objective/quest board (e.g. Thazz'ril's Pick). Stays `observed`, local, never merged into ATT records. Contributing it back goes through the opt-in flow only.
- Preferences additions: UI geometry (size, position, minimap angle), party-notification mode (Off / UI only / Party chat / Both), telemetry opt-in flags, first-run-done flag, quest-view mode.
- Telemetry additions (registered as UNPROVEN until seen): `LEVEL_BREAKPOINT_CHECK`, `DEATH`/`RESURRECT`, `TRAINER_OPENED`, `SPELL_LEARNED`, `TAXI_NODE_DISCOVERED`, `MONEY_DELTA`, `GROUP_CHANGE`, `PLAN_NOW_CHANGED` (action id + reason codes, no raw scores), `NAV_TARGET_SET/CLEARED`. Each with a verified flag via the existing `EVENT_DEFS` mechanism.

## 8. Proposed planner architecture

Pipeline: `Context + Knowledge -> Providers (candidates) -> Eligibility filter -> Single-action value (Engine, strategy weights) -> Sequence search -> Role assignment -> Plan`.

- **Value vs cost split.** Engine computes value per action (XP, chain, progression). `Planner/Cost` computes marginal cost given the previous action: travel, interruption (leaving the current area/combat), turn-in delay savings.
- **Short sequence, not ranking.** Bounded beam/DFS over the top K candidates (K about 12) to depth 3; pick the sequence with best value per minute. Depth and K are constants so cost is predictable.
- **Role assignment.** `now` = first element; `alsoDo` = actions whose marginal detour cost is small relative to value (cap 3, empty is normal); `then` = remaining sequence tail, optional, may be empty.
- **Terms to include (all as data weights per strategy, not per-strategy databases):** travel distance, local density, quest-chain value, prerequisites, level breakpoints, group state, class/profession/pet progression opportunities, delay-turn-in batching, observed performance (TelemetryMetrics, only when `value ~= nil`), strategy.
- **Strategy = weight set + filters.** Balanced, Fast, Questing, Completionist; later Group/Dungeon, Hardcore-aware (adds risk terms). No per-strategy route data.
- **Completed quests are never actionable** (hard filter, not a score).
- **Stability.** Hysteresis: `now` changes only if the new best exceeds the current by a margin or the current becomes invalid. Prevents marker/waypoint flicker.
- **Explainability.** Every plan element carries `reasonCodes`; tooltips render them; Diag prints them.
- **Unknown handling.** Missing XP or location lowers confidence and is surfaced as "unknown", never filled in.
- **Pure function, stub-testable**, like Engine today.

## 9. Proposed map / world-marker architecture

Four distinct roles (all derived from the plan, none inventing data):

| Surface | Meaning | Source |
|---|---|---|
| Quest Map | what exists | Packs + Knowledge, filtered |
| World markers | what Codex wants noticed | `plan.now`, `plan.alsoDo[1]`, flight/inn singles |
| Navigation | where to go | `plan.now` target |
| Tooltip | why | reason codes |

Quest Map: filter set (available / active / turn-ins / objectives / Codex recommendations / optional opportunities / completed / unverified-unknown), each filter a predicate over actions + knowledge state. Pin source is the same action/target model; it must work with data of any provenance and visibly distinguish unknown. Implemented independently of Questie; concept only.

World markers (strict): star = NOW (max 1), diamond = ALSO DO (max 1, only when useful), green triangle = single relevant flight path, moon = single relevant inn. One marker per symbol, auto-moved/removed by `Markers.Sync(plan)`, driven by plan change events, not by UI. If a marker cannot be placed (see investigation), the planner output is unaffected; markers are a pure sink. Do not assume raid-target APIs work on arbitrary NPCs/world objects on Forever. The inn marker needs inn location data that ATT does not provide, so it depends on observed data or bind-location knowledge.

## 10. Proposed tooltip architecture

- A single `UI/Tooltip.lua` that renders from structured fields: quest state, objectives, chain position, rewards, prerequisites, discovery state, "Why am I seeing this?" built from `reasonCodes` with a code-to-sentence table (localisable, testable).
- Normal tooltips never show IDs, provenance flags, raw scores or map IDs. A diagnostics modifier (e.g. `/codex debug tooltips`) adds them.
- Attaches to Codex frames first (own `GameTooltip` use: proven class of widget but not probed on Forever). Hooking world-NPC or map-pin tooltips is **Investigate**.

## 11. Proposed Journey architecture

Durable per-character store `Journey` of milestone records written by an observer that listens to the same events as Telemetry but stores only milestones. Readers: Appendices > Journey page. Only recorded facts appear; performance numbers come from TelemetryMetrics with their observed/calculated/estimated label or are omitted. Capped by compaction (keep milestones, drop high-frequency detail). No dependence on the planner.

## 12. Proposed Appendices / reference architecture

Navigation (top-level sections): Quests (Useful / All), Professions, Trainers, Pets, World, Journey, Settings, Data and Help Improve Codex, Search. Each section is a small module registered through the Registry (new extension point `appendices`) so future systems add pages without touching Window. Human-friendly state wording comes from one table mapping Knowledge states to text ("You did this", "In progress", "You haven't found this yet", "Available", "You can learn this", "You don't have this recipe", "Trainer discovered", "Flight path not discovered"). Sections with no data show an honest empty state. Knowledge feeds the planner as candidate actions (learn ability, discover flight path, learn recipe) valued by strategy; never forced completionism.

## 13. Proposed party-awareness architecture

- `Party.lua` tracks group membership and, only if proven, party quest progress and completion messages.
- Separate "my progress" from "party progress"; never merge them.
- Notification setting: Off / UI only / Party chat / Both. Default does not post to party chat.
- No raw player identities stored without demonstrated need; use per-session ephemeral keys, or hashed/slot index.
- Works with Codex absent on other players: base functionality uses only standard client events (party quest-log events, if proven). Addon-message sync between Codex users is an optional later layer, never required, and must coexist with Questie or no addon.
- Planner reads a small `ctx.group` summary (size, whether shared quests exist) only.
- Telemetry records group state changes (`GROUP_CHANGE`) without identities.

## 14. Proposed telemetry / "Help Improve Codex" architecture

- Keep `Telemetry.lua` and `TelemetryMetrics.lua` unchanged in role. Add event types via `EVENT_DEFS`.
- Page "Help Improve Codex / Codex learns from your adventures" lists only categories with data (counts from the real store; no invented numbers). Controls: View What Codex Learned, Export Data, Clear Data.
- Local recording and sharing are separate switches. Nothing uploads silently. Any upload is a future explicit opt-in with a visible preview of exactly what leaves the machine, following the ForeverRecorder harvest contract v1 (no names, no GUIDs).
- "Codex learned something new" toast comes from the observed-location/knowledge store (e.g. Thazz'ril's Pick), shown once, stored as `observed`.
- XP/hr display consumes `TelemetryMetrics.Summary` as is; if `value == nil`, show nothing.

## 15. Proven vs unproven Forever APIs

PROVEN on Forever: `QUEST_ACCEPTED(questID)`, `QUEST_TURNED_IN(questID, xp, money)`, quest-log diffing via
`UNIT_QUEST_LOG_CHANGED`/`QUEST_LOG_UPDATE` + `C_QuestLog.IsComplete`, `C_Map.GetBestMapForUnit`,
`C_Map.GetPlayerMapPosition`, `C_Map.GetWorldPosFromMapPos`, `SetUserWaypoint` + `C_SuperTrack.SetSuperTrackedUserWaypoint`
+ `UiMapPoint.CreateFromCoordinates` (map 1413), SavedVariables on `/reload`, `GetPlayerFacing`, texture `SetRotation`,
ASCII text (Unicode glyphs render as boxes: **do not use emoji or Unicode symbols in any UI string**), left/right click distinction, UnitGUID creature-id parse.

PRESENT (function exists, behaviour untested): `C_QuestLog.GetQuestsOnMap`, `C_QuestLog.GetMapForQuestPOIs`,
`C_TaskQuest.GetQuestLocation`, `GetQuestLogPortraitTurnIn`, `ClosestUnitPosition`, `ClosestGameObjectPosition`,
`C_TaxiMap.GetAllTaxiNodes`, `C_TaxiMap.GetTaxiNodesForMap`, `TaxiNodeName`, `TaxiNodePosition`.
ABSENT: `GetTaxiNodeCost`, `QuestPOIGetIconInfo`, `IsQuestComplete`, `GetQuestsCompleted`, `GetQuestLogPortraitGiver`.

UNPROVEN (investigate before depending): `PLAYER_XP_UPDATE`, `UnitXP/UnitXPMax`, `PLAYER_LEVEL_UP`,
`PLAYER_REGEN_DISABLED/ENABLED`, combat log (`COMBAT_LOG_EVENT_UNFILTERED`, `PARTY_KILL`), `UnitClass/UnitRace/UnitFactionGroup`
as used by Context (they are used, and the playtest worked, so effectively proven in practice but not formally probed), `GetBindLocation`, world-marker APIs
(`SetRaidTarget`, `SetRaidTargetIcon`, any marker on non-unit objects), `C_NamePlate`, GameTooltip hooks on world units, trainer/trade-skill/taxi window events and APIs,
spell-known APIs, inventory/money APIs, death/ghost/resurrect events, frame resize APIs (`SetResizable`, `StartSizing`, `SetMinResize`/`SetResizeBounds`),
party quest-log sharing events, addon-message comms, pin placement on the world map canvas, Codex-owned arrow conventions (M8.14 v0.2 pending).

Investigation plan: extend the existing M8.14-style probe pattern (a separate probe addon, one question per probe, real-client evidence stored under an `evidence/` folder) rather than speculating in the main addon. Suggested order: (1) resize + geometry saving (cheap, UI value); (2) XP/level/combat events (already used by Telemetry, confirm from its recorded `proven` flags); (3) trainer/spells/taxi-discovered/death/inventory events; (4) marker APIs; (5) quest-POI / map canvas pins; (6) tooltips; (7) party quest events.

## 16. Data / provenance considerations

- ATT-derived data stays `src=att, verified=false`; observed data wins field by field; both remain visible in Diag only.
- No Questie, QuestieDB, Wowhead, RestedXP, ForeverGuide or other questionable data. Questie is concept inspiration only: no code, structures, UI, assets or data copied.
- Player-facing text never says "ATT" or "unverified"; instead the UI shows a neutral "approximate location" / "location unknown" wording derived from the structured `verified`/`approx` fields, while tooltips in diagnostic mode show full provenance. Provenance is hidden, not removed.
- ATT redistribution remains a separate, undecided licensing decision. The addon package stays tester-only until decided.
- New durable stores (Knowledge, Journey, observed locations) are `observed` and per character; they never write back into packs.
- ATT has no turn-in NPC, no vendor/trainer/innkeeper/graveyard flags, 14 flight paths, and mostly raid NPCs: those capabilities depend on observation, so the design must be useful before they exist (graceful "unknown").
- Contributing observations back requires the explicit opt-in flow (section 14).

## 17. UI information hierarchy

Normal view, top to bottom: **NOW** (title, one short why line, distance as a coarse word or number), **ALSO DO** (0-3 lines, hidden when empty), **THEN** (small, collapsible, may be empty), subtle **XP/hr** line. Everything else is behind a tooltip, the Appendices, Settings or `/codex diag`.

Removed from the normal UI (kept in Diag/slash): coordinates, map IDs, source labels, verified flags, action IDs, technical quest states, scoring, raw reason arrays, "waiting", Show on Map / Skip / Add quest / Refresh. Skip and Add remain reachable via right-click context on a line and via slash commands, so player control is preserved.

Window: movable, resizable (min/max bounds, adaptive content), position and size saved per character or account (decision: account-level default, per-character optional later), clamped to screen on restore. Minimap button: draggable, angle saved, positioned relative to the minimap using the standard angle/radius approach so scale and resolution changes are safe. Existing theme/colours are kept; no logo yet.

First-run: a short "Here's your character" card, then route zone, strategy, systems and preferences, then the machinery hides; Settings reachable from Appendices.

## 18. Implementation dependencies

```
Structured action/plan shape  ->  everything below
  |- Quest data schema (giver/turnin/targets[])  -> planner terms, tooltips, quest map
  |- Navigation lifecycle (follows now.id)       -> markers, arrow
  |- UI split + geometry persistence             -> compact UI, first-run, Appendices
  |- Knowledge store + new context fields        -> trainers/recipes/flight in planner, Appendices, Journey
  |- Reason-code table                           -> tooltips, Why-am-I-seeing-this, Diag
Planner (sequence) needs: structured actions + cost model + (optional) Telemetry metrics
Markers need: stable plan.now/alsoDo ids + marker API evidence
Quest Map needs: target model + map-canvas evidence
Party needs: group events evidence + Context group extension
Help Improve Codex needs: Journey/Knowledge stores + export format decision
```

## 19. Recommended implementation order

1. Structured action/plan contract (`now/alsoDo/then`, `targets[]`, `reasonCodes`) and a thin adapter so the current UI keeps working.
2. Navigation controller bound to `plan.now.id` with a Clear-on-complete/invalid lifecycle (fixes the stale waypoint; uses the proven built-in waypoint only).
3. Compact NOW/ALSO DO/THEN UI, saved/resizable window, draggable minimap button, hidden developer details; player-control actions moved to context menu/slash.
4. Planner v1 (short-sequence, hysteresis, completed-never-actionable) behind the Registry as a new strategy consumer; Engine retained.
5. Tooltips + reason-code table.
6. Knowledge store + Context extensions (only through APIs proven by probes), first-run setup.
7. Appendices shell (empty states first), Journey store, XP/hr line, Help Improve Codex page (local only).
8. World markers and Quest Map after their API investigations; Codex-owned arrow after M8.14 v0.2 results.
9. Party awareness last (most unproven, least critical).

## 20. What NOT to implement yet

- Any marker placement (no marker evidence; do not guess an API).
- Quest Map overlay, map canvas pins.
- Party chat posting or addon-message comms.
- Any upload, network, or auto-sharing path.
- Codex arrow as the default navigation (wait for the M8.14 v0.2 real-client axis/facing evidence).
- Trainer/vendor/inn/graveyard/profession/pet recommendations (no data; do not fake).
- Intentional-death shortcut suggestions (needs graveyard data plus a safety design; Hardcore interaction).
- Per-strategy route databases; any second hand-built route set.
- Any Unicode/emoji glyphs in UI strings (render as boxes on Forever).
- ATT data redistribution decisions; hand-adding observed coordinates to packs.
- Fixing the old 84-vs-96 dataset discrepancy; modifying frozen datasets, M8.13, M8.14, `_backup`, `_superseded`, `forever-db`.

## 21. Risks (ways to paint ourselves into a corner)

1. **Display strings in data/providers.** If providers keep emitting player text, tooltips and the compact UI will fight them. Mitigation: reason codes first.
2. **Name-keyed anything.** Same-name quests exist. Mitigation: IDs everywhere; test with the Sarkoth / Simple Parchment cases.
3. **One-target action shape** cemented by more features. Mitigation: `targets[]` before Quest Map/markers.
4. **Marker or arrow dependence on unproven APIs.** Mitigation: markers/arrow are pure sinks of the plan; the plan never depends on them.
5. **Upvalue/size creep** (the M8.13 UI reached 37/60). Mitigation: small modules, per-section files, registry-based appendices.
6. **Telemetry log reused as history.** It is capped and session-timed (`GetTime` resets). Mitigation: separate Journey store.
7. **Telemetry cost/SavedVariables bloat** as new event types arrive. Mitigation: caps per type, compaction, no raw GUIDs/names.
8. **Planner instability** (flicker). Mitigation: hysteresis, deterministic tie-break by ID.
9. **Over-claiming data.** Mitigation: unknown stays nil; a claims-scan test already exists and should be extended to the new wording table.
10. **Search cost** of the sequence search on every event. Mitigation: bounded K/depth, recompute only on meaningful context change, cache keyed by ctx stamp.
11. **Protected actions.** Any marker/waypoint/frame operation inside combat lockdown or on secure frames could be blocked. Mitigation: no secure-frame manipulation; defer non-essential UI work out of combat; investigate the existing login error first.
12. **Privacy** in party features. Mitigation: no identities stored; opt-in only.
13. **Licensing** drift if more third-party data is added. Mitigation: provenance gate stays in generator tests.

## 22. Milestone breakdown

- **M1: Contract and lifecycle.** Structured plan/actions, reason codes, navigation controller (stale-waypoint fix), thin adapter. Tests: ID identity, completed never actionable, nav clears on complete/invalid.
- **M2: Compact UI shell.** NOW / ALSO DO / THEN / XP/hr, resizable saved window, draggable minimap button, developer details moved to diag, player control via context menu/slash.
- **M3: Planner v1.** Sequence search, cost model, hysteresis, strategy weights extension; batching/interruption/chain terms using existing data.
- **M4: Tooltips and Why.** Reason-code renderer; diag modifier.
- **M5: Investigation probes.** Resize, events (trainer/spells/death/taxi/inventory), markers, map canvas, tooltips on world, party events. Evidence files stored; no feature code.
- **M6: Knowledge + first-run + Appendices shell + Journey store + Help Improve Codex (local).**
- **M7: Markers and Quest Map** (per probe results) and Codex arrow (per M8.14 results).
- **M8: Party awareness.**
- **M9: Opt-in sharing design** (separate from everything above; requires explicit decision).

## Per-feature decision table

| Feature | Decision | Exists | Missing | Investigate | Later |
|---|---|---|---|---|---|
| Planner | Separate module, Engine kept as scorer | Engine, Strategies | Sequence, cost, hysteresis | none | M3 |
| Plan shape | now/alsoDo/then with reason codes | next/sequence/nearby | codes, roles | none | M1 |
| Quest identity/state | ID + 6 states | partial | Blocked, Unknown first-class | none | M1 |
| Giver/turn-in | separate in schema; unknown allowed | assumed same | schema/data | observation | M1/M6 |
| Navigation | follows plan.now.id | built-in waypoint, MapPin | lifecycle | arrow (M8.14) | M1, arrow M7 |
| Markers | pure sink, 4 symbols | nothing | everything | marker APIs | M7 |
| Quest Map | same action model, filters | nothing | everything | canvas pins, quest POI APIs | M7 |
| Tooltips | structured, reason-coded | none | all | world-unit hooks | M4 |
| Compact UI | NOW-first; hide dev details | monolithic window | split, resize, save | resize APIs | M2 |
| Appendices | registry-extension pages | none | all | none | M6 |
| Knowledge | observed per-character | none | store + APIs | trainer/spell/taxi/recipe APIs | M5/M6 |
| Journey | milestone store | session telemetry only | store | none | M6 |
| Party | own system, no identities | group size | everything | party quest events, comms | M8 |
| Telemetry | keep, extend EVENT_DEFS | full foundation | new events | combat/XP proofs | incremental |
| Help Improve Codex | local first, opt-in upload later | export path via Diag | page, controls | none | M6, M9 |
| XP/hr | reuse TelemetryMetrics | calculator | display | XP event proof | M2 |

## Known issues: blockers versus enhancements

| Issue | Class | Note |
|---|---|---|
| Stale waypoint (`MapPin.Clear` never called; `Place` only from the button) | Blocker (fixed by M1) | Cause visible in code. |
| Protected-action login error ("blocked from an action only available to the Blizzard UI") | **Unresolved, separate** | Player chose Ignore; addon worked through levels 1-5. The stub probe shows the load/login path makes only read calls plus one Minimap-parented Button; this does NOT identify the cause and no cause is asserted. Needs a targeted real-client bisect (disable modules by a debug flag, one at a time, with `/console scriptErrors 1` or an error-capturing addon to get the offending call and stack). Do before relying on any new frame/marker work. |
| UI too large, exposes developer detail | Blocker for the redesign (M2) | |
| Planner too greedy; completed-quest 100 dominates | Blocker (M3) | |
| One target per action | Blocker (M1 schema) | |
| Context lacks inventory/money/death/trainer/vendor/class-pet-profession state | Enhancement, gated by probes | |
| Telemetry coverage gaps | Enhancement | |

## Recommendation: first implementation milestone

**M1 + the visible half of M2, in that order, with no new unproven APIs:**

1. Introduce the structured plan/action contract (`now / alsoDo / then`, `targets[]`, `reasonCodes`, quest-ID state) behind an adapter so the existing window and Route keep working.
2. Add the navigation controller bound to `plan.now.id` using only the proven built-in waypoint, with clear-on-complete/invalid. This closes the stale-waypoint bug.
3. Only then rebuild the player-facing window compactly (NOW / ALSO DO / small THEN / XP/hr), saved and resizable, draggable minimap button, developer details moved to diag.

Run the targeted protected-action investigation in parallel as a separate, small task; run the M8.14 v0.2 real-client probe and the Codex 0.1 telemetry playtest checks, since both outcomes gate later milestones (arrow, XP/hr display).

Do NOT begin markers, Quest Map, party features or sharing in the first milestone.
