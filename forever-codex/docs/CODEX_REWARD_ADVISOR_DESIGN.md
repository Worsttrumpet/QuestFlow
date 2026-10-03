# Forever Codex: Reward & Progression Advisor, design (inspection and staged plan)

Status: design. Stage 0 (the read-only probe) is implemented in 0.4.4, Stage 0.1 (every choice inspected) in 0.4.5 and Stage 1 (the normalized Item Facts reader) in 0.4.6 (see `CODEX_REALCLIENT_FIXES.md` sections 40-42); nothing else here is built. The five decisions in section 18 were approved: probe first, own icons plus text tags, coarse tiers first, no alt inventories, and the reward cache records every dialog seen. Written after inspecting the repository, the local QuestieDB checkout and the
project's own real-client research folders.

Evidence labels used throughout:
* **[V]** verified in this repository or in the local QuestieDB checkout (`/home/user/questie/questiedb`, version 1.0.4, the same version the real client reported)
* **[R]** observed on the real Forever client, recorded in this repo (`forever-db/docs`, `m4-*`, `m5-*`, Codex real-client reports)
* **[U]** unverified: general knowledge of the WoW API or of another addon. None of Bagnon, BagBrother, What's Training?, GatherMate2 or DungeonJournal is present in this
  environment, so nothing about their internals could be inspected. Every statement about them is [U] until a probe on the player's client confirms it.

The philosophy (do not rebuild existing data, build the intelligence layer) is kept: Codex gets no item database. It gets readers, an interpretation layer
and a small amount of policy data that no existing source has.

---

## 1. What Codex already has about items

Almost nothing. [V]
* No module reads item data. `QuestieBridge.lua` reads only `LibQuestieDB.Quest`, `.Npc` and `.Object`; the `Item` table is exposed by the runtime (the real report lists
  `Item` among the exposed tables) but is not consumed.
* `Context.lua` (the one read-only snapshot) has character, location, quest log, completions and group. No inventory, equipment, skills or spells.
* Telemetry watches 8 events (XP, level, quest accepted/turned in, quest log, combat start/end). No item, bag, equipment, skill or reward event.
* `Knowledge.lua` says outright that trainers, recipes and pets are "Codex cannot see this yet" because those client APIs are unverified on Forever.
* `Providers/Planned.lua` already registers inert system slots for `trainers`, `professions`, `gathering` and `dungeons`. A Reward Advisor is not a route provider and
  does not belong there, but the profession and gathering slots are where the opportunity providers (section 11) would later attach.
* Shipped in 0.4.1 and relevant: the game's own quest tags (`C_QuestLog.GetQuestTagInfo`, [R] works on Forever) and the dungeon-quest card.

## 2. What QuestieDB exposes for items (actual version inspected) [V]

`LibQuestieDB.Item` (ItemDB) has these fields, nothing else: `name`, `npcDrops`, `objectDrops`, `itemDrops`, `startQuest`, `questRewards`, `flags`, `foodType`, `itemLevel`,
`requiredLevel`, `ammoType`, `class`, `subClass`, `vendors`, `relatedQuests`, `teachesSpell`. Plus `Exists`, `GetAll`, `IdsByName` and `GetAllIds`.

| Wanted | In QuestieDB? | Notes |
|---|---|---|
| item id, name | yes | Forever data: 14,889 items |
| type / subtype | yes | `class` (2 weapon, 4 armor, ...) and `subClass` (weapon type, armor type) |
| equip slot | **no** | no inventory type anywhere |
| stats | **no** | no stats, no armor value, no weapon damage |
| quality | **no** | |
| vendor value (sell price) | **no** | `vendors` is only "which NPCs sell it" (1,751 items) |
| use effect | **no** | `teachesSpell` exists in the schema but 0 Forever items have it |
| required level | yes, **unreliable** | of 1,648 quest-reward weapons/armor, 1,429 have `requiredLevel` 0 or nil |
| item level | yes | present for all 1,648 |
| quest reward relationships | partial | only item -> quests that reward it (`questRewards`): 2,138 items, 2,947 links, 1,792 quests. **No choice-versus-guaranteed flag, no counts** |
| what a quest rewards | **no direct field** | the `Quest` type has no reward items at all; it has to be derived by inverting `questRewards` |
| quest that an item starts | schema yes, data **none** (0 items) | quest-starting items are not covered |
| known sources | yes | `npcDrops` (6,624 items have some drop source), `objectDrops`, `itemDrops`, `vendors` |
| profession relevance | **no** | no recipe, reagent or skill link |

