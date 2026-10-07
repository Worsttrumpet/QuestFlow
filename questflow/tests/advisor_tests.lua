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
	check(m.primary == "MIXED" and has(m, "MIXED").reason:find("+4 armor", 1, true) and has(m, "MIXED").reason:find("-1 stamina", 1, true) and has(m, "MIXED").reason:find("does not weigh", 1, true), "armor up and stamina down is MIXED and says Quest Flow does not weigh stats  [" .. has(m, "MIXED").reason .. "]")
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
	check(unk.primary == "UNKNOWN" and unk.comparison.note:find("not in Quest Flow's slot table", 1, true), "an equip location Quest Flow does not know: UNKNOWN")
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
	check(not has(c, "UPGRADE") and c.primary == "UNKNOWN" and has(c, "UNKNOWN").reason:find("not established", 1, true) and has(c, "UNKNOWN").reason:find("+45 armor", 1, true) and c.caveats[1]:find("usability is unclear", 1, true), "with conflicting evidence a better item is NOT called an upgrade: UNKNOWN, stating what it would be if usable, with the conflict in the caveats  [" .. has(c, "UNKNOWN").reason .. "]")
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
	check(lvl.primary == "NOT_USABLE" and has(lvl, "NOT_USABLE").reason:find("Not usable yet: requires level 12, the character is level 9", 1, true) and lvl.eligibility.future.state == "LATER", "a required level above the character's level is a proven NOT YET, with when it unlocks (the worn leather boots show leather is allowed)  [" .. has(lvl, "NOT_USABLE").reason .. "]")
	check(lvl.caveats[1]:find("say usable", 1, true), "and the client's contradicting usable answers are noted as a conflict")
end

section("advisor: a use effect is COMBAT UTILITY (what it does stays unknown); no use effect adds nothing")
do
	reset()
	local skull = facts({ id = 60, name = "Grinning Skull", slot = "", spell = "Skull Blast", classID = 15, type = "Miscellaneous", sell = 5, usable = true, flag = true, stats = {} })
	local c = A.Classify(skull, equipped({}))
	check(c.primary == "COMBAT_UTILITY" and has(c, "COMBAT_UTILITY").reason == "Has a use effect (Skull Blast). Quest Flow does not know what the effect does.", "a use effect: COMBAT UTILITY, honest about not knowing the effect  [" .. tostring(has(c, "COMBAT_UTILITY") and has(c, "COMBAT_UTILITY").reason) .. "]")
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

section("advisor: every classification has a reason, the layers are separate, and the recommender is pluggable with a safe fallback")
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
	check(r.state == "TENTATIVE" and r.selected.index == 1 and r.basis == "STRICT_UPGRADE" and #r.items == 4 and r.caveats[1]:find("item data was not available", 1, true),
		"the default recommendation is the conservative recommender: a proven-usable strict upgrade, but TENTATIVE because one choice has not loaded")
	local seen
	A.SetRecommender(function(e) seen = e; return { state = "CUSTOM", reason = "plugged in", items = {} } end)
	local r2 = A.Recommend(ev)
	check(r2.state == "CUSTOM" and seen == ev, "a later recommender receives the classifications and replaces the default without touching classification")
	A.SetRecommender(function() error("boom") end)
	check(A.Recommend(ev).state == "TENTATIVE", "a recommender that errors falls back to the built-in conservative recommender")
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
	check(text:find("REWARD ADVISOR", 1, true) and text:find("not currently offered", 1, true) and text:find("RECOMMENDATION: NO_CLEAR_RECOMMENDATION", 1, true) and text:find("Quest Flow makes no pick", 1, true), "the report labels it as closed and shows that Quest Flow makes no pick (nothing usable improves)")
	check(text:find("[NOT USABLE]", 1, true) and text:find("usability evidence: IsUsableItem=false, reward dialog flag=false -> NOT_USABLE", 1, true), "the report shows the category, and both evidence sources")
	open = true
	local t2 = table.concat(A.ReportLines({ character = { level = 9 } }), "\n")
	check(t2:find("the reward dialog that is open now", 1, true) and not t2:find("not currently offered", 1, true), "reopened: the report says it is the dialog open now")
	for _, n in ipairs({ "GetQuestID", "GetNumQuestChoices", "GetNumQuestRewards", "GetQuestItemInfo", "GetQuestItemLink", "GetItemInfo", "GetItemStats", "IsUsableItem", "GetItemSpell", "GetItemCount", "GetInventoryItemLink" }) do _G[n] = nil end
	-- nothing seen at all
	local ns2 = boot({ char = { level = 9 } })
	check(ns2.Advisor.Evaluate() == nil and ns2.Advisor.ReportLines()[1]:find("no reward dialog seen this session", 1, true), "with no dialog seen the advisor says so")
end

-- ================================================================ R1: the conservative recommender
-- Table-driven cases over synthetic facts. Every expectation is stated as "state / basis / pick / stances"; the recommender may only use what classification and
-- eligibility already know (no weights, no scores).

local function choiceEval(specs, eq, ch, kind)
	local items = {}
	for i, f in ipairs(specs) do
		items[i] = { index = i, kind = kind or "choice", id = f.id, name = f.fields and f.fields.name and f.fields.name.value, facts = f, classification = A.Classify(f, eq, { character = ch or { level = 9 } }) }
	end
	return { items = items }
end
local function stances(rec) local s = {} for i, it in ipairs(rec.items) do s[i] = it.stance or "-" end return table.concat(s, ",") end

local U = { usable = true, second = false, flag = true }               -- the client's two usability answers agree: usable
local N = { usable = false, second = false, flag = false }             -- both say not usable
local CF = { usable = false, second = false, flag = true }             -- they disagree
local function boots(id, name, armor, flags, extra)
	local o = { id = id, name = name, slot = "INVTYPE_FEET", stats = { RESISTANCE0_NAME = armor }, sell = 5 }
	for k, v in pairs(flags or {}) do o[k] = v end
	for k, v in pairs(extra or {}) do o[k] = v end
	return facts(o)
end
local function worn() return equipped({ [8] = facts({ id = 20, name = "Old Boots", slot = "INVTYPE_FEET", stats = { RESISTANCE0_NAME = 16 } }) }) end

