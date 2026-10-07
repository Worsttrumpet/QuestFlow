# forever-codex

The Forever Codex addon and everything used to build, test and package it. The project overview, installation and usage are in the [repository README](../README.md).

```
ForeverCodex/     the addon (this folder is what a player installs, into Interface\AddOns\)
generator/        data-pack generator, release packager (package_addon.py) and their tests
tests/            Lua 5.1 stub-client tests:   lua5.1 run_codex_tests.lua ../ForeverCodex
docs/             design notes, data sources and licences, release process (RELEASING.md)
dist/             the current release candidate ZIP (built by generator/package_addon.py); older builds are not kept
```

Start with `docs/CODEX_ARCHITECTURE.md` (how it fits together), `docs/CODEX_DATA_SOURCES.md` (where data comes from, licences) and `docs/RELEASING.md` (how a release is built). The `docs/CODEX_0xx_*.md` files are development notes kept for history.
