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
	local info, infoName = find("C_Item", "GetItemInfo", "GetItemInfo")
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
	local inst, instName = find("C_Item", "GetItemInfoInstant", "GetItemInfoInstant")
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
	local stats, statsName = find("C_Item", "GetItemStats", "GetItemStats")
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

	local usable, usableName = find("C_Item", "IsUsableItem", "IsUsableItem")
	if not usable then
		facts.err.usable = "api absent"
	else
		local ok, r = call(usable, ref)
		if not ok then facts.err.usable = "error: " .. r
		elseif type(r[1]) ~= "boolean" then facts.err.usable = "returned nothing"
		else f.usable, facts.src.usable = r[1], usableName end
	end

	local spell, spellName = find("C_Item", "GetItemSpell", "GetItemSpell")
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

	local count, countName = find("C_Item", "GetItemCount", "GetItemCount")
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
	local get = find(nil, nil, "GetInventoryItemLink")
	if not get then return {}, "api absent" end
	local out, errs = {}, 0
	for slot = 1, I.EQUIP_SLOTS do
		local ok, r = call(get, "player", slot)
		if not ok then errs = errs + 1 elseif type(r[1]) == "string" then out[#out + 1] = { slot = slot, link = r[1] } end
	end
	if errs == I.EQUIP_SLOTS then return out, "error on every slot" end
	return out, nil
end

--- Items in the player's bags: { { bag, slot, link, count }, ... } and a reason when the API is missing.
function I.Bags()
	local numSlots = find("C_Container", "GetContainerNumSlots", "GetContainerNumSlots")
	local getLink = find("C_Container", "GetContainerItemLink", "GetContainerItemLink")
	if not (numSlots and getLink) then return {}, "api absent" end
	local getInfo = find("C_Container", "GetContainerItemInfo", "GetContainerItemInfo")
	local out = {}
	for bag = 0, I.MAX_BAGS do
		local ok, r = call(numSlots, bag)
		local n = ok and type(r[1]) == "number" and r[1] or 0
		for slot = 1, n do
			local okL, rl = call(getLink, bag, slot)
			if okL and type(rl[1]) == "string" then
				local count
				if getInfo then
					local okI, ri = call(getInfo, bag, slot)
					if okI then
						if type(ri[1]) == "table" then count = ri[1].stackCount else count = ri[2] end
					end
				end
				out[#out + 1] = { bag = bag, slot = slot, link = rl[1], count = type(count) == "number" and count or nil }
			end
		end
	end
	return out, nil
end

--- The character's skill lines: { { name, rank, header }, ... } and a reason when the API is missing (classic GetNumSkillLines / GetSkillLineInfo).
function I.SkillLines()
	local num = find(nil, nil, "GetNumSkillLines")
	local info = find(nil, nil, "GetSkillLineInfo")
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
