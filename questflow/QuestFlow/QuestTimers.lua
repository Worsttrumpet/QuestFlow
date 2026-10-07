-- ForeverCodex.QuestTimers: TIMED QUESTS. The game gives some quests a countdown; the player sees it in the game's own quest UI. Codex shows the same live remaining time, and the
-- planner favours a timed quest more and more as its deadline closes in (see Planner.TimerUrgency): not immediately, because a timed quest exists, but as the SLACK (time left minus the
-- estimated walk and work) shrinks.
--
-- WHERE THE TIME COMES FROM (evidence boundary): only the live client. Codex never takes a duration from QuestieDB or ATT. Which client function answers on Forever is NOT proven by
-- anything in this repository, so the reader tries each known shape behind pcall and the report says which one answered (/codex report, QUEST TIMERS):
--   1. C_QuestLog.GetTimeAllowed(questID)          -> total, elapsed       (remaining = total - elapsed)
--   2. GetQuestTimers() + GetQuestIndexForTimer(i) -> remaining seconds per timed quest, mapped to the log by index
-- If neither answers, no quest is treated as timed and nothing is shown: unknown stays unknown.
--
-- State is kept for the session only (an end time per quest, taken from the client at every context). Remaining time between two reads is end time minus the clock. A quest that leaves
-- the log (handed in, abandoned, failed) or whose time reaches zero stops being urgent and is removed from the card.

local _, ns = ...
local QT = {}
ns.QuestTimers = QT

QT.state = {}          -- [questID] = { endsAt, total, via }
QT.ended = {}          -- [questID] = "GONE" | "EXPIRED" | "COMPLETE" (the last few, for the report)
QT.via = nil
QT.lastTried = {}

local function clock() return type(_G.GetTime) == "function" and _G.GetTime() or 0 end

local function try(fn, ...)
	if type(fn) ~= "function" then return false end
	local r = { pcall(fn, ...) }
	if not r[1] then return false end
	table.remove(r, 1)
	return true, r
end

--- Reads the client for every timed quest in `log` ({ [id] = { index } }). Returns { [questID] = { remaining, total } }, via ("GetTimeAllowed" | "GetQuestTimers" | nil).
function QT.Read(log)
	local out, via = {}, nil
	local tried = {
		GetTimeAllowed = type(_G.C_QuestLog) == "table" and type(_G.C_QuestLog.GetTimeAllowed) == "function",
		GetQuestTimers = type(_G.GetQuestTimers) == "function", GetQuestIndexForTimer = type(_G.GetQuestIndexForTimer) == "function",
	}
	QT.lastTried = tried
	if tried.GetTimeAllowed then
		for id in pairs(log or {}) do
			local ok, r = try(_G.C_QuestLog.GetTimeAllowed, id)
			if ok and type(r[1]) == "number" and r[1] > 0 then
				local elapsed = type(r[2]) == "number" and r[2] or 0
				out[id] = { remaining = math.max(0, r[1] - elapsed), total = r[1] }
				via = "GetTimeAllowed"
			end
		end
	end
	if not via and tried.GetQuestTimers and tried.GetQuestIndexForTimer then
		local byIndex = {}
		for id, e in pairs(log or {}) do if type(e.index) == "number" then byIndex[e.index] = id end end
		local ok, r = try(_G.GetQuestTimers)
		if ok then
			for i, rem in ipairs(r) do
				if type(rem) == "number" then
					local okI, ri = try(_G.GetQuestIndexForTimer, i)
					local id = okI and byIndex[ri[1]] or nil
					if id then out[id] = { remaining = math.max(0, rem) } via = "GetQuestTimers" end
				end
			end
		end
	end
	return out, via
end

