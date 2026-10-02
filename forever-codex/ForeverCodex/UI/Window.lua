-- ForeverCodex.DevUI: the DEVELOPER window (/codex dev): the engineering view with provenance, route pickers and the old buttons.
-- Normal players get the compact window in UI/Main.lua.
--
--   header      character, race origin / route zone / current location (three separate things)
--   controls    route zone  < >   and   route style  < >
--   NEXT card   the recommended action, why, where, its status, Show on Map / Skip / Add
--   coming up   the next few stops;   while you're here   things close to you right now
--   systems     toggles (planned systems are greyed out and cannot be switched on)
--
-- The window only RENDERS ns.State.plan and forwards clicks to Preferences; it holds no logic of its own, and it
-- is split into small builder functions (M8.13's build() was within 3 upvalues of Lua's limit of 60).
-- Provenance wording: ATT-derived data is always shown as "ATT, unverified". Nothing in this window calls ATT data
-- "confirmed".

local addonName, ns = ...
local R = ns.Registry
local P = ns.Prefs
local W = ns.Widgets

local UI = {}
ns.DevUI = UI      -- the developer window (/codex dev); the player window is ns.UI (UI/Main.lua)

local WIDTH, HEIGHT = 500, 668
local UPCOMING_ROWS, NEARBY_ROWS, DETAIL_LINES, ADD_ROWS = 6, 4, 6, 6

UI.w = {}  -- widgets by name (kept in one table so no function needs many upvalues)

-- ---------------------------------------------------------------- actions the buttons trigger

local function recompute()
	ns.State.Recompute()
end

--- Places the game's own map waypoint for an action (the proven M8.6-B path). Never raises.
function UI.ShowOnMap(a)
	local t = a and a.target
	if not t then
		ns.Say("There is no location to show for this recommendation.")
		return false
	end
	local note
	if t.approx then
		note = "Approximate position (a player position seen on Forever, not the NPC)."
	elseif t.verified then
		note = "Position observed on Forever."
	else
		note = (t.src == "questiedb" and "QuestieDB position" or "ATT-derived position") .. ", unverified on Forever."
	end
	local ok, why = ns.MapPin.Place(t.map, t.x, t.y, t.label or a.title, note)
	if not ok then ns.Say("Could not place a map pin: " .. tostring(why)) end
	return ok
end

local function onShowMap()
	local plan = ns.State.plan
	if plan and plan.next then UI.ShowOnMap(plan.next) end
end

local function onSkip()
	local plan = ns.State.plan
	local a = plan and plan.next
	if not a then return end
	if P.Skip(a.skipKey) then
		ns.Say("Skipped: " .. tostring(a.title) .. ". (/codex unskip brings skipped items back.)")
		recompute()
	end
end

local function cycle(list, current, step)
	local idx = 1
	for i, v in ipairs(list) do
		if v == current then idx = i end
	end
	idx = idx + step
	if idx < 1 then idx = #list end
	if idx > #list then idx = 1 end
	return list[idx]
end

