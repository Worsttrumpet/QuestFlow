-- ForeverCodex.Items: the ONE read path for item facts (Stage 0 foundation of the future Reward Advisor). Nothing here advises, scores or decides.
--
-- Every function is a read-only, pcall-guarded client read. Nothing is assumed about the Forever client: an API that is missing, errors, or
-- returns nothing is reported as exactly that, per field, so callers (today only ItemProbe) can say what the client really exposes.
--   * facts.f[field]   the value read (only fields the client actually returned)
--   * facts.src[field] which client function produced it (provenance, per field)
--   * facts.err[group] why a group of fields is missing: "api absent", "error: ...", or "blank/nil (not loaded yet)"
--   * facts.unloaded   true when the item's data was not available yet (a blank name or nil): item data loads asynchronously, so the
--                      caller retries later (GET_ITEM_INFO_RECEIVED); this was seen on Forever for quest reward names
-- Client functions are looked up at CALL time (never captured at load), so a test double or a late-defined API is honoured.
--
-- Two layers (Stage 1):
--   I.Read(ref)       the raw read above (what the client returned, per group, and why anything is missing)
--   I.Normalize(raw)  the same read as ONE normalized ItemFacts object with a state per field (see the block below). It is a pure function of a raw read,
--                     so a read that completes later (item data loads asynchronously) is simply normalized again; there is no second late-loading system:
--                     ItemProbe's existing GET_ITEM_INFO_RECEIVED retry refreshes the raw read and callers normalize what it holds.
--   I.Facts(ref)      Read + Normalize + the optional QuestieDB cross-reference

local addonName, ns = ...

local I = {}
ns.Items = I

I.EQUIP_SLOTS = 19                 -- inventory slots 1..19 (the last is the tabard); slot 0 (ammo) is not probed
I.MAX_BAGS = 4                     -- the player's bag containers 1..4 plus the backpack 0

--- A function from a namespace table (modern, e.g. C_Item.GetItemInfo) or the global of the same purpose (classic), and its name; nil when neither exists.
local function find(tblName, key, globalName)
	local t = tblName and _G[tblName]
	if type(t) == "table" and type(t[key]) == "function" then return t[key], tblName .. "." .. key end
	if globalName and type(_G[globalName]) == "function" then return _G[globalName], globalName end
	return nil
end
I.Find = find

-- THE one place that says how each client function is looked up (namespace table first, then the global of the same purpose). Every read in this file goes through
-- I.Resolve, and the diagnostics ask it too, so what the readers use and what the report calls "present" cannot disagree.
I.API = {
	GetItemInfo = { "C_Item", "GetItemInfo", "GetItemInfo" }, GetItemInfoInstant = { "C_Item", "GetItemInfoInstant", "GetItemInfoInstant" },
	GetItemStats = { "C_Item", "GetItemStats", "GetItemStats" }, IsUsableItem = { "C_Item", "IsUsableItem", "IsUsableItem" },
	GetItemSpell = { "C_Item", "GetItemSpell", "GetItemSpell" }, GetItemCount = { "C_Item", "GetItemCount", "GetItemCount" },
	GetInventoryItemLink = { nil, nil, "GetInventoryItemLink" },
	GetContainerNumSlots = { "C_Container", "GetContainerNumSlots", "GetContainerNumSlots" }, GetContainerItemLink = { "C_Container", "GetContainerItemLink", "GetContainerItemLink" },
	GetContainerItemInfo = { "C_Container", "GetContainerItemInfo", "GetContainerItemInfo" },
	GetNumSkillLines = { nil, nil, "GetNumSkillLines" }, GetSkillLineInfo = { nil, nil, "GetSkillLineInfo" },
	-- looked up as plain globals by ItemProbe / Context
	GetQuestItemInfo = { nil, nil, "GetQuestItemInfo" }, GetQuestItemLink = { nil, nil, "GetQuestItemLink" },
	UnitClass = { nil, nil, "UnitClass" }, UnitLevel = { nil, nil, "UnitLevel" }, UnitRace = { nil, nil, "UnitRace" },
}

