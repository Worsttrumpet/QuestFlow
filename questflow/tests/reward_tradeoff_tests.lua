-- reward_tradeoff_tests.lua (0.9.6): the reward overlay. The Advisor decides, the overlay (UI/RewardOverlay.lua) only DISPLAYS Advisor.Display(): tags, short stat text, RECOMMENDED / NO CLEAR PICK,
-- drawn on the game's own reward choice buttons (stub buttons here; the real frame's structure is not proven on Forever). Fake item data and fake dialogs: the clear-recommendation
-- rendering is FIXTURE-tested, not real-client-tested (the real Q5730 gives NO CLEAR PICK).

local H = ...
local check, section, boot = H.check, H.section, H.boot
local ns = boot({ char = { level = 15, class = "Rogue", classToken = "ROGUE" }, synthetic = true })
local A, RO, I, G = ns.Advisor, ns.RewardOverlay, ns.Items, ns.Gear

local function facts(o)
	local f = { name = o.name, link = "|Hitem:" .. (o.id or 1) .. "::|h[" .. o.name .. "]|h", quality = 1, level = 18, minLevel = 0, type = "Weapon", subType = "Daggers",
		equipLoc = o.slot or "INVTYPE_WEAPONMAINHAND", sellPrice = o.sell or 1291, classID = 2, subClassID = o.sub or 15, stats = o.stats or {}, usable = o.usable, usableSecond = o.second }
	local r = { id = o.id or 1, ref = o.id or 1, f = f, src = {}, err = {}, spellRead = true }
	if o.usable == nil then r.err.usable = "api absent" end
	local n = I.Normalize(r)
	if o.flag ~= nil then n.offered = { source = "reward_dialog", kind = "choice", index = 1, quest = 1, dialogFlag = o.flag } end
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
local DPS, AGI, STR, SPI, STA = "ITEM_MOD_DAMAGE_PER_SECOND_SHORT", "ITEM_MOD_AGILITY_SHORT", "ITEM_MOD_STRENGTH_SHORT", "ITEM_MOD_SPIRIT_SHORT", "ITEM_MOD_STAMINA_SHORT"
local U = { usable = true, second = true, flag = true }       -- the client's two usability answers agree: usable
local N = { usable = false, second = false, flag = false }     -- both say not usable
local CF = { usable = false, second = false, flag = true }     -- they disagree (the real Kris / Hammer)
local function w(id, name, stats, flags, extra)
	local o = { id = id, name = name, stats = stats }
	for k, v in pairs(flags) do o[k] = v end
	for k, v in pairs(extra or {}) do o[k] = v end
	return facts(o)
end
-- the real Q5730 character: Defias Rapier in the main hand AND Quickblade's Dagger in the off hand (an empty off hand would make Kris "fill an empty slot")
local EQ = equipped({ [16] = facts({ id = 900, name = "Defias Rapier", stats = { [DPS] = 8.125, [AGI] = 2 } }),
	[17] = facts({ id = 901, name = "Quickblade's Dagger", slot = "INVTYPE_WEAPON", stats = { [DPS] = 6.76, [AGI] = 1 } }) })
local ROGUE = { level = 15, classToken = "ROGUE" }


--- A fake LIVE reward dialog of CHOICES, as ItemProbe.DialogFacts would give it.
local function dialog(list, char)
	local ch = {}
	for i, f in ipairs(list) do ch[i] = { index = i, kind = "choice", id = f.id, name = f.fields.name.value, facts = f } end
	return { dialog = { live = true, q = 5730, at = "QUEST_COMPLETE", choices = ch, rewards = {} }, equipped = EQ, character = char or ROGUE }
end
local KRIS = function() return w(1, "Kris of Orgrimmar", { [DPS] = 8, [STA] = 4 }, CF, { slot = "INVTYPE_WEAPON" }) end
local HAMMER = function() return w(2, "Hammer of Orgrimmar", { [DPS] = 12.41, [STR] = 3, [SPI] = 3 }, CF, { subType = "Maces", sub = 4 }) end
local AXE = function() return w(3, "Axe of Orgrimmar", { [DPS] = 16.06, [SPI] = 6, [STA] = 6 }, N, { slot = "INVTYPE_2HWEAPON", sub = 1 }) end
local STAFF = function() return w(4, "Staff of Orgrimmar", { [DPS] = 11.8, [AGI] = 6 }, N, { slot = "INVTYPE_2HWEAPON", sub = 10 }) end
local function tags(it) return it.classification.outcome and it.classification.outcome.kind or "?" end

