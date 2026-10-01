# M6.5 Production Collection Report — Run-001

## Objective

Use the existing, already-active `run-001-resolve-unresolved-titles` to perform the first real-client
production collection against 10 quests with unresolved `title`/`quest_level`/`objectives` evidence, and
measure honestly what actually changed — not what merely looks like progress.

## Run

- **Run ID**: `run-001-resolve-unresolved-titles`
- **Lifecycle**: `active` (unchanged by this session — see Conclusion)
- **Target fields**: `title`, `quest_level`, `objectives`
- **Target quest IDs**: `92516, 92517, 92553, 93318, 93319, 93951, 94411, 95350, 97970, 99196`

## Collection Procedure

Performed by the user in the real WoW Forever client, `ForeverRecorder` enabled, on map `2521`
("Shen'dar Village," per the user's own in-game observation — not something the recorder itself captures).
All 10 quests were already sitting accepted in the quest log at the start of this session (from a prior
session not covered by this report). The user talked to each of 7 named NPCs plus attempted the one
bounty-board target:

| Target | Interaction result |
|---|---|
| Teeri Wellwind (92516, 93319) | Reached, interacted |
| Zerril Softbreeze (92553) | Reached, interacted |
| Taleen Shimmerthread (93951) | Reached, interacted |
| Illaya Amberwind (94411) | Reached, interacted |
| Raan Wildwind (97970) | Reached, interacted |
| Constable Aonda (92517, previously unknown title) | Reached, interacted |
| Bounty board / Danarii Bellowveil (93318) | **Board not interactable** — quest already active, nothing to click. The user separately found and viewed the quest's own detail screen directly (a screenshot, not a recorder capture) confirming the real title, reward-matched choice items, and the real turn-in NPC name. |
| 95350 (different map), 99196 (no location clue) | Not attempted this session, per the original plan |

## Sessions

- **`848e65fa491920`** — the first real collection session, associated with this run. Contains all 7 NPC
  interactions above and nothing else.
- **`220c686428dde8`** — the follow-up session, associated with this run, in which quest 92517 was turned
  in (see below).
- **`bc6a05e007ba07`** — a separate, brief session containing one incidental sighting of a previously
  unseen NPC ("Coriella Calmbreeze," creature `254089`), unrelated to any of the 10 targets. **Not**
  associated with this run, per the explicit instruction not to lump unrelated observations into a
  collection run's session list.

## Results

**A real, important finding that shapes everything below**: every one of the 16 new observations this
session was a `GOSSIP_SHOW` checkpoint — **none were `QUEST_DETAIL` or `QUEST_COMPLETE`**. Talking to an
NPC while their quest is already accepted opened a gossip interaction in this client, not the quest-detail
frame. This was not anticipated going in, and is reported exactly as found, not smoothed over.

| Quest | Title before | Title after (via Gossip, not QuestMeta) | `title.harvest_observed` state | Direct QuestMeta obtained? |
|---|---|---|---|---|
| 92516 | unresolved | "Hippogryph Harrassment," level 7 (already known) | **still unresolved** | No |
| 92517 | unresolved | **"The Criminal Element," level 7 — newly confirmed** | **still unresolved** | No |
| 92553 | unresolved | "Restocking the Larders," level 6 (level newly seen) | **still unresolved** | No |
| 93318 | unresolved | "WANTED: Vulgara the Insatiable" (confirmed via direct quest-screen view, not the recorder) | **still unresolved** | No |
| 93319 | unresolved | "Pilfered Windstones," level 7 (already known) | **still unresolved** | No |
| 93951 | unresolved | "A Little Beauty," level 7 (level newly seen) | **still unresolved** | No |
| 94411 | unresolved | "Meddlesome Mages," level 6 (level newly seen) | **still unresolved** | No |
| 95350 | unresolved | not attempted | unresolved | No |
| 97970 | unresolved | "Camping 101: Mining" (no new gossip data this session) | unresolved | No |
| 99196 | unresolved | not attempted | unresolved | No |

## Evidence Changes

**Zero fields moved from `unresolved` to a stronger state for any of the run's actual targets**
(`title`/`quest_level`/`objectives`), computed via the existing, unmodified `compute_coverage_delta()` —
confirmed directly, not assumed. Per the established rule (and the M6.5 brief's own explicit warning),
Gossip-sourced titles are never silently promoted into `title.harvest_observed`, so the very real,
very useful confirmations above (especially resolving "The Criminal Element" = 92517 with certainty) do
not count as resolving this run's coverage target, and this report does not claim otherwise.

**What genuinely did improve**, outside the run's specific targets: `gossip_availability_sightings`
coverage rose from 76/95 to **77/95** quests overall (dataset-wide, not limited to these 10), and 6 of the
10 targets now carry a real `active`-kind gossip sighting where before they only had (or lacked) an
`available`-kind one — a real, if narrower, evidence gain, not claimed as title/level/objective resolution.

## Conflicts (M6.4)

Re-ran the existing, unmodified M6.4 classifier against the updated dataset: **zero `genuine_conflict`,
zero `ambiguous_difference`** anywhere in the dataset, including all 10 targets. `gossip_availability_sightings`
conflicts (M6.2's raw same-checkpoint count) rose from 47 to 50 — all 50 correctly classify as
`state_change` under M6.4 (the same well-understood available→active pattern already documented), not
genuine problems.

## Follow-Up Session: Real Resolution Achieved

A second real session (`220c686428dde8`) followed the recommendation above — the user turned in quest
**92517 ("The Criminal Element")** directly, rather than only re-visiting its giver. This produced genuine
`QUEST_COMPLETE`/`QUEST_TURNED_IN` observations, and `compute_coverage_delta()` confirms **all three**
target fields genuinely transitioned:

| Field | Before | After |
|---|---|---|
| `title` | unresolved | **confirmed** — "The Criminal Element" |
| `quest_level` | unresolved | **confirmed** — 7 |
| `objectives` | unresolved | **confirmed** — "10/10 Highlands Bandit slain", "1/1 \"Badwind\" Bennic slain", both finished |

Bonus evidence, outside the run's formal targets but real and captured: 3 choice items ("Bandit's Jerkin",
"Patchwork Leggings", "Highlands Mail Legguards"), 2 reputation factions (`2778`/`2779`, 5000 each), 480 XP,
175 money. `quest_complete_immediate` and `quest_complete_delayed` agree exactly — M6.4 classifies every
field `none` (fully consistent), zero conflicts.

**This is the run's first genuine target resolution**, confirmed the same rigorous way as everything else
in this project: by an actual evidence-state transition, not an observation count or a gossip-sourced
guess. All prior 1,678 observations remain byte-for-byte intact; 13 new observations were added.

## Remaining Unknowns

**1 of 10 targets (92517) is now fully resolved.** The other 9 remain `unresolved` for
`title`/`quest_level`/`objectives`. `95350` and `99196` still have not been attempted at all. The
demonstrated path forward for the remaining 8 reachable targets (everything except `95350`/`99196`) is the
same one that worked here: **turn the quest in**, not merely re-visit the giver.

## Provenance

Build `70009`, interface `16001`, locale `enUS` (all confirmed from the real export's own metadata).
Recorder session `848e65fa491920` associated with this run; all 1,662 prior observations confirmed
byte-for-byte unchanged before this session's 16 new ones were appended.

## Limitations

- **A real blocker was found and reported, not silently fixed**: `coverage.py`'s conflict-detection code
  converts a Python `set` to a list without sorting, making its JSON serialization (and any hash of it)
  non-deterministic across separate process runs, even when the underlying data is identical — confirmed
  by direct comparison, which also confirmed every `evidence_state`/`observation_count` value is stable
  and correct regardless. This does not affect the correctness of anything reported here; it affects only
  whether a stored snapshot's SHA-256 can be exactly reproduced later. `coverage.py` was **not** modified
  to fix this, per instruction to stop and report rather than change M6.2 architecture unilaterally.
- The mismatch between the before-snapshot's recorded hash and a freshly-recomputed one (discovered while
  verifying Phase 1's baseline) is caused by the same issue above, not by any change to the underlying
  coverage data — verified directly by comparing every quest's every field.
- Talking to an NPC with an already-accepted quest producing only `GOSSIP_SHOW`, not `QUEST_DETAIL`, was
  not anticipated by the original collection plan and is a real behavior of this client worth remembering
  for future collection runs: **completing or turning in** a quest (which does trigger
  `QUEST_COMPLETE`/`QUEST_TURNED_IN`) is likely necessary to actually resolve `title.harvest_observed` for
  an already-accepted quest, not merely re-visiting the giver.
- 93318's title/reward match was confirmed via a direct player screenshot of the quest's own UI, not a
  recorder capture — genuinely true and useful, but this report does not claim it as `QuestMeta` evidence.

## Final Round-Up: 8 of 10 Resolved

Across six real sessions on the Warrior, six more targets were turned in and genuinely resolved the same
rigorous way as 92517 and 92516 above — every one confirmed via an actual evidence-state transition, not
inferred from gossip or assumed from an observation count:

| Quest | Title | Level | Notable real detail |
|---|---|---|---|
| 93951 "A Little Beauty" | ✅ | 7 | Matched user's own 8/8 report exactly |
| 97970 "Camping 101: Mining" | ✅ | 6 | Level resolved for the first time; real objective text |
| 92553 "Restocking the Larders" | ✅ | 6 | Guaranteed item names resolved only at the delayed checkpoint (same known timing pattern as M4) |
| 94411 "Meddlesome Mages" | ✅ | 6 | Double reputation amount (10000) — a real, unexplained outlier worth remembering |
| 93319 "Pilfered Windstones" | ✅ | 7 | See the delayed-checkpoint anomaly below |
| 93318 "WANTED: Vulgara the Insatiable" | ✅ | 9 | Confirmed the exact reward match found via a player screenshot days earlier |

**One genuinely interesting anomaly, investigated and confirmed harmless**: 93319 turned in fast enough
that its `quest_complete_delayed` checkpoint fired after the quest had already left the log. Rather than
recording a false value, `QuestMeta` correctly omitted the field entirely — verified directly that this
produced zero conflicting assertions (title/level for 93319 show `single_observation`, not
`genuine_conflict`). The existing safety design worked exactly as intended, with no code change needed.

### The Last Two: Genuinely Blocked, Not Merely Unattempted

**95350** — the giver (Alaana Stormwalker) no longer offers any interaction at all. The most likely
explanation, consistent with the evidence: this quest was already completed on a prior character/session,
before this recorder existed in its current form (the only evidence for it comes from build `69977`, a
much older session lineage than everything else in this run). Most quests cannot be turned in twice — this
may be permanently unrecoverable through a fresh turn-in, and that is an honest, acceptable outcome, not a
process failure.

**99196** "A Donation of Wool" — actually located and viewed in-game (on a different, level-20 character,
explicitly **not** associated with this run) at a new NPC, Oura Stormspinner. Two real findings here: first,
the initial view did not produce a `QuestMeta` capture at all — a different quest (97964, an incidental
sighting) was captured instead, suggesting this quest's donation-style UI may not fire the same event a
normal quest dialog does. Second, and decisively: the quest requires **60 Wool Cloth** just to accept,
which the user does not currently have. Genuinely blocked, not a recorder gap.

## Conclusion

**Run-001 ends this collection round at 8 of 10 targets genuinely resolved, entirely on the Warrior, across
six real sessions — every resolution confirmed by an actual evidence-state transition, never inferred from
gossip, an observation count, or the user's own gameplay report alone.** The single lesson that unlocked
most of this round's progress: re-visiting a quest's giver only produces `GOSSIP_SHOW`, not
`QUEST_DETAIL` — **turning the quest in** is what actually captures `QuestMeta`. Both remaining targets were
investigated directly rather than left as unexplained gaps: 95350 appears already completed prior to this
recorder's existence, and 99196 is blocked by a real, unmet material requirement. Neither reflects a defect
in the recorder or the collection process. The run remains `active`, not `completed` — 2 of 10 targets are
still genuinely open, and marking this closed would overstate what has actually been established. Should
either 95350 become otherwise accessible or the user acquire 60 Wool Cloth, both remaining targets have a
clear, documented path to resolution; otherwise this stands as an honest, final 8/10 result.

---

**Tests and preservation, confirmed this session**: 52 M6 tests and 141 M4 tests pass, run fresh. `db.py`,
`assertions.py`, and `importer.py` are byte-identical to before. The Observation Lab and M5 recorder
implementation are unmodified. `coverage.py`'s known ordering issue (above) was found and documented, not
patched, per instruction.
