# M4 Planning Document

**Status: planning only. No code, schema, or test files were written or modified to produce this.**
M0, M1, M1.5, M2, and M3 are frozen and untouched. This document lives under a new `planning/`
directory, additive to the frozen tree, matching the precedent set by `research/m1_5/` in M1.5.

Evidence tags used throughout, per project convention: `[V]` directly verified on the real client.
`[2nd]` reported by an external source, not independently reproduced. `[?]` unresolved.

---

## Revision note (research pass)

This document was revised after reviewing a follow-up research pass (Warcraft Wiki API/event pages
`[2nd]`, a legacy Fandom API mirror `[2nd]`, direct inspection of QuestieLearner's real source code
`[2nd]` for technique only — not Forever proof, and a freshly-fetched Blizzard official UI Add-On
Development Policy — a primary source, though still `[2nd]` as to Forever specifically since none of it
was tested there). **Nothing below was upgraded to `[V]` on the strength of this research alone** — where
it conflicts with M3's actual data, M3's data wins (see the item-reward discussion under §3a).

Changes made, each marked inline as **(revised)** at its section:

1. Added a **pre-M4 micro-experiment (§3a)**, gating only item-reward and gossip-availability fields —
   the rest of M4 is unblocked and proceeds regardless of that experiment's outcome.
2. Generalized the reward `capture_context` field into a proper lifecycle-checkpoint enum (§4, §5).
3. Added an explicit no-automatic-network-broadcast principle to the contract (§4), naming the
   `QuestieLearnerComms` anti-pattern this rules out.
4. Added `addon_version`, `probe_version`, `locale` as required export-level metadata (§4) — a schema-only
   addition, no database change.
5. Flagged NPC-position averaging as a future `derived_position` table (parallel to M1's existing
   `derived_coordinate`), explicitly deferred out of M4 (§6, §7).
6. Refined the prerequisites row with the specific structural reason inference is required (§8).
7. Updated the licensing framing (§ risks) to reflect the now-fetched addon policy text, while explicitly
   **not** treating the still-unresolved EULA data-mining question as newly settled.

**On the item-reward finding specifically**: the research's "call the reward getters at the completion
dialog" theory does not, on its own, explain M3's own data — M3 already called `GetQuestLogRewardMoney`/
`XP` at `QUEST_COMPLETE` (matching that theory) and got zero 15 of 16 times, while `QUEST_TURNED_IN`'s
arguments carried the real values instead. The research's actual new contribution is different: untested
*item-specific* functions (`GetQuestItemInfo`, `GetNumQuestRewards`/`Choices`), an untested checkpoint
(`QUEST_DETAIL`, and a delayed re-read), and an async item-cache-retry pattern — none of which M3 ever
exercised, since no M3 quest happened to carry an item reward. That is a genuinely open question, not a
re-litigation of something M3 already settled the other way. Hence: experiment required, not assumed.

---

## 1. What did M0–M3 actually establish?

**M0** (desk research): identified the candidate DB2 tables, found the QuestV2/quest-count discrepancy
across sources, validated the UiMapAssignment coordinate transform against 14 ATT flight paths
(mean error 0.09%), and flagged licensing constraints (Wowhead, ForeverGuide, Questie, RestedXP excluded).

**M1** (data/evidence foundation, code): built the provenance model (`dataset`, `assertion`,
`assertion_status_log`), the tri-state quest-evidence view (`v_quest_shell`), the ranked-resolution
policy (`policy.rank`), the ATT importer, and the coordinate transform with tests. Designed but did not
implement the harvest contract (`schemas/harvest_observation.v0.schema.json`, design-only).

