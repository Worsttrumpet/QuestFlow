-- advisor_tests.lua: Stage 3, the REWARD ADVISOR (RewardAdvisor.lua). Synthetic ItemFacts built from raw reads (no real items are hard-coded into the advisor);
-- a few integration tests use a stub client for the open-versus-closed reward dialog. They prove the classification logic, the evidence handling and the
-- separation of layers. They say nothing about what the real Forever client returns.

local H = ...
local check, section, boot = H.check, H.section, H.boot

local ns = boot({ char = { level = 9 } })
local A, G, I = ns.Advisor, ns.Gear, ns.Items

-- ---------------------------------------------------------------- synthetic facts

--- o = { id, name, slot (equip location), stats (table, or nil = an EMPTY table), sell, req, classID, sub, spell, usable, second, flag, waiting, noStats }
local function facts(o)
	local f = { name = o.name, link = "|Hitem:" .. (o.id or 1) .. "::|h[" .. o.name .. "]|h", quality = 1, level = o.ilvl or 8, minLevel = o.req or 0, type = o.type or "Armor",
		subType = o.subType or "Leather", equipLoc = o.slot or "", sellPrice = o.sell, classID = o.classID or 4, subClassID = o.sub or 2, stats = o.stats or {}, spell = o.spell,
		spellId = o.spell and 99 or nil, usable = o.usable, usableSecond = o.second }
	local r = { id = o.id or 1, ref = o.id or 1, f = f, src = {}, err = {}, spellRead = true }
	if o.usable == nil then r.err.usable = "api absent" end
	if o.noStats then r.err.stats = "api absent"; f.stats = nil end
	if o.waiting then r = { id = o.id or 1, ref = o.id or 1, f = {}, src = {}, err = { info = "blank/nil (not loaded yet)" }, unloaded = true } end
	local n = I.Normalize(r)
	if o.flag ~= nil then n.offered = { source = "reward_dialog", kind = "choice", index = 1, quest = 1, dialogFlag = o.flag } end
	return n
end

--- An equipment result (Gear.Equipped shape) with the given items in the given inventory slots; every other slot EMPTY.
local function equipped(items)
	local eq = { state = "OK", slots = {}, list = {} }
	for n = 1, I.EQUIP_SLOTS do
		local e = { slot = n, slotName = G.SLOT_NAMES[n], state = "EMPTY" }
		if items and items[n] then e.state, e.itemFacts, e.itemId = "POPULATED", items[n], items[n].id end
		eq.slots[n], eq.list[n] = e, e
	end
	return eq
end

