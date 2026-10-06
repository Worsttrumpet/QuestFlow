-- contract_tests.lua: Phase 1 of the Planner migration (structured Action/Target contract).
-- Loaded by run_codex_tests.lua with one argument, the shared harness table H (stub client, boot, check, ...).
--
-- Two jobs:
--   A. BEHAVIOUR NEUTRALITY: the engine's decisions (the plan the existing UI renders) are serialised, using only
--      the LEGACY action fields, for a spread of scenarios and compared with tests/golden/engine_plan.golden, a
--      file produced by the engine BEFORE the contract migration. Any change in recommendations, ordering, scores,
--      distances, reasons, filter counts or warnings fails here.
--   B. CONTRACT: identity, quest states, targets, provenance, objective progress, skip compatibility, immutability.
--
-- To regenerate the golden file deliberately (only when a behaviour change is INTENDED and reviewed):
--     CODEX_WRITE_GOLDEN=1 lua5.1 run_codex_tests.lua ../ForeverCodex

local H = ...
ns_Contract = nil   -- set by the sections below (a global only inside this test file)
local check, section, boot = H.check, H.section, H.boot

local goldenPath = (arg[0]:match("^(.*)[/\\]") or ".") .. "/golden/engine_plan.golden"

-- ---------------------------------------------------------------- canonical serialisation (legacy fields only)

local function num(v) return v == nil and "nil" or string.format("%.4f", v) end

