-- ForeverCodex.UI (the PLAYER window): a compact companion, not a database. "Hide the machinery, show the decision."
--
--   [ Codex  v ]   one dropdown (Codex, World, Journey, Appendices): no tab row, no back / forward arrows
--
-- This file is only the shell: the frame, the tabs, where the window remembers it was, and a registry the pages plug into
-- (UI/Page*.lua). Pages receive view models from Presenter / World / Journey / Knowledge / Party / HelpCodex and draw
-- them; none of them reads the Planner or the data directly. The engineering window (provenance, route pickers, the old
-- buttons) lives on as ns.DevUI (/codex dev).
--
-- Only primitives proven on Forever are used (see Widgets.lua). ASCII only: glyphs render as blank boxes (M8.14 v0.1), so
-- the star / diamond / triangle are small coloured squares with a letter.

local addonName, ns = ...
local P = ns.Prefs
local W = ns.Widgets

local UI = {}
ns.UI = UI

UI.WIDTH, UI.HEIGHT = 520, 430       -- the full-size window (Setup, World, Journey, Appendices)
UI.COMPACT_WIDTH = 330               -- the Codex page: a right-side tracker about as wide as the game's own (readable, not a panel)
UI.HEIGHT_MIN = 150          -- the Codex page shrinks the window to its content, never below this; other pages use UI.HEIGHT
UI.pageDefs = {}            -- registration order = tab order
UI.pages = {}               -- key -> { frame, refresh }
UI.current = "codex"
UI.main = {}                -- named widgets (for tests and the pages)

-- anything not defined here (ProvenanceText, ShowReport, ...) is the developer window's
setmetatable(UI, { __index = function(_, k) return ns.DevUI and ns.DevUI[k] end })

--- Pages register themselves: key, tab label, build(parentFrame) -> pageTable, where pageTable.Refresh() draws.
function UI.RegisterPage(key, label, build)
	UI.pageDefs[#UI.pageDefs + 1] = { key = key, label = label, build = build }
end

local ICON_COLOR = { star = { 1, 0.82, 0 }, diamond = { 0.75, 0.45, 1 }, triangle = { 0.35, 0.9, 0.35 }, moon = { 0.7, 0.8, 1 } }
local ICON_LETTER = { star = "*", diamond = "o", triangle = "^", moon = ")" }

--- A small coloured square with a letter (a small ASCII icon).
function UI.Icon(parent, kind)
	local f = CreateFrame("Frame", nil, parent)
	f:SetSize(14, 14)
	f.bg = f:CreateTexture(nil, "BACKGROUND")
	f.bg:SetAllPoints()
	f.letter = W.Text(f, W.WHITE)
	f.letter:SetPoint("CENTER")
	f.kind = nil
	function f.Set(self, k)
		self.kind = k
		local c = ICON_COLOR[k] or { 0.4, 0.4, 0.4 }
		self.bg:SetColorTexture(c[1], c[2], c[3], 0.95)
		self.letter:SetText(ICON_LETTER[k] or "")
	end
	f:Set(kind)
	return f
end

--- Sets the window size keeping its TOP-LEFT corner where it is (a CENTER / RIGHT / BOTTOM anchored frame would otherwise jump).
-- w is optional (the current width is kept).
function UI.FitSize(w, h)
	local frame = UI.frame
	if not frame then return end
	h = math.floor(math.max(UI.HEIGHT_MIN, h) + 0.5)
	local oldH, oldW = UI.main.height or UI.HEIGHT, UI.main.width or UI.WIDTH
	w = math.floor((w or oldW) + 0.5)
	if h == oldH and w == oldW then return end
	local ok, point, _, rel, x, y = pcall(frame.GetPoint, frame, 1)
	frame:SetSize(w, h)
	UI.main.height, UI.main.width = h, w
	if ok and type(point) == "string" and type(x) == "number" and type(y) == "number" then
		if point:find("BOTTOM") then y = y + (oldH - h)
		elseif not point:find("TOP") then y = y + (oldH - h) / 2 end
		if point:find("RIGHT") then x = x + (w - oldW)
		elseif not point:find("LEFT") then x = x + (w - oldW) / 2 end
		frame:ClearAllPoints()
		frame:SetPoint(point, UIParent, rel or point, x, y)
	end
end
function UI.FitHeight(h) UI.FitSize(nil, h) end

local function savePosition(frame)
	local ok, point, _, rel, x, y = pcall(frame.GetPoint, frame, 1)
	if ok and type(point) == "string" and type(x) == "number" and type(y) == "number" then
		P.SetWindowPos({ point = point, rel = rel or point, x = x, y = y, h = UI.main.height, w = UI.main.width })
	end
end

local function restorePosition(frame)
	-- 0.2.6: the Codex window became a compact right-side tracker with a new default place. A position saved by an older layout is dropped once, so
	-- nobody keeps the old big window dead-centre; after that the player's own position is remembered as before.
	local ui = P.UI()
	if ui.windowLayout ~= 3 then
		ui.windowLayout = 3
		ui.window = nil
	end
	local pos = P.WindowPos()
	-- the window was saved at the size it had then (the Codex page fits its content): start from it, so fitting again keeps the corner where it was
	local sw, sh = UI.COMPACT_WIDTH, UI.HEIGHT
	if type(pos) == "table" and type(pos.h) == "number" and pos.h >= UI.HEIGHT_MIN and pos.h <= 2000 then sh = pos.h end
	if type(pos) == "table" and type(pos.w) == "number" and pos.w >= 200 and pos.w <= 2000 then sw = pos.w end
	UI.main.height, UI.main.width = sh, sw
	frame:SetSize(sw, sh)
	frame:ClearAllPoints()
	if type(pos) == "table" and pos.point and type(pos.x) == "number" and type(pos.y) == "number" then
		frame:SetPoint(pos.point, UIParent, pos.rel or pos.point, pos.x, pos.y)
	else
		frame:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -20, -240)   -- where the quest tracker normally sits: right side, below the minimap
	end
