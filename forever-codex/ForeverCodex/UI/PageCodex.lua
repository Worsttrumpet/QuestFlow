-- UI page "Codex": what should I do right now, and what is worth doing while I'm here?
--   NOW        one obvious recommendation (plus plain-language "why", how far, and progress such as 4 / 6)
--   ALSO DO    at most one (exactly the Planner's alsoDo); the box is hidden when there is none
--   Then:      one small line, omitted when it says little
--   Party      what party members finished, only when there is something to say
-- Before the first-time setup is finished this page shows the setup panel instead (UI/PageSetup.lua).

local addonName, ns = ...
local W = ns.Widgets
local UI = ns.UI

local FULL = UI.WIDTH - 16          -- page width
local LEFT_NARROW, RIGHT_W, GAP = 304, 192, 8
local NOW_H, NEAR_H = 156, 168

local function card(parent, x, y, w, h)
	local f = CreateFrame("Frame", nil, parent)
	f:SetSize(w, h)
	f:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
	f.bg = f:CreateTexture(nil, "BACKGROUND")
	f.bg:SetAllPoints()
	f.bg:SetColorTexture(0.12, 0.12, 0.12, 0.7)
	return f
end

--- A text line inside a card: centred (the decision is the focus) unless left = true.
local function line(parent, y, color, wrap, left)
	local fs = W.Text(parent, color)
	W.Place(fs, parent, 6, y, 100)
	ns.Safe(fs.SetJustifyH, fs, left and "LEFT" or "CENTER")
	if wrap then ns.Safe(fs.SetWordWrap, fs, true) end
	return fs
end

local function fit(fs, w) fs:SetWidth(w - 12) end

local function build(page)
	local c = {}
	UI.main.codex = c
	c.header = W.Text(page, W.GREY)
	W.Place(c.header, page, 0, -2, FULL)

	-- NOW (left column, top)
	c.nowBox = card(page, 0, -22, LEFT_NARROW, NOW_H)
	c.nowIcon = UI.Icon(c.nowBox, "star")
	c.nowIcon:SetPoint("TOPLEFT", c.nowBox, "TOPLEFT", 6, -6)
	c.nowLabel = W.Text(c.nowBox, W.GREY)
	W.Place(c.nowLabel, c.nowBox, 26, -7, 60)
	c.nowLabel:SetText("NOW")
	c.nowTitle = line(c.nowBox, -26, W.GOLD, true)
	c.nowWho = line(c.nowBox, -62, W.WHITE)
	c.nowDetail = line(c.nowBox, -78, W.WHITE, true)
	c.nowInfo = line(c.nowBox, -112, W.GREEN)
	c.nowWhy = line(c.nowBox, -128, W.GREY)
	c.thenFS = line(c.nowBox, -142, W.WHITE)

	-- NEARBY (left column, under NOW)
	c.nearBox = card(page, 0, -22 - NOW_H - GAP, LEFT_NARROW, NEAR_H)
	c.nearLabel = W.Text(c.nearBox, W.GREY)
	W.Place(c.nearLabel, c.nearBox, 8, -7, 100)
	c.nearLabel:SetText("NEARBY")
	c.nearRows = {}
	for i = 1, 3 do
		local base = -26 - (i - 1) * 46
		c.nearRows[i] = { icon = UI.Icon(c.nearBox, "diamond"), title = line(c.nearBox, base, W.GOLD, false, true), detail = line(c.nearBox, base - 16, W.WHITE, false, true) }
		c.nearRows[i].icon:SetPoint("TOPLEFT", c.nearBox, "TOPLEFT", 6, base)
		W.Place(c.nearRows[i].title, c.nearBox, 26, base, LEFT_NARROW - 34)
		W.Place(c.nearRows[i].detail, c.nearBox, 26, base - 16, LEFT_NARROW - 34)
	end
	c.nearEmpty = line(c.nearBox, -70, W.GREY)

	-- NEW FOR YOU (right column, spans NOW + NEARBY)
	c.nfyBox = card(page, LEFT_NARROW + GAP, -22, RIGHT_W, NOW_H + GAP + NEAR_H)
	c.nfyBox.bg:SetColorTexture(0.2, 0.17, 0.05, 0.75)
	c.nfyLabel = W.Text(c.nfyBox, W.GOLD)
	W.Place(c.nfyLabel, c.nfyBox, 8, -7, RIGHT_W - 16)
	ns.Safe(c.nfyLabel.SetJustifyH, c.nfyLabel, "CENTER")
	c.nfyLabel:SetText("NEW FOR YOU")
	c.nfyLevel = line(c.nfyBox, -26, W.GREY)
	fit(c.nfyLevel, RIGHT_W)
	c.nfyRows = {}
	for i = 1, 3 do
		c.nfyRows[i] = line(c.nfyBox, -52 - (i - 1) * 52, W.WHITE, true)
		fit(c.nfyRows[i], RIGHT_W)
	end

	c.reminderFS = W.Text(page, W.GREY)
	W.Place(c.reminderFS, page, 0, -22 - NOW_H - NEAR_H - GAP - 8, FULL)
	c.partyHead = W.Text(page, W.GOLD)
	W.Place(c.partyHead, page, 0, -22 - NOW_H - NEAR_H - GAP - 26, FULL)
	c.partyRows = {}
	for i = 1, 2 do
		c.partyRows[i] = { head = W.Text(page, W.WHITE) }
		W.Place(c.partyRows[i].head, page, 0, -22 - NOW_H - NEAR_H - GAP - 42 - (i - 1) * 16, FULL)
	end
	return page
end

local function refresh()
	local c = UI.main.codex
	local ctx, plan = ns.State.ctx, ns.State.plan
	if not ctx then return end
	c.header:SetText(ns.Presenter.Header(ctx))
	local nfy = ns.NewForYou.Active()
	UI.main.nfyShown = nfy ~= nil
	local leftW = nfy and LEFT_NARROW or FULL
	for _, f in ipairs({ c.nowBox, c.nearBox }) do f:SetWidth(leftW) end
	for _, fs in ipairs({ c.nowTitle, c.nowWho, c.nowDetail, c.nowInfo, c.nowWhy, c.thenFS }) do fit(fs, leftW) end
	local card = ns.Presenter.Card(plan, ctx)
	if card.now then
		c.nowIcon:Set("star")
		c.nowTitle:SetText(card.now.title or "")
		c.nowWho:SetText(card.now.who or "")
		c.nowDetail:SetText(card.now.detail or "")
		local info = {}
		if card.now.progress then info[#info + 1] = card.now.progress end
		if card.now.where then info[#info + 1] = card.now.where end
		c.nowInfo:SetText(table.concat(info, "   -   "))
		c.nowWhy:SetText(card.now.why or "")
	else
		c.nowIcon:Set(nil)
		c.nowTitle:SetText(card.empty.title)
		c.nowWho:SetText(card.empty.lines[1] or "")
		c.nowDetail:SetText(card.empty.lines[2] or "")
		c.nowInfo:SetText("")
		c.nowWhy:SetText("")
	end
	c.thenFS:SetText(card.thenLine and ("Then: " .. card.thenLine) or "")
	-- NEARBY: only what is useful and trustworthy; the card says so plainly when there is nothing
	local near = ns.Nearby.List(plan, ctx)
	for i, row in ipairs(c.nearRows) do
		local it = near[i]
		if it then
			row.icon:Set(it.icon or "diamond"); row.icon.__shown = true; row.icon:Show()
			row.title:SetText(it.title or "")
			row.detail:SetText(it.detail and (it.detail .. (it.where and ("  -  " .. it.where) or "")) or (it.where or ""))
		else
			row.icon:Hide()
			row.title:SetText("")
			row.detail:SetText("")
		end
	end
	c.nearEmpty:SetText(#near == 0 and "Nothing needed nearby right now." or "")
	fit(c.nearEmpty, leftW)
	-- NEW FOR YOU: present only while it is active
	if nfy then
		c.nfyBox:Show()
		c.nfyLevel:SetText("Level " .. nfy.level)
		for i, fs in ipairs(c.nfyRows) do
			local it = nfy.items[i]
			fs:SetText(it and (it.title .. (it.detail and ("\n" .. it.detail) or "")) or "")
		end
	else
		c.nfyBox:Hide()
	end
	if #card.reminders > 0 and card.now then
		c.reminderFS:SetText("In your log, not placed on the map: " .. table.concat(card.reminders, ", "))
	else
		c.reminderFS:SetText("")
	end
	local pv = ns.Party.View(ctx)
	if #pv.lines > 0 then
		c.partyHead:SetText("Party")
		for i, row in ipairs(c.partyRows) do
			local e = pv.lines[i]
			row.head:SetText(e and (e.head .. "  -  " .. e.mine) or "")
		end
	else
		c.partyHead:SetText("")
		for _, row in ipairs(c.partyRows) do row.head:SetText("") end
	end
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
			setup.frame:Show()
			setup.Refresh()
		end
	end
	return page
end)
