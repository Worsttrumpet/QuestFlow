-- recompute_tests.lua (audit hardening): the first scan is spread across frames, and an idle open window does not recompute. The plan a warmed-up login produces is the plan a synchronous one produces.

local H = ...
local check, section, boot = H.check, H.section, H.boot

local HERE = { map = 9001, x = 0.5, y = 0.5, zone = "Fixture" }
local function world()
	return boot({ char = { level = 10, class = "Rogue", classToken = "ROGUE" }, synthetic = true, loc = HERE, keepWarmup = true })
end

local function bigPack(ns, n)
	-- n synthetic quests: a real pickup near the player plus filler that is not for this character (a required level far above 10)
	local quests = { { id = 1, name = "Near Pickup", map = 9001, x = 0.52, y = 0.5, req = 5, giverNpc = 7001, giverName = "Hub Giver" } }
	for i = 2, n do quests[i] = { id = i, name = "Filler " .. i, map = 9001, x = 0.9, y = 0.9, req = 55, giverNpc = 8000 + i, giverName = "Far " .. i } end
	H.attPack(ns, quests, { { key = "zone-a", label = "A", map = 9001, quests = n } })
	local W = H.world()
	W.log, W.objectives = {}, {}
	return quests
end

section("warm-up: a large data set is warmed a few frames at a time; the window says it is gathering; the plan is the same as a synchronous login's")
do
	local ns = world()
	bigPack(ns, 1500)
	ns.Prefs.FinishSetup()
	local S = ns.State
	local before = S.computeCount
	S.plan = nil
	S.BeginLogin()
	check(S.warmup.state == "running" and S.plan == nil and S.ctx ~= nil and S.computeCount == before, "login with 1,500 quests: warming up, no plan yet, the context is already there (no recompute was paid in the login frame)")
	local card = ns.Presenter.Card(S.plan, S.ctx)
	check(card.now == nil and card.empty and card.empty.title == "Gathering information...", "the window says it is gathering information, not that there is nothing to do")
	S.MarkDirty("QUEST_LOG_UPDATE")
	S.Tick(0.5)
	check(S.warmup.state == "running" and S.computeCount == before, "an event during the warm-up does not trigger a recompute")
	local frames = 0
	while S.warmup.state == "running" and frames < 1000 do S.Tick(0.016); frames = frames + 1 end
	check(S.warmup.state == "done" and S.warmup.frames > 1, "the scan finished over several frames  [" .. frames .. " frames]")
	check(S.computeCount == before + 1 and S.plan ~= nil and S.plan.now ~= nil, "exactly one recompute ran at the end, and there is a plan")
	local warmNow = S.plan.now.id
	-- the same data, a plain synchronous first recompute
	local ns2 = world()
	bigPack(ns2, 1500)
	ns2.Prefs.FinishSetup()
	ns2.State.Recompute()
	check(ns2.State.plan.now.id == warmNow and warmNow == "Q:1:ACCEPT", "the plan is identical to a synchronous one: NOW is the same  [" .. tostring(warmNow) .. "]")
	local sameCount = #ns2.State.plan.sequence == #S.plan.sequence
	check(sameCount, "and so is the length of the route")
	check(#ns.errors == 0 and #ns2.errors == 0, "no errors")
end

section("warm-up: someone who needs the plan now (a command, the window opening) gets it at once; small data sets never warm up")
do
	local ns = world()
	bigPack(ns, 1200)
	ns.Prefs.FinishSetup()
	local S = ns.State
	S.BeginLogin()
	check(S.warmup.state == "running", "(setup) warming")
	S.Recompute()
	check(S.warmup.state == "done" and S.warmup.early == true and S.plan ~= nil, "an explicit recompute finishes the warm-up (the cost is paid there, nothing waits)")
	local small = world()
	bigPack(small, 40)
	small.State.BeginLogin()
	check(small.State.warmup.state == "skipped" and small.State.plan ~= nil, "a small data set is recomputed at once, synchronously")
end

section("idle: with the window open and nothing changed the periodic refresh is skipped; movement, an event, a timed quest or a closed window behave as they should")
do
	local ns = world()
	bigPack(ns, 60)
	ns.Prefs.FinishSetup()
	ns.State.Recompute()
	ns.UI.Open("codex")
	local S = ns.State
	S.Tick(0.5)                                                   -- (settle: the window opening may have marked something dirty)
	local c = S.computeCount
	for _ = 1, 5 do S.Tick(3.1) end
	check(S.computeCount == c and (S.perf.skippedIdle or 0) >= 4, "five idle periods, window open, standing still: no recompute  [" .. S.computeCount - c .. "]")
	H.world().loc.x = H.world().loc.x + 0.001                     -- a few yards: not enough to change anything
	S.Tick(3.1)
	check(S.computeCount == c, "a few yards of movement does not recompute")
	H.world().loc.x = H.world().loc.x + 0.05                      -- well over the threshold
	S.Tick(3.1)
	check(S.computeCount == c + 1, "real movement does")
	S.MarkDirty("QUEST_LOG_UPDATE")
	S.Tick(0.5)
	check(S.computeCount == c + 2, "an event still recomputes (after its short delay)")
	H.world().loc.map = 9002
	S.Tick(3.1)
	check(S.computeCount == c + 3, "a change of map recomputes")
	ns.UI.frame:Hide(); if ns.UI.options then ns.UI.options:Hide() end
	local c2 = S.computeCount
	H.world().loc.x = H.world().loc.x + 0.2
	S.Tick(30)
	check(S.computeCount == c2, "a closed window never refreshes just because the player moved (as before)")
	check(#ns.errors == 0, "no errors")
end
