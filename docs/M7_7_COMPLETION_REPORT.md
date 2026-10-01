# M7.7 Completion Report: QUEST_PROGRESS Recorder Capture

## Status: COMPLETE / LOCKED

M7.7 added recorder capture for the WoW client's `QUEST_PROGRESS` event and was validated on the real WoW
Forever client. **No dataset was changed** — the real observations have not been imported into M6.

Scope actually delivered: `docs/M7_7_SCOPE.md` **Change 1 only**. Not implemented (and unchanged by this
milestone): `QUEST_ACCEPTED`, the quest-log lookup investigation (Change 2), gossip expansion, target/NPC
integration.

## 1. What Changed

Four files under `m5-production-recorder/`, 115 insertions and 2 deletions in total:

| File | Change |
|---|---|
| `addon/ForeverRecorder/core/Dispatcher.lua` | +15 lines: register `QUEST_PROGRESS`; one `OnEvent` branch that obtains the quest ID via `GetQuestID()` (same mechanism as `QUEST_DETAIL`) and calls `dispatchCheckpoint("quest_progress", ctx)` |
| `addon/ForeverRecorder/observers/QuestMeta.lua` | 1 line: `"quest_progress"` added to its `checkpoints` list |
| `addon/ForeverRecorder/observers/GiverIdentity.lua` | 1 line: `"quest_progress"` added to its `checkpoints` list |
| `tests/run_recorder_tests.lua` | +98 lines: 5 new tests |

No reward observer was added to the new checkpoint (no reward data exists on a progress screen). No M4
importer, schema, ATT, or M6 code was touched.

## 2. Evidence — Four Separate Layers

These are kept distinct on purpose. Each says something different, and only layer 2 says anything about the
real client.

### 2.1 Synthetic implementation tests (wiring and shape only)

- **5 new recorder tests**, run in the existing stub environment: event recognized and routed; a valid
  capture yields exactly one `QuestMeta` + one `GiverIdentity` observation and no reward observer; an
  unresolvable quest ID is never fabricated (`QuestMeta` reports its existing `"no quest_id in context"`
  error, `GiverIdentity` still succeeds); the observation envelope is structurally identical to
  `quest_detail`'s; and a full-lifecycle regression with `QUEST_PROGRESS` alongside every existing checkpoint.
- **One synthetic-export importer check**: a schema-valid synthetic export (fake quest ID) with one
  `quest_progress` row produced 3 assertions through the unmodified M4 importer. The synthetic file was not
  kept in the repository.
- These prove the code is wired correctly. They say **nothing** about how the real client behaves.

### 2.2 Real-client validation

Environment: WoW Forever, build 70009, interface 16001; fresh Troll Shaman; NPC Cook Torka (Durotar).
Observed export: session `0df16c83d4799a`, 12 rows = **3 `GOSSIP_SHOW` windows (6 rows) + 3 progress-screen
events (6 `quest_progress` rows)**; each progress event produced exactly 2 observations (`QuestMeta` +
`GiverIdentity`).

| Time | Quest ID | Title | Level | Objective |
|---|---:|---|---:|---|
| 20:27:37 | 815 | Break a Few Eggs | 8 | `0/3 Taillasher Egg` |
| 20:27:43 | 96825 | This Fruit Could Bite Back | 6 | `2/8 Prickly Pear Fruit` |
| 20:27:45 | 96825 | This Fruit Could Bite Back | 6 | `2/8 Prickly Pear Fruit` |

- `GetQuestID()` returned a valid ID in **3 of 3** events; title, level and objective text (with item name)
  resolved with no lookup error in all three.
- Export accounting: the file holds 3,008 observations = 2,994 prior (a byte-identical prefix of the
  previous export) + 12 in the session above + 2 in the next session (`7e6f72f9ca76b0`, one further gossip
  window after the save/reload). Provenance: sha256 `723dac899c56b1cfd884f07670f3ecd8aa77dde1627c87529c525e5103bea39a`,
  3,848,772 bytes.
- **Validation history (recorded for honesty):** an earlier export (2,994 observations) contained zero
  `quest_progress` rows. The cause was not a code defect: the three modified files had not yet been copied
  into the WoW AddOns folder (a text search of the installed files returned 0/0/0). After installation, the
  16 installed files were confirmed byte-identical to the project's. Because the recorder's version string
  was left unchanged, the in-game banner could not distinguish the old build from the new one.

