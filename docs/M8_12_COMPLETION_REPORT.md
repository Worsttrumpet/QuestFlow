# M8.12 Completion Report: Progression Startup-State Probe

**Result:** quest state **can** be reconstructed at startup — reliably from `PLAYER_LOGIN` onward, on both a fresh
login and a reload. **Before `PLAYER_LOGIN` on a fresh login it is silently wrong:** the quest log is empty and
the completed-quest APIs return confident negative answers (`false`, an empty list), not `nil` or an error.
The probe also confirmed that SavedVariables are restored **after** an addon's files run and before
`ADDON_LOADED`, contradicting an assumption written into ForeverQuestGuide v0.6. No production code, route data,
schema, recorder, M8.7–M8.11 file, or `M8_2_SCOPE.md` was modified.

## Validation record

| | |
|---|---|
| Date | 2026-09-30 |
| Client | build **70124**, interface `16001` |
| Character | same character as M8.7–M8.10; no questing, no travel |
| Raw evidence | `evidence/ForeverProbeM812.lua` — 3 sessions (v0.1 reload; v0.2 fresh login; v0.2 reload), 220,335 bytes, SHA-256 `7da6ae97d46cd38a6dbfaf8dda2baf78617ca8ba5621b908ea0485c7092d76f4` |
| Other evidence | Operator screenshots of 3 fresh logins (two under v0.1, whose sessions were not persisted — see §Probe revision) and 3 reloads |
| Lua errors | None reported on the first run; to be confirmed for the v0.2 runs |

## Probe revision

v0.1 inserted its session into its SavedVariables table at file load. On the real client every session after the
first was lost and the file re-saved unchanged. v0.2 attached the session at `ADDON_LOADED` and recorded the
timing: in both v0.2 sessions the table was **absent at file load** and **replaced before `ADDON_LOADED`**, and
the earlier-session count grew 1 → 2. v0.1's own reload-session data is unaffected and is kept as session 1.

## Checkpoint results

**Fresh login (session 2, `isInitialLogin = true`):**

| Checkpoint | t (s) | Log entries / quests | Completed flag, 8 turned-in quests | `GetAllCompletedQuestIDs` |
|---|---|---|---|---|
| file load | 0.000 | **0 / 0** | **0 / 8 — all return `false`** | **empty (0)** |
| `ADDON_LOADED` | 0.000 | **0 / 0** | **0 / 8 — all `false`** | **empty (0)** |
| `PLAYER_LOGIN` | 5.078 | 16 / 13 | 8 / 8 | 190 |
| `PLAYER_ENTERING_WORLD` | 5.078 | 16 / 13 | 8 / 8 | 190 |
| first `QUEST_LOG_UPDATE` | 6.743 | 16 / 13 | 8 / 8 | 190 |
| +0.5 s, +2.0 s, `PEW`+3.0 s | 7.4–8.7 | 16 / 13 | 8 / 8 | 190 |

Every checkpoint from `PLAYER_LOGIN` on is identical to the final one. The two v0.1 fresh logins seen on screen
showed the same pattern (0 entries and 0/8 flags at file load and `ADDON_LOADED`; correct from `PLAYER_LOGIN`).

**Reload (sessions 1 and 3, `isReloadingUi = true`):** all eight checkpoints, from file load onward, identical and
correct: 16 entries, 13 quests, 8/8 flags, completed list 189 (session 1) / 190 (session 3). First
`QUEST_LOG_UPDATE` at 0.917 s and 0.941 s. (The completed count rose by one between sessions — a quest turned in
during normal play.)

## Answers

