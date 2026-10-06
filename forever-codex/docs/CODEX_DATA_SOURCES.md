# Forever Codex: data sources, licences and provenance (authoritative for the addon)

Last reviewed: 2026-10-06 (audit hardening pass). If this file and an older document disagree, this file wins for the **forever-codex addon**; `forever-db/docs/LICENSING.md` governs the dataset pipeline.

## The rules the addon follows
1. **Nothing from Questie, QuestieDB, RestedXP, ForeverGuide or Wowhead is copied** into this repository: no code, no data, no scraped text.
2. **Observed Forever data is the only data presented as verified.** Everything else is labelled with where it came from and `verified=false`, and the Registry lets observed data win field by field.
3. **Era / Classic assumptions never replace observed Forever evidence**, and a quest missing from a baseline is UNKNOWN, never "does not exist".
4. No `COMBAT_LOG_EVENT_UNFILTERED`, no protected or secure APIs, no raw GUIDs stored.

## Every dataset the addon uses

| Source | How it gets in | Where | Label | Licence / status |
|---|---|---|---|---|
| **Observed on Forever** (ForeverRecorder, M6 readiness rule) | Generated into `Data/Pack_Observed.lua` | shipped | `src=observed, verified=true` | Own data. Quest text is Blizzard's; positions are the recorder player's position, labelled as such |
| **ATT (AllTheThings) `forever` database**, commit `8e25511...` | Generated into `Data/Pack_ATT_*.lua` by `generator/build_codex_data.py` | shipped in the addon and in `dist/*.zip` | `src=att, verified=false`, commit pinned in every header | **MIT** (copyright AllTheThings WoW Addon). Upstream provenance of its coordinates is UNRESOLVED; its `lvl` is a required level, not a quest level |
| **QuestieDB** (separate addon installed by the player) | Read at RUNTIME through its documented public API (`QuestieBridge.lua`); nothing stored | never shipped | `src=questiedb, verified=false` | GPL-3.0 stated by the project's own notes; no licence file was found in its repositories. Not redistributed, so Codex's use is a runtime read, not a copy. Optional: Codex Options, or `/codex questiedb off` |
| **The game client** (quest log, dialogs, trainer windows, professions, item info) | Read live, stored per character or in account stores (see `CODEX_SAVED_DATA.md`) | SavedVariables | `PROVEN` / `UNPROVEN` per API, quest log = client truth | The player's own session data; never uploaded |
| **Codex's own art** | `generator/make_art.py` | `Media/*.tga` | n/a | Own work |
| Game fonts / textures | Referenced by game path, never shipped | n/a | n/a | Blizzard's, used in place |
| Wago CSVs (`forever-db/data/raw/att-head/.../.wago`) | Local files used by forever-db only; **untracked** (`git ls-files forever-db/data` is empty) | not in the addon | n/a | Blizzard-derived; redistribution unresolved |

## Decision C1: the QuestieDB runtime dependency (2026-10-06)
**Finding.** The addon depends on QuestieDB at runtime (`QuestieBridge.lua`, `## OptionalDeps: QuestieDB`) and, with it present, most of Codex's quest knowledge (about 4,257 of 4,357 quests) comes from it. `docs/LICENSING.md` and `forever-db/docs/LICENSING.md` said
Questie/QuestieDB was "Not read", which described the dataset pipeline and contradicted the addon.

**Decision.** The runtime read is compatible with the project's stated rule (rule 1 above: nothing is copied or shipped) and with its provenance rule (rule 2: it is labelled unverified and never overrides observed data). The licensing documents are corrected to say
what is true instead of "Not read". Two safeguards are added so the dependency is a visible choice rather than an accident: it is **optional and off-switchable** (Codex Options "Use QuestieDB quest data if installed", or `/codex questiedb on|off`), and
`CODEX_QUESTIEDB_BRIDGE.md` records exactly which API surface is used.

**Still open (needs the owner, not the code).** QuestieDB's own licence could not be confirmed. Before any PUBLIC release, confirm it with the maintainers. If the owner's intent is "no use of QuestieDB at all", flip the default of `Preferences.UseQuestieDB`
to false (one line) and Codex falls back to its observed and ATT packs (about 1,100 quests) with no other change.

## Decision C2: ATT-derived packs in the committed zips (2026-10-06)
**Finding.** Every `dist/<minor>/ForeverCodex-<version>.zip` contains `Data/Pack_ATT_*.lua`. `CODEX_PROVENANCE_DECISION.md` allows that for local development and invited testers and forbids PUBLIC redistribution until it is decided.
The repository `Worsttrumpet/wow-forever-guide` is **PRIVATE** (GitHub API `visibility: private`, checked 2026-10-06), so nothing is currently published.

**Decision.** The current arrangement is acceptable: the data is MIT upstream, every pack header carries its source, commit and `verified=false`, the repository is private, and no third party can fetch the zips. What is NOT acceptable and is now guarded:
* making the repository public, attaching a zip to a public release, or posting a zip while ATT redistribution is unresolved. **Gate:** do not do any of these until the owner records a decision here. The automated test `generator/test_data_provenance.py` pins the expected data files, their provenance headers and their manifest hashes, and fails if a data file appears that is not listed here.
* Removing provenance: the headers and `Data/MANIFEST.txt` stay.
If the repository is ever made public, first remove `dist/` and the ATT packs from the tree (and from history if required) or record the owner's redistribution decision in this file.
