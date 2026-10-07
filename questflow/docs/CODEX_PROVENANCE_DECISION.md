# Forever Codex: provenance decision for the first development build

**Decision (project owner, for the first local development build only):** the Codex addon's data packs may be
generated from the current ATT-derived data so the route engine and UI can be tested against real quest data.

What this decision **is**:

* Local development and testing by the project owner and invited testers.
* ATT-derived data stays in its **own packs**, marked `src = att`, `verified = false`, with the pinned ATT commit
  (`8e25511677df4ea5c3d0322009eafc18f203ffd3`, MIT) in every file header and in the pack metadata.
* Observed Forever data (ForeverRecorder, passed the M6 readiness rule) is a **separate pack**, `src = observed`,
  `verified = true`, and takes precedence over ATT field by field when the same quest is present.
* The generator is deterministic and read-only with respect to its inputs; the frozen ATT files and the M8.13
  observed table are never modified.

What this decision is **not**:

* It is **not** a statement that ATT content is Forever-specific or confirmed. ATT coordinates have unresolved
  upstream provenance (`forever-db/docs/LICENSING.md`) and ATT's `lvl` is a required level, not a quest level.
  Codex shows ATT-derived content as "ATT - unverified on Forever".
* It is **not** a decision on **public redistribution** of ATT-derived data. That remains a separate, open licensing
  question. Do not publish the Codex data packs publicly until it is decided.
* It does **not** change `forever-db/docs/LICENSING.md` or any other licensing document (they are unchanged).
* It does not touch the excluded sources (ForeverGuide, Questie/QuestieDB, RestedXP-derived data, Wowhead) or the
  Blizzard-derived wago CSVs; none of them is read or shipped.
* It does not cover Blizzard-derived data of any kind. Codex ships only quest records (ids, names, giver ids and
  names, map coordinates, required levels, prerequisites, restrictions).

Long-term direction (not implemented): Classic/Era/SoD baseline + Forever-specific observed/verified additions and
changes, added as further packs.
