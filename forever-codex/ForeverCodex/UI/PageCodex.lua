-- UI page "Codex": what am I doing now, what is left of it, and what else can I knock out while I'm here?
--   NOW                 the one thing to do, with EVERY unfinished objective of that quest (counts and a thin bar each)
--   ALSO COMPLETE THIS  other unfinished objectives that fit with NOW (and the planner's own "also do" line); hidden when there is none
--   READY TO TURN IN    finished quests waiting for the right moment (listed, never forced into NOW); hidden when there are none
--   NEW FOR YOU         a temporary card for a level you just reached (secondary, never in front of NOW)
--   Party               what party members finished, only when there is something to say
-- Before the first-time setup is finished this page shows the setup panel instead (UI/PageSetup.lua).
--
-- This is a small companion panel (UI.COMPACT_WIDTH wide), not a quest database: no explanations of WHY (that stays in /codex report),
-- no sentences where a number says it. This file only DRAWS: every word and count comes from Presenter (which asks Overlap for the
-- ALSO COMPLETE THIS rows); nothing here reads the Planner or the data. Progress bars are textures (the UI is ASCII only: block
-- glyphs would render as boxes) and show only counts the quest log really reported.

local addonName, ns = ...
local W = ns.Widgets
local UI = ns.UI

local FULL = UI.COMPACT_WIDTH - 16  -- page width
local GAP, PAD = W.GAP, W.PAD
local TOP = 22                      -- below the character line
local NOW_MIN = 56                  -- a card never gets smaller than this
local READY_ROWS = 12              -- hand-ins listed in READY TO TURN IN (the window grows to fit; the rest are summarised in one line)
local DG_GROUPS, DG_ROWS = 4, 12      -- DUNGEON QUESTS: dungeons and quest lines drawn (the rest are summarised in one line)
local MAX_ROWS = 8                  -- objective rows drawn in one card (the rest are summarised in one line)

--- Places a card at a vertical offset below the page top and sizes it.
local function placeCard(c, card, y, w, h)
	card:ClearAllPoints()
	card:SetPoint("TOPLEFT", c.page, "TOPLEFT", card.__x or 0, -y)
	card:SetSize(w, h)
end

local function build(page)
	local c = { page = page }
	UI.main.codex = c
	c.header = W.Line(page, 12, W.DIM, "LEFT")
	W.Place(c.header, page, 0, -2, FULL - 72)
	-- the quest-log counter, right-aligned on the same line: "14/40" (the normal quest log holds 40; a finished quest still holds its slot)
	c.slots = W.Line(page, 12, W.DIM, "RIGHT")
	W.Place(c.slots, page, FULL - 70, -2, 70)

	-- NOW: the strongest card
	c.nowBox = W.Card(page, FULL, NOW_MIN, W.STYLE_NOW)
	-- a way out of a recommendation that is wrong or unavailable: skips it (the same as /codex skip; /codex unskip brings it back)
	c.nowSkip = W.Button(c.nowBox, 40, 16, "Skip", function()
		local a = ns.State.SkipCurrent()
		if a then ns.Say("Skipped: " .. tostring(a.title) .. ". (/codex unskip brings skipped items back.)") end
	end)
	c.nowSkip:SetPoint("TOPRIGHT", c.nowBox, "TOPRIGHT", -PAD + 4, -PAD + 3)
	c.nowLabel = W.Label(c.nowBox, "NOW", W.STYLE_NOW.label)
	c.nowLabel:SetPoint("TOPLEFT", c.nowBox, "TOPLEFT", c.nowBox.insetX, -PAD)
	c.nowKindIcon = W.Icon(c.nowBox, 16)                -- "!" for a pickup, "?" for a hand-in; nothing for objectives
	c.nowTitle = W.Line(c.nowBox, 16, W.WARM_GOLD, "LEFT", true)
	c.nowWho = W.Line(c.nowBox, 12, W.TEXT, "LEFT")
	c.nowDetail = W.Line(c.nowBox, 11, W.DIM, "LEFT", true)
	c.nowRows = {}
	for i = 1, MAX_ROWS do c.nowRows[i] = W.ProgressRow(c.nowBox) end
	c.nowMore = W.Line(c.nowBox, 11, W.DIM, "LEFT")
	c.nowInfo = W.Line(c.nowBox, 11, W.SOFT_GREEN, "LEFT")
	c.nowDivider = W.Divider(c.nowBox)
	c.thenFS = W.Line(c.nowBox, 11, W.DIM, "LEFT")

	-- ALSO COMPLETE THIS: supporting, cooler and smaller; present only when there is something to say
	c.alsoBox = W.Card(page, FULL, 40, W.STYLE_NEAR)
	c.alsoLabel = W.Label(c.alsoBox, "ALSO COMPLETE THIS", W.STYLE_NEAR.label)
	c.alsoLabel:SetPoint("TOPLEFT", c.alsoBox, "TOPLEFT", c.alsoBox.insetX, -PAD + 2)
	c.alsoHeads, c.alsoRows = {}, {}
	for i = 1, 4 do c.alsoHeads[i] = W.Line(c.alsoBox, 12, W.TEXT, "LEFT") end
	for i = 1, MAX_ROWS do c.alsoRows[i] = W.ProgressRow(c.alsoBox) end
	c.alsoMore = W.Line(c.alsoBox, 11, W.DIM, "LEFT")

	-- READY TO TURN IN: finished quests, a quiet green card; present only when there are some
	c.readyBox = W.Card(page, FULL, 40, W.STYLE_READY)
	c.readyLabel = W.Label(c.readyBox, "READY TO TURN IN", W.STYLE_READY.label)
	c.readyLabel:SetPoint("TOPLEFT", c.readyBox, "TOPLEFT", c.readyBox.insetX, -PAD + 2)
	c.readyRows, c.readyIcons = {}, {}
	for i = 1, READY_ROWS do
		c.readyRows[i] = W.Line(c.readyBox, 12, W.TEXT, "LEFT")
		c.readyIcons[i] = W.Icon(c.readyBox, 14)
	end
	c.readyMore = W.Line(c.readyBox, 11, W.DIM, "LEFT")

	-- DUNGEON QUESTS: quests the game tags as dungeon / raid, a red card, grouped by dungeon; present only when there are some
	c.dgBox = W.Card(page, FULL, 40, W.STYLE_DUNGEON)
	c.dgLabel = W.Label(c.dgBox, "DUNGEON QUESTS", W.STYLE_DUNGEON.label)
	c.dgLabel:SetPoint("TOPLEFT", c.dgBox, "TOPLEFT", c.dgBox.insetX, -PAD + 2)
	c.dgHeads, c.dgRows = {}, {}
	for i = 1, DG_GROUPS do c.dgHeads[i] = W.Line(c.dgBox, 12, W.STYLE_DUNGEON.label, "LEFT") end
	for i = 1, DG_ROWS do c.dgRows[i] = W.Line(c.dgBox, 12, W.TEXT, "LEFT") end
	c.dgMore = W.Line(c.dgBox, 11, W.DIM, "LEFT")

	-- NEW FOR YOU: secondary, fits its content; present only while active
	c.nfyBox = W.Card(page, FULL, 80, W.STYLE_NEW)
	c.nfyLabel = W.Label(c.nfyBox, "NEW FOR YOU", W.STYLE_NEW.label)
	c.nfyLabel:SetPoint("TOPLEFT", c.nfyBox, "TOPLEFT", c.nfyBox.insetX, -c.nfyBox.insetY)
	c.nfyLevel = W.Line(c.nfyBox, 10, W.DIM, "LEFT")
	c.nfyRows = {}
	for i = 1, 3 do c.nfyRows[i] = W.Line(c.nfyBox, 12, W.TEXT, "LEFT", true) end

	c.partyHead = W.Line(page, 11, W.WARM_GOLD, "LEFT")
	c.partyRows = {}
	for i = 1, 2 do c.partyRows[i] = { head = W.Line(page, 11, W.TEXT, "LEFT") } end
	return page
end

--- Draws a list of objectives { text, have, need } as progress rows (at most `rows` of them). Returns the new y and how many were left out.
local function drawObjectives(box, st, rows, list, inner, x)
	local shown = 0
	for i, row in ipairs(rows) do
		local o = list[i]
		if o then
			row:Place(box, x, st.y, inner)
			row:Set(o.text, o.have, o.need)
			st.y = st.y + W.ROW_H + 3
			shown = shown + 1
		else
			row:Clear()
		end
	end
	return #list - shown
end

local function drawNow(c, card)
	local box = c.nowBox
	local inner = FULL - box.insetX - PAD
	local st = W.Stack(box, inner)
	local n = card.now
	local objectives = n and n.objectives or {}
	if n then
		c.nowTitle:SetText(n.title or "")
		c.nowWho:SetText(n.who or "")
		-- the one-line detail is only for an objective whose counts the quest log did not report
		c.nowDetail:SetText((n.kind == "OBJECTIVE" and #objectives == 0) and (n.detail or "") or "")
		c.nowInfo:SetText(n.whereShort or n.where or "")
	else
		-- nothing to recommend: say so quietly, without the marker
		c.nowTitle:SetText(card.empty.title)
		c.nowWho:SetText(card.empty.lines[1] or "")
		c.nowDetail:SetText(card.empty.lines[2] or "")
		c.nowInfo:SetText("")
	end
	W.SetColor(c.nowTitle, n and W.WARM_GOLD or W.DIM)
	if n then c.nowSkip:Show() else c.nowSkip:Hide() end
	c.thenFS:SetText(card.thenLine and ("Then: " .. card.thenLine) or "")
	st:Skip(18)                                       -- the NOW label row
	local kindIcon = n and (n.kind == "ACCEPT" and "bang" or (n.kind == "TURN_IN" and "query")) or nil
	c.nowKindIcon:Set(kindIcon)
	if kindIcon then
		c.nowKindIcon:Place(box, box.insetX, st.y + 1)
		st:Add(c.nowTitle, 3, box.insetX + 20, inner - 24)
	else
		st:Add(c.nowTitle, 3, nil, inner - 4)
	end
	st:Add(c.nowWho, 3)
	st:Add(c.nowDetail, 4)
	local left = drawObjectives(box, st, c.nowRows, objectives, inner, box.insetX)
	c.nowMore:SetText(left > 0 and string.format("+ %d more", left) or "")
	st:Add(c.nowMore, 2)
	st:Add(c.nowInfo, 3)
	if W.TextOf(c.thenFS) ~= "" then
		c.nowDivider:ClearAllPoints()
		c.nowDivider:SetPoint("TOPLEFT", box, "TOPLEFT", box.insetX, -(st.y + 1))
		c.nowDivider:SetPoint("TOPRIGHT", box, "TOPRIGHT", -PAD, -(st.y + 1))
		c.nowDivider:Show()
		st:Skip(6)
		st:Add(c.thenFS, 0)
	else
		c.nowDivider:Hide()
		c.thenFS:Hide()
	end
	return math.max(NOW_MIN, math.floor(st.y + PAD + 0.5))
end

--- ALSO COMPLETE THIS. Returns the card height, or nil when there is nothing to show (the card is then hidden).
local function drawAlso(c, items)
	local box = c.alsoBox
	if #items == 0 then return nil end
	local inner = FULL - box.insetX - PAD
	local st = W.Stack(box, inner)
	local hasObjective = false
	for _, it in ipairs(items) do if it.kind == "objective" then hasObjective = true end end
	c.alsoLabel:SetText(hasObjective and "ALSO COMPLETE THIS" or "ALSO DO")
	st:Skip(16)
	local rowsUsed, headsUsed, left = 0, 0, 0
	for _, h in ipairs(c.alsoHeads) do h:SetText(""); h:Hide() end
	local rowPool = {}
	for _, it in ipairs(items) do
		if it.kind == "objective" then
			local single = #it.objectives == 1
			if single then
				-- one unfinished objective: the quest's own name beside its count, one row
				if rowsUsed < #c.alsoRows then
					rowsUsed = rowsUsed + 1
					local row, o = c.alsoRows[rowsUsed], it.objectives[1]
					row:Place(box, box.insetX, st.y, inner)
					row:Set(it.title, o.have, o.need)
					st.y = st.y + W.ROW_H + 3
				else
					left = left + 1
				end
			else
				headsUsed = headsUsed + 1
				local head = c.alsoHeads[headsUsed]
				if head then
					head:SetText(it.title)
					st:Add(head, 1)
				end
				for _, o in ipairs(it.objectives) do
					if rowsUsed < #c.alsoRows then
						rowsUsed = rowsUsed + 1
						local row = c.alsoRows[rowsUsed]
						row:Place(box, box.insetX + 6, st.y, inner - 6)
						row:Set(o.text, o.have, o.need)
						st.y = st.y + W.ROW_H + 3
					else
						left = left + 1
					end
				end
			end
		else
			-- the planner's own "also do" (a pickup or hand-in at the same stop): a plain line
			headsUsed = headsUsed + 1
			local head = c.alsoHeads[headsUsed]
			if head then
				head:SetText(it.title .. (it.where and ("  -  " .. it.where) or ""))
				st:Add(head, 3)
			end
		end
	end
	for i = rowsUsed + 1, #c.alsoRows do c.alsoRows[i]:Clear() end
	c.alsoMore:SetText(left > 0 and string.format("+ %d more", left) or "")
	st:Add(c.alsoMore, 0)
	return math.floor(st.y + PAD - 2 + 0.5)
end

--- READY TO TURN IN. Returns the card height, or nil when nothing is ready (the card is then hidden).
local function drawReady(c, items)
	local box = c.readyBox
	if #items == 0 then return nil end
	local inner = FULL - box.insetX - PAD
	local st = W.Stack(box, inner)
	st:Skip(16)
	local left = 0
	for i, row in ipairs(c.readyRows) do
		local it = items[i]
		row:SetText(it and (it.title .. (it.where and ("  -  " .. it.where) or "")) or "")
		local y0 = st.y
		st:Add(row, 2, box.insetX + 18, inner - 18)
		if it then
			c.readyIcons[i]:Set("query")
			c.readyIcons[i]:Place(box, box.insetX, y0 + 0)
		else
			c.readyIcons[i]:Set(nil)
		end
	end
	left = #items - #c.readyRows
	c.readyMore:SetText(left > 0 and string.format("+ %d more", left) or "")
	st:Add(c.readyMore, 0)
	return math.floor(st.y + PAD - 2 + 0.5)
end

--- DUNGEON QUESTS, grouped by dungeon (a heading only when there is more than one dungeon). Returns the card height, or nil when there are none.
local function drawDungeons(c, groups)
	if #groups == 0 then return nil end
	local box = c.dgBox
	local inner = FULL - box.insetX - PAD
	local st = W.Stack(box, inner)
	st:Skip(16)
	local rows, heads, left = 0, 0, 0
	local several = #groups > 1
	for _, h in ipairs(c.dgHeads) do h:SetText("") end
	for _, r in ipairs(c.dgRows) do r:SetText("") end
	for gi, g in ipairs(groups) do
		local head = (several or g.via ~= "none") and c.dgHeads[gi] or nil
		if head and gi <= #c.dgHeads then
			head:SetText(g.name)
			st:Add(head, 3, box.insetX, inner)
		end
		for _, q in ipairs(g.quests) do
			rows = rows + 1
			local row = c.dgRows[rows]
			if row then
				row:SetText(q.title .. (q.complete and "  -  ready to turn in" or ""))
				st:Add(row, 2, box.insetX + (head and 8 or 0), inner - (head and 8 or 0))
			else
				left = left + 1
			end
		end
	end
	c.dgMore:SetText(left > 0 and string.format("+ %d more", left) or "")
	st:Add(c.dgMore, 0)
	return math.floor(st.y + PAD - 2 + 0.5)
end

local function drawNewForYou(c, nfy)
	local box = c.nfyBox
	local inner = FULL - box.insetX - PAD
	c.nfyLevel:SetText("Level " .. nfy.level)
	for i, fs in ipairs(c.nfyRows) do
		local it = nfy.items[i]
		fs:SetText(it and (it.title .. (it.detail and ("\n" .. it.detail) or "")) or "")
	end
	local st = W.Stack(box, inner)
	st:Skip(16)                                       -- the label row
	st:Add(c.nfyLevel, 4)
	for _, fs in ipairs(c.nfyRows) do st:Add(fs, 6) end
	return math.floor(st.y + PAD + 0.5)
end

local function refresh()
	local c = UI.main.codex
	local ctx, plan = ns.State.ctx, ns.State.plan
	if not ctx then return end
	c.header:SetText(ns.Presenter.Header(ctx))
	local nfy = ns.NewForYou.Active()
	UI.main.nfyShown = nfy ~= nil
	local card = ns.Presenter.Card(plan, ctx)

	local sl = card.slots
	if sl then
		c.slots:SetText(string.format("%d/%d", sl.used, sl.max))
		W.SetColor(c.slots, sl.full and W.ALERT or (sl.free <= 2 and W.WARM_GOLD or W.DIM))      -- quiet normally, gold at 38+, red when full
	else
		c.slots:SetText("")
	end

	local nowH = drawNow(c, card)
	placeCard(c, c.nowBox, TOP, FULL, nowH)
	local bottom = TOP + nowH

	local alsoH = drawAlso(c, card.also or {})
	if alsoH then
		c.alsoBox:Show()
		placeCard(c, c.alsoBox, bottom + GAP - 2, FULL, alsoH)
		bottom = bottom + GAP - 2 + alsoH
	else
		c.alsoBox:Hide()
	end

	local readyH = drawReady(c, card.ready or {})
	if readyH then
		c.readyBox:Show()
		placeCard(c, c.readyBox, bottom + GAP - 2, FULL, readyH)
		bottom = bottom + GAP - 2 + readyH
	else
		c.readyBox:Hide()
	end

	local dgH = drawDungeons(c, card.dungeons or {})
	if dgH then
		c.dgBox:Show()
		placeCard(c, c.dgBox, bottom + GAP - 2, FULL, dgH)
		bottom = bottom + GAP - 2 + dgH
	else
		c.dgBox:Hide()
	end

	if nfy then
		c.nfyBox:Show()
		local h = drawNewForYou(c, nfy)
		placeCard(c, c.nfyBox, bottom + GAP - 2, FULL, h)
		bottom = bottom + GAP - 2 + h
	else
		c.nfyBox:Hide()
	end

	-- below the cards: the party card (quests Codex cannot place are not listed here: they are in /codex report)
	local y = bottom + 6
	local pv = ns.Party.View(ctx)
	if #pv.lines > 0 then
		c.partyHead:SetText("Party")
		W.Place(c.partyHead, c.page, 0, -y, FULL)
		y = y + 16
		for i, row in ipairs(c.partyRows) do
			local e = pv.lines[i]
			row.head:SetText(e and (e.head .. "  -  " .. e.mine) or "")
			if e then
				W.Place(row.head, c.page, 0, -y, FULL)
				y = y + 16
			end
		end
	else
		c.partyHead:SetText("")
		for _, row in ipairs(c.partyRows) do row.head:SetText("") end
	end
	-- the window fits the page: the page starts 36 px below the window top, with a little room under the last line
	if UI.FitSize then UI.FitSize(UI.COMPACT_WIDTH, 36 + y + 8) end
end

UI.RegisterPage("codex", "Codex", function(parent)
	local holder = CreateFrame("Frame", nil, parent)
	holder:SetSize(UI.COMPACT_WIDTH - 16, UI.HEIGHT - 44)
	holder:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
	local page = { frame = holder }
	UI.main.codexPage = holder
	build(holder)
	-- before the first-time setup is finished the tracker only points to it (setup lives in the options window)
	local welcome = CreateFrame("Frame", nil, parent)
	welcome:SetSize(UI.COMPACT_WIDTH - 16, 70)
	welcome:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
	local msg = W.Line(welcome, 12, W.TEXT, "LEFT", true)
	msg:SetPoint("TOPLEFT", welcome, "TOPLEFT", 0, -4)
	msg:SetWidth(UI.COMPACT_WIDTH - 16)
	msg:SetText("Welcome! Set up Forever Codex once, then this tracker tells you what to do next.")
	local go = W.Button(welcome, 120, 22, "Set up Codex", function() UI.ShowPage("options") end)
	go:SetPoint("TOPLEFT", welcome, "TOPLEFT", 0, -46)
	UI.main.welcome = welcome
	function page.Refresh()
		if ns.Prefs.SetupDone() then
			welcome:Hide()
			holder:Show()
			refresh()
		else
			holder:Hide()
			welcome:Show()
			if UI.FitSize then UI.FitSize(UI.COMPACT_WIDTH, 36 + 76) end
		end
	end
	return page
end)
