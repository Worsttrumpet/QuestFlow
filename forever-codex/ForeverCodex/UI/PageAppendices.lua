-- UI page "Appendices": reference and settings, kept compact: one list, one page at a time.
--   Quests (search and see where you stand)  Knowledge (trainers, recipes, pets, flight paths: what Codex can and cannot see)
--   Settings  Help Improve Codex  Party

local addonName, ns = ...
local W = ns.Widgets
local UI = ns.UI

local WIDTH = UI.WIDTH - 24
local RESULTS = 6
local ENTRIES = { { "quests", "Quests" }, { "knowledge", "Knowledge" }, { "help", "Help Improve Codex" }, { "party", "Party" } }

local function lineAt(parent, y, color, wrap, x, width)
	local fs = W.Text(parent, color)
	W.Place(fs, parent, x or 0, y, width or WIDTH)
	if wrap then ns.Safe(fs.SetWordWrap, fs, true) end
	return fs
end

local function buildQuests(f, w)
	w.qHint = lineAt(f, -30, W.GREY)
	w.qHint:SetText("Type part of a quest name")
	local box = CreateFrame("EditBox", nil, f)
	box:SetSize(WIDTH - 10, 20)
	box:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -46)
	box:SetAutoFocus(false)
	ns.Safe(box.SetMaxLetters, box, 50)
	ns.Safe(box.SetFontObject, box, GameFontNormal)
	box.bg = box:CreateTexture(nil, "BACKGROUND")
	box.bg:SetAllPoints()
	box.bg:SetColorTexture(0.15, 0.15, 0.15, 0.95)
	box:SetScript("OnEscapePressed", function(self) ns.Safe(self.ClearFocus, self) end)
	w.qBox = box
	w.qRows = {}
	for i = 1, RESULTS do
		w.qRows[i] = { name = lineAt(f, -74 - (i - 1) * 34, W.WHITE), state = lineAt(f, -74 - (i - 1) * 34 - 15, W.GREY) }
	end
	box:SetScript("OnTextChanged", function() UI.pages.appendices.Refresh() end)
end

local function refreshQuests(w)
	local text = w.qBox:GetText() or ""
	local ctx = ns.State.ctx
	local found = ns.Registry.Search(text, RESULTS)
	for i, row in ipairs(w.qRows) do
		local r = found[i]
		if r and ctx then
			local k = ns.Knowledge.Quest(r.id, ctx)
			row.name:SetText(r.name)
			row.state:SetText(k.label .. (k.detail and (" - " .. k.detail) or ""))
		else
			row.name:SetText("")
			row.state:SetText("")
		end
	end
	w.qHint:SetText(#text < 2 and "Type part of a quest name" or (#found == 0 and "No quest matches that." or ""))
end

local function buildKnowledge(f, w)
	w.kRows = {}
	for i = 1, 4 do
		w.kRows[i] = { name = lineAt(f, -30 - (i - 1) * 46, W.WHITE), text = lineAt(f, -30 - (i - 1) * 46 - 16, W.GREY, true) }
	end
end

local function refreshKnowledge(w)
	for i, s in ipairs(ns.Knowledge.Systems()) do
		w.kRows[i].name:SetText(s.label)
		w.kRows[i].text:SetText(s.text)
	end
end

local function buildHelp(f, w)
	local copy = ns.HelpCodex.COPY
	w.hTitle = lineAt(f, -30, W.GOLD)
	w.hTitle:SetText(copy.title)
	w.hTag = lineAt(f, -48, W.GREEN)
	w.hTag:SetText(copy.tagline)
	w.hBody = lineAt(f, -66, W.WHITE, true)
	w.hBody:SetText(copy.body)
	w.hCount = lineAt(f, -132, W.WHITE)
	w.hNote = lineAt(f, -148, W.GREY, true)
	w.hView = W.Button(f, 170, 22, "View What Codex Learned", function() w.learnedShown = not w.learnedShown; UI.pages.appendices.Refresh() end)
	w.hView:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -176)
	w.hClear = W.Button(f, 120, 22, "Clear Data", function()
		if w.confirmClear then
			w.cleared = ns.HelpCodex.Clear()
			w.confirmClear = false
		else
			w.confirmClear = true
		end
		UI.pages.appendices.Refresh()
	end)
	w.hClear:SetPoint("TOPLEFT", f, "TOPLEFT", 180, -176)
	w.hLines = {}
	for i = 1, 8 do w.hLines[i] = lineAt(f, -206 - (i - 1) * 15, W.WHITE, false, 8) end
