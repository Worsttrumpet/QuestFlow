-- ForeverCodex.Eligibility: "can this character use this item, and if not, will they be able to soon?" It is its own layer, below the Reward Advisor and
-- independent of it, so other systems (a future opportunity system, for example) can ask "this item becomes useful at level 40" without knowing anything about
-- rewards.
--
--   ItemFacts -> Eligibility (current / future) -> Gear comparison -> Advisor classification -> Recommendation
--
-- Two separate answers, never one boolean:
--   current   PROVEN_YES | PROVEN_NO | UNKNOWN          can the character use it NOW
--   future    NOT_RELEVANT | SOON | LATER | UNKNOWN      if not now, does that change, and is it close enough to matter
-- "You cannot use this" and "you cannot use this yet" are different results. A future answer says nothing about whether to take or keep the item.
--
-- Evidence, in the order it is weighed (each check keeps its own state and source):
--   level          the item's required level (a client fact) against the character's level
--   proficiency    can this class use this armor / weapon type at this level. There is NO built-in class -> armor table. Evidence comes from
--                  (a) items of the same type the character is wearing right now (the game let them equip it), and (b) registered evidence records
--                  (Eligibility.AddEvidence). Standard Classic rules are kept only as a labelled REFERENCE (proven = false): they produce a hint in the
--                  diagnostics and are NEVER used to decide. Forever evidence wins; with none, the answer is UNKNOWN.
--   restrictions   explicit class / race / faction requirements, only when ItemFacts carries them (facts.requirements; nothing reads them from the client yet)
--   client         the client's own usability answers (IsUsableItem and the reward dialog's flag, kept side by side). IsUsableItem alone is never trusted.
-- A proven failure (a class restriction, a level the character has not reached) overrides everything else. UNKNOWN stays UNKNOWN: it is never turned into yes or no.
-- Read-only; independent of the planner, strategies, presenter, UI and the Reward Advisor.

local addonName, ns = ...

local E = {}
ns.Eligibility = E

-- PROPOSED, untuned: how many levels away still counts as "soon".
E.SOON_LEVELS = 2

-- ---------------------------------------------------------------- the character (the existing Context reader, not a second one)

--- { level, classToken, raceToken, faction, missing } from the existing Context character reader (or `override` fields merged over it).
function E.Character(override)
	local c = {}
	local reader = ns.Context and ns.Context.DefaultReader and ns.Context.DefaultReader.character
	if reader then
		local ok, r = pcall(reader)
		if ok and type(r) == "table" then c = { level = r.level, classToken = r.classToken, raceToken = r.raceToken, faction = r.faction, missing = r.missing } end
	end
	for k, v in pairs(override or {}) do c[k] = v end
	return c
end

-- ---------------------------------------------------------------- proficiency evidence

local reference, added = {}, {}

