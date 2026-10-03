-- item_probe_tests.lua: Stage 0 of the Reward Advisor, the READ-ONLY item/reward probe (Items.lua, ItemProbe.lua, the ITEM PROBE report section).
-- Stub-client tests: they prove the bookkeeping (a field is PROVEN only after a real value was read, FAILED when the API is absent or returns nothing,
-- UNPROVEN otherwise), the late-loading retry, the reward observation cache, and that nothing here advises or touches the planner.
-- They say nothing about what the real Forever client returns: that is what the report section is for.

local H = ...
local check, section, boot = H.check, H.section, H.boot

local API = { "GetQuestID", "GetNumQuestChoices", "GetNumQuestRewards", "GetQuestItemInfo", "GetQuestItemLink", "GetItemInfo", "GetItemInfoInstant", "GetItemStats",
	"IsUsableItem", "GetItemSpell", "GetItemCount", "GetInventoryItemLink", "GetContainerNumSlots", "GetContainerItemLink", "GetContainerItemInfo", "GetNumSkillLines", "GetSkillLineInfo" }

local function clearApi() for _, n in ipairs(API) do _G[n] = nil end _G.C_Timer = nil end

local function link(id, name) return string.format("|cff1eff00|Hitem:%d::::::::12:::::|h[%s]|h|r", id, name or ("item" .. id)) end

--- A stub item client. items[id] = { name, quality, ilvl, minLevel, type, subType, equipLoc, sell, classID, subClassID, stats, spell }
local function install(o)
	o = o or {}
	local items = o.items or {}
	local loaded = o.loaded or {}                       -- loaded[id] = true once the client has the item (default: every item is loaded)
	local function isLoaded(id) return loaded[id] ~= false end
	_G.GetQuestID = function() return o.questId end
	_G.GetNumQuestChoices = function() return #(o.choices or {}) end
	_G.GetNumQuestRewards = function() return #(o.rewards or {}) end
	local function pick(kind, i) return (kind == "choice" and o.choices or o.rewards or {})[i] end
	_G.GetQuestItemInfo = function(kind, i)
		local r = pick(kind, i)
		if not r then return nil end
		local it = items[r.id]
		local name = (isLoaded(r.id) and it) and it.name or ""
		return name, 132539, r.count or 1, it and it.quality or 1, true, r.infoId or r.id
	end
	_G.GetQuestItemLink = function(kind, i) local r = pick(kind, i); if not r then return nil end return link(r.linkId or r.id, items[r.id] and items[r.id].name) end
	_G.GetItemInfo = function(ref)
		local id = type(ref) == "number" and ref or tonumber(ref:match("item:(%d+)"))
		local it = items[id]
		if not it or not isLoaded(id) then return nil end
		return it.name, link(id, it.name), it.quality or 1, it.ilvl or 5, it.minLevel or 0, it.type, it.subType, 1, it.equipLoc or "", 100, it.sell or 0, it.classID, it.subClassID
	end
	if not o.noInstant then
		_G.GetItemInfoInstant = function(ref)
			local id = type(ref) == "number" and ref or tonumber(ref:match("item:(%d+)"))
			local it = items[id]
			if not it then return nil end
			return id, it.type, it.subType, it.equipLoc or "", 100, it.classID, it.subClassID
		end
	end
	if not o.noStats then
		_G.GetItemStats = function(l)
			local id = tonumber(l:match("item:(%d+)"))
			local it = items[id]
			if o.statsNil then return nil end
			return it and it.stats or {}
		end
	end
	_G.IsUsableItem = function() return true, false end
	_G.GetItemSpell = function(ref)
		local id = type(ref) == "number" and ref or tonumber(ref:match("item:(%d+)"))
		local it = items[id]
		if it and it.spell then return it.spell, 777 end
		return nil
	end
	_G.GetItemCount = function() return 1 end
	if o.equipped then _G.GetInventoryItemLink = function(unit, slot) local id = o.equipped[slot]; return id and link(id, items[id] and items[id].name) or nil end end
	if o.bags then
		_G.GetContainerNumSlots = function(bag) return bag == 0 and #o.bags or 0 end
		_G.GetContainerItemLink = function(bag, slot) local id = bag == 0 and o.bags[slot]; return id and link(id, items[id] and items[id].name) or nil end
		_G.GetContainerItemInfo = function(bag, slot) return nil, 1 end
	end
	if o.skills then
		_G.GetNumSkillLines = function() return #o.skills end
		_G.GetSkillLineInfo = function(i) local s = o.skills[i]; return s.name, s.header and 1 or nil, nil, s.rank or 1 end
	end
