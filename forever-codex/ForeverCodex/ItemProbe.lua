-- ForeverCodex.ItemProbe: Stage 0 of the Reward Advisor. A READ-ONLY probe that answers one question: what item and reward information does the
-- real Forever client actually expose to Codex? It gives no advice, scores nothing, recommends nothing and does not touch the planner.
--
--   * PROBE: each field of interest (reward item id / name / link, item info, stats, equip slot, ...) keeps a small tally in the SavedVariable
--     (ForeverCodexDB.items.proof): how many real values were read, how many reads failed, how many resolved late, a short sample, the build.
--         PROVEN    a real value was read on this client at least once (an API merely existing is never enough)
--         FAILED    the API is absent, errored, or returned nothing on every try
--         UNPROVEN  not tried yet, or tried but there was nothing to read (for example no weapon was sampled yet)
--     A field that was read but only after a retry says so ("late"): item data loads asynchronously on this client.
--   * REWARD CACHE: every quest reward dialog Codex sees (QUEST_DETAIL and QUEST_COMPLETE) is stored as an observation with
--     src = CODEX_OBSERVED, so Codex can later say "I saw this Forever quest offer this reward". Minimal by design; nothing reads it yet.
--   * EVENTS: the item-related client events are registered and counted (with their first arguments) as UNPROVEN until they fire.
--
-- Independent of the planner, strategies, registry and UI. The only consumer is the item section of /codex report (ReportLines).

local addonName, ns = ...

local P = {}
ns.ItemProbe = P

local I = ns.Items

P.SCHEMA = 1
P.MAX_QUESTS = 500             -- reward observations kept (the oldest is dropped beyond this)
P.MAX_BAG_SAMPLES = 8          -- bag items whose item info is read per probe
P.RETRIES = 3                  -- late-resolution attempts for an item that read blank
P.RETRY_SECONDS = 2

--- The fields reported, in report order. group: reward / item / character.
P.FIELDS = {
	{ key = "questId",     group = "reward",    label = "Quest id (GetQuestID)" },
	{ key = "rewardCounts", group = "reward",   label = "Reward counts" },
	{ key = "rewardInfo",  group = "reward",    label = "Reward item name" },
	{ key = "rewardId",    group = "reward",    label = "Reward item id" },
	{ key = "rewardLink",  group = "reward",    label = "Reward item link" },
	{ key = "itemInfo",    group = "item",      label = "Item info" },
	{ key = "itemInstant", group = "item",      label = "Item info (instant)" },
	{ key = "itemClass",   group = "item",      label = "Item class / subclass" },
	{ key = "itemLevel",   group = "item",      label = "Item level" },
	{ key = "equipSlot",   group = "item",      label = "Equip slot" },
	{ key = "requiredLevel", group = "item",    label = "Required level" },
	{ key = "vendorValue", group = "item",      label = "Vendor value" },
	{ key = "itemStats",   group = "item",      label = "Item stats" },
	{ key = "usable",      group = "item",      label = "Usable (IsUsableItem)" },
	{ key = "useEffect",   group = "item",      label = "Use effect" },
	{ key = "weaponInfo",  group = "item",      label = "Weapon info (type + dps)" },
	{ key = "itemCount",   group = "item",      label = "Item count" },
	{ key = "equipped",    group = "character", label = "Equipped items" },
	{ key = "bags",        group = "character", label = "Bag items" },
	{ key = "skills",      group = "character", label = "Skill lines" },
	{ key = "weaponSkill", group = "character", label = "Weapon skill lines" },
}

--- The item events watched (registered as UNPROVEN until each fires). Only the reward-dialog events and the late-data event cause any work.
P.EVENTS = { "QUEST_DETAIL", "QUEST_COMPLETE", "QUEST_ITEM_UPDATE", "GET_ITEM_INFO_RECEIVED", "PLAYER_EQUIPMENT_CHANGED", "BAG_UPDATE_DELAYED", "SKILL_LINES_CHANGED" }

-- English weapon skill names (a localized client will not match: the sample line shows what the client really reports)
local WEAPON_SKILLS = { "swords", "two-handed swords", "axes", "two-handed axes", "maces", "two-handed maces", "daggers", "staves", "polearms",
	"fist weapons", "bows", "guns", "crossbows", "wands", "thrown", "unarmed" }

