-- ForeverCodex.Telemetry: a quiet recorder of RAW gameplay observations. It records; it never decides.
--
-- Purpose: give a future Fast route strategy real evidence about THIS character's performance (XP gained, kills,
-- time in combat, time travelling, quest durations) instead of static assumptions. The recorder is independent of
-- the route engine, Strategies, the UI and navigation: it listens to the client on its own frame and appends events
-- to a small capped log. The engine can later READ it (see TelemetryMetrics.lua); nothing reads it today.
--
-- Evidence philosophy (same as the rest of Codex): every recorded value is an OBSERVATION; derived numbers live in
-- TelemetryMetrics and are labelled "calculated" or "estimated". Each event type also carries a verification status:
--   verified    its event / API was proven on the real Forever client in an earlier milestone (evidence cited)
--   unverified  standard Classic event/API that this project has NEVER observed on Forever; it may not fire, or
--               may behave differently. /codex diag and /codex telemetry show, per event type, whether it was
--               registered and how many events were actually recorded this session, so the first real-client run
--               answers the question instead of this file guessing.
--
-- Events (fields are all observed values; `t` = GetTime() seconds, 2 decimals; `w` = time() epoch seconds):
--   SESSION        login marker: w, v (schema), lvl, xp, max, build.  Durations/rates only span ONE session.
--   XP_GAIN        d (XP gained), xp, max, lvl, src ("event"|"poll"|"level_event"), sk (seconds since the last kill, only if
--                  <= 10), lvlup (true when the gain crossed a level), multi (true if several levels at once)
--   MOB_KILL       UNAVAILABLE on Forever: the combat log cannot be registered by addons (see WATCHED_EVENTS). Never recorded.
--   LEVEL_UP       lvl, src
--   QUEST_ACCEPT   q, w
--   QUEST_COMPLETE q, dur (wall seconds since accept, only if the accept was seen).  = OBJECTIVES complete (log diff), not turn-in.
--   QUEST_TURNIN   q, xp, money (from QUEST_TURNED_IN, verified), dur
--   PLAYER_MOVE    one movement SEGMENT: dur, dist (yards), map, x0,y0,x1,y1 (map fractions), approx (distance estimated from map
--                  fractions because world coordinates were unavailable)
--   COMBAT_START / COMBAT_END   (dur on END).  Source: PLAYER_REGEN_DISABLED / ENABLED.
--
-- Privacy / size: only numeric ids and timings are stored. A raw GUID is NEVER stored (a creature id is parsed from it
-- and the GUID is dropped, per the project's GuidUtil rule); no names, no chat, no account data. The log is capped
-- (default 300 events) and lives directly in ForeverCodexDB.telemetry, so /reload saves it with everything else.
-- Persistence caveat (docs/M8_0_SCOPE.md): logout saves can fail on Forever; /reload is reliable.
--
-- Not captured (unavailable or deliberately out of scope): DPS / damage, healing, loot, money income outside quest
-- rewards, AFK vs reading vs inventory idle (downtime is simply "not fighting and not moving"), mounted/flying
-- state, XP source attribution beyond timing, rested-XP state, death/repair time, group XP sharing.

local addonName, ns = ...

local T = {}
ns.Telemetry = T

T.SCHEMA = 1
local DEFAULT_CAP = 300
local TICK_SECONDS = 1.0          -- polling cadence: movement sampling, XP poll fallback, quest-log diff
local MOVE_EPS = 2.0              -- yards per sample that count as moving (walking is ~7 yd/s)
local MAX_STEP = 120              -- yards per sample: more is a teleport/flight/loading screen, not walking
local STILL_SAMPLES = 2           -- consecutive still samples that end a movement segment
local MAX_SEGMENT = 120           -- seconds: longer travel is split into several PLAYER_MOVE events
local MIN_SEG_DUR, MIN_SEG_DIST = 1, 5
local KILL_LINK = 10              -- seconds: an XP gain this soon after a kill carries `sk`
local MAX_ACCEPTED = 60           -- remembered quest accept times (for durations)
local MAP_YARDS = 3000            -- rough yards per full map width, ONLY for the flagged approximate fallback

-- ---------------------------------------------------------------- what we know about each event type

--- Static knowledge, not runtime state. `verified` means proven on the real Forever client earlier in this project.
T.EVENT_DEFS = {
	{ type = "QUEST_ACCEPT", sources = { "QUEST_ACCEPTED" }, verified = true, evidence = "M8.7: fires once per accept, arg = questID" },
	{ type = "QUEST_COMPLETE", sources = { "UNIT_QUEST_LOG_CHANGED", "QUEST_LOG_UPDATE", "C_QuestLog.IsComplete" }, verified = true,
		evidence = "M8.9: log diffing detected 15/15 objective changes; the events carry no quest id, so the diff finds it" },
	{ type = "QUEST_TURNIN", sources = { "QUEST_TURNED_IN" }, verified = true, evidence = "M8.8: (questID, xp, money), XP matched the client's line" },
	{ type = "PLAYER_MOVE", sources = { "C_Map.GetPlayerMapPosition (1 Hz sampling)" }, verified = true,
		evidence = "M8.10: position + world conversion proven on Forever; the segmenting logic is Codex's own and untested on the client" },
	{ type = "XP_GAIN", sources = { "PLAYER_XP_UPDATE", "UnitXP/UnitXPMax (poll)" }, verified = false, evidence = "never probed on Forever" },
	{ type = "LEVEL_UP", sources = { "PLAYER_LEVEL_UP", "UnitLevel (poll)" }, verified = false, evidence = "UnitLevel is proven on Forever; PLAYER_LEVEL_UP and the XP wrap are not" },
	{ type = "MOB_KILL", sources = { "COMBAT_LOG_EVENT_UNFILTERED / PARTY_KILL" }, verified = false, unavailable = true,
		evidence = "Forever BLOCKS addon registration of COMBAT_LOG_EVENT_UNFILTERED (real client: IsEventRegistered=false plus a taint popup); kills cannot be counted this way" },
	{ type = "COMBAT_START", sources = { "PLAYER_REGEN_DISABLED" }, verified = false, evidence = "never probed on Forever" },
	{ type = "COMBAT_END", sources = { "PLAYER_REGEN_ENABLED" }, verified = false, evidence = "never probed on Forever" },
}

local WATCHED_EVENTS = { "PLAYER_XP_UPDATE", "PLAYER_LEVEL_UP", "QUEST_ACCEPTED", "QUEST_TURNED_IN", "UNIT_QUEST_LOG_CHANGED",
	"QUEST_LOG_UPDATE", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED" }
-- COMBAT_LOG_EVENT_UNFILTERED is deliberately NOT here: the Forever client refuses an addon's registration of it and raises a
-- taint popup ("ForeverCodex has been blocked from an action only available to the Blizzard UI"; real-client taint log
-- pointed at registerAll). The MOB_KILL handler below stays for a future, proven source, but nothing feeds it today.

-- ---------------------------------------------------------------- client readers (replaceable in tests)

local function pcallValue(fn, ...)
	if type(fn) ~= "function" then return nil end
	local ok, a, b, c = pcall(fn, ...)
	if ok then return a, b, c end
	return nil
end

local function defaultPosition()
	if type(C_Map) ~= "table" or type(C_Map.GetBestMapForUnit) ~= "function" then return nil end
	local map = pcallValue(C_Map.GetBestMapForUnit, "player")
	if type(map) ~= "number" then return nil end
	local pos = pcallValue(C_Map.GetPlayerMapPosition, map, "player")
	if type(pos) ~= "table" then return nil end
	local x, y
	if type(pos.GetXY) == "function" then
		local ok, a, b = pcall(pos.GetXY, pos)
		if ok then x, y = a, b end
	end
	x, y = x or pos.x, y or pos.y
	if type(x) ~= "number" or type(y) ~= "number" or (x == 0 and y == 0) then return nil end
	local p = { map = map, x = x, y = y }
	if type(CreateVector2D) == "function" and type(C_Map.GetWorldPosFromMapPos) == "function" then
		local v = pcallValue(CreateVector2D, x, y)
		if v then
			local cont, wp = pcallValue(C_Map.GetWorldPosFromMapPos, map, v)
			if cont and type(wp) == "table" then
				local wx, wy
				if type(wp.GetXY) == "function" then
					local ok, a, b = pcall(wp.GetXY, wp)
					if ok then wx, wy = a, b end
				end
				wx, wy = wx or wp.x, wy or wp.y
				if type(wx) == "number" and type(wy) == "number" then p.cont, p.wx, p.wy = cont, wx, wy end
			end
		end
	end
	return p
end

--- { [questID] = complete(bool) } for the player's quest log, or nil if the log API is unavailable.
local function defaultQuestLog()
	if type(C_QuestLog) ~= "table" or type(C_QuestLog.GetNumQuestLogEntries) ~= "function" then return nil end
	local n = pcallValue(C_QuestLog.GetNumQuestLogEntries)
	if type(n) ~= "number" then return nil end
	local log = {}
	for i = 1, n do
		local info = pcallValue(C_QuestLog.GetInfo, i)
		if type(info) == "table" and not info.isHeader and type(info.questID) == "number" then
			local id = info.questID
			log[id] = pcallValue(C_QuestLog.IsComplete, id) == true or pcallValue(C_QuestLog.ReadyForTurnIn, id) == true
		end
	end
	return log
end

T.reader = {
	now = function() return type(GetTime) == "function" and GetTime() or 0 end,
	wall = function() return type(time) == "function" and time() or 0 end,
	level = function() return pcallValue(UnitLevel, "player") end,
	xp = function() return pcallValue(UnitXP, "player") end,
	xpMax = function() return pcallValue(UnitXPMax, "player") end,
	position = defaultPosition,
	questLog = defaultQuestLog,
}

-- ---------------------------------------------------------------- state

local frame = CreateFrame("Frame")
local started = false
local registered = {}           -- watched event -> true/false (did RegisterEvent succeed?)
local seen = {}                 -- telemetry event type -> count recorded this session
local lastKillT = nil
local combatStart = nil
local xpState = {}              -- lvl, cur, max, pendingDrop, anomalies
local moveState = {}            -- last = last sample, seg = open segment, still = consecutive still samples
local logPrev = nil             -- questID -> complete at the previous diff
local logDirty = false
local sinceTick = 0
T.anomalies = 0                 -- XP decreases without a level change, teleports skipped, etc. (diagnostic only)

local function round2(v) return math.floor(v * 100 + 0.5) / 100 end

local function now() return T.reader.now() end

local function store()
	if type(ForeverCodexDB) ~= "table" then return nil end
	local s = ForeverCodexDB.telemetry
	if type(s) ~= "table" then
		s = {}
		ForeverCodexDB.telemetry = s
	end
	if s.v == nil then s.v = T.SCHEMA end
	if s.enabled == nil then s.enabled = true end
	if type(s.cap) ~= "number" or s.cap < 50 then s.cap = DEFAULT_CAP end
	s.events = type(s.events) == "table" and s.events or {}
	s.accepted = type(s.accepted) == "table" and s.accepted or {}
	return s
end

function T.IsEnabled()
	local s = store()
	return s ~= nil and s.enabled == true
end

--- Appends one event (observed values only) to the capped log. Returns the event, or nil when disabled.
function T.Record(e, fields)
	local s = store()
	if not s or not s.enabled then return nil end
	local ev = fields or {}
	ev.e = e
	ev.t = round2(now())
	local list = s.events
	list[#list + 1] = ev
	while #list > s.cap do table.remove(list, 1) end
	seen[e] = (seen[e] or 0) + 1
	return ev
end

--- The live event list (oldest first). Read-only for callers.
function T.Events()
	local s = store()
	return s and s.events or {}
end

function T.Counts() return seen end

-- ---------------------------------------------------------------- XP and level

local function sinceKill()
	if lastKillT then
		local d = now() - lastKillT
		if d >= 0 and d <= KILL_LINK then return round2(d) end
	end
	return nil
end

local function checkXp(src)
	local r = T.reader
	local lvl, cur, max = r.level(), r.xp(), r.xpMax()
	if type(lvl) ~= "number" or type(cur) ~= "number" then return end
	if xpState.lvl == nil then
		xpState.lvl, xpState.cur, xpState.max = lvl, cur, max
		return
	end
	if lvl > xpState.lvl then
		-- finished the old level, plus progress into the new one. If several levels passed at once the middle levels
		-- are unknown, so the delta is a lower bound and flagged.
		local delta = (xpState.max or 0) - xpState.cur + cur
		T.Record("XP_GAIN", { d = delta, xp = cur, max = max, lvl = lvl, src = src, sk = sinceKill(), lvlup = true,
			multi = (lvl - xpState.lvl > 1) or nil })
		T.Record("LEVEL_UP", { lvl = lvl, src = src })
		xpState.lvl, xpState.cur, xpState.max, xpState.pendingDrop = lvl, cur, max, nil
	elseif lvl == xpState.lvl and cur > xpState.cur then
		T.Record("XP_GAIN", { d = cur - xpState.cur, xp = cur, max = max, lvl = lvl, src = src, sk = sinceKill() })
		xpState.cur, xpState.max, xpState.pendingDrop = cur, max, nil
	elseif lvl == xpState.lvl and cur < xpState.cur then
		-- The XP bar reset can arrive a moment before UnitLevel updates: wait one more check for the level before
		-- treating it as an anomaly (never record a negative gain).
		if xpState.pendingDrop then
			T.anomalies = T.anomalies + 1
			xpState.cur, xpState.max, xpState.pendingDrop = cur, max, nil
		else
			xpState.pendingDrop = true
		end
	elseif lvl < xpState.lvl then
		xpState.lvl, xpState.cur, xpState.max, xpState.pendingDrop = lvl, cur, max, nil   -- e.g. a level reset: rebase silently
	end
end

-- ---------------------------------------------------------------- combat log (kills only)

local function flagSet(flags, mask)
	return flags % (mask * 2) >= mask    -- single-bit test without a bit library
end

--- The creature id from a GUID, or nil. The GUID itself is never returned or stored.
local function creatureId(guid)
	if type(guid) ~= "string" then return nil end
	local kind, npc = guid:match("^(%a+)%-%d+%-%d+%-%d+%-%d+%-(%d+)%-")
	if (kind == "Creature" or kind == "Vehicle") and npc then return tonumber(npc) end
	return nil
end

local function onCombatLog(...)
	local sub, sFlags, dGUID
	if type(CombatLogGetCurrentEventInfo) == "function" then
		local _, s, _, _, _, f, _, d = CombatLogGetCurrentEventInfo()
		sub, sFlags, dGUID = s, f, d
	else
		local _, s, _, _, _, f, _, d = ...
		sub, sFlags, dGUID = s, f, d
	end
	if sub ~= "PARTY_KILL" or type(sFlags) ~= "number" then return end
	local mine = flagSet(sFlags, 0x1)                      -- COMBATLOG_OBJECT_AFFILIATION_MINE
	local party = flagSet(sFlags, 0x2) or flagSet(sFlags, 0x4)   -- PARTY / RAID
	if not (mine or party) then return end
	local npc = creatureId(dGUID)
	if not npc then return end                              -- not a creature (e.g. a player): not a mob kill
	lastKillT = now()
	T.Record("MOB_KILL", { npc = npc, by = mine and "me" or "party", pet = flagSet(sFlags, 0x1000) or nil })
end

-- ---------------------------------------------------------------- quests

local function pruneAccepted(s)
	local n, oldest, oldestId = 0, nil, nil
	for id, w in pairs(s.accepted) do
		n = n + 1
		if not oldest or w < oldest then oldest, oldestId = w, id end
	end
	if n > MAX_ACCEPTED and oldestId then s.accepted[oldestId] = nil end
end

local function duration(s, questId)
	local w0 = s.accepted[questId]
	local w1 = T.reader.wall()
	if w0 and w1 and w1 >= w0 then return w1 - w0 end
	return nil
end

local function onQuestAccepted(questId)
	local s = store()
	if not s or type(questId) ~= "number" then return end
	local w = T.reader.wall()
	s.accepted[questId] = w
	pruneAccepted(s)
	T.Record("QUEST_ACCEPT", { q = questId, w = w })
	logDirty = true
end

local function onQuestTurnedIn(questId, xp, money)
	local s = store()
	if not s or type(questId) ~= "number" then return end
	T.Record("QUEST_TURNIN", { q = questId, xp = type(xp) == "number" and xp or nil, money = type(money) == "number" and money or nil,
		dur = duration(s, questId) })
	s.accepted[questId] = nil
	if logPrev then logPrev[questId] = nil end
	logDirty = true
end

--- Diffs the quest log: a quest whose objectives became complete since the last diff yields QUEST_COMPLETE.
local function diffQuestLog()
	logDirty = false
	local s = store()
	if not s then return end
	local cur = T.reader.questLog()
	if not cur then return end
	if logPrev == nil then
		logPrev = cur
		return
	end
	for id, complete in pairs(cur) do
		local was = logPrev[id]
		local becameComplete = complete and (was == false or (was == nil and s.accepted[id] ~= nil))
		if becameComplete then
			T.Record("QUEST_COMPLETE", { q = id, dur = duration(s, id) })
		end
	end
	logPrev = cur
end

-- ---------------------------------------------------------------- movement

local function distance(a, b)
	if a.cont and b.cont and a.wx and b.wx then
		if a.cont ~= b.cont then return nil, false end
		local dx, dy = a.wx - b.wx, a.wy - b.wy
		return math.sqrt(dx * dx + dy * dy), false
	end
	if a.map == b.map then
		local dx, dy = (a.x - b.x) * MAP_YARDS, (a.y - b.y) * MAP_YARDS
		return math.sqrt(dx * dx + dy * dy), true
	end
	return nil, false
end

local function endSegment(tEnd)
	local seg = moveState.seg
	moveState.seg = nil
	if not seg then return end
	local dur = tEnd - seg.t0
	if dur >= MIN_SEG_DUR and seg.dist >= MIN_SEG_DIST then
		local ev = T.Record("PLAYER_MOVE", { dur = round2(dur), dist = math.floor(seg.dist + 0.5), map = seg.map,
			x0 = math.floor(seg.x0 * 10000 + 0.5) / 10000, y0 = math.floor(seg.y0 * 10000 + 0.5) / 10000,
			x1 = math.floor(seg.x1 * 10000 + 0.5) / 10000, y1 = math.floor(seg.y1 * 10000 + 0.5) / 10000, approx = seg.approx or nil })
		if ev then ev.t = round2(tEnd) end
	end
end

local function sampleMove()
	local t = now()
	local p = T.reader.position()
	local last = moveState.last
	if not p then
		if moveState.seg then endSegment(moveState.lastT or t) end
		moveState.last, moveState.lastT, moveState.still = nil, nil, 0
		return
	end
	if last then
		local d, approx = distance(last, p)
		if d == nil or d > MAX_STEP then
			-- map/continent change, teleport, flight path or loading screen: not walking. End the segment, count nothing.
			if moveState.seg then endSegment(moveState.lastT or t) end
			T.anomalies = T.anomalies + 1
			moveState.still = 0
		elseif d >= MOVE_EPS then
			local seg = moveState.seg
			if not seg then
				seg = { t0 = moveState.lastT or t, dist = 0, map = last.map, x0 = last.x, y0 = last.y, approx = false }
				moveState.seg = seg
			end
			seg.dist = seg.dist + d
			seg.x1, seg.y1 = p.x, p.y
			seg.approx = seg.approx or approx
			seg.lastMoveT = t
			moveState.still = 0
			if t - seg.t0 >= MAX_SEGMENT then endSegment(t) end
		else
			moveState.still = (moveState.still or 0) + 1
			if moveState.seg and moveState.still >= STILL_SAMPLES then endSegment(moveState.seg.lastMoveT or t) end
		end
	end
	moveState.last, moveState.lastT = p, t
end

-- ---------------------------------------------------------------- driving it

--- Called every frame with the elapsed time; does its work about once a second.
function T.Tick(elapsed)
	if not started or not T.IsEnabled() then return end
	sinceTick = sinceTick + (elapsed or 0)
	if sinceTick < TICK_SECONDS then return end
	sinceTick = 0
	local ok, err = pcall(function()
		checkXp("poll")
		sampleMove()
		if logDirty then diffQuestLog() end
	end)
	if not ok then ns.RecordError("telemetry tick", err) end
end

local function registerAll()
	for _, ev in ipairs(WATCHED_EVENTS) do
		local ok = pcall(frame.RegisterEvent, frame, ev)
		registered[ev] = ok and true or false
	end
end

local function unregisterAll()
	for _, ev in ipairs(WATCHED_EVENTS) do pcall(frame.UnregisterEvent, frame, ev) end
end

local function beginSession()
	started = true
	sinceTick = 0
	seen = {}
	moveState = {}
	combatStart, lastKillT = nil, nil
	xpState = {}
	logPrev = nil
	local r = T.reader
	local lvl, cur, max = r.level(), r.xp(), r.xpMax()
	local _, build = pcallValue(GetBuildInfo)
	T.Record("SESSION", { w = r.wall(), v = T.SCHEMA, lvl = lvl, xp = cur, max = max, build = build })
	if type(lvl) == "number" and type(cur) == "number" then
		xpState.lvl, xpState.cur, xpState.max = lvl, cur, max
	end
	logPrev = r.questLog()
end

function T.OnEvent(event, ...)
	local arg1, arg2, arg3 = ...
	if event == "ADDON_LOADED" then
		if arg1 ~= addonName then return end
		local s = store()
		if s and not s.enabled then unregisterAll() end
		return
	end
	if event == "PLAYER_LOGIN" then
		if T.IsEnabled() then beginSession() end
		return
	end
	if not started or not T.IsEnabled() then return end
	local extra = { ... }          -- only the combat-log fallback (old payload-as-arguments API) needs the full list
	local ok, err = pcall(function()
		if event == "PLAYER_XP_UPDATE" then
			checkXp("event")
		elseif event == "PLAYER_LEVEL_UP" then
			checkXp("level_event")
		elseif event == "QUEST_ACCEPTED" then
			onQuestAccepted(arg1)
		elseif event == "QUEST_TURNED_IN" then
			onQuestTurnedIn(arg1, arg2, arg3)
		elseif event == "UNIT_QUEST_LOG_CHANGED" then
			if arg1 == "player" then logDirty = true end
		elseif event == "QUEST_LOG_UPDATE" then
			logDirty = true
		elseif event == "PLAYER_REGEN_DISABLED" then
			if not combatStart then
				combatStart = now()
				T.Record("COMBAT_START", {})
			end
		elseif event == "PLAYER_REGEN_ENABLED" then
			if combatStart then
				T.Record("COMBAT_END", { dur = round2(now() - combatStart) })
				combatStart = nil
			end
		elseif event == "COMBAT_LOG_EVENT_UNFILTERED" then
			onCombatLog(unpack(extra, 1, 12))
		end
	end)
	if not ok then ns.RecordError("telemetry " .. tostring(event), err) end
end

function T.SetEnabled(on)
	local s = store()
	if not s then return false end
	on = on == true
	if on == s.enabled then return true end
	s.enabled = on
	if on then
		registerAll()
		if not started then beginSession() else logPrev = T.reader.questLog() end
	else
		unregisterAll()
		moveState, combatStart = {}, nil
	end
	return true
end

--- Clears the stored log and remembered accept times (the next events start fresh).
function T.Reset()
	local s = store()
	if not s then return end
	s.events, s.accepted = {}, {}
	seen = {}
	T.anomalies = 0
	if started and s.enabled then
		xpState, moveState, combatStart = {}, {}, nil
		beginSession()
	end
end

--- Per event type: what we know statically, whether its client events registered, and how many were recorded.
function T.Capabilities()
	local out = {}
	for _, def in ipairs(T.EVENT_DEFS) do
		local srcRegistered, allKnown = true, true
		for _, ev in ipairs(WATCHED_EVENTS) do
			for _, src in ipairs(def.sources) do
				if src:find(ev, 1, true) then
					if registered[ev] == nil then allKnown = false end
					if registered[ev] == false then srcRegistered = false end
				end
			end
		end
		out[#out + 1] = { type = def.type, verified = def.verified, evidence = def.evidence, sources = def.sources,
			registered = (not def.unavailable) and (allKnown and srcRegistered or nil) or false, unavailable = def.unavailable or nil, recorded = seen[def.type] or 0 }
	end
	return out
end

function T.Status()
	local s = store()
	return { enabled = s ~= nil and s.enabled == true, stored = s and #s.events or 0, cap = s and s.cap or DEFAULT_CAP,
		anomalies = T.anomalies, started = started }
end

registerAll()
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function(_, event, ...) T.OnEvent(event, ...) end)
frame:SetScript("OnUpdate", function(_, elapsed) T.Tick(elapsed) end)

ns._selftest = ns._selftest or {}
ns._selftest.telemetry = { frame = frame, onEvent = T.OnEvent, tick = T.Tick, registered = registered }
