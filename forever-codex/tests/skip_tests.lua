-- skip_tests.lua (0.8.0): a SKIPPED quest never reaches the planner's actionable output, even when the player had ADDED it first (the real-client bug: Q:98298 was skipped, listed under "skipped by you",
-- and still came back as NOW [BEST_SEQUENCE,PLAYER_ADDED]). The skip check used to come after the "added" (pinned) branch in Providers/Quest.lua and Engine / Planner exempted pinned actions from skipping.

local H = ...
local check, section, boot = H.check, H.section, H.boot

local ID = 98298
local function rec(id, name, x, y, o)
	local q = { id = id, name = name, map = 9001, x = x, y = y, req = 1 }
	for k, v in pairs(o or {}) do q[k] = v end
	return q
end
local function world(db, extra)
	local ns = boot({ char = { level = 10, class = "Hunter", classToken = "HUNTER", name = "Skipper" }, synthetic = true, savedVars = db, loc = { map = 9001, x = 0.5, y = 0.5, zone = "F" } })
	local quests = { rec(ID, "Arugal's Folly", 0.9, 0.5, { giverNpc = 7001, giverName = "Dalar Dawnweaver" }), rec(2, "Nearby Errand", 0.55, 0.5, { giverNpc = 7002, giverName = "Local Giver" }) }
	for _, q in ipairs(extra or {}) do quests[#quests + 1] = q end
	H.attPack(ns, quests, { { key = "zone-a", label = "A", map = 9001, quests = #quests } })
	local W = H.world()
	W.log, W.objectives = {}, {}
	ns.Prefs.FinishSetup()
	return ns, W
end

--- Everything the player can be told to do: true when quest `id` shows up anywhere in the plan's actionable output or in the window's card.
local function appears(ns, id)
	local plan, ctx = ns.State.plan, ns.State.ctx
	local aid, tid = "Q:" .. id .. ":ACCEPT", "T:Q:" .. id .. ":ACCEPT"
	local seen, hit = {}, nil
	local function walk(v, where, depth)
		if hit or depth > 6 then return end
		if type(v) == "string" then
			if v == aid or v == tid then hit = where end
		elseif type(v) == "table" and not seen[v] then
			seen[v] = true
			if v.quest == id and (v.kind == "ACCEPT" or v.verb == "ACCEPT") then hit = where return end
			if v.forId == aid then hit = where return end
			for k, x in pairs(v) do walk(x, where, depth + 1) if hit then return end end
		end
	end
	for _, f in ipairs({ "now", "alsoDo", "thenAction", "next", "sequence", "upcoming", "nearby", "inProgress", "reminders", "turnIns", "objectives", "stops" }) do
		walk(plan and plan[f], "plan." .. f, 0)
		if hit then return hit end
	end
	local card = ns.Presenter.Card(plan, ctx)
	for _, f in ipairs({ "now", "alsoDo", "also", "ready", "reminders", "questItems" }) do
		walk(card[f], "card." .. f, 0)
		if hit then return hit end
	end
	if card.thenLine and card.thenLine:find("Arugal", 1, true) then return "card.thenLine" end
	return nil
end

section("skip: a quest the player ADDED and then SKIPPED (the Q:98298 bug) cannot appear anywhere in the plan or the window")
do
	local ns = world()
	ns.Prefs.Add(ID)
	ns.State.Recompute()
	local p = ns.State.plan
	check(p.now and p.now.id == "Q:" .. ID .. ":ACCEPT" and p.now.pinned == true, "(setup) the added quest is NOW and pinned: this is the PLAYER_ADDED path  [" .. tostring(p.now and p.now.id) .. "]")
	local reasons = {}
	for _, r in ipairs(p.diag.reasons[p.now.id] or {}) do reasons[r.code] = true end
	check(reasons.PLAYER_ADDED == true, "(setup) the planner gave it the PLAYER_ADDED reason")
	-- the Skip button / /codex skip path
	local skipped = ns.State.SkipCurrent()
	check(skipped and skipped.skipKey == "Q:" .. ID, "SkipCurrent skipped it  [" .. tostring(skipped and skipped.skipKey) .. "]")
	check(ns.Prefs.IsSkipped("Q:" .. ID) and not ns.Prefs.IsAdded(ID), "the skip is recorded AND the quest is no longer 'added'")
	ns.State.Recompute()
	check(appears(ns, ID) == nil, "recomputed: the quest is nowhere in the actionable output  [" .. tostring(appears(ns, ID)) .. "]")
	check(ns.State.plan.now and ns.State.plan.now.id == "Q:2:ACCEPT", "the plan carries on with the other quest  [" .. tostring(ns.State.plan.now and ns.State.plan.now.id) .. "]")
	check(((ns.State.plan.stats.filtered or {}).skipped or 0) >= 1, "the funnel ('skipped by you') counts it")
	check(#ns.errors == 0, "no errors")
end

section("skip: a SAVE that has the quest both added and skipped (written by 0.7.9) is resolved the same way, with or without the login clean-up")
do
	local ns = world()
	local c = ns.Prefs.Char()
	c.added[ID] = true                                            -- as an old save could hold it: both flags
	c.skipped["Q:" .. ID] = true
	ns.State.Recompute()
	check(appears(ns, ID) == nil, "even with both flags set (no clean-up yet) the skip wins in the candidate filter")
	check(ns.State.plan.now and ns.State.plan.now.id == "Q:2:ACCEPT", "NOW is the other quest")
	-- the login clean-up
	local db = _G.ForeverCodexDB
	local ns2 = boot({ char = { level = 10, class = "Hunter", classToken = "HUNTER", name = "Skipper" }, synthetic = true, savedVars = db })
	check(ns2.Prefs.IsSkipped("Q:" .. ID) and not ns2.Prefs.IsAdded(ID), "at login the quest leaves 'added' (the skip stays)")
	check(ns2.Prefs.NormalizeOverrides() == 0, "and the clean-up is idempotent")
end

section("skip: the ways back are explicit: /codex unskip, or adding it again")
do
	local ns = world()
	ns.Prefs.Add(ID)
	ns.State.Recompute()
	ns.State.SkipCurrent()
	ns.State.Recompute()
	check(appears(ns, ID) == nil, "(setup) skipped")
	H.slash("unskip")
	ns.State.Recompute()
	local cand
	for _, c in ipairs(ns.Engine.Candidates(ns.Context.Build()).candidates) do if c.id == "Q:" .. ID .. ":ACCEPT" then cand = c end end
	check(cand ~= nil and cand.pinned ~= true and not ns.Prefs.IsAdded(ID), "/codex unskip makes it an ordinary candidate again (not pinned: the skip had undone the add)")
	ns.State.SkipCurrent()
	ns.State.Recompute()
	local skippedNow = ns.Prefs.IsSkipped("Q:" .. ID) or ns.Prefs.IsSkipped("Q:2")
	check(skippedNow, "(setup) something is skipped again")
	ns.Prefs.ClearSkips()
	ns.Prefs.Skip("Q:" .. ID)
	ns.State.Recompute()
	check(appears(ns, ID) == nil, "skipped again: gone")
	H.slash("add " .. ID)
	check(ns.Prefs.IsAdded(ID) and not ns.Prefs.IsSkipped("Q:" .. ID), "/codex add is the explicit way back: it clears the skip and adds it")
	check(appears(ns, ID) ~= nil and ns.State.plan.now and ns.State.plan.now.id == "Q:" .. ID .. ":ACCEPT", "and the quest is NOW again, pinned")
end

section("skip: a plain skip (never added) and a skipped quest that is far away never become a route stop or a TRAVEL step")
do
	local ns = world()
	ns.Prefs.Skip("Q:" .. ID)
	ns.State.Recompute()
	check(appears(ns, ID) == nil, "skipped, never added: absent")
	local legs = 0
	for _, a in ipairs(ns.State.plan.sequence or {}) do if a.forId == "Q:" .. ID .. ":ACCEPT" or a.id == "Q:" .. ID .. ":ACCEPT" then legs = legs + 1 end end
	check(legs == 0, "no leg of the route (including TRAVEL) is for it")
	for _, st in ipairs(ns.State.plan.diag and ns.State.plan.diag.stopIds or {}) do check(st ~= "Q:" .. ID .. ":ACCEPT", "no planner stop is for it") end
	-- the strategies that change what is allowed do not let it back in
	for _, style in ipairs({ "efficient", "completionist" }) do
		ns.Prefs.SetStyle(style)
		ns.State.Recompute()
		check(appears(ns, ID) == nil, "style " .. style .. ": still absent")
	end
end

section("skip: a quest already IN THE LOG that is added and skipped is not offered either (the QT skip), and the funnel is consistent")
do
	local ns, W = world()
	W.log = { { questID = ID, title = "Arugal's Folly", complete = false } }
	W.objectives[ID] = { { text = "Kill things", type = "event", finished = false, numFulfilled = 0, numRequired = 3 } }
	ns.Prefs.Add(ID)
	ns.Prefs.Skip("QT:" .. ID)
	ns.State.Recompute()
	local hit = false
	for _, f in ipairs({ "now", "alsoDo", "thenAction" }) do local a = ns.State.plan[f]; if a and a.quest == ID then hit = true end end
	check(not hit, "a skipped in-log quest is not NOW, ALSO DO or THEN")
	check(not ns.Prefs.IsAdded(ID), "and the skip removed it from 'added'")
end
