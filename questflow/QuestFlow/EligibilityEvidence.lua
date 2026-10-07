-- ForeverCodex.EligibilityEvidence: a small, standalone recorder of what the Forever client actually lets this character use, so that "can a Shaman use Mail at
-- this level on Forever?" can eventually be answered from real observations instead of Classic assumptions.
--
--   ItemFacts -> Eligibility Evidence -> Eligibility -> Gear comparison -> Reward Advisor
--
-- Actual Forever client evidence is authoritative; Classic rules are reference material only. NOTHING in this file knows a class, an armor type or a level
-- threshold: it records observations and answers questions from them (no class-to-armor table, no Classic rule).
--
-- OBSERVATION  one recorded fact: "a <class> at level <L> (race, faction) and an item of type <T> (id, required level): the client said usable = true/false,
--              from <source>, in build <B>". An observation is NOT a rule.
-- PROVEN       an answer for a (class, item type, level) that the explicit POLICY below allows an aggregate of observations to support.
-- OBSERVED     observations exist but the policy is not met. UNKNOWN: no observation. CONFLICT: observations contradict each other (never resolved here).
--
-- POLICY (conservative, inspectable, Ev.POLICY):
--   * YES at level L (the type is usable from at most level L, because proficiency does not disappear as the level rises) needs, at that level, 1 distinct item
--     WORN by the character (the game let them equip it) or 2 distinct items the client flagged usable (both client answers true).
--   * NO at level L (not usable at L, and so not at any lower level) needs 3 distinct items the client flagged unusable (both answers false) at that level.
--     Negative evidence is held to a higher bar because a hidden restriction on one item (a class-only item) would look the same.
--   * An observation where the item's required level is above the character's level (or unknown) is recorded but never counted: it does not isolate proficiency.
--   * Level requirement and proficiency stay separate: nothing here says an item's required level is met.
--   * The exact unlock level is PROVEN only with a proven NO at level U-1 and a proven YES at level U.
--   * CONFLICT: an unconfounded NO observed at a level at or above an unconfounded YES for the same class and type, or the same item observed both ways at one
--     level. A hidden restriction can cause a false conflict; that errs toward UNKNOWN, which is the safe side.
-- DEDUPLICATION: identical observations (same class, level, race, faction, item, result, source and build) are one record with a repeat count and first/last
-- time. A different result, item, level, source or BUILD is a separate record.
-- Read-only; independent of the planner, Gear, UI, the advisor and Eligibility (Eligibility asks this file, never the reverse). The only use of the item reader is
-- Items.Resolve, to say in the diagnostics whether a client function is present by the same lookup the readers use.

local addonName, ns = ...

local Ev = {}
ns.EligibilityEvidence = Ev

Ev.SCHEMA = 1
Ev.MAX_OBSERVATIONS = 2000          -- the oldest (by last seen) is dropped beyond this

Ev.POLICY = { version = 1, yesWorn = 1, yesClient = 2, noClient = 3, ignoreConfounded = true }

-- ---------------------------------------------------------------- storage

local indexes = setmetatable({}, { __mode = "k" })

local function store()
	if type(ForeverCodexDB) ~= "table" then return nil end
	local items = ForeverCodexDB.items
	if type(items) ~= "table" then items = {}; ForeverCodexDB.items = items end
	local s = items.evidence
	if type(s) ~= "table" then s = {}; items.evidence = s end
	if s.v == nil then s.v = Ev.SCHEMA end
	s.obs = type(s.obs) == "table" and s.obs or {}
	s.skips = type(s.skips) == "table" and s.skips or {}
	return s
end

local function index(s)
	local ix = indexes[s.obs]
	if not ix then
		ix = {}
		for i, o in ipairs(s.obs) do if o.fp then ix[o.fp] = o end end
		indexes[s.obs] = ix
	end
	return ix
end

local function skip(reason)
	local s = store()
	if s then s.skips[reason] = (s.skips[reason] or 0) + 1 end
	return nil, reason
end

local function wall() return type(time) == "function" and time() or 0 end