local function zoneKeys()
	local keys = { "auto" }
	for _, z in ipairs(R.Zones()) do keys[#keys + 1] = z.key end
	return keys
end

local function styleKeys()
	local keys = {}
	for _, s in ipairs(R.Strategies()) do
		if s.active ~= false then keys[#keys + 1] = s.key end
	end
	return keys
end

local function onZone(step)
	local ok, why = P.SetRouteZone(cycle(zoneKeys(), P.GetRouteZone(), step))
	if not ok then ns.Say(tostring(why)) end
	recompute()
end

local function onStyle(step)
	local ok, why = P.SetStyle(cycle(styleKeys(), P.GetStyle(), step))
	if not ok then ns.Say(tostring(why)) end
	recompute()
end

local function onSystem(key)
	local s = R.System(key)
	if s and s.planned then
		ns.Say(s.label .. " is planned: Codex has no reliable data for it yet, so it stays off.")
		return
	end
	P.ToggleSystem(key)
	recompute()
end

local function onHardcore()
	P.SetHardcore(not P.IsHardcore())
	ns.Say(P.IsHardcore() and "Hardcore on: respawn skips will never be recommended." or "Hardcore off.")
	recompute()
end

-- ---------------------------------------------------------------- Add-a-quest panel

local function refreshAddResults()
	local box, rows = UI.w.addBox, UI.w.addRows
	local results = R.Search(box:GetText(), ADD_ROWS)
	for i, row in ipairs(rows) do
		local r = results[i]
		if r then
			local q = R.Quest(r.id)
			local lvl = q and q.req and (" (req " .. q.req .. ")") or ""
			row.text:SetText(ns.Trunc(r.name .. lvl .. "  #" .. r.id, 70))
			row.pick = r.id
			row:Show()
		else
			row.pick = nil
			row.text:SetText("")
			row:Hide()
		end
	end
end

local function onAddPick(id)
	P.Add(id)
	ns.Say("Added quest " .. id .. " to your route. Codex will recommend it first.")
	UI.w.addPanel:Hide()
	recompute()
end

local function buildAddPanel(frame)
	local w = UI.w
	local panel = CreateFrame("Frame", nil, frame)
	panel:SetSize(WIDTH - 20, 214)
	panel:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -300)
	panel.bg = panel:CreateTexture(nil, "BACKGROUND")
	panel.bg:SetAllPoints()
	panel.bg:SetColorTexture(0.05, 0.05, 0.08, 0.98)
	local hdr = W.Text(panel, W.GOLD)
	W.Place(hdr, panel, 8, -8, 400)
	hdr:SetText("Add a quest to your route (type part of its name or its id):")

	local box = CreateFrame("EditBox", nil, panel)
	box:SetSize(WIDTH - 60, 20)
	box:SetPoint("TOPLEFT", panel, "TOPLEFT", 8, -28)
	box:SetAutoFocus(false)
	ns.Safe(box.SetMaxLetters, box, 50)
	ns.Safe(box.SetFontObject, box, GameFontNormal)
	box.bg = box:CreateTexture(nil, "BACKGROUND")
	box.bg:SetAllPoints()
	box.bg:SetColorTexture(0.15, 0.15, 0.15, 0.95)
	box:SetScript("OnTextChanged", refreshAddResults)
	box:SetScript("OnEscapePressed", function(self) ns.Safe(self.ClearFocus, self) end)
	w.addBox = box

	w.addRows = {}
	for i = 1, ADD_ROWS do
		local row = W.Row(panel, WIDTH - 40, 18, function() end)
		row:SetPoint("TOPLEFT", panel, "TOPLEFT", 8, -54 - (i - 1) * 20)
		row:SetScript("OnClick", function(self) if self.pick then onAddPick(self.pick) end end)
		w.addRows[i] = row
	end
	local close = W.Button(panel, 80, 20, "Close", function() panel:Hide() end)
	close:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -8, 8)
	local note = W.Text(panel, W.GREY)
	W.Place(note, panel, 8, -190, 380)
	note:SetText("Added quests are recommended first, even if Codex thinks you are not eligible.")
	panel:Hide()
	w.addPanel = panel
end

local function onAdd()
	local p = UI.w.addPanel
	if p:IsShown() then
		p:Hide()
	else
		UI.w.addBox:SetText("")
		refreshAddResults()
		p:Show()
	end
end

-- ---------------------------------------------------------------- builders

local function buildHeader(frame)
	local w = UI.w
	local title = W.Text(frame, W.GOLD)
	W.Place(title, frame, 12, -10, WIDTH - 60)
	title:SetText("Forever Codex 0.1 - First Light (dev build)")
	local close = W.Button(frame, 20, 20, "X", function() frame:Hide() end)
	close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -6, -6)
	w.charFS = W.Text(frame, W.WHITE); W.Place(w.charFS, frame, 12, -30, WIDTH - 24)
	w.whereFS = W.Text(frame, W.GREY); W.Place(w.whereFS, frame, 12, -46, WIDTH - 24)
