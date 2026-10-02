-- ForeverCodex.Overlap: the "ALSO COMPLETE THIS" card: other unfinished quest objectives that can be progressed while doing NOW.
--
-- It is NOT a list of everything nearby. It answers: "what else can I knock out while I'm already here?" and is built from three facts
-- Codex already has, with nothing invented:
--   * the quest log's own objective counts (have / need) for quests the player already has
--   * the quest's zone (QuestieDB / ATT), and, only where a pack supplies them, objective coordinates
--   * what NOW is and where it is
-- A quest overlaps NOW when NOW is an objective (you are out working, not on a hand-in trip) and
--   * its objective spot is known and within OVERLAP_YD of NOW's spot (or of you, when NOW has no spot): same patch of ground; or
--   * its spot is not known but its ZONE is the zone you are working in. That is as precise as the data goes: Codex has no spawn
--     points for most objectives, so "same zone" is a weaker claim than "same spot", and nothing here says otherwise.
-- Quests with no known zone are left out (unknown is never "compatible"). Finished objectives drop out; a quest with nothing left
-- unfinished is not listed. The planner's own ALSO DO (a pickup or hand-in at the same stop, already checked for a small detour) is
-- included as a plain line. Pure: no frames, no client calls except reading the plan and context it is given.
--
--   Overlap.List(plan, ctx) -> { { kind = "objective", title, objectives = { {text, have, need}, ... }, fraction }
--                                | { kind = "action", title, where }, ... }      (at most MAX_QUESTS objective quests + the ALSO DO line)

local addonName, ns = ...
local E = ns.Engine
local Pl = ns.Planner

local Ov = {}
ns.Overlap = Ov

Ov.MAX_QUESTS = 3
Ov.ALSO_ACTION_YD = 300        -- a pickup is only 'also' when it is a short walk from the player; a hand-in is never listed here (READY TO TURN IN has it)
Ov.OVERLAP_YD = 300
Ov.NOW_HANDIN_YD = 150         -- when NOW is a hand-in this close, nearby unfinished objectives still count as 'also complete this'

--- "here" / "nearby" / "350 yd": the short distance text of the tracker (nil when the distance is unknown or not on this continent).
function Ov.ShortWhere(d)
	if type(d) ~= "number" or d >= E.DIFFERENT_CONTINENT then return nil end
	if d < 30 then return "here" end
	if d < 150 then return "nearby" end
	return string.format("%d yd", math.floor(d / 50 + 0.5) * 50)
end

local function distanceTo(a, ctx)
	local pos = Pl.Locate(a)
	local loc = ctx and ctx.loc
	if not (pos and loc and loc.available) then return nil end
	return E.Distance(ctx, { map = loc.map, x = loc.x, y = loc.y, world = loc.world or false }, pos)
end

local function suffix(ctx, quest) return ns.Dungeons and ns.Dungeons.Suffix(ctx, quest) or "" end
local function inDungeonCard(ctx, quest) return ns.Dungeons ~= nil and ns.Dungeons.IsDungeon(ctx, quest) end

