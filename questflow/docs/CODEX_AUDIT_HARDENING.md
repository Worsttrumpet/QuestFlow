# Audit hardening pass

Source: the read-only audit of the 0.7.8 tree (findings C1, C2, H1 to H3, M2 to M6, L1 to L5). Every item below states what was done and what still needs the real Forever client. Stub tests prove Codex's own logic, not the real client.

| Item | Status | What changed |
|---|---|---|
| C1 QuestieDB dependency | **Resolved by decision** (owner confirmation still advised) | Documented as acceptable: runtime read of the player's own addon, nothing copied or shipped, labelled unverified. Licensing documents corrected. NEW: optional and off-switchable (Codex Options, `/codex questiedb on/off`, `Preferences.UseQuestieDB`). QuestieDB's own licence is still unconfirmed: confirm before any public release. `CODEX_DATA_SOURCES.md` |
| C2 ATT packs in committed zips | **Resolved by decision + guard** | Repository is PRIVATE (checked via the GitHub API); the provenance decision allows dev builds and invited testers. Public release stays gated. `generator/test_data_provenance.py` pins the data set, the provenance headers and the manifest hashes |
| H1 telemetry / offers isolation | **Resolved** | Per-character stores with parking, a migration, reset on a re-created character. `SavedData.lua`, `CODEX_SAVED_DATA.md`, `tests/saved_data_tests.lua` |
| H2 saved-data migration | **Resolved** | `SavedData.Migrate`, version 2, old-save fixtures (single character, several characters, no version field, newer version, idempotence) |
| H3 login / idle recompute | **Resolved in code, NOT measured on the real client** | First scan warmed over several frames; idle periodic refreshes skipped unless the player moved or a timed quest is active; counters in the report. `tests/recompute_tests.lua` |
| M2 / M3 stale text | **Resolved** | HelpCodex (storage wording), Diag (quest-starting items, performance line, conditional line), Knowledge ("found" wording, trainer purchase caveat) |
| M4 loadstring on QuestieDB data | **Partially resolved** | `loadstring` removed: the AreaID table is parsed as DATA by a strict parser (only `[int]=int` pairs). Codex still has NO area table of its own (the Blizzard AreaTable it would come from is not redistributable), so without QuestieDB's table NPC areas cannot be placed. NOTE: the audit called the field "private internals"; the bridge header says it is documented API, which could not be verified here. REAL-CLIENT CHECK: `/codex report` shows "QuestieDB area map: read as data (N entries)"; "REJECTED" means the real text has another format and the parser needs adapting |
| M5 NOW with no arrow | **Resolved** | A withheld arrow now says "Head roughly south-east, about 860 yards" (compass word and rounded distance from the same measurement the arrow uses), never a coordinate, and the arrow stays withheld. Not given when Codex cannot measure, or for special travel |
| M6 legacy test dependency | **Resolved** | Observed-data input copied into `generator/inputs/`; copy-fidelity test replaced by hash pins (`generator/test_frozen_inputs.py`); the Lua tests no longer take the legacy directory. Verified by running the whole suite with `m8-13-progression/` moved away |
| L1 dead combat-log path | **Resolved** | Handler, helpers and the `sk` field removed from Telemetry; MOB_KILL stays only as an UNAVAILABLE capability entry |
| L2 BlizzardTracker taint | **Mitigated** | No Hide / Show while `InCombatLockdown()`; postponed to PLAYER_REGEN_ENABLED. Whether the real tracker frame is protected is still unknown |
| L3 swallowed errors | **Resolved** | The first error from each place is announced once in chat (max 3 per session) |
| L4 "found" wording | **Resolved** | See M2/M3 |
| L5 committed zips (58, 13 MB) | **Intentionally unresolved** | Deleting released builds is the owner's call; the repository is private and the size is modest |
| Inert planned systems, `PlanAdapter` bridge, `UI/Window.lua` developer window | **Intentionally unresolved** | Removing them is a refactor with real regression risk and no player benefit today; documented in the audit |

## Needs the real Forever client
1. First-login feel: is the warm-up smooth, and what does `login warm-up` report?
2. A second character on the same account: its `/codex report` SAVED DATA shows its own stores, not the first character's.
3. The QuestieDB area map line (see M4) and `/codex questiedb off`.
4. A far approximate NOW objective: is the compass direction right when compared with the real map?
5. The earlier open items: the purchase hook (0.7.7), the resize drag and first-run setup (0.7.8).