end

local function buildPickerRow(frame, y, label, onStep)
	local fs = W.Text(frame, W.GOLD); W.Place(fs, frame, 12, y - 3, 84); fs:SetText(label)
	local prev = W.Button(frame, 22, 18, "<", function() onStep(-1) end)
	prev:SetPoint("TOPLEFT", frame, "TOPLEFT", 100, y)
	local value = W.Text(frame, W.WHITE); W.Place(value, frame, 128, y - 3, 280)
	local nxt = W.Button(frame, 22, 18, ">", function() onStep(1) end)
	nxt:SetPoint("TOPLEFT", frame, "TOPLEFT", 412, y)
	return value, prev, nxt
end

local function buildControls(frame)
	local w = UI.w
	w.zoneFS, w.zonePrev, w.zoneNext = buildPickerRow(frame, -68, "Route zone", onZone)
	w.styleFS, w.stylePrev, w.styleNext = buildPickerRow(frame, -92, "Route style", onStyle)
	w.styleDescFS = W.Text(frame, W.GREY); W.Place(w.styleDescFS, frame, 12, -114, WIDTH - 24)
end

local function buildNextCard(frame)
	local w = UI.w
	local bg = frame:CreateTexture(nil, "BACKGROUND")
	bg:SetPoint("TOPLEFT", frame, "TOPLEFT", 8, -132)
	bg:SetSize(WIDTH - 16, 164)
	bg:SetColorTexture(0.12, 0.12, 0.16, 0.9)
	local hdr = W.Text(frame, W.GOLD); W.Place(hdr, frame, 14, -136, 200); hdr:SetText("NEXT")
	w.nextTitle = W.Text(frame, W.WHITE); W.Place(w.nextTitle, frame, 14, -152, WIDTH - 28)
	w.detail = {}
	for i = 1, DETAIL_LINES do
		local fs = W.Text(frame, W.WHITE)
		W.Place(fs, frame, 14, -170 - (i - 1) * 14, WIDTH - 28)
		w.detail[i] = fs
	end
	w.statusFS = W.Text(frame, W.GREY); W.Place(w.statusFS, frame, 14, -256, WIDTH - 28)
	w.btnMap = W.Button(frame, 110, 20, "Show on Map", onShowMap); w.btnMap:SetPoint("TOPLEFT", frame, "TOPLEFT", 14, -272)
	w.btnSkip = W.Button(frame, 70, 20, "Skip", onSkip); w.btnSkip:SetPoint("LEFT", w.btnMap, "RIGHT", 6, 0)
	w.btnAdd = W.Button(frame, 90, 20, "Add quest...", onAdd); w.btnAdd:SetPoint("LEFT", w.btnSkip, "RIGHT", 6, 0)
	w.btnRefresh = W.Button(frame, 70, 20, "Refresh", recompute); w.btnRefresh:SetPoint("LEFT", w.btnAdd, "RIGHT", 6, 0)
end

local function buildLists(frame)
	local w = UI.w
	local h1 = W.Text(frame, W.GOLD); W.Place(h1, frame, 12, -304, 300); h1:SetText("Coming up")
	w.upRows = {}
	for i = 1, UPCOMING_ROWS do
		local row = W.Row(frame, WIDTH - 24, 16, UI.ShowOnMap)
		row:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -320 - (i - 1) * 16)
		w.upRows[i] = row
	end
	local h2 = W.Text(frame, W.GOLD); W.Place(h2, frame, 12, -424, 300); h2:SetText("While you're here")
	w.nearRows = {}
	for i = 1, NEARBY_ROWS do
		local row = W.Row(frame, WIDTH - 24, 16, UI.ShowOnMap)
		row:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -440 - (i - 1) * 16)
		w.nearRows[i] = row
	end
	w.progFS = W.Text(frame, W.GREY); W.Place(w.progFS, frame, 12, -508, WIDTH - 24)
