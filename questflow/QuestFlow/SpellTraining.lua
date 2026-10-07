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
-- key = "S:<spell id>" when the trainer link carries one, else "N:<name>|<rank>|L<level requirement>" (flagged: the name is then the only identity; the level requirement
-- tells two ranks of one spell apart when the client gives no rank text, as on Forever build 70205).
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

--- Like call, but keeps EVERY return value: { n = count, ... }. The client's GetTrainerServiceInfo order is not the Classic one (see ReadTrainer).
local function callN(fn, ...)
	if type(fn) ~= "function" then return false end
	local r = { pcall(fn, ...) }
	if not r[1] then return false end
	local out = { n = #r - 1 }
	for i = 2, #r do out[i - 1] = r[i] end
	return true, out
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

local function keyOf(id, name, rank, level)
	if type(id) == "number" then return "S:" .. id end
	return "N:" .. tostring(name) .. "|" .. tostring(rank or "") .. "|L" .. tostring(level or "")
end

local KNOWN_CATEGORY = { available = true, unavailable = true, used = true }

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
	-- which service categories the window currently shows (the Classic trainer filters); nil = the client does not say (GetTrainerServiceTypeFilter is not proven on Forever)
	r.filters = {}
	if type(_G.GetTrainerServiceTypeFilter) == "function" then
		for _, k in ipairs({ "available", "unavailable", "used" }) do
			local okF, v = call(_G.GetTrainerServiceTypeFilter, k)
			if okF and v ~= nil then r.filters[k] = (v == true or v == 1) end
		end
	end
	r.categories, r.sample, r.n = {}, {}, n
	for i = 1, n do
		local okI, rv = callN(_G.GetTrainerServiceInfo, i)
		local name = okI and rv[1]
		if okI and type(name) == "string" and name ~= "" then
			-- OBSERVED on Forever (build 70205): GetTrainerServiceInfo returns (name, "unavailable" | ..., <number>, ...): the category is the SECOND value and a number follows
			-- (an icon file id, not a spell id); there is no rank text. The Classic order is (name, rank, category). So the returns after the name are read by what they ARE: a string that is
			-- one of available / unavailable / used (any case) is the category; another non-empty string is the rank text; a number is kept as `icon`. Nothing else is assumed.
			local category, rank, icon
			for k = 2, math.min(rv.n, 6) do
				local v = rv[k]
				if type(v) == "string" then
					local lv = v:lower()
					if KNOWN_CATEGORY[lv] and not category then category = lv
					elseif v ~= "" and not KNOWN_CATEGORY[lv] and not rank then rank = v end
				elseif type(v) == "number" and not icon then icon = v end
			end
			local ck = category or "none"
			r.categories[ck] = (r.categories[ck] or 0) + 1
			local s = { index = i, name = name, rank = rank, category = category, icon = icon }
			local okC, cost = call(_G.GetTrainerServiceCost, i)
			if okC and type(cost) == "number" then s.cost = cost end
			local okL, lvl = call(_G.GetTrainerServiceLevelReq, i)
			if okL and type(lvl) == "number" then s.levelReq = lvl end
			local okK, link = call(_G.GetTrainerServiceItemLink, i)
			if okK then s.id = S.IdFromLink(link) end
			if #r.sample < 6 then
				local raw = {}
				for k = 1, math.min(rv.n, 6) do raw[#raw + 1] = type(rv[k]) == "string" and ('"' .. rv[k] .. '"') or (type(rv[k]) .. ":" .. tostring(rv[k])) end
				r.sample[#r.sample + 1] = string.format("#%d returns [%s] -> category %s, rank %s | cost %s | level %s | link %s", i, table.concat(raw, ", "), tostring(category), tostring(rank),
					tostring(s.cost), tostring(s.levelReq), okK and (type(link) == "string" and ('"' .. link:gsub("|", "||"):sub(1, 70) .. '"') or type(link)) or "call failed")
			end
			r.services[#r.services + 1] = s
		end
	end
	r.ok = true
	return r
end

S.lastRead = nil
S.lastGood = nil            -- the latest read that listed at least one service (TRAINER_UPDATE also fires with an empty list when the window closes)

-- ---------------------------------------------------------------- the observed spell CATALOG (account-wide, per class)
--
-- Codex ships NO spell data: there is no Forever spell/trainer dataset in this repository and importing Era / Classic tables would present another game's rules as Forever's. What exists is
-- what the Forever client itself showed: every class-trainer window a character of this account opens is recorded here, per class (name, rank text, level requirement, cost, the build). A
-- later character of the same class then learns about level-gated spells WITHOUT visiting a trainer. The catalog is OBSERVED trainer-window data (src "trainer window"), never QuestieDB or
-- ATT, and is only as complete as the windows that were opened. It is class data, not character state: it is not reset when a character is re-created.
-- A catalog row is shown to a character only when it became learnable while Codex was watching that character (its level requirement is above the level Codex first saw it at): a
-- spell at or below that level may have been learned before Codex ran and Forever offers no spellbook API to check, so it waits for the character's own trainer visit.

local function catalogStore()
	if type(ForeverCodexDB) ~= "table" then return nil end
	local c = ForeverCodexDB.spellCatalog
	if type(c) ~= "table" then c = {}; ForeverCodexDB.spellCatalog = c end
	c.v = c.v or 1
	c.classes = type(c.classes) == "table" and c.classes or {}
	return c
end

local function classOf(ctx)
	return (ctx and ctx.char and ctx.char.classToken) or S._classToken()
end

--- Merges one class-trainer read into the account's catalog for the character's class. Only rows that were still to learn carry a level requirement and cost (a learned row reports level 0).
local function recordCatalog(read, ctx)
	local cat, class = catalogStore(), classOf(ctx)
	if not cat or not class then return 0 end
	local c = cat.classes[class]
	if type(c) ~= "table" then c = { entries = {} }; cat.classes[class] = c end
	c.entries = type(c.entries) == "table" and c.entries or {}
	-- a window that shares no spell with what this class's catalog already holds is not this class's trainer (a hunter's pet-training window): it never enters the catalog
	local known, overlap, any = {}, false, false
	for _, e in pairs(c.entries) do known[e.name] = true; any = true end
	if any then
		for _, s in ipairs(read.services) do if known[s.name] then overlap = true break end end
		if not overlap then return 0 end
	end
	local ok, _, build = pcall(_G.GetBuildInfo)
	c.build, c.at, c.src = ok and build or c.build, type(_G.time) == "function" and _G.time() or 0, "trainer window"
	local n = 0
	for _, s in ipairs(read.services) do
		if (s.category == "available" or s.category == "unavailable") and type(s.levelReq) == "number" and s.levelReq > 0 then
			local key = keyOf(s.id, s.name, s.rank, s.levelReq)
			c.entries[key] = { id = s.id, name = s.name, rank = s.rank, rankNum = rankNumber(s.rank), levelReq = s.levelReq, cost = s.cost }
			n = n + 1
		end
	end
	return n
end

--- The level Codex first saw this character at (the journey's start entry), or nil.
local function startLevel()
	local j = ns.Prefs.Char().journey
	local first = type(j) == "table" and type(j.entries) == "table" and j.entries[1]
	return type(first) == "table" and first.k == "start" and type(first.lvl) == "number" and first.lvl or nil
end

--- Adds the catalog rows this character should now hear about to its own entries (never touches an entry it already has, so a learned or dismissed spell stays that way).
local function seedFromCatalog(st, ctx)
	local cat, class = catalogStore(), classOf(ctx)
	local c = cat and class and cat.classes[class]
	local from = startLevel()
	if not (c and from) then return 0 end
	local n = 0
	for key, row in pairs(c.entries or {}) do
		if not st.entries[key] and type(row.levelReq) == "number" and (row.levelReq > from or (from == 1 and row.levelReq == 1)) then
			st.entries[key] = { id = row.id, name = row.name, rank = row.rank, rankNum = row.rankNum, levelReq = row.levelReq, cost = row.cost, cat = "catalog", fromCatalog = true }
			n = n + 1
		end
	end
	return n
end

--- The stored entry a trainer row refers to: the exact key, or (a learned row reports level 0) the same name and rank text, or the same name and cost.
local function matchEntry(st, s)
	local e = st.entries[keyOf(s.id, s.name, s.rank, s.levelReq)]
	if e then return e end
	for _, e2 in pairs(st.entries) do
		if e2.name == s.name and ((s.id and e2.id == s.id) or (s.rank and e2.rank == s.rank) or (s.cost and e2.cost == s.cost and (s.rank == nil or e2.rank == nil))) then return e2 end
	end
	return nil
end

--- Folds one trainer read into the character's store. A profession trainer is not class training and is ignored. Returns the number of entries touched.
function S.Record(read, ctx)
	S.lastRead = read
	if read and read.ok and #read.services > 0 then S.lastGood = read end
	if not (read and read.ok) or read.tradeskill == true then return 0 end
	local st = store(ctx)
	local lvl = ctx and ctx.char and ctx.char.level
	local touched = 0
	if read.tradeskill == false or read.tradeskill == nil then recordCatalog(read, ctx) end
	seedFromCatalog(st, ctx)
	local seen, matched, shows = {}, 0, {}
	for _, s in ipairs(read.services) do
		if s.category then shows[s.category] = true end
		local e = matchEntry(st, s)
		if e then seen[e] = true; matched = matched + 1 end
		if s.category == "used" then
			-- the trainer itself says this is already known (OBSERVED on Forever: such a row reports level requirement 0, so it is matched by name and rank text / cost, not by key)
			if e then e.learned = true end
		elseif s.category == "available" or s.category == "unavailable" then
			local key = keyOf(s.id, s.name, s.rank, s.levelReq)
			if not e then e = {}; st.entries[key] = e; seen[e] = true end
			e.id, e.name, e.rank, e.rankNum = s.id, s.name, s.rank, rankNumber(s.rank)
			e.cost, e.levelReq, e.cat, e.fromCatalog = s.cost, s.levelReq, s.category, nil
			e.seenLevel = lvl
			e.trainerKind = read.tradeskill == false and "class" or "unknown"
			touched = touched + 1
		end
	end
	-- ABSENCE: a spell the character can already learn that this class-trainer window does not list was learned (the window hides learned spells when its "known" filter is off). Only trusted
	-- when the window clearly is this class's trainer (at least one stored spell appears in it: a hunter's pet-training window shares none) and shows "available" rows at all (so that filter is on).
	local availableShown = read.filters and read.filters.available == true or (read.filters and read.filters.available == nil and shows.available)
	if matched > 0 and availableShown and type(lvl) == "number" then
		for _, e in pairs(st.entries) do
			if not e.learned and not seen[e] and type(e.levelReq) == "number" and e.levelReq <= lvl then e.learned, e.learnedBy = true, "absent from the trainer window" end
		end
	end
	return touched
end

--- Boot calls this at TRAINER_SHOW and TRAINER_UPDATE (a purchase fires an update, which is how a spell learned at the window is noticed at once).
function S.OnTrainerEvent()
	local ctx = ns.State and ns.State.ctx
	local n = S.Record(S.ReadTrainer(), ctx)
	S.Settle(ctx)                                  -- (a purchase's money change can arrive with the update that follows it)
	return n
end

-- ---------------------------------------------------------------- purchases (0.7.7)
-- Forever gives no spellbook API and no spell id in the trainer rows, and a window whose "Already Known" filter is off simply stops listing a learned spell, so a trainer read alone cannot say
-- that a purchase worked (0.7.6 left Rockbiter Weapon listed). The primary signal is therefore the player's own action plus the client's own learn event: a post-hook on BuyTrainerService
-- remembers WHICH available row was bought, and the next learn event (LEARNED_SPELL_IN_TAB, or SPELLS_CHANGED with the price paid) confirms it. A purchase that is refused (not enough money)
-- fires no learn event and is dropped after PENDING_SECS. The trainer's own "used" row and the absence rule in Record stay as the fallback. Nothing here is persisted: a pending purchase is
-- session memory tied to the character that made it.

local groupOf
local PENDING_SECS, PENDING_MAX = 20, 5
S.pending = {}
S.stats = { bought = 0, confirmed = 0, expired = 0 }
S.hook = "not installed"

local function clock()
	if type(_G.GetTime) == "function" then local ok, t = pcall(_G.GetTime) if ok and type(t) == "number" then return t end end
	return wall()
end
local function money()
	if type(_G.GetMoney) == "function" then local ok, m = pcall(_G.GetMoney) if ok and type(m) == "number" then return m end end
	return nil
end

--- Ranks are bought in order, so buying a rank means every lower rank of the same spell is known: mark them learned so they never come back.
local function retireLower(st, e)
	local ord = e.rankNum or e.levelReq
	if not ord then return end
	local g = groupOf(e)
	for _, o in pairs(st.entries) do
		local ordO = o.rankNum or o.levelReq
		if o ~= e and not o.learned and ordO and ordO < ord and groupOf(o) == g then o.learned, o.learnedBy = true, "a higher rank of it was bought" end
	end
end

local function confirm(p, ctx)
	local st = store(ctx)
	local e = matchEntry(st, p)
	if not e then
		e = { id = p.id, name = p.name, rank = p.rank, rankNum = rankNumber(p.rank), cost = p.cost, levelReq = p.levelReq, cat = "available" }
		st.entries[keyOf(p.id, p.name, p.rank, p.levelReq)] = e
	end
	e.learned, e.learnedBy = true, "bought at the trainer (purchase and learn event)"
	retireLower(st, e)
	S.stats.confirmed = S.stats.confirmed + 1
end

--- The post-hook body: BuyTrainerService(index) was called. Remembers the service at that index when it is an AVAILABLE class-trainer row. Returns true when a purchase was remembered.
function S.OnPurchase(index)
	if type(index) ~= "number" then return false end
	local read = S.ReadTrainer()
	if not read.ok or read.tradeskill == true then return false end
	local row
	for _, s in ipairs(read.services) do if s.index == index then row = s break end end
	if not row or row.category ~= "available" then return false end
	for _, p in ipairs(S.pending) do if p.name == row.name and p.rank == row.rank and p.levelReq == row.levelReq then return false end end      -- a double click is one purchase
	S.pending[#S.pending + 1] = { name = row.name, rank = row.rank, cost = row.cost, levelReq = row.levelReq, id = row.id, at = clock(), money = money(), char = ns.Prefs.CharKey() }
	while #S.pending > PENDING_MAX do table.remove(S.pending, 1) end
	S.stats.bought = S.stats.bought + 1
	return true
end

--- Resolves pending purchases. `event` is the event that just fired (LEARNED_SPELL_IN_TAB confirms the oldest purchase whose price was paid; SPELLS_CHANGED confirms purchases whose price was paid),
-- or nil to just re-check (the money may update after the learn event) and drop expired purchases. Returns the number confirmed.
function S.Settle(ctx, event)
	if #S.pending == 0 then return 0 end
	ctx = ctx or (ns.State and ns.State.ctx)
	local now, me, m = clock(), ns.Prefs.CharKey(), money()
	local function paid(p) return p.money == nil or m == nil or p.cost == nil or m <= p.money - p.cost end
	if event == "SPELLS_CHANGED" or event == "LEARNED_SPELL_IN_TAB" then
		for _, p in ipairs(S.pending) do p.sawChange = true end
	end
	if event == "LEARNED_SPELL_IN_TAB" then
		for _, p in ipairs(S.pending) do if p.char == me and not p.sawLearn and paid(p) then p.sawLearn = true break end end
	end
	local keep, n = {}, 0
	for _, p in ipairs(S.pending) do
		if p.char ~= me then
			S.stats.expired = S.stats.expired + 1                                  -- another character's purchase never lands on this one
		elseif now - p.at > PENDING_SECS then
			S.stats.expired = S.stats.expired + 1
		elseif p.sawLearn or (p.sawChange and paid(p)) then
			confirm(p, ctx); n = n + 1
		else
			keep[#keep + 1] = p
		end
	end
	S.pending = keep
	return n
end

--- Installs the BuyTrainerService post-hook once. Never raises; S.hook says what happened (the report shows it, so a client whose Train button does not go through it is visible).
function S.InstallHook()
	if S.hook == "hooked" then return true end
	if type(_G.hooksecurefunc) ~= "function" then S.hook = "hooksecurefunc absent" return false end
	if type(_G.BuyTrainerService) ~= "function" then S.hook = "BuyTrainerService absent" return false end
	local ok, err = pcall(_G.hooksecurefunc, "BuyTrainerService", function(index)
		local okH, e = pcall(S.OnPurchase, index)
		if not okH then ns.RecordError("spell purchase hook", e) end
	end)
	S.hook = ok and "hooked" or ("hook refused: " .. tostring(err))
	return ok
end

--- Boot calls this for LEARNED_SPELL_IN_TAB and SPELLS_CHANGED.
function S.OnLearnEvent(event)
	return S.Settle(ns.State and ns.State.ctx, event)
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

--- Ranks are only compared with ranks of the same kind: by rank text when the entry has it, by level requirement when it has none (the two are not on one scale).
groupOf = function(e) return e.name .. (e.rankNum and "#rank" or "#level") end

local function displayName(e)
	return e.name .. (e.rank and (" " .. e.rank) or "")
end

--- The spells to show now: { rows = { { key, id, name, rank, title, cost, costText } }, total, totalText, partial } or nil when there are none
-- (the section is then not drawn at all). Pure with respect to the plan: it reads the store, the level and the spellbook, nothing else.
function S.List(ctx)
	local st = store(ctx)
	local lvl = ctx and ctx.char and ctx.char.level
	if type(lvl) ~= "number" then return nil end
	S.Settle(ctx)                                 -- a purchase confirmed late (price paid after the learn event) or expired
	seedFromCatalog(st, ctx)                      -- level-gated spells seen on this account's earlier trainer visits appear on level-up, with no visit
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
		local ordK = e.rankNum or e.levelReq
		if isKnown(e, book) and ordK then local g = groupOf(e) knownRank[g] = math.max(knownRank[g] or 0, ordK) end
	end
	local cand = {}
	for _, k in ipairs(keys) do
		local e = st.entries[k]
		local show = not e.learned and not st.dismissed[k] and type(e.levelReq) == "number" and e.levelReq <= lvl
		local ordS = e.rankNum or e.levelReq
		if show and ordS and (knownRank[groupOf(e)] or 0) > ordS then show = false end      -- a higher rank is already known (rank text, else the level requirement orders the ranks)
		if show then cand[#cand + 1] = { key = k, e = e } end
	end
	-- one rank of a spell at a time: the lowest one still to learn (the trainer sells the next rank after the previous)
	local lowest = {}
	for _, c in ipairs(cand) do
		local n = c.e.rankNum or c.e.levelReq          -- (no rank text, as on Forever: the level requirement orders the ranks of one spell)
		local g = groupOf(c.e)
		if n and (lowest[g] == nil or n < lowest[g]) then lowest[g] = n end
	end
	local rows, total, partial = {}, 0, false
	for _, c in ipairs(cand) do
		local e = c.e
		local ord = e.rankNum or e.levelReq
		if not (ord and lowest[groupOf(e)] ~= ord) then
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

--- The account's observed catalog for the character's class as text lines (for /codex spells catalog: a developer can paste it to turn observed windows into shipped data later).
function S.CatalogLines(ctx)
	local cat, class = catalogStore(), classOf(ctx)
	local c = cat and class and cat.classes[class]
	local L = { string.format("SPELL CATALOG (observed trainer windows only) class=%s build=%s", tostring(class), tostring(c and c.build)) }
	local rows = {}
	for _, e in pairs(c and c.entries or {}) do rows[#rows + 1] = e end
	table.sort(rows, function(a, b) if a.levelReq ~= b.levelReq then return a.levelReq < b.levelReq end if a.name ~= b.name then return a.name < b.name end return (a.rank or "") < (b.rank or "") end)
	for _, e in ipairs(rows) do L[#L + 1] = string.format("%d | %s | %s | %s", e.levelReq, e.name, e.rank or "-", tostring(e.cost)) end
	if #rows == 0 then L[#L + 1] = "(empty: open this class's trainer once)" end
	return L
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
	L[#L + 1] = "SPELL TRAINING (class spells the trainer window listed on a past visit; Quest Flow never trains for you)"
	local apis = {}
	for _, n in ipairs({ "GetNumTrainerServices", "GetTrainerServiceInfo", "GetTrainerServiceCost", "GetTrainerServiceLevelReq", "GetTrainerServiceItemLink", "IsTradeskillTrainer", "IsPlayerSpell", "IsSpellKnown", "GetNumSpellTabs", "GetSpellBookItemName" }) do
		apis[#apis + 1] = n .. "=" .. (type(_G[n]) == "function" and "yes" or "NO")
	end
	L[#L + 1] = "  client APIs: " .. table.concat(apis, " ")
	for _, n in ipairs({ "GetSpellInfo", "C_Spell", "C_SpellBook", "GetSpellLink", "C_Trainer" }) do apis[#apis + 1] = n .. "=" .. (_G[n] ~= nil and "yes" or "NO") end
	L[#L + 1] = "  other spell / trainer client names present: " .. table.concat(apis, " ", 11)
	local r = S.lastGood or S.lastRead
	if S.lastRead and S.lastGood and S.lastRead ~= S.lastGood then
		L[#L + 1] = string.format("  latest trainer read was empty (%d service(s): the window closed or was not loaded yet); showing the latest read that listed services", #S.lastRead.services)
	end
	if r then
		L[#L + 1] = string.format("  last trainer read: %s, %d service(s), profession trainer: %s%s", r.ok and "ok" or "FAILED", #r.services,
			r.tradeskill == nil and "unknown" or tostring(r.tradeskill), r.err and (" (" .. r.err .. ")") or "")
		local cats = {}
		for k, v in pairs(r.categories or {}) do cats[#cats + 1] = k .. " x" .. v end
		table.sort(cats)
		L[#L + 1] = "  categories the client gave: " .. (#cats > 0 and table.concat(cats, ", ") or "none")
		for _, line in ipairs(r.sample or {}) do L[#L + 1] = "    " .. line end
		local withId = 0
		for _, s in ipairs(r.services) do if s.id then withId = withId + 1 end end
		L[#L + 1] = string.format("  spell ids in trainer links: %d of %d (a missing id falls back to name and rank)", withId, #r.services)
	else
		L[#L + 1] = "  no trainer window has been read this session"
	end
	L[#L + 1] = string.format("  purchase hook (BuyTrainerService): %s | purchases seen %d, matched by a learn event %d, expired with no learn event %d, waiting %d", S.hook, S.stats.bought, S.stats.confirmed, S.stats.expired, #S.pending)
	L[#L + 1] = string.format("  stored for this character: %d spell(s), %d marked Don't Want to Learn", nE, nD)
	do
		local cat, class = catalogStore(), classOf(ctx)
		local c = cat and class and cat.classes[class]
		local n = 0
		for _ in pairs(c and c.entries or {}) do n = n + 1 end
		L[#L + 1] = string.format("  observed catalog for %s: %d row(s) from this account's trainer windows (%s, build %s); GetTrainerServiceTypeFilter=%s",
			tostring(class), n, c and c.src or "none yet", tostring(c and c.build), type(_G.GetTrainerServiceTypeFilter) == "function" and "yes" or "NO")
	end
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
