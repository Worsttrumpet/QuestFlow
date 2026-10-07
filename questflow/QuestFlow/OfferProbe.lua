-- ForeverCodex.OfferProbe: a READ-ONLY probe of what the Forever client says an NPC is OFFERING when the player opens its dialog.
--
-- WHY. Codex knows that a quest exists and where it was recorded (QuestieDB / ATT / Codex's observed pack). None of that proves THIS character is
-- offered it: at Yorana Windyreed, Codex recommended two pickups and her window offered nothing. This probe records what the client itself reports
-- when a dialog opens, so the difference between "known to exist" and "offered to this character just now" is visible AND used.
--
-- WHO USES IT (since 0.6.x; the evidence is a decision input, not only a diagnostic). The Planner reads it through O.OfferEvidence (Planner.lua Pl.OfferState):
--   * a pickup whose giver was asked at the character's CURRENT progression and did not offer it is HELD BACK (never a candidate, never a stop) until the evidence goes stale or the client offers it;
--   * a pickup with no client evidence is UNKNOWN: it is discounted a little and, when far, is only a POSSIBLE pickup (never NOW); UNKNOWN is never read as "unavailable";
--   * client evidence that the quest was offered lifts that distance limit and the discount;
--   * a quest no pack knows, offered by the client, becomes an "offered here" action with no location (Providers/Quest.lua, O.FreshOffers).
-- What it never does: turn "not observed" into "does not exist", write a class / race / prerequisite rule, or invent a location. QuestieDB / ATT stay supporting data: a direct,
-- current client observation outranks them.
--
-- THE RULES (0.8.5), all of them about how far a piece of evidence may be trusted:
--   * POSITIVE evidence is kept as history and is not aged by progress alone. It is routing-grade (OBSERVED) only while nothing newer contradicts it.
--   * A NEWER listing from the quest's giver that omits the quest overrides the older positive: NOT_OFFERED while that listing is current (read at the character's present progression);
--     when that listing goes stale the result is UNKNOWN. The old positive never comes back to life on its own (OBSERVED again needs a new observation that lists the quest).
--   * Positive evidence counts for the quest's GIVER only when the NPC that produced it is that giver: the same creature id, or the same name when an id is missing on either side. Two
--     known creature ids that differ never match, even with an identical name. Evidence from a different NPC is kept for diagnostics, reads as UNKNOWN (never NOT_OFFERED: we do not know
--     what it means) and is explained by O.Explain.
--
-- WHAT IT READS (nothing is assumed; each call is made through pcall, only if it exists, and tallied PROVEN / UNPROVEN / FAILED / ABSENT):
--   GOSSIP_SHOW      C_GossipInfo.GetAvailableQuests / GetActiveQuests / GetOptions (PROVEN on Forever, build 70205: every answer carried quest ids; the older
--                    GetNumGossip* / GetGossip* functions and GetAvailableQuestID are proven ABSENT and are no longer called)
--   QUEST_GREETING   GetNumAvailableQuests / GetAvailableTitle, GetNumActiveQuests / GetActiveTitle (PROVEN on Forever, 0.8.1 report: the event fires and the counts and TITLES answer, with NO quest ids:
--                    so it is recorded and never used as listing evidence, because a title is not an id)
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
	"GetNumAvailableQuests", "GetAvailableTitle", "GetNumActiveQuests", "GetActiveTitle",
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
		s = { owner = ns.SavedData and ns.SavedData.Owner() or nil }
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

