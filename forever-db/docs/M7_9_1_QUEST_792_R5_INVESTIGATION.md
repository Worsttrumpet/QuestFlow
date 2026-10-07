# M7.9.1: Quest 792 `r5` Investigation

**Status: investigation only.** Nothing was ingested. M6, M4, the recorder, the M6.4 classifier, CollectionRuns,
guide-readiness, the pending export, licensing and sources were not modified. The 792 conflict was not suppressed and
was not marked safe.

## Conclusion

| Question | Answer |
|---|---|
| **What is `r5`?** (established) | The fifth positional return of the game's `GetQuestItemInfo(kind, index)`, captured uninterpreted by `RewardsItems`. It is a **boolean in all 596** recorded item rows. |
| **What does it mean?** | **Not established.** No project document, comment or test defines it, and the project's own M4 probe records that the return order "has not been confirmed on Forever". |
| **Best-supported reading** | A *hypothesis*: a per-player, evaluated-at-read-time flag that gates equipment and recipes. The data fit it; the data do not prove it. |
| **Which of your three cases?** | **(3) an unknown value whose semantics cannot currently be established.** Case (2), legitimate variation by context, is consistent with the data but not established, because **no recorded field identifies what differs between the two groups**. Case (1), genuinely conflicting evidence, is not supported, but it is not excluded either. |
| **Resolvable?** | **Not from the repository.** A cheap, no-gameplay step (an operator declaration of which character produced each session) can test one prediction; establishing the *meaning* needs a new real-client observation, which is described here at design level only. |
| **For M7.9 ingestion** | Do not suppress and do not mark safe. See Section 9. |

## 0. How this was done, and two refinements to M7.9

Read-only. Exports were parsed and imported in memory through the unmodified M4 importer; the client `Item` and
`ItemSearchName` tables already stored under `forever-db/data/raw/` (gitignored, labeled build `69913`) were read
locally, as elsewhere in the project. No web source, no new source, no new recorder observation. No project file other than this
document was written (scratch analysis lived under `/tmp`, outside the project). Client-table values appear here only as analysis findings; their licensing status is unchanged and
still unresolved (`docs/LICENSING.md`).

Two statements in `docs/M7_9_SCOPE.md` need refining, based on what this investigation found:

- *"`r5` is stable within each session."* That holds for quest 792 and for every **resolved** read. It does **not** hold
  for an item first read *unresolved* and later resolved: `r5` changed in 4 of 21 such cases (Section 6, item 4).
- *"The four sessions split into two groups."* Group A's two sessions are **one game login recorded twice** (Section 3),
  so the honest comparison is **one login versus two logins**, not two versus two.

## 1. Exact conflicting observations

