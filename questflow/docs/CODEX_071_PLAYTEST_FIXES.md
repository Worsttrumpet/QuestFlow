# 0.7.1: fixes from the 0.7.0 playtest (level 14 Skyborne Rogue, build 70205)

Five changes, each a general rule (no quest id, no NPC, no special case). Evidence boundaries are unchanged: QuestieDB and ATT are not observed Forever behaviour; the observed pack's `pos` is a
PLAYER position, not an NPC coordinate (C-12 is NOT implemented here).

## 1. Active and ready quests always get guidance (Presenter only)
When the planner has no NOW but the player has a finished quest or an unfinished objective Codex cannot place, the NOW card shows the quest name, the quest log's own objective text and an honest
"no map location / could not measure, so there is no arrow". The planner, waypoint and arrow are untouched (a test checks that nothing is pointed at). Skip is hidden (guidance is not a recommendation).

## 2. Restriction-known vs restriction-unknown pickups
`Registry` marks a pack as carrying restriction data when it says so (`meta.restrictions`, QuestieDB) or has at least one record with a class/race restriction. A quest is restriction-known when a layer
covering it carries such data (ATT Kalimdor / Eastern Kingdoms, QuestieDB). The observed pack (no class/race fields) and `att:other-zones` are restriction-UNKNOWN: "none listed" is not "unrestricted".
A restriction-unknown pickup with no fresh offer is a candidate only within `Planner.RESTRICTION_UNKNOWN_MAX_YD` (200 yd); beyond that it is a POSSIBLE pickup (counted and listed in `/codex report`, usable
only as an on-the-way extra). Lifted by: a fresh client offer (OBSERVED), a quest the player added, a route zone the player chose. No observed data is removed.

## 3. Fresh offers are a candidate source
`OfferProbe.FreshOffers`: positive evidence (QUEST_DETAIL, or a listed available quest with an id) read at the CURRENT progression stamp and not contradicted by a newer complete listing. A quest no pack knows becomes an
"offered here" ACCEPT (`Q:<id>:ACCEPT`, state AVAILABLE / CLIENT_OFFER) with **no target**: the offer record carries no position, so none is invented (position capture is X1, not built). It shows as ALSO PICK UP
(or the NOW guidance card when nothing else exists) with the NPC's name. Accepting it moves it to the normal log pipeline; a turn-in changes the stamp so old offers expire; repeated events never duplicate it.
Also fixed: the progression stamp cache is now keyed by the turned-in count too (a turn-in between two recomputes could otherwise stamp a dialog with the old value).

## 4. Navigation safety (`Navigation.Assess`)
The waypoint and arrow are straight lines; Codex has no path, portal or transport data. A destination gets a pin/arrow only when it is measurable; an exact NPC coordinate up to 2,500 yd; an approximate one (objective
area, assumed hand-in, game quest-map point) up to 600 yd; an observed-pack PLAYER position only within 150 yd; and a far (>300 yd) quest whose own objective text names special travel (boat, ship, zeppelin, airship, portal, ferry,
teleport, skycutter) gets that text and no arrow. Beyond 1,000 yd a pin is labelled "straight line only". These are design values, not game facts; the transport words are a heuristic on the client's own quest text. The card
shows the reason ("no arrow: ..."). No portal or transport data was invented; nothing mentions any quest.

## 5. UNKNOWN is not AVAILABLE
A pickup with no positive client evidence (never offered, or a negative that went stale) is a candidate only within `Planner.UNCONFIRMED_MAX_YD` (500 yd); beyond that it is POSSIBLE, never NOW, however good its location or value.
Same exemptions as above. A fresh NOT_OFFERED still holds the quest back (0.6.8); a stale negative becomes UNKNOWN and is subject to the same limit (never positive). **Trade-off:** with no client evidence, Codex now will not
send the player far for a pickup on the data's word alone; the empty card says how many far, unconfirmed pickups it knows of. Both limits are single constants to retune after playtesting.

## Test harness note
The generic harness turns the 500 yd limit OFF (`boot` without `production = true`) because many older tests use far, unconfirmed pickups to exercise routing and TRAVEL; `pickup_tests.lua` runs with it on. The
restriction limit is on everywhere. The bridge-equivalence test switches the restriction limit off (it asks whether QuestieDB changes a decision, which restriction knowledge now legitimately does).

## Golden baseline change (`tests/golden/planner_eval_baseline.txt`)
Only the six real-data scenarios changed (A0, A1, A2, D1, E2, H1). Reason: they used to route to Forever-new quests that exist only in the observed pack (The Great Outdoors, The Adventurer, Vanquish the Betrayers ...)
300-460 yd away; those are restriction-unknown and far, so they are now possible pickups and the plans use the ATT-known quests and local work instead (A0 NOW: Continue: Sting of the Scorpid, a local unplaced objective).
All synthetic scenarios and all sweeps are unchanged. `CODEX_PLANNER_EVAL_REPORT.md` was regenerated.

## Real-client validation checklist
1. A class-restricted quest that appeared before (Warrior's Path / Taming the Beast for a Rogue): it must not be NOW; `/codex report` lists it under POSSIBLE PICKUPS.
2. An active objective with poor/no location (Q93836): the NOW card names it with the game's objective text and "no arrow"; no pin.
3. A ready quest with an unmeasured destination: guidance card, not "Nothing to recommend".
4. Turn a quest in and talk to the NPC who offers the follow-up (What Comes Next): "Accept ..." appears under ALSO PICK UP with the NPC's name; accept it and it becomes an active quest.
5. The Earthen Ring: the quest's own text is shown; no walking arrow.
6. Confront Lorthuna: no long straight-line arrow toward the cliff; the card says why (or the arrow is labelled straight-line).
7. Taming the Beast (previously UNKNOWN): not NOW unless Valennia/its giver actually offers it; open the giver's dialog and see it appear.
8. Normal known-good pickups and turn-ins nearby still become NOW with an arrow.
9. Spell Training and Professions: see `CODEX_SPELL_TRAINING.md`, `CODEX_PROFESSIONS.md`. Also Report a problem: `CODEX_FEEDBACK.md`.

### Spell Training, Professions and Report a problem (in-game)
* `/codex spells`, `/codex professions`, `/codex feedback status` first: they print which client functions exist. Anything shown as `NO` means that part cannot work on Forever and the section stays hidden.
* Spell Training: open your class trainer (the section appears after the visit once a listed spell's level is reached); learn one: it disappears without a reload and the total drops; click Don't Want to Learn on another, `/reload`: it stays gone; log in a different character: it is not hidden there.
* Professions: log in with professions: skill/cap match your skills window; with Fishing / Cooking / First Aid missing: "Not Learned" lines and (if you have one primary) "1 primary profession slot available"; visit a profession trainer with a rank available: "<service> available"; train it: the cap rises and the line goes.
* Report a problem: click Feedback (or Report on the NOW card), pick a category, type a sentence, Create Report; check the text says "saved locally" and never "sent"; paste the block and check it has the NOW/READY context, build and version, and no character name; do it again with no recommendation.
