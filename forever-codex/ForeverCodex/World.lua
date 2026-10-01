-- ForeverCodex.World: "what is out there?" The foundation of the World tab: what the data and your quest log say about the
-- place you are in. It is a LIST, not a map (a Questie-like map is a later phase; it will be built independently and will
-- not copy Questie's code, data or UI). Locations are never shown to the player; only names and plain states.

local addonName, ns = ...
local R = ns.Registry
local K = ns.Contract

local Wd = {}
ns.World = Wd

Wd.MAX = 8

--- { zone, available = { {name, note} }, inProgress = { name }, moreAvailable = n, empty = text }
function Wd.Around(ctx)
	local v = { zone = ctx.loc and ctx.loc.zone or nil, available = {}, inProgress = {}, moreAvailable = 0 }
	local map = ctx.loc and ctx.loc.map
	local rows = {}
	for _, id in ipairs(R.QuestIds()) do
		local view = R.Quest(id)
		if view and view.loc and map and view.loc.map == map and not view.repeatable then
			local st = K.QuestState(id, view, ctx)
			if st.state == "AVAILABLE" then rows[#rows + 1] = { name = view.name or ("quest " .. id), id = id, lvl = view.req or view.level or 0 } end
		end
	end
	table.sort(rows, function(a, b)
		if a.lvl ~= b.lvl then return a.lvl < b.lvl end
		if a.name ~= b.name then return a.name < b.name end
		return a.id < b.id
	end)
	for i, r in ipairs(rows) do
		if i <= Wd.MAX then v.available[#v.available + 1] = { name = r.name, note = r.lvl > 0 and ("level " .. r.lvl) or nil } end
	end
	v.moreAvailable = math.max(0, #rows - Wd.MAX)
	local ids = {}
	for id in pairs(ctx.log or {}) do ids[#ids + 1] = id end
	table.sort(ids)
	for _, id in ipairs(ids) do
		local e = ctx.log[id]
		local view = R.Quest(id)
		v.inProgress[#v.inProgress + 1] = (view and view.name or e.title or "a quest") .. (e.complete and " (ready to turn in)" or "")
	end
	if not map then v.empty = "Codex cannot tell where you are right now." end
	return v
end