local frame = CreateFrame("Frame")
local registered = {}
local pending = {}                 -- late-resolution queue: { qid, kind, index, ref, tries }
local timerArmed = false
P.last = {}                        -- the latest character probe (memory only): { equipped, bagItems, sampled }

local function build()
	local ok, _, b = pcall(GetBuildInfo)
	return ok and b or nil
end

local function wall() return type(time) == "function" and time() or 0 end

local function store()
	if type(ForeverCodexDB) ~= "table" then return nil end
	local s = ForeverCodexDB.items
	if type(s) ~= "table" then
		s = {}
		ForeverCodexDB.items = s
	end
	if s.v == nil then s.v = P.SCHEMA end
	s.proof = type(s.proof) == "table" and s.proof or {}
	s.events = type(s.events) == "table" and s.events or {}
	s.rewards = type(s.rewards) == "table" and s.rewards or {}
	s.dialogs = type(s.dialogs) == "number" and s.dialogs or 0
	return s
end

-- ---------------------------------------------------------------- proof tallies

--- outcome "ok" (a real value, `sample` says what), "fail" (`why` says why) or "none" (the call worked but there was nothing to read).
local function note(key, outcome, sample, why)
	local s = store()
	if not s then return end
	local e = s.proof[key]
	if type(e) ~= "table" then e = {}; s.proof[key] = e end
	e.n = (e.n or 0) + 1
	if outcome == "ok" then
		e.ok = (e.ok or 0) + 1
		if sample ~= nil then e.s = tostring(sample):sub(1, 90) end
		e.b = build()
	elseif outcome == "fail" then
		e.fail = (e.fail or 0) + 1
		e.f = tostring(why or "failed"):sub(1, 90)
	else
		e.none = (e.none or 0) + 1
	end
end

local function noteLate(key)
	local s = store()
	if not s then return end
	local e = s.proof[key]
	if type(e) == "table" then e.late = (e.late or 0) + 1 end
end

--- "PROVEN" / "FAILED" / "UNPROVEN", and a short detail line, for one field.
function P.Status(key)
	local s = store()
	local e = s and s.proof[key]
	if type(e) ~= "table" or (e.n or 0) == 0 then return "UNPROVEN", "not tried yet" end
	if (e.ok or 0) > 0 then
		local d = e.s or "read"
		if (e.late or 0) > 0 then d = d .. " | late x" .. e.late end
		if (e.fail or 0) > 0 then d = d .. " | failed x" .. e.fail .. (e.f and (": " .. e.f) or "") end
		return "PROVEN", d
	end
	if (e.fail or 0) > 0 then return "FAILED", e.f or "failed" end
	return "UNPROVEN", string.format("tried %d, nothing to read yet", e.n)
end

-- ---------------------------------------------------------------- one item's facts -> field tallies

local function equippableClass(c) return c == 2 or c == 4 end

