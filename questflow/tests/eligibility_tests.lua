-- eligibility_tests.lua: the Eligibility layer (Eligibility.lua) and its use by the Reward Advisor. "You cannot use this" versus "you cannot use this YET".
-- Synthetic ItemFacts and characters; no real items and no real class rules are assumed. Standard Classic proficiency rules appear only as an unproven
-- REFERENCE; every test that needs a proficiency threshold registers proven evidence explicitly, which is exactly what Forever evidence would do.

local H = ...
local check, section, boot = H.check, H.section, H.boot

local ns = boot({ char = { level = 39 } })
local E, A, G, I = ns.Eligibility, ns.Advisor, ns.Gear, ns.Items

local function facts(o)
	local f = { name = o.name, link = "|Hitem:" .. (o.id or 1) .. "::|h[" .. o.name .. "]|h", quality = 2, level = o.ilvl or 36, minLevel = o.req or 0, type = o.type or "Armor",
		subType = o.subType or "Mail", equipLoc = o.slot or "INVTYPE_CHEST", sellPrice = o.sell or 90, classID = o.classID or 4, subClassID = o.sub or 3, stats = o.stats or {},
		usable = o.usable, usableSecond = o.second }
	local r = { id = o.id or 1, ref = o.id or 1, f = f, src = {}, err = {}, spellRead = true }
	if o.usable == nil then r.err.usable = "api absent" end
	if o.waiting then r = { id = o.id or 1, ref = o.id or 1, f = {}, src = {}, err = { info = "blank/nil (not loaded yet)" }, unloaded = true } end
	local n = I.Normalize(r)
	if o.flag ~= nil then n.offered = { source = "reward_dialog", kind = "choice", index = 1, quest = 1, dialogFlag = o.flag } end
	if o.requirements then n.requirements = o.requirements end
	return n
end

local function equipped(items)
	local eq = { state = "OK", slots = {}, list = {} }
	for n = 1, I.EQUIP_SLOTS do
		local e = { slot = n, slotName = G.SLOT_NAMES[n], state = "EMPTY" }
		if items and items[n] then e.state, e.itemFacts, e.itemId = "POPULATED", items[n], items[n].id end
		eq.slots[n], eq.list[n] = e, e
	end
	return eq
end

local function has(c, id) for _, x in ipairs(c.categories) do if x.id == id then return x end end end

-- the worn items of a Shaman who has leather and cloth but no mail yet
local function wornNoMail() return equipped({ [5] = facts({ id = 900, name = "Leather Vest", slot = "INVTYPE_CHEST", subType = "Leather", sub = 2, stats = { RESISTANCE0_NAME = 30 } }) }) end

local SHAMAN = function(level) return { level = level, classToken = "SHAMAN", raceToken = "ORC", faction = "Horde" } end
local function reset() E.ClearEvidence(); A.ClearRegistries(); E.SOON_LEVELS = 2 end
local function mailProven() E.AddEvidence({ class = "SHAMAN", itemClass = 4, subClass = 3, minLevel = 40, proven = true, src = "observed on Forever (test evidence)" }) end

-- a good mail chest, offered as a reward: the client says not usable (both sources false)
local function goodMail(o)
	o = o or {}
	local usable, flag = false, false
	if o.usable ~= nil then usable = o.usable end
	if o.flag ~= nil then flag = o.flag end
	if o.noFlag then flag = nil end
	return facts({ id = 1000, name = "Fine Mail Chest", slot = "INVTYPE_CHEST", stats = o.stats or { RESISTANCE0_NAME = 120, ITEM_MOD_STAMINA_SHORT = 9 }, req = o.req or 35, usable = usable, second = false, flag = flag })
end

