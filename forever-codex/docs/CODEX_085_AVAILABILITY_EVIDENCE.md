# 0.8.5: offer evidence is trusted only as far as it goes

The planner already used OfferProbe evidence (held-back pickups, POSSIBLE pickups, confidence). Three correctness gaps found in the 0.8.4 audit are fixed; no new API or telemetry.

| | before | now |
|---|---|---|
| G1 | positive, then a newer current negative (NOT_OFFERED), then the negative goes stale: the old positive came back as OBSERVED | stale negative over an older positive = UNKNOWN (`SUPERSEDED`); OBSERVED again only after a new observation lists the quest. A positive is not aged by progress alone. The record is kept. |
| G2 | a quest opened at ANY NPC was OBSERVED for routing to the data giver's position | only when that NPC is the quest's giver (id, or name when an id is missing). A different known NPC: kept as history, `OBSERVED_ELSEWHERE`, UNKNOWN, never NOT_OFFERED. The giver's own listing, if any, still counts. |
| G3 | a listing matched by name even when both creature ids were known and different | names match only when an id is missing on at least one side (a guild line in data names, "<Priest Trainer>", is ignored). |

`Planner.OfferState`, `Actionability` and `/codex report` (PickupEvidenceLines) read the new kinds. Tests: `availability_evidence_tests.lua`; three `item_probe_tests.lua` expectations that encoded the old behaviour were updated. No golden changed.

Real client: whether Forever ever opens a quest dialog at an NPC other than the data giver is still unknown; such a case now reads UNKNOWN.
