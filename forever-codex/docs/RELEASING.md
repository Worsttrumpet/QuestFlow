# Releasing a Forever Codex build

Every code change that gets packaged for WoW gets a **new patch version** (`0.2.1`, `0.2.2`, `0.2.3`, ...). The patch number only runs 0-9: after `0.3.9` comes `0.4.0`, after `0.4.9` comes `0.5.0`, and so on. A zip name is never reused, so an old build can never be installed by accident.

## Bump and package
1. Set the new version in **both** places (they must match; the packager refuses to run otherwise):
   * `ForeverCodex/ForeverCodex.toc`: `## Version: 0.2.2`
   * `ForeverCodex/Core.lua`: `C.VERSION = "0.2.2"`
2. Run the tests, then package: `python3 forever-codex/generator/package_addon.py`
   -> `forever-codex/dist/0.2/ForeverCodex-0.2.2.zip` (one folder per minor version: `dist/0.2/`, `dist/0.3/`, `dist/0.4/` ...)
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

## Renumbering note (builds before 0.4.0)
Builds 0.2.10 to 0.2.20 were numbered before the 0-9 rule. In the new numbering they are:

| shipped as | counts as |
|---|---|
| 0.2.10 ... 0.2.19 | 0.3.0 ... 0.3.9 |
| 0.2.20 | 0.4.0 (the build packaged as `ForeverCodex-0.4.0.zip`; there is no 0.2.20 zip) |

The zips for 0.2.10 to 0.2.19 were renamed to `ForeverCodex-0.3.0.zip` ... `ForeverCodex-0.3.9.zip` so `dist/` sorts in release order; they now sit in `dist/0.2/` (0.2.1 to 0.2.9, plus the alpha zip), `dist/0.3/` (0.3.0 to 0.3.9) and `dist/0.4/`. Only the file names changed: a renamed zip's contents still say the old version (for example `ForeverCodex-0.3.5.zip` shows `v0.2.15` in the window). `docs/CODEX_REALCLIENT_FIXES.md` keeps the numbers it was written with.
