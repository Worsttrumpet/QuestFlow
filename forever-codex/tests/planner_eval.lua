-- planner_eval.lua: Phase 2.5, the Planner EVALUATION harness. Loaded by run_codex_tests.lua with the shared harness
-- table H (the stub client). Run it on its own, with full reports:
--
--     cd forever-codex/tests
--     lua5.1 run_planner_eval.lua ../ForeverCodex
--
-- PURPOSE. Show what the CURRENT Planner decides in situations taken from the level 1-5 Orc Warrior playtest
-- (docs/CODEX_PLANNING_MODEL.md), so a human can judge whether it is what we want BEFORE a UI is built around it.
-- It is an evaluation, not a tuning step: nothing here changes a Planner constant.
--
-- A scenario is plain data (character, position, strategy, route zone, quests and their relationships, quest log with
-- objective progress, completions, skips, added quests, observed overlays). The runner turns it into the stub client's
-- state and runs   scenario -> Engine.Candidates -> Planner.Compute(trace) -> report.
-- Two kinds:
--   DETERMINISTIC  has assertions that are true by design (they are counted as checks and can fail)
--   REVIEW         only produces a report: no PASS/FAIL, because the right answer is a human judgement
--
-- Quest ids and names below are FIXTURE DATA copied from the playtest notes and the ATT pack. Nothing in the Planner
-- names a quest, a zone or a map. Positions in synthetic scenarios are written in YARDS (map 9001: 1 unit = 1000 yd).
-- Real-data scenarios use the harness's stub map size (3500 x 2800 yd per map), NOT Forever's real size, so only the
-- relative layout is meaningful there.
--
-- Future baseline / community routes: they would arrive as another candidate source (a provider) or as an
-- `opts.hints` input to Planner.Compute. A scenario already separates "what exists" (quests, overlays) from "what
-- the player did" (log, skips, adds), so a route can be added as a third input without touching the Planner's rules.
-- Nothing of that exists yet.

local H = ...
local check, section, boot = H.check, H.section, H.boot

local VERBOSE = os.getenv("CODEX_EVAL") == "1" or rawget(_G, "PLANNER_EVAL_REPORT") == true

local M = {}
local scenarios = {}

-- ---------------------------------------------------------------- scenario plumbing

local function yd(n) return n / 1000 end

local ORC_WARRIOR = { class = "Warrior", classToken = "WARRIOR", race = "Orc", raceToken = "Orc", faction = "Horde" }

local function charOf(sc)
	local c = { level = sc.level or 4 }
	for k, v in pairs(ORC_WARRIOR) do c[k] = (sc.char and sc.char[k]) or v end
	return c
end

