# M2 findings

QuestV2 was successfully extracted from a real WoW Forever beta client. The client contains 6,690 QuestV2
records according to the DB2 header: 6,600 unencrypted records and 90 encrypted records across two
encrypted sections. The 6,600 unencrypted count matches the previously reported public extraction count.
The encrypted records were intentionally not decrypted — no TACT keys were used.

**This does NOT establish that all 6,690 records are usable quest records, obtainable quests, or
server-confirmed quests.** QuestV2 is an ID/existence table and requires additional evidence to determine
what those IDs represent. It does not establish quest titles, objectives, rewards, NPCs, prerequisites, or
any other server-side quest information.

The 90 encrypted records are not "90 new quests" — they are 90 encrypted QuestV2 rows whose content is
unknown.

Full detail: `M2_REPORT.md`. Full machine-readable record: `M2_ATTESTATION.json`.