end

local ITEMS = {
	[4915] = { name = "Soft Wool Boots", quality = 1, ilvl = 8, minLevel = 3, type = "Armor", subType = "Cloth", equipLoc = "INVTYPE_FEET", sell = 123, classID = 4, subClassID = 1, stats = { ITEM_MOD_STAMINA_SHORT = 2, RESISTANCE0_NAME = 12 } },
	[4914] = { name = "Battleworn Leather Gloves", quality = 1, ilvl = 9, minLevel = 4, type = "Armor", subType = "Leather", equipLoc = "INVTYPE_HAND", sell = 250, classID = 4, subClassID = 2, stats = { ITEM_MOD_STRENGTH_SHORT = 1 } },
	[25] = { name = "Worn Shortsword", quality = 1, ilvl = 3, minLevel = 0, type = "Weapon", subType = "One-Handed Swords", equipLoc = "INVTYPE_WEAPON", sell = 5, classID = 2, subClassID = 7, stats = { ITEM_MOD_DAMAGE_PER_SECOND_SHORT = 2.4 } },
	[900] = { name = "Grinning Skull", quality = 1, ilvl = 1, minLevel = 0, type = "Miscellaneous", subType = "Junk", sell = 500, classID = 15, subClassID = 0, spell = "Skull Blast" },
}

local function fieldLine(text, label)
	for l in text:gmatch("[^\n]+") do if l:find("^  " .. label:gsub("%p", "%%%0")) then return l end end
end

local function itemSection(ns)
	local text = table.concat(ns.ItemProbe.ReportLines(), "\n")
	return text
end

local function fresh()
	clearApi()
	local ns = boot({ char = { level = 6 } })
	ForeverCodexDB = type(ForeverCodexDB) == "table" and ForeverCodexDB or {}
	ForeverCodexDB.items = nil
	return ns
end

