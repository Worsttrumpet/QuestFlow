# Contributing to Forever Codex

Thanks for helping. Bug reports with a `/codex report` attached are the most useful contribution.

## Running the tests
You need Lua 5.1 and Python 3.11+ with pytest.

```
cd forever-codex/tests && lua5.1 run_codex_tests.lua ../ForeverCodex      # addon tests (stub client; takes a minute or two)
cd forever-codex/tests && lua5.1 run_planner_eval.lua ../ForeverCodex     # planner evaluation
cd forever-codex && python3 -m pytest -q generator                        # data and packaging tests
cd forever-db && python3 -m pytest -q                                     # dataset tooling
```

## Ground rules
- **Honesty first.** If Codex does not know something, it says so. Do not turn a guess into a route, a location or a recommendation. Facts read from the real Forever client outrank any database, and database facts are labelled unverified.
- **Read-only.** The addon never accepts, completes, turns in, sells or equips anything and uses no protected functions.
- **No new data without a licence.** Do not add data copied from Wowhead, RestedXP, Questie or any source whose licence allows no redistribution. See `forever-codex/docs/CODEX_DATA_SOURCES.md`.
- Keep changes small and add a test when behaviour changes. Real-client behaviour cannot be proven by the stub tests; say what you checked in the game.

## Releases
See `forever-codex/docs/RELEASING.md` (version numbers, packaging, release notes) and `docs/release/`.