-- STANDARD CLASSIC RULES, as a reference only (proven = false): the Forever client may differ, so these are never used to decide anything. They appear in the
-- diagnostics as a hint next to an UNKNOWN. Only the entries stated for this project are listed.
local function ref(class, subClass, minLevel) reference[#reference + 1] = { class = class, itemClass = 4, subClass = subClass, minLevel = minLevel, proven = false, src = "Classic reference (not proven on Forever)" } end
ref("SHAMAN", 3, 40); ref("HUNTER", 3, 40); ref("WARRIOR", 4, 40); ref("PALADIN", 4, 40)

--- Registers a piece of proficiency evidence: { class = "SHAMAN", itemClass = 4, subClass = 3, minLevel = 40 | nil, never = boolean, proven = boolean, src = "..." }.
-- Only proven = true evidence decides anything. Nothing registers evidence by itself yet (a later step can record what the client actually allows at each level).
function E.AddEvidence(rec) added[#added + 1] = rec end
function E.ClearEvidence() added = {} end
function E.Evidence() return added, reference end

local function matching(list, class, itemClass, subClass)
	local out = {}
	for _, r in ipairs(list) do
		if r.class == class and r.itemClass == itemClass and r.subClass == subClass then out[#out + 1] = r end
	end
	return out
end

-- ---------------------------------------------------------------- client usability evidence (moved here from the advisor; the advisor delegates)

--- The client's usability answers side by side: IsUsableItem (never trusted alone on Forever: it returned false for items the dialog flagged usable) and the
-- reward dialog's own flag (the 5th GetQuestItemInfo value; its exact meaning is itself unproven). verdict: USABLE (both true), NOT_USABLE (both false),
-- CONFLICT (they disagree), UNKNOWN (no second source, or nothing readable). Returns { verdict, sources = { { name, value } }, reason }.
function E.ClientUsability(facts)
	local out = { sources = {} }
	local u = facts and facts.fields and facts.fields.usable
	local flag = facts and facts.offered and facts.offered.dialogFlag
	if u and u.state == "PROVEN" then out.sources[#out.sources + 1] = { name = "IsUsableItem", value = u.value, second = u.second } end
	if type(flag) == "boolean" then out.sources[#out.sources + 1] = { name = "reward dialog flag", value = flag } end
	local isU = u and u.state == "PROVEN" and u.value
	if type(flag) ~= "boolean" then
		out.verdict = "UNKNOWN"
		if u and u.state == "PROVEN" then out.reason = "only IsUsableItem answered (" .. tostring(u.value) .. "); Codex does not trust it alone on Forever"
		else out.reason = "no usable evidence: IsUsableItem is " .. (u and (u.state .. (u.reason and (" (" .. u.reason .. ")") or "")) or "not read") end
		return out
	end
	if not (u and u.state == "PROVEN") then
		out.verdict = "UNKNOWN"
		out.reason = "the dialog flag is " .. tostring(flag) .. " but IsUsableItem is " .. (u and u.state or "not read")
		return out
	end
	if flag == true and isU == true then out.verdict, out.reason = "USABLE", "IsUsableItem and the reward dialog flag both say true"
	elseif flag == false and isU == false then out.verdict, out.reason = "NOT_USABLE", "IsUsableItem and the reward dialog flag both say false"
	else out.verdict, out.reason = "CONFLICT", string.format("IsUsableItem says %s but the reward dialog flag says %s", tostring(isU), tostring(flag)) end
	return out
end

-- ---------------------------------------------------------------- the checks

local function check(state, detail, extra)
	local c = { state = state, detail = detail }
	if extra then for k, v in pairs(extra) do c[k] = v end end
	return c
end

local function fieldWord(f) return f.state .. (f.reason and (" (" .. f.reason .. ")") or "") end

-- level: the item's required level against the character's level
local function levelCheck(facts, char)
	local req = facts.fields.requiredLevel
	if req.state ~= "PROVEN" then return check("UNKNOWN", "the item's required level is " .. fieldWord(req)) end
	if type(char.level) ~= "number" then return check("UNKNOWN", "the character's level is not known") end
	if char.level >= req.value then return check("YES", string.format("requires level %d, the character is level %d", req.value, char.level), { requires = req.value, src = req.src }) end
	return check("NO", string.format("requires level %d, the character is level %d", req.value, char.level), { unlock = req.value, requires = req.value, src = req.src })
end

-- proficiency: only for armor types and weapons; evidence from worn gear, then registered proven evidence; reference rules are a hint only
local function applicable(classID, sub)
	if classID == 2 then return type(sub) == "number" end
	if classID == 4 then return type(sub) == "number" and ((sub >= 1 and sub <= 4) or sub == 6) end
	return false
end

local function proficiencyCheck(facts, char, equipped)
	local cls, sub = facts.fields.class, facts.fields.subclass
	if cls.state ~= "PROVEN" or sub.state ~= "PROVEN" then
		return check("UNKNOWN", "the item's type is not known yet (" .. (cls.state ~= "PROVEN" and ("class " .. fieldWord(cls)) or ("subclass " .. fieldWord(sub))) .. ")")
	end
	if not applicable(cls.value, sub.value) then return check("NOT_APPLICABLE", "this kind of item has no armor or weapon proficiency") end
	local text = (cls.text or tostring(cls.value)) .. "/" .. (sub.text or tostring(sub.value))
	-- (a) the same type is being worn right now: the game allowed it
	if equipped and equipped.slots then
		for slot, e in pairs(equipped.slots) do
			if slot ~= 4 and slot ~= 19 and e.state == "POPULATED" and e.itemFacts and e.itemFacts.fields then
				local ec, es = e.itemFacts.fields.class, e.itemFacts.fields.subclass
				if ec and es and ec.state == "PROVEN" and es.state == "PROVEN" and ec.value == cls.value and es.value == sub.value then
					return check("YES", text .. " is already worn in slot " .. slot .. " (the game allowed it)", { src = "worn item of the same type", proven = true })
				end
			end
		end
	end
	if not char.classToken then return check("UNKNOWN", "the character's class is not known") end
	-- (b) registered evidence
	for _, r in ipairs(matching(added, char.classToken, cls.value, sub.value)) do
		if r.proven == true then
			if r.never then return check("NO", text .. " can never be used by " .. char.classToken, { permanent = true, src = r.src, proven = true }) end
			if type(r.minLevel) == "number" and type(char.level) == "number" then
				if char.level >= r.minLevel then return check("YES", string.format("%s is usable from level %d (%s)", text, r.minLevel, tostring(r.src)), { src = r.src, proven = true }) end
				return check("NO", string.format("%s becomes usable at level %d, the character is level %d (%s)", text, r.minLevel, char.level, tostring(r.src)), { unlock = r.minLevel, src = r.src, proven = true })
			end
		end
	end
	-- (c) observations recorded from the real client (EligibilityEvidence): used only when its policy proves an answer; a conflict stays UNKNOWN
	local recorded
	local EE = ns.EligibilityEvidence
	if EE and type(char.level) == "number" then
		recorded = EE.GetProficiency(char.classToken, cls.value, sub.value, char.level)
		if recorded.state == "PROVEN_YES" then
			return check("YES", text .. " is usable at this level: " .. recorded.reason, { src = "recorded Forever observations", proven = true, evidence = recorded })
		elseif recorded.state == "PROVEN_NO" then
			return check("NO", text .. " is not usable at level " .. char.level .. ": " .. recorded.reason, { unlock = recorded.unlockLevel, src = "recorded Forever observations", proven = true, evidence = recorded })
		elseif recorded.state == "CONFLICT" then
			return check("UNKNOWN", text .. " proficiency: " .. recorded.reason, { evidence = recorded })
		end
	end
	-- nothing proven: UNKNOWN, with the Classic reference shown as a hint only
	local hint
	for _, r in ipairs(matching(reference, char.classToken, cls.value, sub.value)) do hint = { minLevel = r.minLevel, src = r.src } end
	return check("UNKNOWN", text .. " proficiency for " .. char.classToken .. " is not established on Forever", { referenceHint = hint, evidence = recorded })
end

-- explicit restrictions, only when ItemFacts carries them (facts.requirements = { classes = {tokens}, races = {tokens}, faction = "Horde", src })
local function restrictionChecks(facts, char, opts)
	local req = facts.requirements or (opts and opts.requirements)
	local out = { class = check("NOT_READ", "no explicit class requirement was read"), race = check("NOT_READ", "no explicit race requirement was read"), faction = check("NOT_READ", "no explicit faction requirement was read") }
	if not req then return out end
	local function listCheck(list, value, label)
		if type(list) ~= "table" then return nil end
		if not value then return check("UNKNOWN", "the character's " .. label .. " is not known") end
		for _, v in ipairs(list) do if v == value then return check("YES", "the item allows " .. value, { src = req.src }) end end
		return check("NO", string.format("the item is restricted to %s; the character is %s", table.concat(list, ", "), value), { permanent = true, src = req.src, proven = true })
	end
	out.class = listCheck(req.classes, char.classToken, "class") or out.class
	out.race = listCheck(req.races, char.raceToken, "race") or out.race
	if type(req.faction) == "string" then
		if not char.faction then out.faction = check("UNKNOWN", "the character's faction is not known")
		elseif req.faction == char.faction then out.faction = check("YES", "the item allows " .. char.faction, { src = req.src })
		else out.faction = check("NO", string.format("the item is for %s; the character is %s", req.faction, char.faction), { permanent = true, src = req.src, proven = true }) end
	end
	return out
end

-- ---------------------------------------------------------------- the evaluation

--- Evaluates one item for one character.
--   facts      normalized ItemFacts (Items.Facts / ItemProbe.DialogFacts); facts.offered.dialogFlag and facts.requirements are used when present
--   character  { level, classToken, raceToken, faction } (E.Character() when nil)
--   opts       { equipped = a Gear.Equipped() result (worn items are proficiency evidence), requirements = explicit restrictions }
-- Returns { schema, current = { state, blockers, conflicts }, future = { state, unlockLevel, levelsAway, basis, reason, referenceHint },
--           checks = { level, proficiency, class, race, faction, client }, character, caveats }.
function E.Evaluate(facts, character, opts)
	opts = opts or {}
	local char = character or E.Character()
	local out = { schema = 1, character = char, caveats = {}, checks = {}, current = { blockers = {}, conflicts = {} }, future = {} }
	if not (facts and facts.fields) then
		out.current.state, out.future.state = "UNKNOWN", "UNKNOWN"
		out.future.reason = "no item facts"
		return out
	end
	local ck = out.checks
	ck.level = levelCheck(facts, char)
	ck.proficiency = proficiencyCheck(facts, char, opts.equipped)
	local rc = restrictionChecks(facts, char, opts)
	ck.class, ck.race, ck.faction = rc.class, rc.race, rc.faction
	local cu = E.ClientUsability(facts)
	out.clientUsability = cu
	ck.client = check(cu.verdict == "USABLE" and "YES" or (cu.verdict == "NOT_USABLE" and "NO" or "UNKNOWN"), cu.reason, { verdict = cu.verdict })

	-- current: a proven failure of any identified requirement overrides everything
	local cur = out.current
	for _, name in ipairs({ "class", "race", "faction", "level", "proficiency" }) do
		if ck[name].state == "NO" then cur.blockers[#cur.blockers + 1] = { check = name, detail = ck[name].detail, unlock = ck[name].unlock, permanent = ck[name].permanent, src = ck[name].src, proven = ck[name].proven } end
	end
	if #cur.blockers > 0 then
		cur.state = "PROVEN_NO"
		if ck.client.state == "YES" then cur.conflicts[#cur.conflicts + 1] = "the client's usability answers say usable, but " .. cur.blockers[1].detail end
	elseif ck.client.state == "NO" then
		cur.state = "PROVEN_NO"
		cur.blockers[1] = { check = "client", detail = cu.reason .. " (the reason is not identified)", unlock = nil, src = "client usability evidence" }
	elseif ck.client.state == "YES" then
		cur.state = "PROVEN_YES"
	elseif ck.proficiency.state == "YES" and ck.level.state == "YES" and cu.verdict ~= "CONFLICT"
		and ck.class.state ~= "UNKNOWN" and ck.race.state ~= "UNKNOWN" and ck.faction.state ~= "UNKNOWN" then
		cur.state = "PROVEN_YES"
	elseif ck.proficiency.state == "NOT_APPLICABLE" and ck.level.state == "YES" and cu.verdict ~= "CONFLICT" and cu.verdict ~= "UNKNOWN" then
		cur.state = "PROVEN_YES"
	else
		cur.state = "UNKNOWN"
	end
	if ck.class.state == "NOT_READ" and ck.race.state == "NOT_READ" then out.caveats[#out.caveats + 1] = "explicit class / race requirements were not read" end

	-- future
	local fut = out.future
	fut.basis = {}
	if cur.state == "PROVEN_YES" then
		fut.state, fut.reason = "NOT_RELEVANT", "already usable now"
	elseif cur.state == "UNKNOWN" then
		fut.state = "UNKNOWN"
		local why = {}
		for _, name in ipairs({ "level", "proficiency", "client" }) do if ck[name].state == "UNKNOWN" then why[#why + 1] = name .. ": " .. ck[name].detail end end
		fut.reason = "current eligibility is not established" .. (#why > 0 and (" (" .. table.concat(why, "; ") .. ")") or "")
		if ck.proficiency.referenceHint then fut.referenceHint = ck.proficiency.referenceHint end
	else
		-- PROVEN_NO: permanent, unlockable, or of unknown timing
		local permanent, unlockLevel, unknownUnlock = nil, nil, false
		for _, b in ipairs(cur.blockers) do
			if b.permanent then permanent = b end
			if b.unlock then
				unlockLevel = math.max(unlockLevel or 0, b.unlock)
				fut.basis[#fut.basis + 1] = { check = b.check, unlock = b.unlock, src = b.src, proven = b.proven }
			elseif not b.permanent then
				unknownUnlock = true
			end
		end
		-- another requirement that is not known can still keep the item unusable after the known one is met
		local pending = {}
		if ck.proficiency.state == "UNKNOWN" then pending[#pending + 1] = "proficiency: " .. ck.proficiency.detail end
		if ck.level.state == "UNKNOWN" then pending[#pending + 1] = "level: " .. ck.level.detail end
		if permanent then
			fut.state, fut.reason = "NOT_RELEVANT", "never usable by this character: " .. permanent.detail
		elseif unknownUnlock and not unlockLevel then
			fut.state = "UNKNOWN"
			fut.reason = "the client says the item is not usable, but nothing identifies what would change that"
			if ck.proficiency.referenceHint then fut.referenceHint = ck.proficiency.referenceHint end
		elseif #pending > 0 then
			fut.state = "UNKNOWN"
			fut.reason = "one requirement is known (unlocks at level " .. tostring(unlockLevel) .. ") but another is not: " .. table.concat(pending, "; ")
			fut.unlockLevel = unlockLevel
			if ck.proficiency.referenceHint then fut.referenceHint = ck.proficiency.referenceHint end
		elseif unlockLevel and type(char.level) == "number" then
			fut.unlockLevel, fut.levelsAway = unlockLevel, unlockLevel - char.level
			fut.state = (fut.levelsAway <= E.SOON_LEVELS) and "SOON" or "LATER"
			local parts = {}
			for _, b in ipairs(cur.blockers) do if b.unlock then parts[#parts + 1] = b.detail end end
			fut.reason = string.format("usable from level %d (%d level(s) away): %s", unlockLevel, fut.levelsAway, table.concat(parts, "; "))
		else
			fut.state, fut.reason = "UNKNOWN", "the unlock level could not be established"
		end
	end
	return out
end

--- A one-line description of both answers: "now PROVEN_NO | future SOON (level 40, 1 level(s) away)".
function E.Describe(e)
	local f = e.future
	local s = "now " .. tostring(e.current.state) .. " | future " .. tostring(f.state)
	if f.state == "SOON" or f.state == "LATER" then s = s .. string.format(" (level %d, %d level(s) away)", f.unlockLevel, f.levelsAway) end
	if f.referenceHint then s = s .. string.format(" | Classic reference only: level %s (not proven on Forever)", tostring(f.referenceHint.minLevel)) end
	return s
end