Quest 792 has **19** `RewardsItems` capture rows with choice items: 16 in group A (all already in M6's input export) and
3 in group B (pending only). Observation indexes are positions in the pending export (0-based).

| Group | Session | Checkpoint | Observation index (in the pending export) | Recorded at | `r5` per item (1-4) |
|---|---|---|---|---|---|
| A | `804f0f…` | `quest_detail` | #2139, #2147 | 2026-09-25 04:18:42 – 04:18:42 | `FTTF` |
| A | `804f0f…` | `quest_complete_immediate` | #2261, #2269, #2293 | 2026-09-25 04:34:37 – 04:34:47 | `FTTF` |
| A | `804f0f…` | `quest_complete_delayed` | #2281, #2285, #2297 | 2026-09-25 04:34:39 – 04:34:48 | `FTTF` |
| A | `85e1e2…` | `quest_detail` | #2135, #2143 | 2026-09-25 04:18:42 – 04:18:42 | `FTTF` |
| A | `85e1e2…` | `quest_complete_immediate` | #2257, #2265, #2289 | 2026-09-25 04:34:37 – 04:34:47 | `FTTF` |
| A | `85e1e2…` | `quest_complete_delayed` | #2273, #2277, #2301 | 2026-09-25 04:34:39 – 04:34:48 | `FTTF` |
| B | `3d2cdd…` | `quest_complete_immediate` | #2717 | 2026-09-27 19:47:22 | `TFFT` |
| B | `3d2cdd…` | `quest_complete_delayed` | #2721 | 2026-09-27 19:47:24 | `TFFT` |
| B | `538e31…` | `quest_detail` | #2603 | 2026-09-27 18:42:02 | `TFFT` |

The M6 assertions built from them differ only in `r5`; every other captured field is identical between the groups
(Section 2).

## 2. Exact `r5` values

Every field of every item, per group (`ok` is `true`, `error` is empty and `v1_unresolved` is `false` in all 19 captures,
so none is an unresolved read):

| Item | `r1` name | `r2` | `r3` | `r4` | `r6` | `r5` group A | `r5` group B |
|---:|---|---:|---:|---:|---:|:---:|:---:|
| 1 | Primitive Club | 133485 | 1 | 1 | 4924 | `False` | `True` |
| 2 | Primitive Hand Blade | 135641 | 1 | 1 | 4925 | `True` | `False` |
| 3 | Primitive Hatchet | 135419 | 1 | 1 | 4923 | `True` | `False` |
| 4 | Primitive Walking Stick | 135139 | 1 | 1 | 5778 | `False` | `True` |

- **Only `r5` differs**, for all four items, and the two groups are exact **inverses** of each other (`FTTF` vs `TFFT`).
- Within each group the vector is identical at all three checkpoints and in every repeated capture.

**M6 representation.** `RewardsItems` → M4 importer emits one assertion per capture, field
`reward_choice_items.harvest_observed`, whose value is `{"checkpoint": …, "items": [ {index, ok, r1…r6,
v1_unresolved} … ]}`, so `r5` is *inside* the compared value. For example:

| Group | Assertion ID | Value hash | Locator |
|---|---:|---|---|
| A | 2650 | `eb7ff06044aa267e` | `session:85e1e2eafd010e\|observations[2135].choice_items` |
| B | 3316 | `1267cf738a163fa3` | `session:538e3166c69d56\|observations[2603].choice_items` |

Both are `status=observed`, `confidence=observed_first_hand`. M6.4 treats `choice_items` as a checkpoint-embedded reward
field and compares the whole `items` list, so a single differing sub-field produces a distinct value. Each of the three
checkpoint groups holds **2 distinct value hashes**, which M6.4 classifies as `genuine_conflict`. That label is the
outcome of a comparison ("more than one distinct value at the same checkpoint"); it does not say which value, if
either, is wrong.

**What M6 would display.** The guide dataset's `choice_items` value for 792 currently shows the group-A vector `FTTF`
(classification `none`, 16 observations). After ingestion it would show the group-B vector `TFFT` (classification
`genuine_conflict`, 19 observations), **only because group B is newer**.

## 3. Session and context comparison

| Session | Group | First recorded | Last recorded | Observations | In M6 input? |
|---|---|---|---|---:|---|
| `85e1e2eafd010e` | A | 2026-09-25 04:12:05 | 2026-09-25 04:36:26 | 193 | yes |
| `804f0f21338c28` | A | 2026-09-25 04:12:05 | 2026-09-25 04:36:26 | 193 | yes |
| `538e3166c69d56` | B | 2026-09-27 18:37:19 | 2026-09-27 18:53:57 | 122 | no (pending) |
| `3d2cdddf99fa10` | B | 2026-09-27 19:46:31 | 2026-09-27 20:10:52 | 295 | no (pending) |

**Group A is one login recorded by two addons.** The two sessions have identical time ranges and counts, interleave in
the file, and 192 of 193 observations pair up on timestamp, module, checkpoint and quest. The only differences (other
than session ID) are one observation timestamped one second later, and a field, `reward_items_evidence_note`, present in
7 observations of one session and absent from the other. That field exists **only** in `ForeverRecorder`'s code
(3 occurrences) and never in the Observation Lab's (0), so the pair is best explained as the Observation Lab and the Recorder loaded
in the same client. Group B is **two separate logins**, about 53 minutes apart, that agree with each other.

**Already-recorded context for the first look at quest 792** (`quest_detail`):

| Field | Group A | Group B |
|---|---|---|
| Client build / version / build date / TOC | 70009 / 1.60.1 / Sep 23 2026 / 16001 | **identical** |
| Giver | Zureetha Fargaze (3145) | **identical** |
| Player map and position | map 1411, (0.4280, 0.6914) | map 1411, (0.4284, 0.6906) |
| Quest choices / rewards | 4 / 0 | **identical** |
| Reads unresolved on first look | no | no |
| **Quest-log entries at that moment** | **6** | **3** |
| Date | 2026-09-25 | 2026-09-27 |

So **a client-build change does not explain the flip**, and nothing about the giver, place or offer differs. The
recorded differences are the date, the session, and the size of the quest log.

**Not recorded anywhere:** character name or identity, class, race, level, faction, realm, account, professions or weapon
skills. The recorder deliberately stores no character information. File-level `meta` is overwritten at every login, so
only per-observation stamps (build, version, build date, TOC, time, session ID) survive per session.

**Operator-stated context, not repository evidence:** earlier in this project the operator described the 2026-09-27
play as a fresh Troll Shaman. Nothing identifies the group-A character.

One inference, labeled as such: both groups show quest 792's *offer* screen followed by its turn-in, two days apart.
Given the project's finding that the offer screen appears for a quest not yet accepted, this is more consistent with two
different characters than one. It is not recorded, and it says nothing about what differs between them.

## 4. Where the field originates

| Layer | What it does |
|---|---|
| Game API | `GetQuestItemInfo(kind, index)` returns positional values. |
| Observer | `RewardsItems.lua` calls `SafeCall(GetQuestItemInfo, 6, kind, i)` and stores `r1 = v[1] … r6 = v[6]` **uninterpreted** (`captureItemsForKind`). Nothing labels `r5`. |
| Contract | `HARVEST_CONTRACT.md`: raw per-item fields `r1`..`r6` "pass through unmodified, no field renamed". The M5 design and the module authoring guide say the same. |
| Project's own M4 probe | Records positionally because the return order "has not been confirmed on Forever". |
| M4 importer | Emits the whole item list as one value under `reward_choice_items.harvest_observed` / `reward_items.harvest_observed`. |
| M6 | M6.2 tier `confirmed` for `choice_items`; M6.4 compares the whole value. |
| Tests | **No test references `r5`.** The recorder test stub returns five values with a *numeric* fifth, an earlier assumption that real data contradicts (real position 5 is boolean, position 6 numeric). It was not modified, and it establishes nothing about Forever. The M3 probe's names (`quality`, `isUsable`) were assumptions applied to a *different* function (`GetQuestLogRewardInfo`), so they are not evidence either. |

## 5. What the field appears to represent

**Established (from recorded data and client tables):**

- `r5` is the **only** one of the six positions that is a boolean, and it is a boolean in **596 of 596** rows (`r1` is text, the other four are integers).
- The other positions are validated against client data, which isolates `r5` as the unexplained one:
  - `r6` is a valid item ID in the client `Item` table in **566/566** resolved rows.
  - `r1` equals the client item name in **382/382** rows where the client name table has that item (184 rows are for items absent
    from that table, so they cannot be checked; there are **0 mismatches**).
  - `r4` equals the client quality value in **382/382** checkable rows.
  - `r2` equals the client icon ID in **564/566** rows (2 differ, not investigated; the client table is labeled build
    69913 while the observations are build 70009).
  - `r3` holds small counts (1, 3, 5, 10), which cannot be checked against these tables.

**Not established:** what `r5` means.

**Consistent with, but not proof of:** a per-player flag, evaluated at read time, that gates whether the character can
use an item, applying only to equipment and recipes. Section 6 lists the evidence and its limits.

## 6. Evidence supporting that reading

1. **Where it is False.** Among resolved rows, `r5` is False for client item class 2 (items such as Club, Quarterstaff,
   Greathammer) in **78/153** (51%), class 4 (items such as Leggings, Bracers, Gauntlets, Buckler) in **73/290** (25%), and
   class 9 (all named "Recipe:" or "Pattern:") in **7/7**. It is **never False for classes 0, 1 or 15** (0 of 116 rows;
   these hold items such as the "Cactus Apple Surprise" and "Mining for Dummies" quest items). The numeric class values
   are the client's; this document does not rely on any label for them beyond the item names quoted.
2. **Not explained by the item's own requirements.** For the 382 resolved rows whose item has a client name-table row,
   `AllowableClass` is `-1` (no class restriction) in every one, `RequiredSkill` is zero in every one, and
   `RequiredLevel` is zero in all but 10 rows (all 10 of which read True). All four 792 items have **identical** requirement fields
   (no class restriction, required level 0, required skill 0, item level 5) and differ only in weapon subclass
   (0, 4, 10 and 15). Nothing on the item side explains a difference between characters.
3. **Default when data is missing.** In all **30** rows read *unresolved* (blank name, `r4=0`) `r5` is `True`.
4. **It can change within one session when only the item's data loads.** In **4 of 21** unresolved-then-resolved
   cases, `r5` went True → False, for "Recipe: Skywall Souffle", "Recipe: Pincer Bites", "Flutterfly Swatter" and "Windshaped Shield". That indicates `r5` is computed
   from item data at read time, rather than being a fixed per-character constant.
5. **Isolated cross-session disagreement.** On **resolved reads**, 45 item IDs were seen in two or more sessions; **41
   agree** (30 True, 11 False, so agreement is not just "always True") and **4 disagree: exactly quest 792's four
   weapons**. Every session pair with at least three shared items agrees 100% except group-B against group-A, and there
   only on those four.
6. **A and B agree everywhere else.** They share 17 resolved items. All 13 non-792 items agree: 4 class-0 items (True in both),
   7 armor items of client subclasses 1 and 2 (True in both) and 2 armor items of subclass 3 ("Battleworn Chain Leggings",
   "Jagged Chain Vest": False in both). They differ on **the four 792 weapons only**.
7. **The pattern is not what noise looks like.** The flip is complementary across four weapon subclasses, identical at
   three checkpoints, and reproduced across two logins in group B. That is an argument, not a measurement.

**Limits of this evidence.** Every item above is a correlation. None identifies a *player attribute*, because none is
recorded. Group A is one login, so the "groups" comparison rests on one login against two. The flip occurs on a single
quest, so there is no second independent instance to test any hypothesis against.

## 7. Evidence that remains missing

- Any recorded player attribute: class, race, level, faction, weapon skills, professions.
- Which character produced each session, and whether groups A and B are different characters.
- A label for position 5 from the client. Client `Item` tables hold item properties, not per-player state, so they cannot
  supply it, and no in-repo API documentation exists.
- **Ground truth:** what the game's own interface showed for these four items to each character (for example how the
  reward list rendered), which is exactly what would confirm or refute the hypothesis.
