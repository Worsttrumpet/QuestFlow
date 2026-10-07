-- UI: first-time setup and the Codex Options. One layout for both: SECTIONS (a small gold header and a thin rule), CHECK ROWS (a check box, a label and one dim line saying what it changes) and
-- DROPDOWNS (the current choice is always visible on the button; a short list opens under it). Appearance settings (the arrow, the look of Codex, the game's own tracker) live on the Themes tab.
--
--   setup (first run)   "Welcome to Quest Flow", three short steps: 1 what Quest Flow is (NOW, ALSO DO, and that it uses what the game offers), 2 how it looks and what is on screen (theme, tracker, waypoint,
--                       arrow), 3 your route (where to level, how to play, what else to look out for) and Get Started. Everything else is in Quest Flow Options later.
--   settings            YOUR ROUTE (where to level, how to play), WHAT CODEX DOES (waypoint, extras, Hardcore, party news), and Run setup again.

local addonName, ns = ...
local R = ns.Registry
local P = ns.Prefs
local W = ns.Widgets
local UI = ns.UI

local WIDTH = UI.WIDTH - 24
local PARTY_OPTIONS = { { key = "ui", label = "Show a party card" }, { key = "off", label = "Off" } }
local LABEL_W, DROP_X, DROP_W = 112, 120, 210

local function recompute() ns.State.Recompute() end

local function zoneOptions()
	local out = { { key = "auto", label = "Wherever I am" } }
	for _, z in ipairs(R.Zones()) do out[#out + 1] = { key = z.key, label = z.label or z.key } end
	return out
end

local function styleOptions()
	local out = {}
	for _, s in ipairs(R.Strategies()) do if s.active ~= false then out[#out + 1] = { key = s.key, label = s.label or s.key } end end
	return out
end

local STYLE_HELP = {
	efficient = "Fewer detours: quests that fit your level and keep the walking short.",
	completionist = "Everything the zone offers, nearest first. Low-level quests are not hidden.",
	questing = "Quest steps and the travel between them only. No flight or other extras.",
}
local ZONE_HELP = "Quest Flow plans quests in this zone. \"Wherever I am\" follows you from zone to zone."

--- A labelled dropdown row: label on the left, the dropdown, then a dim line of help under it. Returns the dropdown (d.help is the help line).
local function dropdownRow(f, y, label, onSelect)
	local fs = W.Line(f, 12, W.GREY, "LEFT")
	fs:SetText(label)
	fs:SetPoint("TOPLEFT", f, "TOPLEFT", 0, y - 4)
	fs:SetWidth(LABEL_W)
	local d = W.Dropdown(f, DROP_X, y, DROP_W, onSelect)
	d.help = W.Line(f, 11, W.DIM, "LEFT", true)
	d.help:SetPoint("TOPLEFT", f, "TOPLEFT", DROP_X, y - 25)
	d.help:SetWidth(WIDTH - DROP_X - 8)
	return d
end

--- Builds the panel into `parent`. mode: "setup" (first run) or "settings". Returns { frame, Refresh, w }.
function UI.BuildSetup(parent, mode)
	local f = CreateFrame("Frame", nil, parent)
	f:SetSize(UI.WIDTH - 16, UI.HEIGHT - 40)
	f:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
	local w = {}
	local isSetup = mode == "setup"
	local y = -2
	w.title = W.Line(f, 14, W.WARM_GOLD, "LEFT")
	w.title:SetPoint("TOPLEFT", f, "TOPLEFT", 0, y)
	w.title:SetWidth(WIDTH)
	w.title:SetText(isSetup and "Welcome to Quest Flow" or "Quest Flow Options")
	y = y - 20
	local s1, s2, s3
	if isSetup then
		-- the logo (the same file the minimap button and the add-on list use) and the three steps; step groups are children of f, shown one at a time
		w.logo = f:CreateTexture(nil, "ARTWORK")
		w.logo:SetSize(48, 48)
		w.logo:SetPoint("TOPRIGHT", f, "TOPRIGHT", -6, -2)
		ns.Safe(w.logo.SetTexture, w.logo, "Interface\\AddOns\\QuestFlow\\Media\\QuestFlowLogo.tga")
		w.tagline = W.Line(f, 12, W.TEXT, "LEFT")
		w.tagline:SetPoint("TOPLEFT", f, "TOPLEFT", 0, y)
		w.tagline:SetWidth(WIDTH - 60)
		w.tagline:SetText("See what's available. Choose what comes next.")
		y = y - 22
	end
	w.char = W.Line(f, 12, W.DIM, "LEFT")
	w.char:SetPoint("TOPLEFT", f, "TOPLEFT", 0, y)
	w.char:SetWidth(WIDTH)
	y = y - 26
	if isSetup then
		local function group()
			local g = CreateFrame("Frame", nil, f)
			g:SetSize(UI.WIDTH - 16, UI.HEIGHT - 110)
			g:SetPoint("TOPLEFT", f, "TOPLEFT", 0, y)
			g:Hide()
			return g
		end
		s1, s2, s3 = group(), group(), group()
		w.groups = { s1, s2, s3 }
		w.step = 1
	end
	local hostRoute, ry = f, y
	if isSetup then hostRoute, ry = s3, -2 end

	local y0 = y
	y = ry
	w.routeHead = W.Section(hostRoute, "YOUR ROUTE", 0, y, WIDTH)
	y = y - 24
	w.zone = dropdownRow(hostRoute, y, "Where to level", function(key) P.SetRouteZone(key); recompute() end)
	y = y - W.ROW_H_DROP
	w.style = dropdownRow(hostRoute, y, "How to play", function(key) P.SetStyle(key); recompute() end)
	y = y - W.ROW_H_DROP - 2

	-- the systems Codex can consider (only those that exist: planned ones are not offered)
	w.sys = {}
	local sysShown = false
	for _, s in ipairs(R.Systems()) do
		if not s.planned then
			if not sysShown then
				w.sysHead = W.Section(hostRoute, isSetup and "ALSO LOOK OUT FOR" or "WHAT QUEST FLOW DOES", 0, y, WIDTH)
				y = y - 24
				sysShown = true
			end
			local b = W.CheckRow(hostRoute, 0, y, WIDTH, function() P.ToggleSystem(s.key); recompute() end)
			b.sysKey, b.sysLabel, b.sysDesc = s.key, s.label, s.desc
			b.text = b.label
			w.sys[#w.sys + 1] = b
			y = y - W.ROW_H_CHECK
		end
	end

	if isSetup then
		-- STEP 1: what Quest Flow is
		local y1 = -2
		local function block(parent, yy, head, text, h)
			local hd = W.Line(parent, 12, W.WARM_GOLD, "LEFT")
			hd:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, yy)
			hd:SetText(head)
			local tx = W.Line(parent, 12, W.TEXT, "LEFT", true)
			tx:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, yy - 17)
			tx:SetWidth(WIDTH - 8)
			tx:SetText(text)
			return hd, tx, yy - 17 - h - 10
		end
		w.welcome = W.Line(s1, 12, W.TEXT, "LEFT", true)
		w.welcome:SetPoint("TOPLEFT", s1, "TOPLEFT", 0, y1)
		w.welcome:SetWidth(WIDTH - 8)
		w.welcome:SetText("Quest Flow is a questing companion. It helps you decide what to do next as you play, and you stay in control.")
		y1 = y1 - 44
		w.nowHead, w.nowText, y1 = block(s1, y1, "NOW", "The best next thing to do, worked out from your quests, your progress, where you are and what you are heading for.", 32)
		w.alsoHead, w.alsoText, y1 = block(s1, y1, "ALSO DO", "Other quests or objectives worth a look while you are already in the area or passing through.", 32)
		w.honestHead, w.honestText, y1 = block(s1, y1, "ONLY WHAT IS REALLY OFFERED", "Quest Flow does not assume every quest it knows about is available. Where it can, it uses what the game itself offers you.", 46)
		w.next1 = W.Button(s1, 120, 24, "Next >", function() w.ShowStep(2) end)
		w.next1:SetPoint("TOPLEFT", s1, "TOPLEFT", 0, y1 - 6)
		w.dots1 = W.Line(s1, 11, W.DIM, "LEFT")
		w.dots1:SetPoint("LEFT", w.next1, "RIGHT", 12, 0)
		w.dots1:SetText("Step 1 of 3")

		-- STEP 2: how it looks and what is on screen (all existing settings; the theme restyles the window at once, so that is the preview)
		local y2 = -2
		w.lookHead = W.Section(s2, "LOOK OF QUEST FLOW", 0, y2, WIDTH)
		y2 = y2 - 24
		w.theme = dropdownRow(s2, y2, "Theme", function(key) ns.Theme.Set(key); UI.Refresh() end)
		y2 = y2 - W.ROW_H_DROP - 2
		w.screenHead = W.Section(s2, "ON YOUR SCREEN", 0, y2, WIDTH)
		y2 = y2 - 24
		w.trackerOn = W.CheckRow(s2, 0, y2, WIDTH, function() P.SetTrackerShown(not P.TrackerShown()) end)
		y2 = y2 - W.ROW_H_CHECK
		w.navOn = W.CheckRow(s2, 0, y2, WIDTH, function() P.SetNavigation(not P.NavigationOn()); recompute() end)
		y2 = y2 - W.ROW_H_CHECK
		w.arrowOn = W.CheckRow(s2, 0, y2, WIDTH, function() P.SetArrow(not P.ArrowOn()) end)
		y2 = y2 - W.ROW_H_CHECK
		w.back2 = W.Button(s2, 90, 24, "< Back", function() w.ShowStep(1) end)
		w.back2:SetPoint("TOPLEFT", s2, "TOPLEFT", 0, y2 - 8)
		w.next2 = W.Button(s2, 120, 24, "Next >", function() w.ShowStep(3) end)
		w.next2:SetPoint("LEFT", w.back2, "RIGHT", 10, 0)
		w.dots2 = W.Line(s2, 11, W.DIM, "LEFT")
		w.dots2:SetPoint("LEFT", w.next2, "RIGHT", 12, 0)
		w.dots2:SetText("Step 2 of 3")

		-- STEP 3: your route (built above into s3) and the final action
		w.start = W.Button(s3, 140, 24, "Get Started", function()
			P.FinishSetup()
			w.step = 1
			recompute()
			if P.TrackerShown() then
				UI.Open("codex")                                  -- show the tracker; the options window stays open on Quest Flow Options
			elseif UI.options then
				UI.options:Hide()                                 -- the player turned the tracker off: just close the welcome
			end
		end)
		w.start:SetPoint("TOPLEFT", s3, "TOPLEFT", 0, y - 12)
		w.back3 = W.Button(s3, 90, 24, "< Back", function() w.ShowStep(2) end)
		w.back3:SetPoint("LEFT", w.start, "RIGHT", 10, 0)
		w.dots3 = W.Line(s3, 11, W.DIM, "LEFT")
		w.dots3:SetPoint("LEFT", w.back3, "RIGHT", 12, 0)
		w.dots3:SetText("Step 3 of 3   Everything here can be changed later in Quest Flow Options.")

		function w.ShowStep(n)
			w.step = math.max(1, math.min(3, n))
			for i, g in ipairs(w.groups) do if i == w.step then g:Show() else g:Hide() end end
		end
	else
		if not sysShown then
			w.sysHead = W.Section(f, "WHAT QUEST FLOW DOES", 0, y, WIDTH)
			y = y - 24
		end
		w.nav = W.CheckRow(f, 0, y, WIDTH, function() P.SetNavigation(not P.NavigationOn()); recompute() end)
		w.nav.text = w.nav.label
		y = y - W.ROW_H_CHECK
		w.hardcore = W.CheckRow(f, 0, y, WIDTH, function() P.SetHardcore(not P.IsHardcore()); recompute() end)
		w.hardcore.text = w.hardcore.label
		y = y - W.ROW_H_CHECK
		w.questie = W.CheckRow(f, 0, y, WIDTH, function() P.SetUseQuestieDB(not P.UseQuestieDB()); if ns.QuestieBridge then ns.Safe(ns.QuestieBridge.Init) end; recompute() end)
		y = y - W.ROW_H_CHECK
		w.party = dropdownRow(f, y, "Party news", function(key) P.SetPartyNotify(key) end)
		y = y - W.ROW_H_DROP - 4
		w.again = W.Button(f, 150, 22, "Run setup again", function() P.ReopenSetup(); UI.ShowPage("codex") end)
		w.again:SetPoint("TOPLEFT", f, "TOPLEFT", 0, y)
		w.againHelp = W.Line(f, 11, W.DIM, "LEFT")
		w.againHelp:SetPoint("LEFT", w.again, "RIGHT", 10, 0)
		w.againHelp:SetText("Shows the welcome choices again.")
	end

	local function refresh()
		local ctx = ns.State.ctx
		w.char:SetText(ctx and ns.Presenter.Header(ctx) or "")
		w.zone:SetOptions(zoneOptions())
		w.zone:SetValue(P.GetRouteZone())
		w.zone.help:SetText(ZONE_HELP)
		w.style:SetOptions(styleOptions())
		w.style:SetValue(P.GetStyle())
		local st = R.Strategy(P.GetStyle())
		w.style.help:SetText(STYLE_HELP[P.GetStyle()] or (st and st.desc) or "")
		for _, b in ipairs(w.sys) do b:SetOn(P.IsSystemOn(b.sysKey), b.sysLabel, b.sysDesc) end
		if isSetup then
			w.ShowStep(w.step or 1)
			local key = ns.Theme.Key()
			local opts = {}
			for _, k in ipairs(ns.Theme.ORDER) do opts[#opts + 1] = { key = k, label = ns.Theme.THEMES[k].name } end
			w.theme:SetOptions(opts)
			w.theme:SetValue(key)
			w.theme.help:SetText(ns.Theme.THEMES[key].desc .. " The window changes as you pick.")
			w.trackerOn:SetOn(P.TrackerShown(), "Show the quest tracker", "The Quest Flow window that lists NOW and what else is worth doing. You can also open it from the minimap button.")
			w.navOn:SetOn(P.NavigationOn(), "Move the map waypoint for me", "Quest Flow points the game's waypoint at your current target. A waypoint you set yourself is left alone.")
			w.arrowOn:SetOn(P.ArrowOn(), "Show the direction arrow", "A small arrow on your screen that points at your current target.")
		end
		if not isSetup then
			w.nav:SetOn(P.NavigationOn(), "Move the map waypoint for me", "Quest Flow points the game's waypoint at your current target. A waypoint you set yourself is left alone.")
			w.hardcore:SetOn(P.IsHardcore(), "Hardcore character", "Quest Flow will never suggest a shortcut that needs you to die.")
			w.questie:SetOn(P.UseQuestieDB(), "Use QuestieDB quest data if installed", "Where quests are, and what comes first, from the QuestieDB addon. It is third-party data, not something Quest Flow saw on Forever.")
			w.party:SetOptions(PARTY_OPTIONS)
			w.party:SetValue(P.PartyNotify())
			w.party.help:SetText(P.PartyNotify() == "off" and "Nothing about your party is shown." or "A card shows what your party members have finished.")
		end
	end
	local self = { frame = f, Refresh = refresh, w = w }
	f:Hide()
	return self
end
