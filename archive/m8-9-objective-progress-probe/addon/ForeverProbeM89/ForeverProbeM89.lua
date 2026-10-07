-- ForeverProbeM89: disposable M8.9 research probe.
--
-- ONE question: does WoW Forever expose enough reliable client-side information to detect quest objective
-- progress and completion? It does not design or implement route progression.
--
-- Unlike M8.7/M8.8, there is no single event that says "objective N of quest Q went from 3/8 to 4/8". The
-- candidate events (QUEST_LOG_UPDATE, UNIT_QUEST_LOG_CHANGED, QUEST_WATCH_UPDATE) are generic, so the probe
-- keeps a snapshot of every quest's objectives and diffs it:
--   * at the moment each candidate event fires        -> "was state already updated when the event fired?"
--   * at fixed delays after each candidate event       -> "if not, how long until it is?"
--   * on a 1-second background poll, only when no delayed read is pending
--                                                      -> "did state change with NO candidate event at all?"
-- M8.8 showed quest-log state can lag the event that announces it, so all three are recorded separately and
-- nothing is inferred from one alone.
--
-- Same convention as ForeverProbeM87/M88 and the M3/M4 probes.
--
-- | Folder / files     | ForeverProbeM89 / ForeverProbeM89.lua, .toc |
-- | SavedVariables     | ForeverProbeM89DB                           |
-- | Slash command      | /fprobe89   (/fprobe89 snap = print current objectives) |
-- | Chat prefix        | [FProbeM89] (green)                         |
-- | Version            | m8-9-probe-0.1                              |
--
-- READ-ONLY: only quest-log READ functions are called. Never AcceptQuest, AbandonQuest, CompleteQuest,
-- GetQuestReward, or anything else that changes quest state. No hooks are installed.
--
-- Timers: delayed reads and the poll run from a frame's OnUpdate script (frames are confirmed on Forever);
-- C_Timer is NOT relied on. The number of OnUpdate ticks is recorded so a timer that never ran is visible.
--
-- Persistence: end the test with /reload (M8_0_SCOPE.md SS2). A final snapshot is taken on PLAYER_LOGOUT,
-- which /reload fires before SavedVariables are written.

local addonName, ns = ...
local VERSION = "m8-9-probe-0.1"
local PREFIX = "|cff66ff66[FProbeM89]|r "

local CANDIDATE_EVENTS = { "QUEST_LOG_UPDATE", "UNIT_QUEST_LOG_CHANGED", "QUEST_WATCH_UPDATE" }
local CONTEXT_EVENTS = { "QUEST_ACCEPTED", "QUEST_TURNED_IN", "QUEST_REMOVED", "UI_INFO_MESSAGE" }
local IS_CANDIDATE = {}
for _, e in ipairs(CANDIDATE_EVENTS) do IS_CANDIDATE[e] = true end

local DELAYS = { 0.1, 0.25, 0.5, 1.0, 2.0 }  -- seconds after a candidate event
local POLL_INTERVAL = 1.0
local SETTLE_SECONDS = 3.0                    -- after PLAYER_ENTERING_WORLD, before the baseline snapshot
local MAX_RECORDS = 600
local MAX_NOCHANGE_EVENTS = 200
local MAX_PENDING = 60
local MAX_INFO_MESSAGES = 60

ForeverProbeM89DB = ForeverProbeM89DB or {}
ForeverProbeM89DB.sessions = ForeverProbeM89DB.sessions or {}

local session
local current           -- last snapshot: [questID] = { title, log_index, complete, ready, source, objectives }
local ready = false     -- baseline taken?
local settleAt          -- GetTime() at which to take the baseline
local pending = {}      -- delayed reads: { due, offset, trigger_seq, trigger_event, trigger_t }
local lastPoll = 0
local lastCandidate     -- { seq, event, t }
local nochangeStored = 0
local infoStored = 0

-- ---------------------------------------------------------------- helpers

local function say(msg)
	if DEFAULT_CHAT_FRAME then
		DEFAULT_CHAT_FRAME:AddMessage(PREFIX .. msg)
	end
end

local function safe(fn, ...)
	if type(fn) ~= "function" then
		return false, "function not available"
	end
	local ok, a, b, c, d = pcall(fn, ...)
	if not ok then
		return false, a
	end
	return true, a, b, c, d
end

local function now()
	local ok, t = safe(GetTime)
	return ok and t or nil
