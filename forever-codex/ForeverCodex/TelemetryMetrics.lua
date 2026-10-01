-- ForeverCodex.TelemetryMetrics: PURE calculators over the Telemetry event log. No client calls, no state.
--
-- Every number is labelled with HOW we know it:
--   observed    summed/counted straight from recorded events (e.g. total XP gained, kills, seconds in combat)
--   calculated  arithmetic on observed values (e.g. XP per minute, downtime share)
--   estimated   depends on an inference that is NOT proven (e.g. XP per kill, pairing a kill with an XP gain by timing)
-- A metric without enough evidence is returned as { value = nil, reason = "..." }, never as a guess.
--
-- Nothing in Codex consumes these yet. They exist so a future Fast strategy can ask "what is this character
-- actually earning per minute?" from evidence instead of assumptions, e.g.:
--     local s = ForeverCodex ... ns.TelemetryMetrics.Summary(ns.Telemetry.Events())
--     s.xp.perMinute.value, s.kills.avgXpPerKill.value, s.timing.downtimeShare.value ...
-- and compare them with a quest's expected XP and time.
--
-- Windows: events are timestamped with GetTime(), which restarts every session, so a summary only ever spans ONE
-- session (the events after the last SESSION marker). The default window is the last 600 seconds of that session.
-- PLAYER_MOVE and COMBAT_END events are stamped when they END, so a segment straddling the window start is counted
-- only if it ended inside the window (a small, stated approximation).

local addonName, ns = ...

local M = {}
ns.TelemetryMetrics = M

M.DEFAULT_SPAN = 600          -- seconds
M.MIN_SECONDS = 60            -- shortest window a per-minute rate is reported over
M.KILL_XP_LINK = 1.5          -- seconds: an XP gain this soon after a kill is paired with it

local function metric(kind, value, unit, n, basis)
	return { kind = kind, value = value, unit = unit, n = n, basis = basis }
end

local function insufficient(kind, unit, reason, n)
	return { kind = kind, value = nil, unit = unit, n = n or 0, reason = reason }
end

--- Events of the most recent session (from the last SESSION marker on). Returns a new list, oldest first.
function M.LastSession(events)
	local start = 1
	for i = #events, 1, -1 do
		if events[i].e == "SESSION" then start = i break end
	end
	local out = {}
	for i = start, #events do out[#out + 1] = events[i] end
	return out
end

local function sum(list, field)
	local total = 0
	for _, ev in ipairs(list) do total = total + (ev[field] or 0) end
	return total
end

