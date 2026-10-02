-- ForeverCodex.Nearby: the NEARBY card: only useful, relevant, trustworthy things close to you. Never a list of everything.
--
--   1. the Planner's ALSO DO (a genuinely worthwhile extra action), when there is one
--   2. a flight master close by, when you have the flight-hint system on (ATT data; Codex cannot tell whether you already have
--      the path, so it only says a flight master is here)
-- Inns, mailboxes, vendors, class and profession trainers are NOT listed: Codex has no trustworthy location data for them yet
-- (ATT has none, and Forever's trainer / vendor APIs are unverified). They will plug in here as providers when they exist.

local addonName, ns = ...

local Nb = {}
ns.Nearby = Nb

Nb.MAX = 3
Nb.FLIGHT_YD = 150

--- list of { title, detail, icon }
function Nb.List(plan, ctx)
	local out = {}
	if not plan then return out end
	if plan.alsoDo then
		local it = ns.Presenter.Describe(plan.alsoDo, plan, ctx, plan.alsoDo.type == "FLIGHT" and "triangle" or "diamond")
		out[#out + 1] = { title = it.title, detail = it.detail or it.who, icon = it.icon, where = it.where }
	end
	for _, a in ipairs(plan.nearby or {}) do
		if #out >= Nb.MAX then break end
		if a.type == "FLIGHT" and (not plan.alsoDo or a.id ~= plan.alsoDo.id) then
			local pos = ns.Planner.Locate(a)
			local me = ctx.loc and ctx.loc.available and { map = ctx.loc.map, x = ctx.loc.x, y = ctx.loc.y, world = ctx.loc.world or false }
			local d = pos and me and ns.Engine.Distance(ctx, me, pos)
			if d and d <= Nb.FLIGHT_YD then
				out[#out + 1] = { title = "Flight master", detail = a.name, icon = "triangle", where = ns.Presenter.Where(a, ctx) }
			end
		end
	end
	return out
end
