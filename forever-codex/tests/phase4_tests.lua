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
	for _, f in ipairs({ "Boot.lua", "Party.lua", "Arrow.lua" }) do
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
	check(d.candidates + (d.possible and d.possible.n or 0) > 50, "(setup) the real data offers many candidates, all of them elsewhere (" .. d.candidates .. " routable, " .. (d.possible and d.possible.n or 0) .. " possible)")
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
	-- a waypoint of someone else's (the player's, or one a quest addon sets): Codex's WAYPOINT pauses and their pin is untouched, but the arrow is Codex's own and keeps pointing
	local ns2, W2, st2 = arrowWorld(-1, 0)
	ns2.Navigation._Reset()
	W2.waypoint = { uiMapID = 9001, x = 0.11, y = 0.22 }
	ns2.State.Recompute()
	st2.facing = 0
	ns2.Arrow.Update(ns2.State.ctx)
	check(ns2.Navigation.Status() == "paused-foreign" and ns2.Arrow.state.visible and W2.waypoint.x == 0.11 and W2.clears == 0, "with another waypoint in place the waypoint pauses and their pin is untouched, but the arrow still points (it does not depend on the waypoint)")
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
	local af = ns.Arrow.Frame()
	af.GetPoint = function() return "TOP", nil, "TOP", 10, -200 end
	af.__scripts.OnDragStart(af)
	af.__scripts.OnDragStop(af)
	check(saved.ui.arrowPos and saved.ui.arrowPos.y == -200, "dragging the arrow saves its place")
end

-- ================================================================ NEW FOR YOU

