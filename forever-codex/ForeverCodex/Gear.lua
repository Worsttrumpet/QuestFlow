-- ForeverCodex.Gear: Stage 2 of the Reward Advisor, the shared equipped / bag item facts reader and a FACTS-ONLY comparison helper.
--
-- It answers "what is equipped in each slot, what is in the bags, and how do two items differ?" using the Stage 1 normalized ItemFacts. It builds no second
-- item reader and no second loading queue: every item goes through Items.Facts, and an item whose data has not loaded yet (WAITING) is registered on
-- ItemProbe's one late-loading queue (ItemProbe.Watch), which refreshes the fact in place when GET_ITEM_INFO_RECEIVED arrives.
--
-- It makes no judgement. There is no score, no "upgrade", no recommendation, no take/sell, no replacement logic and no class or proficiency inference. Unknown
-- stays unknown: an empty slot is EMPTY (not a failure, not "no item" for a failed read), a loading item is WAITING, a missing API is FAILED, and a comparison
-- involving anything not PROVEN says UNKNOWN with the reason rather than a zero.
--
--   EquipmentFact { slot, slotName, state = POPULATED | EMPTY | FAILED, itemId, link, itemFacts, src, reason }
--   BagFact       { bag, slot, state = POPULATED | EMPTY | FAILED, itemId, count, link, itemFacts, src, reason }
-- Independent of the planner, strategies, presenter and UI. The only consumer is the report (Gear.ReportLines).

local addonName, ns = ...

local G = {}
ns.Gear = G

local I = ns.Items

G.SLOT_NAMES = { "HEAD", "NECK", "SHOULDER", "SHIRT", "CHEST", "WAIST", "LEGS", "FEET", "WRIST", "HANDS", "FINGER1", "FINGER2", "TRINKET1", "TRINKET2",
	"BACK", "MAINHAND", "OFFHAND", "RANGED", "TABARD" }

-- Which inventory slots an item's equip location (INVTYPE_*, as the client returns it) can go in. A static table of the game's own slot ids, NOT item data and NOT
-- verified on Forever beyond the equip locations seen so far (an equip location that is not listed stays UNKNOWN: nothing is guessed). Two-handed weapons are
-- listed under the main hand only.
G.SLOTS_FOR = {
	INVTYPE_HEAD = { 1 }, INVTYPE_NECK = { 2 }, INVTYPE_SHOULDER = { 3 }, INVTYPE_BODY = { 4 }, INVTYPE_CHEST = { 5 }, INVTYPE_ROBE = { 5 },
	INVTYPE_WAIST = { 6 }, INVTYPE_LEGS = { 7 }, INVTYPE_FEET = { 8 }, INVTYPE_WRIST = { 9 }, INVTYPE_HAND = { 10 }, INVTYPE_FINGER = { 11, 12 },
	INVTYPE_TRINKET = { 13, 14 }, INVTYPE_CLOAK = { 15 }, INVTYPE_WEAPON = { 16, 17 }, INVTYPE_SHIELD = { 17 }, INVTYPE_2HWEAPON = { 16 },
	INVTYPE_WEAPONMAINHAND = { 16 }, INVTYPE_WEAPONOFFHAND = { 17 }, INVTYPE_HOLDABLE = { 17 }, INVTYPE_RANGED = { 18 }, INVTYPE_RANGEDRIGHT = { 18 },
	INVTYPE_THROWN = { 18 }, INVTYPE_RELIC = { 18 }, INVTYPE_TABARD = { 19 },
}

local function wall() return type(time) == "function" and time() or 0 end

--- The inventory slots a normalized item can go in: `slots, nil` or `nil, reason` ("equip slot not PROVEN", "no equip slot", "equip slot X is not in the slot table").
function G.SlotsFor(facts)
	local f = facts and facts.fields and facts.fields.equipSlot
	if not f then return nil, "no facts" end
	if f.state == "EMPTY" then return nil, "no equip slot" end
	if f.state ~= "PROVEN" then return nil, "equip slot " .. f.state .. (f.reason and (" (" .. f.reason .. ")") or "") end
	local slots = G.SLOTS_FOR[f.value]
	if not slots then return nil, "equip slot " .. tostring(f.value) .. " is not in Codex's slot table" end
	return slots, nil
end

-- ---------------------------------------------------------------- reading the character