- A second independent instance of a cross-session `r5` difference.

## 8. Is the conflict resolvable?

| Route | Needs | What it can establish |
|---|---|---|
| **From the repository alone** | nothing | **No.** The meaning cannot be determined. |
| **Operator declaration** (no code, no gameplay) | The operator states which character (class, level, faction) produced each of the four sessions, as was done for the test sessions in M7.8. | Whether groups A and B differ in class or level. This can test one prediction of the per-character hypothesis, and if the two are the *same* class and level yet `r5` differs, it weakens it. It still would not establish what `r5` means. |
| **New real-client observation** (design only; not requested now) | The existing recorder plus a screenshot, with **no addon change or hook**: view an *unaccepted* quest whose reward list includes weapons on two characters of different declared classes, and compare the game's own display of each item with the recorded `r5`, as was done to identify quest 913. | Whether `r5=False` corresponds to what the game itself marks as unusable for that character. This is the only route that can establish the meaning. |

Per the instructions, this stops at design level: no hook was added, nothing was run, and the operator is not being asked
to do any gameplay.

## 9. Recommendation for M7.9 ingestion (nothing was ingested)

1. **Treat it as case (3): an open, unresolved-semantics item.** Do not suppress the M6.4 conflict, and do not mark it
   safe. The label stays as the classifier produced it, and it should be read as "two distinct values observed", not
   "one is wrong".
