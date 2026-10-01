# M5: Production Recorder Design

**Status: design only. No addon code exists yet. Nothing here has been built or tested on a real client.**
M0–M4 are frozen/complete; nothing under `forever-db/` outside this document (and its companion,
`M5_TEST_PLAN.md`) was touched to produce this. Evidence tags: `[V]` directly verified on the real
Forever client (M2–M4). `[2nd]` reported elsewhere, not independently reproduced. `[?]` unresolved.

---

## 0. Contradictions found during inspection (per the explicit review step)

None of these are severe enough to halt the design — each resolves into a concrete decision below — but
per instruction, listed separately and honestly before the design itself, not silently folded in.

| # | Finding | Classification |
|---|---|---|
| 1 | M0's original v0 harvest contract anticipated an `npc_seen`-style observation kind distinct from quest-scoped evidence. The Observation Lab's *first* `GiverIdentity` implementation dropped this distinction (required `quest_id` unconditionally) and only regained it after the real-export test found 8 real observations being silently discarded. | **Confirmed, already resolved** — M4's importer now handles both cases. M5 must treat NPC-scoped observation as first-class from the start, not rediscover this the same way. |
| 2 | The recorder's own `locale` field is captured and exported by the Observation Lab, but the M4 importer never threads it into any assertion or dataset field — it's currently informational passthrough only. | **Confirmed, minor** — not an architectural blocker. M5 should still capture and export it (cheap, may matter later), but should not claim it's "used" anywhere downstream today. |
| 3 | Guaranteed (non-choice) item reward capture was confirmed working exactly **once** (the item-retry follow-up, quest 92515 — "Simple Leather Satchel"). The real, production-validating M4 export (§6 below) never contained a single guaranteed-item-reward quest — every real quest tested had `num_rewards=0`. Choice items and reputation, by contrast, were independently reproduced across *three* separate real sessions each. | **Needs a design decision** — resolved in §6: choice items and reputation are treated as proven-tier for M5; guaranteed items remain experimental-tier despite a working code path existing, because "worked once, never reproduced" is a materially weaker evidence basis than "worked repeatedly, independently." |
| 4 | The item-name "unresolved" condition (empty string, not nil) that motivated the retry mechanism has been directly observed exactly **once**, in the very first real session. Neither of the two real sessions since (including the actual M4-validating export) has reproduced it — every real item name resolved immediately. | **Needs a design decision** — resolved in §6 and §13: the defensive check and bounded retry are kept (cheap, harmless, already correctly self-labeled as unverified in production data — the literal string `"stub_tested_only_not_yet_observed_fixing_a_real_case"` already appears in real exports today), but M5 must not claim the retry mechanism has ever fixed a real failure, because it hasn't. |
| 5 | The SavedVariables logout/character-select persistence failure (`SAVEDVARIABLES_PERSISTENCE_FINDING.md`) was reproduced twice, but its root cause is `[?]` — client-side, not addon-side, never directly instrumented. | **Confirmed, unresolved root cause** — M5's export workflow (§10) must design around the *symptom* (don't trust implicit logout saves) without claiming to know or fix the *cause*, which may not even be fixable from addon code. |

---

## 1. M5 objective, restated precisely

Not "discover everything about WoW Forever." Specifically:

> Design the smallest production-grade recorder that reliably produces a valid M4 v1 harvest export,
> using only the field set M3/M4 actually demonstrated working on the real client, with the same or
> stricter privacy discipline than the Observation Lab, and no gameplay automation of any kind.

## 2. What gets reused from the Observation Lab, and what doesn't

The Observation Lab was built as a research instrument — deliberately broad (11 modules, most
experimental, a diagnostic `/flab scan`) to answer open questions. A production recorder answers no open
questions; it re-observes a known-good field set repeatedly, for many players. That difference drives
every decision below.