end

-- ---------------------------------------------------------------- two windows
--
--   the TRACKER (UI.frame, "ForeverCodexMain"): the compact Codex page, nothing else. Left click on the minimap button, or /codex.
--   the OPTIONS window (UI.options, "ForeverCodexOptions"): a tabbed window like most addons have: Codex Options, World, Journey,
--   Appendices. Right click on the minimap button, the tracker's "Options" button, or /codex options.
-- The pages themselves (UI/Page*.lua) are unchanged: each is built once into whichever window owns it.

local OPTION_TABS = { "options", "world", "journey", "appendices" }
local function isOptionsPage(key) for _, k in ipairs(OPTION_TABS) do if k == key then return true end end return false end

--- The shared look of both windows: a 1 px muted-gold border (an outer texture with the fill inset on top).
local function shell(frame)
	local edge = frame:CreateTexture(nil, "BACKGROUND")
	edge:SetAllPoints()
	edge:SetColorTexture(0.40, 0.33, 0.16, 0.95)
	local bg = frame:CreateTexture(nil, "BORDER")
	bg:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
	bg:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -1, 1)
	bg:SetColorTexture(0.04, 0.04, 0.05, 0.94)
	local sep = frame:CreateTexture(nil, "ARTWORK")
	sep:SetPoint("TOPLEFT", frame, "TOPLEFT", 8, -33)
	sep:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -8, -33)
	sep:SetSize(1, 1)
	sep:SetColorTexture(0.40, 0.34, 0.18, 0.55)
end

local function buildPage(def, parent)
	local pf = CreateFrame("Frame", nil, parent)
	pf:SetSize(UI.WIDTH - 16, UI.HEIGHT - 40)
	pf:SetPoint("TOPLEFT", parent, "TOPLEFT", 8, -36)
	local page = def.build(pf) or {}
	page.frame = pf
	UI.pages[def.key] = page
	return page
end

local function defOf(key) for _, d in ipairs(UI.pageDefs) do if d.key == key then return d end end end

-- ---------------------------------------------------------------- the tracker

