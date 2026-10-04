# Character identity and state isolation (0.7.5)

## Real-client finding (build 70205, 0.7.4 playtest)
A new level 2 Tauren Hunter named like an earlier, deleted character inherited that character's state: 92 turn-ins in the progression stamp, 107 journey entries, 10 skips (including Zephras Isle quests from the old
Skyborne Rogue), Spell Training dismissals and profession state. Separately, 8-13 hour old dialogs with no progression stamp held Zephras quests back for the new character. **Name-Realm is not a character identity.**

## Where state lives
| Scope | Stored in | Contents |
|---|---|---|
| Per character (`ForeverCodexDB.chars["Name-Realm"]`) | Preferences | gameplay: `skipped`, `added`, `journey` (entries, turned-in quests, last level), `nav` (last waypoint), `routeZone`, `spellTraining`, `professions`; preferences: `style`, `systems`, `navigation`, `arrow`, `partyNotify`, `hardcore`, `hereRadius`, `setupDone`; and (new) `identity`, `identityReset` |
| Global / account-wide | `ForeverCodexDB.ui`, `.offers`, `.items`, `.quest`, `.telemetry`, `.feedback`, `.diag` | window and minimap settings, OfferProbe dialogs, item and eligibility evidence, remembered quest items, telemetry events, feedback reports |

## What identity signal Forever provides
* `UnitGUID` is proven to answer on Forever for an NPC (`UnitGUID("npc")`, used by OfferProbe). **Whether `UnitGUID("player")` returns a usable `Player-...` value on Forever is unproven.** Codex uses it only if it returns a string
  starting `Player-`, stores only a 16-digit one-way hash (never the GUID), and reports in `/codex report` which signal decided.
* Proven and reliable: class, race, faction and level (and levels never go down).

## The check (`Preferences.CheckIdentity`, at PLAYER_LOGIN before anything reads the state)
1. Same hashed id -> same character. A different hashed id under the same name -> a new character (the only signal that can see a same-class, same-race, same-level re-roll).
2. No usable id: a different class, race or faction, or a level lower than the highest level seen for this name, cannot be the same character -> new character.
3. A legacy save (no fingerprint yet) is judged by the highest level in its journey; a save nothing contradicts is kept and fingerprinted.
A new character gets a clean slate for **gameplay state only** (skips, added quests, journey and turn-ins, saved waypoint, route zone, Spell Training, Professions) and the player is told once in chat. Window position, route style,
system toggles and every account-wide store are untouched. A normal level-up or relog never resets anything (`NoteLevel` only raises the stored highest level).

## What it cannot detect (stated plainly: this is a defence, not an identity)
A deleted character recreated with the same name, class, race and faction whose level has not gone below the old one's highest (for example a level 1 re-roll of a level 1 character: nothing is lost), or an old character that
never got past the new one's level, is not detected unless `UnitGUID("player")` works. The account-wide offers store is still shared between characters; dialogs are protected only by the progression stamp, which is not
character-specific (a coincidental `level:turn-ins:ready` match between two characters is possible).

## Unstamped dialogs (second fix)
A dialog observation with no progression stamp (saved before stamps existed, or by an older build) is **never current**: a negative read from it is stale (the quest's state is UNKNOWN, not NOT_OFFERED) and cannot hold a
quest back. Codex does not invent a stamp for it. A fresh stamped negative still holds; a stale stamped negative still ages out to UNKNOWN; positive evidence and fresh offered-here candidates are unchanged (a positive record with no
stamp is still evidence of an offer but is not offered as current).
