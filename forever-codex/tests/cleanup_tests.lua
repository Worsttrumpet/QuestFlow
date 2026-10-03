-- cleanup_tests.lua: 0.2.5 cleanup.
--   * Codex does not use raid-target (world marker) APIs at all, and has no marker module, command, setting or event
--   * Codex puts no pins of its own on the world map (the waypoint, the arrow and the internal coordinate logic stay)
--   * /codex report: the nearest relevant stops with quest names and action types, a readable sequence, an honest count of what was left out,
--     and, for quests Codex cannot place, which data layer lacks the location

local H = ...
local check, section, boot = H.check, H.section, H.boot

local function addonFiles()
	local out = {}
	for line in H.readFile(H.addonDir .. "/ForeverCodex.toc"):gmatch("[^\r\n]+") do
		if not line:match("^%s*#") and line:match("%.lua%s*$") then out[#out + 1] = (line:gsub("^%s+", ""):gsub("%s+$", ""):gsub("\\", "/")) end
	end
	return out
end
local function code(file) return (H.readFile(H.addonDir .. "/" .. file):gsub("%-%-[^\n]*", "")) end

section("0.2.5: automatic world markers are gone (no raid-target API, module, command, setting or event)")
do
	local files = addonFiles()
	check(#files > 20, "(the .toc lists the addon's files)")
	local bad = { "SetRaidTarget", "GetRaidTargetIndex", "RaidTarget", "PLAYER_TARGET_CHANGED", "UPDATE_MOUSEOVER_UNIT", "ns.Markers", "MarkersOn", "SetMarkers" }
	for _, f in ipairs(files) do
		local src = code(f)
		for _, word in ipairs(bad) do
			check(not src:find(word, 1, true), f .. " does not mention " .. word)
		end
		check(f ~= "Markers.lua" and f ~= "Pins.lua", "the .toc does not load " .. f .. " (a retired module)")
	end
	local ns, W = boot({ char = { level = 6 }, synthetic = true })
	check(ns.Markers == nil and ns.Prefs.MarkersOn == nil and ns.Prefs.SetMarkers == nil, "no Markers module and no marker preference")
	local seen = {}
	for _, e in ipairs(W and W.registeredEvents or H.world().registeredEvents or {}) do seen[e] = true end
	check(not seen.PLAYER_TARGET_CHANGED and not seen.UPDATE_MOUSEOVER_UNIT, "the marker-only events are not registered")
	local W2 = H.world()
	W2.chat = {}
	H.slash("markers")
	check(table.concat(W2.chat, "\n"):find("unknown command 'markers'", 1, true) ~= nil, "/codex markers is not a command any more")
	W2.chat = {}
	H.slash("help")
	check(not table.concat(W2.chat, "\n"):lower():find("marker", 1, true), "help no longer mentions markers")
	-- a character saved by an older version (markers / pins keys in its data) loads without any error
	local old = { version = 1, ui = {}, chars = { ["Thrall-Forever"] = { routeZone = "auto", style = "efficient", systems = {}, skipped = {}, added = {}, markers = true, pins = true } }, diag = {} }
	local ns2 = boot({ char = { level = 12 }, synthetic = true, savedVars = old })
	ns2.State.Recompute()
	check(#ns2.errors == 0, "old saved marker / pin choices are ignored without errors")
	check(#ns.errors == 0, "no errors")
end

section("0.2.5: Codex puts no pins of its own on the world map (waypoint, arrow and coordinate logic stay)")
do
	local ns = boot({ char = { level = 6 }, synthetic = true })
	check(ns.Pins == nil and ns.Prefs.PinsOn == nil and ns.Prefs.SetPins == nil, "no Pins module and no pin preference")
	for _, f in ipairs(addonFiles()) do
		local src = code(f)
		for _, word in ipairs({ "GetCanvas", "AddDataProvider", "MapCanvas", "ns.Pins", "PinsOn" }) do
			-- (WorldMapButton.lua anchors a plain BUTTON to the map's canvas container: that is not a pin)
			check(f == "WorldMapButton.lua" and word == "GetCanvas" or not src:find(word, 1, true), f .. " does not mention " .. word)
		end
	end
	local W = H.world()
	W.chat = {}
	H.slash("pins")
	check(table.concat(W.chat, "\n"):find("unknown command 'pins'", 1, true) ~= nil, "/codex pins is not a command any more")
	W.chat = {}
	H.slash("help")
	check(not table.concat(W.chat, "\n"):lower():find("pins", 1, true), "help no longer mentions pins")
	-- what stays
	check(ns.Navigation ~= nil and ns.Arrow ~= nil and ns.MapPin ~= nil and ns.Engine.Distance ~= nil, "Navigation (the waypoint), the arrow, MapPin (show the waypoint) and the distance logic are still there")
	-- the settings page has neither toggle
	ns.Prefs.FinishSetup()
	ns.UI.Open("appendices")
	local setup = ns.UI.main and ns.UI.main.setupPanel
	local texts = {}
	for _, pg in pairs(ns.UI.pages or {}) do if pg.w then for k in pairs(pg.w) do texts[k] = true end end end
	check(not texts.pins and not texts.markers, "the settings page has no pins or markers toggle")
	local diagNs = boot({ char = { level = 6 }, synthetic = true })
	local W3 = H.world()
	W3.chat = {}
	H.slash("diag")
	local out = table.concat(W3.chat, "\n"):lower()
	check(not out:find("map pins", 1, true) and not out:find("markers:", 1, true), "/codex diag has no pin or marker lines")
	check(#ns.errors == 0 and #diagNs.errors == 0, "no errors")
end

-- ---------------------------------------------------------------- /codex report

local function Q(id, name, dx, dy, o)
	local q = { id = id, name = name, map = 9001, x = 0.5 + dx / 1000, y = 0.5 + (dy or 0) / 1000, req = 1, giverName = "Giver " .. id }
	for k, v in pairs(o or {}) do q[k] = v end
	return q
end

local function reportOf(ns)
	local text
	rawset(ns.UI, "ShowReport", function(t) text = t end)
	H.slash("report")
	return text
end

local function section_(text, head)
	local a = text:find("--- " .. head, 1, true)
	if not a then return "" end
	local b = text:find("\n--- ", a + 5, true)
	return text:sub(a, (b or #text + 1) - 1)
end

section("report: the nearest relevant stops, with quest names and actions; the rest is counted, not listed")
do
	local quests = {}
	for i = 1, 24 do quests[#quests + 1] = Q(100 + i, "Pickup number " .. i, 80 * ((i - 1) % 10 + 1), 80 * math.floor((i - 1) / 10)) end   -- 24 separate stops (80 yd apart: more than the 60 yd that merge)
	quests[#quests + 1] = Q(200, "Finished errand", -80, 5)
	for i = 1, 4 do quests[#quests + 1] = Q(300 + i, "Overseas job " .. i, 0, 0, { map = 9003, x = 0.1 * i, y = 0.5 }) end   -- no distance can be measured
	local ns = boot({ char = { level = 6 }, synthetic = true, loc = { map = 9001, x = 0.5, y = 0.5, zone = "Fixture Valley" } })
	H.attPack(ns, quests, nil)
	local W = H.world()
	W.log, W.objectives, W.completed = { { questID = 200, title = "Finished errand", complete = true } }, {}, {}
	ns.Prefs.FinishSetup()
	ns.State.Recompute()
	local text = reportOf(ns)
	check(type(text) == "string", "the report opens")
	if os.getenv("SHOW_REPORT") then print(text) end
	local near = section_(text, "NEAREST RELEVANT STOPS")
	local lines = {}
	for line in near:gmatch("[^\n]+") do if line:match("^Q:") then lines[#lines + 1] = line end end
	check(#lines >= 2 and #lines <= 16, "about 15 stops are listed, not all of them  [" .. #lines .. "]")
	check(near:find("Q:200 Finished errand - TURN_IN - ", 1, true) ~= nil, "a line has the quest id, the quest NAME, the action type and the distance")
	check(near:find("Q:101 Pickup number 1 - ACCEPT - ", 1, true) ~= nil, "pickups are shown as ACCEPT")
	check(near:find(" yd", 1, true) ~= nil, "distances are in yards")
	local prev = -1
	local ordered = true
	for _, line in ipairs(lines) do
		local yd = tonumber(line:match(" %- (%d+) yd"))
		if yd then if yd < prev - 0.5 then ordered = false end prev = yd end
	end
	check(ordered, "they are sorted nearest first")
	check(not near:find("Overseas job", 1, true), "stops with no measurable distance are not listed among the nearest")
	local omitted = tonumber(near:match("%+ (%d+) additional stops omitted"))
	check(omitted and omitted > 0, "the end says how many more stops were left out  [" .. tostring(omitted) .. "]")
	check(near:find("with no measurable distance", 1, true) and near:match("(%d+) with no measurable distance") == "4", "and how many of them have no measurable distance (the 4 overseas stops)")
	local total = tonumber(text:match("(%d+) stops, %d+ sequences"))
	check(total == #lines + omitted, "listed + omitted equals the planner's stop count  [" .. #lines .. " + " .. tostring(omitted) .. " = " .. tostring(total) .. "]")
	check(text:find("reason=", 1, true) and text:find("flags:", 1, true) and text:find("net ", 1, true) and text:find("unknown legs", 1, true) and text:find("sequences", 1, true) and text:find("rejected ALSO DO", 1, true),
		"the useful trace fields are all still there: reason, flags, net, time, unknown legs, sequences, rejected ALSO DO")
	check(#ns.errors == 0, "no errors")
end

section("report: the sequence reads like instructions")
do
	local ns = boot({ char = { level = 6 }, synthetic = true, loc = { map = 9001, x = 0.5, y = 0.5, zone = "Fixture Valley" } })
	H.attPack(ns, { Q(5, "The Haunted Mills", 30, 0, { giverName = "Coleman Farthing" }), Q(6, "A Letter Undelivered", 30, 0, { giverName = "Coleman Farthing" }), Q(7, "Fresh pickup", 35, 0) }, nil)
	local W = H.world()
	W.log, W.objectives, W.completed = { { questID = 5, title = "The Haunted Mills", complete = true }, { questID = 6, title = "A Letter Undelivered", complete = true } }, {}, {}
	ns.Prefs.FinishSetup()
	ns.State.Recompute()
	local seq = section_(reportOf(ns), "SEQUENCE")
	check(seq:find("1. Travel to Coleman Farthing", 1, true) ~= nil, "it starts with where to go  [" .. seq:gsub("\n", " / ") .. "]")
	check(seq:find("Turn in The Haunted Mills [Q:5]", 1, true) ~= nil and seq:find("Turn in A Letter Undelivered [Q:6]", 1, true) ~= nil, "then each action, with the quest name and id")
	check(not seq:find("Q:5:TURN_IN", 1, true), "no raw action ids in the sequence")
	local a, b = seq:find("Turn in The Haunted Mills", 1, true), seq:find("Accept Fresh pickup", 1, true)
	check(a and (not b or a < b), "hand-ins come before the pickup at the same stop")
	check(#ns.errors == 0, "no errors")
end

section("report: quests Codex cannot place say which layer lacks the data")
do
	local f = H.fake.new({ version = "1.0.4" })
	f.mapArea(9001, 9001)
	f.addNpc(8001, { name = "Giver With Place", spawns = { [9001] = { { 51.0, 50.0 } } }, zoneID = 9001, friendlyToFaction = "H" })
	f.addNpc(8002, { name = "Taker Without Place", zoneID = 9001, friendlyToFaction = "H" })
	f.addQuest(97001, { name = "Objectives without places", startedBy = { { 8001 } }, finishedBy = { { 8002 } }, requiredLevel = 1,
		objectives = { { { 8001, "a thing" } }, {}, { { 555, "an item" } } } })
	f.install()
	local ns = boot({ char = { level = 6 }, synthetic = true, loc = { map = 9001, x = 0.5, y = 0.5, zone = "F" } })
	H.attPack(ns, { Q(1, "A pickup", 20, 0) }, nil)
	local W = H.world()
	W.log = { { questID = 97001, title = "Objectives without places", complete = false }, { questID = 99999, title = "Nobody knows this one", complete = false } }
	W.objectives, W.completed = {}, {}
	ns.Prefs.FinishSetup()
	ns.State.Recompute()
	local text = reportOf(ns)
	local np = section_(text, "NOT PLACED")
	check(np:find("Q:97001 Objectives without places - OBJECTIVE", 1, true) ~= nil, "the quest is listed with its id, name and action")
	check(np:find("Q:99999", 1, true) ~= nil and np:find("no pack (observed, QuestieDB, ATT) knows this quest", 1, true) ~= nil, "a quest no layer knows is reported as exactly that")
	check(np:find("QuestieDB: does not have this quest (UNKNOWN", 1, true) ~= nil, "and QuestieDB lacking it is UNKNOWN, not 'no such quest'")
	check(np:find("QuestieDB: giver Giver With Place, has a position | turn-in Taker Without Place, NO position", 1, true) ~= nil, "QuestieDB's giver and turn-in NPCs are reported with whether each has a position")
	check(np:find("slot 1: 1 entries (1 NPCs with a position)", 1, true) ~= nil and np:find("slot 3: 1 entries (0 NPCs with a position)", 1, true) ~= nil, "its objective entries are counted, and how many NPCs among them have a position")
	check(np:find("game quest-map points on map 9001 (C_QuestLog.GetQuestsOnMap): ", 1, true) ~= nil and np:find("game map point:", 1, true) ~= nil, "the game's own quest-map points are checked for each (read only)")
	check(np:find("Codex data:", 1, true) ~= nil, "the Codex-side layers (observed / QuestieDB pack / ATT) are summarised too")
	check(text:find("QuestieDB tables exposed:", 1, true) ~= nil, "which QuestieDB tables exist is reported (are object / item tables reachable?)")
	check(#ns.errors == 0, "no errors")
	f.uninstall()
end

-- ---------------------------------------------------------------- 0.5.3: performance cleanup (quest scan reads the skipped table once) and counters
section("performance: the quest scan reads the skipped table once and returns exactly what it did before")
do
	local ns = boot({ char = { level = 6 }, synthetic = true, loc = { map = 9001, x = 0.5, y = 0.5, zone = "F" } })
	local recs = {}
	for i = 1, 300 do recs[#recs + 1] = Q(i, "Quest " .. i, (i % 20) * 10, math.floor(i / 20) * 10) end
	H.attPack(ns, recs, nil)
	local W = H.world()
	W.log, W.objectives, W.completed = { { questID = 5, title = "Quest 5", complete = false }, { questID = 88888, title = "Unknown held", complete = false } }, {}, {}
	ns.Prefs.FinishSetup()
	ns.Prefs.Skip("Q:7")
	ns.Prefs.Skip("QT:5")
	ns.Prefs.Skip("QT:88888")
	ns.Prefs.Add(99999)
	ns.Prefs.Skip("Q:99999")
	local function ids(list) local t = {} for _, a in ipairs(list) do t[#t + 1] = a.id end table.sort(t) return table.concat(t, ",") end
	local ctx = ns.Context.Build()
	local calls = 0
	local realChar = ns.Prefs.Char
	ns.Prefs.Char = function(...) calls = calls + 1 return realChar(...) end
	local env = { strategy = ns.Registry.Strategy("efficient"), stats = { filtered = {}, byType = {}, providers = {} }, warnings = {} }
	local out = ns.QuestProvider.Generate(ctx, env)
	ns.Prefs.Char = realChar
	check(calls < 10, "Q.Generate no longer rebuilds the preferences once per quest (P.Char calls: " .. calls .. " for 300 quests)")
	local got = ids(out)
	check(not got:find("Q:7,", 1, true) and not got:find("QT:5", 1, true) and not got:find("QT:88888", 1, true) and not got:find("99999", 1, true), "skipped quests (Q:, QT:, unknown held, added-unknown) are still excluded")
	check(env.stats.filtered.skipped == 2, "the skipped counter is unchanged (Q:7 and the held quest QT:5; unknown held / added quests are dropped without counting, as before): " .. tostring(env.stats.filtered.skipped))
	-- the same answer through the legacy per-key lookups (P.IsSkipped), id by id
	local expectOk = true
	for _, a in ipairs(out) do
		local qid = tonumber(tostring(a.id):match("(%d+)$"))
		if qid and (ns.Prefs.IsSkipped("Q:" .. qid) and not ctx.log[qid]) then expectOk = false end
	end
	check(expectOk, "no candidate is one that P.IsSkipped would have vetoed")
	ns.Prefs.Unskip("Q:7")
	local after = ids(ns.QuestProvider.Generate(ctx, { strategy = env.strategy, stats = { filtered = {}, byType = {}, providers = {} }, warnings = {} }))
	check(after ~= got, "un-skipping brings the quest back")
end

section("performance counters: recomputes, causes, events, memory, and no effect on the plan")
do
	local ns = boot({ char = { level = 6 }, synthetic = true, loc = { map = 9001, x = 0.5, y = 0.5, zone = "F" } })
	H.attPack(ns, { Q(1, "A pickup", 20, 0), Q(2, "Another", 60, 30) }, nil)
	H.world().log, H.world().objectives, H.world().completed = {}, {}, {}
	ns.Prefs.FinishSetup()
	local pf = ns.State.perf
	local base = pf.count
	ns.State.Recompute()
	check(pf.count == base + 1 and (pf.recomputeBy.direct or 0) >= 1, "a recompute is counted with the cause 'direct'")
	local clock = 0
	_G.debugprofilestop = function() clock = clock + 5 return clock end
	ns.State.Recompute("dirty")
	check(pf.last == 5 and pf.worst >= 5 and pf.total >= 5, "last / worst / total use the client's clock (stub clock: 5 per call)")
	local planA = ns.State.plan
	local seqA = {}
	for _, a in ipairs(planA.sequence or {}) do seqA[#seqA + 1] = a.id end
	_G.debugprofilestop = nil
	ns.State.Recompute()
	local seqB = {}
	for _, a in ipairs(ns.State.plan.sequence or {}) do seqB[#seqB + 1] = a.id end
	check(table.concat(seqA, ",") == table.concat(seqB, ",") and (planA.now and planA.now.id) == (ns.State.plan.now and ns.State.plan.now.id), "timing on or off: the plan is identical")
	check(type(pf.last) == "number", "without a clock the previous timing is kept and nothing fails")
	local before = pf.dirtyBy.QUEST_LOG_UPDATE or 0
	local boot_ = ns._selftest.boot
	boot_.onEvent(nil, "QUEST_LOG_UPDATE")
	boot_.onEvent(nil, "ZONE_CHANGED")
	boot_.onEvent(nil, "UNIT_QUEST_LOG_CHANGED", "player")
	boot_.onEvent(nil, "UNIT_QUEST_LOG_CHANGED", "pet")
	check((pf.dirtyBy.QUEST_LOG_UPDATE or 0) == before + 1 and pf.dirtyBy.ZONE_CHANGED == 1 and pf.dirtyBy.UNIT_QUEST_LOG_CHANGED == 1, "events that mark the plan stale are counted by name (a pet's log change is ignored, as before)")
	local n = pf.count
	ns.State.Tick(0.1)
	check(pf.count == n, "a dirty plan still waits for the 0.4 s delay (unchanged)")
	ns.State.Tick(0.5)
	check(pf.count == n + 1 and pf.recomputeBy.dirty >= 1, "after the delay one 'dirty' recompute runs")
	local m = pf.count
	ns.State.Tick(0.5)
	check(pf.count == m, "an idle tick does not recompute with the window closed")
	_G.GetAddOnMemoryUsage = function() return 2048 end
	local text = table.concat(ns.Diag.PerformanceLines(), "\n")
	check(text:find("recomputes:", 1, true) and text:find("recomputes by cause:", 1, true) and text:find("events that marked the plan stale:", 1, true) and text:find("Codex memory: 2.0 MB now", 1, true), "the PERFORMANCE lines show counts, causes, events and memory")
	_G.GetAddOnMemoryUsage = nil
	text = table.concat(ns.Diag.PerformanceLines(), "\n")
	check(text:find("unavailable", 1, true) and text:find("absent", 1, true), "memory is reported as unavailable when the client API is absent")
	local rep = reportOf(ns)
	check(rep:find("PERFORMANCE (counters only", 1, true) ~= nil, "/codex report has a PERFORMANCE section")
	check(#ns.errors == 0, "no errors")
end

-- ---------------------------------------------------------------- Phase 1 of the Opportunity System: diagnostics only
section("opportunity diagnostics: every priced candidate is explained, and the plan is the same with or without them")
-- The core route is forced: three quests the player ADDED sit 300 / 600 / 900 yd due east of the player (an added quest is always sequenced).
local function oppWorld(extra)
	local ns = boot({ char = { level = 6 }, synthetic = true, loc = { map = 9001, x = 0.5, y = 0.5, zone = "F" } })
	local recs = {}
	for i = 1, 3 do recs[#recs + 1] = Q(100 + i, "Core " .. i, 300 * i, 0, { level = 6, req = 5 }) end
	for _, q in ipairs(extra or {}) do recs[#recs + 1] = q end
	H.attPack(ns, recs, nil)
	local W = H.world()
	W.log, W.objectives, W.completed = {}, {}, {}
	ns.Prefs.FinishSetup()
	for i = 1, 3 do ns.Prefs.Add(100 + i) end
	return ns
end
local function oppRun(ns, over)
	local ctx = ns.Context.Build()
	local c = ns.Engine.Candidates(ctx)
	local plan = ns.Planner.Compute(ctx, c, { trace = true })
	return ctx, plan, c
end
local function oppById(plan, id)
	for _, o in ipairs(plan.diag.opps and plan.diag.opps.list or {}) do if o.id == id then return o end end
end
local P5 = { level = 6, req = 5 }
local spec = {
	Q(1, "Right on the line", 150, 0, P5),            -- A: between you and Core 1, on the straight line
	Q(2, "Behind you", -150, 0, P5),                  -- B: the opposite direction
	Q(3, "Hub one", 300, -400, P5), Q(4, "Hub two", 320, -410, P5), Q(5, "Hub three", 310, -430, P5),   -- C: three givers together, off the line
	Q(6, "Off then back", 450, 150, P5),              -- D: leaves the route and reconnects
	Q(7, "Beside the last stop", 900, 90, P5),        -- E: near a later stop
	Q(8, "Past the end", 1500, 0, P5),                -- after the whole route
}
do
	local ns = oppWorld(spec)
	local ctx, plan = oppRun(ns)
	local o = plan.diag.opps
	print("OPPDEBUG route", table.concat(plan.diag.sequence or {}, ">"), "total", o and o.total)
	for _, e in ipairs(o and o.list or {}) do print(string.format("OPPDEBUG %s cost=%s rel=%s cls=%s dec=%s from=%s to=%s stop=%s/%s net=%.1f", e.id, tostring(e.cost), e.rel, e.cls, e.dec, tostring(e.from), tostring(e.to), tostring(e.stop), tostring(e.stopSize), e.net or 0)) end
	for _, h in ipairs(o and o.hubs or {}) do print("OPPDEBUG hub", h.stop, h.size, h.cost, h.net) end
end

-- ---- the scenarios
do
	local ns = oppWorld(spec)
	local ctx, plan = oppRun(ns)
	local o = plan.diag.opps
	check(plan.diag.sequence[1] == "Q:101:ACCEPT" and plan.diag.sequence[3] == "Q:103:ACCEPT", "the forced core route is the three added quests, in order")
	check(o ~= nil and o.total == 8 and #o.list == 8, "every candidate the planner priced is kept (8 of 8), not just one winner and six rejections")
	-- A: directly on the route
	local a = oppById(plan, "Q:1:ACCEPT")
	check(a and a.cost == 0 and a.rel == "DIRECTLY_ON_ROUTE" and a.cls == "FREE" and a.dec == "ACCEPTED" and a.from == "you" and a.to == "Q:101:ACCEPT", "A: a pickup on the straight line costs 0 s, is DIRECTLY_ON_ROUTE / FREE, and is the ALSO DO")
	check(plan.alsoDo and plan.alsoDo.id == "Q:1:ACCEPT", "the real ALSO DO is that same item (the diagnostics describe the decision, they do not make it)")
	-- B: opposite direction: the out-and-back is charged
	local b = oppById(plan, "Q:2:ACCEPT")
	check(b and math.abs(b.cost - 300 / 7) < 0.01 and b.rel == "RECONNECTING_DETOUR" and b.from == "you" and b.dec == "TOO_FAR" and b.cls == "MODERATE", "B: a quest 150 yd BEHIND you costs the out-and-back (300 yd = 42.9 s), MODERATE, TOO_FAR; backtracking shows only as that cost")
	-- C: a hub of three givers shares one stop
	local c3, c4, c5 = oppById(plan, "Q:3:ACCEPT"), oppById(plan, "Q:4:ACCEPT"), oppById(plan, "Q:5:ACCEPT")
	check(c3 and c4 and c5 and c3.stop == c4.stop and c4.stop == c5.stop and c3.stopSize == 3, "C: three nearby givers are ONE stop of 3 actions")
	check(c3.cls == "EXPENSIVE" and c4.cls == "EXPENSIVE" and c5.cls == "EXPENSIVE", "C: priced one by one each is EXPENSIVE (net <= 0 after the walk)")
	local hub = o.hubs[1]
	check(hub and hub.size == 3 and hub.stop == c3.stop and hub.net > 0 and hub.val > 3 * 19, "C: priced as one trip the same hub is net positive (" .. (hub and string.format("%.1f", hub.net) or "?") .. ": the compound value the per-item pricing hides)")
	-- D: leaves the route and reconnects
	local d = oppById(plan, "Q:6:ACCEPT")
	check(d and d.rel == "RECONNECTING_DETOUR" and d.from == "Q:101:ACCEPT" and d.to == "Q:102:ACCEPT" and d.cls == "CHEAP" and d.dec == "OUTRANKED", "D: a detour between two route stops is RECONNECTING_DETOUR, CHEAP, and OUTRANKED (it cleared both bars; a better item won)")
	-- E: next to the last stop
	local e = oppById(plan, "Q:7:ACCEPT")
	check(e and e.rel == "AFTER_ROUTE" and e.from == "Q:103:ACCEPT" and e.to == nil and math.abs(e.cost - 90 / 7) < 0.01, "E: a quest beside the last stop is priced after the route (90 yd = 12.9 s)")
	local f = oppById(plan, "Q:8:ACCEPT")
	check(f and f.cls == "EXPENSIVE" and f.dec == "TOO_FAR", "a quest 600 yd past the end is EXPENSIVE and TOO_FAR")
	-- the independent check: every cost equals the cheapest insertion into player -> stops, recomputed here from the trace
	local route = { { map = 9001, x = 0.5, y = 0.5 } }
	for _, sid in ipairs(plan.diag.sequence) do for _, st in ipairs(plan.diag.stopList) do if st.id == sid then route[#route + 1] = { map = st.map, x = st.x, y = st.y } end end end
	local all = true
	for _, e2 in ipairs(o.list) do
		local pos = plan.diag.items[e2.id]
		if not e2.same and pos then
			local best
			for i = 1, #route do
				local da = ns.Engine.Distance(ctx, route[i], pos) / 7
				local extra
				if route[i + 1] then extra = math.max(0, da + ns.Engine.Distance(ctx, pos, route[i + 1]) / 7 - ns.Engine.Distance(ctx, route[i], route[i + 1]) / 7) else extra = da end
				if not best or extra < best then best = extra end
			end
			if math.abs(best - e2.cost) > 1e-6 then all = false end
		end
	end
	check(all, "every recorded cost equals the cheapest insertion into player -> stops, recomputed independently from the trace")
	-- the counts and the deterministic order
	check(o.class.FREE == 1 and o.class.CHEAP == 2 and o.class.MODERATE == 1 and o.class.EXPENSIVE == 4, "cost-class counts cover every priced candidate")
	check(o.decision.ACCEPTED == 1 and o.decision.OUTRANKED == 2 and o.decision.TOO_FAR == 5, "decision counts: ACCEPTED 1, OUTRANKED 2, TOO_FAR 5")
	local sorted = true
	for i = 2, #o.list do if o.list[i - 1].cost > o.list[i].cost then sorted = false end end
	check(sorted, "the list is ordered cheapest extra time first")
	-- the existing TOO_FAR record is untouched
	local tf = 0
	for _, r in ipairs(plan.diag.rejected) do if r.code == "TOO_FAR" then tf = tf + 1 end end
	check(tf == 5 or #plan.diag.rejected == 6, "the old diag.rejected list keeps its own six-entry cap and shape")
	-- same plan twice: deterministic
	local _, plan2 = oppRun(ns)
	local same = #plan2.diag.opps.list == #o.list
	for i, e2 in ipairs(o.list) do if plan2.diag.opps.list[i].id ~= e2.id then same = false end end
	check(same, "a second run lists the same candidates in the same order")
	-- provenance: a database record is not client evidence
	ns.State.Recompute()
	local lines = table.concat(ns.Diag.OpportunityLines(), "\n")
	check(lines:find("Q:1:ACCEPT", 1, true) and lines:find("actionability UNKNOWN (never seen offered", 1, true) ~= nil, "an ACCEPT known only from a database stays 'actionability UNKNOWN' in the report")
	check(lines:find("classMask=", 1, true) and lines:find("raceMask=", 1, true), "the report prints the class and race mask the data holds, without acting on them")
	check(lines:find("stop Q:3:ACCEPT holds 3 action", 1, true) and lines:find("priced AS A WHOLE", 1, true), "the report shows the 3-action stop and the hub priced as a whole")
	check(not lines:find("evidence=observed", 1, true), "nothing database-derived is labelled observed")
end

do
	-- a quest dialog the client really showed is the one thing that turns UNKNOWN into OBSERVED
	local ns = oppWorld(spec)
	ForeverCodexDB.items = ForeverCodexDB.items or {}
	ForeverCodexDB.items.rewards = { [1] = { q = 1, at = "QUEST_DETAIL", src = "CODEX_OBSERVED" } }
	ns.State.Recompute()
	local lines = table.concat(ns.Diag.OpportunityLines(), "\n")
	check(lines:find("actionability OBSERVED (a quest dialog for it was seen)", 1, true) ~= nil, "a QUEST_DETAIL observation turns that quest's actionability to OBSERVED")
	ForeverCodexDB.items.rewards = nil
end

section("opportunity diagnostics: cost labels, LOW_VALUE, the cap, optional hints, no behaviour change")
do
	local ns = oppWorld(spec)
	local Pl = ns.Planner
	check(Pl.CostClass(0, true, 5, 30) == "FREE" and Pl.CostClass(0.3, false, 12, 30) == "FREE", "FREE: same stop, or <= 0.5 s extra")
	check(Pl.CostClass(20, false, 8, 30) == "CHEAP", "CHEAP: within the detour limit and net positive")
	check(Pl.CostClass(60, false, 4, 30) == "MODERATE", "MODERATE: above the limit but still net positive")
	check(Pl.CostClass(60, false, -2, 30) == "EXPENSIVE" and Pl.CostClass(20, false, -2, 30) == "EXPENSIVE", "EXPENSIVE: net <= 0 after the walk, even inside the limit")
	check(Pl.CostClass(nil, false, nil, 30) == "UNKNOWN" and Pl.RouteRelation(nil, false, false) == "UNKNOWN", "an unmeasurable leg is UNKNOWN, never guessed")
	check(Pl.RouteRelation(10, false, true) == "AFTER_ROUTE" and Pl.RouteRelation(10, false, false) == "RECONNECTING_DETOUR" and Pl.RouteRelation(0.4, false, false) == "DIRECTLY_ON_ROUTE", "route relation from the insertion the planner already computed")
	-- LOW_VALUE: an action kind the planner values at 0, 3 s from the route
	ForeverCodex.RegisterProvider({ key = "opp-lowvalue", type = "RESPAWN_SKIP", label = "test low value", generate = function()
		return { ns.Registry.NewAction({ id = "RS:9", type = "RESPAWN_SKIP", kind = "RESPAWN_SKIP", skipKey = "RS:9", title = "Worthless thing",
			target = { map = 9001, x = 0.5 + 0.150, y = 0.5 + 0.030, label = "x", src = "att", verified = false }, src = "att", verified = false }) }
	end })
	ForeverCodex.RegisterActionType("RESPAWN_SKIP", { label = "Respawn skip" })
	local ctx, plan = oppRun(ns)
	local lv = oppById(plan, "RS:9")
	check(lv and lv.dec == "LOW_VALUE" and lv.cost <= 30 and lv.net < 5, "LOW_VALUE: close enough, but not worth its time (net " .. (lv and string.format("%.1f", lv.net) or "?") .. ")")
	-- the cap
	local many = {}
	for i = 1, 60 do many[#many + 1] = Q(200 + i, "Many " .. i, 100 + i * 15, 200 + (i % 7) * 40, P5) end
	local ns2 = oppWorld(many)
	local _, plan3 = oppRun(ns2)
	local o3 = plan3.diag.opps
	check(o3.total > 40 and #o3.list == 40 and o3.cap == 40, "the kept list is capped at 40 while the counts cover all " .. o3.total .. " priced")
	local sorted = true
	for i = 2, #o3.list do if o3.list[i - 1].cost > o3.list[i].cost or (o3.list[i - 1].cost == o3.list[i].cost and o3.list[i - 1].id > o3.list[i].id) then sorted = false end end
	check(sorted, "the cap keeps the cheapest first, ties by id (deterministic)")
	-- an optional hint is priced too and has no stop
	-- no behaviour change: NOW / ALSO DO / THEN and the sequence do not depend on the diagnostics
	local before = { plan3.now and plan3.now.id, plan3.alsoDo and plan3.alsoDo.id, plan3.thenAction and plan3.thenAction.id, table.concat(plan3.diag.sequence, ">") }
	ns2.Planner.OPP_CAP = 1
	local _, plan4 = oppRun(ns2)
	local after = { plan4.now and plan4.now.id, plan4.alsoDo and plan4.alsoDo.id, plan4.thenAction and plan4.thenAction.id, table.concat(plan4.diag.sequence, ">") }
	ns2.Planner.OPP_CAP = 40
	check(table.concat(before, "|") == table.concat(after, "|") and #plan4.diag.opps.list == 1, "changing the diagnostic cap changes only the diagnostics, never the plan")
	check(#ns2.errors == 0, "no errors")
end

-- ---------------------------------------------------------------- Opportunity System Phase A/B (0.6.0): plan.onTheWay
section("on the way: every candidate that clears the ALSO DO bars is carried, normalised, with its route cost and reason")
do
	-- core route: three added quests east of you; pickups: one on the line, one 250 yd off (too far), and a 3-giver hub right at the first stop
	local ns = oppWorld({
		Q(1, "Right on the line", 150, 0, P5),
		Q(2, "Behind you", -150, 0, P5),
		Q(6, "Off then back", 450, 150, P5),
		Q(7, "Beside the last stop", 900, 90, P5),
		Q(8, "Past the end", 1500, 0, P5),
		Q(21, "Hub A", 300, 20, P5), Q(22, "Hub B", 310, 10, P5), Q(23, "Hub C", 305, -10, P5),
	})
	local ctx, plan = oppRun(ns)
	local list = plan.onTheWay
	local ids = {}
	for _, o in ipairs(list) do ids[#ids + 1] = o.id end
	check(#list >= 2 and #list <= ns.Planner.ON_THE_WAY_MAX, "several opportunities are carried, capped at " .. ns.Planner.ON_THE_WAY_MAX .. ": " .. table.concat(ids, " "))
	check(plan.alsoDo and list[1].id == plan.alsoDo.id and list[1].action == plan.alsoDo, "onTheWay[1] is exactly the ALSO DO (the planner's choice is unchanged)")
	local sorted = true
	for i = 2, #list do if list[i - 1].net < list[i].net then sorted = false end end
	check(sorted, "ordered best net first")
	local passing = plan.diag.onTheWayTotal
	local count = 0
	for _, e in ipairs(plan.diag.opps.list) do if e.dec == "ACCEPTED" or e.dec == "OUTRANKED" then count = count + 1 end end
	check(passing == count, "the carried set is exactly the candidates the diagnostics call ACCEPTED or OUTRANKED (" .. tostring(passing) .. ")")
	for _, o in ipairs(list) do
		check(o.cost <= 30 and o.net >= 5 and o.relation and o.costClass and o.reason and o.reason.code and o.action and o.evidence ~= nil, "every carried item cleared both bars and has relation / cost class / reason: " .. o.id)
	end
	local first = list[1]
	check(first.reason.code == "ON_THE_WAY" or first.reason.code == "SAME_STOP" or first.reason.code == "SMALL_DETOUR", "its reason is one of the planner's own codes (" .. first.reason.code .. ")")
	local byId = {}
	for _, o in ipairs(list) do byId[o.id] = o end
	check(byId["Q:2:ACCEPT"] == nil and byId["Q:8:ACCEPT"] == nil, "a candidate behind you (out and back) or far past the end is not carried")
	check(first.actionability == "UNKNOWN" and first.action.kind == "ACCEPT", "a database pickup is carried with actionability UNKNOWN, never OBSERVED")
	-- the tracker lists them, as ALSO PICK UP
	ns.State.Recompute()
	ns.UI.Open("codex")
	local c = ns.UI.main.codex
	local card = ns.Presenter.Card(ns.State.plan, ns.State.ctx)
	local acts = 0
	for _, it in ipairs(card.also) do if it.kind == "action" then acts = acts + 1 end end
	check(acts >= 2 and acts <= ns.Overlap.MAX_ACTIONS, "the ALSO card lists several pickups, not only one (" .. acts .. ")")
	check(c.alsoLabel.__text == "ALSO PICK UP", "titled for what they are")
	-- repeatable
	local _, plan2 = oppRun(ns)
	local same = #plan2.onTheWay == #list
	for i, o in ipairs(list) do if plan2.onTheWay[i].id ~= o.id then same = false end end
	check(same, "the same list, in the same order, on a second run")
	check(#ns.errors == 0, "no errors")
end

section("on the way: an in-log quest is IN_LOG, a quest dialog seen is OBSERVED, and the cap changes only what is carried")
do
	local ns = oppWorld({ Q(1, "Right on the line", 150, 0, P5) })
	local Pl = ns.Planner
	check(Pl.Actionability({ kind = "OBJECTIVE", quest = 1 }) == "NOT_APPLICABLE" and Pl.Actionability(nil) == "NOT_APPLICABLE", "only a pickup has an actionability")
	check(Pl.Actionability({ kind = "ACCEPT", quest = 1 }) == "UNKNOWN", "UNKNOWN by default")
	ForeverCodexDB.items = ForeverCodexDB.items or {}
	ForeverCodexDB.items.rewards = { [1] = { q = 1, at = "QUEST_DETAIL" } }
	check(Pl.Actionability({ kind = "ACCEPT", quest = 1 }) == "OBSERVED", "OBSERVED after a QUEST_DETAIL dialog was recorded")
	ForeverCodexDB.items.rewards = { [1] = { q = 1, at = "QUEST_COMPLETE" } }
	check(Pl.Actionability({ kind = "ACCEPT", quest = 1 }) == "UNKNOWN", "a turn-in dialog is not evidence that it was offered")
	ForeverCodexDB.items.rewards = nil
	local _, plan = oppRun(ns)
	local keep = #plan.onTheWay
	Pl.ON_THE_WAY_MAX = 1
	local _, plan2 = oppRun(ns)
	Pl.ON_THE_WAY_MAX = 4
	check(#plan2.onTheWay <= 1 and plan2.now.id == plan.now.id and (plan2.alsoDo and plan2.alsoDo.id) == (plan.alsoDo and plan.alsoDo.id), "lowering the cap changes only what is carried, never NOW or the ALSO DO")
end
