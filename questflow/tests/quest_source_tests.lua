-- quest_source_tests.lua: where a quest STARTS (an NPC, a world object or an item). The data layer is a fake QuestieDB: reference data, not Forever behaviour. These tests prove that Codex keeps
-- the source kind it is given and does not name a nearby NPC as the giver of an item- or object-started quest. They do NOT show that the real QuestieDB or Forever expose this for any quest:
-- that is the documented gap (docs/CODEX_QUEST_SOURCES.md).

local H = ...
local check, section, boot = H.check, H.section, H.boot

local function world(setup)
	local ns = boot({ char = { level = 5 }, synthetic = true, loc = { map = 9001, x = 0.5, y = 0.5, zone = "F" } })
	-- (ATT records give these two quests a place so they are candidates at all; a quest with no place anywhere is not offered)
	H.attPack(ns, { { id = 781, name = "Source Item Quest", map = 9001, x = 0.52, y = 0.5, req = 1 }, { id = 783, name = "Object Quest", map = 9001, x = 0.53, y = 0.5, req = 1 } }, { { key = "zone-a", label = "A", map = 9001, quests = 2 } })
	local fake = H.fake.new()
	fake.addNpc(9101, { name = "Nearby Squealer", zoneID = 9001, spawns = { [9001] = { { 52, 50 } } } })
	fake.addNpc(9102, { name = "Plain Giver", zoneID = 9001, spawns = { [9001] = { { 54, 50 } } } })
	fake.mapArea(9001, 9001)
	setup(fake)
	fake.install()
	_G.LibQuestieDB.Item = { Exists = function(id) return id == 4851 end, Get = function(id, k) if id == 4851 and k == "name" then return "Dirt-Stained Map" end end }
	ns.QuestieBridge.Init()
	ns.Prefs.FinishSetup()
	ns.State.Recompute()
	return ns
end
local function acceptOf(ns, id)
	for _, a in ipairs(ns.Engine.Candidates(ns.Context.Build()).candidates) do if a.id == "Q:" .. id .. ":ACCEPT" then return a end end
	for _, a in ipairs(ns.State.plan.reminders) do if a.id == "Q:" .. id .. ":ACCEPT" then return a end end
end

section("quest sources: an item-started quest is not given by the NPC beside the item")
do
	local ns = world(function(f)
		f.addQuest(781, { name = "Source Item Quest", startedBy = { {}, {}, { 4851 } }, finishedBy = { { 9101 } }, requiredLevel = 1, questLevel = 1 })
		f.addQuest(782, { name = "Plain Quest", startedBy = { { 9102 } }, finishedBy = { { 9102 } }, requiredLevel = 1, questLevel = 1 })
		f.addQuest(783, { name = "Object Quest", startedBy = { {}, { 3333 }, {} }, finishedBy = { { 9102 } }, requiredLevel = 1, questLevel = 1 })
	end)
	local v = ns.Registry.Quest(781)
	check(v.startKind == "ITEM" and v.startItem == 4851 and v.startItemName == "Dirt-Stained Map" and v.giverNpc == nil and v.giverName == nil, "the record keeps the source kind (ITEM), the item and its name, and NO giver")
	check(ns.Registry.Quest(782).startKind == "NPC" and ns.Registry.Quest(782).giverName == "Plain Giver", "an NPC-started quest is unchanged")
	local o = ns.Registry.Quest(783)
	check(o.startKind == "OBJECT" and o.startObject == 3333 and o.giverNpc == nil, "an object-started quest keeps its object id and names no giver")
	local a = acceptOf(ns, 781)
	check(a and a.giver == nil and a.sourceKind == "ITEM" and a.sourceItem == "Dirt-Stained Map", "the ACCEPT action carries the source and no NPC")
	check(table.concat(a.lines, "\n"):find("Starts from an item: Dirt-Stained Map (QuestieDB, unverified on Forever)", 1, true) ~= nil, "its text says where it starts, and that this is reference data")
	local card = ns.Presenter.Describe(a, ns.State.plan, ns.State.ctx, nil)
	check(card.title == "Accept Source Item Quest" and card.who == nil and card.npc == nil and card.detail == "Starts from an item: Dirt-Stained Map. Not from an NPC.", "the card names the item, not an NPC  [" .. tostring(card.detail) .. "]")
	local ao = acceptOf(ns, 783)
	check(ns.Presenter.Describe(ao, ns.State.plan, ns.State.ctx, nil).detail == "Starts from a world object. Not from an NPC.", "an object-started quest says so")
	check(#ns.errors == 0, "no errors")
end

section("quest sources: a creature starter wins when the data lists one, and extra object / item starters are kept beside it")
do
	local ns = world(function(f)
		f.addQuest(790, { name = "Both", startedBy = { { 9102 }, {}, { 4851 } }, finishedBy = { { 9102 } }, requiredLevel = 1, questLevel = 1 })
	end)
	local v = ns.Registry.Quest(790)
	check(v.startKind == "NPC" and v.giverName == "Plain Giver" and v.startItem == 4851, "an NPC starter is the source; the item is recorded too")
end

section("quest sources: no layer, no claim (the observed pack and ATT carry no source kind; nothing is inferred from a nearby NPC)")
do
	local ns = boot({ char = { level = 5 }, synthetic = true, loc = { map = 9001, x = 0.5, y = 0.5, zone = "F" } })
	H.attPack(ns, { { id = 5, name = "ATT Quest", map = 9001, x = 0.55, y = 0.5, req = 1, giverNpc = 1, giverName = "Somebody" } }, { { key = "zone-a", label = "A", map = 9001, quests = 1 } })
	check(ns.Registry.Quest(5).startKind == nil, "a quest known only from ATT has no source kind: unknown stays unknown")
	local src = H.readFile(H.addonDir .. "/QuestieBridge.lua")
	check(not src:find("lib%.Object") and not src:find("ObjectDB"), "no object table is read (its API is not documented for the bridge): object sources are kept by id only, with no coordinates")
end
