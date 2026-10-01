# M7.6: In-Game Data Harvesting Feasibility Investigation

**Read-only investigation. No implementation, no recorder change, no M6 modification. Every finding is
traced to actual source code in `m5-production-recorder/` or existing research in
`research/m1_5/REPORT.md`/`docs/M5_PRODUCTION_RECORDER_DESIGN.md` — nothing here is speculation.** Full
technical detail: `research/m7_6/harvesting_feasibility.md`; structured data:
`research/m7_6/harvesting_feasibility.json`.

## Question 1: What can the Forever client legitimately expose to an addon?

More than the recorder currently uses. Confirmed, currently-used: `C_QuestLog.*` (log entries, objectives),
`Unit*` functions (name, level, GUID, classification/creature-type/family), `C_Map.*` (player position),
`C_GossipInfo.*`, `GetQuestItemInfo`, `GetQuestLogRewardFactionInfo`, raw event arguments at
`QUEST_TURNED_IN`. Confirmed *available but unused*, per this project's own prior research (`[2nd]`-tagged,
never attempted on Forever): quest-frame text APIs, taxi node APIs, and client-side WDB cache files. The
WDB cache files in particular sit outside the addon API surface entirely — reading them would be a
meaningfully different kind of access than anything this addon has done, and their accessibility from a
normal addon on Forever is unverified.

## Question 2: What can the existing `/fr` recorder already capture?

Exactly what's traced in the technical research doc, Section 4 — quest ID/title/level/objectives (when the
quest is in the log), giver and target unit identity plus classification data, player position (only), item
names, faction rewards, and XP/money from the turn-in event. `/fr status` reports only a count and session
ID; `/fr save` performs `ReloadUI()` and nothing else — confirmed by reading the complete `Export.lua`.

## Question 3: What is currently captured but discarded?

Three confirmed instances: (1) Gossip quest lists beyond the first 5 entries — the total count is kept, the
detail is not. (2) `UnitClassification`/`UnitCreatureType`/`UnitCreatureFamily` for both NPC and target
units — captured every time, never imported by M4. (3) The entire `target` unit capture (as opposed to
`npc`) — recorded in full on every `GiverIdentity` call, never read by the importer at all.

## Question 4: What could plausibly be captured automatically while the player plays normally?

**Talking to NPCs, already.** `GOSSIP_SHOW` fires on essentially any NPC interaction and triggers a real
capture without the player needing to think about data collection — this is confirmed already happening
incidentally in real M6.5 sessions. Beyond that, nothing currently hooked fires from ordinary movement,
objective progress, or quest acceptance. One concrete, code-grounded possibility was identified but **not
implemented**: hooking `QUEST_ACCEPTED` to trigger the same capture logic already used at `QUEST_DETAIL`
would let the recorder capture a quest's title/level/objectives at the moment it's accepted — directly
addressing the already-documented M6.5 finding that re-visiting an already-accepted quest's giver opens
gossip, not the quest-detail frame.

## Question 5: What still appears to require deliberate manual collection?

Objective progress (no event fires on progress, confirmed by its absence from the hooked-event list) and
quest turn-in (the strongest existing capture, but still requires the player to manually initiate it — this
was never a candidate for automation, only for reliable capture once initiated, which it already achieves).
Standalone player-position tracking (e.g., for zone/travel-path data unconnected to a quest interaction)
would also require a new mechanism — none exists today.

## Question 6: Can passive harvesting substantially reduce the amount of manual quest collection required?

**Based strictly on the evidence found: no, not substantially, and this should not be overstated.** The
recorder cannot bypass normal play — every existing and every plausibly-addable hook still fires from the
player doing something (targeting, talking, accepting, turning in). What passive harvesting *can*
plausibly do, if `QUEST_ACCEPTED` were hooked, is capture more of what a player is **already doing during
normal leveling** without a separate, deliberate "go investigate this specific quest" step — reducing the
number of quests that need a *second*, deliberate revisit (as Run-001 required) rather than reducing the
amount of actual play. This is a real but modest claim, not a claim that manual collection could be
eliminated.

## Question 7: What is the smallest practical future implementation?

Derived directly from the evidence, not assumed: hook `QUEST_ACCEPTED`, route it to the same
`QuestMeta`/`GiverIdentity` capture logic already proven at `QUEST_DETAIL`. That is the single smallest
change with concrete evidence behind it. Everything else investigated (WDB cache files, taxi nodes, an
NPC-position API) remains unverified on Forever and would need its own separate investigation before being
considered "minimum viable."

## Question 8: What needs a tiny in-game experiment before implementation?

Three specific unknowns cannot be resolved from the repository alone:
1. Whether `QUEST_ACCEPTED` reliably fires on Forever with a usable quest-ID argument.
2. Whether `C_QuestLog.GetInfo`/`GetQuestObjectives` succeed immediately at that moment, or need a short
   delay (the way `quest_complete_delayed` already exists for a similar timing reason).
3. Whether any NPC-world-position API exists and returns a real value on this client — never queried by
   this addon.

**Smallest experiment, requiring no code change**: accept one quest, then immediately re-open that same
NPC's dialogue, then `/fr status` → `/fr save`, and check empirically which checkpoint fires
(`GOSSIP_SHOW` or `QUEST_DETAIL`) in that specific sequence. This single, minimal test would directly inform
whether the `QUEST_ACCEPTED` hook is worth pursuing, without requiring any implementation first.

## Summary

The existing recorder is a proven, working, but **interaction-gated** capture mechanism — nothing currently
fires without the player deliberately opening a dialogue or turning in a quest. One real, code-grounded
opportunity for a small architectural improvement was identified (`QUEST_ACCEPTED`), traced to a specific
prior design decision that addressed a narrower question than the one this milestone asked. No
implementation was performed. The project's ideal end-to-end workflow (client → addon → local recorder →
observation artifact → M6 pipeline) is technically real today for the interaction-triggered case; whether it
can be meaningfully extended toward passive capture remains partially open, pending the small experiment
above.