**M1.5** (research spike): established that QuestV2 is very likely a real client table (`[2nd]` at the
time), that DB2 tooling (WoWDBDefs, `wow.tools.local`, `wowsims/mop`'s `db2tool`) can plausibly read
Forever's format, and that build identity requires multiple corroborating signals since no single one is
proof. Flagged the EULA data-mining question as unresolved, not decided.

**M2** (real-client extraction test): **`[V]` QuestV2 is confirmed real** — extracted from the operator's
actual client, SHA-256-verified, layout-hash-matched against the pinned WoWDBDefs definition. Header
shows 6,690 total records: 6,600 unencrypted (matching prior `[2nd]` reports exactly) plus **90 encrypted
records neither prior source disclosed**. Five independent signals converged on build `1.60.1.69913`.
QuestV2's own internal `schema_string` read an unrelated `"WOWSTATIC_1_60_1_69800"` — a concrete,
real-world instance of exactly the failure mode the provenance model's `claimed_build_id` vs
`observed_build_id` distinction was designed to guard against.

**M3** (addon/API real-client test): **`[V]` A normal, read-only, policy-compliant addon can capture
quest ID, title, level, objectives, XP/money rewards, quest-giver creature ID and name, and interaction
coordinates**, for quests actually played — demonstrated across 3 sessions, 18 accepts, 23 turn-ins, 14
distinct NPCs. Also found and fixed two real implementation bugs (title-capture truncation,
reward-capture timing), and reversed one conclusion (which reward API is reliable) once the sample size
grew from 1 to 15 — both corrections preserved in the record rather than smoothed over.

## 2. What original assumptions are now confirmed, weakened, or obsolete?

| Assumption (origin) | Status after M2/M3 |
|---|---|
| QuestV2 is a real client table with only ID/UniqueBitFlag/UiQuestDetailsThemeID (M0) | **Confirmed**, `[V]` |
| Quest content (title, objectives, rewards, giver) is not in client DB2 tables, must come from elsewhere (M0/M1) | **Confirmed**, `[V]` — and M3 confirmed a concrete "elsewhere" (the addon API) actually works |
| "Server-side data can only come from a real recorder we haven't built yet" (M1 harvest contract framing) | **Weakened.** M3 shows a disposable *probe* already gets most of the way there with off-the-shelf documented APIs. The gap between "design-only contract" and "working recorder" is smaller than M1 assumed. |
| Harvest contract's `quest_record` kind = `{api, args, returns}` per raw API call (M1 `schemas/harvest_observation.v0.schema.json`) | **Weakened/needs revision.** M3's most reliable reward data came from **event arguments** (`QUEST_TURNED_IN`), not from a modeled "API call with args/returns" — the v0 schema's `api_return` shape doesn't naturally fit an event payload. Needs a v1 revision, not a rewrite. |
| "No personal data: NPC/object GUIDs themselves are not exported, only derived entity IDs" (M1 `HARVEST_CONTRACT.md` §4) | **Not weakened — but M3's own probe violated it.** The M3 probe recorded raw NPC GUIDs alongside parsed creature IDs, by deliberate design, to validate the parsing technique itself. That was a reasonable debugging choice for a disposable research probe; it must **not** be carried into any M4/M5 production exporter. Flagged explicitly so this doesn't quietly become the new norm. |
| `objective_progress` kind takes one `objective_index` at a time (M1 v0 schema) | **Obsolete.** `[V]` `C_QuestLog.GetQuestObjectives(questID)` returns the full objectives array in one call, each with `type`, `text`, `numFulfilled`, `numRequired`, `finished`. The per-index design in v0 doesn't match how the real API actually shapes data. |
| "Whether Forever exposes the quest-data request API reliably" — `[?]` (M1 `HARVEST_CONTRACT.md` "Unverified items") | **Resolved to `[V]` yes, with specific caveats** (see §8) — the single biggest open question the harvest contract was built around is no longer open. |
| `harvest_observation` as a `source_kind` (schema/policy already support it) | **Never exercised by an importer.** `db.py`/`policy.py` have supported `source_kind='harvest_observation'` since M1, and `test_db_quests_assertions.py` already uses it twice in synthetic unit tests to validate the ranking policy generically — but no importer has ever constructed one from an actual external data source, the way `att/importer.py` does for `third_party_import`. M4 is the first milestone that would do so. |
| `QuestCache.wdb` may not persist on Forever, may have moved entirely to `DBCache.bin` (M1.5 open question) | **Resolved to `[V]`: it persists and is actively written to** (61,265 → 62,446 bytes after one session). Per-record content remains undecoded — that part of the question is still open. |
| Coordinate transform validated only on 14 ATT flight paths, thin/absent for several zones (M1) | **Unchanged by M2/M3.** Not retested this phase. Still the known limitation from M0/M1. |

## 3. Smallest useful M4 milestone

**M4 = make the existing, already-designed `harvest_observation` source-kind real, informed by exactly
what M3 proved works — nothing more.**

Concretely: a revised harvest-observation contract (v1, correcting the specific v0 mismatches M3 found),
an importer that turns a harvest-shaped export into `assertion` rows using the *existing* schema and
*existing* resolution policy (no new tables, no new ranking logic), and tests proving the ingestion is
safe and correct.

**M4 explicitly does not include**: a new recorder addon (the M3 probe was a disposable research tool,
not a production exporter — building a real one is later work); cache-file (`.wdb`) content decoding;
solving the reward-API selection-state question left open in M3; prerequisites/chains; any UI, API, or
route-planning work. Each of these is listed again in §9.

This keeps M4 narrow: it is entirely pipeline-side (Python, schema, tests), it can be built and tested
using **synthetic fixtures modeled on M3's real findings** (field shapes, event names, the confirmed
reward-source distinction) rather than needing a new live-client session, and it closes the gap between
"the contract is designed" and "the contract has ever ingested anything" for the first time since M1.