end

local function refreshHelp(w)
	local s = ns.HelpCodex.Summary()
	w.hCount:SetText(s.text)
	w.hNote:SetText(s.note or "")
	w.hClear.text:SetText(w.confirmClear and "Click again to clear" or "Clear Data")
	local lines = w.learnedShown and ns.HelpCodex.Learned() or {}
	for i, fs in ipairs(w.hLines) do fs:SetText(lines[i] or (i == 1 and w.learnedShown and "Nothing recorded yet." or "")) end
end

local function buildParty(f, w)
	w.pMode = lineAt(f, -30, W.WHITE)
	w.pNote = lineAt(f, -50, W.GREY, true)
	w.pRows = {}
	for i = 1, 6 do w.pRows[i] = { head = lineAt(f, -90 - (i - 1) * 32, W.WHITE), mine = lineAt(f, -90 - (i - 1) * 32 - 15, W.GREY) } end
end

local function refreshParty(w)
	local ctx = ns.State.ctx
	local label = ({ off = "Off", ui = "Party card in the window" })[ns.Prefs.PartyNotify()]
	w.pMode:SetText("Party news: " .. tostring(label) .. "   (change it in Settings)")
	local v = ns.Party.View(ctx)
	w.pNote:SetText(v.note or (ctx.group and ctx.group.inGroup and "" or "You are not in a party."))
	for i, row in ipairs(w.pRows) do
		local e = v.lines[i]
		row.head:SetText(e and e.head or "")
		row.mine:SetText(e and e.mine or "")
	end
end

UI.RegisterPage("appendices", "Appendices", function(parent)
	local w = { sub = "menu", subs = {} }
	UI.main.app = w
	w.menuTitle = lineAt(parent, -2, W.GOLD)
	w.menuTitle:SetText("Reference and settings")
	w.menu = {}
	for i, e in ipairs(ENTRIES) do
		w.menu[e[1]] = W.Button(parent, 200, 24, e[2], function() w.sub = e[1]; UI.pages.appendices.Refresh() end)
		w.menu[e[1]]:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -26 - (i - 1) * 30)
	end
	w.back = W.Button(parent, 70, 20, "< Back", function() w.sub = "menu"; w.confirmClear = false; UI.pages.appendices.Refresh() end)
	w.back:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -2)
	local function sub(key, builder)
		local f = CreateFrame("Frame", nil, parent)
		f:SetSize(UI.WIDTH - 16, UI.HEIGHT - 70)
		f:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -24)
		if builder then builder(f, w) end
		w.subs[key] = f
		return f
	end
	sub("quests", buildQuests)
	sub("knowledge", buildKnowledge)
	sub("help", buildHelp)
	sub("party", buildParty)
	return { Refresh = function()
		local ctx = ns.State.ctx
		if not ctx then return end
		local menu = w.sub == "menu"
		if menu then w.menuTitle:SetText("Reference and settings") else w.menuTitle:SetText("") end
		for _, b in pairs(w.menu) do if menu then b:Show() else b:Hide() end end
		if menu then w.back:Hide() else w.back:Show() end
		for key, f in pairs(w.subs) do if key == w.sub then f:Show() else f:Hide() end end
		if w.sub == "quests" then refreshQuests(w)
		elseif w.sub == "knowledge" then refreshKnowledge(w)
		elseif w.sub == "help" then refreshHelp(w)
		elseif w.sub == "party" then refreshParty(w)
		end
	end }
end)
