-- run_planner_eval.lua: ONE command to run every Planner calibration scenario and print the full reports.
--
--     cd forever-codex/tests
--     lua5.1 run_planner_eval.lua ../ForeverCodex ../../m8-13-progression/ForeverQuestGuide
--
-- It runs the normal Codex test harness (so the stub client and every guarantee are the same) in a quiet mode: only
-- failures and the evaluation output are printed. DETERMINISTIC scenarios are asserted; REVIEW scenarios are only
-- reported, because their right answer is a human judgement. Nothing here changes a Planner constant.
PLANNER_EVAL_ONLY = true
PLANNER_EVAL_REPORT = true
local dir = arg[0]:match("^(.*)[/\\]") or "."
dofile(dir .. "/run_codex_tests.lua")
