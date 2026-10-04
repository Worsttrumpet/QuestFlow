-- ForeverCodex.SpellTraining: the SPELL TRAINING section of the Codex window. Informational only: Codex never trains anything.
--
-- WHAT IT SHOWS: class spells (and ranks) the player's own trainer listed on a past visit, whose level requirement the character has now reached, that
-- the character does not know, and that the player has not marked "Don't Want to Learn". Cost per spell and the total of what is shown.
--
-- WHERE THE DATA COMES FROM (evidence boundary, read this before changing anything):
--   * The ONLY source of "what can be trained" is the trainer window the player opens, read through the classic trainer API (GetNumTrainerServices,
--     GetTrainerServiceInfo, GetTrainerServiceCost, GetTrainerServiceLevelReq, GetTrainerServiceItemLink, IsTradeskillTrainer) at TRAINER_SHOW /
--     TRAINER_UPDATE. There is no remote trainer query, so nothing can be listed before the first trainer visit, and a cost is the cost the trainer
--     showed on the last visit. Codex ships NO spell, rank, cost, trainer or location data.
--   * "Known" is read from the client: IsPlayerSpell / IsSpellKnown by spell id, or the spellbook by name and rank when the trainer gave no spell id.
--   * Whether these APIs behave this way on Forever is NOT proven by anything in this repository (see docs/CODEX_SPELL_TRAINING.md). Every read is
--     defensive; a missing API means the section stays empty, never a guess. /codex spells prints what the client answered.
--
-- Persisted per character (Prefs.Char().spellTraining, never shared between characters):
--   { class = "ROGUE", entries = { [key] = { id, name, rank, rankNum, cost, levelReq, cat, learned, seenLevel } }, dismissed = { [key] = { name, rank } } }
-- key = "S:<spell id>" when the trainer link carries one, else "N:<name>|<rank>" (flagged: the name is then the only identity).
-- A new rank is a different spell id, so it is a new training opportunity by itself; a dismissal never carries over to it.

local _, ns = ...
local S = {}
ns.SpellTraining = S

S.MAX_ROWS = 12

local function call(fn, ...)
	if type(fn) ~= "function" then return false end
	local r = { pcall(fn, ...) }
	if not r[1] then return false end
	table.remove(r, 1)
	return true, r[1], r[2], r[3], r[4]
end

local function wall() return type(_G.time) == "function" and _G.time() or 0 end

-- ---------------------------------------------------------------- the persisted per-character store

local function store(ctx)
	local c = ns.Prefs.Char()
	local st = c.spellTraining
	if type(st) ~= "table" then st = {}; c.spellTraining = st end
	st.entries = type(st.entries) == "table" and st.entries or {}
	st.dismissed = type(st.dismissed) == "table" and st.dismissed or {}
	-- a different class under the same name and realm (a deleted and re-rolled character) must not inherit the old character's spells or choices
	local token = ctx and ctx.char and ctx.char.classToken or S._classToken()
	if token then
		if st.class and st.class ~= token then st.entries, st.dismissed = {}, {} end
		st.class = token
	end
	return st
end

function S._classToken()
	local ok, _, token = call(_G.UnitClass, "player")
	return ok and type(token) == "string" and token ~= "" and token or nil
end

local function keyOf(id, name, rank)
	if type(id) == "number" then return "S:" .. id end
	return "N:" .. tostring(name) .. "|" .. tostring(rank or "")
end

local function rankNumber(rank)
	return type(rank) == "string" and tonumber(rank:match("(%d+)")) or nil
end

-- ---------------------------------------------------------------- reading the trainer window

--- The spell id in a trainer service's item link ("|Hspell:1752|h[...]|h"), or nil when the client gives none.
function S.IdFromLink(link)
	if type(link) ~= "string" then return nil end
	return tonumber(link:match("spell:(%d+)"))
end