section("reward trade-offs: Q5730 as a Rogue: both viable choices stay MIXED, Hammer is the pick (tentative: usability is not established)")
do
	local ev = A.Evaluate(dialog({ KRIS(), HAMMER(), AXE(), STAFF() }))
	local r = ev.recommendation
	check(tags(ev.items[1]) == "mixed" and tags(ev.items[2]) == "mixed", "Kris and Hammer are both still classified MIXED  [" .. tags(ev.items[1]) .. " | " .. tags(ev.items[2]) .. "]")
	check(r.state == "TENTATIVE" and r.selected and r.selected.index == 2 and r.basis == "MIXED_DPS", "the Hammer is the pick, TENTATIVE because the client's usability answers conflict  [" .. tostring(r.state) .. " " .. tostring(r.selected and r.selected.index) .. " " .. tostring(r.basis) .. "]")
	local d0 = A.Display(dialog({ KRIS(), HAMMER(), AXE(), STAFF() }))
	check(d0.rows[1].tags[1] == "MIXED" and d0.rows[2].tags[1] == "MIXED", "and the display still tags them MIXED")
	check(d0.rows[3].tags[1] == "NOT USABLE" and d0.rows[3].tags[2] == "VENDOR" and d0.rows[4].tags[1] == "NOT USABLE" and d0.rows[4].tags[2] == "VENDOR", "Axe and Staff stay NOT USABLE + VENDOR")
	local joined = table.concat(r.reasons, " | ") .. " | " .. table.concat(r.caveats, " | ")
	check(joined:find("weapon damage", 1, true) and joined:find("Both stay MIXED", 1, true), "the reason names weapon damage and says both stay MIXED")
	check(joined:find("cannot confirm", 1, true), "and the usability doubt is a caveat, not hidden")
	local d = A.Display(dialog({ KRIS(), HAMMER(), AXE(), STAFF() }))
	check(d.verdict.kind == "tentative" and d.rows[2].recommended == "tentative" and d.rows[1].recommended == nil, "the display marks only the Hammer (tentative)  [" .. d.verdict.text .. "]")
end

section("reward trade-offs: the same case with usability agreed gives a plain RECOMMEND")
do
	local kris = w(1, "Kris of Orgrimmar", { [DPS] = 8, [STA] = 4 }, U, { slot = "INVTYPE_WEAPON" })
	local hammer = w(2, "Hammer of Orgrimmar", { [DPS] = 12.41, [STR] = 3 }, U, { subType = "Maces", sub = 4 })
	local r = A.Evaluate(dialog({ kris, hammer })).recommendation
	check(r.state == "RECOMMEND" and r.selected.index == 2, "usable both ways: RECOMMEND the Hammer  [" .. tostring(r.state) .. "]")
end

section("reward trade-offs: where the rule must NOT pick")
do
	-- another class: no weapon-damage rule
	local r = A.Evaluate(dialog({ KRIS(), HAMMER() }, { level = 15, classToken = "MAGE" })).recommendation
	check(r.state == "NO_CLEAR_RECOMMENDATION", "a class not listed keeps NO CLEAR PICK between mixed choices  [" .. tostring(r.state) .. "]")
	-- the other choice loses less: A would give up something B keeps
	local a = w(1, "A", { [DPS] = 12.41, [AGI] = 0, [STR] = 3 }, U, { slot = "INVTYPE_WEAPONMAINHAND" })
	local b = w(2, "B", { [DPS] = 8, [STA] = 4, [AGI] = 1 }, U, { slot = "INVTYPE_WEAPONMAINHAND" })
	r = A.Evaluate(dialog({ a, b })).recommendation
	check(r.state == "NO_CLEAR_RECOMMENDATION", "the faster weapon that loses more agility than the other: no pick  [" .. tostring(r.state) .. "]")
	-- a dps gain that is not clear (under 25% of the worn weapon)
	local c = w(1, "C", { [DPS] = 9.5, [STR] = 3 }, U)
	local e = w(2, "E", { [DPS] = 8, [STA] = 4 }, U, { slot = "INVTYPE_WEAPON" })
	r = A.Evaluate(dialog({ c, e })).recommendation
	check(r.state == "NO_CLEAR_RECOMMENDATION", "a 17% dps gain is not clear enough: no pick  [" .. tostring(r.state) .. "]")
	-- both gain dps: not separated by this rule
	local f = w(1, "F", { [DPS] = 12.4, [STR] = 3, [AGI] = 0 }, U)
	local g2 = w(2, "G", { [DPS] = 11, [STA] = 4 }, U, { slot = "INVTYPE_WEAPON" })
	r = A.Evaluate(dialog({ f, g2 })).recommendation
	check(r.state == "NO_CLEAR_RECOMMENDATION", "both raise weapon damage: no pick  [" .. tostring(r.state) .. "]")
	-- an unreadable third choice could be better: no pick
	local h = facts({ id = 7, name = "Unloaded Thing", slot = "INVTYPE_WEAPONMAINHAND" })
	h.fields.equipSlot = { state = "UNPROVEN", reason = "not loaded" }
	r = A.Evaluate(dialog({ KRIS(), HAMMER(), h })).recommendation
	check(r.state == "NO_CLEAR_RECOMMENDATION", "a choice that could not be read blocks the pick  [" .. tostring(r.state) .. "]")
end
