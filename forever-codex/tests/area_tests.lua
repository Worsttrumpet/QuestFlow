-- area_tests.lua: area objectives versus exact destinations (AreaEvidence.lua, Navigation.Assess). An area is one representative point with NO known boundary; Codex does not invent one.
-- It treats the player as inside the area when objective progress was made where they stand, or they arrived at the marker. Stub-client tests of Codex's own rules.

local H = ...
local check, section, boot = H.check, H.section, H.boot

local function Q(id, name, dx, dy, o)
	local q = { id = id, name = name, map = 9001, x = 0.5 + dx / 1000, y = 0.5 + (dy or 0) / 1000, req = 1 }
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
--- Player at (px, py) in yards from the middle of the 1000 yd fixture map; an objective area whose marker is at (mx, my).
local function world(px, py, mx, my, have)
	local ns = boot({ char = { level = 10 }, synthetic = true, loc = { map = 9001, x = 0.5 + px / 1000, y = 0.5 + py / 1000, zone = "F" } })
	H.attPack(ns, { Q(1, "Kill Quilboar", mx, my, { objCoords = { { map = 9001, x = 0.5 + mx / 1000, y = 0.5 + my / 1000 } } }) }, { { key = "zone-a", label = "A", map = 9001, quests = 1 } })
	local W = H.world()
	installWaypoint(W)
	W.log = { { questID = 1, title = "Kill Quilboar", complete = false } }
	W.objectives = { [1] = { { text = "Bristleback slain", type = "monster", finished = false, numFulfilled = have or 0, numRequired = 10 } } }
	ns.Prefs.FinishSetup(); ns.Prefs.SetNavigation(true); ns.Navigation._Reset()
	ns.State.Recompute()
	return ns, W
end
local function move(ns, W, px, py) W.loc.x, W.loc.y = 0.5 + px / 1000, 0.5 + py / 1000; ns.State.Recompute() end
local function kill(ns, W, n) W.objectives[1][1].numFulfilled = n; ns.State.Recompute() end
local function assess(ns) return ns.Navigation.Assess(ns.State.plan.now, ns.State.ctx) end

section("area objectives: outside the area the marker is navigated to; with no progress seen the place is approximate and Codex keeps steering")
do
	local ns, W = world(0, 0, 300, 0)
	check(ns.State.plan.now.id == "Q:1:OBJECTIVE" and ns.Navigation.Target() ~= nil, "300 yd from the marker: the arrow points at it")
	local ns2 = world(0, 0, 120, 0)
	local as = assess(ns2)
	check(as.pin == true and not as.inArea and ns2.Navigation.Target() ~= nil, "120 yd from the marker with no progress seen: no boundary is known, so Codex does not claim the player is inside")
	check(ns2.Presenter.Card(ns2.State.plan, ns2.State.ctx).now.dist:find("^~") ~= nil, "and the distance is shown as approximate  [" .. tostring(ns2.Presenter.Card(ns2.State.plan, ns2.State.ctx).now.dist) .. "]")
end

section("area objectives: progress made where the player stands means they are in the area; the arrow stops steering and the card says so")
do
	local ns, W = world(0, 0, 120, 0)
	check(ns.Navigation.Target() ~= nil, "(setup) 120 yd from the marker, arrow on")
	kill(ns, W, 1)
	local as = assess(ns)
	check(as.inArea == true and as.areaWhy == "progress" and as.reason == "IN_AREA" and as.pin == false, "a kill counted here: in the area (progress)")
	check(ns.Navigation.Target() == nil and W.waypoint == nil, "no arrow and the waypoint Codex placed is cleared")
	local c = ns.Presenter.Card(ns.State.plan, ns.State.ctx)
	check(c.now.dist == "In the objective area" and c.now.navNote:find("You are in the objective area", 1, true) ~= nil, "the card says 'In the objective area' instead of '120 yd'")
	check(c.now.title == "Finish Kill Quilboar" and c.now.objectives[1].have == 1, "the quest and its progress are still shown")
	-- moving around inside the area: no flicker of the arrow
	for _, p in ipairs({ { 30, 20 }, { -40, 30 }, { 50, -40 }, { 10, 60 } }) do
		move(ns, W, p[1], p[2])
		check(ns.Navigation.Target() == nil, string.format("moving to (%d, %d): still in the area, still no arrow", p[1], p[2]))
	end
	-- leaving the area: far from every place progress was made
	move(ns, W, -400, 0)
	check(assess(ns).inArea ~= true and ns.Navigation.Target() ~= nil, "400 yd away from where they were fighting: outside again, the arrow returns")
end

section("area objectives: arriving at the marker counts as arriving; an exact destination is never treated as an area")
do
	local ns = world(0, 0, 25, 0)
	check(assess(ns).inArea == true and assess(ns).areaWhy == "marker" and ns.Navigation.Target() == nil, "25 yd from the marker: arrived")
	-- an exact hand-in 25 yd away still gets its arrow (the normal arrival radius applies)
	local ns2 = boot({ char = { level = 10 }, synthetic = true, loc = { map = 9001, x = 0.5, y = 0.5, zone = "F" } })
	H.attPack(ns2, { Q(2, "Hand In", 60, 0, { giverName = "Hanna" }) }, { { key = "zone-a", label = "A", map = 9001, quests = 1 } })
	local W2 = H.world()
	installWaypoint(W2)
	W2.log = { { questID = 2, title = "Hand In", complete = true } }
	ns2.Prefs.FinishSetup(); ns2.Prefs.SetNavigation(true); ns2.Navigation._Reset()
	ns2.State.Recompute()
	local as2 = ns2.Navigation.Assess(ns2.State.plan.now, ns2.State.ctx)
	check(ns2.State.plan.now.kind == "TURN_IN" and as2.inArea ~= true and as2.pin == true and ns2.Navigation.Target() ~= nil, "an exact turn-in 60 yd away: navigated to, never 'in the area'")
end

section("area objectives: a boundary the data does give (a radius) is used; a small known area versus a large one")
do
	local function withRadius(r)
		local ns, W = world(0, 0, 150, 0)
		local a = ns.State.plan.now
		local pos = a.targets[1].where.points[1]
		pos.radius = r
		return ns, a
	end
	local nsSmall, aSmall = withRadius(60)
	check(nsSmall.Navigation.Assess(aSmall, nsSmall.State.ctx).inArea ~= true, "a 60 yd area whose marker is 150 yd away: outside, navigate")
	local nsLarge, aLarge = withRadius(600)
	local asL = nsLarge.Navigation.Assess(aLarge, nsLarge.State.ctx)
	check(asL.inArea == true and asL.areaWhy == "radius", "a 600 yd area: inside (a real radius is honoured; none ships today)")
end

section("area objectives: finishing the objective inside the area hands the quest to the normal hand-in; nothing is remembered for it")
do
	local ns, W = world(0, 0, 120, 0)
	kill(ns, W, 9)
	check(assess(ns).inArea == true, "(setup) in the area")
	W.log[1].complete = true
	W.objectives[1][1].numFulfilled, W.objectives[1][1].finished = 10, true
	ns.State.Recompute()
	check(ns.State.plan.now == nil or ns.State.plan.now.kind ~= "OBJECTIVE", "complete: the quest is a hand-in now")
	check(ns.AreaEvidence.sightings[1] == nil, "its remembered places are dropped")
	W.log = {}
	ns.State.Recompute()
	check(#ns.errors == 0 and table.concat(ns.AreaEvidence.ReportLines(), "\n"):find("AREA OBJECTIVES", 1, true), "no errors; the report has an AREA OBJECTIVES section")
end
