-- ForeverCodex.Presenter: turns the Planner's plan into what a PLAYER should read. Pure: no frames, no client calls.
--
-- "Hide the machinery, show the decision." Nothing here emits an id, a coordinate, a source label, a confidence, a
-- score, a raw state or a map id. Titles and sentences are built from structured action facts and reason codes; where a
-- fact is unknown the sentence is simply omitted (it is never invented).
--
--   Presenter.Card(plan, ctx) -> {
--     now    = { title, who, detail, progress, objectives = { { text, have, need } }, where, why, icon, kind } | nil
--              (`why` is for /codex report: the window does not draw it)
--     alsoDo = same | nil          (at most ONE, exactly the Planner's alsoDo)
--     ready  = { { title, who, where } }     READY TO TURN IN: finished quests that are not NOW
--     also   = { { kind = "objective", title, objectives = { { text, have, need } } } | { kind = "action", title, where } }   ALSO COMPLETE THIS
--     thenLine = "Turn in X" | nil (omitted when it is far away or says little)
--     empty  = { title, lines } | nil
--     reminders = { "Quest name", ... }    quests in the log Codex cannot place on the map
--   }

local addonName, ns = ...
local R = ns.Registry
local E = ns.Engine
local Pl = ns.Planner

local Pr = {}
ns.Presenter = Pr

Pr.THEN_MAX_YD = 600      -- a THEN farther than this is not worth a line in the window (a presentation choice, not a planner rule)

local function trim(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end

--- "10/10 Mottled Boar slain" / "Mottled Boar slain: 3/10" -> "Mottled Boar slain"; nil if nothing is left.
function Pr.CleanObjective(text)
	if type(text) ~= "string" then return nil end
	local t = text:gsub("^%s*%d+%s*/%s*%d+%s*:?%s*", ""):gsub("%s*:?%s*%d+%s*/%s*%d+%s*$", "")
	t = trim(t)
	return t ~= "" and t or nil
end

local function questName(a)
	if a.name and a.name ~= "" then return a.name end
	if a.title then
		local t = a.title:match("^[^:]*:%s*(.+)$")
		if t and not t:match("^quest %d+$") then return t end
	end
	return "a quest"
end

--- The first unfinished objective's counts, e.g. "4 / 6", or nil when the quest log did not report them.
function Pr.Progress(a)
	local os = a.objectiveState
	if not (os and os.known) then return nil end
	for _, o in ipairs(os.list) do
		if not o.finished and type(o.have) == "number" and type(o.need) == "number" and o.need > 0 then
			return string.format("%d / %d", o.have, o.need)
		end
	end
	return nil
end

local function unfinished(a)
	local out = {}
	local os = a.objectiveState
	if os and os.known then
		for _, o in ipairs(os.list) do if not o.finished then out[#out + 1] = o end end
	end
	return out
end

--- Coarse, human distance from the player to an action's target. nil when it cannot be said.
function Pr.Where(a, ctx)
	local pos = Pl.Locate(a)
	local me = ctx.loc and ctx.loc.available and { map = ctx.loc.map, x = ctx.loc.x, y = ctx.loc.y, world = ctx.loc.world or false } or nil
	if not pos or not me then return nil end
	local d = E.Distance(ctx, me, pos)
	if d == nil or d >= E.DIFFERENT_CONTINENT then return "In another area" end
	if d < 30 then return "Right here" end
	if d < 150 then return "Nearby" end
	return string.format("About %d yards away", math.floor(d / 50 + 0.5) * 50)
end

--- The distance as the tracker prints it: "Here" (under 30 yd), "90 yd", "1,800 yd", "In another area"; nil when it cannot be said.
function Pr.Dist(d)
	if type(d) ~= "number" then return nil end
	if d >= E.DIFFERENT_CONTINENT then return "In another area" end
	if d < 30 then return "Here" end
	local r = d < 1000 and math.floor(d / 10 + 0.5) * 10 or math.floor(d / 50 + 0.5) * 50
	local t = tostring(r)
	if r >= 1000 then t = t:sub(1, #t - 3) .. "," .. t:sub(-3) end
	return t .. " yd"
end

--- "a - b" for the parts that exist (nil when none do).
function Pr.Join(...)
	local out = {}
	for i = 1, select("#", ...) do
		local v = select(i, ...)
		if type(v) == "string" and v ~= "" then out[#out + 1] = v end
	end
	return #out > 0 and table.concat(out, " - ") or nil
end

--- How many follow-up quests turning this one in would open for THIS character, by the rules Codex already applies to every pickup (the same
-- eligibility check, run as if the quest were done). Quests already done or in the log, repeatables and anything the rules exclude are not counted.
-- nil when the data names none. (QuestieDB prerequisite lists: unverified, so this says "Codex knows of", never more.)
function Pr.Unlocks(a, ctx)
	if not (a and a.quest and ctx and Pl.Unlocks and ns.QuestProvider) then return nil end
	local after = setmetatable({ isCompleted = function(id) return id == a.quest or ctx.isCompleted(id) end }, { __index = ctx })
	local strategy = R.Strategy(ctx.prefs and ctx.prefs.style)
	local n = 0
	for _, qid in ipairs(Pl.Unlocks(a.quest)) do
		local v = R.Quest(qid)
		if v and not ctx.log[qid] and not ctx.isCompleted(qid) and ns.QuestProvider.Eligibility(v, after, strategy) then n = n + 1 end
	end
	return n > 0 and n or nil
end

--- The short reason the planner put an action beside the route (from its own reason codes), or nil. Never invented.
function Pr.AlsoWhy(plan, a)
	local why = plan and plan.diag and plan.diag.reasons and plan.diag.reasons[a.id]
	for _, o in ipairs(plan and plan.onTheWay or {}) do
		if o.id == a.id then why = { o.reason } break end        -- the opportunity carries its own reason code (every on-the-way row, not only the ALSO DO)
	end
	for _, r in ipairs(why or {}) do
		if r.code == "SAME_STOP" then return "Same stop." end
		if r.code == "ON_THE_WAY" then return "On your way." end
		if r.code == "SMALL_DETOUR" then return string.format("A short detour (about %d s).", r.seconds or 0) end
	end
	return nil
end

local function describe(a, plan, ctx, icon)
	local name = questName(a) .. (ns.Dungeons and ns.Dungeons.Suffix(ctx, a.quest) or "")
	local it = { kind = a.kind, icon = icon, where = Pr.Where(a, ctx), progress = Pr.Progress(a) }
	-- the tracker's short form of the same distance ("Here", "Nearby", "750 yd away"); nil when it cannot be said
	local pos0 = Pl.Locate(a)
	local me0 = ctx.loc and ctx.loc.available and { map = ctx.loc.map, x = ctx.loc.x, y = ctx.loc.y, world = ctx.loc.world or false } or nil
	local d0 = pos0 and me0 and E.Distance(ctx, me0, pos0) or nil
	local sw = ns.Overlap and ns.Overlap.ShortWhere(d0)
	if sw then it.whereShort = (sw == "here" and "Here") or (sw == "nearby" and "Nearby") or (sw .. " away") end
	if pos0 and d0 and d0 >= E.DIFFERENT_CONTINENT then it.whereShort = "In another area" end
	it.dist = Pr.Dist(d0)                                 -- the number the tracker prints ("90 yd", "1,800 yd", "Here")
	if type(a.level) == "number" and a.quest then it.level = a.level end
	if a.type == "FLIGHT" then
		it.title = "Visit the flight master"
		it.detail = a.name and ("Flight path: " .. a.name .. ".") or nil
		it.who = nil
	elseif a.kind == "ACCEPT" then
		it.title = "Accept " .. name
		it.who = a.giver
		it.npc = a.giver
		local view = a.quest and R.Quest(a.quest)
		local obj = view and view.objectives and Pr.CleanObjective(view.objectives[1])
		it.detail = obj and ("Goal: " .. obj .. ".") or (a.giver and ("Talk to " .. a.giver .. ".") or nil)
	elseif a.kind == "OBJECTIVE" then
		it.title = "Finish " .. name
		local todo = unfinished(a)
		local first = todo[1] and Pr.CleanObjective(todo[1].text)
		if first then
			it.detail = first .. (#todo > 1 and string.format(" (and %d more)", #todo - 1) or "") .. "."
		end
		-- EVERY unfinished objective the quest log reports (finished ones are left out), so the player sees all that remains
		it.objectives = {}
		for _, o in ipairs(todo) do it.objectives[#it.objectives + 1] = { text = Pr.CleanObjective(o.text) or "objective", have = o.have, need = o.need } end
	elseif a.kind == "TURN_IN" then
		it.title = "Turn in " .. name
		it.npc = a.turnInNpc and a.giver or nil           -- only a NAMED turn-in NPC; the quest giver's name is not assumed to be where it is handed in
		it.who = it.npc
		it.detail = a.giver and ("Hand it in near " .. a.giver .. ".") or "Your objectives are done."
	else
		it.title = name
	end
	local why = ns.PlanAdapter.Sentences(plan, a)
	it.why = why[1]
	if why[1] == "Best available option" then it.why = nil end
	return it
end

Pr.Describe = describe

function Pr.Card(plan, ctx)
	local card = { reminders = {} }
	for _, a in ipairs(plan and plan.reminders or {}) do
		if #card.reminders < 3 then card.reminders[#card.reminders + 1] = questName(a) end
	end
	if not (plan and plan.now) then
		local lines = {}
		if #card.reminders > 0 then
			lines[1] = "You have quests Codex cannot place on the map yet."
		else
			lines[1] = "Explore, or accept a quest, and Codex will pick it up from there."
		end
		for _, w in ipairs(plan and plan.warnings or {}) do
			if #lines < 3 and not w:find("^Not available on this client") then lines[#lines + 1] = w end
		end
		card.empty = { title = "Nothing to recommend right now", lines = lines }
		card.also, card.ready = {}, ns.Overlap and ns.Overlap.Ready(plan, ctx) or {}
		card.slots = Pr.Slots(ctx)
		card.dungeons = ns.Dungeons and ns.Dungeons.List(ctx) or {}
		return card
	end
	card.now = describe(plan.now, plan, ctx, "star")
	-- ALSO COMPLETE THIS: other unfinished objectives that fit with NOW (ns.Overlap), plus the planner's own ALSO DO
	card.also = ns.Overlap and ns.Overlap.List(plan, ctx) or {}
	-- READY TO TURN IN: finished quests waiting for the right moment (never promoted to NOW just because they are finished)
	card.ready = ns.Overlap and ns.Overlap.Ready(plan, ctx) or {}
	card.slots = Pr.Slots(ctx)
	card.dungeons = ns.Dungeons and ns.Dungeons.List(ctx) or {}
	if plan.alsoDo then
		card.alsoDo = describe(plan.alsoDo, plan, ctx, plan.alsoDo.type == "FLIGHT" and "triangle" or "diamond")
	end
	local t = plan.thenAction
	if t then
		local show = false                                -- (a THEN hand-in would repeat READY TO TURN IN)
		if t.kind ~= "TURN_IN" then
			local a, b = Pl.Locate(plan.now), Pl.Locate(t)
			local d = a and b and E.Distance(ctx, a, b) or nil
			show = d ~= nil and d < E.DIFFERENT_CONTINENT and d <= Pr.THEN_MAX_YD
		end
		if show then
			local th = describe(t, plan, ctx, nil)
			card.thenLine = th.title
			card.thenWhere = Pr.Join(th.dist, th.npc)
		end
	end
	return card
end

--- The normal quest-log usage the quest log reports: { used, max, free, full } or nil when it cannot be read.
function Pr.Slots(ctx)
	if not (ctx and ctx.logAvailable and type(ctx.logCount) == "number") then return nil end
	local max = E.QUEST_LOG_MAX
	return { used = ctx.logCount, max = max, free = math.max(0, max - ctx.logCount), full = ctx.logCount >= max }
end

--- "Thrall - level 25 Troll Warrior"
function Pr.Header(ctx)
	local c = ctx and ctx.char or {}
	local parts = {}
	if c.level then parts[#parts + 1] = "level " .. c.level end
	if c.race then parts[#parts + 1] = c.race end
	if c.class then parts[#parts + 1] = c.class end
	return (c.name or "Your character") .. (#parts > 0 and (" - " .. table.concat(parts, " ")) or "")
end