local function watch(key, entry)
	-- an item that has not loaded yet is refreshed in place by the one late-loading queue
	if entry.itemFacts and entry.itemFacts.waiting and ns.ItemProbe and ns.ItemProbe.Watch then
		ns.ItemProbe.Watch(key, entry.link, function(raw) entry.itemFacts = I.Annotate(I.Normalize(raw)) end)
	end
end

local function attach(key, entry)
	entry.itemFacts = I.Facts(entry.link)
	entry.itemId = entry.itemFacts.id
	watch(key, entry)
end

local function equipEntry(r)
	local e = { slot = r.slot, slotName = G.SLOT_NAMES[r.slot], state = r.state, link = r.link, src = r.src, reason = r.reason }
	if r.state == "POPULATED" then attach("equip:" .. r.slot, e) end
	return e
end

--- The equipment: { state = "OK" | "FAILED", reason, slots = { [1..19] = EquipmentFact }, list = { EquipmentFact in slot order } }.
-- Every slot is present: POPULATED (with its normalized itemFacts), EMPTY (the slot was read and holds nothing) or FAILED (the read itself failed).
-- `slot` is the ACTUAL equipment slot that was read; the item's own equip location is itemFacts.fields.equipSlot (the two stay separate).
function G.Equipped()
	local raw = I.EquipmentSlots()
	local out = { state = "OK", slots = {}, list = {} }
	local failed = 0
	for slot = 1, I.EQUIP_SLOTS do
		local e = equipEntry(raw[slot])
		if e.state == "FAILED" then failed = failed + 1 end
		out.slots[slot], out.list[#out.list + 1] = e, e
	end
	if failed == I.EQUIP_SLOTS then out.state, out.reason = "FAILED", raw[1].reason end
	return out
end

--- One bag slot as a BagFact (POPULATED / EMPTY / FAILED), with normalized itemFacts when populated.
function G.BagSlot(bag, slot)
	local r = I.BagSlot(bag, slot)
	local e = { bag = bag, slot = slot, state = r.state, link = r.link, count = r.count, src = r.src, reason = r.reason }
	if r.state == "POPULATED" then attach("bag:" .. bag .. ":" .. slot, e) end
	return e
end

--- The bags: { state = "OK" | "FAILED", reason, containers = { { bag, size, state, reason, empty, populated } }, stacks = { BagFact (populated only) } }.
-- Empty slots are counted per container (not listed one by one); G.BagSlot reads any single slot, empty or not.
function G.Bags()
	local out = { state = "OK", containers = {}, stacks = {} }
	local containers, err = I.BagContainers()
	if err then out.state, out.reason = "FAILED", err; return out end
	for _, c in ipairs(containers) do
		local row = { bag = c.bag, size = c.size, state = c.state, reason = c.reason, empty = 0, populated = 0, failed = 0 }
		if c.state == "OK" then
			for slot = 1, c.size do
				local e = G.BagSlot(c.bag, slot)
				if e.state == "POPULATED" then row.populated = row.populated + 1; out.stacks[#out.stacks + 1] = e
				elseif e.state == "EMPTY" then row.empty = row.empty + 1
				else row.failed = row.failed + 1 end
			end
		end
		out.containers[#out.containers + 1] = row
	end
	return out
end

-- ---------------------------------------------------------------- refresh (events reuse ItemProbe's event frame)

G.stats = { equipmentEvents = 0, slotRefreshes = 0, bagEvents = 0, bagRescans = 0 }
G.dirty = { equipment = false, bags = false }

--- Equipment and bags together: { t, equipped, bags }, read NOW. Remembered as G.last (the late-loading watchers refresh its entries in place).
function G.Snapshot()
	local snap = { t = wall(), equipped = G.Equipped(), bags = G.Bags() }
	G.last = snap
	G.dirty.equipment, G.dirty.bags = false, false
	return snap
end

--- The event-maintained snapshot: read once, then kept current by PLAYER_EQUIPMENT_CHANGED (the one changed slot is re-read) and BAG_UPDATE_DELAYED (the bags
-- are re-read the next time they are asked for). Item data that finishes loading refreshes the entries in place. Use G.Snapshot() to force a fresh read.
function G.Get()
	local snap = G.last
	if not snap then return G.Snapshot() end
	if G.dirty.equipment then snap.equipped = G.Equipped(); G.dirty.equipment = false end
	if G.dirty.bags then snap.bags = G.Bags(); G.dirty.bags = false; G.stats.bagRescans = G.stats.bagRescans + 1 end
	return snap
end

--- PLAYER_EQUIPMENT_CHANGED(slot, hasCurrent): re-reads just that slot. An unusable slot argument marks the whole equipment dirty instead.
function G.OnEquipmentChanged(slot)
	G.stats.equipmentEvents = G.stats.equipmentEvents + 1
	if not G.last then return end
	if type(slot) == "number" and slot >= 1 and slot <= I.EQUIP_SLOTS then
		local e = equipEntry(I.EquipmentSlot(slot))
		G.last.equipped.slots[slot] = e
		G.last.equipped.list[slot] = e
		G.stats.slotRefreshes = G.stats.slotRefreshes + 1
	else
		G.dirty.equipment = true
	end
end

--- BAG_UPDATE_DELAYED: the bags changed somewhere; they are re-read the next time G.Get() is called (correctness first, no per-slot bookkeeping).
function G.OnBagsChanged()
	G.stats.bagEvents = G.stats.bagEvents + 1
	if G.last then G.dirty.bags = true end
end

--- Counts for the report, computed on demand so they follow late-resolved facts: populated / empty / failedSlots, and over the populated items
-- normalized (LOADED), waiting (WAITING) and failed (FAILED).
local function tally(entries)
	local t = { populated = 0, empty = 0, slotFailed = 0, normalized = 0, waiting = 0, failed = 0 }
	for _, e in ipairs(entries) do
		if e.state == "POPULATED" then
			t.populated = t.populated + 1
			local st = e.itemFacts and e.itemFacts.state
			if st == "LOADED" then t.normalized = t.normalized + 1 elseif st == "WAITING" then t.waiting = t.waiting + 1 else t.failed = t.failed + 1 end
		elseif e.state == "EMPTY" then t.empty = t.empty + 1
		else t.slotFailed = t.slotFailed + 1 end
	end
	return t
end
function G.EquippedSummary(eq) return tally(eq.list) end
function G.BagSummary(bags)
	local t = tally(bags.stacks)
	local ids = {}
	t.unique = 0
	for _, e in ipairs(bags.stacks) do
		if e.itemId and not ids[e.itemId] then ids[e.itemId] = true; t.unique = t.unique + 1 end
	end
	t.containers, t.emptySlots, t.slotFailed = #bags.containers, 0, 0
	for _, c in ipairs(bags.containers) do t.emptySlots = t.emptySlots + (c.empty or 0); t.slotFailed = t.slotFailed + (c.failed or 0) end
	return t
end

-- ---------------------------------------------------------------- comparison: facts only

local STATS = { "armor", "strength", "agility", "stamina", "intellect", "spirit" }
G.COMPARED_STATS = STATS

local function brief(facts)
	if not facts then return { id = nil, name = nil } end
	local n = facts.fields and facts.fields.name
	return { id = facts.id, name = (n and n.state == "PROVEN") and n.value or nil, state = facts.state }
end

local function why(fa, fb)
	local parts = {}
	if fa.state ~= "PROVEN" then parts[#parts + 1] = "first: " .. fa.state .. (fa.reason and (" (" .. fa.reason .. ")") or "") end
	if fb.state ~= "PROVEN" then parts[#parts + 1] = "second: " .. fb.state .. (fb.reason and (" (" .. fb.reason .. ")") or "") end
	return table.concat(parts, "; ")
end

--- A scalar field of two items: { state = "COMPARED", a, b, same, diff (numbers: a - b), aText, bText } when both are PROVEN, else { state = "UNKNOWN", reason }.
local function scalar(a, b, key)
	local fa, fb = a.fields[key], b.fields[key]
	if fa.state == "PROVEN" and fb.state == "PROVEN" then
		local e = { state = "COMPARED", a = fa.value, b = fb.value, same = fa.value == fb.value, aText = fa.text, bText = fb.text }
		if type(fa.value) == "number" and type(fb.value) == "number" then e.diff = fa.value - fb.value end
		return e
	end
	return { state = "UNKNOWN", reason = why(fa, fb) }
end

local function conflictedStats(facts)
	local out = {}
	local st = facts.fields.stats
	for _, e in ipairs(st.list or {}) do
		local map = I.STAT_KEYS[e.key]
		if map and e.meaning == "label-conflict" then out[map.stat] = e.key end
	end
	return out
end

local function meaningOf(facts, stat)
	for _, e in ipairs(facts.fields.stats.list or {}) do if e.stat == stat then return e.meaning end end
	return nil
end

--- Compares two normalized ItemFacts and reports ONLY the factual differences. Pure; no judgement.
--   { schema, a = {id, name, state}, b = {...},
--     slot = { state = SAME | SHARED | DIFFERENT | NO_SLOT | UNKNOWN, a, b, shared = { inventory slots }, reason },
--     class, subclass, itemLevel, requiredLevel, usable = scalar results,
--     stats = { armor, strength, agility, stamina, intellect, spirit, weapon_dps = stat results },
--     unmapped = { keys present in either item's stat table that Codex does not name } }
-- A stat result: { state = COMPARED (a, b, diff, assumedZero = { a = bool, b = bool }, meaning = { a, b }) | NOT_LISTED (neither item lists it) |
-- NOT_APPLICABLE (weapon dps on a non-weapon) | UNKNOWN (reason) }. "assumedZero" says a side did not list the stat in a stat table the client PROVED, so the
-- difference counts it as 0; an EMPTY, waiting, failed or label-conflicted stat table makes the result UNKNOWN, never zero.
function G.Compare(a, b)
	local out = { schema = 1, a = brief(a), b = brief(b), stats = {}, unmapped = {} }
	if not (a and a.fields and b and b.fields) then
		out.slot = { state = "UNKNOWN", reason = "an item has no facts" }
		return out
	end
	-- the equip slot
	local sa, sb = a.fields.equipSlot, b.fields.equipSlot
	if sa.state == "PROVEN" and sb.state == "PROVEN" then
		local ua, ub = G.SLOTS_FOR[sa.value], G.SLOTS_FOR[sb.value]
		if sa.value == sb.value then
			out.slot = { state = "SAME", a = sa.value, b = sb.value, shared = ua }
		elseif ua and ub then
			local shared = {}
			for _, x in ipairs(ua) do for _, y in ipairs(ub) do if x == y then shared[#shared + 1] = x end end end
			out.slot = { state = #shared > 0 and "SHARED" or "DIFFERENT", a = sa.value, b = sb.value, shared = shared }
		else
			out.slot = { state = "UNKNOWN", a = sa.value, b = sb.value, reason = "an equip location is not in Codex's slot table" }
		end
	elseif sa.state == "EMPTY" or sb.state == "EMPTY" then
		out.slot = { state = "NO_SLOT", a = sa.value, b = sb.value, reason = "an item has no equip slot" }
	else
		out.slot = { state = "UNKNOWN", reason = why(sa, sb) }
	end
	out.class, out.subclass = scalar(a, b, "class"), scalar(a, b, "subclass")
	out.itemLevel, out.requiredLevel, out.usable = scalar(a, b, "itemLevel"), scalar(a, b, "requiredLevel"), scalar(a, b, "usable")

	-- stats: only when both stat tables are PROVEN (an EMPTY table is not interpreted as "no stats")
	local sta, stb = a.fields.stats, b.fields.stats
	local bothKnown = sta.state == "PROVEN" and stb.state == "PROVEN"
	local ca, cb = bothKnown and conflictedStats(a) or {}, bothKnown and conflictedStats(b) or {}
	for _, stat in ipairs(STATS) do
		if not bothKnown then
			out.stats[stat] = { state = "UNKNOWN", reason = why(sta, stb) }
		elseif ca[stat] or cb[stat] then
			out.stats[stat] = { state = "UNKNOWN", reason = "the client's text for " .. tostring(ca[stat] or cb[stat]) .. " does not match the stat Codex expects for that key (label-conflict)" }
		else
			local va, vb = sta.byStat[stat], stb.byStat[stat]
			if va == nil and vb == nil then
				out.stats[stat] = { state = "NOT_LISTED" }
			else
				out.stats[stat] = { state = "COMPARED", a = va, b = vb, diff = (va or 0) - (vb or 0), assumedZero = { a = va == nil, b = vb == nil },
					meaning = { a = meaningOf(a, stat), b = meaningOf(b, stat) } }
			end
		end
	end
	-- weapon dps
	local da, db = a.fields.weaponDps, b.fields.weaponDps
	if da.state == "PROVEN" and db.state == "PROVEN" then
		out.stats.weapon_dps = { state = "COMPARED", a = da.value, b = db.value, diff = da.value - db.value }
	elseif (da.state == "EMPTY" and da.reason == "not a weapon") or (db.state == "EMPTY" and db.reason == "not a weapon") then
		out.stats.weapon_dps = { state = "NOT_APPLICABLE", reason = "not a weapon" }
	else
		out.stats.weapon_dps = { state = "UNKNOWN", reason = why(da, db) }
	end
	-- raw stat keys Codex does not name, so a later layer knows the comparison above is partial
	if sta.state == "PROVEN" or stb.state == "PROVEN" then
		local seen = {}
		for _, st in ipairs({ sta, stb }) do
			for _, e in ipairs(st.list or {}) do
				if (e.meaning == "unmapped" or e.meaning == "label-conflict") and not seen[e.key] then seen[e.key] = true; out.unmapped[#out.unmapped + 1] = e.key end
			end
		end
		table.sort(out.unmapped)
	end
	return out
end

--- Compares an item (normalized facts) with whatever is equipped in the slot(s) it can go in:
--   { state = COMPARABLE | NO_SLOT | UNKNOWN, reason, entries = { { slot, slotName, state, equipment, comparison, reason } } }
-- entry.state: COMPARED (an equipped item with comparison), EMPTY_SLOT (the slot holds nothing: a fact, not an unknown), UNKNOWN (the slot read failed, or the
-- equipped item is not loaded enough: its comparison, if any, says which fields are UNKNOWN).
function G.CompareToEquipped(facts, equipped)
	local slots, reason = G.SlotsFor(facts)
	if not slots then
		local noSlot = facts and facts.fields and facts.fields.equipSlot and facts.fields.equipSlot.state == "EMPTY"
		return { state = noSlot and "NO_SLOT" or "UNKNOWN", reason = reason, entries = {} }
	end
	local out = { state = "COMPARABLE", entries = {} }
	for _, n in ipairs(slots) do
		local eq = equipped and equipped.slots and equipped.slots[n]
		local entry = { slot = n, slotName = G.SLOT_NAMES[n], equipment = eq }
		if not eq or eq.state == "FAILED" then
			entry.state, entry.reason = "UNKNOWN", eq and ("the slot could not be read: " .. tostring(eq.reason)) or "the slot was not read"
		elseif eq.state == "EMPTY" then
			entry.state = "EMPTY_SLOT"
		else
			entry.comparison = G.Compare(facts, eq.itemFacts)
			entry.state = (eq.itemFacts and eq.itemFacts.state == "LOADED") and "COMPARED" or "UNKNOWN"
			if entry.state == "UNKNOWN" then entry.reason = "the equipped item's facts are " .. tostring(eq.itemFacts and eq.itemFacts.state) end
		end
		out.entries[#out.entries + 1] = entry
	end
	return out
end

-- ---------------------------------------------------------------- the report section

local function num(v) if v == nil then return "-" end return tostring(v) end

local function statWord(name, r)
	if r.state == "COMPARED" then
		local d = r.diff
		return string.format("%s %s vs %s (diff %s%s)", name, num(r.a), num(r.b), (type(d) == "number" and d > 0) and "+" or "", num(d))
	elseif r.state == "NOT_LISTED" then return nil end
	return name .. " " .. r.state
end

local function comparisonLine(label, cand, entry)
	local head = string.format("%s (%s) vs slot %d %s", label, tostring(cand.fields.equipSlot.value), entry.slot, entry.slotName)
	if entry.state == "EMPTY_SLOT" then return head .. ": the slot is empty" end
	if not entry.comparison then return head .. ": " .. entry.state .. " (" .. tostring(entry.reason) .. ")" end
	local c = entry.comparison
	local parts = { "equipped " .. (c.b.name or "(name not loaded)") .. " [" .. tostring(c.b.state) .. "]", "slot " .. c.slot.state }
	for _, k in ipairs({ "armor", "strength", "agility", "stamina", "intellect", "spirit", "weapon_dps" }) do
		local w = statWord(k, c.stats[k])
		if w and c.stats[k].state ~= "NOT_APPLICABLE" then parts[#parts + 1] = w end
	end
	parts[#parts + 1] = "req level " .. (c.requiredLevel.state == "COMPARED" and (num(c.requiredLevel.a) .. " vs " .. num(c.requiredLevel.b)) or c.requiredLevel.state)
	parts[#parts + 1] = "usable " .. (c.usable.state == "COMPARED" and (tostring(c.usable.a) .. " vs " .. tostring(c.usable.b)) or c.usable.state)
	return head .. ": " .. table.concat(parts, " | ")
end

--- The EQUIPPED ITEM FACTS / BAG ITEM FACTS / COMPARISON FACTS lines of /codex report. Reads the equipment and bags now. Never errors.
function G.ReportLines()
	local L = {}
	local ok, snap = pcall(G.Snapshot)
	if not ok then
		L[#L + 1] = "EQUIPPED ITEM FACTS: error: " .. tostring(snap)
		return L
	end
	local eq, bags = snap.equipped, snap.bags
	local function itemWord(e)
		local fl = e.itemFacts.fields
		local nm = fl.name.state == "PROVEN" and fl.name.value or "(name not loaded)"
		return string.format("%s (id %s)", nm, tostring(e.itemId))
	end
	if eq.state == "FAILED" then
		L[#L + 1] = "EQUIPPED ITEM FACTS: FAILED (" .. tostring(eq.reason) .. ")"
	else
		local t = G.EquippedSummary(eq)
		L[#L + 1] = string.format("EQUIPPED ITEM FACTS: occupied slots %d of %d | facts loaded %d | waiting %d | failed %d | empty slots %d | slot reads failed %d",
			t.populated, I.EQUIP_SLOTS, t.normalized, t.waiting, t.failed, t.empty, t.slotFailed)
		for _, e in ipairs(eq.list) do
			if e.state == "POPULATED" then
				local es = e.itemFacts.fields.equipSlot
				L[#L + 1] = string.format("  slot %d %s: %s %s | item equip location %s", e.slot, e.slotName, itemWord(e), e.itemFacts.state, es.state == "PROVEN" and es.value or es.state)
			end
		end
	end
	if bags.state == "FAILED" then
		L[#L + 1] = "BAG ITEM FACTS: FAILED (" .. tostring(bags.reason) .. ")"
	else
		local t = G.BagSummary(bags)
		L[#L + 1] = string.format("BAG ITEM FACTS: occupied stacks %d | unique item ids %d | facts loaded %d | waiting %d | failed %d | containers read %d (empty slots %d, slot reads failed %d)",
			t.populated, t.unique, t.normalized, t.waiting, t.failed, t.containers, t.emptySlots, t.slotFailed)
		for i, e in ipairs(bags.stacks) do
			if i > 24 then L[#L + 1] = string.format("  + %d more stacks", #bags.stacks - 24); break end
			L[#L + 1] = string.format("  bag %d slot %d: %s x%s %s", e.bag, e.slot, itemWord(e), e.count and tostring(e.count) or "?", e.itemFacts.state)
		end
	end
	L[#L + 1] = string.format("  refresh events seen: PLAYER_EQUIPMENT_CHANGED %d (slot re-reads %d) | BAG_UPDATE_DELAYED %d (bag re-reads %d) | items waiting for data %d",
		G.stats.equipmentEvents, G.stats.slotRefreshes, G.stats.bagEvents, G.stats.bagRescans, ns.ItemProbe and ns.ItemProbe.PendingCount and ns.ItemProbe.PendingCount() or 0)
	-- the offered reward items against what is equipped in their slot: differences only
	local df = ns.ItemProbe and ns.ItemProbe.DialogFacts and ns.ItemProbe.DialogFacts(true)
	if df and (#df.choices + #df.rewards) > 0 and eq.state ~= "FAILED" then
		L[#L + 1] = "COMPARISON FACTS (offered reward item vs the item in the same slot; differences only, no judgement; '-' = the item does not list the stat):"
		for _, spec in ipairs({ { "Choice", df.choices }, { "Reward", df.rewards } }) do
			for i, it in ipairs(spec[2]) do
				local cmp = G.CompareToEquipped(it.facts, eq)
				local label = spec[1] .. " " .. i
				if #cmp.entries == 0 then
					L[#L + 1] = string.format("%s: %s (%s)", label, cmp.state, tostring(cmp.reason))
				else
					for _, entry in ipairs(cmp.entries) do L[#L + 1] = comparisonLine(label, it.facts, entry) end
				end
			end
		end
	end
	return L
end
