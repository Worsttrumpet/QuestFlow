-- ForeverCodex.Advisor: Stage 3, the REWARD ADVISOR. It sits above the Stage 1 ItemFacts and the Stage 2 Gear reader and answers one question per reward item:
-- "what kind of value does this reward appear to have for this character, and on what evidence?"
--
-- The layers stay separate (each is a different function, none calls "up"):
--   ItemFacts           what the client tells us                                   Items.Facts / Items.Normalize        (Stage 1)
--   Eligibility         can the character use it now / will they soon             Eligibility.Evaluate                 (its own layer, 0.5.0)
--   Gear comparison     the factual difference between two items                  Gear.Compare / CompareToEquipped     (Stage 2)
--   Classification      what kind of value the reward appears to have, and why    Advisor.Classify                     (this file)
--   Recommendation      what Codex suggests doing                                  Advisor.Recommend                    (an interface only: no opinion yet)
--
-- NOT a Pawn clone: there are no stat weights and no scores. An item is judged only from known facts: it either improves some compared stats without lowering
-- any (improvement), lowers some and raises others (MIXED: Codex does not weigh stats against each other), or does not improve. The size of an improvement is
-- the largest relative gain over what is equipped (Advisor.THRESHOLDS: PROPOSED values, untuned, kept in one table).
--
-- Uncertainty is kept, never collapsed: UNKNOWN is not ABSENT, EMPTY is not zero, UNPROVEN is not false. A comparison that cannot be made is UNKNOWN, an item
-- that has not loaded is UNKNOWN, and conflicting usability evidence stays a conflict. Every category carries a reason that only states known facts.
--
-- A classification describes the ITEM. "Upgrade" is never "take this". The default recommender gives no opinion; later layers (replacement horizon, route,
-- vendor value, future use) plug in through the context argument and the registries below.
-- Read-only, independent of the planner, strategies, presenter and UI; the only consumer is /codex report (Advisor.ReportLines).

local addonName, ns = ...

local A = {}
ns.Advisor = A

local I = ns.Items

-- PROPOSED thresholds (they have not been tuned against real play; one place to change them):
--   slightRelative   an improvement whose largest relative gain is below this is a SLIGHT upgrade
--   relativeFloor    the smallest base a relative gain is measured against (so +1 over 0 is not "infinite")
--   temporaryQuests / temporaryMinutes   a known replacement at most this far away makes an upgrade TEMPORARY (needs context; never invented)
A.THRESHOLDS = { slightRelative = 0.25, relativeFloor = 5, temporaryQuests = 3, temporaryMinutes = 15 }

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
local function judge(cmp)
	local r = { gains = {}, losses = {}, unknown = {}, compared = 0 }
	for _, stat in ipairs(STAT_ORDER) do
		local s = cmp.stats[stat]
		if s.state == "COMPARED" then
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

--- Which equipped entry the reward is judged against: an EMPTY slot it fits first, otherwise the comparable entry with the largest relative gain (or, when
-- none gains, the first comparable one). All entries are kept in the evidence. Returns the entry or nil.
local function chooseEntry(entries)
	local bestGain, bestRel, firstCompared, firstOther
	for _, e in ipairs(entries) do
		if e.state == "EMPTY_SLOT" then return e end
		if e.state == "COMPARED" then
			firstCompared = firstCompared or e
			local j = judge(e.comparison)
			local rel = 0
			for _, g in ipairs(j.gains) do rel = math.max(rel, g.relative) end
			if #j.gains > 0 and #j.losses == 0 and (not bestRel or rel > bestRel) then bestGain, bestRel = e, rel end
		else
			firstOther = firstOther or e
		end
	end
	return bestGain or firstCompared or firstOther
end

-- ---------------------------------------------------------------- classification