section("recommender: table-driven cases (clear upgrade, inferior, unusable, empty slot, mixed, conflicting flags, future-only, equivalents, none usable, vendor tie-break, ambiguous)")
do
	reset()
	local cases = {
		{ name = "one clear upgrade, one that is no gain",
		  items = function() return { boots(1, "Fine Boots", 61, U), boots(2, "Poor Boots", 5, U) } end,
		  state = "RECOMMEND", basis = "STRICT_UPGRADE", pick = 1, stances = "PREFERRED,INFERIOR" },
		{ name = "a proven-unusable reward beside a usable upgrade",
		  items = function() return { boots(1, "Fine Boots", 61, U), boots(2, "Big Boots", 90, N) } end,
		  state = "RECOMMEND", basis = "STRICT_UPGRADE", pick = 1, stances = "PREFERRED,INFERIOR" },
		{ name = "a reward that fills an empty slot",
		  eq = function() return equipped({}) end,
		  items = function() return { boots(1, "Fine Boots", 61, U), boots(2, "Big Boots", 90, N) } end,
		  state = "RECOMMEND", basis = "EMPTY_SLOT", pick = 1, stances = "PREFERRED,INFERIOR" },
		{ name = "a dominating upgrade in the same slot beats a smaller one",
		  items = function() return { boots(1, "Small Boots", 30, U), boots(2, "Big Boots", 61, U) } end,
		  state = "RECOMMEND", basis = "STRICT_UPGRADE", pick = 2, stances = "INFERIOR,PREFERRED" },
		{ name = "mixed stats only: no pick",
		  items = function() return { boots(1, "Agile Boots", 10, U, { stats = { RESISTANCE0_NAME = 10, ITEM_MOD_AGILITY_SHORT = 3 } }), boots(2, "Flat Boots", 12, U) } end,
		  state = "NO_CLEAR_RECOMMENDATION", basis = "MIXED_ONLY", pick = nil, stances = "UNCERTAIN,UNCERTAIN" },
		{ name = "a strict upgrade beside a mixed choice is only TENTATIVE",
		  items = function() return { boots(1, "Fine Boots", 61, U), boots(2, "Agile Boots", 10, U, { stats = { RESISTANCE0_NAME = 10, ITEM_MOD_AGILITY_SHORT = 3 } }) } end,
		  state = "TENTATIVE", basis = "STRICT_UPGRADE", pick = 1, stances = "PREFERRED,UNCERTAIN", caveat = "Agile Boots" },
		{ name = "conflicting usability flags: the only candidate is TENTATIVE, with the conflict stated",
		  items = function() return { boots(1, "Fine Boots", 61, CF), boots(2, "Big Boots", 90, N) } end,
		  state = "TENTATIVE", basis = "ONLY_CANDIDATE", pick = 1, stances = "PREFERRED,INFERIOR", caveat = "cannot confirm" },
		{ name = "two equivalent upgrades: no pick",
		  items = function() return { boots(1, "Boots A", 61, U), boots(2, "Boots B", 61, U) } end,
		  state = "NO_CLEAR_RECOMMENDATION", basis = "AMBIGUOUS", pick = nil, stances = "UNCERTAIN,UNCERTAIN" },
		{ name = "genuinely ambiguous: same slot, different stats improved",
		  items = function() return { boots(1, "Agile Boots", 16, U, { stats = { RESISTANCE0_NAME = 16, ITEM_MOD_AGILITY_SHORT = 3 } }), boots(2, "Sturdy Boots", 16, U, { stats = { RESISTANCE0_NAME = 16, ITEM_MOD_STAMINA_SHORT = 3 } }) } end,
		  state = "NO_CLEAR_RECOMMENDATION", basis = "AMBIGUOUS", pick = nil, stances = "UNCERTAIN,UNCERTAIN" },
		{ name = "upgrades in different slots are not compared",
		  items = function() return { boots(1, "Fine Boots", 61, U), facts({ id = 3, name = "Fine Gloves", slot = "INVTYPE_HAND", stats = { RESISTANCE0_NAME = 40 }, sell = 5, usable = true, second = false, flag = true }) } end,
		  eq = function() return equipped({ [8] = facts({ id = 20, name = "Old Boots", slot = "INVTYPE_FEET", stats = { RESISTANCE0_NAME = 16 } }), [10] = facts({ id = 21, name = "Old Gloves", slot = "INVTYPE_HAND", stats = { RESISTANCE0_NAME = 10 } }) }) end,
		  state = "NO_CLEAR_RECOMMENDATION", basis = "AMBIGUOUS", pick = nil, stances = "UNCERTAIN,UNCERTAIN" },
		{ name = "no usable choices",
		  items = function() return { boots(1, "Big Boots", 61, N), boots(2, "Huge Boots", 90, N) } end,
		  state = "NO_CLEAR_RECOMMENDATION", basis = "NONE_USABLE", pick = nil, stances = "INFERIOR,INFERIOR" },
		{ name = "no choice improves what is worn",
		  items = function() return { boots(1, "Poor Boots", 5, U), boots(2, "Worse Boots", 3, U) } end,
		  state = "NO_CLEAR_RECOMMENDATION", basis = "NO_IMPROVEMENT", pick = nil, stances = "UNCERTAIN,UNCERTAIN" },
		{ name = "an unloaded item keeps a clear upgrade TENTATIVE",
		  items = function() return { boots(1, "Fine Boots", 61, U), facts({ id = 9, name = "Loading", slot = "INVTYPE_FEET", waiting = true }) } end,
		  state = "TENTATIVE", basis = "STRICT_UPGRADE", pick = 1, stances = "PREFERRED,UNCERTAIN", caveat = "item data was not available" },
	}
	for _, c in ipairs(cases) do
		local eq = c.eq and c.eq() or worn()
		local rec = A.Recommend(choiceEval(c.items(), eq))
		check(rec.state == c.state and rec.basis == c.basis, c.name .. ": " .. tostring(rec.state) .. " / " .. tostring(rec.basis))
		check((rec.selected and rec.selected.index) == c.pick, c.name .. ": pick " .. tostring(rec.selected and rec.selected.index))
		check(stances(rec) == c.stances, c.name .. ": stances " .. stances(rec))
		if c.caveat then check(table.concat(rec.caveats, " | "):find(c.caveat, 1, true) ~= nil, c.name .. ": caveat mentions " .. c.caveat) end
		check(type(rec.reason) == "string" and #rec.reason > 10, c.name .. ": has a reason")
	end
end

section("recommender: future-only upgrade, vendor tie-break among non-gear, not-a-choice, determinism")
do
	reset()
	local E = ns.Eligibility
	E.ClearEvidence()
	E.AddEvidence({ class = "SHAMAN", itemClass = 4, subClass = 3, minLevel = 40, proven = true, src = "observed on Forever (test evidence)" })
	local ch = { level = 39, classToken = "SHAMAN" }
	local eqC = equipped({ [5] = facts({ id = 30, name = "Worn Vest", slot = "INVTYPE_CHEST", stats = { RESISTANCE0_NAME = 30 } }) })
	local mail = facts({ id = 1, name = "Fine Mail", slot = "INVTYPE_CHEST", classID = 4, sub = 3, subType = "Mail", stats = { RESISTANCE0_NAME = 60 }, sell = 9 })
	local junk = facts({ id = 2, name = "Poor Mail", slot = "INVTYPE_CHEST", classID = 4, sub = 3, subType = "Mail", stats = { RESISTANCE0_NAME = 20 }, sell = 4 })
	local rec = A.Recommend(choiceEval({ mail, junk }, eqC, ch))
	check(rec.state == "TENTATIVE" and rec.basis == "FUTURE_ONLY" and rec.selected.index == 1 and stances(rec) == "PREFERRED,INFERIOR", "future-only upgrade: TENTATIVE, FUTURE_ONLY, the unusable-and-no-gain one INFERIOR  [" .. rec.state .. "/" .. tostring(rec.basis) .. " " .. stances(rec) .. "]")
	check(table.concat(rec.caveats, " | "):find("later improvement", 1, true) and table.concat(rec.reasons, " | "):find("level 40", 1, true), "its caveat says it is a later improvement and the unlock level is in the facts")
	-- two future-only items cannot be separated
	local mail2 = facts({ id = 3, name = "Other Mail", slot = "INVTYPE_CHEST", classID = 4, sub = 3, subType = "Mail", stats = { RESISTANCE0_NAME = 70 }, sell = 9 })
	check(A.Recommend(choiceEval({ mail, mail2 }, eqC, ch)).state == "NO_CLEAR_RECOMMENDATION", "two future-only improvements: no pick")
	E.ClearEvidence()

	-- non-gear: a vendor-value tie-break is TENTATIVE and labelled; ties and missing values give no pick; a use effect is not 'no benefit'
	local function item(id, name, sell, o)
		local x = { id = id, name = name, slot = "", classID = 0, type = "Consumable", subType = "Potion", sell = sell, usable = true, second = false, flag = true, stats = {} }
		for k, v in pairs(o or {}) do x[k] = v end
		return facts(x)
	end
	local v = A.Recommend(choiceEval({ item(1, "Cheap Potion", 25), item(2, "Dear Potion", 150) }, worn()))
	check(v.state == "TENTATIVE" and v.basis == "VENDOR_TIEBREAK" and v.selected.index == 2 and stances(v) == "UNCERTAIN,PREFERRED", "non-gear: the higher vendor value is a TENTATIVE VENDOR_TIEBREAK pick")
	check(v.state ~= "RECOMMEND" and table.concat(v.caveats, " "):find("vendor-value tie-break only", 1, true) and v.reason:find("vendor value", 1, true), "it is labelled as a vendor-value tie-break and says it is not about usefulness")
	check(A.Recommend(choiceEval({ item(1, "A", 50), item(2, "B", 50) }, worn())).state == "NO_CLEAR_RECOMMENDATION", "equal vendor values: no pick")
	check(A.Recommend(choiceEval({ item(1, "A", nil), item(2, "B", 50) }, worn())).state == "NO_CLEAR_RECOMMENDATION", "a vendor value that was not read: no pick")
	check(A.Recommend(choiceEval({ item(1, "A", 10, { spell = "Heal" }), item(2, "B", 50) }, worn())).state == "NO_CLEAR_RECOMMENDATION", "a choice with a use effect is not 'no benefit': no vendor tie-break")
	local gearAndPotion = A.Recommend(choiceEval({ item(1, "A", 10), boots(2, "Poor Boots", 5, U) }, worn()))
	check(gearAndPotion.basis ~= "VENDOR_TIEBREAK", "vendor value is never used when any choice is gear")
	check(A.Recommend(choiceEval({ boots(1, "Poor Boots", 5, U, { sell = 100 }), boots(2, "Worse Boots", 3, U, { sell = 1 }) }, worn())).selected == nil, "gear that does not improve is never picked by vendor value")

	-- nothing to choose
	local g = A.Recommend(choiceEval({ boots(1, "Fine Boots", 61, U), boots(2, "Other", 40, U) }, worn(), nil, "reward"))
	check(g.state == "NOT_A_CHOICE" and g.selected == nil and g.items[1].stance == nil and g.items[1].why:find("guaranteed", 1, true), "guaranteed rewards: NOT_A_CHOICE, no stance")
	check(A.Recommend(choiceEval({ boots(1, "Only", 61, U) }, worn())).state == "NOT_A_CHOICE", "a single choice: NOT_A_CHOICE")

	-- determinism: the order the choices are listed in never changes who is picked
	local function names(order)
		local pool = { boots(1, "Fine Boots", 61, U), boots(2, "Poor Boots", 5, U), boots(3, "Big Boots", 90, N) }
		local list = {}
		for _, k in ipairs(order) do list[#list + 1] = pool[k] end
		local r = A.Recommend(choiceEval(list, worn()))
		return r.state .. ":" .. (r.selected and r.selected.name or "-")
	end
	local base = names({ 1, 2, 3 })
	check(base == "RECOMMEND:Fine Boots" and names({ 3, 2, 1 }) == base and names({ 2, 1, 3 }) == base and names({ 3, 1, 2 }) == base, "the same choices in any order give the same recommendation  [" .. base .. "]")
	-- the recommender reads classifications only: it does not change them
	local f1 = boots(1, "Fine Boots", 61, U)
	local c1 = A.Classify(f1, worn(), { character = { level = 9 } })
	local before = cats(c1) .. "|" .. tostring(c1.primary)
	A.Recommend({ items = { { index = 1, kind = "choice", id = 1, facts = f1, classification = c1 }, { index = 2, kind = "choice", id = 2, facts = f1, classification = c1 } } })
	check(cats(c1) .. "|" .. tostring(c1.primary) == before and c1.recommendation == nil and c1.score == nil, "recommending leaves the classification unchanged and adds no score")
end

section("recommender: the three real reward dialogs (Q92880, Q93320, Q93746 as reported by the Forever client, build 70205)")
do
	reset()
	ns.Eligibility.ClearEvidence()
	local E = ns.Eligibility
	local ROGUE = { level = 13, classToken = "ROGUE" }
	local function weapon(o)
		local x = { type = "Weapon", classID = 2, ilvl = 13, req = 0, slot = "INVTYPE_WEAPON" }
		for k, v in pairs(o) do x[k] = v end
		return facts(x)
	end
	local DPS = "ITEM_MOD_DAMAGE_PER_SECOND_SHORT"
	-- Q92880 (Return to Valanaar, Rogue 13): Honed Greathammer false/false, Quickblade's Dagger IsUsableItem false but dialog flag true, Balanced Quarterstaff false/false
	local eqW = equipped({
		[16] = weapon({ id = 727, name = "Notched Shortsword of the Boar", subType = "One-Handed Swords", sub = 7, ilvl = 5, req = 5, stats = { ITEM_MOD_STRENGTH_SHORT = 1, ITEM_MOD_SPIRIT_SHORT = 1, [DPS] = 5.4761905670166 } }),
		[17] = weapon({ id = 263313, name = "Trusty Wrench", subType = "One-Handed Maces", sub = 4, ilvl = 5, stats = { ITEM_MOD_AGILITY_SHORT = 1, [DPS] = 5.277777671814 } }),
	})
	local items = {
		weapon({ id = 257345, name = "Honed Greathammer", subType = "Two-Handed Maces", sub = 5, slot = "INVTYPE_2HWEAPON", sell = 625, usable = false, second = false, flag = false, stats = { [DPS] = 9.0625, ITEM_MOD_SPIRIT_SHORT = 2, ITEM_MOD_STRENGTH_SHORT = 2 } }),
		weapon({ id = 257346, name = "Quickblade's Dagger", subType = "Daggers", sub = 15, sell = 501, usable = false, second = false, flag = true, stats = { ITEM_MOD_AGILITY_SHORT = 1, [DPS] = 6.764705657959 } }),
		weapon({ id = 257343, name = "Balanced Quarterstaff", subType = "Staves", sub = 10, slot = "INVTYPE_2HWEAPON", sell = 621, usable = false, second = false, flag = false, stats = { [DPS] = 8.8636360168457, ITEM_MOD_SPIRIT_SHORT = 2, ITEM_MOD_STAMINA_SHORT = 2 } }),
	}
	local ev = A.Evaluate({ dialog = { live = true, q = 92880, at = "QUEST_COMPLETE", choices = { { index = 1, kind = "choice", id = 257345, name = "Honed Greathammer", facts = items[1] }, { index = 2, kind = "choice", id = 257346, name = "Quickblade's Dagger", facts = items[2] }, { index = 3, kind = "choice", id = 257343, name = "Balanced Quarterstaff", facts = items[3] } }, rewards = {} }, equipped = eqW, character = ROGUE })
	local r = ev.recommendation
	check(r.state == "TENTATIVE" and r.basis == "ONLY_CANDIDATE" and r.selected.index == 2 and r.selected.name == "Quickblade's Dagger", "Q92880: the dagger is the only choice not proven unusable and it would improve the off-hand: TENTATIVE  [" .. tostring(r.state) .. "/" .. tostring(r.basis) .. "]")
	check(stances(r) == "INFERIOR,PREFERRED,INFERIOR", "Q92880: the hammer and the staff are INFERIOR (both client answers say not usable)  [" .. stances(r) .. "]")
	check(table.concat(r.caveats, " | "):find("cannot confirm", 1, true) and table.concat(r.caveats, " | "):find("IsUsableItem", 1, true), "Q92880: the caveat states the client's usability answers disagree (IsUsableItem false, dialog flag true)")
	check(table.concat(r.reasons, " | "):find("weapon dps", 1, true) and table.concat(r.reasons, " | "):find("Trusty Wrench", 1, true), "Q92880: the fact is the dps gain over the equipped off-hand")

	-- Q93320 (Tower Defense): Defender's Bracers (leather, IsUsableItem false / flag true), Windswept Slippers (cloth, false / true), Peacekeeper's Legguards (mail, false / false)
	local function armor(o)
		local x = { type = "Armor", classID = 4, ilvl = 13, req = 0 }
		for k, v in pairs(o) do x[k] = v end
		return facts(x)
	end
	local eqA = equipped({
		[9] = armor({ id = 1504, name = "Warped Leather Bracers", subType = "Leather", sub = 2, slot = "INVTYPE_WRIST", ilvl = 6, req = 6, stats = { RESISTANCE0_NAME = 23 } }),
		[8] = armor({ id = 263309, name = "Freedom Walkers", subType = "Leather", sub = 2, slot = "INVTYPE_FEET", stats = { RESISTANCE0_NAME = 40, ITEM_MOD_STRENGTH_SHORT = 1 } }),
		[7] = armor({ id = 257334, name = "Well-Worn Pants", subType = "Leather", sub = 2, slot = "INVTYPE_LEGS", ilvl = 5, stats = { RESISTANCE0_NAME = 46 } }),
	})
	local a = {
		armor({ id = 263338, name = "Defender's Bracers", subType = "Leather", sub = 2, slot = "INVTYPE_WRIST", sell = 122, usable = false, second = false, flag = true, stats = { ITEM_MOD_STAMINA_SHORT = 1, RESISTANCE0_NAME = 28 } }),
		armor({ id = 263339, name = "Windswept Slippers", subType = "Cloth", sub = 1, slot = "INVTYPE_FEET", sell = 145, usable = false, second = false, flag = true, stats = { ITEM_MOD_SPIRIT_SHORT = 2, RESISTANCE0_NAME = 17 } }),
		armor({ id = 263340, name = "Peacekeeper's Legguards", subType = "Mail", sub = 3, slot = "INVTYPE_LEGS", sell = 292, usable = false, second = false, flag = false, stats = { ITEM_MOD_AGILITY_SHORT = 3, RESISTANCE0_NAME = 113 } }),
	}
	local ev2 = A.Evaluate({ dialog = { live = true, q = 93320, at = "QUEST_COMPLETE", choices = { { index = 1, kind = "choice", id = 263338, name = "Defender's Bracers", facts = a[1] }, { index = 2, kind = "choice", id = 263339, name = "Windswept Slippers", facts = a[2] }, { index = 3, kind = "choice", id = 263340, name = "Peacekeeper's Legguards", facts = a[3] } }, rewards = {} }, equipped = eqA, character = ROGUE })
	local r2 = ev2.recommendation
	local c1 = ev2.items[1].classification
	check(c1.primary == "UNKNOWN" and c1.eligibility.current.state == "UNKNOWN" and c1.eligibility.checks.proficiency.state == "YES", "Q93320: the classification is still UNKNOWN for the bracers although leather is already worn (the proficiency check says YES): the conflict is not hidden")
	check(r2.state == "TENTATIVE" and r2.selected.index == 1 and r2.basis == "ONLY_CANDIDATE", "Q93320: Defender's Bracers is the TENTATIVE pick  [" .. tostring(r2.state) .. "/" .. tostring(r2.basis) .. " " .. tostring(r2.selected and r2.selected.name) .. "]")
	check(stances(r2) == "PREFERRED,UNCERTAIN,INFERIOR", "Q93320: slippers UNCERTAIN (mixed, flags disagree), legguards INFERIOR (both flags false)  [" .. stances(r2) .. "]")
	local cv = table.concat(r2.caveats, " | ")
	check(cv:find("proficiency evidence says it can be worn", 1, true) and cv:find("do not agree with each other", 1, true), "Q93320: the caveat says proficiency evidence supports it but the client's flags disagree, and does not call it proven")
	-- 0.8.9: a Rogue gets nothing from the slippers' spirit, so they are no longer a "mixed" item: armor is lost and the spirit is not counted, said in the reason
	local c2 = ev2.items[2].classification
	check(c2.outcome.kind == "none" and c2.outcome.note:find("not counted for a Rogue: spirit", 1, true) ~= nil, "Q93320: the cloth slippers are no improvement for a Rogue (spirit not counted), not a mixed trade  [" .. tostring(c2.outcome.kind) .. "]")
	check(r2.state ~= "RECOMMEND", "Q93320: never a confident RECOMMEND while the client's own answers conflict")

	-- Q93746 (A Firm Response): two GUARANTEED rewards, no choice
	local rw = {
		armor({ id = 263305, name = "Windshaped Shield", subType = "Shields", sub = 6, slot = "INVTYPE_SHIELD", ilvl = 10, sell = 156, usable = false, second = false, flag = false, stats = { ITEM_MOD_STRENGTH_SHORT = 1, RESISTANCE0_NAME = 177 } }),
		facts({ id = 250339, name = "Minor Mageblood Elixir", slot = "", classID = 0, type = "Consumable", subType = "Elixir", ilvl = 5, req = 5, sell = 25, usable = false, second = false, flag = true, stats = {}, spell = "Minor Mageblood Elixir" }),
	}
	local ev3 = A.Evaluate({ dialog = { live = false, q = 93746, at = "QUEST_COMPLETE", choices = {}, rewards = { { index = 1, kind = "reward", id = 263305, name = "Windshaped Shield", facts = rw[1] }, { index = 2, kind = "reward", id = 250339, name = "Minor Mageblood Elixir", facts = rw[2] } } }, equipped = eqA, character = ROGUE })
	check(ev3.recommendation.state == "NOT_A_CHOICE" and ev3.recommendation.selected == nil, "Q93746: both are guaranteed: NOT_A_CHOICE, nothing picked")
	-- the report shows each of these without errors, ASCII only
	for _, d in ipairs({ ev, ev2, ev3 }) do
		local lines = table.concat(A.ReportLines({ dialog = { live = d.live, q = d.q, at = d.at, choices = (function() local o = {} for _, it in ipairs(d.items) do if it.kind == "choice" then o[#o + 1] = it end end return o end)(), rewards = (function() local o = {} for _, it in ipairs(d.items) do if it.kind ~= "choice" then o[#o + 1] = it end end return o end)() }, equipped = d.q == 92880 and eqW or eqA, character = ROGUE }), "\n")
		check(not lines:find("[\128-\255]") and lines:find("RECOMMENDATION:", 1, true), "Q" .. d.q .. ": the report section has a RECOMMENDATION line and is ASCII only")
	end
end

section("recommender: the report shows the state, the pick, the facts and the caveats")
do
	reset()
	local ev = A.Evaluate({ dialog = { live = true, q = 1, at = "QUEST_COMPLETE", choices = { { index = 1, kind = "choice", id = 1, name = "Fine Boots", facts = boots(1, "Fine Boots", 61, CF) }, { index = 2, kind = "choice", id = 2, name = "Big Boots", facts = boots(2, "Big Boots", 90, N) } }, rewards = {} }, equipped = worn(), character = { level = 9 } })
	local lines = A.ReportLines({ dialog = { live = true, q = 1, at = "QUEST_COMPLETE", choices = { { index = 1, kind = "choice", id = 1, name = "Fine Boots", facts = boots(1, "Fine Boots", 61, CF) }, { index = 2, kind = "choice", id = 2, name = "Big Boots", facts = boots(2, "Big Boots", 90, N) } }, rewards = {} }, equipped = worn(), character = { level = 9 } })
	local text = table.concat(lines, "\n")
	check(text:find("RECOMMENDATION: TENTATIVE | pick: choice 1, Fine Boots | basis ONLY_CANDIDATE | TENTATIVE: the evidence is incomplete", 1, true), "TENTATIVE: the state, the pick and the incomplete-evidence warning are on one line")
	check(text:find("    caveat: Quest Flow cannot confirm this character can use it", 1, true) and text:find("    fact: choice 2, Big Boots: cannot be used by this character", 1, true), "a caveat line and a fact line follow")
	check(text:find("    Choice 1. Fine Boots: PREFERRED", 1, true) and text:find("    Choice 2. Big Boots: INFERIOR", 1, true), "each choice shows its stance")
	check(not text:lower():find("you should") and not text:lower():find("take this"), "no instruction wording")
	check(ev.recommendation.selected.id == 1, "the structured result carries the pick")
end

section("advisor: Stage 3 is independent, read-only, free of stat weights and instruction wording; only the report consumes the recommender (the planner, presenter and providers do not, yet)")
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
	check(#readers == 0, "the planner, presenter and providers do not read the advisor (R1: reward recommendations do not influence any plan)")
	check(code("Diag.lua"):find("Advisor.ReportLines", 1, true) ~= nil, "the report consumes the advisor through Advisor.ReportLines (and with it the recommender)")
	check(not code("Planner.lua"):find("Recommend") and not code("PlanAdapter.lua"):find("Recommend") and not code("Presenter.lua"):find("Recommend"), "no planner, adapter or presenter code calls a recommender")
end

-- ================================================================ 0.8.9: stat trade-offs (class-aware, no weights, no score)
section("advisor 0.8.9: a Rogue's unused stats are left out and said so; real trade-offs still name no pick")
do
	reset()
	ns.Eligibility.ClearEvidence()
	local ROGUE = { level = 15, classToken = "ROGUE" }
	local DPS, AGI, STR, SPI, INT, STA = "ITEM_MOD_DAMAGE_PER_SECOND_SHORT", "ITEM_MOD_AGILITY_SHORT", "ITEM_MOD_STRENGTH_SHORT", "ITEM_MOD_SPIRIT_SHORT", "ITEM_MOD_INTELLECT_SHORT", "ITEM_MOD_STAMINA_SHORT"
	local function weapon(id, name, stats, extra)
		local o = { id = id, name = name, type = "Weapon", classID = 2, subType = "Daggers", sub = 15, slot = "INVTYPE_WEAPONMAINHAND", stats = stats, sell = 1291, usable = true, second = true, flag = true }
		for k, v in pairs(extra or {}) do o[k] = v end
		return facts(o)
	end
	local function eqWith(stats) return equipped({ [16] = weapon(900, "Defias Rapier", stats) }) end
	local eq = eqWith({ [DPS] = 8.125, [AGI] = 2 })
	local function classify(f, e, ch) return A.Classify(f, e or eq, { character = ch or ROGUE }) end
	local function reasonOf(c) for _, x in ipairs(c.categories) do if x.id == c.primary then return x.reason end end end

	-- a clearly better relevant-stat weapon
	local up = classify(weapon(1, "Good Dagger", { [DPS] = 12, [AGI] = 5 }))
	check(up.primary == "UPGRADE" and reasonOf(up):find("agility", 1, true) and reasonOf(up):find("weapon dps", 1, true), "clearly better dps and agility: UPGRADE, with the stats in the reason  [" .. tostring(up.primary) .. ": " .. tostring(reasonOf(up)) .. "]")
	-- a clearly worse one
	local worse = classify(weapon(2, "Bad Dagger", { [DPS] = 5, [AGI] = 1 }))
	check(worse.primary ~= "UPGRADE" and worse.outcome.kind == "none", "lower dps and agility: not an improvement")
	-- gains only in stats a Rogue does not use are no improvement (they used to be called an upgrade)
	local junk = classify(weapon(3, "Mage Dagger", { [DPS] = 8.125, [AGI] = 2, [SPI] = 6, [INT] = 6 }))
	check(junk.outcome.kind == "none" and junk.primary == "VENDOR" and reasonOf(junk):find("not counted for a Rogue: intellect, spirit", 1, true), "only spirit and intellect gained: no improvement, VENDOR, and the reason says those were not counted  [" .. tostring(junk.primary) .. ": " .. tostring(reasonOf(junk)) .. "]")
	local sh = classify(weapon(3, "Mage Dagger", { [DPS] = 8.125, [AGI] = 2, [SPI] = 6 }), nil, { level = 15, classToken = "SHAMAN" })
	check(sh.outcome.kind ~= "none", "another class keeps the plain comparison (spirit counts for a Shaman)")
	-- losing an unused stat is not a loss
	local eqS = eqWith({ [DPS] = 8.125, [AGI] = 2, [SPI] = 3 })
	local keep = classify(weapon(4, "Agile Dagger", { [DPS] = 8.125, [AGI] = 5 }), eqS)
	check(keep.primary == "UPGRADE" and reasonOf(keep):find("not counted for a Rogue: spirit", 1, true), "+3 agility and -3 spirit: UPGRADE for a Rogue (the lost spirit is not counted, and that is said)  [" .. tostring(keep.primary) .. ": " .. tostring(reasonOf(keep)) .. "]")
	-- higher dps but a LOSS of a stat that counts (the Q5730 hammer): still a trade-off, no pick
	local hammer = classify(weapon(5, "Hammer", { [DPS] = 12.41, [STR] = 3, [SPI] = 3 }, { subType = "Maces", sub = 4 }))
	check(hammer.primary == "UNKNOWN" or hammer.primary == "MIXED", "more dps and strength but -2 agility: a trade-off, not an Upgrade")
	check(hammer.outcome.kind == "mixed" and reasonOf(hammer) ~= nil, "(its outcome is mixed)")
	-- a rounding-sized dps difference is noise (Kris: -0.125 dps = -1.5%): mentioned nowhere, +stamina does not rescue the -2 agility
	local kris = classify(weapon(6, "Kris", { [DPS] = 8, [STA] = 4 }))
	check(kris.outcome.kind == "mixed" and not reasonOf(kris):find("weapon dps", 1, true), "-1.5% dps is noise, and +4 stamina does not outweigh -2 agility: mixed, dps not mentioned")
	local noise = classify(weapon(7, "Same Dagger", { [DPS] = 8.2, [AGI] = 2 }))
	check(noise.outcome.kind == "none", "+0.9% dps and nothing else: no improvement")
	local slight = classify(weapon(8, "Slightly Better", { [DPS] = 8.9, [AGI] = 2 }))
	check(slight.primary == "SLIGHT_UPGRADE", "+9.5% dps: only a SLIGHT upgrade, never presented as a big one  [" .. tostring(slight.primary) .. "]")
	-- usability and missing information are untouched
	check(classify(weapon(9, "Two Hander", { [DPS] = 16, [AGI] = 9 }, { usable = false, second = false, flag = false })).primary == "NOT_USABLE", "an item the client says is not usable stays NOT_USABLE")
	check(classify(facts({ id = 10, name = "Loading", waiting = true })).primary == "UNKNOWN", "an item that has not loaded stays UNKNOWN")
	check(A.Recommend({ items = {} }).state == "NOT_A_CHOICE", "no reward items: NOT_A_CHOICE")

	-- several choices
	local good, bad = weapon(11, "Good Dagger", { [DPS] = 12, [AGI] = 5 }), weapon(12, "Hammer", { [DPS] = 12.41, [STR] = 3, [SPI] = 3 }, { subType = "Maces", sub = 4 })
	local r = A.Recommend(choiceEval({ good, bad }, eq, ROGUE))
	check((r.state == "RECOMMEND" or r.state == "TENTATIVE") and r.selected and r.selected.index == 1, "one clearly better choice and one trade-off: the clear one is picked  [" .. tostring(r.state) .. "/" .. tostring(r.selected and r.selected.index) .. "]")
	local q = A.Recommend(choiceEval({ weapon(13, "Hammer", { [DPS] = 12.41, [STR] = 3, [SPI] = 3 }, { subType = "Maces", sub = 4 }), weapon(14, "Kris", { [DPS] = 8, [STA] = 4 }) }, eq, ROGUE))
	-- 0.9.6: both stay MIXED, but the one that clearly raises weapon damage for a loss no larger than the other's is the pick (reward_tradeoff_tests.lua has the rule's limits)
	check((q.state == "RECOMMEND" or q.state == "TENTATIVE") and q.selected and q.selected.index == 1 and q.basis == "MIXED_DPS", "two trade-offs: the Hammer (clear weapon dps gain, same agility loss) is the pick  [" .. tostring(q.state) .. "/" .. tostring(q.basis) .. "]")
	check(#ns.errors == 0, "no errors")
end

-- ================================================================ 0.9.1: legal equipment slots (generic fixtures; no item names are special)
section("advisor 0.9.1: a reward is compared with the item in each slot it may legally occupy, and only those")
do
	reset()
	ns.Eligibility.ClearEvidence()
	local ROGUE = { level = 15, classToken = "ROGUE" }
	local DPS, AGI, STA, STR, SPI = "ITEM_MOD_DAMAGE_PER_SECOND_SHORT", "ITEM_MOD_AGILITY_SHORT", "ITEM_MOD_STAMINA_SHORT", "ITEM_MOD_STRENGTH_SHORT", "ITEM_MOD_SPIRIT_SHORT"
	local function wp(id, name, slot, dps, agi, flags, extra)
		local o = { id = id, name = name, type = "Weapon", classID = 2, subType = "Daggers", sub = 15, slot = slot, stats = { [DPS] = dps, [AGI] = agi }, sell = 500, usable = true, second = true, flag = true }
		for k, v in pairs(flags or {}) do o[k] = v end
		for k, v in pairs(extra or {}) do o[k] = v end
		return facts(o)
	end
	local MH, OH, EITHER, TWO = "INVTYPE_WEAPONMAINHAND", "INVTYPE_WEAPONOFFHAND", "INVTYPE_WEAPON", "INVTYPE_2HWEAPON"
	local function setup(mh, oh) return equipped({ [16] = mh, [17] = oh }) end
	local function classify(f, eq) return A.Classify(f, eq, { character = ROGUE }) end
	local function slotsOf(c) local s = {} for _, e in ipairs(c.comparison.entries or {}) do s[#s + 1] = e.slot end return table.concat(s, ",") end
	local function reasonOf(c) for _, x in ipairs(c.categories) do if x.id == c.primary then return x.reason end end end
	local eq = setup(wp(100, "Worn Main", MH, 10, 2), wp(101, "Worn Off", OH, 7, 1))

	-- 1. a main-hand-only reward is compared with the main hand only
	local c1 = classify(wp(1, "Mh Reward", MH, 12, 5), eq)
	check(slotsOf(c1) == "16" and c1.outcome.chosen == 16 and c1.outcome.evidence.against == "Worn Main" and c1.outcome.kind == "upgrade", "main-hand-only reward: compared with slot 16 (the main hand) only  [" .. slotsOf(c1) .. "]")
	-- 2. an off-hand-only reward is compared with the off hand only
	local c2 = classify(wp(2, "Oh Reward", OH, 9, 2), eq)
	check(slotsOf(c2) == "17" and c2.outcome.chosen == 17 and c2.outcome.evidence.against == "Worn Off", "off-hand-only reward: compared with slot 17 (the off hand) only  [" .. slotsOf(c2) .. "]")
	-- 4. a main-hand-only item that is worn is never a replacement target for an off-hand reward (nor an off-hand-only worn item for a main-hand reward)
	local c4 = classify(wp(4, "Weak Off Reward", OH, 6, 1), eq)
	check(slotsOf(c4) == "17" and c4.outcome.kind == "none", "a weaker off-hand reward is judged against the off hand only (not an upgrade over the worn main hand's slot)  [" .. c4.outcome.kind .. "]")
	local c4b = classify(wp(5, "Strong Off Reward", OH, 12, 5), eq)
	check(slotsOf(c4b) == "17" and c4b.outcome.evidence.against == "Worn Off", "a stronger off-hand reward replaces the off hand, not the main hand")

	-- 3. an either-hand weapon: both legal slots are considered; it is an upgrade where it replaces the weaker one
	local c3 = classify(wp(3, "Either Reward", EITHER, 9, 2), eq)
	check(slotsOf(c3) == "16,17", "an either-hand reward considers both the main hand and the off hand  [" .. slotsOf(c3) .. "]")
	check(c3.outcome.chosen == 17 and c3.outcome.kind == "upgrade" and c3.primary == "UPGRADE", "9 dps is worse than the main hand (10) but better than the off hand (7): an UPGRADE as the off hand  [" .. tostring(c3.outcome.kind) .. " slot " .. tostring(c3.outcome.chosen) .. "]")
	check(reasonOf(c3):find("OFFHAND", 1, true), "and the reason names the slot  [" .. tostring(reasonOf(c3)) .. "]")
	-- (the same weapon is judged against the main hand alone it is no upgrade: the slot awareness is what changes the answer)
	check(classify(wp(3, "Same Weapon", MH, 9, 2), eq).outcome.kind == "none", "(as a main-hand-only item, the same stats are no upgrade)")

	-- 6. several legal scenarios with different results: the clearly better one wins; mixed stays mixed
	local eq6 = setup(wp(110, "Main", MH, 10, 5), wp(111, "Off", OH, 7, 1))
	local c6 = classify(wp(6, "Either", EITHER, 12, 3), eq6)
	check(c6.outcome.chosen == 17 and c6.outcome.kind == "upgrade", "mixed in the main hand but a clear gain in the off hand: the off hand is the scenario  [" .. c6.outcome.kind .. "/" .. tostring(c6.outcome.chosen) .. "]")
	local eq6b = setup(wp(112, "Main", MH, 10, 5), wp(113, "Off", OH, 14, 1))
	local c6b = classify(wp(7, "Either", EITHER, 12, 3), eq6b)
	check(c6b.outcome.kind == "mixed", "mixed in both hands: still mixed, no scenario is clearly better  [" .. c6b.outcome.kind .. "]")
	local eq6c = setup(wp(114, "Main", MH, 14, 5), wp(115, "Off", OH, 14, 1))
	local c6c = classify(wp(8, "Either", EITHER, 12, 3), eq6c)
	check(c6c.outcome.kind == "mixed" and c6c.outcome.chosen == 17, "no gain over the main hand, a trade-off against the off hand: reported as the trade-off it is (mixed), not as 'no gain'  [" .. c6c.outcome.kind .. "]")
	local rec = A.Recommend(choiceEval({ wp(9, "Either A", EITHER, 12, 3), wp(10, "Either B", EITHER, 12, 3) }, eq6b, ROGUE))
	check(rec.state == "NO_CLEAR_RECOMMENDATION" and rec.selected == nil, "two such choices: no clear recommendation")

	-- 5. two-handers: not a plain main-hand replacement
	local c5 = classify(wp(11, "Two Hand", TWO, 20, 8), eq)
	check(c5.outcome.kind == "unknown" and c5.outcome.note:find("two-handed", 1, true) and c5.primary ~= "UPGRADE", "a two-hander with an off-hand item worn: not compared as a main-hand upgrade, stays UNKNOWN  [" .. tostring(c5.outcome.note) .. "]")
	check(c5.outcome.note:find("Worn Main", 1, true) and c5.outcome.note:find("Worn Off", 1, true), "and the note names what it would replace")
	local rec5 = A.Recommend(choiceEval({ wp(12, "Two Hand", TWO, 20, 8), wp(13, "Poor One", MH, 5, 1) }, eq, ROGUE))
	check(rec5.selected == nil or rec5.selected.index ~= 1, "a two-hander is never the pick over an off-hand-displacing setup Quest Flow cannot judge")
	local eqEmpty = setup(wp(120, "Worn Main", MH, 10, 2), nil)
	local c5b = classify(wp(14, "Two Hand", TWO, 20, 8), eqEmpty)
	check(c5b.outcome.kind == "upgrade" and c5b.outcome.chosen == 16 and slotsOf(c5b) == "16", "with the off hand empty a two-hander is an ordinary comparison with the main hand")
	-- an off-hand slot is not free while a two-hander is wielded
	local eq2h = setup(wp(121, "Worn Two Hand", TWO, 18, 4), nil)
	local c5c = classify(wp(15, "Off Reward", OH, 6, 1), eq2h)
	check(c5c.outcome.kind == "unknown" and c5c.primary ~= "UPGRADE", "an off-hand reward while the main hand holds a two-hander: the empty off hand is NOT 'free' (UNKNOWN)  [" .. c5c.outcome.kind .. "]")
	local c5d = classify(wp(16, "Either", EITHER, 12, 5), eq2h)
	check(c5d.outcome.kind ~= "empty_slot", "an either-hand reward is judged against the two-hander in the main hand, not as filling a 'free' off hand  [" .. c5d.outcome.kind .. "]")

	-- the real Q5730 setup: Hammer is main-hand-only, Kris either-hand, Axe and Staff two-handed; still no clear pick
	local rapier = facts({ id = 900, name = "Defias Rapier", type = "Weapon", classID = 2, subType = "Daggers", sub = 15, slot = MH, stats = { [DPS] = 8.125, [AGI] = 2 }, usable = true, second = true })
	local quick = facts({ id = 901, name = "Quickblade's Dagger", type = "Weapon", classID = 2, subType = "Daggers", sub = 15, slot = EITHER, stats = { [DPS] = 6.76, [AGI] = 1 }, usable = true, second = true })
	local eqQ = equipped({ [16] = rapier, [17] = quick })
	local CF = { usable = false, second = false, flag = true }
	local NO = { usable = false, second = false, flag = false }
	local kris = facts({ id = 1, name = "Kris", type = "Weapon", classID = 2, subType = "Daggers", sub = 15, slot = EITHER, stats = { [DPS] = 8, [STA] = 4 }, sell = 1291, usable = false, second = false, flag = true })
	local hammer = facts({ id = 2, name = "Hammer", type = "Weapon", classID = 2, subType = "Maces", sub = 4, slot = MH, stats = { [DPS] = 12.41, [STR] = 3, [SPI] = 3 }, sell = 1291, usable = false, second = false, flag = true })
	local axe = facts({ id = 3, name = "Axe", type = "Weapon", classID = 2, subType = "Two-Handed Axes", sub = 1, slot = TWO, stats = { [DPS] = 16.06, [SPI] = 6, [STA] = 6 }, sell = 1614, usable = false, second = false, flag = false })
	local staff = facts({ id = 4, name = "Staff", type = "Weapon", classID = 2, subType = "Staves", sub = 10, slot = TWO, stats = { [DPS] = 11.8, [AGI] = 6 }, sell = 1614, usable = false, second = false, flag = false })
	local ck, ch = classify(kris, eqQ), classify(hammer, eqQ)
	check(slotsOf(ch) == "16" and ch.outcome.evidence.against == "Defias Rapier", "Hammer (main-hand-only) is compared with the main hand, Defias Rapier")
	check(slotsOf(ck) == "16,17", "Kris (either hand) is compared with both hands")
	local rq = A.Recommend(choiceEval({ kris, hammer, axe, staff }, eqQ, ROGUE))
	check(rq.state == "TENTATIVE" and rq.selected and rq.selected.index == 2 and rq.basis == "MIXED_DPS", "Q5730 (0.9.6): the Hammer is the tentative pick; usability is not established, so not a plain RECOMMEND  [" .. tostring(rq.state) .. "/" .. tostring(rq.selected and rq.selected.index) .. "]")
	check(classify(axe, eqQ).primary == "NOT_USABLE" and classify(staff, eqQ).primary == "NOT_USABLE", "Axe and Staff stay NOT_USABLE")
	check(#ns.errors == 0, "no errors")
end