### 2.3 In-memory M4 importer validation (on the real export)

The real export was processed through the existing, unmodified M4 importer in a throwaway in-memory database:
`fatal_error` none; 3,008 observations seen; **0 skipped**; 3,835 assertions over the whole file, of which
**15** came from `quest_progress` rows:

| Quest | Captures | Assertions per capture | Total |
|---|---:|---|---:|
| 815 | 1 | title, level, objectives, `giver.npc`, `location.observed_player_position` | 5 |
| 96825 | 2 | same five | 10 |

Each assertion carries `method = QuestMeta@quest_progress` or `GiverIdentity@quest_progress`. No importer
change was required. Nothing was persisted, and **nothing was imported into M6**.

### 2.4 Regression (run during finalization)

| Suite | Result |
|---|---|
| Recorder Lua tests (13 existing + 5 new M7.7 tests) | all pass |
| M4 unit suite (includes ATT unit + repo-safety) | 141 / 141 |
| Real ATT integration | 7 / 7 |
| M6 regression (M6.2 + M6.3 + M6.4 + M6.6) | 62 / 62 |
| M7.4 suite | 10 pass, **1 known failure** |
| M7.5 suite | 14 / 14 |
| M7.6 citation/preservation suite | 12 / 12 |

**246 Python tests passed, 1 failed, 0 new failures.** The single failure is
`test_no_collection_run_is_created_in_the_m6_registry`, whose trailing `len(data) == 1` assertion went stale
when M7.5 legitimately added ten planned runs. It predates M7.7, is documented in the M7.5 report, and was
deliberately left unedited because M7.4 is a locked artifact.

## 3. Resolved Risk

The open M7.7 risk — whether `GetQuestID()` returns a valid quest ID while a real `QUEST_PROGRESS` frame is
open on WoW Forever — is **resolved on the tested cases** (3 of 3). The scope's stop condition (a) was not
triggered.

## 4. Passive-Collection Finding (Scoped)

On the tested real-client cases, opening an in-progress quest through its giver captured its **title,
level, and objective information without completing the quest**.

What this does **not** claim: that all quests, NPCs, or progress screens behave this way. The tested cases
are two incomplete quests (`0/3` and `2/8`), one NPC, reached through a gossip list. Whether a
ready-to-turn-in quest produces a `quest_progress` capture, or goes straight to the reward screen, was not
tested.

## 5. What Remains Unresolved

- **Quest 913's `QUEST_DETAIL` title/level lookup failure** (M7.6) is **not resolved** by this milestone and
  remains a separate open observation. The only related fact from this validation is that the same
  log-index scan succeeded in these three progress captures; that is a data point, not an explanation.
- **The `QUEST_ACCEPTED` timing hypothesis** remains unresolved (M7.6).
- **Untested cases:** ready-to-turn-in quests; NPCs with a single quest and no gossip window; other zones and
  classes; any case where `GetQuestID()` might fail (the fallback is unit-tested but not yet seen in the
  real client).
- **Observability:** `RECORDER_VERSION` is still `m5-recorder-0.1`, so nothing in-game distinguishes the
  M7.7 build. Not changed (out of scope).
- **Stale comment:** the inline comment in `Dispatcher.lua`'s `QUEST_PROGRESS` branch still says the
  behavior is "unverified." It was accurate when written and is superseded by Section 2.2. It is
  intentionally left as-is so the locked source stays byte-identical to the build that was validated.
- **M6 does not contain these observations.** They exist only in the user's export.

## 6. Explicitly Out of Scope (untouched)

`QUEST_ACCEPTED`; any change to quest-log lookup behavior (including `GetLogIndexForQuestID`); gossip
expansion beyond five entries; target/NPC integration; WDB-cache and taxi-node work; M6 datasets
(`m6_guide_dataset.json`, `m6_coverage.json`, `m6_evidence_report.json`); CollectionRuns (none created or
modified); M7.3, M7.4 and M7.5 artifacts; `config/sources.toml`; `docs/LICENSING.md`; new external sources;
any dataset redesign.

## 7. Integrity Verification

