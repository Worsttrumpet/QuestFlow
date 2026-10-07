-- ui_trace_harness.lua <addonDir> [outTrace]
-- Loads ForeverQuestGuide in TOC order against a recording stub client, drives a fixed UI session, and writes
-- every widget method call (widget identity = creation order) to a trace. Two builds whose traces are identical
-- behave identically for everything this session exercises.
local dir, out = arg[1], arg[2]
local trace, nextId = {}, 0
local function fmt(v)
	local t = type(v)
	if t == "table" then return v.__id and ("#" .. v.__id) or "{}" end
	if t == "function" then return "fn" end
	if t == "number" then return string.format("%.4f", v) end
	return tostring(v)
end
local function log(id, name, ...)
	local parts = {}
	for i = 1, select("#", ...) do parts[#parts + 1] = fmt((select(i, ...))) end
	trace[#trace + 1] = "#" .. id .. ":" .. name .. "(" .. table.concat(parts, ",") .. ")"
end
local function widget(kind)
	nextId = nextId + 1
	local w = { __id = nextId, __kind = kind, __shown = true, __text = "", __scripts = {} }
	return setmetatable(w, { __index = function(t, k)
		if k == "IsShown" then return function(self) return self.__shown end end
		if k == "GetText" then return function(self) return self.__text end end
		if k == "GetStringHeight" then return function() return 12 end end
		if k == "GetScript" then return function(self, n) return self.__scripts[n] end end
		return function(self, ...)
			log(self.__id, k, ...)
			if k == "Show" then self.__shown = true elseif k == "Hide" then self.__shown = false end
			if k == "SetText" then self.__text = (...) or "" end
			if k == "SetScript" then local n, fn = ...; self.__scripts[n] = fn end
			if k == "CreateTexture" then return widget("Texture") end
			if k == "CreateFontString" then return widget("FontString") end
		end
	end })
end
_G.CreateFrame = function(kind) local w = widget(kind); log(w.__id, "CreateFrame", kind); return w end
_G.UIParent, _G.Minimap, _G.WorldMapFrame = widget("UIParent"), widget("Minimap"), widget("WorldMapFrame")
_G.GameFontNormal, _G.GameTooltip = {}, widget("GameTooltip")
_G.DEFAULT_CHAT_FRAME = { AddMessage = function(_, m) trace[#trace + 1] = "CHAT:" .. m end }
_G.GetBuildInfo = function() return "1.60.1", "70124", "Sep 29 2026", 16001 end
_G.GetTime = function() return 100 end
_G.SlashCmdList = {}
_G.unpack = unpack
_G.ToggleWorldMap = function() trace[#trace + 1] = "ToggleWorldMap" end
_G.C_Map = {
	SetUserWaypoint = function(p) trace[#trace + 1] = "SetUserWaypoint:" .. p.uiMapID end,
	CanSetUserWaypointOnMap = function() return true end,
	ClearUserWaypoint = function() end,
}
_G.C_SuperTrack = { SetSuperTrackedUserWaypoint = function() end }
_G.UiMapPoint = { CreateFromCoordinates = function(m, x, y) return { uiMapID = m, position = { x = x, y = y } } end }
_G.ForeverQuestGuideDB = nil
local ns = {}
local toc = io.open(dir .. "/ForeverQuestGuide.toc"):read("*a")
for line in toc:gmatch("[^\r\n]+") do
	if line:match("%.lua$") then assert(loadfile(dir .. "/" .. line))("ForeverQuestGuide", ns) end
end
-- drive the session
if ns._selftest.fireAddonLoaded then ns._selftest.fireAddonLoaded() end
if ns._hooks and ns._hooks.playerLogin then ns._hooks.playerLogin() end
ns.UI.Toggle()
local f = ns._selftest.getFrame()
for _, b in ipairs(ns._selftest.getListButtons()) do if b.questID then b.__scripts.OnClick(b); break end end
f.questMapBtn.__scripts.OnClick()
ns._selftest.setFilterText("peon")
ns._selftest.setFilterText("")
ns._selftest.setActiveTab("ROUTE")
for _ = 1, 3 do ns._selftest.routeNext() end
ns._selftest.getRouteButtons().map.__scripts.OnClick()   -- step 4: has a destination
for _ = 1, 2 do ns._selftest.routeNext() end              -- past the end: no-op at the last step
for _ = 1, 2 do ns._selftest.routePrevious() end
ns._selftest.getRouteButtons().map.__scripts.OnClick()
ns._selftest.getPreviewToggleButton().__scripts.OnClick()
SlashCmdList.FOREVERQUESTGUIDE("theme dark")
SlashCmdList.FOREVERQUESTGUIDE("mode compact")
SlashCmdList.FOREVERQUESTGUIDE("mode detailed")
ns._selftest.setActiveTab("QUESTS")
ns.UI.Toggle()
local fh = io.open(out, "w"); fh:write(table.concat(trace, "\n")); fh:close()
print(string.format("trace: %d calls, %d widgets", #trace, nextId))
