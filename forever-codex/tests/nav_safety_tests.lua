-- nav_safety_tests.lua: Fix 4 (0.7.1) navigation safety. The waypoint and the arrow are straight lines with no path, portal or transport knowledge, so Codex only points at a
-- destination it can measure and that is sensible to walk toward. Stub-client tests of Codex's own policy; they say nothing about the real client's terrain.

local H = ...
local check, section, boot = H.check, H.section, H.boot

local function rec(id, name, x, y, o)
	local q = { id = id, name = name, map = 9001, x = x, y = y, req = 1 }
	for k, v in pairs(o or {}) do q[k] = v end
	return q
end

local function installWaypoint(W)
	W.sets, W.clears = 0, 0
	local base = _G.C_Map
	base.HasUserWaypoint = function() return W.waypoint ~= nil end
	base.GetUserWaypoint = function() local p = W.waypoint; return p and { uiMapID = p.uiMapID, position = { x = p.x, y = p.y } } or nil end
	base.ClearUserWaypoint = function() W.waypoint = nil; W.clears = W.clears + 1 end
	local oldSet = base.SetUserWaypoint
	base.SetUserWaypoint = function(p) W.sets = W.sets + 1; oldSet(p) end
end
--- Player at (px, py) on `map` (default the 1000 yd fixture map 9001); quests in the restriction-carrying fixture pack; a quest log as in guidance_tests.
local function world(quests, log, at)
	at = at or { map = 9001, x = 0.5, y = 0.5 }
	local ns = boot({ char = { level = 10 }, synthetic = true, loc = { map = at.map, x = at.x, y = at.y, zone = "Fixture" } })
	H.attPack(ns, quests, { { key = "zone-a", label = "Zone A", map = 9001, quests = #quests } })
	local W = H.world()
	W.log, W.objectives = {}, {}
	for id, e in pairs(log or {}) do
		W.log[#W.log + 1] = { questID = id, title = e.title or ("quest " .. id), complete = e.complete == true }
		if e.objectives then
			W.objectives[id] = {}
			for i, ob in ipairs(e.objectives) do W.objectives[id][i] = { text = ob.text, type = "event", finished = false, numFulfilled = ob.have or 0, numRequired = ob.need or 1 } end
		end
	end
	installWaypoint(W)
	ns.Prefs.FinishSetup()
	ns.Prefs.SetNavigation(true)
	ns.Navigation._Reset()
	ns.State.Recompute()
	return ns, W
end
local function card(ns) return ns.Presenter.Card(ns.State.plan, ns.State.ctx) end

section("navigation safety: a trustworthy local destination still gets its waypoint and arrow")
do
	local ns, W = world({ rec(1, "Near Pickup", 0.6, 0.5) })
	check(ns.State.plan.now and ns.State.plan.now.id == "Q:1:ACCEPT", "(setup) NOW is the near pickup (100 yd, an exact NPC coordinate)")
	check(ns.Navigation.Target() ~= nil and ns.Navigation.Target().action == "Q:1:ACCEPT" and W.sets >= 1, "the arrow has a target and the waypoint was placed")
	check(ns.Navigation.NoPin() == nil and card(ns).now.navNote == nil, "and there is no 'no arrow' note")
	local as = ns.Navigation.Assess(ns.State.plan.now, ns.State.ctx)
	check(as.pin == true and as.reason == nil and as.straight == nil and math.abs(as.distance - 100) < 1, "the assessment: pin, measured 100 yd, no caveat")
end

section("navigation safety: an unmeasured destination never gets an arrow")
do
	local ns, W = world({ rec(1, "Elsewhere", 0.6, 0.5) }, nil, { map = 7777, x = 0.5, y = 0.5 })      -- a map Codex cannot convert: the leg is unknown
	local act
	for _, c in ipairs(ns.Engine.Candidates(ns.Context.Build()).candidates) do if c.id == "Q:1:ACCEPT" then act = c end end
	check(act ~= nil, "(setup) the candidate exists")
	local as = ns.Navigation.Assess(act, ns.State.ctx)
	check(as.pin == false and as.reason == "UNMEASURED" and as.text:find("no arrow", 1, true), "Assess: UNMEASURED, with a player-facing reason")
	check(ns.Navigation.Target() == nil and W.sets == 0, "no target and no waypoint")
	-- no player position at all is unmeasured too
	local ns2 = world({ rec(1, "Elsewhere", 0.6, 0.5) })
	ns2.State.ctx.loc = { available = false }
	check(ns2.Navigation.Assess(act, ns2.State.ctx).reason == "UNMEASURED", "a missing player position cannot measure anything")
end

section("navigation safety: an approximate destination is pointed at only when it is not far")
do
	local near = { rec(2, "Objective", 0.5, 0.5, { objCoords = { { map = 9001, x = 0.7, y = 0.5 } } }) }
	local nsN, WN = world(near, { [2] = { title = "Objective", objectives = { { text = "Kill boars", have = 0, need = 5 } } } })
	check(nsN.State.plan.now and nsN.State.plan.now.id == "Q:2:OBJECTIVE" and nsN.Navigation.Target() ~= nil, "an objective area 200 yd away gets the arrow")
	local far = { rec(2, "Objective", 0.5, 0.5, { objCoords = { { map = 9001, x = 0.99, y = 0.99 } } }) }
	local nsF, WF = world(far, { [2] = { title = "Objective", objectives = { { text = "Kill boars", have = 0, need = 5 } } } }, { map = 9001, x = 0.01, y = 0.01 })
	local as = nsF.Navigation.Assess(nsF.State.plan.now, nsF.State.ctx)
	check(as.pin == false and as.reason == "APPROX_FAR" and nsF.Navigation.Target() == nil and WF.sets == 0, "an objective area about 1,380 yd away: no arrow, no waypoint (APPROX_FAR)")
	check(nsF.Navigation.NoPin() and nsF.Navigation.NoPin().reason == "APPROX_FAR", "the report can say why")
	local c = card(nsF)
	check(c.now.navNote and c.now.navNote:find("no arrow", 1, true) and c.now.title == "Finish Objective" and c.now.objectives[1].text == "Kill boars", "the card still shows the quest and its objective, with the reason")
end

section("navigation safety: an observed-pack PLAYER position is not an NPC coordinate: only a short distance")
do
	local function obsWorld(x)
		local ns = boot({ char = { level = 10 }, synthetic = true, loc = { map = 9001, x = 0.5, y = 0.5, zone = "Fixture" } })
		H.attPack(ns, {}, { { key = "zone-a", label = "Zone A", map = 9001, quests = 0 } })
		ForeverCodex.RegisterPack("quests", "observed:t", { meta = { src = "observed", verified = true, priority = 100 }, zones = {}, quests = {
			[600] = { id = 600, name = "Observed Turn-in", level = 2, objectives = { "" }, giverNpc = 1, giverName = "Somebody", turnIn = { npc = 1, atGiver = true }, pos = { map = 9001, x = x, y = 0.5 } } } })
		ns.Prefs.FinishSetup(); ns.Prefs.SetNavigation(true); ns.Navigation._Reset()
		H.world().log = { { questID = 600, title = "Observed Turn-in", complete = true } }
		ns.State.Recompute()
		return ns
	end
	local near, far = obsWorld(0.58), obsWorld(0.9)
	check(near.State.plan.now and near.Navigation.Target() ~= nil, "80 yd from where the recorder stood: the arrow is allowed (the last steps are visible)")
	check(far.State.plan.now and far.Navigation.Target() == nil and far.Navigation.NoPin() and far.Navigation.NoPin().reason == "PLAYER_POSITION_FAR", "400 yd away: no arrow (PLAYER_POSITION_FAR)")
end

section("navigation safety: a far quest whose own text names special travel gets the text, not a walking arrow")
do
	local q = { rec(3, "The Earthen Ring", 0.5, 0.5, { objCoords = { { map = 9001, x = 0.99, y = 0.5 } } }) }
	local ns, W = world(q, { [3] = { title = "The Earthen Ring", objectives = { { text = "Take the Skycutter to Thunder Totem", have = 0, need = 1 } } } }, { map = 9001, x = 0.4, y = 0.5 })
	local as = ns.Navigation.Assess(ns.State.plan.now, ns.State.ctx)
	check(ns.State.plan.now and as.pin == false and as.reason == "SPECIAL_TRAVEL" and ns.Navigation.Target() == nil and W.sets == 0, "special travel: no arrow and no waypoint  [" .. tostring(as.reason) .. "]")
	local c = card(ns)
	check(c.now.objectives[1].text == "Take the Skycutter to Thunder Totem" and c.now.navNote:find("special travel", 1, true), "the quest's own words are shown, with the note")
	-- the same words with the target close by: walk
	local ns2 = world({ rec(3, "The Earthen Ring", 0.5, 0.5, { objCoords = { { map = 9001, x = 0.6, y = 0.5 } } }) }, { [3] = { title = "The Earthen Ring", objectives = { { text = "Speak with the Zeppelin Master", have = 0, need = 1 } } } })
	check(ns2.Navigation.Target() ~= nil, "a vehicle word with the target 100 yd away does not stop the arrow")
	check(ns.Navigation.TravelWord({ objectiveState = { list = { { text = "Shipping crates collected", finished = false } } } }) == nil and ns.Navigation.TravelWord({ objectiveState = { list = { { text = "Board the ship", finished = true } } } }) == nil,
		"whole words only, and a finished objective's text does not count")
end

section("navigation safety: a long exact destination is pointed at but labelled straight-line only; too far is not pointed at")
do
	local ns = boot({ char = { level = 10 }, synthetic = true, loc = { map = 9001, x = 0.9, y = 0.5, zone = "Fixture" } })
	H.attPack(ns, { { id = 5, name = "Far Hub", map = 9002, x = 0.0, y = 0.5, req = 1 } }, { { key = "zone-a", label = "A", map = 9001, quests = 0 }, { key = "zone-b", label = "B", map = 9002, quests = 1 } })
	ns.Prefs.FinishSetup(); ns.Prefs.SetNavigation(true); ns.Navigation._Reset()
	ns.State.Recompute()
	local act
	for _, c in ipairs(ns.Engine.Candidates(ns.Context.Build()).candidates) do if c.id == "Q:5:ACCEPT" then act = c end end
	local as = ns.Navigation.Assess(act, ns.State.ctx)
	check(act and as.pin == true and as.straight == true and as.text:find("Straight line only", 1, true) and math.abs(as.distance - 2100) < 5, "2,100 yd away: a pin with the straight-line label  [" .. tostring(as.distance) .. "]")
	local ns2 = boot({ char = { level = 10 }, synthetic = true, loc = { map = 9001, x = 0.1, y = 0.5, zone = "Fixture" } })
	H.attPack(ns2, { { id = 5, name = "Far Hub", map = 9002, x = 0.5, y = 0.5, req = 1 } }, { { key = "zone-a", label = "A", map = 9001, quests = 0 }, { key = "zone-b", label = "B", map = 9002, quests = 1 } })
	ns2.State.Recompute()
	local act2
	for _, c in ipairs(ns2.Engine.Candidates(ns2.Context.Build()).candidates) do if c.id == "Q:5:ACCEPT" then act2 = c end end
	check(ns2.Navigation.Assess(act2, ns2.State.ctx).pin == false, "beyond 2,500 yd a straight line means nothing: no pin")
end

section("navigation safety: it is a general policy (no quest id or name in Navigation), and flight / travel behaviour is untouched")
do
	local src = H.readFile(H.addonDir .. "/Navigation.lua")
	check(not src:find("Lorthuna", 1, true) and not src:find("Earthen", 1, true) and not src:find("%f[%d]9%d%d%d%d%f[%D]"), "no quest name or quest id appears in Navigation.lua")
	local ns = world({ rec(1, "Near", 0.6, 0.5) })
	check(#ns.errors == 0, "no errors")
end

section("NOW guidance when the arrow is withheld (audit M5): a compass direction and a rounded distance, never a coordinate, and the arrow stays withheld")
do
	local ns0 = boot({ char = { level = 10 }, synthetic = true })
	local C = ns0.Navigation.Compass
	check(C(0) == "north" and C(math.pi / 2) == "east" and C(math.pi) == "south" and C(-math.pi / 2) == "west" and C(math.pi / 4) == "north-east" and C(-3 * math.pi / 4) == "south-west" and C(2 * math.pi) == "north", "the compass words")
	check(C(nil) == nil and C(0 / 0) == nil, "junk gives no direction")
	local far = { rec(2, "Objective", 0.5, 0.5, { objCoords = { { map = 9001, x = 0.99, y = 0.99 } } }) }
	local ns, W = world(far, { [2] = { title = "Objective", objectives = { { text = "Kill boars", have = 0, need = 5 } } } }, { map = 9001, x = 0.01, y = 0.01 })
	local as = ns.Navigation.Assess(ns.State.plan.now, ns.State.ctx)
	check(as.pin == false and as.reason == "APPROX_FAR" and ns.Navigation.Target() == nil and W.sets == 0, "(setup) the arrow and the waypoint are still withheld")
	check(as.direction == "south-east" and as.hintYards and as.hintYards % 10 == 0 and as.hintYards > 1000, "the destination is south-east of the player and about " .. tostring(as.hintYards) .. " yards (rounded to ten)")
	check(as.text:find("Head roughly south-east", 1, true) and as.text:find("so there is no arrow", 1, true) and not as.text:find("0%.%d%d"), "the text gives the direction, keeps the reason, and shows no coordinate")
	local c = card(ns)
	check(c.now.navNote == as.text and c.now.navDirection == "south-east", "the NOW card carries it")
	local ui = ns.UI
	ui.Open("codex")
	check(ui.main.codex.nowNav.__text:find("Head roughly south-east", 1, true) ~= nil, "and the window shows it under the action")
	-- no measurement, no hint: another continent / an unconvertible map
	local nsU = world({ rec(1, "Elsewhere", 0.6, 0.5) }, nil, { map = 7777, x = 0.5, y = 0.5 })
	local act
	for _, cnd in ipairs(nsU.Engine.Candidates(nsU.Context.Build()).candidates) do if cnd.id == "Q:1:ACCEPT" then act = cnd end end
	local asU = nsU.Navigation.Assess(act, nsU.State.ctx)
	check(asU.reason == "UNMEASURED" and asU.direction == nil and asU.text == nsU.Navigation.REASON_TEXT.UNMEASURED, "when Codex cannot measure the way there, it says only that (no invented direction)")
	-- special travel keeps its own message
	check(ns.Navigation.REASON_TEXT.SPECIAL_TRAVEL:find("boat", 1, true) ~= nil, "special travel keeps its dedicated wording (no direction is offered for a boat or portal)")
	check(#ns.errors == 0 and #nsU.errors == 0, "no errors")
end
