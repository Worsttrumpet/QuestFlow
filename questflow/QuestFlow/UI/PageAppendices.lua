-- UI page "Appendices": reference, kept compact: one list, one page at a time.
--   Quests (search and see where you stand)   What Codex knows (trainers, professions, pets, flight paths: what Codex can and cannot see today)
--   Commands and guide (the few slash commands worth knowing, and what each card's marker means)   Help Improve Codex   Party
-- (Settings live on the Codex Options and Themes tabs.)

local addonName, ns = ...
local W = ns.Widgets
local UI = ns.UI

local WIDTH = UI.WIDTH - 24
local RESULTS = 6
local ENTRIES = { { "quests", "Quests" }, { "knowledge", "What Quest Flow knows" }, { "guide", "Commands and card guide" }, { "help", "Help Improve Quest Flow" }, { "party", "Party" } }

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

local K_ROW = 62
local K_ROWS = 6
local function buildKnowledge(f, w)
	w.kIntro = lineAt(f, -30, W.GREY, true)
	w.kIntro:SetText("What Quest Flow knows, by area. It only lists what helps a decision.")
	w.kCat = w.kCat or 1
	w.kTabs = {}
	for i = 1, 7 do
		local b = W.Button(f, 74, 20, "", function() w.kCat = i; UI.pages.appendices.Refresh() end)
		b:SetPoint("TOPLEFT", f, "TOPLEFT", (i - 1) * 78, -50)
		w.kTabs[i] = b
	end
	w.kRows = {}
	for i = 1, K_ROWS do
		local y = -78 - (i - 1) * K_ROW
		w.kRows[i] = { name = lineAt(f, y, W.WHITE), text = lineAt(f, y - 16, W.GREY, true) }
		w.kRows[i].text:SetHeight(K_ROW - 22)
	end
end

local K_SHORT = { quest = "Quests", world = "World", travel = "Travel", player = "You", planner = "Planner", navigation = "Navigate", extra = "More" }
local function refreshKnowledge(w)
	local cats = ns.Knowledge.Categories(ns.State.ctx)
	if w.kCat > #cats then w.kCat = 1 end
	for i, b in ipairs(w.kTabs) do
		local c = cats[i]
		if c then
			b:Show()
			local label = (i == w.kCat and "> " or "") .. (K_SHORT[c.key] or c.label)
			if b.text then b.text:SetText(label) else ns.Safe(b.SetText, b, label) end
		else b:Hide() end
	end
	local rows = cats[w.kCat].rows
	for i = 1, K_ROWS do
		local r, s = w.kRows[i], rows[i]
		r.name:SetText(s and (s.label .. (s.status and ("  -  " .. s.status) or "")) or "")
		r.text:SetText(s and s.text or "")
	end
end

-- COMMANDS AND CARD GUIDE: the commands worth knowing, and what each card's marker letter means (the same letters in every theme)
local LEGEND_ORDER = { "primary", "optional", "urgent", "ready", "discovery", "training", "profession", "dungeon", "world", "progression" }
local function buildGuide(f, w)
	w.gCmdHead = W.Section(f, "COMMANDS", 0, -30, WIDTH)
	w.gCmds = {}
	for i = 1, 8 do
		w.gCmds[i] = { cmd = lineAt(f, -52 - (i - 1) * 17, W.WARM_GOLD, false, 0, 150), text = lineAt(f, -52 - (i - 1) * 17, W.TEXT, false, 154, WIDTH - 158) }
	end
	local ly = -52 - 8 * 17 - 14
	w.gLegendHead = W.Section(f, "WHAT THE MARKERS MEAN", 0, ly, WIDTH)
	w.gLegend = {}
	for i, role in ipairs(LEGEND_ORDER) do
		local col, row = (i - 1) % 2, math.floor((i - 1) / 2)
		local x, y = col * (WIDTH / 2), ly - 24 - row * 19
		local m = W.Marker(f, role, 13)
		m:SetPoint("TOPLEFT", f, "TOPLEFT", x, y)
		local fs = lineAt(f, y - 1, W.TEXT, false, x + 20, WIDTH / 2 - 24)
		fs:SetText(ns.Theme.NAME[role] or role)
		w.gLegend[i] = { marker = m, role = role }
	end
end

local function refreshGuide(w)
	for i, c in ipairs(ns.Knowledge.Commands()) do
		if w.gCmds[i] then w.gCmds[i].cmd:SetText(c[1]); w.gCmds[i].text:SetText(c[2]) end
	end
	for _, e in ipairs(w.gLegend) do e.marker:Set(e.role) end             -- (a theme change re-tints them)
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
	w.hView = W.Button(f, 170, 22, "View What Quest Flow Learned", function() w.learnedShown = not w.learnedShown; UI.pages.appendices.Refresh() end)
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
	local label = ({ off = "Off", ui = "Show a party card" })[ns.Prefs.PartyNotify()]
	w.pMode:SetText("Party news: " .. tostring(label) .. "   (change it in Quest Flow Options)")
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
	w.menuTitle:SetText("Reference")
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
	sub("guide", buildGuide)
	sub("help", buildHelp)
	sub("party", buildParty)
	return { Refresh = function()
		local ctx = ns.State.ctx
		if not ctx then return end
		local menu = w.sub == "menu"
		if menu then w.menuTitle:SetText("Reference") else w.menuTitle:SetText("") end
		for _, b in pairs(w.menu) do if menu then b:Show() else b:Hide() end end
		if menu then w.back:Hide() else w.back:Show() end
		for key, f in pairs(w.subs) do if key == w.sub then f:Show() else f:Hide() end end
		if w.sub == "quests" then refreshQuests(w)
		elseif w.sub == "knowledge" then refreshKnowledge(w)
		elseif w.sub == "guide" then refreshGuide(w)
		elseif w.sub == "help" then refreshHelp(w)
		elseif w.sub == "party" then refreshParty(w)
		end
	end }
end)
