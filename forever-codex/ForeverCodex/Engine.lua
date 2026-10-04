-- ForeverCodex.Engine: "what should this character do next?"
--
-- Stateless: Engine.Compute(ctx) -> plan. It reads a Context (character, location, quest log, completions, the
-- player's choices) and asks every registered, enabled provider for candidate ACTIONS. It then filters, scores
-- with the active route STYLE, and builds a short sequence by walking the map greedily from where the character
-- stands. Because it is recomputed from the world state, the player's choices (route zone, style, system toggles,
-- skips, added quests) simply change its inputs: nothing is "locked in", everything recalculates.
--
-- Actions, not quests: the engine only knows ACTIONS (type, kind, target, score). Quests are one provider. Travel
-- is derived here. Flight hints, and later trainers / professions / camps / dungeons / pets, plug in as providers.
--
-- Hardcore: when the character is flagged Hardcore, RESPAWN_SKIP actions are dropped here regardless of which
-- provider produced them, so an intentional-death shortcut can never be recommended to a Hardcore character.
--
-- Determinism: no randomness, stable sorts, explicit tie-breaks by action id.

local addonName, ns = ...
local R = ns.Registry

local E = {}
ns.Engine = E

-- The normal quest log holds 40 quests on WoW Forever (stated by the project owner; not probed from the client). A planner INPUT, not a measured value.
E.QUEST_LOG_MAX = 40
local DIFFERENT_CONTINENT = 5000   -- yards charged when two points cannot be compared directly
local CHAIN_LENGTH = 8             -- quest-ish stops planned ahead
local TRAVEL_MIN = 150             -- yards before a TRAVEL step is inserted
local NEARBY_LIMIT = 5
local CLUSTER_CELL = 40            -- map is bucketed 40 x 40 for hub detection (~100-150 yards per cell)

-- ---------------------------------------------------------------- geometry

local function worldOf(ctx, p)
	if p.world ~= nil then
		return p.world or nil
	end
	local w = ctx.worldOf(p.map, p.x, p.y)
	p.world = w or false
	return w
end

--- Yards between two { map, x, y } points. Same continent: world distance. Same map without a world conversion:
-- a rough fraction-of-map estimate. Otherwise a fixed large number.
function E.Distance(ctx, a, b)
	if not a or not b then return nil end
	local wa, wb = worldOf(ctx, a), worldOf(ctx, b)
	if wa and wb then
		if wa.continent ~= wb.continent then return DIFFERENT_CONTINENT end
		local dx, dy = wa.x - wb.x, wa.y - wb.y
		return math.sqrt(dx * dx + dy * dy)
	end
	if a.map == b.map and a.x and b.x then
		local dx, dy = (a.x - b.x) * 3000, (a.y - b.y) * 3000
		return math.sqrt(dx * dx + dy * dy)
	end
	return DIFFERENT_CONTINENT
end

-- ---------------------------------------------------------------- scoring

local function levelFit(a, lvl, w)
	if not w.levelFit or not lvl or a.kind ~= "ACCEPT" then return 0 end
	local fit = a.level or a.reqLevel
	if not fit then return 0 end
	local gap = lvl - fit
	if gap < 0 then gap = 0 end
	local v
	if gap <= 6 then
		v = 15 - gap
	elseif gap <= 12 then
		v = 9 - (gap - 6) * 2.5
	else
		v = -6 - (gap - 12) * 3
	end
	return v * (w.fitMul or 1)
end

local function baseScore(a, w)
	if a.kind == "TURN_IN" and not a.target then return w.base.TURN_IN_NOLOC end
	return w.base[a.kind] or 0
end

--- Position-independent part of the score.
local function staticScore(a, ctx, w, clusterCount)
	local s = baseScore(a, w)
	if a.pinned then s = s + (a.target and 500 or 200) end
	s = s + levelFit(a, ctx.char.level, w)
	if a.breadcrumb then s = s + (w.breadcrumb or 0) end
	a._cluster = 0
	if a.kind == "ACCEPT" and a.target and (w.cluster or 0) > 0 then
		local n = (clusterCount(a) or 1) - 1
		if n > w.clusterCap then n = w.clusterCap end
		if n > 0 then
			a._cluster = n
			s = s + n * w.cluster
		end
	end
	return s