section("eligibility: level 39 Shaman + a mail item: not usable NOW (proven), usable SOON (the threshold is proven evidence)")
do
	reset(); mailProven()
	local e = E.Evaluate(goodMail(), SHAMAN(39), { equipped = wornNoMail() })
	check(e.current.state == "PROVEN_NO", "current: PROVEN_NO  [" .. e.current.state .. "]")
	check(e.future.state == "SOON" and e.future.unlockLevel == 40 and e.future.levelsAway == 1, "future: SOON, unlocks at level 40, 1 level away  [" .. e.future.state .. "]")
	check(e.checks.proficiency.state == "NO" and e.checks.proficiency.proven == true and e.checks.proficiency.src:find("observed on Forever", 1, true), "the proficiency check is a proven NO with its source")
	check(e.checks.level.state == "YES", "the item's required level (35) is met: that is not what blocks it")
	check(E.Describe(e):find("now PROVEN_NO | future SOON (level 40, 1 level(s) away)", 1, true), "current and future are separately readable in one line")
	local c = A.Classify(goodMail(), wornNoMail(), { character = SHAMAN(39) })
	check(c.primary == "FUTURE_UPGRADE" and not has(c, "NOT_USABLE") and not has(c, "UPGRADE"), "the advisor calls it a FUTURE UPGRADE, not an upgrade and not simply NOT USABLE  [" .. tostring(c.primary) .. "]")
	local r = has(c, "FUTURE_UPGRADE").reason
	check(r:find("You can't use this yet", 1, true) and r:find("level 40", 1, true) and r:find("+90 armor", 1, true) and r:find("(1 level(s) away)", 1, true), "the reason says it is not usable yet, when it unlocks, and what it would be  [" .. r .. "]")
	check(c.eligibility.current.state == "PROVEN_NO" and c.eligibility.future.state == "SOON", "the eligibility result is attached to the classification, both answers separate")
end

section("eligibility: level 40 Shaman + mail: usable now when the evidence supports it")
do
	reset(); mailProven()
	local item = goodMail({ usable = true, flag = true })
	local e = E.Evaluate(item, SHAMAN(40), { equipped = wornNoMail() })
	check(e.current.state == "PROVEN_YES" and e.future.state == "NOT_RELEVANT" and e.future.reason == "already usable now", "level 40 with the proven threshold and usable client answers: PROVEN_YES, future NOT_RELEVANT")
	-- without any client answer the proven threshold plus the met level requirement is enough
	local bare = goodMail({ usable = false, flag = false })
	bare.fields.usable = { state = "UNPROVEN", reason = "not read" }; bare.offered = nil
	local e2 = E.Evaluate(bare, SHAMAN(40), { equipped = wornNoMail() })
	check(e2.current.state == "PROVEN_YES" and e2.checks.client.state == "UNKNOWN", "proven proficiency + met level are enough even with no client answer")
	-- once usable, it is a normal upgrade
	local c = A.Classify(item, wornNoMail(), { character = SHAMAN(40) })
	check(c.primary == "UPGRADE" and not has(c, "FUTURE_UPGRADE"), "and it is classified as a normal UPGRADE (not a future one)")
	-- wearing mail already is evidence too
	local withMail = equipped({ [5] = facts({ id = 901, name = "Worn Mail Chest", slot = "INVTYPE_CHEST", stats = { RESISTANCE0_NAME = 60 } }) })
	reset()
	local e3 = E.Evaluate(bare, SHAMAN(40), { equipped = withMail })
	check(e3.current.state == "PROVEN_YES" and e3.checks.proficiency.src == "worn item of the same type", "mail already worn is proof the character can use mail (no registered evidence needed)")
end

section("eligibility: level 30 Shaman + mail is LATER, not a near-future opportunity")
do
	reset(); mailProven()
	local e = E.Evaluate(goodMail({ req = 20 }), SHAMAN(30), { equipped = wornNoMail() })
	check(e.current.state == "PROVEN_NO" and e.future.state == "LATER" and e.future.levelsAway == 10, "10 levels away: LATER")
	local c = A.Classify(goodMail({ req = 20 }), wornNoMail(), { character = SHAMAN(30) })
	check(c.primary == "NOT_USABLE" and not has(c, "FUTURE_UPGRADE") and has(c, "NOT_USABLE").reason:find("Not usable yet", 1, true) and has(c, "NOT_USABLE").reason:find("level 40 (10 level(s) away)", 1, true), "it is NOT USABLE (yet), with when  [" .. has(c, "NOT_USABLE").reason .. "]")
	E.SOON_LEVELS = 10
	check(E.Evaluate(goodMail({ req = 20 }), SHAMAN(30), { equipped = wornNoMail() }).future.state == "SOON", "what counts as soon is one tunable number")
	reset()
end

