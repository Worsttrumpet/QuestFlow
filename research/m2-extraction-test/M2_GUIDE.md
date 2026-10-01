# M2.1/M2.2 local extraction test — guide

Goal: establish what your real Forever beta client contains. Not a database build, not an addon, not
route planning. Nothing here touches `forever-db/`.

I cannot access your machine. You run each command locally and paste the output back to me; I use it to
fill in `m2_attestation.json`. `verify_db2_header.py` in this folder needs no install — plain Python 3.

**Rules we're following:** no TACT keys unless you explicitly say so; base tables only (`--no-hotfixes`
on the extractor); no game files modified; no Wago, no Wowhead; only QuestV2's raw bytes get deeply
analyzed — the other 14 tables are existence-checked only, and I say below exactly what that check does
and does not touch.

---

## Step 0 — identify your installation

Tell me:
1. **OS** (Windows or macOS).
2. **The WoW root folder** — the one that directly contains `.build.info`, one level above the
   `_retail_` / `_classic_` / `_classic_beta_`-style subfolders. If you're not sure, the Battle.net app
   can show it: select **WoW Forever Beta** → the gear/options icon → **Show in Explorer** (Windows) or
   **Show in Finder** (macOS). That opens the product subfolder; go up one level to reach the root.

You can start Steps 1–3 right now with the commands below; I only need your answer to proceed to Step 4
onward, since the CASC path and the extraction tool's settings file depend on the exact `Product` string
your client reports.

---

## Step 1 — `.build.info`

This file sits directly in the WoW root (shared across every product installed there, not just Forever).

**Windows (PowerShell):**
```powershell
cd "<your WoW root>"
Get-Content .build.info
Get-FileHash .build.info -Algorithm SHA256
```

**macOS (Terminal):**
```bash
cd "<your WoW root>"
cat .build.info
shasum -a 256 .build.info
```

