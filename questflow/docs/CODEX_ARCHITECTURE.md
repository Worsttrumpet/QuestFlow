# Forever Codex 0.1 "First Light": architecture

Forever Codex is a **dynamic, character-aware progression companion** for WoW Classic Forever. It answers
"what should this character do next?" and the **player stays in control**: Codex recommends, the player can
override, skip, add, ignore, change route zone and style, and toggle systems. Everything recalculates around those
choices. It is read-only with respect to the game (never accepts, completes or turns in quests; the only visible
effect is the map waypoint the player asks for with "Show on Map").

This is a local development build. Data is partial and **ATT-derived data is shown as unverified**.

## Data flow

```
ATT 'forever' DB (local, read-only) --\
                                       +--> generator/build_codex_data.py --> ForeverCodex/Data/Pack_*.lua   (separate layers)
M8.13 observed quest table (read-only) /                                            |
                                                                                    v
 character / location / quest log --> Context.Build --> Engine.Compute --> plan --> UI / Slash / Diag
   (read-only client calls)               ^                  ^
                                          |                  +-- providers (quest, flight, ...planned) via Registry
                              Preferences (the player's choices: route zone, style, systems, skips, added quests)
```

## Modules (ForeverCodex/)

| File | Role |
|---|---|
| `Core.lua` | namespace, chat output, `Safe` call helper, error ring for diagnostics |
| `Registry.lua` | **every extension point**: data packs, merged quest view, zones, action types, systems, providers, strategies, `NewAction` |
| `Preferences.lua` | the one SavedVariable (`ForeverCodexDB`), per character: route zone, style, hardcore, systems, skips, added quests |
| `Strategies.lua` | route styles = scoring weights over the same actions (Efficient, Fast, Questing-only, Completionist active; Solo, Dungeon-friendly, Hardcore planned) |
| `Providers/Quest.lua` | quest data + quest log -> ACCEPT / TURN_IN / OBJECTIVE actions with eligibility |
| `Providers/Flight.lua` | nearby flight-node hints (ATT data; discovery status unknowable, said so in the UI) |
| `Providers/Planned.lua` | registers the planned systems/types **inert**: trainers, professions, gathering, camping, dungeons, pets, respawn skips, class progression, group |
| `Context.lua` | one read-only snapshot: character, location, quest log, completions, group |
| `Engine.lua` | stateless planner: collect -> filter -> score -> greedy chain from the character's position, travel insertion, "while you're here", in-progress list |
| `Route.lua` | adapts actions to the M8.13 step schema; evaluates progress with the M8.13 evaluators |
| `State.lua` | latest context/plan, throttled recompute |
| `Diag.lua` | `/codex diag`, `/codex report`: the bug-report snapshot |
| `Telemetry.lua`, `TelemetryMetrics.lua` | quiet observation log (XP, kills, combat, movement, quests) + pure, labelled calculators. Independent of the engine, strategies, UI and navigation; read by nothing yet. See `CODEX_TELEMETRY.md` |
| `UI/Widgets.lua`, `UI/Window.lua` | the window (only primitives proven on Forever in M8.x; ASCII only) |
| `Slash.lua`, `Boot.lua` | `/codex`, events |
| `ProgressionEval.lua`, `MapPin.lua`, `MinimapButton.lua` | **copied from M8.13** (renames only; a test proves it) |

## Concepts that must stay separate

* **Race origin** (what the character is) - read live, never used to pick a route.
* **Route zone** (where the player chose to level) - a per-character choice, `auto` = follow the current zone.
* **Current location** - read live.

A Troll Warrior can choose Stranglethorn (or the Undead start zone) as the route zone while standing anywhere;
an explicit route zone carries a strong bonus (`routeZoneBonus`) so the player's choice wins over convenience.

## Provenance (non-negotiable)