--- The client function for a name in I.API: `fn, via` (via = "C_Item.IsUsableItem" or "IsUsableItem"), or nil when neither form exists RIGHT NOW. Presence only:
-- it says nothing about whether the function works or answers correctly.
function I.Resolve(name)
	local spec = I.API[name]
	if not spec then return nil end
	return find(spec[1], spec[2], spec[3])
end

local function call(fn, ...)
	local r = { pcall(fn, ...) }
	if not r[1] then return false, tostring(r[2]) end
	table.remove(r, 1)
	return true, r
end
I.Call = call

--- The numeric item id from an item link ("|Hitem:4915::::...|h[Name]|h|r" or "item:4915"), or nil.
function I.IdFromLink(link)
	if type(link) ~= "string" then return nil end
	return tonumber(link:match("item:(%d+)"))
end

--- Copper as "1g 20s 5c" (zero parts left out); "0c" for nothing.
function I.Money(copper)
	if type(copper) ~= "number" then return "?" end
	local g, s, c = math.floor(copper / 10000), math.floor(copper / 100) % 100, copper % 100
	local out = {}
	if g > 0 then out[#out + 1] = g .. "g" end
	if s > 0 then out[#out + 1] = s .. "s" end
	if c > 0 or #out == 0 then out[#out + 1] = c .. "c" end
	return table.concat(out, " ")
end

--- Reads everything the client will tell about ONE item (an item link, or a numeric item id). Never errors.
function I.Read(ref)
	local facts = { ref = ref, f = {}, src = {}, err = {} }
	local f = facts.f
	facts.id = type(ref) == "number" and ref or I.IdFromLink(ref)
	if ref == nil then facts.err.info = "no item reference"; return facts end

	-- name, link, quality, item level, required level, type, subtype, stack, equip location, texture, sell price, class id, subclass id
	local info, infoName = I.Resolve("GetItemInfo")
	if not info then
		facts.err.info = "api absent"
	else
		local ok, r = call(info, ref)
		if not ok then
			facts.err.info = "error: " .. r
		elseif r[1] == nil or r[1] == "" then
			facts.unloaded = true
			facts.err.info = "blank/nil (not loaded yet)"
		else
			local keys = { "name", "link", "quality", "level", "minLevel", "type", "subType", "stack", "equipLoc", "texture", "sellPrice", "classID", "subClassID" }
			for i, k in ipairs(keys) do
				if r[i] ~= nil then f[k] = r[i]; facts.src[k] = infoName end
			end
		end
	end

	-- the cache-independent subset (class, subclass, equip location, icon), when the client has it
	local inst, instName = I.Resolve("GetItemInfoInstant")
	if not inst then
		facts.err.instant = "api absent"
	else
		local ok, r = call(inst, ref)
		if not ok then
			facts.err.instant = "error: " .. r
		elseif type(r[1]) ~= "number" then
			facts.err.instant = "returned nothing"
		else
			facts.instant = { id = r[1], type = r[2], subType = r[3], equipLoc = r[4], icon = r[5], classID = r[6], subClassID = r[7] }
			facts.src.instant = instName
		end
	end

	-- stats need an item link; a bare id is read through the link the info call returned
	local link = type(ref) == "string" and ref or f.link
	local stats, statsName = I.Resolve("GetItemStats")
	if not stats then
		facts.err.stats = "api absent"
	elseif type(link) ~= "string" then
		facts.err.stats = "no item link to read stats from"
	else
		local ok, r = call(stats, link)
		if not ok then
			facts.err.stats = "error: " .. r
		elseif type(r[1]) ~= "table" then
			facts.err.stats = "returned nothing"
		else
			f.stats = r[1]
			facts.src.stats = statsName
		end
	end

	local usable, usableName = I.Resolve("IsUsableItem")
	if not usable then
		facts.err.usable = "api absent"
	else
		local ok, r = call(usable, ref)
		if not ok then facts.err.usable = "error: " .. r
		elseif type(r[1]) ~= "boolean" then facts.err.usable = "returned nothing"
		else f.usable, f.usableSecond, facts.src.usable = r[1], r[2], usableName end
	end

	local spell, spellName = I.Resolve("GetItemSpell")
	if not spell then
		facts.err.spell = "api absent"
	else
		local ok, r = call(spell, ref)
		if not ok then
			facts.err.spell = "error: " .. r
		else
			facts.spellRead = true                      -- the call worked; most items simply have no use effect
			if type(r[1]) == "string" and r[1] ~= "" then f.spell, f.spellId, facts.src.spell = r[1], r[2], spellName end
		end
	end

	local count, countName = I.Resolve("GetItemCount")
	if not count then
		facts.err.count = "api absent"
	else
		local ok, r = call(count, ref)
		if not ok then facts.err.count = "error: " .. r
		elseif type(r[1]) ~= "number" then facts.err.count = "returned nothing"
		else f.count, facts.src.count = r[1], countName end
	end
	return facts
end

-- ---------------------------------------------------------------- the character's items

--- Equipped items: { { slot, link }, ... } and a reason when the API is missing.
function I.Equipped()
	local get = I.Resolve("GetInventoryItemLink")
	if not get then return {}, "api absent" end
	local out, errs = {}, 0
	for slot = 1, I.EQUIP_SLOTS do
		local ok, r = call(get, "player", slot)
		if not ok then errs = errs + 1 elseif type(r[1]) == "string" then out[#out + 1] = { slot = slot, link = r[1] } end
	end
	if errs == I.EQUIP_SLOTS then return out, "error on every slot" end
	return out, nil
end

local function stackCount(getInfo, bag, slot)
	if not getInfo then return nil end
	local ok, r = call(getInfo, bag, slot)
	if not ok then return nil end
	local c
	if type(r[1]) == "table" then c = r[1].stackCount else c = r[2] end
	return type(c) == "number" and c or nil
end

--- Items in the player's bags: { { bag, slot, link, count }, ... } and a reason when the API is missing.
function I.Bags()
	local numSlots = I.Resolve("GetContainerNumSlots")
	local getLink = I.Resolve("GetContainerItemLink")
	if not (numSlots and getLink) then return {}, "api absent" end
	local getInfo = I.Resolve("GetContainerItemInfo")
	local out = {}
	for bag = 0, I.MAX_BAGS do
		local ok, r = call(numSlots, bag)
		local n = ok and type(r[1]) == "number" and r[1] or 0
		for slot = 1, n do
			local okL, rl = call(getLink, bag, slot)
			if okL and type(rl[1]) == "string" then
				out[#out + 1] = { bag = bag, slot = slot, link = rl[1], count = stackCount(getInfo, bag, slot) }
			end
		end
	end
	return out, nil
end

-- ---------------------------------------------------------------- slot-level reads (Stage 2): an empty slot is not an API failure

--- One equipment slot: { slot, state, link, reason, src }. state: POPULATED (an item link came back), EMPTY (the call worked and returned nothing),
-- FAILED (api absent, an error, or an unusable result; reason says which).
function I.EquipmentSlot(slot)
	local get, name = I.Resolve("GetInventoryItemLink")
	local e = { slot = slot, src = name }
	if not get then
		e.state, e.reason = "FAILED", "api absent"
	else
		local ok, r = call(get, "player", slot)
		if not ok then e.state, e.reason = "FAILED", "error: " .. r
		elseif type(r[1]) == "string" and r[1] ~= "" then e.state, e.link = "POPULATED", r[1]
		elseif r[1] == nil then e.state = "EMPTY"
		else e.state, e.reason = "FAILED", "unusable result of type " .. type(r[1]) end
	end
	return e
end

--- Every equipment slot 1..EQUIP_SLOTS as I.EquipmentSlot results, indexed by slot.
function I.EquipmentSlots()
	local out = {}
	for slot = 1, I.EQUIP_SLOTS do out[slot] = I.EquipmentSlot(slot) end
	return out
end

--- One bag slot: { bag, slot, state, link, count, reason, src } with the same states as EquipmentSlots.
function I.BagSlot(bag, slot)
	local getLink, linkName = I.Resolve("GetContainerItemLink")
	local e = { bag = bag, slot = slot, src = linkName }
	if not getLink then e.state, e.reason = "FAILED", "api absent"; return e end
	local ok, r = call(getLink, bag, slot)
	if not ok then e.state, e.reason = "FAILED", "error: " .. r
	elseif type(r[1]) == "string" and r[1] ~= "" then
		e.state, e.link = "POPULATED", r[1]
		e.count = stackCount(I.Resolve("GetContainerItemInfo"), bag, slot)
	elseif r[1] == nil then e.state = "EMPTY"
	else e.state, e.reason = "FAILED", "unusable result of type " .. type(r[1]) end
	return e
end

--- The bag containers the client reports: { { bag, size, state, reason }, ... }, and a reason when the API is missing. size is the slot count.
function I.BagContainers()
	local numSlots = I.Resolve("GetContainerNumSlots")
	if not numSlots then return {}, "api absent" end
	local out = {}
	for bag = 0, I.MAX_BAGS do
		local ok, r = call(numSlots, bag)
		if not ok then out[#out + 1] = { bag = bag, state = "FAILED", reason = "error: " .. r }
		elseif type(r[1]) ~= "number" then out[#out + 1] = { bag = bag, state = "FAILED", reason = "unusable result" }
		else out[#out + 1] = { bag = bag, size = r[1], state = "OK" } end
	end
	return out, nil
end

--- The character's skill lines: { { name, rank, header }, ... } and a reason when the API is missing (classic GetNumSkillLines / GetSkillLineInfo).
function I.SkillLines()
	local num = I.Resolve("GetNumSkillLines")
	local info = I.Resolve("GetSkillLineInfo")
	if not (num and info) then return {}, "api absent" end
	local ok, r = call(num)
	if not ok then return {}, "error: " .. r end
	local n = type(r[1]) == "number" and r[1] or 0
	local out = {}
	for i = 1, n do
		local okI, ri = call(info, i)
		if okI and type(ri[1]) == "string" then out[#out + 1] = { name = ri[1], header = ri[2] == true or ri[2] == 1, rank = type(ri[4]) == "number" and ri[4] or nil } end
	end
	return out, nil
end

-- ================================================================ normalized ItemFacts (Stage 1)
--
-- ItemFacts = {
--   schema = 1, id = number|nil,
--   state = "LOADED" | "WAITING" (item data not loaded yet) | "FAILED" (the info call is absent or errored),
--   waiting = boolean,
--   fields = { id, name, link, quality, class, subclass, itemLevel, equipSlot, requiredLevel, vendorValue, stats, usable, useEffect, weaponType, weaponDps },
--   external = { questiedb = {...} } (only when QuestieDB answers; never mixed into fields), conflicts = { { field, client, external } },
-- }
-- Every field = { state, value, src, reason, ... }:
--   PROVEN    a real usable value was read from the client (src names the client function)
--   UNPROVEN  not successfully read yet: the item is still loading ("waiting for item data") or the field was not read. NEVER a failure.
--   FAILED    the API is absent, errored, or returned a genuinely unusable result (reason says which)
--   EMPTY     the API worked and returned an empty value (an empty stat table, an empty equip slot string, no use effect), or the field does not apply
--             (a weapon field on armor, reason "not a weapon"). EMPTY is NOT interpreted: an empty stat table does not mean "this item has no stats".
-- class / subclass also carry `text` (the client's type / subtype words). stats also carries `list`, `byStat` and `raw` (see below).

local function F(state, value, src, reason, extra)
	local t = { state = state, value = value, src = src, reason = reason }
	if extra then for k, v in pairs(extra) do t[k] = v end end
	return t
end

-- The stat keys Codex knows how to name. The stat table's KEYS come from the client (GetItemStats); this table only says what Codex believes a key means,
-- and `label` names a client GLOBAL STRING whose text should equal the key's own text if the belief is right (RESISTANCE0_NAME should read like ARMOR).
-- A key that is not here stays raw ("unmapped"). Nothing here is a claim about the Forever client until the report shows the label comparison.
I.STAT_KEYS = {
	RESISTANCE0_NAME        = { stat = "armor",     label = "ARMOR" },
	ITEM_MOD_STRENGTH_SHORT  = { stat = "strength",  label = "SPELL_STAT1_NAME" },
	ITEM_MOD_AGILITY_SHORT   = { stat = "agility",   label = "SPELL_STAT2_NAME" },
	ITEM_MOD_STAMINA_SHORT   = { stat = "stamina",   label = "SPELL_STAT3_NAME" },
	ITEM_MOD_INTELLECT_SHORT = { stat = "intellect", label = "SPELL_STAT4_NAME" },
	ITEM_MOD_SPIRIT_SHORT    = { stat = "spirit",    label = "SPELL_STAT5_NAME" },
}
local DPS_PATTERN = "DAMAGE_PER_SECOND"

local function globalText(name)
	local v = type(name) == "string" and rawget(_G, name) or nil
	return type(v) == "string" and v ~= "" and v or nil
end

--- A raw stat table { key = value } -> { list, byStat, raw }. list is sorted by key; each entry =
--   { key, value, stat, label, meaning }   meaning: "label-match" (the client's text for the key equals its text for the expected stat: canonical `stat` set),
--   "label-missing" (Codex's mapping applies but the client strings could not be compared: `stat` set, uncorroborated), "label-conflict" (the texts differ:
--   `stat` NOT set, raw kept), "key-pattern" (the weapon dps key, matched by name), "unmapped" (raw only).
-- byStat holds only entries whose canonical stat was set.
function I.NormalizeStats(raw)
	local keys = {}
	for k in pairs(raw) do keys[#keys + 1] = k end
	table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
	local list, byStat = {}, {}
	for _, k in ipairs(keys) do
		local v = raw[k]
		local e = { key = k, value = v, label = globalText(k) }
		local map = I.STAT_KEYS[k]
		if map then
			local expect = globalText(map.label)
			if e.label and expect then
				if e.label:lower() == expect:lower() then e.stat, e.meaning = map.stat, "label-match"
				else e.meaning = "label-conflict" end
			else
				e.stat, e.meaning = map.stat, "label-missing"
			end
		elseif tostring(k):find(DPS_PATTERN, 1, true) then
			e.stat, e.meaning = "weapon_dps", "key-pattern"
		else
			e.meaning = "unmapped"
		end
		if e.stat then byStat[e.stat] = (byStat[e.stat] or 0) + (type(v) == "number" and v or 0) end
		list[#list + 1] = e
	end
	return { list = list, byStat = byStat, raw = raw }
end

--- One raw read (I.Read) -> ItemFacts. Pure: no client calls except reading the client's own label strings for the stat comparison.
function I.Normalize(raw)
	raw = raw or { f = {}, src = {}, err = { info = "no item reference" } }
	local f, src, err = raw.f or {}, raw.src or {}, raw.err or {}
	local inst = raw.instant
	local waiting = raw.unloaded == true
	local infoFailed = err.info ~= nil and not waiting
	local facts = { schema = 1, id = raw.id, waiting = waiting, fields = {}, conflicts = {} }
	facts.state = infoFailed and "FAILED" or (waiting and "WAITING" or "LOADED")
	local fl = facts.fields

	local function missing()
		if waiting then return F("UNPROVEN", nil, nil, "waiting for item data") end
		if infoFailed then return F("FAILED", nil, nil, err.info) end
		return F("FAILED", nil, nil, "not returned")
	end
	local function numberField(key)
		if type(f[key]) == "number" then return F("PROVEN", f[key], src[key]) end
		return missing()
	end

	if raw.id then fl.id = F("PROVEN", raw.id, type(raw.ref) == "number" and "argument" or "item link")
	elseif inst and type(inst.id) == "number" then fl.id = F("PROVEN", inst.id, src.instant)
	else fl.id = F("FAILED", nil, nil, "no item id") end
	facts.id = facts.id or fl.id.value

	if type(f.name) == "string" and f.name ~= "" then fl.name = F("PROVEN", f.name, src.name) else fl.name = missing() end
	if type(f.link) == "string" and f.link ~= "" then fl.link = F("PROVEN", f.link, src.link)
	elseif type(raw.ref) == "string" and raw.ref:find("item:", 1, true) then fl.link = F("PROVEN", raw.ref, "item link given")
	else fl.link = missing() end
	fl.quality = numberField("quality")

	-- class and subclass: the info call, or the cache-independent instant call when the item has not loaded yet
	local function classLike(key, textKey, instKey, instTextKey)
		if type(f[key]) == "number" then return F("PROVEN", f[key], src[key], nil, { text = f[textKey] }) end
		if inst and type(inst[instKey]) == "number" then return F("PROVEN", inst[instKey], src.instant, nil, { text = inst[instTextKey] }) end
		return missing()
	end
	fl.class = classLike("classID", "type", "classID", "type")
	fl.subclass = classLike("subClassID", "subType", "subClassID", "subType")

	if type(f.equipLoc) == "string" then
		fl.equipSlot = f.equipLoc ~= "" and F("PROVEN", f.equipLoc, src.equipLoc) or F("EMPTY", "", src.equipLoc, "the client returned an empty equip slot")
	elseif inst and type(inst.equipLoc) == "string" then
		fl.equipSlot = inst.equipLoc ~= "" and F("PROVEN", inst.equipLoc, src.instant) or F("EMPTY", "", src.instant, "the client returned an empty equip slot")
	else
		fl.equipSlot = missing()
	end
	fl.itemLevel = numberField("level")
	fl.requiredLevel = numberField("minLevel")
	fl.vendorValue = numberField("sellPrice")

	-- the read of usable / use effect / stats depends on the item being loaded: while it is not, none of them means anything yet
	if waiting then
		fl.usable = F("UNPROVEN", nil, nil, "waiting for item data")
	elseif err.usable then
		fl.usable = F("FAILED", nil, nil, err.usable)
	elseif type(f.usable) == "boolean" then
		fl.usable = F("PROVEN", f.usable, src.usable, nil, { second = f.usableSecond })
	else
		fl.usable = F("FAILED", nil, nil, "not returned")
	end

	if waiting then
		fl.useEffect = F("UNPROVEN", nil, nil, "waiting for item data")
	elseif err.spell then
		fl.useEffect = F("FAILED", nil, nil, err.spell)
	elseif f.spell then
		fl.useEffect = F("PROVEN", f.spell, src.spell, nil, { spellId = f.spellId })
	else
		fl.useEffect = F("EMPTY", nil, nil, "the call worked and returned no spell")
	end

	if waiting then
		fl.stats = F("UNPROVEN", nil, nil, "waiting for item data")
	elseif err.stats then
		fl.stats = F("FAILED", nil, nil, err.stats)
	elseif type(f.stats) == "table" and next(f.stats) ~= nil then
		local n = I.NormalizeStats(f.stats)
		fl.stats = F("PROVEN", n.byStat, src.stats, nil, { list = n.list, byStat = n.byStat, raw = n.raw })
	elseif type(f.stats) == "table" then
		fl.stats = F("EMPTY", nil, src.stats, "the client returned an empty stat table (not interpreted)", { list = {}, byStat = {}, raw = {} })
	else
		fl.stats = F("FAILED", nil, nil, "not returned")
	end

	-- weapon type and dps: only meaningful for a weapon (item class 2)
	local classID = fl.class.state == "PROVEN" and fl.class.value or nil
	if classID == nil then
		fl.weaponType = F("UNPROVEN", nil, nil, fl.class.reason or "item class not known yet")
		fl.weaponDps = F("UNPROVEN", nil, nil, fl.class.reason or "item class not known yet")
	elseif classID ~= 2 then
		fl.weaponType = F("EMPTY", nil, nil, "not a weapon")
		fl.weaponDps = F("EMPTY", nil, nil, "not a weapon")
	else
		if fl.subclass.state == "PROVEN" then
			fl.weaponType = F("PROVEN", fl.subclass.value, fl.subclass.src, nil, { text = fl.subclass.text })
		else
			fl.weaponType = F(fl.subclass.state, nil, nil, fl.subclass.reason)
		end
		if fl.stats.state == "PROVEN" or fl.stats.state == "EMPTY" then
			local dps, key
			for _, e in ipairs(fl.stats.list) do if e.stat == "weapon_dps" and type(e.value) == "number" then dps, key = e.value, e.key end end
			if dps then fl.weaponDps = F("PROVEN", dps, fl.stats.src, nil, { key = key })
			else fl.weaponDps = F("EMPTY", nil, fl.stats.src, "the stat table has no dps key") end
		else
			fl.weaponDps = F(fl.stats.state, nil, nil, fl.stats.reason)
		end
	end
	return facts
end

-- ---------------------------------------------------------------- the optional QuestieDB cross-reference (never overrides the client)

--- What QuestieDB's documented consumer API says about an item id, kept apart from the client's facts: { src = "questiedb", verified = false, exists,
-- name, class, subClass, itemLevel, requiredLevel }, or nil when QuestieDB is not installed or has no Item table. exists = false means "unknown to QuestieDB",
-- not "no such item" (QuestieDB has no Forever-added items).
function I.External(id)
	local lib = rawget(_G, "LibQuestieDB")
	if type(id) ~= "number" or type(lib) ~= "table" or type(lib.Item) ~= "table" then return nil end
	local Item = lib.Item
	local out = { src = "questiedb", verified = false }
	local okE, e = pcall(Item.Exists, id)
	out.exists = okE and e == true
	if not out.exists then return out end
	for _, k in ipairs({ "name", "class", "subClass", "itemLevel", "requiredLevel" }) do
		local ok, v = pcall(Item.Get, id, k)
		if ok and v ~= nil then out[k] = v end
	end
	return out
end

--- Attaches facts.external.questiedb and records disagreements in facts.conflicts (field, the client's value, QuestieDB's value). The client's fields are
-- never changed. Returns facts.
function I.Annotate(facts)
	local x = I.External(facts.id)
	if not x then return facts end
	facts.external = { questiedb = x }
	if x.exists then
		local fl = facts.fields
		for _, pair in ipairs({ { "name", "name" }, { "class", "class" }, { "subclass", "subClass" }, { "itemLevel", "itemLevel" }, { "requiredLevel", "requiredLevel" } }) do
			local c, e = fl[pair[1]], x[pair[2]]
			if c and c.state == "PROVEN" and e ~= nil and c.value ~= e then
				facts.conflicts[#facts.conflicts + 1] = { field = pair[1], client = c.value, external = e }
			end
		end
	end
	return facts
end

--- One call: read the item, normalize it, cross-reference QuestieDB. ref = an item link or a numeric item id.
function I.Facts(ref)
	return I.Annotate(I.Normalize(I.Read(ref)))
end
