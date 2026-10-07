-- ForeverCodex.WorldMapButton: a small Codex button in the corner of the world map that shows / hides the tracker (left click) or opens the
-- options (right click). It is a plain button parented to the world map frame: it adds nothing TO the map (no pins, no overlays).
--
-- Where it sits: the world map keeps its own buttons in the top-right corner of the map canvas, in slots of 32 px. Codex takes the next free
-- slot after the addon buttons it can see (Krowi-style "Krowi_WorldMapButtonsN" frames, and a slot for Questie when it is loaded).
-- Everything is feature-checked and pcall-wrapped. NOT VERIFIED ON FOREVER: that WorldMapFrame:GetCanvasContainer() is the right anchor here
-- (Questie's own world-map button is anchored that way on this client) and the exact slot; /codex diag reports what was found.

local addonName, ns = ...
local P = ns.Prefs

local WM = {}
ns.WorldMapButton = WM

WM.ART_SIZE = 32
WM.state = { status = "not built" }

local button

local function mapFrame() return rawget(_G, "WorldMapFrame") end

--- Which slot (0, 1, 2 ...) from the corner Codex should take: one per other addon button already there.
local function slot()
	local n = 0
	for i = 0, 8 do
		local b = rawget(_G, "Krowi_WorldMapButtons" .. i)
		if type(b) == "table" and b ~= button then n = n + 1 end
	end
	if n == 0 and rawget(_G, "Questie") ~= nil then n = 1 end
	return n
end

local function anchor()
	local m = mapFrame()
	if not (button and m) then return end
	local ok, canvas = pcall(m.GetCanvasContainer, m)
	if not ok or type(canvas) ~= "table" then canvas = m end
	button:ClearAllPoints()
	button:SetPoint("TOPRIGHT", canvas, "TOPRIGHT", -(4 + 32 * slot()), -2)
end

local function build()
	local m = mapFrame()
	if type(m) ~= "table" then return false, "no world map frame" end
	button = CreateFrame("Button", "ForeverCodexWorldMapButton", m)
	button:SetSize(WM.ART_SIZE, WM.ART_SIZE)
	pcall(button.SetFrameStrata, button, "HIGH")
	-- the same pieces as the minimap button: the game's disc, ring and glow, with the Codex logo inside
	button.background = button:CreateTexture(nil, "BACKGROUND")
	button.background:SetSize(25, 25)
	button.background:SetPoint("TOPLEFT", 2, -4)
	ns.Safe(button.background.SetTexture, button.background, "Interface\\Minimap\\UI-Minimap-Background")
	button.icon = button:CreateTexture(nil, "ARTWORK")
	button.icon:SetSize(22, 22)
	button.icon:SetPoint("TOPLEFT", 6, -5)
	ns.Safe(button.icon.SetTexture, button.icon, "Interface\\AddOns\\QuestFlow\\Media\\CodexLogo.tga")
	button.border = button:CreateTexture(nil, "OVERLAY")
	button.border:SetSize(54, 54)
	button.border:SetPoint("TOPLEFT")
	ns.Safe(button.border.SetTexture, button.border, "Interface\\Minimap\\MiniMap-TrackingBorder")
	ns.Safe(button.SetHighlightTexture, button, "Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
	pcall(button.RegisterForClicks, button, "LeftButtonUp", "RightButtonUp")
	button:SetScript("OnClick", function(_, mouse)
		if mouse == "RightButton" then
			if ns.UI and ns.UI.ToggleOptions then ns.UI.ToggleOptions() end
		elseif ns.UI and ns.UI.Toggle then
			ns.UI.Toggle()
		end
	end)
	button:SetScript("OnEnter", function(self)
		if ns.Widgets and ns.Widgets.ShowTooltip then
			ns.Widgets.ShowTooltip(self, "ANCHOR_LEFT", { title = "Quest Flow", version = "v" .. tostring(ForeverCodex and ForeverCodex.VERSION or ""),
				rows = { { "Left Click", "Show / hide the tracker" }, { "Right Click", "Options" } } })
		end
	end)
	button:SetScript("OnLeave", function() local t = rawget(_G, "GameTooltip"); if t then pcall(t.Hide, t) end end)
	-- the map re-lays its own buttons when it changes: keep ours in its slot
	if type(hooksecurefunc) == "function" then
		for _, name in ipairs({ "RefreshOverlayFrames", "OnMapChanged" }) do
			if type(m[name]) == "function" then pcall(hooksecurefunc, m, name, anchor) end
		end
	end
	return true
end

--- Brings the button in line with the setting (built on first use). Safe to call any time.
function WM.Apply()
	if not P.WorldMapButtonOn() then
		if button then button:Hide() end
		WM.state = { status = "off" }
		return WM.state
	end
	if not button then
		local ok, err = build()
		if not ok then
			WM.state = { status = err or "not built" }
			return WM.state
		end
	end
	anchor()
	button:Show()
	WM.state = { status = "shown", slot = slot() }
	return WM.state
end

function WM.Status() return { setting = P.WorldMapButtonOn(), status = WM.state.status, slot = WM.state.slot } end
function WM.Button() return button end
function WM._Reset() button = nil; WM.state = { status = "not built" } end   -- test seam