| Item | Result |
|---|---|
| M6 guide dataset, coverage, evidence report | identical to the pre-M7.5 snapshot |
| M6 collection-run registry | expected post-M7.5 hash; 11 runs (Run-001 `active`; ten M7.5 pilots all `planned`) |
| M6's input export (`latest_export_ForeverRecorder.lua`) | unchanged (still the M6.5-era file) |
| M7.3 and M7.4 artifacts | hash-identical |
| `sources.toml`, `LICENSING.md` | hash-identical |
| Frozen M4/ATT code, v1 schema | hash-identical |
| ATT snapshots | `att-head` `8e25511…`, `att-a054efd` `a054efd…` (exact) |

**Repository state:** none of the project folders is a git repository, so there is no native `git status` or
`diff`. The diff in Section 1 was produced by rebuilding the pre-M7.7 recorder in a scratch repository
outside the project (reversing the three recorded edits; the rebuilt baseline was confirmed to contain no
`QUEST_PROGRESS` and to pass the original test suite). It is a reconstruction, not a stored backup. Files
modified by this finalization pass: `docs/M7_7_COMPLETION_REPORT.md` (new),
`docs/M7_7_IMPLEMENTATION_REPORT.md` (status, Section 6, diff figures), `docs/M7_7_SCOPE.md` (Section 13
appended). Test-cache directories created by test runs were removed. No other project file changed.

## 8. Lock Manifest

The recorder build validated on the real client (the 16 addon files the user uploaded from the WoW AddOns
folder were byte-identical to these), plus the test file. Hashes are SHA-256 of the files under
`m5-production-recorder/addon/ForeverRecorder/` (test file: `m5-production-recorder/tests/`):

| sha256 | File |
|---|---|
| `d2045dd1fda361246c6d8259a233977e1915f7a38b3ed91c44d9aa72db243d3f` | `ForeverRecorder.toc` |
| `2dd3554c908bc64555fd90cd048e24bbafa454415bd21e0d8aa77ce66fe1c1a1` | `ForeverRecorder.lua` |
| `16a910a906777913a150a1b94224a6f72eedec6a0fce11443092dee4b0101406` | `core/SafeCall.lua` |
| `3fe409cdc0b8cc6781c17fb4a1436aa9288b1f38b87b26777babab392e69da9f` | `core/GuidUtil.lua` |
| `97e3f81b8dd1c7f2f3c3d9353b53dbecdf954eccad057f7a1142a8694cb432aa` | `core/PositionUtil.lua` |
| `b6809d1a062dfb342eedb6f502e6419ef93d9be6ca347e5b5ece8eab2e2c2e90` | `core/Bootstrap.lua` |
| `9602354c705109bad8df7e990eb6ac171736576067ba93640900f7858f07aca5` | `core/Registry.lua` |
| `c7f107a192c0321946ba98d6cc69698c098461e7f53f0f678625869313351996` | `core/Dispatcher.lua` |
| `eea5da005547644707faac0a4c0bb5c6fccef00d09a54bd4611e82777aa21670` | `core/Export.lua` |
| `a8a0fb6e16aa8f9315f45ee14804b2ed255b1f8d39f9bc93076c376fe81f94a8` | `core/SlashCommands.lua` |
| `c4cad3effdae416ab9281c8e26c34b7ba62291a4cb2480b621af0a09e2354ecd` | `observers/QuestMeta.lua` |
| `f39c7c1bceca6d2545d9b63ef87eb07e48f9c53f625655dc9f56812c6372b206` | `observers/RewardsXPMoney.lua` |
| `e126246776aedef0412ed353853a7f427c7f61c402e3b4db368a50b9ae86da38` | `observers/RewardsItems.lua` |
| `bcaed97506969dcb2ee457803cfbe48b51219ab36ffae4a60e12d22f5324d778` | `observers/RewardsReputation.lua` |
| `d6f24d9f3e5e084d1e81746f2d2ddc460ae1f0e28b04ddb74f4784c77839d684` | `observers/GiverIdentity.lua` |
| `161407255638633b484c7b570cb75aac6c14ff22c4d5e599119ed7bc2e69a660` | `observers/Gossip.lua` |
| `62212854fd55e3aac1263a6c6121903a94f197d2c4193dd30014a8685b461296` | `tests/run_recorder_tests.lua` |

Any further change to these files requires a new, explicitly approved milestone.

**M7.7 is COMPLETE / LOCKED.**
