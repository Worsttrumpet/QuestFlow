# Forever Codex: recovered backlog (audit of the repository at 0.6.5)

## Executive summary

This is a recovered backlog of everything that was discussed, planned, proposed, deferred, partially built or put on the back burner for Forever Codex and the
surrounding ForeverQuestGuide / forever-db work, checked against the ACTUAL repository (code, docs, tests, build scripts, git history), not against memory.
Where the repository contradicts an older conversation, the repository wins and the old assumption is marked **STALE**.

It is a memory, not a plan: it assigns no deadlines, no version numbers and no agreed priorities. "Suggested priority" is a proposal for discussion only.
Some items were reconstructed from the project owner's own statements (which leave no trace in the repository); those are marked **[conversation only]**.

How it was built: every file under `forever-codex/` (addon, docs, tests, generator), the root `docs/`, `forever-db/` (docs, planning), and the milestone folders were
searched for TODO / FIXME / "later" / "future" / "planned" / "not yet" / "UNPROVEN", the design and roadmap documents were read, and each concept in the request was
searched for in code. No feature was implemented while writing this.

### Counts (as of this audit)

75 status-tagged items: BUILT 19, PARTIAL 21, UNBUILT 24, DEFERRED 4, NEEDS VERIFICATION 6, REJECTED / SUPERSEDED 1, IN PROGRESS 0. Plus 8 integration rows (H-02), 5 business / product ideas (L-01 to L-05, all
undecided) and 10 rejected / superseded entries (O-01 to O-10): 98 recorded entries in total. (C-12 was added after the 0.6.9 playtests; the audit itself dates from 0.6.5.) "BUILT" does not mean real-client validated; each item says what was and was not validated.

## Status legend

| Status | Meaning |
|---|---|
| BUILT | exists in the repository and does what the item says (real-client validation is noted separately) |
| PARTIAL | some real pieces exist; the item names exactly what is missing |
| IN PROGRESS | work has started and is not complete (none at the time of writing: the last releases were each finished) |
| DEFERRED | deliberately postponed with a stated reason; usually blocked on evidence |
| UNBUILT | discussed or designed; no implementation exists |
| NEEDS VERIFICATION | the repository cannot settle it (real-client evidence, a decision, or a stale document is needed) |
| REJECTED / SUPERSEDED | decided against, or replaced by something built later |

Suggested priority uses HIGH / MEDIUM / LOW / UNSET (UNSET = no basis yet for ranking).

## Established principles to preserve (section 0)

These are settled and are used to audit every item below.

1. **Codex is an assistant, not an authority.** The player may fish, explore, grind, ignore Codex, take a break or do anything unrelated. Codex never scolds, never nags, does not
   force a re-route, and treats the player's choice as an input, not an error. (Code: recomputation follows the player's real position; stickiness; Skip / Add / route zone /
   system toggles; no wording audited as scolding. Test: the UI text scans in `ui_polish_tests.lua`.)
2. **Don't optimize individual actions; optimize the opportunities the route creates.** Don't go out of your way for everything; just don't walk past free progression.
3. **One planner.** No second "Opportunity planner", no competing "best next action".
4. **Unknown is not absent. Runtime evidence beats assumption.** "We have a database record" is not "the Forever client showed us this" (offer evidence, provenance labels,
   `verified` flags, UNKNOWN states).
5. **Codex is the brain, not the organs.** Other addons provide information; Codex combines it. Do not turn Codex into a duplicate of What's Training?, GatherMate2, Bagnon, etc.
6. **No giant dashboard.** Keep recommendations contextual and understandable; hide machinery (the player UI shows no ids, scores or sources).
7. **Read-only toward the game.** Never accepts, completes or turns in quests; no protected or taint-prone APIs; no `COMBAT_LOG_EVENT_UNFILTERED`; ASCII-only UI.
8. **Provenance stays separate** (observed / QuestieDB / ATT / quest log / estimated); nothing from Questie, QuestieDB, RestedXP or ForeverGuide code or data is copied into Codex.
9. **No hardcoded external-rule assumptions** (no Classic class / race / armor / "every two levels" tables presented as Forever truth).
10. **No identity, no raw GUIDs stored; no automatic upload; export only by explicit opt-in.**

Audit of the code against these principles (findings, details in the items):
* Principle 4 is **weakly honoured by the planner today**: quests from the observed pack (`evidence=observed`, location approximate) are valued at full strength even when the
  character was never offered them (the Yorana Windyreed / Taming the Beast cases). See C-02.
* Principle 9 vs **NEW FOR YOU's "even levels only" trigger** (`NewForYou.lua`): the planning model says not to hard-code "every two levels" as a Forever rule. See A-01.
* Principle 6: `/codex report` is very large by design (a developer artefact); the player UI is compact. See K-07.

---

## A. Product-facing experience

### A-01 NEW FOR YOU
**Status:** PARTIAL (framework only; no content source)
* **Discussed:** a card telling the player about genuinely new or newly relevant things: new spells / abilities / training opportunities, newly relevant progression, new Codex
  capabilities, new information Codex learned, newly available quests, things that became relevant at a level-up.
* **What exists:** `NewForYou.lua` (event-driven provider registry, one card), the card in `UI/PageCodex.lua` (`W.STYLE_NEW`), a 60 s lifetime, a baseline rule (first context after
  login never fires). **Zero providers are registered**, so the card is always hidden ("NEW FOR YOU: hidden" in every report). A quests provider was deliberately removed (a
  level-up never shows a quest).
