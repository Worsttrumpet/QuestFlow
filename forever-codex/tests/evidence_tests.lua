-- evidence_tests.lua: the proficiency-evidence recorder (EligibilityEvidence.lua), its use by Eligibility, and the natural observation points (reward dialog,
-- worn items). Synthetic observations and a stub client only: they prove the bookkeeping, the policy and the "UNKNOWN unless proven" behaviour. They say nothing
-- about what the real Forever client allows; that evidence has to be recorded by playing.

local H = ...
local check, section, boot = H.check, H.section, H.boot

local ns = boot({ char = { level = 39 } })
local Ev, E, A, I = ns.EligibilityEvidence, ns.Eligibility, ns.Advisor, ns.Items
ForeverCodexDB = type(ForeverCodexDB) == "table" and ForeverCodexDB or {}

local function reset() ForeverCodexDB.items = nil; Ev.Clear(); E.ClearEvidence(); Ev.POLICY.yesWorn, Ev.POLICY.yesClient, Ev.POLICY.noClient = 1, 2, 3 end
reset()

--- A raw observation. o = { class, level, id, usable, req, source, build, sub, race }
local function raw(o)
	return { character = { class = o.class or "SHAMAN", level = o.level, race = o.race or "ORC", faction = "Horde" },
		item = { id = o.id, itemClass = o.itemClass or 4, subClass = o.sub or 3, typeText = o.text or "Armor/Mail", requiredLevel = o.req == nil and 1 or o.req, equipSlot = "INVTYPE_CHEST" },
		result = { usable = o.usable, source = o.source or "client_usability" }, context = { build = o.build or "70205", evidenceSource = "test", t = o.t or 100 } }
end
local function rec(o) return Ev.Record(raw(o)) end

local function facts(o)
	local f = { name = o.name or "Item", link = "|Hitem:" .. (o.id or 1) .. "::|h[x]|h", quality = 2, level = 30, minLevel = o.req or 1, type = "Armor", subType = o.subType or "Mail",
		equipLoc = o.slot or "INVTYPE_CHEST", sellPrice = 50, classID = o.classID or 4, subClassID = o.sub or 3, stats = { RESISTANCE0_NAME = 50 }, usable = o.usable, usableSecond = false }
	local r = { id = o.id or 1, ref = o.id or 1, f = f, src = {}, err = {}, spellRead = true }
	if o.usable == nil then r.err.usable = "api absent" end
	local n = I.Normalize(r)
	if o.flag ~= nil then n.offered = { source = "reward_dialog", kind = "choice", index = 1, quest = 1, dialogFlag = o.flag } end
	return n
end

local function equipped(items)
	local eq = { state = "OK", slots = {}, list = {} }
	for n = 1, I.EQUIP_SLOTS do
		local e = { slot = n, slotName = ns.Gear.SLOT_NAMES[n], state = "EMPTY" }
		if items and items[n] then e.state, e.itemFacts, e.itemId = "POPULATED", items[n], items[n].id end
		eq.slots[n], eq.list[n] = e, e
	end
	return eq
end

