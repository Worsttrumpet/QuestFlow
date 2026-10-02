-- UI: the setup panel. Shown once ("Here's your character"), then reachable later as Appendices > Settings.
-- Setup picks the route zone, the route style and the systems Codex should consider; Settings adds navigation, markers,
-- party notifications and Hardcore. After setup the main window shows none of this: it shows the decision.

local addonName, ns = ...
local R = ns.Registry
local P = ns.Prefs
local W = ns.Widgets
local UI = ns.UI

local WIDTH = UI.WIDTH - 24
local PARTY_LABEL = { off = "Off", ui = "In the window only", party = "Party chat", both = "Window and party chat" }

local function recompute() ns.State.Recompute() end

local function zoneKeys()
	local keys = { "auto" }
	for _, z in ipairs(R.Zones()) do keys[#keys + 1] = z.key end
	return keys
end

local function activeStyles()
	local out = {}
	for _, s in ipairs(R.Strategies()) do if s.active ~= false then out[#out + 1] = s.key end end
	return out
end

local function step(list, current, dir)
	local idx = 1
	for i, k in ipairs(list) do if k == current then idx = i end end
	idx = idx + dir
	if idx < 1 then idx = #list elseif idx > #list then idx = 1 end
	return list[idx]
end

local function zoneLabel(key)
	if key == "auto" then return "Wherever I am" end
	local z = R.ZoneByKey(key)
	return z and z.label or key
end

local function styleLabel(key)
	local s = R.Strategy(key)
	return s and s.label or key
end

local function picker(frame, y, label, onStep)
	local fs = W.Text(frame, W.GREY)
	W.Place(fs, frame, 0, y, 110)
	fs:SetText(label)
	local prev = W.Button(frame, 22, 20, "<", function() onStep(-1) end)
	prev:SetPoint("TOPLEFT", frame, "TOPLEFT", 112, y + 4)
	local value = W.Text(frame, W.WHITE)
	W.Place(value, frame, 140, y, 170)
	local nxt = W.Button(frame, 22, 20, ">", function() onStep(1) end)
	nxt:SetPoint("TOPLEFT", frame, "TOPLEFT", 312, y + 4)
	return value, prev, nxt
end

local function toggle(frame, y, onClick)
	local b = W.Button(frame, WIDTH, 20, "", onClick)
	b:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, y + 4)
	b.text:SetPoint("LEFT", b, "LEFT", 6, 0)
	ns.Safe(b.text.SetJustifyH, b.text, "LEFT")
	return b
end

local function box(on, text) return (on and "[x] " or "[ ] ") .. text end

--- Builds the panel into `parent`. mode: "setup" (first run) or "settings". Returns { frame, Refresh, w }.
function UI.BuildSetup(parent, mode)
	local f = CreateFrame("Frame", nil, parent)
	f:SetSize(UI.WIDTH - 16, UI.HEIGHT - 40)
	f:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
	local w = {}
	local isSetup = mode == "setup"
	local y = -2
	w.title = W.Text(f, W.GOLD)
	W.Place(w.title, f, 0, y, WIDTH)
	w.title:SetText(isSetup and "Here's your character." or "Settings")
	y = y - 20
	w.char = W.Text(f, W.WHITE)
	W.Place(w.char, f, 0, y, WIDTH)
	y = y - 30
	w.zone = picker(f, y, "Where to level", function(dir)
		P.SetRouteZone(step(zoneKeys(), P.GetRouteZone(), dir))
		recompute()
	end)
	y = y - 26
	w.style = picker(f, y, "How to play", function(dir)
		P.SetStyle(step(activeStyles(), P.GetStyle(), dir))
		recompute()
	end)
	y = y - 30
	w.sysHead = W.Text(f, W.GREY)
	W.Place(w.sysHead, f, 0, y, WIDTH)
	w.sysHead:SetText("Let Codex also look out for")
	y = y - 20
	w.sys = {}
	for _, s in ipairs(R.Systems()) do
		if not s.planned then
			local b = toggle(f, y, function()
				P.ToggleSystem(s.key)
				recompute()
			end)
			b.sysKey, b.sysLabel = s.key, s.label
			w.sys[#w.sys + 1] = b
			y = y - 22
		end
	end
	if isSetup then
		w.start = W.Button(f, 120, 24, "Start", function()
			P.FinishSetup()
			recompute()
			UI.Refresh()
		end)
		w.start:SetPoint("TOPLEFT", f, "TOPLEFT", 0, y - 14)
	else
		y = y - 6
		w.nav = toggle(f, y, function() P.SetNavigation(not P.NavigationOn()); recompute() end)
		y = y - 22
		w.arrow = toggle(f, y, function() P.SetArrow(not P.ArrowOn()) end)
		y = y - 22
		w.pins = toggle(f, y, function() P.SetPins(not P.PinsOn()); recompute() end)
		y = y - 22
		w.markers = toggle(f, y, function()
			local st = ns.Markers.Status()
			if st.probe ~= "passed" then
				ns.Say("World markers stay off until the quick test passes: target an NPC and type /codex markers probe.")
			else
				P.SetMarkers(not P.MarkersOn())
			end
			recompute()
		end)
		y = y - 22
		w.hardcore = toggle(f, y, function() P.SetHardcore(not P.IsHardcore()); recompute() end)
		y = y - 26
		w.party = picker(f, y, "Party news", function(dir) P.SetPartyNotify(step(P.PARTY_MODES, P.PartyNotify(), dir)) end)
		y = y - 30
		w.again = W.Button(f, 150, 22, "Run setup again", function() P.ReopenSetup(); UI.ShowPage("codex") end)
		w.again:SetPoint("TOPLEFT", f, "TOPLEFT", 0, y)
	end

	local function refresh()
		local ctx = ns.State.ctx
		w.char:SetText(ctx and ns.Presenter.Header(ctx) or "")
		w.zone:SetText(zoneLabel(P.GetRouteZone()))
		w.style:SetText(styleLabel(P.GetStyle()))
		for _, b in ipairs(w.sys) do b.text:SetText(box(P.IsSystemOn(b.sysKey), b.sysLabel)) end
		if not isSetup then
			w.nav.text:SetText(box(P.NavigationOn(), "Waypoint follows what Codex recommends"))
			w.arrow.text:SetText(box(P.ArrowOn(), "Small direction arrow"))
			w.pins.text:SetText(box(P.PinsOn(), "Pins on the world map"))
			local st = ns.Markers.Status()
			w.markers.text:SetText(box(P.MarkersOn() and st.enabled, "World markers" .. (st.probe == "passed" and "" or " (needs a quick test)")))
			w.hardcore.text:SetText(box(P.IsHardcore(), "This is a Hardcore character"))
			w.party:SetText(PARTY_LABEL[P.PartyNotify()] or P.PartyNotify())
		end
	end
	local self = { frame = f, Refresh = refresh, w = w }
	f:Hide()
	return self
end
