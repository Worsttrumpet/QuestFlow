-- ForeverCodex.Professions: the PROFESSIONS section of the Codex window. A small status and reminder card, NOT a profession guide: what professions the character has,
-- their skill and cap, a secondary profession not yet learned, whether a primary slot is free, and a trainer-offered rank-up the player has not taken.
-- No leveling advice, no routes, no trainer locations, no recipes, no Learn button. Informational only; the player trains normally.
--
-- WHAT IS KNOWN ABOUT THE CLIENT (evidence boundary; read docs/CODEX_PROFESSIONS.md):
--   * The Classic skill-line functions GetNumSkillLines / GetSkillLineInfo were reported ABSENT by real Forever reports (build 70205): see Items.lua / EligibilityEvidence.
--   * Nothing in this repository proves which profession API the Forever client DOES answer. So the reader tries, in order, every shape a client of this family is known to
--     use, each behind pcall, and reports which one answered (/codex professions, /codex report):
--       1. GetProfessions() + GetProfessionInfo(i)      (name, icon, rank, maxRank, numSpells, spellOffset, skillLine ...)
--       2. GetNumSkillLines() + GetSkillLineInfo(i)     (header rows "Professions" / "Secondary Skills", then name, rank, max)
--     If neither answers, the section is hidden: unknown stays unknown, nothing is guessed.
--   * UNVERIFIED reference, labelled as such everywhere: the three secondary professions (Fishing, Cooking, First Aid) and their skill-line ids (356, 185, 129), and the
--     number of primary slots (2). They come from the Classic rule set, not from anything observed on Forever. They are used only for the "Not Learned" and slot lines, and
--     only when the reader succeeded. English names are matched when the client gives no skill-line id (a localized client may not match: then the line is simply absent).
--   * A rank-up is reported ONLY from the client's own trainer window (the same TRAINER_SHOW / TRAINER_UPDATE read Spell Training uses): a profession trainer's service that is
--     "available" and whose name carries one of the character's profession names and is not that bare name ("Journeyman Skinning"). No rank words, no skill thresholds are
--     hard-coded. It is cleared when the profession's cap rises (the trainer's training was taken) or the trainer shows the service as learned.
--
-- Per character (Prefs.Char().professions): { rankUps = { [key] = { service, maxAt } }, hidden = { [key] = true } }. Nothing else is stored: skill and cap are read live.

local _, ns = ...
local P = {}
ns.Professions = P

P.MAX_PRIMARY = 2            -- ASSUMED (Classic rule), not observed on Forever
P.SECONDARY = {              -- UNVERIFIED reference list (Classic): key, English name, skill-line id
	{ key = "fishing", name = "Fishing", skillLine = 356 },
	{ key = "cooking", name = "Cooking", skillLine = 185 },
	{ key = "firstaid", name = "First Aid", skillLine = 129 },
}
local SECONDARY_BY_LINE, SECONDARY_BY_NAME = {}, {}
for _, s in ipairs(P.SECONDARY) do SECONDARY_BY_LINE[s.skillLine] = s; SECONDARY_BY_NAME[s.name:lower()] = s end

local function call(fn, ...)
	if type(fn) ~= "function" then return false end
	local r = { pcall(fn, ...) }
	if not r[1] then return false end
	table.remove(r, 1)
	return true, r[1], r[2], r[3], r[4], r[5], r[6], r[7], r[8], r[9]
end

-- ---------------------------------------------------------------- the per-character store

local function store()
	local c = ns.Prefs.Char()
	local st = c.professions
	if type(st) ~= "table" then st = {}; c.professions = st end
	st.rankUps = type(st.rankUps) == "table" and st.rankUps or {}
	st.hidden = type(st.hidden) == "table" and st.hidden or {}
	return st
end

-- ---------------------------------------------------------------- reading the client

local function keyOf(skillLine, name)
	if type(skillLine) == "number" then return "S:" .. skillLine end
	return "N:" .. tostring(name):lower()
end

local function classify(name, skillLine)
	local sec = (skillLine and SECONDARY_BY_LINE[skillLine]) or (type(name) == "string" and SECONDARY_BY_NAME[name:lower()]) or nil
	return sec
end