It's a small pipe-delimited table; the first line is column headers like `Branch!STRING:0|...`. Paste me
the **whole file** (it's build metadata only — branch, hashes, version — no account or character data)
and the hash. I'll pull out `Product`, `Version`, and `Build Key` for the row that matches Forever.

**Evidence level:** `[V]` for what the file contains — you read it yourself. `[2nd]` that it correctly
identifies the running build: `.build.info` is written by the Battle.net agent as a cache, not by the
game client itself, so it's one claim, not proof (this is why Steps 2–4 cross-check it independently).

---

## Step 2 — game executable version

First we need to know which subfolder is actually the Forever beta — don't guess by folder name, since
naming conventions aren't guaranteed. Each product folder contains a `.flavor.info` file that names its
TACT product directly:

**Windows:**
```powershell
Get-ChildItem -Recurse -Depth 1 -Filter ".flavor.info" | ForEach-Object {
  Write-Host $_.FullName; Get-Content $_.FullName
}
```
**macOS:**
```bash
find . -maxdepth 2 -name ".flavor.info" -exec sh -c 'echo {}; cat {}' \;
```

Match the product name against the `Product` column from Step 1. That subfolder is your Forever install
(`<Forever folder>` below).

Then, the executable version resource:

**Windows:**
```powershell
$exe = Get-ChildItem "<Forever folder>" -Filter "Wow*.exe" | Select-Object -First 1
$exe.FullName
$exe.VersionInfo | Format-List FileVersion, ProductVersion, InternalName, OriginalFilename
Get-FileHash $exe.FullName -Algorithm SHA256
```
(A third-party bug report says the beta executable is named `WowB.exe`; the filter above catches it
without assuming that's exactly right — tell me what `Get-ChildItem` actually finds.)

**macOS:** WoW ships as a bundle, and past clients haven't reliably exposed a version resource in
`Info.plist`. Try:
```bash
find "<Forever folder>" -maxdepth 3 -iname "*.app" -o -iname "wow*"
```
and tell me what's there — I'll give you an exact next command once I know the structure, rather than
guessing at Mac WoW internals I haven't verified.

**Evidence level:** `[V]` for whatever the OS reports about the file you're pointing at; `[?]` whether
this executable's version resource is reliably populated for this beta build until we see it.

---

## Step 3 — `GetBuildInfo()` in-game

In WoW, with any character (your level 20 works fine — no need to be at a specific spot):
```
/dump GetBuildInfo()
```
This opens a small window showing four return values: version string, build number, build date, and
interface (TOC) version. Paste all four back to me. This is a documented, official Blizzard API — the
same call every quest-helper addon uses to log which build it's running on.

**Evidence level:** `[V]` — the client's own answer to an official API, independent of `.build.info`.

---

## Step 4 — locate CASC data and cross-check the build key

Inside `<Forever folder>`, the CASC data lives under `Data/`:

**Windows:**
```powershell
Get-ChildItem "<Forever folder>\Data" -Directory
```
**macOS:**
```bash
ls "<Forever folder>/Data"
```
You should see `data/` (the actual content archives, `data.###` and `.idx` files) and `config/`
(content-addressed config files, two levels of hash-prefix directories).

**The useful check:** the build config file's *name* should be the Build Key from `.build.info`, and its
*content hash* should equal that name (CASC is content-addressed). Using the Build Key you found in Step 1:

**Windows:**
```powershell
$key = "<Build Key from .build.info>"
$p1, $p2 = $key.Substring(0,2), $key.Substring(2,2)
$cfgPath = "<Forever folder>\Data\config\$p1\$p2\$key"
Test-Path $cfgPath
Get-FileHash $cfgPath -Algorithm MD5
Get-Content $cfgPath | Select-String "^root|^encoding|^build-name"
```
**macOS:**
```bash
key="<Build Key from .build.info>"
p1=${key:0:2}; p2=${key:2:2}
cfg="<Forever folder>/Data/config/$p1/$p2/$key"
ls -la "$cfg"
md5 "$cfg"
grep -E "^root|^encoding|^build-name" "$cfg"
```
If the MD5 equals the Build Key, that's a genuine internal-consistency check: the locally installed
files actually match what `.build.info` claims, independent of trusting the agent's cache blindly. If it
does *not* match, stop and tell me — that would mean something is stale or wrong, and we shouldn't
proceed on the assumption the build is what we think it is.

**Evidence level:** `[V]` if the hash check passes — this is you, on your own machine, verifying content
addressing yourself. Still doesn't prove Blizzard's server agrees; it proves internal consistency of your
local install.

---

## Steps 5–7 — table existence and QuestV2 extraction

This needs a small Go program, `db2tool`, from the `wowsims/mop` repository (MIT license). I read its
actual source before recommending it — not just its README — so what follows matches real behavior,
including its exact error messages, not documentation guesses.

### 5a. Install Go

Download Go 1.25+ from https://go.dev/dl/ if you don't have it. Verify with `go version`.

### 5b. Get the tool at a pinned commit

```
git clone https://github.com/wowsims/mop.git
cd mop
git fetch --depth 1 origin adbbb9824059712ed299bc89ec1b3b08c1f28a97
```
**Stop here and tell me the result of that fetch.** That's the full hash of the exact commit I read
source from (`git log -1` on it prints "Merge pull request #1586…", dated 2026-09-21). If it doesn't
resolve (repos get rewritten), run `git log --oneline -5` on whatever HEAD you get instead and tell me
the commit and date, so I record exactly what ran rather than silently trusting "latest".
```
git checkout FETCH_HEAD    # only after the fetch above succeeds
```

### 5c. Pin the DBD definitions (not the tool's default, which follows `master`)

```
git clone https://github.com/wowdev/WoWDBDefs.git ../WoWDBDefs-pinned
cd ../WoWDBDefs-pinned
git fetch --depth 1 origin 02b1fa9a4714fa41adbbd600304f0449d0b58146
git checkout FETCH_HEAD
cd ../mop
mkdir -p tools/db2tool/DBDCache
```
**Windows:**
```powershell
Copy-Item ..\WoWDBDefs-pinned\definitions\QuestV2.dbd tools\db2tool\DBDCache\
(Get-Item tools\db2tool\DBDCache\QuestV2.dbd).LastWriteTime = Get-Date
```
**macOS:**
```bash
cp ../WoWDBDefs-pinned/definitions/QuestV2.dbd tools/db2tool/DBDCache/
touch tools/db2tool/DBDCache/QuestV2.dbd
```
This matters: `db2tool` re-fetches a `.dbd` from `WoWDBDefs@master` (unpinned) whenever its cached copy
is more than 24 hours old. Copying our pinned commit's file in and touching its timestamp makes the tool
see it as fresh and use exactly that version instead of whatever `master` has moved to.

The listfile (which maps table names to internal file IDs) is a separate, ~150MB download from
`wow-listfile`'s latest GitHub release, and `db2tool` does **not** offer a way to pin its version — this
is a disclosed limitation, not something I'm hiding. Record its hash after it downloads (Step 5d shows
where) so the exact version used is at least on record for later reproduction.

### 5d. One settings file per table, one run per table

Don't list all 15 tables in one settings file — I checked the source, and `db2tool` stops at the *first*
table that fails, so a combined run would silently never attempt anything after the first missing table.
Running one table at a time gives a clean, honest result for each.

Create `tools/db2tool/m2-settings.json` (edit `Product` and `BaseDir` first — `Product` is the exact
string from your `.build.info`, `BaseDir` is `<your WoW root>` from Step 0, **not** the Forever
subfolder):

```json
{
  "Settings": {
    "Product": "<Product from .build.info>",
    "BaseDir": "<your WoW root>"
  },
  "Tables": ["QuestV2"]
}
```

Run it from the `mop` repo root:
```
go run ./tools/db2tool --settings tools/db2tool/m2-settings.json --output m2-test.db --no-hotfixes
```

Then edit just the `"Tables"` line to the next name (`["QuestPOIBlob"]`, then `["QuestPOIPoint"]`, …) and
re-run, once per table in this list:

```
QuestV2, QuestPOIBlob, QuestPOIPoint, QuestObjective, QuestV2CliTask, QuestLabel, QuestLine,
QuestLineXQuest, QuestHub, QuestPackageItem, QuestFactionReward, QuestMoneyReward, QuestSort,
TaxiPathNode, Creature
```

**Read the output for each run and classify it — paste me the exact text, don't summarize:**

| What you see | Meaning | Record as |
|---|---|---|
| `Extracting <product> <version> (build <n>) from local install` then `Processing completed.` | The table exists, was read from your client, decoded, and written to `tools/db2tool/dbfilesclient/<Table>.db2` | `exists_extracted` |
| Same start, but an error mentioning `.dbd definition` / `WoWDBDefs may not contain this build yet` | **The raw file was still written** before this error — check `tools/db2tool/dbfilesclient/<Table>.db2` anyway | `exists_but_decode_failed` |
| Error containing `fdid ... not found in root` | The name is known, but this build's file manifest doesn't have it | `fdid_not_in_root` |
| Error containing `not found in static FDID map or listfile` | The name isn't in the tool's list at all | `not_in_listfile` |

This directly answers Step 5 for all 15 tables, and Step 6 (QuestV2 only) happens as the first run in
this same sequence — nothing beyond QuestV2's raw bytes gets deeply analyzed; the other 14 only get this
pass/fail signal and, incidentally, a locally-kept raw copy if they resolved (never sent to me, never
committed anywhere).

Paste me, for every table: the outcome line, and whether `tools/db2tool/dbfilesclient/<Table>.db2` exists
on disk afterward (`Test-Path` on Windows, `ls` on macOS) regardless of what the console said.

### 5e. If a table's raw bytes exist but the DBD decode failed

That's fine — the file is still real. Just run it through `verify_db2_header.py` (Step 7) directly; that
script doesn't need the DBD at all, only the file's own self-describing header.

---

## Step 7 — verify QuestV2's format, hash, and layout

```
python verify_db2_header.py "<mop repo path>/tools/db2tool/dbfilesclient/QuestV2.db2"
```
Paste me the full JSON it prints. It reports: magic, schema string, header record count, table hash,
layout hash (cross-checked against `1854BDB9`, the value in the pinned QuestV2 definition), section
count, total records across sections, and how many sections are encrypted (a section is encrypted if it
declares a nonzero `TactKeyLookup` — the script reports this by inspecting the header, and does not
attempt to decrypt anything).

If `db2tool` printed a row count too (from `Processing completed.` reaching the SQLite insert stage),
tell me that number as well — two independent code paths (Go decoder, my Python header parser) agreeing
is real cross-verification.

If `encrypted_sections > 0`, stop there for that table. We are not loading TACT keys unless you
explicitly say otherwise, per the constraint you set.

---

## What I'll do once I have your answers

Fill in `m2_attestation.json` field by field from exactly what you report — nothing inferred, nothing
carried over from the earlier research assumptions. Every field keeps whichever tag (`[V]`, `[2nd]`,
`[?]`) actually applies once we have a real answer, and anything that still doesn't resolve gets listed
under `unverified_claims` rather than papered over.

Nothing in this process writes to, deletes from, or reads from your live game installation beyond the
plain file reads above — no writes, no addon, no modified files.
