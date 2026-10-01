# M5 Real-Client Completion Report

Documentation only. No addon code, test file, the M4 importer, the v1 schema, the Observation Lab, or any
other implementation file was modified to produce this report. No SavedVariables or test data was cleared
or reset.

Throughout this report, a claim is marked **[data-verified]** when it was checked directly against a real
exported file from this session, **[code-verified]** when it follows necessarily from reading the addon's
own source (true regardless of which session produced the data), and **[reported]** when it rests on what
the tester (not this report) observed in-game and relayed, without independent file-level confirmation.

## 1. Executive Summary

The M5 production recorder (`ForeverRecorder`, version `m5-recorder-0.1`) was installed and run on a real
WoW Forever beta client for the first time in this session. All 6 of its proven observer modules produced
real observations from real gameplay — two full quest turn-ins, one real NPC-scoped sighting, one
guaranteed-item-reward capture, and a real, second reproduction of the item-name resolution timing
behavior first found during M4. The resulting real export was validated against the existing v1 schema
and successfully ingested by the existing, unmodified M4 importer, including a confirmed idempotent
re-import. Session and build provenance were verified directly across multiple reload and one logout/login
transition, with no data loss observed in any of them. This report also documents a real limitation of the
current importer (the recorder's new `evidence_note` field does not yet reach SQLite) and several areas
this session's testing does not establish, listed plainly in Section 8.

## 2. Test Environment

- **Build**: `1.60.1.70009` (a new build — every prior M3/M4 session in this project used `69977`; this is
  the first real evidence the recorder tolerates a build change without refusing to run, matching M5
  design §14's intent) [data-verified, from every real export's own `observed_build` field]
- **Interface**: `16001` [data-verified]
- **Locale**: `enUS` [data-verified]
- **Recorder version**: `m5-recorder-0.1` [data-verified, `meta.lab_version` field]
- **Character**: a fresh test character was used for this session's new activity [reported]
- **Observation Lab status**: `ForeverObservationLab` was disabled partway through this session
  specifically so subsequent new observations could be attributed to `ForeverRecorder` alone
  [data-verified: no new observations after the disable point carry any signature inconsistent with
  `ForeverRecorder`'s own code, and the shared dataset's session boundaries line up exactly with the
  addon-list screenshots showing only `[FRecorder]` loading, no `[FLab]`, from that point on]

## 3. Real-Client Tests Performed

Mapped against the 8 scenarios `M5_TEST_PLAN.md` originally planned. Each is marked strictly on the
evidence actually gathered in this session — a related behavior being observed elsewhere does not by
itself mark a different scenario complete.

| # | Scenario | Status | Basis |
|---|---|---|---|
| 1 | Quest observation | **Completed** | Two full real turn-ins captured end-to-end (§4) |
| 2 | NPC-only observation | **Completed** | Spirit Healer (creature 6491), no `quest_id` fabricated (§4) |
| 3 | Reward observation | **Completed, with a caveat** | Choice items, reputation, and (for the first time on this recorder) a guaranteed item all captured — but the guaranteed-item case is the same quest ID as the prior M4 confirmation, not an independent quest (§7) |
| 4 | Position observation | **Completed** | Real coordinates on every observation; player position, never NPC position |
| 5 | Session/build provenance | **Completed** | Multiple session boundaries and a build change verified directly across five separate real exports (§5) |
| 6 | Manual `/fr save` export | **Completed** | Confirmed directly, including an important nuance found in this session: `/fr status` alone never writes to disk — only `/fr save` (or any reload) does (§5) |
| 7 | Re-import into M4 | **Completed** | Real export validated against the unmodified v1 schema and imported by the unmodified M4 importer, idempotently (§6) |
| 8 | Persistence behavior (`/reload` vs. logout/login) | **Completed** | Both transitions tested against real data; see the important note in §5 about how this session's logout/login result compares to the earlier documented finding |

## 4. Real Data Captured

### Quest turn-ins

**Foul Matriarch** (quest 92470) and **Aggressive Encroachment** (quest 92473) — both captured completely
[data-verified]:
- Real titles, levels, and full objective arrays at `quest_complete_immediate` and `quest_complete_delayed`
- Real XP/money from the `QUEST_TURNED_IN` event: 550 XP / 100 copper, and 360 XP / 0 copper respectively
- Real choice item names (e.g. "Worn Greatsword," "Refined Shortbow" for 92470; "Thendal Ranger's Shoes"
  and others for 92473)

**Viewed-but-not-accepted quests** (92472, 96638): `QuestMeta` correctly recorded no title/level/objectives
for either, with the honest `quest_log_index_error: "not found among N entries"` note — the same, expected
behavior already established in M4 real-client testing, not a defect [data-verified]

### Guaranteed-item quest 92515, "The Problem With Prideclaws"

Captured completely, with the exact evidence nuance preserved [data-verified]:
- `quest_detail`: reward item unresolved (empty string, `v1_unresolved: true`)
- `quest_complete_immediate`: resolved to **"Simple Leather Satchel"**
- `quest_complete_delayed`: same, "Simple Leather Satchel"
- `QUEST_TURNED_IN`: 550 XP, 125 copper
- **This is a second real-client observation of the same quest ID (92515) as the original M4 item-retry
  follow-up confirmation — not an independent confirmation on a different quest.** The guaranteed-item
  evidence base remains "confirmed on one specific quest, observed twice," not "confirmed across multiple
  quests."
- The item resolved naturally by the next checkpoint. **The bounded retry mechanism itself did not fire in
  this observation** [data-verified: no `retry_after_*` checkpoint exists for quest 92515 in the real
  export] — its own effectiveness remains exactly as unconfirmed as before this session.
- `reward_items_evidence_note` is present, worded as designed, on all three checkpoints
  [data-verified]

### NPC/Gossip observations

- A **Spirit Healer** (creature ID `6491`) was observed via `GOSSIP_SHOW` with no `quest_id` present.
  `GiverIdentity` correctly recorded this as an NPC-scoped observation (`entity_type="npc"` once imported)
  rather than fabricating a quest attachment [data-verified]
- A later NPC interaction produced exactly 4 observations (2 `GiverIdentity`, 2 `Gossip`), all under
  session `9a2307cc62589b` [data-verified directly, individually, on each of the 4 rows], including real
  quest-sighting content for quest `93319`, "Pilfered Windstones." The two matching pairs (rather than one
  of each) reflect `GOSSIP_SHOW` firing twice for that interaction — noted as an observed event/checkpoint
  behavior, not treated as an error, since nothing in the design assumes `GOSSIP_SHOW` fires exactly once
  per interaction.

## 5. Persistence and Session Provenance

The full sequence, each step's count/session confirmed the way stated:

| Step | Observations | Session | Basis |
|---|---|---|---|
| Before `/reload` | 1656 | `71e063f2d39cbe` | [reported — status line, no file at this exact point] |
| After `/reload` | 1656 | `9a2307cc62589b` | [reported, then corroborated: the next real export's meta matched] |
| After NPC interaction | 1660 | `9a2307cc62589b` | [data-verified: file contained exactly 4 new rows under this session] |
| After `/fr save` (live) | — | `038eb179f79ceb` | [reported via status]; the file `/fr save` actually wrote still showed the **previous** session, because **`/fr status` alone never writes to disk — only a save/reload does** [data-verified: the file matching this point in time had `meta.session_id = 9a2307cc62589b`, not the new live session] |
| After full logout/login | 1662 | `f560b6cb92a97c` | [reported via status] |
| After the next `/fr save` | 1662 | `f560b6cb92a97c` | [data-verified: this file's meta and all new rows correctly showed this session] |

**Integrity, checked directly at every step**: each successive real export's prior observations were
byte-for-byte identical, in the same order, to the previous export's full content — confirmed by direct
comparison, not by count alone, at three separate points in this sequence. Nothing was lost, overwritten,
or duplicated at any transition.

**An important, carefully-scoped note on the logout/login result**: M4's own prior finding
(`SAVEDVARIABLES_PERSISTENCE_FINDING.md`) reproduced complete observation loss across a logout/
character-select transition, twice, with an unconfirmed client-side cause. **In this session's single
logout/login test, with `ForeverRecorder` on build `70009`, no loss occurred** — 1660 observations went
into the transition and 1662 came out (2 new, from further play), with the full prior set intact. This is
one test, on a different addon and a different build than the original finding, and does **not**
establish that the earlier issue is resolved, disproven, or was ever addon-specific — only that it did not
reproduce here. Both facts are recorded as what they are: the earlier finding stands as previously
documented; this session's result is a new, separate data point that happens to differ from it.

## 6. Schema / Importer / Privacy Validation

All of the following were re-confirmed in this session against the real recorder export, not only
against synthetic fixtures:

- **Static syntax**: 15/15 files pass `luac5.1 -p`
- **Safety scanner** (existing, unmodified): pass — zero forbidden-call references, zero networking
  references
- **Manual forbidden/disallowed-key checks**: pass
- **Unit/integration test suite**: all 13 test blocks pass
- **Schema validation of the real export**: 0 errors against the existing, unmodified v1 schema
- **`module_status`**: every observation in the real export reports `"proven"`; zero report
  `"experimental"` — consistent with the recorder shipping no experimental modules at all
- **M4 importer, unmodified, against the real export**: 1809 assertions produced, 0 skipped, 0 rejected
  for any reason, 0 privacy rejections
- **Idempotent re-import**: importing the identical real file a second time added 0 new assertions; all
  1809 correctly recognized as duplicates
- **Privacy scan of the imported data**: 0 raw-GUID-shaped strings, 0 persistent-identifier-shaped keys,
  checked directly against the actual stored assertion values

### Known importer limitation, preserved exactly as previously found — not fixed here

`reward_items_evidence_note` is present in the recorder's raw export and is schema-valid (the schema
permits additional properties on an observation's `data`). **It does not reach the imported SQLite
assertion** — the existing, unmodified importer's field-mapping for `reward_items.harvest_observed` only
extracts `items` and `checkpoint`; it has no code path for a field it doesn't know about. This was
confirmed again directly against this session's real quest-92515 data: the note is in the raw file, absent
from the stored assertion's value. Not fixed in this report, and not described as if it reaches SQLite.

`locale` continues to be captured and exported by the recorder but is not consumed by the recorder itself
or by the M4 importer for anything — this was true before this session and remains true; nothing in this
session's testing changed that or established a new consumer for it.

## 7. Evidence Strength and Important Nuances

- **Choice item rewards and reputation**: now independently reproduced across four real sessions total
  (three from M4 testing, plus this session) — the strongest-evidenced reward categories.
- **Guaranteed item rewards**: now observed twice, but both observations are the same quest (92515). The
  evidence base is "one quest, confirmed twice," not "confirmed across multiple quests" — materially
  weaker than choice items and reputation, and should continue to be treated that way.
- **The item-name resolution timing behavior** (empty string at `quest_detail`, resolved by
  `quest_complete_immediate`) reproduced exactly, a second time, on the same quest. The **retry
  mechanism's own effectiveness remains unconfirmed** — in both real occurrences to date, resolution
  happened naturally by the next checkpoint, not because the bounded retry fired.
- **NPC-scoped `GiverIdentity`**: now confirmed working correctly on the production recorder's own code on
  a real client, not just in stub tests and not just via the original M4 discovery on the Observation Lab.
- **Build tolerance**: the recorder correctly loaded, recorded the new build (`70009`) accurately, and did
  not refuse to operate — the first real evidence for M5 design §14's "no demonstrated safety reason to
  disable on a build change" position.

## 8. Remaining Limitations / Unproven Areas

1. This session's real-client testing does not prove every possible quest, NPC, or reward edge case —
   only the specific scenarios actually exercised are established.
2. Guaranteed non-choice item rewards now have two real observations, but both are quest `92515` — this is
   not two independent quest-level confirmations, and should not be described as such.
3. The bounded retry mechanism's effectiveness has still not been directly demonstrated by any case that
   actually required a retry attempt to succeed; both real occurrences of the underlying condition
   resolved naturally at the next checkpoint instead.
4. "Missing/nil API returns" is covered by the existing stub-based unit test suite, but no separate,
   dedicated real-client test was performed for each individual API returning nil — real-client coverage
   of this specific behavior is indirect (inferred from the checkpoints that did run cleanly), not a
   standalone confirmed test.
5. Each of the 8 originally-planned real-client scenarios is marked individually in Section 3, based only
   on what was actually observed this session — none was marked complete solely because a related behavior
   happened to be observed elsewhere.
6. `ForeverObservationLab` and `ForeverRecorder` intentionally share the `ForeverObservationLabDB` data
   name, by design, for compatibility with the existing M4 pipeline. The Lab was disabled partway through
   this session specifically for clean attribution of new observations, but the underlying dataset still
   contains all historical Lab observations alongside the new recorder ones.
7. Because of the point above, **the total observation count in any export from this session is not an
   M5-only count** — it is the full shared history. Every M5-specific claim in this report is scoped to
   the specific new observations/sessions identified, not the running total.
8. Successful ingestion through the existing M4 importer establishes that this specific importer correctly
   consumes the recorder's output — it does not establish that every possible downstream consumer would
   interpret every optional field (the `evidence_note` limitation in Section 6 is a concrete example of
   exactly this kind of gap).
9. The logout/login persistence result in this session (no data loss) is one test, on one build, with one
   addon, and does not resolve, disprove, or generalize beyond the earlier, separately-documented
   SavedVariables persistence finding.

## 9. Final M5 Status

**M5 production recorder is validated on a real Forever client for the tested scenarios and is ready for
documented use, with the limitations listed above.**

This is not a claim that M5 is fully proven or that it works in every real-client scenario. It reflects
exactly the scenarios exercised in this session, each scoped as precisely as the evidence allows in
Sections 3 through 8.

## 10. Files Changed for This Report

One file created: this report. No other file — addon code, tests, the M4 importer, the v1 schema, the
Observation Lab, or any SavedVariables/test data — was created, modified, or cleared to produce it.
