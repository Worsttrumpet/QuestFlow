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
