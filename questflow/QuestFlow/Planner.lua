-- ForeverCodex.Planner (Phase 2): turns the Engine's candidate ACTIONS into a short, character-aware SEQUENCE.
--
--     Engine.Candidates(ctx)  ->  Planner.Compute(ctx, candidates)  ->  plan
--
--     plan = {
--       now        = action | nil     the first action of the best short sequence (exactly one, or nil)
--       alsoDo     = action | nil     at most ONE opportunistic action worth doing while already here
--       thenAction = action | nil     at most one contextual continuation (the next stop), never forced
--       reminders  = { action, ... }  quests in the log / pins with NO usable location (never routed, never marked)
--       diag       = { ... }          everything about HOW it was decided: counts, scores, times, reason codes, rejects
--     }
--
-- The Planner reads only structured action facts (Contract.lua) and the Context. It does not read the UI, navigation,
-- markers, the quest map, party state or telemetry, and it has no state of its own: the previous NOW id is passed in
-- (opts.prevNowId) for stability. It never mutates an action. Deterministic: stable orders, ties broken by action id.
--
-- HOW IT DECIDES (the short version; CODEX_PLANNER_DESIGN.md sections 8-13 have the reasoning):
--   1. Actions with a usable location are grouped into STOPS: one place (within STOP_RADIUS yards) where several
--      actions can be done for one trip. Batching (two objectives in one area; turn in two quests; accept three at a
--      hub) therefore falls out of the cost model, with no special rule.
--   2. Every ordered sequence of up to DEPTH stops (drawn from the BEAM_K most promising) is scored:
--          net = sum(value of its actions) - timeValue * (walking time + time spent doing things)
--      This is "value per unit time" written so that sequences of different length compare fairly: it is positive
--      exactly when the sequence earns more than timeValue points per second. (A plain ratio always prefers the
--      single cheapest action, which is the "turn it in first" failure this Planner exists to fix.)
--   3. NOW = the best action of the FIRST stop of the best sequence; THEN = the best action of the SECOND stop.
--   4. ALSO DO = the one other action whose INTERRUPTION COST (extra time to insert it into that sequence; zero for
--      an action in the same stop) is small relative to its value; nil when nothing qualifies.
--
-- BASIS of every number (nothing here is XP): value points are POLICY values (no quest has an XP value before turn-in);
-- walking time is distance / RUN_SPEED, an ESTIMATE (7 yd/s is a game constant, not yet measured on Forever); times
-- spent doing things are POLICY constants. Calibration constants below are named, strategy-scoped and meant to be tuned.
--
-- Unknown stays unknown: an action with no usable location is a reminder, never NOW / ALSO DO / THEN; a leg whose
-- walking time cannot be known (another continent, no world conversion) is marked unknown and ranks after every
-- sequence made of known legs; an assumed turn-in location is trusted less than an observed one.

local addonName, ns = ...
local R = ns.Registry
local E = ns.Engine
local K = ns.Contract

local Pl = {}
ns.Planner = Pl

-- ---------------------------------------------------------------- calibration (named, labelled, tunable)

Pl.RUN_SPEED = 7          -- yards per second. ESTIMATED: a game constant, not measured on Forever
Pl.STOP_RADIUS = 60       -- yards: actions this close share one stop (policy; NPC reach + a local mob area)
Pl.BEAM_K = 8             -- stops considered for sequences (the most promising by solo net value)
Pl.DEPTH = 3              -- stops per sequence
Pl.UNKNOWN_LEG_SECONDS = 900  -- policy: a leg whose walking time cannot be known (other continent / no world conversion) is NOT free; charged as ~15 min (boat/flight/long ride)
Pl.CHAIN_RADIUS = 200     -- yards: a quest this close to a turn-in counts as "unlocked by it" (1 hop)

local BASE = {
	timeValue = 0.30,                                              -- policy points per second of the player's time
	value = { ACCEPT = 20, OBJECTIVE = 60, TURN_IN = 40, DISCOVER = 3 },   -- policy points; a finished quest is worth ~120
	dwell = { ACCEPT = 15, OBJECTIVE = 120, TURN_IN = 15, DISCOVER = 10 }, -- policy seconds spent at the stop
	dwellDefault = 15, valueDefault = 0,
	levelFit = 0.5,        -- scale of the Engine's level-fit points (so the strategy's levelFit / fitMul still apply)
	pinned = 200,          -- points for a quest the player added: an explicit choice outweighs ~10 minutes of walking
	chain = 0.25,          -- share of a successor quest's whole value credited to the turn-in that unlocks it (1 hop)
	detour = 30,           -- seconds of extra time an ALSO DO may add
	alsoFloor = 5,         -- points of net value an ALSO DO must still clear after paying for its time
	stickiness = 3,        -- points: keep the previous NOW unless another sequence is better by more than this
	confidence = { approx = 0.8, assumed = 0.8, unverifiedAccept = 0.9, logUnavailable = 0.5, notOffered = 0.25 },
}

-- Per-strategy differences only. The strategies themselves (and their level-fit / maxGap / allow filters) are the
-- existing ones in Strategies.lua; no strategy is created here, and an unknown key uses the base values.
local PER_STRATEGY = {
	efficient = {},
	fast = { timeValue = 0.45, detour = 20 },                      -- values time more: less walking, tighter detours
	questing_only = {},                                            -- the type filter is already applied by the Engine
	completionist = { timeValue = 0.15, detour = 45, value = { DISCOVER = 8 } },   -- more patient, surfaces more
}
Pl.STRATEGY_KEYS = { "completionist", "efficient", "fast", "questing_only" }

-- LOCAL PROGRESSION. A leveling guide asks "is there still something useful for this player to do HERE?" before "what is the best quest
-- anywhere?". The player's own map is the local area (no zone list: it works for any starting zone, faction, class or level):
--   1. when the player's map has located work worth doing (net value above LOCAL_MIN_NET after paying for its own time), only that map's stops
--      are sequenced; things elsewhere can still be an ALSO DO if they fit in cheaply. (The same mechanism a chosen route zone uses.)
--   2. when it has none, but the player has a quest IN PROGRESS in this area whose exact objective spot is not known, finishing it is
--      NOW (without a map location), rather than sending the player somewhere else; a distant trip waits until that work is done or skipped.
-- Never overrides a route zone the player chose or a quest they added. Pl.LOCAL_FIRST = false switches both off (tests).
Pl.LOCAL_FIRST = true
Pl.DEFER_PICKUPS = true              -- a distant new pickup waits while objective work of quests already in the log is waiting on the player's map (see Compute)
Pl.PICKUP_DEFER_RANGE_YD = 900       -- ...and that work is within this many yards
Pl.LOCAL_MIN_NET = 0

-- PROGRESSION. "Available" is not "recommended": every quest action is classified (level band, goal, chain reasons; Progression.lua) before it is valued. A pickup that is gray, far
-- above the player, or (with a goal) low, and has no REASON to be there, is rejected with the reason recorded; the others are scaled by their band. Pl.PROGRESSION = false switches the
-- whole stage off (tests use it to prove the stage is what changes the result).
Pl.PROGRESSION = true

