-- quest_detail_tests.lua (0.8.3): the clickable quest-details fallback. A quest in the player's log that Codex cannot place on the map is never lost: it is listed under IN YOUR LOG, NOT ON THE MAP
-- and opens a small QUEST DETAILS card (QuestDetail.lua). Quests Codex CAN route keep their normal guided behaviour. Stub-client tests of Codex's own logic: they do not prove how the card looks
-- or feels in the real client, and the game's own quest-UI functions are never called.

local H = ...
local check, section, boot = H.check, H.section, H.boot

local function Q(id, name, dx, dy, o)
	local q = { id = id, name = name, map = 9001, x = 0.5 + dx / 1000, y = 0.5 + (dy or 0) / 1000 }
	for k, v in pairs(o or {}) do q[k] = v end
	return q
end

--- A world: quests in the synthetic ATT pack, a quest log { [id] = { title, complete, header, objectives = { { text, have, need } } } }.
local function world(quests, log)
	local ns = boot({ char = { level = 10 }, synthetic = true, loc = { map = 9001, x = 0.5, y = 0.5, zone = "Fixture Valley" } })
	H.attPack(ns, quests, nil)
	local W = H.world()
	W.log, W.objectives = {}, {}
	local function setLog(l)
		W.log, W.objectives = {}, {}
		local ids = {}
		for id in pairs(l) do ids[#ids + 1] = id end
		table.sort(ids)
		for _, id in ipairs(ids) do
			local e = l[id]
			W.log[#W.log + 1] = { questID = id, title = e.title or ("quest " .. id), complete = e.complete == true }
			if e.objectives then
				W.objectives[id] = {}
				for i, ob in ipairs(e.objectives) do
					W.objectives[id][i] = { text = ob.text, type = "item", finished = (ob.have or 0) >= (ob.need or 1), numFulfilled = ob.have or 0, numRequired = ob.need or 1 }
				end
			end
		end
	end
	setLog(log or {})
	ns.Prefs.FinishSetup()
	ns.State.Recompute()
	return ns, W, setLog
end
local function card(ns) return ns.Presenter.Card(ns.State.plan, ns.State.ctx) end

section("quest detail: the pure description (a quest-log snapshot in, plain data out; no client call)")
do
	local ns = boot({ char = { level = 10 }, synthetic = true })
	local QD = ns.QuestDetail
	local ctx = { log = {
		[1] = { id = 1, title = "Kodo Hide Bag", complete = false, header = "Thunder Bluff", objectives = { { text = "Kodo Hide: 1/4", numFulfilled = 1, numRequired = 4, finished = false }, { text = "Rope: 2/2", numFulfilled = 2, numRequired = 2, finished = true } } },
		[2] = { id = 2, title = "Done Deal", complete = true, objectives = {} },
		[3] = { id = 3, title = "Loading", complete = false, objectives = { { text = "", numFulfilled = 0, numRequired = 1, finished = false } } },
	}, questTag = function(id) if id == 1 then return { id = 1, name = "Elite" } end end }
	local d = QD.Describe(1, ctx, {})
	check(d.title == "Kodo Hide Bag" and d.header == "Thunder Bluff", "title and the quest log section heading")
	check(d.state == "IN_PROGRESS" and d.status == "In progress: 1 objective left", "status counts the unfinished objectives  [" .. tostring(d.status) .. "]")
	check(#d.objectives == 2 and d.objectives[1].have == 1 and d.objectives[1].need == 4 and d.objectives[2].finished == true, "every objective with its current counts")
	check(d.tag == "Elite", "the game's own quest tag when there is one")
	check(d.giver == nil and d.turnIn == nil and d.note == nil, "no QuestieDB line and no note unless asked for")
	local r = QD.Describe(2, ctx, {})
	check(r.state == "READY" and r.status == "Ready to turn in" and #r.objectives == 0 and r.tag == nil, "a finished quest says it is ready to turn in")
	check(QD.Describe(3, ctx, {}).objectives[1].loading == true and QD.ObjectiveLine(QD.Describe(3, ctx, {}).objectives[1]) == "Objective still loading", "a blank objective is shown as still loading, never invented")
	check(QD.Describe(99, ctx, {}) == nil, "a quest that is not in the log has no details")
	local n = QD.Describe(1, ctx, { unplaced = true, names = { giver = "Rahauro", turnIn = "Rahauro" } })
	check(n.note == "Quest Flow has no usable map position for this quest, so there is no arrow.", "the no-arrow explanation when the quest has no position")
	check(n.giver == "Quest giver: Rahauro (QuestieDB, unverified)" and n.turnIn == "Turn-in: Rahauro (QuestieDB, unverified)", "QuestieDB names are labelled unverified  [" .. tostring(n.giver) .. "]")
	local g = QD.Describe(1, ctx, { names = { turnIn = "Thrall" } })
	check(g.giver == nil and g.turnIn == "Turn-in: Thrall (QuestieDB, unverified)", "a name QuestieDB lacks is omitted, not invented")
	for _, v in pairs(n) do
		if type(v) == "string" then check(not v:find("%d%.%d"), "no coordinates in the description") end
	end
	local api = table.concat(QD.ApiLines(), "\n")
	for _, name in ipairs({ "QuestMapFrame_OpenToQuestDetails", "QuestLogPopupDetailFrame_Show", "ToggleQuestLog", "OpenQuestLog", "C_QuestLog.SetSelectedQuest" }) do
		check(api:find(name, 1, true) ~= nil, "the report names " .. name)
	end
	check(api:find("UNPROVEN", 1, true) ~= nil and not api:find("PROVEN on Forever", 1, true), "every quest-UI function is reported UNPROVEN: existing is not working")
	check(#ns.errors == 0, "no errors")
end

section("quest detail: QuestieDB names come from the bridge as names only")
do
	local ns = boot({ char = { level = 10 }, synthetic = true })
	check(ns.QuestieBridge.Names(12345) == nil, "no QuestieDB installed: no names")
	local src = H.readFile(H.addonDir .. "/QuestDetail.lua")
	check(not src:find("QuestieBridge", 1, true) and not src:find("CreateFrame", 1, true), "the description module reads no data source and builds no frame")
end

section("quest detail: IN YOUR LOG, NOT ON THE MAP lists every quest Quest Flow cannot place, and nothing else")
do
	local log = {
		[10] = { title = "Unplaced A", objectives = { { text = "Boars", have = 0, need = 5 } } },
		[11] = { title = "Unplaced B", complete = true },
		[12] = { title = "Located", objectives = { { text = "Wolves", have = 1, need = 5 } } },
	}
	local ns = world({ Q(12, "Located", 100, 0, { objCoords = { { map = 9001, x = 0.6, y = 0.5 } } }) }, log)
	local c = card(ns)
	check(c.unplaced ~= nil and #c.unplaced.rows == 1, "the unfinished quest no pack knows is listed  [" .. tostring(c.unplaced and #c.unplaced.rows) .. "]")
	check(c.unplaced.rows[1].quest == 10 and c.unplaced.rows[1].state == "1 objective left", "with what is left")
	check(c.unplaced.ids[11] == nil, "a finished quest is not repeated: READY TO TURN IN already carries it (as a click area, below)")
	local ready11
	for _, r in ipairs(c.ready) do if r.quest == 11 then ready11 = r end end
	check(ready11 ~= nil and ready11.placed == false, "(setup) it is a READY row with no position")
	check(c.unplaced.ids[12] == nil, "a quest Quest Flow can route is not in the list")
	check(ns.State.plan.now ~= nil and ns.State.plan.now.quest == 12, "(setup) the located quest is NOW as before")

	-- cap: the list is short and says how many more
	local many = {}
	for i = 1, 8 do many[100 + i] = { title = "Lost " .. i, objectives = { { text = "x", have = 0, need = 1 } } } end
	local ns2 = world({}, many)
	local c2 = card(ns2)
	-- (one of the eight is the guidance quest under NOW, so it is not repeated here)
	local gq = c2.now and c2.now.quest
	check(gq ~= nil and c2.now.guidance == true, "(setup) one lost quest is the guidance quest under NOW")
	check(#c2.unplaced.rows == ns2.Presenter.UNPLACED_ROWS and c2.unplaced.more == 7 - ns2.Presenter.UNPLACED_ROWS, "at most five rows and a count of the rest  [" .. #c2.unplaced.rows .. " + " .. c2.unplaced.more .. "]")
	for i = 101, 108 do check(c2.unplaced.ids[i] == true or i == gq, "every quest is still reachable: " .. i) end

	-- nothing to list: the card is absent
	local ns3 = world({ Q(12, "Located", 100, 0, { objCoords = { { map = 9001, x = 0.6, y = 0.5 } } }) }, { [12] = log[12] })
	check(card(ns3).unplaced == nil, "no card when every quest has a place")
	check(#ns.errors == 0 and #ns2.errors == 0 and #ns3.errors == 0, "no errors")
end

section("quest detail: the planner is untouched by the card")
do
	local log = { [10] = { title = "Unplaced A", objectives = { { text = "Boars", have = 0, need = 5 } } }, [12] = { title = "Located", objectives = { { text = "Wolves", have = 1, need = 5 } } } }
	local ns = world({ Q(12, "Located", 100, 0, { objCoords = { { map = 9001, x = 0.6, y = 0.5 } } }) }, log)
	local before = { ns.State.plan.now and ns.State.plan.now.id, #ns.State.plan.sequence, #ns.State.plan.reminders }
	card(ns); ns.UI.Open("codex"); ns.UI.ToggleQuestDetail(10)
	ns.State.Recompute()
	local after = { ns.State.plan.now and ns.State.plan.now.id, #ns.State.plan.sequence, #ns.State.plan.reminders }
	check(before[1] == after[1] and before[2] == after[2] and before[3] == after[3], "NOW, the sequence and the reminders are identical with the details card open")
	check(ns.Navigation.Target() ~= nil, "the arrow still follows the planner's own target")
end

section("quest detail: clicking a row opens, collapses and follows the quest log live")
do
	local log = {
		[10] = { title = "Unplaced A", objectives = { { text = "Boars", have = 0, need = 5 } } },
		[11] = { title = "Unplaced B", objectives = { { text = "Wolves", have = 1, need = 4 } } },
		[12] = { title = "Located", objectives = { { text = "Bears", have = 1, need = 5 } } },
	}
	local ns, W, setLog = world({ Q(12, "Located", 100, 0, { objCoords = { { map = 9001, x = 0.6, y = 0.5 } } }) }, log)
	local UI = ns.UI
	UI.Open("codex")
	local c = UI.main.codex
	check(c.unBox.__shown ~= false and c.qdBox.__shown == false, "the NOT ON THE MAP card shows; QUEST DETAILS is closed")
	check(c.unHits[1] and c.unHits[1].action == 10 and c.unHits[1].__shown ~= false, "rows are click areas (hover highlight is the Row's own)")
	check(c.unArrows[1].__text == "[+]", "a small expand indicator  [" .. tostring(c.unArrows[1].__text) .. "]")

	c.unHits[1].__scripts.OnClick(c.unHits[1])
	check(UI.main.detailQuest == 10 and c.qdBox.__shown ~= false, "clicking opens QUEST DETAILS")
	check(c.qdTitle.__text == "Unplaced A" and c.qdStatus.__text == "In progress: 1 objective left", "title and status  [" .. tostring(c.qdTitle.__text) .. " / " .. tostring(c.qdStatus.__text) .. "]")
	check(c.qdRows[1].cur and c.qdRows[1].cur[1] == "Boars" and c.qdRows[1].cur[2] == 0 and c.qdRows[1].cur[3] == 5, "every objective with its counts")
	check(c.qdNote.__text == "Quest Flow has no usable map position for this quest, so there is no arrow.", "and the no-arrow explanation")
	check(c.unArrows[1].__text == "[-]", "the indicator shows it is open")

	-- live: objective progress
	setLog({ [10] = { title = "Unplaced A", objectives = { { text = "Boars", have = 3, need = 5 } } }, [11] = log[11], [12] = log[12] })
	ns.State.Recompute()
	check(c.qdRows[1].cur[2] == 3, "objective progress updates the open card")

	-- live: the quest becomes ready
	setLog({ [10] = { title = "Unplaced A", complete = true, objectives = { { text = "Boars", have = 5, need = 5 } } }, [11] = log[11], [12] = log[12] })
	ns.State.Recompute()
	check(UI.main.detailQuest == 10 and c.qdStatus.__text == "Ready to turn in", "becoming ready updates the status  [" .. tostring(c.qdStatus.__text) .. "]")

	-- clicking another quest switches; the same quest again collapses
	local hit11
	for _, h in ipairs(c.unHits) do if h.action == 11 and h.__shown ~= false then hit11 = h end end
	check(hit11 ~= nil, "(setup) the other quest has a click area")
	hit11.__scripts.OnClick(hit11)
	check(UI.main.detailQuest == 11 and c.qdTitle.__text == "Unplaced B", "clicking another quest shows that one")
	hit11.__scripts.OnClick(hit11)
	check(UI.main.detailQuest == nil and c.qdBox.__shown == false, "clicking the same quest again collapses the card")

	-- the Close button
	hit11.__scripts.OnClick(hit11)
	c.qdClose.__scripts.OnClick(c.qdClose)
	check(UI.main.detailQuest == nil and c.qdBox.__shown == false, "the Close button closes it")

	-- live: the quest leaves the log
	setLog(log)
	ns.State.Recompute()
	local hit10
	for _, h in ipairs(c.unHits) do if h.action == 10 and h.__shown ~= false then hit10 = h end end
	hit10.__scripts.OnClick(hit10)
	check(UI.main.detailQuest == 10, "(setup) open again")
	setLog({ [11] = log[11], [12] = log[12] })
	ns.State.Recompute()
	check(UI.main.detailQuest == nil and c.qdBox.__shown == false, "a quest that leaves the log closes its card")

	-- live: a quest leaves the NOT ON THE MAP list
	setLog({ [12] = log[12] })
	ns.State.Recompute()
	check(card(ns).unplaced == nil and c.unBox.__shown == false, "when no quest is left the NOT ON THE MAP card goes away")
	setLog({ [11] = log[11], [12] = log[12], [13] = { title = "Brand New", objectives = { { text = "Owls", have = 0, need = 2 } } } })
	ns.State.Recompute()
	check(#card(ns).unplaced.rows == 2 and c.unBox.__shown ~= false, "and a quest entering the log appears in it")
	check(#ns.errors == 0, "no errors")
end

section("quest detail: nothing about the open card is saved")
do
	local ns = world({ Q(12, "Located", 100, 0, { objCoords = { { map = 9001, x = 0.6, y = 0.5 } } }) }, { [10] = { title = "Unplaced A", objectives = { { text = "Boars", have = 0, need = 5 } } }, [12] = { title = "Located", objectives = { { text = "Bears", have = 1, need = 5 } } } })
	ns.UI.Open("codex")
	local c = ns.UI.main.codex
	local function dump(t, seen, out)
		for k, v in pairs(t) do
			out[#out + 1] = tostring(k)
			if type(v) == "table" and not seen[v] then seen[v] = true; dump(v, seen, out) end
		end
		return out
	end
	local before = #dump(ForeverCodexDB or {}, {}, {})
	c.unHits[1].__scripts.OnClick(c.unHits[1])
	check(ns.UI.main.detailQuest == 10, "(setup) the card is open")
	local keys = table.concat(dump(ForeverCodexDB or {}, {}, {}), "|")
	check(#dump(ForeverCodexDB or {}, {}, {}) == before and not keys:find("detail", 1, true), "the saved data did not change: the selection is session-only")
	local src = H.readFile(H.addonDir .. "/UI/PageCodex.lua")
	local touched = false
	for line in src:gmatch("[^\n]+") do if line:find("detailQuest", 1, true) and (line:find("Prefs", 1, true) or line:find("SavedData", 1, true)) then touched = true end end
	check(not touched, "the page never hands the selection to Preferences or SavedData")
end

section("quest detail: guidance NOW title and READY rows without a position are clickable; routed quests are not")
do
	-- guidance: the only quest is one Codex cannot place
	local ns = world({}, { [900] = { title = "The Earthen Ring", objectives = { { text = "Take the Skycutter to Mulgore", have = 0, need = 1 } } } })
	ns.UI.Open("codex")
	local c = ns.UI.main.codex
	local cd = card(ns)
	check(cd.guidance == true and cd.now.unplaced == true and cd.unplaced == nil, "the guidance quest is not repeated in the NOT ON THE MAP card")
	check(c.nowHits[1] and c.nowHits[1].action == 900 and c.nowHits[1].__shown ~= false, "the guidance quest title is a click area")
	check(c.nowHint.__text:find("details", 1, true) ~= nil, "with a short hint")
	c.nowHits[1].__scripts.OnClick(c.nowHits[1])
	check(ns.UI.main.detailQuest == 900 and c.qdBox.__shown ~= false and c.qdNote.__text:find("no arrow", 1, true) ~= nil, "it opens the details, with the no-arrow note")
	c.nowHits[1].__scripts.OnClick(c.nowHits[1])
	check(ns.UI.main.detailQuest == nil, "and collapses")

	-- a located quest: guided as before; since 0.14.3 its title is also a click area (opens the details; no change to the route)
	local ns2 = world({ Q(1, "Near Quest", 100, 0, { objCoords = { { map = 9001, x = 0.6, y = 0.5 } } }) }, { [1] = { title = "Near Quest", objectives = { { text = "Boars", have = 1, need = 5 } } } })
	ns2.UI.Open("codex")
	local c2 = ns2.UI.main.codex
	check(ns2.State.plan.now ~= nil and c2.nowHits[1] and c2.nowHits[1].__shown ~= false, "a quest the planner routes: its title opens the details (0.14.3)")
	c2.nowHits[1].__scripts.OnClick(c2.nowHits[1])
	check(ns2.UI.main.detailQuest == 1 and ns2.State.plan.now ~= nil and ns2.State.plan.now.quest == 1, "opening the details leaves the route untouched")

	-- READY rows: one with a position and one without
	local ns3 = world({
		Q(1, "Near Quest", 100, 0, { objCoords = { { map = 9001, x = 0.6, y = 0.5 } } }),
		Q(2, "Near Hand-in", 200, 0, { giverName = "Hanna" }),
		{ id = 3, name = "Lost Hand-in", giverName = "Gornek" },
	}, {
		[1] = { title = "Near Quest", objectives = { { text = "Boars", have = 1, need = 5 } } },
		[2] = { title = "Near Hand-in", complete = true },
		[3] = { title = "Lost Hand-in", complete = true },
	})
	ns3.UI.Open("codex")
	local c3 = ns3.UI.main.codex
	local rows = card(ns3).ready
	local placedOf = {}
	for _, r in ipairs(rows) do placedOf[r.quest] = r.placed end
	check(placedOf[2] == true and placedOf[3] == false, "(setup) READY rows know whether Quest Flow has a position  [" .. tostring(placedOf[2]) .. "/" .. tostring(placedOf[3]) .. "]")
	local clickable = {}
	for _, h in pairs(c3.readyHits) do if h.__shown ~= false then clickable[#clickable + 1] = h.action end end
	check(#clickable == 1 and clickable[1] == 3, "only the READY row with no position is a click area  [" .. table.concat(clickable, ",") .. "]")
	local h = c3.readyHits[1] and c3.readyHits[1].__shown ~= false and c3.readyHits[1] or c3.readyHits[2]
	h.__scripts.OnClick(h)
	check(ns3.UI.main.detailQuest == 3 and c3.qdStatus.__text == "Ready to turn in", "it opens the details for the finished quest")
	check(#ns.errors == 0 and #ns2.errors == 0 and #ns3.errors == 0, "no errors")
end

section("quest detail: the report names the quest-UI functions as UNPROVEN and Quest Flow never calls them")
do
	local called = {}
	local ns = boot({ char = { level = 10 }, synthetic = true })
	for _, name in ipairs({ "QuestMapFrame_OpenToQuestDetails", "QuestLogPopupDetailFrame_Show", "ToggleQuestLog", "OpenQuestLog" }) do
		_G[name] = function() called[#called + 1] = name end
	end
	ns.Prefs.FinishSetup()
	ns.State.Recompute()
	ns.UI.Open("codex")
	local _, lines = ns.Diag.Report()
	local report = table.concat(lines or {}, "\n")
	check(report:find("QuestMapFrame_OpenToQuestDetails: present, UNPROVEN (never called)", 1, true) ~= nil, "the report says the opener exists and is UNPROVEN")
	check(#called == 0, "no quest-UI function was called while building the report and the tracker")
	for _, name in ipairs({ "QuestMapFrame_OpenToQuestDetails", "QuestLogPopupDetailFrame_Show", "ToggleQuestLog", "OpenQuestLog" }) do _G[name] = nil end
end