local function cats(c) local t = {} for _, x in ipairs(c.categories) do t[#t + 1] = x.id end return table.concat(t, ",") end
local function has(c, id) for _, x in ipairs(c.categories) do if x.id == id then return x end end end

local USABLE = { usable = true, second = false, flag = true }

local function reset() A.ClearRegistries(); A.THRESHOLDS.slightRelative, A.THRESHOLDS.relativeFloor, A.THRESHOLDS.temporaryQuests, A.THRESHOLDS.temporaryMinutes = 0.25, 5, 3, 15 end
reset()

section("advisor: a reward is matched to the equipped item in its slot (the item's equip location is not the actual slot)")
do
	local boots = facts({ id = 10, name = "Sturdy Boots", slot = "INVTYPE_FEET", stats = { RESISTANCE0_NAME = 61 }, sell = 36, usable = true, flag = true })
	local gloves = facts({ id = 11, name = "Plain Gloves", slot = "INVTYPE_HAND", stats = { RESISTANCE0_NAME = 28 }, sell = 19, usable = true, flag = true })
	local eq = equipped({ [8] = facts({ id = 20, name = "Old Boots", slot = "INVTYPE_FEET", stats = { RESISTANCE0_NAME = 16 } }), [10] = facts({ id = 21, name = "Old Gloves", slot = "INVTYPE_HAND", stats = { RESISTANCE0_NAME = 33 } }) })
	local c1 = A.Classify(boots, eq)
	check(c1.comparison.chosen == 8 and c1.comparison.entries[1].slotName == "FEET" and c1.comparison.entries[1].equipment.itemId == 20, "INVTYPE_FEET is compared with actual slot 8 (FEET), against Old Boots")
	local c2 = A.Classify(gloves, eq)
	check(c2.comparison.chosen == 10 and c2.comparison.entries[1].equipment.itemId == 21, "INVTYPE_HAND is compared with actual slot 10 (HANDS)")
	local c3 = A.Classify(facts({ id = 12, name = "Ring", slot = "INVTYPE_FINGER", stats = { ITEM_MOD_STAMINA_SHORT = 2 }, usable = true, flag = true }), eq)
	check(#c3.comparison.entries == 2 and c3.comparison.entries[1].slot == 11 and c3.comparison.entries[2].slot == 12, "a ring can go in two actual slots and both were considered")
end

section("advisor: a positive armor difference is an UPGRADE with a stated reason; the size is relative, not a score")
do
	reset()
	local boots = facts({ id = 10, name = "Sturdy Boots", slot = "INVTYPE_FEET", stats = { RESISTANCE0_NAME = 61 }, sell = 36, usable = true, flag = true })
	local eq = equipped({ [8] = facts({ id = 20, name = "Ragged Boots", slot = "INVTYPE_FEET", stats = { RESISTANCE0_NAME = 16 } }) })
	local c = A.Classify(boots, eq)
	check(c.primary == "UPGRADE" and has(c, "UPGRADE").reason == "+45 armor over your current Ragged Boots (FEET).", "UPGRADE: +45 armor over your current Ragged Boots  [" .. tostring(has(c, "UPGRADE") and has(c, "UPGRADE").reason) .. "]")
	check(has(c, "UPGRADE").certainty == "PROVEN" and has(c, "UPGRADE").evidence.gains[1].diff == 45, "certainty PROVEN (both stat tables and usability are proven) and the evidence keeps the numbers")
	-- a small relative gain is SLIGHT
	local eq2 = equipped({ [8] = facts({ id = 20, name = "Fair Boots", slot = "INVTYPE_FEET", stats = { RESISTANCE0_NAME = 60 } }) })
	local s = A.Classify(boots, eq2)
	check(s.primary == "SLIGHT_UPGRADE" and has(s, "SLIGHT_UPGRADE").reason:find("+1 armor", 1, true), "+1 over 60 is a SLIGHT upgrade, still with the fact stated")
	-- the tier boundary is the (proposed) threshold, one place
	A.THRESHOLDS.slightRelative = 0.01
	check(A.Classify(boots, eq2).primary == "UPGRADE", "lowering the proposed threshold changes the tier (it is one tunable table)")
	reset()
	-- several stats all higher
	local multi = facts({ id = 13, name = "Fine Chest", slot = "INVTYPE_CHEST", stats = { RESISTANCE0_NAME = 50, ITEM_MOD_STAMINA_SHORT = 4, ITEM_MOD_STRENGTH_SHORT = 3 }, usable = true, flag = true })
	local eq3 = equipped({ [5] = facts({ id = 22, name = "Old Chest", slot = "INVTYPE_CHEST", stats = { RESISTANCE0_NAME = 40, ITEM_MOD_STAMINA_SHORT = 1 } }) })
	local m = A.Classify(multi, eq3)
	check(m.primary == "UPGRADE" and has(m, "UPGRADE").reason:find("+10 armor, +3 strength, +3 stamina", 1, true), "several stats all higher: UPGRADE listing them  [" .. tostring(has(m, "UPGRADE") and has(m, "UPGRADE").reason) .. "]")
end

section("advisor: a negative armor difference is not an upgrade; mixed differences are MIXED, not weighed")
do
	reset()
	local wraps = facts({ id = 30, name = "Wraps", slot = "INVTYPE_HAND", stats = { RESISTANCE0_NAME = 28 }, sell = 19, usable = true, flag = true })
	local eq = equipped({ [10] = facts({ id = 31, name = "Burnt Gloves", slot = "INVTYPE_HAND", stats = { RESISTANCE0_NAME = 33 } }) })
	local c = A.Classify(wraps, eq)
	check(not has(c, "UPGRADE") and not has(c, "SLIGHT_UPGRADE") and c.primary == "VENDOR", "armor 28 vs 33 is not an upgrade; with no other known benefit the category is VENDOR")
	check(has(c, "VENDOR").reason:find("-5 armor versus your current Burnt Gloves", 1, true) and has(c, "VENDOR").reason:find("Vendor value: 19c", 1, true), "and the reason states the difference and the vendor value  [" .. has(c, "VENDOR").reason .. "]")
	-- a cloak with a missing stat on the candidate: armor lower AND stamina lower (counted as zero, flagged)
	local cloak = facts({ id = 32, name = "Cloak", slot = "INVTYPE_CLOAK", stats = { RESISTANCE0_NAME = 7 }, sell = 24, usable = true, flag = true })
	local eq2 = equipped({ [15] = facts({ id = 33, name = "Simple Cloak", slot = "INVTYPE_CLOAK", stats = { RESISTANCE0_NAME = 8, ITEM_MOD_STAMINA_SHORT = 1 } }) })
	local c2 = A.Classify(cloak, eq2)
	check(c2.primary == "VENDOR" and has(c2, "VENDOR").reason:find("-1 armor, -1 stamina", 1, true), "armor 7 vs 8 and no stamina vs 1: both lower  [" .. has(c2, "VENDOR").reason .. "]")
	local mixed = facts({ id = 34, name = "Odd Cloak", slot = "INVTYPE_CLOAK", stats = { RESISTANCE0_NAME = 12, ITEM_MOD_STAMINA_SHORT = 0 }, usable = true, flag = true })
	local m = A.Classify(mixed, eq2)
	check(m.primary == "MIXED" and has(m, "MIXED").reason:find("+4 armor", 1, true) and has(m, "MIXED").reason:find("-1 stamina", 1, true) and has(m, "MIXED").reason:find("does not weigh", 1, true), "armor up and stamina down is MIXED and says Codex does not weigh stats  [" .. has(m, "MIXED").reason .. "]")
	local same = A.Classify(facts({ id = 35, name = "Same", slot = "INVTYPE_CLOAK", stats = { RESISTANCE0_NAME = 8, ITEM_MOD_STAMINA_SHORT = 1 }, sell = 5, usable = true, flag = true }), eq2)
	check(same.primary == "VENDOR" and has(same, "VENDOR").reason:find("no difference in the compared stats", 1, true), "an identical stat table is no difference, reported as such")
end

section("advisor: an empty slot, no equipment read, and unknown comparisons never become 'not an upgrade'")
do
	reset()
	local boots = facts({ id = 10, name = "Boots", slot = "INVTYPE_FEET", stats = { RESISTANCE0_NAME = 20 }, sell = 4, usable = true, flag = true })
	local empty = A.Classify(boots, equipped({}))
	check(empty.primary == "UPGRADE" and has(empty, "UPGRADE").reason == "Fills your empty FEET slot." and has(empty, "UPGRADE").evidence.kind == "empty_slot", "an EMPTY equipment slot: the item fills it")
	local none = A.Classify(boots, nil)
	check(none.primary == "UNKNOWN" and none.comparison.note == "the equipped items were not read" and not has(none, "VENDOR"), "equipment not read: UNKNOWN, never VENDOR")
	local failed = equipped({})
	for n = 1, 19 do failed.slots[n] = { slot = n, slotName = G.SLOT_NAMES[n], state = "FAILED", reason = "api absent" } end
	failed.state = "FAILED"
	local f = A.Classify(boots, failed)
	check(f.primary == "UNKNOWN" and not has(f, "UPGRADE") and not has(f, "VENDOR"), "an equipment read that FAILED is UNKNOWN (not 'slot empty', not 'no upgrade')")
	local waitingEq = equipped({ [8] = facts({ id = 20, name = "Loading", slot = "INVTYPE_FEET", waiting = true }) })
	local w = A.Classify(boots, waitingEq)
	check(w.primary == "UNKNOWN" and not has(w, "VENDOR") and w.comparison.note ~= nil, "an equipped item that has not loaded: UNKNOWN with the reason  [" .. tostring(w.comparison.note) .. "]")
	local unk = A.Classify(facts({ id = 14, name = "Mystery", slot = "INVTYPE_MYSTERY", stats = { RESISTANCE0_NAME = 5 }, sell = 2, usable = true, flag = true }), equipped({}))
	check(unk.primary == "UNKNOWN" and unk.comparison.note:find("not in Codex's slot table", 1, true), "an equip location Codex does not know: UNKNOWN")
end

section("advisor: EMPTY stats and UNPROVEN stats are not zero")
do
	reset()
	local cur = facts({ id = 20, name = "Current", slot = "INVTYPE_CLOAK", stats = { RESISTANCE0_NAME = 8 } })
	local emptyStats = facts({ id = 40, name = "Bare Cloak", slot = "INVTYPE_CLOAK", stats = {}, sell = 24, usable = true, flag = true })
	check(emptyStats.fields.stats.state == "EMPTY", "(the candidate's stat table is EMPTY)")
	local c = A.Classify(emptyStats, equipped({ [15] = cur }))
	check(c.primary == "UNKNOWN" and not has(c, "VENDOR") and not has(c, "UPGRADE"), "an EMPTY stat table is not interpreted as 'no stats': the comparison is UNKNOWN, not 'worse' and not VENDOR")
	local noStats = facts({ id = 41, name = "Unread", slot = "INVTYPE_CLOAK", noStats = true, sell = 24, usable = true, flag = true })
	local c2 = A.Classify(noStats, equipped({ [15] = cur }))
	check(c2.primary == "UNKNOWN" and has(c2, "UNKNOWN").reason:find("api absent", 1, true), "an unreadable stat table is UNKNOWN with the reason")
	local waiting = A.Classify(facts({ id = 42, name = "Loading", slot = "INVTYPE_CLOAK", waiting = true }), equipped({ [15] = cur }))
	check(waiting.primary == "UNKNOWN" and waiting.categories[1].reason:find("has not loaded yet", 1, true) and waiting.categories[1].certainty == "UNPROVEN", "an item that is still loading is UNKNOWN, UNPROVEN, nothing assumed")
	local nofacts = A.Classify(nil, equipped({}))
	check(nofacts.primary == "UNKNOWN", "no facts at all is UNKNOWN")
end

section("advisor: usability evidence is kept side by side; IsUsableItem alone is never trusted")
do
	reset()
	local eq = equipped({ [8] = facts({ id = 20, name = "Old Boots", slot = "INVTYPE_FEET", stats = { RESISTANCE0_NAME = 16 } }) })
	-- both sources say false: NOT_USABLE, and the vendor value then matters
	local notUsable = facts({ id = 50, name = "Mail Boots", slot = "INVTYPE_FEET", stats = { RESISTANCE0_NAME = 61 }, sell = 36, usable = false, second = false, flag = false })
	local n = A.Classify(notUsable, eq)
	check(n.usability.verdict == "NOT_USABLE" and n.primary == "NOT_USABLE" and has(n, "NOT_USABLE").reason:find("both say false", 1, true), "IsUsableItem false AND the dialog flag false: NOT USABLE")
	check(not has(n, "UPGRADE") and has(n, "VENDOR") and has(n, "VENDOR").reason:find("36c", 1, true), "an item that is not usable is not offered as an upgrade, and with no other use the vendor value is shown")
	-- the sources disagree: a CONFLICT, never NOT_USABLE, never silently usable
	local conflict = facts({ id = 51, name = "Leather Wraps", slot = "INVTYPE_FEET", stats = { RESISTANCE0_NAME = 61 }, sell = 19, usable = false, second = false, flag = true })
	local c = A.Classify(conflict, eq)
	check(c.usability.verdict == "CONFLICT" and not has(c, "NOT_USABLE"), "IsUsableItem false but the dialog flag true: CONFLICT, not NOT_USABLE")
	check(has(c, "UPGRADE") and has(c, "UPGRADE").certainty == "PARTIAL" and c.caveats[1]:find("usability is unclear", 1, true), "the upgrade is still described, marked PARTIAL, with the conflict in the caveats")
	check(c.usability.sources[1].name == "IsUsableItem" and c.usability.sources[1].value == false and c.usability.sources[2].name == "reward dialog flag" and c.usability.sources[2].value == true, "both evidence sources are preserved")
	-- IsUsableItem alone (no dialog flag): UNKNOWN, even when false
	local alone = facts({ id = 52, name = "Owned Item", slot = "INVTYPE_FEET", stats = { RESISTANCE0_NAME = 61 }, sell = 5, usable = false })
	local a = A.Classify(alone, eq)
	check(a.usability.verdict == "UNKNOWN" and not has(a, "NOT_USABLE") and a.usability.reason:find("does not trust it alone", 1, true), "IsUsableItem alone, even false, is UNKNOWN: it is not proof")
	local aTrue = A.Classify(facts({ id = 53, name = "Another", slot = "INVTYPE_FEET", stats = { RESISTANCE0_NAME = 61 }, sell = 5, usable = true }), eq)
	check(aTrue.usability.verdict == "UNKNOWN", "and IsUsableItem true alone is not proof either")
	local ok = A.Classify(facts({ id = 54, name = "Fine", slot = "INVTYPE_FEET", stats = { RESISTANCE0_NAME = 61 }, usable = true, flag = true }), eq)
	check(ok.usability.verdict == "USABLE", "both true: USABLE")
	-- the level requirement is a caveat from proven facts
	local lvl = A.Classify(facts({ id = 55, name = "Heavy", slot = "INVTYPE_FEET", stats = { RESISTANCE0_NAME = 61 }, req = 12, usable = true, flag = true }), eq, { character = { level = 9 } })
	check(lvl.caveats[1] == "requires level 12 (the character is level 9)", "a required level above the character's level is a caveat")
end

section("advisor: a use effect is COMBAT UTILITY (what it does stays unknown); no use effect adds nothing")
do
	reset()
	local skull = facts({ id = 60, name = "Grinning Skull", slot = "", spell = "Skull Blast", classID = 15, type = "Miscellaneous", sell = 5, usable = true, flag = true, stats = {} })
	local c = A.Classify(skull, equipped({}))
	check(c.primary == "COMBAT_UTILITY" and has(c, "COMBAT_UTILITY").reason == "Has a use effect (Skull Blast). Codex does not know what the effect does.", "a use effect: COMBAT UTILITY, honest about not knowing the effect  [" .. tostring(has(c, "COMBAT_UTILITY") and has(c, "COMBAT_UTILITY").reason) .. "]")
	check(has(c, "COMBAT_UTILITY").certainty == "PARTIAL" and not has(c, "VENDOR"), "PARTIAL certainty, and a useful item is not labelled VENDOR")
	local plain = facts({ id = 61, name = "Plain Junk", slot = "", classID = 15, type = "Miscellaneous", sell = 5, usable = true, flag = true, stats = {} })
	check(plain.fields.useEffect.state == "EMPTY", "(no use effect: the call worked and returned none)")
	local p = A.Classify(plain, equipped({}))
	check(not has(p, "COMBAT_UTILITY") and p.primary == "VENDOR", "no use effect adds no utility")
	-- a registered utility source can add knowledge
	A.RegisterUtility("test", function(f) if f.id == 61 then return { reason = "Restores health in combat.", certainty = "PROVEN", source = "test source" } end end)
	local q = A.Classify(plain, equipped({}))
	check(q.primary == "COMBAT_UTILITY" and has(q, "COMBAT_UTILITY").evidence.source == "test source", "a utility source can supply its own reason and keeps its provenance")
	reset()
end

section("advisor: vendor value, a missing vendor value, and future use")
do
	reset()
	local junk = facts({ id = 70, name = "Shiny Rock", slot = "", classID = 15, type = "Miscellaneous", sell = 36, usable = true, flag = true, stats = {} })
	local v = A.Classify(junk, equipped({}))
	check(v.primary == "VENDOR" and has(v, "VENDOR").reason:find("No known equipment or utility benefit", 1, true) and has(v, "VENDOR").reason:find("Vendor value: 36c", 1, true), "VENDOR states what is not known and the vendor value  [" .. has(v, "VENDOR").reason .. "]")
	check(v.futureUse.state == "UNKNOWN" and v.futureUse.reason == "no future-use source is registered", "future use stays UNKNOWN (and visible) when no source exists")
	local noValue = facts({ id = 71, name = "Unpriced", slot = "", classID = 15, type = "Miscellaneous", usable = true, flag = true, stats = {} })
	check(noValue.fields.vendorValue.state ~= "PROVEN", "(the vendor value was not read)")
	local n = A.Classify(noValue, equipped({}))
	check(n.primary == "UNKNOWN" and not has(n, "VENDOR") and has(n, "UNKNOWN").reason:find("vendor value was not read", 1, true), "a missing vendor value is UNKNOWN, not VENDOR and not 0c")
	-- a registered future-use source
	A.RegisterFutureUse("synthetic", function(f) if f.id == 70 then return { reason = "A known requirement asks for this item.", certainty = "PROVEN", source = "synthetic source" } end end)
	local f = A.Classify(junk, equipped({}))
	check(f.primary == "FUTURE_USE" and not has(f, "VENDOR") and f.futureUse.state == "KNOWN" and f.futureUse.source == "synthetic source", "a future-use source makes it FUTURE USE instead of VENDOR, with its provenance")
	A.RegisterFutureUse("broken", function() error("boom") end)
	check(A.Classify(junk, equipped({})).primary == "FUTURE_USE", "a future-use source that errors is ignored")
	reset()
	check(A.Classify(junk, equipped({})).futureUse.state == "UNKNOWN", "with the registry cleared it is UNKNOWN again")
end

section("advisor: the temporary-upgrade framework takes replacement context; it never invents one")
do
	reset()
	local boots = facts({ id = 10, name = "Boots", slot = "INVTYPE_FEET", stats = { RESISTANCE0_NAME = 61 }, sell = 4, usable = true, flag = true })
	local eq = equipped({ [8] = facts({ id = 20, name = "Old", slot = "INVTYPE_FEET", stats = { RESISTANCE0_NAME = 16 } }) })
	check(not has(A.Classify(boots, eq), "TEMPORARY_UPGRADE"), "without context there is no temporary classification")
	check(not has(A.Classify(boots, eq, { context = { replacement = { state = "UNKNOWN" } } }), "TEMPORARY_UPGRADE"), "an UNKNOWN replacement adds nothing")
	local soon = A.Classify(boots, eq, { context = { replacement = { state = "KNOWN", quests = 2, certainty = "GUARANTEED", source = "planned quest" } } })
	check(has(soon, "TEMPORARY_UPGRADE") and has(soon, "UPGRADE") and has(soon, "TEMPORARY_UPGRADE").reason:find("2 quest(s)", 1, true) and has(soon, "TEMPORARY_UPGRADE").reason:find("planned quest", 1, true), "a known nearby replacement adds TEMPORARY next to UPGRADE (the item is still an upgrade)")
	check(soon.primary == "UPGRADE", "the order is presentation only")
	local possible = A.Classify(boots, eq, { context = { replacement = { state = "KNOWN", minutes = 10, certainty = "POSSIBLE", source = "route" } } })
	check(has(possible, "TEMPORARY_UPGRADE").certainty == "PARTIAL", "a merely possible replacement is PARTIAL")
	check(not has(A.Classify(boots, eq, { context = { replacement = { state = "KNOWN", quests = 9, certainty = "GUARANTEED" } } }), "TEMPORARY_UPGRADE"), "a distant replacement adds nothing")
	local worse = facts({ id = 15, name = "Worse", slot = "INVTYPE_FEET", stats = { RESISTANCE0_NAME = 5 }, sell = 2, usable = true, flag = true })
	check(not has(A.Classify(worse, eq, { context = { replacement = { state = "KNOWN", quests = 1, certainty = "GUARANTEED" } } }), "TEMPORARY_UPGRADE"), "an item that is not an improvement is not made 'temporary' by context")
end

section("advisor: every classification has a reason, the layers are separate, and the default recommendation gives no opinion")
do
	reset()
	local eq = equipped({ [8] = facts({ id = 20, name = "Old", slot = "INVTYPE_FEET", stats = { RESISTANCE0_NAME = 16 } }) })
	local items = {
		facts({ id = 10, name = "A", slot = "INVTYPE_FEET", stats = { RESISTANCE0_NAME = 61 }, sell = 36, usable = true, flag = true }),
		facts({ id = 11, name = "B", slot = "INVTYPE_FEET", stats = { RESISTANCE0_NAME = 5 }, sell = 3, usable = false, flag = false }),
		facts({ id = 12, name = "C", slot = "INVTYPE_FEET", waiting = true }),
		facts({ id = 13, name = "D", slot = "", classID = 15, sell = 2, usable = true, flag = true, stats = {}, spell = "Zap" }),
	}
	local ev = { items = {} }
	for i, f in ipairs(items) do
		local c = A.Classify(f, eq)
		check(#c.categories >= 1, "item " .. i .. " has a category")
		for _, x in ipairs(c.categories) do
			check(type(x.reason) == "string" and #x.reason > 8 and type(x.certainty) == "string" and x.tag and x.family, "item " .. i .. " [" .. x.id .. "] has a reason, a certainty, a tag and a colour family")
			check(not x.reason:lower():find("take this") and not x.reason:lower():find("best item") and not x.reason:lower():find("wrong choice") and not x.reason:lower():find("you should"), "item " .. i .. " reason has no instruction wording")
		end
		check(c.recommendation == nil and c.take == nil and c.score == nil, "a classification carries no recommendation and no score")
		ev.items[#ev.items + 1] = { index = i, kind = "choice", classification = c }
	end
	local r = A.Recommend(ev)
	check(r.state == "NO_OPINION" and #r.items == 4 and r.items[1].stance == nil and r.items[1].primary == "UPGRADE", "the default recommendation is NO_OPINION and only echoes the categories")
	local seen
	A.SetRecommender(function(e) seen = e; return { state = "CUSTOM", reason = "plugged in", items = {} } end)
	local r2 = A.Recommend(ev)
	check(r2.state == "CUSTOM" and seen == ev, "a later recommender receives the classifications and replaces the default without touching classification")
	A.SetRecommender(function() error("boom") end)
	check(A.Recommend(ev).state == "NO_OPINION", "a recommender that errors falls back to no opinion")
	reset()
	check(A.Classify(items[1], eq).primary == "UPGRADE", "classification is unchanged by the recommender registry")
end

section("advisor: the reward dialog open now versus the last dialog seen (closed)")
do
	reset()
	local DB = {
		[701] = { name = "Sample Boots", equipLoc = "INVTYPE_FEET", classID = 4, sub = 2, sell = 36, stats = { RESISTANCE0_NAME = 61 } },
		[702] = { name = "Sample Cloak", equipLoc = "INVTYPE_CLOAK", classID = 4, sub = 1, sell = 24, stats = { RESISTANCE0_NAME = 7 } },
	}
	local function lk(id) return "|Hitem:" .. id .. "::|h[" .. DB[id].name .. "]|h" end
	local open = true
	local equippedLinks = { [8] = 900, [15] = 901 }
	DB[900] = { name = "Ragged Boots", equipLoc = "INVTYPE_FEET", classID = 4, sub = 2, sell = 1, stats = { RESISTANCE0_NAME = 16 } }
	DB[901] = { name = "Old Cloak", equipLoc = "INVTYPE_CLOAK", classID = 4, sub = 1, sell = 1, stats = { RESISTANCE0_NAME = 8, ITEM_MOD_STAMINA_SHORT = 1 } }
	local function idOf(ref) return type(ref) == "number" and ref or tonumber(ref:match("item:(%d+)")) end
	_G.GetQuestID = function() return 55 end
	_G.GetNumQuestChoices = function() return open and 2 or 0 end
	_G.GetNumQuestRewards = function() return 0 end
	_G.GetQuestItemInfo = function(kind, i) local id = 700 + i; local flag = true; if i == 1 then flag = false end; return DB[id].name, 1, 1, 1, flag, id end
	_G.GetQuestItemLink = function(kind, i) return lk(700 + i) end
	_G.GetItemInfo = function(ref) local id = idOf(ref); local d = DB[id]; if not d then return nil end return d.name, lk(id), 1, 8, 0, "Armor", "x", 1, d.equipLoc, 1, d.sell, d.classID, d.sub end
	_G.GetItemStats = function(l) return DB[idOf(l)].stats end
	_G.IsUsableItem = function() return false, false end
	_G.GetItemSpell = function() return nil end
	_G.GetItemCount = function() return 1 end
	_G.GetInventoryItemLink = function(u, slot) local id = equippedLinks[slot]; if id then return lk(id) end end
	ns.ItemProbe.OnEvent("QUEST_DETAIL")
	local live = A.Evaluate({ character = { level = 9 } })
	check(live.live == true and live.available == true and #live.items == 2 and live.source:find("open now", 1, true), "the open dialog: live and available")
	check(live.items[1].classification.primary == "NOT_USABLE" and live.items[2].classification.usability.verdict == "CONFLICT", "both usability sources are used: item 1 false/false NOT USABLE, item 2 false/true CONFLICT")
	check(live.items[1].facts.offered.dialogFlag == false and live.items[2].facts.offered.dialogFlag == true, "the dialog flag came from the dialog itself")
	open = false
	local closedEv = A.Evaluate({ character = { level = 9 } })
	check(closedEv.live == false and closedEv.available == false and closedEv.source:find("not currently offered", 1, true) and closedEv.q == 55, "the closed dialog: not live, not available, labelled as the last dialog seen")
	check(#closedEv.items == 2 and closedEv.items[1].classification.primary == "NOT_USABLE", "its classifications are still produced from the last observation")
	local text = table.concat(A.ReportLines({ character = { level = 9 } }), "\n")
	check(text:find("REWARD ADVISOR", 1, true) and text:find("not currently offered", 1, true) and text:find("RECOMMENDATION: NO_OPINION", 1, true), "the report labels it and shows no recommendation")
	check(text:find("[NOT USABLE]", 1, true) and text:find("usability evidence: IsUsableItem=false, reward dialog flag=false -> NOT_USABLE", 1, true), "the report shows the category, and both evidence sources")
	open = true
	local t2 = table.concat(A.ReportLines({ character = { level = 9 } }), "\n")
	check(t2:find("the reward dialog that is open now", 1, true) and not t2:find("not currently offered", 1, true), "reopened: the report says it is the dialog open now")
	for _, n in ipairs({ "GetQuestID", "GetNumQuestChoices", "GetNumQuestRewards", "GetQuestItemInfo", "GetQuestItemLink", "GetItemInfo", "GetItemStats", "IsUsableItem", "GetItemSpell", "GetItemCount", "GetInventoryItemLink" }) do _G[n] = nil end
	-- nothing seen at all
	local ns2 = boot({ char = { level = 9 } })
	check(ns2.Advisor.Evaluate() == nil and ns2.Advisor.ReportLines()[1]:find("no reward dialog seen this session", 1, true), "with no dialog seen the advisor says so")
end

section("advisor: Stage 3 is independent, read-only, free of stat weights and instruction wording, and nothing else consumes it")
do
	local function code(f) return (H.readFile(H.addonDir .. "/" .. f):gsub("%-%-[^\n]*", "")) end
	local src = code("RewardAdvisor.lua")
	for _, pat in ipairs({ "ns%.Planner", "ns%.Engine", "ns%.Strategies", "ns%.State", "ns%.UI", "ns%.Presenter", "ns%.Registry", "ns%.Context", "ns%.Prefs", "ns%.Overlap", "ns%.QuestieBridge" }) do
		check(not src:find(pat), "RewardAdvisor.lua does not depend on " .. pat:gsub("%%", ""))
	end
	for _, word in ipairs({ "weight", "pawn", "take this", "best item", "wrong choice", "you should", "sell it" }) do
		check(not src:lower():find(word, 1, true), "RewardAdvisor.lua does not contain '" .. word .. "'")
	end
	for _, api in ipairs({ "EquipItemByName", "PickupInventoryItem", "UseContainerItem", "SellCursorItem", "AutoEquipCursorItem", "GetQuestReward" }) do
		check(not src:find(api .. "%s*%("), "RewardAdvisor.lua never calls " .. api)
	end
	local readers = {}
	for _, f in ipairs({ "Planner.lua", "Engine.lua", "Presenter.lua", "Overlap.lua", "PlanAdapter.lua", "Providers/Quest.lua", "State.lua", "Strategies.lua", "Navigation.lua" }) do
		if code(f):find("ns%.Advisor") then readers[#readers + 1] = f end
	end
	check(#readers == 0, "the planner, presenter and providers do not read the advisor")
end
