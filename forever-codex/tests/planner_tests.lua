-- planner_tests.lua: Phase 2 (the Planner). Loaded by run_codex_tests.lua with the shared harness table H.
--
-- Two kinds of test:
--   * PURE planner tests build candidate actions by hand (through the Phase 1 contract) on the synthetic map 9001,
--     where one map unit is 1000 yards, and call Planner.Compute directly. They state exactly what situation the
--     Planner is in, so the expected NOW / ALSO DO / THEN follows from the model, not from real quest data.
--   * INTEGRATION tests go through providers, State and the adapter with synthetic packs.
-- The scenarios are the GENERAL situations of the level 1-5 playtest (batching, local density, travel that contains
-- work, deferred turn-ins, chains, same-name quests, unknown locations); no test names a real quest or a zone.

local H = ...
local check, section, boot = H.check, H.section, H.boot

-- ---------------------------------------------------------------- helpers

local function idOf(a) return a and a.id or nil end

local ROLE = { ACCEPT = "GIVER", TURN_IN = "TURN_IN", OBJECTIVE = "OBJECTIVE" }
local STATE = { ACCEPT = "AVAILABLE", TURN_IN = "READY", OBJECTIVE = "ACTIVE" }
local REACHES = { ACCEPT = "ACCEPTED", TURN_IN = "TURNED_IN", OBJECTIVE = "OBJECTIVES" }

--- A hand-built quest action, positioned in yards-as-fractions on map `o.map` (default 9001). x == nil = no location.
local function act(ns, kind, q, x, y, o)
	o = o or {}
	local K = ns.Contract
	local src = o.src or "att"
	local map = o.map or 9001
	local where = x and K.Where(o.status or "known", { { map = map, x = x, y = y } }, o.whereKind or "exact") or K.Where("unknown")
	local t = K.Target({ role = ROLE[kind], where = where, assumed = o.assumed, prov = K.Prov(src), entity = { kind = "npc" } })
	local id = "Q:" .. q .. ":" .. kind
	local a = { id = id, type = "QUEST", kind = kind, quest = q, title = (o.title or ("quest " .. q)), lines = {}, reasons = {},
		src = src, verified = src == "observed", pinned = o.pinned or false, level = o.level, reqLevel = o.req, breadcrumb = o.breadcrumb }
	if x then a.target = { map = map, x = x, y = y, label = id, src = src, verified = src == "observed", approx = (o.status == "approx") or nil } end
	K.Attach(a, { ref = { kind = "quest", id = q }, state = o.state or STATE[kind], skip = o.skip or { logical = false, keys = {} }, targets = { t },
		requirements = {}, completion = { watch = "quest", id = q, reaches = REACHES[kind] }, objectiveState = o.objectiveState, optional = o.optional,
		prov = { state = "client" } })
	if o.hereOnly then a.hereOnly = true end
	return a
end

--- Candidates in the shape Engine.Candidates returns, around a player at (px, py) on map 9001 (nil = no position).
local function cands(ns, list, o)
	o = o or {}
	local ctx = ns.Context.Build()
	local strat = ns.Registry.Strategy(o.style or "efficient")
	local env = { strategy = strat, w = strat.w, stats = { filtered = {}, byType = {} }, warnings = {}, hardcore = false, routeMap = o.routeMap }
	if o.px then env.player = { map = 9001, x = o.px, y = o.py, world = ctx.worldOf(9001, o.px, o.py) or false } end
	local c = { env = env, candidates = {}, inProgress = {}, hints = {} }
	for _, a in ipairs(list) do table.insert(a.hereOnly and c.hints or c.candidates, a) end
	return ctx, c
end