Coverage gap that matters for design [V]: **none of the quests Forever added (ids 90000 and up) has a reward item in QuestieDB, and the Forever data has no Forever-added
item ids at all.** In the player's own reports, Lich's Identity (357) and At War With The Scarlet Crusade (371) have no reward links either. So QuestieDB can
answer "which vanilla quests might reward this item" but cannot be the source for "what does this quest reward".

## 3. What the WoW API gives directly

Proven on the real Forever client [R], recorded by the M4/M5 probes: at `QUEST_DETAIL` and `QUEST_COMPLETE`, `GetNumQuestChoices()`, `GetNumQuestRewards()` and
`GetQuestItemInfo(kind, i)` ("choice" / "reward") return the reward items. Choice items repeatedly confirmed; guaranteed items confirmed exactly once. The
name can read as an empty string at first and resolve later (seen once; `GET_ITEM_INFO_RECEIVED` is the retry hook). The fifth return of `GetQuestItemInfo` is
unconfirmed on Forever (observed with two different values).

Not probed anywhere in this repo, so all [U] on Forever: `GetItemInfo` / `C_Item.GetItemInfo` (type, subtype, equip location, sell price, level, required level),
`GetItemStats` (the stat table, and weapon DPS), `GetQuestItemLink`, `GetInventoryItemLink("player", slot)`, `C_Container` / `GetContainerItem*`, `GetItemCount`,
`GetItemSpell` (use effect), `IsUsableItem`, `IsSpellKnown`, skill-line APIs (weapon and armor proficiencies), and the events `GET_ITEM_INFO_RECEIVED`,
`PLAYER_EQUIPMENT_CHANGED`, `BAG_UPDATE_DELAYED`, `SKILL_LINES_CHANGED`, `LEARNED_SPELL_IN_TAB`. Item data may not be cached: the first read of an item the
client has not seen returns nil until `GET_ITEM_INFO_RECEIVED`, so every item read has to be asynchronous-tolerant.

Consequence: the live reward dialog and the item-link APIs are the authoritative source for the CURRENT quest; they cannot see a quest the player has not reached.

## 4. Bagnon / BagBrother [U]

* Not needed for the current character: bags, equipped items, counts and (after a visit) bank counts come from the client API (`GetItemCount(id, true)`, container and
  inventory-link APIs). Codex must not depend on Bagnon.
* BagBrother's value is OTHER characters' and offline bank data (alts). It stores that in its own SavedVariables in an internal format; there is no documented public API
  that I know of. Recommendation: do not integrate in the first stages. Revisit only if "do my alts own this" becomes a wanted feature, and then only after a
  probe shows a stable, read-only interface.

## 5. What's Training? [U]

* No documented public API known. Its trainer-ability data is its own bundled data, and the project rule is not to copy another addon's database.
* What Codex needs from it is narrow: "has this character learned the weapon/armor skill this item needs". That should come from the client (skill lines, or the
  proficiency spells with `IsSpellKnown`), checked by a probe, with a small class table as fallback. It is the key input for the green-versus-yellow badge.
* Optional later: if What's Training? turns out to expose something readable, it is an optional enrichment, never a requirement.

## 6. GatherMate2 [U]

* Holds known node positions and types; it may expose functions, or only SavedVariables. Neither is verified here.
* It is an OPPORTUNITY source, not a reward source (section 11): "a Mining node within a short detour of the planned route". It must be optional and read-only. Whether its
  data is available to read, and under what license, has to be checked before any integration. Do not copy node data into Codex.

