# Releasing a Forever Codex build

Every code change that gets packaged for WoW gets a **new patch version** (`0.2.1`, `0.2.2`, `0.2.3`, ...). A zip name is never reused, so an old build can never be installed by accident.

## Bump and package
1. Set the new version in **both** places (they must match; the packager refuses to run otherwise):
   * `ForeverCodex/ForeverCodex.toc`: `## Version: 0.2.2`
   * `ForeverCodex/Core.lua`: `C.VERSION = "0.2.2"`
2. Run the tests, then package: `python3 forever-codex/generator/package_addon.py`
   -> `forever-codex/dist/ForeverCodex-0.2.2.zip`
3. If `ForeverCodex-<version>.zip` already exists with different contents the packager stops and tells you to bump the version. Older zips in `dist/` are kept.
4. Commit the source, the new zip and (when the test count moved) the regenerated `docs/CODEX_PLANNER_EVAL_REPORT.md` together.

## Install
Unzip `ForeverCodex-<version>.zip` into `World of Warcraft/_classic_/Interface/AddOns/` so you end up with `.../AddOns/ForeverCodex/ForeverCodex.toc`. Replace the old `ForeverCodex` folder; do not merge two builds.

## Check which build is running
* the login line: `Forever Codex v0.2.2 loaded.`
* the window header: `FOREVER CODEX  v0.2.2`
* the minimap button tooltip (top right: `v0.2.2`)
* `/codex diag` (first line)
* the AddOns list (the version column)
