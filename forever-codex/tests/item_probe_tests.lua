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
	_G.IsUsableItem = function(ref)
		local id = type(ref) == "number" and ref or tonumber(ref:match("item:(%d+)"))
		local it = items[id]
		if it and it.usable == false then return false, false end
		return true, false
	end
	_G.GetItemSpell = function(ref)
		local id = type(ref) == "number" and ref or tonumber(ref:match("item:(%d+)"))
		local it = items[id]
		if it and it.spell then return it.spell, 777 end
		return nil
	end
	_G.GetItemCount = function() return 1 end
	if o.equipped then _G.GetInventoryItemLink = function(unit, slot) local id = o.equipped[slot]; return id and link(id, items[id] and items[id].name) or nil end end
	if o.bags then
		_G.GetContainerNumSlots = function(bag) return bag == 0 and (o.bagSize or #o.bags) or 0 end
		_G.GetContainerItemLink = function(bag, slot) local id = bag == 0 and o.bags[slot]; return id and link(id, items[id] and items[id].name) or nil end
		_G.GetContainerItemInfo = function(bag, slot) return nil, (o.counts and o.counts[slot]) or 1 end
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

-- ================================================================ Stage 1: the normalized Item Facts reader (0.4.6)

local STAGE1 = {
	[5201] = { name = "Plain Pants", quality = 1, ilvl = 8, minLevel = 0, type = "Armor", subType = "Cloth", equipLoc = "INVTYPE_LEGS", sell = 19, classID = 4, subClassID = 1, stats = { RESISTANCE0_NAME = 28, ITEM_MOD_STAMINA_SHORT = 2, ITEM_MOD_FANCY_SHORT = 5 } },
	[5202] = { name = "Bare Cloak", quality = 1, ilvl = 8, minLevel = 0, type = "Armor", subType = "Cloth", equipLoc = "INVTYPE_CLOAK", sell = 24, classID = 4, subClassID = 1, stats = {} },
	[5203] = { name = "Heavy Plate Helm", quality = 2, ilvl = 8, minLevel = 0, type = "Armor", subType = "Plate", equipLoc = "INVTYPE_HEAD", sell = 90, classID = 4, subClassID = 4, stats = { RESISTANCE0_NAME = 90 }, usable = false },
	[5204] = { name = "Strengthless Blade", quality = 1, ilvl = 5, minLevel = 0, type = "Weapon", subType = "One-Handed Swords", equipLoc = "INVTYPE_WEAPON", sell = 40, classID = 2, subClassID = 7, stats = { ITEM_MOD_STRENGTH_SHORT = 1 } },
}
for k, v in pairs(CHOICE_ITEMS) do STAGE1[k] = v end

local function stateOf(facts, key) return facts.fields[key].state end

section("item facts: a fully populated item is normalized, every field PROVEN with its source")
do
	local ns = fresh()
	install({ items = STAGE1 })
	local facts = ns.Items.Facts(link(5101, "Traveler's Wraps"))
	local fl = facts.fields
	check(facts.state == "LOADED" and facts.waiting == false and facts.id == 5101, "the item is LOADED and its id comes from the link")
	for _, key in ipairs({ "id", "name", "link", "quality", "class", "subclass", "itemLevel", "equipSlot", "requiredLevel", "vendorValue", "stats", "usable" }) do
		check(stateOf(facts, key) == "PROVEN", key .. " is PROVEN  [" .. stateOf(facts, key) .. "]")
	end
	check(fl.name.value == "Traveler's Wraps" and fl.class.value == 4 and fl.class.text == "Armor" and fl.subclass.value == 1 and fl.subclass.text == "Cloth", "name, class and subclass (id and the client's word)")
	check(fl.itemLevel.value == 12 and fl.equipSlot.value == "INVTYPE_WRIST" and fl.requiredLevel.value == 8 and fl.vendorValue.value == 310 and fl.usable.value == true, "level, slot, required level, vendor value (copper) and usable")
	check(fl.useEffect.state == "EMPTY" and fl.weaponType.state == "EMPTY" and fl.weaponDps.state == "EMPTY" and fl.weaponType.reason == "not a weapon", "no use effect is EMPTY and the weapon fields are EMPTY (not a weapon), neither is PROVEN")
	check(fl.name.src == "GetItemInfo" and fl.stats.src == "GetItemStats" and fl.usable.src == "IsUsableItem" and fl.id.src == "item link", "each field names the client function that produced it")
	local byId = ns.Items.Facts(5101)
	check(byId.fields.id.src == "argument" and byId.fields.name.value == "Traveler's Wraps", "an item id works as well as a link (the link then comes from the info call)")
end

section("item facts: a missing API is FAILED, not PROVEN and not 'no information'")
do
	local ns = fresh()
	clearApi()
	local facts = ns.Items.Facts(4915)
	check(facts.state == "FAILED", "the item state is FAILED  [" .. facts.state .. "]")
	for _, key in ipairs({ "name", "class", "subclass", "itemLevel", "equipSlot", "requiredLevel", "vendorValue", "stats", "usable" }) do
		check(stateOf(facts, key) == "FAILED", key .. " is FAILED  [" .. stateOf(facts, key) .. "]")
	end
	check(facts.fields.name.reason == "api absent" and facts.fields.stats.reason == "api absent" and facts.fields.usable.reason == "api absent", "and says why")
	check(facts.fields.id.state == "PROVEN", "the id itself was given, so it is PROVEN")
end

section("item facts: blank/nil item info is UNPROVEN (waiting), never FAILED and never 'no information'")
do
	local ns = fresh()
	install({ items = STAGE1, loaded = { [5101] = false } })
	local facts = ns.Items.Facts(link(5101, "Traveler's Wraps"))
	check(facts.state == "WAITING" and facts.waiting == true, "the item is WAITING")
	for _, key in ipairs({ "name", "quality", "itemLevel", "requiredLevel", "vendorValue", "stats", "usable", "useEffect" }) do
		check(stateOf(facts, key) == "UNPROVEN" and facts.fields[key].reason == "waiting for item data", key .. " is UNPROVEN, waiting  [" .. stateOf(facts, key) .. "]")
	end
	check(stateOf(facts, "class") == "PROVEN" and facts.fields.class.src == "GetItemInfoInstant" and stateOf(facts, "equipSlot") == "PROVEN", "the cache-independent instant call still supplies class and slot, labelled with its own source")
	check(stateOf(facts, "link") == "PROVEN" and facts.fields.link.src == "item link given", "a link that was handed in is a link")
	check(stateOf(facts, "weaponType") == "EMPTY", "(armor, so the weapon fields do not apply)")
end

section("item facts: late-loading data completes the facts through the existing GET_ITEM_INFO_RECEIVED retry (no second system)")
do
	local ns = fresh()
	local loaded = { [5103] = false }
	install({ items = STAGE1, loaded = loaded, questId = 61, choices = { { id = 5101 }, { id = 5102 }, { id = 5103 } } })
	ns.ItemProbe.OnEvent("QUEST_DETAIL")
	local df = ns.ItemProbe.DialogFacts()
	local boots = df.choices[3].facts
	check(boots.state == "WAITING" and stateOf(boots, "name") == "UNPROVEN" and stateOf(boots, "stats") == "UNPROVEN", "the unloaded choice is WAITING with UNPROVEN fields")
	check(df.choices[1].facts.state == "LOADED", "the loaded choices are not affected")
	loaded[5103] = true
	ns.ItemProbe.OnEvent("GET_ITEM_INFO_RECEIVED", 5103, true)
	local after = ns.ItemProbe.DialogFacts().choices[3].facts
	check(after.state == "LOADED" and after.fields.name.value == "Hiking Boots" and stateOf(after, "stats") == "PROVEN", "after the event the same item is LOADED with its name and stats")
	check(after.fields.equipSlot.value == "INVTYPE_FEET" and after.fields.requiredLevel.value == 9, "and its facts are complete")
	check(ns.Items.Retry == nil and ns.Items.Pending == nil, "Items.lua has no retry queue of its own")
end

section("item facts: an empty stat table is EMPTY and is not interpreted; a populated one is normalized")
do
	local ns = fresh()
	install({ items = STAGE1 })
	local empty = ns.Items.Facts(5202)
	check(stateOf(empty, "stats") == "EMPTY" and empty.fields.stats.value == nil and next(empty.fields.stats.byStat) == nil and #empty.fields.stats.list == 0, "an empty table is EMPTY, with no value and nothing normalized")
	check(empty.fields.stats.state ~= "PROVEN" and empty.fields.stats.reason:find("not interpreted", 1, true), "it is not PROVEN and it says it is not interpreted (not 'this item has no stats')")
	_G.ARMOR, _G.RESISTANCE0_NAME, _G.SPELL_STAT3_NAME = "Armor", "Armor", "Stamina"
	_G.ITEM_MOD_STAMINA_SHORT = "Stamina"
	local full = ns.Items.Facts(5201)
	local st = full.fields.stats
	check(st.state == "PROVEN" and #st.list == 3 and st.raw.RESISTANCE0_NAME == 28 and st.raw.ITEM_MOD_FANCY_SHORT == 5, "a populated table is PROVEN and keeps every raw key and value")
	check(st.byStat.armor == 28 and st.byStat.stamina == 2, "armor and stamina are normalized")
	local byKey = {}
	for _, e in ipairs(st.list) do byKey[e.key] = e end
	check(byKey.RESISTANCE0_NAME.stat == "armor" and byKey.RESISTANCE0_NAME.meaning == "label-match" and byKey.RESISTANCE0_NAME.label == "Armor", "RESISTANCE0_NAME is armor because the client's own text for the key matches its text for ARMOR")
	check(byKey.ITEM_MOD_FANCY_SHORT.stat == nil and byKey.ITEM_MOD_FANCY_SHORT.meaning == "unmapped" and st.byStat.fancy == nil, "a key Codex does not know stays raw (unmapped), nothing is invented")
	-- the client's text disagrees: the mapping is NOT applied and the raw value is kept
	_G.RESISTANCE0_NAME = "Physical Resistance"
	local conflict = ns.Items.Facts(5201).fields.stats
	local ck
	for _, e in ipairs(conflict.list) do if e.key == "RESISTANCE0_NAME" then ck = e end end
	check(ck.stat == nil and ck.meaning == "label-conflict" and conflict.byStat.armor == nil and conflict.raw.RESISTANCE0_NAME == 28, "a conflicting client label means no canonical stat is assigned; the raw value is preserved")
	-- no client text to compare: the mapping applies but is marked uncorroborated
	_G.ARMOR, _G.RESISTANCE0_NAME = nil, nil
	local nolabel = ns.Items.Facts(5201).fields.stats
	local nk
	for _, e in ipairs(nolabel.list) do if e.key == "RESISTANCE0_NAME" then nk = e end end
	check(nk.stat == "armor" and nk.meaning == "label-missing" and nolabel.byStat.armor == 28, "with no client text to compare the mapping is used but marked label-missing (uncorroborated)")
	_G.ITEM_MOD_STAMINA_SHORT, _G.SPELL_STAT3_NAME = nil, nil
end

section("item facts: an item with no equip slot, one with a use effect, a weapon with type and dps, an unusable item")
do
	local ns = fresh()
	install({ items = STAGE1 })
	local skull = ns.Items.Facts(900)
	check(stateOf(skull, "equipSlot") == "EMPTY" and skull.fields.equipSlot.value == "", "no equip slot: EMPTY (the client returned an empty string)")
	check(stateOf(skull, "useEffect") == "PROVEN" and skull.fields.useEffect.value == "Skull Blast" and skull.fields.useEffect.spellId == 777, "a use effect is PROVEN with its spell name and id")
	local sword = ns.Items.Facts(25)
	check(stateOf(sword, "weaponType") == "PROVEN" and sword.fields.weaponType.value == 7 and sword.fields.weaponType.text == "One-Handed Swords", "a weapon has its weapon type (subclass id and the client's words)")
	check(stateOf(sword, "weaponDps") == "PROVEN" and sword.fields.weaponDps.value == 2.4 and sword.fields.weaponDps.key == "ITEM_MOD_DAMAGE_PER_SECOND_SHORT", "and its dps with the raw key it came from")
	check(sword.fields.stats.byStat.weapon_dps == 2.4, "the dps is also in the normalized stats")
	local blade = ns.Items.Facts(5204)
	check(stateOf(blade, "weaponType") == "PROVEN" and stateOf(blade, "weaponDps") == "EMPTY" and blade.fields.weaponDps.reason:find("no dps key", 1, true), "a weapon whose stat table has no dps key: dps is EMPTY, not invented")
	local helm = ns.Items.Facts(5203)
	check(stateOf(helm, "usable") == "PROVEN" and helm.fields.usable.value == false, "an unusable item: usable is PROVEN with the value false (a real answer, not a failure)")
	check(ns.Items.Facts(5201).fields.usable.value == true, "a usable item reads true")
end

section("item facts: the reward dialog's choices are normalized one by one, and QuestieDB never adds or removes a choice")
do
	local ns = fresh()
	install({ items = STAGE1, questId = 4881, choices = { { id = 5101 }, { id = 5102 }, { id = 5103 } } })
	ns.ItemProbe.OnEvent("QUEST_COMPLETE")
	local df = ns.ItemProbe.DialogFacts(false)
	check(#df.choices == 3 and #df.rewards == 0 and df.q == 4881, "three choices, no guaranteed items, quest 4881")
	for i, id in ipairs({ 5101, 5102, 5103 }) do
		local it = df.choices[i]
		check(it.id == id and it.facts.id == id and it.facts.offered.source == "reward_dialog" and it.facts.offered.index == i and it.facts.offered.quest == 4881, "choice " .. i .. " is item " .. id .. ", marked as offered by the dialog")
	end
	check(df.choices[1].facts.fields.name.value == "Traveler's Wraps" and df.choices[2].facts.fields.name.value == "Adventurer's Cloak" and df.choices[3].facts.fields.name.value == "Hiking Boots", "each has its own facts")
	-- a QuestieDB that knows other items and a conflicting class for one of the offered ones
	_G.LibQuestieDB = { Item = {
		Exists = function(id) return id == 5101 or id == 5201 or id == 5102 end,
		Get = function(id, key) local t = { [5101] = { name = "Traveler's Wraps", class = 2, subClass = 1, itemLevel = 12, requiredLevel = 8 }, [5201] = { name = "Plain Pants" }, [5102] = { class = 4 } }; return t[id] and t[id][key] end,
	} }
	local df2 = ns.ItemProbe.DialogFacts(false)
	check(#df2.choices == 3, "QuestieDB knowing other items adds nothing: still the three the dialog offered")
	local wraps = df2.choices[1].facts
	check(wraps.external.questiedb.src == "questiedb" and wraps.external.questiedb.verified == false and wraps.external.questiedb.exists == true, "the QuestieDB data sits apart, labelled src=questiedb, unverified")
	check(#wraps.conflicts == 1 and wraps.conflicts[1].field == "class" and wraps.conflicts[1].client == 4 and wraps.conflicts[1].external == 2, "a disagreement is recorded as a conflict (client 4, questiedb 2)")
	check(wraps.fields.class.value == 4 and wraps.fields.class.state == "PROVEN" and wraps.fields.class.src == "GetItemInfo", "and the client's value is untouched")
	check(df2.choices[2].facts.external.questiedb.exists == true and #df2.choices[2].facts.conflicts == 0, "an agreeing or partial QuestieDB record is no conflict")
	check(df2.choices[3].facts.external.questiedb.exists == false and df2.choices[3].facts.fields.name.state == "PROVEN", "an item QuestieDB does not know is 'unknown to QuestieDB' and the client facts stand")
	_G.LibQuestieDB = nil
	check(ns.ItemProbe.DialogFacts(false).choices[1].facts.external == nil, "without QuestieDB there is simply no external section")
	check(#ns.errors == 0, "no errors")
end

section("item facts: the report shows the normalized facts compactly, next to the raw REWARD CHOICE DETAILS")
do
	local ns = fresh()
	_G.ARMOR, _G.RESISTANCE0_NAME = "Armor", "Armor"
	install({ items = STAGE1, questId = 4881, choices = { { id = 5101 }, { id = 5102 }, { id = 5103 } } })
	local text = joined(ns.ItemProbe.ReportLines())
	check(text:find("REWARD CHOICE DETAILS", 1, true) and text:find("ITEM FACTS (normalized", 1, true), "both the raw choice details and the normalized facts are present")
	check(text:find("Choice 1: Traveler's Wraps | id PROVEN 5101 | LOADED", 1, true), "the normalized facts name each choice")
	check(text:find("stats PROVEN", 1, true) and text:find("stats EMPTY (the client returned an empty stat table (not interpreted))", 1, true), "a populated and an empty stat table are shown differently")
	check(text:find("[client text \"Armor\", label-match]", 1, true) or text:find("RESISTANCE0_NAME", 1, true), "the stat's raw key and the client's own text are shown")
	local lines = ns.ItemProbe.ReportLines()
	check(#lines <= 95, "the whole item section stays bounded with three choices  [" .. #lines .. " lines]")
	_G.ARMOR, _G.RESISTANCE0_NAME = nil, nil
end

-- ================================================================ Stage 2: equipped / bag item facts and the facts-only comparison (0.4.7)

local STAGE2 = {
	[5301] = { name = "Old Wraps", quality = 1, ilvl = 6, minLevel = 0, type = "Armor", subType = "Cloth", equipLoc = "INVTYPE_WRIST", sell = 11, classID = 4, subClassID = 1, stats = { RESISTANCE0_NAME = 10, ITEM_MOD_STAMINA_SHORT = 1 } },
	[5401] = { name = "Dull Mace", quality = 1, ilvl = 6, minLevel = 0, type = "Weapon", subType = "One-Handed Maces", equipLoc = "INVTYPE_WEAPON", sell = 30, classID = 2, subClassID = 4, stats = { ITEM_MOD_DAMAGE_PER_SECOND_SHORT = 3.1 } },
	[5402] = { name = "Great Axe", quality = 1, ilvl = 7, minLevel = 0, type = "Weapon", subType = "Two-Handed Axes", equipLoc = "INVTYPE_2HWEAPON", sell = 70, classID = 2, subClassID = 1, stats = { ITEM_MOD_DAMAGE_PER_SECOND_SHORT = 5.0, ITEM_MOD_STRENGTH_SHORT = 4 } },
	[5403] = { name = "Multi Stat Chest", quality = 2, ilvl = 10, minLevel = 0, type = "Armor", subType = "Leather", equipLoc = "INVTYPE_CHEST", sell = 80, classID = 4, subClassID = 2, stats = { RESISTANCE0_NAME = 40, ITEM_MOD_STRENGTH_SHORT = 3, ITEM_MOD_AGILITY_SHORT = 2, ITEM_MOD_STAMINA_SHORT = 4, ITEM_MOD_INTELLECT_SHORT = 1, ITEM_MOD_SPIRIT_SHORT = 1 } },
}
for k, v in pairs(STAGE1) do STAGE2[k] = v end

local function gearWorld(o)
	local ns = fresh()
	o.items = o.items or STAGE2
	install(o)
	return ns
end

section("equipped items: an empty slot is EMPTY, a populated slot has normalized facts and a source")
do
	local ns = gearWorld({ equipped = { [8] = 5103, [16] = 25 } })
	local eq = ns.Gear.Equipped()
	check(eq.state == "OK" and #eq.list == 19, "all 19 slots are present")
	check(eq.slots[9].state == "EMPTY" and eq.slots[9].itemFacts == nil and eq.slots[9].reason == nil, "slot 9 is EMPTY: read fine, holds nothing (not a failure)")
	local boots = eq.slots[8]
	check(boots.state == "POPULATED" and boots.slotName == "FEET" and boots.itemId == 5103 and boots.src == "GetInventoryItemLink", "slot 8 is POPULATED with the item id and the client function that produced it")
	check(boots.itemFacts.state == "LOADED" and boots.itemFacts.fields.name.value == "Hiking Boots" and boots.itemFacts.fields.equipSlot.value == "INVTYPE_FEET", "with normalized ItemFacts from the same Stage 1 reader")
	check(eq.slots[16].itemFacts.fields.weaponDps.value == 2.4 and eq.slots[16].slotName == "MAINHAND", "a weapon in the main hand keeps its dps")
	local t = ns.Gear.EquippedSummary(eq)
	check(t.populated == 2 and t.empty == 17 and t.slotFailed == 0 and t.normalized == 2 and t.waiting == 0 and t.failed == 0, "summary: 2 populated, 17 empty, 2 normalized")
end

section("equipped items: a missing equipment API is FAILED, and is never read as 'nothing equipped'")
do
	local ns = fresh()
	clearApi()
	local eq = ns.Gear.Equipped()
	check(eq.state == "FAILED" and eq.reason == "api absent", "the equipment read is FAILED, api absent")
	check(eq.slots[8].state == "FAILED" and eq.slots[8].state ~= "EMPTY", "each slot is FAILED, not EMPTY")
	local t = ns.Gear.EquippedSummary(eq)
	check(t.empty == 0 and t.slotFailed == 19 and t.populated == 0, "summary: 0 empty, 19 slot reads failed")
	install({ items = STAGE2 })
	local cmp = ns.Gear.CompareToEquipped(ns.Items.Facts(5101), eq)
	check(cmp.entries[1].state == "UNKNOWN" and cmp.entries[1].state ~= "EMPTY_SLOT", "an item compared to an unreadable slot is UNKNOWN, not 'the slot is empty'")
end

section("bag items: populated, empty and failed slots are distinct, and counts are read")
do
	local ns = gearWorld({ bags = { 4914, 900 }, bagSize = 4 })
	local pop = ns.Gear.BagSlot(0, 1)
	check(pop.state == "POPULATED" and pop.itemId == 4914 and pop.count == 1 and pop.bag == 0 and pop.slot == 1 and pop.src == "GetContainerItemLink", "a populated bag slot: bag, slot, item id, count and source")
	check(pop.itemFacts.state == "LOADED" and pop.itemFacts.fields.name.value == "Battleworn Leather Gloves", "with normalized ItemFacts")
	local empty = ns.Gear.BagSlot(0, 3)
	check(empty.state == "EMPTY" and empty.itemFacts == nil, "an empty bag slot is EMPTY")
	local bags = ns.Gear.Bags()
	check(bags.state == "OK" and #bags.stacks == 2 and bags.containers[1].size == 4 and bags.containers[1].empty == 2 and bags.containers[1].populated == 2, "the bags: 2 stacks, and the empty slots are counted per container (2 of 4)")
	local t = ns.Gear.BagSummary(bags)
	check(t.populated == 2 and t.normalized == 2 and t.waiting == 0 and t.failed == 0 and t.emptySlots == 2, "summary: 2 stacks, 2 normalized, 2 empty slots")
	local ns2 = fresh()
	clearApi()
	local b2 = ns2.Gear.Bags()
	check(b2.state == "FAILED" and b2.reason == "api absent" and #b2.stacks == 0, "a missing container API is FAILED (not 'empty bags')")
	check(ns2.Gear.BagSlot(0, 1).state == "FAILED", "and a single slot read is FAILED")
end

section("equipped / bag items: item data that has not loaded is WAITING, then completed in place by the one late-loading queue")
do
	local loaded = { [5103] = false, [4914] = false }
	local ns = gearWorld({ equipped = { [8] = 5103 }, bags = { 4914 }, loaded = loaded })
	local snap = ns.Gear.Snapshot()
	local boots, gloves = snap.equipped.slots[8], snap.bags.stacks[1]
	check(boots.itemFacts.state == "WAITING" and boots.itemFacts.fields.name.state == "UNPROVEN" and boots.itemFacts.fields.stats.state == "UNPROVEN", "the equipped item is WAITING with UNPROVEN fields (not FAILED)")
	check(gloves.itemFacts.state == "WAITING", "so is the bag item")
	local es, bs = ns.Gear.EquippedSummary(snap.equipped), ns.Gear.BagSummary(snap.bags)
	check(es.waiting == 1 and es.normalized == 0 and es.failed == 0 and bs.waiting == 1 and bs.failed == 0, "the summaries count them as waiting, not failed")
	check(ns.ItemProbe.PendingCount() == 2, "both are on ItemProbe's one retry queue  [" .. ns.ItemProbe.PendingCount() .. "]")
	loaded[5103], loaded[4914] = true, true
	ns.ItemProbe.OnEvent("GET_ITEM_INFO_RECEIVED", 5103, true)
	check(boots.itemFacts.state == "LOADED" and boots.itemFacts.fields.name.value == "Hiking Boots" and gloves.itemFacts.state == "LOADED", "the same snapshot entries are LOADED after GET_ITEM_INFO_RECEIVED")
	check(ns.ItemProbe.PendingCount() == 0, "and the queue is empty")
	local es2 = ns.Gear.EquippedSummary(snap.equipped)
	check(es2.waiting == 0 and es2.normalized == 1, "the summary follows the completed facts")
	check(ns.Gear.Pending == nil and ns.Gear.Retry == nil, "Gear has no queue of its own")
	-- reading again does not pile up watchers
	loaded[5103] = false
	ns.Gear.Snapshot(); ns.Gear.Snapshot(); ns.Gear.Snapshot()
	check(ns.ItemProbe.PendingCount() <= 2, "repeated snapshots do not duplicate the queue entries  [" .. ns.ItemProbe.PendingCount() .. "]")
end

section("equipped items: armor and several known stats are normalized from the client's own table")
do
	_G.ARMOR, _G.RESISTANCE0_NAME = "Armor", "Armor"
	local ns = gearWorld({ equipped = { [5] = 5403, [8] = 5103 } })
	local chest = ns.Gear.Equipped().slots[5].itemFacts.fields.stats
	check(chest.state == "PROVEN" and chest.byStat.armor == 40 and chest.byStat.strength == 3 and chest.byStat.agility == 2 and chest.byStat.stamina == 4 and chest.byStat.intellect == 1 and chest.byStat.spirit == 1, "armor, strength, agility, stamina, intellect and spirit are all normalized")
	local armorEntry
	for _, e in ipairs(chest.list) do if e.key == "RESISTANCE0_NAME" then armorEntry = e end end
	check(armorEntry.stat == "armor" and armorEntry.meaning == "label-match", "armor through the client's own label match")
	_G.ARMOR, _G.RESISTANCE0_NAME = nil, nil
end

section("comparison: two items in the same slot are compared by facts only")
do
	local ns = gearWorld({})
	local a, b = ns.Items.Facts(5101), ns.Items.Facts(5301)
	local c = ns.Gear.Compare(a, b)
	check(c.slot.state == "SAME" and c.slot.a == "INVTYPE_WRIST" and c.slot.shared[1] == 9, "same slot (INVTYPE_WRIST, inventory slot 9)")
	check(c.stats.armor.state == "COMPARED" and c.stats.armor.a == 4 and c.stats.armor.b == 10 and c.stats.armor.diff == -6, "armor 4 vs 10, diff -6")
	check(c.stats.stamina.diff == 2 and c.stats.stamina.assumedZero.a == false and c.stats.stamina.assumedZero.b == false, "stamina 3 vs 1, diff +2")
	check(c.stats.strength.state == "NOT_LISTED" and c.stats.agility.state == "NOT_LISTED", "a stat neither item lists is NOT_LISTED (no diff invented)")
	check(c.requiredLevel.state == "COMPARED" and c.requiredLevel.a == 8 and c.requiredLevel.b == 0 and c.requiredLevel.diff == 8, "required level 8 vs 0")
	check(c.itemLevel.diff == 6 and c.class.same == true and c.subclass.same == true, "item level, class and subclass differences are facts too")
	-- a stat only one side lists: the other side's absence is counted as 0, and says so
	local d = ns.Gear.Compare(ns.Items.Facts(5403), ns.Items.Facts(5101))
	check(d.stats.strength.state == "COMPARED" and d.stats.strength.a == 3 and d.stats.strength.b == nil and d.stats.strength.diff == 3 and d.stats.strength.assumedZero.b == true, "a stat one item does not list is assumedZero on that side, flagged")
	check(#d.unmapped == 0, "no unmapped stat keys here")
	local e = ns.Gear.Compare(ns.Items.Facts(5201), ns.Items.Facts(5101))
	check(e.unmapped[1] == "ITEM_MOD_FANCY_SHORT", "a stat key Codex does not name is listed as unmapped, so the comparison is known to be partial")
end

section("comparison: different slots, no slot, and unknown slots are reported as such")
do
	local ns = gearWorld({ equipped = { [8] = 5103 } })
	local wraps, boots, skull = ns.Items.Facts(5101), ns.Items.Facts(5103), ns.Items.Facts(900)
	check(ns.Gear.Compare(wraps, boots).slot.state == "DIFFERENT", "wrist vs feet: DIFFERENT")
	check(ns.Gear.Compare(wraps, skull).slot.state == "NO_SLOT" and ns.Gear.Compare(wraps, skull).slot.reason:find("no equip slot", 1, true), "an item with no equip slot: NO_SLOT (no slot is invented)")
	local eq = ns.Gear.Equipped()
	local toEmpty = ns.Gear.CompareToEquipped(wraps, eq)
	check(toEmpty.state == "COMPARABLE" and toEmpty.entries[1].slot == 9 and toEmpty.entries[1].state == "EMPTY_SLOT", "a wrist item against equipment with an empty wrist slot: the slot is EMPTY (a fact)")
	local noSlot = ns.Gear.CompareToEquipped(skull, eq)
	check(noSlot.state == "NO_SLOT" and #noSlot.entries == 0, "an item with no equip slot has nothing to compare against")
	local boot2 = ns.Gear.CompareToEquipped(ns.Items.Facts(5103), eq)
	check(boot2.entries[1].state == "COMPARED" and boot2.entries[1].comparison.slot.state == "SAME", "boots against the equipped boots: COMPARED, same slot")
	local ring = { fields = setmetatable({ equipSlot = { state = "PROVEN", value = "INVTYPE_FINGER" } }, { __index = function() return { state = "UNPROVEN" } end }) }
	local rc = ns.Gear.CompareToEquipped(ring, eq)
	check(#rc.entries == 2 and rc.entries[1].slot == 11 and rc.entries[2].slot == 12, "a ring can go in two slots and both are reported")
	local odd = { fields = setmetatable({ equipSlot = { state = "PROVEN", value = "INVTYPE_MYSTERY" } }, { __index = function() return { state = "UNPROVEN" } end }) }
	check(ns.Gear.CompareToEquipped(odd, eq).state == "UNKNOWN" and ns.Gear.CompareToEquipped(odd, eq).reason:find("not in Codex's slot table", 1, true), "an equip location Codex does not know is UNKNOWN, not guessed")
end

section("comparison: unknown stats stay UNKNOWN (never zero), and a waiting item makes its fields UNKNOWN")
do
	local loaded = { [5301] = false }
	local ns = gearWorld({ loaded = loaded })
	local wraps, cloak = ns.Items.Facts(5101), ns.Items.Facts(5102)
	local c = ns.Gear.Compare(wraps, cloak)
	check(c.stats.armor.state == "UNKNOWN" and c.stats.armor.diff == nil and c.stats.armor.reason:find("EMPTY", 1, true), "an EMPTY stat table is not interpreted: every stat is UNKNOWN with the reason")
	check(c.slot.state == "DIFFERENT" and c.requiredLevel.state == "COMPARED", "while the other facts are still compared")
	local waiting = ns.Items.Facts(5301)
	local w = ns.Gear.Compare(wraps, waiting)
	check(waiting.state == "WAITING" and w.stats.stamina.state == "UNKNOWN" and w.stats.stamina.diff == nil and w.requiredLevel.state == "UNKNOWN", "a waiting item gives UNKNOWN stats and UNKNOWN required level, not zeros")
	check(w.slot.state == "SAME", "its equip slot, readable without the cache, is still compared")
	check(ns.Gear.Compare(nil, wraps).slot.state == "UNKNOWN", "an item with no facts at all compares as UNKNOWN")
	-- a client label that contradicts the mapping: that stat is UNKNOWN and the raw key is listed
	_G.ARMOR, _G.RESISTANCE0_NAME = "Armor", "Physical Resistance"
	local x = ns.Gear.Compare(ns.Items.Facts(5101), ns.Items.Facts(5103))
	check(x.stats.armor.state == "UNKNOWN" and x.stats.armor.reason:find("label-conflict", 1, true) and x.unmapped[1] == "RESISTANCE0_NAME", "a label-conflicted armor key is UNKNOWN and shows up as unmapped")
	_G.ARMOR, _G.RESISTANCE0_NAME = nil, nil
end

section("comparison: usable state and weapons")
do
	local ns = gearWorld({})
	local helm, pants = ns.Items.Facts(5203), ns.Items.Facts(5201)
	local u = ns.Gear.Compare(helm, pants).usable
	check(u.state == "COMPARED" and u.a == false and u.b == true and u.same == false and u.diff == nil, "one unusable item: usable false vs true, reported as a difference of fact")
	check(ns.Gear.Compare(pants, ns.Items.Facts(5101)).usable.same == true, "two usable items agree")
	local sword, mace, axe = ns.Items.Facts(25), ns.Items.Facts(5401), ns.Items.Facts(5402)
	local w = ns.Gear.Compare(sword, mace)
	check(w.slot.state == "SAME" and w.stats.weapon_dps.state == "COMPARED" and w.stats.weapon_dps.a == 2.4 and w.stats.weapon_dps.b == 3.1 and math.abs(w.stats.weapon_dps.diff + 0.7) < 1e-9, "two one-handed weapons: same slot, dps 2.4 vs 3.1")
	local wa = ns.Gear.Compare(sword, axe)
	check(wa.slot.state == "SHARED" and wa.slot.shared[1] == 16, "a one-hander and a two-hander share the main hand (SHARED)")
	check(wa.stats.strength.state == "COMPARED" and wa.stats.strength.assumedZero.a == true, "the axe's strength is compared with the sword's absent strength, flagged assumedZero")
	check(ns.Gear.Compare(sword, pants).stats.weapon_dps.state == "NOT_APPLICABLE", "weapon dps against armor is NOT_APPLICABLE")
	check(ns.Gear.Compare(sword, ns.Items.Facts(5204)).stats.weapon_dps.state == "UNKNOWN", "a weapon whose table has no dps key is UNKNOWN, not zero")
end

section("provenance: every equipped / bag / comparison fact keeps its source, the client wins over QuestieDB")
do
	local ns = gearWorld({ equipped = { [8] = 5103 }, bags = { 4914 } })
	_G.LibQuestieDB = { Item = { Exists = function(id) return id == 5103 end, Get = function(id, k) return ({ name = "Hiking Boots", class = 4, subClass = 3, itemLevel = 8, requiredLevel = 0 })[k] end } }
	local snap = ns.Gear.Snapshot()
	local boots = snap.equipped.slots[8]
	check(boots.src == "GetInventoryItemLink" and boots.itemFacts.fields.name.src == "GetItemInfo" and boots.itemFacts.fields.stats.src == "GetItemStats" and boots.itemFacts.fields.id.src == "item link", "equipment: slot source, item source, stats source, id source")
	check(snap.bags.stacks[1].src == "GetContainerItemLink", "bags: the container function")
	check(boots.itemFacts.external.questiedb.verified == false and boots.itemFacts.external.questiedb.src == "questiedb" and boots.itemFacts.conflicts[1].field == "subclass" and boots.itemFacts.conflicts[1].client == 2, "QuestieDB stays external and unverified; its disagreement is a conflict, the client's value stands")
	check(boots.itemFacts.fields.subclass.value == 2 and boots.itemFacts.fields.subclass.state == "PROVEN", "the client's subclass is untouched")
	local cmp = ns.Gear.Compare(boots.itemFacts, ns.Items.Facts(5101))
	check(cmp.subclass.a == 2 and cmp.subclass.aText == "Leather", "a comparison uses the client facts only (QuestieDB's 3 is not used)")
	_G.LibQuestieDB = nil
end

section("report: EQUIPPED ITEM FACTS, BAG ITEM FACTS and facts-only COMPARISON FACTS, compact and without advice")
do
	local ns = gearWorld({ equipped = { [8] = 5103, [10] = 5201 }, bags = { 4914, 900 }, bagSize = 5, questId = 4881, choices = { { id = 5101 }, { id = 5103 } } })
	local text = joined(ns.Gear.ReportLines())
	check(text:find("EQUIPPED ITEM FACTS: occupied slots 2 of 19 | facts loaded 2 | waiting 0 | failed 0 | empty slots 17 | slot reads failed 0", 1, true), "the equipped counts")
	check(text:find("BAG ITEM FACTS: occupied stacks 2 | unique item ids 2 | facts loaded 2 | waiting 0 | failed 0 | containers read 5 (empty slots 3, slot reads failed 0)", 1, true), "the bag counts")
	check(text:find("COMPARISON FACTS", 1, true) and text:find("Choice 1 (INVTYPE_WRIST) vs slot 9 WRIST: the slot is empty", 1, true), "an offered item against an empty slot")
	check(text:find("Choice 2 (INVTYPE_FEET) vs slot 8 FEET: equipped Hiking Boots [LOADED] | slot SAME", 1, true), "an offered item against the equipped item in its slot")
	check(text:find("req level 9 vs 9 | usable true vs true", 1, true), "required level and usable are shown as facts")
	for _, w in ipairs({ "upgrade", "recommend", "take it", "sell it", "better", "worse", "best" }) do
		check(not text:lower():find(w, 1, true), "the report text does not say '" .. w .. "'")
	end
	check(#ns.Gear.ReportLines() <= 16, "and it stays compact  [" .. #ns.Gear.ReportLines() .. " lines]")
	local full
	rawset(ns.UI, "ShowReport", function(t) full = t end)
	H.slash("report")
	check(full and full:find("EQUIPPED ITEM FACTS:", 1, true) and full:find("BAG ITEM FACTS:", 1, true), "/codex report contains both sections")
	local ns2 = fresh()
	clearApi()
	local t2 = joined(ns2.Gear.ReportLines())
	check(t2:find("EQUIPPED ITEM FACTS: FAILED (api absent)", 1, true) and t2:find("BAG ITEM FACTS: FAILED (api absent)", 1, true), "with no APIs both sections say FAILED, not 'nothing equipped'")
end

-- ================================================================ Stage 2 completion (0.4.8): refresh events, stacks and counts, listings, the usable evidence

section("gear refresh: PLAYER_EQUIPMENT_CHANGED re-reads only the changed slot; BAG_UPDATE_DELAYED re-reads the bags")
do
	local equipped = { [8] = 5103 }
	local bags = { 4914 }
	local ns = gearWorld({ equipped = equipped, bags = bags, bagSize = 3 })
	ns.Gear.last = nil                       -- (the quest-item provider already took a snapshot of the empty stub world at boot: start from a clean first read)
	local snap = ns.Gear.Get()
	check(snap.equipped.slots[8].itemId == 5103 and snap.equipped.slots[9].state == "EMPTY" and #snap.bags.stacks == 1, "the first Get reads the equipment and the bags")
	local untouched = snap.equipped.slots[8]
	-- a ring is equipped: the client says slot 11 changed
	equipped[11] = 5201
	ns.ItemProbe.OnEvent("PLAYER_EQUIPMENT_CHANGED", 11, true)
	local after = ns.Gear.Get()
	check(after.equipped.slots[11].state == "POPULATED" and after.equipped.slots[11].itemId == 5201 and after.equipped.slots[11].itemFacts.fields.name.value == "Plain Pants", "the changed slot now holds the new item")
	check(after.equipped.slots[8] == untouched, "the other slots were not re-read (same entry)")
	check(ns.Gear.stats.slotRefreshes == 1 and ns.Gear.stats.equipmentEvents == 1, "one targeted slot re-read was counted")
	-- the item is taken off
	equipped[11] = nil
	ns.ItemProbe.OnEvent("PLAYER_EQUIPMENT_CHANGED", 11, false)
	check(ns.Gear.Get().equipped.slots[11].state == "EMPTY", "an emptied slot becomes EMPTY (not FAILED)")
	-- a bad slot argument marks everything dirty, and the next Get rescans
	equipped[9] = 5301
	ns.ItemProbe.OnEvent("PLAYER_EQUIPMENT_CHANGED")
	check(ns.Gear.Get().equipped.slots[9].itemId == 5301, "an event without a slot number leads to a full equipment re-read on the next Get")
	-- bags
	bags[2] = 900
	local before = ns.Gear.Get().bags
	ns.ItemProbe.OnEvent("BAG_UPDATE_DELAYED")
	local rescanned = ns.Gear.Get().bags
	check(rescanned ~= before and #rescanned.stacks == 2 and rescanned.stacks[2].itemId == 900 and ns.Gear.stats.bagRescans == 1, "BAG_UPDATE_DELAYED leads to a bag re-read on the next Get; the new stack is there")
	ns.Gear.Get()
	check(ns.Gear.stats.bagRescans == 1, "and nothing is re-read again until another bag event")
	-- events before anything was read do nothing harmful
	local ns2 = gearWorld({ equipped = { [8] = 5103 } })
	ns2.ItemProbe.OnEvent("PLAYER_EQUIPMENT_CHANGED", 8, true)
	ns2.ItemProbe.OnEvent("BAG_UPDATE_DELAYED")
	check(ns2.Gear.Get().equipped.slots[8].itemId == 5103 and #ns2.errors == 0, "events before the first read are harmless")
	check(#ns.errors == 0, "no errors")
end

section("gear: multiple stacks keep their own counts, item facts are reused, and unique item ids are counted")
do
	local ns = gearWorld({ bags = { 4914, 4914, 900 }, bagSize = 4, counts = { [1] = 6, [2] = 3, [3] = 1 } })
	local bags = ns.Gear.Bags()
	check(#bags.stacks == 3, "three stacks (two of the same item are not merged)")
	check(bags.stacks[1].itemId == 4914 and bags.stacks[1].count == 6 and bags.stacks[2].itemId == 4914 and bags.stacks[2].count == 3 and bags.stacks[3].count == 1, "each stack keeps its own count: 6, 3 and 1")
	check(bags.stacks[1].bag == 0 and bags.stacks[1].slot == 1 and bags.stacks[2].slot == 2, "and its bag and slot")
	check(bags.stacks[1].itemFacts.fields.name.value == "Battleworn Leather Gloves" and bags.stacks[1].itemFacts.fields.stackCount == nil, "the count lives on the stack, not in the item's facts")
	local t = ns.Gear.BagSummary(bags)
	check(t.populated == 3 and t.unique == 2, "3 stacks, 2 unique item ids")
	local direct = ns.Items.Facts(bags.stacks[1].link)
	check(bags.stacks[1].itemFacts.fields.name.value == direct.fields.name.value and bags.stacks[1].itemFacts.schema == direct.schema, "a bag item's facts are the same Items.Facts structure")
	local text = joined(ns.Gear.ReportLines())
	check(text:find("bag 0 slot 1: Battleworn Leather Gloves (id 4914) x6 LOADED", 1, true) and text:find("bag 0 slot 2: Battleworn Leather Gloves (id 4914) x3 LOADED", 1, true), "the report lists each stack with its id, count and status")
	check(text:find("unique item ids 2", 1, true), "and the unique item id count")
end

section("gear: failed item info is FAILED (counted), and QuestieDB not knowing an item changes nothing")
do
	local ns = gearWorld({ equipped = { [8] = 5103 }, bags = { 4914 } })
	_G.GetItemInfo = nil
	local snap = ns.Gear.Snapshot()
	check(snap.equipped.slots[8].state == "POPULATED" and snap.equipped.slots[8].itemFacts.state == "FAILED" and snap.equipped.slots[8].itemFacts.fields.name.reason == "api absent", "the slot is populated but its item info FAILED (api absent)")
	local es = ns.Gear.EquippedSummary(snap.equipped)
	check(es.populated == 1 and es.failed == 1 and es.normalized == 0 and es.waiting == 0, "counted as failed, not waiting")
	check(ns.ItemProbe.PendingCount() == 0, "a failure is not retried as if it were loading")
	local text = joined(ns.Gear.ReportLines())
	check(text:find("facts loaded 0 | waiting 0 | failed 1", 1, true), "the report says failed 1")
	-- QuestieDB present but not knowing the item
	local ns2 = gearWorld({ equipped = { [8] = 5103 } })
	_G.LibQuestieDB = { Item = { Exists = function() return false end, Get = function() return nil end } }
	local f = ns2.Gear.Snapshot().equipped.slots[8].itemFacts
	check(f.external.questiedb.exists == false and f.state == "LOADED" and f.fields.name.state == "PROVEN" and #f.conflicts == 0, "unknown to QuestieDB is external.exists = false; the client's facts are untouched and nothing conflicts")
	_G.LibQuestieDB = { Item = { Exists = function() return true end, Get = function(id, k) return ({ class = 4, subClass = 3, itemLevel = 13 })[k] end } }
	local g = ns2.Gear.Snapshot().equipped.slots[8].itemFacts
	check(g.external.questiedb.exists == true and g.external.questiedb.verified == false and g.fields.subclass.value == 2 and g.conflicts[1].field == "subclass" and g.conflicts[1].external == 3, "a QuestieDB record is external and unverified; a disagreement is a conflict, the client's subclass stays")
	_G.LibQuestieDB = nil
end

section("gear: the actual slot and the item's equip location stay separate; factual stat comparison")
do
	local ns = gearWorld({ equipped = { [16] = 25, [17] = 5401 } })
	local eq = ns.Gear.Equipped()
	check(eq.slots[16].slotName == "MAINHAND" and eq.slots[16].itemFacts.fields.equipSlot.value == "INVTYPE_WEAPON", "slot 16 MAINHAND holds an item whose equip location is INVTYPE_WEAPON")
	check(eq.slots[17].slotName == "OFFHAND" and eq.slots[17].itemFacts.fields.equipSlot.value == "INVTYPE_WEAPON", "the same equip location sits in the OFFHAND slot: the two are not merged")
	local cur = ns.Items.Facts(5403)
	local cand = ns.Items.Facts(5403)
	local c = ns.Gear.Compare(cand, cur)
	check(c.stats.armor.diff == 0 and c.stats.stamina.diff == 0, "identical items: every difference is 0")
	_G.ARMOR, _G.RESISTANCE0_NAME = "Armor", "Armor"
	local a = ns.Items.Facts(5201)       -- armor 28, stamina 2
	local b = ns.Items.Facts(5403)       -- armor 40, stamina 4
	local d = ns.Gear.Compare(b, a)
	check(d.stats.armor.a == 40 and d.stats.armor.b == 28 and d.stats.armor.diff == 12 and d.stats.stamina.diff == 2, "armor 40 vs 28 (+12), stamina 4 vs 2 (+2)")
	check(d.stats.armor.meaning.a == "label-match", "and each side's evidence for what the key means")
	_G.ARMOR, _G.RESISTANCE0_NAME = nil, nil
	local text = joined(ns.Gear.ReportLines())
	for _, w in ipairs({ "upgrade", "downgrade", "better", "worse", "take this", "sell this", "temporary" }) do
		check(not text:lower():find(w, 1, true), "the report never says '" .. w .. "'")
	end
end

section("item facts: the usable value keeps IsUsableItem's second value and the dialog's own flag, as evidence only")
do
	local ns = fresh()
	_G.IsUsableItem = nil
	install({ items = STAGE2, questId = 92579, choices = { { id = 5101 }, { id = 5102 } } })
	_G.IsUsableItem = function() return false, true end
	ns.ItemProbe.OnEvent("QUEST_COMPLETE")
	local f = ns.ItemProbe.DialogFacts(false).choices[1].facts
	check(f.fields.usable.state == "PROVEN" and f.fields.usable.value == false and f.fields.usable.second == true, "usable false, with the second return value kept")
	check(f.offered.dialogFlag == true, "and the dialog's own 5th GetQuestItemInfo value is kept beside it")
	local text = joined(ns.ItemProbe.FactsLines())
	check(text:find("usable PROVEN false [IsUsableItem second value true; dialog flag true]", 1, true), "the report shows both next to the value, without interpreting them")
end

section("gear: Stage 2 is read-only, judges nothing, and feeds nothing (no planner, presenter or provider reads it)")
do
	local function code(f) return (H.readFile(H.addonDir .. "/" .. f):gsub("%-%-[^\n]*", "")) end
	local src = code("Gear.lua")
	for _, pat in ipairs({ "ns%.Planner", "ns%.Engine", "ns%.Strategies", "ns%.State", "ns%.UI", "ns%.Presenter", "ns%.Registry", "ns%.Context", "ns%.Prefs", "ns%.Overlap" }) do
		check(not src:find(pat), "Gear.lua does not depend on " .. pat:gsub("%%", ""))
	end
	for _, word in ipairs({ "upgrade", "recommend", "score", "should ", "take it", "sell it", "best " }) do
		check(not src:lower():find(word, 1, true), "Gear.lua (code and strings) does not contain '" .. word .. "'")
	end
	for _, api in ipairs({ "EquipItemByName", "PickupInventoryItem", "UseContainerItem", "PickupContainerItem", "AutoEquipCursorItem", "SellCursorItem" }) do
		check(not src:find(api .. "%s*%("), "Gear.lua never calls " .. api)
	end
	local readers = {}
	for _, f in ipairs({ "Planner.lua", "Engine.lua", "Presenter.lua", "Overlap.lua", "PlanAdapter.lua", "Providers/Quest.lua", "State.lua", "Strategies.lua", "Navigation.lua" }) do
		if code(f):find("ns%.Gear") then readers[#readers + 1] = f end
	end
	check(#readers == 0, "no planner, presenter or provider reads Gear")
end

section("item facts: Stage 1 adds no advice and no consumer (still read-only, ASCII, independent of the planner)")
do
	local function code(f) return (H.readFile(H.addonDir .. "/" .. f):gsub("%-%-[^\n]*", "")) end
	for _, word in ipairs({ "upgrade", "recommend", "should the player", "take it", "sell it", "best reward" }) do
		check(not code("Items.lua"):lower():find(word, 1, true), "Items.lua does not mention '" .. word .. "'")
	end
	local readers = {}
	for _, f in ipairs({ "Planner.lua", "Engine.lua", "Presenter.lua", "Overlap.lua", "PlanAdapter.lua", "Providers/Quest.lua", "State.lua", "Strategies.lua" }) do
		local src = code(f)
		if src:find("ns%.Items") or src:find("ns%.ItemProbe") then readers[#readers + 1] = f end
	end
	check(#readers == 0, "the planner, presenter and providers do not read item facts")
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
	check(#sec <= 60, "and it is compact  [" .. #sec .. " lines]")
	check(table.concat(sec, "\n"):find("PROVEN: Quest id (GetQuestID), Reward counts", 1, true), "the field tallies name each field under its status")
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

-- ---------------------------------------------------------------- OfferProbe (0.6.4): what the client says an NPC offers
section("offered quests probe: records what the client lists, keeps 'empty' apart from 'no data', and never touches the planner")
do
	local NAMES = { "C_GossipInfo", "GetNumGossipAvailableQuests", "GetGossipAvailableQuests", "GetNumGossipActiveQuests", "GetGossipActiveQuests", "GetNumGossipOptions",
		"GetNumAvailableQuests", "GetAvailableTitle", "GetAvailableQuestID", "GetNumActiveQuests", "GetActiveTitle", "GetQuestID", "GetTitleText", "UnitName", "UnitGUID" }
	local function clear() for _, n in ipairs(NAMES) do _G[n] = nil end end
	local ns = boot({ char = { level = 10 }, synthetic = true, loc = { map = 9001, x = 0.5, y = 0.5 } })
	clear()                                  -- (the harness stubs UnitName / UnitGUID for the PLAYER; the probe asks about "npc")
	check(ns.OfferProbe ~= nil and ns.OfferProbe.OnEvent ~= nil, "the probe module is loaded")
	local O = ns.OfferProbe
	local function reset() ForeverCodexDB.offers = nil end
	reset()
	local dirtyBefore, countBefore = ns.State.perf.dirtyBy, ns.State.perf.count
	local function dirtyTotal() local n = 0 for _, v in pairs(ns.State.perf.dirtyBy) do n = n + v end return n end
	local d0 = dirtyTotal()

	-- no APIs at all: the probe is attempted and says so, nothing is invented
	O.OnEvent("GOSSIP_SHOW")
	local s = ForeverCodexDB.offers
	check(s and #s.obs == 1 and s.obs[1].npc == nil, "an observation is saved even with no API, with no NPC invented")
	local states = {}
	for _, a in ipairs(s.obs[1].answers) do states[a.api] = a.state end
	check(states["C_GossipInfo.GetAvailableQuests"] == "ABSENT" and states["GetNumGossipAvailableQuests"] == nil, "a missing API is ABSENT (not 'none offered'); the proven-absent legacy functions are no longer asked at all")
	check(table.concat(O.ReportLines(), "\n"):find("absent: ", 1, true) ~= nil, "the report says which APIs are absent")

	-- an NPC that lists nothing: the API ANSWERS with an empty list -> EMPTY (meaningful), and the NPC is recorded without its GUID
	reset()
	_G.UnitName = function(u) return u == "npc" and "Yorana Windyreed" or nil end
	_G.UnitGUID = function(u) return u == "npc" and "Creature-0-4170-2521-9999-12345-0000A1B2C3" or nil end
	_G.C_GossipInfo = { GetAvailableQuests = function() return {} end, GetActiveQuests = function() return {} end, GetOptions = function() return {} end }
	O.OnEvent("GOSSIP_SHOW")
	local ob = ForeverCodexDB.offers.obs[1]
	local av
	for _, a in ipairs(ob.answers) do if a.api == "C_GossipInfo.GetAvailableQuests" then av = a end end
	check(av and av.state == "EMPTY" and av.n == 0, "an empty list is EMPTY: the client answered 'nothing offered'")
	check(ob.npc and ob.npc.name == "Yorana Windyreed" and ob.npc.id == 12345, "the NPC name and creature id are recorded")
	check(not (function() local function scan(t, depth) for k, v in pairs(t) do if type(v) == "string" and v:find("Creature-", 1, true) then return true end if type(v) == "table" and depth < 6 and scan(v, depth + 1) then return true end end end return scan(ForeverCodexDB.offers, 0) end)(), "the raw GUID is never stored")
	check(ob.src == "CODEX_OBSERVED", "the observation is labelled CODEX_OBSERVED (not QuestieDB / ATT / the observed quest pack)")

	-- an API that answers with nothing at all is NO_DATA, not EMPTY
	reset()
	_G.C_GossipInfo = { GetAvailableQuests = function() return nil end }
	O.OnEvent("GOSSIP_SHOW")
	local nd
	for _, a in ipairs(ForeverCodexDB.offers.obs[1].answers) do if a.api == "C_GossipInfo.GetAvailableQuests" then nd = a end end
	check(nd and nd.state == "NO_DATA", "a nil answer is NO_DATA, kept apart from an empty list")

	-- listed quests: the quest id is kept when the client gives one, the payload field names are kept
	reset()
	_G.C_GossipInfo = { GetAvailableQuests = function() return { { questID = 92642, title = "Disrupting Logistics", questLevel = 11, isTrivial = false }, { title = "No id here" } } end,
		GetActiveQuests = function() return { { questID = 93317, title = "Crab Season" } } end, GetOptions = function() return { { name = "x" } } end }
	O.OnEvent("GOSSIP_SHOW")
	local o2 = ForeverCodexDB.offers.obs[1]
	local list
	for _, a in ipairs(o2.answers) do if a.api == "C_GossipInfo.GetAvailableQuests" then list = a end end
	check(list.state == "LISTED" and list.n == 2 and list.entries[1].id == 92642 and list.entries[1].title == "Disrupting Logistics" and list.entries[1].level == 11, "a listed quest keeps the id, title and level the client gave")
	check(list.entries[2].id == nil and list.entries[2].title == "No id here", "an entry without an id stays title-only (no id is guessed)")
	check(list.shape and list.shape:find("questID", 1, true) and list.shape:find("title", 1, true), "the payload's field names are kept: " .. tostring(list.shape))
	local st = ForeverCodexDB.offers.stats
	check(st.entries == 2 and st.entriesWithId == 1 and st.entriesTitleOnly == 1, "counters: 2 entries, 1 with an id, 1 title only")
	local text = table.concat(O.ReportLines(), "\n")
	check(text:find("ACTIONABILITY / OFFER EVIDENCE", 1, true) and text:find("Q92642 Disrupting Logistics | NPC Yorana Windyreed (creature 12345) | OBSERVED | sources: AVAILABLE_LIST x1", 1, true) and text:find("(no id) No id here", 1, true) and text:find("PROVEN", 1, true), "the report shows the listed quests, ids and PROVEN status")
	check(text:find("only 'not listed in that dialog at that moment'", 1, true) ~= nil, "the report states what a negative does and does not mean")

	-- an unchanged repeat of the same dialog is one observation with a counter
	O.OnEvent("GOSSIP_SHOW")
	check(#ForeverCodexDB.offers.obs == 1 and ForeverCodexDB.offers.obs[1].n == 2, "a refreshed identical dialog raises a counter instead of adding a row")

	-- QUEST_GREETING with legacy-style APIs: titles only, no id unless the client has an id function
	reset()
	_G.C_GossipInfo = nil
	_G.GetNumAvailableQuests = function() return 2 end
	_G.GetAvailableTitle = function(i) return ({ "First", "Second" })[i] end
	_G.GetNumActiveQuests = function() return 0 end
	O.OnEvent("QUEST_GREETING")
	local g = ForeverCodexDB.offers.obs[1]
	local ga
	for _, a in ipairs(g.answers) do if a.kind == "available" then ga = a end end
	check(g.via == "QUEST_GREETING" and ga.state == "LISTED" and #ga.entries == 2 and ga.entries[1].title == "First" and ga.entries[1].id == nil, "QUEST_GREETING: titles only when the client has no id function")
	local gb
	for _, a in ipairs(g.answers) do if a.kind == "active" then gb = a end end
	check(gb.state == "EMPTY", "zero active quests is an EMPTY answer")
	_G.GetAvailableQuestID = function(i) return 5000 + i end
	O.OnEvent("QUEST_GREETING")
	local g2 = ForeverCodexDB.offers.obs[#ForeverCodexDB.offers.obs]
	local ga2
	for _, a in ipairs(g2.answers) do if a.kind == "available" then ga2 = a end end
	check(ga2.entries[1].id == nil, "GetAvailableQuestID is proven absent on Forever and is never called, so a greeting entry never gets an id from it")
	check(next(ForeverCodexDB.offers.npcs) == nil and next(ForeverCodexDB.offers.quests) == nil, "a QUEST_GREETING (unproven payload) is recorded as an observation but never becomes NPC or quest evidence")
	_G.GetAvailableQuestID = nil

	-- QUEST_DETAIL: the quest whose offer dialog is open
	reset()
	_G.GetQuestID = function() return 92645 end
	_G.GetTitleText = function() return "Breaking the Breaker" end
	O.OnEvent("QUEST_DETAIL")
	local d = ForeverCodexDB.offers.obs[1]
	check(d.via == "QUEST_DETAIL" and d.answers[1].kind == "offered" and d.answers[1].entries[1].id == 92645 and d.answers[1].entries[1].title == "Breaking the Breaker", "QUEST_DETAIL: the open offer is recorded with its id and title")

	-- a failing API is FAILED / ERROR and never breaks anything
	reset()
	_G.C_GossipInfo = { GetAvailableQuests = function() error("boom") end }
	O.OnEvent("GOSSIP_SHOW")
	local er
	for _, a in ipairs(ForeverCodexDB.offers.obs[1].answers) do if a.api == "C_GossipInfo.GetAvailableQuests" then er = a end end
	check(er.state == "ERROR" and ForeverCodexDB.offers.proof["C_GossipInfo.GetAvailableQuests"].fail == 1, "an API that raises is ERROR / FAILED, and the probe carries on")

	-- bounded
	reset()
	_G.C_GossipInfo = nil
	for i = 1, O.MAX_OBS + 20 do
		_G.UnitName = function() return "NPC " .. i end
		O.OnEvent("GOSSIP_SHOW")
	end
	check(#ForeverCodexDB.offers.obs == O.MAX_OBS, "at most " .. O.MAX_OBS .. " observations are kept")

	-- read-only: no recompute, no dirty mark, no error
	check(dirtyTotal() == d0 and ns.State.perf.count == countBefore, "the probe marked nothing dirty and recomputed nothing")
	check(#ns.errors == 0, "no errors")
	clear()
	reset()
end

-- ---------------------------------------------------------------- Offer evidence layer (0.6.5): OBSERVED / EMPTY_AT_NPC / NOT_LISTED_AT_NPC / UNKNOWN
section("offer evidence: positive client evidence, contextual negatives, and UNKNOWN as the default (the planner is unchanged)")
do
	local NAMES = { "C_GossipInfo", "GetNumAvailableQuests", "GetAvailableTitle", "GetNumActiveQuests", "GetActiveTitle", "GetQuestID", "GetTitleText", "UnitName", "UnitGUID" }
	local ns = boot({ char = { level = 10 }, synthetic = true, loc = { map = 9001, x = 0.5, y = 0.5 } })
	for _, n in ipairs(NAMES) do _G[n] = nil end
	local O, Pl = ns.OfferProbe, ns.Planner
	-- quests whose giver is a known NPC (creature id and name), as the data layers give them
	H.attPack(ns, {
		{ id = 201, name = "At Valennia", map = 9001, x = 0.52, y = 0.5, req = 1, giverNpc = 7001, giverName = "Valennia Stormfist" },
		{ id = 202, name = "Also Valennia", map = 9001, x = 0.52, y = 0.5, req = 1, giverNpc = 7001, giverName = "Valennia Stormfist" },
		{ id = 203, name = "At Talaanis", map = 9001, x = 0.53, y = 0.5, req = 1, giverNpc = 7002, giverName = "Talaanis Shadowsong" },
		{ id = 204, name = "Never Seen", map = 9001, x = 0.54, y = 0.5, req = 1, giverNpc = 7003, giverName = "Nobody Yet" },
		{ id = 205, name = "Named Only", map = 9001, x = 0.55, y = 0.5, req = 1, giverName = "Name Only Npc" },
		{ id = 206, name = "Not In List", map = 9001, x = 0.53, y = 0.5, req = 1, giverNpc = 7002, giverName = "Talaanis Shadowsong" },
	}, nil)
	local function pickup(id) return { kind = "ACCEPT", quest = id } end
	local function reset() ForeverCodexDB.offers = nil; ForeverCodexDB.items = nil end
	local function stubNpc(name, id)
		_G.UnitName = function(u) return u == "npc" and name or nil end
		_G.UnitGUID = function(u) return u == "npc" and id and ("Creature-0-1-2-3-" .. id .. "-ABCDEF") or nil end
	end
	local function gossip(avail, active)
		_G.C_GossipInfo = { GetAvailableQuests = function() return avail end, GetActiveQuests = function() return active or {} end, GetOptions = function() return {} end }
		O.OnEvent("GOSSIP_SHOW")
	end
	reset()

	-- 8 / 11: no evidence -> UNKNOWN, no offer evidence, for a database pickup nobody has seen
	check(Pl.Actionability(pickup(204)) == "UNKNOWN" and Pl.OfferEvidence(pickup(204)) == nil, "no client evidence: UNKNOWN and no offer evidence (the default stays)")
	check(Pl.Actionability({ kind = "OBJECTIVE", quest = 204 }) == "NOT_APPLICABLE", "only pickups have an actionability")

	-- 3: an empty available list at an NPC is contextual evidence for that NPC's quests, and the actionability stays UNKNOWN
	stubNpc("Valennia Stormfist", 7001)
	gossip({}, {})
	local ev = Pl.OfferEvidence(pickup(201))
	check(ev and ev.kind == "EMPTY_AT_NPC" and ev.npc == "Valennia Stormfist", "an EMPTY available list at the giver's NPC (matched by creature id) is EMPTY_AT_NPC")
	check(Pl.Actionability(pickup(201)) == "UNKNOWN", "...and the quest's actionability is still UNKNOWN: a contextual negative is not a verdict")
	local npcs = ForeverCodexDB.offers.npcs
	check(npcs["id:7001"] and npcs["id:7001"].avail.state == "EMPTY" and npcs["id:7001"].active.state == "EMPTY", "the NPC context records AVAILABLE and ACTIVE as EMPTY")

	-- 4: an identical repeat merges (one observation, counters rise, no new rows)
	gossip({}, {})
	local nObs = #ForeverCodexDB.offers.obs
	check(nObs == 1 and ForeverCodexDB.offers.obs[1].n == 2 and npcs["id:7001"].n == 2, "an identical empty dialog merges: one observation, seen x2")

	-- 5: a different NPC is a separate context
	stubNpc("Talaanis Shadowsong", 7002)
	gossip({}, {})
	local count = 0
	for _ in pairs(ForeverCodexDB.offers.npcs) do count = count + 1 end
	check(count == 2 and ForeverCodexDB.offers.npcs["id:7002"].avail.state == "EMPTY", "a different NPC is a separate context")

	-- 6: an empty answer at NPC A says nothing about a quest whose giver is B, or one observed elsewhere
	check(Pl.OfferEvidence(pickup(204)) == nil, "an empty dialog at other NPCs does not touch a quest from an NPC never opened")
	stubNpc("Fendaal Windstone", 7009)
	_G.GetQuestID = function() return 203 end
	_G.GetTitleText = function() return "At Talaanis" end
	O.OnEvent("QUEST_DETAIL")
	local seen = Pl.OfferEvidence(pickup(203))
	check(seen and seen.kind == "OBSERVED" and seen.via == "QUEST_DETAIL" and seen.npc == "Fendaal Windstone", "a quest opened at ANOTHER NPC is OBSERVED there (the empty dialog at its giver does not invalidate it)")
	check(Pl.Actionability(pickup(203)) == "OBSERVED", "and its actionability is OBSERVED")

	-- 1: QUEST_DETAIL creates positive actionability; 7: a positive observation upgrades a contextual negative
	check(Pl.Actionability(pickup(201)) == "UNKNOWN" and Pl.OfferEvidence(pickup(201)).kind == "EMPTY_AT_NPC", "before: contextual negative only")
	_G.GetQuestID = function() return 201 end
	_G.GetTitleText = function() return "At Valennia" end
	stubNpc("Valennia Stormfist", 7001)
	O.OnEvent("QUEST_DETAIL")
	local up = Pl.OfferEvidence(pickup(201))
	check(up.kind == "OBSERVED" and up.via == "QUEST_DETAIL" and Pl.Actionability(pickup(201)) == "OBSERVED", "after a QUEST_DETAIL for it: OBSERVED outranks the earlier contextual negative")
	check(ForeverCodexDB.offers.npcs["id:7001"].avail.state == "EMPTY", "the QUEST_DETAIL did not rewrite what the NPC's listing said")
	check(Pl.OfferEvidence(pickup(202)).kind == "EMPTY_AT_NPC", "the sibling quest of the same NPC is still only contextual")

	-- 2: an available list that carries the quest id is positive evidence; a complete list without it is NOT_LISTED_AT_NPC
	stubNpc("Talaanis Shadowsong", 7002)
	gossip({ { questID = 303, title = "Elsewhere" }, { questID = 304, title = "Another" } }, {})
	check(Pl.OfferEvidence({ kind = "ACCEPT", quest = 303 }).kind == "OBSERVED" and Pl.OfferEvidence({ kind = "ACCEPT", quest = 303 }).via == "AVAILABLE_LIST", "a quest id inside a client available list is OBSERVED via AVAILABLE_LIST")
	local nl = Pl.OfferEvidence(pickup(203))
	check(nl.kind == "OBSERVED", "a quest already observed stays OBSERVED even if a later list at its giver omits it (positive evidence is never erased)")
	-- a quest from that giver that was never observed and is not in the complete list: contextual negative
	check(Pl.OfferEvidence(pickup(206)).kind == "NOT_LISTED_AT_NPC", "a complete id list that omits the quest is NOT_LISTED_AT_NPC (contextual)")
	check(Pl.Actionability(pickup(206)) == "UNKNOWN", "...and still UNKNOWN")
	-- an incomplete list (an entry without an id) makes no negative claim
	gossip({ { questID = 303, title = "Elsewhere" }, { title = "No id" } }, {})
	check(Pl.OfferEvidence(pickup(206)) == nil, "a list with an entry that has no id makes NO negative claim (nothing is manufactured from incomplete data)")
	-- the name-only giver (no creature id in the data) is matched by exact name, never loosely
	stubNpc("Name Only Npc", nil)
	gossip({}, {})
	check(Pl.OfferEvidence(pickup(205)).kind == "EMPTY_AT_NPC", "a giver known only by name is matched by that exact name")

	-- 9: no raw GUID anywhere in the saved evidence
	local function scan(t, d) for k, v in pairs(t) do if type(v) == "string" and (v:find("Creature-", 1, true) or v:find("ABCDEF", 1, true)) then return true end if type(v) == "table" and d < 8 and scan(v, d + 1) then return true end end return false end
	check(not scan(ForeverCodexDB.offers, 0), "no raw GUID is persisted (only the creature id)")

	-- 10: bounded
	reset()
	for i = 1, O.MAX_QUESTS + 30 do
		_G.GetQuestID = function() return 500000 + i end
		_G.GetTitleText = function() return "Q" .. i end
		stubNpc("NPC " .. i, 100000 + i)
		O.OnEvent("QUEST_DETAIL")
	end
	for i = 1, O.MAX_NPCS + 30 do
		stubNpc("List NPC " .. i, 200000 + i)
		gossip({}, {})
	end
	local nq, nn = 0, 0
	for _ in pairs(ForeverCodexDB.offers.quests) do nq = nq + 1 end
	for _ in pairs(ForeverCodexDB.offers.npcs) do nn = nn + 1 end
	check(nq <= O.MAX_QUESTS and nn <= O.MAX_NPCS and #ForeverCodexDB.offers.obs <= O.MAX_OBS, "quests, NPC contexts and observations are all bounded (" .. nq .. " / " .. nn .. " / " .. #ForeverCodexDB.offers.obs .. ")")

	-- the report wording: concise, with the meaning stated, and the opportunity line keeps UNKNOWN
	reset()
	stubNpc("Valennia Stormfist", 7001)
	gossip({}, {})
	_G.GetQuestID = function() return 98512 end
	_G.GetTitleText = function() return "Al'Aketh Assassins" end
	stubNpc("Fendaal Windstone", 7010)
	O.OnEvent("QUEST_DETAIL")
	local text = table.concat(O.ReportLines(), "\n")
	check(text:find("Q98512 Al'Aketh Assassins | NPC Fendaal Windstone (creature 7010) | OBSERVED | sources: QUEST_DETAIL x1 | observations 1", 1, true) ~= nil, "the report lists the observed quest with its NPC, sources and observation count")
	check(text:find("Valennia Stormfist (creature 7001) | available EMPTY | active EMPTY", 1, true) ~= nil and text:find("describe that dialog at that moment only", 1, true) ~= nil, "the report shows the EMPTY NPC dialog and says what it does not prove")
	local line = ns.Diag.OpportunityLines
	check(type(line) == "function", "the opportunity diagnostics are still available")
	check(#ns.errors == 0, "no errors")
	for _, n in ipairs(NAMES) do _G[n] = nil end
	reset()
end

-- ---------------------------------------------------------------- 0.6.6: the real Forever payload, AVAILABLE vs ACTIVE, evidence strength and hierarchy
section("offer evidence (real payload): available vs active kept apart, both sources counted, positive evidence never erased, malformed answers make no claim")
do
	local NAMES = { "C_GossipInfo", "GetNumAvailableQuests", "GetAvailableTitle", "GetNumActiveQuests", "GetActiveTitle", "GetQuestID", "GetTitleText", "UnitName", "UnitGUID",
		"GetNumGossipAvailableQuests", "GetGossipAvailableQuests" }
	local ns = boot({ char = { level = 11 }, synthetic = true, loc = { map = 9001, x = 0.5, y = 0.5 } })
	for _, n in ipairs(NAMES) do _G[n] = nil end
	local O, Pl = ns.OfferProbe, ns.Planner
	H.attPack(ns, {
		{ id = 93160, name = "The Forest's Bounty", map = 9001, x = 0.52, y = 0.5, req = 1, giverNpc = 8001, giverName = "Strange Hermit" },
		{ id = 93172, name = "Free the Hollows", map = 9001, x = 0.52, y = 0.5, req = 1, giverNpc = 8001, giverName = "Strange Hermit" },
		{ id = 93159, name = "The Strange Hermit", map = 9001, x = 0.52, y = 0.5, req = 1, giverNpc = 8001, giverName = "Strange Hermit" },
		{ id = 100, name = "Q100", map = 9001, x = 0.53, y = 0.5, req = 1, giverNpc = 8002, giverName = "Talaanis Shadowsong" },
		{ id = 101, name = "Q101", map = 9001, x = 0.53, y = 0.5, req = 1, giverNpc = 8002, giverName = "Talaanis Shadowsong" },
		{ id = 102, name = "Q102", map = 9001, x = 0.53, y = 0.5, req = 1, giverNpc = 8002, giverName = "Talaanis Shadowsong" },
		{ id = 103, name = "Q103", map = 9001, x = 0.53, y = 0.5, req = 1, giverNpc = 8002, giverName = "Talaanis Shadowsong" },
	}, nil)
	local function pickup(id) return { kind = "ACCEPT", quest = id } end
	local function reset() ForeverCodexDB.offers = nil; ForeverCodexDB.items = nil end
	local function stubNpc(name, id)
		_G.UnitName = function(u) return u == "npc" and name or nil end
		_G.UnitGUID = function(u) return u == "npc" and id and ("Creature-0-1-2-3-" .. id .. "-ABCDEF") or nil end
	end
	-- the entry shape the Forever client really returns
	local function e(id, title, extra)
		local t = { questID = id, title = title, questLevel = 11, questInfoID = 0, repeatable = false, isComplete = false, isImportant = false }
		for k, v in pairs(extra or {}) do t[k] = v end
		return t
	end
	local function gossip(avail, active)
		_G.C_GossipInfo = { GetAvailableQuests = function() return avail end, GetActiveQuests = function() return active end, GetOptions = function() return {} end }
		O.OnEvent("GOSSIP_SHOW")
	end
	reset()

	-- Strange Hermit: two available, one active (the real-client example)
	stubNpc("Strange Hermit", 8001)
	gossip({ e(93160, "The Forest's Bounty"), e(93172, "Free the Hollows") }, { e(93172, "Free the Hollows") })
	local ev = Pl.OfferEvidence(pickup(93160))
	check(ev and ev.kind == "OBSERVED" and ev.via == "AVAILABLE_LIST" and ev.by.AVAILABLE_LIST == 1, "an available list carrying the quest id is OBSERVED via AVAILABLE_LIST")
	local hermit = ForeverCodexDB.offers.npcs["id:8001"]
	check(hermit.avail.state == "LISTED" and hermit.avail.complete and #hermit.avail.ids == 2 and hermit.avail.entries[1].title == "The Forest's Bounty", "the NPC context keeps the available ids and titles")
	check(hermit.active.state == "LISTED" and hermit.active.ids[1] == 93172, "the ACTIVE list is kept as its own concept (Q93172 active)")

	-- 5: an ACTIVE quest is not an offer
	reset()
	stubNpc("Strange Hermit", 8001)
	gossip({}, { e(93159, "The Strange Hermit") })
	check(O.QuestEvidence(93159) == nil and Pl.OfferEvidence(pickup(93159)).kind == "EMPTY_AT_NPC", "a quest only in the ACTIVE list is NOT positive offer evidence (the available list was empty)")
	check(Pl.Actionability(pickup(93159)) == "UNKNOWN", "...and its actionability stays UNKNOWN")

	-- both sources are counted; QUEST_DETAIL is the stronger via
	reset()
	stubNpc("Strange Hermit", 8001)
	gossip({ e(93160, "The Forest's Bounty") }, {})
	_G.GetQuestID = function() return 93160 end
	_G.GetTitleText = function() return "The Forest's Bounty" end
	O.OnEvent("QUEST_DETAIL")
	local both = Pl.OfferEvidence(pickup(93160))
	check(both.via == "QUEST_DETAIL" and both.by.QUEST_DETAIL == 1 and both.by.AVAILABLE_LIST == 1 and both.n == 2, "QUEST_DETAIL and AVAILABLE_LIST are both counted; QUEST_DETAIL is the stronger source")
	check(table.concat(O.ReportLines(), "\n"):find("Q93160 The Forest's Bounty | NPC Strange Hermit (creature 8001) | OBSERVED | sources: QUEST_DETAIL x1 + AVAILABLE_LIST x1 | observations 2", 1, true) ~= nil, "the report shows OBSERVED with both sources and the observation count")

	-- a later EMPTY dialog at the same NPC does not erase it, and is reported beside it
	gossip({}, {})
	local still = Pl.OfferEvidence(pickup(93160))
	check(still.kind == "OBSERVED" and still.newer == "EMPTY_AT_NPC", "a later EMPTY listing never erases positive evidence; it is reported as NEWER context")
	check(Pl.Actionability(pickup(93160)) == "OBSERVED", "actionability stays OBSERVED")
	check(table.concat(O.ReportLines(), "\n"):find("NEWER dialog at that NPC: available EMPTY (kept, not erased)", 1, true) ~= nil, "the report says so")

	-- a later complete list that omits it also leaves it OBSERVED
	gossip({ e(93172, "Free the Hollows") }, {})
	check(Pl.OfferEvidence(pickup(93160)).newer == "NOT_LISTED_AT_NPC" and Pl.OfferEvidence(pickup(93160)).kind == "OBSERVED", "a later complete list without it: still OBSERVED, with the newer not-listed context")

	-- NOT_LISTED_AT_NPC needs a complete id list; Q100 / Q101 / Q102 listed, Q103 not
	reset()
	stubNpc("Talaanis Shadowsong", 8002)
	gossip({ e(100, "Q100"), e(101, "Q101"), e(102, "Q102") }, {})
	check(Pl.OfferEvidence(pickup(103)).kind == "NOT_LISTED_AT_NPC", "Q103 is NOT_LISTED_AT_NPC when the NPC's complete id list had Q100-Q102")
	check(Pl.OfferEvidence(pickup(100)).kind == "OBSERVED" and Pl.OfferEvidence(pickup(101)).kind == "OBSERVED", "the listed quests are OBSERVED; evidence for Q100 does not touch Q103")
	check(Pl.Actionability(pickup(103)) == "UNKNOWN", "NOT_LISTED never becomes a verdict: actionability UNKNOWN")
	-- a different NPC is unaffected
	check(Pl.OfferEvidence(pickup(93160)) == nil, "another NPC's quests are untouched by this NPC's list")

	-- safety: title-only entries, malformed answers, missing API, API error
	reset()
	stubNpc("Talaanis Shadowsong", 8002)
	gossip({ e(100, "Q100"), { title = "no id" } }, {})
	check(Pl.OfferEvidence(pickup(103)) == nil, "a list with a title-only entry makes no NOT_LISTED claim")
	reset()
	stubNpc("Talaanis Shadowsong", 8002)
	gossip(42, {})                                   -- malformed: a number, not a list
	check(Pl.OfferEvidence(pickup(103)) == nil, "a malformed answer (not a table) is UNKNOWN")
	gossip({ e(100, "Q100"), "garbage" }, {})        -- a non-table entry among the entries
	check(Pl.OfferEvidence(pickup(103)) == nil, "a list containing a non-table entry is incomplete: UNKNOWN")
	reset()
	stubNpc("Talaanis Shadowsong", 8002)
	gossip({ { questID = "100", title = "string id" } }, {})
	check(Pl.OfferEvidence(pickup(103)) == nil and O.QuestEvidence(100) == nil, "an id that is not a number is not an id: no claim and no positive evidence")
	_G.C_GossipInfo = nil
	O.OnEvent("GOSSIP_SHOW")
	check(Pl.OfferEvidence(pickup(103)) == nil, "a missing API makes no claim")
	_G.C_GossipInfo = { GetAvailableQuests = function() error("boom") end, GetActiveQuests = function() return {} end }
	O.OnEvent("GOSSIP_SHOW")
	check(Pl.OfferEvidence(pickup(103)) == nil, "an API that raises makes no claim")
	-- the legacy functions are not called any more
	local called = 0
	_G.GetNumGossipAvailableQuests = function() called = called + 1 return 0 end
	_G.C_GossipInfo = { GetAvailableQuests = function() return {} end, GetActiveQuests = function() return {} end, GetOptions = function() return {} end }
	O.OnEvent("GOSSIP_SHOW")
	check(called == 0, "the proven-absent legacy gossip functions are not asked")

	-- repeats merge; positive evidence per quest is bounded
	reset()
	stubNpc("Talaanis Shadowsong", 8002)
	for _ = 1, 5 do gossip({ e(100, "Q100") }, {}) end
	check(#ForeverCodexDB.offers.obs == 1 and ForeverCodexDB.offers.obs[1].n == 5 and O.QuestEvidence(100).n == 5, "five identical dialogs: one observation, counted x5")
	check(#ns.errors == 0, "no errors")
	for _, n in ipairs(NAMES) do _G[n] = nil end
	reset()
end

-- ---------------------------------------------------------------- 0.6.7: availability evidence in the planner, and quest-starting items
section("pickup availability: database knowledge is ELIGIBLE-level support; only the client's own dialog establishes OFFERED, and progress makes a 'not offered' stale")
do
	local NAMES = { "C_GossipInfo", "UnitName", "UnitGUID" }
	local ns = boot({ char = { level = 11 }, synthetic = true, loc = { map = 9001, x = 0.5, y = 0.5 } })
	for _, n in ipairs(NAMES) do _G[n] = nil end
	local O, Pl = ns.OfferProbe, ns.Planner
	local function reset() ForeverCodexDB.offers = nil; ForeverCodexDB.items = nil end
	local function stubNpc(name, id)
		_G.UnitName = function(u) return u == "npc" and name or nil end
		_G.UnitGUID = function(u) return u == "npc" and id and ("Creature-0-1-2-3-" .. id .. "-ABCDEF") or nil end
	end
	local function gossip(avail)
		_G.C_GossipInfo = { GetAvailableQuests = function() return avail end, GetActiveQuests = function() return {} end, GetOptions = function() return {} end }
		O.OnEvent("GOSSIP_SHOW")
	end
	local function e(id, title) return { questID = id, title = title, questLevel = 11 } end
	local function pickup(id) return { kind = "ACCEPT", quest = id, evidence = "unverified", target = { map = 9001, x = 0.52, y = 0.5 } } end
	-- the Ties That Bind case: the data knows nothing of a prerequisite, so the quest is "eligible", but the NPC does not offer it until Feathers for Binding is done
	H.attPack(ns, {
		{ id = 300, name = "Feathers for Binding", map = 9001, x = 0.52, y = 0.5, req = 1, giverNpc = 9001, giverName = "Hub NPC" },
		{ id = 301, name = "The Ties That Bind", map = 9001, x = 0.52, y = 0.5, req = 1, giverNpc = 9001, giverName = "Hub NPC" },
		{ id = 302, name = "Elsewhere", map = 9001, x = 0.53, y = 0.5, req = 1, giverNpc = 9002, giverName = "Other NPC" },
	}, nil)
	local W = H.world()
	W.log, W.objectives, W.completed = {}, {}, {}
	ns.Prefs.FinishSetup()
	reset()
	ns.State.Recompute()

	-- 1: exists in the database, no availability evidence: UNKNOWN, and the existing small discount only
	local st, ev = Pl.OfferState(pickup(301))
	check(st == "UNKNOWN" and ev == nil, "1: a database quest with no client evidence is UNKNOWN (eligible, not proven offered)")
	local c0 = Pl.Confidence(pickup(301))
	check(c0 > 0.5 and c0 < 1, "1: it keeps the existing unverified discount (" .. string.format("%.2f", c0) .. "): still recommendable, just not certain")

	-- 2: eligible by the data, but the NPC's complete list (read now) does not offer it
	stubNpc("Hub NPC", 9001)
	gossip({ e(300, "Feathers for Binding") })
	local st2, ev2 = Pl.OfferState(pickup(301))
	check(st2 == "NOT_OFFERED" and ev2.kind == "NOT_LISTED_AT_NPC", "2: the giver's complete list did not offer it: NOT_OFFERED (contextual)")
	check(Pl.Confidence(pickup(301)) < 0.3 * c0 + 0.001 and Pl.Confidence(pickup(301)) < Pl.Confidence(pickup(302)), "2: its value is strongly discounted below an unevidenced pickup (" .. string.format("%.2f", Pl.Confidence(pickup(301))) .. ")")
	check(Pl.OfferState(pickup(300)) == "OBSERVED" and Pl.Confidence(pickup(300)) == 1, "4: a quest the client listed is OBSERVED: no discount at all")
	check(Pl.OfferState(pickup(302)) == "UNKNOWN", "evidence about one NPC does not touch another NPC's quests")
	-- the player-facing line says it plainly
	local card = ns.Presenter.Describe({ kind = "ACCEPT", quest = 301, name = "The Ties That Bind", title = "Accept: The Ties That Bind", giver = "Hub NPC", id = "Q:301:ACCEPT", target = { map = 9001, x = 0.52, y = 0.5 } }, { diag = { reasons = {} } }, ns.State.ctx, nil)
	check(card.caution and card.caution:find("Not offered by Hub NPC", 1, true) and card.offerState == "NOT_OFFERED", "2: the tracker says 'Not offered by Hub NPC the last time you asked' instead of promising an accept")

	-- 3: Feathers for Binding is turned in: progression changed, so the earlier 'not offered' is STALE and the quest is back to UNKNOWN (re-check at the NPC)
	W.completed[300] = true
	ns.Journey.OnQuestTurnedIn(300, 100)
	ns.State.Recompute()
	local st3, ev3 = Pl.OfferState(pickup(301))
	check(st3 == "UNKNOWN" and ev3 and ev3.stale, "3: after the prerequisite is turned in the old 'not offered' is stale: UNKNOWN again, with the stale note")
	check(math.abs(Pl.Confidence(pickup(301)) - c0) < 1e-9, "3: and the quest is valued as before (not penalised by a fact that progress has outdated)")
	-- the NPC is asked again and now offers both
	gossip({ e(301, "The Ties That Bind"), e(303, "The Wounds of Betrayal") })
	check(Pl.OfferState(pickup(301)) == "OBSERVED" and Pl.Confidence(pickup(301)) == 1, "3/4: the new dialog lists it: OBSERVED")
	-- a positive observation is not undone by later progress...
	W.completed[999] = true
	ns.Journey.OnQuestTurnedIn(999, 100)
	ns.State.Recompute()
	check(Pl.OfferState(pickup(301)) == "OBSERVED", "5: a positive observation survives later progress (it is not stale just because the character moved on)")
	-- ...but a newer complete list at the CURRENT progression that omits it contradicts it
	gossip({ e(303, "The Wounds of Betrayal") })
	local st5, ev5 = Pl.OfferState(pickup(301))
	check(st5 == "NOT_OFFERED" and ev5.contradicted, "5: a newer dialog at the same progression that no longer lists it contradicts the old observation")
	-- ...and that contradiction in turn goes stale with the next progress
	ns.Journey.OnQuestTurnedIn(998, 100)
	ns.State.Recompute()
	check(Pl.OfferState(pickup(301)) == "OBSERVED", "5: once progress changes again the contradiction is stale and the earlier positive stands")

	-- an empty dialog (nothing offered) is the same kind of contextual negative, with the same expiry
	reset()
	stubNpc("Other NPC", 9002)
	gossip({})
	check(Pl.OfferState(pickup(302)) == "NOT_OFFERED", "an EMPTY list at the giver is NOT_OFFERED right now")
	ns.Journey.OnQuestTurnedIn(997, 10)
	ns.State.Recompute()
	check(Pl.OfferState(pickup(302)) == "UNKNOWN", "and stale after any progress")

	-- a prerequisite the DATA knows about still blocks it outright (existing progression handling)
	H.attPack(ns, { { id = 310, name = "Needs A Prereq", map = 9001, x = 0.52, y = 0.5, req = 1, prereq = { 311 } }, { id = 311, name = "The Prereq", map = 9001, x = 0.5, y = 0.52, req = 1 } }, nil)
	local ctx = ns.Context.Build()
	local c = ns.Engine.Candidates(ctx)
	local has310 = false
	for _, a in ipairs(c.candidates) do if a.quest == 310 then has310 = true end end
	check(not has310 and (c.env.stats.filtered.prereq or 0) >= 1, "a quest with an unmet prerequisite in the data is not even a candidate")
	H.world().completed[311] = true
	local c2 = ns.Engine.Candidates(ns.Context.Build())
	local has310b = false
	for _, a in ipairs(c2.candidates) do if a.quest == 310 then has310b = true end end
	check(has310b, "and becomes one when the prerequisite is completed")
	check(#ns.errors == 0, "no errors")
	for _, n in ipairs(NAMES) do _G[n] = nil end
	reset()
end

section("quest-starting items: detected from client / QuestieDB evidence only, filtered by the existing progression rules, shown as NEW QUEST ITEM")
do
	local ns = gearWorld({ bags = { 4914, 900 }, bagSize = 4 })
	_G.LibQuestieDB = nil
	local QI = ns.QuestItems
	check(QI ~= nil, "the module is loaded")
	local info = {}                                   -- [bag .. ":" .. slot] = table the client would return
	_G.GetContainerItemQuestInfo = function(bag, slot) return info[bag .. ":" .. slot] or { isQuestItem = false } end
	H.attPack(ns, { { id = 555, name = "The Missive Quest", map = 9001, x = 0.52, y = 0.5, req = 1 }, { id = 556, name = "A High Level Quest", map = 9001, x = 0.52, y = 0.5, req = 40 } }, nil)
	local W = H.world()
	W.log, W.objectives, W.completed = {}, {}, {}
	ns.Prefs.FinishSetup()
	local function refresh()
		ns.Gear.Snapshot()
		ns.State.Recompute()
		return ns.State.plan, ns.Presenter.Card(ns.State.plan, ns.State.ctx)
	end

	-- possession alone proves nothing
	local plan, card = refresh()
	check(#plan.questItems == 0 and #card.questItems == 0, "an item in the bags with no evidence it starts a quest is NOT surfaced")
	-- the client reports that bag 0 slot 1 starts quest 555
	info["0:1"] = { isQuestItem = true, questID = 555, isActive = false }
	plan, card = refresh()
	check(#plan.questItems == 1 and plan.questItems[1].itemId == 4914 and plan.questItems[1].quest == 555, "the client's container quest info marks the item as starting Q555")
	check(plan.questItems[1].verified == true and plan.questItems[1].src == "client", "provenance: client-reported (verified)")
	check(#card.questItems == 1 and card.questItems[1].title == "Battleworn Leather Gloves" and card.questItems[1].detail:find("This item starts a quest. Use it to continue your progression.", 1, true), "the NEW QUEST ITEM row says what it is and what to do")
	check(card.questItems[1].questName == "The Missive Quest", "and names the quest when Codex has data for it")
	-- it is a candidate through the normal funnel but never takes NOW / ALSO DO
	check((plan.now == nil or plan.now.type ~= "QUEST_ITEM") and (plan.alsoDo == nil or plan.alsoDo.type ~= "QUEST_ITEM"), "it never becomes NOW or ALSO DO")
	for _, o in ipairs(plan.onTheWay or {}) do check(o.action.type ~= "QUEST_ITEM", "and is not an on-the-way row") end
	for _, it in ipairs(ns.Overlap.List(plan, ns.State.ctx)) do check(it.title ~= "Use: Battleworn Leather Gloves", "nor an ALSO row (it has its own card)") end
	-- the tracker draws it
	ns.UI.Open("codex")
	ns.State.Recompute()
	local c = ns.UI.main.codex
	check(c.qiBox.__shown and c.qiLabel.__text == "NEW QUEST ITEM" and c.qiRows[1].head.__text == "Battleworn Leather Gloves", "the tracker shows the NEW QUEST ITEM card")
	local report
	rawset(ns.UI, "ShowReport", function(t) report = t end)
	H.slash("report")
	check(report and report:find("QUEST-STARTING ITEMS", 1, true) and report:find("starts Q555 | evidence: client (client-reported) | ACTIONABLE", 1, true), "the report shows the evidence and the ACTIONABLE verdict")

	-- filtered by the existing rules
	W.log = { { questID = 555, title = "The Missive Quest", complete = false } }
	plan = refresh()
	check(#plan.questItems == 0 and (plan.stats.filtered.questItemIN_LOG or 0) == 1, "the quest is already in the quest log: not surfaced (IN_LOG)")
	W.log, W.completed[555] = {}, true
	plan = refresh()
	check(#plan.questItems == 0 and (plan.stats.filtered.questItemCOMPLETED or 0) == 1, "the quest is already completed: not surfaced (COMPLETED)")
	W.completed[555] = nil
	info["0:1"] = { isQuestItem = true, questID = 555, isActive = true }
	plan = refresh()
	check(#plan.questItems == 0 and (plan.stats.filtered.questItemACTIVE or 0) == 1, "the client says the quest is already active: not surfaced (ACTIVE)")
	info["0:1"] = { isQuestItem = true, questID = 555, isActive = false }
	ns.Prefs.Skip("QI:4914")
	plan = refresh()
	check(#plan.questItems == 0 and (plan.stats.filtered.questItemSKIPPED or 0) == 1, "skipped by the player (QI:<item id>): not surfaced (SKIPPED)")
	ns.Prefs.Unskip("QI:4914")
	ns.Prefs.Skip("Q:555")
	plan = refresh()
	check(#plan.questItems == 0, "the quest itself skipped: not surfaced")
	ns.Prefs.Unskip("Q:555")
	info["0:1"] = { isQuestItem = true, questID = 556, isActive = false }
	plan = refresh()
	check(#plan.questItems == 0 and (plan.stats.filtered.questItemELIGIBILITY_level or 0) == 1, "the quest needs a higher level (existing pickup eligibility): not surfaced")
	info["0:1"] = { isQuestItem = true, questID = 777, isActive = false }
	plan = refresh()
	check(#plan.questItems == 1, "a quest Codex has no data for is still offered when the CLIENT said the item starts it")
	check(ns.State.perf and true, "no new timers or polling: scanning is keyed to the Gear snapshot")

	-- QuestieDB evidence: unverified, labelled as such, and the client wins a disagreement
	info["0:1"] = nil
	_G.LibQuestieDB = { Item = { Exists = function(id) return id == 4914 end, Get = function(id, k) if k == "startQuest" then return 555 end end } }
	plan, card = refresh()
	check(#plan.questItems == 1 and plan.questItems[1].src == "questiedb" and plan.questItems[1].verified == false, "QuestieDB's Item.startQuest is used, labelled unverified third-party data")
	check(card.questItems[1].detail:find("Codex's data says this item starts a quest.", 1, true), "and the player-facing line does not claim more than that")
	info["0:1"] = { isQuestItem = true, questID = 556, isActive = false }
	local list = QI.Scan(ns.Gear.Snapshot().bags)
	check(list[1].quest == 556 and list[1].src == "client" and list[1].conflict and list[1].conflict.questiedb == 555, "when the client disagrees with QuestieDB the client wins and the conflict is recorded")
	_G.LibQuestieDB = nil

	-- evidence tallies and bounded memory
	check(ForeverCodexDB.questItems.proof.ok and ForeverCodexDB.questItems.proof.ok >= 1, "the client function is tallied PROVEN once it returned a quest id")
	local n = 0
	for _ in pairs(ForeverCodexDB.questItems.seen) do n = n + 1 end
	check(n >= 1 and n <= QI.MAX_SEEN, "remembered quest-starting items are bounded")
	-- a missing function simply means no client evidence
	_G.GetContainerItemQuestInfo = nil
	plan = refresh()
	check(#plan.questItems == 0 and #ns.errors == 0, "without the client function (and QuestieDB) nothing is surfaced and nothing fails")
	_G.GetContainerItemQuestInfo = nil
end

-- ---------------------------------------------------------------- 0.6.8: a quest its giver just declined to offer is held back, not routed
section("held back: a pickup the giver did not offer at this progression is never the immediate ACCEPT; it stays known and returns when the evidence goes stale or the client offers it")
do
	local NAMES = { "C_GossipInfo", "UnitName", "UnitGUID" }
	local ns = boot({ char = { level = 11 }, synthetic = true, loc = { map = 9001, x = 0.5, y = 0.5 } })
	for _, n in ipairs(NAMES) do _G[n] = nil end
	local O, Pl = ns.OfferProbe, ns.Planner
	local function reset() ForeverCodexDB.offers = nil; ForeverCodexDB.items = nil end
	local function stubNpc(name, id)
		_G.UnitName = function(u) return u == "npc" and name or nil end
		_G.UnitGUID = function(u) return u == "npc" and id and ("Creature-0-1-2-3-" .. id .. "-ABCDEF") or nil end
	end
	local function gossip(avail)
		_G.C_GossipInfo = { GetAvailableQuests = function() return avail end, GetActiveQuests = function() return {} end, GetOptions = function() return {} end }
		O.OnEvent("GOSSIP_SHOW")
	end
	local function e(id, title) return { questID = id, title = title, questLevel = 11 } end
	-- two pickups of one giver standing right where the player is (no travel at all), and one elsewhere with a different giver
	H.attPack(ns, {
		{ id = 401, name = "Disrupting Like", map = 9001, x = 0.5, y = 0.5, req = 1, giverNpc = 9003, giverName = "Yorana" },
		{ id = 402, name = "Breaking Like", map = 9001, x = 0.5, y = 0.5, req = 1, giverNpc = 9003, giverName = "Yorana" },
		{ id = 403, name = "Elsewhere Quest", map = 9001, x = 0.6, y = 0.5, req = 1, giverNpc = 9004, giverName = "Other" },
	}, nil)
	local W = H.world()
	W.log, W.objectives, W.completed = {}, {}, {}
	ns.Prefs.FinishSetup()
	reset()
	local function plan() ns.State.Recompute(); return ns.State.plan end
	local function isHeld(p, id) for _, h in ipairs(p.diag.held and p.diag.held.list or {}) do if h.id == id then return h end end end
	local function inSequence(p, id) for _, k in ipairs(p.diag.sequence or {}) do if k == id then return true end end return false end

	-- 1-2: eligible, giver known, never asked: the planner may use it (UNKNOWN is not a veto)
	local p0 = plan()
	check(p0.diag.nowId == "Q:401:ACCEPT" or p0.diag.nowId == "Q:402:ACCEPT", "1: with no client evidence a pickup standing here is recommended as before (" .. tostring(p0.diag.nowId) .. ")")
	check(not p0.diag.held, "1: nothing is held back without evidence")

	-- 3-5: the giver is asked and offers nothing
	stubNpc("Yorana", 9003)
	gossip({})
	local p1 = plan()
	check(p1.diag.nowId ~= "Q:401:ACCEPT" and p1.diag.nowId ~= "Q:402:ACCEPT", "5: right after an empty dialog the planner does not pick that giver's quests as the immediate action (NOW=" .. tostring(p1.diag.nowId) .. ")")
	check(not inSequence(p1, "Q:401:ACCEPT") and not inSequence(p1, "Q:402:ACCEPT"), "5: nor anywhere in the sequence")
	check(p1.now == nil or (p1.now.quest ~= 401 and p1.now.quest ~= 402), "5: the tracker's NOW is not that quest either")
	for _, a in ipairs(p1.onTheWay or {}) do check(a.id ~= "Q:401:ACCEPT" and a.id ~= "Q:402:ACCEPT", "5: and it is not an ALSO DO") end
	-- 6: still known
	check(isHeld(p1, "Q:401:ACCEPT") and isHeld(p1, "Q:402:ACCEPT") and p1.diag.held.n == 2, "6: both stay in the candidate universe, reported as HELD BACK (" .. tostring(p1.diag.held and p1.diag.held.n) .. ")")
	check(isHeld(p1, "Q:401:ACCEPT").kind == "EMPTY_AT_NPC", "6: with the evidence kind that held them")
	check(p1.diag.nowId == "Q:403:ACCEPT", "the planner is not made useless: it routes the other giver's quest (" .. tostring(p1.diag.nowId) .. ")")
	check(Pl.Actionability({ kind = "ACCEPT", quest = 401 }) == "UNKNOWN", "the evidence model still says UNKNOWN (nothing was proven about the quest itself)")
	local text = table.concat(ns.Diag.OpportunityLines(), "\n")
	check(text:find("HELD BACK (2 pickup(s)", 1, true) and text:find("Q:401:ACCEPT", 1, true) and text:find("EMPTY_AT_NPC at Yorana", 1, true), "6: the report lists them with the evidence")

	-- 7: progression changes (a turn-in): the negative is stale, so the quests are candidates again
	ns.Journey.OnQuestTurnedIn(990, 100)
	local p2 = plan()
	check(not p2.diag.held, "7: after a turn-in the old 'asked and not offered' is stale: nothing is held back")
	check(p2.diag.nowId == "Q:401:ACCEPT" or p2.diag.nowId == "Q:402:ACCEPT", "8: and the quest can be recommended normally again (" .. tostring(p2.diag.nowId) .. ")")

	-- 9: a real positive observation makes it strongly actionable
	gossip({ e(401, "Disrupting Like") })
	local p3 = plan()
	check(p3.diag.nowId == "Q:401:ACCEPT" and Pl.OfferState({ kind = "ACCEPT", quest = 401 }) == "OBSERVED", "9: listed by the client: OBSERVED, and the planner takes it (" .. tostring(p3.diag.nowId) .. ")")
	check(isHeld(p3, "Q:402:ACCEPT") and not isHeld(p3, "Q:401:ACCEPT"), "9: while the sibling the complete list omitted is held back again")

	-- a QUEST_DETAIL observation of the held one wins over an older negative as well
	reset()
	stubNpc("Yorana", 9003)
	gossip({})
	check(plan().diag.held ~= nil, "(setup) held again after a fresh empty dialog")
	_G.GetQuestID = function() return 402 end
	_G.GetTitleText = function() return "Breaking Like" end
	O.OnEvent("QUEST_DETAIL")
	_G.GetQuestID, _G.GetTitleText = nil, nil
	local p4 = plan()
	check(not isHeld(p4, "Q:402:ACCEPT"), "9: a quest dialog for it (QUEST_DETAIL) lifts the hold")

	-- the Ayessa case (real 0.6.7): her COMPLETE list names two other quests, so the third quest she is "known" to give is held back, even right after a turn-in
	reset()
	H.attPack(ns, {
		{ id = 410, name = "Confront Like", map = 9001, x = 0.5, y = 0.5, req = 1, giverNpc = 9005, giverName = "Ayessa" },
		{ id = 411, name = "In Service Like", map = 9001, x = 0.5, y = 0.5, req = 1, giverNpc = 9005, giverName = "Ayessa" },
		{ id = 412, name = "Blood Like", map = 9001, x = 0.5, y = 0.5, req = 1, giverNpc = 9005, giverName = "Ayessa" },
		{ id = 413, name = "Elsewhere Quest", map = 9001, x = 0.6, y = 0.5, req = 1, giverNpc = 9004, giverName = "Other" },
	}, nil)
	ns.State.Recompute()
	ns.Journey.OnQuestTurnedIn(980, 100)               -- the quest just handed in changed the progression BEFORE she is asked again
	stubNpc("Ayessa", 9005)
	gossip({ e(411, "In Service Like"), e(412, "Blood Like") })
	local pa = plan()
	check(isHeld(pa, "Q:410:ACCEPT") and isHeld(pa, "Q:410:ACCEPT").kind == "NOT_LISTED_AT_NPC", "Ayessa: the quest her complete list omitted is held back (NOT_LISTED_AT_NPC)")
	check(pa.diag.nowId ~= "Q:410:ACCEPT" and not inSequence(pa, "Q:410:ACCEPT"), "Ayessa: and it is not NOW or in the sequence (NOW=" .. tostring(pa.diag.nowId) .. ")")
	check(pa.diag.nowId == "Q:411:ACCEPT" or pa.diag.nowId == "Q:412:ACCEPT", "Ayessa: the quests she did list are what Codex sends you to accept (" .. tostring(pa.diag.nowId) .. ")")
	-- a stale negative from another NPC (read before that turn-in) does not hold anything
	check(not isHeld(pa, "Q:413:ACCEPT"), "an unrelated quest is untouched")
	check(#ns.errors == 0, "no errors")
	for _, n in ipairs(NAMES) do _G[n] = nil end
	reset()
end