## 7. DungeonJournal [U]

* Not present, no interface known, license unknown. Do not integrate, do not copy. The shipped dungeon-quest card uses the game's own quest tags and the game's area
  names, which need no other addon. Dungeon loot tables, if ever wanted, come from QuestieDB drop data (`npcDrops`) plus the game's item API.

## 8. What Codex has to add itself (the only "data" we write)

1. A **valuation policy**, not facts: per class, which stats matter and how much (a short weight table), used to turn "Item A versus Item B" into a percent change. This
   is policy and will be wrong sometimes; it must be labelled as an estimate everywhere.
2. A **proficiency fallback**: class -> allowed armor and weapon types (about a dozen lines per class), used only if the client cannot answer "can I use this".
3. **Thresholds** for the badge tiers and for the recommendation rules (section 13), kept in one file and tuned from real playtests.
4. A **learned reward cache** (SavedVariables): when the player sees a quest's reward dialog (`QUEST_DETAIL`), Codex records which items it offered, tagged
   `src=observed verified=true`. This is how Forever-added quests (which QuestieDB does not cover) get reward knowledge, and it is how Codex learns a future reward is
   guaranteed (the quest is in the log and its rewards were seen).
5. Nothing else. No item database, no loot tables, no recipe database, no node database.

## 9. Optional integrations versus what must work alone

Must work with no other addon installed: reading the reward dialog, equipped items and bags from the client, usability, the valuation, the recommendation, the learned
reward cache, the "sell / keep" advice from known quest and in-log needs.

Optional (QuestieDB is already optional in Codex): item relationships (`questRewards` for future rewards, `vendors`, `npcDrops`, `class`/`subClass`, `itemLevel`).
If QuestieDB is missing the advisor still advises on the live dialog; it just cannot look ahead.

Optional and deferred, each only after a probe and a license check: GatherMate2 (nodes), BagBrother (alts), What's Training? (nothing planned), DungeonJournal (nothing planned).

## 10. Where it lives in the existing architecture

Separate from the route planner, as required. The planner is not changed; the advisors READ its output.

```
Context.Build (add read-only readers: equipped, bags, skills, item facts)
      |
      +--> Planner/Engine ............ unchanged: "where should I go?"  -> plan (sequence, stops, seconds)
      |
      +--> Advisor (new, reads ctx + plan, never writes to the planner)
              Items.lua       item facts: ONE read path, per-field provenance (game / questiedb / observed)
              ItemBridge.lua  optional QuestieDB item reader (parallel to QuestieBridge.lua)
              Gear.lua        equipped item per slot + usability/proficiency
              Horizon.lua     "what better thing is coming?" from plan stops + known/observed rewards
              Rewards.lua     REWARD ADVISOR: describe each reward, then recommend (two separate outputs)
              Inventory.lua   keep / use / sell: future needs from the quest log and QuestieDB
              Utility.lua     COMBAT UTILITY: use effects
              Opportunities.lua  OPPORTUNITIES: optional side-things near the route (nodes later)
      |
      +--> Presenter / UI: a REWARD card in the tracker (and a line in /codex report)
```

The five systems named in the brief map to five small modules that share `Items.lua` and nothing else. No shared score.

Reused as is:
* `Registry` provenance pattern (`src=`, `verified=`) for item facts.
* `QuestieBridge` structure (optional dependency, `pcall`-guarded reads, caches, "unknown stays unknown") as the template for `ItemBridge`.
* `Context.reader` (test-replaceable readers) for equipment, bags and skills.
* `Planner` outputs: `plan.diag.sequence`, per-stop seconds and the `Planner.Locate` / `Engine.Distance` helpers, for "how soon" and "detour cost" (Horizon, Opportunities).
* The detour limit logic already behind ALSO DO (`SMALL_DETOUR`) for opportunities: an opportunity is only offered inside the same small-detour budget.
* `Telemetry` event registry (with its `UNPROVEN`/`proven` status per event) for the new events.
* `Diag.PlaytestLines` for a new report section (the quest-tag line in 0.4.1 is the model: it told us what the real client does).
* `Overlap`/`Presenter`/`PageCodex` card pattern for a REWARD card, and `make_art.py` for badge icons.
* `Dungeons.lua` as the template for a small, display-only module.

