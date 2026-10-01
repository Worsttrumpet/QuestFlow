# M8.2: Route & Navigation Architecture Reconnaissance

**Status: architecture/reconnaissance only. No implementation performed.** No route was invented, no
ordering was inferred, no coordinate was fabricated, and nothing outside this document was created or
modified.

## 1. Current state

Verified directly against the live files, not assumed:

| | Value |
|---|---|
| M6 observed quests | 153 |
| Guide-ready quests | 96 |
| `prerequisites` field resolved anywhere in M6 | **0 of 153** |
| M7.4 qualified ATT candidate pool | 1,102 |
| Candidates with any M6 evidence (M7.9) | 19 (6 guide-ready) |
| Candidates still unobserved | 1,083 |
| ATT `sourceQuest`/`altQuest` hints among the 1,083 unobserved | 604 (M7.10 §5) |
| Of those, hints pointing at an already-observed quest | 15 candidates (595 of the 604's reference instances point at *another unobserved candidate*, not at anything M6 has seen) |
| NPC world coordinates ever captured by the recorder | **0** — `PositionUtil.lua` captures only `UnitPosition`-equivalent data for `"player"`; this is stated in its own header comment and has been true since M4 |
| Map-pin/POI/MapCanvas API confirmed on Forever | **No** — M8.0 §2 lists this as the largest open unknown; nothing in six addons, two stub environments, or the vendored ATT `.toc` interface list names such an API |
| M8.1 addon status | Complete, real-client validated (`docs/M8_1_REAL_CLIENT_VALIDATION.md`): loads, displays 96 static quests, no navigation, no ordering, no map interaction |

The one-sentence version of this milestone's central fact: **the repository has quest content and, for 96
quests, enough evidence to describe them individually, but it has no route, no ordering signal strong enough
to build one, and no destination coordinate for anything other than the player's own past position.**

## 2. Route-step model recommendation

A route step should be the smallest unit of player instruction that can be displayed and (eventually)
progressed independently. Based on what the repository can actually populate today, the recommended step
shape is a plain, explicitly-typed record — not the exact type list in the M8.2 request, which mixes two
different concerns (action verbs like `TALK_TO_NPC`/`KILL` with lifecycle markers like `NEXT_ROUTE_STEP`):

```
RouteStep = {
  id:            string          -- stable, route-scoped identifier, never derived from quest ID
  kind:          one of {ACCEPT, TRAVEL, OBJECTIVE, TURN_IN, TALK}
  quest_id:      int | nil        -- present for ACCEPT/OBJECTIVE/TURN_IN steps that reference a quest
  npc:           {name, npc_id} | nil
  destination:   Destination | nil   -- see §3; nil is valid and must be handled, not treated as an error
  objective_ref: {objective_index} | nil  -- which of the quest's own objectives array entries this step tracks
  display_text:  string          -- author-facing text; never auto-generated from quest text alone (a quest's
                                     objective text describes the objective, not the instruction to reach it)
  next_step_id:  string | nil    -- explicit forward link; nil marks the end of a route
}
```

**Why five `kind`s and not more:** `ACCEPT`, `TRAVEL`, `OBJECTIVE`, `TURN_IN`, and `TALK` (a generic
NPC-interaction step for gossip-only content, which M7.10 established exists — quests reached only through
`GOSSIP_SHOW`) cover every capture checkpoint the recorder actually has evidence for
(`quest_detail`, `quest_progress`, `quest_complete_*`, `GOSSIP_SHOW`). `NEXT_ROUTE_STEP` from the prompt's
example is not a step at all — it's exactly what `next_step_id` already expresses, and modeling it as a
step of its own would let a route point at a step that does nothing, which is a bug waiting to happen, not a
feature.

**Which fields are optional:** `quest_id`, `npc`, `destination`, and `objective_ref` are all optional and
independently so — a pure travel step may have a destination but no quest; a `TALK` step (gossip-only
content) may have an NPC but no quest at all until one is offered. `display_text` and `next_step_id` are the
only two fields every step needs (the last step's `next_step_id` is `nil` by design, not an omission).

**How steps reference quests/NPCs/objectives:** by ID, always — `quest_id` is the M6 quest ID (an integer
already used consistently across `m6_guide_dataset.json` and the M8.1 `Data.lua`), `npc` is the same
`{name, npc_id}` shape M6 already stores under `giver`, and `objective_ref` is a zero-based index into that
quest's own `objectives` array (never a copy of the objective text, so a future M6 refresh that corrects
objective text doesn't silently orphan the reference).

**How steps link to the next step:** an explicit `next_step_id` string, not positional array order. This
matters directly for §10 (branching routes): a linked-list-by-ID structure supports a step having more than
one *route* point at it, and supports (later) a step conditionally linking to one of several next steps,
neither of which a plain ordered array can express without a redesign.

## 3. Route ordering model

**The route itself must be a separate, explicitly-authored object — never derived from the quest data.**
Recommended shape:

```
Route = {
  id:          string
  title:       string
  first_step:  string          -- id of the entry-point RouteStep
  steps:       { [step_id]: RouteStep }
}
```

A route is a graph entered at `first_step` and walked via each step's `next_step_id`, not an array. This is
the direct consequence of §2's linking choice, and it is deliberately **not** `route.steps = [step1, step2,
step3]` in array order — an array's order is easy to accidentally resort, filter, or regenerate, and nothing
in the existing M6/M8.1 pipeline pattern (deterministic *generation* from a canonical source) applies here,
because **there is no canonical source to generate a route from.** A route is hand-authored data, full stop;
its integrity depends on explicit links, not incidental array position.

**One quest in multiple steps or routes:** both must be supported, and the data model above already
supports both without change — nothing keys a `RouteStep` uniquely by `quest_id` (a step's own `id` is
separate), so quest 815 could appear as an `ACCEPT` step in a "Durotar levels 1–10" route and, independently,
as an `OBJECTIVE` step referencing a different objective index in a "pet battle" side-route, with no
collision. This is a design requirement to verify, not something this milestone builds.

## 4. Destination/coordinate model

This is the section where the repository's limits matter most, and where the M8.2 instruction not to assume
ATT coordinates are acceptable is directly load-bearing.

**What coordinate-shaped data actually exists**, classified exactly as the brief requests:

| Source | What it is | Classification |
|---|---|---|
| `interaction_position` (M6, all 96 guide-ready quests) | The **player's own** position at the moment they interacted with a quest, at a specific checkpoint (`quest_detail`, `quest_complete_*`, etc.) | **Observed** — but observed player history, not an NPC or destination location. Using it as a proxy for "where the giver stands" is a reasonable-looking shortcut this document explicitly declines to bless (see below). |
| ATT `location.att_coord` (per M7.10 §5, present for many candidates and some observed quests) | Coordinates ATT itself associates with a quest giver or objective | **Source-derived, unresolved provenance.** `docs/LICENSING.md` already flags ATT's own coordinate provenance as unresolved project-wide, independent of this milestone; M7.10 §5 additionally found ATT's `lvl` field disagrees with observed values by 1–8 levels in most cases where both exist, so ATT's own internal accuracy is not established either. |
| NPC world position (any NPC, any quest) | — | **Unavailable.** Never captured by the recorder at any milestone; `PositionUtil.lua`'s only call target has always been `"player"`. |
| Objective-area coordinates (a kill zone, a collection radius) | — | **Unavailable.** Nothing in M4–M7 ever attempted to capture one; ATT's `objective.att` hint (448 of the 1,083 unobserved candidates carry one, per M7.10 §5) names item/NPC/object target IDs, not coordinates. |

**Why `interaction_position` cannot stand in for a destination without saying so out loud:** it is real,
observed data, but it answers "where was the player standing when this fired," not "where should the next
player stand." Two independent players' first look at the same quest can differ by meters (M7.10's own
`interaction_position` classification is literally `position_variance` for some quests), and the position was
captured after the player had presumably already walked to the giver — it is evidence *of* a workable
approach, not a verified destination. **Recommendation:** it is usable as a first-pass, clearly-labeled
"approximate, player-observed" destination hint (better than nothing, honestly attributed), but the data
model must carry its provenance label (`observed_player_position`, not `npc_location`) all the way to the UI
layer, exactly as M8.1's own `Data.lua` header comment already insists interaction_position is "the player's
position at interaction, never the NPC's." A `Destination` record should therefore be:

```
Destination = {
  ui_map_id: int
  x, y:      float
  kind:      one of {OBSERVED_PLAYER_POSITION, SOURCE_DERIVED_ATT, ROUTE_AUTHORED}
}
```

`ROUTE_AUTHORED` is included because §11 requires a category for information the project explicitly adds
after establishing its own provenance (e.g., an operator manually confirms an NPC's actual position through
their own play and records it as such) — that is neither "observed" (the recorder didn't capture it) nor
"source-derived" (it isn't ATT's), and conflating it with either would misrepresent its actual origin.

## 5. Player-position findings

`C_Map.GetBestMapForUnit("player")` returns a `ui_map_id`; `C_Map.GetPlayerMapPosition(mapID, "player")`
returns a position object whose `:GetXY()` gives fractional (0–1) coordinates within that map — this is
exactly the format M6 already stores under `interaction_position`, which is itself produced by this same
API pair (`PositionUtil.lua`). So the *format* question is already answered by existing, real-client-proven
code.

**What is not answered:**
- **Cross-map distance/direction is undefined.** Two `(ui_map_id, x, y)` triples on different maps cannot be
  compared numerically at all — fractional map coordinates are per-map and have no shared origin. If the
  player is on Durotar's map (1411) and the destination is on Barrens' map (1413), there is no confirmed API
  in this project that converts either into a common frame. **This is the single largest technical gap for
  any arrow feature**, more so than the missing NPC coordinates, because even a perfectly accurate NPC
  coordinate would still need this conversion to be useful across a zone boundary.
- **Zone changes mid-route are not handled by anything existing.** Nothing in the recorder or the M8.1 addon
  reacts to `ZONE_CHANGED`-family events; this project has never hooked one.
- **Player-position unavailability:** `PositionUtil.Capture()` already handles this defensively (`SafeCall`
  wrapping, `map_ok`/`position_ok` flags) and simply records the failure — a future navigation feature can
  reuse this exact pattern, but "reuse the pattern" is a design note, not evidence that a live navigation
  frame would behave identically to a one-shot capture called from a quest event.
- **Sufficiency for a directional arrow:** **not established.** The two confirmed APIs give the player's own
  position in their own current map. That is necessary but not sufficient — a same-map arrow (destination on
  the map the player is already standing on) is plausible from these two APIs alone; a cross-map arrow needs
  an unconfirmed additional capability (§4/§5 above).

## 6. Directional-arrow requirements (design only)

Minimum information to compute, assuming same-map only (per §5, cross-map is unresolved):

- Player `(ui_map_id, x, y)` — confirmed available, live, every frame if needed (`C_Timer.After`-driven
  polling, following the recorder's own confirmed usage of `C_Timer`).
- Destination `(ui_map_id, x, y)` with its provenance label (§4) — available only for the subset of content
  with an `interaction_position` or an accepted ATT coordinate; **unavailable for most unobserved content**.
- **Direction**, if both points share a `ui_map_id`: `atan2(dest.y - player.y, dest.x - player.x)`, adjusted
  for the fact that WoW's fractional map coordinates place `y` increasing *downward* (south), which any
  future implementation must account for explicitly rather than assume — this project has not verified the
  axis convention against a real facing/heading value, only against relative positions.
- **Distance**: converting a fractional coordinate delta into yards requires the map's real-world dimensions
  (`C_Map.GetMapWorldSize` or equivalent) — **not referenced anywhere in this project**, confirmed or
  otherwise. Without it, a "125 yd" label like the prompt's example cannot be produced honestly; only a
  relative closer/farther signal could be, and even that is unverified.
- **Destination reached**: a distance threshold against the (unverified) distance calculation above.
- **Off-map / different-map destination**: detectable trivially (`ui_map_id` mismatch) even without solving
  cross-map distance — the arrow feature can and should distinguish "same map, here's a direction" from
  "different map, direction unavailable" rather than guessing or hiding the distinction.
- **Off-route**: not a geometry question at all — it requires knowing which step is "current" (§9), which
  this section does not attempt to solve.

No arrow code was written. This is the requirements list a future milestone would need to satisfy.

## 7. Marker model

A marker is a presentation concern layered on top of a `RouteStep.kind` (§2), not a new data type. Each
`kind` maps to exactly one marker glyph for UI/list display purposes (⭐ for `ACCEPT`/`TALK`/`TURN_IN`, ⚔️
for `OBJECTIVE` steps whose quest data shows a kill-type objective, 📍 for `TRAVEL`), which is a pure
presentation-layer lookup table, not new state. **Map/minimap markers are a different matter entirely**:
placing an icon on the world map or minimap requires the same unconfirmed map-pin API §4/M8.0 already
flagged as the project's largest open unknown, so a map/minimap marker cannot be designed further than "it
would need the same coordinate this section already can't always supply, plus an API this project has never
confirmed exists." UI-list markers (next to route-step text, exactly like M8.1's plain-text quest rows) need
nothing beyond what M8.1 already proved works (`CreateFontString`, plain text) — emoji glyphs render as plain
text characters if the font supports them, which is itself unverified on Forever and would need its own
one-line real-client check before relying on it, separate from anything else in this document.

## 8. Quest-state findings

Per-event, checked against exactly what M8.0/M7.6/M7.7 established was actually observed firing (not merely
"exists"):

| Signal needed | Status | Basis |
|---|---|---|
| Quest accepted | **Currently unavailable as a live signal.** `QUEST_ACCEPTED` is confirmed to exist as an event name (M7.6) but has never been hooked or observed firing by any project addon. | M8.0 §2 "confirmed present but not hooked" |
| Quest offered/in dialogue | **Confirmed.** `QUEST_DETAIL` fires and supplies a quest ID via `GetQuestID()`. | M7.6, M7.7 real-client validation |
| Quest in progress, objective counts | **Confirmed**, with a caveat: `QUEST_PROGRESS` fires and supplies live `C_QuestLog.GetQuestObjectives()` data (M7.7's real 815/96825 captures show real progress counts, e.g. `2/8`) — but M7.7 explicitly notes this was validated on **incomplete** quests only; whether a *ready-to-turn-in* quest still fires `QUEST_PROGRESS` or goes straight to a reward screen was never tested. | M7.7 completion report §5 "what remains unresolved" |
| Ready to turn in | **Possible but unverified.** No project code has ever checked this distinctly from "quest complete" below. | — |
| Completed / turned in | **Confirmed** — `QUEST_COMPLETE` and `QUEST_TURNED_IN` both fire and are hooked (M7.6/M7.7). | M7.6, M7.7 |
| Skipped or abandoned by the player | **Currently unavailable.** No event for this has ever been named, tested, or hooked anywhere in the project. | — |
| A quest already in the player's log at addon load (before any event fires) | **Confirmed available in principle** via `C_QuestLog.GetInfo`/`GetNumQuestLogEntries` (used by the recorder's own `QuestMeta.lua` to *look up* a quest by ID), but **never used to enumerate the whole log** — only to find one specific already-known ID. Whether scanning the whole log for arbitrary route quests behaves the same way is unverified. | `QuestMeta.lua` (`findQuestLogIndexByID`) |
| Quest-log capacity/size as a state signal | **Confirmed available** (`GetNumQuestLogEntries`), but no project code has used its value for anything except iterating to find one ID. | Same |

**What cannot be assumed:** that these events, taken together, are *sufficient* to reconstruct a specific
route step's state without gaps. In particular, a player who accepts a quest while the addon is closed, or
who reloads mid-quest, presents a state the addon cannot reconstruct purely from events (since
`QUEST_ACCEPTED` isn't hooked) — it would need to fall back to scanning the quest log at load (unverified for
this purpose, as above).

## 9. Route progression model

Comparing the three options against what's actually confirmed:

| Option | What it needs | What's confirmed | Verdict |
|---|---|---|---|
| **A. Fully automatic** | Reliable accept/progress/complete/abandon signals for arbitrary quests | Accept and abandon are **not** confirmed (§8); progress and complete are confirmed but only for quests already known to the addon *and* only tested on incomplete quests | **Not supportable today.** The addon cannot safely advance a route step it can't confirm the player actually accepted. |
| **B. Semi-automatic** (addon suggests, player confirms) | The same signals as A, but treated as suggestions rather than authoritative | Same gaps as A, but a wrong suggestion is a UX annoyance, not silent incorrect state | **The best fit for what's confirmed today** — it can use `QUEST_PROGRESS`/`QUEST_COMPLETE`/`QUEST_TURNED_IN` (all confirmed) to *suggest* "looks like you finished this, advance?" while still requiring the player to confirm, which absorbs the `QUEST_ACCEPTED` gap by simply not needing to detect acceptance automatically. |
| **C. Manual** ("Next" button) | Nothing beyond what M8.1 already has (a click handler) | Fully confirmed, already proven in M8.1 | **Zero new API risk**, but the least helpful UX of the three. |

This is a tradeoff description, not a recommendation to pick one now (per the instruction not to choose
based on preference) — but it is worth noting plainly that **Option A cannot currently be built honestly**
given the confirmed API surface, which narrows the real decision to B vs. C, or a C-now/B-later sequencing.

## 10. Off-route behavior considerations

Every scenario listed in the request maps to a state the route-progression model (§9) would need to
represent, none of which exists yet:

- **Walked somewhere else / skipped / abandoned:** requires detecting divergence from the "current step,"
  which requires knowing what the current step even is (§9's core problem) before it can be compared against
  anything.
- **Completed a quest early** (e.g., turned in without the addon walking them through it): confirmed
  detectable via `QUEST_TURNED_IN` (§8) even if the addon wasn't "watching" that step, *if* the route data
  model can map a `quest_id` back to whichever step(s) reference it (§2's `quest_id` field already supports
  this lookup).
- **Logs in somewhere unexpected / mid-route:** falls back to the quest-log-scan question flagged as
  unverified in §8.
- **Dies and respawns / changes zone:** zone-change detection is unhooked project-wide (§5); death/respawn
  events have never been referenced by any project addon and are simply unresearched here — an explicit gap,
  not a finding.
- **Manually completes a later quest:** same lookup as "completed early," but for a step further ahead in
  the route than the one currently marked active — the data model doesn't prevent this, but nothing tracks
  "which step index is active" today, so there is nothing yet for this event to update.

**What state the addon would need to track**, at minimum: a `current_step_id` per route per character (this
alone argues for *some* persistence, which reopens the M8.0-documented, twice-reproduced logout/
character-select SavedVariables failure with an unknown root cause — a real constraint on any progression
design, not a hypothetical one).

## 11. Multiple-route considerations

The `Route`/`RouteStep` model in §2–3 supports every variant listed structurally (a route is just a named
graph of steps; nothing prevents authoring several):

- **Leveling / zone / class-specific / faction-specific routes:** each is simply a different `Route` object;
  no schema change needed.
- **Optional branches / alternates:** requires a step to have more than one valid `next_step_id` with a
  selection rule — not supported by the single `next_step_id` field in §2 as written, and this document does
  not propose extending it now (an unused capability is better than a speculative, untested one); flagged
  here as a known extension point.
- **Skipped quests / recovery after leaving the route:** a progression-engine concern (§9/§10), not a data-
  model concern — the graph structure doesn't block recovery, but nothing here designs how recovery would
  actually pick a re-entry step.

**Conclusion:** the base data model can support these without a redesign; the progression *engine* (§9) is
where most of the unbuilt complexity actually lives, not the data shape.

## 12. Evidence and licensing boundary

Extending M6/M7's existing three-tier distinction (observed / source-derived / derived-guide-readiness) with
exactly one new category, `route-authored`, as required:

| Category | Definition | Existing precedent |
|---|---|---|
| **Observed guide data** | Recorder-captured, M6-pipeline evidence (title, level, objectives, giver, interaction_position, etc.) | Already how M6/M8.1 work; unchanged |
| **Source-derived candidate data** | ATT or other external, unverified data (coordinates, level hints, restriction flags, prerequisite hints) | Already how M7.3/M7.4/M7.9/M7.10 treat ATT; unchanged |
| **Route-authored information** | Anything a human explicitly adds to build a route — step ordering, `display_text`, a manually-confirmed destination, a chosen `next_step_id` — recorded with its own provenance, never silently blended into "observed" | **New category this milestone introduces**, needed because a route step's *existence and order* is neither recorded by the recorder nor sourced from ATT — a human decided it, and the data model must say so |

**Where this must show up concretely:** every `RouteStep` and every `Destination` record needs a provenance
tag (§2's implicit `kind`, §4's explicit `kind` field) that survives all the way to the UI, exactly as M8.1's
`interaction_position` already carries "player position, not NPC" through to its own header comments. A
route-authoring tool (future work, not this milestone) must never be able to write a `Destination` tagged
`OBSERVED_PLAYER_POSITION` from a value the author typed in by hand.

**Restated, unchanged by this milestone:** ATT candidate coordinates and quest relationships remain
source-derived, never promoted to observed; no RestedXP/ForeverGuide/Questie/Wowhead/Wago data was
introduced or considered; no licensing decision was changed. `docs/LICENSING.md` was read, not modified.

## 13. Available vs. missing data (gap analysis)

| Category | Items |
|---|---|
| **Already available** | Quest identity/level/objectives/giver for 96 quests (M6, `confirmed`); the player-position API pair (`C_Map.GetBestMapForUnit`/`GetPlayerMapPosition`, real-client confirmed); `QUEST_DETAIL`/`QUEST_PROGRESS`/`QUEST_COMPLETE`/`QUEST_TURNED_IN`/`GOSSIP_SHOW` events (confirmed firing); the M8.1 addon's namespace/data-loading pattern to extend |
| **Available but needs validation** | Whether `QUEST_PROGRESS` fires for a ready-to-turn-in quest (M7.7 gap); whether a full quest-log scan (not single-ID lookup) behaves reliably; whether emoji glyphs render via the confirmed `GameFontNormal` path; same-map arrow math once someone actually measures it against real player movement |
| **Needs new data collection** | NPC world coordinates (never captured, would need new recorder work — explicitly out of scope for M8.2 and not requested here); objective-area coordinates; a validated, non-ATT source for any of the above |
| **Needs route authoring** | Every route's step ordering and existence, by definition (§12); `display_text` per step; which content warrants a route at all, given only 96 of 1,102+ candidates are guide-ready |
| **Unknown** | Whether cross-map distance/direction is computable at all without an unconfirmed API (§5); whether `QUEST_ACCEPTED` could ever be hooked reliably (existence confirmed, behavior never tested); whether Forever exposes any map-pin capability whatsoever (M8.0's largest standing unknown, unchanged by this milestone); the real-world yard-distance conversion (`GetMapWorldSize`-equivalent), never referenced anywhere in this project |

## 14. Recommended architecture

```
Quest Data (M6 guide-ready records, unchanged)
        │
        ▼
Generated Addon Quest Data (M8.1's Data.lua, unchanged — routes reference it, never duplicate it)
        │
        ▼
Route Data (NEW: hand-authored Route/RouteStep graphs, §2-3 — a separate generated-or-authored
             file, referencing quest IDs, never embedding a copy of quest content)
        │
        ▼
Route Progression State (NEW: which step is current, per route — the one piece of state that
             plausibly needs to persist, directly bumping into the unresolved SavedVariables
             logout issue from M8.0 -- a real open question, not solved here)
        │
        ▼
Navigation Target (NEW, same-map only per §5/6: resolves the current step's Destination against
             the player's live position when both share a ui_map_id; explicitly "unavailable" or
             "different map" otherwise, never a guess)
        │
        ▼
UI (extends M8.1's list/detail pattern with a route view; markers per §7 are a presentation
    lookup, not new state)
```

**Why this shape:** it inserts Route Data as a distinct layer *between* quest data and everything else,
which directly satisfies the instruction that route logic must not couple to the current 96-quest dataset —
a `Route` references quest IDs the same way regardless of whether 96 or 9,600 quests are guide-ready, and
nothing about the route schema changes as the evidence base grows. The one layer this document flags as
genuinely unresolved rather than merely "not yet built" is Navigation Target, because it depends on the
cross-map math gap in §5, which no amount of careful data modeling resolves by itself.

## 15. Proposed M8.3 scope

**Recommended: schema and one authored test route, UI only, no live navigation.** Concretely:

1. Define the `Route`/`RouteStep`/`Destination` schema from §2–4 as a small, tested Python or JSON-Schema
   definition (mirroring how `forever-db/schemas/harvest_observation.v1.schema.json` documents M4's own
   contract) — this is pure data-shape work, no game code.
2. Hand-author **one** short test route using only observed M6 fields already proven reliable — for example,
   a 3–5 step route built entirely from already-guide-ready quests sharing a giver or a tight level band
   (M7.10 §3 already identifies NPCs with multiple guide-ready quests, e.g. NPC groups with 4–6 ready
   quests), with every `Destination` tagged `OBSERVED_PLAYER_POSITION` (§4) — never inventing an NPC
   coordinate to make the route "complete."
3. Extend the M8.1 UI with a route-view panel that displays the authored route's steps in order (using
   `next_step_id` traversal, §2) with the §7 marker glyphs — **static display only**, no progression, no
   arrow, no live quest-state reading.
4. A manual "Next"/"Previous" button (Option C from §9) to move between steps — the only progression
   mechanism with zero unresolved API risk.
5. Tests mirroring M8.1's own pattern: a generator/schema test suite plus a Lua execute-level self-test that
   loads the authored route and exercises Next/Previous without a real client.

**Explicitly excluded from M8.3** (deferred to whichever milestone actually resolves the relevant unknown):
automatic or semi-automatic progression (§9 Options A/B — blocked on `QUEST_ACCEPTED`), the directional arrow
(§5/§6 — blocked on cross-map math and distance-in-yards, neither confirmed), any map/minimap marker (§7 —
blocked on the map-pin API question), off-route recovery logic (§10), and any second or branching route
(§11) — one authored route is enough to prove the schema and UI layer work before investing in the harder,
still-unresolved pieces.

## Out of scope for M8.2

Nothing was done from this list; restated for the record: M6/M7/recorder modification, recorder hooks, new
quest collection, CollectionRuns, guide-readiness rule changes, ATT ingestion changes, Quest 792 `r5`
resolution, map pins, directional-arrow code, any automation, CurseForge publishing, third-party data,
licensing changes, invented route ordering, invented prerequisites, invented NPC or objective coordinates.

## Final recommendation

Proceed to M8.3 as scoped in §15: schema plus one honestly-sourced authored route plus static UI, explicitly
deferring both the progression engine (blocked on `QUEST_ACCEPTED`) and the navigation/arrow feature
(blocked on cross-map math and an unconfirmed distance API) until those specific unknowns are investigated on
their own terms. Building the data model and UI first, on data whose provenance is already fully understood,
avoids designing around capabilities this project has not yet confirmed exist.

**M8.2 STATUS: COMPLETE**
