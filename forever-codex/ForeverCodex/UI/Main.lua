-- ForeverCodex.UI (the PLAYER window): a compact companion, not a database. "Hide the machinery, show the decision."
--
--   [ Codex | World | Journey | Appendices ]
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

UI.WIDTH, UI.HEIGHT = 400, 360
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

--- A small coloured square with a letter (the ASCII stand-in for the world-marker symbols).
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

local function savePosition(frame)
	local ok, point, _, rel, x, y = pcall(frame.GetPoint, frame, 1)
	if ok and type(point) == "string" and type(x) == "number" and type(y) == "number" then
		P.SetWindowPos({ point = point, rel = rel or point, x = x, y = y })
	end
end

local function restorePosition(frame)
	local pos = P.WindowPos()
	frame:ClearAllPoints()
	if type(pos) == "table" and pos.point and type(pos.x) == "number" and type(pos.y) == "number" then
		frame:SetPoint(pos.point, UIParent, pos.rel or pos.point, pos.x, pos.y)
	else
		frame:SetPoint("CENTER")
	end
end

local function showPage(key)
	UI.current = key
	for k, pg in pairs(UI.pages) do
		if k == key then pg.frame:Show() else pg.frame:Hide() end
	end
	for k, b in pairs(UI.main.tabs or {}) do
		W.SetColor(b.text, k == key and W.GOLD or W.GREY)
		b.bg:SetColorTexture(k == key and 0.3 or 0.15, k == key and 0.3 or 0.15, k == key and 0.12 or 0.15, 0.95)
	end
	UI.Refresh()
end
UI.ShowPage = showPage

local function build()
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
	local bg = frame:CreateTexture(nil, "BACKGROUND")
	bg:SetAllPoints()
	bg:SetColorTexture(0, 0, 0, 0.88)
	UI.frame = frame
	UI.main.tabs = {}
	local x = 8
	for _, def in ipairs(UI.pageDefs) do
		local b = W.Button(frame, 88, 20, def.label, function() showPage(def.key) end)
		b:SetPoint("TOPLEFT", frame, "TOPLEFT", x, -6)
		UI.main.tabs[def.key] = b
		x = x + 92
		local pf = CreateFrame("Frame", nil, frame)
		pf:SetSize(UI.WIDTH - 16, UI.HEIGHT - 40)
		pf:SetPoint("TOPLEFT", frame, "TOPLEFT", 8, -32)
		local page = def.build(pf) or {}
		page.frame = pf
		UI.pages[def.key] = page
	end
	local close = W.Button(frame, 18, 18, "x", function() frame:Hide() end)
	close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -4, -4)
	UI.main.close = close
	showPage(UI.current)
end

function UI.Refresh()
	if ns.DevUI and ns.DevUI.IsShown and ns.DevUI.IsShown() then ns.DevUI.Refresh() end
	if not UI.frame or not UI.frame:IsShown() then return end
	local pg = UI.pages[UI.current]
	if pg and pg.Refresh then
		local ok, err = pcall(pg.Refresh)
		if not ok then ns.RecordError("ui page " .. tostring(UI.current), err) end
	end
end

function UI.IsShown()
	return (UI.frame ~= nil and UI.frame:IsShown()) or (ns.DevUI ~= nil and ns.DevUI.IsShown() == true)
end

function UI.Toggle()
	if not UI.frame then
		build()
		ns.State.Recompute()
		UI.frame:Show()
		UI.Refresh()
		return
	end
	if UI.frame:IsShown() then
		UI.frame:Hide()
	else
		ns.State.Recompute()
		UI.frame:Show()
		UI.Refresh()
	end
end

--- Opens the window on a page ("codex", "world", "journey", "appendices").
function UI.Open(key)
	if not UI.frame then build() end
	UI.frame:Show()
	ns.State.Recompute()
	showPage(UI.pages[key] and key or "codex")
end

function UI._Build() if not UI.frame then build() end end