local function buildTracker()
	local frame = CreateFrame("Frame", "ForeverCodexMain", UIParent)
	frame:SetSize(UI.WIDTH, UI.HEIGHT)
	frame:SetFrameStrata("HIGH")
	frame:SetMovable(true)
	frame:EnableMouse(true)
	frame:RegisterForDrag("LeftButton")
	frame:SetScript("OnDragStart", frame.StartMoving)
	frame:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
		savePosition(self)
	end)
	ns.Safe(frame.SetClampedToScreen, frame, true)
	restorePosition(frame)
	shell(frame)
	local title = W.Line(frame, 10, W.DIM, "LEFT")
	title:SetPoint("TOPLEFT", frame, "TOPLEFT", 74, -11)
	title:SetWidth(200)
	title:SetText("FOREVER CODEX v" .. tostring(ForeverCodex and ForeverCodex.VERSION or "?"))
	UI.frame = frame
	UI.main.height = UI.main.height or UI.HEIGHT
	-- the one way to the options from here (the minimap button's right click and /codex options are the others)
	UI.main.optionsButton = W.Button(frame, 60, 20, "Options", function() UI.ShowPage("options") end)
	UI.main.optionsButton:SetPoint("TOPLEFT", frame, "TOPLEFT", 8, -7)
	-- REPORT A PROBLEM: one button, no slash command (UI/Feedback.lua)
	UI.main.feedbackButton = W.Button(frame, 62, 20, "Feedback", function() if UI.OpenFeedback then UI.OpenFeedback({ from = "WINDOW" }) end end)
	UI.main.feedbackButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -32, -7)
	buildPage(defOf("codex"), frame)
	-- NEW FOR YOU lasts exactly one minute and then disappears by itself: a light check keeps the card honest while the window is open
	local sinceCheck = 0
	frame:SetScript("OnUpdate", function(_, dt)
		sinceCheck = sinceCheck + (dt or 0)
		if sinceCheck < 0.5 then return end
		sinceCheck = 0
		if ns.NewForYou and (ns.NewForYou.Active() ~= nil) ~= (UI.main.nfyShown == true) then UI.Refresh() end
		-- a timed quest's countdown: the texts follow the clock (no recompute); a card that appeared or disappeared since the last draw is a full refresh
		if ns.QuestTimers then
			local active = ns.QuestTimers.AnyActive()
			if active ~= (UI.main.timerShown == true) then UI.main.timerShown = active; UI.Refresh() elseif active and UI.RefreshTimers then UI.RefreshTimers() end
		end
	end)
	local close = W.Button(frame, 18, 18, "x", function() frame:Hide(); P.SetTrackerShown(false) end)
	close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -4, -4)
	UI.main.close = close
	frame:Hide()                       -- (a new frame is shown by default: whoever opens it shows it)
end

-- ---------------------------------------------------------------- the options window
--
-- Built the way most addons' options are: the game's own dialog frame (UI-DialogBox background and border), a gold title plate on top, tabs
-- along the pane's top edge (the game's options-frame tab pictures), a bordered pane for the page, and the game's red buttons. Only standard
-- game pictures and templates are used (the ones Questie's and other addons' options windows are made of, so they exist on this client).
-- Every piece is feature-checked: if the dialog or button template cannot be made, the flat look of the tracker is used instead.

local OPTIONS_W, OPTIONS_H = 560, 520
UI.OPTIONS_W, UI.OPTIONS_H = OPTIONS_W, OPTIONS_H
local DIALOG_BACKDROP = {
	bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background", edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
	tile = true, tileSize = 32, edgeSize = 32, insets = { left = 8, right = 8, top = 8, bottom = 8 },
}
local PANE_BACKDROP = {
	bgFile = "Interface\\ChatFrame\\ChatFrameBackground", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
	tile = true, tileSize = 16, edgeSize = 16, insets = { left = 3, right = 3, top = 5, bottom = 3 },
}
local TAB_ACTIVE, TAB_INACTIVE = "Interface\\OptionsFrame\\UI-OptionsFrame-ActiveTab", "Interface\\OptionsFrame\\UI-OptionsFrame-InActiveTab"
local HEADER = "Interface\\DialogFrame\\UI-DialogBox-Header"

--- A frame with a backdrop when the game offers one (BackdropTemplate), else a plain frame (flat = true: the caller draws the flat shell).
local function backdropFrame(parent, backdrop, r, g, b, a, br, bg_, bb)
	local ok, f = pcall(CreateFrame, "Frame", nil, parent, "BackdropTemplate")
	if not ok or type(f) ~= "table" then return CreateFrame("Frame", nil, parent), true end
	local okB = pcall(f.SetBackdrop, f, backdrop)
	if not okB then return f, true end
	pcall(f.SetBackdropColor, f, r, g, b, a)
	if br then pcall(f.SetBackdropBorderColor, f, br, bg_, bb) end
	return f, false
end