local function unfinishedOf(a)
	local out = {}
	local os = a.objectiveState
	if not (os and os.known) then return out end
	for _, o in ipairs(os.list) do
		if not o.finished then out[#out + 1] = { text = o.text, have = o.have, need = o.need } end
	end
	return out
end
Ov.Unfinished = unfinishedOf

--- 0..1: how far along a quest's objectives are (finished ones count as done; unknown counts as nothing).
local function fractionOf(a)
	local os = a.objectiveState
	if not (os and os.known) or #os.list == 0 then return 0 end
	local sum = 0
	for _, o in ipairs(os.list) do
		if o.finished then sum = sum + 1
		elseif type(o.have) == "number" and type(o.need) == "number" and o.need > 0 then sum = sum + math.min(1, o.have / o.need) end
	end
	return sum / #os.list
end

local function questName(a)
	if a.name and a.name ~= "" then return a.name end
	local t = a.title and a.title:match("^[^:]*:%s*(.+)$")
	return t or "a quest"
end

--- Compatible with NOW? ref = where the work is (NOW's spot, else the player); refMap = the map it is on.
local function compatible(a, ctx, ref, refMap)
	local pos = Pl.Locate(a)
	if pos then
		if not ref then return false end
		local d = E.Distance(ctx, ref, pos)
		return d ~= nil and d < E.DIFFERENT_CONTINENT and d <= Ov.OVERLAP_YD
	end
	return a.areaMap ~= nil and refMap ~= nil and a.areaMap == refMap
end

function Ov.List(plan, ctx)
	local out = {}
	if not plan or not plan.now then return out end
	local now = plan.now
	local P = ns.Prefs
	local seen = {}
	if now.quest then seen[now.quest] = true end
	local nowD = now.kind == "TURN_IN" and distanceTo(now, ctx) or nil
	if now.kind == "OBJECTIVE" or (nowD ~= nil and nowD <= Ov.NOW_HANDIN_YD) then
		local loc = ctx and ctx.loc
		local me = loc and loc.available and { map = loc.map, x = loc.x, y = loc.y, world = loc.world or false } or nil
		local nowPos = Pl.Locate(now)
		-- a close hand-in is not where the work is: measure from the player
		local ref = (now.kind == "TURN_IN" and me) or nowPos or me
		local refMap = (now.kind == "TURN_IN" and me and me.map) or (nowPos and nowPos.map) or (me and me.map) or nil
		local pool = {}
		for _, a in ipairs(plan.objectives or {}) do
			if a.kind == "OBJECTIVE" and a.quest and not seen[a.quest] and not (P and a.skipKey and P.IsSkipped(a.skipKey)) and not a.unknown and not inDungeonCard(ctx, a.quest) then pool[#pool + 1] = a end
		end
		local cand = {}
		for _, a in ipairs(pool) do
			local todo = unfinishedOf(a)
			if #todo > 0 and compatible(a, ctx, ref, refMap) then cand[#cand + 1] = { a = a, todo = todo, fraction = fractionOf(a) } end
		end
		-- closest to done first (the quickest wins), then by id so the order is stable
		table.sort(cand, function(x, y)
			if x.fraction ~= y.fraction then return x.fraction > y.fraction end
			return x.a.id < y.a.id
		end)
		for _, c in ipairs(cand) do
			if #out >= Ov.MAX_QUESTS then break end
			if not seen[c.a.quest] then
				seen[c.a.quest] = true
				out[#out + 1] = { kind = "objective", title = questName(c.a) .. suffix(ctx, c.a.quest), objectives = c.todo, fraction = c.fraction, quest = c.a.quest }
			end
		end
	end
	-- the planner's own ALSO DO: a pickup or hand-in at the same stop, or a located objective, already checked for a small detour
	local also = plan.alsoDo
	if also and not (also.quest and seen[also.quest]) and not inDungeonCard(ctx, also.quest) then
		if also.kind == "OBJECTIVE" and #unfinishedOf(also) > 0 then
			out[#out + 1] = { kind = "objective", title = questName(also) .. suffix(ctx, also.quest), objectives = unfinishedOf(also), fraction = fractionOf(also), quest = also.quest }
		elseif also.type ~= "FLIGHT" and also.kind ~= "TURN_IN" then
			local d = distanceTo(also, ctx)
			if d == nil or d <= Ov.ALSO_ACTION_YD then
				local it = ns.Presenter.Describe(also, plan, ctx, "diamond")
				out[#out + 1] = { kind = "action", title = it.title, where = Ov.ShortWhere(d), quest = also.quest }
			end
		end
	end
	return out
end

-- ---------------------------------------------------------------- READY TO TURN IN

Ov.MAX_READY = 12

--- Finished quests that can be handed in and are NOT the current NOW: { { title = quest name, who = turn-in NPC or nil, where = "Nearby" ... or nil, quest }, ... },
-- nearest first (unknown distances last). A finished quest is a pending hand-in, not an instruction: it is listed here until the planner makes it NOW.
function Ov.Ready(plan, ctx)
	local out = {}
	if not plan then return out end
	local P = ns.Prefs
	local nowId = plan.now and plan.now.id
	for _, a in ipairs(plan.turnIns or {}) do
		if a.id ~= nowId and not (P and a.skipKey and P.IsSkipped(a.skipKey)) and not inDungeonCard(ctx, a.quest) then
			local d = distanceTo(a, ctx)
			if d and d >= E.DIFFERENT_CONTINENT then d = nil end
			local short = Ov.ShortWhere(d)
			out[#out + 1] = { title = questName(a) .. suffix(ctx, a.quest), who = a.giver, where = short, quest = a.quest, dist = d }
		end
	end
	table.sort(out, function(x, y)
		if (x.dist ~= nil) ~= (y.dist ~= nil) then return x.dist ~= nil end
		if x.dist and y.dist and x.dist ~= y.dist then return x.dist < y.dist end
		return x.title < y.title
	end)
	return out
end
