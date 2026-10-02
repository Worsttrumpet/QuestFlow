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

UI.WIDTH, UI.HEIGHT = 520, 430
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

--- Sets the window height keeping the TOP edge where it is (a CENTER or BOTTOM anchored frame would otherwise jump).
function UI.FitHeight(h)
	local frame = UI.frame
	if not frame then return end
	h = math.floor(math.max(UI.HEIGHT_MIN, h) + 0.5)
	local old = UI.main.height or UI.HEIGHT
	if h == old then return end
	local ok, point, _, rel, x, y = pcall(frame.GetPoint, frame, 1)
	frame:SetHeight(h)
	UI.main.height = h
	if ok and type(point) == "string" and type(x) == "number" and type(y) == "number" then
		if point:find("BOTTOM") then y = y + (old - h)
		elseif not point:find("TOP") then y = y + (old - h) / 2 end
		frame:ClearAllPoints()
		frame:SetPoint(point, UIParent, rel or point, x, y)
	end
end

local function savePosition(frame)
	local ok, point, _, rel, x, y = pcall(frame.GetPoint, frame, 1)
	if ok and type(point) == "string" and type(x) == "number" and type(y) == "number" then
		P.SetWindowPos({ point = point, rel = rel or point, x = x, y = y, h = UI.main.height })
	end
end

local function restorePosition(frame)
	local pos = P.WindowPos()
	-- the window was saved at the height it had then (the Codex page fits its content): start from that height, so fitting again keeps the top edge where it was
	if type(pos) == "table" and type(pos.h) == "number" and pos.h >= UI.HEIGHT_MIN and pos.h <= 2000 then
		UI.main.height = pos.h
		frame:SetHeight(pos.h)
	end
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
	local nav = UI.main.nav
	if nav then
		for _, def in ipairs(UI.pageDefs) do if def.key == key then nav.button.text:SetText(def.label .. "  v") end end
		nav.menu:Hide()
	end
	if key ~= "codex" then UI.FitHeight(UI.HEIGHT) end        -- only the Codex page fits its content
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
	-- the shell: a 1 px muted-gold border (an outer texture with the fill inset on top), a small title and a separator under the header
	local edge = frame:CreateTexture(nil, "BACKGROUND")
	edge:SetAllPoints()
	edge:SetColorTexture(0.40, 0.33, 0.16, 0.95)
	local bg = frame:CreateTexture(nil, "BORDER")
	bg:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
	bg:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -1, 1)
	bg:SetColorTexture(0.04, 0.04, 0.05, 0.94)
	local title = W.Line(frame, 10, W.DIM, "CENTER")
	title:SetPoint("TOP", frame, "TOP", 0, -11)
	title:SetWidth(200)
	title:SetText("FOREVER CODEX  v" .. tostring(ForeverCodex and ForeverCodex.VERSION or "?"))
	local sep = frame:CreateTexture(nil, "ARTWORK")
	sep:SetPoint("TOPLEFT", frame, "TOPLEFT", 8, -33)
	sep:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -8, -33)
	sep:SetSize(1, 1)
	sep:SetColorTexture(0.40, 0.34, 0.18, 0.55)
	UI.frame = frame
	UI.main.height = UI.main.height or UI.HEIGHT
	local nav = { items = {} }
	UI.main.nav = nav
	nav.button = W.Button(frame, 150, 22, "Codex  v", function() if nav.menu:IsShown() then nav.menu:Hide() else nav.menu:Show() end end)
	nav.button:SetPoint("TOPLEFT", frame, "TOPLEFT", 8, -6)
	nav.menu = CreateFrame("Frame", nil, frame)
	nav.menu:SetSize(150, 4 + 24 * #UI.pageDefs)
	nav.menu:SetPoint("TOPLEFT", frame, "TOPLEFT", 8, -30)
	nav.menu:SetFrameStrata("DIALOG")
	nav.menu.bg = nav.menu:CreateTexture(nil, "BACKGROUND")
	nav.menu.bg:SetAllPoints()
	nav.menu.bg:SetColorTexture(0.08, 0.08, 0.08, 0.98)
	for i, def in ipairs(UI.pageDefs) do
		local b = W.Button(nav.menu, 146, 22, def.label, function() showPage(def.key) end)
		b:SetPoint("TOPLEFT", nav.menu, "TOPLEFT", 2, -2 - (i - 1) * 24)
		nav.items[def.key] = b
	end
	nav.menu:Hide()
	for _, def in ipairs(UI.pageDefs) do
		local pf = CreateFrame("Frame", nil, frame)
		pf:SetSize(UI.WIDTH - 16, UI.HEIGHT - 40)
		pf:SetPoint("TOPLEFT", frame, "TOPLEFT", 8, -36)
		local page = def.build(pf) or {}
		page.frame = pf
		UI.pages[def.key] = page
	end
	-- NEW FOR YOU lasts exactly one minute and then disappears by itself: a light check keeps the card honest while the window is open
	local sinceCheck = 0
	frame:SetScript("OnUpdate", function(_, dt)
		sinceCheck = sinceCheck + (dt or 0)
		if sinceCheck < 0.5 then return end
		sinceCheck = 0
		if UI.current == "codex" and ns.NewForYou and (ns.NewForYou.Active() ~= nil) ~= (UI.main.nfyShown == true) then UI.Refresh() end
	end)
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
