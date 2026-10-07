-- UI page "World": what is out there? The foundation of the Questie-like reference: today a plain list of what the data and
-- your quest log say about the zone you are in (names and levels only; never coordinates). A real map comes later.

local addonName, ns = ...
local W = ns.Widgets
local UI = ns.UI

local ROWS = 8

UI.RegisterPage("world", "World", function(parent)
	local w = {}
	UI.main.world = w
	w.title = W.Text(parent, W.GOLD)
	W.Place(w.title, parent, 0, -2, UI.WIDTH - 24)
	w.sub = W.Text(parent, W.GREY)
	W.Place(w.sub, parent, 0, -20, UI.WIDTH - 24)
	w.rows = {}
	for i = 1, ROWS do
		local fs = W.Text(parent, W.WHITE)
		W.Place(fs, parent, 8, -42 - (i - 1) * 16, UI.WIDTH - 40)
		w.rows[i] = fs
	end
	w.more = W.Text(parent, W.GREY)
	W.Place(w.more, parent, 8, -42 - ROWS * 16, UI.WIDTH - 40)
	w.logHead = W.Text(parent, W.GREY)
	W.Place(w.logHead, parent, 0, -42 - ROWS * 16 - 22, UI.WIDTH - 24)
	w.logs = {}
	for i = 1, 3 do
		local fs = W.Text(parent, W.WHITE)
		W.Place(fs, parent, 8, -42 - ROWS * 16 - 40 - (i - 1) * 16, UI.WIDTH - 40)
		w.logs[i] = fs
	end
	return { Refresh = function()
		local ctx = ns.State.ctx
		if not ctx then return end
		local v = ns.World.Around(ctx)
		w.title:SetText(v.zone and ("Around you: " .. v.zone) or "Around you")
		w.sub:SetText(v.empty or "Quests you could take here")
		for i, fs in ipairs(w.rows) do
			local q = v.available[i]
			fs:SetText(q and (q.name .. (q.note and ("  (" .. q.note .. ")") or "")) or "")
		end
		w.more:SetText(v.moreAvailable > 0 and string.format("... and %d more", v.moreAvailable) or "")
		w.logHead:SetText(#v.inProgress > 0 and "In your quest log" or "")
		for i, fs in ipairs(w.logs) do fs:SetText(v.inProgress[i] or "") end
	end }
end)
