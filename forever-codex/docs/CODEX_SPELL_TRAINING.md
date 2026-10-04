# SPELL TRAINING (0.7.1)

A section of the existing Codex window, below DUNGEON QUESTS. Informational: Codex never trains anything and has no Learn button.

## What it shows
Class spells (one rank at a time) that the trainer window listed on a past visit, whose level requirement the character has reached, that the character does not know and has not
marked **Don't Want to Learn**. Name, rank, cost (the project's `Items.Money`, e.g. `12s`), and `Total training: ...` for what is listed. No spells: no section (no empty header).

## Evidence boundary (what is and is not verified)
* **Not verified on Forever:** nothing in this repository proves the trainer, spell or spellbook APIs work on Forever. Before 0.7.1 the repo said "Forever's spell and trainer APIs are unverified"
  (`NewForYou.lua`, `Knowledge.lua`); no earlier probe or "What's Training?" integration exists. Every read is behind `pcall`; a missing API means the section stays empty.
  `/codex spells` and `/codex report` print which functions exist and what the last trainer read returned.
* **The only source of "what can be trained" is the trainer window the player opens** (`GetNumTrainerServices`, `GetTrainerServiceInfo`, `GetTrainerServiceCost`, `GetTrainerServiceLevelReq`,
  `GetTrainerServiceItemLink`, `IsTradeskillTrainer`), read at `TRAINER_SHOW` / `TRAINER_UPDATE`. There is no remote trainer query: nothing is listed before the first visit, costs are those
  shown at the last visit, and a spell becomes listed at its level requirement from the stored visit. Codex ships no spell, rank, cost or trainer data and no locations.
* **Known spells:** `IsPlayerSpell(id)` / `IsSpellKnown(id)` when the trainer link carries a spell id (`|Hspell:ID|`), otherwise the spellbook by name and rank
  (`GetNumSpellTabs`, `GetSpellTabInfo`, `GetSpellBookItemName`). A trainer service shown as "used" marks the spell learned.
* **Learning is noticed automatically:** `TRAINER_UPDATE` (a purchase), `LEARNED_SPELL_IN_TAB` / `SPELLS_CHANGED` (registered optionally; refused events are ignored) and the known-spell
  check on every recompute. Nothing polls.

## Ranks
A rank is its own spell id on a Classic-style client, so a new rank is a new entry and a new opportunity. Only the lowest rank still to learn of a spell is shown; a known higher rank retires
lower ones. If the trainer gives no spell id the key is `name|rank` and is flagged `no spell id` in the report. **Forever may differ**: if Forever merges ranks into one spell id, Codex would
treat the new rank as the same entry. That is unverified.

## Don't Want to Learn
Per character (`Prefs.Char().spellTraining.dismissed`, keyed by spell id). Survives recompute, reload, relog; never shared between characters; a new rank (new id) is not covered by an old
dismissal. `/codex spells restore` brings dismissed spells back. The store is stamped with the class: a deleted-and-recreated character of another class under the same name starts empty.

## Not done / limits
No trainer locations, no automatic training, no planner input (the planner, adapter and engine do not reference it; a test checks that). Profession trainers are ignored here (they feed PROFESSIONS).
A profession-trainer check relies on `IsTradeskillTrainer`; when it is absent the snapshot is flagged `trainerKind = unknown`.

## Observed on Forever (build 70205, 0.7.1 playtest, level 23 Hunter)
* Present: `GetNumTrainerServices`, `GetTrainerServiceInfo`, `GetTrainerServiceCost`, `GetTrainerServiceLevelReq`, `GetTrainerServiceItemLink`, `IsTradeskillTrainer`, `IsPlayerSpell`, `IsSpellKnown`.
  **Absent:** `GetNumSpellTabs`, `GetSpellBookItemName` (so the spellbook name/rank fallback cannot work on Forever).
* A class trainer window returned **89 services** and `IsTradeskillTrainer()` false; `GetTrainerServiceItemLink` gave **no spell id for any of them** (0 of 89 matched `spell:<id>`), and **no service was stored**,
  so the category values Forever returns are not the Classic strings `available` / `unavailable` / `used` (or are not strings). Without ids the known-spell check by `IsPlayerSpell` cannot run either.
* A profession trainer window read once returned 0 services (probably an empty update as the window closed; `TRAINER_UPDATE` fires many times).
* 0.7.2 adds diagnostics only (the exact categories, the first six raw services including the link, the latest non-empty read, and which other spell names exist). The next report decides how to read the list; nothing is guessed.