-- ---------------------------------------------------------------- secret values (0.8.1)
--
-- Real-client finding (0.8.0, a dungeon run): `OfferProbe.lua:119: attempt to index a secret string value (execution tainted by 'ForeverCodex')`. This client can hand an addon a SECRET value
-- (a string, number or table it will not let addon code read, compare, index or concatenate) for some unit data, and the line that built the report's "sample of what came back" called
-- `tostring(v):sub(1, 60)` on UnitName("npc"). The same would have happened further down (`pack[1] ~= ""`, `:sub(1, 40)`, `guid:match(...)`). Nothing about the NPC or the dialog is assumed
-- when a value is unreadable: it is treated as NOT GIVEN, so a listing that cannot be read is never EMPTY (no negative evidence), never LISTED, never an offer; it is recorded as UNREADABLE for the report.
-- Every value that comes back from the client now goes through these readers, which (a) ask issecretvalue() when the client has it and (b) do the real operation inside pcall, so a secret raises
-- INSIDE the guard instead of in the probe.

local function isSecret(v)
	local f = _G.issecretvalue
	if type(f) == "function" then
		local ok, r = pcall(f, v)
		if ok and r == true then return true end
	end
	return false
end

--- A readable, trimmed string, or nil (not a string, empty, secret, or anything that raises).
local function text(v, max)
	if type(v) ~= "string" or isSecret(v) then return nil end
	local ok, r = pcall(function() if v == "" then return nil end return v:sub(1, max or 60) end)
	return ok and r or nil
end

--- A readable number, or nil.
local function num(v)
	if type(v) ~= "number" or isSecret(v) then return nil end
	local ok, r = pcall(function() return v + 0 end)
	return ok and r or nil
end

--- Whether `v` is nil, without ever raising (comparing a secret value can raise).
local function isNil(v)
	local ok, r = pcall(function() return v == nil end)
	return ok and r or false
end

