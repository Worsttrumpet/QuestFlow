# questflow

The Quest Flow addon and everything used to build, test and package it. The project overview, installation and usage are in the [repository README](../README.md).

```
QuestFlow/        the addon (this folder is what a player installs, into Interface\\AddOns\\)
generator/        data-pack generator, release packager (package_addon.py) and their tests
tests/            Lua 5.1 stub-client tests:   lua5.1 run_codex_tests.lua ../QuestFlow
docs/             design notes, data sources and licences, release process (RELEASING.md)
dist/             the current release candidate ZIP (built by generator/package_addon.py); older builds are not kept
```

Start with `docs/CODEX_ARCHITECTURE.md` (how it fits together), `docs/CODEX_DATA_SOURCES.md` (where data comes from, licences) and `docs/RELEASING.md` (how a release is built).

**A note on names.** Quest Flow was developed under the working name *Forever Codex*. The design and development notes in `docs/` (`CODEX_*.md`) and many source comments keep that name because they are history. Some internal identifiers keep it too, on purpose, so nothing breaks: the global `ForeverCodex`, the saved variable `ForeverCodexDB`, internal frame names, the party-message prefix, and the data tag `CODEX_OBSERVED`.