### 3a. Pre-M4 micro-experiment **(new, revised)**

Two fields remain genuinely untested on Forever: **item rewards** and **gossip active/available quest
state**. Both are deferred behind a small, targeted experiment — not assumed, and not blocking the rest
of M4.

**Scope**: a small, disposable extension of the *final* M3 probe logic (forked into a new sibling folder,
e.g. `m4-pre-experiment/`, not modifying the frozen `m3-experiment/` files), tested against a stub WoW
environment before use, same discipline as every M3 probe change. It should:

- On a small batch of quests **known to carry an item reward** (M3 never tested one — `GetNumQuestRewards`
  read `0` on every quest observed), call `GetNumQuestRewards`/`GetNumQuestChoices` +
  `GetQuestItemInfo("reward"/"choice", i)` at three checkpoints: `QUEST_DETAIL`, immediately on
  `QUEST_COMPLETE`, and again after a short delay on `QUEST_COMPLETE` — all strictly before the player
  clicks the button that calls `GetQuestReward` (never call that function programmatically; it commits
  the turn-in).
- Retry item-name resolution on `GET_ITEM_INFO_RECEIVED` rather than trusting a single read, mirroring
  the same async-cache pattern already glimpsed (but not resolved) in M3's session-1 blank-item-name
  objective quirk.
- Separately, at `GOSSIP_SHOW`, call both `C_GossipInfo.GetAvailableQuests()` and `GetActiveQuests()` and
  log the raw return shape, independent of the already-proven `GOSSIP_SHOW` + `UnitGUID` technique.

**Outcome drives the schema, not the other way around**: if item rewards are captured reliably at a
specific checkpoint, that checkpoint and shape join the v1 contract (§4/§5). If the experiment is
inconclusive or negative, that is itself documented as a clean finding — same honest-negative-result
standard M3 already set — and item rewards stay excluded from v1, revisited later rather than guessed at.

**This experiment does not block the rest of M4.** Schema/importer/test work for the already-proven
fields (quest ID, title, level, objectives, XP, money, giver identity, coordinates) proceeds immediately
and independently.

## 4. What the M4 data-acquisition contract should look like

Revise `schemas/harvest_observation.v0.schema.json` → `v1`, keeping the v0 principles intact
(observed-not-interpreted, build provenance required, no personal data, positions as-returned) and fixing
the two concrete mismatches M3 exposed:

