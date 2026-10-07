# Generator inputs

`observed_m6_data.lua` is a byte-for-byte copy (sha256 `636f854c...2d4568d3`) of the observed-quest table that shipped in the M8.13 addon (`m8-13-progression/ForeverQuestGuide/Data.lua`): quests observed on the live Forever
client by ForeverRecorder that passed the M6 readiness rule. It is the input of `build_codex_data.py` for `Data/Pack_Observed.lua` (`src=observed, verified=true`). It lives here so that Codex's generator and tests do not need the legacy
M8.13 addon in the tree. The M8.13 original is frozen and untouched; if this copy ever has to change, that is a data decision to record in `docs/CODEX_OBSERVED_PACK_PROVENANCE.md`, not an edit.
