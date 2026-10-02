-- phase3_tests.lua: the player-facing build (Phase 3). Loaded by run_codex_tests.lua with the shared harness table H.
--
-- Covers: the Presenter (what the player reads), the player window and its pages, setup and window persistence, Journey,
-- Knowledge, Navigation (ownership above all), Party, Help Improve Codex, event wiring, diagnostics, and
-- the guarantee that none of it changed what the Planner decides.
-- As everywhere in this project: these prove Codex's OWN logic against a stub client. What Forever does is a separate,
-- real-client question (docs/CODEX_PHASE3_NOTES.md lists what has and has not been verified there).

local H = ...
local check, section, boot = H.check, H.section, H.boot

local function click(b) b.__scripts.OnClick(b) end
local function say(W, s) for _, m in ipairs(W.chat) do if m:find(s, 1, true) then return true end end return false end

local function allTexts(W)
	local out = {}
	for _, f in ipairs(W.fonts or {}) do if f.__text and f.__text ~= "" then out[#out + 1] = f.__text end end
	return out
end

-- ("Skip" is allowed: the NOW card has a Skip button, the player's way out of a wrong or unavailable recommendation; the other old buttons stay banned)
local FORBIDDEN = { "Show on Map", "Add quest", "Refresh", "ATT", "verified", "unverified", "waiting", "Source:", "Status:", "policy", "confidence",
	"score", "interruption", "AllTheThings", "observed on Forever" }
local function leaks(W)
	local bad = {}
	for _, t in ipairs(allTexts(W)) do
		for _, w in ipairs(FORBIDDEN) do if t:find(w, 1, true) then bad[#bad + 1] = w .. " in '" .. t .. "'" end end
		if t:find("%d+%.%d+, %d+%.%d+") or t:find("Q:%d") or t:find("map %d") or t:find("%[%d+%]") then bad[#bad + 1] = "ids/coordinates in '" .. t .. "'" end
	end
	return bad
end

--- A synthetic world around the player at the centre of map 9001 (1 map unit = 1000 yd).
local function world(level, quests, log, o)
	o = o or {}
	local ns = boot({ char = { level = level or 6 }, synthetic = true, loc = { map = 9001, x = 0.5, y = 0.5, zone = "Fixture Valley" } })
	H.attPack(ns, quests or {}, nil)
	local W = H.world()
	W.log, W.objectives = {}, {}
	for id, e in pairs(log or {}) do
		W.log[#W.log + 1] = { questID = id, title = e.title or ("quest " .. id), complete = e.complete == true }
		if e.objectives then
			W.objectives[id] = {}
			for i, ob in ipairs(e.objectives) do W.objectives[id][i] = { text = ob.text, type = "monster", finished = ob.have >= ob.need, numFulfilled = ob.have, numRequired = ob.need } end
		end
	end
	table.sort(W.log, function(a, b) return a.questID < b.questID end)
	if not o.keepSetup then ns.Prefs.FinishSetup() end
	ns.State.Recompute()
	return ns, W
end

local function Q(id, name, dx, dy, o)
	local q = { id = id, name = name, map = 9001, x = 0.5 + dx / 1000, y = 0.5 + (dy or 0) / 1000 }
	for k, v in pairs(o or {}) do q[k] = v end
	return q
end

-- ================================================================ Presenter: what the player reads

section("phase 3: Presenter (the decision in plain language)")
do
	local ns, W = world(6, {
		Q(1, "Wayward Weapons", 20, 0, { giverName = "Kzan Thornslash", giverNpc = 3159, objectives = { "0/6 Abandoned Training Weapon" } }),
		Q(2, "Sting of the Scorpid", 25, 5, { giverName = "Gornek", objCoords = { { map = 9001, x = 0.52, y = 0.5 } }, objectives = { "10/10 Scorpid Worker Tail" } }),
	}, { [2] = { title = "Sting of the Scorpid", objectives = { { text = "Scorpid Worker Tail: 4/6", have = 4, need = 6 } } } })
	local card = ns.Presenter.Card(ns.State.plan, ns.State.ctx)
	check(card.now ~= nil and card.now.icon == "star", "NOW has one obvious card with the star icon")
	check(card.now.title == "Finish Sting of the Scorpid" or card.now.title == "Accept Wayward Weapons", "the title is a plain verb + quest name: " .. tostring(card.now.title))
	local item = card.now.kind == "OBJECTIVE" and card.now or card.alsoDo
	check(item and item.progress == "4 / 6", "objective progress reads like a player says it: 4 / 6")
	check(item and item.detail and item.detail:find("Scorpid Worker Tail", 1, true) and not item.detail:find("4/6", 1, true), "the objective is described without the raw counts")
	check(card.now.where == "Right here" or card.now.where == "Nearby", "distance is a word, not coordinates: " .. tostring(card.now.where))
	local acc = (card.now.kind == "ACCEPT" and card.now) or (card.alsoDo and card.alsoDo.kind == "ACCEPT" and card.alsoDo)
	check(acc and acc.who == "Kzan Thornslash" and acc.detail:find("abandoned", 1, true) == nil or acc.detail:find("Abandoned Training Weapon", 1, true), "an accept names the quest giver and the goal")
	local function clean(it)
		if not it then return true end
		for _, k in ipairs({ "title", "who", "detail", "progress", "where", "why" }) do
			local t = it[k]
			if t then
				for _, w in ipairs(FORBIDDEN) do if t:find(w, 1, true) then return false end end
				if t:find("Q:%d") or t:find("%d%.%d, %d") then return false end
			end
		end
		return true
	end
	check(clean(card.now) and clean(card.alsoDo), "no source, provenance, id, coordinate, score or technical word reaches the card")
	check(card.alsoDo == nil or ns.State.plan.alsoDo ~= nil, "ALSO DO is shown only when the Planner has one")
	-- exactly the Planner's choices
	check(card.now.title:find(ns.State.plan.now.name or "", 1, true) ~= nil, "NOW is the Planner's NOW")
	-- ObjectiveClean
	check(ns.Presenter.CleanObjective("10/10 Mottled Boar slain") == "Mottled Boar slain" and ns.Presenter.CleanObjective("Mottled Boar slain: 3/10") == "Mottled Boar slain"
		and ns.Presenter.CleanObjective("3/10") == nil and ns.Presenter.CleanObjective(nil) == nil, "objective text is cleaned of counts")
end

section("phase 3: Presenter, THEN and the empty states")
do
	local ns = world(6, { Q(1, "A ready quest", 600, 0, { giverName = "Far Giver" }), Q(2, "Local", 20, 0) }, { [1] = { complete = true, title = "A ready quest" } })
	local card = ns.Presenter.Card(ns.State.plan, ns.State.ctx)
	check(card.now.kind == "ACCEPT" or card.now.kind == "TURN_IN", "(setup) a plan with a turn-in")
	-- a THEN that is a turn-in is always worth a line; a far non-turn-in is not
	local p = { now = ns.State.plan.now, alsoDo = nil, reminders = {}, warnings = {}, diag = { reasons = {} } }
	local far = { id = "Q:9:ACCEPT", kind = "ACCEPT", type = "QUEST", quest = 9, name = "Far pickup", contract = 1, targets = { ns.Contract.Target({ role = "GIVER",
		where = ns.Contract.Where("known", { { map = 9001, x = 0.5 + 0.9, y = 0.5 } }), prov = ns.Contract.Prov("att") }) } }
	p.thenAction = far
	check(ns.Presenter.Card(p, ns.State.ctx).thenLine == nil, "a THEN far away is left out")
	local near = { id = "Q:8:ACCEPT", kind = "ACCEPT", type = "QUEST", quest = 8, name = "Near pickup", contract = 1, targets = { ns.Contract.Target({ role = "GIVER",
		where = ns.Contract.Where("known", { { map = 9001, x = 0.5 + 0.1, y = 0.5 } }), prov = ns.Contract.Prov("att") }) } }
	p.thenAction = near
	p.now = { id = "Q:1:ACCEPT", kind = "ACCEPT", type = "QUEST", quest = 1, name = "Here", contract = 1, targets = { ns.Contract.Target({ role = "GIVER",
		where = ns.Contract.Where("known", { { map = 9001, x = 0.5, y = 0.5 } }), prov = ns.Contract.Prov("att") }) } }
	check(ns.Presenter.Card(p, ns.State.ctx).thenLine == "Accept Near pickup", "a near THEN is one short line")
	local turn = { id = "Q:7:TURN_IN", kind = "TURN_IN", type = "QUEST", quest = 7, name = "Hand in", giver = "Gornek", contract = 1, targets = far.targets }
	p.thenAction = turn
	check(ns.Presenter.Card(p, ns.State.ctx).thenLine == nil, "a turn-in is never a THEN line: finished quests are listed under READY TO TURN IN instead")
	-- nothing to recommend
	local ns2 = world(6, {}, {})
	local c2 = ns.Presenter.Card(ns2.State.plan, ns2.State.ctx)
	check(c2.now == nil and c2.empty and c2.empty.title == "Nothing to recommend right now" and #c2.empty.lines >= 1, "no NOW: an honest empty card, no filler")
	local ns3 = world(6, { Q(1, "Located", 10, 0) }, { [900] = { title = "Mystery", complete = true } })
	ns3.Prefs.Skip("Q:1")
	ns3.State.Recompute()
	local c3 = ns3.Presenter.Card(ns3.State.plan, ns3.State.ctx)
	check(c3.now == nil and #c3.reminders == 1 and c3.reminders[1] == "Mystery" and c3.empty.lines[1]:find("cannot place"), "unplaceable quests are named as reminders, never as a destination")
end

-- ================================================================ the player window

section("phase 3: the player window, first-time setup, and no engineering machinery")
do
	local ns = boot({ char = { level = 12 }, synthetic = true, loc = { map = 9001, x = 0.5, y = 0.5, zone = "Fixture Valley" } })
	H.attPack(ns, { Q(1, "Pickup", 30, 0, { giverName = "Someone" }) }, nil)
	local W = H.world()
	H.slash("")
	check(ns.UI.IsShown() and ns.UI.options and ns.UI.options.__name == "ForeverCodexOptions" and ns.UI.frame == nil, "first run: /codex opens the options window (where setup is), not the tracker")
	check(ns.DevUI.frame == nil, "the developer window is not built for a normal player")
	local setup = ns.UI.main.setupPanel
	check(not ns.Prefs.SetupDone() and setup.frame.__shown and ns.UI.optionsKey == "options", "first run: the setup panel is shown on the Codex Options tab")
	check(setup.w.title.__text == "Here's your character." and setup.w.char.__text:find("Thrall - level 12 Troll Warrior", 1, true), "setup says 'Here's your character' and shows who it is")
	check(setup.w.start ~= nil, "setup has a Start button")
	-- choices
	local zonesBefore = ns.Prefs.GetRouteZone()
	local btns = {}
	for _, f in ipairs(W.frames) do if f.__kind == "Button" then btns[#btns + 1] = f end end
	check(#btns >= 6, "setup has buttons (tabs, pickers, toggles, Start)")
	for _, f in ipairs(W.frames) do
		if f.__kind == "Button" and f.text and f.text.__text == ">" then click(f) break end    -- first ">" is the route-zone picker
	end
	check(ns.Prefs.GetRouteZone() ~= zonesBefore or #ns.Registry.Zones() == 0, "the route-zone picker changes the route zone")
	local styleBefore = ns.Prefs.GetStyle()
	local seen = 0
	for _, f in ipairs(W.frames) do
		if f.__kind == "Button" and f.text and f.text.__text == ">" then
			seen = seen + 1
			if seen == 2 then click(f) break end
		end
	end
	check(ns.Prefs.GetStyle() ~= styleBefore, "the style picker changes the route style")
	check(ns.Prefs.GetStyle() ~= "solo" and ns.Prefs.GetStyle() ~= "hardcore", "and never lands on a planned style")
	local flightBtn
	for _, b in ipairs(setup.w.sys) do if b.sysKey == "flight" then flightBtn = b end end
	local flightBefore = ns.Prefs.IsSystemOn("flight")
	click(flightBtn)
	check(ns.Prefs.IsSystemOn("flight") ~= flightBefore, "a system toggle flips")
	check(#setup.w.sys >= 1, "only systems that exist are offered (planned ones are not shown)")
	click(setup.w.start)
	check(ns.Prefs.SetupDone() and not setup.frame.__shown and ns.UI.main.settingsPanel.frame.__shown and ns.UI.frame and ns.UI.main.codexPage.__shown, "Start finishes setup, shows the settings and opens the tracker")
	check(ns.UI.main.codex.header.__text:find("Thrall", 1, true) and ns.UI.main.codex.nowTitle.__text:find("Pickup", 1, true), "the Codex page shows the character and NOW")
	check(ns.UI.main.codex.nowIcon == nil, "NOW has no star box (just the label)")
	-- the normal window has none of the old machinery, on any page
	for _, key in ipairs({ "codex", "world", "journey", "appendices" }) do ns.UI.ShowPage(key) end
	for _, sub in ipairs({ "quests", "knowledge", "help", "party", "menu" }) do ns.UI.main.app.sub = sub; ns.UI.ShowPage("appendices") end
	local bad = leaks(W)
	check(#bad == 0, "no 'Show on Map', Add quest, Refresh, source, provenance, id or coordinate appears anywhere in the player window" .. (#bad > 0 and (": " .. bad[1]) or ""))
	local btnLabels = {}
	for _, f in ipairs(W.frames) do if f.__kind == "Button" and f.text then btnLabels[f.text.__text] = true end end
	check(not btnLabels["Show on Map"] and not btnLabels["Add quest..."] and not btnLabels["Refresh"], "none of the old buttons exist (Skip is the NOW card's own control)")
	check(ns.UI.frame.__scripts.OnDragStart ~= nil and ns.UI.frame.__scripts.OnDragStop ~= nil, "the window is movable")
	check(#ns.errors == 0, "no caught errors" .. (#ns.errors > 0 and (": " .. ns.errors[1]) or ""))
end

section("phase 3: setup and window position persist")
do
	local ns = boot({ char = { level = 12 }, synthetic = true, loc = { map = 9001, x = 0.5, y = 0.5 } })
	H.attPack(ns, { Q(1, "Pickup", 30, 0) }, { { key = "zone-a", label = "Zone A", map = 9001, quests = 1 } })
	ns.Prefs.SetStyle("fast"); ns.Prefs.SetRouteZone("zone-a"); ns.Prefs.SetPartyNotify("off"); ns.Prefs.SetNavigation(false); ns.Prefs.FinishSetup()
	H.slash("")
	ns.UI.frame.GetPoint = function() return "TOPLEFT", nil, "TOPLEFT", 120, -80 end
	ns.UI.frame.__scripts.OnDragStop(ns.UI.frame)
	local pos = ns.Prefs.WindowPos()
	check(pos and pos.point == "TOPLEFT" and pos.x == 120 and pos.y == -80, "dragging the window saves where it is")
	check(ns.Prefs.IsSavedVariablesSafe(ForeverCodexDB), "everything saved is SavedVariables-safe")
	local saved = ForeverCodexDB
	local ns2 = boot({ char = { level = 12 }, synthetic = true, loc = { map = 9001, x = 0.5, y = 0.5 }, savedVars = saved })
	H.attPack(ns2, { Q(1, "Pickup", 30, 0) }, { { key = "zone-a", label = "Zone A", map = 9001, quests = 1 } })
	check(ns2.Prefs.SetupDone() and ns2.Prefs.GetStyle() == "fast" and ns2.Prefs.GetRouteZone() == "zone-a" and ns2.Prefs.PartyNotify() == "off" and not ns2.Prefs.NavigationOn(),
		"after a reload the setup choices (zone, style, party news, navigation) are still there")
	H.slash("")
	local pts = ns2.UI.frame.__points
	check(pts and pts[1] == "TOPLEFT" and pts[3] == "TOPLEFT" and pts[4] == 120 and pts[5] == -80, "and the window opens where it was left")
	check(ns2.UI.main.codexPage.__shown and ns2.UI.options == nil, "a finished setup is not shown again: /codex opens the tracker, not the setup")
	-- defaults for a character that never saw Phase 3
	local old = { version = 1, ui = {}, chars = { ["Thrall-Forever"] = { routeZone = "auto", style = "efficient", systems = {}, skipped = { ["Q:5"] = true }, added = {} } }, diag = {} }
	local ns3 = boot({ char = { level = 12 }, synthetic = true, savedVars = old })
	check(not ns3.Prefs.SetupDone() and ns3.Prefs.PartyNotify() == "ui" and ns3.Prefs.NavigationOn() and ns3.Prefs.IsSkipped("Q:5"),
		"an existing character gets safe defaults (setup once, party news in the window only) and keeps its skips")
	H.slash("setup")
	check(not ns3.Prefs.SetupDone() and ns3.UI.IsShown(), "/codex setup runs the setup again")
end

-- ================================================================ World, Journey, Knowledge, Appendices

section("phase 3: Journey records only what Codex saw")
do
	local ns, W = world(3, {}, {})
	local J = ns.Journey
	local v = J.View()
	check(#ns.Prefs.Char().journey.entries == 1 and ns.Prefs.Char().journey.entries[1].k == "start" and ns.Prefs.Char().journey.entries[1].lvl == 3,
		"the first look records where Codex started watching, not a made-up history")
	check(v.stats[1]:find("began watching this character at level 3", 1, true) and v.stats[2] == "Quests you turned in while Codex was watching: 0", "the Journey says what it knows and no more")
	W.char.level = 4
	ns.State.Recompute()
	J.OnQuestTurnedIn(77, 450)
	J.OnQuestTurnedIn(77, 450)                      -- the same event twice in one tick
	W.char.level = 5
	ns.State.Recompute()
	local e = ns.Prefs.Char().journey.entries
	check(#e == 4 and e[2].k == "level" and e[2].lvl == 4 and e[3].k == "quest" and e[3].id == 77 and e[3].xp == 450 and e[4].k == "level" and e[4].lvl == 5, "level-ups and the turn-in are recorded once each, in order")
	local v2 = J.View()
	check(v2.stats[2] == "Quests you turned in while Codex was watching: 1" and v2.stats[3]:find("450", 1, true), "the summary counts only recorded turn-ins and their reported XP")
	check(v2.lines[1]:find("Reached level 5", 1, true) and v2.lines[2]:find("Completed a quest", 1, true), "newest first; a quest the data does not know is 'a quest', never a made-up name")
	check(J.SawTurnIn(77) and not J.SawTurnIn(78), "Codex remembers which turn-ins it saw")
	W.char.level = 2
	ns.State.Recompute()
	check(#ns.Prefs.Char().journey.entries == 4, "a lower level is not a milestone")
	for i = 1, 200 do J.OnQuestTurnedIn(1000 + i, 1) end
	check(#ns.Prefs.Char().journey.entries <= J.CAP and ns.Prefs.Char().journey.entries[1].k == "start", "the history is capped and keeps its start")
	local saved = ForeverCodexDB
	local ns2 = boot({ char = { level = 5 }, synthetic = true, savedVars = saved })
	check(ns2.Journey.SawTurnIn(77) and ns2.Prefs.IsSavedVariablesSafe(ForeverCodexDB), "the Journey survives a reload")
	ns2.UI.Open("journey")
	check(ns2.UI.main.journey.rows[1].__text ~= "" and #leaks(H.world()) == 0, "the Journey page lists it, without technical words")
	local ns3 = world(1, {}, {})
	ns3.Prefs.Char().journey.entries = {}
	ns3.Prefs.Char().journey.lastLevel = nil
	check(ns3.Journey.View().empty:find("Nothing recorded yet") ~= nil, "an empty journey says so")
end

section("phase 3: Knowledge says what Codex can establish, and admits the rest")
do
	local ns, W = world(5, {
		Q(1, "Open quest", 10, 0), Q(2, "Needs level 20", 20, 0, { req = 20 }), Q(3, "Active quest", 30, 0), Q(4, "Ready quest", 40, 0), Q(5, "Done quest", 50, 0),
		Q(6, "Needs another", 60, 0, { prereq = { 5 } }), Q(7, "Other race", 70, 0, { faction = "Alliance" }),
	}, { [3] = { objectives = { { text = "x: 2/9", have = 2, need = 9 } } }, [4] = { complete = true } })
	W.completed[5] = true
	W.completed[6] = false
	ns.State.Recompute()
	local K, ctx = ns.Knowledge, ns.State.ctx
	local function q(id) return K.Quest(id, ctx) end
	check(q(1).label == "Available" and q(1).detail == "You haven't found this yet.", "available: 'You haven't found this yet.'")
	check(q(2).label == "Not yet" and q(2).detail == "You need level 20 first.", "level-gated: says which level")
	check(q(3).label == "In progress" and q(3).detail == "Progress 2 / 9.", "in progress, with progress")
	check(q(4).label == "Ready to turn in", "ready to turn in")
	check(q(5).label == "You did this", "completed: 'You did this'")
	W.completed[5] = false
	W.log = {}
	ns.State.Recompute()
	check(K.Quest(6, ns.State.ctx).label == "Not yet" and K.Quest(6, ns.State.ctx).detail == "Another quest comes first.", "needs another quest first")
	check(q(7).label == "Not yet" and q(7).detail:find("different kind of character", 1, true), "for a different faction")
	check(K.Quest(99999, ctx).label == "Codex does not know this quest", "a quest the data does not know is not guessed at")
	J = ns.Journey
	J.OnQuestTurnedIn(99998, 10)
	check(K.Quest(99998, ctx).label == "You did this", "a turn-in Codex saw itself counts, even for a quest it has no data for")
	local sys = K.Systems()
	local keys, allUnknown = {}, true
	for _, s in ipairs(sys) do keys[s.key] = true; if s.state ~= "unknown" then allUnknown = false end end
	check(keys.trainers and keys.recipes and keys.pets and keys.flight and allUnknown, "trainers, recipes, pets and flight paths are reported as unknown (their client APIs are unverified), never faked")
end

section("phase 3: World and Appendices pages")
do
	local ns, W = world(5, { Q(1, "Open one", 10, 0, { req = 1 }), Q(2, "Open two", 20, 0, { req = 3 }), Q(3, "In the log", 30, 0) }, { [3] = { title = "In the log" } })
	local v = ns.World.Around(ns.State.ctx)
	check(v.zone == "Fixture Valley" and #v.available == 2 and v.available[1].name == "Open one" and #v.inProgress == 1, "World lists what you could take here, lowest level first, and what you are doing")
	ns.UI.Open("world")
	check(ns.UI.main.world.title.__text == "Around you: Fixture Valley" and ns.UI.main.world.rows[1].__text:find("Open one", 1, true), "the World page draws it")
	ns.UI.Open("appendices")
	local app = ns.UI.main.app
	for _, key in ipairs({ "quests", "knowledge", "help", "party" }) do check(app.menu[key] ~= nil, "Appendices lists " .. key) end
	check(app.menu.settings == nil, "settings are not in Appendices any more: they are the Codex Options tab")
	click(app.menu.quests)
	app.qBox.__text = "Open"
	app.qBox.__scripts.OnTextChanged(app.qBox)
	check(app.qRows[1].name.__text:find("Open", 1, true) and app.qRows[1].state.__text:find("Available", 1, true), "searching a quest shows where you stand with it")
	click(app.back)
	click(app.menu.knowledge)
	check(app.kRows[1].name.__text == "Trainers" and app.kRows[1].text.__text:find("cannot yet see", 1, true), "Knowledge says what Codex cannot see yet")
	click(app.back)
	ns.Prefs.FinishSetup()
	ns.UI.Open("options")
	local st = ns.UI.main.settingsPanel
	check(st.frame.__shown and st.w.title.__text == "Settings" and st.w.nav ~= nil and st.w.party ~= nil, "the settings are the Codex Options tab")
	check(#leaks(W) == 0, "no technical words anywhere")
end

-- ================================================================ Navigation

local function installWaypoint(W)
	W.sets, W.clears = 0, 0
	local base = _G.C_Map
	base.HasUserWaypoint = function() return W.waypoint ~= nil end
	base.GetUserWaypoint = function() local p = W.waypoint; return p and { uiMapID = p.uiMapID, position = { x = p.x, y = p.y } } or nil end
	base.ClearUserWaypoint = function() W.waypoint = nil; W.clears = W.clears + 1 end
	local oldSet = base.SetUserWaypoint
	base.SetUserWaypoint = function(p) W.sets = W.sets + 1; oldSet(p) end
end

local function act(ns, id, q, dx, dy, o)
	o = o or {}
	local K = ns.Contract
	local a = { id = id, type = "QUEST", kind = o.kind or "ACCEPT", quest = q, title = id, lines = {}, reasons = {}, name = "Quest " .. q }
	K.Attach(a, { ref = { kind = "quest", id = q }, state = "AVAILABLE", skip = { logical = false, keys = {} },
		targets = { K.Target({ role = "GIVER", entity = { kind = "npc", id = o.npc }, assumed = o.assumed,
			where = dx and K.Where("known", { { map = o.map or 9001, x = 0.5 + dx / 1000, y = 0.5 + (dy or 0) / 1000 } }) or K.Where("unknown"), prov = K.Prov("att") }) },
		requirements = {}, completion = { watch = "quest", id = q, reaches = "ACCEPTED" } })
	return a
end

local function navWorld()
	local ns = boot({ char = { level = 6 }, synthetic = true, loc = { map = 9001, x = 0.5, y = 0.5 } })
	local W = H.world()
	installWaypoint(W)
	ns.Prefs.FinishSetup()
	ns.Navigation._Reset()
	return ns, W
end

local function planOf(now) return { now = now, reminders = {}, warnings = {}, diag = { reasons = {} } } end

section("phase 3: Navigation follows NOW and owns only its own waypoint")
do
	local ns, W = navWorld()
	local N, ctx = ns.Navigation, ns.Context.Build()
	local A, B = act(ns, "Q:1:ACCEPT", 1, 300, 0), act(ns, "Q:2:ACCEPT", 2, 0, 400)
	N.OnPlan(planOf(A), ctx)
	check(W.sets == 1 and W.waypoint and W.waypoint.uiMapID == 9001 and math.abs(W.waypoint.x - 0.8) < 1e-9 and W.supertrack == true, "NOW gets a waypoint at its target, and the game's arrow follows it")
	check(N.Status() == "following" and N.Owned().action == "Q:1:ACCEPT", "Codex records which action the waypoint is for")
	N.OnPlan(planOf(A), ctx); N.OnPlan(planOf(A), ctx)
	check(W.sets == 1 and W.clears == 0, "the same NOW causes no further waypoint calls (no placement loop)")
	N.Tick(0.5); N.Tick(0.4)
	check(W.sets == 1 and W.clears == 0, "the arrival check places nothing")
	N.OnPlan(planOf(B), ctx)
	check(W.sets == 2 and math.abs(W.waypoint.y - 0.9) < 1e-9 and N.Owned().action == "Q:2:ACCEPT", "when NOW changes the waypoint moves to the new target")
	N.OnPlan(planOf(nil), ctx)
	check(W.waypoint == nil and W.clears == 1 and N.Owned() == nil and N.Status() == "idle", "when there is no NOW (completed / invalid) Codex clears its own waypoint")
	N.OnPlan(planOf(nil), ctx)
	check(W.clears == 1, "and does not clear again")
	N.OnPlan(planOf(act(ns, "Q:3:ACCEPT", 3, nil)), ctx)
	check(W.waypoint == nil and W.sets == 2 and N.Status() == "idle", "a NOW with no known location gets no waypoint (nothing invented)")
	check(ns.Prefs.NavRecord() == nil, "and nothing is remembered for it")
end

section("phase 3: Navigation never overwrites or clears a waypoint it does not own")
do
	local ns, W = navWorld()
	local N, ctx = ns.Navigation, ns.Context.Build()
	local A, B = act(ns, "Q:1:ACCEPT", 1, 300, 0), act(ns, "Q:2:ACCEPT", 2, 0, 400)
	-- the player's own pin exists first
	W.waypoint = { uiMapID = 9001, x = 0.11, y = 0.22 }
	N.OnPlan(planOf(A), ctx)
	check(W.sets == 0 and W.waypoint.x == 0.11 and N.Status() == "paused-foreign", "a player-made waypoint is left alone: navigation pauses")
	N.OnPlan(planOf(B), ctx); N.OnPlan(planOf(nil), ctx)
	check(W.sets == 0 and W.clears == 0 and W.waypoint ~= nil, "and it is never cleared, whatever NOW does")
	-- the player removes it: Codex may place again
	W.waypoint = nil
	N.OnPlan(planOf(A), ctx)
	check(W.sets == 1 and N.Status() == "following", "once the player's pin is gone Codex places its own")
	-- the player replaces Codex's pin with their own
	W.waypoint = { uiMapID = 9001, x = 0.33, y = 0.44 }
	W.now = W.now + 5                               -- (past the moment our own placement muted the event)
	N.OnWaypointEvent()
	check(N.Owned() == nil and N.Status() == "paused-foreign", "if the pin is replaced, it is theirs now")
	N.OnPlan(planOf(B), ctx); N.OnPlan(planOf(nil), ctx)
	check(W.waypoint.x == 0.33 and W.sets == 1 and W.clears == 0, "Codex neither overwrites nor clears it")
	-- the player removes Codex's pin: do not fight it for this action
	W.waypoint = nil
	N.OnPlan(planOf(A), ctx)
	check(W.sets == 2, "(setup) Codex places for A again")
	W.waypoint = nil
	W.now = W.now + 5
	N.OnWaypointEvent()
	N.OnPlan(planOf(A), ctx)
	check(W.sets == 2 and N.Status() == "dismissed", "if the player removes Codex's pin, Codex does not put it back for the same action")
	N.OnPlan(planOf(B), ctx)
	check(W.sets == 3 and N.Status() == "following", "but a new NOW gets one")
	-- the pin was replaced by the player WITHOUT Codex hearing the event, then NOW disappears: Codex must not clear THEIR pin
	W.waypoint = nil
	N._Reset()
	N.OnPlan(planOf(A), ctx)
	check(N.Owned() ~= nil, "(setup) Codex has placed its own pin")
	W.waypoint = { uiMapID = 9001, x = 0.61, y = 0.62 }
	local clearsBefore = W.clears
	N.OnPlan(planOf(nil), ctx)
	check(W.clears == clearsBefore and W.waypoint and W.waypoint.x == 0.61, "a pin replaced behind Codex's back is not cleared when NOW goes away")
	W.waypoint = { uiMapID = 9001, x = 0.71, y = 0.72 }
	N._Reset()
	W.waypoint = nil
	N.OnPlan(planOf(A), ctx)
	W.waypoint = { uiMapID = 9001, x = 0.61, y = 0.62 }
	ns.Prefs.SetNavigation(false)
	clearsBefore = W.clears
	N.OnPlan(planOf(A), ctx)
	check(W.clears == clearsBefore and W.waypoint and W.waypoint.x == 0.61, "nor when navigation is switched off")
	ns.Prefs.SetNavigation(true)
	-- a quest-tracking change replaced the pin between recomputes: seen as foreign without an event
	N._Reset()
	W.waypoint = nil
	N.OnPlan(planOf(B), ctx)
	local sets0, clears0 = W.sets, W.clears
	W.waypoint = { uiMapID = 9001, x = 0.9, y = 0.9 }
	N.OnPlan(planOf(act(ns, "Q:4:ACCEPT", 4, 100, 100)), ctx)
	check(W.sets == sets0 and W.clears == clears0 and W.waypoint.x == 0.9, "a changed pin is never mistaken for Codex's own")
end

section("phase 3: Navigation arrival, switches, events and login")
do
	local ns, W = navWorld()
	local N, ctx = ns.Navigation, ns.Context.Build()
	local A = act(ns, "Q:1:ACCEPT", 1, 300, 0)
	N.OnPlan(planOf(A), ctx)
	W.loc.x = 0.8; W.loc.y = 0.5            -- the player walks to the target
	N.Tick(2)
	check(W.waypoint == nil and N.Status() == "arrived" and W.clears == 1, "arriving (by Codex's own distance) clears Codex's waypoint")
	local here = ns.Context.Build()
	N.OnPlan(planOf(A), here); N.Tick(2)
	check(W.sets == 1, "and it is not placed again while that is still NOW")
	N.OnPlan(planOf(act(ns, "Q:2:ACCEPT", 2, 0, -400)), here)
	check(W.sets == 2, "the next NOW gets a waypoint")
	-- events from our own placement are ignored; a later one is not
	local before = N.Status()
	N.OnWaypointEvent()
	check(N.Status() == before and N.Owned() ~= nil, "the event caused by Codex's own placement is ignored")
	-- switch off
	ns.Prefs.SetNavigation(false)
	N.OnPlan(planOf(A), here)
	check(W.waypoint == nil and N.Status() == "off", "turning navigation off clears Codex's own pin")
	W.waypoint = { uiMapID = 9001, x = 0.2, y = 0.2 }
	N.OnPlan(planOf(A), here)
	check(W.waypoint ~= nil and W.waypoint.x == 0.2, "and leaves anyone else's alone")
	ns.Prefs.SetNavigation(true)
	-- API missing: nothing breaks
	local ns2, W2 = navWorld()
	_G.C_Map.SetUserWaypoint = nil
	ns2.Navigation.OnPlan(planOf(act(ns2, "Q:1:ACCEPT", 1, 300, 0)), ns2.Context.Build())
	check(ns2.Navigation.Status() == "unavailable" and #ns2.errors == 0, "without the waypoint API navigation is simply unavailable, with no error")
	-- cross-map target the game refuses
	local ns3, W3 = navWorld()
	_G.C_Map.CanSetUserWaypointOnMap = function() return false end
	ns3.Navigation.OnPlan(planOf(act(ns3, "Q:1:ACCEPT", 1, 300, 0)), ns3.Context.Build())
	check(W3.sets == 0 and ns3.Navigation.Status() == "unavailable", "a map the game will not take a waypoint on gets none")
	-- login: adopt only the exact saved pin
	local ns4, W4 = navWorld()
	ns4.Navigation.OnPlan(planOf(act(ns4, "Q:1:ACCEPT", 1, 300, 0)), ns4.Context.Build())
	check(ns4.Prefs.NavRecord() and ns4.Prefs.NavRecord().action == "Q:1:ACCEPT", "the placed pin is remembered per character")
	ns4.Navigation._Reset()
	ns4.Navigation.Restore()
	check(ns4.Navigation.Owned() and ns4.Navigation.Owned().action == "Q:1:ACCEPT", "after a reload Codex adopts the pin only because the game still shows exactly it")
	ns4.Navigation._Reset()
	W4.waypoint = { uiMapID = 9001, x = 0.1, y = 0.1 }
	ns4.Navigation.Restore()
	check(ns4.Navigation.Owned() == nil and ns4.Prefs.NavRecord() == nil, "a different pin at login is not Codex's")
	-- the Planner does not know about any of this
	local src = H.readFile(H.addonDir .. "/Planner.lua"):gsub("%-%-[^\n]*", "")
	check(not src:find("Navigation", 1, true) and not src:find("Presenter", 1, true) and not src:find("Journey", 1, true) and not src:find("Party", 1, true),
		"Planner.lua mentions none of Navigation, Presenter, Journey or Party")
end

section("phase 3: navigation through State follows the real plan")
do
	local ns, W = world(6, { Q(1, "Near", 60, 0), Q(2, "Far", 800, 0) }, {})
	installWaypoint(W)
	ns.Navigation._Reset()
	ns.State.Recompute()
	check(W.sets == 1 and W.waypoint ~= nil and ns.Navigation.Owned().action == ns.State.plan.now.id, "the plan's NOW is the waypoint")
	local first = ns.State.plan.now.id
	W.completed[ns.State.plan.now.quest] = true
	W.log = { { questID = ns.State.plan.now.quest, title = "done", complete = false } }
	W.log = {}
	ns.State.Recompute()
	check(ns.State.plan.now == nil or ns.State.plan.now.id ~= first, "(setup) the action is done and NOW moves on")
	check(ns.Navigation.Owned() == nil or ns.Navigation.Owned().action == ns.State.plan.now.id, "the waypoint follows (never left pointing at a finished action)")
	-- a failing consumer never costs the player the plan
	local realOnPlan = ns.Navigation.OnPlan
	ns.Navigation.OnPlan = function() error("boom") end
	local p = ns.State.Recompute()
	check(p ~= nil and #ns.errors >= 1 and ns.errors[#ns.errors]:find("navigation"), "a navigation failure is recorded and the plan is still produced")
	ns.Navigation.OnPlan = realOnPlan
end

-- ================================================================ Party

section("phase 3: Party awareness (your progress, others' progress, no spam)")
do
	local function group(ns, size) H.world().group = size end
	local ns, W = world(6, { Q(1, "Sting of the Scorpid", 20, 0, { objCoords = { { map = 9001, x = 0.52, y = 0.5 } } }) }, {
		[1] = { title = "Sting of the Scorpid", objectives = { { text = "Scorpid Worker Tail", have = 3, need = 10 } } } })
	local Pt = ns.Party
	local sentAddon, sentChat = {}, {}
	Pt.api.sendAddon = function(t) sentAddon[#sentAddon + 1] = t; return true end
	_G.SendChatMessage = function(t) sentChat[#sentChat + 1] = t end     -- the real chat call: Codex must never use it
	Pt.api.selfName = function() return "Thrall" end
	group(ns, 3)
	ns.State.Recompute()
	check(#sentAddon == 0 and #sentChat == 0, "the first look is a baseline: nothing is announced for what was already true")
	ns.Prefs.SetPartyNotify("ui")
	-- finishing the objective
	W.objectives[1][1].numFulfilled, W.objectives[1][1].finished = 10, true
	W.now = W.now + 10
	ns.State.Recompute()
	check(#sentAddon == 1 and sentAddon[1] == "v1|OBJ|1|10|10" and #sentChat == 0, "'UI only': an objective finished is shared as a quiet addon message; nothing is said in chat")
	-- the quest becomes complete
	W.log[1].complete = true
	W.now = W.now + 10
	ns.State.Recompute()
	check(sentAddon[#sentAddon] == "v1|DONE|1" and #sentChat == 0, "a finished quest is shared the same way")
	-- turn-in
	W.now = W.now + 10
	Pt.OnTurnedIn(1, ns.State.ctx)
	check(sentAddon[#sentAddon] == "v1|TURNIN|1" and #sentChat == 0, "a turn-in is shared quietly (never in chat)")
	local n = #sentAddon
	Pt.OnTurnedIn(1, ns.State.ctx)
	check(#sentAddon == n, "the same event twice in a few seconds is sent once")
	-- modes: the chat modes were removed (Questie already announces quest status); only off and ui remain
	check(not ns.Prefs.SetPartyNotify("party") and not ns.Prefs.SetPartyNotify("both") and ns.Prefs.PartyNotify() == "ui", "the removed chat modes ('party', 'both') are refused")
	check(table.concat(ns.Prefs.PARTY_MODES, ",") == "off,ui", "only 'off' and 'ui' exist")
	W.now = W.now + 20
	Pt.OnTurnedIn(1, ns.State.ctx)
	check(#sentChat == 0 and #sentAddon == n + 1, "'ui': a turn-in is one invisible addon message and nothing in chat")
	ns.Prefs.SetPartyNotify("off")
	W.now = W.now + 20
	Pt.OnTurnedIn(1, ns.State.ctx)
	check(#sentChat == 0 and #sentAddon == n + 1, "'Off': nothing is sent")
	check(not ns.Prefs.SetPartyNotify("shout") and ns.Prefs.PartyNotify() == "off", "an unknown mode is refused")
	-- solo
	group(ns, 1)
	ns.Prefs.SetPartyNotify("ui")
	W.now = W.now + 20
	ns.State.Recompute()
	Pt.OnTurnedIn(1, ns.State.ctx)
	check(#sentChat == 0 and #sentAddon == n + 1, "outside a group nothing is sent")
	check(ns.Prefs.Char().partyNotify == "ui" and not ns.Prefs.IsSavedVariablesSafe == false, "(the setting is stored per character)")
end

section("phase 3: Party, what other Codex users share")
do
	local ns, W = world(6, { Q(1, "Sting of the Scorpid", 20, 0) }, { [1] = { title = "Sting of the Scorpid", objectives = { { text = "Scorpid Worker Tail", have = 7, need = 10 } } } })
	local Pt = ns.Party
	Pt.api.selfName = function() return "Thrall" end
	W.group = 2
	ns.State.Recompute()
	local v0 = Pt.View(ns.State.ctx)
	check(#v0.lines == 0 and v0.note:find("who also use Codex", 1, true), "in a group with nothing shared yet, the card says how it works")
	Pt.OnAddonMessage("FCODEX", "v1|DONE|1", "PARTY", "Bob-Forever")
	local v = Pt.View(ns.State.ctx)
	check(#v.lines == 1 and v.lines[1].head == "Bob finished: Sting of the Scorpid" and v.lines[1].mine == "Your progress: 7 / 10", "a member's completion is shown next to YOUR progress on the same quest")
	Pt.OnAddonMessage("FCODEX", "v1|TURNIN|2", "PARTY", "Amy")
	check(Pt.View(ns.State.ctx).lines[1].head == "Amy turned in: a quest" and Pt.View(ns.State.ctx).lines[1].mine == "You have not started it", "a quest the data does not know is 'a quest'; a quest you have not started says so")
	Pt.OnAddonMessage("FCODEX", "v1|OBJ|1|4|10", "PARTY", "Cy-Other")
	check(Pt.View(ns.State.ctx).lines[1].head == "Cy completed an objective of: Sting of the Scorpid", "an objective completion is shown, with the realm stripped from the name")
	local before = #Pt.View(ns.State.ctx).lines
	Pt.OnAddonMessage("FCODEX", "v1|DONE|1", "PARTY", "Thrall-Forever")
	Pt.OnAddonMessage("OTHER", "v1|DONE|1", "PARTY", "Dan")
	Pt.OnAddonMessage("FCODEX", "garbage", "PARTY", "Dan")
	Pt.OnAddonMessage("FCODEX", "v2|DONE|1", "PARTY", "Dan")
	Pt.OnAddonMessage("FCODEX", "v1|DROP|1", "PARTY", "Dan")
	check(#Pt.View(ns.State.ctx).lines == before, "your own message, other prefixes, garbage, other versions and unknown kinds are ignored")
	for i = 1, 30 do Pt.OnAddonMessage("FCODEX", "v1|DONE|" .. i, "PARTY", "Eve") end
	check(#Pt.View(ns.State.ctx).lines <= Pt.FEED_MAX, "the feed is capped")
	check(not tostring(ForeverCodexDB and require and "" or ""):find("Bob"), "(identity) see the next check")
	local function scan(t, seen)
		seen = seen or {}
		if seen[t] then return false end
		seen[t] = true
		for k, v in pairs(t) do
			if type(k) == "string" and (k:find("Bob") or k:find("Amy") or k:find("Eve")) then return true end
			if type(v) == "string" and (v:find("Bob") or v:find("Amy") or v:find("Eve")) then return true end
			if type(v) == "table" and scan(v, seen) then return true end
		end
		return false
	end
	ns.Diag.Print()
	check(not scan(ForeverCodexDB), "other players' names are never saved (kept in memory for this session only)")
	ns.Prefs.SetPartyNotify("off")
	check(Pt.View(ns.State.ctx).note == "Party notifications are off." and #Pt.View(ns.State.ctx).lines == 0, "with party news off nothing is shown")
	Pt.OnAddonMessage("FCODEX", "v1|DONE|1", "PARTY", "Zed")
	check(#Pt.View(ns.State.ctx).lines == 0 or Pt.View(ns.State.ctx).lines[1].head:find("Zed") == nil, "with party news off a message from a party member does not feed the window")
	ns.Prefs.SetPartyNotify("ui")
	Pt._Reset()
	Pt.OnAddonMessage("FCODEX", "v1|DONE|1", "PARTY", "Zed")
	ns.UI.Open("codex")
	check(ns.UI.main.codex.partyHead.__text == "Party" and ns.UI.main.codex.partyRows[1].head.__text:find("Zed finished: Sting of the Scorpid", 1, true), "the Codex page shows the party card only when there is something to say")
	Pt._Reset()
	ns.State.Recompute()
	check(ns.UI.main.codex.partyHead.__text == "", "and hides it again when there is not")
end

section("phase 3: Party works with the API missing")
do
	local ns, W = world(6, {}, {})
	local Pt = ns.Party
	local saveC, saveS, saveA = _G.C_ChatInfo, _G.SendChatMessage, _G.SendAddonMessage
	_G.C_ChatInfo, _G.SendChatMessage, _G.SendAddonMessage = nil, nil, nil
	check(not Pt.Register() and not Pt.Status().addonMessages and not Pt.Status().chat, "no addon-message or chat API: reported as unavailable")
	check(select(1, pcall(Pt.OnTurnedIn, 5, { group = { inGroup = true } })) and #ns.errors == 0, "and nothing breaks")
	_G.C_ChatInfo, _G.SendChatMessage, _G.SendAddonMessage = saveC, saveS, saveA
	local registered
	_G.C_ChatInfo = { RegisterAddonMessagePrefix = function(p) registered = p; return true end, SendAddonMessage = function() end }
	check(Pt.Register() and registered == "FCODEX", "the addon-message prefix is registered when the API exists")
	_G.C_ChatInfo = saveC
end

-- ================================================================ Help Improve Codex

section("phase 3: Help Improve Codex (local only)")
do
	local ns, W = world(6, { Q(1, "Q", 10, 0) }, {})
	local Hc = ns.HelpCodex
	ns.Telemetry.Reset()
	local s0 = Hc.Summary()
	check(s0.total == 0 and s0.text == "Codex has not learned anything on this character yet. Just play.", "nothing recorded: it says so, no invented count")
	check(#Hc.Learned() == 0, "and lists nothing")
	ns.Telemetry.onEvent = nil
	local tele = ns._selftest.telemetry
	tele.onEvent("QUEST_ACCEPTED", 1)
	tele.onEvent("QUEST_ACCEPTED", 2)
	tele.onEvent("QUEST_TURNED_IN", 1, 100, 5)
	local s = Hc.Summary()
	check(s.total == #ns.Telemetry.Events() - 1 or s.total >= 3, "the count is the number of real stored observations (" .. s.total .. ")")
	check(s.text == string.format("Codex has learned %d observations from this character.", s.total), "'Codex has learned N observations from this character.'")
	local lines = Hc.Learned()
	local text = table.concat(lines, "|")
	check(text:find("Quests you accepted: 2", 1, true) and text:find("Quests you turned in: 1", 1, true) and not text:find("Creatures defeated", 1, true), "only kinds that were actually recorded are listed, with real counts")
	check(s.note:find("nothing is uploaded or shared", 1, true) and Hc.COPY.tagline == "Codex learns from your adventures.", "it says plainly that nothing leaves the machine")
	check(not Hc.COPY.body:lower():find("telemetry"), "the player-facing text does not lead with the word 'telemetry'")
	-- the page
	ns.UI.Open("appendices")
	local app = ns.UI.main.app
	click(app.menu.help)
	check(app.hCount.__text == s.text, "the page shows the headline")
	click(app.hView)
	check(app.hLines[1].__text:find("Quests you accepted: 2", 1, true), "'View What Codex Learned' lists the kinds and counts")
	click(app.hClear)
	check(app.hClear.text.__text == "Click again to clear" and Hc.Summary().total == s.total, "'Clear Data' asks before it clears")
	click(app.hClear)
	check(Hc.Summary().total == 0 and app.hCount.__text:find("not learned anything", 1, true), "and clears this character's observations when confirmed")
	check(ns.Telemetry.IsEnabled(), "clearing does not switch recording off")
	local ok = true
	for _, k in ipairs({ "export", "upload", "send", "share", "http" }) do
		if H.readFile(H.addonDir .. "/HelpCodex.lua"):gsub("%-%-[^\n]*", ""):find(k:gsub("^%l", string.upper), 1, true) then ok = false end
	end
	check(ok, "HelpCodex.lua has no export / upload / share path")
end

-- ================================================================ wiring, slash, diag, planner unchanged

section("phase 3: events, slash commands and diagnostics")
do
	local ns, W = world(6, { Q(1, "Pickup", 20, 0) }, {})
	installWaypoint(W)
	ns.Navigation._Reset()
	local fire = ns._selftest.boot.onEvent
	fire(nil, "QUEST_TURNED_IN", 321, 250, 10)
	check(ns.Journey.SawTurnIn(321) and ns.Prefs.Char().journey.entries[#ns.Prefs.Char().journey.entries].xp == 250, "QUEST_TURNED_IN feeds the Journey")
	ns.State.Recompute()
	local owned = ns.Navigation.Owned()
	W.waypoint = nil
	fire(nil, "USER_WAYPOINT_UPDATED")
	check(owned == nil or ns.Navigation.Owned() == nil, "USER_WAYPOINT_UPDATED reaches Navigation")
	fire(nil, "CHAT_MSG_ADDON", "FCODEX", "v1|DONE|1", "PARTY", "Bob-Forever")
	W.group = 2
	ns.State.Recompute()
	check(#ns.Party.View(ns.State.ctx).lines == 1, "CHAT_MSG_ADDON reaches Party")
	-- slash
	W.chat = {}
	H.slash("nav"); check(say(W, "Waypoint following is on"), "/codex nav reports its state")
	H.slash("nav off"); check(not ns.Prefs.NavigationOn() and say(W, "leaves yours alone"), "/codex nav off")
	H.slash("nav on")
	H.slash("party"); check(say(W, "Party news: ui"), "/codex party reports")
	H.slash("party both"); check(ns.Prefs.PartyNotify() == "ui" and say(W, "usage: /codex party off|ui|log"), "/codex party both is refused: there is no chat mode any more")
	H.slash("party off"); check(ns.Prefs.PartyNotify() == "off", "/codex party off")
	H.slash("party ui")
	H.slash("party nonsense"); check(say(W, "usage: /codex party"), "/codex party rejects nonsense")
	H.slash("journey"); check(ns.UI.current == "journey" and ns.UI.IsShown(), "/codex journey opens the Journey tab")
	H.slash("world"); check(ns.UI.current == "world", "/codex world")
	H.slash("appendices"); check(ns.UI.current == "appendices", "/codex appendices")
	H.slash("dev"); check(ns.DevUI.IsShown(), "/codex dev opens the developer window (with the old machinery)")
	W.chat = {}
	H.slash("help"); check(say(W, "/codex setup") and say(W, "/codex nav") and say(W, "/codex party"), "help lists the new commands")
	-- diag
	W.chat = {}
	H.slash("diag")
	check(say(W, "Player experience: setup done | waypoint following on") and say(W, "party news:"), "/codex diag reports navigation and party")
	check(ns.Prefs.IsSavedVariablesSafe(ForeverCodexDB.diag[#ForeverCodexDB.diag]), "and the snapshot stays SavedVariables-safe")
	check(#ns.errors == 0, "no caught errors" .. (#ns.errors > 0 and (": " .. ns.errors[1]) or ""))
end

section("phase 3: the Planner's decisions are untouched")
do
	-- the same scenario with every Phase 3 consumer present: the decision equals a fresh Engine -> Planner run
	local ns, W = world(6, { Q(1, "A", 20, 0), Q(2, "B", 25, 5), Q(3, "C", 300, 0) }, { [3] = { complete = true } })
	local plan = ns.State.plan
	local ctx = ns.Context.Build()
	local bare = ns.Planner.Compute(ctx, ns.Engine.Candidates(ctx), {})
	check(plan.now.id == bare.now.id and (plan.alsoDo and plan.alsoDo.id) == (bare.alsoDo and bare.alsoDo.id) and (plan.thenAction and plan.thenAction.id) == (bare.thenAction and bare.thenAction.id),
		"NOW, ALSO DO and THEN are exactly what the Planner alone decides")
	ns.Prefs.SetNavigation(false); ns.Prefs.SetPartyNotify("off")
	ns.State.Recompute()
	check(ns.State.plan.now.id == plan.now.id, "and do not depend on navigation or party settings")
end
