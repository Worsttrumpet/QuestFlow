-- ForeverCodex.Presenter: turns the Planner's plan into what a PLAYER should read. Pure: no frames, no client calls.
--
-- "Hide the machinery, show the decision." Nothing here emits an id, a coordinate, a source label, a confidence, a
-- score, a raw state or a map id. Titles and sentences are built from structured action facts and reason codes; where a
-- fact is unknown the sentence is simply omitted (it is never invented).
--
--   Presenter.Card(plan, ctx) -> {
--     now    = { title, who, detail, progress, where, why, icon, kind } | nil
--     alsoDo = same | nil          (at most ONE, exactly the Planner's alsoDo)
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

local function describe(a, plan, ctx, icon)
	local name = questName(a)
	local it = { kind = a.kind, icon = icon, where = Pr.Where(a, ctx), progress = Pr.Progress(a) }
	if a.type == "FLIGHT" then
		it.title = "Visit the flight master"
		it.detail = a.name and ("Flight path: " .. a.name .. ".") or nil
		it.who = nil
	elseif a.kind == "ACCEPT" then
		it.title = "Accept " .. name
		it.who = a.giver
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
	elseif a.kind == "TURN_IN" then
		it.title = "Turn in " .. name
		it.who = a.giver
		it.detail = a.giver and ("Hand it in near " .. a.giver .. ".") or "Your objectives are done."
	else
		it.title = name
	end
	local why = ns.PlanAdapter.Sentences(plan, a)
	it.why = why[1]
	if why[1] == "Best available option" then it.why = nil end
	return it
end

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
		return card
	end
	card.now = describe(plan.now, plan, ctx, "star")
	if plan.alsoDo then
		card.alsoDo = describe(plan.alsoDo, plan, ctx, plan.alsoDo.type == "FLIGHT" and "triangle" or "diamond")
	end
	local t = plan.thenAction
	if t then
		local show = t.kind == "TURN_IN"
		if not show then
			local a, b = Pl.Locate(plan.now), Pl.Locate(t)
			local d = a and b and E.Distance(ctx, a, b) or nil
			show = d ~= nil and d < E.DIFFERENT_CONTINENT and d <= Pr.THEN_MAX_YD
		end
		if show then
			local th = describe(t, plan, ctx, nil)
			card.thenLine = th.title
		end
	end
	return card
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
