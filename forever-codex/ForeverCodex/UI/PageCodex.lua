-- UI page "Codex": what should I do right now, and what is worth doing while I'm here?
--   NOW        one obvious recommendation (plus plain-language "why", how far, and progress such as 4 / 6)
--   NEARBY     what else is worth doing around you (supporting information, visually quieter than NOW)
--   NEW FOR YOU  a temporary card for a level you just reached (secondary, never in front of NOW)
--   Party      what party members finished, only when there is something to say
-- Before the first-time setup is finished this page shows the setup panel instead (UI/PageSetup.lua).
--
-- This file only DRAWS. Every word comes from Presenter / Nearby / NewForYou / Party; nothing here reads the Planner or the data, and
-- the progress bar shows only counts the Presenter already reports. The look is a small card system (Widgets.lua: W.Card, W.Stack,
-- W.Progress, the W.STYLE_* tables): NOW is the strongest card (warm gold edge, larger title), NEARBY is cooler and smaller, NEW FOR YOU
-- is narrower and fits its content. A future panel (for example a dungeon recommendation) is a new style plus its own lines in the
-- same stack, with no new drawing code.

local addonName, ns = ...
local W = ns.Widgets
local UI = ns.UI

local FULL = UI.WIDTH - 16          -- page width
local LEFT_NARROW, RIGHT_W = 304, 192
local GAP, PAD = W.GAP, W.PAD
local TOP = 22                      -- below the character line
local ROW_GAP = 6
local NOW_MIN, NEAR_MIN = 88, 56    -- a card never gets smaller than this, so the page keeps its rhythm

--- Places a card at a vertical offset below the page top and sizes it.
local function placeCard(c, card, y, w, h)
	card:ClearAllPoints()
	card:SetPoint("TOPLEFT", c.page, "TOPLEFT", card.__x or 0, -y)
	card:SetSize(w, h)
end

local function build(page)
	local c = { page = page }
	UI.main.codex = c
	c.header = W.Line(page, 11, W.DIM, "LEFT")
	W.Place(c.header, page, 0, -2, FULL)

	-- NOW: the strongest card
	c.nowBox = W.Card(page, LEFT_NARROW, NOW_MIN, W.STYLE_NOW)
	c.nowIcon = UI.Icon(c.nowBox, "star")
	c.nowIcon:SetPoint("TOPLEFT", c.nowBox, "TOPLEFT", c.nowBox.insetX, -PAD)
	-- a way out of a recommendation that is wrong or unavailable: skips it (the same as /codex skip; /codex unskip brings it back)
	c.nowSkip = W.Button(c.nowBox, 40, 16, "Skip", function()
		local a = ns.State.SkipCurrent()
		if a then ns.Say("Skipped: " .. tostring(a.title) .. ". (/codex unskip brings skipped items back.)") end
	end)
	c.nowSkip:SetPoint("TOPRIGHT", c.nowBox, "TOPRIGHT", -PAD, -PAD + 1)
	c.nowLabel = W.Label(c.nowBox, "NOW", W.STYLE_NOW.label)
	c.nowLabel:SetPoint("TOPLEFT", c.nowBox, "TOPLEFT", c.nowBox.insetX + 20, -PAD - 1)
	c.nowTitle = W.Line(c.nowBox, 16, W.WARM_GOLD, "CENTER", true)
	c.nowWho = W.Line(c.nowBox, 12, W.TEXT, "CENTER")
	c.nowDetail = W.Line(c.nowBox, 11, W.TEXT, "CENTER", true)
	c.nowBar = W.Progress(c.nowBox, LEFT_NARROW - 2 * PAD, 12)
	c.nowInfo = W.Line(c.nowBox, 11, W.SOFT_GREEN, "CENTER")
	c.nowWhy = W.Line(c.nowBox, 10, W.DIM, "CENTER", true)
	c.nowDivider = W.Divider(c.nowBox)
	c.thenFS = W.Line(c.nowBox, 11, W.DIM, "CENTER")

	-- NEARBY: supporting information, cooler and smaller
	c.nearBox = W.Card(page, LEFT_NARROW, NEAR_MIN, W.STYLE_NEAR)
	c.nearLabel = W.Label(c.nearBox, "NEARBY", W.STYLE_NEAR.label)
	c.nearLabel:SetPoint("TOPLEFT", c.nearBox, "TOPLEFT", c.nearBox.insetX, -PAD)
	c.nearRows = {}
	for i = 1, 3 do
		c.nearRows[i] = { icon = UI.Icon(c.nearBox, "diamond"), title = W.Line(c.nearBox, 12, W.TEXT, "LEFT"), detail = W.Line(c.nearBox, 10, W.DIM, "LEFT") }
	end
	c.nearEmpty = W.Line(c.nearBox, 11, W.DIM, "CENTER")

	-- NEW FOR YOU: narrower, secondary, fits its content; present only while active
	c.nfyBox = W.Card(page, RIGHT_W, 80, W.STYLE_NEW)
	c.nfyBox.__x = LEFT_NARROW + GAP
	c.nfyLabel = W.Label(c.nfyBox, "NEW FOR YOU", W.STYLE_NEW.label)
	c.nfyLabel:SetPoint("TOPLEFT", c.nfyBox, "TOPLEFT", c.nfyBox.insetX, -c.nfyBox.insetY)
	c.nfyLabel:SetWidth(RIGHT_W - 2 * PAD)
	ns.Safe(c.nfyLabel.SetJustifyH, c.nfyLabel, "CENTER")
	c.nfyLevel = W.Line(c.nfyBox, 11, W.DIM, "CENTER")
	c.nfyRows = {}
	for i = 1, 3 do c.nfyRows[i] = W.Line(c.nfyBox, 11, W.TEXT, "LEFT", true) end

	c.reminderFS = W.Line(page, 10, W.DIM, "LEFT", true)
	c.partyHead = W.Line(page, 11, W.WARM_GOLD, "LEFT")
	c.partyRows = {}
	for i = 1, 2 do c.partyRows[i] = { head = W.Line(page, 11, W.TEXT, "LEFT") } end
	return page