section("evidence: a usable and an unusable observation are recorded as OBSERVATIONS with their provenance")
do
	reset()
	local st, o = rec({ level = 40, id = 1, usable = true, source = "worn_item" })
	check(st == "recorded" and o.usable == true and o.state == "OBSERVED" and o.source == "worn_item" and o.class == "SHAMAN" and o.level == 40, "a usable observation: usable = true, OBSERVED, source worn_item")
	check(o.itemId == 1 and o.itemClass == 4 and o.subClass == 3 and o.typeText == "Armor/Mail" and o.equipSlot == "INVTYPE_CHEST" and o.requiredLevel == 1, "with the item's id, type, equip slot and required level")
	check(o.race == "ORC" and o.faction == "Horde" and o.build == "70205" and o.evidenceSource == "test" and o.first == 100 and o.last == 100 and o.n == 1, "and the character's race and faction, the build, the evidence source, the times and a repeat count of 1")
	local st2, o2 = rec({ level = 39, id = 2, usable = false })
	check(st2 == "recorded" and o2.usable == false and o2.state == "OBSERVED", "an unusable observation: usable = false, OBSERVED")
	check(#o.confounds == 0, "an item whose required level is below the character's level has no confounder")
	check(#Ev.Observations() == 2, "both are stored")
end

section("evidence: missing information stays UNKNOWN and is never turned into false")
do
	reset()
	local st, why = Ev.Record({ character = { level = 40 }, item = { id = 1, itemClass = 4, subClass = 3 }, result = { usable = true, source = "worn_item" } })
	check(st == "rejected" and why == "character class not known", "no class: rejected, reason stated")
	check(select(2, Ev.Record({ character = { class = "SHAMAN" }, item = { id = 1, itemClass = 4, subClass = 3 }, result = { usable = true, source = "x" } })) == "character level not known", "no level: rejected")
	check(select(2, Ev.Record({ character = { class = "SHAMAN", level = 5 }, item = { id = 1 }, result = { usable = true, source = "x" } })) == "item type not known", "no item type: rejected")
	check(select(2, Ev.Record(raw({ level = 5, id = 1, usable = true, itemClass = 4, sub = 0 }))) == "item type has no proficiency", "an item type with no proficiency (rings, necks) is not evidence")
	check(select(2, Ev.Record({ character = { class = "SHAMAN", level = 5 }, item = { id = 1, itemClass = 4, subClass = 3 }, result = { usable = true } })) == "no source", "no source: rejected")
	local sk = Ev.Status().skipped
	check(sk["character class not known"] == 1 and sk["character level not known"] == 1 and sk["no source"] == 1, "every rejection is counted by reason")
	-- a result that is not known is kept but never counted
	local s, o = rec({ level = 39, id = 9, usable = nil })
	check(s == "recorded" and o.usable == nil and o.state == "UNKNOWN", "an observation whose result is unknown is kept as UNKNOWN (not false)")
	local g = Ev.Group("SHAMAN", 4, 3)
	check(g.counts.unknown == 1 and g.counts.yes == 0 and g.counts.no == 0 and g.evidenceState == "OBSERVED", "and it counts as neither usable nor unusable")
	local r = Ev.GetProficiency("SHAMAN", 4, 3, 39)
	check(r.state == "UNKNOWN" and r.evidenceState == "OBSERVED", "the answer stays UNKNOWN")
	reset()
	local none = Ev.GetProficiency("SHAMAN", 4, 3, 39)
	check(none.state == "UNKNOWN" and none.reason == "No proven Forever client evidence" and none.evidenceState == "UNKNOWN" and none.evidenceCount == 0, "with nothing recorded: UNKNOWN, 'No proven Forever client evidence'")
	check(Ev.GetProficiency(nil, 4, 3, 39).state == "UNKNOWN" and Ev.GetProficiency("SHAMAN", 4, 3, nil).state == "UNKNOWN", "missing arguments are UNKNOWN")
end

section("evidence: compatible observations accumulate; a PROVEN answer needs the policy, and an unproven aggregate cannot masquerade as one")
do
	reset()
	rec({ level = 28, id = 11, usable = false }); rec({ level = 28, id = 12, usable = false })
	local r2 = Ev.GetProficiency("SHAMAN", 4, 3, 28)
	check(r2.state == "UNKNOWN" and r2.evidenceState == "OBSERVED" and r2.evidenceCount == 2, "2 unusable items at one level: OBSERVED, not proven (a NO needs 3 distinct items)")
	rec({ level = 28, id = 13, usable = false })
	local r3 = Ev.GetProficiency("SHAMAN", 4, 3, 28)
	check(r3.state == "PROVEN_NO" and r3.evidenceState == "PROVEN" and r3.bounds.noAt == 28 and r3.evidenceCount == 3 and r3.source == "observed_client", "3 distinct unusable items at one level: PROVEN_NO")
	check(r3.unlockLevel == nil and r3.reason:find("unlock level not proven", 1, true), "the unlock level is NOT proven by a NO alone")
	check(Ev.GetProficiency("SHAMAN", 4, 3, 20).state == "PROVEN_NO", "not usable at 28 is also not usable at a lower level (proficiency does not disappear as the level rises)")
	check(Ev.GetProficiency("SHAMAN", 4, 3, 30).state == "UNKNOWN", "but it says nothing about level 30")
	-- the same item three times is one distinct item
	reset()
	for i = 1, 3 do rec({ level = 28, id = 11, usable = false, t = 100 + i }) end
	check(Ev.GetProficiency("SHAMAN", 4, 3, 28).state == "UNKNOWN", "the same item observed three times is one item: not proven")
	-- a single client-flagged usable item is observed, two are proven; a worn item is proven by itself
	reset()
	rec({ level = 30, id = 21, usable = true })
	check(Ev.GetProficiency("SHAMAN", 4, 3, 30).state == "UNKNOWN", "one client-flagged usable item is not enough")
	rec({ level = 30, id = 22, usable = true })
	check(Ev.GetProficiency("SHAMAN", 4, 3, 30).state == "PROVEN_YES", "two distinct client-flagged usable items prove it")
	reset()
	rec({ level = 30, id = 23, usable = true, source = "worn_item" })
	local w = Ev.GetProficiency("SHAMAN", 4, 3, 35)
	check(w.state == "PROVEN_YES" and w.unlockAtMost == 30 and w.unlockLevel == nil, "one worn item proves usable from level 30 at the latest (and for every higher level), with no claim about the exact unlock")
	check(Ev.GetProficiency("SHAMAN", 4, 3, 29).state == "UNKNOWN", "and says nothing about level 29")
	-- observations that do not isolate proficiency are not counted
	reset()
	for i = 1, 5 do rec({ level = 39, id = 30 + i, usable = false, req = 45 }) end
	local c = Ev.GetProficiency("SHAMAN", 4, 3, 39)
	check(c.state == "UNKNOWN" and Ev.Group("SHAMAN", 4, 3).counts.confounded == 5, "five unusable items whose required level is above the character's level prove nothing about proficiency")
	local unknownReq = Ev.Record(raw({ level = 39, id = 40, usable = false, req = false }))
	check(true, "(required level handling below)")
	reset()
	local rr = raw({ level = 39, id = 41, usable = false }); rr.item.requiredLevel = nil
	local _, ro = Ev.Record(rr)
	check(ro.confounds[1] == "required level not known", "an unknown required level is a recorded confounder, not zero")
end

section("evidence: contradictions are CONFLICT, never resolved, and Eligibility treats them as UNKNOWN")
do
	reset()
	rec({ level = 40, id = 50, usable = true }); rec({ level = 40, id = 50, usable = false })
	local g = Ev.Group("SHAMAN", 4, 3)
	check(g.evidenceState == "CONFLICT" and #g.conflicts >= 1, "the same item usable and unusable at one level: CONFLICT")
	local r = Ev.GetProficiency("SHAMAN", 4, 3, 40)
	check(r.state == "CONFLICT" and r.evidenceState == "CONFLICT" and r.conflicts and r.reason:find("conflict", 1, true), "the answer is CONFLICT with the reason")
	check(#Ev.Observations() == 2, "both observations are still stored (nothing was overwritten)")
	-- a monotonic conflict across items
	reset()
	rec({ level = 30, id = 51, usable = true, source = "worn_item" })
	for i = 1, 3 do rec({ level = 35, id = 60 + i, usable = false }) end
	local m = Ev.Group("SHAMAN", 4, 3)
	check(m.evidenceState == "CONFLICT" and m.conflicts[1].yesLevel == 30 and m.conflicts[1].noLevel == 35, "unusable at level 35 after usable at level 30 is a conflict")
	-- Eligibility never turns a conflict into yes or no
	local item = facts({ id = 70, usable = true, flag = nil, req = 5 })
	local e = E.Evaluate(item, { level = 35, classToken = "SHAMAN" }, { equipped = equipped({}) })
	check(e.checks.proficiency.state == "UNKNOWN" and e.checks.proficiency.detail:find("conflict", 1, true) and e.current.state ~= "PROVEN_YES" and e.current.state ~= "PROVEN_NO", "Eligibility: a conflict is UNKNOWN, never PROVEN_YES or PROVEN_NO  [" .. e.current.state .. "]")
end

section("evidence: duplicates are merged, different builds, items and results stay distinct")
do
	reset()
	local s1 = rec({ level = 39, id = 80, usable = false, t = 100 })
	local s2, d = rec({ level = 39, id = 80, usable = false, t = 250 })
	check(s1 == "recorded" and s2 == "duplicate" and d.n == 2 and d.first == 100 and d.last == 250 and #Ev.Observations() == 1, "an identical observation is one record with a repeat count and the first and last time")
	check(Ev.Group("SHAMAN", 4, 3).counts.observations == 2, "the group still counts both sightings")
	local s3 = rec({ level = 39, id = 80, usable = false, build = "70999" })
	check(s3 == "recorded" and #Ev.Observations() == 2, "the same observation from a DIFFERENT BUILD is a separate record")
	check(rec({ level = 39, id = 81, usable = false }) == "recorded" and rec({ level = 38, id = 80, usable = false }) == "recorded" and rec({ level = 39, id = 80, usable = true }) == "recorded", "a different item, level or result is a separate record")
	check(rec({ level = 39, id = 80, usable = false, race = "TAUREN" }) == "recorded", "a different race is a separate record")
	local builds = {}
	for _, o in ipairs(Ev.Observations()) do builds[o.build] = true end
	check(builds["70205"] and builds["70999"], "the builds remain distinguishable in the stored records")
	check(Ev.Dump(10)[1]:find("build", 1, true), "the detailed dump shows the build")
	local st = Ev.Status()
	check(st.repeats == 1, "status counts the merged repeat")
end

section("evidence: an exact unlock level is proven only by a NO at U-1 and a YES at U; PROVEN answers can be queried")
do
	reset()
	for i = 1, 3 do rec({ level = 39, id = 90 + i, usable = false }) end
	rec({ level = 40, id = 99, usable = true, source = "worn_item" })
	local atNo = Ev.GetProficiency("SHAMAN", 4, 3, 39)
	check(atNo.state == "PROVEN_NO" and atNo.unlockLevel == 40 and atNo.bounds.noAt == 39 and atNo.bounds.yesAt == 40, "usable at 40 and not at 39: PROVEN_NO at 39 with the exact unlock level 40")
	local atYes = Ev.GetProficiency("SHAMAN", 4, 3, 40)
	check(atYes.state == "PROVEN_YES" and atYes.unlockLevel == 40 and atYes.evidenceCount == 4, "and PROVEN_YES at 40 with the same unlock level")
	check(Ev.GetProficiency("SHAMAN", 4, 3, 45).state == "PROVEN_YES", "and at any higher level")
	check(Ev.GetProficiency("WARRIOR", 4, 3, 40).state == "UNKNOWN", "other classes are untouched")
	check(Ev.GetProficiency("SHAMAN", 4, 4, 40).state == "UNKNOWN", "and so are other item types")
	-- a gap between the two levels keeps the unlock unproven
	reset()
	for i = 1, 3 do rec({ level = 30, id = 100 + i, usable = false }) end
	rec({ level = 40, id = 110, usable = true, source = "worn_item" })
	local gap = Ev.GetProficiency("SHAMAN", 4, 3, 30)
	check(gap.state == "PROVEN_NO" and gap.unlockLevel == nil and gap.bounds.yesAt == 40, "NO at 30 and YES at 40: the unlock is somewhere between, not proven")
	check(Ev.GetProficiency("SHAMAN", 4, 3, 35).state == "UNKNOWN", "and level 35 is UNKNOWN")
end

section("eligibility consumes proven evidence, stays UNKNOWN otherwise, and keeps level and proficiency separate")
do
	reset()
	local SH = function(level) return { level = level, classToken = "SHAMAN", raceToken = "ORC", faction = "Horde" } end
	local mail = function(o) return facts({ id = 200, usable = false, flag = false, req = o and o.req or 35 }) end
	-- no evidence at all
	local e0 = E.Evaluate(mail(), SH(39), { equipped = equipped({}) })
	check(e0.checks.proficiency.state == "UNKNOWN" and e0.checks.proficiency.referenceHint.minLevel == 40 and e0.checks.proficiency.referenceHint.src:find("not proven on Forever", 1, true), "no evidence: UNKNOWN, with the Classic reference shown only as a hint labelled not proven on Forever")
	check(e0.future.state == "UNKNOWN", "and the future is UNKNOWN")
	-- merely OBSERVED evidence changes nothing
	rec({ level = 39, id = 300, usable = false }); rec({ level = 39, id = 301, usable = false })
	local e1 = E.Evaluate(mail(), SH(39), { equipped = equipped({}) })
	check(e1.checks.proficiency.state == "UNKNOWN" and e1.checks.proficiency.evidence.evidenceState == "OBSERVED", "two observations are recorded but not proven: eligibility stays UNKNOWN (recording does not raise certainty)")
	check(e1.current.state == "PROVEN_NO", "(the client's own answers still say no now)")
	-- proven evidence is consumed
	rec({ level = 39, id = 302, usable = false })
	rec({ level = 40, id = 303, usable = true, source = "worn_item" })
	local e2 = E.Evaluate(mail(), SH(39), { equipped = equipped({}) })
	check(e2.checks.proficiency.state == "NO" and e2.checks.proficiency.unlock == 40 and e2.checks.proficiency.src == "recorded Forever observations" and e2.checks.proficiency.proven == true, "proven evidence: a proficiency NO that unlocks at 40, source 'recorded Forever observations'")
	check(e2.current.state == "PROVEN_NO" and e2.future.state == "SOON" and e2.future.unlockLevel == 40, "current PROVEN_NO, future SOON (unlock 40)  [" .. e2.future.state .. "]")
	local e3 = E.Evaluate(facts({ id = 200, usable = true, flag = true, req = 35 }), SH(40), { equipped = equipped({}) })
	check(e3.checks.proficiency.state == "YES" and e3.current.state == "PROVEN_YES", "at level 40 the same evidence gives PROVEN_YES")
	-- level requirement and proficiency stay separate
	local high = E.Evaluate(facts({ id = 201, usable = false, flag = false, req = 45 }), SH(40), { equipped = equipped({}) })
	check(high.checks.proficiency.state == "YES" and high.checks.level.state == "NO" and high.current.state == "PROVEN_NO", "proficiency proven, but the item's required level (45) is not met: still PROVEN_NO because of the level")
	check(high.future.state == "LATER" and high.future.unlockLevel == 45, "and the future follows the level requirement")
	local lowReq = E.Evaluate(facts({ id = 202, usable = false, flag = false, req = 5 }), SH(39), { equipped = equipped({}) })
	check(lowReq.checks.level.state == "YES" and lowReq.checks.proficiency.state == "NO", "a met required level does not prove proficiency")
	-- a different class is not affected by this class's evidence
	local other = E.Evaluate(mail(), { level = 39, classToken = "WARRIOR" }, { equipped = equipped({}) })
	check(other.checks.proficiency.state == "UNKNOWN", "another class has no evidence")
end

section("evidence: Classic rules stay a labelled reference; no class-to-armor table exists")
do
	reset()
	local ee, rr = E.Evidence()
	check(#rr == 4 and rr[1].proven == false and rr[2].proven == false and rr[3].proven == false and rr[4].proven == false, "the four Classic reference records are all proven = false")
	for _, r in ipairs(rr) do check(r.src == "Classic reference (not proven on Forever)", "reference record is labelled: " .. r.class) end
	local function code(f) return (H.readFile(H.addonDir .. "/" .. f):gsub("%-%-[^\n]*", "")) end
	local src = code("EligibilityEvidence.lua")
	for _, tok in ipairs({ "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "SHAMAN", "MAGE", "WARLOCK", "DRUID", "Classic" }) do
		check(not src:find(tok, 1, true), "EligibilityEvidence.lua does not mention " .. tok)
	end
	check(not src:find("minLevel%s*=%s*%d") and not src:find("40"), "EligibilityEvidence.lua contains no proficiency level threshold")
	for _, pat in ipairs({ "ns%.Planner", "ns%.Engine", "ns%.Strategies", "ns%.State", "ns%.UI", "ns%.Presenter", "ns%.Registry", "ns%.Gear", "ns%.Advisor", "ns%.Eligibility[^E]", "ns%.Overlap", "ns%.ItemProbe" }) do
		check(not src:find(pat), "EligibilityEvidence.lua does not depend on " .. pat:gsub("%%", ""))
	end
	-- a Classic reference alone never becomes a proven answer
	reset()
	check(Ev.GetProficiency("SHAMAN", 4, 3, 40).state == "UNKNOWN", "a Shaman at 40 is UNKNOWN: the Classic rule is not evidence")
end

section("evidence: natural observation points (reward dialog, worn items); repeated reads and reports do not inflate or change the evidence")
do
	reset()
	ns.Context.DefaultReader.character = function() return { level = 39, classToken = "SHAMAN", raceToken = "ORC", faction = "Horde" } end
	local DB = {
		[7001] = { name = "Mail Chest A", equipLoc = "INVTYPE_CHEST", classID = 4, sub = 3, req = 5 },
		[7002] = { name = "Mail Legs B", equipLoc = "INVTYPE_LEGS", classID = 4, sub = 3, req = 5 },
		[7003] = { name = "Mail Boots C", equipLoc = "INVTYPE_FEET", classID = 4, sub = 3, req = 5 },
		[7010] = { name = "Leather Vest", equipLoc = "INVTYPE_CHEST", classID = 4, sub = 2, req = 1 },
		[7011] = { name = "Shirt", equipLoc = "INVTYPE_BODY", classID = 4, sub = 0, req = 0 },
	}
	local function idOf(ref) return type(ref) == "number" and ref or tonumber(ref:match("item:(%d+)")) end
	local function lk(id) return "|Hitem:" .. id .. "::|h[" .. DB[id].name .. "]|h" end
	local worn = { [5] = 7010, [4] = 7011 }
	_G.GetQuestID = function() return 77 end
	_G.GetNumQuestChoices = function() return 3 end
	_G.GetNumQuestRewards = function() return 0 end
	_G.GetQuestItemInfo = function(kind, i) return DB[7000 + i].name, 1, 1, 1, false, 7000 + i end
	_G.GetQuestItemLink = function(kind, i) return lk(7000 + i) end
	_G.GetItemInfo = function(ref) local id = idOf(ref); local d = DB[id]; if not d then return nil end return d.name, lk(id), 1, 10, d.req, "Armor", "x", 1, d.equipLoc, 1, 5, d.classID, d.sub end
	_G.GetItemStats = function() return { RESISTANCE0_NAME = 10 } end
	_G.IsUsableItem = function() return false, false end
	_G.GetItemSpell = function() return nil end
	_G.GetItemCount = function() return 1 end
	_G.GetInventoryItemLink = function(u, slot) local id = worn[slot]; if id then return lk(id) end end
	ns.ItemProbe.OnEvent("QUEST_COMPLETE")
	local g = Ev.Group("SHAMAN", 4, 3)
	check(g.counts.no == 3 and g.counts.yes == 0 and g.evidenceState == "PROVEN" and g.noAt == 39, "a reward dialog of three mail items the client flags unusable records three NO observations and proves 'not usable at 39' (3 distinct items)")
	local leather = Ev.Group("SHAMAN", 4, 2)
	check(leather.counts.observations == 0, "(worn items are recorded when equipment changes or a report is made, not by the dialog)")
	ns.ItemProbe.OnEvent("PLAYER_EQUIPMENT_CHANGED", 5, true)
	leather = Ev.Group("SHAMAN", 4, 2)
	check(leather.counts.yes == 1 and leather.yesAt == 39 and leather.evidenceState == "PROVEN", "wearing a leather vest records one worn-item observation: usable at 39 (PROVEN by the policy)")
	check(Ev.Group("SHAMAN", 4, 0).counts.observations == 0, "a worn shirt (subclass 0, a cosmetic slot) is not evidence")
	local before = #Ev.Observations()
	ns.ItemProbe.OnEvent("QUEST_COMPLETE"); ns.ItemProbe.OnEvent("QUEST_COMPLETE"); ns.ItemProbe.OnEvent("PLAYER_EQUIPMENT_CHANGED", 5, true)
	check(#Ev.Observations() == before and Ev.Status().repeats > 0, "the same dialog and the same worn item seen again add no records (repeat counts only)")
	local t1 = table.concat(Ev.ReportLines(), "\n")
	local t2 = table.concat(Ev.ReportLines(), "\n")
	check(t1 == t2 and Ev.GetProficiency("SHAMAN", 4, 3, 39).state == "PROVEN_NO", "reading the report twice changes nothing, and the answer is unchanged")
	-- a character whose class cannot be read records nothing
	ns.Context.DefaultReader.character = function() return { level = 39 } end
	local n0 = #Ev.Observations()
	ns.ItemProbe.OnEvent("QUEST_COMPLETE")
	check(#Ev.Observations() == n0 and Ev.Status().skipped["character class not known"] >= 3, "with no readable class nothing is recorded and the skips are counted")
	-- evidence survives a reload of the saved variable
	local saved = ForeverCodexDB
	local ns2 = boot({ char = { level = 39 } })
	ForeverCodexDB = saved
	check(ns2.EligibilityEvidence.GetProficiency("SHAMAN", 4, 3, 39).state == "PROVEN_NO", "stored observations survive a reload and still answer")
	check(ns2.EligibilityEvidence.Record(raw({ level = 39, id = 7001, usable = false, build = select(2, GetBuildInfo()) })) == "duplicate", "and the duplicate index is rebuilt: an old observation is still recognised")
	for _, n in ipairs({ "GetQuestID", "GetNumQuestChoices", "GetNumQuestRewards", "GetQuestItemInfo", "GetQuestItemLink", "GetItemInfo", "GetItemStats", "IsUsableItem", "GetItemSpell", "GetItemCount", "GetInventoryItemLink" }) do _G[n] = nil end
end

section("evidence: diagnostics are compact and honest; planner and advisor behaviour are unchanged")
do
	reset()
	rec({ level = 39, id = 1, usable = false }); rec({ level = 39, id = 2, usable = false }); rec({ level = 39, id = 3, usable = false })
	rec({ level = 40, id = 9, usable = true }); rec({ level = 40, id = 9, usable = false })
	local lines = Ev.ReportLines({ "  extra line" })
	local text = table.concat(lines, "\n")
	check(#lines <= 12, "the section is compact  [" .. #lines .. " lines]")
	check(text:find("recording: active | observations", 1, true) and text:find("proven answers", 1, true) and text:find("conflicts", 1, true), "it says whether recording is active and the counts of observations, proven answers and conflicts")
	check(text:find("policy v1: YES needs 1 worn item or 2 client-flagged items", 1, true), "it states the evidence policy")
	check(text:find("IsUsableItem", 1, true) and text:find("skill lines", 1, true) and text:find("not probed: IsSpellKnown", 1, true), "it lists the client signals relied on, the one that is absent, and the one not probed")
	check(text:find("CONFLICT", 1, true), "a conflicting group is shown as CONFLICT")
	check(not text:find("item 3 req", 1, true), "individual observations are not dumped into the report")
	check(Ev.Dump(2)[1]:find("item 9", 1, true), "they are available through the detailed dump")
	local full
	local nsr = boot({ char = { level = 39 } })
	rawset(nsr.UI, "ShowReport", function(t) full = t end)
	H.slash("report")
	check(full and full:find("ELIGIBILITY EVIDENCE", 1, true) and full:find("detail: /dump ForeverCodexDB.items.evidence", 1, true), "/codex report contains the section and says where the detail lives")
	local function code(f) return (H.readFile(H.addonDir .. "/" .. f):gsub("%-%-[^\n]*", "")) end
	for _, f in ipairs({ "Planner.lua", "Engine.lua", "Strategies.lua", "Presenter.lua", "Overlap.lua", "PlanAdapter.lua", "Providers/Quest.lua", "State.lua", "RewardAdvisor.lua", "Gear.lua" }) do
		check(not code(f):find("EligibilityEvidence"), f .. " does not reference the evidence recorder")
	end
	check(A.Recommend({ items = {} }).state == "NO_OPINION", "the recommendation layer still gives no opinion")
	-- 0.5.0 behaviour is intact: registered proven evidence still drives SOON
	reset()
	E.AddEvidence({ class = "SHAMAN", itemClass = 4, subClass = 3, minLevel = 40, proven = true, src = "registered test evidence" })
	local e = E.Evaluate(facts({ id = 400, usable = false, flag = false, req = 35 }), { level = 39, classToken = "SHAMAN" }, { equipped = equipped({}) })
	check(e.current.state == "PROVEN_NO" and e.future.state == "SOON" and e.future.unlockLevel == 40, "registered proven evidence still gives PROVEN_NO now and SOON")
	E.ClearEvidence(); reset()
end
