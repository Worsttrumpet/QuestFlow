-- UI page "Journey": what have I done? Only what Codex actually recorded (see Journey.lua).

local addonName, ns = ...
local W = ns.Widgets
local UI = ns.UI

local ROWS = 12

UI.RegisterPage("journey", "Journey", function(parent)
	local w = {}
	UI.main.journey = w
	w.title = W.Text(parent, W.GOLD)
	W.Place(w.title, parent, 0, -2, UI.WIDTH - 24)
	w.title:SetText("Your journey")
	w.stats = {}
	for i = 1, 3 do
		local fs = W.Text(parent, W.GREY)
		W.Place(fs, parent, 0, -22 - (i - 1) * 16, UI.WIDTH - 24)
		w.stats[i] = fs
	end
	w.rows = {}
	for i = 1, ROWS do
		local fs = W.Text(parent, W.WHITE)
		W.Place(fs, parent, 8, -78 - (i - 1) * 16, UI.WIDTH - 40)
		w.rows[i] = fs
	end
	return { Refresh = function()
		local v = ns.Journey.View(ROWS)
		for i, fs in ipairs(w.stats) do fs:SetText(v.stats[i] or "") end
		for i, fs in ipairs(w.rows) do fs:SetText(v.lines[i] or (i == 1 and v.empty) or "") end
	end }
end)
