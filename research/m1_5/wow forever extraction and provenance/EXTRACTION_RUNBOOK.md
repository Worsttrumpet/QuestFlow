# Extraction runbook: first-party QuestV2 from a Forever beta client

**Status: UNTESTED.** Nothing below was run against a real client. The sandbox that produced it had no Forever
client, no route to Blizzard's CDN, and no .NET or Go runtime. Steps are labelled:

- **[V]** the command/parameter exists in source or docs I read
- **[?]** I could not confirm it works for this product/build; try it and record what happens

Do not commit anything this produces except the attestation JSON (step 6) and, if you choose, hashes.
Raw `.db2` and CSV files are Blizzard-derived. See `REPORT.md` section 8 before deciding anything about sharing them.

Time-sensitive: Blizzard says the beta runs **Sept 17 to Oct 21, 2026** (news.blizzard.com article 24304160).
The EULA's beta terms (§1.D.ii.3, "Termination" paragraph) ask you to delete pre-release materials when a test ends.

## 0. Rules for this run

1. Read-only against the game install. Do not modify any client file. Close Battle.net and WoW first (wow.tools.local README [V]).
2. Base tables only on the first pass: `useHotfixes=false`. Hotfixes (`DBCache.bin`) are server-pushed and change over time.
3. Do **not** load TACT keys. Encrypted DB2 sections are counted, not read. (`wowsims/mop` db2tool also skips them [V].)
4. Pin every tool and the definitions to a commit. Record the commits in the attestation.

## 1. Capture identity evidence before touching anything

From the WoW root folder (the folder that holds `.build.info`):

```
sha256sum .build.info > identity.sha256
cp .build.info .build.info.copy
# each product subfolder has .flavor.info naming the TACT product (wowdev.wiki/TACT [2nd])
```

`.build.info` is pipe-delimited with a header row of `Name!TYPE:len` fields. The header row starts with `Branch!` and the columns this project needs are
`Build Key`, `Version`, `Product` [V: these three are what wowsims/mop `tact/buildinfo.go` parses]. Other columns
(e.g. `CDN Key`) are described in wowdev.wiki/TACT [2nd]; record whatever your file contains.

Expected, if this is the current beta build (all **[2nd]**, see `build_identity.json`):

| Field | Expected |
|---|---|
| Product | `wow_classic_beta` |
| Version | `1.60.1.69913` (or 69893 / 69876) |
| Build Key | `6c0df97e8e481a9a41600e373367c200` for 69913 |

**Important:** `.build.info` is written by the Battle.net agent, not the game, and the client trusts it as a cache
(wowdev.wiki/TACT [2nd]). A matching `.build.info` is *not* proof of the build. It is one claim to record.

Stronger checks, in order:

1. **Executable version resource** of `WowB.exe` (the beta executable per a third-party report [2nd]). Record it.
2. **In-game** `/dump GetBuildInfo()` returns version, build, date, interface. Record output [?].
3. **Build config file hash.** If the build config file is stored locally under `Data/config/` (location: verify on
   your machine [?]), its MD5 should equal the `Build Key`. Record the path and hash.
4. **Content keys.** A CASC file's content key is the MD5 of its (decoded) content and is what the build's encoding
   file maps FileDataIDs to [2nd]. Tools in step 3 do this internally; record which file/hash they report.

## 2. Pin the definitions

```
git clone https://github.com/wowdev/WoWDBDefs.git
cd WoWDBDefs && git checkout 02b1fa9a4714fa41adbbd600304f0449d0b58146   # [V] exists: "Merge 1.60.1.69913"
```

At that commit `definitions/QuestV2.dbd` lists `BUILD 1.60.1.69876, 1.60.1.69893, 1.60.1.69913` under
`LAYOUT 1854BDB9` with columns `ID, UniqueBitFlag, UiQuestDetailsThemeID` [V].

Licence note: definitions are CC BY-SA 4.0, code is BSD-3-Clause [V, LICENSE.md].

## 3. Extract with wow.tools.local (primary candidate)

Repo: `Marlamin/wow.tools.local`, MIT, commit `06d1bf9` inspected [V]. Pin a release or commit and record it.

```
wow.tools.local  -wowFolder "<WoW root>" -wowProduct wow_classic_beta \
                 -definitionDir "<path>/WoWDBDefs/definitions" -dbcFolder "./dbcs"
```

- The flags exist [V, README]. That `wow_classic_beta` is accepted as `-wowProduct` is **[?]** (README examples:
  `wow`, `wowt`, `wow_classic`).
- Set `-definitionDir` explicitly. If unset it downloads definitions from GitHub periodically, which is not pinned [V].
- It also fetches a community listfile and TACT keys from GitHub by default [V, SettingsManager.cs]. Point
  `-listfileURL` at a pinned local checkout of `wowdev/wow-listfile` (has no license file [V]). How to *disable*
  key loading is **[?]**: if it cannot be disabled, say so in the attestation.

Then, in a browser or with `curl` against the local server (default `http://localhost:5000`):

