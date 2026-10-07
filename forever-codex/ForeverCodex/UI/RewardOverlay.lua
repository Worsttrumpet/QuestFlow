-- UI: REWARD OVERLAY. Small annotations drawn directly ON the game's own quest reward choices (no Codex window, nothing to move):
--   * each choice gets a row of small Codex ICONS (UI/CodexIcons.lua), one per classification the advisor gave it (UPGRADE, NOT AN UPGRADE, MIXED, VENDOR, NOT USABLE, UNKNOWN ...),
--     and a VENDOR coin is followed by the sell value ("[coin] 3s 24c"), the one number the player would otherwise open Blizzard's tooltip for;
--   * the reward the advisor RECOMMENDS gets a golden border and a star: the border is the recommendation, the icons are the classification, and they are separate things;
--   * hovering a choice adds ONE line to the game's own item tooltip, "CODEX: <classification>": Blizzard's tooltip already has the item and its stats, Codex adds only its opinion.
-- There is no verdict line ("NO CLEAR PICK" and the like): without a recommendation there is simply no border and no star.
--
--   ADVISOR DECIDES, THIS FILE DISPLAYS. Everything shown comes from ns.Advisor.Display() (RewardAdvisor.lua). This file reads no item facts, compares no stats, judges no usability,
--   and never picks a reward: it cannot click, accept or choose anything, and it never replaces or re-parents the game's reward buttons (the strips are children that take no mouse input).
--
--   WHERE IT ATTACHES (NOT PROVEN on Forever: the reward frame's structure was never inspected): the choice buttons are looked up by the names the game's quest-info frame
--   gives them in the Classic family of clients, CANDIDATES below, and a button is used only when it is shown and, if it says which choice it is (GetID), says the right one. A choice
--   whose button is not found is simply not annotated (and the report says so: /codex report, REWARD OVERLAY). Nothing is guessed about a frame that is not there.
--
--   WHEN: it refreshes on the events that change a reward dialog (QUEST_COMPLETE, QUEST_ITEM_UPDATE, late item data, an equipment change), notices a dialog that is open and not yet
--   annotated (a light check, about 2.5 times a second), and hides as soon as the dialog is no longer open.

local addonName, ns = ...

local RO = {}
ns.RewardOverlay = RO

RO.INSET = 12                        -- the right-hand column of buttons runs to the edge of the game's scroll area, which clips anything drawn on it: stay this far in
RO.EVENTS = { "QUEST_COMPLETE", "QUEST_ITEM_UPDATE", "GET_ITEM_INFO_RECEIVED", "PLAYER_EQUIPMENT_CHANGED" }
-- the names a choice button may have, by choice number (Classic family of clients; unproven on Forever)
RO.CANDIDATES = { "QuestInfoRewardsFrameQuestInfoItem%d", "QuestInfoItem%d" }

local COLORS = {
	green = { 0.56, 0.80, 0.52 }, yellow = { 1, 0.84, 0.36 }, red = { 0.92, 0.38, 0.32 }, blue = { 0.50, 0.72, 1.0 },
	purple = { 0.78, 0.60, 0.92 }, gold = { 0.85, 0.72, 0.40 }, grey = { 0.70, 0.68, 0.62 },
}
local PICK = { 0.45, 0.95, 0.45 }
local EDGE = { 1, 0.82, 0.20 }          -- the golden recommendation border: bright gold, 3 px, drawn INSIDE the button's own edge (the right-hand column runs to the scroll area's edge, which clips anything outside)
local EDGE_IN = { 0.55, 0.38, 0.04 }     -- a 1 px darker amber line just inside it, so the gold stands out against the parchment and the button art
RO.BORDER = 3

local state = { builtFor = nil, postHits = 0, postBuilt = 0, hoverPost = 0, tipHooks = 0, tipLines = 0, tipKept = 0, tipLost = 0, hoverT = 0, hoverFixes = 0, shown = false, display = nil, attached = {}, since = 0, settled = false, backoff = 0 }
RO.state = state
local cache = setmetatable({}, { __mode = "k" })           -- button -> its strip (created once, reused)

