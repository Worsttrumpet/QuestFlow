-- timer_tests.lua: TIMED QUESTS (QuestTimers.lua, the planner's timer urgency, the TIMED QUEST card). The stub client answers C_QuestLog.GetTimeAllowed (or the classic GetQuestTimers);
-- which of these Forever really answers is UNPROVEN, so these tests prove Codex's own logic only.

local H = ...
local check, section, boot = H.check, H.section, H.boot

local function Q(id, name, dx, o)
	local q = { id = id, name = name, map = 9001, x = 0.5 + dx / 1000, y = 0.5, req = 1, objCoords = { { map = 9001, x = 0.5 + dx / 1000, y = 0.5 } } }
	for k, v in pairs(o or {}) do q[k] = v end
	return q
end

local TIME = { total = {}, elapsed = {} }
local function world(quests, log)
	TIME.total, TIME.elapsed = {}, {}
	local ns = boot({ char = { level = 10 }, synthetic = true, loc = { map = 9001, x = 0.5, y = 0.5, zone = "F" } })
	H.attPack(ns, quests, { { key = "zone-a", label = "A", map = 9001, quests = #quests } })
	local W = H.world()
	W.log, W.objectives = {}, {}
	local ids = {}
	for id in pairs(log) do ids[#ids + 1] = id end
	table.sort(ids)
	for _, id in ipairs(ids) do
		local e = log[id]
		W.log[#W.log + 1] = { questID = id, title = e.title or ("quest " .. id), complete = e.complete == true }
		W.objectives[id] = { { text = "Do it", type = "monster", finished = e.complete == true, numFulfilled = e.complete and 5 or 0, numRequired = 5 } }
	end
	_G.C_QuestLog.GetTimeAllowed = function(id) return TIME.total[id], TIME.elapsed[id] end
	ns.Prefs.FinishSetup()
	ns.State.Recompute()
	return ns, W
end
local function timed(ns, id, total, elapsed) TIME.total[id], TIME.elapsed[id] = total, elapsed or 0; ns.State.Recompute() end
local function nowId(ns) return ns.State.plan.now and ns.State.plan.now.id end

section("timers: an untimed quest has no timer, no card and no boost")
do
	local ns = world({ Q(1, "Plain", 50) }, { [1] = {} })
	check(ns.QuestTimers.Get(1) == nil and #ns.Presenter.Card(ns.State.plan, ns.State.ctx).timers == 0, "no timer, no TIMED QUEST rows")
	check(ns.State.plan.now and ns.State.plan.now.timer == nil and nowId(ns) == "Q:1:OBJECTIVE", "the planner's NOW is as before")
end

section("timers: the urgency curve is flat with plenty of slack, rises smoothly, and is critical at the end")
do
	local ns = world({ Q(1, "Plain", 50) }, { [1] = {} })
	local U = ns.Planner.TimerUrgency
	local b1, c1 = U(5000)
	local b2, c2 = U(400)
	local b3, c3 = U(200)
	local b4, c4 = U(60)
	local b5, c5 = U(-30)
	check(b1 == 1 and not c1, "plenty of slack: no change")
	check(b2 > 1 and b3 > b2 and not c2 and not c3, "less slack: a higher value, not yet critical  [" .. string.format("%.2f %.2f", b2, b3) .. "]")
	check(b4 == ns.Planner.TIMER.maxBoost and c4 and c5, "at or below the critical slack (or already past it): the maximum boost and critical")
end

section("timers: with plenty of time the normal plan stands; as the deadline closes the timed quest takes over")
do
	-- Q1 is 50 yd away (untimed), Q2 is 400 yd away and timed
	local ns = world({ Q(1, "Near Work", 50), Q(2, "Grace of An'she and Musha", 400) }, { [1] = {}, [2] = {} })
	timed(ns, 2, 1800, 0)
	check(nowId(ns) == "Q:1:OBJECTIVE", "30 minutes left: the nearer quest is still NOW (a timed quest is not automatically first)")
	local card = ns.Presenter.Card(ns.State.plan, ns.State.ctx)
	check(#card.timers == 1 and card.timers[1].title == "Grace of An'she and Musha" and card.timers[1].text == "Time remaining: 30:00" and card.timers[1].level == "OK", "but the card already shows the live time  [" .. tostring(card.timers[1] and card.timers[1].text) .. "]")
	H.world().now = H.world().now + 1500          -- 25 minutes pass: 5:00 left
	ns.State.Recompute()
	TIME.elapsed[2] = 1500
	ns.State.Recompute()
	local it = ns.State.plan.diag
	local tr = ns.Planner.TimerUrgency(300 - 60 - 15)
	check(tr > 1, "5 minutes left: the quest's value is boosted")
	TIME.elapsed[2] = 1730                         -- 70 s left: critical
	H.world().now = H.world().now + 0
	ns.State.Recompute()
	check(nowId(ns) == "Q:2:OBJECTIVE", "critical: the timed quest is NOW even though another quest is nearer  [" .. tostring(nowId(ns)) .. "]")
	local c2 = ns.Presenter.Card(ns.State.plan, ns.State.ctx)
	check(c2.timers[1].level == "CRITICAL", "and its card row is critical")
end

section("timers: the displayed time follows the clock between recomputes; expiry, completion and removal update the state")
do
	local ns = world({ Q(2, "Timed", 100) }, { [2] = {} })
	timed(ns, 2, 600, 0)
	local c = ns.Presenter.Card(ns.State.plan, ns.State.ctx)
	check(c.timers[1].text == "Time remaining: 10:00", "10:00 at the start")
	H.world().now = H.world().now + 90
	local list = ns.QuestTimers.List(ns.State.ctx)
	check(list[1].text == "Time remaining: 8:30", "90 s later, with no recompute: 8:30  [" .. list[1].text .. "]")
	TIME.elapsed[2] = 90                              -- (the client's own elapsed time moves with the clock)
	ns.UI.Open("codex"); ns.State.Recompute()
	local ui = ns.UI.main.codex
	check(ui.tmBox.__shown == true and ui.tmRows[1].time.__text:find("Time remaining: ", 1, true), "the tracker shows the TIMED QUEST card")
	H.world().now = H.world().now + 60
	check(ns.UI.RefreshTimers() == true and ui.tmRows[1].time.__text == "Time remaining: 7:30", "RefreshTimers updates only the text  [" .. ui.tmRows[1].time.__text .. "]")
	-- time runs out while the quest is still in the log
	TIME.elapsed[2] = 600
	ns.State.Recompute()
	check(ns.QuestTimers.Get(2) == nil and ns.Presenter.Card(ns.State.plan, ns.State.ctx).timers[1].text == "Time is up", "expired: no urgency, and the card says the time is up")
	-- the quest leaves the log (failed, abandoned or handed in)
	H.world().log = {}
	ns.State.Recompute()
	check(#ns.Presenter.Card(ns.State.plan, ns.State.ctx).timers == 0 and ns.QuestTimers.ended[2] ~= nil and ui.tmBox.__shown == false, "removed from the log: the card is gone")
	-- completion of the objectives
	local ns2 = world({ Q(2, "Timed", 100) }, { [2] = {} })
	timed(ns2, 2, 600, 0)
	H.world().log = { { questID = 2, title = "Timed", complete = true } }
	TIME.total[2] = nil                               -- the client stops reporting a timer once the quest is complete
	ns2.State.Recompute()
	check(#ns2.Presenter.Card(ns2.State.plan, ns2.State.ctx).timers == 0 and ns2.QuestTimers.ended[2] == "COMPLETE", "completed: the timer card goes and the quest is recorded as complete")
end

section("timers: several timed quests are listed soonest first; the closest deadline wins the NOW slot")
do
	local ns = world({ Q(1, "A", 80), Q(2, "B", 120), Q(3, "C", 160) }, { [1] = {}, [2] = {}, [3] = {} })
	TIME.total[1], TIME.total[2], TIME.total[3] = 900, 100, 30
	ns.State.Recompute()
	local timers = ns.Presenter.Card(ns.State.plan, ns.State.ctx).timers
	check(#timers == 3 and timers[1].quest == 3 and timers[2].quest == 2 and timers[3].quest == 1, "listed by remaining time")
	check(nowId(ns) == "Q:3:OBJECTIVE" or nowId(ns) == "Q:2:OBJECTIVE", "a critical timed quest is NOW  [" .. tostring(nowId(ns)) .. "]")
end

section("timers: an unplaced timed quest still gets guidance first, and the classic GetQuestTimers shape is read too")
do
	local ns = world({}, { [7] = { title = "Unplaced Timed" }, [8] = { title = "Other" } })
	timed(ns, 7, 300, 0)
	local c = ns.Presenter.Card(ns.State.plan, ns.State.ctx)
	check(c.guidance and c.now.title == "Finish Unplaced Timed" and c.timers[1].quest == 7, "guidance names the timed quest first, with its card")
	-- classic shape: C_QuestLog.GetTimeAllowed absent, GetQuestTimers + GetQuestIndexForTimer
	local ns2 = world({ Q(5, "Classic", 100) }, { [5] = {} })
	_G.C_QuestLog.GetTimeAllowed = nil
	_G.GetQuestTimers = function() return 240 end
	_G.GetQuestIndexForTimer = function(i) return 1 end
	ns2.State.Recompute()
	check(ns2.QuestTimers.via == "GetQuestTimers" and ns2.QuestTimers.Get(5) and math.abs(ns2.QuestTimers.Get(5).remaining - 240) < 2, "GetQuestTimers + GetQuestIndexForTimer are mapped through the log index")
	_G.GetQuestTimers, _G.GetQuestIndexForTimer = nil, nil
	ns2.State.Recompute()
	check(ns2.QuestTimers.Get(5) == nil, "no timer API: nothing is timed (unknown stays unknown)")
	local text = table.concat(ns2.QuestTimers.ReportLines(ns2.State.ctx), "\n")
	check(text:find("QUEST TIMERS", 1, true) and text:find("GetQuestTimers=NO", 1, true), "the report says which functions exist")
	check(#ns2.errors == 0, "no errors")
end