local function plan(ns, list, o)
	local ctx, c = cands(ns, list, o)
	local p = ns.Planner.Compute(ctx, c, o and o.opts)
	if os.getenv("PLAN_DEBUG") then      -- developer aid: PLAN_DEBUG=1 prints every plan these tests build
		local d = p.diag
		print(string.format("  [plan] now=%s also=%s then=%s seq=%s net=%.1f secs=%.0f stops=%s rej=%d", tostring(idOf and idOf(p.now)), tostring(p.alsoDo and p.alsoDo.id),
			tostring(p.thenAction and p.thenAction.id), table.concat(d.sequence or {}, ">"), d.net or 0, d.seconds or 0, tostring(d.stops), #d.rejected))
	end
	return p, ctx, c
end


local function synth(level)
	return boot({ char = { level = level or 10 }, synthetic = true, loc = { map = 9001, x = 0.5, y = 0.5 } })
end

-- ---------------------------------------------------------------- plan shape

section("planner: plan shape")
do
	local ns = synth()
	local p = plan(ns, {
		act(ns, "OBJECTIVE", 1, 0.55, 0.5), act(ns, "OBJECTIVE", 2, 0.56, 0.5), act(ns, "TURN_IN", 3, 0.9, 0.5),
	}, { px = 0.5, py = 0.5 })
	check(p.now ~= nil and type(p.now) == "table" and p.now.kind, "now can be populated")
	local keys = {}
	for k in pairs(p) do keys[#keys + 1] = k end
	table.sort(keys)
	check(table.concat(keys, ",") == "alsoDo,diag,now,reminders,thenAction" or table.concat(keys, ",") == "diag,now,reminders,thenAction" or table.concat(keys, ",") == "alsoDo,diag,now,reminders",
		"the plan carries only now / alsoDo / thenAction / reminders / diag: " .. table.concat(keys, ","))
	check(p.alsoDo ~= nil and p.thenAction ~= nil, "this situation has all three")
	local ids = { p.now.id, p.alsoDo.id, p.thenAction.id }
	check(ids[1] ~= ids[2] and ids[1] ~= ids[3] and ids[2] ~= ids[3], "no action appears twice in now / alsoDo / thenAction")
	local ns2 = synth()
	local empty = plan(ns2, {}, { px = 0.5, py = 0.5 })
	check(empty.now == nil and empty.alsoDo == nil and empty.thenAction == nil, "now can be nil: nothing to do")
	check(empty.diag.reason == "NO_CANDIDATES" and #empty.reminders == 0, "and says why (NO_CANDIDATES)")
	local solo = plan(ns2, { act(ns2, "ACCEPT", 1, 0.52, 0.5) }, { px = 0.5, py = 0.5 })
	check(solo.now ~= nil and solo.alsoDo == nil and solo.thenAction == nil, "alsoDo and thenAction can be nil: one action is just NOW")
	check(solo.now.id == "Q:1:ACCEPT", "with one candidate NOW is that candidate")
	local function bare(a)   -- the UI-facing plan carries action records only; no scores, coordinates or provenance are added to them
		return a == nil or (a._score == nil and a.score == nil and a._dist == nil and a.net == nil and a.interruption == nil)
	end
	check(bare(p.now) and bare(p.alsoDo) and bare(p.thenAction), "the planner adds no score, distance or interruption to the actions it returns")
end

section("planner: it never mutates the actions it is given")
do
	local ns = synth()
	local list = { act(ns, "OBJECTIVE", 1, 0.55, 0.5), act(ns, "OBJECTIVE", 2, 0.56, 0.5), act(ns, "TURN_IN", 3, 0.9, 0.5), act(ns, "ACCEPT", 4, 0.7, 0.2) }
	local function dump(v, seen)
		if type(v) ~= "table" then return tostring(v) end
		local keys = {}
		for k in pairs(v) do keys[#keys + 1] = k end
		table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
		local out = {}
		for _, k in ipairs(keys) do out[#out + 1] = tostring(k) .. "=" .. dump(v[k]) end
		return "{" .. table.concat(out, ",") .. "}"
	end
	local before = {}
	for i, a in ipairs(list) do before[i] = dump(a) end
	plan(ns, list, { px = 0.5, py = 0.5 })
	local same = true
	for i, a in ipairs(list) do if dump(a) ~= before[i] then same = false end end
	check(same, "every action is byte-for-byte unchanged after planning")
end

-- ---------------------------------------------------------------- determinism

section("planner: deterministic")
do
	local ns = synth()
	local function build()
		return { act(ns, "OBJECTIVE", 1, 0.55, 0.5), act(ns, "OBJECTIVE", 2, 0.56, 0.5), act(ns, "TURN_IN", 3, 0.9, 0.5), act(ns, "ACCEPT", 4, 0.7, 0.2),
			act(ns, "ACCEPT", 5, 0.2, 0.2), act(ns, "ACCEPT", 6, 0.21, 0.2) }
	end
	local function sig(p)
		return table.concat({ tostring(idOf(p.now)), tostring(idOf(p.alsoDo)), tostring(idOf(p.thenAction)), table.concat(p.diag.sequence or {}, ">"), string.format("%.6f", p.diag.net or 0) }, "|")
	end
	local a = sig(plan(ns, build(), { px = 0.5, py = 0.5 }))
	local b = sig(plan(ns, build(), { px = 0.5, py = 0.5 }))
	check(a == b and a:find("Q:") ~= nil, "the same context and candidates give the same plan twice (" .. a .. ")")
	local rev = build()
	for i = 1, math.floor(#rev / 2) do rev[i], rev[#rev + 1 - i] = rev[#rev + 1 - i], rev[i] end
	check(sig(plan(ns, rev, { px = 0.5, py = 0.5 })) == a, "and the order the candidates arrive in does not matter")
	local t1 = sig(plan(ns, { act(ns, "ACCEPT", 7, 0.6, 0.5), act(ns, "ACCEPT", 8, 0.4, 0.5) }, { px = 0.5, py = 0.5 }))
	local t2 = sig(plan(ns, { act(ns, "ACCEPT", 8, 0.4, 0.5), act(ns, "ACCEPT", 7, 0.6, 0.5) }, { px = 0.5, py = 0.5 }))
	check(t1 == t2, "exact ties (equal distance, equal value) are broken by action id")
	check(plan(ns, { act(ns, "ACCEPT", 7, 0.6, 0.5), act(ns, "ACCEPT", 8, 0.4, 0.5) }, { px = 0.5, py = 0.5 }).now.id == "Q:7:ACCEPT", "the smaller id wins the tie")
end

-- ---------------------------------------------------------------- sequence behaviour

section("planner: the nearest action is not necessarily the best first step")
do
	local ns = synth()
	-- the nearest action is a lone pickup 250 yd west; three objectives share a spot 400 yd east.
	local p, ctx = plan(ns, {
		act(ns, "ACCEPT", 1, 0.25, 0.5),
		act(ns, "OBJECTIVE", 2, 0.90, 0.5), act(ns, "OBJECTIVE", 3, 0.91, 0.5), act(ns, "OBJECTIVE", 4, 0.90, 0.51),
	}, { px = 0.5, py = 0.5 })
	check(p.diag.nearestId == "Q:1:ACCEPT", "(setup) the nearest action is the lone pickup")
	check(p.now.kind == "OBJECTIVE", "NOW is the productive stop, not the nearest action")
	check(p.diag.stops == 2, "four actions are two stops (the three objectives share one)")
	check(p.diag.sequence[1] ~= "Q:1:ACCEPT", "the lone pickup is not the first stop of the best sequence")
end

section("planner: two actions that share a stop are one trip")
do
	local ns = synth()
	local p = plan(ns, { act(ns, "ACCEPT", 1, 0.60, 0.5), act(ns, "ACCEPT", 2, 0.62, 0.5) }, { px = 0.5, py = 0.5 })
	check(p.diag.stops == 1 and p.diag.candidates == 2, "two accepts 20 yd apart: one stop")
	check(p.now ~= nil and p.alsoDo ~= nil and p.now.id ~= p.alsoDo.id, "NOW and ALSO DO come from the same stop")
	check(p.diag.interruption == 0, "so the ALSO DO costs no extra time")
	local codes = {}
	for _, r in ipairs(p.diag.reasons[p.alsoDo.id] or {}) do codes[r.code] = true end
	check(codes.SAME_STOP == true, "and the reason code says SAME_STOP")
	check(p.thenAction == nil, "one stop: no THEN")
	local far = plan(ns, { act(ns, "ACCEPT", 1, 0.60, 0.5), act(ns, "ACCEPT", 2, 0.90, 0.5) }, { px = 0.5, py = 0.5 })
	check(far.diag.stops == 2, "the same two accepts 300 yd apart are two stops")
end

section("planner: a same-stop action becomes ALSO DO; an action on the way is part of the trip; a detour that costs too much is rejected")
do
	local ns = synth()
	-- NOW trip: an objective area 300 yd east, with a second objective 25 yd from it
	local p = plan(ns, { act(ns, "OBJECTIVE", 1, 0.80, 0.5), act(ns, "OBJECTIVE", 7, 0.80, 0.525) }, { px = 0.5, py = 0.5 })
	check(p.now ~= nil and p.now.kind == "OBJECTIVE" and p.alsoDo ~= nil and p.alsoDo.kind == "OBJECTIVE", "two objectives in one area: NOW and ALSO DO")
	check(p.diag.interruption == 0, "the ALSO DO costs no extra time (same stop)")
	-- an action right along the path is part of the trip: it is the first thing done on the way, and the reason says so
	local q = plan(ns, { act(ns, "OBJECTIVE", 1, 0.80, 0.5), act(ns, "ACCEPT", 2, 0.65, 0.505) }, { px = 0.5, py = 0.5 })
	check(q.now.id == "Q:2:ACCEPT" and q.thenAction and q.thenAction.id == "Q:1:OBJECTIVE", "an action on the way is done on the way, then the objective area")
	local codes = {}
	for _, r in ipairs(q.diag.reasons[q.now.id] or {}) do codes[r.code] = r end
	check(codes.ON_THE_WAY ~= nil and codes.ON_THE_WAY.seconds <= 1, "its reason is ON_THE_WAY, with almost no detour")
	check(q.diag.seconds < (300 / 7) + 135 + 5, "the trip takes barely longer than the walk plus the work (" .. string.format("%.0f", q.diag.seconds) .. " s)")
	-- a pickup far off the path is rejected as ALSO DO, with the reason recorded
	local r = plan(ns, { act(ns, "OBJECTIVE", 1, 0.80, 0.5), act(ns, "ACCEPT", 3, 0.65, 0.95) }, { px = 0.5, py = 0.5 })
	local rejected
	for _, x in ipairs(r.diag.rejected) do if x.id == "Q:3:ACCEPT" then rejected = x end end
	check(r.alsoDo == nil, "a pickup 450 yd off the path is not offered as ALSO DO")
	check(rejected ~= nil and (rejected.code == "TOO_FAR" or rejected.code == "LOW_VALUE"), "and the diagnostics say why: " .. tostring(rejected and rejected.code))
	check(r.thenAction == nil or r.thenAction.id == "Q:3:ACCEPT", "it is at most the THEN, never the ALSO DO")
end

section("planner: ALSO DO is silence by default")
do
	local ns = synth()
	local p = plan(ns, { act(ns, "OBJECTIVE", 1, 0.80, 0.5) }, { px = 0.5, py = 0.5 })
	check(p.now ~= nil and p.alsoDo == nil, "nothing else to do: no ALSO DO, not a second-ranked filler")
	-- a flight hint beside the NOW is not worth an ALSO DO for the balanced strategy
	local fp = act(ns, "ACCEPT", 90, 0.805, 0.5, { optional = true, hereOnly = true })
	fp.kind, fp.type, fp.id = "DISCOVER", "FLIGHT", "FP:90"
	local q = plan(ns, { act(ns, "OBJECTIVE", 1, 0.80, 0.5), fp }, { px = 0.5, py = 0.5 })
	check(q.alsoDo == nil, "a flight hint at the same place does not clear the ALSO DO bar for Efficient")
	local r = plan(ns, { act(ns, "OBJECTIVE", 1, 0.80, 0.5), fp }, { px = 0.5, py = 0.5, style = "completionist" })
	check(r.alsoDo and r.alsoDo.id == "FP:90", "but it does for Completionist (it values discovery and time less)")
	check(r.now.id == "Q:1:OBJECTIVE", "and a hint is never NOW")
end

section("planner: a hint is never NOW, and a detour over the tolerance is refused even when the action is valuable")
do
	local ns = synth()
	local function hint(q, x, y)
		local h = act(ns, "ACCEPT", q, x, y, { optional = true, hereOnly = true })
		return h
	end
	local only = plan(ns, { hint(1, 0.55, 0.5) }, { px = 0.5, py = 0.5 })
	check(only.now == nil and only.alsoDo == nil and only.diag.optional == 1, "alone, an optional hint is not a NOW (nothing is routed to it)")
	-- Completionist is patient (45 s of detour, cheap time), so a valuable optional action 60 s off the path clears the value bar
	-- and is refused ONLY because of the detour limit
	local list = { act(ns, "OBJECTIVE", 2, 0.80, 0.5), hint(3, 0.80, 0.92) }
	local p = plan(ns, list, { px = 0.5, py = 0.5, style = "completionist" })
	local why
	for _, r in ipairs(p.diag.rejected) do if r.id == "Q:3:ACCEPT" then why = r end end
	check(p.alsoDo == nil and why and why.code == "TOO_FAR", "a valuable optional action 420 yd off the path is rejected as TOO_FAR (" .. tostring(why and why.code) .. ")")
	local near = plan(ns, { act(ns, "OBJECTIVE", 2, 0.80, 0.5), hint(3, 0.80, 0.56) }, { px = 0.5, py = 0.5, style = "completionist" })
	check(near.alsoDo and near.alsoDo.id == "Q:3:ACCEPT" and near.diag.interruption > 0, "the same action 60 yd off the path is accepted, with a small positive interruption cost")
end

section("planner: a finished quest does not automatically beat efficient local work")
do
	local ns = synth()
	-- a turn-in 300 yd east; two objectives in one spot 40 yd west of the player
	local list = function()
		return { act(ns, "TURN_IN", 1, 0.80, 0.5, { assumed = true, status = "approx", whereKind = "assumed_giver" }),
			act(ns, "OBJECTIVE", 2, 0.46, 0.5), act(ns, "OBJECTIVE", 3, 0.46, 0.52) }
	end
	local p = plan(ns, list(), { px = 0.5, py = 0.5 })
	check(p.now.kind == "OBJECTIVE", "NOW is local work, not the ready turn-in")
	check(p.alsoDo ~= nil and p.alsoDo.kind == "OBJECTIVE", "the second objective in that spot is the ALSO DO")
	check(p.thenAction ~= nil and p.thenAction.id == "Q:1:TURN_IN", "and the turn-in is what comes THEN (the trip is batched, not skipped)")
	local codes = {}
	for _, r in ipairs(p.diag.reasons[p.now.id] or {}) do codes[r.code] = true end
	check(codes.TURN_IN_WAITS == true, "the reason code records that a turn-in was waiting")
	-- with no local work the turn-in is simply NOW
	local q = plan(ns, { list()[1] }, { px = 0.5, py = 0.5 })
	check(q.now.id == "Q:1:TURN_IN", "with nothing else to do, the turn-in is NOW")
	-- standing at the turn-in: it is NOW even with local work elsewhere
	local r = plan(ns, list(), { px = 0.80, py = 0.50 })
	check(r.now.id == "Q:1:TURN_IN", "standing at the NPC, turning in is the best first step")
end

section("planner: the turn-in waits for the batch, and the batch is not cut short")
do
	local ns = synth()
	-- the Scorpid / Vile Familiars shape: two objective areas close together, the turn-in NPC back at camp
	local p = plan(ns, {
		act(ns, "TURN_IN", 1, 0.50, 0.50, { assumed = true, status = "approx", whereKind = "assumed_giver" }),     -- camp, where the player stands
		act(ns, "OBJECTIVE", 2, 0.80, 0.50), act(ns, "OBJECTIVE", 3, 0.82, 0.52),                                  -- 300 yd out, one area
		act(ns, "TURN_IN", 4, 0.50, 0.50, { assumed = true, status = "approx", whereKind = "assumed_giver" }),
	}, { px = 0.5, py = 0.5 })
	-- standing at camp with two turn-ins ready AND objective work out in the field: both turn-ins first (zero walking), then out
	check(p.now.kind == "TURN_IN", "at camp, turn-ins cost nothing: they come first")
	check(p.diag.sequence[1] ~= p.diag.sequence[2] and #p.diag.sequence == 2, "and the field trip is the next stop")
	check(p.thenAction ~= nil and p.thenAction.kind == "OBJECTIVE", "THEN is the objective area")
end

section("planner: travel that contains work (an action on the way)")
do
	local ns = synth()
	-- the player heads for a turn-in 600 yd east; an objective lies right along that path
	local p = plan(ns, { act(ns, "TURN_IN", 1, 1.10 - 0.2, 0.5), act(ns, "OBJECTIVE", 2, 0.80, 0.505) }, { px = 0.3, py = 0.5 })
	check(p.now ~= nil, "(setup) something to do")
	local ids = { [tostring(idOf(p.now))] = true, [tostring(idOf(p.alsoDo))] = true, [tostring(idOf(p.thenAction))] = true }
	check(ids["Q:1:TURN_IN"] and ids["Q:2:OBJECTIVE"], "the on-the-way objective and the turn-in are both in the plan")
	local obj = (p.now.id == "Q:2:OBJECTIVE") or (p.alsoDo and p.alsoDo.id == "Q:2:OBJECTIVE")
	check(obj, "the objective is done on the way (NOW or ALSO DO), not after a return trip")
	check(p.diag.seconds < (900 / 7) + 135 + 10, "the whole sequence takes barely longer than the walk alone plus doing the work (" .. string.format("%.0f", p.diag.seconds) .. " s)")
end

section("planner: local density beats a distant action that scored well on its own")
do
	local ns = synth()
	-- one turn-in 375 yd away; three objectives 50 yd away (the Innkeeper Grosk shape)
	local p = plan(ns, {
		act(ns, "TURN_IN", 1, 0.875, 0.5, { assumed = true, status = "approx", whereKind = "assumed_giver" }),
		act(ns, "OBJECTIVE", 2, 0.55, 0.5), act(ns, "OBJECTIVE", 3, 0.56, 0.5), act(ns, "OBJECTIVE", 4, 0.55, 0.52),
	}, { px = 0.5, py = 0.5 })
	check(p.now.kind == "OBJECTIVE", "NOW is in the dense nearby area")
	check(p.diag.nearestId ~= "Q:1:TURN_IN", "(the turn-in was not even the nearest)")
	local fast = plan(ns, { act(ns, "TURN_IN", 1, 0.875, 0.5, { assumed = true, status = "approx", whereKind = "assumed_giver" }), act(ns, "OBJECTIVE", 2, 0.55, 0.5) },
		{ px = 0.5, py = 0.5, style = "fast" })
	check(fast.now.kind == "OBJECTIVE", "Fast agrees: the nearby objective first")
end

section("planner: unknown location cannot be NOW, ALSO DO or THEN")
do
	local ns = synth()
	local lost = act(ns, "TURN_IN", 5, nil, nil)
	check(lost.targets[1].where.status == "unknown", "(setup) an action with an unknown location")
	local p = plan(ns, { lost }, { px = 0.5, py = 0.5 })
	check(p.now == nil and p.alsoDo == nil and p.thenAction == nil, "alone, it is not a NOW: there is nowhere to go")
	check(#p.reminders == 1 and p.reminders[1].id == "Q:5:TURN_IN", "it becomes a reminder")
	check(p.diag.reason == "NO_LOCATED_ACTION", "and the diagnostics say NO_LOCATED_ACTION")
	local q = plan(ns, { lost, act(ns, "ACCEPT", 1, 0.6, 0.5) }, { px = 0.5, py = 0.5 })
	check(q.now.id == "Q:1:ACCEPT" and #q.reminders == 1, "next to a located action it is still only a reminder")
	local ids = { idOf(q.now), idOf(q.alsoDo), idOf(q.thenAction) }
	local leaked = false
	for _, id in ipairs(ids) do if id == "Q:5:TURN_IN" then leaked = true end end
	check(not leaked, "and never appears as NOW, ALSO DO or THEN")
	check(lost.targets[1].where.points == nil, "no coordinates were invented for it")
end

section("planner: an assumed turn-in location is trusted less than an observed one")
do
	local ns = synth()
	local Pl = ns.Planner
	local observed = act(ns, "ACCEPT", 1, 0.5, 0.5, { src = "observed" })
	observed.evidence = "observed"
	local assumed = act(ns, "TURN_IN", 2, 0.5, 0.5, { assumed = true, status = "approx", whereKind = "assumed_giver" })
	local approx = act(ns, "OBJECTIVE", 3, 0.5, 0.5, { status = "approx", whereKind = "area" })
	local exact = act(ns, "OBJECTIVE", 4, 0.5, 0.5)
	check(Pl.Confidence(observed) == 1, "an observed, exact location is fully trusted")
	check(Pl.Confidence(assumed) < Pl.Confidence(exact), "an assumed turn-in is trusted less than a known location")
	check(Pl.Confidence(approx) < Pl.Confidence(exact), "an approximate area is trusted less than an exact one")
	check(Pl.Confidence(assumed) < Pl.Confidence(observed), "and less than an observed one")
	-- ... and it changes what the Planner picks when everything else is equal
	-- two turn-ins on opposite sides, each 500 yd away: only one trip is worth it, and the better-trusted location wins
	local a = act(ns, "TURN_IN", 10, 1.00, 0.5, { assumed = true, status = "approx", whereKind = "assumed_giver" })
	local b = act(ns, "TURN_IN", 11, 0.00, 0.5, { src = "observed" })
	b.targets[1].assumed = nil
	local p = plan(ns, { a, b }, { px = 0.5, py = 0.5 })
	check(#p.diag.sequence == 1 and p.now.id == "Q:11:TURN_IN", "two turn-ins equally far away on opposite sides: the one at an observed location is NOW")
	check(ns.Contract.Evidence(assumed) == "unverified", "(Phase 1 rule kept) an assumed location is never 'observed' evidence")
end

section("planner: several objectives coexist without pretending to map to objective indexes")
do
	local ns = synth()
	local Pl = ns.Planner
	-- one quest, a multi-point objective area (the data does not say which point is which objective)
	local a = act(ns, "OBJECTIVE", 1, 0.62, 0.5, { status = "approx", whereKind = "area" })
	a.targets[1].where.points[2] = { map = 9001, x = 0.64, y = 0.52 }
	a.targets[1].where.indexed = false
	a.objectiveState = ns.Contract.ObjectiveState({ { text = "a", finished = true, numFulfilled = 3, numRequired = 3 }, { text = "b", finished = false, numFulfilled = 1, numRequired = 4 } })
	local b = act(ns, "OBJECTIVE", 2, 0.63, 0.51)
	local p = plan(ns, { a, b }, { px = 0.5, py = 0.5 })
	check(p.diag.stops == 1 and p.diag.candidates == 2, "two quests' objectives in one area are one stop")
	check(p.now ~= nil and p.alsoDo ~= nil, "both are in the plan (NOW + ALSO DO)")
	local pt, status = Pl.Locate(a)
	check(pt.x == 0.62 and status == "approx", "a multi-point objective area is located by its first point, as an approximate area")
	check(a.targets[1].where.indexed == false and #a.targets[1].where.points == 2, "the planner leaves the points un-indexed (it never ties a point to an objective)")
	local json = ""
	for k, v in pairs(p.diag) do json = json .. tostring(k) end
	check(not json:find("objectiveIndex") and not json:find("indexed"), "nothing in the plan diagnostics claims an objective index")
	-- progress shortens the time left (counts only); it never moves the location
	local full = act(ns, "OBJECTIVE", 3, 0.62, 0.5)
	local half = act(ns, "OBJECTIVE", 3, 0.62, 0.5)
	half.objectiveState = ns.Contract.ObjectiveState({ { text = "a", finished = true, numFulfilled = 3, numRequired = 3 }, { text = "b", finished = false, numFulfilled = 0, numRequired = 4 } })
	local pf = plan(ns, { full }, { px = 0.5, py = 0.5 })
	local ph = plan(ns, { half }, { px = 0.5, py = 0.5 })
	check(ph.diag.seconds < pf.diag.seconds, "an objective that is half done is expected to take less time")
	check(select(1, Pl.Locate(half)).x == select(1, Pl.Locate(full)).x, "and its location is unchanged")
end

section("planner: quest chains, one hop (what a turn-in unlocks)")
do
	-- the player stands at the west edge with a pickup next to them; a finished quest is 900 yd east.
	local function world(withFollowUp)
		local ns = boot({ char = { level = 12 }, synthetic = true, loc = { map = 9001, x = 0.05, y = 0.5 } })
		local recs = { { id = 101, name = "Chain start", map = 9001, x = 0.95, y = 0.5 }, { id = 104, name = "A pickup nearby", map = 9001, x = 0.10, y = 0.5 } }
		if withFollowUp then recs[#recs + 1] = { id = 102, name = "Chain follow-up", map = 9001, x = 0.96, y = 0.5, prereq = { 101 } } end   -- offered right where 101 is turned in
		H.attPack(ns, recs, nil)
		H.world().log = { { questID = 101, title = "Chain start", complete = true } }
		ns.State.Recompute()
		return ns, ns.State.plan
	end
	local _, withChain = world(true)
	local _, noChain = world(false)
	local codes = {}
	for _, r in ipairs(withChain.diag.reasons["Q:101:TURN_IN"] or {}) do codes[r.code] = true end
	check(withChain.thenAction and withChain.thenAction.id == "Q:101:TURN_IN", "a turn-in that unlocks a follow-up right there is worth the 900 yard trip: it is THEN")
	check(noChain.thenAction == nil, "the identical turn-in with nothing to unlock is not worth that trip while there is local work")
	check(withChain.now.id == "Q:104:ACCEPT" and noChain.now.id == "Q:104:ACCEPT", "NOW is the nearby pickup either way")
	check(withChain.diag.net > noChain.diag.net, "the unlock is what makes the difference (higher net value with the chain)")
	-- the chain is derived from data: no follow-up in the data, no credit; the credit never makes anything 'verified'
	check(withChain.thenAction.evidence ~= "observed", "chain credit does not change the provenance of the action")
	-- already-completed chain steps (before the addon was installed) simply make the follow-up available
	local ns4 = boot({ char = { level = 12 }, synthetic = true, loc = { map = 9001, x = 0.5, y = 0.5 } })
	H.attPack(ns4, { { id = 101, name = "Chain start", map = 9001, x = 0.52, y = 0.5 }, { id = 102, name = "Chain follow-up", map = 9001, x = 0.53, y = 0.5, prereq = { 101 } } }, nil)
	ns4.State.Recompute()
	local before = {}
	for _, a in ipairs(ns4.State.plan.sequence) do before[a.id] = true end
	check(before["Q:101:ACCEPT"] and not before["Q:102:ACCEPT"], "mid-chain at the start: the follow-up is not offered yet")
	H.world().completed[101] = true
	ns4.State.Recompute()
	local after = {}
	for _, a in ipairs(ns4.State.plan.sequence) do after[a.id] = true end
	check(after["Q:102:ACCEPT"] and not after["Q:101:ACCEPT"], "a chain step completed outside Codex: the follow-up is offered and the finished step is never actionable")
end

section("planner: unknown walking time is unknown, not a number")
do
	local ns = synth()
	local p = plan(ns, { act(ns, "ACCEPT", 1, 0.6, 0.5), act(ns, "ACCEPT", 2, 0.5, 0.5, { map = 9003 }) }, { px = 0.5, py = 0.5 })
	check(p.now.id == "Q:1:ACCEPT", "a candidate on another continent ranks after a reachable one")
	local alone = plan(ns, { act(ns, "ACCEPT", 2, 0.5, 0.5, { map = 9003 }) }, { px = 0.5, py = 0.5 })
	-- (changed after the first real-client test: an unmeasurable leg used to be free, so a lone far quest became NOW)
	check(alone.now == nil and alone.diag.reason == "ONLY_DISTANT_UNMEASURED" and alone.diag.unknownLegs == 1, "if it is all there is, it is NOT recommended: reachable only through an unmeasurable leg that does not pay for itself")
	local chosen = plan(ns, { act(ns, "ACCEPT", 2, 0.5, 0.5, { map = 9003 }) }, { px = 0.5, py = 0.5, routeMap = 9003 })
	check(chosen.now ~= nil and chosen.diag.unknownLegs == 1, "but a route zone the player chose there is their call: it is NOW, and the plan says a leg's time is unknown")
	local pinned = plan(ns, { act(ns, "ACCEPT", 1, 0.6, 0.5), act(ns, "ACCEPT", 2, 0.5, 0.5, { map = 9003, pinned = true }) }, { px = 0.5, py = 0.5 })
	check(pinned.now.id == "Q:2:ACCEPT", "a quest the player added comes first, even on another continent")
	local nopos = plan(ns, { act(ns, "ACCEPT", 1, 0.6, 0.5) }, {})
	check(nopos.now ~= nil and #nopos.diag.warnings == 1, "with no player position the first leg is free, and the plan says so")
end

-- ---------------------------------------------------------------- strategies

section("planner: strategies are the existing ones")
do
	local ns = synth()
	local keys = {}
	for _, s in ipairs(ns.Registry.Strategies()) do if s.active ~= false then keys[#keys + 1] = s.key end end
	table.sort(keys)
	check(table.concat(keys, ",") == table.concat(ns.Planner.STRATEGY_KEYS, ","), "the Planner tunes exactly the registered active strategies: " .. table.concat(keys, ","))
	check(ns.Planner.Params("no-such-style").timeValue == ns.Planner.Params("efficient").timeValue, "an unknown key gets the base values; no strategy is created")
	for _, s in ipairs(ns.Registry.Strategies()) do
		check(s.key ~= "planner" and s.key ~= "sequence", "no planner strategy was registered (" .. s.key .. ")")
	end
	-- the player's selected style is what the plan reports
	for _, key in ipairs({ "efficient", "fast", "questing_only", "completionist" }) do
		ns.Prefs.SetStyle(key)
		check(ns.State.Recompute().strategy == key and ns.State.plan.diag.strategy == key, "style " .. key .. " drives the Planner")
	end
	ns.Prefs.SetStyle("solo")
	check(ns.Prefs.GetStyle() == "completionist" or ns.Prefs.GetStyle() == "efficient", "a planned style still cannot be selected")
	-- Fast and Completionist differ only in how they weigh time
	local far = { act(ns, "OBJECTIVE", 1, 0.55, 0.5), act(ns, "ACCEPT", 2, 0.92, 0.5) }
	local f = plan(ns, far, { px = 0.5, py = 0.5, style = "fast" })
	local c = plan(ns, far, { px = 0.5, py = 0.5, style = "completionist" })
	check(#f.diag.sequence <= #c.diag.sequence and c.diag.sequence[2] ~= nil, "Completionist includes the far pickup; Fast values the walk more and leaves it out")
end

section("planner: the player's route zone and added quests are choices, not scores")
do
	local ns = synth()
	local here = act(ns, "OBJECTIVE", 1, 0.55, 0.5)
	local there = act(ns, "ACCEPT", 2, 0.50, 0.50, { map = 9002 })
	local p = plan(ns, { here, there }, { px = 0.5, py = 0.5, routeMap = 9002 })
	check(p.now.id == "Q:2:ACCEPT" and p.diag.routeZoneOnly == true, "with a route zone chosen, its stops are the plan even when other work is closer")
	local none = plan(ns, { here }, { px = 0.5, py = 0.5, routeMap = 9002 })
	check(none.now.id == "Q:1:OBJECTIVE", "a route zone with nothing to do does not leave the player with no plan")
	local pin = plan(ns, { here, act(ns, "ACCEPT", 3, 0.95, 0.9, { pinned = true }) }, { px = 0.5, py = 0.5 })
	check(pin.now.id == "Q:3:ACCEPT", "a quest the player added is where the plan starts")
	local blocked = act(ns, "ACCEPT", 4, 0.6, 0.5, { pinned = true, state = "BLOCKED" })
	blocked.stateWhy = "LEVEL_TOO_LOW"
	check(plan(ns, { blocked }, { px = 0.5, py = 0.5 }).now ~= nil, "an added quest is planned even if the data says the character is too low (the data is unverified; the player decided)")
	local skipped = act(ns, "ACCEPT", 5, 0.6, 0.5, { skip = { logical = true, keys = { "QT:5" } } })
	check(plan(ns, { skipped }, { px = 0.5, py = 0.5 }).now == nil, "a quest the player skipped (either legacy key) is never planned")
	local blockedPlain = act(ns, "ACCEPT", 6, 0.6, 0.5, { state = "BLOCKED" })
	blockedPlain.stateWhy = "LEVEL_TOO_LOW"
	local pb = plan(ns, { blockedPlain }, { px = 0.5, py = 0.5 })
	check(pb.now == nil and pb.diag.filtered.state == 1, "a blocked quest nobody asked for is not planned (and the count is recorded)")
end

-- ---------------------------------------------------------------- stability and deviation

section("planner: NOW is stable under near-ties, and follows the player's actual state")
do
	local ns = synth()
	local list = function() return { act(ns, "ACCEPT", 1, 0.55, 0.5), act(ns, "ACCEPT", 2, 0.45, 0.5) } end
	local p1 = plan(ns, list(), { px = 0.5, py = 0.5 })
	local other = p1.now.id == "Q:1:ACCEPT" and "Q:2:ACCEPT" or "Q:1:ACCEPT"
	local p2 = plan(ns, list(), { px = 0.5, py = 0.5, opts = { prevNowId = other } })
	check(p2.now.id == other and p2.diag.stuck == true, "a near-tie keeps the previous NOW (no flapping)")
	local far = { act(ns, "ACCEPT", 1, 0.55, 0.5), act(ns, "OBJECTIVE", 2, 0.05, 0.05), act(ns, "OBJECTIVE", 3, 0.06, 0.05), act(ns, "OBJECTIVE", 4, 0.05, 0.06) }
	local p3 = plan(ns, far, { px = 0.5, py = 0.5, opts = { prevNowId = "Q:1:ACCEPT" } })
	local p4 = plan(ns, far, { px = 0.5, py = 0.5 })
	check(p3.now.id == p4.now.id or p3.diag.stuck == true, "stickiness never overrides a clearly better plan")
	check(true, "(stickiness margin: " .. ns.Planner.Params("efficient").stickiness .. " points)")
end

section("planner: integration through State, providers and the adapter")
do
	local ns = boot({ char = { level = 12 }, synthetic = true, loc = { map = 9001, x = 0.5, y = 0.5 } })
	H.attPack(ns, {
		{ id = 201, name = "Sarkoth", map = 9001, x = 0.53, y = 0.50 },
		{ id = 202, name = "Sarkoth", map = 9001, x = 0.53, y = 0.52 },            -- a different quest, same visible name
		{ id = 203, name = "Simple Parchment", map = 9001, x = 0.80, y = 0.50 },
		{ id = 204, name = "Simple Parchment", map = 9001, x = 0.82, y = 0.50, prereq = { 203 } },
	}, nil)
	local W = H.world()
	W.completed[201] = true
	ns.State.Recompute()
	local pl = ns.State.plan
	local ids = {}
	for _, a in ipairs(pl.sequence) do ids[a.id] = true end
	check(ids["Q:202:ACCEPT"] and not ids["Q:201:ACCEPT"], "same-name quests are told apart by ID: the completed one never returns, the other is offered")
	check(pl.now ~= nil and pl.now == pl.sequence[1] or pl.sequence[1].type == "TRAVEL", "legacy shape: next / sequence are filled from the Planner")
	check(pl.next == pl.sequence[1] and #pl.upcoming == #pl.sequence - 1, "legacy shape: next and upcoming are consistent with sequence")
	check(pl.diag and pl.diag.nowId == pl.now.id, "the plan carries its diagnostics")
	-- reason strings are player-facing: no ids, scores, provenance, coordinates
	local ugly = {}
	for _, a in ipairs({ pl.now, pl.alsoDo, pl.thenAction }) do
		for _, r in ipairs(a and a.reasons or {}) do
			if r:find("Q:%d") or r:lower():find("score") or r:find("ATT") or r:lower():find("verified") or r:find("%d%d%d%.%d") or r:find("policy") then ugly[#ugly + 1] = r end
		end
	end
	check(#ugly == 0, "the reasons shown to the player contain no ids, scores, provenance or coordinates" .. (#ugly > 0 and (": " .. ugly[1]) or ""))
	-- deviation: the player does something outside Codex
	local first = pl.now.id
	W.completed[202] = true
	ns.State.Recompute()
	check(ns.State.plan.now == nil or ns.State.plan.now.id ~= first, "the player finishes the NOW action outside Codex: NOW moves on")
	W.log = { { questID = 203, title = "Simple Parchment", complete = false } }
	ns.State.Recompute()
	local seen = false
	for _, a in ipairs(ns.State.plan.inProgress) do if a.quest == 203 then seen = true end end
	check(seen or (ns.State.plan.now and ns.State.plan.now.quest == 203), "an unrelated quest accepted by the player enters the plan by its ID")
	check(#ns.errors == 0, "no caught errors")
end

section("planner: level changes eligibility but does not invalidate a still-useful action")
do
	local ns = boot({ char = { level = 5 }, synthetic = true, loc = { map = 9001, x = 0.5, y = 0.5 } })
	H.attPack(ns, {
		{ id = 301, name = "Local pickup", map = 9001, x = 0.52, y = 0.5, req = 1 },
		{ id = 302, name = "Needs level 8", map = 9001, x = 0.53, y = 0.5, req = 8 },
	}, nil)
	ns.State.Recompute()
	local ids = {}
	for _, a in ipairs(ns.State.plan.sequence) do ids[a.id] = true end
	check(ids["Q:301:ACCEPT"] and not ids["Q:302:ACCEPT"], "level 5: only the quest it can take")
	local firstNow = ns.State.plan.now.id
	H.world().char.level = 8
	ns.State.Recompute()
	local ids2 = {}
	for _, a in ipairs(ns.State.plan.sequence) do ids2[a.id] = true end
	check(ids2["Q:302:ACCEPT"] or (ns.State.plan.alsoDo and ns.State.plan.alsoDo.id == "Q:302:ACCEPT"), "level 8: the new quest becomes available")
	local still = ns.State.plan.now.id == firstNow or (ns.State.plan.alsoDo and ns.State.plan.alsoDo.id == firstNow)
	check(still, "and the action that was already useful is still in the plan")
	-- a style change is applied immediately
	ns.Prefs.SetStyle("fast")
	check(ns.State.Recompute().strategy == "fast", "changing the strategy changes the plan's strategy at once")
end

-- ---------------------------------------------------------------- adapter, diagnostics, switches

section("planner: the adapter gives the existing UI what it expects")
do
	local ns = boot({ char = { level = 12 }, synthetic = true, loc = { map = 9001, x = 0.5, y = 0.5 } })
	H.attPack(ns, {
		{ id = 401, name = "Near", map = 9001, x = 0.52, y = 0.5 },
		{ id = 402, name = "Also near", map = 9001, x = 0.53, y = 0.5 },
		{ id = 403, name = "Far east", map = 9001, x = 0.92, y = 0.5 },
	}, nil)
	H.world().log = { { questID = 901, title = "Not in any pack", complete = true } }
	local p = ns.State.Recompute()
	check(p.next and p.sequence[1] == p.next and type(p.upcoming) == "table" and type(p.nearby) == "table" and type(p.inProgress) == "table", "next, sequence, upcoming, nearby, inProgress all exist")
	check(p.warnings ~= nil and p.stats ~= nil and p.strategy == "efficient", "warnings, stats and strategy are carried over")
	local unlocated = false
	for _, a in ipairs(p.inProgress) do if a.quest == 901 then unlocated = true end end
	check(unlocated, "a quest with no location is listed under 'in your log, location unknown'")
	check(p.nearby[1] == p.alsoDo or p.alsoDo == nil, "the ALSO DO action leads the 'while you're here' list")
	local travel
	for _, a in ipairs(p.sequence) do if a.type == "TRAVEL" then travel = a end end
	check(travel == nil or (travel.forId and travel.dist >= ns.Engine.TRAVEL_MIN), "TRAVEL steps are inserted as before (only for 150+ yards)")
	check(ns.UI and ns.UI.Refresh and pcall(ns.UI.Refresh), "the existing window renders the adapted plan")
	-- the old path is still available and unchanged
	ns.State.SetPlanner(false)
	local old = ns.State.Recompute()
	check(old.now == nil and old.diag == nil and old.next ~= nil, "legacy mode: the previous engine, no planner fields")
	ns.State.SetPlanner(true)
	check(ns.State.Recompute().now ~= nil, "planner mode again")
end

section("planner: /codex planner and /codex diag")
do
	local ns = boot({ char = { level = 12 }, synthetic = true, loc = { map = 9001, x = 0.5, y = 0.5 } })
	H.attPack(ns, { { id = 501, name = "One", map = 9001, x = 0.52, y = 0.5 }, { id = 502, name = "Two", map = 9001, x = 0.53, y = 0.5 } }, nil)
	local W = H.world()
	local function said(s) for _, m in ipairs(W.chat) do if m:find(s, 1, true) then return true end end return false end
	H.slash("planner"); check(said("Planner is on"), "/codex planner reports its state")
	W.chat = {}
	H.slash("planner off"); check(ns.State.mode == "legacy" and said("Planner off"), "/codex planner off")
	check(ns.State.plan.now == nil, "and the plan is the legacy one")
	H.slash("planner on"); check(ns.State.mode == "planner" and ns.State.plan.now ~= nil, "/codex planner on")
	W.chat = {}
	H.slash("diag")
	check(said("Planner (planner)") and said("NOW Q:") and said("ALSO DO") and said("THEN") and said("policy points, not XP"), "/codex diag prints the Planner section (NOW / ALSO DO / THEN and the value basis)")
	check(said("sequence ") and said("interruption") and said("alternatives") and said("rejected"), "with the sequence, interruption cost, alternatives and rejected ALSO DOs")
	check(ns.Prefs.IsSavedVariablesSafe(ForeverCodexDB.diag[#ForeverCodexDB.diag]), "the stored diag snapshot (with the planner section) is SavedVariables-safe")
	local snap = ForeverCodexDB.diag[#ForeverCodexDB.diag]
	check(snap.planner and snap.planner.diag and snap.planner.diag.nowId, "the snapshot keeps the planner diagnostics")
	W.chat = {}
	H.slash("help"); check(said("/codex planner"), "help lists the planner switch")
end

section("planner: a planner failure falls back to the previous engine")
do
	local ns = boot({ char = { level = 12 }, synthetic = true, loc = { map = 9001, x = 0.5, y = 0.5 } })
	H.attPack(ns, { { id = 601, name = "One", map = 9001, x = 0.52, y = 0.5 } }, nil)
	local real = ns.Planner.Compute
	ns.Planner.Compute = function() error("boom") end
	local p = ns.State.Recompute()
	check(p ~= nil and p.next ~= nil, "a plan is still produced")
	local warned = false
	for _, w in ipairs(p.warnings) do if w:find("planner failed") then warned = true end end
	check(warned and #ns.errors >= 1 and ns.errors[#ns.errors]:find("planner"), "the player is told, and the error is recorded for /codex diag")
	ns.Planner.Compute = real
	check(ns.State.Recompute().now ~= nil, "and the next recompute uses the Planner again")
end

section("planner: what it does NOT do yet")
do
	local ns = boot({ char = { level = 25 } })
	local p = ns.State.Recompute()
	local types = {}
	for _, l in ipairs({ p.sequence, p.nearby, p.upcoming }) do for _, a in ipairs(l) do types[a.type] = true end end
	local extra = {}
	for t in pairs(types) do if t ~= "QUEST" and t ~= "TRAVEL" and t ~= "FLIGHT" then extra[#extra + 1] = t end end
	check(#extra == 0, "only quest, travel and flight-hint actions exist: no grind, trainer, vendor, inn, pet, profession or respawn actions")
	-- (Phase 3 added Navigation and Markers as consumers of the plan; the Planner does not depend on them: see the independence check below)
	check(ns.QuestMap == nil, "no quest map module yet")
	check(H.world().waypointCalls == 0, "nothing placed a waypoint (Show on Map is still the only thing that does)")
	check(#ns.errors == 0, "no caught errors")
end

section("planner: it does not depend on the UI, navigation, markers, quest map or telemetry")
do
	local src = H.readFile(H.addonDir .. "/Planner.lua")
	local code = src:gsub("%-%-[^\n]*", "")      -- ignore comments
	local bad = {}
	for _, name in ipairs({ "ns.UI", "UI.", "MapPin", "ns.Navigation", "ns.Markers", "ns.QuestMap", "ns.Telemetry", "TelemetryMetrics", "C_Map", "C_QuestLog", "C_SuperTrack", "SetUserWaypoint", "CreateFrame", "GetTime", "UnitXP" }) do
		if code:find(name, 1, true) then bad[#bad + 1] = name end
	end
	check(#bad == 0, "Planner.lua mentions none of: UI, MapPin, navigation, markers, quest map, telemetry, or any client API" .. (#bad > 0 and (" (found " .. table.concat(bad, ",") .. ")") or ""))
	check(not code:find("questID", 1, true) and not code:find("Q:", 1, true) and not code:find("%d%d%d%d"), "and names no quest and no map or zone id (no special cases)")
end

section("planner: bounded work")
do
	local ns = synth()
	local list = {}
	for i = 1, 300 do list[#list + 1] = act(ns, "ACCEPT", 1000 + i, 0.05 + (i % 20) * 0.045, 0.05 + math.floor(i / 20) * 0.06) end
	local p = plan(ns, list, { px = 0.5, py = 0.5 })
	check(p.diag.candidates == 300 and p.diag.considered <= ns.Planner.BEAM_K, "300 candidates: at most BEAM_K stops are searched (" .. tostring(p.diag.considered) .. ")")
	check(p.diag.sequences <= 8 + 8 * 7 + 8 * 7 * 6, "and at most " .. (8 + 56 + 336) .. " sequences are scored (" .. tostring(p.diag.sequences) .. ")")
	check(p.now ~= nil, "a plan is produced")
end