local function sortedKeys(t)
	local k = {}
	for key in pairs(t or {}) do k[#k + 1] = tostring(key) end
	table.sort(k)
	return k
end

local function ser(v)
	local t = type(v)
	if t == "number" then return num(v) end
	if t == "table" then
		local parts = {}
		local keys = {}
		for k in pairs(v) do keys[#keys + 1] = k end
		table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
		for _, k in ipairs(keys) do parts[#parts + 1] = tostring(k) .. "=" .. ser(v[k]) end
		return "{" .. table.concat(parts, ",") .. "}"
	end
	return tostring(v)
end

-- The fields every action carried BEFORE the contract migration. New contract fields are deliberately not listed.
local LEGACY = { "id", "type", "kind", "quest", "skipKey", "title", "lines", "reasons", "src", "verified", "nameSrc", "giver",
	"pinned", "reqLevel", "level", "breadcrumb", "noLocation", "unknown", "hereOnly", "forId", "dist", "_score", "_dist", "_cluster" }

local function actionLine(a)
	local parts = {}
	for _, f in ipairs(LEGACY) do
		if a[f] ~= nil then parts[#parts + 1] = f .. "=" .. ser(a[f]) end
	end
	local t = a.target
	if t then
		parts[#parts + 1] = "target=" .. ser({ map = t.map, x = t.x, y = t.y, label = t.label, src = t.src, verified = t.verified, approx = t.approx })
	end
	return table.concat(parts, "|")
end

local function snapshot(plan)
	local out = {}
	local function list(name, l)
		out[#out + 1] = name .. ": " .. #(l or {})
		for i, a in ipairs(l or {}) do out[#out + 1] = string.format("  %s[%d] %s", name, i, actionLine(a)) end
	end
	list("sequence", plan.sequence)
	list("upcoming", plan.upcoming)
	list("nearby", plan.nearby)
	list("inProgress", plan.inProgress)
	out[#out + 1] = "next=" .. (plan.next and plan.next.id or "nil")
	out[#out + 1] = "stats=" .. ser({ filtered = plan.stats.filtered, byType = plan.stats.byType, candidates = plan.stats.candidates, providers = plan.stats.providers })
	out[#out + 1] = "warnings=" .. ser(plan.warnings)
	out[#out + 1] = "strategy=" .. tostring(plan.strategy) .. " routeZone=" .. tostring(plan.routeZone) .. " routeMap=" .. tostring(plan.routeMap)
	out[#out + 1] = "player=" .. ser(plan.player)
	return table.concat(out, "\n")
end

-- ---------------------------------------------------------------- scenarios (deterministic, real packs + synthetic)

local function pickQuests(ns)
	-- deterministic picks from the real packs: the first quests (by id) with the properties we need
	local R = ns.Registry
	local with = { loc = {}, obj = {}, prereq = {} }
	for _, id in ipairs(R.QuestIds()) do
		local v = R.Quest(id)
		if v.loc and not v.repeatable and not v.prereq and not v.req and #with.loc < 6 then with.loc[#with.loc + 1] = id end
		if v.loc and v.objCoords and not v.repeatable and #with.obj < 3 then with.obj[#with.obj + 1] = id end
		if v.prereq and #with.prereq < 2 then with.prereq[#with.prereq + 1] = id end
	end
	return with
end

local scenarios = {}
local function scenario(name, fn) scenarios[#scenarios + 1] = { name = name, fn = fn } end

local STYLES = { "efficient", "fast", "questing_only", "completionist" }
for _, style in ipairs(STYLES) do
	scenario("real data, Troll Warrior L25 Barrens, style " .. style, function()
		local ns = boot({ char = { level = 25 } })
		ns.Prefs.SetStyle(style)
		return ns
	end)
end
scenario("real data, Gnome Mage L22 (Alliance)", function()
	local ns = boot({ char = { level = 22, class = "Mage", classToken = "MAGE", race = "Gnome", raceToken = "Gnome", faction = "Alliance" }, loc = { map = 1426, x = 0.5, y = 0.5 } })
	return ns
end)
scenario("real data, Orc Hunter L12 Durotar", function()
	return boot({ char = { level = 12, class = "Hunter", classToken = "HUNTER", race = "Orc", raceToken = "Orc" }, loc = { map = 1411, x = 0.5, y = 0.5 } })
end)
scenario("real data, level 1 Orc Warrior", function()
	return boot({ char = { level = 1, race = "Orc", raceToken = "Orc" }, loc = { map = 1411, x = 0.45, y = 0.62 } })
end)
scenario("real data, Night Elf Priest L30, explicit route zone", function()
	local ns = boot({ char = { level = 30, class = "Priest", classToken = "PRIEST", race = "Night Elf", raceToken = "NightElf", faction = "Alliance" }, loc = { map = 1438, x = 0.5, y = 0.5 } })
	local z = ns.Registry.Zones()[1]
	if z then ns.Prefs.SetRouteZone(z.key) end
	return ns
end)
scenario("real data, location unavailable", function() return boot({ noLoc = true }) end)
scenario("real data, flight hints off", function()
	local ns = boot({ char = { level = 25 } })
	ns.Prefs.SetSystem("flight", false)
	return ns
end)
scenario("real data, hardcore flag", function()
	local ns = boot({ char = { level = 25 } })
	ns.Prefs.SetHardcore(true)
	return ns
end)
scenario("real data, quest log (one ready, one in progress, one unknown to the data), completions, skips, pins", function()
	local ns = boot({ char = { level = 25 } })
	local q = pickQuests(ns)
	local W = H.world()
	W.log = {
		{ questID = q.loc[1], title = "ready quest", complete = true },
		{ questID = q.obj[1], title = "in progress quest", complete = false },
		{ questID = 999991, title = "a quest no pack knows", complete = false },
		{ questID = 999992, title = "another unknown, done", complete = true },
	}
	W.completed[q.loc[2]] = true
	ns.Prefs.Skip("Q:" .. q.loc[3])
	ns.Prefs.Skip("QT:" .. q.obj[1])           -- skips the in-progress reminder, as the UI would
	ns.Prefs.Skip("FP:" .. (ns.Registry.FlightNodes()[1] and ns.Registry.FlightNodes()[1].id or 0))
	ns.Prefs.Add(q.loc[4])
	ns.Prefs.Add(999993)                       -- pinned quest no pack knows
	return ns
end)
scenario("real data, in-progress quests with objective coordinates (not skipped)", function()
	local ns = boot({ char = { level = 25 } })
	local q = pickQuests(ns)
	local W = H.world()
	W.log = { { questID = q.obj[1], title = "obj one", complete = false }, { questID = q.obj[2], title = "obj two", complete = false },
		{ questID = q.obj[3], title = "obj three", complete = true } }
	local oc = ns.Registry.Quest(q.obj[1]).objCoords[1]      -- stand at the first quest's objective area
	W.loc.map, W.loc.x, W.loc.y = oc.map, oc.x, oc.y
	return ns
end)
scenario("real data, quest log with a prerequisite chain", function()
	local ns = boot({ char = { level = 25 } })
	local q = pickQuests(ns)
	local W = H.world()
	for _, id in ipairs(q.prereq) do
		local v = ns.Registry.Quest(id)
		for _, p in ipairs(v.prereq) do W.completed[p] = true end
	end
	return ns
end)
scenario("synthetic data, hub, distance, other continent, objective coordinates", function()
	local ns = boot({ char = { level = 10 }, synthetic = true, loc = { map = 9001, x = 0.1, y = 0.1 } })
	H.attPack(ns, {
		{ id = 1, name = "A", map = 9001, x = 0.12, y = 0.1, lvl = 1 },
		{ id = 2, name = "B", map = 9001, x = 0.13, y = 0.11, lvl = 5 },
		{ id = 3, name = "B", map = 9001, x = 0.9, y = 0.9, lvl = 9 },       -- same name as 2, different quest
		{ id = 4, name = "C", map = 9002, x = 0.2, y = 0.2, lvl = 8 },
		{ id = 5, name = "D", map = 9003, x = 0.2, y = 0.2, lvl = 8 },
		{ id = 6, name = "E", map = 9001, x = 0.5, y = 0.5, lvl = 4, sourceQuest = 1 },
	}, nil)
	local W = H.world()
	W.log = { { questID = 2, title = "B", complete = true }, { questID = 3, title = "B", complete = false } }
	return ns
end)

scenario("synthetic data, requirements, objective coordinates, observed overlay, pins, skips, same-name quests", function()
	local ns = boot({ char = { level = 12, class = "Warrior", classToken = "WARRIOR", race = "Orc", raceToken = "Orc", faction = "Horde" }, synthetic = true, loc = { map = 9001, x = 0.1, y = 0.1 } })
	H.attPack(ns, {
		{ id = 11, name = "Dup", map = 9001, x = 0.12, y = 0.10, req = 1, level = 3, giverNpc = 500, giverName = "Giver A", objectives = { "Kill five things" },
			objCoords = { { map = 9001, x = 0.3, y = 0.3 }, { map = 9001, x = 0.31, y = 0.32 } } },
		{ id = 12, name = "Dup", map = 9001, x = 0.8, y = 0.8, req = 1, level = 3 },
		{ id = 13, name = "Gate", map = 9001, x = 0.2, y = 0.2, req = 20 },
		{ id = 14, name = "Chain two", map = 9001, x = 0.22, y = 0.2, prereq = { 11 } },
		{ id = 15, name = "Alliance only", map = 9001, x = 0.2, y = 0.25, faction = "Alliance" },
		{ id = 16, name = "Orc only", map = 9001, x = 0.25, y = 0.25, races = { "ORC" } },
		{ id = 17, name = "Mage only", map = 9001, x = 0.25, y = 0.3, classes = { "MAGE" } },
		{ id = 18, name = "Objective area", map = 9002, x = 0.5, y = 0.5, objCoords = { { map = 9002, x = 0.6, y = 0.6 } } },
	}, nil)
	ForeverCodex.RegisterPack("quests", "observed:test", {
		meta = { src = "observed", verified = true, priority = 100, label = "test observed" }, zones = {},
		quests = { [11] = { id = 11, name = "Dup (seen)", level = 4 }, [19] = { id = 19, name = "Seen only", level = 2, pos = { map = 9001, x = 0.4, y = 0.4 } } },
	})
	local W = H.world()
	W.log = { { questID = 11, title = "Dup", complete = false }, { questID = 18, title = "Objective area", complete = true }, { questID = 77, title = "Unknown to data", complete = false } }
	W.completed[12] = true
	ns.Prefs.Skip("Q:16"); ns.Prefs.Skip("QT:11")
	ns.Prefs.Add(17); ns.Prefs.Add(20)
	return ns
end)
scenario("synthetic data, in-progress quest with no objective coordinates and a completed prerequisite chain", function()
	local ns = boot({ char = { level = 8 }, synthetic = true, loc = { map = 9001, x = 0.5, y = 0.5 } })
	H.attPack(ns, {
		{ id = 21, name = "First", map = 9001, x = 0.5, y = 0.52 },
		{ id = 22, name = "Second", map = 9001, x = 0.52, y = 0.5, prereq = { 21 } },
		{ id = 23, name = "Third", map = 9001, x = 0.9, y = 0.1, prereq = { 21, 22 } },
	}, nil)
	local W = H.world()
	W.completed[21] = true
	W.log = { { questID = 22, title = "Second", complete = false } }
	return ns
end)

local function runScenario(sc)
	local ns = sc.fn()
	ns.State.SetPlanner(false)     -- the golden file pins the LEGACY engine path (Phase 2 keeps it as the compatibility path)
	ns.State.Recompute()
	return snapshot(ns.State.plan), ns
end

local function allSnapshots()
	local out = {}
	for _, sc in ipairs(scenarios) do
		local snap, ns = runScenario(sc)
		out[#out + 1] = "#### " .. sc.name .. "\n" .. snap
		assert(#ns.errors == 0, "scenario raised a caught error: " .. tostring(ns.errors[1]))
	end
	return table.concat(out, "\n")
end

-- ---------------------------------------------------------------- A. behaviour neutrality

section("contract A: the engine's decisions are unchanged (golden snapshot, legacy fields only)")
do
	local text = allSnapshots()
	if os.getenv("CODEX_WRITE_GOLDEN") == "1" then
		local f = assert(io.open(goldenPath, "wb"))
		f:write(text, "\n")
		f:close()
		print("  (golden file written: " .. goldenPath .. ", " .. #text .. " bytes, " .. #scenarios .. " scenarios)")
	else
		local f = io.open(goldenPath, "rb")
		check(f ~= nil, "golden file exists (" .. goldenPath .. ")")
		if f then
			local golden = f:read("*a"):gsub("\n$", "")
			f:close()
			local same = golden == text
			if not same then
				-- locate the first differing line to make the failure actionable
				local gl, tl = {}, {}
				for l in (golden .. "\n"):gmatch("([^\n]*)\n") do gl[#gl + 1] = l end
				for l in (text .. "\n"):gmatch("([^\n]*)\n") do tl[#tl + 1] = l end
				for i = 1, math.max(#gl, #tl) do
					if gl[i] ~= tl[i] then
						print("  first difference at line " .. i .. ":\n    golden: " .. tostring(gl[i]):sub(1, 300) .. "\n    now:    " .. tostring(tl[i]):sub(1, 300))
						break
					end
				end
			end
			check(same, "all " .. #scenarios .. " scenarios produce byte-identical plans to the pre-migration engine")
		end
	end
end

-- ================================================================ B. the structured contract

local function fakeCtx(o)
	o = o or {}
	local completed = o.completed or {}
	return {
		char = o.char or { level = 10, faction = "Horde", raceKey = "ORC", classToken = "WARRIOR" },
		log = o.log or {}, logAvailable = o.logAvailable ~= false,
		isCompleted = function(id) return completed[id] == true end,
	}
end

local function byId(list, id)
	for _, a in ipairs(list) do if a.id == id then return a end end
	return nil
end

local function allActions(ns)
	local ctx = ns.Context.Build()
	local c = ns.Engine.Candidates(ctx)
	local all = {}
	for _, l in ipairs({ c.candidates, c.inProgress, c.hints }) do for _, a in ipairs(l) do all[#all + 1] = a end end
	return all, ctx, c
end

--- Serialises ONLY the contract fields of an action (for the immutability check).
local CONTRACT_FIELDS = { "contract", "ref", "state", "stateWhy", "skip", "targets", "requirements", "completion", "objectiveState", "optional", "prov", "evidence" }
local function contractText(a)
	local t = {}
	for _, f in ipairs(CONTRACT_FIELDS) do t[f] = a[f] end
	return ser(t)
end

local function synthetic(level, race)
	local ns = boot({ char = { level = level or 12, class = "Warrior", classToken = "WARRIOR", race = race or "Orc", raceToken = race or "Orc", faction = "Horde" },
		synthetic = true, loc = { map = 9001, x = 0.1, y = 0.1 } })
	return ns
end

local function problems(list)
	local out = {}
	for _, a in ipairs(list) do for _, p in ipairs(ns_Contract.Validate(a)) do out[#out + 1] = p end end
	return out
end

-- ---------------------------------------------------------------- the contract exists and is wired in

section("contract: wiring (the legacy path is intact; navigation / markers / quest map are absent)")
do
	local ns = boot({ char = { level = 25 } })
	check(type(ns.Contract) == "table" and ns.Contract.VERSION == 1, "ns.Contract is loaded")
	ns_Contract = ns.Contract
	local toc = H.readFile(H.addonDir .. "/ForeverCodex.toc")
	local iC, iQ, iP = toc:find("Contract.lua", 1, true), toc:find("Providers\\Quest.lua", 1, true), toc:find("Preferences.lua", 1, true)
	check(iC and iQ and iP and iC < iQ and iC < iP, "Contract.lua loads before Preferences and the providers")
	ns.State.SetPlanner(false)
	ns.State.Recompute()
	local keys = {}
	for k in pairs(ns.State.plan) do keys[#keys + 1] = k end
	table.sort(keys)
	-- (routeMap is nil with route zone "auto", and a nil value is not a key)
	check(table.concat(keys, ",") == "inProgress,nearby,next,player,routeZone,sequence,stats,strategy,upcoming,warnings",
		"legacy mode: the plan has exactly the legacy keys: " .. table.concat(keys, ","))
	check(ns.State.plan.now == nil and ns.State.plan.alsoDo == nil and ns.State.plan.thenAction == nil, "legacy mode: no NOW / ALSO DO / THEN")
	-- (Phase 3 added Navigation and Markers as CONSUMERS of the plan; the Planner still depends on neither: see planner_tests.lua)
	check(ns.QuestMap == nil, "no quest map module yet")
	check(#ns.errors == 0, "no caught errors")
end

-- ---------------------------------------------------------------- Engine stage 1 is separable and pure

section("contract: Engine.Candidates is reusable and does no scoring")
do
	local ns = boot({ char = { level = 25 } })
	local all, ctx, c = allActions(ns)
	check(type(c.env) == "table" and #c.candidates > 0 and type(c.inProgress) == "table" and type(c.hints) == "table", "Candidates returns env, candidates, inProgress, hints")
	local scored = 0
	for _, a in ipairs(all) do if a._score ~= nil or a._static ~= nil or a._dist ~= nil then scored = scored + 1 end end
	check(scored == 0, "no action carries a score, static score or distance after stage 1")
	local hintOk = #c.hints > 0
	for _, a in ipairs(c.hints) do if not a.hereOnly or a.type ~= "FLIGHT" then hintOk = false end end
	check(hintOk, "hints are the here-only flight actions")
	local plan = ns.Engine.Compute(ns.Context.Build())
	check(plan.stats.candidates == #c.candidates, "Compute is stage 1 plus the existing policy stages (same candidate count)")
	check(#ns.errors == 0, "no caught errors")
end

-- ---------------------------------------------------------------- identity

section("contract: action identity (quest ID, never name)")
do
	local ns = synthetic(12)
	H.attPack(ns, {
		{ id = 31, name = "Same name", map = 9001, x = 0.12, y = 0.1 },
		{ id = 32, name = "Same name", map = 9001, x = 0.8, y = 0.8 },
	}, nil)
	local all = allActions(ns)
	local a31, a32 = byId(all, "Q:31:ACCEPT"), byId(all, "Q:32:ACCEPT")
	check(a31 and a32 and a31.title == a32.title, "two different quests share one display name")
	check(a31.ref.kind == "quest" and a31.ref.id == 31 and a32.ref.id == 32, "each carries its own quest ID in ref")
	check(a31.completion.id == 31 and a32.completion.id == 32 and a31.completion.reaches == "ACCEPTED", "completion is tied to the quest ID")
	check(a31.id ~= a32.id, "action ids differ")
	H.world().completed[32] = true
	local all2 = allActions(ns)
	check(byId(all2, "Q:31:ACCEPT") ~= nil and byId(all2, "Q:32:ACCEPT") == nil, "completing 32 removes only 32: 31 (same name) stays actionable")
	ns_Contract = ns.Contract
	local st = ns.Contract.QuestState(32, ns.Registry.Quest(32), ns.Context.Build())
	check(st.state == "COMPLETED", "32 classifies COMPLETED by ID")
	check(ns.Contract.QuestState(31, ns.Registry.Quest(31), ns.Context.Build()).state == "AVAILABLE", "31 classifies AVAILABLE by ID")
	check(#problems(all2) == 0, "all actions validate")
end

section("contract: non-quest actions use the same shape")
do
	local ns = boot({ char = { level = 25 } })
	local all = allActions(ns)
	local fp
	for _, a in ipairs(all) do if a.type == "FLIGHT" then fp = a break end end
	check(fp ~= nil, "a flight action exists in the real data")
	check(fp.ref.kind == "flightNode" and type(fp.ref.id) == "number" and fp.id == "FP:" .. fp.ref.id, "flight action is identified by the node ID")
	check(fp.state == "UNKNOWN" and fp.stateWhy == "DISCOVERY_UNDETECTABLE", "discovery state is UNKNOWN, never claimed available (taxi APIs unproven)")
	check(fp.optional == true and fp.completion == nil, "flight discovery is optional and has no completion signal")
	local t = fp.targets[1]
	check(t.role == "SERVICE" and t.service == "FLIGHT" and t.where.status == "known", "a SERVICE target at a known ATT location")
	check(t.prov.src == "att" and t.prov.verified == false, "the ATT provenance is kept, not verified")
	check(#problems(all) == 0, "every real-data action validates (" .. #all .. " actions)")
end

-- ---------------------------------------------------------------- quest states

section("contract: quest states")
do
	local ns = boot({ char = { level = 25 } })
	local K = ns.Contract
	ns_Contract = K
	local function view(o) local v = { id = 1, prov = {} }; for k, val in pairs(o or {}) do v[k] = val end; return v end
	local st = function(ctx, v, id) return K.QuestState(id or 1, v, ctx) end
	check(st(fakeCtx(), view()).state == "AVAILABLE", "available: not in the log, nothing blocks it")
	check(st(fakeCtx({ log = { [1] = { id = 1, complete = false } } }), view()).state == "ACTIVE", "active: in the log, objectives not done")
	check(st(fakeCtx({ log = { [1] = { id = 1, complete = true } } }), view()).state == "READY", "ready: in the log, objectives done")
	check(st(fakeCtx({ completed = { [1] = true } }), view()).state == "COMPLETED", "completed: flagged completed")
	check(st(fakeCtx({ completed = { [1] = true }, log = {} }), view({ req = 99 })).state == "COMPLETED", "completed beats a stated requirement")
	local b = st(fakeCtx(), view({ req = 99 }))
	check(b.state == "BLOCKED" and b.why == "LEVEL_TOO_LOW", "blocked: level")
	b = st(fakeCtx(), view({ prereq = { 5, 6 } }))
	check(b.state == "BLOCKED" and b.why == "PREREQ_MISSING", "blocked: no prerequisite completed")
	check(st(fakeCtx({ completed = { [6] = true } }), view({ prereq = { 5, 6 } })).state == "AVAILABLE", "a prerequisite is ANY-OF (the data cannot say otherwise)")
	check(st(fakeCtx(), view({ faction = "Alliance" })).why == "FACTION", "blocked: faction")
	check(st(fakeCtx(), view({ races = { "TROLL" } })).why == "RACE", "blocked: race")
	check(st(fakeCtx(), view({ classes = { "MAGE" } })).why == "CLASS", "blocked: class")
	check(st(fakeCtx(), view({ faction = "Alliance", req = 99, prereq = { 5 } })).why == "FACTION", "when several requirements fail the reason follows the eligibility order")
	local u = st(fakeCtx(), nil)
	check(u.state == "UNKNOWN" and u.why == "NO_DATA", "unknown: no data and not in the log")
	u = st(fakeCtx({ logAvailable = false }), view())
	check(u.state == "UNKNOWN" and u.why == "LOG_UNAVAILABLE", "unknown: the quest log cannot be read, so available vs active is not claimed")
	check(st(fakeCtx({ log = { [1] = { id = 1, complete = false } } }), nil).state == "ACTIVE", "a quest in the log is ACTIVE even when no pack knows it")
	-- requirement results are tri-state
	local reqs = K.QuestRequirements(view({ req = 5, faction = "Horde" }), fakeCtx({ char = { level = nil, faction = nil } }))
	local allNil = true
	for _, r in ipairs(reqs) do if r.result ~= nil then allNil = false end end
	check(#reqs == 2 and allNil, "a requirement that cannot be evaluated is nil (unknown), not false or true")
	reqs = K.QuestRequirements(view({ req = 5 }), fakeCtx({ char = { level = 3 } }))
	check(reqs[1].result == false, "level 3 < required 5 is false (not nil)")
	-- the veto is separate from the game state
	check(K.Effective("AVAILABLE", true) == "SKIPPED" and K.Effective("ACTIVE", true) == "SKIPPED" and K.Effective("READY", true) == "SKIPPED", "skipped: the veto turns a plannable state into SKIPPED")
	check(K.Effective("COMPLETED", true) == "COMPLETED" and K.Effective("BLOCKED", true) == "BLOCKED" and K.Effective("UNKNOWN", true) == "UNKNOWN", "a veto never hides a completed, blocked or unknown state")
	check(K.Plannable("AVAILABLE", false) and K.Plannable("ACTIVE", false) and K.Plannable("READY", false), "available / active / ready are plannable")
	check(not K.Plannable("COMPLETED", false) and not K.Plannable("BLOCKED", false) and not K.Plannable("UNKNOWN", false) and not K.Plannable("READY", true), "completed / blocked / unknown / skipped are not")
end

section("contract: states carried by real provider output")
do
	local ns = synthetic(12)
	H.attPack(ns, {
		{ id = 41, name = "Open", map = 9001, x = 0.12, y = 0.1 },
		{ id = 42, name = "In log", map = 9001, x = 0.13, y = 0.1, objCoords = { { map = 9001, x = 0.4, y = 0.4 } } },
		{ id = 43, name = "Done", map = 9001, x = 0.14, y = 0.1 },
		{ id = 44, name = "Gated", map = 9001, x = 0.15, y = 0.1, req = 40 },
	}, nil)
	local W = H.world()
	W.log = { { questID = 42, title = "In log", complete = false }, { questID = 43, title = "Done", complete = true } }
	ns.Prefs.Add(44)
	local all = allActions(ns)
	check(byId(all, "Q:41:ACCEPT").state == "AVAILABLE", "ACCEPT of an open quest: AVAILABLE")
	check(byId(all, "Q:42:OBJECTIVE").state == "ACTIVE", "OBJECTIVE of a logged quest: ACTIVE")
	check(byId(all, "Q:43:TURN_IN").state == "READY", "TURN_IN of a finished quest: READY")
	local pinned = byId(all, "Q:44:ACCEPT")
	check(pinned and pinned.state == "BLOCKED" and pinned.stateWhy == "LEVEL_TOO_LOW", "a player-added quest the character cannot take yet is emitted (as today) and honestly marked BLOCKED")
	local unk = byId(all, "Q:999:ACCEPT")
	check(unk == nil, "(sanity) no stray action")
	ns.Prefs.Add(999)
	unk = byId(allActions(ns), "Q:999:ACCEPT")
	check(unk and unk.state == "UNKNOWN" and unk.stateWhy == "NO_DATA", "a player-added quest no pack knows is UNKNOWN")
	W.log[#W.log + 1] = { questID = 888, title = "Mystery", complete = true }
	local m = byId(allActions(ns), "Q:888:TURN_IN")
	check(m and m.state == "READY" and m.evidence == "unknown", "a logged quest no pack knows is READY, with unknown evidence")
	W.completed[41] = true
	check(byId(allActions(ns), "Q:41:ACCEPT") == nil, "a completed quest produces no action")
	check(#problems(allActions(ns)) == 0, "all validate")
end

-- ---------------------------------------------------------------- targets

section("contract: targets (location status, roles)")
do
	local ns = synthetic(12)
	H.attPack(ns, {
		{ id = 51, name = "Roles", map = 9001, x = 0.12, y = 0.1, giverNpc = 700, giverName = "Giver", turnIn = false, objCoords = { { map = 9001, x = 0.3, y = 0.3 }, { map = 9001, x = 0.31, y = 0.33 } } },
		{ id = 52, name = "No objective area", map = 9001, x = 0.14, y = 0.1 },
	}, nil)
	ForeverCodex.RegisterPack("quests", "observed:test", {
		meta = { src = "observed", verified = true, priority = 100, label = "test observed" }, zones = {},
		quests = { [53] = { id = 53, name = "Seen only", pos = { map = 9001, x = 0.4, y = 0.4 } } },
	})
	local W = H.world()
	-- ACCEPT: a GIVER target, known (ATT coordinate), unverified
	local all = allActions(ns)
	local acc = byId(all, "Q:51:ACCEPT")
	local g = acc.targets[1]
	check(#acc.targets == 1 and g.role == "GIVER", "ACCEPT has one GIVER target")
	check(g.where.status == "known" and g.where.kind == "exact" and #g.where.points == 1 and g.where.points[1].map == 9001, "ATT giver coordinate: known, exact, one point")
	check(g.prov.src == "att" and g.prov.verified == false, "ATT giver coordinate is not verified")
	check(g.entity.kind == "npc" and g.entity.id == 700 and g.entity.name == "Giver", "the giver entity keeps its NPC id and name")
	-- approximate: the observed layer only has a player position
	local seen = byId(all, "Q:53:ACCEPT")
	check(seen and seen.targets[1].where.status == "approx" and seen.targets[1].where.kind == "player_position", "an observed PLAYER position is approx, kind player_position")
	check(seen.targets[1].prov.src == "observed" and seen.targets[1].prov.verified == true, "and carries observed provenance")
	-- in the log, incomplete: OBJECTIVE target is an area with ALL known points
	W.log = { { questID = 51, title = "Roles", complete = false }, { questID = 52, title = "No objective area", complete = false } }
	all = allActions(ns)
	local obj = byId(all, "Q:51:OBJECTIVE")
	local o = obj.targets[1]
	check(#obj.targets == 1 and o.role == "OBJECTIVE" and o.where.status == "approx" and o.where.kind == "area", "OBJECTIVE target is an approximate area")
	check(#o.where.points == 2 and o.where.indexed == false, "multiple objective coordinates are kept as points, explicitly NOT tied to objective indexes")
	check(obj.target.x == 0.3 and obj.target.y == 0.3, "the legacy single target is still the first coordinate (engine input unchanged)")
	check(o.prov.src == "att" and o.prov.verified == false, "objective coordinates are ATT, unverified")
	-- no objective coordinates: unknown, with no coordinates at all
	local noObj
	for _, a in ipairs(select(3, allActions(ns)).candidates) do if a.id == "Q:52:OBJECTIVE" then noObj = a end end
	local u
	check(noObj == nil, "(engine) an OBJECTIVE with no location stays in inProgress, not in candidates")
	local ip
	for _, a in ipairs(select(3, allActions(ns)).inProgress) do if a.id == "Q:52:OBJECTIVE" then ip = a end end
	u = ip and ip.targets[1]
	check(u and u.role == "OBJECTIVE" and u.where.status == "unknown" and u.where.points == nil, "unknown location: status unknown, no points")
	check(u.entity.kind == "unknown" and u.prov.src == "unknown", "and unknown entity and provenance, nothing invented")
	-- ready: with no turn-in data (0.8.4) the giver's spot is NOT the hand-in place: the TURN_IN target is unknown and carries no coordinates, and no giver entity
	W.log[1].complete = true
	all = allActions(ns)
	local ti = byId(all, "Q:51:TURN_IN")
	local t = ti.targets[1]
	check(t.role == "TURN_IN" and t.where.status == "unknown" and t.where.points == nil and t.assumed ~= true, "no turn-in data: the hand-in location is UNKNOWN, not the giver's")
	check(t.entity.kind == "unknown", "and the giver is not named as the turn-in NPC")
	check(ti.evidence ~= "observed", "an unknown turn-in never yields 'observed' evidence")
	check(ti.target == nil and ti.noLocation == true, "the legacy target is gone: a reminder, never routed")
	check(#problems(all) == 0, "all validate")
end

section("contract: giver and turn-in as separate targets (the shape a future pack will fill)")
do
	local K = boot({ char = { level = 10 } }).Contract
	ns_Contract = K
	local giver = K.Target({ role = "GIVER", entity = { kind = "npc", id = 1, name = "Giver" }, where = K.Where("known", { { map = 1, x = 0.1, y = 0.1 } }, "exact"), prov = K.Prov("att") })
	local turnin = K.Target({ role = "TURN_IN", entity = { kind = "npc", id = 2, name = "Someone else" }, where = K.Where("known", { { map = 1, x = 0.8, y = 0.8 } }, "exact"), prov = K.Prov("observed") })
	local obj = K.Target({ role = "OBJECTIVE", entity = { kind = "object" }, where = K.Where("known", { { map = 1, x = 0.4, y = 0.4 } }, "exact"), prov = K.Prov("observed") })
	local a = { id = "Q:7:ACCEPT", type = "QUEST", kind = "ACCEPT" }
	K.Attach(a, { ref = { kind = "quest", id = 7 }, state = "AVAILABLE", skip = { logical = false, keys = {} }, targets = { giver, obj, turnin },
		requirements = {}, completion = { watch = "quest", id = 7, reaches = "TURNED_IN" } })
	check(#K.Validate(a) == 0, "an action with a giver, an objective and a different turn-in NPC validates")
	check(a.targets[1].entity.id ~= a.targets[3].entity.id and a.targets[1].where.points[1].x ~= a.targets[3].where.points[1].x, "giver and turn-in differ in entity and place")
	check(a.evidence == "mixed", "an ATT giver with observed objective and turn-in is 'mixed', not 'observed'")
	-- several objectives: two separate OBJECTIVE targets
	local a2 = { id = "Q:8:OBJECTIVE", type = "QUEST", kind = "OBJECTIVE" }
	K.Attach(a2, { ref = { kind = "quest", id = 8 }, state = "ACTIVE", skip = { logical = false, keys = {} }, targets = { obj, K.Target({ role = "OBJECTIVE", where = K.Where("unknown") }) },
		requirements = {}, completion = { watch = "quest", id = 8, reaches = "OBJECTIVES" } })
	check(#K.Validate(a2) == 0 and #a2.targets == 2, "multiple objective targets, one of them with an unknown location")
	check(K.Where("known", {}).status == "unknown" and K.Where("known", nil).points == nil, "a where with no points is unknown and carries none")
	check(K.FromLegacyTarget(nil, "GIVER").where.status == "unknown", "a missing legacy target becomes an explicit unknown target")
	local bad = K.Target({ role = "GIVER", where = { status = "unknown", points = { { map = 1, x = 0, y = 0 } } } })
	a.targets = { bad }
	check(#K.Validate(a) > 0, "the validator rejects an unknown location that carries coordinates")
end

-- ---------------------------------------------------------------- provenance

section("contract: provenance is carried and never upgraded")
do
	local K = boot({ char = { level = 10 } }).Contract
	ns_Contract = K
	check(K.Prov("observed").verified == true, "observed is verified")
	check(K.Prov("att").verified == false and K.Prov("estimated").verified == false and K.Prov("log").verified == false and K.Prov("unknown").verified == false, "att / estimated / log / unknown are never verified")
	local legacy = { map = 1, x = 0.1, y = 0.1, src = "att", verified = true }     -- a (wrongly) over-claimed legacy flag
	check(K.FromLegacyTarget(legacy, "GIVER").prov.verified == false, "a legacy verified=true on ATT data is not carried over")
	check(K.FromLegacyTarget({ map = 1, x = 0.1, y = 0.1, src = "estimated", verified = true }, "GIVER").prov.verified == false, "estimated stays unverified")
	check(K.FromLegacyTarget({ map = 1, x = 0.1, y = 0.1, src = "observed", verified = true }, "GIVER").prov.verified == true, "observed with a verified legacy flag stays verified")
	check(K.FromLegacyTarget({ map = 1, x = 0.1, y = 0.1, src = "observed", verified = false }, "GIVER").prov.verified == false, "observed with a false legacy flag is not promoted")
	local function ev(targets, reqs)
		return K.Evidence({ targets = targets, requirements = reqs or {} })
	end
	local function tgt(src, assumed) return K.Target({ role = "GIVER", where = K.Where("known", { { map = 1, x = 0, y = 0 } }), prov = K.Prov(src), assumed = assumed }) end
	check(ev({ tgt("observed") }) == "observed", "evidence: observed target")
	check(ev({ tgt("att") }) == "unverified", "evidence: ATT target")
	check(ev({ tgt("estimated") }) == "unverified", "evidence: estimated target")
	check(ev({ tgt("observed", true) }) == "unverified", "evidence: an assumed location is unverified even with an observed source")
	check(ev({ tgt("observed"), tgt("att") }) == "mixed", "evidence: observed + ATT is mixed")
	check(ev({ K.Target({ role = "GIVER" }) }) == "unknown" and ev({}) == "unknown", "evidence: no known input is unknown")
	check(ev({ tgt("observed") }, { { kind = "level", result = true, prov = K.Prov("att") } }) == "mixed", "evidence: an unverified requirement pulls an observed target down to mixed")
	check(ev({ tgt("observed") }, { { kind = "level", result = nil, prov = K.Prov("att") } }) == "observed", "evidence: an UNKNOWN requirement result is not an input")
	-- weakest link: adding any non-observed input never raises the label
	local rank = { unknown = 0, unverified = 1, mixed = 2, observed = 3 }
	local base = { tgt("observed"), tgt("observed") }
	local worst = true
	for _, extra in ipairs({ tgt("att"), tgt("estimated"), tgt("observed", true) }) do
		local with = { base[1], base[2], extra }
		if rank[ev(with)] > rank[ev(base)] then worst = false end
	end
	check(worst, "adding a non-observed input never makes the evidence stronger")
	-- the validator catches forged flags
	local a = { id = "FP:1", type = "FLIGHT" }
	K.Attach(a, { ref = { kind = "flightNode", id = 1 }, state = "UNKNOWN", targets = { { role = "SERVICE", where = K.Where("known", { { map = 1, x = 0, y = 0 } }), prov = { src = "att", verified = true } } } })
	check(#K.Validate(a) > 0, "the validator rejects verified=true on a non-observed source")
	a.targets[1].prov.verified = false
	a.evidence = "observed"
	check(#K.Validate(a) > 0, "the validator rejects a hand-set evidence label that does not match its inputs")
end

section("contract: provenance survives conversion from the real providers")
do
	local ns = boot({ char = { level = 25 } })
	local scenarioFns = { function() return ns end }
	local lost, checked, upgraded = 0, 0, 0
	local function scan(nsx)
		local all = allActions(nsx)
		for _, a in ipairs(all) do
			local t = a.targets and a.targets[1]
			if t and t.where.status ~= "unknown" and a.target then
				checked = checked + 1
				if t.prov.src ~= a.target.src then lost = lost + 1 end
				if t.prov.verified == true and not (a.target.verified == true) then upgraded = upgraded + 1 end
			end
			if a.evidence == "observed" and a.verified ~= true then upgraded = upgraded + 1 end
		end
	end
	scan(ns)
	local ns2 = boot({ char = { level = 12, race = "Orc", raceToken = "Orc" }, loc = { map = 1411, x = 0.5, y = 0.5 } })
	scan(ns2)
	check(checked > 100, "provenance compared on " .. checked .. " located targets from the real packs")
	check(lost == 0, "the contract target's source always equals the legacy target's source")
	check(upgraded == 0, "no action or target is more verified than its legacy counterpart")
	local atts, obs = 0, 0
	for _, a in ipairs(allActions(ns)) do if a.evidence == "unverified" then atts = atts + 1 elseif a.evidence == "observed" then obs = obs + 1 end end
	check(atts > 0, "ATT-derived actions are 'unverified' (" .. atts .. "), observed-only ones are separate (" .. obs .. ")")
end

-- ---------------------------------------------------------------- objective progress

section("contract: objective progress lives in quest-log state, never in a Target")
do
	local ns = synthetic(12)
	ns_Contract = ns.Contract
	H.attPack(ns, { { id = 61, name = "Counting", map = 9001, x = 0.12, y = 0.1, objCoords = { { map = 9001, x = 0.3, y = 0.3 } } } }, nil)
	local W = H.world()
	W.log = { { questID = 61, title = "Counting", complete = false } }
	W.objectives = { [61] = {
		{ text = "5/10 Scorpid Worker Tails", type = "item", finished = false, numFulfilled = 5, numRequired = 10 },
		{ text = "6/6 Training Weapons", type = "item", finished = true, numFulfilled = 6, numRequired = 6 },
	} }
	local all = allActions(ns)
	local a = byId(all, "Q:61:OBJECTIVE")
	local os = a.objectiveState
	check(os and os.known and os.summary == "partial" and #os.list == 2, "partial progress read from the quest log objectives")
	check(os.list[1].have == 5 and os.list[1].need == 10 and os.list[1].finished == false and os.list[2].finished == true, "5/10 and 6/6 are kept as counts")
	check(a.state == "ACTIVE", "a partially done quest is still ACTIVE")
	local clean = true
	for _, t in ipairs(a.targets) do
		if t.progress ~= nil or t.have ~= nil or t.need ~= nil or t.where.have ~= nil then clean = false end
	end
	check(clean, "no Target carries progress")
	check(#problems(all) == 0, "validates")
	check(a.target.x == 0.3, "progress changes nothing about the legacy target")
	-- every objective done, ready
	W.log[1].complete = true
	W.objectives[61][1].finished, W.objectives[61][1].numFulfilled = true, 10
	local ti = byId(allActions(ns), "Q:61:TURN_IN")
	check(ti.state == "READY" and ti.objectiveState.summary == "complete", "all objectives done: READY with a 'complete' summary")
	-- unreadable
	W.objectives = nil
	ti = byId(allActions(ns), "Q:61:TURN_IN")
	check(ti.objectiveState.known == false and ti.objectiveState.summary == "unknown" and ti.state == "READY", "objectives unreadable: progress is UNKNOWN; readiness still comes from the quest-log flag")
	_G.C_QuestLog.GetQuestObjectives = nil
	local okB = pcall(ns.Context.Build)
	check(okB and ns.Context.Build().log[61].objectives == nil, "no GetQuestObjectives API at all: no error, objectives nil")
	_G.C_QuestLog.GetQuestObjectives = function() error("boom") end
	local okC, c = pcall(ns.Context.Build)
	check(okC and c.log[61].objectives == nil, "GetQuestObjectives raising an error is contained")
	local K = ns.Contract
	check(K.ObjectiveState(nil).summary == "unknown" and K.ObjectiveState({}).summary == "unknown", "no / empty objective list is UNKNOWN, never 'complete'")
	check(K.ObjectiveState({ { text = "0/6  ", type = "monster", finished = false, numFulfilled = 0, numRequired = 6 } }).summary == "none", "0/6 with a blank name (transient, M8.9) is 'none'")
	check(K.ObjectiveState({ { text = "Enter the Dead Fields", type = "event", finished = false } }).summary == "none", "an event objective has no counts: finished only")
	check(K.ObjectiveState({ { text = "Enter the Dead Fields", type = "event", finished = true } }).summary == "complete", "and finished means complete")
	check(K.ObjectiveState({ { text = "a", finished = false, numFulfilled = 1, numRequired = 3 }, { text = "b", finished = false, numFulfilled = 0, numRequired = 2 } }).summary == "partial", "one objective started: partial")
end

-- ---------------------------------------------------------------- skip compatibility

section("contract: skip keeps working over the old saved keys; one logical state is possible")
do
	local ns = boot({ char = { level = 25 } })
	local K = ns.Contract
	local P = ns.Prefs
	P.Skip("Q:907"); P.Skip("QT:200"); P.Skip("Q:300"); P.Skip("QT:300"); P.Skip("FP:25")
	check(P.QuestSkipState(907).logical and #P.QuestSkipState(907).keys == 1 and P.QuestSkipState(907).keys[1] == "Q:907", "Q:<id> alone is a skip")
	check(P.QuestSkipState(200).logical and P.QuestSkipState(200).keys[1] == "QT:200", "QT:<id> alone is a skip")
	check(P.QuestSkipState(300).logical and #P.QuestSkipState(300).keys == 2, "both keys are one logical skip with two keys")
	check(not P.QuestSkipState(1).logical and #P.QuestSkipState(1).keys == 0, "no key: not skipped")
	check(not P.QuestSkipState(25).logical, "a flight-node key is not a quest skip")
	local raw = { ["Q:907"] = true, ["QT:200"] = true, ["Q:300"] = true, ["QT:300"] = true, ["FP:25"] = true, ["Q:1"] = false }
	local before = ser(raw)
	local l = K.LogicalSkips(raw)
	check(l.quests[907] and l.quests[200] and l.quests[300] and not l.quests[1] and #l.other == 1 and l.other[1] == "FP:25", "LogicalSkips: one entry per quest ID, others kept apart, false ignored")
	local c = K.CollapseSkips(raw)
	check(c["Q:907"] and c["Q:200"] and c["Q:300"] and c["FP:25"] and not c["QT:200"] and not c["QT:300"], "CollapseSkips: one canonical Q:<id> key per quest, unrelated keys kept")
	check(ser(raw) == before, "the helpers never modify their input")
	local cleared = K.AddClearsSkip(raw, 300)
	check(not cleared["Q:300"] and not cleared["QT:300"] and cleared["Q:907"] and cleared["FP:25"], "Add clears both keys of that quest, nothing else")
	-- old SavedVariables
	local saved = ForeverCodexDB
	local snapshotKeys = table.concat(P.SkippedKeys(), ",")
	local ns2 = boot({ char = { level = 25 }, savedVars = saved })
	check(table.concat(ns2.Prefs.SkippedKeys(), ",") == snapshotKeys, "an existing saved skipped table loads unchanged (no migration is applied)")
	ns2.State.Recompute()
	check(table.concat(ns2.Prefs.SkippedKeys(), ",") == snapshotKeys, "and is unchanged after the engine ran")
	check(ns2.Prefs.QuestSkipState(300).logical, "old keys are read through the logical view")
	-- documented, unchanged legacy behaviour (a later phase makes Add clear BOTH keys)
	ns2.Prefs.Add(300)
	check(not ns2.Prefs.IsSkipped("Q:300") and ns2.Prefs.IsSkipped("QT:300"), "(legacy, unchanged in Phase 1) Add clears only Q:<id>")
end

section("contract: the action reports the logical skip without changing what the engine does")
do
	local ns = synthetic(12)
	H.attPack(ns, { { id = 71, name = "Skippable", map = 9001, x = 0.12, y = 0.1 } }, nil)
	ns.Prefs.Skip("QT:71")                       -- the in-progress key: the legacy ACCEPT path ignores it
	local a = byId(allActions(ns), "Q:71:ACCEPT")
	check(a ~= nil, "legacy behaviour: an ACCEPT is still offered when only QT:<id> is set")
	check(a.skip.logical == true and a.skip.keys[1] == "QT:71", "the contract reports the quest as skipped (the one logical state)")
	ns.Prefs.Skip("Q:71")
	check(byId(allActions(ns), "Q:71:ACCEPT") == nil, "Q:<id> hides the ACCEPT, as before")
end

-- ---------------------------------------------------------------- immutability

section("contract: the engine never changes an action's contract fields")
do
	local ns = boot({ char = { level = 25 } })
	local q = pickQuests(ns)
	local W = H.world()
	W.log = { { questID = q.obj[1], title = "x", complete = false }, { questID = q.loc[1], title = "y", complete = true } }
	W.objectives = { [q.obj[1]] = { { text = "1/3 a", type = "monster", finished = false, numFulfilled = 1, numRequired = 3 } } }
	local fresh = {}
	for _, a in ipairs(allActions(ns)) do fresh[a.id] = contractText(a) end
	local ctx = ns.Context.Build()
	local plan = ns.Engine.Compute(ctx)
	local checked, changed = 0, 0
	for _, l in ipairs({ plan.sequence, plan.nearby, plan.inProgress }) do
		for _, a in ipairs(l) do
			if a.type ~= "TRAVEL" then
				checked = checked + 1
				if fresh[a.id] ~= contractText(a) then changed = changed + 1 end
			end
		end
	end
	check(checked > 5 and changed == 0, "contract fields identical before and after scoring, chaining and nearby (" .. checked .. " actions)")
	local travel = 0
	for _, a in ipairs(plan.sequence) do if a.type == "TRAVEL" then travel = travel + 1; if a.contract ~= nil then changed = changed + 1 end end end
	check(travel > 0 and changed == 0, "(documented) engine-made TRAVEL steps carry no contract: transit is the Planner's concern")
end

-- ---------------------------------------------------------------- Context

section("contract: Context reads quest-log objectives without changing anything else")
do
	local ns = boot({ char = { level = 25 } })
	local W = H.world()
	W.log = { { questID = 5, title = "t", complete = false } }
	W.objectives = { [5] = { { text = "2/4 x", type = "item", finished = false, numFulfilled = 2, numRequired = 4 } } }
	local c = ns.Context.Build()
	check(c.log[5].objectives and c.log[5].objectives[1].numFulfilled == 2, "ctx.log[id].objectives holds the client's objective list")
	check(c.log[5].id == 5 and c.log[5].title == "t" and c.log[5].complete == false, "id, title and complete are as before")
	W.objectives = nil
	check(ns.Context.Build().log[5].objectives == nil, "unknown quest objectives: nil, not an empty list")
	check(W.questCalls == 0, "no quest state was changed")
end

-- ---------------------------------------------------------------- every provider output validates, across scenarios

section("contract: every action from every golden scenario satisfies the contract")
do
	local total, bad = 0, {}
	for _, sc in ipairs(scenarios) do
		local ns = sc.fn()
		ns_Contract = ns.Contract
		local all = allActions(ns)
		for _, a in ipairs(all) do
			total = total + 1
			for _, p in ipairs(ns.Contract.Validate(a)) do bad[#bad + 1] = sc.name .. " :: " .. p end
		end
	end
	check(total > 500 and #bad == 0, string.format("%d actions across %d scenarios validate%s", total, #scenarios, #bad > 0 and (": " .. bad[1]) or ""))
end
