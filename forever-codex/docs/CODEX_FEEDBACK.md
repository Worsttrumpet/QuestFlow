# REPORT A PROBLEM (0.7.1)

One button in the Codex window, one sentence from the player, and Codex captures the technical context itself.

## What the Forever client allows (investigation)
A WoW addon runs in a sandbox. **Nothing in this repository shows Forever lifting any of these limits, and Codex does not pretend otherwise:**
| Capability | Result |
|---|---|
| Outbound HTTP / POST to a Discord webhook | **Not possible** from an addon. No HTTP function exists in the addon API; none was found in any probe in this repository. Codex looks for such functions by name (`Feedback.Capabilities`, shown in `/codex report` and `/codex feedback status`) and never calls them. |
| Open an external URL | Not possible (no such addon function). |
| Write arbitrary files / export a text file | Not possible. Only SavedVariables are written, by the client, at `/reload` and logout (`/reload` is reliable on Forever; logout saves have failed intermittently, M8.0). |
| Clipboard | No clipboard API. The proven mechanism is an EditBox with highlighted text and Ctrl+C (the existing `/codex report` window). |
| Addon communication | `C_ChatInfo.SendAddonMessage` goes to game channels only (used by the Party card, unverified on Forever). It cannot reach Discord. |
Direct webhook delivery is therefore **not supported**. It would also be unsafe in an addon: a webhook URL shipped in an addon is readable by every user and can be abused to spam the channel.
**No webhook URL is in the code.**

## Delivery that is implemented
1. The report is created and **saved locally** in `ForeverCodexDB.feedback.reports` (last 20; written to disk at `/reload` or logout).
2. The window shows ONE compact block (a short readable summary, then one line of JSON) selected for Ctrl+C. The player pastes it where the developer asked (Discord, a DM).
3. The window never says "sent": it says *"Feedback report created and saved locally ... Codex cannot send it for you."* `result.sent` is always false.
Developers retrieve reports from the pasted text, or from `WTF/Account/<account>/SavedVariables/ForeverCodex.lua` (`feedback.reports[*].export`).

## UI
* **Feedback** button in the tracker's title bar (right of the title, left of the close button); `/codex feedback` opens the same window (`/codex feedback list|status` for power users).
* A **Report** button on the NOW card opens the form with "Codex recommended something wrong" chosen and the recommendation named. READY/ALSO rows have no buttons (the report always captures them).
* Seven categories: wrong recommendation, missing quest, navigation, spell / profession, something isn't working, suggestion, other. A sentence is required.
* The window says what is included: *"Codex will include your current game and addon state ... Your character name is not included."*
* `/codex report` (the developer diagnostic) is unchanged and now includes a FEEDBACK line about what the client can do.

## Report format (schema 1)
Deterministic JSON (sorted keys; `Feedback.ToJson`, no library). Fields: `schema, id (FC-<session>-<n>), session, at, category, from (NOW|WINDOW), text, version, client{build,game,interface},
char{class,level,faction,race}, loc{map,x,y,zone,subzone}, window{guidance, now{title,who,dist,why,note}, nowAction{id,quest,kind,type,name,npc,evidence,state,offerState,actionability,offer{},
where{map,x,y,status,kind,src},yards,codes[]}, ready[], also[], alsoDo, spells, professions}, log[{id,title,done,obj}], plan{reason,candidates,unlocated,held,possible}, nav{status,noPin,hasTarget},
events[last 8], extra[] (spell/profession category only), codexErrors[last 3], trimmed[]`. The "why" is the planner's own reason codes plus the offer/evidence facts Codex already derives; there is no second
explanation engine. Size: the JSON is capped at 3,500 bytes by dropping the least useful sections first (listed in `trimmed`).

## Privacy
Included: Codex version, build, interface, class, level, faction, race, map/position/zone, quest log (ids, titles, completion), what the window shows and why, navigation state, a few recent events, up to three Codex error
strings. **Excluded:** character name, realm, account / Battle.net data, GUIDs, machine or filesystem information (paths in any text are replaced by `<path>`). The player's sentence is included as written (600 chars max).

## Future
The `schema`, `id` and `session` conventions are shared with a later opt-in **Help Improve Codex** (richer telemetry export): that is a separate feature and is not implemented. A helper, website or Discord relay can
consume the JSON unchanged; if the platform ever provides a network function, a transport can be added behind `Feedback.Create` without changing the format.