--- Called with every fresh context (before the planner): refreshes the session state from the client.
function QT.Observe(ctx)
	local log = ctx and ctx.log or {}
	local read, via = QT.Read(log)
	local now = clock()
	if via then QT.via = via end
	for id, r in pairs(read) do
		local e = QT.state[id]
		if not e then e = {}; QT.state[id] = e end
		e.endsAt, e.total, e.via = now + r.remaining, r.total or e.total, via
	end
	for id, e in pairs(QT.state) do
		if not read[id] then
			local entry = log[id]
			QT.ended[id] = (entry and entry.complete) and "COMPLETE" or (entry and "EXPIRED") or "GONE"
			QT.state[id] = nil
		end
	end
	ctx.timers = read
end

--- Live seconds left for a timed quest (0 when the time is up), or nil when the quest is not timed.
function QT.Remaining(id)
	local e = QT.state[id]
	if not e then return nil end
	return math.max(0, e.endsAt - clock())
end

--- { remaining, total } for the planner / provider, or nil for a quest that is not timed (or already out of time).
function QT.Get(id)
	local r = QT.Remaining(id)
	if r == nil or r <= 0 then return nil end
	return { remaining = r, total = QT.state[id].total }
end

function QT.AnyActive()
	for _ in pairs(QT.state) do return true end
	return false
end

--- "2:00", "0:45", "1:02:03".
function QT.Format(sec)
	sec = math.max(0, math.floor((sec or 0) + 0.5))
	local h, m, s = math.floor(sec / 3600), math.floor(sec / 60) % 60, sec % 60
	if h > 0 then return string.format("%d:%02d:%02d", h, m, s) end
	return string.format("%d:%02d", m, s)
end

QT.WARN_SECONDS = 300       -- the card turns gold under this many seconds left, red under CRITICAL (display only; the planner uses the slack, see Planner.TimerUrgency)
QT.CRITICAL_SECONDS = 120

--- The TIMED QUEST card rows, soonest deadline first: { { quest, title, remaining, text, level = "OK" | "WARN" | "CRITICAL" | "EXPIRED" } }.
function QT.List(ctx)
	local out = {}
	for id in pairs(QT.state) do
		local r = QT.Remaining(id)
		local entry = ctx and ctx.log and ctx.log[id]
		local view = ns.Registry and ns.Registry.Quest(id)
		local title = (view and view.name) or (entry and entry.title) or ("quest " .. id)
		local level = (r <= 0 and "EXPIRED") or (r <= QT.CRITICAL_SECONDS and "CRITICAL") or (r <= QT.WARN_SECONDS and "WARN") or "OK"
		out[#out + 1] = { quest = id, title = title, remaining = r, text = r > 0 and ("Time remaining: " .. QT.Format(r)) or "Time is up", level = level, complete = entry and entry.complete or false }
	end
	table.sort(out, function(a, b) if a.remaining ~= b.remaining then return a.remaining < b.remaining end return a.quest < b.quest end)
	return out
end

function QT.ReportLines(ctx)
	local L = { "QUEST TIMERS (live time from the client only; nothing is taken from quest data)" }
	local t = QT.lastTried
	L[#L + 1] = string.format("  client: C_QuestLog.GetTimeAllowed=%s GetQuestTimers=%s GetQuestIndexForTimer=%s | reader that answered: %s", t.GetTimeAllowed and "yes" or "NO", t.GetQuestTimers and "yes" or "NO",
		t.GetQuestIndexForTimer and "yes" or "NO", tostring(QT.via or "none yet (no timed quest seen, or no API answered)"))
	local list = QT.List(ctx)
	if #list == 0 then L[#L + 1] = "  no timed quest is active" end
	for _, r in ipairs(list) do L[#L + 1] = string.format("  Q%d %s | %s | %s", r.quest, tostring(r.title), r.text, r.level) end
	for id, why in pairs(QT.ended) do L[#L + 1] = string.format("  ended: Q%d (%s)", id, why) end
	return L
end

function QT._Reset() QT.state, QT.ended, QT.via = {}, {}, nil end