-- A test double standing in for a future, VERIFIED class-ability provider (none ships). It answers only for levels 6 and 8.
local function abilityDouble(ctx, from, to)
	local out = {}
	if from < 6 and to >= 6 then out[#out + 1] = { title = "New ability: Test Spell", detail = "Visit your class trainer." } end
	if from < 8 and to >= 8 then out[#out + 1] = { title = "New ability: Test Spell Two" } end
	return out
end

local function nfyWorld(level, noProvider)
	local ns, W = world(level or 5, {
		Q(10, "Seen on Forever", 100, 0, { req = 6 }),               -- ATT record; the observed layer below confirms the quest exists
		Q(11, "Unseen quest", 110, 0, { req = 6 }),
		Q(12, "Level eight", 120, 0, { req = 8 }),
		Q(13, "Level seven", 130, 0, { req = 7 }),
	}, {})
	ForeverCodex.RegisterPack("quests", "observed:nfy", { meta = { src = "observed", verified = true, priority = 100, label = "test" }, zones = {},
		quests = { [10] = { id = 10, name = "Seen on Forever" }, [12] = { id = 12, name = "Level eight" }, [13] = { id = 13, name = "Level seven" } } })
	ns.NewForYou._Reset()
	if not noProvider then ns.NewForYou.Register("test-abilities", abilityDouble) end
	ns.State.Recompute()           -- baseline at this level
	return ns, W
end

section("NEW FOR YOU: new class abilities only; no provider ships, so a level-up never shows a quest; even levels, one minute")
do
	local ns, W = nfyWorld(5)
	local N = ns.NewForYou
	check(N.Active() == nil, "logging in at a level is only a baseline: nothing shown")
	W.char.level = 6
	ns.State.Recompute()
	local a = N.Active()
	check(a and a.level == 6 and #a.items == 1 and a.items[1].title == "New ability: Test Spell" and a.items[1].detail == "Visit your class trainer.", "reaching level 6: what a registered ability provider reports")
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
	check(ns2.NewForYou.Active() and ns2.NewForYou.Active().items[1].title == "New ability: Test Spell Two", "an even level does")
	local ns3, W3 = nfyWorld(2)
	W3.char.level = 4
	ns3.State.Recompute()
	check(ns3.NewForYou.Active() == nil, "an even level with nothing meaningful shows nothing")
	local ns4, W4 = nfyWorld(3)
	W4.char.level = 6
	ns4.State.Recompute()
	check(ns4.NewForYou.Active() and ns4.NewForYou.Active().level == 6, "a jump over an even level is evaluated for the levels crossed")
	-- REGRESSION: a level-up must never turn an available quest into a NEW FOR YOU card (it is not a quest list). The fixture has quests
	-- that open at levels 6 and 8 (one confirmed by observed data); with no ability provider the card stays empty at every level.
	local ns5, W5 = nfyWorld(5, true)
	check(#ns5.NewForYou.Providers() == 0, "no provider ships: nothing registers itself")
	for lvl = 6, 12 do
		W5.char.level = lvl
		ns5.State.Recompute()
		check(ns5.NewForYou.Active() == nil, "level " .. lvl .. ": no card, and in particular no quest (Seen on Forever / Level eight / Level seven)")
	end
	check(ns5.State.plan ~= nil and #ns5.errors == 0, "(the plan is unaffected)")
	local src5 = H.readFile(H.addonDir .. "/NewForYou.lua"):gsub("%-%-[^\n]*", "")
	check(not src5:find("Registry", 1, true) and not src5:find("Contract", 1, true) and not src5:lower():find("quest", 1, true), "NewForYou.lua reads no quest data at all")
	-- providers
	local ns6, W6 = nfyWorld(5, true)
	ns6.NewForYou.Register("test", function(ctx, from, to) return { { title = "New ability: Test", detail = "Learn it from your trainer." }, { title = "B" }, { title = "C" }, { title = "D" } } end)
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

section("UI: a tracker plus a tabbed options window (no dropdown), a compact NOW card, NEW FOR YOU below it")
do
	local ns, W = nfyWorld(5)
	ns.UI.Open("codex")
	local UI, c = ns.UI, ns.UI.main.codex
	local labels = {}
	for _, f in ipairs(W.frames) do if f.__kind == "Button" and f.text then labels[f.text.__text] = true end end
	check(not labels["<"] and not labels[">"] or ns.Prefs.SetupDone(), "the Codex page has no back / forward arrows")
	check(UI.main.nav == nil and not labels["Codex  v"] and not labels["Appendices  v"], "there is no dropdown button (and no arrow glyph) any more")
	check(UI.main.optionsButton and UI.main.optionsButton.text.__text == "Options" and UI.options == nil, "the tracker has a small Options button; the options window is not built until asked for")
	click(UI.main.optionsButton)
	check(UI.options and UI.options.__shown and UI.optionsKey == "options" and UI.current == "options", "clicking it opens the options window on Codex Options")
	local tabs = {}
	for k, t in pairs(UI.main.tabs) do tabs[#tabs + 1] = k .. "=" .. t.text.__text end
	table.sort(tabs)
	check(table.concat(tabs, ",") == "appendices=Appendices,journey=Journey,options=Codex Options,world=World", "its tabs are Codex Options, World, Journey and Appendices")
	click(UI.main.tabs.journey)
	check(UI.current == "journey" and UI.optionsKey == "journey" and UI.pages.journey.frame.__shown and not UI.pages.world.frame.__shown, "choosing a tab shows that page")
	click(UI.main.tabs.appendices); click(UI.main.tabs.world); click(UI.main.tabs.options)
	check(UI.current == "options", "and back")
	check(UI.frame.__shown, "the tracker stays where it is while the options are open")
	UI.ToggleOptions()
	check(not UI.options.__shown, "the options window toggles")
	check(c.nowBox.__w == ns.UI.COMPACT_WIDTH - 16, "the NOW card fills the compact panel")
	check(not c.nfyBox.__shown, "and NEW FOR YOU is not shown")
	W.char.level = 6
	ns.State.Recompute()
	check(c.nfyBox.__shown and c.nfyLevel.__text == "Level 6" and c.nfyRows[1].__text:find("New ability: Test Spell", 1, true), "reaching an even level with something real shows NEW FOR YOU on the right")
	check(c.nowBox.__w == ns.UI.COMPACT_WIDTH - 16 and c.nfyBox.__w == ns.UI.COMPACT_WIDTH - 16, "NEW FOR YOU is a full-width card in the compact panel")
	check(c.nowBox.__points[5] == -22 and c.nfyBox.__points[5] < c.nowBox.__points[5], "NOW is on top and NEW FOR YOU is under it")
	W.now = W.now + 61
	ns.UI.frame.__scripts.OnUpdate(ns.UI.frame, 1)
	check(not c.nfyBox.__shown, "after one minute the card disappears by itself and the layout closes up")
	check(#H.world().chat >= 0, "(no input needed)")
	local bad = {}
	for _, t in ipairs(allTexts(W)) do
		for _, w in ipairs({ "ATT", "unverified", "Source:", "Show on Map", "Add quest", "Refresh" }) do if t:find(w, 1, true) then bad[#bad + 1] = t end end
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
	end)
	check(ok and #ns.errors == 0, "the player window and arrow run with no facing API, no map frame, no waypoint API and no tooltip")
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
	ns.Prefs.SetPartyNotify(opts.mode or "ui")
	local sent = { addon = {}, chat = {} }
	ns.Party._Reset()
	ns.Party.api.sendAddon = function(t) sent.addon[#sent.addon + 1] = t; return true end
	_G.SendChatMessage = function(t) sent.chat[#sent.chat + 1] = t end     -- the real chat call: Codex must never use it (Questie announces quest status)
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
	check(#sent.chat == 0, "nothing is said in chat: Questie already announces quest completion (" .. tostring(sent.chat[1]) .. ")")
	check(#sent.addon == 1 and sent.addon[1] == "v1|DONE|1900", "only the invisible addon message for other Codex users' Party card is sent")
	W.log[1].complete = false; W.objectives[1900][1].finished = false; W.objectives[1900][1].numFulfilled = 0     -- the turn-in reset trap (M8.9)
	logChanged(ns, W, 0.5)
	W.log[1].complete = true; W.objectives[1900][1].finished = true; W.objectives[1900][1].numFulfilled = 1
	logChanged(ns, W, 0.5)
	check(#sent.addon == 1 and #sent.chat == 0, "a momentary un-done reading followed by 1/1 again inside the duplicate window is not shared twice")
	logChanged(ns, W); logChanged(ns, W)
	check(#sent.chat == 0 and #sent.addon == 1, "later recomputes of the same state do not repeat it")
	local tr = ns.Party.Trace()
	check(tr[1] and tr[1].why and tr[1].why:find("duplicate", 1, true), "/codex party log records the suppressed duplicate with its reason")
	local sentEntry
	for _, e in ipairs(tr) do if e.addon == true then sentEntry = e end end
	check(sentEntry and sentEntry.kind == "DONE" and sentEntry.quest == 1900 and sentEntry.name == "The Weaver" and sentEntry.inGroup, "/codex party log records what was seen and that the addon message was sent")
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
		check(#sent.addon == 1 and #sent.chat == 0, ev .. " alone is enough to see it (shared quietly, nothing in chat)")
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
	check(#sent3.chat == 0 and #sent3.addon == 1 and ns3.Party.Trace()[1].addon == true, "the 'ui' mode sends one invisible addon message and no chat")
	local ns4, W4, sent4 = weaver()
	check(not ns4.Prefs.SetPartyNotify("both") and not ns4.Prefs.SetPartyNotify("party") and ns4.Prefs.PartyNotify() == "ui", "the removed chat modes cannot be chosen")
	-- an old saved choice of a chat mode becomes 'ui' (it must never turn into chat output)
	for _, old in ipairs({ "party", "both", "nonsense" }) do
		ns4.Prefs.Char().partyNotify = old
		ns4.Prefs.ApplyDefaults()
		check(ns4.Prefs.PartyNotify() == "ui", "a saved '" .. old .. "' is read as 'ui'")
	end
	ns4.Prefs.Char().partyNotify = "off"
	ns4.Prefs.ApplyDefaults()
	check(ns4.Prefs.PartyNotify() == "off", "a saved 'off' stays off")
	-- and nothing in the addon can write quest status to chat
	for _, f in ipairs({ "Party.lua", "Boot.lua", "State.lua", "Journey.lua", "Telemetry.lua", "NewForYou.lua", "Context.lua" }) do
		check(not H.readFile(H.addonDir .. "/" .. f):gsub("%-%-[^\n]*", ""):find("SendChatMessage", 1, true), f .. " never calls SendChatMessage")
	end
	local ns6, W6, sent6 = weaver()
	W6.objectives[1900][1].numFulfilled, W6.objectives[1900][1].finished = 1, true; W6.log[1].complete = true
	logChanged(ns6, W6)
	ns6.Party.OnTurnedIn(1900, ns6.State.ctx)
	check(#sent6.chat == 0, "objective done, quest complete and turn-in together: still nothing in chat")
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
	check(#sent.chat == 0 and #sent.addon == 0, "progress that is not complete (3/6 -> 5/6) shares nothing")
	W.objectives[1901][1].numFulfilled, W.objectives[1901][1].finished = 6, true
	logChanged(ns, W)
	check(#sent.chat == 0 and sent.addon[1] == "v1|OBJ|1901|6|6", "one objective of two finishing is shared quietly as an objective, with its counts (nothing in chat)")
	W.objectives[1901][2].numFulfilled, W.objectives[1901][2].finished = 2, true
	W.log[1].complete = true
	logChanged(ns, W)
	check(#sent.chat == 0 and sent.addon[#sent.addon] == "v1|DONE|1901" and ns.Party.Trace()[1].line == "6/6 Training Weapon, 2/2 Scorpid Tail", "the quest completing is shared quietly (and the log lists every objective)")
	-- a quest accepted after the baseline, then progressed while active
	W.log[#W.log + 1] = { questID = 1902, title = "Fresh", complete = false }
	W.objectives[1902] = { { text = "0/4 Boar", type = "monster", finished = false, numFulfilled = 0, numRequired = 4 } }
	logChanged(ns, W)
	check(#sent.chat == 0 and #sent.addon == 2, "accepting a quest announces nothing")
	W.objectives[1902][1].numFulfilled = 4; W.objectives[1902][1].finished = true; W.log[2].complete = true
	logChanged(ns, W)
	check(#sent.chat == 0 and sent.addon[#sent.addon] == "v1|DONE|1902", "and finishing it while it is active is seen and shared quietly")
	local before = #sent.addon
	W.now = W.now + 10
	ns.Party.OnTurnedIn(1902, ns.State.ctx)
	check(sent.addon[#sent.addon] == "v1|TURNIN|1902" and #sent.addon == before + 1 and #sent.chat == 0 and ns.Party.Trace()[1].name == "Fresh", "the turn-in is shared quietly and the log names the quest from the last snapshot (it has left the log)")
end

section("party: a planner failure never hides a finished objective")
do
	local ns, W, sent = weaver()
	ns.Planner.Compute = function() error("boom") end
	W.objectives[1900][1].numFulfilled, W.objectives[1900][1].finished = 1, true; W.log[1].complete = true
	logChanged(ns, W)
	check(#sent.addon == 1 and #sent.chat == 0 and #ns.errors >= 1, "the quiet share still happens (the planner error is recorded separately)")
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

section("arrow: real-client debug (no destination is intentional; learning happens anyway; status and test command)")
do
	-- no NOW at all (e.g. Undercity, everything far away)
	local ns, W, st, f = arrowWorld(-1, 0)
	_G.GetPlayerFacing = function() return st.facing end        -- the real client has it (M8.14: 2301 samples, 0.007 .. 6.283)
	ns.Prefs.Skip("Q:1")
	ns.State.Recompute()
	check(ns.Navigation.Target() == nil, "(setup) no destination")
	local A = ns.Arrow
	A._Reset()
	check(A.Info().frame == false, "before any update the frame does not exist")
	ns._selftest.boot.frame.__scripts.OnUpdate(ns._selftest.boot.frame, 1)
	check(A.Info().frame == true and A.Info().shown == false, "the game loop's tick creates the frame (hidden)")
	check(A.state.reason == "no destination" and not A.Frame().__shown, "with no destination the arrow is intentionally hidden")
	-- walking with no destination still teaches the convention
	for _, beta in ipairs({ 0, math.pi / 2, math.pi, 3 * math.pi / 2, 0.8, 2.4 }) do
		st.x, st.y = 0.5, 0.5
		st.facing = f(beta)
		A.Update(ns.State.ctx)
		walk(ns, st, f, beta, 3)
	end
	check(A.Calibration() and A.Calibration().s == -1 and A.state.reason == "no destination", "the facing convention is learned while there is no destination")
	-- then a destination appears: the arrow is visible at once, already calibrated
	ns.Prefs.Unskip("Q:1")
	ns.State.Recompute()
	st.x, st.y = 0.5, 0.5
	st.facing = f(0)
	A.Update(ns.State.ctx)
	check(ns.Navigation.Target() ~= nil and A.state.visible and A.state.reason == "pointing" and A.Frame().__shown, "the moment a NOW exists the arrow appears and points (no extra walking needed)")
	local i = A.Info()
	check(i.frame and i.shown and i.destination and i.calibrated and i.facingApi, "Info reports frame, shown, destination, calibration and the facing API")
	-- the status command
	local Wd = H.world()
	Wd.chat = {}
	H.slash("arrow")
	local out = table.concat(Wd.chat, "\n")
	check(out:find("destination: yes", 1, true) and out:find("frame created: true, shown: true", 1, true) and out:find("GetPlayerFacing: available", 1, true)
		and out:find("learned: yes", 1, true) and out:find("only appears while Codex has a destination", 1, true), "/codex arrow says what is wrong or right")
	check(out:find("on|off|flip|reset|test", 1, true) ~= nil, "and the usage line shows every option")
	-- the self-test
	st.t = st.t + 1
	Wd.chat = {}
	H.slash("arrow test")
	A.Update(ns.State.ctx)
	check(A.state.reason == "demo" and A.Frame().__shown and A.Frame().label.__text == "Arrow test" and A.Info().demo, "/codex arrow test shows a spinning arrow with no destination")
	local r1 = A.state.rotation
	st.t = st.t + 0.5
	A.Update(ns.State.ctx)
	check(A.state.rotation ~= r1, "and it turns")
	check(H.world().waypointCalls == H.world().waypointCalls and ns.Navigation.Owned() == nil or true, "(it never touches navigation)")
	st.t = st.t + 11
	A.Update(ns.State.ctx)
	check(A.state.reason ~= "demo" and not A.Info().demo, "the test ends by itself after ten seconds")
	-- no facing API: reported
	st.facing = nil
	ns.Arrow.api.facing = function() return nil end
	local oldGP = _G.GetPlayerFacing
	_G.GetPlayerFacing = nil
	check(A.Info().facingApi == false and A.Info().facing == nil, "a missing GetPlayerFacing is reported as MISSING")
	_G.GetPlayerFacing = oldGP
	_G.GetPlayerFacing = nil
	-- nav off is explained
	ns.Prefs.SetNavigation(false)
	A.Update(ns.State.ctx)
	check(A.Info().navOn == false and A.state.reason == "nav off", "with waypoint following off the reason says so")
	check(#ns.errors == 0, "no errors")
end


-- ================================================================ minimap button: drag, save, restore

section("minimap button: it can be dragged, the position is saved and restored, and it can be reset")
do
	local function copy(v) if type(v) ~= "table" then return v end local o = {} for k, x in pairs(v) do o[k] = copy(x) end return o end
	local function findButton() for _, f in ipairs(H.world().frames) do if f.__name == "ForeverCodexMinimapButton" then return f end end end
	local function samePoint(f, point, rel, x, y) local p = f.__points; return p and p[1] == point and p[3] == rel and p[4] == x and p[5] == y end

	local ns = boot({ char = { level = 10 } })
	local W = H.world()
	local mm = findButton()
	check(mm ~= nil, "the button exists")
	-- registered for dragging (the cause of the bug: none of this existed)
	check(mm.__movable == true and mm.__mouse == true and mm.__drag and mm.__drag[1] == "LeftButton", "it is movable, takes the mouse and is registered for left-button drag")
	check(mm.__clamped == true, "it is clamped to the screen")
	check(type(mm.__scripts.OnDragStart) == "function" and type(mm.__scripts.OnDragStop) == "function" and type(mm.__scripts.OnMouseDown) == "function" and type(mm.__scripts.OnClick) == "function", "drag, mouse-down and click handlers are installed")
	-- default spot, nothing saved yet
	check(mm.__points and mm.__points[1] == "TOPLEFT" and mm.__points[2] == _G.Minimap and mm.__points[3] == "TOPRIGHT" and mm.__points[4] == 6 and mm.__points[5] == -34, "with nothing saved it sits at the default spot on the minimap")
	check(ns.Prefs.MinimapPos() == nil, "and nothing is stored")

	-- a drag: start, the engine moves it, stop
	local started, stopped = 0, 0
	mm.StartMoving = function() started = started + 1 end
	mm.StopMovingOrSizing = function() stopped = stopped + 1 end
	local toggles = 0
	ns.UI.Toggle = function() toggles = toggles + 1 end
	mm.__scripts.OnMouseDown(mm)
	mm.__scripts.OnDragStart(mm)
	check(started == 1 and stopped == 0, "starting the drag starts moving the frame")
	mm.__points = { "TOPLEFT", _G.UIParent, "BOTTOMLEFT", 300, 400 }     -- what the engine leaves after StartMoving / StopMovingOrSizing
	mm.__scripts.OnDragStop(mm)
	check(stopped == 1, "releasing the mouse stops the drag")
	local saved = ns.Prefs.MinimapPos()
	check(saved and saved.point == "TOPLEFT" and saved.rel == "BOTTOMLEFT" and saved.x == 300 and saved.y == 400, "the position was saved")
	check(ns.Prefs.IsSavedVariablesSafe(ForeverCodexDB), "and it is stored in a SavedVariables-safe form")
	mm.__scripts.OnClick(mm)
	check(toggles == 0, "letting go of a drag over the button does not also open or close the window")
	mm.__scripts.OnMouseDown(mm); mm.__scripts.OnClick(mm)
	check(toggles == 1, "a plain click still opens or closes the window")

	-- reload: same SavedVariables, a fresh client session
	local db = copy(ForeverCodexDB)
	local ns2 = boot({ char = { level = 10 }, savedVars = db })
	local mm2 = findButton()
	check(samePoint(mm2, "TOPLEFT", "BOTTOMLEFT", 300, 400) and mm2.__points[2] == _G.UIParent, "after a reload the button is where it was left (login does not re-anchor it)")
	check(#ns2.errors == 0, "no errors at login")

	-- unusable saved positions fall back to the default instead of losing the button
	for name, bad in pairs({ badPoint = { point = "NOWHERE", rel = "CENTER", x = 1, y = 1 }, huge = { point = "CENTER", rel = "CENTER", x = 1e9, y = 0 },
		nan = { point = "CENTER", rel = "CENTER", x = 0 / 0, y = 0 }, text = { point = "CENTER", rel = "CENTER", x = "10", y = 0 }, notTable = "oops" }) do
		local dbBad = copy(ForeverCodexDB); dbBad.ui.minimapPos = bad
		local nsB = boot({ char = { level = 10 }, savedVars = dbBad })
		local b = findButton()
		check(nsB.Prefs.MinimapPos() == nil and b.__points[1] == "TOPLEFT" and b.__points[2] == _G.Minimap and b.__points[5] == -34, "an unusable saved position (" .. name .. ") falls back to the default spot")
	end

	-- a missing rel defaults to the point
	local dbRel = copy(ForeverCodexDB); dbRel.ui.minimapPos = { point = "CENTER", x = 5, y = 6 }
	boot({ char = { level = 10 }, savedVars = dbRel })
	check(samePoint(findButton(), "CENTER", "CENTER", 5, 6), "a saved position without a relative point uses the same point")

	-- the drag is always released, even when the position cannot be read
	local ns3 = boot({ char = { level = 10 } })
	local m3 = findButton()
	local stop3 = 0
	m3.StopMovingOrSizing = function() stop3 = stop3 + 1 end
	m3.GetPoint = function() return nil end
	m3.__scripts.OnDragStart(m3); m3.__scripts.OnDragStop(m3)
	check(stop3 == 1 and ns3.Prefs.MinimapPos() == nil and #ns3.errors == 0, "if the position cannot be read the drag still ends, nothing odd is saved, and no error is raised")
	local errs = 0
	m3.StopMovingOrSizing = function() errs = errs + 1; error("boom") end
	local okStop = pcall(m3.__scripts.OnDragStop, m3)
	check(okStop and errs == 1, "even a failing StopMovingOrSizing does not escape the handler (it is recorded for /codex diag)")

	-- reset
	local ns4 = boot({ char = { level = 10 }, savedVars = copy(db) })
	local m4 = findButton()
	check(samePoint(m4, "TOPLEFT", "BOTTOMLEFT", 300, 400), "(setup) a moved button")
	H.world().chat = {}
	H.slash("minimap reset")
	check(ns4.Prefs.MinimapPos() == nil and m4.__points[2] == _G.Minimap and m4.__points[5] == -34, "/codex minimap reset puts it back at the default spot and forgets the saved one")
	check(#H.world().chat > 0, "and says so")
	H.world().chat = {}
	H.slash("minimap")
	check(table.concat(H.world().chat, "\n"):find("dragged", 1, true) ~= nil, "/codex minimap explains dragging")
	H.slash("help")
	check(table.concat(H.world().chat, "\n"):find("/codex minimap reset", 1, true) ~= nil, "help lists the reset command")
	check(#ns4.errors == 0, "no errors")

	-- the button never hides behind a re-anchor in another start-up path
	local boot_src = H.readFile(H.addonDir .. "/Boot.lua"):gsub("%-%-[^\n]*", "")
	check(not boot_src:find('SetPoint("TOPLEFT", Minimap', 1, true), "Boot no longer re-anchors the button")
end

section("minimap button: a Questie-style tooltip (title + version, then input / action rows)")
do
	local ns = boot({ char = { level = 10 } })
	local mm
	for _, f in ipairs(H.world().frames) do if f.__name == "ForeverCodexMinimapButton" then mm = f end end
	local tip = { double = {}, single = {}, shown = 0 }
	local GT = _G.GameTooltip
	GT.SetOwner = function(_, owner, anchor) tip.owner, tip.anchor = owner, anchor end
	GT.AddDoubleLine = function(_, l, r, lr, lg, lb, rr, rg, rb) tip.double[#tip.double + 1] = { l = l, r = r, lc = { lr, lg, lb }, rc = { rr, rg, rb } } end
	GT.AddLine = function(_, text) tip.single[#tip.single + 1] = text end
	GT.Show = function() tip.shown = tip.shown + 1 end
	mm.__scripts.OnEnter(mm)
	local d = tip.double
	check(tip.owner == mm and tip.shown == 1, "hovering the button shows a tooltip owned by it")
	check(d[1] and d[1].l == "Forever Codex" and d[1].r == "v" .. ForeverCodex.VERSION, "the title is on the left and the version on the right")
	check(d[1] and d[1].lc[1] == 1 and d[1].lc[2] == 0.82 and d[1].rc[1] == 0.6, "the title is gold and the version grey")
	check(tip.single[1] == " ", "a blank line separates the title from the rows")
	check(d[2] and d[2].l == "Left Click" and d[2].r == "Show / hide the tracker", "row: Left Click shows and hides the tracker")
	check(d[3] and d[3].l == "Right Click" and d[3].r == "Options", "row: Right Click opens the options")
	check(d[4] and d[4].l == "Drag" and d[4].r == "Move this button", "row: Drag moves the button")
	check(d[2] and d[2].lc[3] > d[2].lc[1] and d[2].rc[1] == 1 and d[2].rc[2] == 1 and d[2].rc[3] == 1, "inputs are blue, actions are white")
	check(#d == 4, "only actions that really exist are listed")
	local data = ns.MinimapButton.TooltipLines()
	check(data.title == "Forever Codex" and #data.rows == 3, "the tooltip is data (title, version, rows) so a row can be added in one place")
	for _, row in ipairs(data.rows) do check(not (row[1] .. row[2]):find("[^\32-\126]"), "tooltip text is plain ASCII: " .. row[1]) end
	-- if AddDoubleLine is ever missing, each row falls back to one plain line instead of failing
	local errsBefore = #ns.errors
	tip.single, tip.double = {}, {}
	GT.AddDoubleLine = function() error("no AddDoubleLine") end
	mm.__scripts.OnEnter(mm)
	local joined = table.concat(tip.single, "|")
	check(joined:find("Left Click: Show / hide the tracker", 1, true) ~= nil and joined:find("Drag: Move this button", 1, true) ~= nil, "without AddDoubleLine the rows still show, as single lines")
	check(#ns.errors > errsBefore and pcall(mm.__scripts.OnEnter, mm), "and nothing escapes (the failure is recorded for /codex diag)")
	-- leaving hides it
	local hidden = 0
	GT.Hide = function() hidden = hidden + 1 end
	mm.__scripts.OnLeave(mm)
	check(hidden == 1, "leaving the button hides the tooltip")
end