1. **Add an `event` variant alongside `api_return`.** An observation's `values` array should be able to
   hold either `{api, args, returns}` (a deliberate API call) or `{event, args}` (data that arrived as
   event arguments, e.g. `QUEST_TURNED_IN`'s `questID, xpReward, moneyReward`). This is additive to v0,
   not a breaking change to its principles — it's the same "observed, not interpreted" idea applied to a
   data shape M0/M1 didn't anticipate.
2. **Change `objective_progress`'s shape** from one-objective-per-observation
   (`objective_index` + `values[]`) to one observation holding the **full objectives array** as returned
   by `C_QuestLog.GetQuestObjectives`, preserving each objective's `type`/`text`/`numFulfilled`/
   `numRequired`/`finished` as reported, uninterpreted.
3. **Explicitly forbid raw unit GUIDs in the exported JSON**, only the parsed numeric creature ID plus the
   *method* used to derive it (e.g. `"guid_field_index": 6`) — restating and hardening the existing
   `HARVEST_CONTRACT.md` §4 principle, specifically because §2 shows the M3 probe didn't follow it.
4. **Keep `build_source` exactly as v0 defined it** (`client_api` / `toc_only` / `user_declared`) — M2/M3
   validated that `GetBuildInfo()` is reliably callable, so `client_api` should be the expected common
   case for any real recorder, not a fallback.
5. **Record the exact lifecycle checkpoint a value was read at, as an enum, not a coarse label**
   **(revised)**: `quest_turned_in_event` | `quest_detail` | `quest_complete_immediate` |
   `quest_complete_delayed` | `quest_log_reward_query`. My original draft only distinguished
   `quest_turned_in_event` vs `quest_log_reward_query`; the pre-M4 experiment (§3a) needs the finer
   granularity to tell which specific checkpoint, if any, works for item data — and recording it this way
   means a future consumer can weight or filter by the M3-confirmed reliability difference (event
   arguments over no-argument queries) without the schema itself picking a winner.
6. **Never call, or design toward calling, a function that commits/finalizes a turn-in as part of any
   read path** **(new)** — explicitly naming `GetQuestReward` as the concrete example. This was implicit
   in M3's "read-only, no automation" principle but the research made the specific hazard (item reads must
   happen *before* this call, and calling it programmatically would itself be gameplay automation) worth
   codifying by name, not just by general principle.