local function ofType(list, e)
	local out = {}
	for _, ev in ipairs(list) do
		if ev.e == e then out[#out + 1] = ev end
	end
	return out
end

--- Summarises the last session's recent window. `opts`: span (seconds), minSeconds, now (override window end).
function M.Summary(events, opts)
	opts = opts or {}
	local span = opts.span or M.DEFAULT_SPAN
	local minSeconds = opts.minSeconds or M.MIN_SECONDS
	local session = M.LastSession(events or {})
	local s = { window = { seconds = 0, events = 0, span = span } }
	if #session == 0 then
		s.reason = "no telemetry recorded yet"
	end

	local tEnd = opts.now or (session[#session] and session[#session].t) or 0
	local tStart = math.max(tEnd - span, session[1] and session[1].t or 0)
	local win = {}
	for _, ev in ipairs(session) do
		if ev.e ~= "SESSION" and ev.t >= tStart and ev.t <= tEnd then win[#win + 1] = ev end
	end
	local seconds = tEnd - tStart
	s.window = { seconds = seconds, events = #win, span = span, from = tStart, to = tEnd }

	-- ---- XP
	local gains = ofType(win, "XP_GAIN")
	local totalXp = sum(gains, "d")
	local combat = ofType(win, "COMBAT_END")
	local moves = ofType(win, "PLAYER_MOVE")
	local combatSeconds, moveSeconds, moveDistance = sum(combat, "dur"), sum(moves, "dur"), sum(moves, "dist")
	local activeSeconds = math.min(seconds, combatSeconds + moveSeconds)

	s.xp = { total = metric("observed", totalXp, "xp", #gains, "sum of XP_GAIN deltas in the window") }
	if seconds >= minSeconds and #gains > 0 then
		s.xp.perMinute = metric("calculated", totalXp / (seconds / 60), "xp/min", #gains,
			string.format("%d xp over %.0f s of wall time (includes downtime)", totalXp, seconds))
		s.xp.perHour = metric("calculated", totalXp / (seconds / 3600), "xp/hour", #gains, "perMinute x 60")
	else
		local why = seconds < minSeconds and ("window shorter than " .. minSeconds .. " s") or "no XP gains recorded"
		s.xp.perMinute = insufficient("calculated", "xp/min", why, #gains)
		s.xp.perHour = insufficient("calculated", "xp/hour", why, #gains)
	end
	if activeSeconds >= 30 and #gains > 0 then
		s.xp.perActiveMinute = metric("calculated", totalXp / (activeSeconds / 60), "xp/min", #gains,
			string.format("%d xp over %.0f s of observed combat+movement", totalXp, activeSeconds))
	else
		s.xp.perActiveMinute = insufficient("calculated", "xp/min", activeSeconds < 30 and "under 30 s of observed combat+movement" or "no XP gains recorded", #gains)
	end

	-- ---- kills, and the (estimated) XP they gave
	local kills = ofType(win, "MOB_KILL")
	s.kills = { count = metric("observed", #kills, "kills", #kills, "MOB_KILL events") }
	local paired, pairedXp, lastKill = 0, 0, nil
	for _, ev in ipairs(win) do
		if ev.e == "MOB_KILL" then
			lastKill = ev
		elseif ev.e == "XP_GAIN" and lastKill and not ev.lvlup and ev.t - lastKill.t <= M.KILL_XP_LINK and ev.t >= lastKill.t then
			paired, pairedXp, lastKill = paired + 1, pairedXp + (ev.d or 0), nil
		end
	end
	if paired > 0 then
		s.kills.avgXpPerKill = metric("estimated", pairedXp / paired, "xp/kill", paired,
			"XP gain within " .. M.KILL_XP_LINK .. " s after a kill (timing only; not proven to be that kill's XP)")
	else
		s.kills.avgXpPerKill = insufficient("estimated", "xp/kill", #kills == 0 and "no kills recorded" or "no XP gain followed a kill closely enough", 0)
	end
	if #kills > 0 and seconds >= minSeconds then
		s.kills.perMinute = metric("calculated", #kills / (seconds / 60), "kills/min", #kills, "kills over the window")
	else
		s.kills.perMinute = insufficient("calculated", "kills/min", #kills == 0 and "no kills recorded" or ("window shorter than " .. minSeconds .. " s"), #kills)
	end
	s.kills.avgCombatSeconds = (#combat > 0) and metric("calculated", combatSeconds / #combat, "s/fight", #combat, "mean COMBAT_END duration (a fight may contain several kills)")
		or insufficient("calculated", "s/fight", "no completed fights recorded", 0)

	-- ---- where the time went
	s.timing = {
		combatSeconds = metric("observed", combatSeconds, "s", #combat, "sum of COMBAT_END durations"),
		moveSeconds = metric("observed", moveSeconds, "s", #moves, "sum of PLAYER_MOVE durations"),
		moveDistance = metric("observed", moveDistance, "yd", #moves, "sum of PLAYER_MOVE distances"),
	}
	if seconds >= minSeconds then
		local downtime = math.max(0, seconds - activeSeconds)
		s.timing.downtimeSeconds = metric("calculated", downtime, "s", #win, "window minus combat and movement; includes everything else (reading, looting, AFK, ...)")
		s.timing.downtimeShare = metric("calculated", downtime / seconds, "fraction", #win, "downtime / window")
		s.timing.combatShare = metric("calculated", math.min(1, combatSeconds / seconds), "fraction", #combat, "combat / window")
		s.timing.moveShare = metric("calculated", math.min(1, moveSeconds / seconds), "fraction", #moves, "movement / window")
	else
		local why = "window shorter than " .. minSeconds .. " s"
		s.timing.downtimeSeconds = insufficient("calculated", "s", why, #win)
		s.timing.downtimeShare = insufficient("calculated", "fraction", why, #win)
		s.timing.combatShare = insufficient("calculated", "fraction", why, #combat)
		s.timing.moveShare = insufficient("calculated", "fraction", why, #moves)
	end

	-- ---- quests
	local accepted, completed, turnins = ofType(win, "QUEST_ACCEPT"), ofType(win, "QUEST_COMPLETE"), ofType(win, "QUEST_TURNIN")
	s.quests = {
		accepted = metric("observed", #accepted, "quests", #accepted, "QUEST_ACCEPT events"),
		completed = metric("observed", #completed, "quests", #completed, "QUEST_COMPLETE events (objectives done)"),
		turnedIn = metric("observed", #turnins, "quests", #turnins, "QUEST_TURNIN events"),
		xp = metric("observed", sum(turnins, "xp"), "xp", #turnins, "sum of XP reported by QUEST_TURNED_IN"),
	}
	local durs, n = 0, 0
	for _, ev in ipairs(completed) do
		if ev.dur then durs, n = durs + ev.dur, n + 1 end
	end
	s.quests.avgSecondsToComplete = (n > 0) and metric("calculated", durs / n, "s", n, "accept -> objectives complete, wall clock (includes travel and other activity)")
		or insufficient("calculated", "s", "no completed quest with a known accept time", 0)
	local xpWithDur, secsWithDur, nWithDur = 0, 0, 0
	for _, ev in ipairs(turnins) do
		if ev.dur and ev.dur > 0 and ev.xp then xpWithDur, secsWithDur, nWithDur = xpWithDur + ev.xp, secsWithDur + ev.dur, nWithDur + 1 end
	end
	s.quests.xpPerQuestMinute = (nWithDur > 0) and metric("calculated", xpWithDur / (secsWithDur / 60), "xp/min", nWithDur,
		"turn-in XP / (accept -> turn-in wall time); an UPPER bound on effort, since other work happens in between")
		or insufficient("calculated", "xp/min", "no turn-in with a known accept time", 0)

	s.levelUps = metric("observed", #ofType(win, "LEVEL_UP"), "levels", #ofType(win, "LEVEL_UP"), "LEVEL_UP events")
	return s
end

local function fmt(m)
	if m.value == nil then return "n/a (" .. tostring(m.reason) .. ")" end
	local v = m.value
	local text = (v == math.floor(v)) and string.format("%d", v) or string.format("%.2f", v)
	return string.format("%s %s [%s, n=%d]", text, m.unit, m.kind, m.n or 0)
end

--- Plain-text lines for /codex telemetry summary.
function M.Format(s)
	local L = {}
	L[#L + 1] = string.format("window: %.0f s of the latest session, %d events", s.window.seconds, s.window.events)
	L[#L + 1] = "XP gained: " .. fmt(s.xp.total) .. " | per minute: " .. fmt(s.xp.perMinute)
	L[#L + 1] = "XP per active minute: " .. fmt(s.xp.perActiveMinute)
	L[#L + 1] = "kills: " .. fmt(s.kills.count) .. " | XP per kill: " .. fmt(s.kills.avgXpPerKill)
	L[#L + 1] = "combat: " .. fmt(s.timing.combatSeconds) .. " | moving: " .. fmt(s.timing.moveSeconds) .. " over " .. fmt(s.timing.moveDistance)
	L[#L + 1] = "downtime share: " .. fmt(s.timing.downtimeShare)
	L[#L + 1] = "quests: " .. fmt(s.quests.accepted) .. " accepted, " .. fmt(s.quests.completed) .. " complete, " .. fmt(s.quests.turnedIn) .. " turned in; quest XP " .. fmt(s.quests.xp)
	L[#L + 1] = "avg time to complete: " .. fmt(s.quests.avgSecondsToComplete) .. " | quest XP per minute: " .. fmt(s.quests.xpPerQuestMinute)
	return L
end