-- the factual comparison of the item with what is worn, turned into an outcome the classification can use. Never judges usability.
--   { kind = "empty_slot" | "upgrade" | "slight" | "mixed" | "none" | "unknown" | "no_slot", text, evidence, note, partial }
local function compareOutcome(facts, equipped)
	local fl = facts.fields
	local slotState = fl.equipSlot.state
	if slotState == "EMPTY" then return { kind = "no_slot", note = "the item has no equip slot" } end
	if slotState ~= "PROVEN" then return { kind = "unknown", note = "the item's equip slot is " .. fieldWord(fl.equipSlot) } end
	if not (ns.Gear and equipped) then return { kind = "unknown", note = "the equipped items were not read" } end
	local cmp = ns.Gear.CompareToEquipped(facts, equipped)
	if cmp.state ~= "COMPARABLE" then return { kind = "unknown", note = cmp.reason, comparison = cmp } end
	local entry = chooseEntry(cmp.entries)
	if entry and entry.state == "EMPTY_SLOT" then
		return { kind = "empty_slot", text = string.format("fills your empty %s slot", entry.slotName), evidence = { slot = entry.slot, kind = "empty_slot" }, comparison = cmp, chosen = entry.slot }
	end
	if not (entry and entry.state == "COMPARED") then
		return { kind = "unknown", note = entry and (entry.reason or "the equipped item could not be compared") or "no equipment slot to compare with", comparison = cmp, chosen = entry and entry.slot }
	end
	local j = judge(entry.comparison)
	local cur = nameOf(entry.equipment.itemFacts)
	local ev = { slot = entry.slot, slotName = entry.slotName, against = cur, gains = j.gains, losses = j.losses, unknown = j.unknown }
	local o = { evidence = ev, comparison = cmp, chosen = entry.slot, partial = #j.unknown > 0 and tostring(j.unknown[1].reason) or nil }
	if j.compared == 0 then
		o.kind, o.note = "unknown", "no stat could be compared" .. (j.unknown[1] and (": " .. tostring(j.unknown[1].reason)) or "")
	elseif #j.gains > 0 and #j.losses == 0 then
		local maxRel = 0
		for _, g in ipairs(j.gains) do maxRel = math.max(maxRel, g.relative) end
		ev.maxRelative = maxRel
		o.kind = (maxRel >= A.THRESHOLDS.slightRelative) and "upgrade" or "slight"
		o.text = string.format("%s over your current %s (%s)", statsText(j.gains), cur, entry.slotName)
	elseif #j.gains > 0 and #j.losses > 0 then
		o.kind = "mixed"
		o.text = string.format("%s, but %s versus your current %s; Codex does not weigh different stats against each other", statsText(j.gains), statsText(j.losses), cur)
	else
		o.kind = "none"
		o.note = (#j.losses > 0) and string.format("%s versus your current %s", statsText(j.losses), cur) or ("no difference in the compared stats versus your current " .. cur)
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
	local o = compareOutcome(facts, equipped)
	out.comparison = { state = o.comparison and o.comparison.state or (o.kind == "no_slot" and "NO_SLOT" or "UNKNOWN"), chosen = o.chosen, entries = o.comparison and o.comparison.entries, note = o.note }
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
		add(cat("COMBAT_UTILITY", "PARTIAL", string.format("Has a use effect (%s). Codex does not know what the effect does.", tostring(ue.value)), { spell = ue.value, spellId = ue.spellId }))
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

-- ---------------------------------------------------------------- recommendation (an interface; no opinion yet)

--- Turns an evaluation into a recommendation. The default gives NO OPINION: it only echoes what each classification offers, so a later layer can see exactly
-- what it will have to weigh. SetRecommender replaces it. The classification layer never calls this.
function A.Recommend(evaluation, opts)
	if recommender then
		local ok, r = pcall(recommender, evaluation, opts)
		if ok and type(r) == "table" then return r end
	end
	local items = {}
	for i, it in ipairs(evaluation.items or {}) do
		local ids = {}
		for _, c in ipairs(it.classification.categories) do ids[#ids + 1] = c.id end
		items[i] = { index = it.index, kind = it.kind, name = it.classification.item.name, categories = ids, primary = it.classification.primary, stance = nil }
	end
	return { schema = 1, state = "NO_OPINION", reason = "Stage 3 classifies each reward; it does not choose between them yet.", items = items }
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
		L[#L + 1] = "REWARD ADVISOR: no reward dialog seen this session (open a quest reward dialog, then run /codex report)"
		return L
	end
	L[#L + 1] = string.format("REWARD ADVISOR (classification only: it describes each item and gives no recommendation) | %s | Q:%s", ev.source, tostring(ev.q))
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
	L[#L + 1] = string.format("RECOMMENDATION: %s (%s)", ev.recommendation.state, ev.recommendation.reason or "")
	return L
end
