# PROFESSIONS (0.7.1)

A small status and reminder card in the Codex window (below SPELL TRAINING). **Not a leveling guide**: no routes, trainer locations, recipes, materials, optimisation or arrows.
It answers: what professions do I have, at what skill and cap, is a primary slot free, is a secondary profession not learned, is a higher rank offered by a trainer.

## What is verified about Forever, and what is not
* **Verified (real reports, build 70205, recorded in `CODEX_REALCLIENT_FIXES.md`):** the Classic skill-line functions `GetNumSkillLines` / `GetSkillLineInfo` are ABSENT.
* **Not verified:** which profession API Forever DOES answer. Nothing in the repository proves one. The reader therefore tries, behind `pcall`: (1) `GetProfessions()` + `GetProfessionInfo(i)`
  (name, rank, maxRank, skillLine ...), then (2) `GetNumSkillLines` / `GetSkillLineInfo` (header rows "Professions" / "Secondary Skills"). If neither answers the section is hidden and
  `/codex professions` says so. No other API was probed; GatherMate2 was not used.
* **Assumed, labelled UNVERIFIED in the code and the report:** the secondary professions (Fishing 356, Cooking 185, First Aid 129: Classic skill-line ids / English names) and two primary
  slots. They are used only for the "Not Learned" and slot lines, and only when a reader succeeded. English-name matching fails on a localized client when no skill-line id is given
  (the line is then simply absent).
* Skill and cap are read live from the client; nothing is hard-coded for them.

## Rank-up reminders
The only source is a **profession trainer's own window** (the same `TRAINER_SHOW` read Spell Training uses, and only when `IsTradeskillTrainer()` is true): a service that is "available",
whose name contains one of the character's profession names and is not that bare name ("Journeyman Skinning"). No rank words and no skill thresholds are hard-coded. Stored per character with
the cap at that time; cleared when the profession's cap rises (the training was taken) or the trainer lists the service as learned. Without a trainer visit Codex claims no rank-up.
Assumption: rank services carry the profession name; recipes (which do not) are ignored.

## Persistence, hiding, events
Per character (`Prefs.Char().professions`: `rankUps`, `hidden`), keyed by skill-line id when the client gives one, else by lower-cased name. "Not Learned" rows have a Hide button
(`/codex professions hide fishing`, `restore`). No rows (reader failed, or nothing to say): no section. Updates: `SKILL_LINES_CHANGED`, `CHAT_MSG_SKILL`, `TRAINER_*`, `SPELLS_CHANGED`
(optional registrations) plus every recompute; nothing polls.