Every pack declares `meta.src` (`att` | `observed`) and `meta.verified`. ATT packs are `src=att, verified=false`;
the observed pack is `src=observed, verified=true`. Layers are **never merged on disk**; `Registry.Quest(id)` merges
at read time by priority (observed 100 over ATT 10), field by field, recording which layer each field came from
(`prov`). Rules baked into the code and tests:

* ATT `lvl` is a **required level** (`req`), never a quest level. Quest level only comes from observed data.
* ATT coordinates are never marked verified. The observed layer's `pos` is a **player position** at a recorder
  checkpoint, used only as a labelled approximate fallback when ATT has no coordinate. It is usually the TURN-IN side's
  position, and the observed `giver` is usually the turn-in NPC: M6 displays the latest checkpoint's value. `verified=true`
  there means "recorded on Forever", not "NPC position". See `CODEX_OBSERVED_PACK_PROVENANCE.md`.
* Every action carries `src` / `verified`; the UI says "ATT - unverified on Forever" / "observed on Forever".
  No UI string calls ATT data confirmed (a test scans for it).
* Prerequisites come from ATT `sourceQuest`; when several are listed they are treated as ANY-OF (the parser cannot
  tell a single `sourceQuest` from a list) - this errs towards showing a quest.
* Turn-in location is **assumed** to be the giver's (ATT has no turn-in field) and the card says so.

See `CODEX_PROVENANCE_DECISION.md` for the ATT decision and what it does not decide.

## How to extend (no engine change)

* **More data:** generate/ship another pack and add one line to the `.toc` (a quest pack with `meta`, `zones`,
  `quests`; or a `flight` pack). New zones appear in the route-zone picker automatically. Observed Forever data
  (e.g. 20-30 content recorded by testers) becomes a new `observed:*` pack that outranks ATT per field.
* **A new system** (trainers, professions, camping, dungeons, pets, ...): register a provider with the same key as
  the planned entry and a `generate(ctx, env)` that returns actions (`Registry.NewAction`), set `planned = false` on
  the system. The toggle, the engine, hardcore filtering and "while you're here" already work for it.
* **A new route style:** `ForeverCodex.RegisterStrategy{key, label, active, w = weights, allow = types}`.
* **A new class system** (e.g. hunter pets): a provider + a system toggle, nothing class-specific in the engine.

## Telemetry foundation

A recorder of raw gameplay observations (`CODEX_TELEMETRY.md`) lets a future Fast strategy use the character's real
XP/minute, kill XP, combat/travel/downtime split and quest durations. It makes no decisions and nothing consumes it yet.

## Not in 0.1 (deliberately)

* **Guide arrow:** waits for the M8.14 probe v0.2 conventions (world axes, facing) to be measured on the real
  client. 0.1 uses the game's own waypoint arrow via "Show on Map" (proven in M8.6-B).
* Trainers, professions, gathering, camping, dungeons, hunter pets, respawn skips, class progression, group
  optimization: registered, greyed out, no data, no recommendations.
* Solo / Dungeon-friendly / Hardcore as full styles (the Hardcore *toggle* works and removes respawn skips).
* Hearthstone / bind detection, objective locations (only where ATT has them), turn-in NPCs, quest XP/rewards.
* Public redistribution of ATT-derived data (undecided; see the provenance decision).
* A feedback service: `/codex diag` / `/codex report` produce a self-contained report; nothing is sent anywhere.

## Known limits that affect testers

* Data covers what the pinned ATT snapshot (2026-09-26) contains: it may not include the new 20-30 Forever content.
  Codex still works with whatever it has; the player can Add quests by id, and quests in the player's own log are
  always shown (as reminders) even when unknown.
* SavedVariables: `/reload` saves are reliable on Forever; logout saves have failed intermittently (M8.0). Choices
  (zone, style, skips) may reset after a logout; nothing else is stored.
* `UnitClass` / `UnitRace` / `UnitFactionGroup` / `GetZoneText` / `GetSubZoneText` are standard Classic APIs not yet
  probed on Forever. If one is missing Codex reports it in `/codex diag` and does not guess.