* **What remains:** a verified ability source (the only reliable one found in the investigation is a trainer-window snapshot; no `TRAINER_*`, `SPELLS_CHANGED` or
  `LEARNED_SPELL_*` event is registered, so the client's behaviour is unprobed); providers for professions / pets / travel; a source for "new Codex capabilities" and "new
  information learned" (does not exist); a decision on whether quests belong here (current code says no).
* **Dependencies:** the trainer / spell probe (E-01), A-02.
* **Why it matters:** the one place a returning player learns what is new for THEM.
* **Risks / questions:** the trigger fires only on EVEN levels, which is an observed pattern, not a Forever rule (CODEX_PLANNING_MODEL: "do not hard-code every two levels") **[STALE assumption in code]**.
  Re-leveling and `PLAYER_LEVEL_UP` are labelled UNPROVEN although level-ups were recorded in real reports.
* **Suggested priority:** MEDIUM (blocked on E-01). **Notes:** do not invent progression content.

### A-02 Coming Soon / What's New (product-facing status)
**Status:** UNBUILT
* **Discussed:** a product-facing page so the addon feels like an evolving product, not a debugging interface: Coming Soon, What's New, New For You, recently added intelligence,
  current development status. Names are not final.
* **What exists:** nothing by those names (searched code and docs). Related, not equivalent: the Appendices > Knowledge page lists what Codex "cannot yet see"
  (`Knowledge.lua`), the Help Improve Codex page, the version string in the header/minimap/login line, and `docs/CODEX_*` change notes (developer-facing). No in-addon changelog.
* **What remains:** a content source (curated text vs generated from release notes), a place in the UI (Appendices?), a rule for what counts as "new", and honesty rules
  (list only what is really built; "coming soon" must not promise).
* **Dependencies:** A-01, A-03 (look), K-05 (release process). **Why:** product feel; sets expectations about UNKNOWN. **Risks:** over-promising; maintenance burden.
* **Suggested priority:** LOW to MEDIUM. **Notes:** [conversation only] aside from the Knowledge page.

### A-03 Themes / visual identity
**Status:** UNBUILT (a fixed visual style exists; no theme system)
* **Discussed:** real themes (dark/light, a fantasy "Codex / book" look vs a clean game-UI look), colour configuration, polished iconography, consistent typography.
* **What exists:** five hard-coded card palettes (`W.STYLE_NOW / NEAR / DUNGEON / READY / NEW` in `UI/Widgets.lua`), own art for the minimap button / world-map button /
  arrow (generator `make_art.py`), own text icons ("bang", "query"), a Questie-style options window built from standard game templates. 0.5.5-0.6.3 improved information
  clarity, which is NOT a theme system. No theme selection, no saved style, no light variant, no typography system.
* **What remains:** a style table abstraction (palettes, fonts, icons), a chooser in Options, art assets, a decision on the aesthetic, glyph constraints (ASCII only; glyphs render as boxes on Forever).
* **Dependencies:** none technical. **Why:** identity; cosmetic supporter features could depend on it (L-02). **Risks:** asset licensing; font availability on Forever.
* **Suggested priority:** LOW (UNSET).

### A-04 Information clarity of the tracker
**Status:** BUILT (0.5.5 to 0.6.3)
* NOW / THEN / ALSO COMPLETE-PICK UP-DO / READY TO TURN IN, numeric distances ("~" for objective areas), NPC names only when named, quest level, short planner reasons,
  follow-up count ("opens N more quests"), heading from the whole carried set. Real-client screenshots confirmed the layout. Remaining polish is in A-05 / A-08.

### A-05 "Why" explanations and tooltips
**Status:** PARTIAL
* **Discussed:** reason codes rendered as short human reasons; hover tooltips; the future DECISION BASIS report section.
* **What exists:** reason codes in the planner (`diag.reasons`, `PlanAdapter` sentences), short reasons on ALSO rows (0.5.5), the `why` per NOW (shown in the report; the window
  deliberately does not draw it), a minimap tooltip, widget hover tooltips on the arrow.
* **What remains:** hover tooltips on tracker rows; the concise "DECISION BASIS" report section (investigation sketched it; not built); the `/codex report` reorganisation into
  CHARACTER / PROGRESSION / CURRENT QUESTS / ROUTE / OPPORTUNITIES / REWARD ADVISOR / INVENTORY / INTEGRATIONS / EVIDENCE / DATA QUALITY / DIAGNOSTICS (not done; today's report is
  a long concatenation).
* **Why:** trust and debuggability. **Suggested priority:** MEDIUM.

### A-06 XP per hour / measured rates display
**Status:** UNBUILT
* `TelemetryMetrics.lua` has calculators (XP/min, downtime share, quest durations, labelled observed/calculated/estimated) and `/codex telemetry summary` prints them; the
  player UI shows nothing ("XP tracker: not built or displayed"). XP_GAIN / LEVEL_UP / combat events record in real reports although the static capability table still says
  UNPROVEN (stale label). **Suggested priority:** LOW. **Depends:** B-08.

### A-07 World / Quest map experience
**Status:** PARTIAL
* **Exists:** a World page that lists what the data and quest log say about the current zone (a list, not a map); a world-map corner button (UNVERIFIED anchor on Forever).
* **Not built:** a Questie-like Quest Map; Codex map pins and automatic raid markers were built then REMOVED (see O-01, O-02).
* **Questions:** is a Codex quest map wanted at all given Questie exists (principle 5)? **Priority:** UNSET.

### A-08 Window behaviour (size, resize, position)
**Status:** NEEDS VERIFICATION
* Window position is saved; the tracker is fixed-width and fits its content; "resizable" was in the redesign plan and resize APIs were listed UNVERIFIED. Real-client reports
  show a stable tracker, but no resize feature exists. Confirm whether resizing is still wanted.

### A-09 Search / lookup
**Status:** PARTIAL: Appendices > Quests lookup (by name/id) exists; the design audit's "Search" across sections does not. **Priority:** LOW.

---

## B. Planner and opportunity intelligence

### B-01 Route-relative opportunity pricing and diagnostics
**Status:** BUILT (0.5.4), real-client validated on build 70205
* `chooseAlsoDo` prices every candidate against `player -> stop1 -> stop2 -> stop3`; every priced candidate is recorded (`diag.opps`) with extra seconds, insertion point,
  route relation (DIRECTLY_ON_ROUTE / RECONNECTING_DETOUR / AFTER_ROUTE), cost class (FREE / CHEAP / MODERATE / EXPENSIVE / UNKNOWN) and decision (ACCEPTED / OUTRANKED / TOO_FAR /
  LOW_VALUE / UNKNOWN_TRANSIT). Validated: Crab Season 279 yd = +2 s; The Turncoat 752 yd = +9 s.
* **Not derived:** a NEAR_ROUTE label (needs a distance threshold the planner lacks); backtracking shows only as larger cost. The cost classes are labels; the planner still decides by net value and the 30 s detour limit (`TOO_FAR`).

### B-02 Multiple on-the-way opportunities (beyond one ALSO DO)
**Status:** BUILT (0.6.0 to 0.6.3)
* `plan.onTheWay` carries up to 4 priced, normalised opportunities (`onTheWay[1]` is the ALSO DO); the tracker lists them (ALSO PICK UP / COMPLETE / DO); items after the last stop
  (`AFTER_ROUTE`) are carried but not shown. Real-client confirmed the layout and the heading logic.
* **Remaining:** none required; open design questions are in B-03 and B-14.

### B-03 Hub bundle pricing ("don't walk past free progression")
**Status:** PARTIAL (diagnosed only; NOT implemented)
* **Discussed:** a stop holding several useful actions should be valued as one trip (WHILE YOU'RE HERE).
* **What exists:** stops already aggregate actions within 60 yd (value and dwell sum), so a hub competes in the sequence search as one stop and cluster stops do become core stops
  (e.g. the 3-pickup and 6-action hubs in real routes). `diag.opps.hubs` prices OFF-route stops with 2+ actions as one trip (diagnostic only). Real evidence: a 2-objective stop
  (+33 s) is net +14 as one trip while each member is TOO_FAR; 3-pickup stops +39.7 / +34.1 / 2-pickup +22.9 while each item is TOO_FAR at 40-61 s (each item's own net is above the
  5-point floor; only the 30 s limit rejects them).
* **What remains:** a net-based (not hard-seconds) decision for bundles in the ALSO DO/on-the-way pricing; a hub presentation row; stop-radius question (60 yd vs a larger hub
  radius, needs real data); golden-baseline review because it changes behaviour.
* **Dependencies:** B-01/B-02 built. **Risks:** over-recommending; flicker. **Priority:** HIGH (already named "next major phase" by the project owner). **Notes:** do not change `TOO_FAR` for single items.

### B-04 Local hub mode / local progression
**Status:** PARTIAL
* **Exists:** `LOCAL_FIRST` (the player's own map is the implicit route zone when it has worthwhile work), `WORK_HERE`, `StayLocal`, deferred hand-ins with batching and slot pressure.
* **Not built:** a named "local hub" concept in presentation/diagnostics beyond B-03; hub radius separate from stop radius. Merge with B-03 when specified.

### B-05 Quest urgency / "approaching gray"
**Status:** UNBUILT. No trusted Forever gray / trivial rule exists.
* **Exists:** only `Engine.LevelFit` points inside the ACCEPT value and the `maxGap` filter that hides quests far below the level; no code mentions gray or trivial.
* **What remains:** a trusted source (a client API, or recorded observations of when quests turn gray: nothing of the kind is probed); then a bounded multiplier on existing value.
  Do NOT invent the Classic rule. **Dependencies:** a probe (possibly `GetQuestDifficultyColor`-style APIs; unprobed). **Priority:** MEDIUM (blocked).

### B-06 Future-route awareness / lookahead
**Status:** PARTIAL
* **Exists:** one-hop chain credit (`chainValue`, 200 yd), "opens N more quests" in READY TO TURN IN (QuestieDB prerequisite lists; unverified), 3-stop sequences.
* **Not built:** multi-step lookahead; weighting follow-ups in opportunity value beyond the chain share. The count is a UI fact, not a planner input.
* **Provenance rule:** QuestieDB prerequisite data is a prediction, not Forever-observed. **Priority:** MEDIUM.

### B-07 Travel-cost model (flight, hearthstone, boats, respawn shortcuts)
**Status:** UNBUILT
* **Exists:** straight-line yards / 7 yd/s (estimated); cross-map legs are "unknown" and charged 900 s; `RESPAWN_SKIP` action type registered with no provider; Hardcore toggle
  removes that type (a no-op until a provider exists).
* **Not built:** flight-path travel times, hearth/bind detection, graveyard data, any shortcut recommendation (needs observed evidence; never Hardcore). **Priority:** LOW to MEDIUM.

### B-08 Fast mode driven by measured telemetry
**Status:** UNBUILT. "Fast" exists as scoring weights only; `TelemetryMetrics` calculators exist and nothing consumes them; telemetry must not make decisions itself.

### B-09 Route styles: Solo, Dungeon-friendly, Hardcore
**Status:** UNBUILT (registered, inactive, greyed). Four styles are active (Efficient, Fast, Questing-only, Completionist). They need group/dungeon/safety data.

### B-10 Hardcore safety layer
**Status:** UNBUILT (future; do not preclude)
* Idea: same opportunity model plus a risk dimension (level differences, elite mobs, density, escape routes, resources) presented as SAFE / ELEVATED / HIGH RISK / SAFE ALTERNATIVE.
  No code beyond the toggle. The opportunity record (`relation`, `evidence`, `reason`) leaves room for a `risk` field. **Priority:** UNSET.

### B-11 Objective areas (quest blobs) instead of one point
**Status:** PARTIAL / NEEDS VERIFICATION
* Objectives use one marker point (game quest map `GetQuestsOnMap`, first entry, or ATT/observed coordinates); distances are printed with "~". The game's blue blob areas are not
  available to Codex. Whether the client exposes the area polygons/highlights is unprobed. **Priority:** MEDIUM (affects pricing accuracy for spread-out objectives like Crab Season).

### B-12 Shared destinations / multi-target actions
**Status:** BUILT (Contract `targets[]` with roles GIVER / OBJECTIVE / TURN_IN / SERVICE / AREA / DESTINATION; stops merge co-located actions). The old "one target per action" limitation is **STALE**.

### B-13 Planner performance follow-ups
**Status:** DEFERRED (decided to wait for real-client data; the data is now in)
* Built: per-pair `P.Char()` fix (0.5.3), counters for recompute time/cause/events/memory, worst-recompute stage breakdown (0.6.1).
* Measured on the real client: cold first recompute ~400-460 ms (quest scan ~394 ms of which QuestieDB record builds ~255 ms; once per session), warm ~29-30 ms, window-open refresh
  15-19 per minute (~1.2% of session time), memory 31 MB after first recompute vs 43-79 MB later (includes collectable garbage).
* **Open decisions (not made):** skip the 3 s refresh when nothing moved or changed; cache the eligible candidate set with versioned invalidation; whether to spread the cold build; a
  report-only forced collection to read the true memory floor. **Priority:** MEDIUM.

### B-14 Player agency controls for opportunities
**Status:** PARTIAL
* **Exists:** Skip (NOW), `/codex skip|unskip|add|remove`, route zone, route style, per-system toggles, stickiness, no scolding wording.
* **Not built:** a way to mute or hide opportunity rows, "don't show this kind", or a calm "you're doing something else" mode; activity awareness (B-15). **Priority:** MEDIUM.

### B-15 Player activity awareness
**Status:** UNBUILT (design only)
* **Discussed:** context such as fishing, mining, herbalism, combat, grinding, training, exploring, dungeon activity; used as context, never as scolding ("You're already fishing here.
  Optional: ...").
* **What exists:** telemetry that could feed a pure inference without polling: PLAYER_MOVE (1 Hz), QUEST_OBJECTIVE diffs, COMBAT_START/END, XP_GAIN, LEVEL_UP (these record in real
  reports). No Activity module exists.
* **What remains:** spell-cast / loot / gathering / fishing events are NOT registered or probed; trainer and taxi events are not probed; the activity function; presentation rules.
* **Priority:** MEDIUM (after C-01 evidence work and B-03). **Risk:** nagging.

### B-16 Opportunity sources beyond quests (trainer, gather, items, profession, exploration)
**Status:** UNBUILT. Only quest actions and flight hints exist. The Contract already has SERVICE targets and `optional` / `hereOnly` actions as the seam; `Providers/Planned.lua` registers
inert systems (see E). Tier rules (route / stop / extra / context) are in the design doc only.

---

## C. Actionability, provenance and data quality

### C-01 Offer evidence layer (what the client offered)
**Status:** BUILT (0.6.4 probe, 0.6.5 evidence layer, 0.6.6 refinement); the underlying client API is real-client PROVEN, the normalised layer itself is stub-tested only
* **Proven on build 70205 (v0.6.4 report):** `GOSSIP_SHOW` fired 16 times; `C_GossipInfo.GetAvailableQuests()` and `GetActiveQuests()` answered 16/16 and their entries carry real quest ids (and
  `title`, `questLevel`, `questInfoID`, `repeatable`, `isComplete`, `isImportant`); `GetOptions`, `GetQuestID`, `GetTitleText`, `UnitName`, `UnitGUID` PROVEN; `QUEST_DETAIL` fired 5 times with ids;
  empty lists occur (Valennia Stormfist, Talaanis Shadowsong). `QUEST_GREETING` did not fire. The older `GetNumGossip*` / `GetGossip*` functions and `GetAvailableQuestID` are ABSENT.
* **Built:** bounded stores (observations 100, quests 300, NPCs 100; no raw GUIDs); OBSERVED via QUEST_DETAIL or the available list (both counted, QUEST_DETAIL stronger); the ACTIVE list kept
  separate and never treated as an offer; contextual EMPTY_AT_NPC / NOT_LISTED_AT_NPC (only from a complete, all-ids list from the proven API); positive evidence never erased (a newer contrary dialog is
  shown beside it); report section; opportunity diagnostics wording; `plan.onTheWay[i].offer`.
* **Name-fallback risk (documented after the 0.6.9 playtests):** the NPC lookup falls back from creature id to NPC name, and Valennia Stormfist exists under several creature ids; see C-12 and `CODEX_OBSERVED_PACK_PROVENANCE.md`. Not changed.
* **Remaining unproven:** QUEST_GREETING payloads (recorded, never used as evidence); how long an observation stays meaningful (no staleness policy); the real-client checks of the normalised report
  (A to D in `CODEX_OFFER_PROBE.md`).

### C-02 Using actionability in the planner
**Status:** PARTIAL (0.6.7: confidence only; no hard gate)
* **Update 0.6.7:** `Planner.OfferState` (OBSERVED / NOT_OFFERED / UNKNOWN) now drives ACCEPT confidence: OBSERVED no discount, a current-progression NOT_OFFERED a strong discount (0.25), UNKNOWN unchanged; negatives go stale on progress (progression stamp). See `CODEX_AVAILABILITY_AND_QUEST_ITEMS.md`. Not built: a hard exclusion, an UNKNOWN discount for observed-pack pickups (would change golden baselines), staleness for non-progress changes.
* Original note:
* Today UNKNOWN pickups are valued at full strength when their evidence is "observed" (observed pack) and at 0.9 otherwise. No gate, discount or label uses OBSERVED / EMPTY_AT_NPC.
* **Options not chosen:** drop a pickup whose giver just returned EMPTY (stale-evidence and name-vs-id risks); discount or demote unconfirmed pickups; label them in the tracker.
* **Remains:** a time-bounded, narrow rule reviewed against golden baselines; wording "not offered at this NPC in the observed dialog", never "unavailable".
* **Priority:** HIGH (recurring real-client failure: Yorana Windyreed, Taming the Beast). **Notes:** no class / race / prerequisite inference.

### C-03 QuestieDB bridge
**Status:** BUILT (runtime consumption, no copied code or data); limits listed
* Consumed at runtime through the documented API (quests, NPCs; the Item table only as an unverified annotation). Not used: race masks (Forever's new races), class masks only when all bits
  are known classes, objective areas, object/item starters, exclusivity, chains beyond prerequisites, Questie's hide/blacklist policy.
* **NEEDS VERIFICATION:** the M1 licensing matrix (`docs/LICENSING.md`) still says Questie/QuestieDB is "Not read"; the addon now consumes QuestieDB at runtime. See K-03.

### C-04 Observed (Forever) quest data growth
**Status:** PARTIAL
* **Exists:** the observed pack `observed:m6` (96 records, src=observed, verified=true) generated by `generator/build_codex_data.py` from the M8.13/M6 tables; layering by pack priority.
  The ForeverRecorder addon (`m5-production-recorder`) and forever-db harvest ingestion exist as SEPARATE tooling (real-client validated in M5).
* **Missing:** an in-Codex path that turns what Codex observes (quest dialogs, giver NPC identity and position, objective locations) into observed records; the planning model's
  "evidence capture path" phase was never built as a Codex feature. Many pickups still show `location=approx` (a player position recorded near the NPC).
* **Provenance caveat (found in the 0.6.9 playtests; see `CODEX_OBSERVED_PACK_PROVENANCE.md`):** the pack's `giver` and `pos` are the latest recorder checkpoint's values, usually the TURN-IN side, so they
  do not describe the pickup for a quest whose offering and turn-in NPCs differ. `verified=true` means "recorded on Forever", not "NPC position verified". Fix is tracked as C-12.
* **Priority:** MEDIUM to HIGH (feeds C-02, E, F).

### C-05 Location quality
**Status:** PARTIAL: provenance labels exist (known / approx / assumed, observed player position vs NPC); ~all real-client pickups are `approx`, so price accuracy for pickups is limited. No NPC-position capture exists. For observed-pack pickups the position is also usually the turn-in-side player position, not the pickup's (see C-12).

### C-06 Completed-quest knowledge (`IsQuestFlaggedCompleted`)
**Status:** BUILT; code comments still say "UNVERIFIED" **[STALE caveat]**: real reports show "completed already 41", so the call answers on Forever. Update the comments/docs when touched.

### C-07 Holiday / seasonal quests
**Status:** PARTIAL: a fixed set of 15 holiday category ids hides such quests (0.2.15). Which events are active (a calendar API) is unverified, so event quests are never offered at all.

### C-08 Quest-starting items / conditional quests
**Status:** PARTIAL (0.6.7: bag items that start a quest are detected and surfaced; unproven on Forever)
* Built: generic detection from the client's container quest info or QuestieDB `startQuest`, filtered by the planner's progression rules, shown as a NEW QUEST ITEM card (`CODEX_AVAILABILITY_AND_QUEST_ITEMS.md`). Not built: the funnel line "CONDITIONAL: not modelled yet" in the report still says so for quest-starting DROPS (items not yet in the bags); the client function's behaviour on Forever is unproven.

### C-09 Unlocated quests and reminders
**Status:** BUILT: quests with no usable location become reminders, never destinations.

### C-10 Data pack generation and refresh
**Status:** BUILT (deterministic generator, tests, provenance headers, pinned ATT commit, safety tests). **NEEDS VERIFICATION:** how/when the ATT snapshot (pinned 2026-09-26) and the observed
pack are refreshed, and whether new Forever content (20-30+) is covered.

### C-11 Quest tags, elite labels and dungeon quest card
**Status:** BUILT (0.4.1): game tags via `GetQuestTagInfo` (proven), "(Elite)" label, red DUNGEON QUESTS card grouped by dungeon.

### C-12 Preserve checkpoint-labelled evidence in the generated observed pack
**Status:** UNBUILT (documented finding, no implementation; `CODEX_OBSERVED_PACK_PROVENANCE.md`). Data pipeline task (M6 coverage -> guide dataset -> M8 generator -> `build_codex_data.py` -> `Pack_Observed.lua`).
* **Problem:** M6's `coverage.py` displays the LATEST checkpoint's giver and position (turn-in first), and the later stages carry only that displayed value. The shipped pack therefore loses the offer-side
  evidence and the checkpoint label, so Codex cannot tell pickup from turn-in. Example: Q93065 Prepare for Battle is routed to its turn-in spot; Q93836 The Fate of Zephras to Talaanis, who has never offered it.
* **Task:** keep the checkpoint-labelled evidence in the generated observed pack so pickup and turn-in evidence stay distinct. Where available, preserve per quest and per checkpoint:
  * quest id
  * checkpoint / event type (quest_detail, quest_progress, quest_complete_immediate, quest_complete_delayed, GOSSIP_SHOW)
  * NPC creature id and name
  * player map id and x, y (always labelled as a PLAYER position)
  * timestamp
  * session and build, if useful
* **Goal:** let Codex tell apart the observed PICKUP location, the observed TURN-IN location, player-position evidence, and NPC identity, without inventing an NPC coordinate.
* **Constraints:** do not merge or overwrite on disk (layers stay separable, as today); keep `verified` meaning "recorded on Forever"; do not infer a pickup NPC from a role-ambiguous value; the
  recorder cannot supply an NPC position or a progression stamp, so those stay unknown. Requires a design pass (pack format, Registry consumption, golden-baseline impact) before any change.
* **Related, NOT part of this item:** Valennia Stormfist is observed under creature ids 252383, 253590 and 253844, so the by-name NPC fallback in `OfferProbe.NpcContext` is risky in this zone (0.6.9 now shows
  "matched BY NAME ONLY ... ids differ" in the report). The matching logic was deliberately left unchanged; any change is a separate design decision (see C-01).
* **Priority:** MEDIUM to HIGH (feeds C-02 and C-05). Not scheduled; no version is implied.

---

## D. Items, rewards and inventory

### D-01 Shared item facts reader (ItemFacts) / reward probe
**Status:** BUILT (0.4.4 to 0.4.6; real-client validated). PROVEN / UNPROVEN / FAILED / EMPTY per field, late-loading queue, reward cache (every dialog recorded), QuestieDB annotation kept separate.

### D-02 Equipped and bag item facts, factual comparison
**Status:** BUILT (0.4.7 to 0.4.8): `Gear.lua` snapshot, events (`PLAYER_EQUIPMENT_CHANGED`, `BAG_UPDATE_DELAYED`), `Compare` / `CompareToEquipped`. Facts only; no judgement.

### D-03 Eligibility ("can't use" vs "can't use yet") and proficiency evidence
**Status:** BUILT (0.5.0 to 0.5.2). Current PROVEN_YES / PROVEN_NO / UNKNOWN; future NOT_RELEVANT / SOON / LATER / UNKNOWN; evidence recorder with dedupe and conflict handling. The Classic
reference table is hint-only (`proven=false`). **Limits:** skill-line APIs absent as globals (weapon skills unreadable that way); `IsUsableItem` not trusted alone (conflicts recorded).

### D-04 Reward Advisor: classification
**Status:** BUILT (0.4.9; report-only). Categories NOT_USABLE / UPGRADE / TEMPORARY_UPGRADE / FUTURE_UPGRADE / SLIGHT_UPGRADE / MIXED / COMBAT_UTILITY / FUTURE_USE / VENDOR / UNKNOWN. No
stat weights by design. Thresholds are PROPOSED and untuned. **Not marked complete:** see D-05 to D-10.

### D-05 Reward Advisor: recommendation (Stage 4)
**Status:** UNBUILT. `Advisor.Recommend` is an interface returning NO_OPINION. Missing: replacement Horizon (a `context.replacement` input exists; nothing supplies it), the explainable
recommendation rules, the vendor alternative, reward set look-ahead (future rewards from QuestieDB `questRewards` inverted = "possible reward"), and tuning of thresholds.

### D-06 Reward Advisor: player-facing advice
**Status:** UNBUILT. Nothing in the tracker or options shows reward classifications; they appear only in `/codex report`. Design called for text tags plus own icons (decision approved, unbuilt).

### D-07 Upgrade detection (slight / temporary / future)
**Status:** PARTIAL: classification computes upgrade / slight / mixed from facts and a replacement context; no real Horizon source, no class-weighted valuation (deliberately none).

### D-08 Combat utility and use effects
**Status:** PARTIAL: `COMBAT_UTILITY` appears when an item reports a use spell (spell meaning unknown); `GetItemSpell` reads "EMPTY" for the sampled items. No spell/effect interpretation.

### D-09 Vendor value and sell advice
**Status:** PARTIAL: vendor value is a proven fact and the VENDOR category exists; `MERCHANT_SHOW` is not registered; no keep/use/sell advice; no replacement-aware sell rule.

### D-10 Inventory / equipped intelligence beyond facts
**Status:** UNBUILT: keep / use / sell advice, bag-space awareness, future-use inventory marking (design "Stage 5", `Inventory.lua` was only sketched). ItemFacts and Gear existing does NOT make this built.

### D-11 Future item intelligence ("KEEP this, you'll need it later")
**Status:** UNBUILT
* Design: ItemSource classes ALWAYS_AVAILABLE / VENDOR / QUEST_GATED / PROFESSION_GATED / UNKNOWN; ITEM_KEEP / FUTURE_REQUIREMENT as context only; never "go farm N". Sources would be quest log
  objective text (names, not item ids, on Forever), QuestieDB item relations (unverified), ItemFacts. No code exists.
* **Priority:** LOW to MEDIUM. **Risk:** wrong "keep" advice from unverified relations.

### D-12 Tooltip hook (a Pawn-style upgrade line)
**Status:** DEFERRED (explicitly "later, separately reviewed").

### D-13 Alt / bank inventories (BagBrother)
**Status:** DEFERRED / out of scope for now (decision: no alt inventories in the first stages).

---

## E. Spell, training, profession and gathering intelligence

### E-01 Trainer / spell / "new ability" intelligence
**Status:** UNBUILT (no probe exists)
* **Discussed:** use information (including what What's Training? shows) to produce contextual decisions: new abilities available, training cost, trainer location, "you're already passing a
  trainer", linkage to NEW FOR YOU, without duplicating What's Training?.
* **What exists:** an inert `trainers` / `classProgression` system and TRAINER / CLASS_PROGRESSION action types (greyed, cannot be switched on); `Knowledge.lua` says "Codex cannot yet see
  what your class trainer can teach you"; Contract SERVICE target `TRAINER`. A real-client note (0.2.5): training a spell fired no event Codex listened to; "Codex registers no trainer or
  spell events at all".
* **What remains:** a read-only probe of trainer-window events and APIs (`TRAINER_SHOW`, trainer service lists), spell events (`LEARNED_SPELL_IN_TAB`, `SPELLS_CHANGED`), trainer locations (no
  trustworthy data: ATT has none), a policy for "what is new at this level" that is not "every two levels".
* **Dependencies:** H (What's Training? integration), A-01. **Priority:** MEDIUM to HIGH (feeds NEW FOR YOU and trainer opportunities).

### E-02 Trainer opportunities in the route ("ALSO DO: trainer")
**Status:** UNBUILT (design: SERVICE target within a hub radius of an already-chosen stop; optional, never forced). Depends on E-01.

### E-03 Profession opportunities
**Status:** UNBUILT. Inert `professions` / `gathering` systems only; skill-line APIs absent; no profession detection. Rule: never send the player farming; "if you're already walking past this".

### E-04 Gathering nodes on the route
**Status:** UNBUILT (GatherMate2 would be an optional source; its API and licence unverified). No native node API is known.

### E-05 Weapon skill opportunities
**Status:** UNBUILT **[conversation only]**. No code or document beyond the generic eligibility evidence; skill-line functions are absent on this client, so weapon skill state is currently unreadable.

### E-06 Camping, hunter pets, respawn skips, class progression, group optimisation
**Status:** UNBUILT (registered inert systems in `Providers/Planned.lua`; no providers, no data). "Camping 101" quests are ordinary quests. Respawn skips must never appear in Hardcore.

---

## F. Flight paths

### F-01 Flight path hints
**Status:** PARTIAL (visible only in the report / developer window)
* **Exists:** 14 ATT flight nodes (unverified locations) as optional "while you're here" hints (state UNKNOWN; they cannot say whether a path is already known) and a "flight" system toggle (on). The
  `Nearby.lua` list that would show a flight master within 150 yd is NOT drawn by the current tracker (the report calls it the "old nearby list (not shown in the window)"), and flight actions are
  excluded from the tracker's ALSO rows: in practice flight hints are visible only in `/codex report` and the developer window.
* **Not built:** discovered/undiscovered detection (taxi APIs unprobed), route-aware flight reasoning, flight times in the travel model (B-07). Most hints show as unplaced / UNKNOWN_TRANSIT in
  the opportunity diagnostics (other maps).
* **Priority:** LOW to MEDIUM (needs a taxi probe).

---

## G. Dungeons

### G-01 Dungeon intelligence
**Status:** PARTIAL (display only)
* **Exists:** game quest tags + a red DUNGEON QUESTS card grouped by dungeon; dungeon quests are kept out of NOW / ALSO; inert `dungeons` system and a planned Dungeon-friendly style.
* **Not built:** dungeon recommendations, progression, rewards / gear, route-aware dungeon opportunities, DungeonJournal use (its data and API are unverified).
* **Priority:** LOW (UNSET).

---

## H. Addon integration layer

### H-01 Integration Manager (detect / report / adapt)
**Status:** UNBUILT. Designed (`CODEX_OPPORTUNITY_SYSTEM_DESIGN.md` section 13): a registry of adapters with installed / detected / API available / data available / confidence status and an
INTEGRATIONS report block. No `Integrations.lua`. The addon-loaded detection API on Forever is unprobed.

### H-02 Per-addon integrations
| Addon | Intended role | Status |
|---|---|---|
| QuestieDB (library) | quest data | BUILT (runtime read through its public API; optional dependency) |
| Questie (addon) | quest information / notes | UNBUILT beyond slot awareness in the world-map button and a tracker-conflict note |
| GatherMate2 | gathering nodes | UNBUILT; API / licence unverified |
| What's Training? | trainer information | UNBUILT; no known read API |
| Bagnon / BagBrother | inventory information | UNBUILT (alts deferred, D-13) |
| DungeonJournal | dungeon information | UNBUILT; unverified |
| Titan Panel | character / account information | UNBUILT; no use case defined in the repository **[conversation only]** |
| BlizzThreatPlates | combat information | UNBUILT; no use case defined **[conversation only]** |
Not integrated, by decision: DBM / BigWigs / GTFO / rotation helpers.

### H-03 Licensing of each integration
**Status:** NEEDS VERIFICATION (no conclusions drawn here). Facts: Codex consumes QuestieDB's public API at runtime and copies none of its code or data; ATT-derived data is bundled in Codex's
own packs (MIT upstream, but "upstream provenance of coordinates unresolved"); no LICENSE file exists in the repository; no third-party notice file exists.

---

## I. Navigation, map, waypoint and arrow

### I-01 Waypoint following (the game's user waypoint)
**Status:** BUILT, real-client observed (reports show "waypoint following on ... Codex pin placed"). Ownership rules (own pin only; foreign pins respected; no per-frame placement; arrival measured by Codex).
**Unverified:** that a waypoint survives `/reload`; cross-continent behaviour. `C_Navigation.GetDistance` is known unreliable and unused.

### I-02 Codex direction arrow
**Status:** BUILT, real-client confirmed pointing correctly (0.2.10 results: facing calibration, rotation, resize, tooltip). **Open:** the earlier "arrow comes and goes" report was never closed;
cross-continent behaviour unverified.

### I-03 Map pins on the world map; automatic world markers (raid targets)
**Status:** REJECTED / SUPERSEDED: built then removed in 0.2.5 (no Codex map pins, no automatic markers); raid-target icons act on units, not map points. See O-01, O-02.

### I-04 Minimap button, world-map button, tracker hide
**Status:** BUILT. Minimap button rides the minimap edge (real-client reported fixed); hiding the game's quest tracker verified popup-free on Forever (0.2.10); the world-map corner button's anchor is
UNVERIFIED on Forever.

### I-05 Navigation confidence / presentation
**Status:** PARTIAL: navigation states (following / paused-foreign / dismissed / arrived / unavailable) are reported; no confidence concept beyond the location provenance labels.

---

## J. Telemetry, activity, Help Improve Codex

### J-01 Telemetry
**Status:** BUILT (capped log, 300 events). **Real-client recorded:** QUEST_ACCEPT, QUEST_COMPLETE (objectives done by log diff), QUEST_TURNIN, QUEST_OBJECTIVE, PLAYER_MOVE (1 Hz), XP_GAIN, LEVEL_UP,
COMBAT_START / END. **Unavailable:** MOB_KILL (the combat log cannot be registered by addons on Forever: taint popup). **Not captured / unprobed:** gathering, fishing, trainer interaction, loot
beyond bag events, spell learning, death / respawn, mounted state, rested XP. **STALE:** the static capability table still labels XP_GAIN / LEVEL_UP / COMBAT_* UNPROVEN although they record
in real reports. Consumers: only the Help Improve Codex counts and `/codex telemetry summary`.

### J-02 Help Improve Codex (observation sharing)
**Status:** PARTIAL (local summary only)
* **Discussed:** a friend installs Codex, plays normally, and can choose "Help Improve Codex" to export locally observed gameplay; we import and review it to improve the database. No manual narration.
* **What exists:** the Appendices page (counts from the real telemetry store, "nothing is uploaded"); the offered-quests and reward-dialog observation stores; separately, the ForeverRecorder addon
  (`m5-production-recorder`) with an export contract, privacy model, no networking and idempotent import into forever-db (M4 importer) is real-client validated. Whether Codex will reuse that
  pipeline is undecided.
* **Not built in Codex:** consent flow, transparency page, local-only mode switch, export file, import/review tooling for Codex-shaped data, anonymisation rules for Codex observations, retention,
  deletion, a community observation workflow, any `/codex send`-style command (none exists; explicitly out of scope so far).
* **Dependencies:** J-01, C-01, C-04, K-02 (friend beta), a privacy/licence decision. **Priority:** HIGH after the friend beta (stated by the project owner as a later feature). **Risks:** privacy,
  SavedVariables logout reliability (M8.0: `/reload` saves are reliable, logout saves have failed), data quality.

### J-03 Persistence reliability
**Status:** NEEDS VERIFICATION: logout saves of SavedVariables failed intermittently in M8.0 and the root cause is unknown; Codex relies on `/reload`. Matters for every observation store (J-02, C-01).

---

## K. Release, beta and quality

### K-01 Release discipline and packaging
**Status:** BUILT: `RELEASING.md`, a deterministic packager (`generator/package_addon.py`) that refuses mismatched versions, one folder per minor version in `dist/`, per-release docs, planner golden
baselines, ~3,480 stub tests plus generator tests. **Note:** the documented 0-9 patch rule was departed from once (0.5.5 to 0.6.0); the document does not say who decides the version for feature work.

### K-02 Friend beta
**Status:** PARTIAL (the product has been exercised for many real-client iterations; the beta artefacts are stale)
* **Exists:** `CODEX_FRIEND_TEST_GUIDE.md` (written for 0.2 alpha), `/codex report` as the one bug-report artefact, zero caught Lua errors in the shared reports, graceful UNKNOWN handling, quest tracking,
  waypoint, arrow, reward facts.
* **Missing / stale:** the friend guide and `CODEX_PHASE3_NOTES.md` describe 0.2 (their "NOT VERIFIED" table was never refreshed, though many rows have since been exercised); no beta checklist for
  0.6.x; no instructions for the offered-quest probe and PERFORMANCE section; no onboarding for non-technical friends beyond install steps; no agreed beta scope or exit criteria.
* **Priority:** HIGH (gate for J-02 and K-03).

### K-03 Public release readiness
**Status:** UNBUILT / NEEDS VERIFICATION
* **Known open items from existing documents:** public redistribution of ATT-derived data packs is an explicitly OPEN licensing question ("do not publish the data packs publicly until decided");
  no LICENSE file; no third-party notices; QuestieDB runtime dependence and its licence stance; Blizzard-derived data caution; community-data licence and contributor terms (forever-db LICENSING.md
  decisions left to the owner).
* **Obvious dependencies (not previously agreed, NEEDS VERIFICATION):** user-facing install and configuration docs, a support / bug-report channel, a "known limitations" statement (the Knowledge page is a
  start), a privacy and telemetry disclosure (Help Improve Codex), packaging for the distribution channel.
* **Priority:** UNSET. **Notes:** no legal conclusions are drawn here.

### K-04 Stale documentation
**Status:** NEEDS VERIFICATION (cleanup): `CODEX_ARCHITECTURE.md` (0.1 module list, "Show on Map" only, "Not in 0.1" list), `CODEX_PHASE3_NOTES.md` (markers module, "Codex arrow not integrated"),
`CODEX_FRIEND_TEST_GUIDE.md` (NEARBY / NEW FOR YOU cards, markers probe), `CODEX_TEST_GUIDE.md` (marked superseded), root `docs/LICENSING.md` (Questie "Not read"), `README.md` (0.1 description). The
planning model's "known bugs" section (stale waypoint, protected-action error) is historical. These must not be mistaken for current state.

### K-05 Historical bugs to confirm closed
**Status:** NEEDS VERIFICATION
* Protected-action login popup ("blocked from an action only available to the Blizzard UI"): attributed to the combat-log registration and removed in 0.2.0; no later report mentions it, but a clean
  login confirmation is not recorded.
* Stale waypoint after an objective completes: fixed by the navigation controller (M1); later real-client reports show following / arrived states; not re-listed as verified.

### K-06 Real-client validation gaps of recent releases
**Status:** NEEDS VERIFICATION: 0.6.5 evidence layer (checks A to D pending); 0.6.3 objective row layout; the stage-timer report line (confirmed in a 0.6.2 report); the AFTER_ROUTE filter (screenshot 0.6.2 suggests
fixed).

### K-07 Report size and structure
**Status:** PARTIAL: `/codex report` is the single artefact but has grown very large; planned reorganisation and a concise DECISION BASIS section are unbuilt (A-05). Not a player-facing dashboard.

---

## L. Business and product ideas (nothing decided)

All **[conversation only]**; the repository has no trace of any monetisation. Recorded because they may constrain software decisions.
* **L-01 Free addon:** the addon stays completely free. Status: stated intent; no repository change needed.
* **L-02 Optional supporter membership / cosmetic supporter features:** UNBUILT. Would touch themes (A-03) and possibly identity; conflicts with "no identity stored" unless designed carefully.
* **L-03 Early experimental builds for supporters:** UNBUILT; implies a release-channel concept (K-01 currently has none).
* **L-04 Community / support benefits, donations, paid services outside the addon:** UNBUILT / UNDECIDED; no software dependency identified.
* **L-05 Two-person project / business structure:** not a software item; it affects licensing and data-governance decisions (K-03).
Do not treat any of these as a decided model.

---

## O. Rejected, superseded and stale (kept so they are not rediscovered as "new")

* **O-01** Automatic world markers (raid-target icons): built, hardened, never verified, REMOVED in 0.2.5 (units, not map points; no inn data). Superseded by the waypoint and arrow.
* **O-02** Codex pins on the world map: removed in 0.2.5. (The corner button remains.)
* **O-03** Party chat announcements (`SendChatMessage`): removed (0.2.1); Questie already announces. Party addon messages (progress sharing between Codex users) remain, UNVERIFIED on Forever.
* **O-04** A "quests" provider for NEW FOR YOU: removed (a level-up never shows a quest).
* **O-05** The legacy greedy engine path: kept as a fallback (`/codex planner legacy`), superseded by the Planner.
* **O-06** The monolithic engineering window: demoted to `/codex dev`.
* **O-07** A class-to-armor table presented as truth: rejected; Classic references are hints only (`proven=false`).
* **O-08** Alt inventories / BagBrother in the first reward stages: deferred (D-13).
* **O-09** "One target per action" and "ATT-only quest data" statements in older docs: STALE (Contract targets, QuestieDB, observed pack exist).
* **O-10** `TOO_FAR` changes: explicitly not to be changed for single items; bundle pricing (B-03) is the intended answer.

---

## N. Things surfaced during this audit (not previously discussed; for consideration only)

* The `Pl.Confidence` 0.9 discount applies only to non-observed ACCEPTs; observed-pack pickups carry no discount although observed means "recorded", not "offered" (see C-02).
* The NEW FOR YOU even-level rule and the 60 s lifetime are hard-coded policy (A-01).
* `Planned.lua` systems can be toggled in the report but not in the UI (greyed); an "Integrations" status in Options does not exist (H-01).
* There is no single place that lists which Forever APIs are PROVEN (the knowledge is spread across the REAL-CLIENT FIXES doc, probe tallies and design docs).

---

## Top items by current project state (proposal, not agreement)

1. B-03 Hub bundle pricing (evidence collected; named next major phase).
2. C-02 Actionability in the planner (repeated real-client failures).
3. C-01 real-client checks A to D for the 0.6.5 evidence layer.
4. E-01 Trainer / spell probe (unblocks NEW FOR YOU, trainer opportunities).
5. K-02 Friend beta (refresh guide, scope, exit criteria).
6. J-02 Help Improve Codex export design (after the beta).
7. B-13 Planner performance decisions (periodic refresh, candidate cache).
8. D-05 / D-06 Reward Advisor recommendation and player-facing advice.
9. B-05 Urgency (needs a gray-rule probe first).
10. K-04 Stale documentation cleanup (cheap, reduces confusion).

## Could not be confidently recovered

* Details of conversations before the earlier-session summary beyond what the repository records (the audit relied on the repository; items discussed only verbally are tagged **[conversation only]**).
* The exact intended contents of "Phase 3 / friend beta" as the project owner now means it: the repository's "Phase 3" is the 0.2 player-facing build, which is built; the later meaning (a gate for Help Improve
  Codex) is not defined in any document.
* Roles for Titan Panel and BlizzThreatPlates (no repository trace of a use case).
* Weapon skill opportunities and supporter membership: no repository trace beyond the request.
* Whether "Coming Soon" and "What's New" were meant as one page or two.
