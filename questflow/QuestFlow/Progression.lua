-- ForeverCodex.Progression: "is this quest worth recommending to THIS player right now?", kept apart from "is it available?".
--
-- THE FUNNEL (each stage answers one question; a later stage never re-answers an earlier one):
--   1 AVAILABILITY  can the player take it?           Providers/Quest.lua + OfferProbe: client offer evidence, prerequisites, log, quest cap. UNKNOWN stays UNKNOWN.
--   2 ELIGIBILITY   may it be considered at all?      Providers/Quest.lua Eligibility: faction / class / required level / repeatable / seasonal (unless the player opted in).
--   3 CLASSIFICATION what kind of quest is it for me? THIS FILE: the level band (current / low / gray / above), seasonal, dungeon, chain position.
--   4 RELEVANCE     does it serve what the player is doing? THIS FILE: the current goal (a dungeon the quest log points at) and the quest chains that lead to it or to
--                   a quest the player holds.
--   5 VALUE         is it worth the time?              Planner.valueOf (policy points) scaled by the classification multiplier below.
--   6 PRIORITY      what should be done next?          Planner sequencing: value minus the cost of time and travel.
-- "Technically available" is NOT "recommended": an available quest can be rejected at stage 3 or 4, and the reason is recorded (Pg.Judge returns it; the report prints it).
--
-- WHAT COUNTS AS WHAT (design values for WoW Forever; named so they can be tuned, and each is a judgement, not a game fact):
--   level band    from the QUEST level (QuestieDB's questLevel) and the player's level: gap = player - quest.
--                 CURRENT  gap <= LOW_FROM - 1            normal (a quest up to a few levels under you is ordinary leveling)
--                 LOW      LOW_FROM <= gap <= green range  slightly below: a heavy discount, still allowed on its own merit
--                 GRAY     gap > green range              the game's own "trivial" band: excluded unless it has a REASON
--                 ABOVE    quest level >= player + ABOVE_FROM   penalised; ABOVE_FAR (>= ABOVE_FAR_FROM) excluded unless it has a REASON
--                 UNKNOWN  only a REQUIRED level is known (ATT): no band is invented, the value is not changed, and the report says so
--                 The green range is the client's own GetQuestGreenRange() when it answers (probed, never assumed), else GREEN_DEFAULT.
--   a REASON      the only things that let a GRAY / ABOVE_FAR / (with a goal) LOW quest through:
--                   PINNED          the player added it
--                   DUNGEON_QUEST   the game tags it as a dungeon quest
--                   LEADS_TO_LOG    a quest within CHAIN_DEPTH steps after it is in the player's log
--                   LEADS_TO_DUNGEON a quest within CHAIN_DEPTH steps after it is a dungeon quest
--                   LEADS_TO_FIT    a quest within CHAIN_DEPTH steps after it is in the CURRENT band (it is a required prerequisite of appropriate content)
--   the GOAL      derived ONLY from evidence: dungeon quests in the player's log, as the game tags them (Dungeons.List). With a goal, the dungeon's own objectives
--                 and hand-ins and the quests that lead to it are worth more, and a LOW quest needs a reason too. No tag from the client = no goal (said in the report).
--   seasonal      QuestieDB's negative quest sort, from a fixed list of the game's holiday / world-event categories (QuestieBridge EVENT_SORTS). Seasonal quests are not
--                 in the normal pool (Eligibility) unless the player opts in; even then they are only routed on a client offer. Nothing else classifies a quest as seasonal.
-- Nothing here names a quest. Nothing here changes what is available.

local addonName, ns = ...
local R = ns.Registry

local Pg = {}
ns.Progression = Pg

Pg.GREEN_DEFAULT = 8            -- levels below the player at which a quest turns gray, when the client does not say
Pg.LOW_FROM = 6                 -- gap at which a quest is "low" (below this it is ordinary)
Pg.ABOVE_FROM = 5               -- quest levels over the player's at which a quest is "above"
Pg.ABOVE_FAR_FROM = 8
Pg.CHAIN_DEPTH = 3
Pg.FIT_GAP = 3                  -- a chain successor counts as "fitting" only this close to the player (a weak fit is not a reason)
Pg.FIT_MULT = 0.7               -- a quest that survives only because it leads to a fitting quest is worth less than the fitting quest
Pg.MULT = { CURRENT = 1, LOW = 0.5, GRAY = 0.15, ABOVE = 0.6, ABOVE_FAR = 0.3, UNKNOWN = 1 }
Pg.GOAL_BOOST = 2.5             -- value multiplier for the goal's own objectives and hand-ins
Pg.GOAL_CHAIN_BOOST = 2         -- ... and for the quests that lead to them
Pg.GRAY_IN_LOG_MULT = 0.5       -- objectives of a gray quest the player already holds: finishing it is cheap but earns little (its hand-in is never discounted)
Pg.LIST_CAP = 12

local green = { value = nil, source = "default" }
--- The green range and where it came from ("client" when GetQuestGreenRange answered, else "default").
function Pg.GreenRange()
	local f = _G.GetQuestGreenRange
	if type(f) == "function" then
		local ok, v = pcall(f)
		if ok and type(v) == "number" and v >= 1 and v <= 30 then green.value, green.source = v, "client" return v, "client" end
		green.source = ok and "default (client answered nothing usable)" or "default (client call failed)"
	else
		green.source = "default (GetQuestGreenRange absent)"
	end
	return Pg.GREEN_DEFAULT, green.source
end

--- { band, gap, basis, levelKnown }: how this quest's level compares with the player's.
function Pg.Band(a, playerLevel)
	if not playerLevel then return { band = "UNKNOWN", basis = "player level unknown" } end
	local q = a.level
	if type(q) ~= "number" then
		return { band = "UNKNOWN", basis = a.reqLevel and ("only a required level (" .. a.reqLevel .. ") is known") or "no level known" }
	end
	local gap = playerLevel - q
	local g = Pg.GreenRange()
	local band
	if gap > g then band = "GRAY"
	elseif gap >= Pg.LOW_FROM then band = "LOW"
	elseif -gap >= Pg.ABOVE_FAR_FROM then band = "ABOVE_FAR"
	elseif -gap >= Pg.ABOVE_FROM then band = "ABOVE"
	else band = "CURRENT" end
	return { band = band, gap = gap, level = q, basis = "quest level " .. q, levelKnown = true }
end

-- ---------------------------------------------------------------- the goal

--- The player's current goal, from evidence only: { kind = "DUNGEON", dungeons = { names }, quests = { [id] = true }, count, inside } or nil.
function Pg.Goal(ctx)
	if not (ns.Dungeons and ctx and ctx.log) then return nil end
	local ok, groups = pcall(ns.Dungeons.List, ctx)
	if not ok or #groups == 0 then return nil end
	local goal = { kind = "DUNGEON", dungeons = {}, quests = {}, count = 0, inside = false }
	for _, g in ipairs(groups) do
		goal.dungeons[#goal.dungeons + 1] = g.name
		for _, q in ipairs(g.quests) do
			goal.quests[q.quest] = true
			goal.count = goal.count + 1
			if ns.Dungeons.PlayerInside(ctx, q.quest) then goal.inside = true end
		end
	end
	return goal
end

-- ---------------------------------------------------------------- reasons

local function chainReasons(a, ctx, band)
	local out = {}
	if not (a.quest and ns.Planner and ns.Planner.Unlocks) then return out end
	local seen, frontier = { [a.quest] = true }, { a.quest }
	for depth = 1, Pg.CHAIN_DEPTH do
		local nextFrontier = {}
		for _, id in ipairs(frontier) do
			for _, sid in ipairs(ns.Planner.Unlocks(id)) do
				if not seen[sid] then
					seen[sid] = true
					nextFrontier[#nextFrontier + 1] = sid
					if ctx.log and ctx.log[sid] then out.LEADS_TO_LOG = sid end
					if ns.Dungeons and ns.Dungeons.IsDungeon(ctx, sid) then out.LEADS_TO_DUNGEON = sid end
					local v = R.Quest(sid)
					if v and not v.event and not v.repeatable and not ctx.isCompleted(sid) then
						local b = Pg.Band({ level = v.level, reqLevel = v.req }, ctx.char.level)
						if b.band == "CURRENT" and b.gap and b.gap <= Pg.FIT_GAP then out.LEADS_TO_FIT = out.LEADS_TO_FIT or sid end
					end
				end
			end
		end
		frontier = nextFrontier
	end
	return out
end

-- ---------------------------------------------------------------- judging one action

--- Judges one planner action. Returns
---   { verdict = "NORMAL" | "PENALIZED" | "EXCLUDED" | "BOOSTED", mult, band, gap, basis, reasons = { code, ... }, why = code (when not NORMAL), goal = bool }
-- ACCEPT actions can be EXCLUDED; an OBJECTIVE / TURN_IN of a quest the player already holds is only ever scaled (the player chose to take it).
function Pg.Judge(a, ctx, goal)
	local j = { verdict = "NORMAL", mult = 1, reasons = {} }
	if a.type ~= "QUEST" or not a.quest then return j end
	local b = Pg.Band(a, ctx.char and ctx.char.level)
	j.band, j.gap, j.basis = b.band, b.gap, b.basis
	if a.pinned then j.reasons[#j.reasons + 1] = "PINNED" end
	local inGoal = goal and goal.quests[a.quest] == true
	if inGoal then j.reasons[#j.reasons + 1] = "GOAL_QUEST" end
	local mult = Pg.MULT[b.band] or 1
	if a.kind ~= "ACCEPT" then
		-- a quest already in the log: never excluded; a gray one's objectives earn little, its hand-in is full value
		if b.band == "GRAY" and a.kind == "OBJECTIVE" and not inGoal then mult = Pg.GRAY_IN_LOG_MULT else mult = 1 end
		if inGoal then mult = mult * Pg.GOAL_BOOST end
		j.mult = mult
		if mult < 1 then j.verdict, j.why = "PENALIZED", "LOW_VALUE_IN_LOG" elseif mult > 1 then j.verdict = "BOOSTED" end
		return j
	end
	-- a pickup: the reasons that can save it
	local needReason = b.band == "GRAY" or b.band == "ABOVE_FAR" or (goal and b.band == "LOW")
	local isDungeon = ns.Dungeons and ns.Dungeons.IsDungeon(ctx, a.quest)
	if isDungeon then j.reasons[#j.reasons + 1] = "DUNGEON_QUEST" end
	local chain = (needReason or goal) and chainReasons(a, ctx, b.band) or {}
	for _, code in ipairs({ "LEADS_TO_LOG", "LEADS_TO_DUNGEON", "LEADS_TO_FIT" }) do
		if chain[code] then j.reasons[#j.reasons + 1] = code end
	end
	local reasoned = #j.reasons > 0
	if needReason and not reasoned then
		j.verdict, j.mult = "EXCLUDED", 0
		j.why = (b.band == "GRAY" and "GRAY") or (b.band == "ABOVE_FAR" and "TOO_HIGH") or "LOW_WITH_GOAL"
		return j
	end
	-- a quest that survives only because of a reason is valued by that reason, not by its poor level band
	if needReason and reasoned then
		local strong = a.pinned or isDungeon or chain.LEADS_TO_LOG or chain.LEADS_TO_DUNGEON or inGoal
		mult = strong and 1 or Pg.FIT_MULT
	end
	if goal and (chain.LEADS_TO_DUNGEON or isDungeon) then mult = math.max(mult, 1) * Pg.GOAL_CHAIN_BOOST end
	j.mult = mult
	if mult < 1 then j.verdict, j.why = "PENALIZED", b.band elseif mult > 1 then j.verdict = "BOOSTED" end
	return j
end

-- ---------------------------------------------------------------- the report

--- Lines for /qflow report: the funnel, with the reason each quest was rejected, penalised or boosted. `diag` is the planner's diag.
function Pg.ReportLines(ctx, plan)
	local L = {}
	local d = plan and plan.diag or {}
	local f = d.funnel
	local g, src = Pg.GreenRange()
	L[#L + 1] = string.format("PLANNER FUNNEL (availability -> eligibility -> classification -> relevance -> value -> priority). Green range %d (%s); level bands: low from %d below, gray over %d below, above from %d over.",
		g, src, Pg.LOW_FROM, g, Pg.ABOVE_FROM)
	local seasonal = ns.Prefs and ns.Prefs.IncludeSeasonal and ns.Prefs.IncludeSeasonal()
	L[#L + 1] = "  Seasonal / event quests: " .. (seasonal and "INCLUDED by choice (still only routed on a client offer)" or "not in the normal pool") ..
		"; classified only by QuestieDB's holiday / world-event quest categories (nothing else identifies them on this client)."
	if d.goal then
		L[#L + 1] = string.format("  Goal: dungeon %s (%d dungeon quest(s) in your log%s).", table.concat(d.goal.dungeons, ", "), d.goal.count, d.goal.inside and ", you are inside" or "")
	else
		L[#L + 1] = "  Goal: none known (no dungeon quest in your log, as the game tags them" .. ((ctx and ctx.questTag) and "" or "; the client's quest-tag API did not answer") .. ")."
	end
	local av = d.availability
	if av then
		local held = d.held and d.held.n or 0
		L[#L + 1] = string.format("  Pickup availability: AVAILABLE (client offered) %d | UNKNOWN (no client offer evidence) %d, of which OPTIONAL (listed, not a committed step) %d | HELD (fresh not-offered evidence) %d.", av.available, av.unknown, av.optional, held)
		L[#L + 1] = "  Policy: a pickup becomes NOW / THEN only when the game itself offered it; an unknown one stays OPTIONAL (an ALSO DO on the way, or listed); a fresh not-offered answer holds it back; quests in your log are not pickups."
		local shown = 0
		for _, e in ipairs(d.possible and d.possible.list or {}) do
			if e.why == "UNKNOWN_AVAILABILITY" and shown < 5 then
				shown = shown + 1
				L[#L + 1] = string.format("    OPTIONAL: unknown availability: %s%s", e.title or e.id, e.giver and (" (giver " .. e.giver .. ", no offer recorded)") or "")
			end
		end
	end
	if f then
		local parts = {}
		for _, b in ipairs({ "CURRENT", "LOW", "GRAY", "ABOVE", "ABOVE_FAR", "UNKNOWN" }) do if (f.bands[b] or 0) > 0 then parts[#parts + 1] = b .. "=" .. f.bands[b] end end
		L[#L + 1] = string.format("  Judged %d action(s): bands %s; boosted %d, penalised %d, excluded %d.", f.judged, #parts > 0 and table.concat(parts, ", ") or "none", f.boosted, f.penalized, f.excluded)
		for _, e in ipairs(f.list) do
			L[#L + 1] = string.format("    %s %s (%s): %s%s", e.verdict, e.title or e.id, e.band or "?", e.why or "-", #e.reasons > 0 and ("; reasons " .. table.concat(e.reasons, ",")) or "")
		end
	else
		L[#L + 1] = "  No planner funnel recorded yet (the planner is off or has not run)."
	end
	local function stateText(a)
		if not a or a.kind ~= "ACCEPT" then return nil end
		if a.pinned then return "ADDED by you (your choice, not an availability claim)" end
		local st = ns.Planner.OfferState(a)
		if st == "OBSERVED" then return "AVAILABLE: client offered" end
		if st == "NOT_OFFERED" then return "HELD: fresh not-offered evidence" end
		return "UNKNOWN: no client offer evidence"
	end
	for _, role in ipairs({ { "NOW", plan and plan.now }, { "THEN", plan and plan.thenAction }, { "ALSO DO", plan and plan.alsoDo } }) do
		local t = stateText(role[2])
		if t then L[#L + 1] = string.format("  %s is the pickup %s: %s.", role[1], role[2].title or role[2].id, t) end
	end
	local nowJ = d.nowJudgement
	if plan and plan.now then
		L[#L + 1] = string.format("  NOW is %s: band %s (%s), verdict %s%s.", plan.now.title or plan.now.id, nowJ and nowJ.band or "?", nowJ and nowJ.basis or "no level evidence", nowJ and nowJ.verdict or "NORMAL",
			(nowJ and #nowJ.reasons > 0) and ("; reasons " .. table.concat(nowJ.reasons, ",")) or "")
	else
		L[#L + 1] = "  NOW is empty: " .. tostring(d.reason or "nothing qualified") .. "."
	end
	return L
end
