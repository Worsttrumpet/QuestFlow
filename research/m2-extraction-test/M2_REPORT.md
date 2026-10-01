# M2.1/M2.2 result: QuestV2 extracted from a real WoW Forever beta client

Session concluded here at operator's instruction. Existence checks for the other 14 requested tables
(`QuestPOIBlob`, `QuestPOIPoint`, `QuestObjective`, `QuestV2CliTask`, `QuestLabel`, `QuestLine`,
`QuestLineXQuest`, `QuestHub`, `QuestPackageItem`, `QuestFactionReward`, `QuestMoneyReward`, `QuestSort`,
`TaxiPathNode`, `Creature`) were **not attempted**. `forever-db/` (M1) and the M1.5 research files were not
touched. Full machine-readable detail is in `M2_ATTESTATION.json`; this is the narrative summary.

Evidence tags: `[V]` directly observed by the operator or independently recomputed here. `[2nd]` reported
elsewhere, not reproduced this session. `[?]` unresolved or uninterpreted.

## 1. This was a real client, not a research artifact

Everything below came from the operator's actual, currently installed WoW Forever beta on their own
machine (`E:\World of Warcraft\_classic_beta_`), read live during this session. Nothing here is carried
over from the earlier M1.5 desk research.

## 2. Client / build identity — five independent things agreeing

| Source | Reads | Tag |
|---|---|---|
| Archived Blizzard CDN record (M1.5 research, `mdX7/ribbit_data`) | BuildConfig `6c0df97e8e481a9a41600e373367c200`, CDNConfig `5525ea1ce6668e895569c89c2d6a154c` for `1.60.1.69913` | `[2nd]` |
| `.build.info` (Battle.net-agent-written cache) | `Build Key 6c0df97e8e481a9a41600e373367c200`, `Version 1.60.1.69913`, `Product wow_classic_beta` | `[V]`, agent-written |
| `WowB.exe` version resource (compiled in by Blizzard) | `FileVersion 1.60.1.69913`, `ProductVersion "Version 1.60.1.69913"` | `[V]` |
| Live `/dump GetBuildInfo()` in-game | `"1.60.1"`, `"69913"`, `"Sep 17 2026"`, interface `16001` | `[V]` |
| Local build-config file content check | file at `Data\config\6c\0d\6c0df97e...` has **MD5 equal to its own filename** (content-addressed, self-verifying), and its `build-name` field reads `WOW-69913patch1.60.1_ForeverBeta` — Blizzard-build-system text | `[V]`, tamper-evident |

All five agree on **1.60.1.69913, wow_classic_beta**. This is the strongest evidence obtainable without a
live query to Blizzard's version service, which was not performed (unreachable from the assistant's
environment; not attempted from the operator's machine either).