end

local function captureArgs(...)
	local n = select("#", ...)
	local out = { n = n }
	for i = 1, n do
		local v = select(i, ...)
		local t = type(v)
		if t == "string" or t == "number" or t == "boolean" then
			out[i] = { type = t, value = v }
		else
			out[i] = { type = t }
		end
	end
	return out
end

local function record(fields)
	if not session then
		return nil
	end
	if #session.records >= MAX_RECORDS then
		session.cap_reached = true
		return nil
	end
	fields.seq = #session.records + 1
	fields.t = fields.t or now()
	table.insert(session.records, fields)
	return fields.seq
end

local function bump(name)
	session.counts[name] = (session.counts[name] or 0) + 1
end

local function cq(name)
	return type(C_QuestLog) == "table" and type(C_QuestLog[name]) == "function" and C_QuestLog[name] or nil
end

-- ---------------------------------------------------------------- reading the quest log (read-only)

local function numLogEntries()
	local f = cq("GetNumQuestLogEntries")
	if f then
		local ok, n = safe(f)
		if ok and type(n) == "number" then return n end
	end
	local ok, n = safe(GetNumQuestLogEntries)
	if ok and type(n) == "number" then return n end
	return 0
end

--- Lists the quests in the log (headers skipped). Modern C_QuestLog.GetInfo first, legacy GetQuestLogTitle
-- (which returns many values, so it is pcall'd directly rather than through safe()) as a fallback.
local function listQuests()
	local out = {}
	local getInfo = cq("GetInfo")
	for i = 1, numLogEntries() do
		local qid, title, isHeader
		if getInfo then
			local ok, info = pcall(getInfo, i)
			if ok and type(info) == "table" then
				qid, title, isHeader = info.questID, info.title, info.isHeader
			end
		elseif type(GetQuestLogTitle) == "function" then
			local r = { pcall(GetQuestLogTitle, i) }
			if r[1] then
				title, isHeader, qid = r[2], r[5], r[9]
			end
		end
		if not isHeader and type(qid) == "number" and qid > 0 then
			table.insert(out, { quest_id = qid, title = title, log_index = i })
		end
	end
	return out
end

local function parseCount(text)
	if type(text) ~= "string" then return nil, nil end
	local have, need = text:match("(%d+)%s*/%s*(%d+)")
	return tonumber(have), tonumber(need)
end

--- Text availability is recorded separately from progress availability: an objective whose text has no
-- name ("0/1  ") still has usable numbers.
local function textInfo(text)
	if type(text) ~= "string" or text:match("^%s*$") then
		return "missing"
	end
	if text:match("^%s*%d+%s*/%s*%d+%s*$") then
		return "count_only_no_name"
	end
	return "present"
end

local function readObjectives(qid, logIndex)
	local list = {}
	local getObj = cq("GetQuestObjectives")
	if getObj then
		local ok, objs = pcall(getObj, qid)
		if ok and type(objs) == "table" then
			for i, o in ipairs(objs) do
				if type(o) == "table" then
					list[i] = { text = o.text, type = o.type, finished = o.finished,
						have = o.numFulfilled, need = o.numRequired, text_info = textInfo(o.text) }
				end
			end
			return list, "C_QuestLog.GetQuestObjectives"
		end
	end
	if type(GetNumQuestLeaderBoards) == "function" and type(GetQuestLogLeaderBoard) == "function" then
		local okN, n = pcall(GetNumQuestLeaderBoards, logIndex)
		if okN and type(n) == "number" then
			for j = 1, n do
				local ok, text, otype, finished = pcall(GetQuestLogLeaderBoard, j, logIndex)
				if ok then
					local have, need = parseCount(text)
					list[j] = { text = text, type = otype, finished = finished, have = have, need = need,
						text_info = textInfo(text) }
				end
			end
			return list, "GetQuestLogLeaderBoard"
		end
	end
	return list, "unavailable"
end

local function readFlag(name, qid)
	local f = cq(name)
	if not f then return nil end
	local ok, v = safe(f, qid)
	if ok then return v end
	return nil
end

local function snapshot()
	local snap = {}
	for _, q in ipairs(listQuests()) do
		local objs, source = readObjectives(q.quest_id, q.log_index)
		snap[q.quest_id] = {
			title = q.title, log_index = q.log_index, source = source, objectives = objs,
			complete = readFlag("IsComplete", q.quest_id), ready = readFlag("ReadyForTurnIn", q.quest_id),
		}
	end
	return snap
end

-- ---------------------------------------------------------------- diffing

local function objState(o)
	return o and { have = o.have, need = o.need, finished = o.finished, text = o.text } or nil
end

local function objDiffers(a, b)
	if not a or not b then return a ~= b end
	return a.have ~= b.have or a.need ~= b.need or a.finished ~= b.finished or a.text ~= b.text
end

local function diffQuest(qid, a, b, out)
	if a.complete ~= b.complete then
		table.insert(out, { kind = "complete_changed", quest_id = qid, title = b.title, from = a.complete, to = b.complete })
	end
	if a.ready ~= b.ready then
		table.insert(out, { kind = "ready_changed", quest_id = qid, title = b.title, from = a.ready, to = b.ready })
	end
	if #a.objectives ~= #b.objectives then
		table.insert(out, { kind = "objective_count_changed", quest_id = qid, title = b.title,
			from = #a.objectives, to = #b.objectives })
	end
	local n = math.max(#a.objectives, #b.objectives)
	for i = 1, n do
		if objDiffers(a.objectives[i], b.objectives[i]) then
			table.insert(out, { kind = "objective_changed", quest_id = qid, title = b.title, index = i,
				from = objState(a.objectives[i]), to = objState(b.objectives[i]) })
		end
	end
end

local function diff(a, b)
	local out = {}
	for qid, bq in pairs(b) do
		if not a[qid] then
			table.insert(out, { kind = "quest_added", quest_id = qid, title = bq.title })
		else
			diffQuest(qid, a[qid], bq, out)
		end
	end
	for qid, aq in pairs(a) do
		if not b[qid] then
			table.insert(out, { kind = "quest_removed", quest_id = qid, title = aq.title })
		end
	end
	return out
end

-- ---------------------------------------------------------------- reporting a change

local function fmtObj(o)
	if not o then return "none" end
	local s = (o.have and o.need) and (tostring(o.have) .. "/" .. tostring(o.need)) or "?"
	if o.finished then s = s .. " done" end
	return s
end

local function describeSeen(how, trigger, delay)
	if how == "event" then
		return string.format("seen AT %s", tostring(trigger))
	elseif how == "delayed" then
		return string.format("first seen %.2fs after %s", delay or -1, tostring(trigger))
	end
	return delay and string.format("seen by poll, last quest event %.1fs earlier", delay)
		or "seen by poll, no quest event yet this session"
end

--- Records a batch of changes with how they were detected, snapshots of the affected quests (for objective
-- ordering analysis), and a chat line per meaningful change.
local function reportChanges(changes, how, trigger, triggerSeq, delay)
	local quests = {}
	local meaningful = 0
	for _, c in ipairs(changes) do
		quests[c.quest_id] = current[c.quest_id]
		if c.kind == "objective_changed" then
			meaningful = meaningful + 1
			bump("objective_change:" .. how)
			say(string.format("objective: %s (%d) #%d %s -> %s | %s", tostring(c.title), c.quest_id, c.index,
				fmtObj(c.from), fmtObj(c.to), describeSeen(how, trigger, delay)))
		elseif c.kind == "complete_changed" or c.kind == "ready_changed" then
			meaningful = meaningful + 1
			bump(c.kind .. ":" .. how)
			say(string.format("%s: %s (%d) %s -> %s | %s", c.kind == "complete_changed" and "IsComplete" or "ReadyForTurnIn",
				tostring(c.title), c.quest_id, tostring(c.from), tostring(c.to), describeSeen(how, trigger, delay)))
		else
			bump(c.kind)
		end
	end
	record({ kind = "change", detected_by = how, trigger_event = trigger, trigger_seq = triggerSeq,
		seconds_after_trigger = delay, changes = changes, quest_snapshots = quests, meaningful = meaningful })
end

--- Takes a snapshot, diffs it against the last one, and reports anything that changed.
local function check(how, trigger, triggerSeq, delay)
	if not ready then return 0 end
	local snap = snapshot()
	local changes = diff(current, snap)
	current = snap
	if #changes > 0 then
		reportChanges(changes, how, trigger, triggerSeq, delay)
	end
	return #changes
end

-- ---------------------------------------------------------------- events

local function resolveWatchArg(v)
	if type(v) ~= "number" then return nil end
	local r = { value = v }
	local f = cq("GetTitleForQuestID")
	if f then
		local ok, t = safe(f, v)
		if ok then r.title_if_quest_id = t end
	end
	if type(GetQuestLogTitle) == "function" then
		local ok, t = safe(GetQuestLogTitle, v)
		if ok and type(t) == "string" then r.title_if_log_index = t end
	end
	return r
end

local function onCandidate(event, ...)
	bump(event)
	local t = now()
	local args = captureArgs(...)
	local fields = { kind = "event", event = event, args = args, t = t, pre_baseline = not ready or nil }
	if event == "QUEST_WATCH_UPDATE" and args[1] then
		fields.arg1_resolved = resolveWatchArg(args[1].value)
	end
	local n = check("event", event, nil, 0)
	fields.immediate_change_count = n
	local seq
	if n > 0 or nochangeStored < MAX_NOCHANGE_EVENTS then
		if n == 0 then nochangeStored = nochangeStored + 1 end
		seq = record(fields)
	else
		bump("nochange_event_not_stored")
	end
	lastCandidate = { seq = seq, event = event, t = t }
	if ready and #pending < MAX_PENDING then
		for _, d in ipairs(DELAYS) do
			table.insert(pending, { due = t + d, offset = d, trigger_seq = seq, trigger_event = event })
		end
	end
end

local function onContext(event, ...)
	bump(event)
	local args = captureArgs(...)
	if event == "UI_INFO_MESSAGE" then
		if infoStored >= MAX_INFO_MESSAGES then return end
		infoStored = infoStored + 1
	end
	record({ kind = "context", event = event, args = args })
end

local function onUpdate(_, elapsed)
	if not session then return end
	session.onupdate_ticks = (session.onupdate_ticks or 0) + 1
	local t = now()
	if not t then return end
	if not ready then
		if settleAt and t >= settleAt then
			current = snapshot()
			ready = true
			session.baseline = current
			session.baseline_t = t
			local n = 0
			for _ in pairs(current) do n = n + 1 end
			say(string.format("baseline taken: %d quest(s) in log. Ready. /fprobe89 snap shows objectives.", n))
		end
		return
	end
	local i = 1
	while i <= #pending do
		local p = pending[i]
		if t >= p.due - 0.001 then  -- tolerance for floating-point frame times
			table.remove(pending, i)
			check("delayed", p.trigger_event, p.trigger_seq, p.offset)
		else
			i = i + 1
		end
	end
	-- The poll only looks for changes NO candidate event announced, so it stands aside while any delayed read
	-- is still pending (i.e. within 2 s of a candidate event); otherwise it could claim a change that the
	-- delayed read was about to attribute to its event.
	if #pending == 0 and t - lastPoll >= POLL_INTERVAL then
		lastPoll = t
		check("poll", nil, nil, lastCandidate and (t - lastCandidate.t) or nil)
	end
end

-- ---------------------------------------------------------------- bootstrap

local frame = CreateFrame("Frame")

local function detectApis()
	local list = { "GetNumQuestLogEntries", "GetInfo", "GetQuestObjectives", "IsComplete", "ReadyForTurnIn",
		"GetTitleForQuestID" }
	local out = {}
	for _, name in ipairs(list) do
		out["C_QuestLog." .. name] = cq(name) and "function" or "absent"
	end
	for _, name in ipairs({ "GetQuestLogTitle", "GetNumQuestLeaderBoards", "GetQuestLogLeaderBoard", "GetNumQuestLogEntries" }) do
		out[name] = type(_G[name]) == "function" and "function" or "absent"
	end
	out["C_Timer.After"] = (type(C_Timer) == "table" and type(C_Timer.After) == "function") and "function (not used)" or "absent"
	return out
end

local function startSession()
	local okB, gameVersion, build, buildDate, tocVersion = safe(GetBuildInfo)
	session = {
		probe_version = VERSION, started_t = now(),
		game_version = okB and gameVersion or nil, build = okB and build or nil,
		build_date = okB and buildDate or nil, toc_version = okB and tocVersion or nil,
		counts = {}, records = {}, apis = detectApis(), registration = {},
	}
	table.insert(ForeverProbeM89DB.sessions, session)
	for _, ev in ipairs(CANDIDATE_EVENTS) do
		local ok, err = safe(frame.RegisterEvent, frame, ev)
		session.registration[ev] = ok and "registered" or ("registration_error: " .. tostring(err))
	end
	for _, ev in ipairs(CONTEXT_EVENTS) do
		local ok, err = safe(frame.RegisterEvent, frame, ev)
		session.registration[ev] = ok and "registered" or ("registration_error: " .. tostring(err))
	end
	safe(frame.RegisterEvent, frame, "PLAYER_ENTERING_WORLD")
	safe(frame.RegisterEvent, frame, "PLAYER_LOGOUT")
	local okU, errU = safe(frame.SetScript, frame, "OnUpdate", onUpdate)
	session.onupdate_install = okU and "installed" or ("failed: " .. tostring(errU))
	local r = session.registration
	say(string.format("%s loaded (session %d). QUEST_LOG_UPDATE: %s | UNIT_QUEST_LOG_CHANGED: %s | QUEST_WATCH_UPDATE: %s. Waiting for baseline...",
		VERSION, #ForeverProbeM89DB.sessions, r.QUEST_LOG_UPDATE, r.UNIT_QUEST_LOG_CHANGED, r.QUEST_WATCH_UPDATE))
end

frame:SetScript("OnEvent", function(self, event, ...)
	if event == "ADDON_LOADED" then
		if ... == addonName then
			self:UnregisterEvent("ADDON_LOADED")
			startSession()
		end
		return
	end
	if not session then return end
	if event == "PLAYER_ENTERING_WORLD" then
		if not ready then settleAt = (now() or 0) + SETTLE_SECONDS end
	elseif event == "PLAYER_LOGOUT" then
		if ready then
			session.final_snapshot = snapshot()
			session.final_t = now()
		end
	elseif IS_CANDIDATE[event] then
		onCandidate(event, ...)
	else
		onContext(event, ...)
	end
end)
frame:RegisterEvent("ADDON_LOADED")

-- ---------------------------------------------------------------- slash command

local function printSnap()
	if not ready then
		say("baseline not taken yet.")
		return
	end
	local snap = snapshot()
	local lines = 0
	for qid, q in pairs(snap) do
		local parts = {}
		for i, o in ipairs(q.objectives) do
			table.insert(parts, string.format("#%d %s \"%s\"", i, fmtObj(o), tostring(o.text)))
		end
		if #parts > 0 and lines < 20 then
			lines = lines + 1
			say(string.format("%s (%d): %s | complete=%s", tostring(q.title), qid, table.concat(parts, "; "), tostring(q.complete)))
		end
	end
	if lines == 0 then say("no quests with objectives in the log.") end
	record({ kind = "manual_snapshot", snapshot = snap })
end

SLASH_FOREVERPROBEM891 = "/fprobe89"
SlashCmdList["FOREVERPROBEM89"] = function(msg)
	if not session then
		say("no session started.")
		return
	end
	if (msg or ""):lower():match("snap") then
		printSnap()
		return
	end
	local c = session.counts
	say(string.format("events: QUEST_LOG_UPDATE=%d | UNIT_QUEST_LOG_CHANGED=%d | QUEST_WATCH_UPDATE=%d (%s)",
		c.QUEST_LOG_UPDATE or 0, c.UNIT_QUEST_LOG_CHANGED or 0, c.QUEST_WATCH_UPDATE or 0,
		tostring(session.registration.QUEST_WATCH_UPDATE)))
	say(string.format("objective changes: seen at event=%d | only after a delay=%d | only by poll=%d",
		c["objective_change:event"] or 0, c["objective_change:delayed"] or 0, c["objective_change:poll"] or 0))
	say(string.format("completion flags: at event=%d | after delay=%d | by poll=%d | timer ticks=%d",
		(c["complete_changed:event"] or 0) + (c["ready_changed:event"] or 0),
		(c["complete_changed:delayed"] or 0) + (c["ready_changed:delayed"] or 0),
		(c["complete_changed:poll"] or 0) + (c["ready_changed:poll"] or 0), session.onupdate_ticks or 0))
	say(string.format("records stored: %d%s. Now /reload to save the result.", #session.records,
		session.cap_reached and " (cap reached)" or ""))
end

-- Test-only seam on the addon's private namespace (no new global). No in-game code path reads it.
ns._selftest = {
	getSession = function() return session end,
	onUpdate = function(elapsed) onUpdate(frame, elapsed) end,
	slash = function(msg) SlashCmdList["FOREVERPROBEM89"](msg) end,
	isReady = function() return ready end,
}
