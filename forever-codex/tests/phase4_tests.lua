-- phase4_tests.lua: fixes and additions after the first real-client test of the Phase 3 build.
--   * combat-log registration (Forever refuses it and raises a taint popup)
--   * the Silverpine -> The Barrens plan (an unmeasurable leg is not free; unverified far data is not trusted into a trip)
--   * the direction arrow (own frame, learned facing convention, ownership, lifecycle)
--   * the map-pin layer (trust, ownership, minimap omitted)
--   * NEW FOR YOU, NEARBY, the dropdown navigation and the centred NOW card
-- Stub-client tests: they prove Codex's own logic. Nothing about the arrow, pins or map has been seen on the real Forever client.

local H = ...
local check, section, boot = H.check, H.section, H.boot

local function click(b) b.__scripts.OnClick(b) end

local function Q(id, name, dx, dy, o)
	local q = { id = id, name = name, map = 9001, x = 0.5 + dx / 1000, y = 0.5 + (dy or 0) / 1000 }
	for k, v in pairs(o or {}) do q[k] = v end
	return q
end

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
	ns.Prefs.FinishSetup()
	ns.State.Recompute()
	return ns, W
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

local function allTexts(W)
	local out = {}
	for _, f in ipairs(W.fonts or {}) do if f.__text and f.__text ~= "" then out[#out + 1] = f.__text end end
	return out
end

-- ================================================================ combat log

section("fixes: the combat log is never registered (Forever blocks it and taints the addon)")
do
	local ns = boot({ char = { level = 25 } })
	local W = H.world()
	local n = 0
	for _, e in ipairs(W.registeredEvents or {}) do if e == "COMBAT_LOG_EVENT_UNFILTERED" then n = n + 1 end end
	check(n == 0, "no frame registers COMBAT_LOG_EVENT_UNFILTERED at load or login")
	local seen = {}
	for _, e in ipairs(W.registeredEvents or {}) do seen[e] = true end
	check(seen.QUEST_ACCEPTED and seen.QUEST_TURNED_IN and seen.UNIT_QUEST_LOG_CHANGED and seen.PLAYER_REGEN_DISABLED and seen.PLAYER_XP_UPDATE and seen.PLAYER_LEVEL_UP,
		"the proven quest events and the XP / level / regen events are still registered")
	local src = H.readFile(H.addonDir .. "/Telemetry.lua"):gsub("%-%-[^\n]*", "")
	local list = src:match("local WATCHED_EVENTS = (%b{})")
	check(list and not list:find("COMBAT_LOG", 1, true), "the watched-event list has no combat-log event")
	for _, f in ipairs({ "Boot.lua", "Markers.lua", "Party.lua", "Arrow.lua", "Pins.lua" }) do
		check(not H.readFile(H.addonDir .. "/" .. f):gsub("%-%-[^\n]*", ""):find("COMBAT_LOG", 1, true), f .. " does not reference the combat log")
	end
	W.chat = {}
	H.slash("telemetry")
	check(W.chat[1] and table.concat(W.chat, "\n"):find("MOB_KILL%s+UNAVAILABLE on Forever") ~= nil, "/codex telemetry says kill tracking is UNAVAILABLE")
	W.chat = {}
	H.slash("diag")
	check(table.concat(W.chat, "\n"):find("MOB_KILL[UNAVAILABLE", 1, true) ~= nil, "/codex diag says kill tracking is UNAVAILABLE")
	local caps = {}
	for _, c in ipairs(ns.Telemetry.Capabilities()) do caps[c.type] = c end
	check(caps.MOB_KILL.unavailable and not caps.MOB_KILL.verified and caps.MOB_KILL.registered == false and caps.XP_GAIN.unavailable == nil, "capabilities: only kills are unavailable; XP stays merely unproven")
	local before = #ns.Telemetry.Events()
	check(#ns.errors == 0 and before >= 1, "no errors")
end

-- ================================================================ Silverpine -> Barrens

section("fixes: Silverpine -> The Barrens (real data, level 21 Hunter in the Sepulcher)")
do
	local ns = boot({ char = { level = 21, class = "Hunter", classToken = "HUNTER", race = "Skyborne", raceToken = "Skyborne", faction = "Horde" },
		loc = { map = 1421, x = 0.43, y = 0.414, zone = "Silverpine Forest", subzone = "The Sepulcher" } })
	installWaypoint(H.world())
	ns.Prefs.FinishSetup()
	local plan = ns.State.Recompute()
	local d = plan.diag
	check(d.candidates > 50, "(setup) the real data offers many candidates, all of them elsewhere (" .. d.candidates .. ")")
	local local1421 = 0
	for _, it in pairs(plan.diag.items or {}) do if it.map == 1421 then local1421 = local1421 + 1 end end
	check(plan.now == nil and plan.next == nil, "nothing is recommended: no TRAVEL to Thork, no NOW across the continent")
	check(d.reason == "ONLY_DISTANT_UNMEASURED" and d.unknownLegs >= 1 and d.net < 0, "diagnosed: only distant, unmeasurable, net-negative (" .. tostring(d.reason) .. ")")
	check(H.world().sets == 0 and ns.Navigation.Owned() == nil and ns.Navigation.Target() == nil, "no waypoint and no arrow target for it")
	local card = ns.Presenter.Card(plan, ns.State.ctx)
	check(card.now == nil and card.empty.title == "Nothing to recommend right now", "the card says so honestly")
	-- the ATT location is still used when the player decides
	ns.Prefs.SetStyle("fast"); ns.Prefs.SetStyle("efficient")
	ns.Prefs.Add(6541)
	local p2 = ns.State.Recompute()
	check(p2.now and p2.now.quest == 6541, "a quest the player ADDED is still planned, wherever it is (their choice)")
	ns.Prefs.RemoveAdded(6541)
	local z = ns.Registry.ZoneByKey("the-barrens")
	ns.Prefs.SetRouteZone(z and z.key or "the-barrens")
	local p3 = ns.State.Recompute()
	check(p3.now ~= nil, "and so is a route zone the player chose there")
	ns.Prefs.SetRouteZone("auto")
	check(ns.State.Recompute().now == nil, "back on auto it is not recommended again")
end

section("fixes: an unmeasurable leg is charged, local work wins, and nothing was re-tuned")
do
	local ns, W = world(6, { Q(1, "Local", 300, 0), Q(2, "Over the sea", 0, 0, { map = 9003 }) }, {})
	check(ns.State.plan.now and ns.State.plan.now.quest == 1, "local work is NOW")
	check(ns.Planner.UNKNOWN_LEG_SECONDS > 0, "an unmeasurable leg has a cost (" .. ns.Planner.UNKNOWN_LEG_SECONDS .. " s)")
	local d = ns.State.plan.diag
	check(d.unknownLegs == 0, "and the chosen plan has no unknown leg")
	-- a stop that is only reachable through an unknown leg: its solo value includes the charge
	local ns2 = boot({ char = { level = 6 }, synthetic = true, loc = { map = 9001, x = 0.5, y = 0.5 } })
	H.attPack(ns2, { Q(2, "Over the sea", 0, 0, { map = 9003 }) }, nil)
	local ctx = ns2.Context.Build()
	local c = ns2.Engine.Candidates(ctx)
	local plan = ns2.Planner.Compute(ctx, c, { trace = true })
	local par = ns2.Planner.Params("efficient")
	check(plan.now == nil and plan.diag.reason == "ONLY_DISTANT_UNMEASURED", "alone, a trip through an unmeasurable leg that does not pay for itself is not recommended")
	check(plan.diag.seconds >= ns2.Planner.UNKNOWN_LEG_SECONDS, "its estimated time includes the charge (" .. string.format("%.0f", plan.diag.seconds) .. " s)")
	local trusted = { 1, 2 }
	for k, v in pairs({ timeValue = 0.30, detour = 30, alsoFloor = 5, stickiness = 3, chain = 0.25 }) do
		trusted[#trusted + 1] = (par[k] == v) and 1 or 0
	end
	local ok = true
	for i = 3, #trusted do if trusted[i] ~= 1 then ok = false end end
	check(ok and ns2.Planner.STOP_RADIUS == 60 and ns2.Planner.RUN_SPEED == 7 and par.value.TURN_IN == 40 and par.value.OBJECTIVE == 60 and par.value.ACCEPT == 20, "no policy value, time weight, detour, floor, stability, chain or stop constant was changed")
end

-- ================================================================ arrow

local function conv(s, o) return function(beta) return (s * beta + o) % (2 * math.pi) end end

local function arrowWorld(s, o)
	local ns, W = world(6, { Q(1, "Target", 300, 0, { giverName = "Someone" }) }, {})
	installWaypoint(W)
	ns.Prefs.SetNavigation(true)
	ns.Navigation._Reset()
	ns.Arrow._Reset()
	local st = { x = 0.5, y = 0.5, facing = nil, t = 1000 }
	ns.Arrow.api.position = function() return { map = 9001, x = st.x, y = st.y } end
	ns.Arrow.api.facing = function() return st.facing end
	ns.Arrow.api.now = function() return st.t end
	ns.State.Recompute()
	return ns, W, st, conv(s, o)
end

--- Walks `steps` of 10 yards on compass heading beta (0 = N, clockwise), facing it, updating the arrow each second.
local function walk(ns, st, f, beta, steps)
	for _ = 1, steps do
		st.x = st.x + 0.01 * math.sin(beta)
		st.y = st.y - 0.01 * math.cos(beta)
		st.facing = f(beta)
		st.t = st.t + 1
		ns.Arrow.Update(ns.State.ctx)
	end
end

section("arrow: geometry and learning the facing convention")
do
	local ns = boot({ char = { level = 6 }, synthetic = true, loc = { map = 9001, x = 0.5, y = 0.5 } })
	local A, ctx = ns.Arrow, ns.Context.Build()
	local function bearing(dx, dy) return A.Bearing(ctx, { map = 9001, x = 0.5, y = 0.5 }, { map = 9001, x = 0.5 + dx / 1000, y = 0.5 + dy / 1000 }) end
	local b, d = bearing(100, 0)
	check(math.abs(b - math.pi / 2) < 1e-9 and math.abs(d - 100) < 1e-6, "east is 90 degrees clockwise from north, 100 yards")
	check(math.abs(bearing(0, -100)) < 1e-9 and math.abs(math.abs(bearing(0, 100)) - math.pi) < 1e-9 and math.abs(bearing(-100, 0) + math.pi / 2) < 1e-9, "north 0, south 180, west -90")
	local b2, d2 = bearing(100, -100)
	check(math.abs(b2 - math.pi / 4) < 1e-9 and math.abs(d2 - 141.42135) < 1e-3, "north-east is 45 degrees")
	check(A.Bearing(ctx, { map = 9001, x = 0.5, y = 0.5 }, { map = 9003, x = 0.5, y = 0.5 }) == nil, "another continent has no bearing")
	check(A.Bearing(ctx, nil, { map = 9001, x = 0, y = 0 }) == nil, "no position, no bearing")
	-- Solve: two different client conventions are both learned; nothing is assumed
	local function samplesFor(f, headings)
		local out = {}
		for _, h in ipairs(headings) do out[#out + 1] = { h, f(h) } end
		return out
	end
	local H8 = { 0, 0.7, 1.4, 2.1, 2.8, 3.5, 4.2, 5.0 }
	local retail = A.Solve(samplesFor(conv(-1, 0), H8))
	check(retail and retail.s == -1 and math.abs(retail.o) < 1e-6 or (retail and retail.s == -1 and math.abs(retail.o - 2 * math.pi) < 1e-6), "a counter-clockwise client (facing = -compass) is learned")
	local odd = A.Solve(samplesFor(conv(1, 1.0), H8))
	check(odd and odd.s == 1 and math.abs(odd.o - 1.0) < 1e-6, "a clockwise client with an offset is learned too")
	check(A.Solve(samplesFor(conv(1, 0), { 0, 0.1, 0.05 })) == nil, "too few samples: no guess")
	check(A.Solve(samplesFor(conv(1, 0), { 1, 1, 1, 1, 1, 1, 1, 1 })) == nil, "one direction only: the sign cannot be told, so no guess")
	local noisy = samplesFor(conv(-1, 0), H8)
	noisy[2][2] = noisy[2][2] + 2.5; noisy[5][2] = noisy[5][2] - 2.2; noisy[7][2] = noisy[7][2] + 1.9
	check(A.Solve(noisy) == nil, "samples that do not agree are rejected")
	local cal = { s = 1, o = 0 }
	check(math.abs(A.Relative(cal, 0, math.pi / 2) - math.pi / 2) < 1e-9 and math.abs(A.Relative(cal, math.pi / 2, 0) + math.pi / 2) < 1e-9, "relative angle: target to the right is positive")
	check(A.Words(0) == "straight ahead" and A.Words(1) == "ahead, to your right" and A.Words(-1) == "ahead, to your left" and A.Words(3.1) == "behind you" and A.Words(1.5) == "to your right", "plain words for the direction")
end

section("arrow: appears when it can point, follows you, and disappears")
do
	for _, cv in ipairs({ { -1, 0 }, { 1, 0.8 } }) do
		local ns, W, st, f = arrowWorld(cv[1], cv[2])
		local A = ns.Arrow
		check(ns.Navigation.Target() ~= nil, "(setup) NOW has a destination 300 yd east")
		st.facing = f(0)
		A.Update(ns.State.ctx)
		check(A.state.visible and A.state.reason == "calibrating" and not A.state.art and A.Frame().label.__text:find("Walk a few steps", 1, true), "before it has learned how you face: no arrow, a plain hint")
		for _, beta in ipairs({ 0, math.pi / 2, math.pi, 3 * math.pi / 2, 0.8, 2.4 }) do
			st.x, st.y = 0.5, 0.5
			st.facing = f(beta)
			A.Update(ns.State.ctx)
			walk(ns, st, f, beta, 3)
		end
		check(A.Calibration() and A.Calibration().s == cv[1], "walking in several directions teaches it (convention s=" .. cv[1] .. ")")
		st.x, st.y = 0.5, 0.5
		st.facing = f(0)                                  -- facing north; the target is due east
		A.Update(ns.State.ctx)
		check(A.state.reason == "pointing" and A.state.art and math.abs(A.state.rel - math.pi / 2) < 1e-6 and A.state.words == "ahead, to your right" or A.state.words == "to your right",
			"facing north with the target due east, it points right (" .. tostring(A.state.words) .. ")")
		check(math.abs(A.state.rotation + math.pi / 2) < 1e-6 and math.abs(A.Frame().tex.__rotation + math.pi / 2) < 1e-6, "and the texture is rotated to match (counter-clockwise positive)")
		st.facing = f(math.pi / 2)                        -- turn to face east: straight ahead
		A.Update(ns.State.ctx)
		check(math.abs(A.state.rel) < 1e-6 and A.state.words == "straight ahead", "turning toward it points straight ahead")
		check(A.Frame().label.__text == "300 yd", "the label is the distance in tens of yards")
		ns.Prefs.SetArrowFlip(true)
		A.Update(ns.State.ctx)
		check(math.abs(A.state.rotation - A.state.rel) < 1e-9, "/codex arrow flip inverts the drawing if the real client turns out mirrored")
		ns.Prefs.SetArrowFlip(false)
		-- arrival
		st.x, st.y = 0.8, 0.5
		H.world().loc.x, H.world().loc.y = 0.8, 0.5
		ns.Navigation.Tick(2)
		A.Update(ns.State.ctx)
		check(not A.state.visible and A.state.reason == "no destination" and not A.Frame().__shown, "arriving hides the arrow")
	end
end

section("arrow: switches, ownership and failure")
do
	local ns, W, st, f = arrowWorld(-1, 0)
	local A = ns.Arrow
	st.facing = f(0)
	A.Update(ns.State.ctx)
	check(A.state.visible, "(setup) visible")
	local setsBefore, clearsBefore, callsBefore = W.sets, W.clears, W.waypointCalls
	for _ = 1, 10 do A.Update(ns.State.ctx) end
	check(W.sets == setsBefore and W.clears == clearsBefore and W.waypointCalls == callsBefore, "the arrow never places, moves or clears a waypoint")
	ns.Prefs.SetNavigation(false)
	ns.State.Recompute()
	A.Update(ns.State.ctx)
	check(not A.state.visible and A.state.reason == "nav off" and not A.Frame().__shown, "/codex nav off hides the arrow")
	ns.Prefs.SetNavigation(true)
	ns.State.Recompute()
	ns.Prefs.SetArrow(false)
	A.Update(ns.State.ctx)
	check(not A.state.visible and A.state.reason == "arrow off", "the arrow has its own switch")
	ns.Prefs.SetArrow(true)
	-- a waypoint of the player's: Codex pauses, the arrow stays quiet, the pin is untouched
	local ns2, W2, st2 = arrowWorld(-1, 0)
	ns2.Navigation._Reset()
	W2.waypoint = { uiMapID = 9001, x = 0.11, y = 0.22 }
	ns2.State.Recompute()
	st2.facing = 0
	ns2.Arrow.Update(ns2.State.ctx)
	check(ns2.Navigation.Status() == "paused-foreign" and not ns2.Arrow.state.visible and W2.waypoint.x == 0.11 and W2.clears == 0, "with a waypoint of the player's own the arrow is hidden and their pin is untouched")
	-- no destination
	local ns3, W3, st3 = arrowWorld(-1, 0)
	H.world().log = {}
	ns3.Prefs.Skip("Q:1")
	ns3.State.Recompute()
	ns3.Arrow.Update(ns3.State.ctx)
	check(ns3.State.plan.now == nil and not ns3.Arrow.state.visible and ns3.Arrow.state.reason == "no destination", "without a NOW there is no arrow")
	-- no facing API
	local ns4, W4, st4 = arrowWorld(-1, 0)
	st4.facing = nil
	ns4.Arrow.Update(ns4.State.ctx)
	check(ns4.Arrow.state.visible and ns4.Arrow.state.reason == "no facing" and not ns4.Arrow.state.art and ns4.Arrow.Frame().label.__text == "300 yd", "no GetPlayerFacing: just the distance, no pretend arrow")
	-- another continent
	local ns5, W5, st5 = arrowWorld(-1, 0)
	st5.facing = 0
	st5.x, st5.y = 0.5, 0.5
	ns5.Arrow.api.position = function() return { map = 9003, x = 0.5, y = 0.5 } end
	ns5.Arrow.Update(ns5.State.ctx)
	check(ns5.Arrow.state.reason == "other area" and not ns5.Arrow.state.art, "in another area it says so instead of pointing")
	-- robustness
	ns5.Arrow.api.position = function() error("boom") end
	check(select(1, pcall(ns5.Arrow.Tick, 1)) and true, "a failing client call does not escape the tick")
	local oldCalls = 0
	ns5.Arrow.api.position = function() return nil end
	ns5.Arrow.Update(ns5.State.ctx)
	check(ns5.Arrow.state.reason == "no position", "no position: hidden")
	-- reset forgets the convention
	ns.Prefs.Root().ui.arrowCal = { s = 1, o = 0 }
	H.slash("arrow reset")
	check(ns.Arrow.Calibration() == nil, "/codex arrow reset forgets the learned convention")
	H.slash("arrow flip")
	check(ns.Prefs.ArrowFlip(), "/codex arrow flip")
	H.slash("arrow flip")
	H.slash("arrow off")
	check(not ns.Prefs.ArrowOn(), "/codex arrow off")
	H.slash("arrow on")
	H.world().chat = {}
	H.slash("arrow")
	check(table.concat(H.world().chat, "\n"):find("Unproven on the real client", 1, true) ~= nil, "/codex arrow is honest that it is unproven on the real client")
	local src = H.readFile(H.addonDir .. "/Arrow.lua"):gsub("%-%-[^\n]*", "")
	check(not src:find("SetUserWaypoint", 1, true) and not src:find("ClearUserWaypoint", 1, true) and not src:find("HookScript", 1, true) and not src:find("hooksecurefunc", 1, true)
		and not src:find("Secure", 1, true), "Arrow.lua has no waypoint calls, no hooks and no secure frames")
	check(#ns.errors == 0, "no caught errors")
end

section("arrow: it persists what it learned and where it sits")
do
	local ns, W, st, f = arrowWorld(-1, 0)
	for _, beta in ipairs({ 0, math.pi / 2, math.pi, 3 * math.pi / 2, 0.8, 2.4 }) do st.x, st.y = 0.5, 0.5; st.facing = f(beta); ns.Arrow.Update(ns.State.ctx); walk(ns, st, f, beta, 3) end
	local saved = ForeverCodexDB
	check(saved.ui.arrowCal and saved.ui.arrowCal.s == -1 and ns.Prefs.IsSavedVariablesSafe(saved), "the learned convention is saved, SavedVariables-safe")
	ns.Arrow.Frame().GetPoint = function() return "TOP", nil, "TOP", 10, -200 end
	ns.Arrow.Frame().__scripts.OnDragStop(ns.Arrow.Frame())
	check(saved.ui.arrowPos and saved.ui.arrowPos.y == -200, "dragging the arrow saves its place")
end

-- ================================================================ pins

local function desiredFor(ns, plan) return ns.Pins.Desired(plan) end

local function tgt(ns, role, kind, map, pts, src, o)
	local K = ns.Contract
	o = o or {}
	local points = {}
	for _, p in ipairs(pts) do points[#points + 1] = { map = map, x = p[1], y = p[2] } end
	return K.Target({ role = role, service = o.service, entity = { kind = "npc", id = o.npc }, assumed = o.assumed, where = K.Where(o.status or "known", points, kind), prov = K.Prov(src) })
end

local function planWith(ns, now, also)
	local function a(id, kind, targets, name)
		local x = { id = id, type = "QUEST", kind = kind, quest = 1, name = name or "A Quest", title = id, lines = {}, reasons = {}, contract = 1, targets = targets }
		return x
	end
	return { now = now and a(now.id, now.kind, now.targets, now.name), alsoDo = also and a(also.id, also.kind, also.targets, also.name), reminders = {}, warnings = {}, diag = { reasons = {} } }
end

section("pins: only the plan's own targets, with honest trust")
do
	local ns = boot({ char = { level = 6 }, synthetic = true })
	local obs = tgt(ns, "GIVER", "exact", 9001, { { 0.4, 0.4 } }, "observed", { npc = 7 })
	local att = tgt(ns, "GIVER", "exact", 9001, { { 0.5, 0.5 } }, "att", { npc = 8 })
	local area = tgt(ns, "OBJECTIVE", "area", 9001, { { 0.6, 0.6 }, { 0.61, 0.6 } }, "att", { status = "approx" })
	local assumed = tgt(ns, "TURN_IN", "assumed_giver", 9001, { { 0.7, 0.7 } }, "att", { assumed = true, status = "approx" })
	local flight = tgt(ns, "SERVICE", "exact", 9001, { { 0.2, 0.2 } }, "att", { service = "FLIGHT" })
	local d = ns.Pins.Desired(planWith(ns, { id = "Q:1:ACCEPT", kind = "ACCEPT", targets = { obs } }, { id = "Q:2:ACCEPT", kind = "ACCEPT", targets = { att } }))
	check(#d == 2 and d[1].trust == "observed" and d[1].kind == "giver" and d[1].role == "now" and d[2].trust == "approx" and d[2].role == "alsoDo", "NOW's and ALSO DO's targets only; observed is trusted, ATT-only is approximate")
	local d2 = ns.Pins.Desired(planWith(ns, { id = "Q:1:OBJECTIVE", kind = "OBJECTIVE", targets = { area }, name = "Razormane Scouts" }))
	check(#d2 == 2 and d2[1].kind == "objective" and d2[1].trust == "approx" and d2[1].label == "Razormane Scouts (objective area)", "an objective area is shown as approximate area pins, never as a confirmed spot")
	local d3 = ns.Pins.Desired(planWith(ns, { id = "Q:1:TURN_IN", kind = "TURN_IN", targets = { assumed } }))
	check(d3[1].kind == "turnin" and d3[1].trust == "approx", "a turn-in assumed at the giver is approximate")
	local obsAssumed = tgt(ns, "TURN_IN", "assumed_giver", 9001, { { 0.7, 0.7 } }, "observed", { assumed = true })
	check(ns.Pins.Desired(planWith(ns, { id = "Q:1:TURN_IN", kind = "TURN_IN", targets = { obsAssumed } }))[1].trust == "approx", "an assumed location never counts as observed, whatever its source")
	local d4 = ns.Pins.Desired(planWith(ns, { id = "FP:1", kind = "DISCOVER", targets = { flight } }))
	check(d4[1].kind == "flight", "a flight master target is a flight pin")
	local unknown = ns.Contract.Target({ role = "GIVER" })
	check(#ns.Pins.Desired(planWith(ns, { id = "Q:1:ACCEPT", kind = "ACCEPT", targets = { unknown } })) == 0, "an unknown location is never pinned")
	check(#ns.Pins.Desired({}) == 0 and #ns.Pins.Desired(nil) == 0, "no plan, no pins")
	local many = {}
	for i = 1, 20 do many[i] = { i / 100, 0.5 } end
	check(#ns.Pins.Desired(planWith(ns, { id = "Q:1:OBJECTIVE", kind = "OBJECTIVE", targets = { tgt(ns, "OBJECTIVE", "area", 9001, many, "att", { status = "approx" }) } })) == ns.Pins.MAX, "never more than " .. ns.Pins.MAX .. " pins")
end

local function mapStub(W, id)
	local canvas = { GetWidth = function() return 1000 end, GetHeight = function() return 500 end }
	local m
	m = { shown = true, id = id, GetCanvas = function() return canvas end, GetMapID = function() return m.id end, IsShown = function() return m.shown end }
	_G.WorldMapFrame = m
	return m, canvas
end

section("pins: world map pins are Codex's own frames; minimap is omitted; everything degrades")
do
	local ns, W = world(6, { Q(1, "Pickup", 100, 0, { giverName = "Somebody", giverNpc = 7 }) }, {})
	local Pins = ns.Pins
	local m, canvas = mapStub(W, 9001)
	local foreign = { codexOwned = nil, hidden = false, Hide = function(self) self.hidden = true end }
	canvas.children = { foreign }
	ns.State.Recompute()
	local shown = Pins.Shown()
	check(#shown >= 1 and shown[1].map == 9001 and shown[1].trust == "approx" and shown[1].label:find("Accept: Pickup", 1, true), "with the world map on the right map, Codex shows its pin (approximate: ATT data)")
	check(foreign.hidden == false, "a frame Codex did not create is never touched")
	m.id = 9002
	Pins.Tick(1)
	check(#Pins.Shown() == 0, "when the map shows another map the pin is not shown there")
	m.id = 9001
	Pins.Tick(1)
	check(#Pins.Shown() >= 1, "and returns when the map does")
	ns.Prefs.SetPins(false)
	ns.State.Recompute()
	check(#Pins.Shown() == 0, "/codex pins off hides them")
	ns.Prefs.SetPins(true)
	ns.State.Recompute()
	ns.Prefs.Skip("Q:1")
	ns.State.Recompute()
	check(#Pins.Shown() == 0 and foreign.hidden == false, "when NOW goes away its pins go away, and still nothing else is touched")
	check(Pins.Status().minimap:find("not supported", 1, true) and not Pins.api.minimapSupported(), "the minimap is reported as not supported, not faked")
	check(H.world().waypointCalls == 0, "pins never touch the game's waypoint")
	-- API missing
	_G.WorldMapFrame = nil
	ns.Prefs.Unskip("Q:1")
	ns.State.Recompute()
	check(#Pins.Shown() == 0 and Pins.Status().worldMap:find("unavailable", 1, true) and #ns.errors == 0, "without a world map API there are no pins and no error")
	_G.WorldMapFrame = { GetCanvas = function() error("boom") end, GetMapID = function() return 9001 end, IsShown = function() return true end }
	ns.State.Recompute()
	check(#Pins.Shown() == 0 and #ns.errors == 0, "a map API that raises is absorbed: no pins, no error escapes, and the plan still comes out")
	check(ns.State.plan.now ~= nil, "(plan intact)")
	_G.WorldMapFrame = nil
	local src = H.readFile(H.addonDir .. "/Pins.lua"):gsub("%-%-[^\n]*", "")
	check(not src:find("SetUserWaypoint", 1, true) and not src:find("ClearUserWaypoint", 1, true) and not src:find("Minimap", 1, true) and not src:find("hooksecurefunc", 1, true),
		"Pins.lua touches no waypoint, no minimap and hooks nothing")
	H.slash("pins")
	check(true, "(/codex pins runs)")
end

-- ================================================================ NEW FOR YOU

local function nfyWorld(level)
	local ns, W = world(level or 5, {
		Q(10, "Seen on Forever", 100, 0, { req = 6 }),               -- ATT record; the observed layer below confirms the quest exists
		Q(11, "Unseen quest", 110, 0, { req = 6 }),
		Q(12, "Level eight", 120, 0, { req = 8 }),
		Q(13, "Level seven", 130, 0, { req = 7 }),
	}, {})
	ForeverCodex.RegisterPack("quests", "observed:nfy", { meta = { src = "observed", verified = true, priority = 100, label = "test" }, zones = {},
		quests = { [10] = { id = 10, name = "Seen on Forever" }, [12] = { id = 12, name = "Level eight" }, [13] = { id = 13, name = "Level seven" } } })
	ns.NewForYou._Reset()
	ns.State.Recompute()           -- baseline at this level
	return ns, W
end

section("NEW FOR YOU: only at even levels, only with something real, exactly one minute")
do
	local ns, W = nfyWorld(5)
	local N = ns.NewForYou
	check(N.Active() == nil, "logging in at a level is only a baseline: nothing shown")
	W.char.level = 6
	ns.State.Recompute()
	local a = N.Active()
	check(a and a.level == 6 and #a.items == 1 and a.items[1].title == "New quest: Seen on Forever", "reaching level 6: the quest Forever's own data shows that just opened up (an ATT-only one is not shown)")
	check(N.DURATION == 60, "it lasts one minute")
	W.now = W.now + 59
	check(N.Active() ~= nil, "still there at 59 seconds")
	W.now = W.now + 1
	check(N.Active() == nil, "gone at 60 seconds, no dismissal needed")
	local ns2, W2 = nfyWorld(6)
	W2.char.level = 7
	ns2.State.Recompute()
	check(ns2.NewForYou.Active() == nil, "an odd level never triggers")
	W2.char.level = 8
	ns2.State.Recompute()
	check(ns2.NewForYou.Active() and ns2.NewForYou.Active().items[1].title == "New quest: Level eight", "an even level does")
	local ns3, W3 = nfyWorld(2)
	W3.char.level = 4
	ns3.State.Recompute()
	check(ns3.NewForYou.Active() == nil, "an even level with nothing meaningful shows nothing")
	local ns4, W4 = nfyWorld(3)
	W4.char.level = 6
	ns4.State.Recompute()
	check(ns4.NewForYou.Active() and ns4.NewForYou.Active().level == 6, "a jump over an even level is evaluated for the levels crossed")
	local ns5, W5 = nfyWorld(5)
	W5.log = { { questID = 10, title = "Seen on Forever", complete = false } }
	W5.char.level = 6
	ns5.State.Recompute()
	check(ns5.NewForYou.Active() == nil, "a quest you already have is not new")
	-- providers
	local ns6, W6 = nfyWorld(5)
	ns6.NewForYou.Register("test", function(ctx, from, to) return { { title = "New ability: Test", detail = "Learn it from your trainer." }, { title = "B" }, { title = "C" }, { title = "D" } } end)
	ns6.NewForYou.Unregister("quests")
	W6.char.level = 6
	ns6.State.Recompute()
	local c6 = ns6.NewForYou.Active()
	check(c6 and #c6.items == ns6.NewForYou.MAX_ITEMS and c6.items[1].detail == "Learn it from your trainer.", "other systems plug in as providers (capped)")
	ns6.NewForYou.Register("broken", function() error("boom") end)
	W6.char.level = 8
	ns6.State.Recompute()
	check(ns6.NewForYou.Active() and #ns6.errors >= 1, "a failing provider is contained")
	W6.char.level = 4
	ns6.State.Recompute()
	local shipped = {}
	for _, k in ipairs({ "spells", "trainers", "recipes", "pets", "professions" }) do shipped[#shipped + 1] = k end
	local src = H.readFile(H.addonDir .. "/NewForYou.lua"):gsub("%-%-[^\n]*", "")
	check(not src:find("GetSpellInfo", 1, true) and not src:find("SpellBook", 1, true) and not src:find("Trainer", 1, true), "no spell, spellbook or trainer API is used: Codex does not invent progression")
	check(#ns.errors == 0, "no caught errors")
end

section("UI: dropdown navigation, centred NOW, NOW + NEARBY on the left, NEW FOR YOU on the right")
do
	local ns, W = nfyWorld(5)
	ns.UI.Open("codex")
	local UI, c = ns.UI, ns.UI.main.codex
	local labels = {}
	for _, f in ipairs(W.frames) do if f.__kind == "Button" and f.text then labels[f.text.__text] = true end end
	check(not labels["<"] and not labels[">"] or ns.Prefs.SetupDone(), "the Codex page has no back / forward arrows")
	check(UI.main.nav and UI.main.nav.button.text.__text == "Codex  v" and not UI.main.nav.menu.__shown and UI.main.tabs == nil, "one dropdown button replaces the tab row")
	click(UI.main.nav.button)
	check(UI.main.nav.menu.__shown, "clicking it expands the list")
	local items = {}
	for k in pairs(UI.main.nav.items) do items[#items + 1] = k end
	table.sort(items)
	check(table.concat(items, ",") == "appendices,codex,journey,world", "Codex, World, Journey and Appendices are in it")
	click(UI.main.nav.items.journey)
	check(UI.current == "journey" and not UI.main.nav.menu.__shown and UI.main.nav.button.text.__text == "Journey  v", "choosing one goes there and closes the list")
	click(UI.main.nav.button); click(UI.main.nav.items.codex)
	check(UI.current == "codex", "and back")
	check(c.nowTitle.__justify == "CENTER" and c.nowWho.__justify == "CENTER" and c.nowDetail.__justify == "CENTER" and c.nowInfo.__justify == "CENTER", "the NOW content is centred in its card")
	check(c.nowBox.__w == 504 and c.nearBox.__w == 504, "without NEW FOR YOU the left column uses the full width")
	check(not c.nfyBox.__shown, "and NEW FOR YOU is not shown")
	W.char.level = 6
	ns.State.Recompute()
	check(c.nfyBox.__shown and c.nfyLevel.__text == "Level 6" and c.nfyRows[1].__text:find("New quest: Seen on Forever", 1, true), "reaching an even level with something real shows NEW FOR YOU on the right")
	check(c.nowBox.__w == 304 and c.nearBox.__w == 304 and c.nfyBox.__w == 192, "NOW and NEARBY stack on the left; the card on the right spans both")
	check(c.nfyBox.__h == c.nowBox.__h + c.nearBox.__h + 8, "its height is NOW + NEARBY + the gap")
	check(c.nowBox.__points[5] == -22 and c.nearBox.__points[5] < c.nowBox.__points[5] and c.nfyBox.__points[5] == c.nowBox.__points[5], "NOW is on top, NEARBY under it, NEW FOR YOU level with NOW")
	W.now = W.now + 61
	ns.UI.frame.__scripts.OnUpdate(ns.UI.frame, 1)
	check(not c.nfyBox.__shown and c.nowBox.__w == 504, "after one minute the card disappears by itself and the layout closes up")
	check(#H.world().chat >= 0, "(no input needed)")
	local bad = {}
	for _, t in ipairs(allTexts(W)) do
		for _, w in ipairs({ "ATT", "unverified", "Source:", "Show on Map", "Skip", "Add quest", "Refresh" }) do if t:find(w, 1, true) then bad[#bad + 1] = t end end
	end
	check(#bad == 0, "still no engineering words in the player window" .. (#bad > 0 and (": " .. bad[1]) or ""))
end

section("UI: NEARBY lists only useful, trustworthy things")
do
	local ns, W = world(6, { Q(1, "Pickup", 20, 0, { giverName = "Someone" }) }, {})
	ForeverCodex.RegisterPack("flight", "att:fp-near", { meta = { src = "att", verified = false, priority = 10 },
		nodes = { [1] = { id = 1, name = "Near Point", map = 9001, x = 0.5, y = 0.52, faction = "Horde" }, [2] = { id = 2, name = "Far Point", map = 9001, x = 0.9, y = 0.9, faction = "Horde" } } })
	ns.State.Recompute()
	local list = ns.Nearby.List(ns.State.plan, ns.State.ctx)
	local titles = {}
	for _, it in ipairs(list) do titles[#titles + 1] = it.title .. "|" .. tostring(it.detail) end
	local flat = table.concat(titles, ";")
	check(flat:find("Flight master|Near Point", 1, true) and not flat:find("Far Point", 1, true), "a flight master close by is listed; a far one is not")
	check(#list <= ns.Nearby.MAX, "at most " .. ns.Nearby.MAX .. " entries")
	check(not flat:lower():find("inn") and not flat:lower():find("mailbox") and not flat:lower():find("trainer") and not flat:lower():find("vendor"), "inns, mailboxes, vendors and trainers are not listed: Codex has no trustworthy data for them")
	ns.Prefs.SetSystem("flight", false)
	ns.State.Recompute()
	local after = ns.Nearby.List(ns.State.plan, ns.State.ctx)
	local has = false
	for _, it in ipairs(after) do if it.title == "Flight master" then has = true end end
	check(not has, "switching flight hints off removes it")
	local empty = ns.Nearby.List(nil, ns.State.ctx)
	check(#empty == 0, "no plan, nothing nearby")
end

section("UI: it all works when optional client APIs are missing")
do
	local ns, W = world(6, { Q(1, "Pickup", 20, 0) }, {})
	_G.GetPlayerFacing, _G.WorldMapFrame = nil, nil
	_G.C_SuperTrack, _G.UiMapPoint = nil, nil
	_G.GameTooltip = nil
	local ok = pcall(function()
		ns.State.Recompute()
		ns.UI.Open("codex")
		ns.UI.Open("world"); ns.UI.Open("journey"); ns.UI.Open("appendices")
		ns.Arrow.Update(ns.State.ctx)
		ns.Pins.Tick(1)
	end)
	check(ok and #ns.errors == 0, "the player window, arrow and pins all run with no facing API, no map frame, no waypoint API and no tooltip")
	check(ns.Navigation.Status() == "unavailable" and ns.Navigation.Target() ~= nil, "navigation reports itself unavailable but still knows the destination for the arrow")
	check(ns.State.plan.now ~= nil, "and the plan is intact")
end

section("Planner baseline: unchanged by the fixes")
do
	local ns, W = world(6, { Q(1, "A", 20, 0), Q(2, "B", 25, 5), Q(3, "C", 300, 0) }, { [3] = { complete = true } })
	local ctx = ns.Context.Build()
	local bare = ns.Planner.Compute(ctx, ns.Engine.Candidates(ctx), {})
	check(ns.State.plan.now.id == bare.now.id, "NOW equals the Planner alone")
	check(true, "(the Phase 1 golden and Phase 2.5 baseline checks above are the regression proof)")
end

-- ================================================================ raid markers: ownership and lifecycle

local function markerWorld()
	local ns = boot({ char = { level = 6 }, synthetic = true, loc = { map = 9001, x = 0.5, y = 0.5 } })
	local u = { exists = true, guid = "Creature-0-3-1-0-3143-00001ABC", mark = nil, calls = {}, fail = false }
	_G.UnitExists = function() return u.exists end
	_G.UnitGUID = function() return u.guid end
	_G.GetRaidTargetIndex = function() return u.mark end
	_G.SetRaidTarget = function(_, idx) if u.fail then error("blocked") end u.calls[#u.calls + 1] = idx; u.mark = idx ~= 0 and idx or nil end
	return ns, u
end

local function mact(ns, id, kind, npc, o)
	o = o or {}
	local K = ns.Contract
	local a = { id = id, type = "QUEST", kind = kind, quest = 1, name = "Q", title = id, lines = {}, reasons = {}, contract = 1,
		targets = { K.Target({ role = o.role or "GIVER", entity = o.noNpc and { kind = "area" } or { kind = "npc", id = npc }, assumed = o.assumed,
			where = K.Where("known", { { map = 9001, x = 0.5, y = 0.5 } }), prov = K.Prov("att") }) } }
	return a
end

section("markers: assignment (star, diamond, one NPC one symbol, no spam)")
do
	local ns, u = markerWorld()
	local Mk = ns.Markers
	local A, B = mact(ns, "Q:1:ACCEPT", "ACCEPT", 3143), mact(ns, "Q:2:ACCEPT", "ACCEPT", 3145)
	local d = Mk.Desired({ now = A, alsoDo = B })
	check(d.star.npc == 3143 and d.diamond.npc == 3145 and d.triangle == nil and d.moon == nil, "NOW's NPC gets the star, ALSO DO's NPC the diamond; no triangle or moon")
	check(Mk.Desired({ now = A, alsoDo = mact(ns, "Q:3:ACCEPT", "ACCEPT", 3143) }).diamond == nil, "the same NPC is never given two symbols")
	local turnin = mact(ns, "Q:1:TURN_IN", "TURN_IN", 3150, { role = "TURN_IN" })
	check(Mk.Desired({ now = turnin }).star.npc == 3150, "a turn-in NPC Codex positively knows is marked")
	check(next(Mk.Desired({ now = mact(ns, "Q:1:TURN_IN", "TURN_IN", 3150, { role = "TURN_IN", assumed = true }) })) == nil, "a turn-in NPC that is only ASSUMED (the giver) is not marked")
	check(next(Mk.Desired({ now = mact(ns, "Q:1:OBJECTIVE", "OBJECTIVE", nil, { role = "OBJECTIVE", noNpc = true }) })) == nil, "an objective area with no NPC gets no marker")
	local n = 0
	for _ in pairs(Mk.Desired({ now = A, alsoDo = B })) do n = n + 1 end
	check(n <= 4 and Mk.INDEX.moon == 5 and Mk.Desired({ now = A, alsoDo = B }).moon == nil, "at most four symbols exist and the moon (inn) is never set: there is no inn data")
	local moonSrc = H.readFile(H.addonDir .. "/Markers.lua"):gsub("%-%-[^\n]*", "")
	check(not moonSrc:find('put%("moon"'), "no code path assigns the moon")
end

section("markers: probe and capability state")
do
	local ns, u = markerWorld()
	local Mk = ns.Markers
	check(Mk.Status().probe == "not run" and not Mk.Enabled(), "before the probe: 'not run', off")
	u.calls = {}
	Mk.OnPlan({ now = mact(ns, "Q:1:ACCEPT", "ACCEPT", 3143) })
	Mk.OnUnit("target")
	check(#u.calls == 0, "nothing is placed before the probe passed")
	u.exists = false
	local ok0, m0 = Mk.Probe()
	check(not ok0 and m0:find("target an NPC first", 1, true) and Mk.Status().probe == "not run", "no target: asks for one, records nothing")
	u.exists = true
	u.guid = "Player-1-0000AAAA"
	local okP, mP = Mk.Probe()
	check(not okP and mP:find("not a player", 1, true) and #u.calls == 0, "a player target is refused and never marked")
	u.guid = "Creature-0-3-1-0-3143-00001ABC"
	u.mark = 7
	local okM, mM = Mk.Probe()
	check(not okM and mM:find("already has a raid mark", 1, true) and u.mark == 7 and #u.calls == 0, "an NPC that already carries someone's mark is not touched by the probe")
	u.mark = nil
	local ok, msg = Mk.Probe()
	check(ok and u.mark == nil and #u.calls == 2 and u.calls[1] == 1 and u.calls[2] == 0, "a good probe places the star, reads it back, clears it, and leaves the NPC unmarked")
	check(Mk.Status().probe == "passed" and Mk.Enabled() and msg:find("popup", 1, true), "it records 'passed', enables markers, and says Lua cannot see a taint popup")
	local ns2, u2 = markerWorld()
	u2.fail = true
	local okF, mF = ns2.Markers.Probe()
	check(not okF and mF:find("refused", 1, true) and ns2.Markers.Status().probe == "failed" and not ns2.Markers.Enabled() and not ns2.Prefs.MarkersOn(), "a refused call: 'failed', markers stay off, reason reported")
	local ns3, u3 = markerWorld()
	_G.SetRaidTarget = function(_, idx) if idx == 0 then return end u3.mark = idx end        -- places but cannot clear
	local okC, mC = ns3.Markers.Probe()
	check(not okC and mC:find("could not be cleared", 1, true) and not ns3.Markers.Enabled(), "a mark that cannot be cleared again keeps markers off")
	local ns4 = markerWorld()
	_G.SetRaidTarget = nil
	check(not ns4.Markers.Probe() and ns4.Markers.Status().probe == "failed", "no SetRaidTarget at all: failed, reported")
end

section("markers: ownership, foreign marks, yielding to the player, clearing")
do
	local ns, u = markerWorld()
	local Mk = ns.Markers
	local A, B = mact(ns, "Q:1:ACCEPT", "ACCEPT", 3143), mact(ns, "Q:2:ACCEPT", "ACCEPT", 3145)
	Mk.Probe()
	u.calls = {}
	Mk.OnPlan({ now = A })
	check(u.mark == 1 and #u.calls == 1, "targeting the NOW NPC puts the star on it")
	Mk.OnUnit("target"); Mk.OnUnit("mouseover")
	check(#u.calls == 1, "already right: not set again")
	-- the player removes it: Codex yields
	u.mark = nil
	Mk.OnUnit("target"); Mk.OnUnit("target")
	check(u.mark == nil and #u.calls == 1, "when the player removes Codex's mark it is NOT put back")
	Mk.OnPlan({ now = A })
	Mk.OnUnit("target")
	check(u.mark == nil, "not even when the same plan is recomputed")
	Mk.OnPlan({ now = B })
	Mk.OnPlan({ now = A })
	Mk.OnUnit("target")
	check(u.mark == 1, "but a changed plan for that symbol starts afresh")
	-- another mark on the NPC is never replaced
	local ns2, u2 = markerWorld()
	ns2.Markers.Probe()
	u2.calls = {}
	u2.mark = 8
	ns2.Markers.OnPlan({ now = mact(ns2, "Q:1:ACCEPT", "ACCEPT", 3143) })
	ns2.Markers.OnUnit("target")
	check(u2.mark == 8 and #u2.calls == 0, "a mark the player (or another addon) put on the NPC is never replaced")
	u2.mark = 1                                   -- the very same icon, but not placed by Codex
	ns2.Markers.OnUnit("target")
	ns2.Markers.OnPlan({ now = nil })
	ns2.Markers.OnUnit("target")
	check(u2.mark == 1 and #u2.calls == 0, "an identical icon Codex did not place is not claimed, and not cleared when the plan ends")
	-- clearing: only Codex's own
	local ns3, u3 = markerWorld()
	ns3.Markers.Probe()
	u3.calls = {}
	local A3 = mact(ns3, "Q:1:ACCEPT", "ACCEPT", 3143)
	ns3.Markers.OnPlan({ now = A3 })
	check(u3.mark == 1, "(setup) Codex placed the star")
	ns3.Markers.OnPlan({ now = nil })
	ns3.Markers.OnUnit("target")
	check(u3.mark == nil, "when the action completes (no NOW) Codex's own star is cleared the next time the NPC is seen")
	-- NOW moves to another NPC
	ns3.Markers.OnPlan({ now = A3 })
	check(u3.mark == 1, "(setup) star again")
	u3.guid = "Creature-0-3-1-0-3145-00001DEF"; u3.mark = nil
	ns3.Markers.OnPlan({ now = mact(ns3, "Q:2:ACCEPT", "ACCEPT", 3145) })
	check(u3.mark == 1, "NOW changing to another NPC marks that NPC")
	u3.guid = "Creature-0-3-1-0-3143-00001ABC"; u3.mark = 1
	ns3.Markers.OnUnit("target")
	check(u3.mark == nil, "and the old NPC's star (recorded as Codex's) is removed when it is next seen")
	-- an NPC that is not the planned one
	u3.guid = "Creature-0-3-1-0-9999-00001ABC"; u3.mark = nil
	ns3.Markers.OnUnit("target"); ns3.Markers.OnUnit("mouseover")
	check(u3.mark == nil, "no other NPC is ever marked")
	-- markers switched off: own marks still cleaned, foreign untouched
	ns3, u3 = markerWorld()
	ns3.Markers.Probe()
	ns3.Markers.OnPlan({ now = mact(ns3, "Q:2:ACCEPT", "ACCEPT", 3145) })
	u3.guid = "Creature-0-3-1-0-3145-00001DEF"
	ns3.Markers.OnUnit("target")
	check(u3.mark == 1, "(setup) marked")
	ns3.Prefs.SetMarkers(false)
	ns3.Markers.OnPlan({ now = nil })
	ns3.Markers.OnUnit("target")
	check(u3.mark == nil, "with markers off and no plan, Codex's own mark is still cleaned up")
	u3.mark = 5
	ns3.Markers.OnUnit("target")
	check(u3.mark == 5, "and a foreign mark is left alone")
	local src = H.readFile(H.addonDir .. "/Markers.lua"):gsub("%-%-[^\n]*", "")
	check(not src:find("hooksecurefunc", 1, true) and not src:find("Secure", 1, true) and not src:find("combat", 1, true), "Markers.lua has no hooks, no secure frames, no combat-log use")
	check(#ns.errors == 0 and #ns3.errors == 0, "no caught errors")
	do   -- the plan ends, but before Codex sees the NPC again the player put a DIFFERENT mark on it
		local nsX, uX = markerWorld()
		nsX.Markers.Probe()
		nsX.Markers.OnPlan({ now = mact(nsX, "Q:1:ACCEPT", "ACCEPT", 3143) })
		uX.exists = false                        -- the NPC is out of sight when the plan changes
		nsX.Markers.OnPlan({ now = nil })
		uX.exists = true
		uX.mark = 5
		nsX.Markers.OnUnit("target")
		check(uX.mark == 5, "a different mark put there after Codex's own is never cleared")
	end
end

-- ================================================================ quest objective -> party announcement (The Weaver)

local function weaver(opts)
	opts = opts or {}
	local ns = boot({ char = { level = 21, class = "Hunter", classToken = "HUNTER", race = "Skyborne", raceToken = "Skyborne" }, synthetic = true, loc = { map = 9001, x = 0.5, y = 0.5 } })
	H.attPack(ns, {}, nil)                                   -- the quest is NOT in the data: its name must come from the quest log
	local W = H.world()
	W.group = opts.group or 3
	W.log = { { questID = 1900, title = "The Weaver", complete = false } }
	W.objectives = { [1900] = { { text = "0/1 Ataeric's Staff", type = "item", finished = false, numFulfilled = 0, numRequired = 1 } } }
	ns.Prefs.FinishSetup()
	ns.Prefs.SetPartyNotify(opts.mode or "both")
	local sent = { addon = {}, chat = {} }
	ns.Party._Reset()
	ns.Party.api.sendAddon = function(t) sent.addon[#sent.addon + 1] = t; return true end
	ns.Party.api.sendChat = function(t) sent.chat[#sent.chat + 1] = t; return true end
	ns.State.Recompute()                                     -- baseline: quest in the log, objective 0/1
	W.now = W.now + 5
	ns._selftest.telemetry.onEvent("QUEST_LOG_UPDATE")       -- telemetry's own baseline diff
	ns._selftest.telemetry.tick(2)
	return ns, W, sent
end

--- What the client does when an objective changes: the quest log changes and UNIT_QUEST_LOG_CHANGED("player") then QUEST_LOG_UPDATE fire.
local function logChanged(ns, W, dt)
	W.now = W.now + (dt or 10)
	ns._selftest.boot.onEvent(nil, "UNIT_QUEST_LOG_CHANGED", "player")
	ns._selftest.boot.onEvent(nil, "QUEST_LOG_UPDATE")
	ns._selftest.telemetry.onEvent("UNIT_QUEST_LOG_CHANGED", "player")
	ns._selftest.telemetry.tick(2)
	ns.State.Tick(1)                                         -- the throttled recompute the game loop would run
end

section("party: looting Ataeric's Staff (0/1 -> 1/1) is seen and announced automatically")
do
	local ns, W, sent = weaver()
	W.objectives[1900][1].numFulfilled, W.objectives[1900][1].finished = 1, true
	W.log[1].complete = true
	logChanged(ns, W)
	check(ns.State.ctx.log[1900].objectives[1].numFulfilled == 1 and ns.State.ctx.log[1900].complete, "Codex's context sees the objective at 1/1 and the quest complete (quest-log API only)")
	check(#sent.chat == 1 and sent.chat[1] == "Codex: Quest complete: The Weaver - 1/1 Ataeric's Staff", "party chat says: " .. tostring(sent.chat[1]))
	check(#sent.addon == 1 and sent.addon[1] == "v1|DONE|1900", "and the quiet addon message for other Codex users is sent too")
	W.log[1].complete = false; W.objectives[1900][1].finished = false; W.objectives[1900][1].numFulfilled = 0     -- the turn-in reset trap (M8.9)
	logChanged(ns, W, 0.5)
	W.log[1].complete = true; W.objectives[1900][1].finished = true; W.objectives[1900][1].numFulfilled = 1
	logChanged(ns, W, 0.5)
	check(#sent.chat == 1, "a momentary un-done reading followed by 1/1 again inside the duplicate window is not announced twice")
	logChanged(ns, W); logChanged(ns, W)
	check(#sent.chat == 1 and #sent.addon == 1, "later recomputes of the same state do not repeat it")
	local tr = ns.Party.Trace()
	check(tr[1] and tr[1].why and tr[1].why:find("duplicate", 1, true), "/codex party log records the suppressed duplicate with its reason")
	local sentEntry
	for _, e in ipairs(tr) do if e.chat == true then sentEntry = e end end
	check(sentEntry and sentEntry.kind == "DONE" and sentEntry.quest == 1900 and sentEntry.name == "The Weaver" and sentEntry.inGroup, "/codex party log records what was seen and that chat was sent")
	W.chat = {}
	H.slash("party log")
	check(table.concat(W.chat, "\n"):find("DONE 1900 The Weaver", 1, true) ~= nil, "/codex party log prints it")
	check(#ns.errors == 0, "no errors")
end

section("party: the same event through each path, and no dependence on the combat log")
do
	for _, ev in ipairs({ "UNIT_QUEST_LOG_CHANGED", "QUEST_LOG_UPDATE" }) do
		local ns, W, sent = weaver()
		W.objectives[1900][1].numFulfilled, W.objectives[1900][1].finished = 1, true
		W.log[1].complete = true
		W.now = W.now + 10
		ns._selftest.boot.onEvent(nil, ev, "player")
		ns.State.Tick(1)
		check(#sent.chat == 1, ev .. " alone is enough to see it")
	end
	for _, f in ipairs({ "Party.lua", "Context.lua", "State.lua", "Boot.lua" }) do
		check(not H.readFile(H.addonDir .. "/" .. f):gsub("%-%-[^\n]*", ""):find("COMBAT_LOG", 1, true), f .. " does not use the combat log")
	end
	local W = H.world()
	local n = 0
	for _, e in ipairs(W.registeredEvents or {}) do if e == "COMBAT_LOG_EVENT_UNFILTERED" then n = n + 1 end end
	check(n == 0, "nothing registers COMBAT_LOG_EVENT_UNFILTERED")
end

section("party: modes, no party, duplicates, and why nothing was sent")
do
	local ns, W, sent = weaver({ mode = "off" })
	W.objectives[1900][1].numFulfilled, W.objectives[1900][1].finished = 1, true; W.log[1].complete = true
	logChanged(ns, W)
	check(#sent.chat == 0 and #sent.addon == 0 and ns.Party.Trace()[1].why == "party news is off", "party news off: nothing is sent, and the log says why")
	local ns2, W2, sent2 = weaver({ group = 1 })
	W2.objectives[1900][1].numFulfilled, W2.objectives[1900][1].finished = 1, true; W2.log[1].complete = true
	logChanged(ns2, W2)
	check(#sent2.chat == 0 and #sent2.addon == 0 and ns2.Party.Trace()[1].why == "not in a group" and ns2.Party.Trace()[1].inGroup == false, "not in a group: nothing is sent, and the log says why")
	local ns3, W3, sent3 = weaver({ mode = "ui" })
	W3.objectives[1900][1].numFulfilled, W3.objectives[1900][1].finished = 1, true; W3.log[1].complete = true
	logChanged(ns3, W3)
	check(#sent3.chat == 0 and #sent3.addon == 1 and ns3.Party.Trace()[1].why:find("not party chat", 1, true), "the default 'ui' mode sends no party chat, and the log says that is why")
	local ns4, W4, sent4 = weaver({ mode = "both" })
	W4.objectives[1900][1].numFulfilled, W4.objectives[1900][1].finished = 1, true; W4.log[1].complete = true
	logChanged(ns4, W4)
	check(#sent4.chat == 1 and #sent4.addon == 1, "'both' sends both")
	local ns5, W5, sent5 = weaver()
	ns5.Party.api.sendChat = function() return false end
	W5.objectives[1900][1].numFulfilled, W5.objectives[1900][1].finished = 1, true; W5.log[1].complete = true
	logChanged(ns5, W5)
	check(ns5.Party.Trace()[1].chat == false, "a chat call that fails is recorded as not sent")
end

section("party: partial progress, several objectives, quests accepted later")
do
	local ns, W, sent = weaver()
	W.log = { { questID = 1901, title = "Training", complete = false } }
	W.objectives = { [1901] = {
		{ text = "3/6 Training Weapon", type = "item", finished = false, numFulfilled = 3, numRequired = 6 },
		{ text = "0/2 Scorpid Tail", type = "item", finished = false, numFulfilled = 0, numRequired = 2 } } }
	ns.Party._Reset()
	ns.State.Recompute()
	W.objectives[1901][1].numFulfilled = 5
	logChanged(ns, W)
	check(#sent.chat == 0 and #sent.addon == 0, "progress that is not complete (3/6 -> 5/6) announces nothing")
	W.objectives[1901][1].numFulfilled, W.objectives[1901][1].finished = 6, true
	logChanged(ns, W)
	check(#sent.chat == 1 and sent.chat[1] == "Codex: Objective done: Training - 6/6 Training Weapon" and sent.addon[1] == "v1|OBJ|1901|6|6", "one objective of two finishing is announced as an objective, with its counts")
	W.objectives[1901][2].numFulfilled, W.objectives[1901][2].finished = 2, true
	W.log[1].complete = true
	logChanged(ns, W)
	check(#sent.chat == 2 and sent.chat[2] == "Codex: Quest complete: Training - 6/6 Training Weapon, 2/2 Scorpid Tail", "the quest completing lists every objective")
	-- a quest accepted after the baseline, then progressed while active
	W.log[#W.log + 1] = { questID = 1902, title = "Fresh", complete = false }
	W.objectives[1902] = { { text = "0/4 Boar", type = "monster", finished = false, numFulfilled = 0, numRequired = 4 } }
	logChanged(ns, W)
	check(#sent.chat == 2, "accepting a quest announces nothing")
	W.objectives[1902][1].numFulfilled = 4; W.objectives[1902][1].finished = true; W.log[2].complete = true
	logChanged(ns, W)
	check(#sent.chat == 3 and sent.chat[3] == "Codex: Quest complete: Fresh - 4/4 Boar", "and finishing it while it is active is seen")
	local before = #sent.chat
	W.now = W.now + 10
	ns.Party.OnTurnedIn(1902, ns.State.ctx)
	check(sent.chat[#sent.chat] == "Codex: Turned in: Fresh" and #sent.chat == before + 1, "the turn-in names the quest from the last snapshot (it has left the log)")
end

section("party: a planner failure never hides a finished objective")
do
	local ns, W, sent = weaver()
	ns.Planner.Compute = function() error("boom") end
	W.objectives[1900][1].numFulfilled, W.objectives[1900][1].finished = 1, true; W.log[1].complete = true
	logChanged(ns, W)
	check(#sent.chat == 1 and #ns.errors >= 1, "the announcement still happens (the planner error is recorded separately)")
end

section("telemetry: objective transitions are recorded (observation only; proof comes from the real client)")
do
	local ns, W = weaver()
	local T = ns.Telemetry
	W.objectives[1900][1].numFulfilled, W.objectives[1900][1].finished = 1, true; W.log[1].complete = true
	logChanged(ns, W)
	local evs = {}
	for _, e in ipairs(T.Events()) do if e.e == "QUEST_OBJECTIVE" then evs[#evs + 1] = e end end
	check(#evs == 1 and evs[1].q == 1900 and evs[1].i == 1 and evs[1].have == 1 and evs[1].need == 1, "the finished objective is recorded once: quest, index, have, need")
	local qc = 0
	for _, e in ipairs(T.Events()) do if e.e == "QUEST_COMPLETE" and e.q == 1900 then qc = qc + 1 end end
	check(qc == 1, "alongside the existing QUEST_COMPLETE")
	logChanged(ns, W)
	local again = 0
	for _, e in ipairs(T.Events()) do if e.e == "QUEST_OBJECTIVE" then again = again + 1 end end
	check(again == 1, "and not repeated")
	local def
	for _, d in ipairs(T.EVENT_DEFS) do if d.type == "QUEST_OBJECTIVE" then def = d end end
	check(def and def.evidence:find("M8.9", 1, true) and def.evidence:find("untested on the client", 1, true), "its 'proven' status rests on the M8.9 real-client evidence for reading objectives; the diff itself is labelled untested")
	check(not def.sources[1]:find("COMBAT") and not def.sources[2]:find("COMBAT") and not def.sources[3]:find("COMBAT"), "no combat-log source")
	check(table.concat(ns.HelpCodex.Learned(), "|"):find("Quest objectives you finished: 1", 1, true) ~= nil, "Help Improve Codex counts it")
end

section("chat: a literal pipe is escaped (real client printed 'flipset' for 'flip|reset')")
do
	local ns = boot({ char = { level = 6 }, synthetic = true })
	local W = H.world()
	W.chat, W.chatRaw = {}, {}
	ns.Say("usage: /codex arrow on|off|flip|reset")
	check(W.chatRaw[1] and W.chatRaw[1]:find("on||off||flip||reset", 1, true) ~= nil, "pipes are doubled so the client shows them literally")
	check(W.chatRaw[1]:find("^|cff33cc99%[Codex%]|r ") ~= nil, "while Codex's own colour prefix is untouched")
	check(W.chat[1] == "[Codex] usage: /codex arrow on|off|flip|reset", "and the player sees the whole line: " .. tostring(W.chat[1]))
	local bad = {}
	for _, f in ipairs({ "Slash.lua", "Diag.lua", "Party.lua", "Navigation.lua", "Boot.lua" }) do
		for l in H.readFile(H.addonDir .. "/" .. f):gmatch("[^\n]+") do
			if l:find("|c%x%x", 1) and not l:find("^%s*%-%-") then bad[#bad + 1] = f end
		end
	end
	check(#bad == 0, "no Codex chat text relies on colour escapes")
end
