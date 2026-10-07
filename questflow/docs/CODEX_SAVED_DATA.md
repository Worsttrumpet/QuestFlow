# Forever Codex: what is saved, who owns it, and how an old save is upgraded

`ForeverCodexDB` (SavedVariables). Version: `ForeverCodexDB.version` (this build writes version **2**; `Preferences.DB_VERSION`).

## Who owns what
| Key | Scope | Why |
|---|---|---|
| `chars["Name-Realm"]` | **one character** | choices, skips, journey, Spell Training entries, professions, identity (hash), setup state |
| `offers` (NPC dialog / offer evidence) | **one character** (live table stamped `owner`) | what a dialog offered depends on THAT character's level, class, faction and progress |
| `telemetry` (observation log) | **one character** (live table stamped `owner`) | it is what that character did and saw |
| `ui` (window, minimap, theme, QuestieDB switch) | account-wide | how the player wants Codex to look |
| `items` (item facts, eligibility evidence by class) | account-wide | item data belongs to the game, not a character |
| `spellCatalog` | account-wide, per CLASS | observed trainer windows; used by any character of that class |
| `feedback`, `diag` | account-wide | reports the player wrote / stored |
| `legacy` | archive, unused | see migration |
| `migrations` | log (last 10) | what each upgrade did |

How the per-character stores work: the live tables keep their historical names (`ForeverCodexDB.offers`, `.telemetry`) so no module changed, but each carries `owner`. At login `SavedData.PrepareLogin` makes THIS character's tables live and PARKS the previous owner's under `chars[owner].parked`; a character that logs back in gets its own back. A re-created character with a reused name (`Preferences.CheckIdentity` RESET) drops them with the rest of its state. Telemetry has its own PLAYER_LOGIN handler, so it calls `PrepareLogin` itself (the order of two frames is not relied on).

## Versions and migration (`SavedData.Migrate`)
* A save with no `version` is version 1 if it contains anything, and current if it is empty (a new install).
* Steps run one at a time from the save's version to the current one, never raise, record what they did in `migrations`, and stop (leaving the save at the last good version) if a step fails. A save from a NEWER build is left completely untouched.
* **1 to 2:** the two stores had no owner. If the save has only ever seen ONE character, that character keeps them. If it has seen several, whose they are is unknowable, and giving them to whoever logs in first would recreate the leak, so they are **archived untouched under `legacy`** (nothing is deleted, nothing is used). Cost: a multi-character account's dialog evidence restarts empty and rebuilds as dialogs are opened.
* Additive defaults (`ensureChar`) still fill in anything missing. A migration step is only for a field that was moved, renamed, reshaped or removed. Add one by adding `MIGRATIONS[n]` and raising `DB_VERSION`, and a fixture in `tests/saved_data_tests.lua`.
* `/codex report` prints a SAVED DATA section (version, last migration, what was archived, who owns the live stores).