local function safe(f, ...) local ok, a, b = pcall(f, ...); if ok then return a, b end end

--- The game's choice button for choice `i`: the first candidate that exists, is shown, and (when it can say) is that choice. nil when there is none.
function RO.FindButton(i)
	for _, pattern in ipairs(RO.CANDIDATES) do
		local name = string.format(pattern, i)
		local b = rawget(_G, name)
		if type(b) == "table" and type(b.IsShown) == "function" and safe(b.IsShown, b) then
			local id = type(b.GetID) == "function" and safe(b.GetID, b) or nil
			if type(id) ~= "number" or id == 0 or id == i then return b, name end
		end
	end
	return nil
end

local function color(c, fam) return c[fam] or c.grey end

--- The icon row on a choice button (created on first use). It is a child with mouse input off, so the game's button still takes every click and hover.
local function stripFor(btn)
	local s = cache[btn]
	if s then return s end
	local f = CreateFrame("Frame", nil, btn)
	pcall(f.EnableMouse, f, false)
	pcall(f.SetFrameLevel, f, ((type(btn.GetFrameLevel) == "function" and safe(btn.GetFrameLevel, btn)) or 1) + 5)
	pcall(f.SetHeight, f, ns.CodexIcons and ns.CodexIcons.BadgeSize() or 12)
	s = { frame = f, badges = {}, edges = {}, inner = {}, edgeSpec = {} }
	for n = 1, 4 do
		local t = f:CreateTexture(nil, "OVERLAY")
		pcall(t.SetColorTexture, t, EDGE[1], EDGE[2], EDGE[3], 1)
		s.edges[n] = t
		t:Hide()
		local u = f:CreateTexture(nil, "OVERLAY")
		pcall(u.SetColorTexture, u, EDGE_IN[1], EDGE_IN[2], EDGE_IN[3], 1)
		s.inner[n] = u
		u:Hide()
	end
	cache[btn] = s
	if type(btn.HookScript) == "function" then
		pcall(btn.HookScript, btn, "OnEnter", function(self) RO.Tooltip(self) end)
		pcall(btn.HookScript, btn, "OnLeave", function() state.hover, state.builtFor = nil, nil end)
	end
	return s
end

local function place(s, btn)
	local f = s.frame
	pcall(f.ClearAllPoints, f)
	-- BOTTOM-RIGHT corner of the button, right-aligned: the item's name wraps greedily, so its second line is the short one and the corner under it is the free part. The row is
	-- only as wide as its badges (Draw sets the width), so it never reaches the icon. (The gap BETWEEN the rows is too small for a badge.)
	pcall(f.SetPoint, f, "BOTTOMRIGHT", btn, "BOTTOMRIGHT", -RO.INSET, 3)
	-- the four sides of the golden border (outer, bright) and of the thin dark line inside it. Each side is anchored to two corners of the button and given one thickness; what was
	-- done is kept in s.edgeSpec (the tests read it: the stub client has no layout to measure).
	local w = RO.BORDER
	local function ring(list, inset, thick, key)
		-- top, bottom, left, right
		local specs = {
			{ "TOPLEFT", "TOPRIGHT", inset, -inset, -inset, -inset, nil, thick },
			{ "BOTTOMLEFT", "BOTTOMRIGHT", inset, inset, -inset, inset, nil, thick },
			{ "TOPLEFT", "BOTTOMLEFT", inset, -inset, inset, inset, thick, nil },
			{ "TOPRIGHT", "BOTTOMRIGHT", -inset, -inset, -inset, inset, thick, nil },
		}
		for n, sp in ipairs(specs) do
			local t = list[n]
			pcall(t.ClearAllPoints, t)
			pcall(t.SetPoint, t, sp[1], btn, sp[1], sp[3], sp[4])
			pcall(t.SetPoint, t, sp[2], btn, sp[2], sp[5], sp[6])
			if sp[7] then pcall(t.SetWidth, t, sp[7]) end
			if sp[8] then pcall(t.SetHeight, t, sp[8]) end
			s.edgeSpec[key .. n] = { p1 = sp[1], p2 = sp[2], inset = inset, w = sp[7], h = sp[8] }
		end
	end
	ring(s.edges, 0, w, "outer")
	ring(s.inner, w, 1, "inner")
