-- ForeverCodex.Advisor: Stage 3, the REWARD ADVISOR. It sits above the Stage 1 ItemFacts and the Stage 2 Gear reader and answers one question per reward item:
-- "what kind of value does this reward appear to have for this character, and on what evidence?"
--
-- The layers stay separate (each is a different function, none calls "up"):
--   ItemFacts           what the client tells us                                   Items.Facts / Items.Normalize        (Stage 1)
--   Eligibility         can the character use it now / will they soon             Eligibility.Evaluate                 (its own layer, 0.5.0)
--   Gear comparison     the factual difference between two items                  Gear.Compare / CompareToEquipped     (Stage 2)
--   Classification      what kind of value the reward appears to have, and why    Advisor.Classify                     (this file)
--   Recommendation      what Codex suggests doing                                  Advisor.Recommend                    (R1: conservative, deterministic, facts only)
--
-- NOT a Pawn clone: there are no stat weights and no scores. An item is judged only from known facts: it either improves some compared stats without lowering
-- any (improvement), lowers some and raises others (MIXED: Codex does not weigh stats against each other), or does not improve. The size of an improvement is
-- the largest relative gain over what is equipped (Advisor.THRESHOLDS: PROPOSED values, untuned, kept in one table).
--
-- Uncertainty is kept, never collapsed: UNKNOWN is not ABSENT, EMPTY is not zero, UNPROVEN is not false. A comparison that cannot be made is UNKNOWN, an item
-- that has not loaded is UNKNOWN, and conflicting usability evidence stays a conflict. Every category carries a reason that only states known facts.
--
-- A classification describes the ITEM. "Upgrade" is never a pick by itself. The recommendation is a separate step (below) that reads classifications only; later layers
-- (replacement horizon, route, future use) plug in through the context argument and the registries below.
-- Read-only and independent of the planner, strategies and presenter. Consumers: /codex report (Advisor.ReportLines) and the reward overlay (UI/RewardOverlay.lua, via Advisor.Display).

local addonName, ns = ...

local A = {}
ns.Advisor = A

local I = ns.Items

-- PROPOSED thresholds (they have not been tuned against real play; one place to change them):
--   slightRelative   an improvement whose largest relative gain is below this is a SLIGHT upgrade
--   relativeFloor    the smallest base a relative gain is measured against (so +1 over 0 is not "infinite")
--   temporaryQuests / temporaryMinutes   a known replacement at most this far away makes an upgrade TEMPORARY (needs context; never invented)
A.THRESHOLDS = { slightRelative = 0.25, relativeFloor = 5, temporaryQuests = 3, temporaryMinutes = 15, dpsNoise = 0.03 }

