-- UI page "Codex": what should I do right now, and what is worth doing while I'm here?
--   NOW        one obvious recommendation (plus plain-language "why", how far, and progress such as 4 / 6)
--   ALSO DO    at most one (exactly the Planner's alsoDo); the box is hidden when there is none
--   Then:      one small line, omitted when it says little
--   Party      what party members finished, only when there is something to say
-- Before the first-time setup is finished this page shows the setup panel instead (UI/PageSetup.lua).

local addonName, ns = ...
local W = ns.Widgets
local UI = ns.UI

local WIDTH = UI.WIDTH - 24

local function line(parent, y, color, wrap)
	local fs = W.Text(parent, color)
	W.Place(fs, parent, 0, y, WIDTH)
	if wrap then ns.Safe(fs.SetWordWrap, fs, true) end
	return fs
end

local function build(page)
	local c = {}
	UI.main.codex = c
	c.header = line(page, -2, W.GREY)

	c.nowBox = CreateFrame("Frame", nil, page)
	c.nowBox:SetSize(WIDTH, 120)
	c.nowBox:SetPoint("TOPLEFT", page, "TOPLEFT", 0, -22)
	c.nowIcon = UI.Icon(c.nowBox, "star")
	c.nowIcon:SetPoint("TOPLEFT", c.nowBox, "TOPLEFT", 0, -2)
	c.nowLabel = W.Text(c.nowBox, W.GREY)
	W.Place(c.nowLabel, c.nowBox, 20, 0, 100)
	c.nowLabel:SetText("NOW")
	c.nowTitle = line(c.nowBox, -18, W.GOLD)
	c.nowWho = line(c.nowBox, -36, W.WHITE)
	c.nowDetail = line(c.nowBox, -54, W.WHITE, true)
	c.nowProgress = line(c.nowBox, -86, W.GREEN)
	c.nowWhere = W.Text(c.nowBox, W.GREY)
	W.Place(c.nowWhere, c.nowBox, 220, -86, 160)
	c.nowWhy = line(c.nowBox, -102, W.GREEN)

	c.alsoBox = CreateFrame("Frame", nil, page)
	c.alsoBox:SetSize(WIDTH, 80)
	c.alsoBox:SetPoint("TOPLEFT", page, "TOPLEFT", 0, -150)
	c.alsoIcon = UI.Icon(c.alsoBox, "diamond")
	c.alsoIcon:SetPoint("TOPLEFT", c.alsoBox, "TOPLEFT", 0, -2)
	c.alsoLabel = W.Text(c.alsoBox, W.GREY)
	W.Place(c.alsoLabel, c.alsoBox, 20, 0, 140)
	c.alsoLabel:SetText("ALSO WHILE YOU ARE HERE")
	c.alsoTitle = line(c.alsoBox, -18, W.GOLD)
	c.alsoWho = line(c.alsoBox, -36, W.WHITE)
	c.alsoDetail = line(c.alsoBox, -54, W.WHITE, true)

	c.thenFS = line(page, -236, W.WHITE)
	c.reminderFS = line(page, -256, W.GREY)

	c.partyHead = line(page, -280, W.GOLD)
	c.partyRows = {}
	for i = 1, 2 do
		c.partyRows[i] = { head = line(page, -296 - (i - 1) * 16, W.WHITE), mine = nil }
	end
	return page
end

local function setItem(prefix, c, it)
	local function put(fs, text) fs:SetText(text or "") end
	put(c[prefix .. "Title"], it and it.title)
	put(c[prefix .. "Who"], it and it.who)
	put(c[prefix .. "Detail"], it and it.detail)
end

local function refresh()
	local c = UI.main.codex
	local ctx, plan = ns.State.ctx, ns.State.plan
	if not ctx then return end
	c.header:SetText(ns.Presenter.Header(ctx))
	local card = ns.Presenter.Card(plan, ctx)
	if card.now then
		c.nowIcon:Set("star")
		setItem("now", c, card.now)
		c.nowProgress:SetText(card.now.progress and ("Progress  " .. card.now.progress) or "")
		c.nowWhere:SetText(card.now.where or "")
		c.nowWhy:SetText(card.now.why or "")
	else
		c.nowIcon:Set(nil)
		c.nowTitle:SetText(card.empty.title)
		c.nowWho:SetText(card.empty.lines[1] or "")
		c.nowDetail:SetText(card.empty.lines[2] or "")
		c.nowProgress:SetText("")
		c.nowWhere:SetText("")
		c.nowWhy:SetText("")
	end
	if card.alsoDo then
		c.alsoIcon:Set(card.alsoDo.icon)
		setItem("also", c, card.alsoDo)
		c.alsoBox:Show()
	else
		setItem("also", c, nil)
		c.alsoBox:Hide()
	end
	c.thenFS:SetText(card.thenLine and ("Then: " .. card.thenLine) or "")
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
	holder:SetSize(UI.WIDTH - 16, UI.HEIGHT - 40)
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
