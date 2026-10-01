-- ForeverCodex.PlanAdapter: the TEMPORARY bridge between the Planner's plan and the existing window / slash commands.
--
-- The window (and Diag, Route, /codex next) still read the legacy plan shape: next, sequence, upcoming, nearby,
-- inProgress, stats, warnings. This adapter produces exactly that shape from a Planner plan, so the Planner can be
-- exercised through the current UI without redesigning it. It adds nothing of its own to the decision: it only
--   * turns reason CODES into the short sentences the old "Why:" line shows,
--   * inserts the same TRAVEL steps the old engine inserted (E.MakeTravel),
--   * keeps the old "while you're here" list (so flight hints still appear) with the ALSO DO action first,
--   * lists located-less actions under inProgress (the old "in your log, location unknown" line).
-- The Planner fields (now / alsoDo / thenAction / reminders / diag) ride along on the same table.
-- Delete this file when the UI reads the Planner plan directly.

local addonName, ns = ...
local E = ns.Engine
local Pl = ns.Planner

local A = {}
ns.PlanAdapter = A

local TEXT = {
	BEST_SEQUENCE = function(r) return r.stops and r.stops > 1 and "Best first step of a short plan" or "Best use of your time right now" end,
	SAME_STOP = function(r) return r.count and (r.count .. " things to do here") or "Can be done at the same stop" end,
	CHAIN_UNLOCK = function() return "Unlocks a follow-up quest nearby" end,
	ROUTE_ZONE = function() return "In your route zone" end,
	PLAYER_ADDED = function() return "You added this" end,
	LEVEL_FIT = function() return "Fits your level" end,
	TURN_IN_WAITS = function() return "A turn-in can wait: this saves a trip" end,
	ON_THE_WAY = function() return "Right on your way" end,
	SMALL_DETOUR = function(r) return string.format("Only about %d seconds out of your way", r.seconds or 0) end,
	FOLLOWS = function() return "Comes after the stop above" end,
}

local function sentences(plan, a)
	local out = {}
	for _, r in ipairs(plan.diag.reasons[a.id] or {}) do
		local f = TEXT[r.code]
		if f then out[#out + 1] = f(r) end
	end
	if #out == 0 then out[1] = "Best available option" end
	return out
end

A.Sentences = sentences      -- reason codes -> short sentences (also used by the Presenter)

--- Legacy-shaped plan from a Planner plan. `c` is the Engine.Candidates result the plan was made from.
function A.ToLegacy(plan, ctx, c)
	local env = c.env
	local seq, pos = {}, env.player
	local function push(a)
		if not a then return end
		a.reasons = sentences(plan, a)
		if a.target and pos then
			local d = E.Distance(ctx, pos, a.target)
			a._dist = d
			if d and (d >= E.TRAVEL_MIN or d >= E.DIFFERENT_CONTINENT) then seq[#seq + 1] = E.MakeTravel(a, d) end
		end
		seq[#seq + 1] = a
		if a.target then pos = { map = a.target.map, x = a.target.x, y = a.target.y, world = a.target.world } end
	end
	push(plan.now)
	push(plan.alsoDo)
	push(plan.thenAction)

	local upcoming = {}
	for i = 2, math.min(#seq, 7) do upcoming[#upcoming + 1] = seq[i] end

	-- "while you're here": the ALSO DO action first, then the old nearby list (flight hints included)
	local nearby, seen = {}, {}
	if plan.alsoDo and env.player then      -- (the old list means "near where you are": nothing to say without a position)
		nearby[1] = plan.alsoDo
		seen[plan.alsoDo.id] = true
	end
	if plan.thenAction then seen[plan.thenAction.id] = true end
	for _, a in ipairs(env.player and plan.now and E.Nearby(c.candidates, c.hints, plan.now, ctx, env) or {}) do
		if not seen[a.id] and #nearby < 5 then nearby[#nearby + 1] = a; seen[a.id] = true end
	end

	local inProgress, have = {}, {}
	for _, a in ipairs(c.inProgress) do inProgress[#inProgress + 1] = a; have[a.id] = true end
	for _, a in ipairs(plan.reminders) do
		if not have[a.id] then inProgress[#inProgress + 1] = a; have[a.id] = true end
	end
	table.sort(inProgress, function(x, y) return x.id < y.id end)

	return {
		next = seq[1], sequence = seq, upcoming = upcoming, nearby = nearby, inProgress = inProgress,
		stats = env.stats, warnings = env.warnings, strategy = env.strategy.key, routeZone = ctx.prefs.routeZone, routeMap = env.routeMap,
		player = env.player,
		now = plan.now, alsoDo = plan.alsoDo, thenAction = plan.thenAction, reminders = plan.reminders, diag = plan.diag,
	}
end

--- The whole new pipeline: Engine.Candidates -> Planner -> legacy-shaped plan. opts: { prevNowId }.
function A.Compute(ctx, opts)
	local c = E.Candidates(ctx)
	local plan = Pl.Compute(ctx, c, opts)
	return A.ToLegacy(plan, ctx, c)
end