end

local SYSTEM_COLS, SYSTEM_W, SYSTEM_H = 3, 158, 18

local function buildSystems(frame)
	local w = UI.w
	local hdr = W.Text(frame, W.GOLD); W.Place(hdr, frame, 12, -528, 400)
	hdr:SetText("Systems (you decide what Codex includes; greyed = planned, no data yet)")
	w.sysButtons = {}
	local i = 0
	for _, s in ipairs(R.Systems()) do
		local col, row = i % SYSTEM_COLS, math.floor(i / SYSTEM_COLS)
		local b = W.Button(frame, SYSTEM_W, SYSTEM_H, s.label, function() onSystem(s.key) end)
		b:SetPoint("TOPLEFT", frame, "TOPLEFT", 12 + col * (SYSTEM_W + 4), -546 - row * (SYSTEM_H + 4))
		b.sysKey = s.key
		w.sysButtons[#w.sysButtons + 1] = b
		i = i + 1
	end
	local col, row = i % SYSTEM_COLS, math.floor(i / SYSTEM_COLS)
	w.hardcoreBtn = W.Button(frame, SYSTEM_W, SYSTEM_H, "Hardcore", onHardcore)
	w.hardcoreBtn:SetPoint("TOPLEFT", frame, "TOPLEFT", 12 + col * (SYSTEM_W + 4), -546 - row * (SYSTEM_H + 4))
	w.footerFS = W.Text(frame, W.GREY); W.Place(w.footerFS, frame, 12, -640, WIDTH - 24)
	w.footer2FS = W.Text(frame, W.GREY); W.Place(w.footer2FS, frame, 12, -654, WIDTH - 24)
end

local function build()
	local frame = CreateFrame("Frame", "ForeverCodexWindow", UIParent)
	frame:SetSize(WIDTH, HEIGHT)
	frame:SetPoint("CENTER")
	frame:SetFrameStrata("HIGH")
	frame:SetMovable(true)
	frame:EnableMouse(true)
	frame:RegisterForDrag("LeftButton")
	frame:SetScript("OnDragStart", frame.StartMoving)
	frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
	ns.Safe(frame.SetClampedToScreen, frame, true)
	local bg = frame:CreateTexture(nil, "BACKGROUND")
	bg:SetAllPoints()
	bg:SetColorTexture(0, 0, 0, 0.88)
	UI.frame = frame
	buildHeader(frame)
	buildControls(frame)
	buildNextCard(frame)
	buildLists(frame)
	buildSystems(frame)
	buildAddPanel(frame)
end

-- ---------------------------------------------------------------- rendering

--- "ATT, unverified" / "observed on Forever" / "not in Codex data" wording for an action.
function UI.ProvenanceText(a)
	if a.src == "att" then
		return "Source: ATT (AllTheThings) - unverified on Forever", W.ORANGE
	elseif a.src == "questiedb" then
		return "Source: QuestieDB - unverified on Forever", W.ORANGE
	elseif a.src == "observed" then
		return "Source: observed on Forever", W.GREEN
	elseif a.src == "player" or a.src == "log" then
		return "Source: your own quest log / choice (not in Codex data)", W.GREY
	end
	return "Source: " .. tostring(a.src or "unknown"), W.GREY
end

local function distText(a)
	if a._dist and a._dist < 5000 then return string.format("  (%d yd)", math.floor(a._dist + 0.5)) end
	if a._dist then return "  (other area)" end
	return ""
end

local function renderCharacter(ctx, plan)
	local w = UI.w
	if not ctx then
		w.charFS:SetText("Character: not read yet")
		return
	end
	local c = ctx.char
	if c.name and c.level then
		w.charFS:SetText(string.format("%s - level %s %s %s%s", c.name, tostring(c.level), tostring(c.race or "?"), tostring(c.class or "?"),
			c.faction and (" (" .. c.faction .. ")") or ""))
		W.SetColor(w.charFS, W.WHITE)
	else
		w.charFS:SetText("Character: could not be fully read (see /codex diag)")
		W.SetColor(w.charFS, W.ORANGE)
	end
	local routeLabel = "auto"
	local pz = P.GetRouteZone()
	if pz ~= "auto" then
		local z = R.ZoneByKey(pz)
		routeLabel = z and z.label or pz
	end
	local now = ctx.loc.zone or "unknown"
	if ctx.loc.subzone then now = now .. " / " .. ctx.loc.subzone end
	if ctx.loc.available and ctx.loc.x then now = now .. string.format("  (%.1f, %.1f)", ctx.loc.x * 100, ctx.loc.y * 100) end
	w.whereFS:SetText(ns.Trunc("Race origin: " .. tostring(c.race or "?") .. "  |  Route zone (your choice): " .. routeLabel .. "  |  Now in: " .. now, 90))
end

local function renderControls()
	local w = UI.w
	local pz = P.GetRouteZone()
	if pz == "auto" then
		w.zoneFS:SetText("Auto (follow the zone you are in)")
	else
		local z = R.ZoneByKey(pz)
		w.zoneFS:SetText(z and (z.label .. "  (" .. z.quests .. " quests in data)") or pz)
	end
	local s = R.Strategy(P.GetStyle())
	w.styleFS:SetText(s and s.label or P.GetStyle())
	w.styleDescFS:SetText(ns.Trunc(s and s.desc or "", 90))
end

local function renderNext(plan)
	local w = UI.w
	for _, fs in ipairs(w.detail) do fs:SetText("") end
	local a = plan and plan.next
	if not a then
		w.nextTitle:SetText("Nothing to recommend right now")
		local i = 1
		for _, msg in ipairs(plan and plan.warnings or {}) do
			if i <= DETAIL_LINES then w.detail[i]:SetText(ns.Trunc(msg, 80)); i = i + 1 end
		end
		if i <= DETAIL_LINES then w.detail[i]:SetText("Try another route zone or style, or Add a quest you want to do."); i = i + 1 end
		w.statusFS:SetText("")
		W.SetEnabled(w.btnMap, false); W.SetEnabled(w.btnSkip, false)
		return
	end
	w.nextTitle:SetText(ns.Trunc(a.title, 64))
	local i = 1
	for _, line in ipairs(a.lines) do
		if i <= DETAIL_LINES - 2 then w.detail[i]:SetText(ns.Trunc(line, 82)); W.SetColor(w.detail[i], W.WHITE); i = i + 1 end
	end
	if #a.reasons > 0 and i <= DETAIL_LINES - 1 then
		w.detail[i]:SetText(ns.Trunc("Why: " .. table.concat(a.reasons, "; "), 82)); W.SetColor(w.detail[i], W.GREEN); i = i + 1
	end
	local text, color = UI.ProvenanceText(a)
	if i <= DETAIL_LINES then w.detail[i]:SetText(text); W.SetColor(w.detail[i], color) end
	local st = ns.Route.Evaluate(a)
	w.statusFS:SetText(ns.Trunc("Status: " .. string.lower(st.state) .. " - " .. tostring(st.reason), 90))
	W.SetEnabled(w.btnMap, a.target ~= nil)
	W.SetEnabled(w.btnSkip, a.skipKey ~= nil)
end

local function renderList(rows, list, prefix)
	for i, row in ipairs(rows) do
		local a = list[i]
		if a then
			row.action = a
			row.text:SetText(ns.Trunc((prefix and (prefix .. i .. ". ") or "") .. a.title .. distText(a), 74))
			local _, color = UI.ProvenanceText(a)
			W.SetColor(row.text, a.src == "att" and W.WHITE or color)
			row:Show()
		else
			row.action = nil
			row.text:SetText("")
			row:Hide()
		end
	end
end

local function renderSystems()
	local w = UI.w
	for _, b in ipairs(w.sysButtons) do
		local s = R.System(b.sysKey)
		if s.planned then
			b.text:SetText("[ ] " .. ns.Trunc(s.label, 16) .. " (planned)")
			W.SetColor(b.text, W.GREY)
		else
			b.text:SetText((P.IsSystemOn(b.sysKey) and "[x] " or "[ ] ") .. ns.Trunc(s.label, 20))
			W.SetColor(b.text, W.GOLD)
		end
	end
	w.hardcoreBtn.text:SetText((P.IsHardcore() and "[x] " or "[ ] ") .. "Hardcore")
	W.SetColor(w.hardcoreBtn.text, W.GOLD)
end

function UI.Refresh()
	if not UI.frame then return end
	local ctx, plan = ns.State.ctx, ns.State.plan
	local w = UI.w
	renderCharacter(ctx, plan)
	renderControls()
	renderNext(plan)
	renderList(w.upRows, plan and plan.upcoming or {}, "")
	renderList(w.nearRows, plan and plan.nearby or {}, nil)
	if plan and #plan.inProgress > 0 then
		local names = {}
		for i, a in ipairs(plan.inProgress) do
			if i <= 3 then names[#names + 1] = (a.title:gsub("^Continue: ", "")) end
		end
		w.progFS:SetText(ns.Trunc("In your log, location unknown (" .. #plan.inProgress .. "): " .. table.concat(names, ", ") ..
			(#plan.inProgress > 3 and ", ..." or ""), 96))
	else
		w.progFS:SetText("")
	end
	renderSystems()
	local st = R.Stats()
	w.footerFS:SetText(ns.Trunc(string.format("Data: %d quests (third-party baseline, unverified + observed) | %d flight nodes. Recommendations are suggestions only.", st.quests, st.flightNodes), 100))
	w.footer2FS:SetText("Bug or feedback? /codex diag  (or /codex report for a copyable box)")
end

-- ---------------------------------------------------------------- public

function UI.IsShown()
	return UI.frame ~= nil and UI.frame:IsShown()
end

function UI.Toggle()
	if not UI.frame then
		build()
		ns.State.Recompute()
		UI.frame:Show()
		return
	end
	if UI.frame:IsShown() then
		UI.frame:Hide()
	else
		ns.State.Recompute()
		UI.frame:Show()
	end
end

--- Copyable report box (multi-line EditBox). Raises if the client cannot build it; Diag falls back to chat.
function UI.ShowReport(text)
	if not UI.report then
		local f = CreateFrame("Frame", "ForeverCodexReport", UIParent)
		f:SetSize(620, 340)
		f:SetPoint("CENTER")
		f:SetFrameStrata("DIALOG")
		f:SetMovable(true)
		f:EnableMouse(true)
		f:RegisterForDrag("LeftButton")
		f:SetScript("OnDragStart", f.StartMoving)
		f:SetScript("OnDragStop", f.StopMovingOrSizing)
		f.bg = f:CreateTexture(nil, "BACKGROUND")
		f.bg:SetAllPoints()
		f.bg:SetColorTexture(0, 0, 0, 0.92)
		local hdr = W.Text(f, W.GOLD)
		W.Place(hdr, f, 10, -8, 560)
		hdr:SetText("Forever Codex report - select all (Ctrl+A), copy (Ctrl+C), then paste it where you are reporting.")
		local box = CreateFrame("EditBox", nil, f)
		box:SetMultiLine(true)
		box:SetSize(596, 280)
		box:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -28)
		box:SetAutoFocus(false)
		box:SetFontObject(GameFontNormal)
		box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
		f.box = box
		local close = W.Button(f, 70, 20, "Close", function() f:Hide() end)
		close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -6, -4)
		UI.report = f
	end
	UI.report.box:SetText(text)
	UI.report:Show()
end

--- Test seam: builds the window without showing it.
function UI._Build()
	if not UI.frame then build() end
end
