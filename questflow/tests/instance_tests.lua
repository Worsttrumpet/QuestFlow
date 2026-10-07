-- instance_tests.lua (0.8.1): what Codex does when the client says the player is INSIDE AN INSTANCE (Wailing Caverns in the 0.8.0 playtest). The instance APIs (IsInInstance / GetInstanceInfo) are
-- NOT proven on Forever, so they are feature-checked and an unknown state changes nothing. Inside an instance the outdoor map position is not where the player stands, so the arrow and waypoint are
-- withheld; the planner is untouched. Stub-client tests of Codex's own logic.

local H = ...
local check, section, boot = H.check, H.section, H.boot

local function rec(id, name, x, y, o)
	local q = { id = id, name = name, map = 9001, x = x, y = y, req = 1 }
	for k, v in pairs(o or {}) do q[k] = v end
	return q
end
local function setInstance(inside, kind, name, id)
	_G.IsInInstance = function() return inside, kind end
	_G.GetInstanceInfo = function() return name or "", kind or "none", 1, "Normal", 5, 0, false, id or 0, 5 end
end
local function clearInstance() _G.IsInInstance, _G.GetInstanceInfo = nil, nil end
local function world(setup)
	local ns = boot({ char = { level = 10 }, synthetic = true, loc = { map = 9001, x = 0.5, y = 0.5, zone = "Fixture" } })
	if setup then setup() end
	H.attPack(ns, { rec(1, "Near Pickup", 0.6, 0.5) }, { { key = "zone-a", label = "Zone A", map = 9001, quests = 1 } })
	local W = H.world()
	W.log, W.objectives = {}, {}
	W.sets = 0
	local base = _G.C_Map
	local oldSet = base.SetUserWaypoint
	base.HasUserWaypoint = function() return W.waypoint ~= nil end
	base.GetUserWaypoint = function() local p = W.waypoint; return p and { uiMapID = p.uiMapID, position = { x = p.x, y = p.y } } or nil end
	base.ClearUserWaypoint = function() W.waypoint = nil end
	base.SetUserWaypoint = function(p) W.sets = W.sets + 1; oldSet(p) end
	ns.Prefs.FinishSetup()
	ns.Prefs.SetNavigation(true)
	ns.Navigation._Reset()
	ns.State.Recompute()
	return ns, W
end

section("instance: the reader records what the client says, and nothing when it says nothing")
do
	clearInstance()
	local ns = boot({ char = { level = 10 }, synthetic = true })
	local C = ns.Context
	local r = C.Build()
	check(r.instance and r.instance.known == false and r.instance.inInstance == nil, "no IsInInstance / GetInstanceInfo: the state is UNKNOWN (not 'outside', not 'inside')")
	setInstance(true, "party", "Wailing Caverns", 43)
	local i = C.Build().instance
	check(i.known and i.inInstance == true and i.kind == "party" and i.name == "Wailing Caverns" and i.id == 43, "inside: known, type, name and id are recorded")
	setInstance(false, "none")
	i = C.Build().instance
	check(i.known and i.inInstance == false and i.kind == "none", "outside: known and false")
	_G.IsInInstance = function() error("boom") end
	_G.GetInstanceInfo = function() error("boom") end
	i = C.Build().instance
	check(i.known == false, "an API that raises is contained: unknown")
	_G.IsInInstance = function() return nil end
	check(C.Build().instance.known == false or C.Build().instance.inInstance == false, "an API that answers nothing does not make it 'inside'")
	clearInstance()
end

section("instance: inside one, the arrow and waypoint are withheld with a clear reason; the planner's decision is the same")
do
	clearInstance()
	local outside = world()
	local outId = outside.State.plan.now and outside.State.plan.now.id
	check(outId == "Q:1:ACCEPT" and outside.Navigation.Target() ~= nil, "(control) outdoors: NOW is the near pickup and it has an arrow target")
	local ns, W = world(function() setInstance(true, "party", "Wailing Caverns", 43) end)
	check(ns.State.ctx.instance.inInstance == true, "(setup) the context says the player is inside an instance")
	check(ns.State.plan.now and ns.State.plan.now.id == outId, "the PLANNER is untouched: the same NOW as outdoors  [" .. tostring(ns.State.plan.now and ns.State.plan.now.id) .. "]")
	local as = ns.Navigation.Assess(ns.State.plan.now, ns.State.ctx)
	check(as.pin == false and as.reason == "IN_INSTANCE" and as.text:find("inside an instance", 1, true), "the assessment: no pin, reason IN_INSTANCE, said in words")
	check(ns.Navigation.Target() == nil and W.sets == 0, "no arrow target and no waypoint was placed")
	local card = ns.Presenter.Card(ns.State.plan, ns.State.ctx)
	check(card.now.navNote and card.now.navNote:find("inside an instance", 1, true) and card.now.navReason == "IN_INSTANCE", "the NOW card carries the reason")
	check(not as.text:find("%d%d%.%d"), "no coordinate is shown")
	-- leaving the instance restores the arrow
	setInstance(false, "none")
	ns.State.Recompute()
	check(ns.Navigation.Target() ~= nil and ns.Navigation.NoPin() == nil, "outside again: the arrow target is back")
	-- an UNKNOWN state (APIs absent) changes nothing
	clearInstance()
	local unknown = world()
	check(unknown.State.ctx.instance.known == false and unknown.Navigation.Target() ~= nil, "unknown instance state: navigation behaves exactly as before")
	clearInstance()
	check(#ns.errors == 0 and #unknown.errors == 0 and #outside.errors == 0, "no errors")
end

section("instance: the report prints the evidence (instance state and which position APIs answered) so a dungeon report settles what Forever exposes")
do
	local ns = world(function() setInstance(true, "party", "Wailing Caverns", 43) end)
	_G.UnitPosition = function() return 12.5, -40.2, 3.0, 43 end
	local lines = table.concat(ns.Diag.InstanceLines(ns.State.ctx.instance, { map = 9001, available = true, world = { continent = 1 } }), "\n")
	check(lines:find("IsInInstance present -> true (type party)", 1, true) and lines:find("name 'Wailing Caverns'", 1, true) and lines:find("id 43", 1, true), "the instance line")
	check(lines:find("UnitPosition present -> returns (number, number, number, number) instance/continent id 43", 1, true) and lines:find("map position yes", 1, true), "the position-API line says what came back (types only, no coordinates)")
	check(not lines:find("12.5", 1, true) and not lines:find("40.2", 1, true), "coordinates are not printed")
	check(lines:find("withholds the arrow", 1, true) ~= nil, "and says what Quest Flow does about it")
	_G.UnitPosition = nil
	clearInstance()
	local bare = table.concat(ns.Diag.InstanceLines({ known = false }, { available = false }), "\n")
	check(bare:find("IsInInstance ABSENT -> no answer", 1, true) and bare:find("UnitPosition ABSENT", 1, true) and bare:find("map position NO", 1, true), "with nothing available it says ABSENT / no answer, not a guess")
	local full = table.concat(ns.Diag.Lines(ns.Diag.Snapshot()), "\n")
	check(full:find("Instance: IsInInstance", 1, true) ~= nil, "it is part of the full report")
end