| # | Question | Answer | Classification |
|---|---|---|---|
| 1 | Does `C_QuestLog.IsQuestFlaggedCompleted` exist? | Yes. The legacy global `IsQuestFlaggedCompleted` is **absent**; `C_QuestLog.GetAllCompletedQuestIDs` also exists; legacy `GetQuestsCompleted` absent | VERIFIED ON FOREVER |
| 2 | Correct for completed quests? | Yes, 8/8, from `PLAYER_LOGIN` on (and at all points on reload). Agrees with `GetAllCompletedQuestIDs` | VERIFIED ON FOREVER |
| 3 | Correct for not-completed quests? | Yes: two Alliance controls and quest 907 return `false` at every checkpoint | VERIFIED ON FOREVER |
| 4 | Accepted quest identifiable right after login/reload? | Reload: yes, from the first line of code. Fresh login: **no before `PLAYER_LOGIN`** (log empty); yes from `PLAYER_LOGIN` | VERIFIED ON FOREVER |
| 5 | Objective state readable right after login/reload? | Same timing as #4. All 13 in-log quests read with full objectives (e.g. Rot Hide Ichor 7/8; Watching the Roads 0/8, 0/8; Serpentbloom 0/10, matching the game's own tracker) | VERIFIED ON FOREVER |
| 6 | State differs between load, `PLAYER_LOGIN`, first `QUEST_LOG_UPDATE`, +0.5 s, +2 s? | Fresh login: file load and `ADDON_LOADED` differ (empty, wrong); `PLAYER_LOGIN` onward identical. Reload: no differences | VERIFIED ON FOREVER |
| 7 | Log readable only after a later event? | On fresh login, only from `PLAYER_LOGIN` (≈ 5 s after the addon loads, during the loading screen). No later event was needed | VERIFIED ON FOREVER |
| 8 | Reliable "reconciliation is now safe" trigger? | **`PLAYER_LOGIN`** — earliest correct point on both paths in all observations; `PLAYER_ENTERING_WORLD` fired at the same moment. `ADDON_LOADED` is **not** safe | VERIFIED ON FOREVER (3 fresh logins, 3 reloads) |
| 9 | Quest turned in before load identifiable from the API alone? | Yes: `IsQuestFlaggedCompleted` = `true` and not in the log, for all 8 — **provided it is read at `PLAYER_LOGIN` or later** | VERIFIED ON FOREVER |
| 10 | API existence and return values | See §Checkpoint results and the evidence file | VERIFIED ON FOREVER |

### Additional classifications

| Finding | Classification |
|---|---|
| SavedVariables are restored after the addon's files run and before `ADDON_LOADED` (absent at file load, replaced before `ADDON_LOADED`, in both v0.2 sessions) | VERIFIED ON FOREVER |
| `PLAYER_ENTERING_WORLD` reports `isInitialLogin` / `isReloadingUi` correctly (true/false on login, false/true on reload) | VERIFIED ON FOREVER |
| ForeverQuestGuide v0.6 `Preferences.lua`'s comment assumes SavedVariables are restored **before** its code runs; that is the opposite of the observed behaviour | VERIFIED BY EXISTING CODE |
| v0.6 still works: with a saved table missing a key, its getters return `nil` and every caller falls back to the default. Side effect: the first click of the Theme or View toggle then appears to do nothing (it compares against `nil`) | VERIFIED BY EXISTING CODE (impact low; not changed) |
| A quest **abandoned** before load reads the same as one never accepted (`ABSENT_NOT_FLAGGED`) | UNTESTED — no such quest was available without abandoning one; not required, since abandon is not completion |
| Whether `PLAYER_LOGIN` is equally reliable in instances, on very slow loads, or on a character's first-ever login | UNVERIFIED |
| Whether SavedVariables written at logout now persist (the M8.0 issue) | UNVERIFIED — this probe saved only via `/reload` |

## Incidental observation

Serpentbloom (962) is in the operator's log and in `Data.lua`; its objective text matches `Data.lua`. It has one
objective, so it does **not** close M8.9's open objective-ordering question.

## What the future progression controller should do at startup (design input, not implemented)

1. **Never read quest state at file load or `ADDON_LOADED`.** On a fresh login the answers are empty and falsely
   negative, with nothing to signal that they are wrong.
2. **Run reconciliation at `PLAYER_LOGIN`** (or `PLAYER_ENTERING_WORLD`). No extra delay was needed in any
   observation.
3. **Read saved progression at `ADDON_LOADED`, not at file load**, because that is when the SavedVariables table
   exists; and apply any defaults to the restored table there. (v0.6 applies its defaults at file load, to a table
   that is then replaced.)
4. Classify each step's quest with the five states used here, never inferring turn-in from absence:
   in log (incomplete / complete), flagged completed, absent and not flagged.
5. As a defensive check, treat an empty quest log together with an empty completed list as "not ready", not as
   "nothing done".

## Scope kept

No production code, route data, schema, recorder, M8.7–M8.11 file, or `M8_2_SCOPE.md` modified. No questing, no
travel. The probe can be removed from `AddOns` once this report is locked.

```text
M8.12 STATUS: COMPLETE — PASS (pending operator confirmation of no Lua errors in the v0.2 runs)
```