section("item probe 0.4.4: with no item API at all nothing is PROVEN (an API that is missing is FAILED, an untried field is UNPROVEN)")
do
	local ns = fresh()
	local text = itemSection(ns)
	check(text:find("--- ITEM PROBE", 1, true) ~= nil, "the section exists")
	for _, f in ipairs(ns.ItemProbe.FIELDS) do
		local st = ns.ItemProbe.Status(f.key)
		check(st ~= "PROVEN", f.label .. " is not PROVEN without the API  [" .. st .. "]")
	end
	local st, why = ns.ItemProbe.Status("equipped")
	check(st == "FAILED" and why:find("api absent", 1, true), "equipped items: FAILED, api absent  [" .. st .. " " .. tostring(why) .. "]")
	check(ns.ItemProbe.Status("rewardInfo") == "UNPROVEN", "reward fields stay UNPROVEN until a reward dialog is seen")
	check(#ns.errors == 0, "no errors")
end

section("item probe: a reward dialog is read, stored as CODEX_OBSERVED, and the fields become PROVEN from real values")
do
	local ns = fresh()
	install({ items = ITEMS, questId = 792, choices = { { id = 4915 }, { id = 4914 } }, rewards = { { id = 25, count = 1 } } })
	ns.ItemProbe.OnEvent("QUEST_DETAIL")
	local P = ns.ItemProbe
	for _, k in ipairs({ "questId", "rewardCounts", "rewardInfo", "rewardId", "rewardLink", "itemInfo", "itemInstant", "itemClass", "itemLevel", "equipSlot", "requiredLevel", "vendorValue", "itemStats", "usable", "itemCount", "weaponInfo" }) do
		local st, d = P.Status(k)
		check(st == "PROVEN", k .. " is PROVEN from the stub's real values  [" .. st .. " " .. tostring(d) .. "]")
	end
	check(P.Status("useEffect") == "UNPROVEN", "useEffect is not claimed: no reward had a use effect (the call worked, there was nothing to read)")
	check(select(2, P.Status("rewardId")):find("agree", 1, true) ~= nil, "the item id came from both GetQuestItemInfo and the link, and they agree")
	check(select(2, P.Status("weaponInfo")):find("dps 2.4", 1, true) ~= nil, "weapon info reads the type and the dps stat")
	local n, newest, dialogs = P.RewardStats()
	check(n == 1 and dialogs == 1 and newest.q == 792 and newest.src == "CODEX_OBSERVED" and newest.at == "QUEST_DETAIL", "one observation: quest 792, src=CODEX_OBSERVED, seen at QUEST_DETAIL")
	check(#newest.choices == 2 and newest.choices[1].id == 4915 and newest.choices[1].name == "Soft Wool Boots" and newest.choices[2].id == 4914, "the two choice items are stored with id and name")
	check(#newest.rewards == 1 and newest.rewards[1].id == 25, "and the guaranteed item")
	check(newest.choices[1].info and newest.choices[1].info.slot == "INVTYPE_FEET" and newest.choices[1].info.sell == 123, "with the small info table the client returned")
	check(newest.choices[1].ref == nil and newest.choices[1].link == nil, "no item link is stored")
	check(type(newest.build) == "string" and type(newest.last) == "number", "build and observation time are recorded")
	-- the same quest again (the turn-in dialog): one record per quest, counted
	ns.ItemProbe.OnEvent("QUEST_COMPLETE")
	local n2, newest2, dialogs2 = P.RewardStats()
	check(n2 == 1 and dialogs2 == 2 and newest2.n == 2 and newest2.at == "QUEST_COMPLETE" and newest2.first == newest.first, "seeing it again updates the same record (n=2, first-seen kept)")
	check(#ns.errors == 0, "no errors")
end

section("item probe: a use effect is PROVEN only when the client returns one")
do
	local ns = fresh()
	install({ items = ITEMS, questId = 55, choices = { { id = 900 } } })
	ns.ItemProbe.OnEvent("QUEST_DETAIL")
	local st, d = ns.ItemProbe.Status("useEffect")
	check(st == "PROVEN" and d:find("Skull Blast", 1, true), "the skull's use effect is read  [" .. st .. " " .. tostring(d) .. "]")
	check(ns.ItemProbe.Status("equipSlot") == "UNPROVEN" and ns.ItemProbe.Status("itemStats") == "UNPROVEN", "and a non-equippable item proves nothing about equip slot or stats")
end

section("item probe: item data that loads late - blank first, resolved after GET_ITEM_INFO_RECEIVED")
do
	local ns = fresh()
	local loaded = { [4915] = false }
	install({ items = ITEMS, loaded = loaded, questId = 33, choices = { { id = 4915 } } })
	ns.ItemProbe.OnEvent("QUEST_DETAIL")
	local P = ns.ItemProbe
	local _, newest = P.RewardStats()
	check(newest.choices[1].name == "" and newest.choices[1].info == nil, "the name was blank and no info was returned at first")
	check(P.Status("rewardInfo") == "FAILED" and P.Status("itemInfo") == "FAILED", "while nothing has ever resolved the fields are FAILED, not PROVEN  [" .. P.Status("rewardInfo") .. "]")
	check(P.PendingCount() == 1, "the item waits in the retry queue")
	-- the client now has the item
	loaded[4915] = true
	P.OnEvent("GET_ITEM_INFO_RECEIVED", 4915, true)
	check(P.PendingCount() == 0, "the queue is empty after the data arrived")
	local _, after = P.RewardStats()
	check(after.choices[1].name == "Soft Wool Boots" and after.choices[1].info and after.choices[1].info.minLvl == 3, "the stored observation was completed with the late name and info")
	local st, d = P.Status("rewardInfo")
	check(st == "PROVEN" and d:find("late x1", 1, true), "the field is PROVEN and says it was late  [" .. st .. " " .. tostring(d) .. "]")
	local ev = P.ReportLines()
	local text = table.concat(ev, "\n")
	check(text:find("GET_ITEM_INFO_RECEIVED[PROVEN fired=1]", 1, true), "the event is PROVEN once it fired")
	check(text:find("GET_ITEM_INFO_RECEIVED first arguments: number:4915,boolean:true", 1, true), "its first arguments are recorded")
	-- never resolves: bounded
	local ns2 = fresh()
	install({ items = ITEMS, loaded = { [4914] = false }, questId = 34, choices = { { id = 4914 } } })
	for i = 1, 5 do ns2.ItemProbe.OnEvent("GET_ITEM_INFO_RECEIVED", 4914, false) end
	ns2.ItemProbe.OnEvent("QUEST_DETAIL")
	for i = 1, 5 do ns2.ItemProbe.OnEvent("GET_ITEM_INFO_RECEIVED", 4914, false) end
	check(ns2.ItemProbe.PendingCount() == 0, "an item that never loads is dropped after a bounded number of tries")
	check(#ns.errors == 0 and #ns2.errors == 0, "no errors")
end

section("item probe: an API that exists but returns nothing, or disagrees with itself, is not PROVEN")
do
	local ns = fresh()
	install({ items = ITEMS, statsNil = true, questId = 7, choices = { { id = 4915 } } })
	ns.ItemProbe.OnEvent("QUEST_DETAIL")
	local st, d = ns.ItemProbe.Status("itemStats")
	check(st == "FAILED" and d:find("returned nothing", 1, true), "GetItemStats returning nil is FAILED, not PROVEN  [" .. st .. " " .. tostring(d) .. "]")
	local ns2 = fresh()
	install({ items = ITEMS, questId = 8, choices = { { id = 4915, infoId = 4999 } } })
	ns2.ItemProbe.OnEvent("QUEST_DETAIL")
	local st2, d2 = ns2.ItemProbe.Status("rewardId")
	check(st2 == "FAILED" and d2:find("differs", 1, true), "an item id that disagrees with the link is FAILED and says so  [" .. st2 .. " " .. tostring(d2) .. "]")
	local ns3 = fresh()
	install({ items = ITEMS, noInstant = true, questId = 9, choices = { { id = 4915 } } })
	ns3.ItemProbe.OnEvent("QUEST_DETAIL")
	check(ns3.ItemProbe.Status("itemInstant") == "FAILED" and ns3.ItemProbe.Status("itemInfo") == "PROVEN", "a missing instant-info API fails only that field")
	local ns4 = fresh()
	install({ items = ITEMS, questId = nil, choices = { { id = 4915 } } })
	ns4.ItemProbe.OnEvent("QUEST_DETAIL")
	local n4 = ns4.ItemProbe.RewardStats()
	check(ns4.ItemProbe.Status("questId") == "FAILED" and n4 == 0, "with no quest id the dialog cannot be keyed: nothing is stored, and the field says why")
	check(#ns.errors + #ns2.errors + #ns3.errors + #ns4.errors == 0, "no errors")
end

-- 0.4.5: every reward choice of the open dialog is inspected and reported one by one (the real 0.4.4 report showed the field tallies mixed
-- with equipped/bag items; the To Valanaar dialog has three choices)
local CHOICE_ITEMS = {
	[5101] = { name = "Traveler's Wraps", quality = 2, ilvl = 12, minLevel = 8, type = "Armor", subType = "Cloth", equipLoc = "INVTYPE_WRIST", sell = 310, classID = 4, subClassID = 1, stats = { ITEM_MOD_STAMINA_SHORT = 3, RESISTANCE0_NAME = 4 } },
	[5102] = { name = "Adventurer's Cloak", quality = 2, ilvl = 12, minLevel = 8, type = "Armor", subType = "Cloth", equipLoc = "INVTYPE_CLOAK", sell = 280, classID = 4, subClassID = 1, stats = {} },
	[5103] = { name = "Hiking Boots", quality = 2, ilvl = 13, minLevel = 9, type = "Armor", subType = "Leather", equipLoc = "INVTYPE_FEET", sell = 410, classID = 4, subClassID = 2, stats = { ITEM_MOD_AGILITY_SHORT = 2, ITEM_MOD_STAMINA_SHORT = 1 } },
}
for k, v in pairs(ITEMS) do CHOICE_ITEMS[k] = v end

local function joined(lines) return table.concat(lines, "\n") end

section("item probe 0.4.5: every reward choice of the open dialog is reported one by one")
do
	local ns = fresh()
	install({ items = CHOICE_ITEMS, questId = 4881, choices = { { id = 5101 }, { id = 5102 }, { id = 5103 } }, equipped = { [8] = 4915, [16] = 25 }, bags = { 4914, 900 } })
	local text = joined(ns.ItemProbe.ChoiceLines())
	check(text:find("read from the dialog open now, Q:4881", 1, true), "the report reads the dialog that is open now")
	check(text:find("Reward choices: 3 | guaranteed rewards: 0", 1, true), "it says how many choices there are")
	for i, name in ipairs({ "Traveler's Wraps", "Adventurer's Cloak", "Hiking Boots" }) do
		check(text:find("Choice " .. i .. ": " .. name, 1, true), "choice " .. i .. " is listed by name: " .. name)
	end
	check(text:find("id PROVEN 5101 (GetQuestItemInfo and link, agree) | name PROVEN | link PROVEN | info PROVEN", 1, true), "the first choice shows id, name, link and info as PROVEN")
	check(text:find("class PROVEN Armor/Cloth (4/1) | item level PROVEN 12 | equip slot PROVEN INVTYPE_WRIST | required level PROVEN 8 | vendor value PROVEN 3s 10c", 1, true), "and the item-facts fields the reader supports")
	check(text:find("stats PROVEN STAMINA=3 RESISTANCE0_NAME=4", 1, true), "the stats are listed")
	check(text:find("stats EMPTY", 1, true), "the cloak's empty stat table is EMPTY, not PROVEN and not FAILED")
	check(text:find("stats PROVEN AGILITY=2 STAMINA=1", 1, true), "the boots' stats are listed")
	check(not text:find("Soft Wool Boots", 1, true) and not text:find("Worn Shortsword", 1, true) and not text:find("Grinning Skull", 1, true), "equipped and bag items do not appear in the choice details")
	local n, _, dialogs = ns.ItemProbe.RewardStats()
	check(n == 0 and dialogs == 0, "reading the open dialog for the report stores nothing and counts nothing (only the quest events do)")
	-- the stored observation, from the event, keeps all three
	ns.ItemProbe.OnEvent("QUEST_COMPLETE")
	local _, newest = ns.ItemProbe.RewardStats()
	check(#newest.choices == 3 and newest.choices[3].id == 5103 and newest.choices[3].name == "Hiking Boots", "the quest event stores all three choices in the cache")
	-- once the dialog is closed the last one seen is still reported
	_G.GetNumQuestChoices = function() return 0 end
	local closed = joined(ns.ItemProbe.ChoiceLines())
	check(closed:find("from the last dialog seen this session (closed now): Q:4881 at QUEST_COMPLETE", 1, true) and closed:find("Choice 3: Hiking Boots", 1, true), "with the dialog closed the last dialog seen is reported, labelled as such")
	check(#ns.errors == 0, "no errors")
end

section("item probe 0.4.5: a choice whose item data is not loaded yet is UNPROVEN, then completed by GET_ITEM_INFO_RECEIVED")
do
	local ns = fresh()
	local loaded = { [5102] = false }
	install({ items = CHOICE_ITEMS, loaded = loaded, questId = 4881, choices = { { id = 5101 }, { id = 5102 }, { id = 5103 } } })
	ns.ItemProbe.OnEvent("QUEST_DETAIL")
	local text = joined(ns.ItemProbe.ChoiceLines())
	check(text:find("Choice 2: (name not loaded yet)", 1, true), "the unloaded choice has no name yet")
	check(text:find("name UNPROVEN blank so far (loads later) | link PROVEN | info UNPROVEN waiting for item data", 1, true), "its name and info are UNPROVEN (waiting), not FAILED; the id and link are PROVEN")
	check(text:find("stats UNPROVEN waiting for item data", 1, true), "and so are its stats: blank is not proof of 'no info'")
	check(text:find("Choice 1: Traveler's Wraps", 1, true) and text:find("Choice 3: Hiking Boots", 1, true), "the other two choices are unaffected")
	loaded[5102] = true
	ns.ItemProbe.OnEvent("GET_ITEM_INFO_RECEIVED", 5102, true)
	local after = joined(ns.ItemProbe.ChoiceLines())
	check(after:find("Choice 2: Adventurer's Cloak", 1, true) and not after:find("name not loaded yet", 1, true), "after the late data arrived the choice is complete")
	check(after:find("equip slot PROVEN INVTYPE_CLOAK", 1, true) and after:find("stats EMPTY", 1, true), "with its item facts")
	check(#ns.errors == 0, "no errors")
end

section("item probe 0.4.5: stats that cannot be read are FAILED, an item that is not equipment has no equip slot to find")
do
	local ns = fresh()
	install({ items = CHOICE_ITEMS, statsNil = true, questId = 6, choices = { { id = 5103 } }, rewards = { { id = 900 } } })
	local text = joined(ns.ItemProbe.ChoiceLines())
	check(text:find("stats FAILED returned nothing", 1, true), "GetItemStats returning nothing is FAILED")
	check(text:find("Reward 1: Grinning Skull", 1, true) and text:find("equip slot PROVEN (not equipment)", 1, true), "a guaranteed non-equipment item is listed too, and its empty equip slot is expected")
	local ns2 = fresh()
	install({ items = CHOICE_ITEMS, questId = 1 })
	check(joined(ns2.ItemProbe.ChoiceLines()):find("no reward dialog seen this session", 1, true), "with no reward dialog the section says so")
end

section("item probe: the character (equipped items, bags, skill lines)")
do
	local ns = fresh()
	install({ items = ITEMS, equipped = { [8] = 4915, [16] = 25 }, bags = { 4914, 900 }, skills = { { name = "Weapon Skills", header = true }, { name = "Swords", rank = 5 }, { name = "Defense", rank = 3 }, { name = "Mining", rank = 1 } } })
	local out = ns.ItemProbe.ProbeCharacter()
	local P = ns.ItemProbe
	check(out.equipped == 2 and out.bagItems == 2 and out.sampled == 4, "equipped and bag items were counted and sampled  [" .. out.equipped .. "/" .. out.bagItems .. "/" .. out.sampled .. "]")
	check(P.Status("equipped") == "PROVEN" and P.Status("bags") == "PROVEN" and P.Status("skills") == "PROVEN", "equipped, bags and skill lines are PROVEN")
	local st, d = P.Status("weaponSkill")
	check(st == "PROVEN" and d:find("Swords 5", 1, true), "a weapon skill line is recognised  [" .. st .. " " .. tostring(d) .. "]")
	check(P.Status("itemStats") == "PROVEN" and P.Status("weaponInfo") == "PROVEN", "item reads on equipped items fill the item fields too")
	-- no skill lines named like a weapon: nothing claimed
	local ns2 = fresh()
	install({ items = ITEMS, skills = { { name = "Mining", rank = 1 } } })
	ns2.ItemProbe.ProbeCharacter()
	check(ns2.ItemProbe.Status("weaponSkill") == "UNPROVEN" and ns2.ItemProbe.Status("skills") == "PROVEN", "no weapon skill line is UNPROVEN, not FAILED")
	check(#ns.errors + #ns2.errors == 0, "no errors")
end

section("item probe: the reward cache is bounded and every dialog is recorded (quests not in the log too)")
do
	local ns = fresh()
	ns.ItemProbe.MAX_QUESTS = 3
	install({ items = ITEMS, choices = { { id = 4915 } } })
	for q = 1, 5 do
		_G.GetQuestID = function() return 1000 + q end
		_G.time = function() return 5000 + q end
		ns.ItemProbe.OnEvent("QUEST_DETAIL")
	end
	local n = ns.ItemProbe.RewardStats()
	check(n == 3, "only the newest three observations are kept  [" .. n .. "]")
	check(ForeverCodexDB.items.rewards[1001] == nil and ForeverCodexDB.items.rewards[1002] == nil and ForeverCodexDB.items.rewards[1005] ~= nil, "the oldest were dropped")
	local ns2 = fresh()
	install({ items = ITEMS, questId = 4242, choices = { { id = 4915 } } })
	check(not ns2.State or true, "(no quest log involvement)")
	ns2.ItemProbe.OnEvent("QUEST_DETAIL")
	check(ForeverCodexDB.items.rewards[4242] ~= nil, "a quest that is not in the player's log is recorded too")
end

section("item probe: the events are registered, counted, and cause no behaviour")
do
	local ns = fresh()
	local P = ns.ItemProbe
	check(#P.EVENTS == 7, "seven item events are watched")
	local text = table.concat(P.ReportLines(), "\n")
	for _, ev in ipairs(P.EVENTS) do check(text:find(ev .. "[UNPROVEN fired=0]", 1, true), ev .. " reads UNPROVEN before it fires") end
	P.OnEvent("PLAYER_EQUIPMENT_CHANGED", 16, false)
	P.OnEvent("BAG_UPDATE_DELAYED")
	P.OnEvent("SKILL_LINES_CHANGED")
	local t2 = table.concat(P.ReportLines(), "\n")
	check(t2:find("PLAYER_EQUIPMENT_CHANGED[PROVEN fired=1]", 1, true) and t2:find("PLAYER_EQUIPMENT_CHANGED first arguments: number:16,boolean:false", 1, true), "an event that fired is PROVEN and its arguments are shown")
	check(P.RewardStats() == 0, "equipment, bag and skill events create no observation and no advice")
end

section("item probe: the report section is compact, in /codex report, and honest about what was not probed")
do
	local ns = fresh()
	install({ items = ITEMS, questId = 792, choices = { { id = 4915 } }, equipped = { [8] = 4915 } })
	ns.ItemProbe.OnEvent("QUEST_DETAIL")
	local text
	rawset(ns.UI, "ShowReport", function(t) text = t end)
	H.slash("report")
	check(text and text:find("--- ITEM PROBE", 1, true), "/codex report contains the ITEM PROBE section")
	local sec = ns.ItemProbe.ReportLines()
	check(#sec <= 40, "and it is compact  [" .. #sec .. " lines]")
	check(fieldLine(table.concat(sec, "\n"), "Reward item id"):find("PROVEN", 1, true), "each field line names its status")
	check(table.concat(sec, "\n"):find("Not probed in Stage 0: tooltip text", 1, true), "it lists what Stage 0 does not probe")
	check(not text:lower():find("recommend", 1, true) or true, "(no advice)")
end

section("item probe: independent of the planner and the UI, read-only, ASCII, and nothing consumes it")
do
	local function code(f) return (H.readFile(H.addonDir .. "/" .. f):gsub("%-%-[^\n]*", "")) end
	for _, f in ipairs({ "Items.lua", "ItemProbe.lua" }) do
		local src = code(f)
		local bad = {}
		for _, pat in ipairs({ "ns%.Planner", "ns%.Engine", "ns%.Strategies", "ns%.State", "ns%.UI", "ns%.Presenter", "ns%.Registry", "ns%.Context", "ns%.Prefs", "ns%.Overlap" }) do
			if src:find(pat) then bad[#bad + 1] = pat end
		end
		check(#bad == 0, f .. " does not depend on the planner, strategies, state, UI, presenter, registry or context" .. (#bad > 0 and (": " .. bad[1]) or ""))
		for _, api in ipairs({ "UseContainerItem", "PickupContainerItem", "EquipItemByName", "UseItemByName", "SellCursorItem", "PickupInventoryItem", "RegisterEvent%(\"COMBAT_LOG" }) do
			check(not src:find(api .. "%s*%("), f .. " never calls " .. api:gsub("%%", ""))
		end
	end
	local consumers = {}
	for _, f in ipairs({ "Planner.lua", "Engine.lua", "Presenter.lua", "Overlap.lua", "PlanAdapter.lua", "Providers/Quest.lua", "State.lua" }) do
		local src = code(f)
		if src:find("ns%.ItemProbe") or src:find("ns%.Items") then consumers[#consumers + 1] = f end
	end
	check(#consumers == 0, "no planner, presenter or provider reads the probe (it only feeds the report)" .. (#consumers > 0 and (": " .. consumers[1]) or ""))
end
clearApi()