## 11. Opportunity system (concept only)

A provider returns located candidates with a type and a value; the advisor asks the planner's own geometry whether the candidate is inside the detour budget of the
CURRENT route. Offer it only if it is on or very near the route; never create a route for it unless the player asks. Gathering nodes (GatherMate2, optional) and
"you will kill these anyway" (future-use drops) are the first two instances. It reads the plan; it never adds stops to it.

## 12. Reward set: where the information comes from

| Situation | Source | Certainty |
|---|---|---|
| The reward dialog is open (current quest) | game dialog APIs [R] | authoritative |
| A quest in the log whose dialog was seen before | Codex's learned reward cache | observed, guaranteed |
| A future quest on the planned route | QuestieDB `questRewards` inverted | "possible reward", partial, no choice flag |
| A Forever-added quest never seen | nothing | unknown (stays unknown) |

"Is the future reward guaranteed?" can only be answered "yes" from the learned cache, and "maybe" from QuestieDB. The advisor must say which.

## 13. Description versus recommendation (kept separate)

* **Description** is a fact about the item against the player's current gear: major / good / slight / tiny upgrade, potential upgrade (needs training), not usable, combat
  utility, future use, sell. It never says "take it".
* **Recommendation** is a separate, explainable verdict built from rules, never from one score: for example "take A: it is a good upgrade and nothing better is
  expected soon", or "take the vendor reward: A is +0.7%, a better chest is expected in about 3 quests, the other reward sells for 5g". Every recommendation prints the
  reasons it used, in words. Inputs: upgrade size, how soon and how certain the replacement is (Horizon), how long the item will realistically be used, the alternative
  reward's value, usability, and (only later) survivability.

Proposed starting thresholds (PROPOSALS to calibrate, not to hardcode yet; the unit is the estimated change of a class-weighted power number for that slot):
negligible below about 2 percent, slight about 2 to 6, good about 6 to 15, major 15 and above; "replaced soon" means a known better reward within about 3 quests or 15
minutes of planned route; a vendor alternative counts as meaningful when it is a noticeable fraction of the player's expected income at that level (needs real
data to set). These are placeholders. The percent figures depend entirely on the valuation policy of section 8, which is the weakest part of the design.

## 14. Telemetry / events needed (observation only, registered as `UNPROVEN` until seen)

`QUEST_DETAIL` and `QUEST_COMPLETE` (reward dialog open; for the reward cache), `GET_ITEM_INFO_RECEIVED` (late item data), `PLAYER_EQUIPMENT_CHANGED` (what the player
actually equipped), `BAG_UPDATE_DELAYED` (what they took or sold), `SKILL_LINES_CHANGED` and `LEARNED_SPELL_IN_TAB` (proficiencies, later trainer learning),
`MERCHANT_SHOW` (sell advice context). Plus one Codex event: "advice shown" with the recommendation and, later, what the player did, so advice quality can be judged.
Same privacy rules as today: ids and counts only, no names or chat. The quest turn-in event does not say which reward was chosen; that has to be inferred from the
bag/equipment change after the turn-in.

## 15. What is needed to test this safely in Forever

1. A **read-only probe section in `/codex report`** first (no behaviour): which item APIs exist, a sample `GetItemInfo` / `GetItemStats` of the equipped weapon and chest, whether
   `GetQuestItemLink` works, `IsUsableItem` on an item the class cannot use, which skill lines the client reports for weapon proficiencies, which of the events fire. The
   quest-tag line in 0.4.1 proved this approach: one report told us the API exists and what ids it returns.