--- A three-piece tab (active and inactive pictures), the label centred. tab:SetSelected(bool).
local function makeTab(parent, label, width, onClick)
	local tab = CreateFrame("Button", nil, parent)
	tab:SetSize(width, 24)
	local function slices(file, anchorPoint, dy)
		local L = tab:CreateTexture(nil, "BORDER")
		ns.Safe(L.SetTexture, L, file); L:SetSize(20, 24); L:SetPoint(anchorPoint, tab, anchorPoint, 0, dy); ns.Safe(L.SetTexCoord, L, 0, 0.15625, 0, 1)
		local M = tab:CreateTexture(nil, "BORDER")
		ns.Safe(M.SetTexture, M, file); M:SetSize(width - 40, 24); M:SetPoint("LEFT", L, "RIGHT"); ns.Safe(M.SetTexCoord, M, 0.15625, 0.84375, 0, 1)
		local R = tab:CreateTexture(nil, "BORDER")
		ns.Safe(R.SetTexture, R, file); R:SetSize(20, 24); R:SetPoint("LEFT", M, "RIGHT"); ns.Safe(R.SetTexCoord, R, 0.84375, 1, 0, 1)
		return { L, M, R }
	end
	tab.off = slices(TAB_INACTIVE, "TOPLEFT", 0)
	tab.on = slices(TAB_ACTIVE, "BOTTOMLEFT", -3)
	tab.text = W.Line(tab, 12, W.GOLD, "CENTER")
	tab.text:SetPoint("CENTER", tab, "CENTER", 0, -3)
	tab.text:SetText(label)
	tab:SetScript("OnClick", function() if onClick then onClick() end end)
	function tab:SetSelected(on)
		self.selected = on and true or false
		for _, t in ipairs(self.on) do if on then t:Show() else t:Hide() end end
		for _, t in ipairs(self.off) do if on then t:Hide() else t:Show() end end
		W.SetColor(self.text, on and W.WHITE or W.GOLD)
		self.text:ClearAllPoints()
		self.text:SetPoint("CENTER", self, "CENTER", 0, on and -2 or -3)
	end
	tab:SetSelected(false)
	return tab
end

local function buildOptions()
	local frame, flat = backdropFrame(UIParent, DIALOG_BACKDROP, 0, 0, 0, 1)
	pcall(frame.SetFrameStrata, frame, "FULLSCREEN_DIALOG")
	pcall(frame.SetToplevel, frame, true)
	pcall(frame.SetFrameLevel, frame, 100)
	frame:SetSize(OPTIONS_W, OPTIONS_H)
	frame:SetMovable(true)
	frame:EnableMouse(true)
	frame:RegisterForDrag("LeftButton")
	frame:SetScript("OnDragStart", frame.StartMoving)
	frame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
	ns.Safe(frame.SetClampedToScreen, frame, true)
	frame:ClearAllPoints()
	frame:SetPoint("CENTER")
	if flat then shell(frame) end
	UI.options = frame
	W.useBlizzardButtons = true
	-- the gold title plate on the top edge
	local plate = frame:CreateTexture(nil, "OVERLAY")
	ns.Safe(plate.SetTexture, plate, HEADER); ns.Safe(plate.SetTexCoord, plate, 0.31, 0.67, 0, 0.63)
	plate:SetPoint("TOP", 0, 12); plate:SetSize(180, 40)
	local plateL = frame:CreateTexture(nil, "OVERLAY")
	ns.Safe(plateL.SetTexture, plateL, HEADER); ns.Safe(plateL.SetTexCoord, plateL, 0.21, 0.31, 0, 0.63)
	plateL:SetPoint("RIGHT", plate, "LEFT"); plateL:SetSize(30, 40)
	local plateR = frame:CreateTexture(nil, "OVERLAY")
	ns.Safe(plateR.SetTexture, plateR, HEADER); ns.Safe(plateR.SetTexCoord, plateR, 0.67, 0.77, 0, 0.63)
	plateR:SetPoint("LEFT", plate, "RIGHT"); plateR:SetSize(30, 40)
	local title = W.Line(frame, 12, W.GOLD, "CENTER")
	title:SetPoint("TOP", plate, "TOP", 0, -14)
	title:SetWidth(170)
	title:SetText("Forever Codex v" .. tostring(ForeverCodex and ForeverCodex.VERSION or "?"))
	UI.main.optionsTitle = title
	-- the bordered pane the pages live in, and the tabs on its top edge
	local pane, paneFlat = backdropFrame(frame, PANE_BACKDROP, 0.1, 0.1, 0.1, 0.5, 0.4, 0.4, 0.4)
	pane:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -58)
	pane:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -16, 50)
	UI.main.pane = pane
	UI.main.tabs = {}
	local x = 6
	for _, key in ipairs(OPTION_TABS) do
		local def = defOf(key)
		if def then
			local width = key == "options" and 130 or (key == "appendices" and 110 or 90)
			local tab = makeTab(frame, def.label, width, function() UI.ShowPage(key) end)
			tab:SetPoint("BOTTOMLEFT", pane, "TOPLEFT", x, -3)
			UI.main.tabs[key] = tab
			x = x + width - 4
			local pf = buildPage(def, pane)
			pf.frame:ClearAllPoints()
			pf.frame:SetPoint("TOPLEFT", pane, "TOPLEFT", 14, -14)
			pf.frame:SetSize(OPTIONS_W - 32 - 28, OPTIONS_H - 58 - 50 - 28)
		end
	end
	-- the red Close button on the bottom edge
	local close = W.Button(frame, 100, 22, "Close", function() frame:Hide() end)
	close:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -24, 18)
	UI.main.optionsClose = close
	W.useBlizzardButtons = false
	-- Escape closes it, like the other addons' options
	if type(UISpecialFrames) == "table" and type(tinsert) == "function" then ns.Safe(tinsert, UISpecialFrames, "ForeverCodexOptionsFrame") end
	rawset(_G, "ForeverCodexOptionsFrame", frame)
	frame:Hide()