| Observation Lab piece | Verdict for M5 | Why |
|---|---|---|
| `SafeCall` (explicit-index call wrapper) | **Reuse as-is, unchanged** | This is the fix for a real, confirmed bug class (the reputation follow-up's `unpack()`-on-holes failure). No reason to touch working, tested code. |
| `Registry` + `Dispatcher` (module pattern) | **Reuse the pattern, shrink the contents** | The plug-in architecture itself is sound and cheap. What shrinks is *how many modules exist* — no `RewardsCurrency`/`RewardsSpell`/`RewardsTitle`/`RewardsHonor`/`FactionNameResolution` placeholders in a first production release; those exist in the Lab specifically to be available for *future research*, not for production capture of unconfirmed data. |
| `Bootstrap` (meta capture, session ID, PRNG seeding) | **Reuse, unchanged logic** | Already fixed for the two real bugs found (unseeded PRNG, per-observation build snapshot). No open issues here. |
| Proven vs. experimental module status | **Reuse the concept; ship only proven modules** | A production recorder shipped to many players shouldn't carry experimental collectors at all — there's no `/flab enable` audience for a production tool the way there was for one operator's research sessions. If a future capability needs testing, that's a *research* build's job (fork the recorder, same discipline M3/M4 already established), not a flag inside the production one. |
| `api_scan` / `/flab scan` diagnostic | **Drop from the production build** | This was a *research* diagnostic for verifying API availability during experimentation. A production recorder doesn't need to print 22 lines of `type()` checks to end users; if build-sensitivity monitoring is wanted later, it's a smaller, quieter check (§14), not a chat-spamming scan command. |
| Raw SavedVariables Lua export | **Reuse — this is the actual M4 v1 contract's real shape, not a limitation** | M4_PLAN.md originally assumed JSON; the real exporter (and now the real importer, `savedvars.py`) both work in Lua table text. No reason to invent a JSON export path that would need its own from-scratch parser and testing. |
| The 6 "proven" modules' actual field logic (`QuestMeta`, `RewardsXPMoney`, `RewardsItems`, `RewardsReputation`, `GiverIdentity`, `Gossip`) | **Reuse the verified logic, restructure the module boundaries** (§4) | The *what to call and how to interpret it* is all `[V]`-tested against real data; no reason to redo that work. What changes is organizing it around a smaller, purpose-built component set rather than the Lab's broader module list. |

## 3. Evidence-status recap, precisely (not upgraded from the Lab's own labels)

| Field | Status | Basis |
|---|---|---|
| Quest ID, title, level, objectives (full array) | `[V]` | M3, M4 pre-experiment, and the real M4-validating export all agree |
| XP/money, from `QUEST_TURNED_IN` event args only | `[V]` | M3 corrected this from an initial wrong belief with 15 real turn-ins; the real M4 export reconfirmed it again (quest 92528: 350 XP, 0 money) |
| Choice item rewards | `[V]`, repeatedly | M4 pre-experiment, item-retry follow-up, and the real M4 export (quests 92528, 92550, 93926) all show real item names |
| Guaranteed (non-choice) item rewards | `[V]`, but **once, never reproduced** | Item-retry follow-up only; the real M4-validating export contained zero guaranteed-reward quests |
| Item-name "unresolved" (empty string) condition and its retry fix | Condition `[V]` once; retry's efficacy `[?]`, never exercised again | Neither of the two real sessions since has reproduced the empty-string case |
| Reputation (faction ID, raw amount, normalized amount) | `[V]`, repeatedly | Reputation follow-up (cross-checked against real chat math) and the real M4 export (quests 92550, 93926, 92551, all showing the same faction pair `2778`/`2779`) |
| Faction *names* | `[V]` **absent** — `GetFactionInfoByID` confirmed does not exist on Forever | Reputation follow-up; no replacement API assumed |
| NPC creature ID (via GUID parse) | `[V]`, extensively | 14+ distinct NPCs across M3 and M4 sessions, zero parse failures |
| NPC-scoped observation (no `quest_id`) | `[V]` | The real M4 export: 8 of 41 real observations |
| Player interaction position | `[V]` | Every session; always the *player's* position, never the NPC's (documented caveat carried forward) |
| Currency, spell, title, honor rewards | `[?]`/absent | Currency has no verified API name at all; spell/title/honor APIs exist (`type()=function`) but have never returned non-empty real data |
| SavedVariables logout persistence | `[V]` **failure**, root cause `[?]` | Reproduced twice; client-side cause never instrumented |

## 4. Architecture

Smaller than the suggested example in the task prompt — the Lab's already-proven `Registry`/`Dispatcher`
pattern doesn't need a component per capability; it needs one *observer function per proven capability*,
registered the same lightweight way.

```
ForeverRecorder/
  ForeverRecorder.toc
  core/
    SafeCall.lua          -- unchanged from the Lab, verbatim
    Bootstrap.lua          -- meta capture, PRNG seed, per-observation build/session snapshot (unchanged logic)
    Registry.lua           -- unchanged pattern; production build registers ONLY proven observers
    Dispatcher.lua          -- unchanged pattern; drops the diagnostic-scan responsibility (no api_scan)
    GuidUtil.lua            -- unchanged; never returns a raw GUID
    PositionUtil.lua        -- unchanged; player position only, documented caveat unchanged
    Export.lua              -- reuse the manual-save concept; see §10 for the added confirmation step
    SlashCommands.lua       -- shrunk command set, see §16
  observers/
    QuestMeta.lua           -- unchanged logic from the Lab's proven module
    RewardsXPMoney.lua      -- unchanged logic
    RewardsItems.lua        -- unchanged logic (choice items proven-tier; see §6 for the guaranteed-item nuance)
    RewardsReputation.lua   -- unchanged logic
    GiverIdentity.lua       -- unchanged logic, including the NPC-scoped branch fixed in M4
    Gossip.lua              -- unchanged logic
  ForeverRecorder.lua        -- load-time self-check, same pattern as the Lab's own
```

**Deliberately absent from this list**: any experimental-tier module, the `api_scan` diagnostic, and a
`modules/experimental/` folder at all. If a future research question needs a new observer, it gets built
and tested the same way the Lab's own modules were — as a *research* fork first, promoted here only once
proven, exactly matching the standard this whole project has held itself to since M0.

### Component responsibilities

| Component | Responsibility | Inputs | Outputs | APIs/events | Status | First release? |
|---|---|---|---|---|---|---|
| `Bootstrap` | Seed PRNG, capture session ID + build snapshot once per login | `GetBuildInfo`, `GetLocale`, `time`, `GetTime` | `CurrentSessionID`, `CurrentBuildInfo` (in-memory) | `ADDON_LOADED` | `[V]` | Yes |
| `Registry`/`Dispatcher` | Route checkpoints/events to registered observers | Game events | Observation records | `QUEST_DETAIL`, `QUEST_COMPLETE`, `QUEST_TURNED_IN`, `GOSSIP_SHOW` | `[V]` (mechanism), pattern reused | Yes |
| `QuestMeta` | Title, level, objectives | `C_QuestLog.GetInfo`, `C_QuestLog.GetQuestObjectives` | `title.*`, `level.*`, `objectives.*` shape | quest checkpoints | `[V]` | Yes |
| `RewardsXPMoney` | XP/money | `QUEST_TURNED_IN` event args only | xp/money shape | `QUEST_TURNED_IN` | `[V]` | Yes |
| `RewardsItems` | Choice item names; guaranteed items collected but flagged experimental-tier at ingestion (module itself is proven — the *guaranteed-item sub-case* is the caveat, see §6) | `GetNumQuestRewards/Choices`, `GetQuestItemInfo` | reward/choice item shape, `v1_unresolved` flag | quest checkpoints, `GET_ITEM_INFO_RECEIVED` | `[V]` (choice); `[V]`-once (guaranteed) | Yes, with the caveat surfaced in export metadata |
| `RewardsReputation` | Faction ID + raw/normalized amount | `GetNumQuestLogRewardFactions`, `GetQuestLogRewardFactionInfo` | faction reward shape | quest checkpoints | `[V]` | Yes |
| `GiverIdentity` | NPC name + creature ID + position, quest-scoped or NPC-scoped | `UnitGUID`, `UnitName`, `UnitLevel`, `C_Map.*` | `giver.npc` or `sighting.*` shape depending on `quest_id` presence | quest checkpoints, `GOSSIP_SHOW` | `[V]` | Yes |
| `Gossip` | Available/active quest lists seen at an NPC | `C_GossipInfo.GetAvailableQuests/GetActiveQuests` | per-quest availability shape | `GOSSIP_SHOW` | `[V]` | Yes |
| `Export` | Manual save trigger, confirmation step | player command | writes SavedVariables | none (calls `ReloadUI`) | `[V]` (the save mechanism); confirmation step is new, `[?]` until tested | Yes |
| `SlashCommands` | User controls | player input | — | — | New, design-only | Yes |

## 5. Observation lifecycle — unchanged from what M3/M4 already proved, not reinvented

| Checkpoint | Fires for | What's captured | Why this checkpoint |
|---|---|---|---|
| `QUEST_DETAIL` | Viewing a quest before accepting | `QuestMeta`, `RewardsItems`, `RewardsReputation`, `GiverIdentity` (quest-scoped) | Earliest point quest content might be visible; real data showed this can be *incomplete* (quest 92514's choice count read `0` here, correctly `3` only later) — captured anyway, as evidence, not discarded for being incomplete |
| `QUEST_COMPLETE` immediate | Turn-in dialog opens | Same four, re-read | Where most reward data actually resolves |
| `QUEST_COMPLETE` delayed (+1.5s, `C_Timer.After`) | Same dialog, slightly later | Same four, re-read again | Defends against the confirmed real timing gap (quest 92514) |
| `QUEST_TURNED_IN` | The event itself | `RewardsXPMoney` only | The one confirmed-reliable source for XP/money; nothing else reads this event |
| `GOSSIP_SHOW` | Any NPC gossip interaction | `GiverIdentity` (NPC-scoped if no quest context), `Gossip` | Captures general NPC sightings and quest-availability lists, independent of any specific quest |

No new checkpoints invented. `QUEST_ACCEPTED` and `QUEST_FINISHED` remain deliberately unhandled — the
first carries no additional information beyond what `QUEST_DETAIL` already captured (M3 confirmed it
fires with a single argument, the quest ID, nothing else); the second fires multiple times per turn-in
with no payload (confirmed repeatedly) and would only add noise.

**Incomplete data at a checkpoint is preserved, never discarded or backfilled.** If `GetQuestID()` fails
at `QUEST_DETAIL`, that observation simply has no `quest_id` — exactly the situation that produced the
real NPC-scoped evidence discovery. The recorder does not retry `GetQuestID()` itself or guess a value.

**Correlating observations with a quest**: purely by the per-observation `quest_id` field, set once at
capture time from `GetQuestID()`. No cross-observation matching, no "nearest quest" inference, no time-
window correlation of any kind — exactly the discipline already established.

## 6. Reward handling — the specific design decision on item rewards

Every reward observation preserves, separately, never conflated:

```
observed_value       -- exactly what the API returned, positionally (r1..r6), never renamed as if
                         confirmed
capture_checkpoint    -- quest_detail | quest_complete_immediate | quest_complete_delayed | QUEST_TURNED_IN
capture_method        -- which specific API/event produced it
success_state         -- ok=true/false, independent of whether the outer capture ran cleanly
```

**XP/money**: `QUEST_TURNED_IN` event arguments only. The no-argument reward-query APIs
(`GetQuestLogRewardMoney`/`XP`) are never called by the production recorder — M3 found them unreliable on
15 of 16 real quests, and nothing since has changed that finding.

**Choice items**: proven-tier, included in the first release without qualification — independently
reproduced across three real sessions.

**Guaranteed (non-choice) items**: the collection *code* is proven (same module, same logic, already
tested), but the specific *capability* — capturing a guaranteed item reward — has real-client confirmation
exactly once, never reproduced since, including in the very session that validated the rest of the M4
pipeline. **Design decision**: include the capture logic (it's the same code path as choice items, costs
nothing extra to keep), but the exported observation for a guaranteed item should carry an explicit
`evidence_note` distinguishing it from the choice-item case — something a future importer or reviewer can
use to weight it appropriately, rather than silently treating "the code exists" as "the capability is
proven." This is a metadata addition to the *export*, not new addon logic.

**The unresolved-item-name retry**: kept, unchanged, bounded (max 3 retries, unchanged from the Lab).
Every retry-related observation continues to carry the existing honest label
(`"stub_tested_only_not_yet_observed_fixing_a_real_case"`) verbatim — this is not weakened or removed,
because it remains true: the mechanism has still never been observed fixing a real failure.

## 7. Gossip/NPC observations — first-class from the start

Two genuinely distinct claims, never merged:

- **"NPC observed"** (`entity_type="npc"` on import): name, creature ID, position, checkpoint. Produced
  whenever `GiverIdentity` fires with no `quest_id` — most commonly at `GOSSIP_SHOW`.
- **"NPC observed in relation to quest X"** (`entity_type="quest"`, field `giver.npc`): produced only when
  a real `quest_id` was present at capture time.

**Never inferred**: NPC-seen-at-gossip does not imply quest-giver. NPC-seen-at-turn-in does not imply
"the" giver (real data already shows a quest can have two different NPCs across its lifecycle — quest
92528's Missionary Jasaan vs. Constable Aonda — both preserved as separate observations, neither
privileged as "the real" giver). Two `GiverIdentity` observations are never merged just because they
share a `quest_id` or occurred close in time.

## 8. Position handling

Exactly the existing philosophy, unchanged: `ui_map_id`, `x`, `y`, `checkpoint`, captured when
`position_ok` is true, never averaged, never converted into an NPC-location claim, always documented as
the *player's* position at the moment of interaction. No route geometry, no spawn inference — explicitly
future derived-data problems, not this recorder's job.

## 9. Privacy model

Stricter enforcement than the Lab, same principles:

**Never exported**: raw unit GUIDs (parsed creature ID only, never the GUID string — unchanged from
`GuidUtil.lua`), character name, account name, Battle.net identity, realm identity (never read at all —
no code path in the current Lab or this design ever calls anything realm-identifying), chat message
content, arbitrary/unvetted addon data (no observer captures data outside its own documented field list),
persistent personal identifiers of any kind.

**Allowed, and exported**: a random per-session identifier (unchanged generation, now PRNG-seeded),
build ID, locale, quest IDs, NPC creature IDs, observed coordinates, quest/objective/reward data as
already specified, addon/probe version.

**Flagged for explicit project-owner review, not silently included**: none currently proposed. Every
field in this design traces to something M3/M4 already captured and reviewed. If a future observer
proposes a new field, the same review discipline applies before it ships, not after.

## 10. No automatic networking

Unchanged, hard requirement: no `SendChatMessage`/`SendAddonMessage`/sockets/HTTP of any kind anywhere in
this addon. Export is local-file-write only, triggered exclusively by explicit player action.

## 11. SavedVariables reliability — designing around a confirmed failure, not inventing a fix

The confirmed real finding: `/reload`-triggered saves work reliably (repeatedly confirmed); logout/
character-select saves failed twice in testing; root cause unconfirmed and may not be addon-fixable at
all. The production workflow must not pretend this is solved:

```
record locally (in-memory + SavedVariables, same as the Lab)
  -> player runs an explicit save/export command
  -> command triggers ReloadUI() (the ONLY confirmed-reliable save path)
  -> [NEW, untested] a lightweight on-screen or chat confirmation that the save occurred,
     so the player has a visible signal rather than trusting a silent background process
  -> player may continue playing; recording resumes automatically after reload
```

**What this design does NOT do**: hook `PLAYER_LOGOUT` to force a save automatically. That would be new,
untested behavior addressing a client-side failure whose cause isn't understood — exactly the kind of
invented-without-evidence behavior the instructions warn against. The honest position: the addon can
guarantee a save when the player explicitly asks for one; it cannot currently guarantee anything about an
ordinary logout, and should not imply otherwise in its own UI text.

## 12. Export contract

Targets the actual M4 v1 contract (`schemas/harvest_observation.v1.schema.json`), not v0. No new fields,
no schema changes proposed. The recorder's job is to *produce* a conforming export, which the Observation
Lab already does — this design changes which modules exist, not the export shape itself. `module_status`
continues to gate import eligibility (only `"proven"` observers exist in this design at all, so every
observation this recorder produces is import-eligible by construction). `data.ok` and outer `ok` remain
the two independent signals they already are, unchanged.

## 13. Error handling

| Situation | Behavior |
|---|---|
| API doesn't exist | `SafeCall` returns `ok=false`, recorded, never crashes |
| API throws | Same — `SafeCall` wraps every call |
| API returns nil where a value was expected | Recorded as `nil`/absent, never substituted |
| Incomplete data at a checkpoint | Preserved as-is; a later checkpoint may capture more, both kept |
| Missing quest ID | NPC-scoped path (§7) for `GiverIdentity`; other observers correctly produce no assertion-eligible content, per the existing "missing_quest_id" skip logic |
| Missing NPC identity | Observation simply lacks that field; nothing invented |
| Position unavailable | `position_ok=false`, no position fields emitted |
| Reward data unavailable | Recorded as `ok=false` at the module-data level, per §6 |
| Item info temporarily unavailable | Bounded retry (max 3, unchanged), honestly labeled as unverified in practice |
| Build differs from any specific tested build | Recorded and exported as observed fact (§14) — never blocks operation |

No infinite loops anywhere (retry is hard-bounded). No per-frame polling (everything is event-driven).

## 14. Build/version gating

Every observation carries its own `observed_build`, `observed_toc_version`, `observed_version`,
`observed_build_date`, `session_id` — unchanged from the fix already validated in M4. **The recorder does
not disable itself on an unexpected build.** No demonstrated safety reason exists to do so — a build
change might mean some APIs behave differently, which is exactly the kind of fact this recorder exists to
surface (via `ok=false`/`data.ok=false` on whatever stops working), not to hide by refusing to run.

## 15. Performance

Every capture is event-driven, never polled. No per-frame work of any kind. `GET_ITEM_INFO_RECEIVED`'s
retry handler is a no-op unless a retry is actually pending (unchanged from the Lab, already verified).
Observation records are small, bounded dictionaries — no large allocations. SavedVariables growth is
bounded only by how much a player plays before exporting; no automatic pruning is proposed here (a future
decision, not this design's job) but a `/fr clear` command (§16) gives the player manual control. No
route/path computation, no database work, no expensive scans of any kind — none of that belongs in an
addon at all under this project's own architecture.

## 16. User controls

```
/fr status   -- observation count, current session id, build info
/fr save     -- manual save/export (ReloadUI, with the confirmation step from §11)
/fr clear    -- explicit, deliberate local-data wipe
```

Deliberately smaller than the Lab's command set: no `scan` (no diagnostic surface needed in production),
no `enable`/`disable` (no experimental modules exist to toggle), no `list` (nothing to enumerate — the
module set is fixed at build time for a production release). No GUI — a slash-command workflow matches
every prior probe's proven, low-friction pattern.

## 17. Production safety boundaries

Explicitly, by name, matching the instruction's own list precisely: **no** quest automation, quest
acceptance, quest turn-ins, `GetQuestReward` calls (or any equivalent), movement, targeting, combat
assistance, route following, automatic networking, hidden data collection, raw GUID export, or persistent
user identity, anywhere in this design or any code it would produce. The recorder observes; it does not
play the game.

On Blizzard policy specifically: this design describes **a normal, read-only addon using the available
addon API surface** — consistent with the fetched 8-rule policy text already on record (none of the eight
address data collection specifically). This is not a claim of Blizzard approval, and no such claim is made
anywhere in this document or should appear in the recorder's own UI text.

## 18. Implementation sequence (for review, not authorization to build)

1. `core/` — port `SafeCall`, `Bootstrap`, `Registry`, `Dispatcher`, `GuidUtil`, `PositionUtil` from the
   Lab essentially unchanged; strip the `api_scan` responsibility from `Dispatcher`.
2. `observers/` — port the 6 proven modules' logic unchanged; add the `evidence_note` field (§6) to
   `RewardsItems`' guaranteed-item case only.
3. `Export`/`SlashCommands` — the shrunk command set (§16) plus the new save-confirmation step (§11).
4. Stub-environment tests mirroring the Lab's own (see `M5_TEST_PLAN.md`).
5. A real-client smoke test, same discipline as every prior milestone — before any claim this works.

## 19. Known unknowns going into implementation

- Whether the save-confirmation step (§11) is even necessary in practice, or whether `/fr save`'s existing
  chat message is already sufficient — genuinely untested either way.
- Whether the guaranteed-item-reward capability will ever get a second real confirmation; nothing in this
  design manufactures one.
- Whether Forever's build will have changed again by the time this is actually built and tested — build
  gating (§14) is designed to degrade gracefully regardless, but "gracefully" itself remains `[?]` until
  tried against whatever build is current at that time.
- The SavedVariables logout-persistence root cause remains completely unknown; nothing in this design
  claims to have solved it, only to route around it operationally.

---

**M5 production recorder design is complete and ready for review.**