-- QUEST-STATE PRIORITY. What the player has already earned comes before new work: (1) a FINISHED quest that can be handed in, (2) objectives of
-- quests in progress, (3) new pickups, (4) farther, new progression. Priced by the real walking time, never forced:
--   * inside one stop the order is by state (hand-in, then objectives, then pickups), not by policy value, and a remembered NOW does not hold
--     an older pickup in front of a hand-in that has just become possible;
--   * across stops, when the best plan contains a hand-in, the same stops visited hand-in first win if that costs no more than TURN_IN_FIRST_SECONDS
--     of extra walking (a hand-in 300+ yd out of the way does not pre-empt a pickup beside you; one a few steps away does). A hand-in the best plan
--     does not include is never forced in. Unmeasurable legs never qualify.
--     (objectives in progress keep the planner's own rule: a hand-in waits while objectives right here are done first, so the trip is batched)
-- Pl.TURN_IN_FIRST = false switches both off (tests).
Pl.TURN_IN_FIRST = true
Pl.TURN_IN_FIRST_SECONDS = 45

-- DEFERRED TURN-INS. A quest that is COMPLETE is not the same as "now is the time to hand it in". While the player has work underway in this
-- area, a hand-in that is not a short walk away waits (it stays listed as READY TO TURN IN) and the work goes on; once that work is done, or the
-- hand-in is close, it becomes NOW and the ready quests are handed in together (hand-ins within 60 yd of each other are one stop already).
--   * "work underway" = a located objective stop on the player's map, or a quest in the log in this area whose objective spot is unknown but
--     which the quest log shows has been started (some count above zero): Codex cannot see where the objective is, only that it is being worked
--   * "a short walk" = within DEFER_NEAR_YD of the player; never applies to a quest the player added, a hand-in sharing a stop with objectives,
--     or when there is no such work (then the hand-in is simply the best thing to do)
-- Pl.DEFER_TURN_INS = false switches it off (tests).
Pl.DEFER_TURN_INS = true
Pl.DEFER_NEAR_YD = 150
-- A hand-in is NOT deferred (it is worth the trip, or costs nothing) when:
--   * it is close (DEFER_NEAR_YD), or the log is nearly full (SLOT_PRESSURE_FREE): a freed slot has value
--   * it is naturally on the route to the productive work: walking player -> hand-in -> work costs at most ON_ROUTE_YD more than going straight there
--   * it is part of a batch: BATCH_MIN or more hand-ins at one stop, or in a row of stops no more than BATCH_YD apart, so one trip clears several
--   * there is no located objective work to do first (then the hand-in is simply the best thing to do)
-- The work does NOT have to be physically close: "meaningful productive work somewhere on the route" is enough to defer a far, lone hand-in.
Pl.ON_ROUTE_YD = 100
Pl.BATCH_MIN = 2
Pl.BATCH_YD = 250
-- WORK HERE. Work the player has already started, within a short walk, is finished before leaving the area, in every route style: a higher
-- price on time (the "fast" style) must not walk the player 1800 yd away from two started quests that are 40 yd away just because every local
-- option scores a little below a far pickup trip, or to run 750 yd to one quest's objectives while another started quest's objective is right
-- beside them. It applies when the plan's first stop is more than WORK_LEAVE_YD away (or on another map) and a stop with an objective of a
-- quest in the log is within WORK_HERE_YD on the player's map; it never overrides a quest the player added or a
-- route zone the player chose, and Skip still gets out of it.
-- Pl.WORK_HERE = false switches it off (tests).
Pl.WORK_HERE = true
Pl.WORK_HERE_YD = 150
Pl.WORK_LEAVE_YD = 500

-- QUEST-LOG PRESSURE. A finished quest still holds one of the 40 quest-log slots until it is handed in. With this few slots left, deferring a
-- hand-in is no longer free (each one frees a slot for the next pickup), so the deferral above is switched off and normal route value decides.
-- It never forces a hand-in either: a far hand-in still has to win on net value. Needs a readable quest log.
Pl.SLOT_PRESSURE_FREE = 2

local function merge(into, over)
	for k, v in pairs(over or {}) do
		if type(v) == "table" and type(into[k]) == "table" then
			local copy = {}
			for kk, vv in pairs(into[k]) do copy[kk] = vv end
			for kk, vv in pairs(v) do copy[kk] = vv end
			into[k] = copy
		else
			into[k] = v
		end
	end
	return into
end

--- Planner parameters for a strategy key (a fresh table).
function Pl.Params(key)
	local p = merge({}, BASE)
	return merge(p, PER_STRATEGY[key])
end

-- ---------------------------------------------------------------- facts about one action

--- The first usable location of an action: { map, x, y }, status ("known" | "approx"), assumed. nil when unknown.
-- Reads the structured targets; an action from a provider that does not carry the contract falls back to its single
-- legacy target (still labelled approx when the legacy target says so).
function Pl.Locate(a)
	if a.contract then
		for _, t in ipairs(a.targets or {}) do
			local w = t.where
			if w and w.status ~= "unknown" and w.points and w.points[1] then
				local p = w.points[1]
				return { map = p.map, x = p.x, y = p.y }, w.status, t.assumed == true
			end
		end
		return nil
	end
	local t = a.target
	if t and type(t.map) == "number" then
		return { map = t.map, x = t.x, y = t.y }, t.approx and "approx" or "known", false
	end
	return nil
end

--- What the CLIENT has said about a pickup being offered, reduced to the three states the planner uses (the evidence itself is OfferProbe's):
--   "OBSERVED"     the client offered it to this character (a quest dialog opened, or an NPC's available list carried its id) and nothing newer contradicts that
--   "NOT_OFFERED"  the quest giver's dialog, read at the character's CURRENT progression, did not offer it (an empty list, or a complete list without it)
--   "UNKNOWN"      no client evidence, or evidence that progress has made stale (a negative read before a level / turn-in / finished quest), or an offer that a newer
--                  (now stale) listing from the giver withdrew (the old positive does not come back), or an offer seen at a DIFFERENT NPC than the quest's giver
-- Database knowledge (where it starts, its prerequisites, its level) stays what it was: supporting evidence that makes a pickup ELIGIBLE, never proof that it is offered.
function Pl.OfferState(a)
	if not a or a.kind ~= "ACCEPT" or not a.quest then return "UNKNOWN", nil end
	local ev = Pl.OfferEvidence(a)
	if Pl.Actionability(a) == "OBSERVED" then
		if ev and ev.contradicted then return "NOT_OFFERED", ev end
		return "OBSERVED", ev
	end
	if ev and (ev.kind == "EMPTY_AT_NPC" or ev.kind == "NOT_LISTED_AT_NPC") and not ev.stale then return "NOT_OFFERED", ev end
	return "UNKNOWN", ev
end

--- 0..1: how much to trust the action's data when valuing it. Never raises a value, only discounts it.
function Pl.Confidence(a, par)
	par = par or Pl.Params("efficient")
	local c = par.confidence
	local _, status, assumed = Pl.Locate(a)
	local f = 1
	if assumed then f = c.assumed elseif status == "approx" then f = c.approx end
	if a.kind == "ACCEPT" then
		-- a pickup is valued by how sure we are the client would OFFER it now: observed = full; no evidence = the existing small discount (the quest may not be offered
		-- on Forever, or not yet); the giver just declined to offer it = a strong discount (a contextual fact about that dialog, not a rule about the quest)
		local st = Pl.OfferState(a)
		if st == "NOT_OFFERED" then f = f * c.notOffered
		elseif st ~= "OBSERVED" and a.evidence ~= "observed" then f = f * c.unverifiedAccept end    -- (unchanged: data labelled observed was not discounted before)
	end
	if a.state == "UNKNOWN" and a.stateWhy == "LOG_UNAVAILABLE" then f = f * c.logUnavailable end
	return f
end

-- POSSIBLE PICKUPS. A pickup the client has not confirmed is only "not ruled out". When nothing says it is restricted AWAY from this character's class or
-- race (no data layer that covers the quest carries restriction data) the planner does not send the player far for it: such a pickup is a candidate only for
-- a short walk. Beyond the limit it is kept as a POSSIBLE pickup (counted and listed in the report, usable only as an on-the-way extra), never as NOW.
-- A fresh offer from the quest giver (OBSERVED), a quest the player added, and a route zone the player chose all lift the limit: those are evidence or intent.
Pl.RESTRICTION_UNKNOWN_MAX_YD = 200
-- UNKNOWN IS NOT AVAILABLE. A pickup with no positive client evidence (no offer seen, or only a negative that has aged out) is "not ruled out", not "go there": the data
-- saying it exists, where it starts and that its prerequisites look met is not proof the client will offer it. Such a pickup is a POSSIBLE pickup beyond this distance.
-- (A design value: the limit of "worth walking to on the data's word alone". Fresh evidence, a quest the player added, or a chosen route zone lifts it.)
Pl.UNCONFIRMED_MAX_YD = 500

--- Why this ACCEPT may only be a POSSIBLE pickup, or nil when it may be routed. `pos` is its location, `S` the planning state.
function Pl.PossibleOnly(a, pos, S)
	if a.kind ~= "ACCEPT" or a.pinned or not (S and S.player and pos) then return nil end
	-- a seasonal / event quest is only possible while its event runs, which no data here can tell: it is routed only on the client's own offer (even when the player opted in)
	if a.seasonal and Pl.OfferState(a) ~= "OBSERVED" then return "SEASONAL_UNPROVEN", E.Distance(S.ctx, S.player, pos) end
	if S.env and S.env.routeMap and S.env.routeMap == pos.map then return nil end      -- the player chose to quest there
	if Pl.OfferState(a) == "OBSERVED" then return nil end
	local d = E.Distance(S.ctx, S.player, pos)
	local far = d == nil or d >= E.DIFFERENT_CONTINENT
	-- (a limit of math.huge switches that rule off: the test harness does)
	if a.restrictionUnknown and Pl.RESTRICTION_UNKNOWN_MAX_YD < math.huge and (far or d > Pl.RESTRICTION_UNKNOWN_MAX_YD) then return "RESTRICTION_UNKNOWN", d end
	if Pl.UNCONFIRMED_MAX_YD < math.huge and (far or d > Pl.UNCONFIRMED_MAX_YD) then return "UNKNOWN_AVAILABILITY", d end        -- (OBSERVED returned above, NOT_OFFERED was held back: what is left here is UNKNOWN)
	return nil
end

-- TIMED QUESTS. A quest with a live countdown is not automatically the most urgent thing: only the SLACK matters, the time left minus the walk to it and the work on it (both the
-- planner's own estimates). With plenty of slack nothing changes; as it shrinks the quest's value rises smoothly; at or below CRITICAL it is a must-do-first stop (the same way a quest
-- the player added is). The numbers are design values, not game facts.
Pl.TIMER = { relaxed = 600, critical = 90, maxBoost = 5 }

--- boost (>= 1) and critical (bool) for a timed action with this many seconds of slack.
function Pl.TimerUrgency(slack)
	local t = Pl.TIMER
	if slack >= t.relaxed then return 1, false end
	if slack <= t.critical then return t.maxBoost, true end
	return 1 + (t.maxBoost - 1) * (t.relaxed - slack) / (t.relaxed - t.critical), false
end

--- Can the Planner sequence this action at all? Returns true, or false + a reason key (for diagnostics).
local function usable(a)
	if a.skip and a.skip.logical then return false, "skipped" end       -- a skip wins over "added": a skipped action is never sequenced
	if a.contract == nil or a.optional then return true end
	if a.state == "UNKNOWN" and a.stateWhy == "LOG_UNAVAILABLE" then return true end
	-- a quest the player ADDED is the player's call: the data's requirements (ATT, unverified on Forever) do not veto it
	if a.pinned and (a.state == "BLOCKED" or a.state == "UNKNOWN") then return true end
	if not K.Plannable(a.state, false) then return false, "state" end
	return true
end

-- ---------------------------------------------------------------- chain (one hop, derived from ATT prerequisites)

local idxFor, idx = nil, nil

local function unlocksOf(questId)
	local ids = R.QuestIds()
	if idxFor ~= ids then
		idx = {}
		for _, qid in ipairs(ids) do
			local v = R.Quest(qid)
			for _, pre in ipairs(v and v.prereq or {}) do
				idx[pre] = idx[pre] or {}
				table.insert(idx[pre], qid)
			end
		end
		idxFor = ids
	end
	return idx[questId] or {}
end

--- Points credited to turning in `a` because it makes another quest available right there (nil when it does not).
Pl.Unlocks = unlocksOf          -- read-only: the quests whose prerequisites include this one (the index chainValue already builds)

local function chainValue(a, pos, ctx, par)
	if a.kind ~= "TURN_IN" or not a.ref or a.ref.kind ~= "quest" or not pos then return nil end
	local life = par.value.ACCEPT + par.value.OBJECTIVE + par.value.TURN_IN
	for _, sid in ipairs(unlocksOf(a.ref.id)) do
		local v = R.Quest(sid)
		if v and v.loc and not v.repeatable and not ctx.log[sid] and not ctx.isCompleted(sid) then
			local blocked = false
			for _, r in ipairs(K.QuestRequirements(v, ctx)) do
				if r.kind ~= "prereqQuest" and r.result == false then blocked = true end   -- the prerequisite itself is what we are about to satisfy
			end
			if not blocked then
				local d = E.Distance(ctx, pos, { map = v.loc.map, x = v.loc.x, y = v.loc.y })
				if d and d <= Pl.CHAIN_RADIUS then return par.chain * life, sid end
			end
		end
	end
	return nil
end

-- ---------------------------------------------------------------- value of one action (policy points, never XP)

local function valueOf(a, pos, ctx, env, par)
	local comps = { base = par.value[a.kind] or par.valueDefault }
	local v = comps.base
	local lvl = ctx.char.level
	if a.kind == "ACCEPT" then
		comps.levelFit = E.LevelFit(a, lvl, env.w) * par.levelFit
		v = v + comps.levelFit
	end
	if a.breadcrumb then
		comps.breadcrumb = (env.w.breadcrumb or 0) * par.levelFit
		v = v + comps.breadcrumb
	end
	if a.pinned then
		comps.pinned = par.pinned
		v = v + comps.pinned
	end
	local ch, unlocked = chainValue(a, pos, ctx, par)
	if ch then
		comps.chain, comps.unlocks = ch, unlocked
		v = v + ch
	end
	if v < 0 then v = 0 end
	return v, comps
end

-- ---------------------------------------------------------------- geometry

--- Walking seconds between two points; nil = cannot be known (another continent, no conversion). A missing START
-- (the player's position is unavailable) costs nothing, and is reported in the diagnostics.
local function seconds(ctx, a, b)
	if not a or not b then return 0 end
	local d = E.Distance(ctx, a, b)
	local walk
	if d ~= nil and d < E.DIFFERENT_CONTINENT then walk = d / Pl.RUN_SPEED end
	-- an EVIDENCED faster way (a discovered flight the taxi map offered, a ready hearth with a learned bind, a registered transport) may beat walking; with no
	-- such evidence Travel returns the walking time unchanged (Travel.lua)
	if ns.Travel and (walk == nil or walk >= ns.Travel.MIN_WALK_SECONDS) then
		local s = ns.Travel.Seconds(ctx, a, b, walk)
		return s
	end
	return walk
end

-- ---------------------------------------------------------------- compute

local function byId(x, y) return x.id < y.id end

local STATE_TIER = { TURN_IN = 1, OBJECTIVE = 2, ACCEPT = 3 }       -- (4: everything else: flight hints and so on)
local function tierOf(it) return Pl.TURN_IN_FIRST and STATE_TIER[it.a.kind] or 4 end

local function itemOrder(x, y)
	local tx, ty = tierOf(x), tierOf(y)
	if tx ~= ty then return tx < ty end
	if x.val ~= y.val then return x.val > y.val end
	return x.id < y.id
end

local function hasKind(stop, kind)
	for _, it in ipairs(stop.items) do if it.a.kind == kind then return true end end
	return false
end
local function hasHandIn(stop) return hasKind(stop, "TURN_IN") end

--- Better sequence? Fewer unknown legs first, then higher net value, then the smaller key (determinism).
local function better(x, y)
	if not y then return true end
	if x.unknown ~= y.unknown then return x.unknown < y.unknown end
	if x.net ~= y.net then return x.net > y.net end
	return x.key < y.key
end

-- Compute is a short orchestration over the stage functions below. Each stage is a plain local function that reads and
-- extends one shared state table `S` (ctx, player, params, stops, legs, diag, ...): this keeps every function well under
-- Lua's local-variable and upvalue limits and makes each stage readable on its own. The decisions are unchanged.

local function copyTable(v)
	if type(v) ~= "table" then return v end
	local out = {}
	for k, x in pairs(v) do out[k] = copyTable(x) end
	return out
end

--- Stage 1: which actions can be sequenced. Fills S.items (route actions), S.extras (optional hints), S.reminders.
local function gather(S, c)
	local ctx, env, par, diag = S.ctx, S.env, S.par, S.diag
	local items, extras, reminders = {}, {}, {}
	local function take(a)
		local ok, why = usable(a)
		local pos, status, assumed = Pl.Locate(a)
		if not pos then
			-- no usable location: a reminder, never routed. (A quest the player added that no pack knows is one too.)
			if not a.optional and ok then reminders[#reminders + 1] = a end
			return
		end
		if not ok then diag.filtered[why] = (diag.filtered[why] or 0) + 1 return end
		-- HELD BACK: the quest's giver was asked at this very progression and did not offer it. That is not a price to discount (a pickup at the NPC you stand
		-- at costs no travel and can still net positive at a discount) but a fact about what the player can do right now: sending them back to the same NPC
		-- for the same quest is the exact failure being avoided. The quest stays a known candidate (counted, listed in the report) and re-enters the moment
		-- the evidence goes stale (level / turn-in / finished quest changes the stamp) or the client offers it. A quest the player ADDED is their call.
		if a.kind == "ACCEPT" and not a.pinned and Pl.OfferState(a) == "NOT_OFFERED" then
			diag.held = diag.held or { n = 0, list = {} }
			diag.held.n = diag.held.n + 1
			if #diag.held.list < Pl.HELD_CAP then
				local ev = Pl.OfferEvidence(a)
				diag.held.list[#diag.held.list + 1] = { id = a.id, quest = a.quest, title = a.title, kind = ev and ev.kind or nil, npc = ev and ev.npc or nil, last = ev and ev.last or nil,
					contradicted = ev and ev.contradicted or nil }
			end
			return
		end
		-- A DUNGEON objective is not what to do NOW from outside that dungeon: it stays a known candidate (counted, listed in DUNGEON QUESTS, usable as an on-the-way extra) but never competes with
		-- open-world progress for NOW. Inside the dungeon it is an ordinary action. The tag is the game's own (Dungeons.IsDungeon); nothing here detects a dungeon any other way.
		local outsideDungeon = a.kind == "OBJECTIVE" and a.quest and ns.Dungeons and ns.Dungeons.IsDungeon(ctx, a.quest) and not ns.Dungeons.PlayerInside(ctx, a.quest)
		-- CLASSIFICATION + RELEVANCE (Progression.lua): a pickup with no reason to be recommended is rejected here, with the reason kept for the report
		local judged = Pl.PROGRESSION and ns.Progression and a.type == "QUEST" and ns.Progression.Judge(a, ctx, S.goal) or nil
		if judged then
			local f = diag.funnel
			f.judged = f.judged + 1
			f.bands[judged.band or "UNKNOWN"] = (f.bands[judged.band or "UNKNOWN"] or 0) + 1
			if judged.verdict == "EXCLUDED" then f.excluded = f.excluded + 1 elseif judged.verdict == "PENALIZED" then f.penalized = f.penalized + 1 elseif judged.verdict == "BOOSTED" then f.boosted = f.boosted + 1 end
			if (judged.verdict ~= "NORMAL" or #judged.reasons > 0) and #f.list < ns.Progression.LIST_CAP then
				f.list[#f.list + 1] = { id = a.id, title = a.title, verdict = judged.verdict, band = judged.band, why = judged.why, reasons = judged.reasons }
			end
			S.judgement[a.id] = judged
			if judged.verdict == "EXCLUDED" then
				diag.filtered["progression:" .. tostring(judged.why)] = (diag.filtered["progression:" .. tostring(judged.why)] or 0) + 1
				return
			end
		end
		local possible, pd = Pl.PossibleOnly(a, pos, S)
		local val, comps = valueOf(a, pos, ctx, env, par)
		if judged and judged.mult ~= 1 then val = val * judged.mult comps.progression = judged.mult end
		local timerInfo
		if a.timer and a.kind == "OBJECTIVE" then
			local walk = (S.player and seconds(ctx, S.player, pos)) or 0
			local slack = a.timer.remaining - walk - (par.dwell[a.kind] or par.dwellDefault)
			local boost, critical = Pl.TimerUrgency(slack)
			timerInfo = { remaining = a.timer.remaining, slack = slack, boost = boost, critical = critical }
			if boost > 1 then val = val * boost; comps.timer = boost end
		end
		local conf = Pl.Confidence(a, par)
		local it = { a = a, id = a.id, pos = pos, status = status, assumed = assumed, conf = conf, comps = comps,
			val = val * conf, dwell = par.dwell[a.kind] or par.dwellDefault, timer = timerInfo, urgent = timerInfo and timerInfo.critical or nil }
		-- the time left on an objective shrinks with the progress the quest log reports (counts only; never a map to objective indexes)
		if a.kind == "OBJECTIVE" and a.objectiveState and a.objectiveState.known then
			local n, done = #a.objectiveState.list, 0
			for _, o in ipairs(a.objectiveState.list) do if o.finished then done = done + 1 end end
			if n > 0 then it.dwell = it.dwell * math.max(0.25, 1 - done / n) end
		end
		if possible then
			it.possible = possible
			diag.possible = diag.possible or { n = 0, list = {} }
			diag.possible.n = diag.possible.n + 1
			if #diag.possible.list < Pl.HELD_CAP then
				diag.possible.list[#diag.possible.list + 1] = { id = a.id, quest = a.quest, title = a.title, why = possible, dist = pd, giver = a.giver }
			end
			extras[#extras + 1] = it
		elseif outsideDungeon then
			it.outsideDungeon = true
			diag.dungeonDeferred = diag.dungeonDeferred or { n = 0, list = {} }
			diag.dungeonDeferred.n = diag.dungeonDeferred.n + 1
			if #diag.dungeonDeferred.list < Pl.HELD_CAP then diag.dungeonDeferred.list[#diag.dungeonDeferred.list + 1] = { id = a.id, quest = a.quest, title = a.title } end
			extras[#extras + 1] = it
		elseif a.optional or a.hereOnly then extras[#extras + 1] = it else items[#items + 1] = it end
	end
	for _, a in ipairs(c.candidates) do take(a) end
	for _, a in ipairs(c.inProgress) do take(a) end
	for _, a in ipairs(c.hints) do take(a) end
	table.sort(items, byId)
	table.sort(extras, byId)
	table.sort(reminders, byId)
	-- in-progress quests in the player's area whose exact objective spot is unknown: current local work (most progress first, then id)
	local localWork = {}
	if S.player and S.player.map then
		for _, a in ipairs(reminders) do
			if a.kind == "OBJECTIVE" and a.areaMap and a.areaMap == S.player.map and not a.unknown then localWork[#localWork + 1] = a end
		end
		local function done(a)                         -- how far along: the average of each objective's have / need (counts the quest log reported)
			local os, n, d = a.objectiveState, 0, 0
			if os and os.known then
				for _, o in ipairs(os.list) do
					n = n + 1
					if o.finished then d = d + 1
					elseif type(o.have) == "number" and type(o.need) == "number" and o.need > 0 then d = d + math.min(1, o.have / o.need) end
				end
			end
			return n > 0 and d / n or 0
		end
		table.sort(localWork, function(x, y)
			if (x.timer ~= nil) ~= (y.timer ~= nil) then return x.timer ~= nil end                     -- a timed quest first, the soonest deadline first
			if x.timer and y.timer and x.timer.remaining ~= y.timer.remaining then return x.timer.remaining < y.timer.remaining end
			local dx, dy = done(x), done(y)
			if dx ~= dy then return dx > dy end
			return x.id < y.id
		end)
	end
	S.items, S.extras, S.reminders, S.localWork = items, extras, reminders, localWork
	diag.candidates, diag.optional, diag.unlocated = #items, #extras, #reminders
end

--- Stage 2: stops: one place, several actions, one trip.
local function makeStops(S)
	local stops = {}
	for _, it in ipairs(S.items) do
		local home
		for _, s in ipairs(stops) do
			local d = E.Distance(S.ctx, s.pos, it.pos)
			if d and d <= Pl.STOP_RADIUS then home = s break end
		end
		if not home then
			home = { pos = { map = it.pos.map, x = it.pos.x, y = it.pos.y }, items = {}, val = 0, dwell = 0, id = it.id }
			stops[#stops + 1] = home
		end
		table.insert(home.items, it)
		home.val, home.dwell = home.val + it.val, home.dwell + it.dwell
		if it.a.pinned or it.urgent then home.pinned = true end          -- (a quest about to run out of time is a must-do-first stop, like one the player added)
		it.stop = home
	end
	S.stops = stops
	S.diag.stops = #stops
end

--- Optional trace (evaluation harness only): per-action facts, the stops, the unlocated ids.
local function recordTrace(S)
	local diag = S.diag
	diag.params = copyTable(S.par)
	diag.items, diag.unlocatedIds = {}, {}
	for _, list in ipairs({ S.items, S.extras }) do
		for _, it in ipairs(list) do
			diag.items[it.id] = { kind = it.a.kind, stop = it.stop and it.stop.id or nil, optional = it.stop == nil, map = it.pos.map, x = it.pos.x, y = it.pos.y,
				status = it.status, assumed = it.assumed or false, conf = it.conf, value = it.val, dwell = it.dwell, comps = copyTable(it.comps) }
		end
	end
	for _, a in ipairs(S.reminders) do diag.unlocatedIds[#diag.unlocatedIds + 1] = a.id end
	diag.stopList = {}
	for i, st in ipairs(S.stops) do
		local ids = {}
		for _, it in ipairs(st.items) do ids[#ids + 1] = it.id end
		diag.stopList[i] = { id = st.id, items = ids, map = st.pos.map, x = st.pos.x, y = st.pos.y, value = st.val, dwell = st.dwell }
	end
end

--- Stage 3: the stops worth sequencing: the route zone's (the player's choice) when it has any, ranked by solo net value
-- (unknown first legs last), the best BEAM_K. Also builds S.leg(i, j): walking seconds stop i -> stop j (i = 0 is the player).
local function rankStops(S)
	local ctx, env, stops, diag, lam = S.ctx, S.env, S.stops, S.diag, S.lam
	-- the player's ROUTE ZONE is a choice, and wins over convenience: when it has anything to do, only its stops are
	-- sequenced (actions elsewhere can still be an ALSO DO if they fit in cheaply). If it has nothing, everything is.
	local candidatesStops = stops
	if env.routeMap then
		local inZone = {}
		for _, s in ipairs(stops) do if s.pos.map == env.routeMap then inZone[#inZone + 1] = s end end
		if #inZone > 0 and #inZone < #stops then
			candidatesStops = inZone
			diag.routeZoneOnly = true
		end
	end
	local legCache = {}
	S.leg = function(i, j)
		local key = i .. ">" .. j
		local v = legCache[key]
		if v == nil then
			local from = S.player              -- (nil when the player's position is unavailable)
			if i ~= 0 then from = stops[i].pos end
			v = seconds(ctx, from, stops[j].pos)
			legCache[key] = v == nil and false or v
		end
		if v == false then return nil end
		return v
	end
	-- local progression: with no route zone chosen, the player's own map is the implicit one when it has located work worth doing
	if Pl.LOCAL_FIRST and not env.routeMap and S.player and S.player.map then
		local here, anyUseful = {}, false
		for i, s in ipairs(stops) do
			if s.pos.map == S.player.map or s.pinned then
				here[#here + 1] = s
				if s.pos.map == S.player.map and not s.pinned then
					local t = S.leg(0, i)
					if t ~= nil and s.val - lam * (t + s.dwell) > Pl.LOCAL_MIN_NET then anyUseful = true end
				end
			end
		end
		if anyUseful and #here < #candidatesStops then
			candidatesStops = here
			diag.localOnly = true
		end
	end
	local ranked, allowed = {}, {}
	for _, s in ipairs(candidatesStops) do allowed[s] = true end
	for i, s in ipairs(stops) do
		if allowed[s] then
			local t = S.leg(0, i)
			s.solo = s.val - lam * ((t or Pl.UNKNOWN_LEG_SECONDS) + s.dwell)
			s.soloUnknown = (t == nil and not s.pinned) and 1 or 0     -- a place the player ADDED is theirs to travel to: not penalised
			ranked[#ranked + 1] = i
		end
	end
	table.sort(ranked, function(x, y)
		local sx, sy = stops[x], stops[y]
		if (sx.pinned == true) ~= (sy.pinned == true) then return sx.pinned == true end     -- the player's own quests are always considered
		if sx.soloUnknown ~= sy.soloUnknown then return sx.soloUnknown < sy.soloUnknown end
		if sx.solo ~= sy.solo then return sx.solo > sy.solo end
		return sx.id < sy.id
	end)
	local top = {}
	for i = 1, math.min(Pl.BEAM_K, #ranked) do top[i] = ranked[i] end
	S.top = top
	diag.considered = #top
end

--- Stage 4: bounded, deterministic search over ordered sequences of up to DEPTH stops. Returns the chosen sequence
-- (stability applied) and, for the trace, every scored sequence and the best one starting at each stop.
local function searchSequences(S, prevId)
	local stops, top, lam, leg, trace = S.stops, S.top, S.lam, S.leg, S.trace
	local best, bestPrev, evaluated = nil, nil, 0
	local bestByFirst, allSeqs = {}, {}
	local handInFirst = {}                              -- stop-set key -> the best sequence over that SAME set of stops that starts at a hand-in
	local chosen, used = {}, {}
	local function setKey(list)
		local ks = { unpack(list) }
		table.sort(ks)
		return table.concat(ks, ",")
	end
	-- a quest the player ADDED is the player's call: when one is in reach, the sequence starts at it
	local pinnedFirst = false
	for _, i in ipairs(top) do if stops[i].pinned then pinnedFirst = true end end
	S.diag.pinnedFirst = pinnedFirst or nil
	local function search(prev, net, secs, unknown, key)
		for _, i in ipairs(top) do
			if not used[i] and not (pinnedFirst and #chosen == 0 and not stops[i].pinned) then
				local s = stops[i]
				local t = leg(prev, i)
				local seq = { net = net + s.val - lam * ((t or Pl.UNKNOWN_LEG_SECONDS) + s.dwell), secs = secs + (t or Pl.UNKNOWN_LEG_SECONDS) + s.dwell,
					unknown = unknown + ((t == nil and not s.pinned) and 1 or 0), key = key .. "|" .. s.id }
				chosen[#chosen + 1] = i
				used[i] = true
				evaluated = evaluated + 1
				seq.stops = { unpack(chosen) }
				if trace then allSeqs[#allSeqs + 1] = seq end
				if Pl.TURN_IN_FIRST and hasHandIn(stops[chosen[1]]) then
					local k = setKey(chosen)
					if better(seq, handInFirst[k]) then handInFirst[k] = seq end
				end
				if better(seq, best) then best = seq end
				local f = chosen[1]
				if better(seq, bestByFirst[f]) then bestByFirst[f] = seq end
				if prevId then
					for _, it in ipairs(stops[f].items) do
						if it.id == prevId then
							if better(seq, bestPrev) then bestPrev = seq end
							break
						end
					end
				end
				if #chosen < Pl.DEPTH then search(i, seq.net, seq.secs, seq.unknown, seq.key) end
				chosen[#chosen] = nil
				used[i] = nil
			end
		end
	end
	search(0, 0, 0, 0, "")
	S.diag.sequences = evaluated
	S.bestByFirst, S.allSeqs = bestByFirst, allSeqs

	-- quest-state priority: when the best sequence starts with a NEW PICKUP (not a hand-in, and not objectives in progress, which keep their
	-- own batching rule), a sequence that starts at a hand-in beats it if it costs little extra walking
	local first = best and stops[best.stops[1]]
	if Pl.TURN_IN_FIRST and first and not hasHandIn(first) and not hasKind(first, "OBJECTIVE") then
		-- only a re-ordering of the SAME stops is compared (so the extra cost is just the walking), and only within the margin
		local margin = lam * Pl.TURN_IN_FIRST_SECONDS
		local cand = handInFirst[setKey(best.stops)]
		if cand and cand.unknown <= best.unknown and cand.net >= best.net - margin then
			best = cand
			S.diag.turnInFirst = true
		end
	end

	-- stability: keep the previous NOW unless something else is better by more than `stickiness`
	local pick = best
	if bestPrev and bestPrev ~= best and not S.diag.turnInFirst and bestPrev.unknown <= best.unknown and bestPrev.net >= best.net - S.par.stickiness then
		pick = bestPrev
		S.diag.stuck = true
	end
	return pick
end

--- The best-valued item of a stop (the preferred one first, for stability), and the stop's items in order.
local function bestOf(stop, preferId)
	local list = {}
	for _, it in ipairs(stop.items) do list[#list + 1] = it end
	table.sort(list, itemOrder)
	if preferId then
		for _, it in ipairs(list) do
			-- (the previous NOW is kept for stability, but not in front of a hand-in / objective that has just become the better state)
			-- (nor in front of a quest about to run out of time)
			if it.id == preferId and tierOf(it) <= tierOf(list[1]) and (it.urgent or not list[1].urgent) then return it, list end
		end
	end
	return list[1], list
end

--- OPPORTUNITY DIAGNOSTICS (Phase 1 of the Opportunity System: visibility only; nothing here changes what the planner decides).
-- chooseAlsoDo already prices every candidate against the chosen route; these helpers only NAME what it computed.
Pl.FREE_SECONDS = 0.5        -- mirrors the 0.5 s "on the way" test addReasons already uses; a label boundary, not a new rule
Pl.OPP_CAP = 40              -- priced candidates kept in diag.opps.list (the cheapest first); the rest are counted. ~100 candidates are priced per recompute.
Pl.ON_THE_WAY_MAX = 4        -- opportunities carried in plan.onTheWay (those that clear the ALSO DO bars, best net first)
Pl.OPP_HUB_CAP = 5           -- off-route stops with 2+ actions priced as a whole (diagnostic only)

--- Where a candidate fits in the chosen route, from the insertion the planner already computed. Returns one of
--   DIRECTLY_ON_ROUTE   shares the first stop, or costs <= FREE_SECONDS extra
--   RECONNECTING_DETOUR inserted between two nodes of the route (the player leaves it and rejoins it)
--   AFTER_ROUTE         inserted after the last stop: no rejoining, the cost is the one-way trip
--   UNKNOWN             a leg could not be measured
-- (A "near route" label would need a distance threshold the planner does not have; the cost class carries that distinction.)
Pl.HELD_CAP = 20             -- held-back pickups listed in diag.held.list (the rest are counted)

--- Whether this character is known to be OFFERED the action. A database (QuestieDB / ATT) record says the quest exists somewhere; it is not client
-- evidence. OBSERVED only when Codex recorded a quest dialog (QUEST_DETAIL) for the quest; UNKNOWN otherwise (absence proves nothing); quests already
-- in the log are IN_LOG (the client itself holds them). Never derived from class / race / level rules.
function Pl.Actionability(a)
	if not a or a.kind ~= "ACCEPT" or not a.quest then return "NOT_APPLICABLE" end
	if ns.State and ns.State.ctx and ns.State.ctx.log and ns.State.ctx.log[a.quest] then return "IN_LOG" end
	-- the offered-quests probe (OfferProbe) has the say when it holds evidence for this quest: an offer withdrawn by a newer (stale) listing, or made by a different NPC than the quest's
	-- giver, is history, not proof that the giver offers it (0.8.5)
	local ev = Pl.OfferEvidence(a)
	if ev and (ev.kind == "SUPERSEDED" or ev.kind == "OBSERVED_ELSEWHERE") then return "UNKNOWN" end
	local items = type(ForeverCodexDB) == "table" and ForeverCodexDB.items or nil
	local seen = type(items) == "table" and type(items.rewards) == "table" and items.rewards[a.quest] or nil
	if type(seen) == "table" and seen.at == "QUEST_DETAIL" then return "OBSERVED" end
	-- the offered-quests probe (OfferProbe): the open offer dialog, or an available-quest list that carried the id
	if ev and ev.kind == "OBSERVED" then return "OBSERVED" end
	return "UNKNOWN"
end

--- The client evidence behind an actionability, for a pickup: { kind = "OBSERVED", via, npc } | { kind = "EMPTY_AT_NPC" | "NOT_LISTED_AT_NPC", npc, last } | nil.
-- The negative kinds are CONTEXTUAL (that NPC's dialog, at that time) and leave Pl.Actionability at UNKNOWN. Nothing here is a rule or changes a plan.
function Pl.OfferEvidence(a)
	if not a or a.kind ~= "ACCEPT" or not a.quest or not ns.OfferProbe then return nil end
	local view = R.Quest(a.quest)
	return ns.OfferProbe.OfferEvidence(a.quest, view and view.giverNpc, (view and view.giverName) or a.giver)
end

function Pl.RouteRelation(cost, same, afterLast)
	if same then return "DIRECTLY_ON_ROUTE" end
	if cost == nil then return "UNKNOWN" end
	if cost <= Pl.FREE_SECONDS then return "DIRECTLY_ON_ROUTE" end
	if afterLast then return "AFTER_ROUTE" end
	return "RECONNECTING_DETOUR"
end

--- Cost label for a priced candidate: FREE (same stop / ~no extra time), then EXPENSIVE (net <= 0 after paying for the time),
-- CHEAP (within the detour limit) or MODERATE (above it, still net positive). UNKNOWN when the cost could not be measured.
function Pl.CostClass(cost, same, net, detour)
	if same then return "FREE" end
	if cost == nil then return "UNKNOWN" end
	if cost <= Pl.FREE_SECONDS then return "FREE" end
	if net <= 0 then return "EXPENSIVE" end
	if cost <= detour then return "CHEAP" end
	return "MODERATE"
end

local DECISION_RANK = { ACCEPTED = 1, OUTRANKED = 2, TOO_FAR = 3, LOW_VALUE = 4, UNKNOWN_TRANSIT = 5 }

--- Stage 6: ALSO DO. Interruption cost = extra time to fit the action into the sequence (0 within the first stop).
-- Returns the chosen item and its cost (nil, nil when nothing qualifies).
local function chooseAlsoDo(S, seqStops, firstList, nowIt, inSeq)
	local ctx, diag, par, lam = S.ctx, S.diag, S.par, S.lam
	local nodes = {}
	if S.player then nodes[#nodes + 1] = S.player end
	for _, s in ipairs(seqStops) do nodes[#nodes + 1] = s.pos end
	local function interruption(it)
		local best, bestAt
		for i = 1, #nodes do
			local a = seconds(ctx, nodes[i], it.pos)
			if a == nil then return nil end
			local b = nodes[i + 1] and seconds(ctx, it.pos, nodes[i + 1]) or nil
			if nodes[i + 1] then
				local direct = seconds(ctx, nodes[i], nodes[i + 1])
				if b == nil or direct == nil then return nil end
				local extra = a + b - direct
				if extra < 0 then extra = 0 end
				if not best or extra < best then best, bestAt = extra, i end
			else
				if not best or a < best then best, bestAt = a, i end      -- after the last stop: just getting there
			end
		end
		return best or 0, bestAt           -- (bestAt: the node the item is inserted AFTER; diagnostics only)
	end
	-- diagnostics: a label for node i of the route polyline ("you" or the stop's id), and one record per priced candidate
	local offset = S.player and 1 or 0
	local function nodeLabel(i)
		if not nodes[i] then return nil end
		if S.player and i == 1 then return "you" end
		return seqStops[i - offset] and seqStops[i - offset].id or nil
	end
	local opps, counts = {}, { total = 0, class = {}, decision = {} }
	local function record(it, cost, at, same, net, decision)
		local cls = Pl.CostClass(cost, same, net or 0, par.detour)
		local a = it.a
		counts.total = counts.total + 1
		counts.class[cls] = (counts.class[cls] or 0) + 1
		counts.decision[decision] = (counts.decision[decision] or 0) + 1
		opps[#opps + 1] = { id = it.id, title = a.title, kind = a.kind, type = a.type, qid = (a.ref and a.ref.kind == "quest") and a.ref.id or nil,
			cost = cost, same = same or nil, from = at and nodeLabel(at) or nil, to = at and nodeLabel(at + 1) or nil,
			rel = Pl.RouteRelation(cost, same, at ~= nil and nodes[at + 1] == nil), cls = cls, net = net, val = it.val, dwell = it.dwell,
			stop = it.stop and it.stop.id or nil, stopSize = it.stop and #it.stop.items or nil, dec = decision,
			evidence = a.evidence, status = it.status, assumed = it.assumed or nil, conf = it.conf, item = it }
	end
	local also, alsoNet, alsoCost
	local function offer(it, cost, at, same)
		local net = it.val - lam * (cost + it.dwell)
		if cost > par.detour then
			diag.rejected[#diag.rejected + 1] = { id = it.id, code = "TOO_FAR", seconds = math.floor(cost + 0.5) }
			record(it, cost, at, same, net, "TOO_FAR")
		elseif net < par.alsoFloor then
			diag.rejected[#diag.rejected + 1] = { id = it.id, code = "LOW_VALUE", net = math.floor(net * 10) / 10 }
			record(it, cost, at, same, net, "LOW_VALUE")
		else
			record(it, cost, at, same, net, "OUTRANKED")        -- cleared both bars; ACCEPTED is set below for the one that won
			if not also or net > alsoNet or (net == alsoNet and it.id < also.id) then
				also, alsoNet, alsoCost = it, net, cost
			end
		end
	end
	for _, it in ipairs(firstList) do
		if it ~= nowIt then offer(it, 0, nil, true) end
	end
	for _, pool in ipairs({ S.items, S.extras }) do
		for _, it in ipairs(pool) do
			if not inSeq[it.id] then
				local cost, at = interruption(it)
				if cost == nil then
					diag.rejected[#diag.rejected + 1] = { id = it.id, code = "UNKNOWN_TRANSIT" }
					record(it, nil, nil, false, nil, "UNKNOWN_TRANSIT")
				else
					offer(it, cost, at, false)
				end
			end
		end
	end
	-- diagnostics only: the winner, the deterministic order (cheapest first), the cap, and the off-route stops priced as a whole
	for _, o in ipairs(opps) do
		if also and o.id == also.id then
			o.dec = "ACCEPTED"
			counts.decision.OUTRANKED = (counts.decision.OUTRANKED or 1) - 1
			counts.decision.ACCEPTED = 1
			if counts.decision.OUTRANKED == 0 then counts.decision.OUTRANKED = nil end
		end
	end
	-- PHASE B: every candidate that cleared BOTH ALSO DO bars (detour limit and net floor) is an on-the-way opportunity, best net first (the
	-- planner's own tie rule), so onTheWay[1] is exactly the ALSO DO. Nothing here changes what is chosen; the rest used to be dropped silently.
	local onTheWay = {}
	for _, o in ipairs(opps) do
		if o.dec == "ACCEPTED" or o.dec == "OUTRANKED" then onTheWay[#onTheWay + 1] = o end
	end
	table.sort(onTheWay, function(x, y)
		if x.net ~= y.net then return x.net > y.net end
		return x.id < y.id
	end)
	local carried = {}
	for n = 1, math.min(#onTheWay, Pl.ON_THE_WAY_MAX) do
		local o = onTheWay[n]
		local reason
		if o.cost <= Pl.FREE_SECONDS or o.same then reason = { code = (o.same and "SAME_STOP" or "ON_THE_WAY") }
		else reason = { code = "SMALL_DETOUR", seconds = math.floor(o.cost + 0.5) } end
		-- the normalised opportunity: the action itself plus what the route said about it. Actionability is the same honest UNKNOWN the report prints:
		-- a database record is not client evidence that this character is offered the quest (see Pl.Actionability).
		carried[n] = { id = o.id, action = o.item.a, cost = o.cost, relation = o.rel, costClass = o.cls, net = o.net, value = o.val, dwell = o.dwell,
			sameStop = o.same or false, stopId = o.stop, stopSize = o.stopSize, from = o.from, to = o.to, evidence = o.evidence, status = o.status,
			actionability = Pl.Actionability(o.item.a), offer = Pl.OfferEvidence(o.item.a), reason = reason, decision = o.dec }
	end
	S.onTheWay = carried
	diag.onTheWayTotal = #onTheWay
	table.sort(opps, function(x, y)
		if (x.cost == nil) ~= (y.cost == nil) then return x.cost ~= nil end
		if x.cost ~= y.cost then return x.cost < y.cost end
		return x.id < y.id
	end)
	local kept = {}
	for n = 1, math.min(#opps, Pl.OPP_CAP) do kept[n] = opps[n] end
	for _, o in ipairs(opps) do o.item = nil end
	local hubs, inRoute = {}, {}
	for _, st in ipairs(seqStops) do inRoute[st] = true end
	for _, st in ipairs(S.stops) do
		if not inRoute[st] and #st.items >= 2 then
			local cost = interruption(st)
			if cost ~= nil then
				local ids = {}
				for k, it in ipairs(st.items) do if k <= 6 then ids[k] = it.id end end
				hubs[#hubs + 1] = { stop = st.id, size = #st.items, ids = ids, cost = cost, val = st.val, dwell = st.dwell, net = st.val - lam * (cost + st.dwell) }
			end
		end
	end
	table.sort(hubs, function(x, y) if x.cost ~= y.cost then return x.cost < y.cost end return x.stop < y.stop end)
	while #hubs > Pl.OPP_HUB_CAP do hubs[#hubs] = nil end
	diag.opps = { list = kept, total = counts.total, class = counts.class, decision = counts.decision, cap = Pl.OPP_CAP, hubs = hubs,
		route = { stops = #seqStops, detour = par.detour, alsoFloor = par.alsoFloor, timeValue = lam } }
	return also, alsoCost, S.onTheWay
end

--- Stage 7: reason codes (data, not sentences).
local function addReasons(S, seqStops, firstList, nowIt, thenIt, also, alsoCost)
	local diag, par, ctx = S.diag, S.par, S.ctx
	local why = diag.reasons
	local function add(id, code, args)
		why[id] = why[id] or {}
		local r = { code = code }
		for k, v in pairs(args or {}) do r[k] = v end
		table.insert(why[id], r)
	end
	add(nowIt.id, "BEST_SEQUENCE", { stops = #seqStops })
	if #firstList > 1 then add(nowIt.id, "SAME_STOP", { count = #firstList }) end
	if nowIt.comps.chain then add(nowIt.id, "CHAIN_UNLOCK", {}) end
	if diag.routeZoneOnly then add(nowIt.id, "ROUTE_ZONE", {}) end
	if diag.localOnly then add(nowIt.id, "LOCAL_PROGRESS", {}) end
	if nowIt.comps.pinned then add(nowIt.id, "PLAYER_ADDED", {}) end
	if nowIt.comps.levelFit and nowIt.comps.levelFit >= 4 then add(nowIt.id, "LEVEL_FIT", {}) end
	if nowIt.a.kind ~= "TURN_IN" then
		for _, it in ipairs(S.items) do
			if it.a.kind == "TURN_IN" and it.id ~= nowIt.id then add(nowIt.id, "TURN_IN_WAITS", {}) break end
		end
	end
	if also then
		if alsoCost <= 0.5 then
			add(also.id, #firstList > 1 and also.stop == seqStops[1] and "SAME_STOP" or "ON_THE_WAY", {})
		else
			add(also.id, "SMALL_DETOUR", { seconds = math.floor(alsoCost + 0.5) })
		end
	end
	if thenIt then add(thenIt.id, "FOLLOWS", {}) end
	-- travel that contains work: the first stop lies (nearly) on the way to the second
	if S.player and seqStops[2] then
		local a, b2, direct = seconds(ctx, S.player, seqStops[1].pos), seconds(ctx, seqStops[1].pos, seqStops[2].pos), seconds(ctx, S.player, seqStops[2].pos)
		if a and b2 and direct then
			local extra = math.max(0, a + b2 - direct)
			if extra <= par.detour then add(nowIt.id, "ON_THE_WAY", { seconds = math.floor(extra + 0.5) }) end
		end
	end
end

--- Stage 8: the alternatives that lost (a few, for /codex diag), the nearest action for comparison, and the trace tail.
local function summarize(S, pick)
	local diag, stops, ctx = S.diag, S.stops, S.ctx
	local firsts = {}
	for f, seq in pairs(S.bestByFirst) do firsts[#firsts + 1] = { f = f, seq = seq } end
	table.sort(firsts, function(x, y) return better(x.seq, y.seq) end)
	diag.alternatives = {}
	for _, e in ipairs(firsts) do
		if #diag.alternatives < 3 and e.f ~= pick.stops[1] then
			local it = bestOf(stops[e.f])
			diag.alternatives[#diag.alternatives + 1] = { id = it.id, deficit = math.floor((pick.net - e.seq.net) * 10 + 0.5) / 10, unknownLegs = e.seq.unknown }
		end
	end
	-- the nearest located action, for comparison: the Planner is not "nearest first"
	local nearest, nd
	for _, it in ipairs(S.items) do
		local d = S.player and E.Distance(ctx, S.player, it.pos) or nil
		if d and (not nd or d < nd or (d == nd and it.id < nearest.id)) then nearest, nd = it, d end
	end
	diag.nearestId = nearest and nearest.id or nil
	if S.trace then
		table.sort(S.allSeqs, better)
		diag.sequenceList = {}
		for n = 1, math.min(#S.allSeqs, 40) do
			local q, ids = S.allSeqs[n], {}
			for k, i in ipairs(q.stops) do ids[k] = stops[i].id end
			diag.sequenceList[n] = { stops = ids, net = q.net, secs = q.secs, unknown = q.unknown }
		end
		-- the best sequence that STARTS with each stop (so a reviewer can see what the alternatives were worth)
		diag.bestByFirst = {}
		for f, q in pairs(S.bestByFirst) do diag.bestByFirst[stops[f].id] = { net = q.net, secs = q.secs, unknown = q.unknown } end
	end
end

--- NOW = a quest the player already has in this area, with no map location: "finish it here". No sequence, no ALSO DO, no THEN.
function Pl.StayLocal(S, plan, a)
	local diag = S.diag
	diag.reason, diag.localWork, diag.sequence = "LOCAL_WORK", true, {}
	diag.net, diag.seconds, diag.unknownLegs = 0, 0, 0
	diag.reasons[a.id] = { { code = "LOCAL_PROGRESS" } }
	diag.nowId = a.id
	plan.now = a
	return plan
end

--- plan = Planner.Compute(ctx, c, opts)
--   c    the result of Engine.Candidates(ctx): { env, candidates, inProgress, hints }
--   opts { prevNowId = string }  the previous plan's NOW, so a near-tie does not flip it
--        { trace = true }        also record, in plan.diag, the per-action facts, the stops and every scored sequence
--                                (for the evaluation harness; changes nothing about the decision, costs nothing when off)
function Pl.Compute(ctx, c, opts)
	opts = opts or {}
	if ns.OfferProbe then ns.OfferProbe.SetContext(ctx) end        -- the progression stamp for offer evidence is read from THIS context
	local env = c.env
	local par = Pl.Params(env.strategy and env.strategy.key)
	local diag = { strategy = env.strategy and env.strategy.key, filtered = {}, warnings = {}, reasons = {}, rejected = {}, basis =
		"value: policy points (not XP); walking: distance/RUN_SPEED (estimated); doing: policy seconds" }
	local plan = { reminders = {}, diag = diag }
	local S = { ctx = ctx, env = env, par = par, lam = par.timeValue, diag = diag, trace = opts.trace }
	S.judgement = {}
	diag.funnel = { judged = 0, bands = {}, excluded = 0, penalized = 0, boosted = 0, list = {} }
	S.goal = Pl.PROGRESSION and ns.Progression and ns.Progression.Goal(ctx) or nil
	diag.goal = S.goal and { kind = S.goal.kind, dungeons = S.goal.dungeons, count = S.goal.count, inside = S.goal.inside } or nil
	S.player = env.player and { map = env.player.map, x = env.player.x, y = env.player.y, world = env.player.world } or nil
	if not S.player then diag.warnings[#diag.warnings + 1] = "no player position: the first leg is free" end

	gather(S, c)
	plan.reminders = S.reminders
	makeStops(S)
	if S.trace then recordTrace(S) end
	if #S.stops == 0 then
		if Pl.LOCAL_FIRST and S.localWork[1] then return Pl.StayLocal(S, plan, S.localWork[1]) end
		diag.reason = #S.reminders > 0 and "NO_LOCATED_ACTION" or "NO_CANDIDATES"
		return plan
	end
	rankStops(S)
	local pick = searchSequences(S, opts.prevNowId)
	-- started work right here is done before leaving the area (see WORK_HERE)
	if Pl.WORK_HERE and not diag.pinnedFirst and S.player and S.player.map then
		local first = S.stops[pick.stops[1]]
		local inChosenZone0 = env.routeMap ~= nil and first.pos.map == env.routeMap
		local dFirst = E.Distance(ctx, S.player, first.pos)
		local leaving = dFirst == nil or dFirst > Pl.WORK_LEAVE_YD or first.pos.map ~= S.player.map
		if leaving and not inChosenZone0 then
			local alt
			for f, seq in pairs(S.bestByFirst) do
				local st = S.stops[f]
				if hasKind(st, "OBJECTIVE") and st.pos.map == S.player.map then
					local d = E.Distance(ctx, S.player, st.pos)
					if d and d <= Pl.WORK_HERE_YD and better(seq, alt) then alt = seq end
				end
			end
			if alt then
				pick = alt
				diag.workHere = true
			end
		end
	end
	-- a finished quest is not automatically the thing to do next: with work underway here, a hand-in that is not close waits (see DEFER_TURN_INS)
	local ql = env.questLog
	local slotPressure = ql and ql.free ~= nil and ql.free <= Pl.SLOT_PRESSURE_FREE
	if slotPressure then diag.slotPressure = true end
	if Pl.DEFER_TURN_INS and not slotPressure and not diag.pinnedFirst and S.player and S.player.map then
		local first = S.stops[pick.stops[1]]
		-- a hand-in that OPENS a quest right there (the chain credit the planner already prices) changes the route: it is not left waiting behind work elsewhere
		local opens = false
		for _, it in ipairs(first.items) do if it.a.kind == "TURN_IN" and it.comps and it.comps.chain then opens = true end end
		if opens then diag.handInOpens = true end
		if hasHandIn(first) and not hasKind(first, "OBJECTIVE") and not opens then
			local d = E.Distance(ctx, S.player, first.pos)
			if d and d > Pl.DEFER_NEAR_YD then
				local alt
				for f, seq in pairs(S.bestByFirst) do
					local st = S.stops[f]
					if hasKind(st, "OBJECTIVE") and not hasHandIn(st) and st.pos.map == S.player.map and better(seq, alt) then alt = seq end
				end
				-- how many hand-ins this trip would clear: the first stop's, plus the stops right behind it that are a short walk apart
				local batch, prev = 0, first
				for _, i in ipairs(pick.stops) do
					local st = S.stops[i]
					if not hasHandIn(st) or hasKind(st, "OBJECTIVE") then break end
					if st ~= first then
						local gap = E.Distance(ctx, prev.pos, st.pos)
						if not gap or gap > Pl.BATCH_YD then break end
					end
					for _, it in ipairs(st.items) do if it.a.kind == "TURN_IN" then batch = batch + 1 end end
					prev = st
				end
				local batched = batch >= Pl.BATCH_MIN
				-- on the way to the work: the hand-in costs at most ON_ROUTE_YD of extra walking
				local onRoute = false
				if alt then
					local w = S.stops[alt.stops[1]]
					local direct, leg1, leg2 = E.Distance(ctx, S.player, w.pos), d, E.Distance(ctx, first.pos, w.pos)
					onRoute = direct ~= nil and leg2 ~= nil and leg1 + leg2 - direct <= Pl.ON_ROUTE_YD
				end
				if batched then diag.handInBatched = true end
				if onRoute then diag.handInOnRoute = true end
				if alt and not batched and not onRoute then
					pick = alt
					diag.deferredTurnIn = true
				elseif alt or batched then
					-- keep the hand-in: it is on the route to the work, or it is a batch worth the trip
				else
					local started
					for _, a in ipairs(S.localWork) do
						local os = a.objectiveState
						if os and os.known then
							for _, o in ipairs(os.list) do
								if o.finished or (type(o.have) == "number" and o.have > 0) then started = a break end
							end
						end
						if started then break end
					end
					if started then
						diag.deferredTurnIn = true
						return Pl.StayLocal(S, plan, started)
					end
				end
			end
		end
	end
	-- AVAILABLE IS NOT THE SAME AS BEST RIGHT NOW. A new pickup that is not close, while objective work of the quests already in the log is waiting on this map, does not pull the player away
	-- from that cluster: finish what is underway first (the pickup stays a candidate and can still be an ALSO DO). It does not wait when it costs next to nothing on the way to that work.
	if Pl.DEFER_PICKUPS and not diag.pinnedFirst and S.player and S.player.map then
		local first = S.stops[pick.stops[1]]
		local onlyPickups = #first.items > 0
		for _, it in ipairs(first.items) do if it.a.kind ~= "ACCEPT" or it.a.pinned then onlyPickups = false end end
		local inZone = env.routeMap ~= nil and first.pos.map == env.routeMap
		if onlyPickups and not inZone then
			local d = E.Distance(ctx, S.player, first.pos)
			if d == nil or d > Pl.DEFER_NEAR_YD or first.pos.map ~= S.player.map then
				local alt
				for f, seq in pairs(S.bestByFirst) do
					local st = S.stops[f]
					if hasKind(st, "OBJECTIVE") and not hasHandIn(st) and st.pos.map == S.player.map then
						local dw = E.Distance(ctx, S.player, st.pos)
						if dw and dw <= Pl.PICKUP_DEFER_RANGE_YD and better(seq, alt) then alt = seq end
					end
				end
				if alt then
					local w = S.stops[alt.stops[1]]
					local direct, leg1, leg2 = E.Distance(ctx, S.player, w.pos), d, E.Distance(ctx, first.pos, w.pos)
					local onRoute = direct ~= nil and leg1 ~= nil and leg2 ~= nil and leg1 + leg2 - direct <= Pl.ON_ROUTE_YD
					if not onRoute then
						pick = alt
						diag.deferredPickup = true
					end
				end
			end
		end
	end
	-- work already underway in this area comes before a trip somewhere else (a route zone the player chose, or a quest they added, still wins)
	if Pl.LOCAL_FIRST and S.localWork[1] and not diag.pinnedFirst and S.player and S.stops[pick.stops[1]].pos.map ~= S.player.map
		and not (env.routeMap ~= nil and S.stops[pick.stops[1]].pos.map == env.routeMap) then
		return Pl.StayLocal(S, plan, S.localWork[1])
	end
	-- Reachable only through a leg we cannot measure, and not worth its (charged) time: do not send the player there on the
	-- strength of data that may be unverified. A route zone the player chose, or a quest they added, is their call and stays.
	local inChosenZone = env.routeMap ~= nil and S.stops[pick.stops[1]].pos.map == env.routeMap
	if pick.unknown > 0 and pick.net < 0 and not inChosenZone and not diag.pinnedFirst then
		diag.reason = "ONLY_DISTANT_UNMEASURED"
		diag.net, diag.seconds, diag.unknownLegs, diag.sequence = pick.net, pick.secs, pick.unknown, {}
		diag.nowId = nil
		diag.unmeasuredNet = pick.net
		return plan
	end
	diag.net, diag.seconds, diag.unknownLegs = pick.net, pick.secs, pick.unknown
	local seqStops, seqIds, inSeq = {}, {}, {}
	for n, i in ipairs(pick.stops) do
		seqStops[n] = S.stops[i]
		seqIds[n] = S.stops[i].id
		for _, it in ipairs(S.stops[i].items) do inSeq[it.id] = n end
	end
	diag.sequence = seqIds

	-- 5. NOW (first stop) and THEN (second stop)
	local nowIt, firstList = bestOf(seqStops[1], opts.prevNowId)
	plan.now = nowIt.a
	local thenIt = seqStops[2] and bestOf(seqStops[2]) or nil
	plan.thenAction = thenIt and thenIt.a or nil

	local also, alsoCost, onTheWay = chooseAlsoDo(S, seqStops, firstList, nowIt, inSeq)
	plan.alsoDo = also and also.a or nil
	plan.onTheWay = onTheWay or {}
	diag.interruption = alsoCost and math.floor(alsoCost * 10 + 0.5) / 10 or nil
	table.sort(diag.rejected, function(x, y)
		if x.code ~= y.code then return x.code < y.code end
		return x.id < y.id
	end)
	while #diag.rejected > 6 do diag.rejected[#diag.rejected] = nil end

	addReasons(S, seqStops, firstList, nowIt, thenIt, also, alsoCost)
	summarize(S, pick)
	diag.nowJudgement = S.judgement and S.judgement[plan.now.id] or nil
	diag.nowId, diag.alsoDoId, diag.thenId = plan.now.id, plan.alsoDo and plan.alsoDo.id or nil, plan.thenAction and plan.thenAction.id or nil
	return plan
end
