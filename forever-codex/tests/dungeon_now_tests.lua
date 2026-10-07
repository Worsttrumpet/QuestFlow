-- dungeon_now_tests.lua (0.8.6): a dungeon-tagged OBJECTIVE is not NOW while the player is outside that dungeon (the 0.8.5 playtest: NOW "Finish Serpentbloom (Dungeon)", Wailing Caverns, ~3150 yd, from Durotar).
-- It stays a known candidate (the DUNGEON QUESTS card, the report, an on-the-way extra); inside its dungeon it is ordinary; open-world quests are unchanged. The tag is the game's own (Dungeons.IsDungeon);
-- the instance state is the client's own (Context.instance). Stub-client tests of Codex's own logic.

local H = ...
local check, section, boot = H.check, H.section, H.boot

local function setInstance(inside, name)
	_G.IsInInstance = function() return inside, inside and "party" or "none" end
	_G.GetInstanceInfo = function() return name or "", inside and "party" or "none", 1, "Normal", 5, 0, false, 43, 5 end
end
local function clearInstance() _G.IsInInstance, _G.GetInstanceInfo = nil, nil end

--- Quest 1 is the dungeon quest (right next to the player: the tempting NOW), quest 2 an open-world quest farther away. tags: { [1] = tag table }.
local function world(tag1, areaName)
	local ns = boot({ char = { level = 15 }, synthetic = true, loc = { map = 9001, x = 0.5, y = 0.5, zone = "Durotar" } })
	H.attPack(ns, {
		{ id = 1, name = "Crypt Run", map = 9001, x = 0.52, y = 0.5, req = 1, areaId = areaName and 4000 or nil, objCoords = { { map = 9001, x = 0.52, y = 0.5 } } },
		{ id = 2, name = "Open Task", map = 9001, x = 0.7, y = 0.5, req = 1, objCoords = { { map = 9001, x = 0.7, y = 0.5 } } },
	}, nil)
	local W = H.world()
	W.log = { { questID = 1, title = "Crypt Run", complete = false }, { questID = 2, title = "Open Task", complete = false } }
	W.objectives = { [1] = { { text = "Boss slain", type = "monster", finished = false, numFulfilled = 0, numRequired = 1 } },
		[2] = { { text = "Boars", type = "monster", finished = false, numFulfilled = 1, numRequired = 8 } } }
	ns.Context.DefaultReader.questTag = function(id) if id == 1 then return tag1 end end
	ns.Context.DefaultReader.areaName = function(a) return a == 4000 and areaName or nil end
	ns.Prefs.FinishSetup()
	ns.State.Recompute()
	return ns
end
local DUNGEON = { id = 81, name = "Dungeon" }
local function nowId(ns) local p = ns.State.plan; return p.now and p.now.id end