7. **No automatic network transmission of observations, ever** **(new)** — export is manual/opt-in only,
   written to a local file the operator inspects and sends. This rules out, by name, the P2P
   auto-broadcast pattern found in `QuestieLearnerComms` (a hidden chat channel + `SendChatMessage`,
   exposing the sender's `UnitName`). This was already implicit in "no new recorder addon in M4" but
   deserves to be a standing contract principle, not just a scope boundary that happens to avoid it this
   milestone.
8. **Add required export-level metadata** **(new)**: `addon_version`, `probe_version`, `locale`, and an
   optional minimized character context (level and class only, included only when the observed fact
   plausibly depends on them — e.g. a class-restricted quest) — never character name, account, or realm
   beyond what's needed to prevent cross-realm quest-ID collisions. This needs no database schema change
   (`dataset.notes` is already free-form); it only means the v1 JSON schema and importer should treat
   these as first-class fields rather than leaving them implicit.

## 5. What fields a harvested quest observation should contain

Per quest-lifecycle observation, mapping directly to what M3 confirmed is obtainable:

- `quest_id` (int) — `[V]` always available
- `title` (string, optional) — `[V]` available via `C_QuestLog.GetInfo(index).title`, explicitly extracted (not a generic table dump, per the M3 title-capture bug and its fix)
- `level` (int, optional) — `[V]` same source
- `objectives` (array of `{type, text, numFulfilled, numRequired, finished}`, optional) — `[V]`
- `reward_xp` (int, optional), `reward_money` (int, optional) — `[V]`, sourced from `QUEST_TURNED_IN`
  event arguments per the M3-corrected finding, with `capture_context` recording that source
- `giver_creature_id` (int, optional) — `[V]`, derived from a unit GUID, GUID itself never exported
- `giver_name` (string, optional) — `[V]`
- `interaction_position` (`{ui_map_id, x, y}`, optional) — `[V]`, fractional 0–1 coordinates as the API
  returns them, no derived/converted value trusted from the recorder (unchanged v0 principle)
- `observed_build_id` — required, from `GetBuildInfo()`
- `session_id` — random per export, per the existing no-personal-data principle
- `addon_version`, `probe_version`, `locale` — required, export-level **(new, §4.8)**
- **Deferred pending the §3a experiment, not yet in v1** **(revised)**: `items[]`
  (`{itemID, name, count, quality, checkpoint}`, checkpoint from the §4.5 enum, with `GetItemInfo`-cache
  retry via `GET_ITEM_INFO_RECEIVED` per the same async-name-resolution pattern already glimpsed in M3's
  blank-item-name quirk) and `gossip_available_quests[]`/`gossip_active_quests[]` (raw shape, if
  `C_GossipInfo.GetAvailableQuests`/`GetActiveQuests` prove to work on Forever at all). Neither is assumed
  present; both join v1 only if the experiment confirms them, exactly as documented findings either way.
- Explicitly **still not included** even after this revision: prerequisites, quest chains (structurally
  inference-only, see §8), giver/turn-in NPC's own *position* beyond the player's observed position (the
  existing harvest-contract caveat, unchanged).

## 6. Representing observations, sources, builds, confidence, and provenance

**No schema changes needed here** — M1's model already covers this correctly; M4 just needs to use it:

- Each harvest export becomes one `dataset` row: `source_kind='user_file'` (the export file itself, as
  M1's `acquire.user_file_record` already models any operator-supplied file), `origin='user_supplied'`,
  `redistributable=None` (unresolved, same default as every other dataset — M4 does not decide this).
- Each field observed becomes an `assertion` row: `source_kind='harvest_observation'`,
  `confidence='observed_first_hand'`, `status='observed'`, `observed_build_id` set directly from the
  export's `build_source='client_api'` value (this is the one case where `observed_build_id` — not just
  `claimed_build_id` — is legitimately set on first ingestion, since the recorder had first-hand access
  to `GetBuildInfo()`, unlike a third-party mirror).
- `source_locator` should record enough to trace an assertion back to a specific observation within a
  specific export (e.g. `"<export_id>:event[12]"`), mirroring how the ATT importer uses `file:line`.

**Position is the one field category this model doesn't fit well, and M4 should not try to fix that now
(new, revised)**: QuestieLearner's actual source implements a running-average "healing" model for NPC
positions (`healedX = (oldX*count + newX) / (count+1)`, capped storage, oldest-eviction) — genuine
evidence that repeated position sightings should *converge*, not get picked-one-discard-rest the way a
discrete field like a title correctly does. M4 should **not** implement this: it would mean new merge
logic beyond what §7 already establishes as sufficient. Instead, M4's importer should insert each observed
position as its own `assertion` (the schema already supports this with zero changes — distinct `(x,y)`
readings naturally produce distinct `value_hash`es), and leave position averaging to a **future**
`derived_position` table, structurally parallel to M1's existing `derived_coordinate` — rebuildable from
raw assertions, never itself authoritative. Recording this now, building it later.

## 7. Merging multiple observations of the same quest without destroying conflicting evidence

**No new merge logic is needed — the existing `policy.rank` + `assertions.resolve()` already does this
correctly**, and M4's job is to confirm that with real harvest data, not to build something new:

- Two different operators' harvest observations of the same quest's title are two separate `assertion`
  rows (same `entity_type='quest'`, `entity_id`, `field='title'`, different `source_dataset_id`). If they
  agree, `resolve()` already returns both as tied winners (same rank, same tier). If they disagree, both
  are kept — one becomes the winner by tie-break (newest `observed_build_id`), the other stays queryable
  via `others`, exactly as already tested for ATT-vs-ATT conflicts in `test_db_quests_assertions.py`.
- `harvest_observation` (rank 300) sits below `client_table` (400) and above `third_party_import` (200)
  in `policy.SOURCE_RANK` — meaning a harvest-observed title would already correctly outrank an ATT-based
  guess at the same field, without any new code, once such an assertion exists.
- **M4's actual work here is a new test class**, not new logic: prove that two synthetic harvest exports
  disagreeing on one field produce two coexisting assertions, that `resolve()` picks sensibly, and that
  neither is deleted — following the exact pattern `test_db_quests_assertions.py` already uses for other
  source kinds.
- **Carve-out, revised**: the above holds for discrete/categorical fields (title, level, giver ID). It
  does **not** hold for position, per the note at the end of §6 — that is a known, explicit exception to
  "no new merge logic needed," deferred to a future `derived_position` table, not solved by M4's
  rank-and-resolve approach.

## 8. Where each kind of information should come from

| Kind | Source | M3/M2 status |
|---|---|---|
| Quest existence (ID, UniqueBitFlag, UiQuestDetailsThemeID) | **client DB2** (QuestV2) | `[V]` M2 |
| Title, level, objectives, XP/money rewards, giver identity, interaction coordinates | **addon observation** (player interaction, captured via the harvest contract) | `[V]` M3 |
| Item rewards | **addon observation, pending the §3a experiment** — genuinely untested, not assumed working or absent | `[?]` |
| Prerequisites, quest chains | **must be inferred (future derived data), never observed directly** — nothing in the documented API surface returns a "requires X" / "leads to Y" relationship; `[2nd]` research confirms even `C_QuestLog.IsQuestFlaggedCompleted`/`GetQuestsCompleted` are boolean-only and can't distinguish "incomplete" from "invalid ID" **(revised — reason added, conclusion unchanged: still out of M4)** | `[2nd]`/`[?]` |
| Giver/turn-in NPC's own position (not the player's) | **unresolved** — no source demonstrated yet; needs multiple sightings + a distance model per the existing harvest-contract caveat | `[?]` |
| Coordinate transform (world ↔ UI-map %) | **client DB2** (UiMapAssignment) + derived | `[V]` M0/M1, unchanged |
| Cross-checks on row counts / build claims | **external corroboration** (e.g. ForeverDiff, lodestar) | `[2nd]`, useful only as a sanity check, never a source of truth (M1.5 principle, unchanged) |