--- Builds the stub client + addon state for a scenario and returns ns, ctx, candidates, plan.
local function run(sc, over)
	sc = over and setmetatable(over, { __index = sc }) or sc
	local synthetic = sc.data ~= "real"
	local at = sc.player or { map = 9001, x = 0.5, y = 0.5 }
	local ns = boot({ char = charOf(sc), synthetic = synthetic, loc = { map = at.map, x = at.x, y = at.y, zone = sc.zone or "Fixture" } })
	if synthetic then H.attPack(ns, sc.quests or {}, sc.zones or { { key = "zone-a", label = "Zone A", map = 9001, quests = #(sc.quests or {}) } }) end
	if sc.observed then
		ForeverCodex.RegisterPack("quests", "observed:eval-fixture", {
			meta = { src = "observed", verified = true, priority = 100, label = "evaluation fixture (playtest-observed coordinates; test-only)" }, zones = {}, quests = sc.observed })
	end
	if sc.illustrative then
		ForeverCodex.RegisterPack("quests", "att:eval-illustrative", {
			meta = { src = "att", verified = false, priority = 20, label = "evaluation fixture (ILLUSTRATIVE placement; test-only)" }, zones = {}, quests = sc.illustrative })
	end
	-- the same facts, read through the QuestieDB bridge (a fake QuestieDB built from the baseline just registered)
	local needsAtt
	if sc.bridge then _, needsAtt = H.fake.fromRegistry(ns, sc.bridge) end
	local W = H.world()
	W.log, W.objectives, W.completed = {}, {}, {}
	for id, e in pairs(sc.log or {}) do
		W.log[#W.log + 1] = { questID = id, title = e.title or ("quest " .. id), complete = e.complete == true }
		if e.objectives then
			W.objectives[id] = {}
			for i, o in ipairs(e.objectives) do
				W.objectives[id][i] = { text = o.text or "", type = o.type or "monster", finished = o.have >= o.need, numFulfilled = o.have, numRequired = o.need }
			end
		end
	end
	table.sort(W.log, function(a, b) return a.questID < b.questID end)
	for _, id in ipairs(sc.completed or {}) do W.completed[id] = true end
	ns.Prefs.SetStyle(sc.style or "efficient")
	if sc.routeZone then ns.Prefs.SetRouteZone(sc.routeZone) end
	for _, k in ipairs(sc.skipped or {}) do ns.Prefs.Skip(k) end
	for _, id in ipairs(sc.added or {}) do ns.Prefs.Add(id) end
	-- the bridge-equivalence comparison asks "does reading the same facts through QuestieDB change a decision?"; the restriction-knowledge limit (0.7.1) is
	-- deliberately a function of WHICH layers cover a quest, so it is switched off there and tested on its own (guidance_tests.lua)
	if sc.neutralRestrictions then ns.Planner.RESTRICTION_UNKNOWN_MAX_YD = math.huge end
	local ctx = ns.Context.Build()
	local c = ns.Engine.Candidates(ctx)
	local plan = ns.Planner.Compute(ctx, c, { trace = true })
	local titles = {}
	for _, l in ipairs({ c.candidates, c.inProgress, c.hints }) do for _, a in ipairs(l) do titles[a.id] = a.title end end
	return { ns = ns, ctx = ctx, c = c, plan = plan, diag = plan.diag, titles = titles, sc = sc, needsAtt = needsAtt }
end

-- ---------------------------------------------------------------- the report

local function title(r, a) return a and (r.titles[a.id] or a.id) or "(none)" end

local function distance(r, a, b)
	if not a or not b then return nil end
	local d = r.ns.Engine.Distance(r.ctx, a, b)
	if d == nil or d >= r.ns.Engine.DIFFERENT_CONTINENT then return nil end
	return d
end

local function posOf(r, id)
	local it = r.diag.items and r.diag.items[id]
	return it and { map = it.map, x = it.x, y = it.y } or nil
end

local function fmtYd(d) return d and string.format("%d yd", math.floor(d + 0.5)) or "distance unknown" end

--- Plain-text report. Returns a list of lines. Everything here comes from the plan, its trace, or the scenario.
local function report(r)
	local sc, plan, d, L = r.sc, r.plan, r.diag, {}
	local function add(s) L[#L + 1] = s end
	local ch = r.ctx.char
	local player = r.c.env.player
	add("FOREVER CODEX PLANNER EVALUATION")
	add("")
	add("Scenario:  " .. sc.name .. "   [" .. (sc.kind == "deterministic" and "DETERMINISTIC" or "REVIEW") .. "]")
	if sc.about then add("           " .. sc.about) end
	add(string.format("Character: Level %d %s %s (%s) | strategy %s | route zone %s | position %s", ch.level or 0, ch.race or "?", ch.class or "?", ch.faction or "?",
		d.strategy or "?", r.ctx.prefs.routeZone or "auto", player and string.format("map %d (%.1f, %.1f)", player.map, player.x * 100, player.y * 100) or "unknown"))
	add("")
	local function row(label, a)
		local extra = ""
		if a then
			local dd = distance(r, player, posOf(r, a.id))
			local it = d.items and d.items[a.id]
			extra = string.format("   [%s, %s from you%s]", a.kind, fmtYd(dd), it and (", " .. it.status .. (it.assumed and ", assumed" or "")) or "")
		end
		add(string.format("%-9s %s%s", label, title(r, a), extra))
	end
	row("NOW", plan.now)
	row("ALSO DO", plan.alsoDo)
	row("THEN", plan.thenAction)
	if #plan.reminders > 0 then
		local names = {}
		for _, a in ipairs(plan.reminders) do names[#names + 1] = title(r, a) end
		add("Reminders (no usable location, never routed): " .. table.concat(names, "; "))
	end
	if d.reason then add("No NOW: " .. d.reason) end
	add("")
	if d.sequence then
		add("Selected stops:")
		for n, sid in ipairs(d.sequence) do
			local names, stop = {}, nil
			for _, s in ipairs(d.stopList) do if s.id == sid then stop = s end end
			for _, id in ipairs(stop and stop.items or {}) do names[#names + 1] = title(r, { id = id }) end
			local prevPos = n == 1 and player or (function() local p = d.stopList; for _, s in ipairs(p) do if s.id == d.sequence[n - 1] then return { map = s.map, x = s.x, y = s.y } end end end)()
			add(string.format("  %d. %s   (%s)", n, table.concat(names, " + "), fmtYd(distance(r, prevPos, stop and { map = stop.map, x = stop.x, y = stop.y }))))
		end
		add("")
	end
	add("Planner diagnostics:")
	add(string.format("  Candidates: %d located (+%d optional hints, %d without a location)", d.candidates or 0, d.optional or 0, d.unlocated or 0))
	add(string.format("  Stops: %d   Considered: %s   Sequences scored: %s   Selected stops: %d", d.stops or 0, tostring(d.considered), tostring(d.sequences), d.sequence and #d.sequence or 0))
	if d.sequence then
		local doing = 0
		for _, sid in ipairs(d.sequence) do for _, s in ipairs(d.stopList) do if s.id == sid then doing = doing + s.dwell end end end
		add(string.format("  Estimated sequence time: %ds (about %ds walking + %ds doing; walking = yards / %d, an estimate)", math.floor(d.seconds + 0.5),
			math.floor(d.seconds - doing + 0.5), math.floor(doing + 0.5), r.ns.Planner.RUN_SPEED))
		add(string.format("  Sequence value (net policy points, not XP): %.1f   ALSO DO interruption: %s   Unknown legs: %s", d.net, d.interruption and (d.interruption .. "s") or "-", tostring(d.unknownLegs)))
	end
	-- the reasons, derived from the plan (nothing is assumed about which scenario this is)
	local why = {}
	local function codes(id) local out = {}; for _, x in ipairs(d.reasons and d.reasons[id] or {}) do out[x.code] = x end return out end
	if plan.now then
		local cn = codes(plan.now.id)
		local firstStop = d.items[plan.now.id] and d.items[plan.now.id].stop
		local mates = 0
		for _, s in ipairs(d.stopList) do if s.id == firstStop then mates = #s.items end end
		if mates > 1 then why[#why + 1] = string.format("%d actions share the first stop, so they cost one trip", mates) end
		if cn.TURN_IN_WAITS then
			-- what starting with a turn-in would have been worth, from the scored sequences
			local bestTurnIn
			for _, q in ipairs(d.sequenceList or {}) do
				local f = q.stops[1]
				for _, s in ipairs(d.stopList) do
					if s.id == f then for _, id in ipairs(s.items) do if d.items[id].kind == "TURN_IN" and not bestTurnIn then bestTurnIn = q end end end
				end
			end
			why[#why + 1] = "a turn-in is ready but waits: " .. (bestTurnIn and string.format("starting with a turn-in would score %.1f (this plan %.1f) and take %ds", bestTurnIn.net, d.net, math.floor(bestTurnIn.secs + 0.5))
				or "no sequence that starts with it scored well enough to be compared")
		end
		if cn.ON_THE_WAY then why[#why + 1] = string.format("the first stop is on the way to the second (%ds detour)", cn.ON_THE_WAY.seconds) end
		if cn.CHAIN_UNLOCK then why[#why + 1] = "NOW includes chain credit: turning it in makes a follow-up quest available (from ATT prerequisites, unverified)" end
		if cn.ROUTE_ZONE then why[#why + 1] = "only the player's chosen route zone was sequenced" end
		if cn.PLAYER_ADDED then why[#why + 1] = "the player added this quest" end
	end
	for id, it in pairs(d.items or {}) do
		if it.comps and it.comps.chain and not (plan.now and plan.now.id == id) then
			why[#why + 1] = string.format("chain credit %.1f applied to %s (unlocks a follow-up; ATT prerequisite data, unverified)", it.comps.chain, title(r, { id = id }))
		end
	end
	if plan.alsoDo then
		local ca = codes(plan.alsoDo.id)
		why[#why + 1] = ca.SAME_STOP and "ALSO DO shares the first stop (no extra walking)" or (ca.ON_THE_WAY and "ALSO DO is on the way" or (ca.SMALL_DETOUR and string.format("ALSO DO costs a %ds detour", ca.SMALL_DETOUR.seconds) or "ALSO DO fits the trip"))
	else
		why[#why + 1] = "nothing cleared the ALSO DO bar (silence is the default)"
	end
	if (d.unknownLegs or 0) > 0 then why[#why + 1] = "a leg's walking time is unknown (other continent / no conversion): ranked after known legs" end
	if d.routeZoneOnly then why[#why + 1] = "route zone chosen: other zones' stops were not sequenced" end
	if d.stuck then why[#why + 1] = "kept the previous NOW (within the stability margin)" end
	if #L and #why > 0 then
		add("")
		add("Reason summary:")
		table.sort(why)
		for _, w in ipairs(why) do add("  - " .. w) end
	end
	if d.alternatives and #d.alternatives > 0 then
		local alt = {}
		for _, a in ipairs(d.alternatives) do alt[#alt + 1] = string.format("%s (%.1f lower)", title(r, { id = a.id }), a.deficit) end
		add("")
		add("Runners-up as the first step: " .. table.concat(alt, "; "))
	end
	if d.rejected and #d.rejected > 0 then
		local rej = {}
		for _, x in ipairs(d.rejected) do rej[#rej + 1] = title(r, { id = x.id }) .. " [" .. x.code .. (x.seconds and (" " .. x.seconds .. "s") or "") .. "]" end
		add("Rejected as ALSO DO: " .. table.concat(rej, "; "))
	end
	add("")
	local p = d.params
	if p then
		add(string.format("(constants in force: timeValue %.2f/s, detour limit %ds, ALSO DO floor %d, stop radius %d yd, chain share %.2f; none changed by this harness)", p.timeValue, p.detour, p.alsoFloor,
			r.ns.Planner.STOP_RADIUS, p.chain))
	end
	return L
end

local function emit(lines)
	if VERBOSE then
		for _, l in ipairs(lines) do print(l) end
		print(string.rep("-", 78))
	end
end

local function summary(r)
	return string.format("NOW=%s | ALSO DO=%s | THEN=%s", title(r, r.plan.now), title(r, r.plan.alsoDo), title(r, r.plan.thenAction))
end

-- ---------------------------------------------------------------- scenario registry

local function scenario(s) scenarios[#scenarios + 1] = s end

local function Q(id, name, x, y, o)
	local q = { id = id, name = name, map = 9001, x = x, y = y }
	for k, v in pairs(o or {}) do q[k] = v end
	return q
end

-- A fixture's player stands at the centre of map 9001; positions are offsets in yards (east = +x, north = -y)
local function at(dx, dy) return 0.5 + yd(dx), 0.5 + yd(dy or 0) end
local function QA(id, name, dx, dy, o) local x, y = at(dx, dy); return Q(id, name, x, y, o) end

-- ===== REAL-DATA SCENARIOS (Durotar pack; positions from the ATT pack and the playtest notes) =====

local CAMP = { map = 1411, x = 0.4457, y = 0.6862 }      -- Foreman Thazz'ril / Lazy Peons (ATT giver coordinate)

-- the playtest-observed objective positions (CODEX_PLANNING_MODEL.md observations 8 and 13), supplied to THIS scenario only
local OBSERVED = {
	[789] = { id = 789, objCoords = { { map = 1411, x = 0.465, y = 0.584 } } },       -- Sting of the Scorpid: scorpids at 46.5, 58.4
	[792] = { id = 792, objCoords = { { map = 1411, x = 0.453, y = 0.568 } } },       -- Vile Familiars: at 45.3, 56.8
	[6394] = { id = 6394, objCoords = { { map = 1411, x = 0.437, y = 0.538 } } },     -- Thazz'ril's Pick: on the Pick at 43.7, 53.8
}

local SCORPID_LOG = {
	[4402] = { title = "Galgar's Cactus Apple Surprise", complete = true },        -- finished: turn-in is back at the camp
	[789] = { title = "Sting of the Scorpid", objectives = { { text = "Scorpid Worker Tail", have = 3, need = 10 } } },
	[792] = { title = "Vile Familiars", objectives = { { text = "Vile Familiar slain", have = 0, need = 12 } } },
}

scenario({
	name = "A0 Scorpid / Vile / Cactus, REAL DATA AS IT IS", kind = "review", data = "real", level = 4,
	about = "Level 4 in the scorpid area; Cactus Apples done, Scorpid tails 3/10, Vile Familiars 0/12. ATT has NO objective coordinates for these quests.",
	player = { map = 1411, x = 0.465, y = 0.584, zone = "Durotar" }, log = SCORPID_LOG,
	assert = function(r, ok)
		local reminder = {}
		for _, a in ipairs(r.plan.reminders) do reminder[a.quest or 0] = true end
		ok("the Scorpid and Vile objectives have no location in the data: they are reminders, not places to go", reminder[789] and reminder[792])
		local routed = false
		for _, a in ipairs({ r.plan.now, r.plan.alsoDo, r.plan.thenAction }) do
			if a and (a.id == "Q:789:OBJECTIVE" or a.id == "Q:792:OBJECTIVE") then routed = true end
		end
		-- (0.7.1) finishing in-progress work in this area with no map spot can be NOW (StayLocal, documented): it has no target, so nothing is routed or pointed at
		local pointed = false
		for _, a in ipairs({ r.plan.now, r.plan.alsoDo, r.plan.thenAction }) do
			if a and (a.id == "Q:789:OBJECTIVE" or a.id == "Q:792:OBJECTIVE") and a.target then pointed = true end
		end
		ok("and are never routed to a place (as NOW they carry no target)", not pointed)
		local invented = false
		for _, a in ipairs(r.plan.reminders) do for _, t in ipairs(a.targets or {}) do if t.where.points then invented = true end end end
		ok("no coordinates were invented for them", not invented)
	end,
})

scenario({
	name = "A1 Scorpid / Vile / Cactus, with the playtest-observed objective positions", kind = "review", data = "real", level = 4,
	about = "Same state, but the scorpid (46.5, 58.4) and Vile Familiar (45.3, 56.8) positions the player reported are supplied as a test-only overlay.",
	player = { map = 1411, x = 0.465, y = 0.584, zone = "Durotar" }, log = SCORPID_LOG, observed = OBSERVED,
})

scenario({
	name = "A2 Scorpid / Vile / Cactus, standing at the camp turn-ins", kind = "review", data = "real", level = 4,
	about = "Same quests and overlay, but the player is back at the camp (where the Cactus turn-in is).",
	player = { map = 1411, x = 0.426, y = 0.672, zone = "Durotar" }, log = SCORPID_LOG, observed = OBSERVED,
})

scenario({
	name = "D1 Lazy Peons density (camp), real data + illustrative objective placement", kind = "review", data = "real", level = 4,
	about = "Just accepted Lazy Peons at the camp. Cactus Apples, Scorpid tails and Vile Familiars in the log. Peon and apple positions are ILLUSTRATIVE (not in any data).",
	player = CAMP, log = {
		[5441] = { title = "Lazy Peons", objectives = { { text = "Peons Awoken", have = 0, need = 5 } } },
		[4402] = { title = "Galgar's Cactus Apple Surprise", objectives = { { text = "Cactus Apple", have = 0, need = 10 } } },
		[789] = SCORPID_LOG[789], [792] = SCORPID_LOG[792],
	},
	observed = OBSERVED,
	illustrative = { [5441] = { id = 5441, objCoords = { { map = 1411, x = 0.447, y = 0.692 } } }, [4402] = { id = 4402, objCoords = { { map = 1411, x = 0.43, y = 0.65 } } } },
})

scenario({
	name = "E2 Chain credit on real data: two ready turn-ins", kind = "review", data = "real", level = 4,
	about = "Cutting Teeth (unlocks Sting of the Scorpid, Simple Parchment, Cactus Apples per ATT) and Lazy Peons (unlocks Thazz'ril's Pick) are both ready.",
	player = { map = 1411, x = 0.50, y = 0.60, zone = "Durotar" },
	log = { [788] = { title = "Cutting Teeth", complete = true }, [5441] = { title = "Lazy Peons", complete = true } },
})

scenario({
	name = "H1 Level 2 vs level 4 at the camp (same place, same log)", kind = "deterministic", data = "real", level = 2,
	about = "Quests with a required level (Lazy Peons 3, Carry Your Weight 4) appear only when the character has the level.",
	player = CAMP,
	assert = function(r, ok)
		local function ids(res)
			local set = {}
			for _, l in ipairs({ res.c.candidates, res.c.inProgress }) do for _, a in ipairs(l) do set[a.quest or 0] = true end end
			return set
		end
		local low = ids(r)
		local high = ids(run(r.sc, { level = 4 }))
		ok("level 2: Lazy Peons (requires 3) is not a candidate", not low[5441])
		ok("level 4: Lazy Peons is a candidate", high[5441])
		ok("level 2: Carry Your Weight (requires 4) is not a candidate", not low[791])
		ok("level 4: Carry Your Weight is a candidate", high[791])
		local n1, n2 = 0, 0
		for _ in pairs(low) do n1 = n1 + 1 end
		for _ in pairs(high) do n2 = n2 + 1 end
		ok("the level-4 character has more to choose from than the level-2 one (" .. n1 .. " vs " .. n2 .. ")", n2 > n1)
	end,
})

-- ===== CONTROLLED (SYNTHETIC) SCENARIOS =====

local READY = { complete = true }

scenario({
	name = "B Turn-in 300 yd away vs useful work 40 yd away", kind = "review", level = 6,
	about = "A ready turn-in 300 yd east; an objective 40 yd west; a second objective in the same local area.",
	quests = { QA(1, "The ready quest", 300, 0), QA(2, "Local objective one", -40, 0, { objCoords = { { map = 9001, x = at(-40, 0), y = 0.5 } } }),
		QA(3, "Local objective two", -30, 10, { objCoords = { { map = 9001, x = at(-30, 10), y = 0.5 } } }) },
	log = { [1] = { complete = true }, [2] = { objectives = { { text = "things", have = 0, need = 5 } } }, [3] = { objectives = { { text = "stuff", have = 0, need = 5 } } } },
	assert = function(r, ok)
		ok("local work before the turn-in: NOW is an objective, not the turn-in", r.plan.now and r.plan.now.kind == "OBJECTIVE")
		ok("the turn-in is still in the plan (THEN)", r.plan.thenAction and r.plan.thenAction.id == "Q:1:TURN_IN")
	end,
})

scenario({
	name = "C1 Productive travel: pickup 10 yd off the path to a 300 yd destination", kind = "review", level = 6,
	about = "The destination is an objective area 300 yd east; an unrelated pickup is 10 yd off the straight path.",
	quests = { QA(1, "Destination", 300, 0, { objCoords = { { map = 9001, x = at(300, 0), y = 0.5 } } }), QA(2, "Pickup on the way", 150, 10) },
	log = { [1] = { objectives = { { text = "things", have = 0, need = 5 } } } },
})

scenario({
	name = "C2 Productive travel: pickup 120 yd off the path (a real detour)", kind = "review", level = 6,
	about = "Same destination; the pickup is 120 yd off the straight path.",
	quests = { QA(1, "Destination", 300, 0, { objCoords = { { map = 9001, x = at(300, 0), y = 0.5 } } }), QA(2, "Pickup off the path", 150, 120) },
	log = { [1] = { objectives = { { text = "things", have = 0, need = 5 } } } },
})

scenario({
	name = "D2 Local density: five local actions vs one 375 yd away", kind = "review", level = 4,
	about = "Three objectives and two pickups within a few tens of yards of the player; one more pickup 375 yd away.",
	quests = {
		QA(1, "Local objective one", 10, 10, { objCoords = { { map = 9001, x = at(10, 10), y = 0.5 } } }), QA(2, "Local objective two", 20, -10, { objCoords = { { map = 9001, x = at(20, -10), y = 0.5 } } }),
		QA(3, "Local objective three", -15, 15, { objCoords = { { map = 9001, x = at(-15, 15), y = 0.5 } } }), QA(4, "Local pickup one", 5, -20), QA(5, "Local pickup two", -10, -20),
		QA(6, "Distant pickup", 375, 0) },
	log = { [1] = { objectives = { { text = "a", have = 0, need = 5 } } }, [2] = { objectives = { { text = "b", have = 0, need = 5 } } }, [3] = { objectives = { { text = "c", have = 0, need = 5 } } } },
})

scenario({
	name = "E1 Chain credit: two ready turn-ins 500 yd apart, one unlocks a follow-up", kind = "deterministic", level = 6,
	about = "Turn-in A (west) and turn-in B (east), each 500 yd away; B's quest has a follow-up offered at B's giver. One trip only is worth it. (Chain credit is ATT-derived and unverified.)",
	quests = { QA(1, "Quest A", -500, 0), QA(2, "Quest B", 500, 0), QA(3, "Follow-up to B", 505, 0, { prereq = { 2 } }) },
	log = { [1] = READY, [2] = READY },
	assert = function(r, ok)
		ok("with the follow-up, B is NOW", r.plan.now and r.plan.now.id == "Q:2:TURN_IN")
		local it = r.diag.items["Q:2:TURN_IN"]
		ok("B carries chain credit and A does not", it and it.comps.chain and it.comps.chain > 0 and not r.diag.items["Q:1:TURN_IN"].comps.chain)
		ok("the chain credit is not provenance: the action is still unverified", r.plan.now.evidence ~= "observed")
		local without = run(r.sc, { quests = { QA(1, "Quest A", -500, 0), QA(2, "Quest B", 500, 0) } })
		ok("without the follow-up the two are tied and the smaller id wins (deterministic)", without.plan.now and without.plan.now.id == "Q:1:TURN_IN")
	end,
})

scenario({
	name = "F Unknown location", kind = "deterministic", level = 6,
	about = "A ready quest and an in-progress quest the data has no location for, next to one located pickup.",
	quests = { QA(1, "Located pickup", 80, 0) },
	log = { [900] = { title = "Not in any data (ready)", complete = true }, [901] = { title = "Not in any data (open)" } },
	assert = function(r, ok)
		local rem = {}
		for _, a in ipairs(r.plan.reminders) do rem[a.quest] = a end
		ok("both unknown-location quests are reminders", rem[900] and rem[901])
		local id900 = "Q:900:TURN_IN"
		ok("neither is NOW, ALSO DO or THEN", not ((r.plan.now and r.plan.now.quest >= 900) or (r.plan.alsoDo and r.plan.alsoDo.quest >= 900) or (r.plan.thenAction and r.plan.thenAction.quest >= 900)))
		local coords = false
		for _, a in ipairs(r.plan.reminders) do for _, t in ipairs(a.targets) do if t.where.points or t.where.status ~= "unknown" then coords = true end end end
		ok("no coordinates were invented", not coords)
		local legacy = r.ns.PlanAdapter.ToLegacy(r.plan, r.ctx, r.c)
		local fake = false
		for _, a in ipairs(legacy.sequence) do if (a.forId or a.id):find(":90%d:") then fake = true end end
		ok("the old-UI sequence has no travel step or stop for them", not fake)
		ok("they are listed under 'in your log, location unknown'", #legacy.inProgress >= 2)
		ok("the one located pickup is NOW", r.plan.now and r.plan.now.id == "Q:1:ACCEPT")
		ok("(id check) " .. id900 .. " exists as a reminder", rem[900] and rem[900].id == id900)
		ok("no waypoint was placed", H.world().waypointCalls == 0)
	end,
})

scenario({
	name = "G Same-name quests", kind = "deterministic", level = 6,
	about = "Two different quests are both called 'Simple Parchment' (as in the playtest). One is already completed; the other is open.",
	quests = { QA(2383, "Simple Parchment", 60, 0), QA(2384, "Simple Parchment", 70, 10), QA(2385, "Simple Parchment", 90, 0) },
	completed = { 2383 }, log = { [2385] = { complete = true } },
	assert = function(r, ok)
		local ids = {}
		for _, l in ipairs({ r.c.candidates, r.c.inProgress }) do for _, a in ipairs(l) do ids[a.id] = a end end
		ok("the completed one is never an action", ids["Q:2383:ACCEPT"] == nil and ids["Q:2383:TURN_IN"] == nil)
		ok("the open one is offered by its own id", ids["Q:2384:ACCEPT"] ~= nil)
		ok("the ready one is a turn-in by its own id", ids["Q:2385:TURN_IN"] ~= nil)
		local names = {}
		for _, a in ipairs({ ids["Q:2384:ACCEPT"], ids["Q:2385:TURN_IN"] }) do names[#names + 1] = (a.title:gsub("^%a+[ a-z]*: ", "")) end
		ok("(setup) the two live quests really do share one visible name", names[1] == names[2] and names[1] == "Simple Parchment")
		ok("and are different actions with different quest ids", ids["Q:2384:ACCEPT"].ref.id ~= ids["Q:2385:TURN_IN"].ref.id and ids["Q:2384:ACCEPT"].id ~= ids["Q:2385:TURN_IN"].id)
		local seen, dup = {}, false
		for _, a in ipairs({ r.plan.now, r.plan.alsoDo, r.plan.thenAction }) do if a then if seen[a.id] then dup = true end seen[a.id] = true end end
		ok("no action is repeated in the plan", not dup)
		local nm = 0
		for _, a in ipairs({ r.plan.now, r.plan.alsoDo, r.plan.thenAction }) do if a and a.quest == 2383 then nm = nm + 1 end end
		ok("the completed same-name quest is not in the plan", nm == 0)
	end,
})

scenario({
	name = "I1 Skip: Q:<id> on an unaccepted quest", kind = "deterministic", level = 6, skipped = { "Q:1" },
	about = "The legacy ACCEPT skip key vetoes the quest.",
	quests = { QA(1, "Nearest pickup", 20, 0), QA(2, "Other pickup", 60, 0) },
	assert = function(r, ok)
		local ids = {}
		for _, a in ipairs({ r.plan.now, r.plan.alsoDo, r.plan.thenAction }) do if a then ids[a.quest] = true end end
		ok("skipped quest 1 is not NOW / ALSO DO / THEN", not ids[1])
		ok("quest 2 is", ids[2])
	end,
})

scenario({
	name = "I2 Skip: QT:<id> (the key the old engine used for quests already in the log)", kind = "deterministic", level = 6, skipped = { "QT:1" },
	about = "The in-progress skip key. The old engine only honoured it for quests in the log; the Planner honours either key.",
	quests = { QA(1, "Pickup with only the in-progress key set", 20, 0), QA(2, "Other pickup", 60, 0) },
	assert = function(r, ok)
		local ids = {}
		for _, a in ipairs({ r.plan.now, r.plan.alsoDo, r.plan.thenAction }) do if a then ids[a.quest] = true end end
		ok("quest 1 is vetoed by QT:1 even though it is not in the log (Phase 2 design: either legacy key)", not ids[1])
		ok("quest 2 is not", ids[2])
		local legacyRun = run(r.sc)
		legacyRun.ns.State.SetPlanner(false)
		local old = legacyRun.ns.State.Recompute()
		local oldHas = false
		for _, a in ipairs(old.sequence) do if a.quest == 1 then oldHas = true end end
		ok("(documented difference) the previous engine still offers quest 1 with only QT:1 set", oldHas)
	end,
})

scenario({
	name = "I3 Skip + Add, and a skipped quest already in the log", kind = "deterministic", level = 6, skipped = { "Q:1", "QT:2", "QT:3" }, added = { 1 },
	about = "Quest 1: skipped then added. Quest 2 (in the log, objective area known): QT skip. Quest 3 (ready): QT skip. Add clears Q:<id> only (legacy).",
	quests = { QA(1, "Added after skipping", 40, 0), QA(2, "In the log, skipped", 100, 0, { objCoords = { { map = 9001, x = at(100, 0), y = 0.5 } } }), QA(3, "Ready, skipped", 120, 0), QA(4, "Plain", 80, 0) },
	log = { [2] = { objectives = { { text = "x", have = 0, need = 3 } } }, [3] = READY },
	assert = function(r, ok)
		local ids = {}
		for _, a in ipairs({ r.plan.now, r.plan.alsoDo, r.plan.thenAction }) do if a then ids[a.quest] = true end end
		ok("Add after Skip: quest 1 is planned (Add clears Q:1 and is the player's latest choice)", ids[1])
		ok("a skipped quest in the log (QT:2) is not planned", not ids[2])
		ok("a skipped ready quest (QT:3) is not planned", not ids[3])
		ok("Add did not clear a QT key (legacy behaviour is understood, not redesigned)", r.ns.Prefs.IsSkipped("QT:2") and not r.ns.Prefs.IsSkipped("Q:1"))
	end,
})

scenario({
	name = "J Confidence and provenance", kind = "deterministic", level = 6,
	about = "Four candidates 100 yd apart in different directions: an observed, exact location; an approximate area; an assumed turn-in; an ATT-only pickup.",
	quests = { QA(2, "Approximate objective area", 0, 100, { objCoords = { { map = 9001, x = 0.5, y = at(0, 100) and 0.6 } } }), QA(3, "Assumed turn-in", -100, 0), QA(4, "ATT-only pickup", 0, -100) },
	observed = { [1] = { id = 1, name = "Observed, exact", map = 9001, x = 0.6, y = 0.5 } },
	log = { [2] = { objectives = { { text = "x", have = 0, need = 3 } } }, [3] = READY },
	assert = function(r, ok)
		local it = r.diag.items
		local obs, apx, asm, att = it["Q:1:ACCEPT"], it["Q:2:OBJECTIVE"], it["Q:3:TURN_IN"], it["Q:4:ACCEPT"]
		ok("an observed, exact location is fully trusted (confidence 1)", obs and obs.conf == 1)
		ok("an approximate area is trusted less", apx and apx.conf < 1)
		ok("an assumed turn-in is trusted less than an exact location", asm and asm.conf < 1 and asm.assumed == true)
		ok("an ATT-only pickup is trusted less than an observed one", att and att.conf < obs.conf)
		for _, a in ipairs(r.c.candidates) do
			if a.quest == 3 or a.quest == 4 or a.quest == 2 then
				for _, t in ipairs(a.targets) do
					ok("ATT-derived target of " .. a.id .. " is not verified after passing through the contract", t.prov.src ~= "att" or t.prov.verified == false)
				end
				ok(a.id .. " evidence is not 'observed'", a.evidence ~= "observed")
			end
		end
	end,
})

scenario({
	name = "K1 Far quest: local work + a quest about 3000 yd away", kind = "review", level = 6,
	about = "Two local pickups near the player; one pickup in another zone about 3000 yd east. No route zone chosen.",
	quests = { QA(1, "Local pickup one", 30, 0), QA(2, "Local pickup two", -40, 20), Q(3, "Far pickup", 0.5, 0.5, { map = 9002 }) },
	zones = { { key = "zone-a", label = "Zone A", map = 9001, quests = 2 }, { key = "zone-b", label = "Zone B", map = 9002, quests = 1 } },
})

scenario({
	name = "K2 Far quest: the same, with the far zone chosen as the route zone", kind = "review", level = 6, routeZone = "zone-b",
	about = "As K1, but the player chose Zone B (the far zone) as their route zone.",
	quests = { QA(1, "Local pickup one", 30, 0), QA(2, "Local pickup two", -40, 20), Q(3, "Far pickup", 0.5, 0.5, { map = 9002 }) },
	zones = { { key = "zone-a", label = "Zone A", map = 9001, quests = 2 }, { key = "zone-b", label = "Zone B", map = 9002, quests = 1 } },
})

scenario({
	name = "L Only one clearly useful action", kind = "deterministic", level = 6,
	about = "A single ready turn-in 60 yd away and nothing else.",
	quests = { QA(1, "The only quest", 60, 0) }, log = { [1] = READY },
	assert = function(r, ok)
		ok("NOW is the only action", r.plan.now and r.plan.now.id == "Q:1:TURN_IN")
		ok("ALSO DO is nil: no opportunity is invented", r.plan.alsoDo == nil)
		ok("THEN is nil: no continuation is invented", r.plan.thenAction == nil)
	end,
})

scenario({
	name = "L2 Two stops, no opportunity: NOW and THEN, ALSO DO stays empty", kind = "deterministic", level = 6,
	about = "Two objective areas 160 yd apart (80 yd either side of the player) and nothing else.",
	quests = { QA(1, "Area east", 80, 0, { objCoords = { { map = 9001, x = at(80, 0), y = 0.5 } } }), QA(2, "Area west", -80, 0, { objCoords = { { map = 9001, x = at(-80, 0), y = 0.5 } } }) },
	log = { [1] = { objectives = { { text = "a", have = 0, need = 5 } } }, [2] = { objectives = { { text = "b", have = 0, need = 5 } } } },
	assert = function(r, ok)
		ok("NOW and THEN are the two areas", r.plan.now and r.plan.thenAction and r.plan.now.id ~= r.plan.thenAction.id)
		ok("ALSO DO is nil: the second area is THEN, it is not also offered as an opportunity", r.plan.alsoDo == nil)
	end,
})

scenario({
	name = "M Same-stop batching, then the next stop", kind = "deterministic", level = 6,
	about = "Two pickups 25 yd apart at one spot 60 yd away, and a ready turn-in 400 yd beyond.",
	quests = { QA(1, "Pickup A", 60, 0), QA(2, "Pickup B", 85, 0), QA(3, "Turn-in at the next stop", 460, 0) }, log = { [3] = READY },
	assert = function(r, ok)
		ok("NOW is one of the two pickups", r.plan.now and r.plan.now.kind == "ACCEPT")
		ok("ALSO DO is the other pickup at the same stop", r.plan.alsoDo and r.plan.alsoDo.kind == "ACCEPT" and r.plan.alsoDo.id ~= r.plan.now.id)
		ok("THEN is the next stop (the turn-in)", r.plan.thenAction and r.plan.thenAction.id == "Q:3:TURN_IN")
		ok("two stops: the pickups are one stop, the turn-in another", r.diag.stops == 2 and #r.diag.sequence == 2)
		ok("the two pickups are separate actions at one stop (not merged into one fake action)", r.plan.now.id ~= r.plan.alsoDo.id and r.diag.items[r.plan.now.id].stop == r.diag.items[r.plan.alsoDo.id].stop)
		ok("no action appears twice", r.plan.now ~= r.plan.alsoDo and r.plan.now ~= r.plan.thenAction and r.plan.alsoDo ~= r.plan.thenAction)
	end,
})

-- ---------------------------------------------------------------- sweeps (REVIEW tables: how the decision changes with one number)

local sweeps = {}

local function classify(r, id)
	local p, d = r.plan, r.diag
	if p.now and p.now.id == id then
		local on
		for _, x in ipairs(d.reasons[id] or {}) do if x.code == "ON_THE_WAY" then on = x end end
		return on and string.format("NOW (on the way, +%ds)", on.seconds) or "NOW"
	end
	if p.alsoDo and p.alsoDo.id == id then return "ALSO DO" end
	if p.thenAction and p.thenAction.id == id then return "THEN" end
	for _, x in ipairs(d.rejected or {}) do if x.id == id then return "rejected as ALSO DO: " .. x.code end end
	for _, s in ipairs(d.sequence or {}) do for _, st in ipairs(d.stopList) do if st.id == s then for _, i in ipairs(st.items) do if i == id then return "in the sequence (later)" end end end end end
	return "not in the plan"
end

local function sweepTable(name, header, rows)
	local out = { "", "SWEEP (REVIEW): " .. name, "  " .. header }
	for _, row in ipairs(rows) do out[#out + 1] = "  " .. row end
	sweeps[#sweeps + 1] = out
	if VERBOSE then for _, l in ipairs(out) do print(l) end end
end

local function runSweeps()
	local B = {}
	for _, d in ipairs({ 40, 100, 200, 300, 500, 800 }) do
		local r = run({ name = "sweep", level = 6, quests = { QA(1, "The ready quest", d, 0), QA(2, "Local objective one", -40, 0, { objCoords = { { map = 9001, x = at(-40, 0), y = 0.5 } } }),
			QA(3, "Local objective two", -30, 10, { objCoords = { { map = 9001, x = at(-30, 10), y = 0.5 } } }) },
			log = { [1] = READY, [2] = { objectives = { { text = "a", have = 0, need = 5 } } }, [3] = { objectives = { { text = "b", have = 0, need = 5 } } } } })
		B[#B + 1] = string.format("%4d yd | %s", d, summary(r))
	end
	sweepTable("B: distance of a ready turn-in vs two local objectives", "turn-in at | plan", B)
	local C = {}
	for _, off in ipairs({ 5, 10, 20, 40, 80, 120, 200, 300 }) do
		local r = run({ name = "sweep", level = 6, quests = { QA(1, "Destination", 300, 0, { objCoords = { { map = 9001, x = at(300, 0), y = 0.5 } } }), QA(2, "Pickup", 150, off) },
			log = { [1] = { objectives = { { text = "x", have = 0, need = 5 } } } } })
		C[#C + 1] = string.format("%4d yd off the path | pickup: %-34s | %s", off, classify(r, "Q:2:ACCEPT"), summary(r))
	end
	sweepTable("C: how far off the path to a 300 yd destination a pickup lies", "offset | what the planner does with the pickup | plan", C)
	local K = {}
	for _, x in ipairs({ 0.0, 0.1, 0.25, 0.5, 0.75, 1.0 }) do
		local dist = 3000 + 1000 * x - 500
		local r = run({ name = "sweep", level = 6, zones = { { key = "zone-a", label = "Zone A", map = 9001, quests = 2 }, { key = "zone-b", label = "Zone B", map = 9002, quests = 1 } },
			quests = { QA(1, "Local pickup one", 30, 0), QA(2, "Local pickup two", -40, 20), Q(3, "Far pickup", x, 0.5, { map = 9002 }) } })
		K[#K + 1] = string.format("%5d yd | far pickup: %-28s | %s", math.floor(dist + 0.5), classify(r, "Q:3:ACCEPT"), summary(r))
	end
	sweepTable("K: distance of a far-zone pickup (same continent) next to two local pickups", "distance | what the planner does with it | plan", K)
	local Kc = {}
	local r = run({ name = "sweep", level = 6, zones = { { key = "zone-a", label = "Zone A", map = 9001, quests = 2 }, { key = "zone-c", label = "Zone C (other continent)", map = 9003, quests = 1 } },
		quests = { QA(1, "Local pickup one", 30, 0), Q(3, "Pickup on another continent", 0.5, 0.5, { map = 9003 }) } })
	Kc[#Kc + 1] = string.format("other continent | pickup: %-28s | %s | unknown legs in the plan: %s", classify(r, "Q:3:ACCEPT"), summary(r), tostring(r.diag.unknownLegs))
	sweepTable("K: a pickup on another continent next to one local pickup", "case | what the planner does with it | plan", Kc)
	local S = {}
	for _, style in ipairs({ "efficient", "fast", "questing_only", "completionist" }) do
		local rr = run({ name = "sweep", level = 6, style = style, quests = { QA(1, "The ready quest", 300, 0), QA(2, "Local objective one", -40, 0, { objCoords = { { map = 9001, x = at(-40, 0), y = 0.5 } } }),
			QA(3, "Local objective two", -30, 10, { objCoords = { { map = 9001, x = at(-30, 10), y = 0.5 } } }), QA(4, "A pickup 250 yd away", 0, 250) },
			log = { [1] = READY, [2] = { objectives = { { text = "a", have = 0, need = 5 } } }, [3] = { objectives = { { text = "b", have = 0, need = 5 } } } } })
		S[#S + 1] = string.format("%-14s | %s", style, summary(rr))
	end
	sweepTable("strategies on one situation (turn-in 300 yd, two local objectives, a pickup 250 yd south)", "strategy | plan", S)
end

-- ---------------------------------------------------------------- run everything

section("planner evaluation: calibration scenarios (DETERMINISTIC = asserted, REVIEW = reported only)")
do
	local counts = { deterministic = 0, review = 0, checks = 0 }
	for _, sc in ipairs(scenarios) do
		local r = run(sc)
		emit(report(r))
		if sc.kind == "deterministic" then
			counts.deterministic = counts.deterministic + 1
			if sc.assert then
				sc.assert(r, function(text, cond)
					counts.checks = counts.checks + 1
					check(cond and true or false, "[" .. sc.name:match("^(%S+)") .. "] " .. text)
				end)
			end
		else
			counts.review = counts.review + 1
			if not VERBOSE then print(string.format("  REVIEW  %-72s %s", sc.name, summary(r))) end
			if sc.assert then
				sc.assert(r, function(text, cond)
					counts.checks = counts.checks + 1
					check(cond and true or false, "[" .. sc.name:match("^(%S+)") .. "] " .. text)
				end)
			end
		end
		check(#r.ns.errors == 0, "[" .. sc.name:match("^(%S+)") .. "] no caught errors while evaluating")
	end
	print(string.format("  %d scenarios: %d deterministic (assertions), %d review (report only); %d assertions", #scenarios, counts.deterministic, counts.review, counts.checks))
	runSweeps()
	if not VERBOSE then print("  (full reports and sweep tables: lua5.1 run_planner_eval.lua <addonDir>)") end
end

section("planner evaluation: the trace changes nothing")
do
	for _, sc in ipairs(scenarios) do
		local r = run(sc)
		local ns, ctx, c = r.ns, r.ctx, r.c
		local plain = ns.Planner.Compute(ctx, ns.Engine.Candidates(ctx), {})
		local function sig(p)
			return table.concat({ tostring(p.now and p.now.id), tostring(p.alsoDo and p.alsoDo.id), tostring(p.thenAction and p.thenAction.id), table.concat(p.diag.sequence or {}, ">"), string.format("%.6f", p.diag.net or 0) }, "|")
		end
		check(sig(plain) == sig(r.plan), "[" .. sc.name:match("^(%S+)") .. "] the same plan with and without the trace")
		check(plain.diag.items == nil and plain.diag.params == nil, "[" .. sc.name:match("^(%S+)") .. "] and no trace data is built when it is off")
	end
end

-- ---------------------------------------------------------------- the QuestieDB bridge: equivalent records, the same plan

-- Every scenario is run three ways: with the existing packs only (the baseline), with a fake QuestieDB holding the same facts layered
-- over them, and (where the bridge reads everything the scenario uses) with the fake QuestieDB as the only quest source besides the
-- observed pack. The Planner must make the identical decision each time: it consumes the records, it does not care where they came from.
section("planner evaluation: the QuestieDB bridge feeds the Planner equivalent records (same decisions)")
do
	local function sig(r)
		local d = r.diag
		return table.concat({ summary(r), table.concat(d.sequence or {}, ">"), string.format("%.4f", d.net or 0), string.format("%.2f", d.seconds or 0), tostring(d.stops),
			tostring(d.candidates), tostring(d.unlocated), #r.plan.reminders }, " | ")
	end
	local layered, only, skipped = 0, 0, 0
	for _, sc in ipairs(scenarios) do
		local tag = "[" .. sc.name:match("^(%S+)") .. "] "
		local base = run(sc, { neutralRestrictions = true })
		local lay = run(sc, { bridge = "layered", neutralRestrictions = true })
		local st = lay.ns.QuestieBridge.Status()
		check(st.state == "available" and lay.ns.QuestieBridge.Stats().built > 0, tag .. "the bridge was in use and read records")
		check(sig(lay) == sig(base), tag .. "QuestieDB layered over the existing data: the same plan" .. (sig(lay) ~= sig(base) and ("\n    base:    " .. sig(base) .. "\n    bridged: " .. sig(lay)) or ""))
		check(#lay.ns.errors == 0, tag .. "no caught errors through the bridge")
		layered = layered + 1
		local o = run(sc, { bridge = "only", neutralRestrictions = true })
		if o.needsAtt then
			skipped = skipped + 1
		else
			check(sig(o) == sig(base), tag .. "QuestieDB as the only quest source (plus observed): the same plan" .. (sig(o) ~= sig(base) and ("\n    base:    " .. sig(base) .. "\n    bridged: " .. sig(o)) or ""))
			only = only + 1
		end
		H.fake.new().uninstall()
	end
	print(string.format("  bridge equivalence: %d scenarios layered, %d as the only source (%d need ATT-only data the bridge does not read: objective areas, race lists)", layered, only, skipped))
	check(only >= 8, "the bridge-only comparison covers a meaningful share of the scenarios (" .. only .. "; the rest use objective areas or race lists that only the existing packs carry)")
end

-- ---------------------------------------------------------------- the Phase 2.5 baseline, pinned

-- tests/golden/planner_eval_baseline.txt holds every scenario's decision (NOW / ALSO DO / THEN / stops / net value) and
-- every sweep row as the Planner made them at Phase 2.5. Later phases (the player UI, navigation, ...) must not move it;
-- a deliberate Planner change regenerates it, together with docs/CODEX_PLANNER_EVAL_REPORT.md, in the same reviewed commit:
--     CODEX_WRITE_GOLDEN=1 lua5.1 run_codex_tests.lua ../ForeverCodex
section("planner evaluation: the Phase 2.5 baseline is unchanged")
do
	local lines = {}
	for _, sc in ipairs(scenarios) do
		local r = run(sc)
		local d = r.diag
		lines[#lines + 1] = string.format("%s | %s | seq=%s | net=%.4f | secs=%.2f | stops=%s | reminders=%d", sc.name, summary(r), table.concat(d.sequence or {}, ">"), d.net or 0,
			d.seconds or 0, tostring(d.stops), #r.plan.reminders)
	end
	for _, block in ipairs(sweeps) do for _, l in ipairs(block) do lines[#lines + 1] = l end end
	local text = table.concat(lines, "\n") .. "\n"
	local path = (arg[0]:match("^(.*)[/\\]") or ".") .. "/golden/planner_eval_baseline.txt"
	if os.getenv("CODEX_WRITE_GOLDEN") == "1" then
		local f = assert(io.open(path, "wb"))
		f:write(text)
		f:close()
		print("  (baseline written: " .. path .. ")")
	else
		local f = io.open(path, "rb")
		check(f ~= nil, "the baseline file exists")
		if f then
			local golden = f:read("*a")
			f:close()
			if golden ~= text then
				local gl, tl = {}, {}
				for l in golden:gmatch("([^\n]*)\n") do gl[#gl + 1] = l end
				for l in text:gmatch("([^\n]*)\n") do tl[#tl + 1] = l end
				for i = 1, math.max(#gl, #tl) do
					if gl[i] ~= tl[i] then print("  first difference at line " .. i .. ":\n    baseline: " .. tostring(gl[i]):sub(1, 260) .. "\n    now:      " .. tostring(tl[i]):sub(1, 260)) break end
				end
			end
			check(golden == text, "all " .. #scenarios .. " scenario decisions and every sweep row equal the Phase 2.5 baseline")
		end
	end
end

M.scenarios, M.run, M.report = scenarios, run, report
_G.PLANNER_EVAL = M
