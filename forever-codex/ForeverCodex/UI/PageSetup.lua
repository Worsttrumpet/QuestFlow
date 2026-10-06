-- UI: first-time setup and the Codex Options. One layout for both: SECTIONS (a small gold header and a thin rule), CHECK ROWS (a check box, a label and one dim line saying what it changes) and
-- DROPDOWNS (the current choice is always visible on the button; a short list opens under it). Appearance settings (the arrow, the look of Codex, the game's own tracker) live on the Themes tab.
--
--   setup (first run)   "Welcome to Forever Codex": where to level, how to play, what else to look out for, Start. Nothing else: everything else is in Codex Options later.
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
local ZONE_HELP = "Codex plans quests in this zone. \"Wherever I am\" follows you from zone to zone."

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
	w.title:SetText(isSetup and "Welcome to Forever Codex" or "Codex Options")
	y = y - 20
	if isSetup then
		w.intro = W.Line(f, 12, W.TEXT, "LEFT", true)
		w.intro:SetPoint("TOPLEFT", f, "TOPLEFT", 0, y)
		w.intro:SetWidth(WIDTH)
		w.intro:SetText("Codex is ready to help guide your adventure. It tells you what to do next as you play, and you stay in control. Two quick choices to start (you can change them later in Codex Options):")
		y = y - 44
	end
	w.char = W.Line(f, 12, W.DIM, "LEFT")
	w.char:SetPoint("TOPLEFT", f, "TOPLEFT", 0, y)
	w.char:SetWidth(WIDTH)
	y = y - 26

	w.routeHead = W.Section(f, "YOUR ROUTE", 0, y, WIDTH)
	y = y - 24
	w.zone = dropdownRow(f, y, "Where to level", function(key) P.SetRouteZone(key); recompute() end)
	y = y - W.ROW_H_DROP
	w.style = dropdownRow(f, y, "How to play", function(key) P.SetStyle(key); recompute() end)
	y = y - W.ROW_H_DROP - 2

	-- the systems Codex can consider (only those that exist: planned ones are not offered)
	w.sys = {}
	local sysShown = false
	for _, s in ipairs(R.Systems()) do
		if not s.planned then
			if not sysShown then
				w.sysHead = W.Section(f, isSetup and "ALSO LOOK OUT FOR" or "WHAT CODEX DOES", 0, y, WIDTH)
				y = y - 24
				sysShown = true
			end
			local b = W.CheckRow(f, 0, y, WIDTH, function() P.ToggleSystem(s.key); recompute() end)
			b.sysKey, b.sysLabel, b.sysDesc = s.key, s.label, s.desc
			b.text = b.label
			w.sys[#w.sys + 1] = b
			y = y - W.ROW_H_CHECK
		end
	end

	if isSetup then
		w.start = W.Button(f, 120, 24, "Start", function()
			P.FinishSetup()
			recompute()
			UI.Open("codex")                                  -- show the tracker; the options window stays open on Codex Options
		end)
		w.start:SetPoint("TOPLEFT", f, "TOPLEFT", 0, y - 14)
	else
		if not sysShown then
			w.sysHead = W.Section(f, "WHAT CODEX DOES", 0, y, WIDTH)
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
		if not isSetup then
			w.nav:SetOn(P.NavigationOn(), "Move the map waypoint for me", "Codex points the game's waypoint at your current target. A waypoint you set yourself is left alone.")
			w.hardcore:SetOn(P.IsHardcore(), "Hardcore character", "Codex will never suggest a shortcut that needs you to die.")
			w.questie:SetOn(P.UseQuestieDB(), "Use QuestieDB quest data if installed", "Where quests are, and what comes first, from the QuestieDB addon. It is third-party data, not something Codex saw on Forever.")
			w.party:SetOptions(PARTY_OPTIONS)
			w.party:SetValue(P.PartyNotify())
			w.party.help:SetText(P.PartyNotify() == "off" and "Nothing about your party is shown." or "A card shows what your party members have finished.")
		end
	end
	local self = { frame = f, Refresh = refresh, w = w }
	f:Hide()
	return self
end
