-- ForeverCodex.QuestItems: items in the player's bags that START a quest ("Use it to continue your progression").
--
-- It adds no inventory system: the bag stacks come from the shared Gear snapshot (Stage 2, event-maintained, ItemFacts per stack). It only answers two questions per stack:
--   1. Does this item start a quest, and which one?   (evidence, below)
--   2. Is acting on it sensible for this character NOW? (the same progression rules the planner already applies to a pickup)
-- Possession of an item is never proof that it starts a quest; no item id or name is hard-coded.
--
-- EVIDENCE (strongest first; each record says where it came from, and `verified` follows the project's rule: true only for what the Forever client itself reported):
--   client   C_Container.GetContainerItemQuestInfo(bag, slot) answered with a quest id for that slot. The client's own statement; src = "client", verified = true. Whether this
--            function answers usefully on Forever is UNPROVEN until a report shows it (it is tallied PROVEN / UNPROVEN / FAILED below and printed in /codex report).
--   questiedb  QuestieDB's Item.startQuest for the item id (through Items.External). Third-party baseline data: src = "questiedb", verified = false. QuestieDB has no
--            Forever-added items, so for those it simply says nothing (unknown, never "does not start a quest").
-- When both answer and disagree, the client wins and the disagreement is recorded. With neither, the item is not a quest starter as far as Codex knows.
--
-- ACTIONABLE (QI.Actionable): the quest is not completed, not in the quest log, not active per the client, not skipped (the quest, or the item via /codex skip QI:<id>), the item's
-- own required level (when the client proved it) does not exceed the character's, and, when Codex has data for the quest, the existing pickup eligibility (Quest.Eligibility:
-- level, prerequisites, faction, race, class, event) does not rule it out. A quest Codex has no data for is still offered when the CLIENT said the item starts it.
--
-- Read-only. No timers or polling: scanning is keyed to the identity of the Gear bag snapshot, which only changes on BAG_UPDATE_DELAYED.

local addonName, ns = ...

local QI = {}
ns.QuestItems = QI

QI.MAX_SEEN = 100                 -- remembered item -> quest observations (the least recently seen is dropped)

local I = ns.Items
local lastBags, lastList         -- scan cache keyed by the Gear bags snapshot table

local function wall() return type(time) == "function" and time() or 0 end

local function store()
	if type(ForeverCodexDB) ~= "table" then return nil end
	local s = ForeverCodexDB.questItems
	if type(s) ~= "table" then s = {}; ForeverCodexDB.questItems = s end
	s.v = s.v or 1
	s.seen = type(s.seen) == "table" and s.seen or {}
	s.proof = type(s.proof) == "table" and s.proof or {}
	return s
end

local function tally(outcome, sample)
	local s = store()
	if not s then return end
	local e = s.proof
	e.n = (e.n or 0) + 1
	if outcome == "ok" then e.ok = (e.ok or 0) + 1; if sample then e.s = tostring(sample):sub(1, 100) end
	elseif outcome == "fail" then e.fail = (e.fail or 0) + 1
	else e.none = (e.none or 0) + 1 end
end

