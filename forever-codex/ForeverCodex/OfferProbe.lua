-- ForeverCodex.OfferProbe: a READ-ONLY probe of what the Forever client says an NPC is OFFERING when the player opens its dialog.
--
-- WHY. Codex knows that a quest exists and where it was recorded (QuestieDB / ATT / Codex's observed pack). None of that proves THIS character is
-- offered it: at Yorana Windyreed, Codex recommended two pickups and her window offered nothing. This probe records what the client itself reports
-- when a dialog opens, so the difference between "known to exist" and "offered to this character just now" can be seen, and (later, if the probe
-- proves useful) used. It uses no planner input and gives the planner no output: no candidate, score, skip, filter or actionability changes.
--
-- WHAT IT READS (nothing is assumed; each call is made through pcall, only if it exists, and tallied PROVEN / UNPROVEN / FAILED / ABSENT):
--   GOSSIP_SHOW      C_GossipInfo.GetAvailableQuests / GetActiveQuests / GetOptions, and the older GetNumGossipAvailableQuests / GetGossipAvailableQuests /
--                    GetNumGossipActiveQuests / GetGossipActiveQuests / GetNumGossipOptions
--   QUEST_GREETING   GetNumAvailableQuests / GetAvailableTitle (and GetAvailableQuestID only if the client has it), GetNumActiveQuests / GetActiveTitle
--   QUEST_DETAIL     GetQuestID, GetTitleText: the quest whose offer dialog is open (an explicit offer)
--   the NPC          UnitName("npc") and the creature id parsed from UnitGUID("npc"); the raw GUID is never stored
--
-- WHAT IT RECORDS (ForeverCodexDB.offers, bounded, src = CODEX_OBSERVED; separate from QuestieDB, ATT, the observed quest pack and the quest log):
--   one observation per dialog: event, time, build, NPC (name, creature id), and ANSWERS: for each API asked, its state
--     LISTED  the API answered with quests (each: quest id when the client gave one, else the title only; level when given)
--     EMPTY   the API answered and listed none (this is the only thing that counts as "nothing offered")
--     NO_DATA the call worked but returned nothing at all (not the same as EMPTY)
--     ERROR   the call raised
--   The shape (field names) of the first listed entry is kept, so the real payload can be checked.
-- EVIDENCE LAYER (0.6.5). The observations are normalised into two small bounded indexes, still CODEX_OBSERVED and still never a rule:
--   quests[id]   positive evidence: OBSERVED via QUEST_DETAIL (the offer dialog for that quest opened) or via AVAILABLE_LIST (a client available-quest list
--                carried that quest id). QUEST_DETAIL is the stronger source and is kept when both have been seen.
--   npcs[key]    the latest answer that NPC's dialog gave: AVAILABLE EMPTY (the API answered with no quests), LISTED (with the ids when every entry had one),
--                or NO_DATA; and the same for ACTIVE. Keyed by creature id when the client gave one, else by name. Overwritten by the next dialog.
--   O.OfferEvidence(quest id, giver npc id, giver name) reads them: OBSERVED, or the CONTEXTUAL kinds EMPTY_AT_NPC / NOT_LISTED_AT_NPC (the quest's giver
--   was observed listing nothing / a complete id list without this quest, at that time), or nil (no client evidence: UNKNOWN). Hierarchy: a positive
--   observation always outranks a contextual negative. A contextual negative is about one NPC dialog at one moment, never about the quest.
-- A negative observation means only: "this character opened this NPC's dialog at this time and the client did not list this quest". It is NOT
-- turned into a class / race / prerequisite / availability rule.

local addonName, ns = ...

local O = {}
ns.OfferProbe = O

O.SCHEMA = 1
O.MAX_OBS = 100                 -- observations kept (the oldest is dropped); a dialog repeated unchanged only raises a counter
O.MAX_ENTRIES = 12              -- quests recorded per answer
O.EVENTS = { "GOSSIP_SHOW", "QUEST_GREETING", "QUEST_DETAIL" }
O.SHOW = 3                      -- raw observations printed in /codex report (the evidence summary above them is the main output)
O.MAX_QUESTS = 300              -- quests with positive offer evidence kept (the least recently seen is dropped)
O.MAX_NPCS = 100                -- NPC contexts kept (the least recently seen is dropped)
O.SHOW_EVIDENCE = 8             -- quests / NPCs listed in the report

-- every function the probe may call, by the name the client would give it (a dotted name is a namespace function)
O.APIS = { "C_GossipInfo.GetAvailableQuests", "C_GossipInfo.GetActiveQuests", "C_GossipInfo.GetOptions",
	"GetNumGossipAvailableQuests", "GetGossipAvailableQuests", "GetNumGossipActiveQuests", "GetGossipActiveQuests", "GetNumGossipOptions",
	"GetNumAvailableQuests", "GetAvailableTitle", "GetAvailableQuestID", "GetNumActiveQuests", "GetActiveTitle",
	"GetQuestID", "GetTitleText", "UnitName", "UnitGUID" }

local frame = CreateFrame("Frame")
local registered = {}
local lastSig, lastObs

local function wall() return type(time) == "function" and time() or 0 end
local function build()
	local ok, _, b = pcall(GetBuildInfo)
	return ok and b or nil
end

local function store()
	if type(ForeverCodexDB) ~= "table" then return nil end
	local s = ForeverCodexDB.offers
	if type(s) ~= "table" then
		s = {}
		ForeverCodexDB.offers = s
	end
	if s.v == nil then s.v = O.SCHEMA end
	s.obs = type(s.obs) == "table" and s.obs or {}
	s.proof = type(s.proof) == "table" and s.proof or {}
	s.stats = type(s.stats) == "table" and s.stats or {}
	s.quests = type(s.quests) == "table" and s.quests or {}     -- quest id -> positive offer evidence (see index())
	s.npcs = type(s.npcs) == "table" and s.npcs or {}           -- "id:<creature id>" or "name:<name>" -> the latest listing that NPC's dialog gave
	return s
end

local function bump(key)
	local s = store()
	if s then s.stats[key] = (s.stats[key] or 0) + 1 end
end

--- A client function by name ("C_GossipInfo.GetAvailableQuests" or "GetQuestID"), or nil when it does not exist.
function O.Resolve(name)
	local v = _G
	for part in tostring(name):gmatch("[^%.]+") do
		if type(v) ~= "table" then return nil end
		v = v[part]
	end
	return type(v) == "function" and v or nil
end

--- Calls one client function through pcall and tallies the outcome. Returns ok, packed results ({ n = count, ... }) or false, message.
local function call(name, ...)
	local fn = O.Resolve(name)
	local s = store()
	local e
	if s then
		e = s.proof[name]
		if type(e) ~= "table" then e = {}; s.proof[name] = e end
		e.n = (e.n or 0) + 1
	end
	if not fn then return false, "absent" end
	local res = { pcall(fn, ...) }
	if not res[1] then
		if e then e.fail = (e.fail or 0) + 1; e.f = tostring(res[2]):sub(1, 80) end
		return false, "error"
	end
	local pack = { n = #res - 1 }
	for i = 2, #res do pack[i - 1] = res[i] end
	if pack.n == 0 or pack[1] == nil then
		if e then e.none = (e.none or 0) + 1 end
	else
		if e then
			e.ok = (e.ok or 0) + 1
			e.b = build()
			local v = pack[1]
			-- a sample of what came back, for the report; NEVER for a GUID (only the creature id parsed from it is kept)
			if name == "UnitGUID" then e.s = "string" else e.s = (type(v) == "table" and ("table(" .. #v .. ")") or tostring(v)):sub(1, 60) end
		end
	end
	return true, pack
end

--- The creature id from a GUID, or nil. The GUID itself is never returned or stored.
local function creatureId(guid)
	if type(guid) ~= "string" then return nil end
	local kind, npc = guid:match("^(%a+)%-%d+%-%d+%-%d+%-%d+%-(%d+)%-")
	if (kind == "Creature" or kind == "Vehicle") and npc then return tonumber(npc) end
	return nil
end

local function npcInfo()
	local ok, pack = call("UnitName", "npc")
	local name = ok and type(pack[1]) == "string" and pack[1] ~= "" and pack[1]:sub(1, 40) or nil
	local okG, g = call("UnitGUID", "npc")
	local id = okG and creatureId(g[1]) or nil
	if not name and not id then return nil end
	return { name = name, id = id }
end

local function sortedKeys(t)
	local keys = {}
	for k in pairs(t) do keys[#keys + 1] = tostring(k) end
	table.sort(keys)
	return keys
end

--- One modern-style answer: a table of entries ({ questID, title, questLevel, ... }). kind: "available" | "active" | "options".
local function answerFromTable(kind, api, pack, ok)
	if not ok then return { kind = kind, api = api, state = pack == "absent" and "ABSENT" or "ERROR" } end
	local list = pack[1]
	if type(list) ~= "table" then return { kind = kind, api = api, state = "NO_DATA" } end
	local a = { kind = kind, api = api, n = #list, entries = {} }
	if #list == 0 then a.state = "EMPTY" else a.state = "LISTED" end
	for i = 1, math.min(#list, O.MAX_ENTRIES) do
		local e = list[i]
		if type(e) == "table" then
			if i == 1 then a.shape = table.concat(sortedKeys(e), ","):sub(1, 140) end
			a.entries[#a.entries + 1] = { id = type(e.questID) == "number" and e.questID or nil, title = type(e.title) == "string" and e.title:sub(1, 50) or nil,
				level = type(e.questLevel) == "number" and e.questLevel or nil }
		end
	end
	return a
end

--- A count call (GetNumGossipAvailableQuests): EMPTY when it answers 0, LISTED when it answers a positive number, NO_DATA when it answers nothing.
local function answerFromCount(kind, api, pack, ok)
	if not ok then return { kind = kind, api = api, state = pack == "absent" and "ABSENT" or "ERROR" } end
	local n = pack[1]
	if type(n) ~= "number" then return { kind = kind, api = api, state = "NO_DATA" } end
	return { kind = kind, api = api, state = n == 0 and "EMPTY" or "LISTED", n = n, entries = {} }
end

--- Legacy gossip lists return several values per quest (title, level, ...): only the STRING values are taken (titles); nothing is assumed about the rest.
local function titlesFromLegacy(a, api)
	local ok, pack = call(api)
	if not ok or pack.n == 0 then return end
	a.rawValues = pack.n
	for i = 1, pack.n do
		if type(pack[i]) == "string" and #a.entries < O.MAX_ENTRIES then a.entries[#a.entries + 1] = { title = pack[i]:sub(1, 50) } end
	end
end

local function gossipAnswers()
	local out = {}
	local ok, pack = call("C_GossipInfo.GetAvailableQuests")
	out[#out + 1] = answerFromTable("available", "C_GossipInfo.GetAvailableQuests", pack, ok)
	local ok2, pack2 = call("GetNumGossipAvailableQuests")
	local a2 = answerFromCount("available", "GetNumGossipAvailableQuests", pack2, ok2)
	if a2.state == "LISTED" then titlesFromLegacy(a2, "GetGossipAvailableQuests") end
	out[#out + 1] = a2
	local ok3, pack3 = call("C_GossipInfo.GetActiveQuests")
	out[#out + 1] = answerFromTable("active", "C_GossipInfo.GetActiveQuests", pack3, ok3)
	local ok4, pack4 = call("GetNumGossipActiveQuests")
	local a4 = answerFromCount("active", "GetNumGossipActiveQuests", pack4, ok4)
	if a4.state == "LISTED" then titlesFromLegacy(a4, "GetGossipActiveQuests") end
	out[#out + 1] = a4
	local ok5, pack5 = call("C_GossipInfo.GetOptions")
	out[#out + 1] = answerFromTable("options", "C_GossipInfo.GetOptions", pack5, ok5)
	local ok6, pack6 = call("GetNumGossipOptions")
	out[#out + 1] = answerFromCount("options", "GetNumGossipOptions", pack6, ok6)
	return out
end

local function greetingAnswers()
	local out = {}
	for _, spec in ipairs({ { "available", "GetNumAvailableQuests", "GetAvailableTitle", "GetAvailableQuestID" },
		{ "active", "GetNumActiveQuests", "GetActiveTitle", nil } }) do
		local ok, pack = call(spec[2])
		local a = answerFromCount(spec[1], spec[2], pack, ok)
		if a.state == "LISTED" then
			for i = 1, math.min(a.n, O.MAX_ENTRIES) do
				local e = {}
				local okT, t = call(spec[3], i)
				if okT and type(t[1]) == "string" then e.title = t[1]:sub(1, 50) end
				if spec[4] and O.Resolve(spec[4]) then
					local okI, id = call(spec[4], i)
					if okI and type(id[1]) == "number" then e.id = id[1] end
				end
				a.entries[#a.entries + 1] = e
			end
		end
		out[#out + 1] = a
	end
	return out
end

local function detailAnswers()
	local ok, q = call("GetQuestID")
	local okT, t = call("GetTitleText")
	local a = { kind = "offered", api = "GetQuestID", entries = {} }
	local id = ok and type(q[1]) == "number" and q[1] > 0 and q[1] or nil
	local title = okT and type(t[1]) == "string" and t[1] ~= "" and t[1]:sub(1, 50) or nil
	if id or title then
		a.state, a.n = "LISTED", 1
		a.entries[1] = { id = id, title = title }
	else
		a.state = ok and "NO_DATA" or "ERROR"
	end
	return { a }
end

local function signature(via, npc, answers)
	local parts = { via, npc and (tostring(npc.id) .. ":" .. tostring(npc.name)) or "-" }
	for _, a in ipairs(answers) do
		local ids = {}
		for _, e in ipairs(a.entries or {}) do ids[#ids + 1] = tostring(e.id or e.title) end
		parts[#parts + 1] = a.kind .. "/" .. a.api .. "/" .. a.state .. "/" .. tostring(a.n) .. "/" .. table.concat(ids, ";")
	end
	return table.concat(parts, "|")
end


local function dropOldest(t, cap)
	local n = 0
	for _ in pairs(t) do n = n + 1 end
	while n > cap do
		local oldK, oldT
		for k, v in pairs(t) do
			if oldT == nil or (v.last or 0) < oldT then oldK, oldT = k, v.last or 0 end
		end
		t[oldK] = nil
		n = n - 1
	end
end

local VIA_RANK = { AVAILABLE_LIST = 1, QUEST_DETAIL = 2 }

local function npcKey(npc)
	if npc.id then return "id:" .. npc.id end
	return "name:" .. npc.name
end

local function summary(a)
	if not a then return { state = "NO_DATA", at = wall() } end
	local ids, complete = {}, a.state == "LISTED" and #(a.entries or {}) == (a.n or 0)
	for _, e in ipairs(a.entries or {}) do
		if e.id then ids[#ids + 1] = e.id else complete = false end
	end
	return { state = a.state, api = a.api, n = a.n, ids = ids, complete = complete or nil, at = wall() }
end

local function firstOf(answers, kind)
	for _, a in ipairs(answers) do
		if a.kind == kind and (a.state == "LISTED" or a.state == "EMPTY") then return a end
	end
end

--- Updates the quest / NPC indexes from one dialog (also called for an unchanged repeat, which only raises counters and times).
local function index(s, via, npc, answers)
	local now = wall()
	-- quests the client itself showed: the open offer, or an available-quest list that carried an id
	for _, a in ipairs(answers) do
		if a.kind == "offered" or a.kind == "available" then
			for _, e in ipairs(a.entries or {}) do
				if e.id then
					local src = a.kind == "offered" and "QUEST_DETAIL" or "AVAILABLE_LIST"
					local r = s.quests[e.id]
					if not r then r = { first = now, n = 0 }; s.quests[e.id] = r end
					r.n = r.n + 1
					r.last = now
					if (VIA_RANK[src] or 0) >= (VIA_RANK[r.via] or 0) then r.via = src end
					r.title = e.title or r.title
					if npc then r.npcName, r.npcId = npc.name or r.npcName, npc.id or r.npcId end
				end
			end
		end
	end
	dropOldest(s.quests, O.MAX_QUESTS)
	-- the NPC's latest listing (a QUEST_DETAIL says nothing about what the NPC lists, so it does not touch the listing)
	if npc and (npc.id or npc.name) and via ~= "QUEST_DETAIL" then
		local key = npcKey(npc)
		local r = s.npcs[key]
		if not r then r = { first = now, n = 0 }; s.npcs[key] = r end
		r.name, r.id = npc.name or r.name, npc.id or r.id
		r.n, r.last, r.via = r.n + 1, now, via
		r.avail = summary(firstOf(answers, "available"))
		r.active = summary(firstOf(answers, "active"))
		dropOldest(s.npcs, O.MAX_NPCS)
	end
end

--- Positive evidence for a quest id: { via = "QUEST_DETAIL" | "AVAILABLE_LIST", npcName, npcId, n, first, last, title } or nil.
function O.QuestEvidence(qid)
	local s = store()
	return s and type(qid) == "number" and s.quests[qid] or nil
end

--- The latest listing recorded for an NPC (by creature id, else by exact name), or nil.
function O.NpcContext(npcId, npcName)
	local s = store()
	if not s then return nil end
	local best
	local function consider(r) if r and (not best or (r.last or 0) > (best.last or 0)) then best = r end end
	if npcId then consider(s.npcs["id:" .. npcId]) end
	if npcName then
		consider(s.npcs["name:" .. npcName])
		for _, r in pairs(s.npcs) do if r.name == npcName then consider(r) end end      -- the same NPC seen once with an id and once without
	end
	return best
end

--- What the client has shown about this quest being offered: { kind = "OBSERVED", via, npc, last, n } | { kind = "EMPTY_AT_NPC" | "NOT_LISTED_AT_NPC",
-- npc, last } | nil (no client evidence: UNKNOWN). The negative kinds describe ONE NPC dialog at one moment, never the quest.
function O.OfferEvidence(qid, giverNpcId, giverName)
	local q = O.QuestEvidence(qid)
	if q then return { kind = "OBSERVED", via = q.via, npc = q.npcName, last = q.last, n = q.n } end
	local ctx = O.NpcContext(giverNpcId, giverName)
	local av = ctx and ctx.avail
	if not av then return nil end
	if av.state == "EMPTY" then return { kind = "EMPTY_AT_NPC", npc = ctx.name, last = av.at } end
	if av.state == "LISTED" and av.complete then
		for _, id in ipairs(av.ids) do if id == qid then return { kind = "OBSERVED", via = "AVAILABLE_LIST", npc = ctx.name, last = av.at } end end
		return { kind = "NOT_LISTED_AT_NPC", npc = ctx.name, last = av.at }
	end
	return nil
end

--- Records one dialog. A dialog the client refreshes unchanged (gossip pages do) raises the repeat counter of the previous observation.
function O.Observe(via, answers)
	local s = store()
	if not s then return nil end
	local npc = npcInfo()
	local sig = signature(via, npc, answers)
	if sig == lastSig and lastObs and s.obs[#s.obs] == lastObs then
		lastObs.n = (lastObs.n or 1) + 1
		lastObs.last = wall()
		index(s, via, npc, answers)
		return lastObs
	end
	local obs = { src = "CODEX_OBSERVED", via = via, at = wall(), last = wall(), build = build(), npc = npc, answers = answers, n = 1 }
	s.obs[#s.obs + 1] = obs
	while #s.obs > O.MAX_OBS do table.remove(s.obs, 1) end
	lastSig, lastObs = sig, obs
	index(s, via, npc, answers)
	for _, a in ipairs(answers) do
		if a.kind == "available" or a.kind == "offered" then
			if a.state == "EMPTY" then bump("emptyAnswers") end
			for _, e in ipairs(a.entries or {}) do
				bump("entries")
				if e.id then bump("entriesWithId") else bump("entriesTitleOnly") end
			end
		end
	end
	return obs
end

--- Called for every watched client event. Reads and records; never touches the planner, the quest log or any quest.
function O.OnEvent(event)
	if not store() then return end
	bump(event)
	local ok, err = pcall(function()
		if event == "GOSSIP_SHOW" then
			O.Observe(event, gossipAnswers())
		elseif event == "QUEST_GREETING" then
			O.Observe(event, greetingAnswers())
		elseif event == "QUEST_DETAIL" then
			O.Observe(event, detailAnswers())
		end
	end)
	if not ok and ns.RecordError then ns.RecordError("offerprobe " .. tostring(event), err) end
end

local function registerAll()
	for _, ev in ipairs(O.EVENTS) do
		local ok = pcall(frame.RegisterEvent, frame, ev)
		registered[ev] = ok and true or false
	end
end

frame:SetScript("OnEvent", function(_, event) O.OnEvent(event) end)
registerAll()

-- ---------------------------------------------------------------- report

local function answerText(a)
	if a.state == "ABSENT" then return a.api .. ": API absent" end
	if a.state == "ERROR" then return a.api .. ": call raised an error" end
	if a.state == "NO_DATA" then return a.api .. ": returned nothing (not the same as an empty list)" end
	if a.state == "EMPTY" then return a.api .. ": answered, none listed" end
	local list = {}
	for _, e in ipairs(a.entries or {}) do
		list[#list + 1] = (e.id and ("Q:" .. e.id .. " ") or "(no id) ") .. tostring(e.title or "?") .. (e.level and (" L" .. e.level) or "")
	end
	local more = (a.n or 0) > #list and (" +" .. (a.n - #list) .. " more") or ""
	return string.format("%s: %d listed%s: %s%s%s", a.api, a.n or #list, a.rawValues and (" (" .. a.rawValues .. " raw values)") or "", table.concat(list, "; "), more,
		a.shape and (" | fields: " .. a.shape) or "")
end

local function ago(t, now) return string.format("%ds ago", math.max(0, now - (t or now))) end

function O.ReportLines()
	local L = {}
	local s = store()
	L[#L + 1] = "ACTIONABILITY / OFFER EVIDENCE (read-only: what the client listed when an NPC dialog opened; not used by the planner; a quest NOT listed means only 'not listed in that dialog at that moment')"
	if not s then L[#L + 1] = "  no saved-variables store"; return L end
	local ev = {}
	for _, e in ipairs(O.EVENTS) do
		ev[#ev + 1] = string.format("%s[%s fired=%d]", e, registered[e] == nil and "unknown" or (registered[e] and "registered" or "REFUSED"), s.stats[e] or 0)
	end
	L[#L + 1] = "  events: " .. table.concat(ev, " ")
	local proven, untried, absent, failed = {}, {}, {}, {}
	for _, name in ipairs(O.APIS) do
		local p = s.proof[name]
		if not O.Resolve(name) then absent[#absent + 1] = name
		elseif type(p) ~= "table" or not p.n then untried[#untried + 1] = name
		elseif (p.ok or 0) > 0 then proven[#proven + 1] = name .. "(" .. tostring(p.s) .. ")"
		elseif (p.fail or 0) > 0 then failed[#failed + 1] = name
		else untried[#untried + 1] = name .. "(answered nothing)" end
	end
	L[#L + 1] = "  client functions: PROVEN " .. (#proven > 0 and table.concat(proven, ", ") or "none yet")
	if #untried > 0 then L[#L + 1] = "    present, not called yet: " .. table.concat(untried, ", ") end
	if #failed > 0 then L[#L + 1] = "    FAILED: " .. table.concat(failed, ", ") end
	if #absent > 0 then L[#L + 1] = "    absent: " .. table.concat(absent, ", ") end
	local nq, nn = 0, 0
	for _ in pairs(s.quests) do nq = nq + 1 end
	for _ in pairs(s.npcs) do nn = nn + 1 end
	L[#L + 1] = string.format("  dialogs observed: %d saved (cap %d) | quests with positive evidence: %d (cap %d) | NPC contexts: %d (cap %d) | listed entries %d (with a quest id %d, title only %d) | empty answers %d",
		#s.obs, O.MAX_OBS, nq, O.MAX_QUESTS, nn, O.MAX_NPCS, s.stats.entries or 0, s.stats.entriesWithId or 0, s.stats.entriesTitleOnly or 0, s.stats.emptyAnswers or 0)
	if #s.obs == 0 then
		L[#L + 1] = "  no NPC dialog observed yet: open an NPC's window (one that offers quests, and one that offers none)"
		return L
	end
	local now = wall()
	local qs = {}
	for id, r in pairs(s.quests) do qs[#qs + 1] = { id = id, r = r } end
	table.sort(qs, function(x, y) if (x.r.last or 0) ~= (y.r.last or 0) then return (x.r.last or 0) > (y.r.last or 0) end return x.id < y.id end)
	if #qs > 0 then L[#L + 1] = "  OBSERVED quests (the client showed them to this character; most recent first):" end
	for i = 1, math.min(#qs, O.SHOW_EVIDENCE) do
		local q = qs[i]
		L[#L + 1] = string.format("    Q:%d %s | OBSERVED via %s | NPC %s%s | x%d | %s", q.id, tostring(q.r.title or "?"), tostring(q.r.via), tostring(q.r.npcName or "not reported"),
			q.r.npcId and (" (creature " .. q.r.npcId .. ")") or "", q.r.n or 1, ago(q.r.last, now))
	end
	if #qs > O.SHOW_EVIDENCE then L[#L + 1] = "    + " .. (#qs - O.SHOW_EVIDENCE) .. " more" end
	local ns_ = {}
	for _, r in pairs(s.npcs) do ns_[#ns_ + 1] = r end
	table.sort(ns_, function(x, y) if (x.last or 0) ~= (y.last or 0) then return (x.last or 0) > (y.last or 0) end return tostring(x.name) < tostring(y.name) end)
	if #ns_ > 0 then L[#L + 1] = "  NPC dialogs (latest answer per NPC; an EMPTY answer is about that dialog at that moment only, NOT proof a quest is permanently unavailable):" end
	for i = 1, math.min(#ns_, O.SHOW_EVIDENCE) do
		local r = ns_[i]
		local av, ac = r.avail or {}, r.active or {}
		local listed = ""
		if av.state == "LISTED" then
			listed = av.complete and (" [" .. table.concat(av.ids, ",") .. "]") or " [not every entry had an id]"
		end
		L[#L + 1] = string.format("    %s%s | AVAILABLE %s%s via %s | ACTIVE %s%s | dialogs x%d | %s", tostring(r.name or "?"), r.id and (" (creature " .. r.id .. ")") or "",
			tostring(av.state), av.state == "LISTED" and (" " .. tostring(av.n)) or "", tostring(av.api or "-"), tostring(ac.state), ac.state == "LISTED" and (" " .. tostring(ac.n)) or "", r.n or 1, ago(r.last, now))
		if listed ~= "" then L[#L + 1] = "      listed ids:" .. listed end
	end
	if #ns_ > O.SHOW_EVIDENCE then L[#L + 1] = "    + " .. (#ns_ - O.SHOW_EVIDENCE) .. " more" end
	L[#L + 1] = "  latest raw observations:"
	for i = #s.obs, math.max(1, #s.obs - O.SHOW + 1), -1 do
		local o = s.obs[i]
		L[#L + 1] = string.format("    %s %ds ago | NPC %s%s%s", o.via, math.max(0, now - (o.last or o.at or now)), o.npc and tostring(o.npc.name or "?") or "none reported",
			(o.npc and o.npc.id) and (" (creature " .. o.npc.id .. ")") or "", (o.n or 1) > 1 and (" | seen x" .. o.n) or "")
		for _, a in ipairs(o.answers or {}) do
			if a.state ~= "ABSENT" then L[#L + 1] = string.format("        %s: %s", a.kind, answerText(a)) end
		end
	end
	return L
end