end

--- "4 / 6" from the Presenter -> 4, 6. Anything else (nil, text, zero needed) gives nothing: the bar is never invented.
local function counts(progress)
	if type(progress) ~= "string" then return nil end
	local have, need = progress:match("^(%d+) / (%d+)$")
	have, need = tonumber(have), tonumber(need)
	if have and need and need > 0 then return have, need end
	return nil
end

local function drawNow(c, card, leftW)
	local box = c.nowBox
	local inner = leftW - box.insetX - PAD
	local st = W.Stack(box, inner)
	local n = card.now
	local barHave, barNeed
	if n then
		c.nowIcon:Set("star")
		c.nowIcon:Show()
		c.nowTitle:SetText(n.title or "")
		c.nowWho:SetText(n.who or "")
		c.nowDetail:SetText(n.detail or "")
		c.nowWhy:SetText(n.why or "")
		-- objective progress: a bar when the quest log really reported counts; otherwise exactly what was shown before
		barHave, barNeed = counts(n.progress)
		if barHave then
			c.nowInfo:SetText(n.where or "")
		else
			local info = {}
			if n.progress then info[#info + 1] = n.progress end
			if n.where then info[#info + 1] = n.where end
			c.nowInfo:SetText(table.concat(info, "   -   "))
		end
	else
		-- nothing to recommend: say so quietly, without the marker
		c.nowIcon:Set(nil)
		c.nowIcon:Hide()
		c.nowTitle:SetText(card.empty.title)
		c.nowWho:SetText(card.empty.lines[1] or "")
		c.nowDetail:SetText(card.empty.lines[2] or "")
		c.nowInfo:SetText("")
		c.nowWhy:SetText("")
	end
	W.SetColor(c.nowTitle, n and W.WARM_GOLD or W.DIM)
	if n then c.nowSkip:Show() else c.nowSkip:Hide() end
	c.thenFS:SetText(card.thenLine and ("Then: " .. card.thenLine) or "")
	st:Skip(18)                                       -- the NOW label row
	st:Add(c.nowTitle, 4)
	st:Add(c.nowWho, 3)
	st:Add(c.nowDetail, 6)
	if barHave then
		c.nowBar:Resize(inner)
		c.nowBar:Set(barHave, barNeed)
		c.nowBar:ClearAllPoints()
		c.nowBar:SetPoint("TOPLEFT", box, "TOPLEFT", box.insetX, -st.y)
		st:Skip(12 + 6)
	else
		c.nowBar:Clear()
	end
	st:Add(c.nowInfo, 3)
	st:Add(c.nowWhy, 4)
	if W.TextOf(c.thenFS) ~= "" then
		c.nowDivider:ClearAllPoints()
		c.nowDivider:SetPoint("TOPLEFT", box, "TOPLEFT", box.insetX, -(st.y + 2))
		c.nowDivider:SetPoint("TOPRIGHT", box, "TOPRIGHT", -PAD, -(st.y + 2))
		c.nowDivider:Show()
		st:Skip(9)
		st:Add(c.thenFS, 0)
	else
		c.nowDivider:Hide()
		c.thenFS:Hide()
	end
	return math.max(NOW_MIN, math.floor(st.y + PAD + 0.5))
end

local function drawNearby(c, near, leftW)
	local box = c.nearBox
	local inner = leftW - box.insetX - PAD
	local st = W.Stack(box, inner)
	st:Skip(16)                                       -- the NEARBY label row
	for i, row in ipairs(c.nearRows) do
		local it = near[i]
		if it then
			row.icon:Set(it.icon or "diamond"); row.icon:Show()
			row.title:SetText(it.title or "")
			row.detail:SetText(it.detail and (it.detail .. (it.where and ("  -  " .. it.where) or "")) or (it.where or ""))
			local y0 = st.y
			row.icon:ClearAllPoints()
			row.icon:SetPoint("TOPLEFT", box, "TOPLEFT", box.insetX, -y0)
			st:Add(row.title, 1, box.insetX + 20, inner - 20)
			st:Add(row.detail, ROW_GAP, box.insetX + 20, inner - 20)
		else
			row.icon:Hide()
			row.title:SetText("")
			row.detail:SetText("")
			row.title:Hide(); row.detail:Hide()
		end
	end
	c.nearEmpty:SetText(#near == 0 and "Nothing needed nearby right now." or "")
	st:Add(c.nearEmpty, 0)
	return math.max(NEAR_MIN, math.floor(st.y + PAD + 0.5))
end

local function drawNewForYou(c, nfy)
	local box = c.nfyBox
	local inner = RIGHT_W - 2 * PAD
	c.nfyLevel:SetText("Level " .. nfy.level)
	for i, fs in ipairs(c.nfyRows) do
		local it = nfy.items[i]
		fs:SetText(it and (it.title .. (it.detail and ("\n" .. it.detail) or "")) or "")
	end
	local st = W.Stack(box, inner)
	st:Skip(16)                                       -- the label row
	st:Add(c.nfyLevel, 6)
	for _, fs in ipairs(c.nfyRows) do st:Add(fs, 8) end
	return math.floor(st.y + PAD + 0.5)
end

local function refresh()
	local c = UI.main.codex
	local ctx, plan = ns.State.ctx, ns.State.plan
	if not ctx then return end
	c.header:SetText(ns.Presenter.Header(ctx))
	local nfy = ns.NewForYou.Active()
	UI.main.nfyShown = nfy ~= nil
	local leftW = nfy and LEFT_NARROW or FULL
	local card = ns.Presenter.Card(plan, ctx)
	local near = ns.Nearby.List(plan, ctx)

	local nowH = drawNow(c, card, leftW)
	placeCard(c, c.nowBox, TOP, leftW, nowH)
	local nearH = drawNearby(c, near, leftW)
	placeCard(c, c.nearBox, TOP + nowH + GAP, leftW, nearH)
	local bottom = TOP + nowH + GAP + nearH

	if nfy then
		c.nfyBox:Show()
		local h = drawNewForYou(c, nfy)
		placeCard(c, c.nfyBox, TOP, RIGHT_W, h)
		bottom = math.max(bottom, TOP + h)
	else
		c.nfyBox:Hide()
	end

	-- below the cards: quests Codex cannot place, then the party card
	local y = bottom + GAP
	if #card.reminders > 0 and card.now then
		c.reminderFS:SetText("In your log, not placed on the map: " .. table.concat(card.reminders, ", "))
		c.reminderFS:ClearAllPoints()
		c.reminderFS:SetPoint("TOPLEFT", c.page, "TOPLEFT", 0, -y)
		c.reminderFS:SetWidth(FULL)
		c.reminderFS:Show()
		y = y + W.TextHeight(c.reminderFS, FULL) + 6
	else
		c.reminderFS:SetText("")
		c.reminderFS:Hide()
	end
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
	if UI.FitHeight then UI.FitHeight(36 + y + 12) end
end

UI.RegisterPage("codex", "Codex", function(parent)
	local holder = CreateFrame("Frame", nil, parent)
	holder:SetSize(UI.WIDTH - 16, UI.HEIGHT - 44)
	holder:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
	local page = { frame = holder }
	UI.main.codexPage = holder
	build(holder)
	local setup = ns.UI.BuildSetup(parent, "setup")
	UI.main.setupPanel = setup
	function page.Refresh()
		if ns.Prefs.SetupDone() then
			setup.frame:Hide()
			holder:Show()
			refresh()
		else
			holder:Hide()
			if UI.FitHeight then UI.FitHeight(UI.HEIGHT) end
			setup.frame:Show()
			setup.Refresh()
		end
	end
	return page
end)