--- Reads the character's professions. Returns { ok, via, list = { { key, name, rank, max, kind = "primary" | "secondary" | nil, skillLine, secondary = key } }, err, tried = { api = bool } }.
-- Never raises. `ok` means a reader answered (an empty list is a real answer: no professions).
function P.Read()
	local r = { ok = false, list = {}, tried = {} }
	for _, n in ipairs({ "GetProfessions", "GetProfessionInfo", "GetNumSkillLines", "GetSkillLineInfo" }) do r.tried[n] = type(_G[n]) == "function" end
	-- 1. GetProfessions / GetProfessionInfo
	if r.tried.GetProfessions and r.tried.GetProfessionInfo then
		local okP, a, b, c, d, e = call(_G.GetProfessions)
		if okP then
			r.ok, r.via = true, "GetProfessions"
			local idx = { a, b, c, d, e }
			for pos = 1, 5 do
				local i = idx[pos]
				if type(i) == "number" then
					local okI, name, _, rank, maxRank, _, _, skillLine = call(_G.GetProfessionInfo, i)
					if okI and type(name) == "string" and name ~= "" then
						local sec = classify(name, type(skillLine) == "number" and skillLine or nil)
						r.list[#r.list + 1] = { key = keyOf(skillLine, name), name = name, rank = type(rank) == "number" and rank or nil, max = type(maxRank) == "number" and maxRank or nil,
							skillLine = type(skillLine) == "number" and skillLine or nil, secondary = sec and sec.key or nil,
							kind = sec and "secondary" or ((pos == 1 or pos == 2) and "primary" or nil) }
					end
				end
			end
			return r
		end
	end
	-- 2. GetNumSkillLines / GetSkillLineInfo (header rows name the section)
	if r.tried.GetNumSkillLines and r.tried.GetSkillLineInfo then
		local okN, n = call(_G.GetNumSkillLines)
		if okN and type(n) == "number" then
			r.ok, r.via = true, "GetSkillLineInfo"
			local section
			for i = 1, n do
				local okI, name, header, _, rank, _, _, maxRank = call(_G.GetSkillLineInfo, i)
				if okI and type(name) == "string" then
					if header == true or header == 1 then
						local low = name:lower()
						section = (low == "professions" and "primary") or (low == "secondary skills" and "secondary") or "other"
					elseif section == "primary" or section == "secondary" then
						local sec = classify(name, nil)
						r.list[#r.list + 1] = { key = keyOf(nil, name), name = name, rank = type(rank) == "number" and rank or nil, max = type(maxRank) == "number" and maxRank or nil,
							secondary = sec and sec.key or nil, kind = section }
					end
				end
			end
			return r
		end
	end
	r.err = "no profession API answered (GetProfessions / GetSkillLineInfo)"
	return r
end

P.lastRead = nil

-- ---------------------------------------------------------------- rank-ups from the trainer window

--- Called at TRAINER_SHOW / TRAINER_UPDATE with ns.SpellTraining.ReadTrainer()'s result. Only a PROFESSION trainer counts (the client says so itself).
function P.OnTrainerRead(read)
	if not (read and read.ok) or read.tradeskill ~= true then return 0 end
	local mine = P.Read()
	P.lastRead = mine
	if not mine.ok then return 0 end
	local st = store()
	local n = 0
	for _, s in ipairs(read.services) do
		local low = s.name:lower()
		for _, p in ipairs(mine.list) do
			local pl = p.name:lower()
			if low ~= pl and low:find(pl, 1, true) then
				if s.category == "available" then
					st.rankUps[p.key] = { service = s.name, maxAt = p.max }
					n = n + 1
				elseif s.category == "used" and st.rankUps[p.key] and st.rankUps[p.key].service == s.name then
					st.rankUps[p.key] = nil
				end
			end
		end
	end
	return n
end

function P.OnTrainerEvent()
	if not ns.SpellTraining then return 0 end
	return P.OnTrainerRead(ns.SpellTraining.lastRead or ns.SpellTraining.ReadTrainer())
end

-- ---------------------------------------------------------------- the card

--- { rows = { { text, kind = "status" | "rank" | "missing" | "slots", key } } } or nil when there is nothing useful (the section is then not drawn).
function P.Card(ctx)
	local ok, v = pcall(P.View, ctx)
	if not ok then ns.RecordError("professions", v) return nil end
	return v
end