Also confirmed along the way, `[V]`: the product folder is `_classic_beta_` (verified via its
`.flavor.info`, not assumed from the folder name), and `Data\` is a single CASC store shared across all
five products on this install, not per-flavor.

## 3. QuestV2.db2 exists and was extracted

Tool: `wowsims/mop`, path `tools/db2tool` (Go, MIT license; third-party components listed in its
`NOTICES.md`), pinned to commit **`adbbb9824059712ed299bc89ec1b3b08c1f28a97`** ("Merge pull request #1586
…", 2026-09-21) — the exact commit whose source was read before recommending the tool, confirmed identical
via `git log -1` on the operator's machine.

Definitions: `wowdev/WoWDBDefs`, pinned to commit **`02b1fa9a4714fa41adbbd600304f0449d0b58146`** ("Merge
1.60.1.69913", tag `202609180304`). `QuestV2.dbd` from this commit was copied into the tool's cache
directory and its timestamp refreshed, so the tool used this exact file instead of its normal
fetch-from-`master` behavior. (A raw SHA-256 comparison between the operator's Windows checkout and an
independent Linux checkout initially looked like a mismatch; both were confirmed identical in content,
differing only by CRLF-vs-LF line endings introduced by Git's per-OS defaults — recorded in the
attestation for anyone who re-derives this later.)

Command run (from the `mop` repository root):
```
go run ./tools/db2tool --settings tools/db2tool/m2-settings.json --output m2-test.db --no-hotfixes
```
with `tools/db2tool/m2-settings.json`:
```json
{
  "Settings": { "Product": "wow_classic_beta", "BaseDir": "E:\\World of Warcraft" },
  "Tables": ["QuestV2"]
}
```
`--no-hotfixes` was passed explicitly: server-side hotfix overlays were **not** applied, so everything
below reflects the base client table only.

Output: `Extracting wow_classic_beta 1.60.1.69913 (build 69913) from local install` then
`Processing completed.` — no errors. `[V]` **QuestV2 is a real DB2 table in this Forever beta build.**

Raw file written to `tools/db2tool/dbfilesclient/QuestV2.db2`:
- Size: **34,228 bytes**
- SHA-256: **`3bea59629dbd6e7bf30c59ded4abcb18b2213263db34f9798b7aa39c173d19c0`**
  — computed twice, independently, and confirmed identical both times: once by PowerShell's
  `Get-FileHash` right after extraction, and again inside the from-scratch header-verification program
  below when it read the same file. `[V]`

No TACT keys were loaded at any point. `[V]`, confirmed by the operator's own command history — nothing in
this session requested or configured key material.

## 4. Header verification — independent of the extraction tool

A small program (`m2verify_main.go`, plain Go standard library, no dependencies) was written to parse the
file's WDC5 container header from scratch — a second, independent implementation, not a reuse of
`db2tool`'s own parsing code. It was compiled and tested against a synthetic file before being handed to
the operator; that testing caught and fixed one real bug (a wrong byte offset that would have silently
reported zero sections) prior to running it on real data.

Run against the real `QuestV2.db2`:

| Field | Value | Note |
|---|---|---|
| Magic | `WDC5` | `[V]` |
| Schema string | `WOWSTATIC_1_60_1_69800` | `[V]` observed verbatim. `[?]` meaning — **not** confirmed to be the running build (see §6) |
| Layout hash | `1854BDB9` | `[V]` — matches exactly what the pinned WoWDBDefs commit declares for QuestV2 at builds 69876/69893/69913 |
| Header record count | **6,690** | `[V]` |
| Sections | 3 | `[V]` |

| Section | Records | Encrypted |
|---|---|---|
| 0 | **6,600** | No |
| 1 | 11 | **Yes** |
| 2 | 79 | **Yes** |

Sum of section records (6,600 + 11 + 79 = 6,690) matches the header's own declared total exactly —
internally self-consistent. `[V]`

Both independent decoders agree the file is well-formed and matches the expected layout: `db2tool`'s own
Go decoder completed without error using the per-build field definition, and this from-scratch header
parser confirms the same layout hash from the raw bytes directly.

## 5. What this changes about the earlier (M1.5) research

The M1.5 research (ForeverDiff, and lodestar's separately-sourced notes — both `[2nd]`, neither reproduced
until now) reported QuestV2 at **6,600 rows**. That number matches **section 0 exactly** — the unencrypted
portion. This client's own header shows **90 additional records** (11 + 79) sitting inside two encrypted
sections that neither of those earlier sources appears to have surfaced.

**This is not a claim that 90 new quests were discovered.** What was found is **90 encrypted QuestV2
records** — rows that exist in the table's header accounting but whose content cannot be read without
TACT decryption keys, which were not used. Their contents, purpose, and even whether they represent quests
in any meaningful sense are entirely unknown from this evidence. It's equally possible they're placeholder
IDs, unreleased content, or something else — nothing here distinguishes those possibilities.

## 6. What this does NOT establish

- **Not quest content.** QuestV2 at this layout is a 3-field ID/existence table (`ID`, `UniqueBitFlag`,
  `UiQuestDetailsThemeID`) per the pinned definition. Nothing here reads or claims to know any quest's
  title, objectives, rewards, giver, or prerequisites.
- **Not "obtainable quest" evidence.** As M0/M1 already established, QuestV2 membership is an observed
  client ID, not proof a quest is reachable in-game.
- **Not a live Blizzard confirmation.** The five-way agreement in §2 is the strongest local/archival
  evidence achievable; it is still not equivalent to Blizzard's version service confirming the build
  directly, which was not queried.
- **Not an interpretation of the `69800` schema string.** Recorded verbatim; not claimed to be the build
  that "originated" this table.
- **Not an existence answer for the other 14 tables.** That check was explicitly not run this session.

## Files touched this session

Created/updated, all under `m2-extraction-test/` (nothing under `forever-db/`):
- `M2_ATTESTATION.json` — full machine-readable record, finalized
- `M2_REPORT.md` — this file
- `M2_FINDINGS.md` — one-paragraph summary
- `m2verify_main.go` — the header-verification program (already delivered and run earlier)
- `verify_db2_header.py` — the Python equivalent (delivered, not needed since Go was already available)
- `M2_GUIDE.md` — the step-by-step guide used to reach this point (unchanged from earlier in the session)

On the operator's own machine (not sent to or retained by the assistant): the `mop` and `WoWDBDefs`
clones, `m2-test.db`, and `tools/db2tool/dbfilesclient/QuestV2.db2`.