2. **It does not threaten the evidence store or guide-readiness.** Both values are kept with full provenance and the same
   confidence, nothing in M6 or the guide dataset consumes `r5`, and `choice_items` is not a required readiness field.
   This is a judgment based on the current code, not a claim that `r5` is harmless.
3. **The one real effect is presentation.** Ingestion would flip the *displayed* `r5` vector for 792 from group A's to
   group B's purely because B is newer. If `r5` is per-character, neither vector is a quest-level fact. So the ingestion
   report should annotate `choice_items`' `r5` as **unlabeled, possibly per-character, not a quest attribute**, and no
   consumer should surface it. That is an annotation in a document, not a code change.
4. **Operator options for decision D2**, none of which needs any change to M6, M4 or the classifier:
   - **(a) Ingest with the conflict retained and annotated.** Recommended as non-blocking, because holding 498
     observations for a field nothing consumes has a cost and little benefit. The accepted trade-off is the display flip in
     item 3.
   - **(b) Hold until the operator-declared session-to-character mapping is supplied.** Cheap and needs no gameplay, but
     it cannot establish the meaning.
   - **(c) Hold until the real-client comparison is done.** The only route to a definitive answer; the heaviest.
   Because the existing path is all-or-nothing, the display flip cannot be avoided except by not ingesting.
5. **Follow-up regardless of choice:** obtain the operator-declared mapping (route b) as a low-cost way to start testing
   the hypothesis, before any consumer uses `r5`.

This document does not decide D2; it gives the operator the evidence to decide it.