section("eligibility: a poor mail item at level 39 does not become a 'take this', and a future unlock is not a reason by itself")
do
	reset(); mailProven()
	local poor = goodMail({ stats = { RESISTANCE0_NAME = 20 } })       -- worse than the worn leather vest (30)
	local c = A.Classify(poor, wornNoMail(), { character = SHAMAN(39) })
	check(c.eligibility.future.state == "SOON", "(it does unlock soon)")
	check(not has(c, "FUTURE_UPGRADE") and c.primary == "NOT_USABLE", "but compared with what is worn it is not an improvement, so it is NOT a future upgrade  [" .. c.primary .. "]")
	check(c.caveats[#c.caveats]:find("becomes usable soon, but compared with what is worn it is not an improvement", 1, true), "the caveat says so")
	local slight = goodMail({ stats = { RESISTANCE0_NAME = 32 } })    -- +2 over 30: a slight improvement
	local s = A.Classify(slight, wornNoMail(), { character = SHAMAN(39) })
	check(s.primary == "FUTURE_UPGRADE" and has(s, "FUTURE_UPGRADE").reason:find("a slight improvement", 1, true), "a small gain is described as slight, not as a big future upgrade  [" .. has(s, "FUTURE_UPGRADE").reason .. "]")
	-- whatever the category, a future unlock is never a confident recommendation and no category is an instruction
	local ev = { items = { { index = 1, kind = "choice", classification = c }, { index = 2, kind = "choice", classification = s } } }
	local rec = A.Recommend(ev)
	check(rec.state == "TENTATIVE" and rec.basis == "FUTURE_ONLY" and rec.selected.index == 2 and rec.items[1].stance == "INFERIOR" and rec.items[2].stance == "PREFERRED" and #rec.caveats > 0,
		"the recommendation layer: a future unlock is at most a TENTATIVE pick with a caveat, never a confident one, and the poor item is INFERIOR")
	for _, x in ipairs(s.categories) do check(not x.reason:lower():find("take this") and not x.reason:lower():find("you should"), "no instruction wording in [" .. x.id .. "]") end
	check(s.recommendation == nil and s.eligibility.future.state == "SOON", "the classification carries no recommendation")
end

section("eligibility: unknown Forever proficiency stays UNKNOWN; the Classic rule is only a hint")
do
	reset()
	-- no client evidence at all
	local item = goodMail({ usable = true, noFlag = true })
	item.offered = nil
	local e = E.Evaluate(item, SHAMAN(39), { equipped = wornNoMail() })
	check(e.current.state == "UNKNOWN" and e.future.state == "UNKNOWN", "no evidence: current UNKNOWN, future UNKNOWN (the Classic rule is not assumed)")
	check(e.checks.proficiency.state == "UNKNOWN" and e.checks.proficiency.referenceHint.minLevel == 40 and e.checks.proficiency.referenceHint.src:find("not proven on Forever", 1, true), "the Classic reference is shown as a hint, labelled not proven on Forever")
	check(e.future.referenceHint ~= nil and E.Describe(e):find("Classic reference only: level 40 (not proven on Forever)", 1, true), "and it appears in the diagnostics line")
	-- the client says no, but nothing identifies why
	local clientNo = goodMail({ req = 0 })
	local e2 = E.Evaluate(clientNo, SHAMAN(39), { equipped = wornNoMail() })
	check(e2.current.state == "PROVEN_NO" and e2.current.blockers[1].check == "client" and e2.current.blockers[1].unlock == nil, "the client's own answers say no: PROVEN_NO now, blocker 'client' with no known unlock")
	check(e2.future.state == "UNKNOWN" and e2.future.reason:find("nothing identifies what would change that", 1, true), "but the future is UNKNOWN: the Classic hint is not used to invent an unlock level")
	local c = A.Classify(clientNo, wornNoMail(), { character = SHAMAN(39) })
	check(c.primary == "NOT_USABLE" and not has(c, "FUTURE_UPGRADE") and has(c, "NOT_USABLE").reason:find("Whether that changes is unknown", 1, true), "it is NOT USABLE with the future marked unknown, never a future upgrade")
	-- a class Codex has no reference for at all
	local odd = E.Evaluate(goodMail(), { level = 39, classToken = "WINDSHAPER" }, { equipped = wornNoMail() })
	check(odd.checks.proficiency.state == "UNKNOWN" and odd.checks.proficiency.referenceHint == nil, "a class with no reference and no evidence is simply UNKNOWN")
	local noClass = E.Evaluate(goodMail(), { level = 39 }, { equipped = wornNoMail() })
	check(noClass.checks.proficiency.state == "UNKNOWN" and noClass.checks.proficiency.detail:find("class is not known", 1, true), "an unknown character class is UNKNOWN")
end

section("eligibility: an explicit class restriction is a permanent PROVEN_NO and overrides a positive stat comparison")
do
	reset()
	local item = goodMail({ usable = true, flag = true })
	item.requirements = { classes = { "MAGE", "WARLOCK" }, src = "item tooltip (test)" }
	local e = E.Evaluate(item, SHAMAN(40), { equipped = wornNoMail() })
	check(e.current.state == "PROVEN_NO" and e.checks.class.state == "NO" and e.checks.class.permanent == true, "restricted to mage and warlock, the character is a shaman: PROVEN_NO, permanent")
	check(e.future.state == "NOT_RELEVANT" and e.future.reason:find("never usable", 1, true), "the future is NOT_RELEVANT: it never unlocks")
	check(e.current.conflicts[1]:find("say usable", 1, true), "the client's contradicting 'usable' answers are recorded, they do not override the proven restriction")
	local c = A.Classify(item, wornNoMail(), { character = SHAMAN(40) })
	check(c.primary == "NOT_USABLE" and not has(c, "UPGRADE") and not has(c, "FUTURE_UPGRADE") and has(c, "NOT_USABLE").reason:find("that does not change", 1, true), "+90 armor does not make it an upgrade  [" .. has(c, "NOT_USABLE").reason .. "]")
	-- allowed class: no block
	item.requirements = { classes = { "SHAMAN" }, src = "item tooltip (test)" }
	check(E.Evaluate(item, SHAMAN(40), { equipped = wornNoMail() }).checks.class.state == "YES", "an allowed class passes the restriction")
	-- race and faction
	item.requirements = { races = { "HUMAN" }, faction = "Alliance", src = "item tooltip (test)" }
	local e2 = E.Evaluate(item, SHAMAN(40), { equipped = wornNoMail() })
	check(e2.checks.race.state == "NO" and e2.checks.faction.state == "NO" and e2.current.state == "PROVEN_NO", "race and faction restrictions are checked the same way")
	-- no requirement data is NOT_READ, not 'no restriction'
	local plain = E.Evaluate(goodMail({ usable = true, flag = true }), SHAMAN(40), { equipped = wornNoMail() })
	check(plain.checks.class.state == "NOT_READ" and plain.caveats[1]:find("were not read", 1, true), "when no restriction data exists the check is NOT_READ and a caveat says so")
end

section("eligibility: strong stats with unknown eligibility are not called an upgrade")
do
	reset()
	local item = goodMail({ usable = true, noFlag = true })
	item.offered = nil
	local c = A.Classify(item, wornNoMail(), { character = SHAMAN(39) })
	check(c.eligibility.current.state == "UNKNOWN" and c.primary == "UNKNOWN" and not has(c, "UPGRADE") and not has(c, "FUTURE_UPGRADE"), "strong stats + UNKNOWN eligibility: UNKNOWN, not UPGRADE")
	check(has(c, "UNKNOWN").reason:find("not established", 1, true) and has(c, "UNKNOWN").reason:find("would be +90 armor", 1, true), "the reason keeps the facts: what it would be if usable  [" .. has(c, "UNKNOWN").reason .. "]")
	-- conflicting client answers are UNKNOWN too
	local conflict = goodMail({ usable = false, flag = true, req = 0 })
	local c2 = A.Classify(conflict, wornNoMail(), { character = SHAMAN(39) })
	check(c2.eligibility.current.state == "UNKNOWN" and c2.primary == "UNKNOWN", "conflicting client answers keep eligibility UNKNOWN")
end

section("eligibility: future eligibility works independently of the current slot comparison (an empty slot)")
do
	reset(); mailProven()
	local emptyEq = equipped({})
	local item = goodMail()
	local e = E.Evaluate(item, SHAMAN(39), { equipped = emptyEq })
	local c = A.Classify(item, emptyEq, { character = SHAMAN(39) })
	check(c.eligibility.current.state == "PROVEN_NO" and c.eligibility.future.state == "SOON", "an empty equipment slot does not change eligibility: PROVEN_NO now, SOON")
	check(c.primary == "FUTURE_UPGRADE" and has(c, "FUTURE_UPGRADE").reason:find("would fill your empty CHEST slot", 1, true), "it is a future upgrade because it will fill the empty chest slot  [" .. has(c, "FUTURE_UPGRADE").reason .. "]")
	-- the eligibility itself never reads the slot comparison
	local plain = E.Evaluate(item, SHAMAN(39), nil)
	check(plain.current.state == "PROVEN_NO" and plain.future.state == "SOON", "eligibility needs no equipment at all when the evidence is registered")
end

section("eligibility: one met requirement does not make the item usable while another is unknown or failed")
do
	reset()
	-- the level requirement is the only known blocker; proficiency is unknown (no evidence, nothing worn of that type)
	local item = goodMail({ req = 40, usable = true, noFlag = true })
	item.offered = nil
	local e = E.Evaluate(item, SHAMAN(39), { equipped = equipped({}) })
	check(e.checks.level.state == "NO" and e.checks.proficiency.state == "UNKNOWN", "level 40 required (a proven NO); proficiency UNKNOWN")
	check(e.current.state == "PROVEN_NO" and e.future.state == "UNKNOWN" and e.future.reason:find("another is not", 1, true) and e.future.unlockLevel == 40, "the future is UNKNOWN: reaching level 40 is not assumed to make it usable  [" .. e.future.reason .. "]")
	-- level fine, proficiency proven unlocking later
	reset(); mailProven()
	local e2 = E.Evaluate(goodMail({ req = 10, usable = true, noFlag = true }), SHAMAN(39), { equipped = equipped({}) })
	check(e2.checks.level.state == "YES" and e2.checks.proficiency.state == "NO" and e2.current.state == "PROVEN_NO", "a met level requirement does not make it usable while proficiency is a proven NO")
	-- both requirements block with different unlock levels: the later one decides
	local e3 = E.Evaluate(goodMail({ req = 41, usable = true, noFlag = true }), SHAMAN(39), { equipped = equipped({}) })
	check(e3.future.unlockLevel == 41 and e3.future.levelsAway == 2 and e3.future.state == "SOON" and #e3.future.basis == 2, "with two blockers the item unlocks at the later level (41), with both recorded as the basis")
	-- an item that has not loaded: nothing is concluded
	local w = E.Evaluate(facts({ id = 5, name = "Loading", waiting = true }), SHAMAN(39), { equipped = equipped({}) })
	check(w.current.state == "UNKNOWN" and w.future.state == "UNKNOWN", "an item that has not loaded is UNKNOWN now and later")
	-- level fact missing
	local noLvl = E.Evaluate(goodMail({ usable = true, noFlag = true }), { classToken = "SHAMAN" }, { equipped = equipped({}) })
	check(noLvl.checks.level.state == "UNKNOWN" and noLvl.current.state == "UNKNOWN", "an unknown character level is UNKNOWN, not zero")
end

section("eligibility: current and future are independently inspectable, and the layer stands alone")
do
	reset(); mailProven()
	local c = A.Classify(goodMail(), wornNoMail(), { character = SHAMAN(39), context = nil })
	local ev = { live = true, available = true, q = 1, at = "QUEST_COMPLETE", source = "the reward dialog that is open now", items = { { index = 1, kind = "choice", classification = c } }, recommendation = A.Recommend({ items = {} }) }
	local text = table.concat(A.ReportLines({ dialog = { live = true, q = 1, at = "QUEST_COMPLETE", choices = { { index = 1, kind = "choice", id = 1000, name = "Fine Mail Chest", facts = goodMail() } }, rewards = {} }, equipped = wornNoMail(), character = SHAMAN(39) }), "\n")
	check(text:find("[FUTURE UPGRADE]", 1, true) and text:find("eligibility: now PROVEN_NO | future SOON (level 40, 1 level(s) away)", 1, true), "the report shows the category and both eligibility answers on their own line")
	check(text:find("RECOMMENDATION: NOT_A_CHOICE", 1, true), "and the recommendation separately (one choice: nothing to choose between)")
	local ee, rr = E.Evidence()
	check(#rr == 4 and rr[1].proven == false and rr[1].src:find("not proven on Forever", 1, true), "the built-in Classic rules are a four-entry reference, all marked not proven")
	check(#ee == 1 and ee[1].proven == true, "only the registered evidence is proven")
	local function code(f) return (H.readFile(H.addonDir .. "/" .. f):gsub("%-%-[^\n]*", "")) end
	local src = code("Eligibility.lua")
	for _, pat in ipairs({ "ns%.Advisor", "ns%.Planner", "ns%.Engine", "ns%.Strategies", "ns%.State", "ns%.UI", "ns%.Presenter", "ns%.Registry", "ns%.Gear", "ns%.Overlap" }) do
		check(not src:find(pat), "Eligibility.lua does not depend on " .. pat:gsub("%%", ""))
	end
	for _, word in ipairs({ "take this", "recommend", "upgrade", "best ", "you should", "weight" }) do
		check(not src:lower():find(word, 1, true), "Eligibility.lua does not contain '" .. word .. "'")
	end
	check(not src:find('SHAMAN%s*=%s*"') and not src:find("%[\"SHAMAN\"%]"), "Eligibility.lua has no class-to-armor table (the Classic reference is four labelled reference records)")
	reset()
end