2. Item fixtures for the stub test client (fake `GetItemInfo`/`GetItemStats`/equipment) so the advisor logic is tested without the client, same as the planner.
3. A handful of real reward dialogs captured on Forever (the M4/M5 recorder already stores some) to check the reward cache against.
4. No protected or taint-prone APIs, and no `COMBAT_LOG_EVENT_UNFILTERED`; tooltip hooks (a Pawn-style "upgrade" line inside the item tooltip) are a later, separately
   tested step because of the taint history on this client.

## 16. Major technical and licensing concerns

* **QuestieDB reward coverage is incomplete** (section 2): no Forever-added quest has reward items, no choice flag. The advisor's future-reward look-ahead is therefore
  weak by construction and must label itself "possible".
* **Item data is asynchronous** and may be missing on first read; every path needs a "not loaded yet" state.
* **The valuation is the riskiest part**: percent upgrade numbers depend on class weights we write ourselves. They must be presented as estimates, and the first release
  should lean on coarse tiers, not on false precision.
* **Usability on Forever is unverified**: proficiency and "can this class use it" must come from a probe, not from assumptions about Classic.
* **Licensing:** QuestieDB and Questie are GPL-3.0 with unclear upstream provenance (`docs/LICENSING.md`). The existing stance (consume at runtime through its API, copy
  no code or data into the repo) already applies unchanged to the Item table. No other addon's data may be copied; for GatherMate2, What's Training?, DungeonJournal and
  BagBrother the license and any public interface are unchecked, so they stay out of the required path. Wowhead and similar sites remain unread (their terms bar scraping).
* **ASCII-only UI:** the requested emoji badges conflict with the project's ASCII-only UI rule. Proposal: small own-art badge icons (the same generator as the quest
  icons) plus plain-text tags, in colours.
* **Taint:** UI near the Blizzard quest reward frame (to show badges on the reward icons) is the part most likely to trigger the "blocked action" popup seen with the
  marker probe. Start with Codex's own card, which is safe.

## 17. Minimal staged implementation plan

Each stage is a normal release (new patch version, tests, packaged ZIP), and each stops at a checkpoint where the real client can answer a question.

* **Stage 0, probe (observation only).** Add an "ITEM APIS" section to the report and register the new events as `UNPROVEN`. No advice. Output tells us which APIs
  and events exist on Forever and what they return. Decision point: confirm the APIs before any logic.
* **Stage 1, facts.** `Items.lua` (+ `ItemBridge.lua`): one item-facts read path with provenance, async-safe, tested on fixtures. `Gear.lua` reads equipped items.
  Still no recommendations; the report can print "reward items and what you wear in that slot".
* **Stage 2, describe.** The valuation policy and proficiency, then the DESCRIPTION badges only (major/good/slight/tiny upgrade, potential upgrade, not usable, sell). A small
  REWARD card in the tracker while the dialog is open. Explicitly no "take this" yet.
* **Stage 3, learn.** The reward cache (observed rewards per quest) and the "advice shown / what you took" telemetry. This gives Horizon its guaranteed rewards and gives us data
  to calibrate thresholds.
* **Stage 4, recommend.** Horizon (replacement soon, from the plan and the cache and QuestieDB) and the explainable recommendation rules, including the vendor alternative.
* **Stage 5, the rest, one at a time:** keep/use/sell inventory advice, combat utility (use effects), then opportunities (gathering, optional GatherMate2) after its probe.

## 18. Decisions needed from the project owner

1. Confirm Stage 0 first: ship the read-only item probe before any design above is built on assumptions.
2. Badges: own-art icons plus text, instead of emoji (ASCII-only rule). Agree?
3. Valuation: are coarse tiers (no precise percentages shown, only the tier) acceptable for the first release? The percentages can stay internal until calibrated.
4. Are alts' inventories (BagBrother) wanted at all? Recommendation: no, not now.
5. Should the learned reward cache record rewards for every quest the player views, or only quests in the log? Recommendation: every quest dialog the player opens.