```
GET /dbc/export/alltodisk                                   # raw .db2 -> ./dbcs/<BuildName>/dbfilesclient/  [V]
GET /dbc/export/csv?name=QuestV2&build=1.60.1.69913&useHotfixes=false   # CSV [V]
```

Check that `QuestV2.db2` exists in the raw dump. If it does not, that is a **finding**, not an error: record it.

**Alternative:** `wowsims/mop` `tools/db2tool` (MIT, commit `adbbb98`), Go, local CASC mode. It is built for the
wowsims schema (settings file listing tables, SQLite output), so adapting it to dump QuestV2 is **[?]**.
Offline mode: `--build <n> --db2dir <dir> --dbddir <pinned definitions>` [V]. It selects definitions by exact
trailing build number only and fails if the build is not listed [V].

## 4. Verify the file against the definition (independent of build labels)

Read the WDC5 header of the raw `QuestV2.db2` (layout from wowdev.wiki/DB2 [2nd]; offsets tested on a
**synthetic** header only):

```python
import struct, hashlib, sys
b = open(sys.argv[1], "rb").read()
magic, ver = b[:4], struct.unpack_from("<I", b, 4)[0]
schema = b[8:136].rstrip(b"\0")
rec, fld, rsz, strsz, table_hash, layout_hash = struct.unpack_from("<6I", b, 136)
print(dict(magic=magic, ver=ver, schema=schema, record_count=rec,
           table_hash=hex(table_hash), layout_hash=hex(layout_hash),
           sha256=hashlib.sha256(b).hexdigest(), size=len(b)))
```

Expected: `magic == b"WDC5"`, `layout_hash == 0x1854BDB9` (matches the definition block for these builds [V]),
`record_count` near 6600 if ForeverDiff's figure [2nd] is right. A `layout_hash` mismatch means the definition does
not describe the file. Stop and record it. wowsims/mop db2tool deliberately does not check this [V]; this check is ours.

If the header shows encrypted sections, record how many and which record-ID ranges; do not attempt to read them.

## 5. Reproduce

A second person with the same client repeats steps 1-4. Their raw `QuestV2.db2` **SHA-256 must equal yours**.
Matching hashes are the reproducibility claim. Matching CSV text is weaker (CSV depends on the tool version).

## 6. Attestation record (the only artifact intended for the repository)

```json
{
  "attestation_version": 0,
  "operator": "<name or handle>",
  "performed_at": "<UTC time>",
  "client": {
    "install_source": "Battle.net desktop app, Forever beta (In Development)",
    "build_info_sha256": "",
    "product": "", "version": "", "build_key": "", "cdn_key": "",
    "exe_version_resource": "", "getbuildinfo_output": "",
    "build_config_file_md5": "", "build_config_matches_build_key": null
  },
  "tools": {
    "extractor": {"name": "", "repo": "", "commit": "", "license": ""},
    "definitions": {"repo": "wowdev/WoWDBDefs", "commit": "02b1fa9a4714fa41adbbd600304f0449d0b58146"},
    "listfile_commit": "", "tact_keys_loaded": null, "hotfixes_applied": false
  },
  "files": [
    {"path": "dbfilesclient/questv2.db2", "sha256": "", "size": 0,
     "header": {"magic": "WDC5", "table_hash": "", "layout_hash": "", "record_count": 0},
     "definition_layout_expected": "1854BDB9", "layout_matches": null,
     "encrypted_sections": null},
    {"path": "QuestV2.csv (derived)", "sha256": "", "rows": 0}
  ],
  "unverified_claims": ["build label was taken from .build.info (agent-written cache)"],
  "reproduced_by": []
}
```

Rules: never write `"verified"` for a build. Leave build claims listed under `unverified_claims` unless the
Blizzard-confirmation route in `REPORT.md` section 6 was actually completed.

## 7. What to send back (safe to share)

The completed attestation JSON, the `.build.info` (it contains no account data, but check), the header dict from
step 4, and any error messages. Do **not** send raw `.db2` or CSV until the sharing question in `REPORT.md`
section 8 is settled.

## 8. Extra tables worth probing if the client has them

Definitions exist for these (from the executable's metadata, so presence in the client is **[?]**):
`QuestPOIBlob`, `QuestPOIPoint`, `QuestObjective`, `QuestV2CliTask`, `QuestLabel`, `QuestLine`, `QuestLineXQuest`,
`QuestHub`, `QuestPackageItem`, `QuestFactionReward`, `QuestMoneyReward`, `QuestSort`, `TaxiPathNode`, `Creature`.
Record which exist as files in the raw dump. That resolves the open `QuestObjective`/`QuestV2CliTask` conflict.

## 9. Client cache channel (separate from DB2)

lodestar's notes [2nd] say the client writes `Cache/WDB/questcache.wdb` (and `creaturecache.wdb`,
`gameobjectcache.wdb`) from server responses; `RequestLoadQuestByID` triggers the full record. That is a candidate
first-hand channel for quest text and objective target IDs. Record the folder listing and file hashes if present.
Format details (24-byte header, then id + size + payload) are second-hand and unverified [?].