end

--- The glyph ids of a row's icon row, in the advisor's order: one per classification word, a ? added when usability is unclear (unless UNKNOWN is already there). The
-- recommendation is NOT among them: it is its own star (RO.StarGlyph). Pure; exported for the tests.
function RO.Glyphs(row)
	local I = ns.CodexIcons
	local out, seen = {}, {}
	for _, t in ipairs(row.tags or {}) do
		local g = I.GlyphFor(t) or "UNKNOWN"
		if not seen[g] then seen[g] = true; out[#out + 1] = g end
	end
	if row.unsure and not seen.UNKNOWN then out[#out + 1] = "UNKNOWN" end
	if #out > 4 then for i = #out, 5, -1 do out[i] = nil end end    -- (four fit under a button; the tooltip lists them all)
	return out
end

--- The glyph of the recommendation star for a row (nil when the advisor did not name it).
function RO.StarGlyph(row)
	if row.recommended == "pick" then return "RECOMMENDED" elseif row.recommended == "tentative" then return "TENTATIVE" end
end

local function clear()
	for btn, s in pairs(cache) do
		pcall(s.frame.Hide, s.frame)
		for n, t in ipairs(s.edges) do t:Hide(); s.inner[n]:Hide() end
	end
	state.shown, state.display, state.attached = false, nil, {}
end

--- The strip drawn on a button (for the tests: it must take no mouse input).
function RO.Strip(btn) return cache[btn] end

--- Hides every annotation (the dialog closed, or there is nothing to say).
function RO.Hide() clear(); state.settled, state.backoff = false, 0 end

--- Paints one row's icons into its strip: classification badges from the left, the recommendation star at the right end.
function RO.Draw(s, row)
	local I = ns.CodexIcons
	local glyphs = RO.Glyphs(row)
	local size = I.BadgeSize()
	local x, gap = 0, 2
	-- the sell value is drawn straight after the VENDOR coin ("[coin] 3s 24c"): the one number the player would otherwise have to open Blizzard's tooltip for
	local priceText = row.vendor
	if priceText and not s.price then
		s.price = s.frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
		pcall(s.price.SetTextColor, s.price, 0.85, 0.72, 0.40)
	end
	local priceShown = false
	for n, g in ipairs(glyphs) do
		local b = s.badges[n]
		if not b then b = I.NewBadge(s.frame); s.badges[n] = b end
		pcall(b.frame.ClearAllPoints, b.frame)
		pcall(b.frame.SetPoint, b.frame, "LEFT", s.frame, "LEFT", x, 0)
		-- the colour family is the advisor's for the first (main) classification; the rest use their own category family
		I.Paint(b, g, I.COLORS[(n == 1 and row.family) or I.FAMILY_OF[g] or "grey"] or I.COLORS.grey)
		pcall(b.frame.Show, b.frame)
		x = x + size + gap
		if g == "VENDOR" and priceText and not priceShown then
			priceShown = true
			pcall(s.price.SetText, s.price, priceText)
			local w = type(s.price.GetStringWidth) == "function" and safe(s.price.GetStringWidth, s.price) or nil
			if type(w) ~= "number" or w <= 0 then w = #priceText * 5.5 end
			pcall(s.price.ClearAllPoints, s.price)
			pcall(s.price.SetPoint, s.price, "LEFT", s.frame, "LEFT", x, 0)
			pcall(s.price.Show, s.price)
			s.priceWidth = w
			x = x + w + gap + 1
		end
	end
	if s.price and not priceShown then pcall(s.price.Hide, s.price) end
	for n = #glyphs + 1, #s.badges do pcall(s.badges[n].frame.Hide, s.badges[n].frame) end
	local star = RO.StarGlyph(row)
	local total = x - gap + (star and (gap + size) or 0)
	pcall(s.frame.SetWidth, s.frame, math.max(size, total))
	if star then
		local b = s.star
		if not b then b = I.NewBadge(s.frame); s.star = b end
		pcall(b.frame.ClearAllPoints, b.frame)
		pcall(b.frame.SetPoint, b.frame, "RIGHT", s.frame, "RIGHT", 0, 0)
		I.Paint(b, star, I.STAR, true)
		pcall(b.frame.Show, b.frame)
	elseif s.star then
		pcall(s.star.frame.Hide, s.star.frame)
	end
end

--- Draws a display table (Advisor.Display's result) on the game's choice buttons. Returns how many choices were annotated.
function RO.Apply(d)
	clear()
	if not d or not d.rows or #d.rows == 0 then return 0 end
	local first, n = nil, 0
	local byIndex = {}
	for _, row in ipairs(d.rows) do byIndex[row.index] = row end
	local attached = {}
	for _, row in ipairs(d.rows) do
		local btn, name = RO.FindButton(row.index)
		if btn then
			first = first or btn
			local s = stripFor(btn)
			place(s, btn)
			RO.Draw(s, row)
			pcall(s.frame.Show, s.frame)
			-- the golden border is the recommendation (a pick or a tentative pick): the one thing here that comes from the recommendation, not from the classification
			for n, t in ipairs(s.edges) do
				if row.recommended then t:Show(); s.inner[n]:Show() else t:Hide(); s.inner[n]:Hide() end
			end
			attached[row.index] = { button = name, row = row }
			s.row = row
			n = n + 1
		end
	end
	state.shown, state.display, state.attached = n > 0, d, attached
	return n
end

--- The advisor's full reason as extra tooltip lines on the game's own item tooltip (added after the game has filled it in).
--- The advisor's words as extra lines on the game's item tooltip.
local function addLines(row, noShow)
	local tip = GameTooltip
	local c = ns.CodexIcons.COLORS[row.family] or ns.CodexIcons.COLORS.grey
	pcall(tip.AddLine, tip, " ")
	pcall(tip.AddLine, tip, "CODEX: " .. (row.headline or "UNKNOWN"), c[1], c[2], c[3])      -- the one thing Codex adds: its verdict on this reward (Blizzard's tooltip has the item)
	if not noShow then pcall(tip.Show, tip) end
end

--- OnEnter of a reward button. `again` = a repair (the game rebuilt the tooltip after our lines): not counted as a hover.
function RO.Tooltip(btn, again)
	local s = cache[btn]
	local row = s and s.row
	if not again then
		state.tipHooks = state.tipHooks + 1
		state.hover, state.hoverT, state.hoverFixes = btn, 0, 0
		state.hoverPost = state.postHits - (state.builtFor == btn and 1 or 0)     -- (the game builds the tooltip BEFORE our OnEnter hook runs: that build counts)
	end
	if not (state.shown and row and rawget(_G, "GameTooltip")) then return end
	local tip = GameTooltip
	if type(tip.AddLine) ~= "function" then return end
	if not again and RO.postCall == "registered" and state.builtFor == btn then
		state.tipShown = true; state.tipOwner = "the button"; return      -- the build hook already put our lines in this tooltip
	end
	addLines(row)
	state.tipLines = state.tipLines + 1
	if not again then
		state.tipShown = type(tip.IsShown) == "function" and safe(tip.IsShown, tip) or nil
		local owner = type(tip.GetOwner) == "function" and safe(tip.GetOwner, tip) or nil
		state.tipOwner = owner == nil and "unknown" or (owner == btn and "the button" or "something else")
	end
end

--- Called when the game has built an item tooltip (TooltipDataProcessor post-call): when it is the tooltip of one of our annotated reward buttons, our lines go in as part of that
-- build, so a rebuild (which the real client does constantly) cannot wipe them and nothing flickers.
function RO.OnTooltipBuilt(tip)
	state.postBuilt = state.postBuilt + 1
	if tip ~= rawget(_G, "GameTooltip") or not state.shown then return end
	local owner = type(tip.GetOwner) == "function" and safe(tip.GetOwner, tip) or nil
	local s = owner and cache[owner]
	if not (s and s.row) then return end
	addLines(s.row, true)
	state.postHits = state.postHits + 1
	state.builtFor = owner
end

--- Registers the build hook when the client has it (TooltipDataProcessor.AddTooltipPostCall and Enum.TooltipDataType.Item). Idempotent. RO.postCall = "registered" | "unavailable".
function RO.InstallPostCall()
	if RO.postCall == "registered" then return end
	local tdp, en = rawget(_G, "TooltipDataProcessor"), rawget(_G, "Enum")
	if type(tdp) == "table" and type(tdp.AddTooltipPostCall) == "function" and type(en) == "table" and type(en.TooltipDataType) == "table" and en.TooltipDataType.Item then
		local ok = pcall(tdp.AddTooltipPostCall, en.TooltipDataType.Item, function(tip) RO.OnTooltipBuilt(tip) end)
		RO.postCall = ok and "registered" or "unavailable"
	else
		RO.postCall = "unavailable"
	end
end

--- Does the game's tooltip hold our lines right now? true / false, or nil when its text cannot be read (no line API).
local function tipHasOurs()
	local tip = rawget(_G, "GameTooltip")
	if not (tip and type(tip.NumLines) == "function") then return nil end
	local n = safe(tip.NumLines, tip)
	if type(n) ~= "number" then return nil end
	for i = 1, n do
		local fs = rawget(_G, "GameTooltipTextLeft" .. i)
		local t = fs and type(fs.GetText) == "function" and safe(fs.GetText, fs) or nil
		if type(t) == "string" and t:find("CODEX: ", 1, true) then return true end
	end
	return false
end

--- While the mouse is on a reward, the game may rebuild its tooltip after our hook ran (item data arriving, the comparison tooltip): when our lines are gone, add them again
-- (at most a few times per hover). Counters go to the report so the next real-client check says what happened.
function RO.CheckTooltip()
	local btn = state.hover
	local tip = rawget(_G, "GameTooltip")
	if not (btn and tip and state.shown) then return end
	if type(tip.IsShown) == "function" and not safe(tip.IsShown, tip) then return end
	if RO.postCall == "registered" and state.postHits > state.hoverPost then return end      -- the build hook is adding them on every rebuild: nothing to repair
	local has = tipHasOurs()
	if has == nil then state.tipScan = "unreadable"; return end
	state.tipScan = "readable"
	if has then state.tipKept = state.tipKept + 1
	else
		state.tipLost = state.tipLost + 1
		if state.hoverFixes < 5 then state.hoverFixes = state.hoverFixes + 1; RO.Tooltip(btn, true) end
	end
end

--- Recomputes from the advisor and redraws (or hides). opts as for Advisor.Display (a test passes a fake dialog).
function RO.Update(opts)
	if not ns.Advisor then return 0 end
	local ok, d = pcall(ns.Advisor.Display, opts)
	if not ok then
		if ns.RecordError then ns.RecordError("reward overlay", d) end
		clear()
		return 0
	end
	if not d then
		clear()
		state.settled = true                                -- (nothing to annotate in this dialog: do not ask again until it closes or the game sends news)
		return 0
	end
	local n = RO.Apply(d)
	state.settled = n > 0
	if n == 0 then state.backoff = 5 end                    -- (the buttons are not there (yet): look again in a couple of seconds, not every tick)
	return n
end

--- True while the game's reward dialog looks open (the evidence layer's own check).
local function dialogOpen()
	return ns.ItemProbe and ns.ItemProbe.DialogOpen and ns.ItemProbe.DialogOpen() or false
end

RO.InstallPostCall()
local frame = CreateFrame("Frame")
RO.frame = frame
RO.registered = {}
for _, ev in ipairs(RO.EVENTS) do
	local ok = pcall(frame.RegisterEvent, frame, ev)
	RO.registered[ev] = ok and true or false
end
frame:SetScript("OnEvent", function(_, event)
	-- (item data arrives constantly: only a dialog that is showing, or open, cares)
	if event == "GET_ITEM_INFO_RECEIVED" or event == "PLAYER_EQUIPMENT_CHANGED" then
		if not state.shown then return end
	end
	if state.shown or dialogOpen() then RO.Update() end
end)
-- A light check (about 2.5 times a second): it HIDES the annotations when the dialog closes, and it NOTICES a dialog that opened without an event we could use (the reward event
-- fires before the game's reward frame is shown, so the event handler can see "not open yet"; the first real-client report of 0.9.1 showed exactly that).
frame:SetScript("OnUpdate", function(_, dt)
	if state.hover then
		state.hoverT = state.hoverT + (dt or 0)
		if state.hoverT >= 0.15 then state.hoverT = 0; RO.CheckTooltip() end
	end
	state.since = state.since + (dt or 0)
	if state.since < 0.4 then return end
	state.since = 0
	local open = dialogOpen()
	if state.shown then
		if not open then clear(); state.settled = false end   -- the dialog closed (a reward taken, or walked away)
	elseif open then
		if state.backoff > 0 then state.backoff = state.backoff - 1
		elseif not state.settled then RO.Update() end
	else
		state.settled, state.backoff = false, 0
	end
end)

--- The report lines: what the overlay could attach to (the first real-client check of the reward frame's structure).
function RO.ReportLines()
	local L = {}
	local rf = rawget(_G, "QuestInfoRewardsFrame")
	local found, tried = {}, 0
	for i = 1, 6 do
		local b, name = RO.FindButton(i)
		if b then found[#found + 1] = i .. "=" .. name end
		tried = tried + 1
	end
	L[#L + 1] = string.format("REWARD OVERLAY (annotations drawn on the game's own reward choices; the advisor decides, the overlay only displays): events %s | QuestFrame %s | QuestInfoRewardsFrame %s | choice buttons found now: %s",
		(function() local r = {} for _, ev in ipairs(RO.EVENTS) do r[#r + 1] = ev .. (RO.registered[ev] and "" or "(not registered)") end return table.concat(r, ",") end)(),
		rawget(_G, "QuestFrame") and "present" or "absent", rf and "present" or "absent", #found > 0 and table.concat(found, ", ") or "none (no reward dialog open, or the names are different on this client)")
	if state.shown and state.display then
		local n = 0
		for _ in pairs(state.attached) do n = n + 1 end
		L[#L + 1] = string.format("  showing: %d of %d choices annotated | %s", n, #state.display.rows, state.display.verdict.text)
		L[#L + 1] = string.format("  tooltip: hover hook ran %d time(s), extra lines added %d time(s) (0 and 0 after hovering a choice means the hook is not reached)", state.tipHooks, state.tipLines)
		L[#L + 1] = string.format("  tooltip build hook (TooltipDataProcessor): %s | item tooltips built %d | our lines added in a build %d time(s)", tostring(RO.postCall or "not installed"), state.postBuilt, state.postHits)
		L[#L + 1] = string.format("  tooltip check: GameTooltip shown right after the hook: %s | its owner: %s | line text %s | our lines found %d time(s), missing %d time(s) (each miss added them again, at most 5 per hover)",
			tostring(state.tipShown), tostring(state.tipOwner or "not seen"), tostring(state.tipScan or "not checked"), state.tipKept, state.tipLost)
	else
		L[#L + 1] = "  not showing (no reward dialog with a choice is open)"
	end
	if rf and type(rf.GetChildren) == "function" then
		local ok, c = pcall(function() return { rf:GetChildren() } end)
		if ok and type(c) == "table" then
			local names = {}
			for i, ch in ipairs(c) do
				if i > 10 then names[#names + 1] = "..." break end
				local nm = type(ch.GetName) == "function" and safe(ch.GetName, ch) or nil
				names[#names + 1] = tostring(nm or "(unnamed)")
			end
			L[#L + 1] = "  QuestInfoRewardsFrame children: " .. (#names > 0 and table.concat(names, ", ") or "none")
		end
	end
	return L
end

return RO
