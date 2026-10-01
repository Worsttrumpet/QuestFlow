# Forever DB — M8 files, organized (2026-09-30)

Every file here is the **final, canonical** version. Stale drafts are isolated in `superseded/`.

## Folders

| Folder | What it is | Where it goes in your project |
|---|---|---|
| `forever-db/docs/` | Every milestone scope, report, and design doc (canonical copies) | `forever-db/docs/` |
| `probes/` | Disposable probe packages: addon, self-test, operator guide, their own docs copy | Project root, beside the `m3-`/`m4-` probe folders |
| `releases/ForeverQuestGuide-0.6/` | The validated, frozen v0.6 addon (M8.6-B) | Your ForeverQuestGuide source / `AddOns` install |
| `evidence/` | Raw SavedVariables for M8.7–M8.9, kept outside the locked packages so they stay byte-identical | Keep with the matching probe folder |
| `superseded/` | Earlier drafts replaced by the canonical versions | Safe to delete once you've checked nothing else points at them |

M8.10's raw evidence is already inside its package (`probes/m8-10-travel-arrival-probe/evidence/`).

## Milestone index

| Milestone | Status | Docs in `forever-db/docs/` | Package | Raw evidence |
|---|---|---|---|---|
| M8.6-B Show on Map | Complete and locked | `M8_6_B_COMPLETION_REPORT.md`, `M8_6_B_REAL_CLIENT_VALIDATION.md` | `releases/ForeverQuestGuide-0.6/` | — (screenshots) |
| M8.7 QUEST_ACCEPTED | Complete and locked — PASS | `M8_7_SCOPE.md`, `M8_7_COMPLETION_REPORT.md` | `probes/m8-7-quest-accepted-probe/` | `evidence/M8_7/` |
| M8.8 QUEST_TURNED_IN | Complete and locked — PASS | `M8_8_SCOPE.md`, `M8_8_COMPLETION_REPORT.md` | `probes/m8-8-quest-turned-in-probe/` | `evidence/M8_8/` |
| M8.9 Objective progress | Complete and locked — detection PASS; ordering open | `M8_9_SCOPE.md`, `M8_9_COMPLETION_REPORT.md` | `probes/m8-9-objective-progress-probe/` | `evidence/M8_9/` |
| M8.10 TRAVEL / arrival | Complete and locked — PASS | `M8_10_SCOPE.md`, `M8_10_COMPLETION_REPORT.md` | `probes/m8-10-travel-arrival-probe/` | inside package |
| M8.11 Progression design | Complete (design only) | `M8_11_SCOPE.md`, `M8_11_COMPLETION_REPORT.md`, `PROGRESSION_DESIGN.md` | — (docs only) | — |
| M8.12 Startup-state probe | **In progress — awaiting real-client test** | `M8_12_SCOPE.md` | `probes/m8-12-startup-state-probe/` | pending |

## Raw evidence checksums (SHA-256)

```
d9f64900d3e1e978b359df0c6f7ad97ce2501aeea01716c99f7386a47747c0e8  evidence/M8_7/ForeverProbeM87.lua
7303bc22f46114f47fb5aa846d295174b9c14f061e4d9906c51b1c996fb9509a  evidence/M8_8/ForeverProbeM88.lua
13ba808c2370f0b97f128e8e0f3dd9a814c8e8f2c7c198fe97e0e122d3d49513  evidence/M8_9/ForeverProbeM89.lua
f65c8fbda3a2c6b33fd37ab6b1e9002268134fbf58869dc63e6fcd1e2f6e5a48  probes/m8-10-travel-arrival-probe/evidence/ForeverProbeM810.lua
```

## What's in `superseded/` and why

| File | Replaced by |
|---|---|
| `M8_8_COMPLETION_REPORT.PENDING_DRAFT.md` | `M8_8_COMPLETION_REPORT.md` (locked) |
| `M8_9_COMPLETION_REPORT.PENDING_DRAFT.md` | `M8_9_COMPLETION_REPORT.md` (locked) |
| `M8_10_COMPLETION_REPORT.PENDING_DRAFT.md` | `M8_10_COMPLETION_REPORT.md` (locked) |
| `M8_10_SCOPE.PRE_LOCK.md` | `M8_10_SCOPE.md` (status line updated at lock) |
| `M8_6_B_REAL_CLIENT_VALIDATION.DRAFT_misnamed_M8_7.md` | `M8_6_B_REAL_CLIENT_VALIDATION.md` (was saved as `M8_7_REAL_CLIENT_VALIDATION.md` before the M8.6-B name was settled) |
| `M8_6_B_COMPLETION_REPORT.DRAFT_misnamed_M8_7.md` | `M8_6_B_COMPLETION_REPORT.md` (was saved as `M8_7_MAP_PIN_NOTE.md`) |

Dropped entirely: `M8_12_GUIDE (1).md` (byte-identical duplicate) and five empty placeholder uploads.

## Known, deliberately unfixed inconsistencies

- `M8_7_SCOPE.md`, `M8_8_SCOPE.md`, `M8_9_SCOPE.md` still open with "awaiting real-client test". Their milestones
  are locked and were not edited; the completion reports carry the final status.
- ForeverQuestGuide v0.6 code comments call the map-pin work "M8.7" (it is M8.6-B). Left as-is so the shipped
  files stay identical to the validated build.