--- Reads the open trainer window: { ok, apis = { name = bool }, tradeskill = true|false|nil, services = { { index, name, rank, category, cost, levelReq, id } }, err }.
-- Never raises. Reads nothing when the window API is absent or reports no services.
function S.ReadTrainer()
	local r = { ok = false, apis = {}, services = {} }
	for _, n in ipairs({ "GetNumTrainerServices", "GetTrainerServiceInfo", "GetTrainerServiceCost", "GetTrainerServiceLevelReq", "GetTrainerServiceItemLink", "IsTradeskillTrainer" }) do
		r.apis[n] = type(_G[n]) == "function"
	end
	if not (r.apis.GetNumTrainerServices and r.apis.GetTrainerServiceInfo) then r.err = "trainer service API absent" return r end
	local okN, n = call(_G.GetNumTrainerServices)
	if not okN or type(n) ~= "number" then r.err = "GetNumTrainerServices gave no number" return r end
	if r.apis.IsTradeskillTrainer then
		local okT, t = call(_G.IsTradeskillTrainer)
		if okT and t ~= nil then r.tradeskill = t and true or false end
	end
	for i = 1, n do
		local okI, name, rank, category = call(_G.GetTrainerServiceInfo, i)
		if okI and type(name) == "string" and name ~= "" then
			local s = { index = i, name = name, rank = (type(rank) == "string" and rank ~= "") and rank or nil, category = category }
			local okC, cost = call(_G.GetTrainerServiceCost, i)
			if okC and type(cost) == "number" then s.cost = cost end
			local okL, lvl = call(_G.GetTrainerServiceLevelReq, i)
			if okL and type(lvl) == "number" then s.levelReq = lvl end
			local okK, link = call(_G.GetTrainerServiceItemLink, i)
			if okK then s.id = S.IdFromLink(link) end
			r.services[#r.services + 1] = s
		end
	end
	r.ok = true
	return r
end

S.lastRead = nil

--- Folds one trainer read into the character's store. A profession trainer is not class training and is ignored. Returns the number of entries touched.
function S.Record(read, ctx)
	S.lastRead = read
	if not (read and read.ok) or read.tradeskill == true then return 0 end
	local st = store(ctx)
	local lvl = ctx and ctx.char and ctx.char.level
	local touched = 0
	for _, s in ipairs(read.services) do
		local key = keyOf(s.id, s.name, s.rank)
		local e = st.entries[key]
		if s.category == "used" then
			if e then e.learned = true end       -- the trainer itself says this is already known
		elseif s.category == "available" or s.category == "unavailable" then
			if not e then e = {}; st.entries[key] = e end
			e.id, e.name, e.rank, e.rankNum = s.id, s.name, s.rank, rankNumber(s.rank)
			e.cost, e.levelReq, e.cat = s.cost, s.levelReq, s.category
			e.seenLevel = lvl
			e.trainerKind = read.tradeskill == false and "class" or "unknown"
			touched = touched + 1
		end
	end
	return touched
end

--- Boot calls this at TRAINER_SHOW and TRAINER_UPDATE (a purchase fires an update, which is how a spell learned at the window is noticed at once).
function S.OnTrainerEvent()
	local ctx = ns.State and ns.State.ctx
	return S.Record(S.ReadTrainer(), ctx)
end

-- ---------------------------------------------------------------- known spells

local function spellbookIndex()
	local idx = {}
	local okT, tabs = call(_G.GetNumSpellTabs)
	if not okT or type(tabs) ~= "number" or type(_G.GetSpellTabInfo) ~= "function" or type(_G.GetSpellBookItemName) ~= "function" then return idx, false end
	for t = 1, tabs do
		local okI, _, _, offset, count = call(_G.GetSpellTabInfo, t)
		if okI and type(offset) == "number" and type(count) == "number" then
			for i = offset + 1, offset + count do
				local okS, name, sub = call(_G.GetSpellBookItemName, i, "spell")
				if okS and type(name) == "string" then
					local n = rankNumber(sub) or 0
					if not idx[name] or n > idx[name] then idx[name] = n end
				end
			end
		end
	end
	return idx, true
end

--- Whether the character knows this entry. By spell id when there is one; else by spellbook name and rank (a higher known rank counts).
local function isKnown(e, book)
	if e.learned then return true end
	if e.id then
		for _, fn in ipairs({ "IsPlayerSpell", "IsSpellKnown" }) do
			local ok, v = call(_G[fn], e.id)
			if ok and v then e.learned = true return true end
		end
		return false
	end
	local have = book.idx[e.name]
	if have and (e.rankNum == nil or have >= e.rankNum) then e.learned = true return true end
	return false
end

-- ---------------------------------------------------------------- the list

local function displayName(e)
	return e.name .. (e.rank and (" " .. e.rank) or "")
end

--- The spells to show now: { rows = { { key, id, name, rank, title, cost, costText } }, total, totalText, partial } or nil when there are none
-- (the section is then not drawn at all). Pure with respect to the plan: it reads the store, the level and the spellbook, nothing else.
function S.List(ctx)
	local st = store(ctx)
	local lvl = ctx and ctx.char and ctx.char.level
	if type(lvl) ~= "number" then return nil end
	local book = { idx = nil }
	do
		local idx = spellbookIndex()
		book.idx = idx
	end
	local keys = {}
	for k in pairs(st.entries) do keys[#keys + 1] = k end
	table.sort(keys)
	-- known first, so a known higher rank can retire a lower one of the same spell
	local knownRank = {}
	for _, k in ipairs(keys) do
		local e = st.entries[k]
		if isKnown(e, book) and e.rankNum then knownRank[e.name] = math.max(knownRank[e.name] or 0, e.rankNum) end
	end
	local cand = {}
	for _, k in ipairs(keys) do
		local e = st.entries[k]
		local show = not e.learned and not st.dismissed[k] and type(e.levelReq) == "number" and e.levelReq <= lvl
		if show and e.rankNum and (knownRank[e.name] or 0) > e.rankNum then show = false end      -- a higher rank is already known
		if show then cand[#cand + 1] = { key = k, e = e } end
	end
	-- one rank of a spell at a time: the lowest one still to learn (the trainer sells the next rank after the previous)
	local lowest = {}
	for _, c in ipairs(cand) do
		local n = c.e.rankNum
		if n and (lowest[c.e.name] == nil or n < lowest[c.e.name]) then lowest[c.e.name] = n end
	end
	local rows, total, partial = {}, 0, false
	for _, c in ipairs(cand) do
		local e = c.e
		if not (e.rankNum and lowest[e.name] ~= e.rankNum) then
			rows[#rows + 1] = { key = c.key, id = e.id, name = e.name, rank = e.rank, title = displayName(e), cost = e.cost, levelReq = e.levelReq }
		end
	end
	if #rows == 0 then return nil end
	table.sort(rows, function(a, b)
		if (a.levelReq or 0) ~= (b.levelReq or 0) then return (a.levelReq or 0) < (b.levelReq or 0) end
		if a.name ~= b.name then return a.name < b.name end
		return a.key < b.key
	end)
	for _, r in ipairs(rows) do
		if type(r.cost) == "number" then
			total = total + r.cost
			r.costText = ns.Items.Money(r.cost)
		else
			partial = true
		end
	end
	return { rows = rows, total = total, partial = partial,
		totalText = "Total training: " .. ns.Items.Money(total) .. (partial and " (some costs unknown)" or "") }
end

--- What the Presenter hands the window: the list, or nil (then there is no section).
function S.Card(ctx)
	local ok, list = pcall(S.List, ctx)
	if not ok then ns.RecordError("spelltraining", list) return nil end
	return list
end

-- ---------------------------------------------------------------- Don't Want to Learn

--- Persists "I do not want this spell" for the current character and recomputes at once. False when the key is not a spell Codex lists.
function S.Dismiss(key)
	local st = store(ns.State and ns.State.ctx)
	local e = st.entries[key]
	if not e then return false end
	st.dismissed[key] = { name = e.name, rank = e.rank }
	if ns.State and ns.State.Recompute then ns.State.Recompute("spelltraining") end
	return true
end

--- Brings every dismissed spell of this character back (the player is in control: /codex spells restore).
function S.RestoreAll()
	local st = store(ns.State and ns.State.ctx)
	local n = 0
	for k in pairs(st.dismissed) do st.dismissed[k] = nil; n = n + 1 end
	if n > 0 and ns.State and ns.State.Recompute then ns.State.Recompute("spelltraining") end
	return n
end

-- ---------------------------------------------------------------- /codex spells and the report

function S.ReportLines(ctx)
	local L = {}
	local st = store(ctx)
	local nE, nD = 0, 0
	for _ in pairs(st.entries) do nE = nE + 1 end
	for _ in pairs(st.dismissed) do nD = nD + 1 end
	L[#L + 1] = "SPELL TRAINING (class spells the trainer window listed on a past visit; Codex never trains for you)"
	local apis = {}
	for _, n in ipairs({ "GetNumTrainerServices", "GetTrainerServiceInfo", "GetTrainerServiceCost", "GetTrainerServiceLevelReq", "GetTrainerServiceItemLink", "IsTradeskillTrainer", "IsPlayerSpell", "IsSpellKnown", "GetNumSpellTabs", "GetSpellBookItemName" }) do
		apis[#apis + 1] = n .. "=" .. (type(_G[n]) == "function" and "yes" or "NO")
	end
	L[#L + 1] = "  client APIs: " .. table.concat(apis, " ")
	local r = S.lastRead
	if r then
		L[#L + 1] = string.format("  last trainer read: %s, %d service(s), profession trainer: %s%s", r.ok and "ok" or "FAILED", #r.services,
			r.tradeskill == nil and "unknown" or tostring(r.tradeskill), r.err and (" (" .. r.err .. ")") or "")
		local withId = 0
		for _, s in ipairs(r.services) do if s.id then withId = withId + 1 end end
		L[#L + 1] = string.format("  spell ids in trainer links: %d of %d (a missing id falls back to name and rank)", withId, #r.services)
	else
		L[#L + 1] = "  no trainer window has been read this session"
	end
	L[#L + 1] = string.format("  stored for this character: %d spell(s), %d marked Don't Want to Learn", nE, nD)
	local list = S.List(ctx)
	if not list then
		L[#L + 1] = "  showing: nothing (the section is hidden)"
	else
		for _, row in ipairs(list.rows) do
			L[#L + 1] = string.format("  - %s  %s  [%s]", row.title, row.costText or "cost unknown", row.id and ("spell " .. row.id) or "no spell id")
		end
		L[#L + 1] = "  " .. list.totalText
	end
	return L
end