section("dungeon NOW: outside the dungeon, a dungeon objective cannot be NOW")
do
	clearInstance(); setInstance(false)
	local ns = world(DUNGEON, "Wailing Caverns")
	check(nowId(ns) == "Q:2:OBJECTIVE", "NOW is the open-world quest, not the dungeon objective 20 yd away  [" .. tostring(nowId(ns)) .. "]")
	local p = ns.State.plan
	check(p.diag.dungeonDeferred and p.diag.dungeonDeferred.n == 1 and p.diag.dungeonDeferred.list[1].quest == 1, "the dungeon objective is counted as deferred, not dropped")
	check(p.now.id ~= "Q:1:OBJECTIVE", "and it is not NOW (the planner may still carry it as a lower-priority extra; the tracker lists it under DUNGEON QUESTS, never as ALSO COMPLETE)")
	for _, it in ipairs(ns.Presenter.Card(p, ns.State.ctx).also or {}) do check(it.quest ~= 1, "it is not shown as an ALSO COMPLETE row") end
	local cands = ns.Engine.Candidates(ns.State.ctx)
	local found = false
	for _, l in ipairs({ cands.candidates, cands.inProgress }) do for _, a in ipairs(l) do if a.id == "Q:1:OBJECTIVE" then found = true end end end
	check(found, "the underlying candidate data still holds it")
	local card = ns.Presenter.Card(p, ns.State.ctx)
	check(card.dungeons and #card.dungeons == 1 and card.dungeons[1].quests[1].quest == 1 and card.dungeons[1].name == "Wailing Caverns", "it stays in the DUNGEON QUESTS card, under its dungeon")
	check(card.now and card.now.title:find("Open Task", 1, true) ~= nil, "the NOW card shows the open-world quest")
	local report = table.concat(ns.Diag.Report and select(2, ns.Diag.Report()) or {}, "\n")
	check(report:find("dungeon objectives not NOW", 1, true) ~= nil, "the report says a dungeon objective was kept out of NOW")
	check(#ns.errors == 0, "no errors")
end

section("dungeon NOW: with only a dungeon quest, there is no dungeon NOW (and no empty-handed invention)")
do
	clearInstance(); setInstance(false)
	local ns = boot({ char = { level = 15 }, synthetic = true, loc = { map = 9001, x = 0.5, y = 0.5, zone = "Durotar" } })
	H.attPack(ns, { { id = 1, name = "Crypt Run", map = 9001, x = 0.52, y = 0.5, req = 1, objCoords = { { map = 9001, x = 0.52, y = 0.5 } } } }, nil)
	local W = H.world()
	W.log = { { questID = 1, title = "Crypt Run", complete = false } }
	W.objectives = { [1] = { { text = "Boss slain", type = "monster", finished = false, numFulfilled = 0, numRequired = 1 } } }
	ns.Context.DefaultReader.questTag = function(id) return DUNGEON end
	ns.Prefs.FinishSetup(); ns.State.Recompute()
	local card = ns.Presenter.Card(ns.State.plan, ns.State.ctx)
	check(ns.State.plan.now == nil and (card.now == nil or card.now.quest ~= 1), "NOW is not the dungeon objective")
	check(card.dungeons and #card.dungeons == 1, "it is still listed under DUNGEON QUESTS")
	check(ns.Navigation.Target() == nil, "no arrow to the dungeon")
end

section("dungeon NOW: inside the matching dungeon it behaves normally")
do
	clearInstance(); setInstance(true, "Wailing Caverns")
	local ns = world(DUNGEON, "Wailing Caverns")
	check(nowId(ns) == "Q:1:OBJECTIVE", "inside Wailing Caverns the dungeon objective can be NOW  [" .. tostring(nowId(ns)) .. "]")
	check(not (ns.State.plan.diag.dungeonDeferred and ns.State.plan.diag.dungeonDeferred.n > 0), "nothing is deferred")
	-- a different dungeon
	setInstance(true, "Ragefire Chasm")
	ns.State.Recompute()
	check(nowId(ns) == "Q:2:OBJECTIVE", "inside a DIFFERENT dungeon the quest of another dungeon is still not NOW")
	-- names that cannot be compared: inside an instance, it is not blocked
	local ns2 = world(DUNGEON, nil)
	setInstance(true, "Wailing Caverns"); ns2.State.Recompute()
	check(nowId(ns2) == "Q:1:OBJECTIVE", "inside an instance, with no dungeon name for the quest to compare, it is not blocked")
	-- instance state unknown
	clearInstance()
	local ns3 = world(DUNGEON, "Wailing Caverns")
	check(ns3.State.ctx.instance.known == false and nowId(ns3) == "Q:2:OBJECTIVE", "an unknown instance state counts as outside")
end

section("dungeon NOW: open-world quests are unchanged")
do
	clearInstance(); setInstance(false)
	local ns = world(nil, nil)
	check(nowId(ns) == "Q:1:OBJECTIVE", "an untagged nearby quest is NOW as before")
	local ns2 = world({ id = 1, name = "Elite" }, nil)
	check(nowId(ns2) == "Q:1:OBJECTIVE" and not ns2.State.plan.diag.dungeonDeferred, "an Elite-tagged quest is not a dungeon quest: unchanged")
	-- a dungeon quest's hand-in (a TURN_IN) is not an objective in the dungeon: unchanged
	local ns3 = boot({ char = { level = 15 }, synthetic = true, loc = { map = 9001, x = 0.5, y = 0.5, zone = "Durotar" } })
	H.attPack(ns3, { { id = 1, name = "Crypt Run", map = 9001, x = 0.52, y = 0.5, req = 1 } }, nil)
	H.world().log = { { questID = 1, title = "Crypt Run", complete = true } }
	ns3.Context.DefaultReader.questTag = function() return DUNGEON end
	ns3.Prefs.FinishSetup(); ns3.State.Recompute()
	check(ns3.State.plan.now and ns3.State.plan.now.id == "Q:1:TURN_IN", "a finished dungeon quest's hand-in still routes normally")
	clearInstance()
end

-- 0.8.7: INSIDE the dungeon, its objectives lead even with no usable location (the real report: Ruins of Lordaeron, Q92422 with no objective position, NOW was a hand-in far away)
section("dungeon NOW: inside the dungeon, its objectives lead (guidance) even with no location; the planner's NOW is not lost")
do
	local function inWorld(instanceName)
		local ns = boot({ char = { level = 15 }, synthetic = true, loc = { map = 9001, x = 0.5, y = 0.5, zone = "Ruins of Lordaeron" } })
		H.attPack(ns, {
			{ id = 1, name = "The Wrath", map = 9001, x = 0.52, y = 0.5, req = 1, areaId = 4000 },                          -- dungeon quest: a giver place, NO objective place
			{ id = 2, name = "Other Dungeon Quest", map = 9001, x = 0.53, y = 0.5, req = 1, areaId = 4001 },
			{ id = 3, name = "Far Hand-in", map = 9001, x = 0.9, y = 0.5, req = 1 },
			{ id = 4, name = "Open Task", map = 9001, x = 0.7, y = 0.5, req = 1, objCoords = { { map = 9001, x = 0.7, y = 0.5 } } },
		}, nil)
		local W = H.world()
		W.log = { { questID = 1, title = "The Wrath", complete = false }, { questID = 2, title = "Other Dungeon Quest", complete = false },
			{ questID = 3, title = "Far Hand-in", complete = true }, { questID = 4, title = "Open Task", complete = false } }
		W.objectives = { [1] = { { text = "Rath'mael slain", type = "monster", finished = false, numFulfilled = 0, numRequired = 1 } },
			[2] = { { text = "Boss slain", type = "monster", finished = false, numFulfilled = 0, numRequired = 1 } },
			[4] = { { text = "Boars", type = "monster", finished = false, numFulfilled = 1, numRequired = 8 } } }
		ns.Context.DefaultReader.questTag = function(id) if id == 1 or id == 2 then return DUNGEON end end
		ns.Context.DefaultReader.areaName = function(a) return a == 4000 and "Ruins of Lordaeron" or (a == 4001 and "Ragefire Chasm") or nil end
		clearInstance(); if instanceName then setInstance(true, instanceName) else setInstance(false) end
		ns.Prefs.FinishSetup(); ns.State.Recompute()
		return ns
	end
	local ns = inWorld("Ruins of Lordaeron")
	local card = ns.Presenter.Card(ns.State.plan, ns.State.ctx)
	check(card.guidance == true and card.now.quest == 1 and card.now.title:find("The Wrath", 1, true) ~= nil, "NOW is the dungeon quest of THIS dungeon  [" .. tostring(card.now and card.now.title) .. "]")
	check(card.now.where == nil and card.now.dist == nil and card.now.who:find("no arrow", 1, true) ~= nil, "as guidance: no place, no distance, and it says there is no arrow")
	check(card.now.objectives and card.now.objectives[1] and card.now.objectives[1].text == "Rath'mael slain", "with the quest log's own objective")
	local ready = {}
	for _, r in ipairs(card.ready) do ready[r.quest] = true end
	check(ready[3], "the planner's own hand-in is not lost: it moves to READY TO TURN IN while the dungeon leads")
	check(card.dungeons and #card.dungeons >= 1, "the DUNGEON QUESTS card is still there")
	check(ns.State.plan.now ~= nil and ns.Navigation.Target() == nil, "(the planner still has its own NOW; no arrow is made inside the instance)")
	-- another dungeon's quest is not picked
	local ns2 = inWorld("Wailing Caverns")
	local card2 = ns2.Presenter.Card(ns2.State.plan, ns2.State.ctx)
	check(not (card2.guidance and (card2.now.quest == 1 or card2.now.quest == 2)), "inside an unrelated dungeon neither dungeon quest leads")
	-- outside: unchanged (the planner's NOW stands, dungeon quests stay in their card)
	local ns3 = inWorld(nil)
	local card3 = ns3.Presenter.Card(ns3.State.plan, ns3.State.ctx)
	check(not card3.guidance and ns3.State.plan.now ~= nil, "outside, the planner's NOW stands as before")
	clearInstance()
	check(#ns.errors + #ns2.errors + #ns3.errors == 0, "no errors")
end
