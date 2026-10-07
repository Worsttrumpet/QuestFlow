-- UI page "Themes": everything that changes how Codex LOOKS (and how its arrow looks), in one place, grouped the way a player thinks about it:
--   LOOK OF CODEX     the theme: the palette behind every card. The meaning of a colour never changes (UI/Theme.lua): each kind of information keeps its marker letter in every theme.
--   DIRECTION ARROW   show / hide the on-screen arrow, its picture and its colour, and a short preview
--   GAME INTERFACE    the game's own quest tracker and Codex's button on the world map
--   (and a way to put the Codex window back at its default size and place)
-- These settings already existed (they were scattered through Codex Options); nothing new was invented for this page except the theme choice itself.

local addonName, ns = ...
local P = ns.Prefs
local W = ns.Widgets
local UI = ns.UI

local WIDTH = UI.WIDTH - 24
local LABEL_W, DROP_X, DROP_W = 112, 120, 210
local ROW_DROP = 42

local function dropdownRow(f, y, label, onSelect)
	local fs = W.Line(f, 12, W.GREY, "LEFT")
	fs:SetText(label)
	fs:SetPoint("TOPLEFT", f, "TOPLEFT", 0, y - 4)
	fs:SetWidth(LABEL_W)
	local d = W.Dropdown(f, DROP_X, y, DROP_W, onSelect)
	d.help = W.Line(f, 11, W.DIM, "LEFT")
	d.help:SetPoint("TOPLEFT", f, "TOPLEFT", DROP_X, y - 25)
	d.help:SetWidth(WIDTH - DROP_X - 8)
	return d
end

local function themeOptions()
	local out = {}
	for _, k in ipairs(ns.Theme.ORDER) do out[#out + 1] = { key = k, label = ns.Theme.THEMES[k].name } end
	return out
end
local function styleOptions()
	local out = {}
	for _, s in ipairs(ns.Arrow.STYLES) do out[#out + 1] = { key = s.key, label = s.label } end
	return out
end
local function colorOptions()
	local out = {}
	for _, c in ipairs(ns.Arrow.COLORS) do out[#out + 1] = { key = c.key, label = c.label, color = c.rgb } end
	return out
end

UI.RegisterPage("themes", "Themes", function(parent)
	local w = {}
	UI.main.themes = w
	local y = -2
	w.title = W.Line(parent, 14, W.WARM_GOLD, "LEFT")
	w.title:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, y)
	w.title:SetWidth(WIDTH)
	w.title:SetText("Themes")
	y = y - 20
	w.sub = W.Line(parent, 11, W.DIM, "LEFT")
	w.sub:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, y)
	w.sub:SetWidth(WIDTH)
	w.sub:SetText("These settings change how Quest Flow looks on your screen.")
	y = y - 24

	w.lookHead = W.Section(parent, "LOOK OF QUEST FLOW", 0, y, WIDTH)
	y = y - 24
	w.theme = dropdownRow(parent, y, "Theme", function(key) ns.Theme.Set(key) end)
	y = y - ROW_DROP - 4

	w.arrowHead = W.Section(parent, "DIRECTION ARROW", 0, y, WIDTH)
	y = y - 24
	w.arrow = W.CheckRow(parent, 0, y, WIDTH, function() P.SetArrow(not P.ArrowOn()) ; UI.Refresh() end)
	y = y - W.ROW_H_CHECK + 2
	w.arrowStyle = dropdownRow(parent, y, "Arrow style", function(key) P.SetArrowStyle(key); ns.Arrow.ApplyStyle(); UI.Refresh() end)
	y = y - ROW_DROP
	w.arrowColor = dropdownRow(parent, y, "Arrow colour", function(key) P.SetArrowColor(key); ns.Arrow.ApplyStyle(); UI.Refresh() end)
	w.preview = W.Button(parent, 90, 22, "Preview", function() if ns.Arrow.Demo then ns.Arrow.Demo(10) end end)
	w.preview:SetPoint("TOPLEFT", parent, "TOPLEFT", DROP_X + DROP_W + 12, y)
	y = y - ROW_DROP - 4

	w.gameHead = W.Section(parent, "GAME INTERFACE", 0, y, WIDTH)
	y = y - 24
	w.blizz = W.CheckRow(parent, 0, y, WIDTH, function() P.SetHideBlizzardTracker(not P.HideBlizzardTracker()); ns.BlizzardTracker.Apply(); UI.Refresh() end)
	y = y - W.ROW_H_CHECK + 2
	w.worldMap = W.CheckRow(parent, 0, y, WIDTH, function() P.SetWorldMapButton(not P.WorldMapButtonOn()); ns.WorldMapButton.Apply(); UI.Refresh() end)
	y = y - W.ROW_H_CHECK + 2
	w.reset = W.Button(parent, 190, 22, "Reset window size and place", function() UI.ResetWindow() end)
	w.reset:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, y)
	w.resetHelp = W.Line(parent, 11, W.DIM, "LEFT")
	w.resetHelp:SetPoint("LEFT", w.reset, "RIGHT", 10, 0)
	w.resetHelp:SetText("Drag the Quest Flow window's bottom right corner to resize it.")

	return { Refresh = function()
		local key = ns.Theme.Key()
		w.theme:SetOptions(themeOptions())
		w.theme:SetValue(key)
		w.theme.help:SetText(ns.Theme.THEMES[key].desc .. " Markers and labels stay the same.")
		w.arrow:SetOn(P.ArrowOn(), "Show the direction arrow", "A small arrow on your screen that points at your current target.")
		w.arrowStyle:SetOptions(styleOptions())
		w.arrowStyle:SetValue(ns.Arrow.Style().key)
		w.arrowStyle.help:SetText("The picture the arrow uses.")
		w.arrowColor:SetOptions(colorOptions())
		w.arrowColor:SetValue(ns.Arrow.Color().key)
		w.arrowColor.help:SetText("Pick one that stands out against the game world.")
		w.blizz:SetOn(P.HideBlizzardTracker(), "Hide the game's quest tracker", "Removes the game's own tracker so Quest Flow is the only one on screen.")
		w.worldMap:SetOn(P.WorldMapButtonOn(), "Quest Flow button on the world map", "A small button on the world map that opens Quest Flow.")
	end }
end)
