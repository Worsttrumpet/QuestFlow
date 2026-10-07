-- UI/Feedback.lua: the REPORT A PROBLEM window. A small dialog: what happened (one of a few categories), a sentence from the player, one button. Codex captures the technical context
-- itself (Feedback.lua). The window never says a report was SENT: Codex cannot send anything out of the game; it saves the report locally and shows one compact block to copy.
-- Opened by the tracker's Feedback button, the NOW card's Report button, or /codex feedback.

local addonName, ns = ...
local W = ns.Widgets
local UI = ns.UI

local FB = {}                       -- the window's widgets and state (UI.feedback)
UI.feedback = FB
local WIDTH, HEIGHT = 360, 470

local function labelFor(key)
	for _, c in ipairs(ns.Feedback.CATEGORIES) do if c.key == key then return c.label end end
	return key
end

local function paintCategories()
	for _, row in ipairs(FB.rows or {}) do
		row.text:SetText((row.key == FB.category and "(x) " or "( ) ") .. row.label)
		W.SetColor(row.text, row.key == FB.category and W.WARM_GOLD or W.TEXT)
	end
end

local function build()
	local f = CreateFrame("Frame", "ForeverCodexFeedback", UIParent)
	f:SetSize(WIDTH, HEIGHT)
	f:SetPoint("CENTER")
	f:SetFrameStrata("DIALOG")
	f:SetMovable(true)
	f:EnableMouse(true)
	f:RegisterForDrag("LeftButton")
	f:SetScript("OnDragStart", f.StartMoving)
	f:SetScript("OnDragStop", f.StopMovingOrSizing)
	f.bg = f:CreateTexture(nil, "BACKGROUND")
	f.bg:SetAllPoints()
	f.bg:SetColorTexture(0.04, 0.04, 0.05, 0.96)
	FB.frame = f
	local title = W.Line(f, 12, W.WARM_GOLD, "LEFT")
	title:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -12)
	title:SetText("REPORT A PROBLEM")
	local close = W.Button(f, 18, 18, "x", function() f:Hide() end)
	close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -8, -8)
	ns.Safe(tinsert, UISpecialFrames or {}, "ForeverCodexFeedback")

	FB.about = W.Line(f, 11, W.DIM, "LEFT", true)
	FB.about:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -34)
	FB.about:SetWidth(WIDTH - 24)
	FB.privacy = W.Line(f, 10, W.DIM, "LEFT", true)
	FB.privacy:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -56)
	FB.privacy:SetWidth(WIDTH - 24)
	FB.privacy:SetText("Quest Flow will include your current game and addon state (class, level, location, quest log, what Quest Flow is showing and why) to help diagnose the problem. Your character name is not included.")

	local head = W.Line(f, 11, W.TEXT, "LEFT")
	head:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -100)
	head:SetText("What happened?")
	FB.rows = {}
	local y = 118
	for _, c in ipairs(ns.Feedback.CATEGORIES) do
		local b = CreateFrame("Button", nil, f)
		b:SetSize(WIDTH - 24, 16)
		b:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -y)
		local t = W.Line(b, 11, W.TEXT, "LEFT")
		t:SetPoint("LEFT", b, "LEFT", 4, 0)
		local row = { key = c.key, label = c.label, text = t, button = b }
		b:SetScript("OnClick", function() FB.category = c.key; paintCategories() end)
		FB.rows[#FB.rows + 1] = row
		y = y + 17
	end

	local ask = W.Line(f, 11, W.TEXT, "LEFT")
	ask:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -(y + 6))
	ask:SetText("Tell us what happened:")
	local boxBg = f:CreateTexture(nil, "ARTWORK")
	boxBg:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -(y + 22))
	boxBg:SetSize(WIDTH - 24, 70)
	boxBg:SetColorTexture(0.12, 0.12, 0.14, 0.95)
	local box = CreateFrame("EditBox", nil, f)
	box:SetMultiLine(true)
	box:SetAutoFocus(false)
	box:SetFontObject(GameFontNormal)
	box:SetMaxLetters(ns.Feedback.MAX_TEXT)
	box:SetPoint("TOPLEFT", f, "TOPLEFT", 16, -(y + 26))
	box:SetSize(WIDTH - 32, 62)
	box:SetScript("OnEscapePressed", function() f:Hide() end)
	FB.box = box
	FB.create = W.Button(f, 120, 22, "Create Report", function() FB.Submit() end)
	FB.create:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -(y + 98))
	FB.status = W.Line(f, 11, W.SOFT_GREEN, "LEFT", true)
	FB.status:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -(y + 126))
	FB.status:SetWidth(WIDTH - 24)
	-- the one block the player copies
	local sf = CreateFrame("ScrollFrame", "ForeverCodexFeedbackScroll", f, "UIPanelScrollFrameTemplate")
	sf:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -(y + 176))
	sf:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -30, 12)
	local out = CreateFrame("EditBox", nil, sf)
	out:SetMultiLine(true)
	out:SetWidth(WIDTH - 60)
	out:SetAutoFocus(false)
	out:SetFontObject(GameFontNormal)
	out:SetScript("OnEscapePressed", function() f:Hide() end)
	sf:SetScrollChild(out)
	FB.out, FB.scroll = out, sf
	FB.select = W.Button(f, 90, 20, "Select all", function() out:SetFocus(); out:HighlightText() end)
	FB.select:SetPoint("TOPLEFT", f, "TOPLEFT", 140, -(y + 99))
	FB.select:Hide()
	sf:Hide()
	FB.y = y
end

--- Opens the window. opts = { category = key, from = "NOW" | "WINDOW" }: from NOW preselects "wrong recommendation" and says the report is about the current recommendation.
function UI.OpenFeedback(opts)
	opts = opts or {}
	if not FB.frame then build() end
	FB.from = opts.from or "WINDOW"
	FB.category = opts.category or (FB.from == "NOW" and "wrong") or FB.category or "other"
	FB.result = nil
	FB.box:SetText("")
	FB.out:SetText("")
	FB.scroll:Hide()
	FB.select:Hide()
	FB.status:SetText("")
	local card = ns.State and ns.State.ctx and ns.Presenter.Card(ns.State.plan, ns.State.ctx) or nil
	if FB.from == "NOW" and card and card.now then
		FB.about:SetText("About the current recommendation: " .. tostring(card.now.title))
	else
		FB.about:SetText("About: what Quest Flow is showing right now (the report includes it).")
	end
	paintCategories()
	FB.frame:Show()
	ns.Safe(FB.box.SetFocus, FB.box)
end

--- The Create Report button. Returns the result table (or nil when there was nothing written).
function FB.Submit()
	local text = FB.box:GetText() or ""
	if not text:find("%S") then
		FB.status:SetText("Please write a sentence about what happened, then press Create Report.")
		W.SetColor(FB.status, W.WARM_GOLD)
		return nil
	end
	local result = ns.Feedback.Create({ category = FB.category, text = text, from = FB.from })
	FB.result = result
	FB.status:SetText((result.duplicate and "This report was already created. " or "") .. ns.Feedback.StatusText(result))
	W.SetColor(FB.status, W.SOFT_GREEN)
	FB.out:SetText(result.export)
	FB.scroll:Show()
	FB.select:Show()
	ns.Safe(FB.out.SetFocus, FB.out)
	ns.Safe(FB.out.HighlightText, FB.out)
	return result
end

function UI._BuildFeedback() if not FB.frame then build() end end
