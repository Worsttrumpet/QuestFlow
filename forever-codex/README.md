# Forever Codex

A dynamic, character-aware progression companion for WoW Classic Forever (0.1 "First Light", local dev build).
See `docs/CODEX_ARCHITECTURE.md`, `docs/CODEX_PROVENANCE_DECISION.md` and `docs/CODEX_TEST_GUIDE.md`.

```
ForeverCodex/     the addon (copy this folder to Interface\AddOns\)
generator/        deterministic data-pack generator + tests (reads the local ATT snapshot and the M8.13 observed table)
tests/            Lua 5.1 stub-client tests:   lua5.1 run_codex_tests.lua ../ForeverCodex ../../m8-13-progression/ForeverQuestGuide
docs/             architecture, provenance decision, real-client test guide
dist/             packaged addon zip for testers (built by generator/package_addon.py)
```
