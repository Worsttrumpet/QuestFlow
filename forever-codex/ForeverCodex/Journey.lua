-- ForeverCodex.Journey: "what have I done?" A small, durable, per-character history built ONLY from things Codex actually
-- observed: the level it saw the character at, and each quest turn-in it saw (QUEST_TURNED_IN, proven on Forever in M8.8,
-- which also reports the XP awarded). Nothing is inferred and nothing is back-filled: quests finished before Codex was
-- installed are not listed (they cannot be enumerated), and the history says when Codex started watching.
--
-- Stored in ForeverCodexDB.chars[key].journey = { entries = {...}, lastLevel = n, turnedIn = { [questId] = true } }.
-- Entries: { k = "start"|"level"|"quest", t = wall time, lvl = level, id = questId, xp = number }. Capped; the first
-- entry (start) is always kept.

local addonName, ns = ...
local P = ns.Prefs
local R = ns.Registry

local J = {}
ns.Journey = J

J.CAP = 150

local function wall()
	if type(time) == "function" then
		local ok, t = pcall(time)
		if ok and type(t) == "number" then return t end
	end
	return 0
end

local function store()
	local j = P.Char().journey
	j.turnedIn = type(j.turnedIn) == "table" and j.turnedIn or {}
	return j
end

local function add(entry)
	local j = store()
	entry.t = wall()
	j.entries[#j.entries + 1] = entry
	while #j.entries > J.CAP do table.remove(j.entries, 2) end    -- keep the start entry
end

--- Called with every fresh Context: notices level changes (level reads are proven; the level-up EVENT is not needed).
function J.OnContext(ctx)
	local lvl = ctx and ctx.char and ctx.char.level
	if type(lvl) ~= "number" then return end
	local j = store()
	if j.lastLevel == nil then
		j.lastLevel = lvl
		add({ k = "start", lvl = lvl })
	elseif lvl > j.lastLevel then
		j.lastLevel = lvl
		add({ k = "level", lvl = lvl })
	elseif lvl < j.lastLevel then
		j.lastLevel = lvl         -- (never a milestone going down)
	end
end

--- Called from QUEST_TURNED_IN(questID, xp, money).
function J.OnQuestTurnedIn(id, xp)
	if type(id) ~= "number" then return end
	local j = store()
	local last = j.entries[#j.entries]
	if last and last.k == "quest" and last.id == id and last.t == wall() then return end      -- the same event twice
	j.turnedIn[id] = true
	add({ k = "quest", id = id, xp = type(xp) == "number" and xp or nil, lvl = j.lastLevel })
end

--- True if Codex itself saw this quest turned in.
function J.SawTurnIn(id) return store().turnedIn[id] == true end

--- How many turn-ins Codex has seen for this character (part of the progression stamp, see OfferProbe.Stamp).
function J.TurnedInCount()
	local n = 0
	for _ in pairs(store().turnedIn) do n = n + 1 end
	return n
end

local function questName(id)
	local v = R.Quest(id)
	return v and v.name or "a quest"
end

local function dateText(t)
	if t and t > 0 and type(date) == "function" then
		local ok, s = pcall(date, "%b %d", t)
		if ok and type(s) == "string" then return s end
	end
	return nil
end

--- What the Journey page shows. Only recorded facts.
function J.View(limit)
	limit = limit or 12
	local j = store()
	local v = { lines = {}, stats = {}, empty = nil }
	local started, quests, xp = nil, 0, 0
	for _, e in ipairs(j.entries) do
		if e.k == "start" then started = e.lvl end
		if e.k == "quest" then
			quests = quests + 1
			xp = xp + (e.xp or 0)
		end
	end
	if started then v.stats[#v.stats + 1] = string.format("Codex began watching this character at level %d.", started) end
	v.stats[#v.stats + 1] = string.format("Quests you turned in while Codex was watching: %d", quests)
	if xp > 0 then v.stats[#v.stats + 1] = string.format("Quest experience earned in those turn-ins: %d", xp) end
	for i = #j.entries, 1, -1 do
		local e = j.entries[i]
		if #v.lines >= limit then break end
		local text
		if e.k == "level" then text = "Reached level " .. e.lvl
		elseif e.k == "quest" then text = "Completed " .. questName(e.id) .. (e.lvl and (" (level " .. e.lvl .. ")") or "")
		elseif e.k == "start" then text = "Codex started watching (level " .. tostring(e.lvl) .. ")" end
		if text then
			local d = dateText(e.t)
			v.lines[#v.lines + 1] = d and (d .. ": " .. text) or text
		end
	end
	if #j.entries == 0 then v.empty = "Nothing recorded yet. Play, and your journey will appear here." end
	return v
end