## 9. What should NOT be collected yet

- **Item reward data** — deferred pending §3a's experiment, not assumed either way **(revised)**: if the
  experiment succeeds, this becomes a v1 field; if not, it stays out and the negative result is recorded,
  same standard as M3's own honest-negative findings.
- **Gossip active/available quest state** — same treatment, same reason **(new)**.
- Prerequisites or quest chains (explicitly out of scope per the original project constraints, unchanged;
  now additionally grounded in *why* — see §8).
- `QuestCache.wdb` / `DBCache.bin` **record content** (only file-level headers were read in M3; decoding
  actual records is a materially different, riskier undertaking — separate milestone, separate EULA
  consideration, not bundled into M4).
- Raw NPC/player GUIDs (per §4's hardened contract rule — the M3 probe's practice must not carry forward).
- Any data from Questie, ForeverGuide, RestedXP, or Wowhead (unchanged since M0).
- Giver/turn-in NPC's own world position from a single sighting (the existing harvest contract caveat —
  needs multiple sightings and a distance model, which is out of scope for M4).
- **Any automatic network transmission of observations** — export is manual/opt-in only, per §4.7 **(new)**.
- **Persistent per-character identifiers** — the research raised, as an open tradeoff, whether a stable
  opaque per-character pseudonym (rather than a fully random per-export session ID) might be worth adding
  to allow correlating a character's exports over time at some privacy cost. **This document does not
  decide that tradeoff** — it's a real product-privacy decision, not an engineering one, and stays with
  the existing M1 principle (fully random per export, no persistent identifier) unless the project owner
  explicitly chooses otherwise.

## 10. What should remain outside the repository

Unchanged from M1/M2/M3 practice, restated for M4 specifically:

- Raw harvest export files (SavedVariables-derived JSON) from any operator — these will contain
  Blizzard-derived quest/NPC data. Only the **resulting `assertion` rows** in a locally-built,
  never-committed SQLite database are the pipeline's output, exactly as `data/build/forever.sqlite`
  already is.
- Any `.wdb`/`DBCache.bin` file or content, per the existing M1.5/M2 provenance caution.
- Synthetic test fixtures used in M4's own test suite must remain synthetic (invented IDs, invented
  strings) — never copies of the real M3 SavedVariables data, consistent with how `test_att_importer.py`
  already uses synthetic Lua fixtures rather than real ATT file excerpts.

## 11. Tests M4 should require before being considered complete