local function keysOf(t)
	local keys = {}
	for k in pairs(t) do keys[#keys + 1] = tostring(k) end
	table.sort(keys)
	return table.concat(keys, ","):sub(1, 100)
end

--- What the client says about one bag slot: { answered, questId, isActive, isQuestItem, shape } or nil when the function is absent / raised. Tolerates both the table
-- form (modern) and the multiple-return form (older); nothing is assumed about fields it does not return.
function QI.ClientInfo(bag, slot)
	local fn = I.Resolve("GetContainerItemQuestInfo")
	if not fn then return nil end
	local res = { pcall(fn, bag, slot) }
	if not res[1] then tally("fail"); return nil end
	local v = res[2]
	local out = { answered = true }
	if type(v) == "table" then
		out.shape = keysOf(v)
		out.questId = type(v.questID) == "number" and v.questID > 0 and v.questID or (type(v.questId) == "number" and v.questId > 0 and v.questId or nil)
		out.isActive = v.isActive == true or nil
		out.isQuestItem = v.isQuestItem == true or nil
	elseif v ~= nil then
		out.isQuestItem = v == true or nil
		out.questId = type(res[3]) == "number" and res[3] > 0 and res[3] or nil
		out.isActive = res[4] == true or nil
		out.shape = "multiple returns"
	else
		tally("none")
		return out
	end
	if out.questId then tally("ok", "questID " .. out.questId .. " (" .. tostring(out.shape) .. ")") else tally("none") end
	return out
end

--- The quest id QuestieDB records as started by an item id (via Items.External, kept apart from client facts), or nil.
function QI.External(itemId)
	local x = I.External(itemId)
	if x and x.exists and type(x.startQuest) == "number" and x.startQuest > 0 then return x.startQuest end
	return nil
end

local function nameOf(stack)
	local f = stack.itemFacts and stack.itemFacts.fields and stack.itemFacts.fields.name
	if f and f.state == "PROVEN" and type(f.value) == "string" and f.value ~= "" then return f.value end
	local n = type(stack.link) == "string" and stack.link:match("%[(.-)%]")
	return n or ("item " .. tostring(stack.itemId))
end

--- One stack -> { itemId, name, quest, src, verified, via, active, conflict, bag, slot, count } or nil when no evidence says it starts a quest.
function QI.Starter(stack)
	if not stack or stack.state ~= "POPULATED" or type(stack.itemId) ~= "number" then return nil end
	local client = QI.ClientInfo(stack.bag, stack.slot)
	local ext = QI.External(stack.itemId)
	local e = { itemId = stack.itemId, name = nameOf(stack), bag = stack.bag, slot = stack.slot, count = stack.count or 1, facts = stack.itemFacts }
	if client and client.questId then
		e.quest, e.src, e.verified, e.via, e.active = client.questId, "client", true, "C_Container.GetContainerItemQuestInfo", client.isActive
		if ext and ext ~= client.questId then e.conflict = { client = client.questId, questiedb = ext } end
		return e
	end
	if ext then
		e.quest, e.src, e.verified, e.via = ext, "questiedb", false, "QuestieDB Item.startQuest"
		return e
	end
	return nil
end

--- Every quest-starting item in the bags snapshot (one entry per quest; the stack with the most items represents it). Cached per snapshot.
function QI.Scan(bags)
	if bags == lastBags and lastList then return lastList end
	local byQuest, list = {}, {}
	for _, stack in ipairs(bags and bags.stacks or {}) do
		local e = QI.Starter(stack)
		if e then
			local have = byQuest[e.quest]
			if not have then byQuest[e.quest] = e; list[#list + 1] = e
			elseif (e.count or 1) > (have.count or 1) then
				for i, x in ipairs(list) do if x == have then list[i] = e end end
				byQuest[e.quest] = e
			end
		end
	end
	table.sort(list, function(x, y) return x.itemId < y.itemId end)
	lastBags, lastList = bags, list
	-- remember what the client / QuestieDB said (bounded): lets a report show the evidence after the item has been used
	local s = store()
	if s then
		for _, e in ipairs(list) do
			local r = s.seen[e.itemId]
			if not r then r = { first = wall(), n = 0 }; s.seen[e.itemId] = r end
			r.name, r.quest, r.src, r.verified, r.last, r.n = e.name, e.quest, e.src, e.verified, wall(), r.n + 1
		end
		local n = 0
		for _ in pairs(s.seen) do n = n + 1 end
		while n > QI.MAX_SEEN do
			local oldK, oldT
			for k, v in pairs(s.seen) do if oldT == nil or (v.last or 0) < oldT then oldK, oldT = k, v.last or 0 end end
			s.seen[oldK] = nil
			n = n - 1
		end
	end
	return list
end

--- Is acting on this quest-starting item sensible for this character now? Returns true, or false + a reason code (COMPLETED, IN_LOG, ACTIVE, SKIPPED, ITEM_LEVEL, ELIGIBILITY_<why>).
function QI.Actionable(e, ctx, env)
	local qid = e.quest
	if ctx.isCompleted(qid) then return false, "COMPLETED" end
	if ctx.log and ctx.log[qid] then return false, "IN_LOG" end
	if e.active then return false, "ACTIVE" end
	local sk = ctx.prefs and ctx.prefs.skipped or {}
	if sk["Q:" .. qid] or sk["QT:" .. qid] or sk["QI:" .. e.itemId] then return false, "SKIPPED" end
	local rl = e.facts and e.facts.fields and e.facts.fields.requiredLevel
	local lvl = ctx.char and ctx.char.level
	if rl and rl.state == "PROVEN" and type(rl.value) == "number" and lvl and rl.value > lvl then return false, "ITEM_LEVEL" end
	local view = ns.Registry.Quest(qid)
	if view and ns.QuestProvider then
		local ok, why = ns.QuestProvider.Eligibility(view, ctx, env and env.strategy)
		if not ok and why ~= "noLocation" then return false, "ELIGIBILITY_" .. tostring(why) end    -- (an item quest has no map location: that is not a reason to hide it)
	end
	return true
end

-- ---------------------------------------------------------------- report

function QI.ReportLines()
	local L = {}
	L[#L + 1] = "QUEST-STARTING ITEMS (items in your bags that start a quest; evidence: the client's own container quest info, else QuestieDB's unverified Item.startQuest)"
	local fn = I.Resolve("GetContainerItemQuestInfo")
	local s = store()
	local p = s and s.proof or {}
	local state = not fn and "ABSENT" or ((p.ok or 0) > 0 and string.format("PROVEN (%d of %d slot reads gave a quest id, e.g. %s)", p.ok, p.n, tostring(p.s)))
		or (p.n and string.format("PRESENT, no quest id seen yet (%d reads, %d empty, %d failed)", p.n, p.none or 0, p.fail or 0)) or "PRESENT, UNPROVEN (no bag read yet)"
	L[#L + 1] = "  C_Container.GetContainerItemQuestInfo: " .. state
	local ctx, snap = ns.State and ns.State.ctx, ns.Gear and ns.Gear.last
	local list = snap and QI.Scan(snap.bags) or {}
	if #list == 0 then
		L[#L + 1] = "  none in the bags right now (no evidence from the client or QuestieDB that any bag item starts a quest)"
	end
	for _, e in ipairs(list) do
		local ok, why = true, nil
		if ctx then ok, why = QI.Actionable(e, ctx, { strategy = ns.Registry.Strategy(ctx.prefs and ctx.prefs.style) }) end
		L[#L + 1] = string.format("  %s (item %d) x%d | starts Q%d | evidence: %s%s | %s%s", e.name, e.itemId, e.count or 1, e.quest, e.src, e.verified and " (client-reported)" or " (unverified third-party data)",
			ok and "ACTIONABLE" or ("not actionable: " .. tostring(why)), e.conflict and (" | CONFLICT client Q" .. e.conflict.client .. " vs QuestieDB Q" .. e.conflict.questiedb) or "")
	end
	local n = 0
	for _ in pairs(s and s.seen or {}) do n = n + 1 end
	L[#L + 1] = string.format("  remembered quest-starting items: %d (cap %d)", n, QI.MAX_SEEN)
	return L
end