--- A short description of what came back, for the report. Never raises, never returns a secret.
local function sampleOf(v)
	if type(v) == "table" then
		if isSecret(v) then return "table (secret)" end
		local ok, n = pcall(function() return #v end)
		return ok and ("table(" .. tostring(n) .. ")") or "table (unreadable)"
	end
	local t = text(type(v) == "string" and v or (pcall(tostring, v) and select(2, pcall(tostring, v)) or nil), 60)
	if t then return t end
	return type(v) .. " (unreadable)"
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
	if pack.n == 0 or isNil(pack[1]) then
		if e then e.none = (e.none or 0) + 1 end
	else
		if e then
			e.ok = (e.ok or 0) + 1
			e.b = build()
			local v = pack[1]
			-- a sample of what came back, for the report; NEVER for a GUID (only the creature id parsed from it is kept)
			if name == "UnitGUID" then e.s = "string" else e.s = sampleOf(v) end
			if type(v) ~= "table" and (isSecret(v) or e.s:find("(unreadable)", 1, true)) then e.secret = (e.secret or 0) + 1 end
		end
	end
	return true, pack
end

--- The creature id from a GUID, or nil. The GUID itself is never returned or stored. A secret or unreadable GUID gives nil.
local function creatureId(guid)
	if type(guid) ~= "string" or isSecret(guid) then return nil end
	local ok, kind, npc = pcall(function() return guid:match("^(%a+)%-%d+%-%d+%-%d+%-%d+%-(%d+)%-") end)
	if not ok then return nil end
	if (kind == "Creature" or kind == "Vehicle") and npc then return tonumber(npc) end
	return nil
end

--- Who the dialog is with: { name, id } from UnitName / UnitGUID of "npc", or nil. Second result: true when the client DID answer but the value could not be read (a secret value), so the dialog is
-- recorded without an NPC identity (and therefore supplies no per-NPC evidence at all) rather than guessing one.
local function npcInfo()
	local ok, pack = call("UnitName", "npc")
	local name = ok and text(pack[1], 40) or nil
	local okG, g = call("UnitGUID", "npc")
	local id = okG and creatureId(g[1]) or nil
	local unreadable = (ok and not name and not isNil(pack[1])) or (okG and not id and not isNil(g[1]) and type(g[1]) == "string" and (isSecret(g[1]) or false)) or nil
	if not name and not id then return nil, unreadable end
	return { name = name, id = id }
end

local function sortedKeys(t)
	local keys = {}
	for k in pairs(t) do keys[#keys + 1] = tostring(k) end
	table.sort(keys)
	return keys
end

--- One modern-style answer: a table of entries ({ questID, title, questLevel, ... }). kind: "available" | "active" | "options".
-- Every field is read through the secret-safe readers. A list that cannot be read at all is state UNREADABLE (not EMPTY, not LISTED: it supports neither a positive nor a negative conclusion); an entry
-- whose quest id and title are both unreadable is left out, which also makes the listing "incomplete" (it can then contradict nothing).
local function answerFromTable(kind, api, pack, ok)
	if not ok then return { kind = kind, api = api, state = pack == "absent" and "ABSENT" or "ERROR" } end
	local list = pack[1]
	if type(list) ~= "table" then return { kind = kind, api = api, state = "NO_DATA" } end
	if isSecret(list) then return { kind = kind, api = api, state = "UNREADABLE" } end
	local okParse, a = pcall(function()
		local count = #list
		local r = { kind = kind, api = api, n = count, entries = {} }
		if count == 0 then r.state = "EMPTY" else r.state = "LISTED" end
		for i = 1, math.min(count, O.MAX_ENTRIES) do
			local e = list[i]
			if type(e) == "table" and not isSecret(e) then
				if i == 1 then
					local okK, shape = pcall(function() return table.concat(sortedKeys(e), ","):sub(1, 140) end)
					if okK then r.shape = shape end
				end
				local id = num(e.questID)
				local title = text(e.title, 50)
				local okR, rep = pcall(function() return e.repeatable == true or nil end)
				local okC, comp = pcall(function() return e.isComplete == true or nil end)
				if id or title or kind == "options" then
					r.entries[#r.entries + 1] = { id = id, title = title, level = num(e.questLevel), repeatable = okR and rep or nil, complete = okC and comp or nil }
				else
					r.unreadableEntries = (r.unreadableEntries or 0) + 1
				end
			else
				r.unreadableEntries = (r.unreadableEntries or 0) + 1
			end
		end
		return r
	end)
	if not okParse then return { kind = kind, api = api, state = "UNREADABLE" } end
	return a
end

--- A count call (GetNumAvailableQuests, QUEST_GREETING): EMPTY when it answers 0, LISTED for a positive number, NO_DATA when it answers nothing.
local function answerFromCount(kind, api, pack, ok)
	if not ok then return { kind = kind, api = api, state = pack == "absent" and "ABSENT" or "ERROR" } end
	local raw = pack[1]
	if type(raw) ~= "number" then return { kind = kind, api = api, state = "NO_DATA" } end
	local n = num(raw)
	if not n then return { kind = kind, api = api, state = "UNREADABLE" } end
	return { kind = kind, api = api, state = n == 0 and "EMPTY" or "LISTED", n = n, entries = {} }
end

-- GOSSIP_SHOW: only the modern C_GossipInfo functions are asked. The older GetNumGossip* / GetGossip* functions and GetAvailableQuestID are PROVEN ABSENT on
-- Forever (real client, build 70205), so they are no longer called.
local function gossipAnswers()
	local out = {}
	local ok, pack = call("C_GossipInfo.GetAvailableQuests")
	out[#out + 1] = answerFromTable("available", "C_GossipInfo.GetAvailableQuests", pack, ok)
	local ok3, pack3 = call("C_GossipInfo.GetActiveQuests")
	out[#out + 1] = answerFromTable("active", "C_GossipInfo.GetActiveQuests", pack3, ok3)
	local ok5, pack5 = call("C_GossipInfo.GetOptions")
	out[#out + 1] = answerFromTable("options", "C_GossipInfo.GetOptions", pack5, ok5)
	return out
end

-- QUEST_GREETING fires on Forever (0.8.1 report, an NPC with a greeting frame) and answers counts and titles but NO quest ids: its titles are recorded as observations only and are never used as listing evidence.
local function greetingAnswers()
	local out = {}
	for _, spec in ipairs({ { "available", "GetNumAvailableQuests", "GetAvailableTitle" }, { "active", "GetNumActiveQuests", "GetActiveTitle" } }) do
		local ok, pack = call(spec[2])
		local a = answerFromCount(spec[1], spec[2], pack, ok)
		if a.state == "LISTED" then
			for i = 1, math.min(a.n, O.MAX_ENTRIES) do
				local e = {}
				local okT, t = call(spec[3], i)
				if okT then e.title = text(t[1], 50) end
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
	local qn = ok and num(q[1]) or nil
	local id = qn and qn > 0 and qn or nil
	local title = okT and text(t[1], 50) or nil
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


--- A short stamp of the character's PROGRESSION: level, quests turned in (as Codex saw them) and quests finished and waiting to be handed in. An NPC's list is only
-- evidence about the progression it was read at: when the stamp changes (a level, a turn-in, a finished quest) a NEGATIVE observation is STALE (it may no longer be true,
-- e.g. a quest that opens after its prerequisite is done) and is treated as unknown until the NPC is asked again. A positive observation is not undone by progress.
-- Cached per context (one computation per recompute).
local stampFor, stampValue, stampTurned, activeCtx

--- The planner tells the probe which context it is planning FOR (State.ctx is still the previous one while a recompute runs), so the stamp is never one recompute late.
function O.SetContext(ctx) activeCtx = ctx end

function O.Stamp()
	local ctx = activeCtx or (ns.State and ns.State.ctx)
	-- the turned-in count can move between two recomputes (a turn-in, then a dialog before the next recompute): the cache is valid for one context AND one count
	local turned = ns.Journey and ns.Journey.TurnedInCount and ns.Journey.TurnedInCount() or 0
	if ctx and ctx == stampFor and turned == stampTurned then return stampValue end
	local level = ctx and ctx.char and ctx.char.level or "?"
	local ready = 0
	for _, e in pairs(ctx and ctx.log or {}) do if e.complete then ready = ready + 1 end end
	local v = tostring(level) .. ":" .. turned .. ":" .. ready
	stampFor, stampValue, stampTurned = ctx, v, turned
	return v
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
	local shown = {}
	for _, e in ipairs(a.entries or {}) do shown[#shown + 1] = { id = e.id, title = e.title, complete = e.complete } end
	return { state = a.state, api = a.api, n = a.n, ids = ids, entries = shown, complete = complete or nil, at = wall(), seq = nil, prog = O.Stamp() }
end

-- A listing counts as NPC evidence only when it came from the PROVEN modern gossip API (C_GossipInfo.*). QUEST_GREETING counts are recorded but unproven.
local function firstOf(answers, kind)
	for _, a in ipairs(answers) do
		if a.kind == kind and (a.state == "LISTED" or a.state == "EMPTY") and tostring(a.api):find("^C_GossipInfo%.") then return a end
	end
end

--- Updates the quest / NPC indexes from one dialog (also called for an unchanged repeat, which only raises counters and times).
local function index(s, via, npc, answers)
	local now = wall()
	s.seq = (s.seq or 0) + 1                      -- ordering of evidence: wall time has one-second resolution, a sequence number does not tie
	-- quests the client itself showed: the open offer, or an available-quest list that carried an id
	for _, a in ipairs(answers) do
		if a.kind == "offered" or (a.kind == "available" and a.state == "LISTED" and tostring(a.api):find("^C_GossipInfo%.")) then
			-- (the ACTIVE list is deliberately not here: a quest the character already has is not an offer)
			for _, e in ipairs(a.entries or {}) do
				if e.id then
					local src = a.kind == "offered" and "QUEST_DETAIL" or "AVAILABLE_LIST"
					local r = s.quests[e.id]
					if not r then r = { first = now, n = 0 }; s.quests[e.id] = r end
					r.n = r.n + 1
					r.last, r.seq, r.prog = now, s.seq, O.Stamp()
					r.by = type(r.by) == "table" and r.by or {}
					r.by[src] = (r.by[src] or 0) + 1                 -- observations per source (QUEST_DETAIL / AVAILABLE_LIST), both are positive evidence
					if (VIA_RANK[src] or 0) >= (VIA_RANK[r.via] or 0) then r.via = src end
					r.title = e.title or r.title
					if npc then r.npcName, r.npcId = npc.name or r.npcName, npc.id or r.npcId end
				end
			end
		end
	end
	dropOldest(s.quests, O.MAX_QUESTS)
	-- the NPC's latest listing (a QUEST_DETAIL says nothing about what the NPC lists, so it does not touch the listing)
	if npc and (npc.id or npc.name) and via == "GOSSIP_SHOW" then
		local key = npcKey(npc)
		local r = s.npcs[key]
		if not r then r = { first = now, n = 0 }; s.npcs[key] = r end
		r.name, r.id = npc.name or r.name, npc.id or r.id
		r.n, r.last, r.via = r.n + 1, now, via
		local av, ac = firstOf(answers, "available"), firstOf(answers, "active")
		r.avail, r.active = summary(av), summary(ac)
		r.avail.seq, r.active.seq = s.seq, s.seq
		dropOldest(s.npcs, O.MAX_NPCS)
	end
end

--- Positive evidence for a quest id: { via = "QUEST_DETAIL" | "AVAILABLE_LIST", npcName, npcId, n, first, last, title } or nil.
function O.QuestEvidence(qid)
	local s = store()
	return s and type(qid) == "number" and s.quests[qid] or nil
end

--- Quests the client is offering NOW, by what OfferProbe recorded: positive evidence (QUEST_DETAIL or a listed available quest that carried its id) that was read at the
-- character's CURRENT progression (the stamp has not moved since: no level, turn-in or newly finished quest) and that no newer complete listing from the same NPC
-- contradicts. Returns { { quest, title, npcName, npcId, via, last } } sorted by id. Read-only: the quest log and completed quests are filtered by the caller. Never invents a
-- location (the record has none) and never names a quest the client did not give a title for.
function O.FreshOffers(ctx)
	local s = store()
	local out = {}
	if not s then return out end
	if ctx then activeCtx = ctx end
	local stamp = O.Stamp()
	local ids = {}
	for qid in pairs(s.quests) do ids[#ids + 1] = qid end
	table.sort(ids)
	for _, qid in ipairs(ids) do
		local r = s.quests[qid]
		if type(r.title) == "string" and r.title ~= "" and r.prog == stamp then
			local ev = O.OfferEvidence(qid, r.npcId, r.npcName)
			if ev and ev.kind == "OBSERVED" and not ev.contradicted then
				out[#out + 1] = { quest = qid, title = r.title, npcName = r.npcName, npcId = r.npcId, via = r.via, last = r.last }
			end
		end
	end
	return out
end

local function plainName(n)
	if type(n) ~= "string" or n == "" then return nil end
	return (n:gsub("%s*<.*>%s*$", ""):lower())             -- (quest data may carry the guild line: "High Priest Rohan <Priest Trainer>")
end

--- How two NPCs relate, as the data names them: "ID" (the same creature id), "NAME" (the same name, and an id is missing on at least one side), "MISMATCH" (two known creature ids
-- that differ, even when the names are identical; or, with no ids to compare, two different names), or nil (nothing to compare: no id on both sides and no name on both).
function O.Relate(aId, aName, bId, bName)
	if aId and bId then return aId == bId and "ID" or "MISMATCH" end
	local an, bn = plainName(aName), plainName(bName)
	if an and bn then return an == bn and "NAME" or "MISMATCH" end
	return nil
end

--- The latest listing recorded for an NPC, matched by creature id; by name ONLY when an id is missing on at least one side (two different known ids never match, whatever the names), or nil.
function O.NpcContext(npcId, npcName)
	local s = store()
	if not s then return nil end
	local best
	for _, r in pairs(s.npcs) do
		local rel = O.Relate(npcId, npcName, r.id, r.name)
		if (rel == "ID" or rel == "NAME") and (not best or (r.last or 0) > (best.last or 0)) then best = r end
	end
	return best
end

--- What the client has shown about this quest being offered: { kind = "OBSERVED", via, npc, last, n } | { kind = "EMPTY_AT_NPC" | "NOT_LISTED_AT_NPC",
-- npc, last } | nil (no client evidence: UNKNOWN). The negative kinds describe ONE NPC dialog at one moment, never the quest.
function O.OfferEvidence(qid, giverNpcId, giverName)
	local ctx = O.NpcContext(giverNpcId, giverName)
	local av = ctx and ctx.avail
	-- the contextual kind from the giver's latest listing (never from an incomplete one); `current` = read at the character's present progression
	local ctxKind, ctxAt, current
	if av then
		-- A dialog with NO progression stamp (saved before stamps existed, or by an older build) cannot be shown to belong to the character's present progression, and the offers store
		-- is account-wide: it is never current. A negative read from it is stale (UNKNOWN), not a hold. Codex does not invent a stamp for it.
		current = av.prog ~= nil and av.prog == O.Stamp()
		if av.state == "EMPTY" then ctxKind, ctxAt = "EMPTY_AT_NPC", av.at
		elseif av.state == "LISTED" and av.complete then
			local listed = false
			for _, id in ipairs(av.ids) do if id == qid then listed = true end end
			ctxKind, ctxAt = listed and "LISTED_AT_NPC" or "NOT_LISTED_AT_NPC", av.at
		end
	end
	local negative = ctxKind == "EMPTY_AT_NPC" or ctxKind == "NOT_LISTED_AT_NPC"
	local q = O.QuestEvidence(qid)
	-- a positive observation is about the quest's GIVER only when the NPC that produced it is that giver (nothing to compare = no reason to doubt it)
	local rel = q and O.Relate(giverNpcId, giverName, q.npcId, q.npcName) or nil
	if q and rel ~= "MISMATCH" then
		-- positive evidence is kept as history whatever happens later. A NEWER listing from the giver that omits the quest overrides it: NOT_OFFERED while that listing is current
		-- (read at the character's present progression), UNKNOWN once it is stale. The old positive never resurrects itself when the negative ages out.
		local newer = negative and (av.seq or 0) > (q.seq or 0) and ctxKind or nil
		if newer and not current then
			return { kind = "SUPERSEDED", via = q.via, npc = q.npcName, last = q.last, n = q.n, by = q.by, newer = newer, stale = true }
		end
		return { kind = "OBSERVED", via = q.via, npc = q.npcName, last = q.last, n = q.n, by = q.by, newer = newer, contradicted = (newer ~= nil and current) or nil }
	end
	if ctxKind == "LISTED_AT_NPC" then return { kind = "OBSERVED", via = "AVAILABLE_LIST", npc = ctx.name, last = ctxAt, n = 1, by = { AVAILABLE_LIST = 1 } } end
	if negative then return { kind = ctxKind, npc = ctx.name, last = ctxAt, stale = not current or nil } end
	-- the quest was offered, but by a DIFFERENT known NPC than the one its data names: kept for the report, never routing evidence and never a negative (what it means is unknown)
	if q then return { kind = "OBSERVED_ELSEWHERE", via = q.via, npc = q.npcName, npcId = q.npcId, last = q.last, n = q.n, by = q.by, expectedNpc = giverName, expectedId = giverNpcId } end
	return nil
end

--- DIAGNOSTICS ONLY (the playtest report; the planner never calls this and nothing here is written): the facts behind O.OfferEvidence for one pickup, so a report
-- can say WHICH NPC listing was used, HOW it was matched to the quest's giver, and whether it was read at the current progression.
--   giverNpcId / giverName   the giver as the QUEST DATA names it (not necessarily the NPC the client talked to)
-- Returns { stamp, listing = { name, id, how, state, complete, at, prog, noStamp, fresh } | nil, positive = { via, npcName, npcId, last, n, prog, by } | nil, evidence = O.OfferEvidence(...) }.
-- how: "ID" the listing's creature id equals the giver's | "NAME_IDS_DIFFER" matched by name only and BOTH creature ids are known and differ |
--      "NAME_QUEST_HAS_NO_ID" the quest data has no creature id | "NAME_LISTING_HAS_NO_ID" the listing was recorded without a creature id.
function O.Explain(qid, giverNpcId, giverName)
	local s = store()
	if not s then return nil end
	local stamp = O.Stamp()
	local out = { stamp = stamp, giverNpcId = giverNpcId, giverName = giverName, evidence = O.OfferEvidence(qid, giverNpcId, giverName) }
	local ctx = O.NpcContext(giverNpcId, giverName)
	if ctx then
		local how
		if ctx.id and giverNpcId and ctx.id == giverNpcId then how = "ID"
		elseif ctx.id and giverNpcId then how = "NAME_IDS_DIFFER"
		elseif not giverNpcId then how = "NAME_QUEST_HAS_NO_ID"
		else how = "NAME_LISTING_HAS_NO_ID" end
		local av = ctx.avail or {}
		out.listing = { name = ctx.name, id = ctx.id, how = how, state = av.state, complete = av.complete, at = av.at or ctx.last, prog = av.prog,
			noStamp = av.prog == nil, fresh = av.prog ~= nil and av.prog == stamp }
	end
	local q = O.QuestEvidence(qid)
	if q then
		out.positive = { via = q.via, npcName = q.npcName, npcId = q.npcId, last = q.last, n = q.n, prog = q.prog, by = q.by,
			-- how the NPC that produced it relates to the giver the quest data names: ID | NAME | MISMATCH | nil (nothing comparable)
			relation = O.Relate(giverNpcId, giverName, q.npcId, q.npcName) }
	end
	return out
end

--- Records one dialog. A dialog the client refreshes unchanged (gossip pages do) raises the repeat counter of the previous observation.
function O.Observe(via, answers)
	local s = store()
	if not s then return nil end
	local npc, npcUnreadable = npcInfo()
	if npcUnreadable then bump("npcUnreadable") end
	local sig = signature(via, npc, answers)
	if sig == lastSig and lastObs and s.obs[#s.obs] == lastObs then
		lastObs.n = (lastObs.n or 1) + 1
		lastObs.last = wall()
		index(s, via, npc, answers)
		return lastObs
	end
	local obs = { src = "CODEX_OBSERVED", via = via, at = wall(), last = wall(), build = build(), npc = npc, npcUnreadable = npcUnreadable or nil, answers = answers, n = 1 }
	s.obs[#s.obs + 1] = obs
	while #s.obs > O.MAX_OBS do table.remove(s.obs, 1) end
	lastSig, lastObs = sig, obs
	index(s, via, npc, answers)
	for _, a in ipairs(answers) do
		if a.kind == "available" or a.kind == "offered" then
			if a.state == "EMPTY" then bump("emptyAnswers") end
			if a.state == "UNREADABLE" then bump("unreadableAnswers") end
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
	if a.state == "UNREADABLE" then return a.api .. ": the client answered with a value addons cannot read (a secret value): UNKNOWN, not empty and not listed" end
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
	L[#L + 1] = "ACTIONABILITY / OFFER EVIDENCE (what the client listed when an NPC dialog opened. The planner reads it for one thing only: a pickup whose giver was asked at your CURRENT progression and did not offer it is held back; everything else here is for the report. A quest NOT listed means only 'not listed in that dialog at that moment')"
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
	-- values the client would not let addons read (secret values, 0.8.1): counted so a report says whether it happened. They are UNKNOWN, never empty and never offers.
	L[#L + 1] = string.format("  unreadable (secret) values this save: NPC names or GUIDs %d | whole lists %d | API samples %s",
		s.stats.npcUnreadable or 0, s.stats.unreadableAnswers or 0, (function() local n = 0 for _, e in pairs(s.proof or {}) do n = n + (e.secret or 0) end return tostring(n) end)())
	if #s.obs == 0 then
		L[#L + 1] = "  no NPC dialog observed yet: open an NPC's window (one that offers quests, and one that offers none)"
		return L
	end
	local now = wall()
	local function ents(list)
		local out = {}
		for _, e in ipairs(list or {}) do out[#out + 1] = (e.id and ("Q" .. e.id) or "(no id)") .. (e.title and (" " .. e.title) or "") .. (e.complete and " [complete]" or "") end
		return #out > 0 and table.concat(out, ", ") or "none"
	end
	local function src(by)
		local out = {}
		for _, k in ipairs({ "QUEST_DETAIL", "AVAILABLE_LIST" }) do if by and by[k] then out[#out + 1] = k .. " x" .. by[k] end end
		return table.concat(out, " + ")
	end
	local qs = {}
	for id, r in pairs(s.quests) do qs[#qs + 1] = { id = id, r = r } end
	table.sort(qs, function(x, y) if (x.r.last or 0) ~= (y.r.last or 0) then return (x.r.last or 0) > (y.r.last or 0) end return x.id < y.id end)
	if #qs > 0 then L[#L + 1] = "  OFFER EVIDENCE: OBSERVED = the client offered this quest to this character at that time (most recent first; history, not a promise it is still offered):" end
	for i = 1, math.min(#qs, O.SHOW_EVIDENCE) do
		local q = qs[i]
		local ctx = O.NpcContext(q.r.npcId, q.r.npcName)
		local newer = ""
		if ctx and ctx.avail and (ctx.avail.seq or 0) > (q.r.seq or 0) then
			if ctx.avail.state == "EMPTY" then newer = " | NEWER dialog at that NPC: available EMPTY (kept, not erased)"
			elseif ctx.avail.state == "LISTED" and ctx.avail.complete then
				local listed = false
				for _, id in ipairs(ctx.avail.ids) do if id == q.id then listed = true end end
				if not listed then newer = " | NEWER dialog at that NPC: not listed (kept, not erased)" end
			end
		end
		L[#L + 1] = string.format("    Q%d %s | NPC %s%s | OBSERVED | sources: %s | observations %d | %s%s", q.id, tostring(q.r.title or "?"), tostring(q.r.npcName or "not reported"),
			q.r.npcId and (" (creature " .. q.r.npcId .. ")") or "", src(q.r.by) ~= "" and src(q.r.by) or tostring(q.r.via), q.r.n or 1, ago(q.r.last, now), newer)
	end
	if #qs > O.SHOW_EVIDENCE then L[#L + 1] = "    + " .. (#qs - O.SHOW_EVIDENCE) .. " more" end
	local ns_ = {}
	for _, r in pairs(s.npcs) do ns_[#ns_ + 1] = r end
	table.sort(ns_, function(x, y) if (x.last or 0) ~= (y.last or 0) then return (x.last or 0) > (y.last or 0) end return tostring(x.name) < tostring(y.name) end)
	if #ns_ > 0 then L[#L + 1] = "  NPC dialogs (latest answer per NPC; EMPTY / not listed describe that dialog at that moment only; an ACTIVE quest is not an offer):" end
	for i = 1, math.min(#ns_, O.SHOW_EVIDENCE) do
		local r = ns_[i]
		local av, ac = r.avail or {}, r.active or {}
		local avText = av.state == "LISTED" and (av.complete and ("LISTED: " .. ents(av.entries)) or ("LISTED, incomplete (an entry has no quest id): " .. ents(av.entries))) or tostring(av.state)
		local acText = ac.state == "LISTED" and ("LISTED: " .. ents(ac.entries)) or tostring(ac.state)
		L[#L + 1] = string.format("    %s%s | available %s | active %s | dialogs x%d | %s", tostring(r.name or "?"), r.id and (" (creature " .. r.id .. ")") or "", avText, acText, r.n or 1, ago(r.last, now))
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