Following the existing test-file naming and fixture conventions (`tests/unit/test_*.py`, synthetic
fixtures only, `conftest.py`'s `dataset` fixture reused):

1. **`test_harvest_ingestion.py`** — parses a synthetic v1 harvest export (a small, hand-written JSON
   fixture, not real data) and confirms it produces `assertion` rows with
   `source_kind='harvest_observation'`, `confidence='observed_first_hand'`, `status='observed'`, correct
   `observed_build_id` (from `build_source='client_api'`), and correct `source_locator` traceability.
2. **Same file — GUID exclusion test**: confirms the importer rejects or strips any raw GUID-shaped
   string appearing where a creature ID is expected, so the schema's hardened no-GUID rule (§4.3) is
   enforced in code, not just in documentation.
3. **Same file — objectives-array shape test**: confirms the full-array `C_QuestLog.GetQuestObjectives`
   shape (not the old one-objective-per-observation v0 shape) round-trips correctly.
4. **Same file — reward capture-context test**: confirms an observation tagged
   `capture_context='quest_turned_in_event'` is treated identically in ranking to one tagged
   `'quest_log_reward_query'` (the schema records the distinction; ranking policy is intentionally
   unchanged, per §6 — this test guards against someone quietly trying to rank them differently later
   without a deliberate decision).
5. **Extend `test_db_quests_assertions.py`** with a harvest-vs-harvest conflict case (two synthetic
   exports disagreeing on one quest's title), confirming both coexist, `resolve()` behaves per policy,
   and nothing is deleted — the concrete test for §7.
6. **Extend `test_repo_safety.py`** to also scan for accidentally-committed harvest export files (by
   filename pattern or a `contract_version` marker), the same way it already checks for stray
   `.csv`/`.lua` data files.
7. **Schema validation test** for `harvest_observation.v1.schema.json` — following
   `test_harvest_contract.py`'s existing minimal-validator pattern, extended to cover the new `event`
   variant and the revised `objective_progress` shape, using an updated, still-obviously-synthetic
   example file (successor to `docs/examples_harvest_v0.json`).

All of the above run against **synthetic fixtures only** — M4 requires no live client session and no new
addon to be considered complete.

## 12. Files/code that would actually need to change

**New files** (all additive):
- `schemas/harvest_observation.v1.schema.json`
- `docs/examples_harvest_v1.json` (synthetic, successor to the v0 example)
- `src/foreverdb/harvest/__init__.py`, `src/foreverdb/harvest/importer.py` (mirrors `att/importer.py`'s
  structure and style deliberately, for consistency)
- `tests/unit/test_harvest_ingestion.py`

**Modified files**:
- `docs/HARVEST_CONTRACT.md` — updated to v1, with the `event` variant, the revised objectives shape, and
  the hardened no-GUID rule stated explicitly rather than only implied; the "Unverified items this
  contract depends on" section rewritten to move the now-resolved items (API reliability, WDB
  persistence) to `[V]` and add what M3 newly left open (reward-selection-state question, item rewards).
- `tests/unit/test_repo_safety.py` — add the harvest-export-file scan (§11.6).
- `tests/unit/test_db_quests_assertions.py` — add the harvest-conflict test case (§11.5).
- `src/foreverdb/cli.py` — a new `ingest-harvest` subcommand, following the existing `build-db`
  subcommand's pattern (explicit `--build` argument required, no guessed build labels, per the existing
  M1 CLI design principle).

**Not touched**: `src/foreverdb/db.py` (schema already supports everything needed — no new tables, no new
columns), `src/foreverdb/policy.py` (ranking already correct, per §7), `src/foreverdb/assertions.py`
(already generic enough — `AssertionInput` takes `entity_type`/`entity_id`/`field` freely), `registry/`,
`config/`, anything under `research/` or the frozen M2/M3 experiment folders.

**New, outside `forever-db/` (revised)**: `m4-pre-experiment/` — a sibling folder to `m2-extraction-test/`
and `m3-experiment/`, containing a *forked* copy of the final M3 probe extended per §3a. The frozen
`m3-experiment/` files are not modified; the fork starts from them as a known-good baseline, same pattern
M3 itself used when patching the probe mid-milestone (test against a stub environment before any real run).

---

## Licensing note (revised)

A follow-up research pass directly fetched Blizzard's current UI Add-On Development Policy: eight rules
(free distribution, visible/unobfuscated code, no negative realm impact, no advertising, no in-game
donation requests, ESRB compliance, ToU/EULA compliance, Blizzard's right to disable functionality at
will). **None of the eight addresses data collection, export, or external communication specifically** —
a real, better-grounded data point than M1.5/M2 had (previously a `[2nd]`, not-fully-fetched reference).
This supports the M3 conclusion that the addon-API path is in a meaningfully lower-risk category than raw
cache/DB2 file access. **What this does not do**: resolve the separate EULA anti-data-mining question
from M1.5/M2 — that fetch failed again in this pass, so it remains exactly as unresolved as before. Policy
is also reported as actively evolving (2025 reporting on tightened combat-addon APIs alongside loosened
restrictions elsewhere) — a reason to treat today's API-availability facts as build/date-stamped
observations in the schema (which `observed_build_id` already provides for), not permanent guarantees.

