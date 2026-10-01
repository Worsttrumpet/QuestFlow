# M5 Test Plan

**Status: designed, not performed.** No test in this document has been run — there is no addon yet to run
it against. This distinction is stated once here and should be assumed throughout: every item below is a
plan, not a result.

## Static tests (mirrors the Observation Lab's own, already-proven approach)

- **Lua syntax** — `luac5.1 -p` on every file, exactly as done for every prior probe and the Lab.
- **Forbidden API calls** — the existing tokenizer-based scanner (`tests/safety_scan.py`, already tested
  against a deliberately poisoned fixture to confirm it discriminates comments from real calls) run
  against the new addon tree unchanged. No new scanner needed.
- **Networking calls** — same scanner, same existing check (`SendChatMessage`, `SendAddonMessage`,
  `JoinChannel`, `C_ChatInfo`).
- **Raw GUID leakage** — the same recursive-scan approach used to verify every real Observation Lab
  export (zero GUID-shaped strings found, three separate real sessions) applied to this recorder's own
  stub-test output before any real-client use.
- **Persistent identity leakage** — same disallowed-key-name check already proven in the M4 importer,
  applied here to the recorder's own export shape directly (belt-and-suspenders: the importer checks this
  on ingestion; the recorder's own tests should not rely on the importer to catch a recorder-side bug).
- **Prohibited automation calls** — extend the existing scanner's forbidden list check (already covers
  `GetQuestReward`/`AcceptQuest`/`CompleteQuest`/`TurnInQuest`) with the same discipline; no new scanning
  approach needed, since the underlying tokenizer already generalizes to any function name list.

## Unit tests (stub environment, same approach as every prior probe and the Lab)

Stub coverage required before any real-client use, each mapped to a specific real finding it must not
regress:

- Every observer's happy path (real field names, matching the exact real shapes documented in
  `HARVEST_CONTRACT.md`'s field-mapping table).
- Missing/nil API returns for each observer (mirrors the Lab's own edge-case tests for missing
  `GetQuestID`, missing `C_Timer`, etc.).
- `SafeCall` against a return shape with nils in the middle followed by real values — the exact
  reputation-follow-up bug class, re-verified for any new call site this design introduces (there should
  be none, since all reused logic already passed this test in the Lab, but any *new* code, such as the
  save-confirmation step, needs its own coverage).
- Bounded retry: confirm the item-name retry still stops at 3 attempts and is a no-op when nothing is
  pending (unchanged logic, re-verified after porting).
- Build metadata: two simulated logins with different `GetBuildInfo()` values, confirming each
  observation retains its own build (mirrors the existing M4 audit-fix test exactly).
- Quest-scoped vs. NPC-scoped `GiverIdentity`: both branches, using the real-data shape that originally
  exposed this gap (a `GOSSIP_SHOW` observation with no `quest_id`) as the test fixture.
- Guaranteed-item `evidence_note` field (new in this design) present only on the guaranteed-item case, not
  on choice items.

## Contract tests

- A synthetic export produced by the new recorder's own logic validates cleanly against
  `schemas/harvest_observation.v1.schema.json` using the existing shared validator
  (`src/foreverdb/harvest/schema_validate.py`) — no new validator, no schema changes.
- `module_status="proven"` on every observer this design ships (there should be no experimental modules
  at all in a first production release, per §2/§4 of the design doc) — a test that asserts this
  structurally (enumerate registered modules, assert none report `"experimental"`), not just by
  inspection.
- Feed a synthetic export through the *existing, unmodified* M4 importer and confirm it produces the
  expected assertions — this is the strongest contract test available, since it exercises the real
  consumer, not a re-implementation of its rules.

## Integration tests (real client — designed here, not yet performed)

Same discipline as every M3/M4 real-client round: small, targeted, one variable isolated at a time.

1. **Quest observation** — accept, view, complete, turn in one real quest; confirm title/level/objectives/
   XP/money all appear correctly in the export.
2. **NPC-only observation** — trigger `GOSSIP_SHOW` with an NPC not currently offering anything to the
   player; confirm an `entity_type="npc"`-eligible observation results (checked after import, the same
   way the real M4 fix was verified) and that no quest ID is fabricated.
3. **Reward observation** — a quest with a choice reward (proven-tier) and, if one happens to be
   available, a guaranteed-item quest (to attempt a second real confirmation of that still-thin evidence
   base — not required for release, valuable if convenient).
4. **Position observation** — confirm coordinates appear and are clearly the player's position, not an
   NPC's, by comparing against where the player actually stood.
5. **Session/build provenance** — one session, `/fr save`, `/reload`, one more observation, `/fr save`
   again; confirm two distinct session IDs appear across the two saves (mirrors the exact test that
   validated this for the Observation Lab).
6. **Manual export** — confirm `/fr save` reliably produces a file on disk, and that the new confirmation
   step (design §11) actually displays.
7. **Re-import into M4** — the real acceptance test: take the resulting export, run it through the
   unmodified `harvest-import` CLI command, and inspect the actual resulting SQLite rows — not just a
   successful exit code, per the standard already set for M4 itself.
8. **Persistence behavior** — deliberately repeat the exact `/reload`-vs-logout comparison that originally
   found the SavedVariables issue, to confirm the *symptom* still needs the `/fr save`-before-logout
   workaround (or, if Forever's client has changed, to discover that it no longer does — either result is
   useful and should be recorded plainly, not assumed).

**None of items 1–8 have been performed.** They are the exact list that would need to run, in this order,
before any claim that the production recorder works on a real client.

## What this test plan does not cover

Performance benchmarking under real gameplay load, behavior across multiple concurrent characters/realms,
and any multi-contributor scenario — all explicitly out of scope for a first production release per the
design document's own stated boundaries.
