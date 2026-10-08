-- UI page "Codex": what am I doing now, what is left of it, and what else can I knock out while I'm here?
--   NOW                 the one thing to do, with EVERY unfinished objective of that quest (counts and a thin bar each)
--   ALSO COMPLETE / ALSO PICK UP / ALSO DO   other unfinished objectives that fit with NOW (and the planner's own "also do" line), named for what they are
--                       (distance, who, and a short reason when the planner gave one); hidden when there is none
--   READY TO TURN IN    finished quests waiting for the right moment (listed, never forced into NOW) with distance, the hand-in NPC when the data names one,
--                       and how many follow-up quests it opens when the data supports it; hidden when there are none
--   SPELL TRAINING      class spells the trainer offered that you can now learn, with cost and a total; "Don't Want to Learn" hides one for this
--                       character; spells that are learned leave by themselves; hidden when there are none (SpellTraining.lua)
--   PROFESSIONS         status (skill/cap), a secondary profession not learned, a free primary slot, a trainer-offered rank-up; hidden when there is nothing (Professions.lua)
--   NEW FOR YOU         a temporary card for a level you just reached (secondary, never in front of NOW)
--   Party               what party members finished, only when there is something to say
-- Before the first-time setup is finished this page shows the setup panel instead (UI/PageSetup.lua).
--
-- This is a small companion panel (UI.COMPACT_WIDTH wide), not a quest database: only short reasons the planner already gave (the full
-- explanation stays in /codex report), no sentences where a number says it. This file only DRAWS: every word and count comes from Presenter (which asks Overlap for the
-- ALSO COMPLETE THIS rows); nothing here reads the Planner or the data. Progress bars are textures (the UI is ASCII only: block
-- glyphs would render as boxes) and show only counts the quest log really reported.

local addonName, ns = ...
local W = ns.Widgets
local UI = ns.UI

local FULL = UI.COMPACT_WIDTH - 16  -- page width (follows the window: refresh() sets it from UI.main.width, so every card reflows when the player resizes)
local GAP, PAD = W.GAP, W.PAD
local TOP = 22                      -- below the character line
local NOW_MIN = 56                  -- a card never gets smaller than this
local READY_ROWS = 12              -- hand-ins listed in READY TO TURN IN (the window grows to fit; the rest are summarised in one line)
local DG_GROUPS, DG_ROWS = 4, 12      -- DUNGEON QUESTS: dungeons and quest lines drawn (the rest are summarised in one line)
local ST_ROWS = ns.SpellTraining and ns.SpellTraining.MAX_ROWS or 12   -- SPELL TRAINING rows drawn (the rest are summarised in one line)
local PF_ROWS = 12                  -- PROFESSIONS rows drawn
local UN_ROWS = 5                    -- IN YOUR LOG, NOT ON THE MAP rows drawn (Presenter caps the list; the rest are summarised in one line)
local MAX_ROWS = 8                  -- objective rows drawn in one card (the rest are summarised in one line)

--- Places a card at a vertical offset below the page top and sizes it.
local function placeCard(c, card, y, w, h)
	card:ClearAllPoints()
	card:SetPoint("TOPLEFT", c.page, "TOPLEFT", card.__x or 0, -y)
	card:SetSize(w, h)
end

--- A transparent click area over a quest row: opens (or collapses) that quest's QUEST DETAILS card. It has a subtle hover highlight (W.Row) and a tooltip; it only ever reads.
-- Pools are per card (`pool` is a table in c); `i` picks the area, creating it on first use.
local function hitArea(c, pool, i, parent)
	local list = c[pool]
	local b = list[i]
	if not b then
		b = W.Row(parent, 10, 10, function(quest) UI.ToggleQuestDetail(quest) end)
		b:SetScript("OnEnter", function(self)
			self.bg:SetColorTexture(1, 1, 1, 0.12)
			W.ShowTooltip(self, "ANCHOR_RIGHT", { title = "Quest details", rows = { { "Click", "Show or hide this quest's details" } } })
		end)
		b:SetScript("OnLeave", function(self)
			self.bg:SetColorTexture(0, 0, 0, 0)
			local tip = rawget(_G, "GameTooltip")
			if tip then ns.Safe(tip.Hide, tip) end
		end)
		list[i] = b
	end
	return b
end

local function placeHit(b, box, x, y, w, h, quest)
	b:ClearAllPoints()
	b:SetPoint("TOPLEFT", box, "TOPLEFT", x, -y)
	b:SetSize(math.max(1, w), math.max(1, h))
	b.action = quest
	b:Show()
end

local function hideHits(c, pool, from)
	for i = from, #c[pool] do c[pool][i]:Hide() end
end

--- The quest whose details card is open (this session only: never saved, so nothing about it can outlive a reload).
function UI.ToggleQuestDetail(id)
	if not UI.main then return end
	UI.main.detailQuest = (UI.main.detailQuest ~= id) and id or nil
	if UI.Refresh then UI.Refresh() end
end

function UI.CloseQuestDetail()
	if UI.main and UI.main.detailQuest ~= nil then
		UI.main.detailQuest = nil
		if UI.Refresh then UI.Refresh() end
	end
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
	c.nowBox = W.Card(page, FULL, NOW_MIN, "primary")
	-- a way out of a recommendation that is wrong or unavailable: skips it (the same as /codex skip; /codex unskip brings it back)
	c.nowSkip = W.Button(c.nowBox, 40, 16, "Skip", function()
		local a = ns.State.SkipCurrent()
		if a then ns.Say("Skipped: " .. tostring(a.title) .. ". (/qflow unskip brings skipped items back.)") end
	end)
	c.nowSkip:SetPoint("TOPRIGHT", c.nowBox, "TOPRIGHT", -PAD + 4, -PAD + 3)
	-- Report: opens the feedback form about THIS recommendation (category and context already chosen)
	c.nowReport = W.Button(c.nowBox, 46, 16, "Report", function() if ns.UI.OpenFeedback then ns.UI.OpenFeedback({ category = "wrong", from = "NOW" }) end end)
	c.nowReport:SetPoint("TOPRIGHT", c.nowBox, "TOPRIGHT", -PAD - 40, -PAD + 3)
	c.nowLabel = W.CardLabel(c.nowBox, "NOW")
	c.nowKindIcon = W.Icon(c.nowBox, 16)                -- "!" for a pickup, "?" for a hand-in; nothing for objectives
	W.Font(c.nowLabel, 12)
	c.nowTitle = W.Line(c.nowBox, 18, W.WARM_GOLD, "LEFT", true)
	c.nowWho = W.Line(c.nowBox, 12, W.TEXT, "LEFT")
	c.nowDetail = W.Line(c.nowBox, 11, W.DIM, "LEFT", true)
	c.nowRows = {}
	for i = 1, MAX_ROWS do c.nowRows[i] = W.ProgressRow(c.nowBox) end
	c.nowMore = W.Line(c.nowBox, 11, W.DIM, "LEFT")
	c.nowInfo = W.Line(c.nowBox, 11, W.SOFT_GREEN, "LEFT")
	c.nowWhy = W.Line(c.nowBox, 11, W.DIM, "LEFT", true)             -- "Why: ..." one short reason, secondary to the action
	c.nowNav = W.Line(c.nowBox, 11, W.DIM, "LEFT", true)             -- "no arrow: ..." / "straight line only" (Navigation safety)
	c.nowDivider = W.Divider(c.nowBox)
	c.thenFS = W.Line(c.nowBox, 11, W.DIM, "LEFT")
	c.thenWhereFS = W.Line(c.nowBox, 11, W.DIM, "LEFT")      -- "496 yd - Nazgrel" under the THEN line

	-- TIMED QUEST: the game's own countdown for quests that have one, soonest first; present only while one is active. Updated every second by the tracker while it is open.
	c.tmBox = W.Card(page, FULL, 40, "urgent")
	c.tmLabel = W.CardLabel(c.tmBox, "TIMED QUEST")
	c.tmRows = {}
	for i = 1, 3 do c.tmRows[i] = { head = W.Line(c.tmBox, 12, W.TEXT, "LEFT"), time = W.Line(c.tmBox, 13, W.WARM_GOLD, "LEFT") } end

	-- NEW QUEST ITEM: a quest-starting item in the bags (present only when there is one that is actionable)
	c.qiBox = W.Card(page, FULL, 60, "discovery")
	c.qiLabel = W.CardLabel(c.qiBox, "NEW QUEST ITEM")
	c.qiRows = {}
	for i = 1, 2 do
		c.qiRows[i] = { head = W.Line(c.qiBox, 13, W.WARM_GOLD, "LEFT"), body = W.Line(c.qiBox, 11, W.TEXT, "LEFT", true) }
	end
	c.qiMore = W.Line(c.qiBox, 11, W.DIM, "LEFT")

	-- ALSO COMPLETE THIS: supporting, cooler and smaller; present only when there is something to say
	c.alsoBox = W.Card(page, FULL, 40, "optional")
	c.alsoLabel = W.CardLabel(c.alsoBox, "ALSO COMPLETE THIS")
	c.alsoHeads, c.alsoRows = {}, {}
	for i = 1, 4 do c.alsoHeads[i] = W.Line(c.alsoBox, 12, W.TEXT, "LEFT") end
	for i = 1, MAX_ROWS do c.alsoRows[i] = W.ProgressRow(c.alsoBox) end
	c.alsoSubs = {}
	for i = 1, 4 do c.alsoSubs[i] = W.Line(c.alsoBox, 11, W.DIM, "LEFT") end     -- "Here - Aamelia Windfield - same stop" under a pickup
	c.alsoNote = W.Line(c.alsoBox, 11, W.DIM, "LEFT")                            -- one shared reason for the objectives above it
	c.alsoMore = W.Line(c.alsoBox, 11, W.DIM, "LEFT")

	-- READY TO TURN IN: finished quests, a quiet green card; present only when there are some
	c.readyBox = W.Card(page, FULL, 40, "ready")
	c.readyLabel = W.CardLabel(c.readyBox, "READY TO TURN IN")
	c.readyRows, c.readyIcons, c.readySubs = {}, {}, {}
	for i = 1, READY_ROWS do
		c.readyRows[i] = W.Line(c.readyBox, 12, W.TEXT, "LEFT")
		c.readySubs[i] = W.Line(c.readyBox, 11, W.DIM, "LEFT")
		c.readyIcons[i] = W.Icon(c.readyBox, 14)
	end
	c.readyMore = W.Line(c.readyBox, 11, W.DIM, "LEFT")

	-- DUNGEON QUESTS: quests the game tags as dungeon / raid, a red card, grouped by dungeon; present only when there are some
	c.dgBox = W.Card(page, FULL, 40, "dungeon")
	c.dgLabel = W.CardLabel(c.dgBox, "DUNGEON QUESTS")
	c.dgHeads, c.dgRows = {}, {}
	for i = 1, DG_GROUPS do c.dgHeads[i] = W.Line(c.dgBox, 12, ns.Theme.Color("dungeon"), "LEFT") end
	for i = 1, DG_ROWS do c.dgRows[i] = W.Line(c.dgBox, 12, W.TEXT, "LEFT") end
	c.dgMore = W.Line(c.dgBox, 11, W.DIM, "LEFT")

	-- SPELL TRAINING: class spells the trainer offered that the character can now learn; present only while there are some. Informational: no Learn button.
	c.stBox = W.Card(page, FULL, 40, "training")
	c.stLabel = W.CardLabel(c.stBox, "SPELL TRAINING")
	c.stRows = {}
	for i = 1, ST_ROWS do
		local row = { line = W.Line(c.stBox, 12, W.TEXT, "LEFT") }
		row.btn = W.Button(c.stBox, 108, 16, "Don't Want to Learn", function()
			if row.key then ns.SpellTraining.Dismiss(row.key) end
		end)
		c.stRows[i] = row
	end
	c.stMore = W.Line(c.stBox, 11, W.DIM, "LEFT")
	c.stTotal = W.Line(c.stBox, 12, W.WARM_GOLD, "LEFT")

	-- PET TRAINING: only for pet classes and only when a pet source has something to say (Relevance.lua / PetTraining.lua); otherwise the card does not exist and nothing reflows
	c.ptBox = W.Card(page, FULL, 40, "training")
	c.ptLabel = W.CardLabel(c.ptBox, "PET TRAINING")
	c.ptRows = {}
	for i = 1, (ns.PetTraining and ns.PetTraining.MAX_ROWS or 6) do c.ptRows[i] = { head = W.Line(c.ptBox, 12, W.TEXT, "LEFT", true), body = W.Line(c.ptBox, 11, W.DIM, "LEFT", true) } end

	-- PROFESSIONS: status and reminders (skill/cap, a secondary not learned, a free primary slot, a trainer-offered rank-up); present only when there is something to say
	c.pfBox = W.Card(page, FULL, 40, "profession")
	c.pfLabel = W.CardLabel(c.pfBox, "PROFESSIONS")
	c.pfRows = {}
	for i = 1, PF_ROWS do
		local row = { line = W.Line(c.pfBox, 12, W.TEXT, "LEFT") }
		row.btn = W.Button(c.pfBox, 40, 16, "Hide", function() if row.key then ns.Professions.Hide(row.key) end end)
		c.pfRows[i] = row
	end

	-- QUEST DETAILS: a small Codex-owned card for ONE quest the player clicked (a quest Codex cannot place on the map); present only while one is open. Not a quest journal.
	c.qdBox = W.Card(page, FULL, 60, "optional")
	c.qdLabel = W.CardLabel(c.qdBox, "QUEST DETAILS")
	c.qdClose = W.Button(c.qdBox, 40, 16, "Close", function() UI.CloseQuestDetail() end)
	c.qdClose:SetPoint("TOPRIGHT", c.qdBox, "TOPRIGHT", -PAD + 4, -PAD + 3)
	c.qdTitle = W.Line(c.qdBox, 14, W.WARM_GOLD, "LEFT", true)
	c.qdHead = W.Line(c.qdBox, 11, W.DIM, "LEFT")
	c.qdStatus = W.Line(c.qdBox, 12, W.TEXT, "LEFT")
	c.qdRows = {}
	for i = 1, MAX_ROWS do c.qdRows[i] = W.ProgressRow(c.qdBox) end
	c.qdMore = W.Line(c.qdBox, 11, W.DIM, "LEFT")
	c.qdGiver = W.Line(c.qdBox, 11, W.DIM, "LEFT", true)
	c.qdTurn = W.Line(c.qdBox, 11, W.DIM, "LEFT", true)
	c.qdNote = W.Line(c.qdBox, 11, W.DIM, "LEFT", true)

	-- IN YOUR LOG, NOT ON THE MAP: every quest in the log Codex cannot place (no usable map position). Quiet and low priority: it never competes with NOW; each row opens QUEST DETAILS.
	c.unBox = W.Card(page, FULL, 40, "later")
	c.unLabel = W.CardLabel(c.unBox, "IN YOUR LOG, NOT ON THE MAP")
	c.unHint = W.Line(c.unBox, 11, W.DIM, "LEFT", true)
	c.unRows, c.unSubs, c.unArrows = {}, {}, {}
	for i = 1, UN_ROWS do
		c.unRows[i] = W.Line(c.unBox, 12, W.TEXT, "LEFT")
		c.unSubs[i] = W.Line(c.unBox, 11, W.DIM, "LEFT")
		c.unArrows[i] = W.Line(c.unBox, 11, W.DIM, "RIGHT")
	end
	c.unMore = W.Line(c.unBox, 11, W.DIM, "LEFT")
	-- the header row minimises / opens the section (remembered); the [+] / [-] marks it
	c.unToggle = W.Line(c.unBox, 11, W.DIM, "RIGHT")
	c.unHead = W.Row(c.unBox, FULL, 20, function() UI.ToggleUnplaced() end)
	c.unHead:SetPoint("TOPLEFT", c.unBox, "TOPLEFT", 0, 0)
	c.unHead.action = true                                        -- (W.Row only fires for a row that has an action)
	c.unHead:SetScript("OnEnter", function(self)
		self.bg:SetColorTexture(1, 1, 1, 0.08)
		W.ShowTooltip(self, "ANCHOR_RIGHT", { title = "Quests Quest Flow cannot place", rows = { { "Click", "Minimise or open this list" } } })
	end)
	c.unHead:SetScript("OnLeave", function(self)
		self.bg:SetColorTexture(0, 0, 0, 0)
		local tip = rawget(_G, "GameTooltip")
		if tip then ns.Safe(tip.Hide, tip) end
	end)
	c.unHits, c.readyHits, c.nowHits = {}, {}, {}
	c.nowHint = W.Line(c.nowBox, 11, W.DIM, "LEFT")                  -- "Click the quest name for its details." (guidance with no map position only)
	c.readyArrows = {}
	for i = 1, READY_ROWS do c.readyArrows[i] = W.Line(c.readyBox, 11, W.DIM, "RIGHT") end

	-- NEW FOR YOU: secondary, fits its content; present only while active
	c.nfyBox = W.Card(page, FULL, 80, "discovery")
	c.nfyLabel = W.CardLabel(c.nfyBox, "NEW FOR YOU")
	c.nfyLevel = W.Line(c.nfyBox, 10, W.DIM, "LEFT")
	c.nfyRows = {}
	for i = 1, 3 do c.nfyRows[i] = W.Line(c.nfyBox, 12, W.TEXT, "LEFT", true) end

	-- a theme change repaints the cards themselves (W.Restyle); the few texts coloured from a role are repainted here
	W.OnRestyle = function()
		for _, fs in ipairs(c.dgHeads) do W.SetColor(fs, ns.Theme.Color("dungeon")) end
		W.SetColor(c.nowTitle, ns.Theme.Color("primary"))
		if UI.Refresh then UI.Refresh() end
	end
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
		c.nowDetail:SetText(n.caution or (((n.kind == "OBJECTIVE" and #objectives == 0) or n.guidance) and (n.detail or "")) or "")
		-- the distance as a number ("600 yd", "Here"), then the quest's level when the data has one: secondary information
		c.nowInfo:SetText(ns.Presenter.Join(n.dist or n.whereShort or n.where, n.level and ("Lv " .. n.level)) or "")
	else
		-- nothing to recommend: say so quietly, without the marker
		c.nowTitle:SetText(card.empty.title)
		c.nowWho:SetText(card.empty.lines[1] or "")
		c.nowDetail:SetText(card.empty.lines[2] or "")
		c.nowInfo:SetText("")
	end
	W.SetColor(c.nowTitle, n and ns.Theme.Color("primary") or W.DIM)
	if n then c.nowReport:Show() else c.nowReport:Hide() end
	if n and not n.guidance then c.nowSkip:Show() else c.nowSkip:Hide() end       -- (guidance is not a planner recommendation: there is nothing to skip)
	c.thenFS:SetText(card.thenLine and ("Then: " .. card.thenLine) or "")
	c.thenWhereFS:SetText(card.thenLine and card.thenWhere or "")
	st:Skip(18)                                       -- the NOW label row
	local kindIcon = n and (n.kind == "ACCEPT" and "bang" or (n.kind == "TURN_IN" and "query")) or nil
	c.nowKindIcon:Set(kindIcon)
	local titleY, titleH = st.y, 0
	if kindIcon then
		c.nowKindIcon:Place(box, box.insetX, st.y + 1)
		titleH = st:Add(c.nowTitle, 3, box.insetX + 20, inner - 24)
	else
		titleH = st:Add(c.nowTitle, 3, nil, inner - 4)
	end
	-- the title of a NOW quest that is in the log opens its QUEST DETAILS (the planner and the arrow are unaffected)
	local clickable = n and n.quest and n.kind ~= "ACCEPT"            -- (0.14.3) any NOW for a quest in the log opens its details, not only guidance with no place
	if clickable then
		placeHit(hitArea(c, "nowHits", 1, box), box, box.insetX, titleY, inner - 4, titleH, n.quest)
		c.nowHint:SetText(UI.main.detailQuest == n.quest and "Click the quest name to hide its details." or "Click the quest name for its details.")
	else
		hideHits(c, "nowHits", 1)
		c.nowHint:SetText("")
	end
	st:Add(c.nowHint, 3)
	st:Add(c.nowWho, 3)
	st:Add(c.nowDetail, 4)
	local left = drawObjectives(box, st, c.nowRows, objectives, inner, box.insetX)
	c.nowMore:SetText(left > 0 and string.format("+ %d more", left) or "")
	st:Add(c.nowMore, 2)
	st:Add(c.nowInfo, 3)
	c.nowWhy:SetText(n and n.whyPlayer and ("Why: " .. n.whyPlayer) or "")
	st:Add(c.nowWhy, 3)
	c.nowNav:SetText(n and n.navNote or "")
	W.SetColor(c.nowNav, (n and n.navDirection) and W.TEXT or W.DIM)         -- a direction to head in is guidance, not a footnote
	st:Add(c.nowNav, 3)
	if W.TextOf(c.thenFS) ~= "" then
		c.nowDivider:ClearAllPoints()
		c.nowDivider:SetPoint("TOPLEFT", box, "TOPLEFT", box.insetX, -(st.y + 1))
		c.nowDivider:SetPoint("TOPRIGHT", box, "TOPRIGHT", -PAD, -(st.y + 1))
		c.nowDivider:Show()
		st:Skip(6)
		st:Add(c.thenFS, 1)
		st:Add(c.thenWhereFS, 0)
	else
		c.nowDivider:Hide()
		c.thenFS:Hide()
		c.thenWhereFS:Hide()
	end
	return math.max(NOW_MIN, math.floor(st.y + PAD + 0.5))
end

--- Writes the timer rows' text and colours and lets the card follow the most urgent timer (called by the full draw and, every second, by the tracker's own update). The card is the
-- "urgent" role: it gets louder only as the deadline nears (UI/Theme.lua Urgency), and a time that is nearly up also says so in words, not only in colour.
local function paintTimers(c, list)
	local first = list[1]
	local level = first and first.level or "OK"
	local style, _ = ns.Theme.Urgency(level)
	c.tmLevel = level
	c.tmBox.styleOverride = function() return (ns.Theme.Urgency(c.tmLevel)) end
	W.SetCardStyle(c.tmBox, style)
	c.tmLabel:SetText(level == "CRITICAL" and "TIMED QUEST - HURRY" or (level == "EXPIRED" and "TIMED QUEST - OUT OF TIME" or "TIMED QUEST"))
	for i, row in ipairs(c.tmRows) do
		local t = list[i]
		row.time:SetText(t and t.text or "")
		if t then local _, col = ns.Theme.Urgency(t.level); W.SetColor(row.time, col) end
	end
end

--- TIMED QUEST. Returns the card height, or nil when no quest is counting down (the card is then hidden).
local function drawTimers(c, list)
	if #list == 0 then return nil end
	local box = c.tmBox
	local inner = FULL - box.insetX - PAD
	local st = W.Stack(box, inner)
	st:Skip(16)
	for i, row in ipairs(c.tmRows) do
		local t = list[i]
		row.head:SetText(t and t.title or "")
		row.time:SetText(t and t.text or "")
		st:Add(row.head, 1)
		st:Add(row.time, 4)
	end
	paintTimers(c, list)
	return math.floor(st.y + PAD - 2 + 0.5)
end

--- Called by the tracker about once a second while it is open: only the timer texts change, nothing is recomputed. Returns true when a timed quest is on screen.
function UI.RefreshTimers()
	local c = UI.main and UI.main.codex
	local ctx = ns.State and ns.State.ctx
	if not (c and c.tmBox and ctx and ns.QuestTimers) then return false end
	local list = ns.QuestTimers.List(ctx)
	if #list == 0 then return false end
	paintTimers(c, list)
	return true
end

--- NEW QUEST ITEM. Returns the card height, or nil when there is no actionable quest-starting item (the card is then hidden).
local function drawQuestItems(c, items)
	if #items == 0 then return nil end
	local box = c.qiBox
	local inner = FULL - box.insetX - PAD
	local st = W.Stack(box, inner)
	st:Skip(16)
	for i, row in ipairs(c.qiRows) do
		local it = items[i]
		row.head:SetText(it and it.title or "")
		row.body:SetText(it and (it.detail .. (it.questName and (" Starts: " .. it.questName .. ".") or "")) or "")
		st:Add(row.head, 1)
		st:Add(row.body, 4)
	end
	c.qiMore:SetText(#items > #c.qiRows and string.format("+ %d more", #items - #c.qiRows) or "")
	st:Add(c.qiMore, 0)
	return math.floor(st.y + PAD - 2 + 0.5)
end

--- ALSO COMPLETE THIS. Returns the card height, or nil when there is nothing to show (the card is then hidden).
local function drawAlso(c, items)
	local box = c.alsoBox
	if #items == 0 then return nil end
	local inner = FULL - box.insetX - PAD
	local st = W.Stack(box, inner)
	-- named for what the rows are, decided from the whole set (Presenter.AlsoLabel)
	local nObj = 0
	for _, it in ipairs(items) do if it.kind == "objective" then nObj = nObj + 1 end end
	c.alsoLabel:SetText(ns.Presenter.AlsoLabel(items) or "")
	st:Skip(16)
	for _, sub in ipairs(c.alsoSubs) do sub:SetText(""); sub:Hide() end
	local subsUsed = 0
	local noteWhy, noteSame = nil, true
	local rowsUsed, headsUsed, left = 0, 0, 0
	for _, h in ipairs(c.alsoHeads) do h:SetText(""); h:Hide() end
	local rowPool = {}
	for _, it in ipairs(items) do
		if it.kind == "objective" then
			-- one unfinished objective is drawn compactly (quest name beside its count) ONLY when the quest name says what the count is of; when the
			-- objective has its own wording ("Windsong Crawler Meat"), the quest is a heading and the objective is the row, like any other quest
			local o1 = it.objectives[1]
			local single = #it.objectives == 1 and not (o1 and o1.text and o1.text ~= "" and o1.text ~= "objective" and o1.text ~= it.title)
			if single then
				-- one unfinished objective: the quest's own name beside its count, one row
				if rowsUsed < #c.alsoRows then
					rowsUsed = rowsUsed + 1
					local row, o = c.alsoRows[rowsUsed], it.objectives[1]
					row:Place(box, box.insetX, st.y, inner)
					row:Set(ns.Presenter.Join(it.title, it.dist), o.have, o.need)
					st.y = st.y + W.ROW_H + 3
				else
					left = left + 1
				end
			else
				headsUsed = headsUsed + 1
				local head = c.alsoHeads[headsUsed]
				if head then
					head:SetText(ns.Presenter.Join(it.title, it.dist))
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
				-- the title, then (dim) how far, who, and why: "Here - Aamelia Windfield - Same stop."
				local why = it.caution and it.caution:gsub("%.$", ""):lower() or (it.why and it.why:gsub("%.$", ""):lower() or nil)
				if it.unconfirmed then why = (why and (why .. ", ") or "") .. "not offered yet" end      -- an optional extra: the game has not offered this quest
				local sub = ns.Presenter.Join(it.dist or it.where, it.npc, why)
				head:SetText(it.title)
				st:Add(head, sub and 0 or 3)
				if sub then
					subsUsed = subsUsed + 1
					local fs = c.alsoSubs[subsUsed]
					if fs then
						fs:SetText(sub)
						st:Add(fs, 6)
					end
				end
			end
		end
		-- objectives share ONE reason line when they all have the same one
		if it.kind == "objective" then
			if it.why == nil then noteSame = false
			elseif noteWhy == nil then noteWhy = it.why
			elseif noteWhy ~= it.why then noteSame = false end
		end
	end
	-- the shared reason describes objective rows only: shown when EVERY row is an objective (under a mix it would read as applying to the pickups)
	c.alsoNote:SetText((nObj == #items and noteSame and noteWhy) or "")
	st:Add(c.alsoNote, 1)
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
		row:SetText(it and it.title or "")
		local y0 = st.y
		-- under the name (dim): how far, the hand-in NPC when the data names one, and the follow-up quests it opens when the data supports it
		local sub = it and ns.Presenter.Join(it.distText or it.where, it.npc, it.unlocks and string.format("opens %d more quest%s", it.unlocks, it.unlocks == 1 and "" or "s") or nil)
		c.readySubs[i]:SetText(sub or "")
		st:Add(row, sub and 0 or 2, box.insetX + 18, inner - 18)
		st:Add(c.readySubs[i], 3, box.insetX + 18, inner - 18)
		-- a finished quest Codex has no map position for: the row opens its QUEST DETAILS (one with a position keeps its normal behaviour)
		if it and it.placed == false and it.quest then
			placeHit(hitArea(c, "readyHits", i, box), box, box.insetX, y0, inner, st.y - y0 - 1, it.quest)
			c.readyArrows[i]:ClearAllPoints()
			c.readyArrows[i]:SetPoint("TOPRIGHT", box, "TOPRIGHT", -PAD, -y0)
			c.readyArrows[i]:SetText(UI.main.detailQuest == it.quest and "[-]" or "[+]")
			c.readyArrows[i]:Show()
		else
			if c.readyHits[i] then c.readyHits[i]:Hide() end
			c.readyArrows[i]:SetText("")
			c.readyArrows[i]:Hide()
		end
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

--- IN YOUR LOG, NOT ON THE MAP: quests with no usable map position, each opening its QUEST DETAILS. Returns the card height, or nil when there are none.
local function drawUnplaced(c, un)
	local box = c.unBox
	if not un or #un.rows == 0 then hideHits(c, "unHits", 1) c.unHead:Hide() c.unToggle:SetText("") return nil end
	local inner = FULL - box.insetX - PAD
	local st = W.Stack(box, inner)
	local collapsed = ns.Prefs.UnplacedCollapsed()
	c.unLabel:SetText("IN YOUR LOG, NOT ON THE MAP  (" .. (#un.rows + (un.more or 0)) .. ")")
	c.unToggle:ClearAllPoints()
	c.unToggle:SetPoint("TOPRIGHT", box, "TOPRIGHT", -PAD, -(box.insetY))
	c.unToggle:SetText(collapsed and "[+]" or "[-]")
	c.unToggle:Show()
	c.unHead:Show()
	st:Skip(16)
	if collapsed then
		-- minimised: only the header row stays
		hideHits(c, "unHits", 1)
		c.unHint:SetText("")
		c.unMore:SetText("")
		for i = 1, UN_ROWS do
			c.unRows[i]:SetText("")
			c.unSubs[i]:SetText("")
			c.unArrows[i]:SetText("")
			c.unArrows[i]:Hide()
			c.unRows[i]:Hide()
			c.unSubs[i]:Hide()
		end
		c.unHint:Hide()
		c.unMore:Hide()
		return math.floor(st.y + PAD - 2 + 0.5)
	end
	c.unHint:Show()
	c.unMore:Show()
	c.unHint:SetText("No arrow for these: Quest Flow has no map position for them. Click one for its details.")
	st:Add(c.unHint, 4)
	for i = 1, UN_ROWS do
		local r = un.rows[i]
		if r then
			local y0 = st.y
			c.unRows[i]:SetText(r.title)
			c.unSubs[i]:SetText(r.state)
			st:Add(c.unRows[i], 0, nil, inner - 28)
			st:Add(c.unSubs[i], 4)
			placeHit(hitArea(c, "unHits", i, box), box, box.insetX, y0, inner, st.y - y0 - 2, r.quest)
			c.unArrows[i]:ClearAllPoints()
			c.unArrows[i]:SetPoint("TOPRIGHT", box, "TOPRIGHT", -PAD, -y0)
			c.unArrows[i]:SetText(UI.main.detailQuest == r.quest and "[-]" or "[+]")
			c.unArrows[i]:Show()
		else
			c.unRows[i]:SetText("")
			c.unSubs[i]:SetText("")
			c.unArrows[i]:SetText("")
			c.unArrows[i]:Hide()
			if c.unHits[i] then c.unHits[i]:Hide() end
			c.unRows[i]:Hide()
			c.unSubs[i]:Hide()
		end
	end
	c.unMore:SetText(un.more > 0 and string.format("+ %d more in your quest log", un.more) or "")
	st:Add(c.unMore, 0)
	return math.floor(st.y + PAD - 2 + 0.5)
end

--- QUEST DETAILS for the clicked quest (UI.main.detailQuest). Closes itself (and returns nil) when that quest is no longer in the log. Read-only: it never opens the game's own quest UI.
local function drawDetail(c, card, ctx)
	local id = UI.main.detailQuest
	if not id then return nil end
	local d = ns.Presenter.QuestDetail(id, card, ctx)
	if not d then
		UI.main.detailQuest = nil                             -- the quest left the log (handed in, abandoned): the card closes
		return nil
	end
	local box = c.qdBox
	local inner = FULL - box.insetX - PAD
	local st = W.Stack(box, inner)
	st:Skip(18)
	c.qdTitle:SetText(d.title .. (d.tag and (" (" .. d.tag .. ")") or ""))
	c.qdHead:SetText(d.header and ("Quest log: " .. d.header) or "")
	c.qdStatus:SetText(d.status)
	W.SetColor(c.qdStatus, d.state == "READY" and ns.Theme.Color("ready") or W.TEXT)
	st:Add(c.qdTitle, 3, nil, inner - 46)
	st:Add(c.qdHead, 2)
	st:Add(c.qdStatus, 5)
	local shown = 0
	for i, row in ipairs(c.qdRows) do
		local o = d.objectives[i]
		if o then
			row:Place(box, box.insetX, st.y, inner)
			local text = o.loading and "Objective still loading" or (ns.Presenter.CleanObjective(o.text) or o.text)
			row:Set(text, o.have, o.need)
			st.y = st.y + W.ROW_H + 3
			shown = shown + 1
		else
			row:Clear()
		end
	end
	c.qdMore:SetText(#d.objectives > shown and string.format("+ %d more", #d.objectives - shown) or "")
	st:Add(c.qdMore, 2)
	c.qdGiver:SetText(d.giver or "")
	c.qdTurn:SetText(d.turnIn or "")
	c.qdNote:SetText(d.note or "")
	st:Add(c.qdGiver, 2)
	st:Add(c.qdTurn, 2)
	st:Add(c.qdNote, 2)
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
			head:SetText(g.name .. (g.entranceText and ("  -  " .. g.entranceText) or ""))      -- (0.15.3) where it was entered from, once the character has been inside
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

--- SPELL TRAINING. Returns the card height, or nil when there is nothing to train (the card is then hidden entirely: no empty header).
local function drawSpells(c, sp)
	if not sp or #sp.rows == 0 then
		for _, row in ipairs(c.stRows) do row.key = nil; row.btn:Hide() end
		return nil
	end
	local box = c.stBox
	local inner = FULL - box.insetX - PAD
	local st = W.Stack(box, inner)
	st:Skip(16)
	local btnW = 108
	for i, row in ipairs(c.stRows) do
		local r = sp.rows[i]
		row.key = r and r.key or nil
		row.line:SetText(r and (r.title .. "  -  " .. (r.costText or "cost unknown")) or "")
		if r then
			local y0 = st.y
			st:Add(row.line, 4, box.insetX, inner - btnW - 6)
			row.btn:ClearAllPoints()
			row.btn:SetPoint("TOPRIGHT", box, "TOPRIGHT", -PAD, -(y0 - 2))
			row.btn:Show()
		else
			row.line:Hide()
			row.btn:Hide()
		end
	end
	local left = #sp.rows - #c.stRows
	c.stMore:SetText(left > 0 and string.format("+ %d more (included in the total)", left) or "")
	st:Add(c.stMore, 2)
	c.stTotal:SetText(sp.totalText)
	st:Add(c.stTotal, 0)
	return math.floor(st.y + PAD - 2 + 0.5)
end

--- PET TRAINING. Returns the card height, or nil when there is nothing to show (the card is then hidden entirely).
local function drawPets(c, pets)
	if not (pets and pets.rows and #pets.rows > 0) then return nil end
	local box = c.ptBox
	local inner = FULL - box.insetX - PAD
	local st = W.Stack(box, inner)
	st:Skip(16)
	for i, row in ipairs(c.ptRows) do
		local r = pets.rows[i]
		row.head:SetText(r and r.text or "")
		row.body:SetText(r and r.detail or "")
		st:Add(row.head, 1)
		st:Add(row.body, 4)
	end
	return math.floor(st.y + PAD - 2 + 0.5)
end

--- PROFESSIONS. Returns the card height, or nil when there is nothing to show (the card is then hidden entirely).
local function drawProfessions(c, pf)
	if not pf or #pf.rows == 0 then
		for _, row in ipairs(c.pfRows) do row.key = nil; row.btn:Hide() end
		return nil
	end
	local box = c.pfBox
	local inner = FULL - box.insetX - PAD
	local st = W.Stack(box, inner)
	st:Skip(16)
	for i, row in ipairs(c.pfRows) do
		local r = pf.rows[i]
		row.key = r and r.kind == "missing" and r.key or nil
		row.line:SetText(r and r.text or "")
		if r then
			local y0 = st.y
			W.SetColor(row.line, (r.kind == "rank") and W.WARM_GOLD or ((r.kind == "missing" or r.kind == "slots") and W.DIM or W.TEXT))
			st:Add(row.line, 3, box.insetX + (r.kind == "rank" and 10 or 0), inner - (r.kind == "missing" and 46 or 0))
			if r.kind == "missing" then
				row.btn:ClearAllPoints()
				row.btn:SetPoint("TOPRIGHT", box, "TOPRIGHT", -PAD, -(y0 - 2))
				row.btn:Show()
			else
				row.btn:Hide()
			end
		else
			row.line:Hide()
			row.btn:Hide()
		end
	end
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
	FULL = (UI.main.width or UI.COMPACT_WIDTH) - 16                    -- the page follows the window width (the player can resize it)
	c.header:SetWidth(FULL - 72)
	c.slots:ClearAllPoints()
	W.Place(c.slots, c.page, FULL - 70, -2, 70)
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

	-- QUEST DETAILS: directly under NOW while a quest is open (it belongs to the quest the player clicked, so it sits next to the guidance)
	local qdH = drawDetail(c, card, ctx)
	if qdH then
		c.qdBox:Show()
		placeCard(c, c.qdBox, bottom + GAP - 2, FULL, qdH)
		bottom = bottom + GAP - 2 + qdH
	else
		c.qdBox:Hide()
	end

	local tmH = drawTimers(c, card.timers or {})
	if tmH then
		c.tmBox:Show()
		placeCard(c, c.tmBox, bottom + GAP - 2, FULL, tmH)
		bottom = bottom + GAP - 2 + tmH
	else
		c.tmBox:Hide()
	end

	local qiH = drawQuestItems(c, card.questItems or {})
	if qiH then
		c.qiBox:Show()
		placeCard(c, c.qiBox, bottom + GAP - 2, FULL, qiH)
		bottom = bottom + GAP - 2 + qiH
	else
		c.qiBox:Hide()
	end

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

	local stH = drawSpells(c, card.spells)
	if stH then
		c.stBox:Show()
		placeCard(c, c.stBox, bottom + GAP - 2, FULL, stH)
		bottom = bottom + GAP - 2 + stH
	else
		c.stBox:Hide()
	end

	local ptH = drawPets(c, card.pets)
	if ptH then
		c.ptBox:Show()
		placeCard(c, c.ptBox, bottom + GAP - 2, FULL, ptH)
		bottom = bottom + GAP - 2 + ptH
	else
		c.ptBox:Hide()
	end

	local pfH = drawProfessions(c, card.professions)
	if pfH then
		c.pfBox:Show()
		placeCard(c, c.pfBox, bottom + GAP - 2, FULL, pfH)
		bottom = bottom + GAP - 2 + pfH
	else
		c.pfBox:Hide()
	end

	if nfy then
		c.nfyBox:Show()
		local h = drawNewForYou(c, nfy)
		placeCard(c, c.nfyBox, bottom + GAP - 2, FULL, h)
		bottom = bottom + GAP - 2 + h
	else
		c.nfyBox:Hide()
	end

	-- LAST of the cards (0.14.3): quests Quest Flow cannot place are the quietest list, and can be minimised
	local unH = drawUnplaced(c, card.unplaced)
	if unH then
		c.unBox:Show()
		placeCard(c, c.unBox, bottom + GAP - 2, FULL, unH)
		bottom = bottom + GAP - 2 + unH
	else
		c.unBox:Hide()
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
	if UI.FitSize then UI.FitSize(UI.main.width or UI.COMPACT_WIDTH, 36 + y + 8) end
end

UI.RegisterPage("codex", "Quest Flow", function(parent)
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
	msg:SetText("Welcome! Set up Quest Flow once, then this tracker tells you what to do next.")
	local go = W.Button(welcome, 120, 22, "Set up Quest Flow", function() UI.ShowPage("options") end)
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
			if UI.FitSize then UI.FitSize(UI.main.width or UI.COMPACT_WIDTH, 36 + 76) end
		end
	end
	return page
end)