function P.View(ctx)
	local r = P.Read()
	P.lastRead = r
	if not r.ok then return nil end
	local st = store()
	local rows, have, primaries = {}, {}, 0
	local list = {}
	for _, p in ipairs(r.list) do list[#list + 1] = p end
	table.sort(list, function(a, b)
		if (a.kind == "primary") ~= (b.kind == "primary") then return a.kind == "primary" end
		return a.name < b.name
	end)
	for _, p in ipairs(list) do
		have[p.key] = true
		if p.secondary then have[p.secondary] = true end
		if p.kind == "primary" then primaries = primaries + 1 end
		rows[#rows + 1] = { kind = "status", key = p.key, text = p.name .. " " .. tostring(p.rank or "?") .. (p.max and ("/" .. p.max) or "") }
		local ru = st.rankUps[p.key]
		if ru then
			if p.max ~= nil and ru.maxAt ~= nil and p.max > ru.maxAt then st.rankUps[p.key] = nil          -- the cap rose: it was trained
			else rows[#rows + 1] = { kind = "rank", key = p.key, text = ru.service .. " available" } end
		end
	end
	for key in pairs(st.rankUps) do                                                                           -- a profession that is gone takes its reminder with it
		local still = false
		for _, p in ipairs(list) do if p.key == key then still = true end end
		if not still then st.rankUps[key] = nil end
	end
	for _, s in ipairs(P.SECONDARY) do
		if not have[s.key] and not st.hidden[s.key] then rows[#rows + 1] = { kind = "missing", key = s.key, text = s.name .. " - Not Learned" } end
	end
	local free = P.MAX_PRIMARY - primaries
	if free > 0 then rows[#rows + 1] = { kind = "slots", text = string.format("%d primary profession slot%s available", free, free == 1 and "" or "s") } end
	if #rows == 0 then return nil end
	return { rows = rows, primaries = primaries, free = math.max(0, free), via = r.via }
end

--- Stops showing "<secondary> - Not Learned" for this character (the player is in control). key = "fishing" | "cooking" | "firstaid".
function P.Hide(key)
	local known = false
	for _, s in ipairs(P.SECONDARY) do if s.key == key then known = true end end
	if not known then return false end
	store().hidden[key] = true
	if ns.State and ns.State.Recompute then ns.State.Recompute("professions") end
	return true
end

function P.RestoreAll()
	local st = store()
	local n = 0
	for k in pairs(st.hidden) do st.hidden[k] = nil; n = n + 1 end
	if n > 0 and ns.State and ns.State.Recompute then ns.State.Recompute("professions") end
	return n
end

function P.ReportLines(ctx)
	local L = {}
	local r = P.Read()
	L[#L + 1] = "PROFESSIONS (status only; skill and cap are read live from the client, nothing is guessed)"
	local apis = {}
	for _, n in ipairs({ "GetProfessions", "GetProfessionInfo", "GetNumSkillLines", "GetSkillLineInfo" }) do apis[#apis + 1] = n .. "=" .. (r.tried[n] and "yes" or "NO") end
	L[#L + 1] = "  client APIs: " .. table.concat(apis, " ")
	if not r.ok then
		L[#L + 1] = "  reader: FAILED (" .. tostring(r.err) .. "): the section is hidden"
		return L
	end
	L[#L + 1] = string.format("  reader: %s answered, %d profession(s)", tostring(r.via), #r.list)
	for _, p in ipairs(r.list) do
		L[#L + 1] = string.format("  - %s %s/%s | %s%s%s", p.name, tostring(p.rank), tostring(p.max), p.kind or "kind unknown", p.skillLine and (" | skill line " .. p.skillLine) or " | no skill-line id", p.secondary and (" | secondary list: " .. p.secondary) or "")
	end
	local st = store()
	for k, ru in pairs(st.rankUps) do L[#L + 1] = string.format("  rank-up seen at a profession trainer: %s (%s), cap then %s", ru.service, k, tostring(ru.maxAt)) end
	local v = P.View(ctx)
	L[#L + 1] = "  assumptions (UNVERIFIED on Forever): primary slots = " .. P.MAX_PRIMARY .. "; secondary professions = Fishing, Cooking, First Aid (skill lines 356, 185, 129)"
	L[#L + 1] = "  showing: " .. (v and (#v.rows .. " row(s), " .. v.free .. " free primary slot(s)") or "nothing (hidden)")
	return L
end