end

local function selectTab(key)
	for k, tab in pairs(UI.main.tabs or {}) do tab:SetSelected(k == key) end
	for k, pg in pairs(UI.pages) do
		if isOptionsPage(k) then if k == key then pg.frame:Show() else pg.frame:Hide() end end
	end
	UI.optionsKey = key
end

local function ensureTracker() if not UI.frame then buildTracker() end end
local function ensureOptions() if not UI.options then buildOptions() end end

--- Shows a page: "codex" in the tracker, anything else on its tab of the options window.
local function showPage(key)
	if key == "codex" then
		ensureTracker()
		UI.current = "codex"
		UI.frame:Show()
		P.SetTrackerShown(true)
	else
		ensureOptions()
		selectTab(key)
		UI.current = key
		UI.options:Show()
	end
	UI.Refresh()
end
UI.ShowPage = showPage

local function refreshPage(key)
	local pg = UI.pages[key]
	if pg and pg.Refresh then
		local ok, err = pcall(pg.Refresh)
		if not ok then ns.RecordError("ui page " .. tostring(key), err) end
	end
end

function UI.Refresh()
	if ns.DevUI and ns.DevUI.IsShown and ns.DevUI.IsShown() then ns.DevUI.Refresh() end
	if UI.frame and UI.frame:IsShown() then refreshPage("codex") end
	if UI.options and UI.options:IsShown() and UI.optionsKey then refreshPage(UI.optionsKey) end
end

function UI.IsShown()
	return (UI.frame ~= nil and UI.frame:IsShown()) or (UI.options ~= nil and UI.options:IsShown()) or (ns.DevUI ~= nil and ns.DevUI.IsShown() == true)
end

--- The tracker on / off (the minimap button's left click and /codex). Before setup is finished it opens the options, where setup lives.
function UI.Toggle()
	if not P.SetupDone() then
		ns.State.Recompute()
		showPage("options")
		return
	end
	ensureTracker()
	if UI.frame:IsShown() then
		UI.frame:Hide()
		P.SetTrackerShown(false)
	else
		ns.State.Recompute()
		UI.current = "codex"
		UI.frame:Show()
		P.SetTrackerShown(true)
		UI.Refresh()
	end
end

--- The options window on / off (the minimap button's right click).
function UI.ToggleOptions()
	ensureOptions()
	if UI.options:IsShown() then
		UI.options:Hide()
	else
		ns.State.Recompute()
		showPage(UI.optionsKey or "options")
	end
end

--- Opens a page: "codex" is the tracker; "options", "world", "journey" and "appendices" are the options window's tabs.
function UI.Open(key)
	ns.State.Recompute()
	showPage((key == "codex" or isOptionsPage(key)) and key or "codex")
end

function UI._Build()
	ensureTracker()
end