## Risks

- **Schema churn risk**: revising v0 → v1 before any importer used it is low-risk — confirmed by grep:
  the only existing uses of `source_kind='harvest_observation'` are two synthetic unit-test fixtures in
  `test_db_quests_assertions.py` validating the ranking policy in the abstract, not any importer or real
  data path. This is the cheapest possible time to make this correction.
- **Scope-creep risk**: the temptation to also build the "real" recorder addon alongside the pipeline
  work is real, since M3 already proved the APIs work. Recommend resisting this — M4 is explicitly
  pipeline-only; a compliant recorder addon is naturally the *next* milestone once the pipeline can
  actually accept its output.
- **Fixture-fidelity risk**: synthetic fixtures modeled on M3's real findings need to be written carefully
  enough to actually exercise the v1 schema's new shapes (event variant, full objectives array) — a
  fixture that's too simple would let a real bug pass unnoticed, similar to how the original M3 probe's
  own `describe()` truncation went unnoticed until real data exposed it.

## Recommended sequence of work (revised)

0. **(New, non-blocking, can run in parallel with step 1)** Run the §3a pre-experiment: fork the final M3
   probe, add checkpointed item-reward and gossip-availability logging, test against a stub environment,
   run on a small real-quest batch known to carry item rewards. Document the result — positive or
   negative — before it affects the schema.
1. Write `harvest_observation.v1.schema.json` and its synthetic example, reviewed against every concrete
   field M3 confirmed (§4, §5), with item-reward/gossip fields included only if step 0 has concluded
   positively by this point — otherwise left as documented-but-deferred, revisited in a later revision.
2. Write `src/foreverdb/harvest/importer.py` against that schema, following `att/importer.py`'s existing
   structure (an `ImportReport`-style dataclass, explicit `EVIDENCE_KINDS`-style constants, no silent
   dropping of unmapped fields).
3. Write the test suite (§11) alongside the importer, not after it — each new importer function paired
   with its test, matching how M1's own modules were built.
4. Update `docs/HARVEST_CONTRACT.md` last, once the schema and importer are stable, so the documentation
   describes what was actually built rather than what was planned.
5. Only after all of the above passes: consider whether a compliant recorder addon (replacing the
   disposable M3 probe) is the right next milestone, or whether ingesting a manually-adapted M3-style
   export first (as a one-off validation) is worth doing before committing to addon development.

---

## Completion note: real-export ingestion demonstrated

This section is added after the fact, dated, per this document's own established pattern — the sequence
above is left as originally written, not rewritten to look like it anticipated everything that actually
happened.

Steps 1–4 above are now done: `schemas/harvest_observation.v1.schema.json`,
`src/foreverdb/harvest/importer.py`, a 46-test ingestion suite, and an updated `HARVEST_CONTRACT.md` all
exist and were validated against an actual `ForeverObservationLab` export (build `69977`), not only
synthetic fixtures — 41 real observations in, 51 real assertions out, confirmed idempotent on re-import,
confirmed clean of raw GUIDs and persistent identifiers. Full detail in `docs/M4_COMPLETION_REPORT.md`.

Two gaps step 1's schema design didn't anticipate were found only by using real data: `GiverIdentity`
observations with no `quest_id` (a real, common case at `GOSSIP_SHOW`, not an edge case) were being
discarded until fixed to import as `entity_type="npc"` evidence; and `session_id` was never actually
persisted on individual assertions until encoded into `source_locator` — chosen specifically to avoid the
schema change step 2's own instructions warned against inventing without cause. Both are documented in
`HARVEST_CONTRACT.md`'s "Real-data discoveries" section, not silently folded into the original design as
if they'd been anticipated from the start.

Step 5's question — whether to build a compliant recorder addon next — remains open and undecided by this
note. This section confirms the ingestion pipeline is real and demonstrated; it does not decide what M4's
successor milestone should be.