-- STATS A CLASS DOES NOT USE (PROPOSED, from how these classes' resources work in Classic; not read from the client, and not weights): a difference in such a stat is
-- not counted as a gain or a loss, and the reason says it was left out. Only the unambiguous cases are listed; every other class keeps the plain "every stat counts" comparison.
-- Warriors and Rogues have no mana and no spell power in this comparison: intellect and spirit do nothing for them.
-- weaponDamage = true: for this class a weapon's own damage is what the weapon is for (melee classes that fight with it), so a clear weapon-dps gain can separate two weapons
-- that are both MIXED (see mixedWinner in RecommendDefault). Only these two classes are listed; every other class keeps "no pick" between mixed choices.
A.IGNORED_STATS = {
	WARRIOR = { word = "Warrior", stats = { intellect = true, spirit = true }, weaponDamage = true },
	ROGUE   = { word = "Rogue",   stats = { intellect = true, spirit = true }, weaponDamage = true },
}

--- Category table (extensible): id -> { tag (plain ASCII text), family (a colour name for a later icon), order (presentation order only, not a ranking) }.
A.CATEGORIES = {
	NOT_USABLE        = { tag = "NOT USABLE",       family = "red",    order = 1 },
	UPGRADE           = { tag = "UPGRADE",          family = "green",  order = 2 },
	TEMPORARY_UPGRADE = { tag = "TEMPORARY",        family = "yellow", order = 3 },
	FUTURE_UPGRADE    = { tag = "FUTURE UPGRADE",   family = "yellow", order = 4 },
	SLIGHT_UPGRADE    = { tag = "SLIGHT UPGRADE",   family = "yellow", order = 5 },
	MIXED             = { tag = "MIXED",            family = "yellow", order = 6 },
	COMBAT_UTILITY    = { tag = "COMBAT UTILITY",   family = "blue",   order = 7 },
	FUTURE_USE        = { tag = "FUTURE USE",       family = "purple", order = 8 },
	VENDOR            = { tag = "VENDOR",           family = "gold",   order = 9 },
	UNKNOWN           = { tag = "UNKNOWN",          family = "grey",   order = 10 },
}

local STAT_ORDER = { "armor", "strength", "agility", "stamina", "intellect", "spirit", "weapon_dps" }
local STAT_LABEL = { armor = "armor", strength = "strength", agility = "agility", stamina = "stamina", intellect = "intellect", spirit = "spirit", weapon_dps = "weapon dps" }

-- ---------------------------------------------------------------- registries (the extension points; nothing is registered by default)

local futureProviders, utilityProviders = {}, {}
local recommender = nil

--- Registers a future-use source: fn(facts, context) -> nil, or { reason = "...", certainty = "PROVEN" | "PARTIAL", source = "..." }. Codex has none of its own yet:
-- it does not know profession, crafting or future-quest requirements and does not pretend to. A provider that errors is ignored.
function A.RegisterFutureUse(key, fn) futureProviders[key] = fn end

--- Registers a utility source: fn(facts, context) -> nil, or { reason, certainty, source }. Used for combat utility knowledge beyond "has a use effect".
function A.RegisterUtility(key, fn) utilityProviders[key] = fn end

--- Plugs in a recommender: fn(evaluation, opts) -> { state, reason, items }. The default gives no opinion.
function A.SetRecommender(fn) recommender = fn end

function A.ClearRegistries() futureProviders, utilityProviders, recommender = {}, {}, nil end

-- ---------------------------------------------------------------- helpers

local function nameOf(facts)
	local n = facts and facts.fields and facts.fields.name
	return (n and n.state == "PROVEN" and n.value) or "(unnamed item)"
end

local function num(v)
	if type(v) ~= "number" then return tostring(v) end
	if v == math.floor(v) then return tostring(v) end
	return string.format("%.1f", v)
end

local function signed(v) if type(v) == "number" and v > 0 then return "+" .. num(v) end return num(v) end

local function fieldWord(f) return f.state .. (f.reason and (" (" .. f.reason .. ")") or "") end

local function cat(id, certainty, reason, evidence)
	local def = A.CATEGORIES[id]
	return { id = id, tag = def.tag, family = def.family, certainty = certainty, reason = reason, evidence = evidence }
end

-- ---------------------------------------------------------------- usability evidence (lives in Eligibility; kept here as a delegate)

--- The client's usability answers side by side (see Eligibility.ClientUsability). Kept so existing callers keep working.
function A.Usability(facts) return ns.Eligibility.ClientUsability(facts) end

-- ---------------------------------------------------------------- the upgrade judgement (facts in, no weights)

--- Splits a Gear.Compare result into gains, losses and unknowns. Pure.
-- `rel` (optional) = A.IGNORED_STATS[class]: stats the class does not use are left out (listed in r.ignored); a weapon dps difference under A.THRESHOLDS.dpsNoise of
-- the equipped weapon's dps is noise, not a gain or a loss.
local function judge(cmp, rel)
	local r = { gains = {}, losses = {}, unknown = {}, compared = 0, ignored = {} }
	for _, stat in ipairs(STAT_ORDER) do
		local s = cmp.stats[stat]
		local skip = false
		if s.state == "COMPARED" and s.diff ~= 0 then
			if rel and rel.stats[stat] then
				skip = true
				r.ignored[#r.ignored + 1] = STAT_LABEL[stat]
			elseif stat == "weapon_dps" and (s.b or 0) > 0 and math.abs(s.diff) / s.b < A.THRESHOLDS.dpsNoise then
				skip = true                                  -- (a rounding-sized difference: not mentioned either)
			end
		end
		if skip then
			r.compared = r.compared + 1
		elseif s.state == "COMPARED" then
			r.compared = r.compared + 1
			local e = { stat = stat, a = s.a, b = s.b, diff = s.diff, assumedZero = s.assumedZero }
			if s.diff > 0 then
				local base = math.max(s.b or 0, A.THRESHOLDS.relativeFloor)
				e.relative = s.diff / base
				r.gains[#r.gains + 1] = e
			elseif s.diff < 0 then
				r.losses[#r.losses + 1] = e
			end
		elseif s.state == "UNKNOWN" then
			r.unknown[#r.unknown + 1] = { stat = stat, reason = s.reason }
		end
	end
	return r
end

local function statsText(list)
	local parts = {}
	for i, e in ipairs(list) do
		if i > 3 then parts[#parts + 1] = "..."; break end
		parts[#parts + 1] = signed(e.diff) .. " " .. STAT_LABEL[e.stat]
	end
	return table.concat(parts, ", ")
end

--- How good a reward is in ONE legal slot, as a rank (never a score): 3 = a clear gain with no loss, 2 = a slight gain with no loss, 1 = mixed (gains and losses), 0 = no gain,
-- -1 = nothing could be compared; nil = the slot could not be compared at all. Second value: the largest relative gain (to tell two gains apart). Same thresholds as the outcome.
local function entryRank(e, rel)
	if e.state ~= "COMPARED" then return nil end
	local j = judge(e.comparison, rel)
	if j.compared == 0 then return -1, 0 end
	local maxRel = 0
	for _, g in ipairs(j.gains) do maxRel = math.max(maxRel, g.relative) end
	if #j.gains > 0 and #j.losses == 0 then return (maxRel >= A.THRESHOLDS.slightRelative) and 3 or 2, maxRel end
	if #j.gains > 0 then return 1, maxRel end
	return 0, 0
end

--- Which equipped entry the reward is judged against. A reward is compared with the item in EACH slot it may legally occupy (Gear.SLOTS_FOR: a one-hand weapon may go in either
-- hand, a main-hand-only or off-hand-only one in just that hand); an EMPTY slot it fits comes first, otherwise the legal slot where it does best (a clear gain, then a slight gain,
-- then mixed, then no gain; the larger relative gain breaks a tie between two gains; otherwise the first slot). All entries are kept in the evidence. Returns the entry or nil.
local function chooseEntry(entries, rel)
	local best, bestRank, bestRel, firstOther
	for _, e in ipairs(entries) do
		if e.state == "EMPTY_SLOT" then return e end
		local rank, gain = entryRank(e, rel)
		if rank then
			if not best or rank > bestRank or (rank == bestRank and rank >= 2 and gain > bestRel) then best, bestRank, bestRel = e, rank, gain end
		else
			firstOther = firstOther or e
		end
	end
	return best or firstOther
end

-- ---------------------------------------------------------------- classification

-- the factual comparison of the item with what is worn, turned into an outcome the classification can use. Never judges usability.
--   { kind = "empty_slot" | "upgrade" | "slight" | "mixed" | "none" | "unknown" | "no_slot", text, evidence, note, partial }
local function compareOutcome(facts, equipped, rel)
	local fl = facts.fields
	local slotState = fl.equipSlot.state
	if slotState == "EMPTY" then return { kind = "no_slot", note = "the item has no equip slot" } end
	if slotState ~= "PROVEN" then return { kind = "unknown", note = "the item's equip slot is " .. fieldWord(fl.equipSlot) } end
	if not (ns.Gear and equipped) then return { kind = "unknown", note = "the equipped items were not read" } end
	local cmp = ns.Gear.CompareToEquipped(facts, equipped)
	if cmp.state ~= "COMPARABLE" then return { kind = "unknown", note = cmp.reason, comparison = cmp } end
	-- TWO-HANDERS change the whole setup. A two-handed reward takes the main hand AND puts the off hand out of use: with an off-hand item worn (or the off hand unread) Codex does not
	-- compare that setup. And an off-hand slot is not free while the main hand holds a two-handed weapon.
	local function item(slot) local s = equipped.slots and equipped.slots[slot]; return s end
	local function twoHanded(s) local f = s and s.state == "POPULATED" and s.itemFacts and s.itemFacts.fields and s.itemFacts.fields.equipSlot; return f and f.state == "PROVEN" and f.value == "INVTYPE_2HWEAPON" end
	if slotState == "PROVEN" and fl.equipSlot.value == "INVTYPE_2HWEAPON" then
		local oh = item(17)
		if not (oh and oh.state == "EMPTY") then
			local mh = item(16)
			local function nm(s) return (s and s.state == "POPULATED" and s.itemFacts) and nameOf(s.itemFacts) or "?" end
			return { kind = "unknown", comparison = cmp, chosen = 16, twoHand = true,
				note = (oh and oh.state == "POPULATED") and string.format("it is two-handed: it would replace your main hand (%s) and put your off hand (%s) out of use, and Quest Flow does not compare that setup", nm(mh), nm(oh))
					or "it is two-handed and the off hand could not be read, so what it would replace is not known" }
		end
	end
	if twoHanded(item(16)) then
		for _, e in ipairs(cmp.entries) do
			if e.slot == 17 then
				e.state, e.comparison, e.reason = "UNKNOWN", nil, "your main hand holds a two-handed weapon, so the off hand is not free"
			end
		end
	end
	local entry = chooseEntry(cmp.entries, rel)
	if entry and entry.state == "EMPTY_SLOT" then
		return { kind = "empty_slot", text = string.format("fills your empty %s slot", entry.slotName), evidence = { slot = entry.slot, kind = "empty_slot" }, comparison = cmp, chosen = entry.slot }
	end
	if not (entry and entry.state == "COMPARED") then
		return { kind = "unknown", note = entry and (entry.reason or "the equipped item could not be compared") or "no equipment slot to compare with", comparison = cmp, chosen = entry and entry.slot }
	end
	local j = judge(entry.comparison, rel)
	local cur = nameOf(entry.equipment.itemFacts)
	local ev = { slot = entry.slot, slotName = entry.slotName, against = cur, gains = j.gains, losses = j.losses, unknown = j.unknown, ignored = j.ignored }
	-- what was left out, said in the reason: the player should see WHY a stat did not count
	local left = (#j.ignored > 0 and rel) and string.format(" (not counted for a %s: %s)", rel.word, table.concat(j.ignored, ", ")) or ""
	local o = { evidence = ev, comparison = cmp, chosen = entry.slot, partial = #j.unknown > 0 and tostring(j.unknown[1].reason) or nil }
	if j.compared == 0 then
		o.kind, o.note = "unknown", "no stat could be compared" .. (j.unknown[1] and (": " .. tostring(j.unknown[1].reason)) or "")
	elseif #j.gains > 0 and #j.losses == 0 then
		local maxRel = 0
		for _, g in ipairs(j.gains) do maxRel = math.max(maxRel, g.relative) end
		ev.maxRelative = maxRel
		o.kind = (maxRel >= A.THRESHOLDS.slightRelative) and "upgrade" or "slight"
		o.text = string.format("%s over your current %s (%s)%s", statsText(j.gains), cur, entry.slotName, left)
	elseif #j.gains > 0 and #j.losses > 0 then
		o.kind = "mixed"
		o.text = string.format("%s, but %s versus your current %s; Quest Flow does not weigh different stats against each other%s", statsText(j.gains), statsText(j.losses), cur, left)
	else
		o.kind = "none"
		o.note = ((#j.losses > 0) and string.format("%s versus your current %s", statsText(j.losses), cur) or (#j.ignored > 0 and ("no improvement in the stats that count versus your current " .. cur) or ("no difference in the compared stats versus your current " .. cur))) .. left
	end
	return o
end

-- "would be +90 armor over ..." / "would fill your empty CHEST slot": what the item would be, for sentences about an item that is not (yet) usable
local function wouldText(o)
	if o.kind == "empty_slot" then return "would " .. (o.text:gsub("^fills", "fill")) end
	return "would be " .. o.text
end

-- the words for "why the character cannot use it now", from the eligibility result
local function blockedText(elig)
	local f = elig.future
	local b = elig.current.blockers[1]
	local base = b and b.detail or "the client reports it as not usable"
	if f.state == "NOT_RELEVANT" then return "Not usable by this character, and that does not change: " .. f.reason .. "."
	elseif f.state == "SOON" or f.state == "LATER" then return string.format("Not usable yet: %s. It becomes usable at level %d (%d level(s) away).", base, f.unlockLevel, f.levelsAway)
	end
	return "Not usable by this character right now: " .. base .. ". Whether that changes is unknown (" .. tostring(f.reason) .. ")."
end

--- Classifies one reward item. facts = normalized ItemFacts (Items.Facts / ItemProbe.DialogFacts), equipped = a Gear.Equipped() result (or nil),
-- opts = { character = { level, classToken, ... }, requirements = explicit restrictions, context = { replacement = {...} } }.
-- Returns a Classification (see docs/CODEX_REALCLIENT_FIXES.md section 45 and 46):
--   { schema, item = { id, name, state }, primary, categories = { { id, tag, family, certainty, reason, evidence } }, eligibility, usability, comparison, caveats,
--     futureUse, context }
-- `primary` is a presentation order only. It is not a recommendation. Upgrade-type categories need PROVEN current eligibility; a proven "not yet" that is
-- SOON becomes FUTURE_UPGRADE when the item would improve what is worn; everything uncertain stays UNKNOWN.
function A.Classify(facts, equipped, opts)
	opts = opts or {}
	local out = { schema = 1, item = { id = facts and facts.id, name = nameOf(facts), state = facts and facts.state }, categories = {}, caveats = {}, comparison = { state = "NOT_COMPARED" } }
	local function add(c) out.categories[#out.categories + 1] = c end
	if not (facts and facts.fields) then
		add(cat("UNKNOWN", "UNPROVEN", "No item facts were available."))
		out.primary = "UNKNOWN"
		return out
	end
	local fl = facts.fields
	local E = ns.Eligibility

	-- 1. the item itself must be known
	if facts.state ~= "LOADED" then
		local why = facts.state == "WAITING" and "the item's data has not loaded yet" or ("the item info could not be read (" .. tostring(fl.name and fl.name.reason) .. ")")
		add(cat("UNKNOWN", "UNPROVEN", "Not enough is known yet: " .. why .. ". Nothing is assumed about its value."))
		out.primary = "UNKNOWN"
		out.usability = E.ClientUsability(facts)
		out.futureUse = { state = "UNKNOWN", reason = "item not loaded" }
		return out
	end

	-- 2. eligibility: current and future, from the Eligibility layer (nothing here decides it)
	local elig = E.Evaluate(facts, opts.character, { equipped = equipped, requirements = opts.requirements })
	out.eligibility, out.usability = elig, elig.clientUsability
	local us = out.usability
	if us.verdict == "CONFLICT" then out.caveats[#out.caveats + 1] = "usability is unclear: " .. us.reason
	elseif us.verdict == "UNKNOWN" then out.caveats[#out.caveats + 1] = "usability is not established: " .. us.reason end
	for _, c in ipairs(elig.current.conflicts) do out.caveats[#out.caveats + 1] = c end
	local cur = elig.current.state
	local yes, no = cur == "PROVEN_YES", cur == "PROVEN_NO"
	local certainty = yes and "PROVEN" or "PARTIAL"

	-- 3. the factual comparison with what is worn (made whatever the eligibility is; what it MEANS depends on the eligibility)
	local rel = opts.character and opts.character.classToken and A.IGNORED_STATS[tostring(opts.character.classToken):upper()] or nil
	local o = compareOutcome(facts, equipped, rel)
	out.comparison = { state = o.comparison and o.comparison.state or (o.kind == "no_slot" and "NO_SLOT" or "UNKNOWN"), chosen = o.chosen, entries = o.comparison and o.comparison.entries, note = o.note }
	out.outcome = { kind = o.kind, chosen = o.chosen, evidence = o.evidence, note = o.note, partial = o.partial, weaponDamage = rel and rel.weaponDamage == true or nil }   -- the factual comparison result the recommender reads (no new judgement)
	if o.partial then certainty = "PARTIAL"; out.caveats[#out.caveats + 1] = "some stats could not be compared: " .. o.partial end
	local improves = o.kind == "upgrade" or o.kind == "slight" or o.kind == "empty_slot"
	local useful, comparisonUnknown = false, (o.kind == "unknown")

	if no then
		-- the character cannot use it now
		if elig.future.state == "SOON" and improves then
			local size = (o.kind == "slight") and ", a slight improvement" or ""
			local b = elig.current.blockers[1]
			add(cat("FUTURE_UPGRADE", "PARTIAL", string.format("You can't use this yet: %s. It becomes usable at level %d (%d level(s) away). If it fits, it %s%s.",
				b and b.detail or "a requirement is not met", elig.future.unlockLevel, elig.future.levelsAway, wouldText(o), size), { eligibility = elig.future, comparison = o.evidence }))
			useful = true
		else
			add(cat("NOT_USABLE", "PROVEN", blockedText(elig), { eligibility = elig, sources = us.sources }))
			comparisonUnknown = false
			if elig.future.state == "SOON" and not improves then
				out.caveats[#out.caveats + 1] = "it becomes usable soon, but compared with what is worn it is not an improvement (" .. tostring(o.note or o.kind) .. ")"
			end
		end
	elseif yes then
		if o.kind == "empty_slot" then
			add(cat("UPGRADE", certainty, (o.text:gsub("^%l", string.upper)) .. ".", o.evidence)); useful = true
		elseif o.kind == "upgrade" or o.kind == "slight" then
			add(cat(o.kind == "upgrade" and "UPGRADE" or "SLIGHT_UPGRADE", certainty, o.text .. ".", o.evidence)); useful = true
		elseif o.kind == "mixed" then
			add(cat("MIXED", certainty, o.text .. ".", o.evidence)); useful = true
		end
	else
		-- eligibility not established: an apparent improvement is NOT called an upgrade
		if improves or o.kind == "mixed" then
			add(cat("UNKNOWN", "UNPROVEN", string.format("Whether this character can use the item is not established (%s). If it can be used it %s.",
				(elig.current.state == "UNKNOWN" and (us.reason or "no evidence")) or "unknown", wouldText(o)), { eligibility = elig, comparison = o.evidence }))
			useful = true
		end
	end

	-- 4. horizon: a KNOWN, nearby replacement (given as context, never invented) makes an upgrade TEMPORARY
	local rep = opts.context and opts.context.replacement
	out.context = opts.context
	if yes and useful and rep and rep.state == "KNOWN" and (rep.certainty == "GUARANTEED" or rep.certainty == "POSSIBLE") then
		local soonQ = type(rep.quests) == "number" and rep.quests <= A.THRESHOLDS.temporaryQuests
		local soonM = type(rep.minutes) == "number" and rep.minutes <= A.THRESHOLDS.temporaryMinutes
		if soonQ or soonM then
			add(cat("TEMPORARY_UPGRADE", rep.certainty == "GUARANTEED" and certainty or "PARTIAL",
				string.format("A replacement is expected in %s (%s, %s).", soonQ and (rep.quests .. " quest(s)") or (rep.minutes .. " minute(s)"), tostring(rep.source or "context"), rep.certainty:lower()), { replacement = rep }))
		end
	end

	-- 5. combat utility (a proven use effect; what it does is not known unless a utility source says so)
	local ue = fl.useEffect
	if ue.state == "PROVEN" and not no then
		add(cat("COMBAT_UTILITY", "PARTIAL", string.format("Has a use effect (%s). Quest Flow does not know what the effect does.", tostring(ue.value)), { spell = ue.value, spellId = ue.spellId }))
		useful = true
	elseif ue.state == "UNPROVEN" or ue.state == "FAILED" then
		out.caveats[#out.caveats + 1] = "use effect not established: " .. fieldWord(ue)
	end
	for key, fn in pairs(utilityProviders) do
		local ok, r = pcall(fn, facts, opts.context)
		if ok and type(r) == "table" and r.reason then
			add(cat("COMBAT_UTILITY", r.certainty or "PARTIAL", r.reason, { source = r.source or key }))
			useful = true
		end
	end

	-- 6. future use: only what a registered source actually knows. With none, it stays UNKNOWN (and is not hidden).
	out.futureUse = { state = "UNKNOWN", reason = next(futureProviders) and "no registered source recognised this item" or "no future-use source is registered" }
	for key, fn in pairs(futureProviders) do
		local ok, r = pcall(fn, facts, opts.context)
		if ok and type(r) == "table" and r.reason then
			add(cat("FUTURE_USE", r.certainty or "PARTIAL", r.reason, { source = r.source or key }))
			out.futureUse = { state = "KNOWN", reason = r.reason, source = r.source or key }
			useful = true
		end
	end

	-- 7. vendor: only when nothing useful is known AND the comparison could be made (unknown is not "no benefit")
	local vv = fl.vendorValue
	if not useful then
		if comparisonUnknown then
			add(cat("UNKNOWN", "UNPROVEN", "Not enough is known to judge this item: " .. tostring(o.note or "the comparison could not be made") .. ". Nothing is assumed."))
		elseif vv.state == "PROVEN" then
			local why = (o.note and o.kind ~= "no_slot") and (o.note .. "; ") or ""
			add(cat("VENDOR", certainty, string.format("No known equipment or utility benefit (%sno use effect known, no future use known). Vendor value: %s.", why, I.Money(vv.value)), { vendorValue = vv.value }))
		else
			add(cat("UNKNOWN", "UNPROVEN", "No known benefit, and the vendor value was not read (" .. fieldWord(vv) .. ")."))
		end
	end

	table.sort(out.categories, function(a, b) return A.CATEGORIES[a.id].order < A.CATEGORIES[b.id].order end)
	out.primary = out.categories[1] and out.categories[1].id or "UNKNOWN"
	return out
end

-- ---------------------------------------------------------------- recommendation (R1: conservative, deterministic, facts only)
--
-- Reads ONLY what the layers above already produced: each choice's classification (eligibility now / later, the factual comparison with what is worn, the vendor
-- value). No stat weights, no scores, no percentages, no class or spec preferences, no outside data. Two choices are compared only when the comparison is a plain
-- fact: both improve the SAME equipment slot and one is at least as good on every compared stat and better on at least one. Anything else is left uncertain.
--
-- Per item: PREFERRED (the pick), INFERIOR (proven unusable, no gain while another choice gains, or dominated by the pick), UNCERTAIN (everything else).
-- Overall:  RECOMMEND               a proven-usable strict improvement (or an empty slot it fills), with nothing left unresolved
--           TENTATIVE               the best-supported pick, but evidence is incomplete (usability not established, a choice that could not be judged, mixed stats, a
--                                   future-only upgrade, or a vendor-value tie-break among non-gear)
--           NO_CLEAR_RECOMMENDATION no pick is justified (nothing usable improves, equivalent choices, incomparable improvements, not enough known)
--           NOT_A_CHOICE            nothing to choose between (every reward is guaranteed, or only one choice)

local IMPROVES = { upgrade = true, slight = true, empty_slot = true }

--- How one classified choice stands, from its eligibility and its factual comparison:
--   CLEAR (proven usable, improves) | UNPROVEN (usability not established, improves) | FUTURE (not usable yet, would improve) | BLOCKED (proven unusable, no future gain)
--   MIXED | NO_GAIN | NON_GEAR | UNKNOWN_COMPARE | UNRESOLVED (the item could not be read or has not loaded)
local function standingOf(c)
	local o, elig = c and c.outcome, c and c.eligibility
	if not (o and elig) then return "UNRESOLVED" end
	local cur = elig.current.state
	local improves = IMPROVES[o.kind] == true
	if cur == "PROVEN_NO" then
		if elig.future.state == "SOON" and improves then return "FUTURE" end
		return "BLOCKED"
	end
	if improves then return cur == "PROVEN_YES" and "CLEAR" or "UNPROVEN" end
	if o.kind == "mixed" then return "MIXED" end
	if o.kind == "none" then return "NO_GAIN" end
	if o.kind == "no_slot" then return "NON_GEAR" end
	return "UNKNOWN_COMPARE"
end

local function gainMap(o)
	local m = {}
	for _, g in ipairs(o.evidence and o.evidence.gains or {}) do m[g.stat] = g.diff end
	return m
end

--- True only for a plain fact: same equipment slot, complete comparisons, at least as good on every compared stat and better on one.
local function dominates(a, b)
	local oa, ob = a.c.outcome, b.c.outcome
	if not (oa and ob) or oa.kind == "empty_slot" or ob.kind == "empty_slot" then return false end
	if oa.chosen == nil or oa.chosen ~= ob.chosen or oa.partial or ob.partial then return false end
	local ga, gb, better = gainMap(oa), gainMap(ob), false
	local seen = {}
	for stat in pairs(ga) do seen[stat] = true end
	for stat in pairs(gb) do seen[stat] = true end
	for stat in pairs(seen) do
		local x, y = ga[stat] or 0, gb[stat] or 0
		if x < y then return false end
		if x > y then better = true end
	end
	return better
end

local function labelOf(row) return string.format("%s %d, %s", row.kind == "choice" and "choice" or "reward", row.index or 0, row.name) end

--- The first blocker or the plain reason an item cannot be used, in words.
local function blockedWhy(c)
	local b = c.eligibility and c.eligibility.current.blockers[1]
	return b and b.detail or "the client reports it as not usable"
end

--- The usability caveat for an item whose usability is not established: both client answers, and the class evidence when it exists.
local function usabilityCaveat(c)
	local us, elig = c.usability, c.eligibility
	local parts = {}
	if us and us.reason then parts[#parts + 1] = us.reason end
	local prof = elig and elig.checks and elig.checks.proficiency
	if prof and prof.state == "YES" then parts[#parts + 1] = "proficiency evidence says it can be worn (" .. tostring(prof.detail) .. "), but the client's usability answers do not agree with each other" end
	return #parts > 0 and table.concat(parts, "; ") or "no evidence about whether this character can use it"
end

--- The built-in recommender. evaluation = { items = { { index, kind, id, name, facts, classification } } } (the Advisor.Evaluate shape).
-- Returns { schema = 2, state, selected = { index, kind, id, name } | nil, basis, reason, reasons = {...}, caveats = {...}, items = { { index, kind, name, categories, primary, standing, stance, why } } }.
function A.RecommendDefault(evaluation)
	local rows, choices, guaranteed = {}, {}, {}
	for _, it in ipairs(evaluation.items or {}) do
		local c = it.classification
		local row = { index = it.index, kind = it.kind, id = it.id, name = (c and c.item and c.item.name) or it.name or "(unnamed item)", c = c, facts = it.facts }
		row.standing = standingOf(c)
		local ids = {}
		for _, x in ipairs(c and c.categories or {}) do ids[#ids + 1] = x.id end
		row.categories, row.primary = ids, c and c.primary or "UNKNOWN"
		rows[#rows + 1] = row
		if it.kind == "choice" then choices[#choices + 1] = row else guaranteed[#guaranteed + 1] = row end
	end
	local out = { schema = 2, reasons = {}, caveats = {}, items = {} }
	local function reason(t) out.reasons[#out.reasons + 1] = t end
	local function caveat(t) out.caveats[#out.caveats + 1] = t end
	local function finish(state, why, basis, pick)
		out.state, out.reason, out.basis = state, why, basis
		if pick then out.selected = { index = pick.index, kind = pick.kind, id = pick.id, name = pick.name } end
		for _, r in ipairs(rows) do
			local stance, rwhy = nil, nil
			if r.kind == "choice" and state ~= "NOT_A_CHOICE" then
				stance = r.stance or "UNCERTAIN"
				rwhy = r.why
			elseif r.kind ~= "choice" then
				rwhy = "guaranteed with the quest; not part of the choice"
			end
			out.items[#out.items + 1] = { index = r.index, kind = r.kind, name = r.name, categories = r.categories, primary = r.primary, standing = r.standing, stance = stance, why = rwhy }
		end
		return out
	end
	if #rows == 0 then return finish("NOT_A_CHOICE", "No reward items were read.", "NO_REWARDS") end
	if #choices <= 1 then
		return finish("NOT_A_CHOICE", #choices == 1 and "Only one reward can be chosen, so there is nothing to choose between." or "Every reward is guaranteed with the quest; there is nothing to choose between.", "NOTHING_TO_CHOOSE")
	end

	-- group the choices by how they stand (index order throughout: the result never depends on table iteration order)
	local g = { CLEAR = {}, UNPROVEN = {}, FUTURE = {}, BLOCKED = {}, MIXED = {}, NO_GAIN = {}, NON_GEAR = {}, UNKNOWN_COMPARE = {}, UNRESOLVED = {} }
	for _, r in ipairs(choices) do g[r.standing][#g[r.standing] + 1] = r end

	-- what each choice is, as plain facts (also the reason shown when it is not the pick)
	for _, r in ipairs(choices) do
		local c, o = r.c, r.c and r.c.outcome
		if r.standing == "BLOCKED" then r.stance, r.why = "INFERIOR", "cannot be used by this character: " .. blockedWhy(c)
		elseif r.standing == "FUTURE" then r.why = string.format("not usable yet (%s); it would improve what you wear once it is usable", blockedWhy(c))
		elseif r.standing == "MIXED" then r.why = "gains some stats and loses others compared with what you wear; Quest Flow does not weigh different stats against each other"
		elseif r.standing == "NO_GAIN" then r.why = "no improvement over what you wear" .. (o and o.note and (": " .. o.note) or "")
		elseif r.standing == "NON_GEAR" then r.why = "not equipment (no equip slot), so there is no gear comparison"
		elseif r.standing == "UNKNOWN_COMPARE" then r.why = "could not be compared with what you wear" .. (o and o.note and (": " .. o.note) or "")
		elseif r.standing == "UNRESOLVED" then r.why = "its item data was not available, so nothing is known about it yet"
		elseif r.standing == "UNPROVEN" then r.why = "would improve what you wear, but whether this character can use it is not established"
		elseif r.standing == "CLEAR" then r.why = "improves what you wear and is proven usable" end
	end
	local function primaryText(r)
		for _, x in ipairs(r.c.categories) do if x.id == r.c.primary then return x.reason end end
		return r.why
	end

	-- choices that could still turn out better than the pick (anything that is not proven worse or plainly unrelated)
	local function unresolvedAmong(list, pick)
		local u = {}
		for _, r in ipairs(list) do
			if r ~= pick and (r.standing == "UNPROVEN" or r.standing == "FUTURE" or r.standing == "MIXED" or r.standing == "UNKNOWN_COMPARE" or r.standing == "UNRESOLVED") and r.stance ~= "INFERIOR" then u[#u + 1] = r end
		end
		return u
	end
	local function addUnresolvedCaveats(list, pick)
		local u = unresolvedAmong(list, pick)
		for _, r in ipairs(u) do caveat(string.format("%s: %s", labelOf(r), r.why)) end
		return #u
	end

	-- pick the one plain winner of a list of improving choices, or explain why there is none
	local function winnerOf(list)
		if #list == 1 then return list[1] end
		for _, a in ipairs(list) do
			local all = true
			for _, b in ipairs(list) do if a ~= b and not dominates(a, b) then all = false break end end
			if all then return a end
		end
		return nil
	end
	local function markDominated(list, pick)
		for _, r in ipairs(list) do
			if r ~= pick and dominates(pick, r) then
				r.stance, r.why = "INFERIOR", string.format("%s is at least as good on every compared stat and better on at least one, for the same slot", pick.name)
			end
		end
	end
	local function markNoGain(pick)
		for _, r in ipairs(g.NO_GAIN) do r.stance = "INFERIOR"; r.why = r.why .. "; another choice does improve it" end
		return pick
	end

	-- BETWEEN TWO MIXED CHOICES (not a stat weighting): A is preferred to B only when, for the SAME equipment slot and for a class whose weapons are about their damage,
	--   (1) A's weapon damage gain is clear (at least A.THRESHOLDS.slightRelative of the worn weapon's damage) and B has no weapon damage gain, and
	--   (2) everything A loses, B loses as much or more (A gives up nothing that B keeps).
	-- B's own gains (here: stamina) are not weighed against A's; the answer says so. Every item stays MIXED: this only picks among them.
	local function dpsGain(o)
		for _, e in ipairs(o.evidence and o.evidence.gains or {}) do if e.stat == "weapon_dps" then return e end end
	end
	local function lossMap(o)
		local m = {}
		for _, e in ipairs(o.evidence and o.evidence.losses or {}) do m[e.stat] = -e.diff end
		return m
	end
	local function beatsMixed(a, b)
		local oa, ob = a.c.outcome, b.c.outcome
		if not (oa.weaponDamage and oa.kind == "mixed" and ob.kind == "mixed") then return false end
		if oa.chosen == nil or oa.chosen ~= ob.chosen or oa.partial or ob.partial then return false end
		local da = dpsGain(oa)
		if not (da and da.relative and da.relative >= A.THRESHOLDS.slightRelative) or dpsGain(ob) then return false end
		local la, lb = lossMap(oa), lossMap(ob)
		for stat, v in pairs(la) do if (lb[stat] or 0) < v then return false end end
		return true
	end
	local function mixedWinner()
		if #g.MIXED < 2 or #g.MIXED + #g.BLOCKED + #g.NO_GAIN ~= #choices then return nil end   -- (anything unread, uncomparable or not gear could still be better: no pick)
		for _, a in ipairs(g.MIXED) do
			local all = true
			for _, b in ipairs(g.MIXED) do if a ~= b and not beatsMixed(a, b) then all = false break end end
			if all then return a end
		end
	end

	local pick, state, basis, why
	if #g.CLEAR >= 1 then
		pick = winnerOf(g.CLEAR)
		if not pick then
			reason("More than one choice improves what you wear and Quest Flow cannot tell that one is better: they differ in slot or in which stats they improve, or they are equivalent.")
			for _, r in ipairs(g.CLEAR) do reason(string.format("%s: %s", labelOf(r), primaryText(r))) end
			for _, r in ipairs(g.BLOCKED) do reason(string.format("%s: %s", labelOf(r), r.why)) end
			return finish("NO_CLEAR_RECOMMENDATION", "Several choices improve what you wear and the known facts do not separate them; Quest Flow makes no pick.", "AMBIGUOUS")
		end
		markDominated(g.CLEAR, pick)
		markNoGain(pick)
		pick.stance = "PREFERRED"
		local o = pick.c.outcome
		basis = o.kind == "empty_slot" and "EMPTY_SLOT" or "STRICT_UPGRADE"
		why = o.kind == "empty_slot" and string.format("%s fills a slot that is empty now.", pick.name) or string.format("%s is a proven-usable improvement over what you wear.", pick.name)
		reason(string.format("%s: %s", labelOf(pick), primaryText(pick)))
		local n = addUnresolvedCaveats(choices, pick)
		if pick.c.outcome.partial then n = n + 1; caveat("some of its stats could not be compared: " .. tostring(pick.c.outcome.partial)) end
		for _, r in ipairs(g.BLOCKED) do reason(string.format("%s: %s", labelOf(r), r.why)) end
		for _, r in ipairs(g.NO_GAIN) do reason(string.format("%s: %s", labelOf(r), r.why)) end
		return finish(n == 0 and "RECOMMEND" or "TENTATIVE", why, basis, pick)
	end

	if #g.UNPROVEN >= 1 then
		pick = winnerOf(g.UNPROVEN)
		if not pick then
			for _, r in ipairs(g.UNPROVEN) do reason(string.format("%s: %s", labelOf(r), primaryText(r))) end
			return finish("NO_CLEAR_RECOMMENDATION", "Several choices would improve what you wear if they can be used, and the known facts do not separate them; Quest Flow makes no pick.", "AMBIGUOUS")
		end
		markDominated(g.UNPROVEN, pick)
		pick.stance = "PREFERRED"
		reason(string.format("%s: %s", labelOf(pick), primaryText(pick)))
		caveat("Quest Flow cannot confirm this character can use it: " .. usabilityCaveat(pick.c))
		addUnresolvedCaveats(choices, pick)
		local others = #g.BLOCKED + #g.NO_GAIN
		for _, r in ipairs(g.BLOCKED) do reason(string.format("%s: %s", labelOf(r), r.why)) end
		for _, r in ipairs(g.NO_GAIN) do reason(string.format("%s: %s", labelOf(r), r.why)) end
		why = (#g.UNPROVEN == 1 and #g.MIXED + #g.FUTURE + #g.UNKNOWN_COMPARE + #g.UNRESOLVED == 0 and others == #choices - 1)
			and string.format("%s is the only choice that could improve what you wear; the others are proven unusable or give no improvement.", pick.name)
			or string.format("%s is the best-supported choice: it would improve what you wear without losing any compared stat.", pick.name)
		return finish("TENTATIVE", why, "ONLY_CANDIDATE", pick)
	end

	if #g.FUTURE >= 1 then
		if #g.FUTURE == 1 and #g.MIXED + #g.UNKNOWN_COMPARE + #g.UNRESOLVED == 0 then
			pick = g.FUTURE[1]
			pick.stance = "PREFERRED"
			reason(string.format("%s: %s", labelOf(pick), pick.why))
			caveat("nothing offered can be used and improves your gear right now; this one is a later improvement, not a current one")
			for _, r in ipairs(g.BLOCKED) do reason(string.format("%s: %s", labelOf(r), r.why)) end
			for _, r in ipairs(g.NO_GAIN) do reason(string.format("%s: %s", labelOf(r), r.why)) end
			return finish("TENTATIVE", string.format("%s is the only choice that would improve what you wear, once it can be used.", pick.name), "FUTURE_ONLY", pick)
		end
		for _, r in ipairs(g.FUTURE) do reason(string.format("%s: %s", labelOf(r), r.why)) end
		return finish("NO_CLEAR_RECOMMENDATION", "Nothing offered can be used now, and Quest Flow cannot tell which later improvement is better.", "AMBIGUOUS")
	end

	-- no choice improves what is worn: only a plain vendor-value tie-break among NON-GEAR choices is possible, labelled as such
	local allNonGear = #g.NON_GEAR == #choices
	if allNonGear then
		local best, tie, count = nil, false, 0
		for _, r in ipairs(g.NON_GEAR) do
			local vv = r.facts and r.facts.fields and r.facts.fields.vendorValue
			local has = false
			for _, x in ipairs(r.c.categories) do if x.id == "VENDOR" then has = true end end
			if vv and vv.state == "PROVEN" and type(vv.value) == "number" and has then
				count = count + 1
				reason(string.format("%s: vendor value %s", labelOf(r), I.Money(vv.value)))
				if not best or vv.value > best.value then best, tie = { row = r, value = vv.value }, false
				elseif vv.value == best.value then tie = true end
			end
		end
		if count == #g.NON_GEAR and best and not tie then
			pick = best.row
			pick.stance = "PREFERRED"
			caveat("this is a vendor-value tie-break only: none of these rewards is equipment, and a higher sell value says nothing about how useful it is to you")
			return finish("TENTATIVE", string.format("%s has the highest vendor value (%s); none of the choices is equipment.", pick.name, I.Money(best.value)), "VENDOR_TIEBREAK", pick)
		end
		for _, r in ipairs(g.NON_GEAR) do if not (r.facts and r.facts.fields and r.facts.fields.vendorValue and r.facts.fields.vendorValue.state == "PROVEN") then caveat(labelOf(r) .. ": vendor value not read") end end
		return finish("NO_CLEAR_RECOMMENDATION", tie and "The choices are not equipment and the top vendor values are equal; Quest Flow makes no pick." or "The choices are not equipment and their vendor values are not all known; Quest Flow makes no pick.", "VENDOR_UNDECIDED")
	end
	if #g.BLOCKED == #choices then
		for _, r in ipairs(g.BLOCKED) do reason(string.format("%s: %s", labelOf(r), r.why)) end
		return finish("NO_CLEAR_RECOMMENDATION", "No choice can be used by this character; Quest Flow makes no pick.", "NONE_USABLE")
	end
	for _, r in ipairs(choices) do reason(string.format("%s: %s", labelOf(r), r.why)) end
	local mw = mixedWinner()
	if mw then
		mw.stance = "PREFERRED"
		for _, r in ipairs(g.MIXED) do
			if r ~= mw then
				r.stance = "UNCERTAIN"
				r.why = r.why .. string.format("; %s raises weapon damage clearly and gives up nothing this one keeps, while this one's own gains are not weighed against that", mw.name)
			end
		end
		local mo = mw.c.outcome
		local d = dpsGain(mo)
		reason(string.format("%s: the clearest gain is weapon damage (%s weapon dps, %d%% of what you wear), for a loss no larger than the other choice's. Both stay MIXED; Quest Flow does not weigh the other choice's stats against this.", labelOf(mw), signed(d.diff), math.floor(d.relative * 100 + 0.5)))
		local n = 0
		local us = mw.c.eligibility and mw.c.eligibility.current.state
		if us ~= "PROVEN_YES" then
			n = n + 1
			caveat("Quest Flow cannot confirm this character can use it: " .. usabilityCaveat(mw.c))
		end
		for _, r in ipairs(g.MIXED) do if r ~= mw and r.c.eligibility and r.c.eligibility.current.state ~= "PROVEN_YES" then caveat(labelOf(r) .. ": usability is also not established") end end
		return finish(n == 0 and "RECOMMEND" or "TENTATIVE", string.format("%s is the better of the viable choices: both trade stats, and it is the one that clearly raises weapon damage while giving up nothing the other keeps.", mw.name), "MIXED_DPS", mw)
	end
	if #g.MIXED > 0 then
		return finish("NO_CLEAR_RECOMMENDATION", "No choice improves what you wear without giving something up, and Quest Flow does not weigh different stats against each other.", "MIXED_ONLY")
	elseif #g.UNKNOWN_COMPARE + #g.UNRESOLVED > 0 then
		return finish("NO_CLEAR_RECOMMENDATION", "Not enough is known about the choices to pick one (see the reasons).", "NOT_ENOUGH_KNOWN")
	end
	return finish("NO_CLEAR_RECOMMENDATION", "No choice improves what you wear; Quest Flow makes no pick.", "NO_IMPROVEMENT")
end

--- Turns an evaluation into a recommendation. A plugged-in recommender (SetRecommender) replaces the built-in one; one that errors or returns nothing falls back to the
-- built-in recommender. The classification layer never calls this.
function A.Recommend(evaluation, opts)
	if recommender then
		local ok, r = pcall(recommender, evaluation, opts)
		if ok and type(r) == "table" then return r end
	end
	return A.RecommendDefault(evaluation)
end

-- ---------------------------------------------------------------- evaluating the reward dialog

--- Evaluates the offered rewards: { live, available, source, q, at, items = { { index, kind, id, name, facts, classification } }, recommendation }.
-- available is true ONLY while the reward dialog is open right now (live). A dialog that was seen earlier and is closed now is reported as such
-- (live = false, available = false): its rewards are not currently offered and must not be presented as if they were.
-- opts: { dialog = DialogFacts-shaped table, equipped = Gear.Equipped()-shaped table, character, context } (all optional; the real readers are used otherwise).
function A.Evaluate(opts)
	opts = opts or {}
	local df = opts.dialog
	if not df and ns.ItemProbe and ns.ItemProbe.DialogFacts then df = ns.ItemProbe.DialogFacts(true) end
	if not df then return nil end
	local equipped = opts.equipped
	if not equipped and ns.Gear then
		local ok, snap = pcall(ns.Gear.Snapshot)
		equipped = ok and snap and snap.equipped or nil
	end
	local o = { character = opts.character or ns.Eligibility.Character(), context = opts.context, requirements = opts.requirements }
	local ev = { live = df.live == true, available = df.live == true, q = df.q, at = df.at, items = {} }
	ev.source = ev.live and "the reward dialog that is open now" or "the last reward dialog seen (it is closed now, so these rewards are not currently offered)"
	for _, spec in ipairs({ df.choices or {}, df.rewards or {} }) do
		for _, it in ipairs(spec) do
			ev.items[#ev.items + 1] = { index = it.index, kind = it.kind, id = it.id, name = it.name, facts = it.facts, classification = A.Classify(it.facts, equipped, o) }
		end
	end
	ev.recommendation = A.Recommend(ev, o)
	return ev
end

-- ---------------------------------------------------------------- what the PLAYER sees (read by UI/RewardOverlay.lua; the advisor decides, the overlay only draws this)

--- One reward CHOICE as the overlay shows it. Everything here comes from the classification and the recommendation the advisor already made; nothing is decided again.
--   index        the choice number in the reward dialog (the same number the client uses)
--   tags         the advisor's own category words, in its presentation order (e.g. { "NOT USABLE", "VENDOR" }); a mixed trade-off whose usability is not established shows MIXED
--   short        the stat gains and losses of the comparison, e.g. "+4 stamina, -2 agility" (nil when there is none)
--   unsure       true when the client's usability answers are unclear or missing (shown as "usability unclear": never hidden)
--   reason       the advisor's full reason for its main category (for the tooltip); caveats = its caveats
--   recommended  "pick" (the advisor recommends this choice) | "tentative" (it names it, but says the evidence is incomplete) | nil
function A.DisplayRow(it, selected, state)
	local c = it.classification
	local primary
	for _, x in ipairs(c.categories) do if x.id == c.primary then primary = x end end
	local tags, seen = {}, {}
	for _, x in ipairs(c.categories) do if not seen[x.tag] then seen[x.tag] = true; tags[#tags + 1] = x.tag end end
	local o = c.outcome
	local cur = c.eligibility and c.eligibility.current and c.eligibility.current.state
	local unsure = (cur ~= "PROVEN_YES" and cur ~= "PROVEN_NO") and c.item and c.item.state == "LOADED" or false
	-- a trade-off is a trade-off whether or not usability is established; it is shown as MIXED, with the doubt beside it (an apparent IMPROVEMENT is not: it stays UNKNOWN)
	if c.primary == "UNKNOWN" and unsure and o and o.kind == "mixed" then tags = { "MIXED" } end
	local short
	local ev = o and o.evidence
	if ev and (o.kind == "upgrade" or o.kind == "slight" or o.kind == "mixed") then
		local parts = {}
		if ev.gains and #ev.gains > 0 then parts[#parts + 1] = statsText(ev.gains) end
		if ev.losses and #ev.losses > 0 then parts[#parts + 1] = statsText(ev.losses) end
		if #parts > 0 then short = table.concat(parts, ", ") end
	end
	-- 0.10.1: a reward that is equipment and gives no gain over what is worn is NOT AN UPGRADE (its own icon and word; the advisor's outcome kind "none", shown, not re-decided).
	-- Blizzard's own tooltip already carries every stat, so no comparison numbers are put in the view model.
	if o and o.kind == "none" then
		local blocked = false
		for _, t in ipairs(tags) do if t == "NOT USABLE" then blocked = true end end
		if not blocked then table.insert(tags, 1, "NOT AN UPGRADE") end
	end
	local headline = tags[1] or "UNKNOWN"
	local vendor
	for _, t in ipairs(tags) do
		if t == "VENDOR" then
			local vv = it.facts and it.facts.fields and it.facts.fields.vendorValue
			if vv and vv.state == "PROVEN" and type(vv.value) == "number" and vv.value > 0 then vendor = I.Money(vv.value) end
		end
	end
	local row = { index = it.index, name = c.item.name, tags = tags, headline = headline, vendor = vendor, family = primary and primary.family or "grey", short = short, unsure = unsure or nil,
		reason = primary and primary.reason or "Nothing is known about this item yet.", caveats = c.caveats }
	if selected and selected.kind == "choice" and selected.index == it.index then
		row.recommended = state == "RECOMMEND" and "pick" or (state == "TENTATIVE" and "tentative" or nil)
	end
	return row
end

--- The reward dialog as the overlay shows it: nil unless a quest REWARD dialog (the turn-in step, QUEST_COMPLETE) is open right now with two or more choices to decide between.
-- Returns { q, state, pick, verdict = { text, short, kind }, rows = { DisplayRow ... } }. The verdict says which choice (never "the best-looking one") or that Codex makes no pick.
-- opts as for A.Evaluate (a test passes a fake dialog).
function A.Display(opts)
	local ev = A.Evaluate(opts)
	if not (ev and ev.live and ev.at == "QUEST_COMPLETE") then return nil end
	local rec = ev.recommendation or {}
	local rows = {}
	for _, it in ipairs(ev.items) do
		if it.kind == "choice" then rows[#rows + 1] = A.DisplayRow(it, rec.selected, rec.state) end
	end
	if #rows < 2 then return nil end
	local sel = rec.selected
	local verdict
	if rec.state == "RECOMMEND" and sel then
		verdict = { kind = "pick", text = string.format("QUEST FLOW: RECOMMENDED - CHOICE %d", sel.index), short = string.format("QUEST FLOW: RECOMMENDED - CHOICE %d", sel.index) }
	elseif rec.state == "TENTATIVE" and sel then
		verdict = { kind = "tentative", text = string.format("QUEST FLOW: TENTATIVE PICK - CHOICE %d (evidence incomplete)", sel.index), short = string.format("QUEST FLOW: TENTATIVE PICK - CHOICE %d", sel.index) }
	else
		verdict = { kind = "none", text = "QUEST FLOW: NO CLEAR PICK" }
	end
	return { q = ev.q, state = rec.state, pick = sel and sel.index or nil, verdict = verdict, rows = rows }
end

-- ---------------------------------------------------------------- the report section

--- The REWARD ADVISOR lines of /codex report. Never errors.
function A.ReportLines(opts)
	local L = {}
	local ok, ev = pcall(A.Evaluate, opts)
	if not ok then
		L[#L + 1] = "REWARD ADVISOR: error: " .. tostring(ev)
		return L
	end
	if not ev then
		L[#L + 1] = "REWARD ADVISOR: no reward dialog seen this session (open a quest reward dialog, then run /qflow report)"
		return L
	end
	L[#L + 1] = string.format("REWARD ADVISOR (it describes each reward; for a choice it also gives a conservative recommendation from known facts only: nothing is scored) | %s | Q:%s", ev.source, tostring(ev.q))
	for i, it in ipairs(ev.items) do
		local c = it.classification
		local primary
		for _, x in ipairs(c.categories) do if x.id == c.primary then primary = x end end
		L[#L + 1] = string.format("%s %d. %s: [%s] %s (%s)", it.kind == "choice" and "Choice" or "Reward", it.index, c.item.name, primary and primary.tag or "UNKNOWN", primary and primary.reason or "", primary and primary.certainty or "UNPROVEN")
		local extra = {}
		for _, x in ipairs(c.categories) do if x ~= primary then extra[#extra + 1] = "[" .. x.tag .. "] " .. x.reason end end
		if #extra > 0 then L[#L + 1] = "    also: " .. table.concat(extra, " | ") end
		if #c.caveats > 0 then L[#L + 1] = "    caveats: " .. table.concat(c.caveats, "; ") end
		if c.eligibility then L[#L + 1] = "    eligibility: " .. ns.Eligibility.Describe(c.eligibility) end
		local u = c.usability
		if u and #u.sources > 0 then
			local s = {}
			for _, src in ipairs(u.sources) do s[#s + 1] = src.name .. "=" .. tostring(src.value) end
			L[#L + 1] = "    usability evidence: " .. table.concat(s, ", ") .. " -> " .. u.verdict
		end
	end
	local rec = ev.recommendation or {}
	local sel = rec.selected
	if rec.state == "RECOMMEND" or rec.state == "TENTATIVE" then
		L[#L + 1] = string.format("RECOMMENDATION: %s | pick: choice %s, %s | basis %s%s", rec.state, tostring(sel and sel.index or "?"), tostring(sel and sel.name or "?"), tostring(rec.basis),
			rec.state == "TENTATIVE" and " | TENTATIVE: the evidence is incomplete, see the caveats" or "")
	else
		L[#L + 1] = string.format("RECOMMENDATION: %s%s", tostring(rec.state), rec.state == "NO_CLEAR_RECOMMENDATION" and " | Quest Flow makes no pick" or "")
	end
	if rec.reason then L[#L + 1] = "    " .. rec.reason end
	for _, r in ipairs(rec.reasons or {}) do L[#L + 1] = "    fact: " .. r end
	for _, cv in ipairs(rec.caveats or {}) do L[#L + 1] = "    caveat: " .. cv end
	if rec.items then
		for _, it in ipairs(rec.items) do
			if it.stance then L[#L + 1] = string.format("    %s %d. %s: %s%s", it.kind == "choice" and "Choice" or "Reward", it.index or 0, it.name, it.stance, it.why and (" - " .. it.why) or "") end
		end
	end
	if not ev.live and rec.state ~= "NOT_A_CHOICE" then L[#L + 1] = "    (this dialog is closed: the recommendation describes what was offered, it is not an open choice)" end
	return L
end