local function statSample(stats)
	local keys = {}
	for k in pairs(stats) do keys[#keys + 1] = tostring(k):gsub("^ITEM_MOD_", ""):gsub("_SHORT$", "") end
	table.sort(keys)
	return #keys .. " stat(s): " .. table.concat(keys, ",", 1, math.min(#keys, 3))
end

--- Tallies one item read (the result of Items.Read) into the field tallies. Returns "unloaded" when the item data was not there yet.
local function tallyItem(facts)
	local f = facts.f
	if facts.err.info then
		note("itemInfo", "fail", nil, facts.err.info)
	else
		note("itemInfo", "ok", string.format("%s (%s/%s)", tostring(f.name), tostring(f.type), tostring(f.subType)))
	end
	if facts.err.instant then
		note("itemInstant", "fail", nil, facts.err.instant)
	else
		local x = facts.instant
		note("itemInstant", "ok", string.format("id %s class %s/%s slot %s", tostring(x.id), tostring(x.classID), tostring(x.subClassID), tostring(x.equipLoc)))
	end
	local classID = f.classID or (facts.instant and facts.instant.classID)
	local equipLoc = f.equipLoc or (facts.instant and facts.instant.equipLoc)
	if facts.unloaded then return "unloaded" end

	if type(f.classID) == "number" then note("itemClass", "ok", string.format("%s/%s (%s/%s)", tostring(f.type), tostring(f.subType), f.classID, tostring(f.subClassID)))
	else note("itemClass", "fail", nil, "no class id returned") end
	if type(f.level) == "number" then note("itemLevel", "ok", "ilvl " .. f.level) else note("itemLevel", "fail", nil, "no item level returned") end
	if type(f.minLevel) == "number" then note("requiredLevel", "ok", "requires level " .. f.minLevel) else note("requiredLevel", "fail", nil, "no required level returned") end
	if type(f.sellPrice) == "number" then note("vendorValue", "ok", I.Money(f.sellPrice)) else note("vendorValue", "fail", nil, "no sell price returned") end
	if equippableClass(classID) then
		if type(equipLoc) == "string" and equipLoc ~= "" then note("equipSlot", "ok", equipLoc) else note("equipSlot", "fail", nil, "weapon/armor with no equip location") end
		if facts.err.stats then
			note("itemStats", "fail", nil, facts.err.stats)
		elseif next(f.stats) == nil then
			note("itemStats", "fail", nil, "empty stat table for equippable gear")
		else
			note("itemStats", "ok", statSample(f.stats))
		end
	end
	if facts.err.usable then note("usable", "fail", nil, facts.err.usable) else note("usable", "ok", "usable=" .. tostring(f.usable)) end
	if facts.err.spell then note("useEffect", "fail", nil, facts.err.spell)
	elseif f.spell then note("useEffect", "ok", f.spell .. (f.spellId and (" #" .. f.spellId) or ""))
	else note("useEffect", "none") end
	if facts.err.count then note("itemCount", "fail", nil, facts.err.count) else note("itemCount", "ok", "count " .. tostring(f.count)) end
	if classID == 2 then
		local dps
		for k, v in pairs(f.stats or {}) do if tostring(k):find("DAMAGE_PER_SECOND", 1, true) and type(v) == "number" then dps = v end end
		if type(f.subType) == "string" and dps then note("weaponInfo", "ok", string.format("%s, dps %.1f", f.subType, dps))
		else note("weaponInfo", "fail", nil, "weapon without a dps stat" .. (facts.err.stats and (" (" .. facts.err.stats .. ")") or "")) end
	end
	return "loaded"
end

--- The small stored form of an item's facts (only values the client returned).
local function compact(facts)
	local f = facts.f
	if facts.unloaded or facts.err.info then return nil end
	return { cls = f.classID, sub = f.subClassID, ilvl = f.level, slot = f.equipLoc, minLvl = f.minLevel, sell = f.sellPrice }
end

-- ---------------------------------------------------------------- the reward dialog

local function str(v) if type(v) == "string" then return v:sub(1, 24) end return tostring(v) end

local function after(seconds, fn)
	if type(C_Timer) == "table" and type(C_Timer.After) == "function" then
		local ok = pcall(C_Timer.After, seconds, fn)
		return ok
	end
	return false
end

local function saveObservation(obs)
	local s = store()
	if not s or not obs.q then return end
	local old = s.rewards[obs.q]
	if type(old) == "table" then
		obs.first, obs.n = old.first or obs.last, (old.n or 1) + 1
	else
		obs.first, obs.n = obs.last, 1
		local count, oldestKey, oldest = 0, nil, nil
		for k, v in pairs(s.rewards) do
			count = count + 1
			if not oldest or (v.last or 0) < oldest then oldestKey, oldest = k, v.last or 0 end
		end
		if count >= P.MAX_QUESTS and oldestKey then s.rewards[oldestKey] = nil end
	end
	s.rewards[obs.q] = obs
end

local function entryUnresolved(e) return (e.name == nil or e.name == "") or e.info == nil end

local function queueRetry(qid, kind, e, ref)
	if not ref then return end
	for _, p in ipairs(pending) do if p.entry == e then return end end
	pending[#pending + 1] = { qid = qid, kind = kind, entry = e, ref = ref, tries = 0 }
end

--- Reads the open quest reward dialog and stores what was seen. event is the client event that opened or refreshed it.
function P.CaptureDialog(event)
	local s = store()
	if not s then return end
	local okQ, rq = I.Call(GetQuestID or function() end)
	local qid = okQ and type(rq[1]) == "number" and rq[1] > 0 and rq[1] or nil
	if qid then note("questId", "ok", "Q:" .. qid) elseif type(GetQuestID) ~= "function" then note("questId", "fail", nil, "api absent") else note("questId", "fail", nil, "no quest id while the dialog is open") end

	local nChoice, nReward
	if type(GetNumQuestChoices) == "function" and type(GetNumQuestRewards) == "function" then
		local ok1, r1 = I.Call(GetNumQuestChoices)
		local ok2, r2 = I.Call(GetNumQuestRewards)
		if ok1 and ok2 and type(r1[1]) == "number" and type(r2[1]) == "number" then
			nChoice, nReward = r1[1], r2[1]
			note("rewardCounts", "ok", string.format("%d choice(s), %d guaranteed", nChoice, nReward))
		else
			note("rewardCounts", "fail", nil, "count call errored or returned nothing")
		end
	else
		note("rewardCounts", "fail", nil, "api absent")
	end
	s.dialogs = s.dialogs + 1

	local obs = { src = "CODEX_OBSERVED", q = qid, at = event, last = wall(), build = build(), choices = {}, rewards = {} }
	local getInfo, getLink = type(GetQuestItemInfo) == "function" and GetQuestItemInfo, type(GetQuestItemLink) == "function" and GetQuestItemLink
	for _, spec in ipairs({ { "choice", nChoice, obs.choices }, { "reward", nReward, obs.rewards } }) do
		local kind, n, list = spec[1], spec[2] or 0, spec[3]
		for i = 1, n do
			local e = { i = i }
			-- name, texture, count, quality, usable flag, item id (the order the Forever recorder saw; the 5th value's meaning is unknown)
			if not getInfo then
				note("rewardInfo", "fail", nil, "GetQuestItemInfo absent")
			else
				local ok, r = I.Call(getInfo, kind, i)
				if not ok then
					note("rewardInfo", "fail", nil, "error: " .. r)
				else
					e.name, e.n, e.q, e.r5 = r[1], r[3], r[4], r[5]
					if type(r[1]) == "string" and r[1] ~= "" then note("rewardInfo", "ok", string.format("%s x%s q%s", str(r[1]), tostring(r[3]), tostring(r[4])))
					else note("rewardInfo", "fail", nil, "name blank/nil at first read (loads later)") end
					if type(r[6]) == "number" then e.id = r[6] end
				end
			end
			local link
			if not getLink then
				note("rewardLink", "fail", nil, "GetQuestItemLink absent")
			else
				local ok, r = I.Call(getLink, kind, i)
				if ok and type(r[1]) == "string" and r[1]:find("item:", 1, true) then link = r[1]; note("rewardLink", "ok", "item link (" .. #link .. " chars)")
				else note("rewardLink", "fail", nil, ok and "no item link returned" or ("error: " .. r)) end
			end
			local linkId = I.IdFromLink(link)
			if e.id and linkId and e.id ~= linkId then
				note("rewardId", "fail", nil, string.format("id from GetQuestItemInfo (%d) differs from the link (%d)", e.id, linkId))
			elseif e.id or linkId then
				note("rewardId", "ok", string.format("%d via %s", e.id or linkId, (e.id and linkId) and "GetQuestItemInfo and link, agree" or (e.id and "GetQuestItemInfo" or "link")))
			else
				note("rewardId", "fail", nil, "no item id from GetQuestItemInfo or the link")
			end
			e.id = e.id or linkId
			local ref = link or e.id
			if ref then
				local facts = I.Read(ref)
				local state = tallyItem(facts)
				e.info = compact(facts)
				if (e.name == nil or e.name == "") and facts.f.name then e.name = facts.f.name end
				if state == "unloaded" or entryUnresolved(e) then queueRetry(qid, kind, e, ref) end
			end
			list[#list + 1] = e
		end
	end
	-- the stored form keeps no item links (they are long and carry per-item data): only ids, names, counts and the small info table
	local stored = { src = obs.src, q = obs.q, at = obs.at, last = obs.last, build = obs.build, choices = obs.choices, rewards = obs.rewards }
	saveObservation(stored)
	if #pending > 0 then
		P.ArmRetry()
	end
	return stored
end

-- ---------------------------------------------------------------- late-loading item data

local function resolvePending()
	local keep = {}
	for _, p in ipairs(pending) do
		local e = p.entry
		local facts = I.Read(p.ref)
		local hadName = e.name ~= nil and e.name ~= ""
		local state = tallyItem(facts)
		if state == "loaded" then
			e.info = compact(facts)
			if not hadName and facts.f.name then
				e.name = facts.f.name
				note("rewardInfo", "ok", string.format("%s x%s (resolved late)", str(e.name), tostring(e.n)))
				noteLate("rewardInfo")
			end
			noteLate("itemInfo")
		else
			p.tries = p.tries + 1
			if p.tries < P.RETRIES then keep[#keep + 1] = p end
		end
	end
	pending = keep
	return #keep
end

local function onRetryTimer()
	timerArmed = false
	if #pending > 0 and resolvePending() > 0 then P.ArmRetry() end
end

function P.ArmRetry()
	if timerArmed then return end
	timerArmed = after(P.RETRY_SECONDS, onRetryTimer)
end

--- Items still waiting for their data (memory only).
function P.PendingCount() return #pending end

-- ---------------------------------------------------------------- the character

--- Reads the equipped items, a few bag items and the skill lines, and tallies them. Read-only; called when the report is made.
function P.ProbeCharacter()
	local out = { equipped = 0, bagItems = 0, sampled = 0 }
	local eq, eqErr = I.Equipped()
	if eqErr then note("equipped", "fail", nil, eqErr)
	elseif #eq == 0 then note("equipped", "none")
	else note("equipped", "ok", string.format("%d of %d slots hold an item", #eq, I.EQUIP_SLOTS)) end
	out.equipped = #eq
	for _, it in ipairs(eq) do
		tallyItem(I.Read(it.link))
		out.sampled = out.sampled + 1
	end
	local bags, bagErr = I.Bags()
	if bagErr then note("bags", "fail", nil, bagErr)
	elseif #bags == 0 then note("bags", "none")
	else note("bags", "ok", string.format("%d item stack(s) in the bags", #bags)) end
	out.bagItems = #bags
	for i = 1, math.min(#bags, P.MAX_BAG_SAMPLES) do
		tallyItem(I.Read(bags[i].link))
		out.sampled = out.sampled + 1
	end
	local lines, skErr = I.SkillLines()
	if skErr then
		note("skills", "fail", nil, skErr)
		note("weaponSkill", "fail", nil, skErr)
	else
		local names, weapons = {}, {}
		for _, l in ipairs(lines) do
			if not l.header then names[#names + 1] = l.name end
			local low = l.name:lower()
			for _, w in ipairs(WEAPON_SKILLS) do if low == w then weapons[#weapons + 1] = l.name .. (l.rank and (" " .. l.rank) or "") end end
		end
		if #lines == 0 then note("skills", "none") else note("skills", "ok", string.format("%d line(s): %s", #lines, table.concat(names, ", ", 1, math.min(#names, 4)))) end
		if #weapons > 0 then note("weaponSkill", "ok", table.concat(weapons, ", ", 1, math.min(#weapons, 4))) else note("weaponSkill", "none") end
	end
	P.last = out
	return out
end

-- ---------------------------------------------------------------- events

local function argsSample(...)
	local parts = {}
	for i = 1, math.min(select("#", ...), 4) do
		local v = select(i, ...)
		parts[#parts + 1] = type(v) .. ":" .. str(v)
	end
	return table.concat(parts, ",")
end

--- Called for every watched client event. Counts it, keeps the first arguments, and runs the reward-dialog capture or the late-data retry.
function P.OnEvent(event, ...)
	local s = store()
	if not s then return end
	local e = s.events[event]
	if type(e) ~= "table" then e = {}; s.events[event] = e end
	e.n = (e.n or 0) + 1
	e.last = wall()
	if e.n <= 3 then
		e.args = e.args or {}
		e.args[#e.args + 1] = argsSample(...)
	end
	local ok, err = pcall(function()
		if event == "QUEST_DETAIL" or event == "QUEST_COMPLETE" or event == "QUEST_ITEM_UPDATE" then
			P.CaptureDialog(event)
		elseif event == "GET_ITEM_INFO_RECEIVED" then
			if #pending > 0 then resolvePending() end
		end
	end)
	if not ok and ns.RecordError then ns.RecordError("itemprobe " .. tostring(event), err) end
end

local function registerAll()
	for _, ev in ipairs(P.EVENTS) do
		local ok = pcall(frame.RegisterEvent, frame, ev)
		registered[ev] = ok and true or false
	end
end

frame:SetScript("OnEvent", function(_, event, ...) P.OnEvent(event, ...) end)
registerAll()

-- ---------------------------------------------------------------- reward observations (read side)

--- Number of quests with at least one observed reward dialog, and the most recently seen one.
function P.RewardStats()
	local s = store()
	local n, newest = 0, nil
	if s then
		for _, v in pairs(s.rewards) do
			n = n + 1
			if not newest or (v.last or 0) >= (newest.last or 0) then newest = v end
		end
	end
	return n, newest, s and s.dialogs or 0
end

-- ---------------------------------------------------------------- the report section

local function eventStatus(ev)
	local s = store()
	local e = s and s.events[ev]
	local fired = e and e.n or 0
	if registered[ev] == false then return "FAILED", fired end
	if fired > 0 then return "PROVEN", fired end
	return "UNPROVEN", fired
end

--- The ITEM PROBE section of /codex report (a list of lines). Runs a fresh character probe first; never errors.
function P.ReportLines()
	local L = {}
	local okP, errP = pcall(P.ProbeCharacter)
	if not okP and ns.RecordError then ns.RecordError("itemprobe character", errP) end
	L[#L + 1] = "--- ITEM PROBE (read-only: what the Forever client exposes; no advice is built on it) ---"
	L[#L + 1] = "PROVEN = a real value was read on this client | UNPROVEN = not seen working yet | FAILED = missing or returned nothing"
	local n, newest, dialogs = P.RewardStats()
	L[#L + 1] = string.format("reward dialogs seen: %d | quests with a stored observation (src=CODEX_OBSERVED): %d%s", dialogs, n,
		newest and string.format(" | latest Q:%s at %s, %d choice(s), %d guaranteed", tostring(newest.q), tostring(newest.at), #newest.choices, #newest.rewards) or "")
	local group
	for _, fld in ipairs(P.FIELDS) do
		if fld.group ~= group then
			group = fld.group
			L[#L + 1] = (group == "reward" and "Reward dialog:") or (group == "item" and "Item data (reward items, equipped items and a few bag items):") or "Character:"
		end
		local st, detail = P.Status(fld.key)
		L[#L + 1] = string.format("  %-24s %-9s %s", fld.label, st, detail)
	end
	local evs = {}
	for _, ev in ipairs(P.EVENTS) do
		local st, fired = eventStatus(ev)
		evs[#evs + 1] = string.format("%s[%s fired=%d]", ev, st, fired)
	end
	L[#L + 1] = "Events: " .. table.concat(evs, " ")
	local s = store()
	for _, ev in ipairs(P.EVENTS) do
		local e = s and s.events[ev]
		if e and e.args and e.n and e.n > 0 and (ev == "GET_ITEM_INFO_RECEIVED" or ev == "QUEST_ITEM_UPDATE" or ev == "PLAYER_EQUIPMENT_CHANGED" or ev == "BAG_UPDATE_DELAYED" or ev == "SKILL_LINES_CHANGED") then
			L[#L + 1] = string.format("  %s first arguments: %s", ev, table.concat(e.args, " | "))
		end
	end
	L[#L + 1] = string.format("Late item data: %d item(s) still waiting for their info this session", P.PendingCount())
	L[#L + 1] = "Not probed in Stage 0: tooltip text (use-effect wording, class/race requirements), IsSpellKnown proficiencies, items the client has never seen"
	return L
end
