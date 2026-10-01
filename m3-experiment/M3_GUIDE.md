# M3 guide: addon probe + cache snapshot

Goal: find out what the real Forever client's addon environment and local cache expose about a quest,
beyond QuestV2's bare ID/flag/theme fields. Nothing here builds a database, imports data, or automates
gameplay. M0–M2 are frozen and untouched by this.

Everything below was tested before delivery: the addon was load-tested against a stub WoW environment
covering every event and both present/missing API cases (one real bug caught and fixed — a reliance on a
WoW-only string method that was never confirmed to exist here, replaced with plain Lua); the cache script
was run against a synthetic cache directory with known-correct header bytes and against missing-folder,
empty-folder, and truncated-file cases. None of that proves it works identically on your real client —
that's the experiment — but it does mean you're not the first thing to run this code.

## Safety notes (read once)

- The addon is **read-only**. It never calls `AcceptQuest`, `CompleteQuest`, `TurnInQuest`, or anything
  that acts on the world. You perform every game action manually.
- Reading documented quest-log/unit-info APIs from an addon is normal, widely-practiced addon behavior —
  this is what quest-tracking addons have always done. Blizzard's add-on policy (reported, not fully
  read by the assistant) asks addons to be free and have visible/readable code, which this satisfies.
- **Reading cache files directly from disk (the PowerShell script) is a different category** from the
  addon. That's the same kind of local file access flagged as an open EULA question back in M1.5/M2 — not
  re-resolved here, just carried forward honestly. It reads existing files; it changes nothing.
- The addon saves its findings to `ForeverProbeDB` (account-wide SavedVariables). It never records your
  character name, realm, or account info — only quest/NPC/API data.
- **Uninstall the addon after this experiment.** It's a disposable research tool, not something to keep
  running.

## 1. Install the probe addon

Copy the whole `addon/ForeverProbe` folder into your AddOns directory:

```powershell
Copy-Item -Recurse "<wherever you downloaded this>\addon\ForeverProbe" "E:\World of Warcraft\_classic_beta_\Interface\AddOns\ForeverProbe"
```

Launch the Forever beta. At the character-select or addon-list screen, make sure **ForeverProbe** is
enabled (it has no dependencies, so it shouldn't be disabled automatically).

## 2. Confirm it loaded correctly

Log into your level 20 character. You should see, in your chat window, something like:

```
[FProbe] probe m3-probe-0.1 loaded. Read-only: does not accept/complete/turn in quests.
[FProbe] GetBuildInfo() = 1.60.1, 69913, Sep 17 2026, 16001
[FProbe] Interface matches the M2-recorded expectation (16001). [V]
[FProbe] Slash commands: /fprobe scan | /fprobe status | /fprobe clear
```

Paste back exactly what you see. If the interface number differs from `16001`, that's fine and expected
to be recorded, not an error — just tell me the real number.

## 3. Run the API existence scan

```
/fprobe scan
```

This prints one line per API from the M3 research list, showing `type()` — either `function` (exists) or
`nil` (doesn't, on this build). It also writes the full list into `ForeverProbeDB`. Paste back the full
output — it's about 47 lines, which is exactly the point: a clean, complete record of what exists.

## 4. Before-snapshot of the cache

Before doing anything quest-related, from PowerShell:

```powershell
cd "<wherever you want the snapshot files to land, e.g. C:\forever-extraction>"
.\m3_cache_snapshot.ps1 -ForeverRoot "E:\World of Warcraft\_classic_beta_" -Label before
```

Paste back the console output (file counts). Keep the `m3_cache_snapshot_before.json` file it writes —
I'll want its contents pasted back too, or the file itself.

## 5. Perform ONE quest, manually, start to finish

Pick any available quest on your level 20 character and do the full lifecycle yourself:

1. **Talk to the quest giver** and open the gossip/quest dialogue (accept the quest).
2. **Complete the objective(s)** by playing normally.
3. **Return and turn the quest in.**

Do this exactly once for this experiment — one clean, complete lifecycle is the target, not a whole
session's worth. Chat messages will scroll by as the probe records each step; that's expected and you
don't need to read them in real time.

## 6. After-snapshot of the cache

Immediately after turning the quest in:

```powershell
.\m3_cache_snapshot.ps1 -ForeverRoot "E:\World of Warcraft\_classic_beta_" -Label after
```

## 7. Check what the probe recorded

```
/fprobe status
```

Paste back the output. Then find the SavedVariables file (written on logout/reload, not while you're
still logged in):

```powershell
# ForeverProbeDB.lua doesn't exist until you log out or /reload. Do one of those first, then:
Get-ChildItem "E:\World of Warcraft\_classic_beta_\WTF\Account" -Recurse -Filter "ForeverProbe.lua"
```

That'll show you the account folder name (something Battle.net generated, not personally identifying by
itself). Open that file in Notepad and paste its contents back — or attach it directly, whichever's
easier. It's plain Lua table syntax, readable as text.

## 8. Send back both cache snapshots

Paste, or attach, `m3_cache_snapshot_before.json` and `m3_cache_snapshot_after.json`.

## 9. Cleanup

```powershell
Remove-Item -Recurse "E:\World of Warcraft\_classic_beta_\Interface\AddOns\ForeverProbe"
```

Once I have all of the above, I'll fill in `M3_PROBE_FINDINGS.md` and `M3_REPORT.md` from exactly what
you report — same evidence discipline as M1.5/M2: `[V]` for what was actually observed, `[2nd]` for
carried-over research claims, `[?]` for anything still unresolved.