end

--- Full score from a position (nil = unknown position: distance terms are skipped).
local function score(a, pos, env, ctx)
	local w = env.w
	local s = a._static
	a._dist = nil
	local t = a.target
	if t then
		if pos then
			local d = E.Distance(ctx, pos, t)
			a._dist = d
			s = s - math.min(w.distCap, d / w.distScale)
		end
		if env.routeMap then
			if t.map == env.routeMap then s = s + (w.routeZoneBonus or w.zoneBonus) end
		elseif pos and pos.map and t.map == pos.map then
			s = s + w.zoneBonus * 0.6
		end
	end
	return s
end

local function better(a, sa, b, sb)
	if sa ~= sb then return sa > sb end
	return a.id < b.id
end

local function explain(a, env, ctx)
	local r = {}
	local lvl = ctx.char.level
	if a.pinned then r[#r + 1] = "You added this" end
	if a.kind == "TURN_IN" then r[#r + 1] = "Quest complete: turn it in" end
	if a.kind == "OBJECTIVE" then r[#r + 1] = "Already in your quest log" end
	if a.kind == "ACCEPT" and lvl then
		local fit = a.level or a.reqLevel
		if fit then
			local gap = lvl - fit
			if gap <= 6 then r[#r + 1] = string.format("Fits your level (%s %d, you are %d)", a.level and "level" or "requires", fit, lvl) end
		end
	end
	if (a._cluster or 0) >= 2 then r[#r + 1] = string.format("Quest hub: %d other quest givers close by", a._cluster) end
	local t = a.target
	if t then
		if env.routeMap and t.map == env.routeMap then
			r[#r + 1] = "In your route zone"
		elseif not env.routeMap and env.player and env.player.map == t.map then
			r[#r + 1] = "In the zone you are in"
		end
		if a._dist and a._dist < DIFFERENT_CONTINENT then
			r[#r + 1] = string.format("About %d yards away", math.floor(a._dist + 0.5))
		elseif a._dist then
			r[#r + 1] = "In another area"
		end
	end
	if #r == 0 then r[1] = "Best available option" end
	return r
end

-- ---------------------------------------------------------------- compute

local function newStats()
	return { filtered = {}, byType = {}, candidates = 0, providers = {} }
end

local function collect(ctx, env)
	local prefs = ctx.prefs
	local all = {}
	for _, prov in ipairs(R.Providers()) do
		local on = prov.generate and not prov.planned and (not prov.system or prefs.systems[prov.system] == true)
		if on then
			local ok, list = pcall(prov.generate, ctx, env)
			if ok and type(list) == "table" then
				if #list > 0 or not prov.quiet then env.stats.providers[#env.stats.providers + 1] = { key = prov.key, count = #list } end   -- (a `quiet` provider with nothing to say is not listed)
				for _, a in ipairs(list) do all[#all + 1] = a end
			else
				ns.RecordError("provider " .. tostring(prov.key), list)
				env.warnings[#env.warnings + 1] = "provider '" .. tostring(prov.key) .. "' failed (see /codex diag)"
			end
		end
	end
	return all
end

local function bump(stats, key)
	stats.filtered[key] = (stats.filtered[key] or 0) + 1
end

--- STAGE 1 (reusable, no scoring): environment + candidate collection + global filters.
-- Returns { env, candidates, inProgress, hints }:
--   candidates  actions that can be placed on the map (a target) and go on to scoring
--   inProgress  OBJECTIVE actions with no location: reminders, never routed
--   hints       "here only" actions (flight hints): never part of the route, only of the nearby list
-- Order, counts, filters and warnings are exactly what Compute has always produced; Compute now calls this.
function E.Candidates(ctx)
	local prefs = ctx.prefs
	local strategy = R.Strategy(prefs.style)
	if not strategy or strategy.active == false then strategy = R.Strategy("efficient") end
	local env = { strategy = strategy, w = strategy.w, stats = newStats(), warnings = {}, hardcore = prefs.hardcore == true }

	if ctx.loc.available then
		env.player = { map = ctx.loc.map, x = ctx.loc.x, y = ctx.loc.y, world = ctx.loc.world or false }
	else
		env.warnings[#env.warnings + 1] = "Your location is unavailable here, so distance is ignored."
	end
	if prefs.routeZone ~= "auto" then
		local z = R.ZoneByKey(prefs.routeZone)
		if z then env.routeMap, env.routeZone = z.map, z end
	end
	if #ctx.char.missing > 0 then
		env.warnings[#env.warnings + 1] = "Not available on this client: " .. table.concat(ctx.char.missing, ", ")
	end
	if not ctx.logAvailable then
		env.warnings[#env.warnings + 1] = "Quest log is unavailable, so quest progress is unknown."
	end
	if R.QuestIds()[1] == nil then
		env.warnings[#env.warnings + 1] = "No quest data packs are loaded."
	end

	-- the normal quest log holds at most QUEST_LOG_MAX quests, finished-but-not-handed-in ones included (so a ready hand-in also holds a slot).
	-- Quest-starting ITEMS are separate: they live in the bags until used. Only what the quest log really reports is counted.
	env.questLog = { used = ctx.logAvailable and ctx.logCount or nil, max = E.QUEST_LOG_MAX }
	if env.questLog.used then
		env.questLog.free = math.max(0, env.questLog.max - env.questLog.used)
		env.questLog.full = env.questLog.used >= env.questLog.max
	end

	-- 1. collect from providers, 2. global filters
	local all = collect(ctx, env)
	local cands, inProgress, hints = {}, {}, {}
	for _, a in ipairs(all) do
		env.stats.byType[a.type] = (env.stats.byType[a.type] or 0) + 1
		if a.type == "RESPAWN_SKIP" and env.hardcore then
			bump(env.stats, "hardcore")
		elseif strategy.allow and not strategy.allow[a.type] then
			bump(env.stats, "style")
		elseif prefs.skipped[a.skipKey] and not a.pinned then
			bump(env.stats, "skipped")
		elseif env.questLog.full and a.type == "QUEST" and a.kind == "ACCEPT" then
			bump(env.stats, "logFull")                    -- a full quest log cannot take another quest: never recommend one
		elseif a.hereOnly then
			hints[#hints + 1] = a
		elseif a.kind == "OBJECTIVE" and not a.target then
			inProgress[#inProgress + 1] = a
		else
			cands[#cands + 1] = a
		end
	end
	env.stats.candidates = #cands
	return { env = env, candidates = cands, inProgress = inProgress, hints = hints }
end

--- STAGE 2 (existing urgency policy, unchanged): position-independent scores, with hub detection through a coarse grid.
local function applyStaticScores(cands, ctx, env)
	local grid = {}
	local function cell(a) return a.target.map .. ":" .. math.floor(a.target.x * CLUSTER_CELL) .. ":" .. math.floor(a.target.y * CLUSTER_CELL) end
	for _, a in ipairs(cands) do
		if a.kind == "ACCEPT" and a.target then
			local cx, cy = math.floor(a.target.x * CLUSTER_CELL), math.floor(a.target.y * CLUSTER_CELL)
			a._cx, a._cy = cx, cy
			local key = a.target.map .. ":" .. cx .. ":" .. cy
			grid[key] = (grid[key] or 0) + 1
		end
	end
	local function clusterCount(a)
		local n = 0
		for dx = -1, 1 do
			for dy = -1, 1 do
				n = n + (grid[a.target.map .. ":" .. (a._cx + dx) .. ":" .. (a._cy + dy)] or 0)
			end
		end
		return n
	end
	for _, a in ipairs(cands) do a._static = staticScore(a, ctx, env.w, clusterCount) end
end

--- The TRAVEL step that gets you to `chosen` (d yards away). Shared by the greedy chain and the plan adapter.
function E.MakeTravel(chosen, d)
	return ns.Registry.NewAction({
		id = "T:" .. chosen.id, type = "TRAVEL", kind = "TRAVEL", forId = chosen.id, skipKey = chosen.skipKey,
		title = "Travel to " .. (chosen.target.label or "the next stop"), target = chosen.target, dist = d,
		src = chosen.src, verified = chosen.verified,
		lines = { (d >= DIFFERENT_CONTINENT and "That is in another area." or string.format("About %d yards away.", math.floor(d + 0.5))),
			"Then: " .. chosen.title },
		reasons = { "Needed to reach: " .. chosen.title },
	})
end

E.DIFFERENT_CONTINENT, E.TRAVEL_MIN = DIFFERENT_CONTINENT, TRAVEL_MIN
E.LevelFit = levelFit        -- per-action fact (level fit points), reused by the Planner

--- STAGE 3 (existing greedy chain, unchanged): walks the map from the character's position, inserting TRAVEL steps.
local function buildChain(cands, ctx, env)
	local pool = {}
	for i, a in ipairs(cands) do pool[i] = a end
	local seq, pos = {}, env.player
	local stops = 0
	while #pool > 0 and stops < CHAIN_LENGTH do
		local bestI, bestS
		for i, a in ipairs(pool) do
			local s = score(a, pos, env, ctx)
			a._score = s
			if not bestI or better(a, s, pool[bestI], bestS) then bestI, bestS = i, s end
		end
		local chosen = table.remove(pool, bestI)
		chosen._score = bestS
		-- recompute distance for the chosen action from the current simulated position
		local d = (pos and chosen.target) and E.Distance(ctx, pos, chosen.target) or nil
		chosen._dist = d
		chosen.reasons = explain(chosen, env, ctx)
		if chosen.target and pos and d and (d >= TRAVEL_MIN or d >= DIFFERENT_CONTINENT) then
			seq[#seq + 1] = E.MakeTravel(chosen, d)
		end
		seq[#seq + 1] = chosen
		stops = stops + 1
		if chosen.target then
			pos = { map = chosen.target.map, x = chosen.target.x, y = chosen.target.y, world = chosen.target.world }
		end
	end
	return seq
end

--- STAGE 4 (existing "while you're here" list, unchanged): anything close to where the character actually is,
-- from the SAME provider output.
local function buildNearby(cands, hints, seq, ctx, env)
	local prefs = ctx.prefs
	local nearby = {}
	if env.player then
		local radius = prefs.hereRadius or 200
		local skipId = seq[1] and (seq[1].forId or seq[1].id)
		local function consider(a)
			if a.target and a.id ~= skipId and not (a.hereOnly and prefs.skipped[a.skipKey]) then
				local d = E.Distance(ctx, env.player, a.target)
				if d and d <= radius then
					a._dist = d
					a.reasons = a.reasons and #a.reasons > 0 and a.reasons or explain(a, env, ctx)
					nearby[#nearby + 1] = a
				end
			end
		end
		for _, a in ipairs(cands) do consider(a) end
		for _, a in ipairs(hints) do consider(a) end
		table.sort(nearby, function(x, y)
			if x._dist ~= y._dist then return x._dist < y._dist end
			return x.id < y.id
		end)
		while #nearby > NEARBY_LIMIT do nearby[#nearby] = nil end
	end
	return nearby
end

--- The existing "while you're here" list for a given first action (used by the plan adapter).
function E.Nearby(cands, hints, first, ctx, env)
	return buildNearby(cands, hints, { first }, ctx, env)
end

--- Compute = stage 1 + the existing policy stages 2-4. This is the compatibility path the UI still uses.
function E.Compute(ctx)
	local prefs = ctx.prefs
	local c = E.Candidates(ctx)
	local env, cands, inProgress, hints = c.env, c.candidates, c.inProgress, c.hints
	local strategy = env.strategy
	applyStaticScores(cands, ctx, env)
	local seq = buildChain(cands, ctx, env)
	local nearby = buildNearby(cands, hints, seq, ctx, env)

	table.sort(inProgress, function(x, y) return x.id < y.id end)

	local upcoming = {}
	for i = 2, math.min(#seq, 7) do upcoming[#upcoming + 1] = seq[i] end
	return {
		next = seq[1], sequence = seq, upcoming = upcoming, nearby = nearby, inProgress = inProgress,
		stats = env.stats, warnings = env.warnings, strategy = strategy.key, routeZone = prefs.routeZone, routeMap = env.routeMap,
		player = env.player,
	}
end