local function build()
	if type(GetBuildInfo) ~= "function" then return nil end
	local ok, _, b = pcall(GetBuildInfo)
	return ok and b ~= nil and tostring(b) or nil
end

-- ---------------------------------------------------------------- normalization

--- True for item types that have a proficiency (armor types 1-4 and shields, and weapons). Cosmetic and jewelry-type armor (subclass 0) and everything else is not.
function Ev.Applicable(itemClass, subClass)
	if itemClass == 2 then return type(subClass) == "number" end
	if itemClass == 4 then return type(subClass) == "number" and ((subClass >= 1 and subClass <= 4) or subClass == 6) end
	return false
end

--- Raw input -> a normalized observation, or nil and the reason it cannot be one. Missing information is never turned into a value:
--   raw = { character = { class, level, race, faction }, item = { id, itemClass, subClass, typeText, equipSlot, requiredLevel },
--           result = { usable = true | false | nil, source }, context = { build, client, evidenceSource, t } }
-- A usable = nil observation is kept (state UNKNOWN) but never counted. Needs a class, a level and an applicable item type.
function Ev.Normalize(raw)
	if type(raw) ~= "table" then return nil, "no observation" end
	local c, it, r, x = raw.character or {}, raw.item or {}, raw.result or {}, raw.context or {}
	if type(c.class) ~= "string" or c.class == "" then return nil, "character class not known" end
	if type(c.level) ~= "number" then return nil, "character level not known" end
	if type(it.itemClass) ~= "number" or type(it.subClass) ~= "number" then return nil, "item type not known" end
	if not Ev.Applicable(it.itemClass, it.subClass) then return nil, "item type has no proficiency" end
	if r.usable ~= nil and type(r.usable) ~= "boolean" then return nil, "usable result is not a boolean" end
	if type(r.source) ~= "string" or r.source == "" then return nil, "no source" end
	local o = {
		v = Ev.SCHEMA, class = c.class, level = c.level, race = c.race, faction = c.faction,
		itemId = it.id, itemClass = it.itemClass, subClass = it.subClass, typeText = it.typeText, equipSlot = it.equipSlot, requiredLevel = it.requiredLevel,
		usable = r.usable, source = r.source, state = (r.usable == nil) and "UNKNOWN" or "OBSERVED", reason = r.reason,
		build = x.build ~= nil and tostring(x.build) or nil, client = x.client, evidenceSource = x.evidenceSource, first = x.t or wall(),
		confounds = {},
	}
	-- an item whose required level is above the character's (or unknown) does not isolate proficiency
	if type(o.requiredLevel) ~= "number" then o.confounds[#o.confounds + 1] = "required level not known"
	elseif o.requiredLevel > o.level then o.confounds[#o.confounds + 1] = "required level above the character's level" end
	o.last, o.n = o.first, 1
	o.fp = table.concat({ o.class, o.level, o.race or "?", o.faction or "?", o.itemId or "?", o.itemClass, o.subClass, tostring(o.usable), o.source, o.build or "?" }, "|")
	return o
end

--- Records one observation. Returns "recorded" | "duplicate" | "rejected", and the record or the reason.
function Ev.Record(raw)
	local s = store()
	if not s then return "rejected", "no saved variable" end
	local o, why = Ev.Normalize(raw)
	if not o then skip(why); return "rejected", why end
	local ix = index(s)
	local dup = ix[o.fp]
	if dup then
		dup.n = (dup.n or 1) + 1
		dup.last = o.first
		return "duplicate", dup
	end
	if #s.obs >= Ev.MAX_OBSERVATIONS then
		local oldest, at = nil, nil
		for i, e in ipairs(s.obs) do if not at or (e.last or 0) < (s.obs[at].last or 0) then at = i end end
		if at then ix[s.obs[at].fp] = nil; table.remove(s.obs, at) end
	end
	s.obs[#s.obs + 1] = o
	ix[o.fp] = o
	return "recorded", o
end

function Ev.Clear()
	local s = store()
	if s then s.obs, s.skips = {}, {} end
end

--- All stored observations (a list; do not modify).
function Ev.Observations() local s = store(); return s and s.obs or {} end

-- ---------------------------------------------------------------- builders from ItemFacts (the callers supply the character and the client verdict)

local function typeOf(facts)
	local fl = facts and facts.fields
	if not fl then return nil end
	local c, s = fl.class, fl.subclass
	if not (c and s and c.state == "PROVEN" and s.state == "PROVEN") then return nil end
	return c.value, s.value, ((c.text and (tostring(c.text) .. "/") or "") .. (s.text and tostring(s.text) or tostring(s.value)))
end

local function charOf(character)
	character = character or {}
	return { class = character.classToken, level = character.level, race = character.raceToken, faction = character.faction }
end

local function itemOf(facts)
	local ic, sc, text = typeOf(facts)
	local fl = facts.fields
	return { id = facts.id, itemClass = ic, subClass = sc, typeText = text, equipSlot = fl.equipSlot and fl.equipSlot.state == "PROVEN" and fl.equipSlot.value or nil,
		requiredLevel = fl.requiredLevel and fl.requiredLevel.state == "PROVEN" and fl.requiredLevel.value or nil }
end

--- An observation from an item the client answered usability questions about. verdict = { verdict = "USABLE" | "NOT_USABLE" | "CONFLICT" | "UNKNOWN", reason }
-- (the caller computes it from the client's answers). USABLE becomes usable = true, NOT_USABLE usable = false, anything else usable = nil (kept, not counted).
function Ev.FromFacts(facts, character, verdict, opts)
	opts = opts or {}
	if not (facts and facts.fields) then return nil, "no item facts" end
	if facts.state ~= "LOADED" then return nil, "item not loaded" end
	local u
	if verdict and verdict.verdict == "USABLE" then u = true elseif verdict and verdict.verdict == "NOT_USABLE" then u = false end
	return { character = charOf(character), item = itemOf(facts), result = { usable = u, source = "client_usability", reason = verdict and verdict.reason },
		context = { build = build(), evidenceSource = opts.evidenceSource or "item_usability" } }
end

--- An observation from an item the character is wearing: the game allowed it to be equipped, so usable = true at the character's current level.
function Ev.FromWorn(facts, character, slot, opts)
	opts = opts or {}
	if not (facts and facts.fields) then return nil, "no item facts" end
	if facts.state ~= "LOADED" then return nil, "item not loaded" end
	if slot == 4 or slot == 19 then return nil, "shirt and tabard slots are cosmetic" end
	return { character = charOf(character), item = itemOf(facts), result = { usable = true, source = "worn_item" }, context = { build = build(), evidenceSource = opts.evidenceSource or "equipment" } }
end

--- Builds and records in one call; returns the Record result, or "rejected" and the reason.
function Ev.ObserveFacts(facts, character, verdict, opts)
	local raw, why = Ev.FromFacts(facts, character, verdict, opts)
	if not raw then skip(why); return "rejected", why end
	return Ev.Record(raw)
end

function Ev.ObserveWorn(facts, character, slot, opts)
	local raw, why = Ev.FromWorn(facts, character, slot, opts)
	if not raw then skip(why); return "rejected", why end
	return Ev.Record(raw)
end

-- ---------------------------------------------------------------- aggregation

local function groupMatch(o, class, itemClass, subClass) return o.class == class and o.itemClass == itemClass and o.subClass == subClass end

local function distinct(set) local n = 0; for _ in pairs(set) do n = n + 1 end return n end

--- Summarizes the observations for one (class, item class, item subclass): counts, the levels at which a YES or a NO is PROVEN under the policy, the conflicts,
-- and the evidence state (UNKNOWN | OBSERVED | PROVEN | CONFLICT). Pure function of the stored observations.
function Ev.Group(class, itemClass, subClass)
	local g = { class = class, itemClass = itemClass, subClass = subClass, counts = { observations = 0, yes = 0, no = 0, unknown = 0, confounded = 0 }, conflicts = {}, yesLevels = {}, noLevels = {} }
	local yesWorn, yesClient, noClient = {}, {}, {}
	local rawYes, rawNo = {}, {}                 -- unconfounded raw observations by level
	local byItemLevel = {}
	local P = Ev.POLICY
	for _, o in ipairs(Ev.Observations()) do
		if groupMatch(o, class, itemClass, subClass) then
			g.counts.observations = g.counts.observations + (o.n or 1)
			g.typeText = g.typeText or o.typeText
			if o.usable == nil then g.counts.unknown = g.counts.unknown + 1
			else
				if o.usable then g.counts.yes = g.counts.yes + 1 else g.counts.no = g.counts.no + 1 end
				if P.ignoreConfounded and #o.confounds > 0 then
					g.counts.confounded = g.counts.confounded + 1
				else
					local L = o.level
					local id = o.itemId or ("?" .. o.fp)
					if o.usable then
						rawYes[L] = rawYes[L] or o
						if o.source == "worn_item" then yesWorn[L] = yesWorn[L] or {}; yesWorn[L][id] = true
						else yesClient[L] = yesClient[L] or {}; yesClient[L][id] = true end
					else
						rawNo[L] = rawNo[L] or o
						noClient[L] = noClient[L] or {}; noClient[L][id] = true
					end
					if o.itemId then
						local k = o.itemId .. "@" .. L
						local seen = byItemLevel[k]
						if seen == nil then byItemLevel[k] = o.usable elseif seen ~= o.usable then g.conflicts[#g.conflicts + 1] = { kind = "same item, same level, both results", item = o.itemId, level = L } end
					end
				end
			end
		end
	end
	-- proven levels under the policy
	for L in pairs(rawYes) do
		if distinct(yesWorn[L] or {}) >= P.yesWorn or distinct(yesClient[L] or {}) >= P.yesClient then g.yesLevels[L] = true end
	end
	for L in pairs(rawNo) do
		if distinct(noClient[L] or {}) >= P.noClient then g.noLevels[L] = true end
	end
	for L in pairs(g.yesLevels) do if not g.yesAt or L < g.yesAt then g.yesAt = L end end
	for L in pairs(g.noLevels) do if not g.noAt or L > g.noAt then g.noAt = L end end
	-- monotonic conflicts: an unconfounded NO at a level at or above an unconfounded YES
	local minRawYes
	for L in pairs(rawYes) do if not minRawYes or L < minRawYes then minRawYes = L end end
	if minRawYes then
		for L in pairs(rawNo) do
			if L >= minRawYes then g.conflicts[#g.conflicts + 1] = { kind = "not usable at a level at or above one where it was usable", yesLevel = minRawYes, noLevel = L } end
		end
	end
	if #g.conflicts > 0 then g.evidenceState = "CONFLICT"
	elseif g.yesAt or g.noAt then g.evidenceState = "PROVEN"
	elseif g.counts.observations > 0 then g.evidenceState = "OBSERVED"
	else g.evidenceState = "UNKNOWN" end
	return g
end

--- The answer Eligibility asks for: can a <class> character at <level> use items of this type?
--   { state = PROVEN_YES | PROVEN_NO | UNKNOWN | CONFLICT, evidenceState, unlockLevel (only when exact), unlockAtMost, bounds = { noAt, yesAt }, evidenceCount, source, reason }
-- UNKNOWN is the default and the right answer whenever the policy is not met. Missing arguments give UNKNOWN. Recording evidence never raises certainty by itself.
function Ev.GetProficiency(class, itemClass, subClass, level)
	local out = { state = "UNKNOWN", source = "observed_client", evidenceCount = 0 }
	if type(class) ~= "string" or type(itemClass) ~= "number" or type(subClass) ~= "number" or type(level) ~= "number" then
		out.reason = "class, item type or level not known"
		out.evidenceState = "UNKNOWN"
		return out
	end
	local g = Ev.Group(class, itemClass, subClass)
	out.evidenceCount, out.evidenceState, out.bounds = g.counts.observations, g.evidenceState, { noAt = g.noAt, yesAt = g.yesAt }
	if g.evidenceState == "CONFLICT" then
		out.state = "CONFLICT"
		out.reason = string.format("%d conflict(s) among the recorded Forever observations (e.g. %s)", #g.conflicts, g.conflicts[1].kind)
		out.conflicts = g.conflicts
		return out
	end
	if g.noAt and g.yesAt and g.yesAt == g.noAt + 1 then out.unlockLevel = g.yesAt end
	if g.yesAt and level >= g.yesAt then
		out.state = "PROVEN_YES"
		out.unlockAtMost = g.yesAt
		out.reason = string.format("usable at level %d was proven by recorded Forever observations", g.yesAt)
	elseif g.noAt and level <= g.noAt then
		out.state = "PROVEN_NO"
		out.reason = string.format("not usable at level %d was proven by recorded Forever observations%s", g.noAt, out.unlockLevel and (", and usable from level " .. out.unlockLevel) or ", unlock level not proven")
	else
		out.state = "UNKNOWN"
		if g.counts.observations == 0 then out.reason = "No proven Forever client evidence"
		else out.reason = string.format("%d observation(s) recorded, not enough to prove an answer at level %d under the evidence policy", g.counts.observations, level) end
	end
	return out
end

-- ---------------------------------------------------------------- diagnostics

--- All (class, item class, item subclass) groups that have observations, as Ev.Group summaries.
function Ev.Groups()
	local seen, out = {}, {}
	for _, o in ipairs(Ev.Observations()) do
		local k = o.class .. "|" .. o.itemClass .. "|" .. o.subClass
		if not seen[k] then seen[k] = true; out[#out + 1] = Ev.Group(o.class, o.itemClass, o.subClass) end
	end
	table.sort(out, function(a, b) return a.class .. a.itemClass .. a.subClass < b.class .. b.itemClass .. b.subClass end)
	return out
end

--- Totals for the report: { active, observations (records), repeats, groups, proven (groups with a proven answer), conflicts (groups), noResult, skipped = { reason = n }, signals }.
function Ev.Status()
	local s = store()
	local st = { active = s ~= nil, observations = 0, repeats = 0, groups = 0, proven = 0, conflicts = 0, noResult = 0, skipped = s and s.skips or {} }
	if not s then return st end
	st.observations = #s.obs
	for _, o in ipairs(s.obs) do
		if (o.n or 1) > 1 then st.repeats = st.repeats + (o.n - 1) end
		if o.usable == nil then st.noResult = st.noResult + 1 end
	end
	for _, g in ipairs(Ev.Groups()) do
		st.groups = st.groups + 1
		if g.evidenceState == "PROVEN" then st.proven = st.proven + 1 elseif g.evidenceState == "CONFLICT" then st.conflicts = st.conflicts + 1 end
	end
	return st
end

--- The client functions this recorder relies on. AVAILABILITY only, from the same resolver the item readers use (Items.Resolve, which tries the namespace form such
-- as C_Item.IsUsableItem and then the global): { name, label, state = "PRESENT" | "ABSENT", via }. PRESENT means a function with that name exists right now; it does NOT
-- mean it was read successfully (that is ItemProbe's PROVEN / UNPROVEN / FAILED) and it does NOT mean its answers are reliable (a separate question).
-- Without Items (it is not a hard dependency) only the global form can be checked and `via` says so.
function Ev.Signals()
	local function look(name, label, group)
		local via
		if ns.Items and ns.Items.Resolve and ns.Items.API[name] then
			local fn, v = ns.Items.Resolve(name)
			if fn then via = v end
		elseif type(_G[name]) == "function" then
			via = name
		end
		return { name = name, label = label, group = group, state = via and "PRESENT" or "ABSENT", via = via }
	end
	return {
		look("IsUsableItem", "IsUsableItem", "usability"), look("GetQuestItemInfo", "GetQuestItemInfo (reward dialog usable flag)", "usability"),
		look("GetInventoryItemLink", "GetInventoryItemLink (worn items)", "worn"), look("UnitClass", "UnitClass", "character"), look("UnitLevel", "UnitLevel", "character"),
		look("UnitRace", "UnitRace", "character"), look("GetNumSkillLines", "GetNumSkillLines (skill lines)", "skills"), look("GetSkillLineInfo", "GetSkillLineInfo (skill lines)", "skills"),
		notProbed = { "IsSpellKnown for proficiency spells (their Forever spell ids are unproven)" },
	}
end

--- Compact lines for /codex report (never a dump of observations). extra = optional lines appended by the caller (event status); opts.observed(name) = optional
-- function returning the caller's own observation of a signal (for example ItemProbe's "PROVEN"), shown next to its availability.
function Ev.ReportLines(extra, opts)
	local L = {}
	local st = Ev.Status()
	L[#L + 1] = "ELIGIBILITY EVIDENCE (what the Forever client let this character use; observations are not proven rules)"
	if not st.active then
		L[#L + 1] = "  recording: unavailable (no saved variable)"
		return L
	end
	local skipped = {}
	for r, n in pairs(st.skipped) do skipped[#skipped + 1] = n .. " " .. r end
	table.sort(skipped)
	L[#L + 1] = string.format("  recording: active | observations %d (repeats merged %d) | groups %d | proven answers %d | conflicts %d | observations with no usable result %d | not recorded: %s",
		st.observations, st.repeats, st.groups, st.proven, st.conflicts, st.noResult, #skipped > 0 and table.concat(skipped, ", ") or "none")
	local P = Ev.POLICY
	L[#L + 1] = string.format("  policy v%d: YES needs %d worn item or %d client-flagged items at that level; NO needs %d client-flagged items at that level; an item above the character's level is never counted",
		P.version, P.yesWorn, P.yesClient, P.noClient)
	-- signals: three different questions, kept apart: is the function there (availability), was it read successfully (the caller's observation), can its answers be trusted
	local sg = Ev.Signals()
	local present, absent = {}, {}
	for _, x in ipairs(sg) do
		if x.state == "PRESENT" then present[#present + 1] = x.label .. " via " .. x.via else absent[#absent + 1] = x.label end
	end
	L[#L + 1] = "  client functions present: " .. (#present > 0 and table.concat(present, "; ") or "none")
	L[#L + 1] = "  client functions absent (not found as " .. "a namespace function or a global): " .. (#absent > 0 and table.concat(absent, "; ") or "none") .. " | not probed: " .. table.concat(sg.notProbed, "; ")
	local u
	for _, x in ipairs(sg) do if x.name == "IsUsableItem" then u = x end end
	if u then
		local read = opts and opts.observed and opts.observed("IsUsableItem")
		L[#L + 1] = string.format("  IsUsableItem: availability %s%s | reads: %s | reliability: not trusted alone (%d recorded observation(s) had client answers that did not agree)",
			u.state, u.via and (" (" .. u.via .. ")") or "", read or "not reported here", st.noResult)
	end
	for i, g in ipairs(Ev.Groups()) do
		if i > 6 then L[#L + 1] = "  + " .. (#Ev.Groups() - 6) .. " more group(s)"; break end
		L[#L + 1] = string.format("  %s %s: %s | observations %d (usable %d, not usable %d, unknown %d, not counted %d)%s%s", g.class, g.typeText or (g.itemClass .. "/" .. g.subClass), g.evidenceState,
			g.counts.observations, g.counts.yes, g.counts.no, g.counts.unknown, g.counts.confounded, g.yesAt and (" | proven usable from level " .. g.yesAt .. " or lower") or "", g.noAt and (" | proven not usable at level " .. g.noAt) or "")
	end
	for _, l in ipairs(extra or {}) do L[#L + 1] = l end
	return L
end

--- Every observation, one per line, for detailed inspection (not part of the normal report). limit defaults to 50 (newest last).
function Ev.Dump(limit)
	local L, obs = {}, Ev.Observations()
	limit = limit or 50
	for i = math.max(1, #obs - limit + 1), #obs do
		local o = obs[i]
		L[#L + 1] = string.format("%s L%d %s %s item %s req %s -> %s [%s, %s] x%d build %s %s", o.class, o.level, o.race or "?", o.typeText or "?", tostring(o.itemId), tostring(o.requiredLevel),
			o.usable == nil and "NO RESULT" or tostring(o.usable), o.source, o.state, o.n or 1, tostring(o.build), #o.confounds > 0 and ("not counted: " .. table.concat(o.confounds, ", ")) or "")
	end
	return L
end
