-- ForeverProbeM812: disposable M8.12 research probe.
--
-- ONE question: when the addon loads, can quest progression state be reconstructed from the quest API, and at
-- which moment is that state safe to read? It records the same snapshot at a series of startup checkpoints:
--
--   file_load            this file's top-level code runs (earliest practical point)
--   ADDON_LOADED         for this addon
--   PLAYER_LOGIN
--   PLAYER_ENTERING_WORLD (with its isInitialLogin / isReloadingUi arguments)
--   first QUEST_LOG_UPDATE after load
--   first QUEST_LOG_UPDATE + 0.5 s
--   first QUEST_LOG_UPDATE + 2.0 s
--   PLAYER_ENTERING_WORLD + 3.0 s   (the point M8.9's baseline already proved readable)
--
-- Each snapshot: which APIs exist; the quest log (quest IDs, titles, objectives, IsComplete, ReadyForTurnIn,
-- IsOnQuest); the completed flag for every in-log quest and for a REFERENCE SET of quest IDs with known
-- expectations; and a digest so stability between checkpoints can be compared.
--
-- Each quest is classified WITHOUT inferring turn-in from absence:
--   IN_LOG_INCOMPLETE | IN_LOG_COMPLETE | FLAGGED_COMPLETED | ABSENT_NOT_FLAGGED | UNDETERMINED
-- "ABSENT_NOT_FLAGGED" means only that: absent and not flagged. It is never read as "turned in".
--
-- | Folder / files     | ForeverProbeM812 / ForeverProbeM812.lua, .toc |
-- | SavedVariables     | ForeverProbeM812DB                            |
-- | Slash command      | /fprobe812   (| q <questID> | now)            |
-- | Chat prefix        | [FProbeM812] (cyan-blue)                      |
-- | Version            | m8-12-probe-0.1                               |
--
-- READ-ONLY: calls only quest-log / completion READ functions. No hooks, no waypoints, no quest actions.
-- Persistence: logout saves are unreliable on this client (M8_0_SCOPE.md SS2); the guide ends each session with
-- /reload, which is also what saves the previous session's startup observations.

local addonName, ns = ...
local VERSION = "m8-12-probe-0.2"
local PREFIX = "|cff55aaff[FProbeM812]|r "

-- Reference quest IDs with an expectation derived from earlier project evidence on this character.
-- Expectations are hypotheses for the report to check, not facts the probe assumes.
local REFERENCE = {
	{ id = 92421, expect = "completed", note = "Light's Justice, turned in (M8.7/M8.9 evidence)" },
	{ id = 92422, expect = "completed", note = "The Wrath of Rath'mael, turned in (M8.9)" },
	{ id = 92401, expect = "completed", note = "A Frightened Request, turned in (M8.9)" },
	{ id = 95216, expect = "completed", note = "The New Plague, turned in (M8.8)" },
	{ id = 97288, expect = "completed", note = "Unending Torment, turned in (M8.8)" },
	{ id = 97291, expect = "completed", note = "Unending Torment follow-up, turned in (M8.8 post-lock)" },
	{ id = 95204, expect = "completed", note = "Crest of Lordaeron, turned in (M8.8, inconclusive run)" },
	{ id = 428, expect = "completed", note = "Lost Deathstalkers, turned in (M8.9)" },
	{ id = 783, expect = "not_completed", note = "Alliance starter quest; a Horde character cannot have done it" },
	{ id = 7, expect = "not_completed", note = "Alliance starter quest; a Horde character cannot have done it" },
	{ id = 907, expect = "unknown", note = "Enraged Thunder Lizards, route test quest; status unknown" },
}

local MAX_QLU_LOG = 40

-- v0.2: SavedVariables timing. v0.1 inserted its session into ForeverProbeM812DB at file load. On the real
-- client that table was then REPLACED by the copy restored from disk (SavedVariables are restored after an
-- addon's files run, before ADDON_LOADED), so every session after the first was discarded and the old file
-- re-saved. v0.2 builds the session at file load (so the file_load checkpoint still happens) but attaches it to
-- whatever table exists at ADDON_LOADED, and records what it saw so the timing itself is evidence.
local svAtFileLoad = ForeverProbeM812DB
local fileLoadTable = {}

local session
local frame
local firstQLU, pewAt
local pending = {}   -- { due, name }

-- ---------------------------------------------------------------- helpers

local function say(msg)
	if DEFAULT_CHAT_FRAME then
		DEFAULT_CHAT_FRAME:AddMessage(PREFIX .. msg)
	end
end

local function now()
	if type(GetTime) ~= "function" then return nil end
	local ok, t = pcall(GetTime)
	return ok and t or nil
end

local function fn(nsName, name)
	if nsName then
		local t = _G[nsName]
		return type(t) == "table" and type(t[name]) == "function" and t[name] or nil
	end
	return type(_G[name]) == "function" and _G[name] or nil
end

--- Returns status ("absent" | "error" | "nil" | "ok") and the first return value.
local function call(nsName, name, ...)
	local f = fn(nsName, name)
	if not f then return "absent" end
	local ok, v = pcall(f, ...)
	if not ok then return "error", tostring(v) end
	if v == nil then return "nil" end
	return "ok", v
end

local API_LIST = {
	{ "C_QuestLog", "IsQuestFlaggedCompleted" }, { nil, "IsQuestFlaggedCompleted" },
	{ "C_QuestLog", "GetAllCompletedQuestIDs" }, { nil, "GetQuestsCompleted" },
	{ "C_QuestLog", "GetNumQuestLogEntries" }, { "C_QuestLog", "GetInfo" }, { "C_QuestLog", "GetQuestObjectives" },
	{ "C_QuestLog", "IsComplete" }, { "C_QuestLog", "ReadyForTurnIn" }, { "C_QuestLog", "IsOnQuest" },
	{ "C_QuestLog", "GetLogIndexForQuestID" }, { "C_QuestLog", "GetTitleForQuestID" },
}

local function apiInventory()
	local out = {}
	for _, a in ipairs(API_LIST) do
		out[(a[1] and (a[1] .. ".") or "") .. a[2]] = fn(a[1], a[2]) and "function" or "absent"
	end
	return out
end

--- Completed flag via the modern API, falling back to the legacy global. Returns status, value, source.
local function flagged(qid)
	local st, v = call("C_QuestLog", "IsQuestFlaggedCompleted", qid)
	if st ~= "absent" then return st, v, "C_QuestLog.IsQuestFlaggedCompleted" end
	st, v = call(nil, "IsQuestFlaggedCompleted", qid)
	return st, v, "IsQuestFlaggedCompleted"
end

local function classify(inLog, complete, ready, flagStatus, flagValue)
	if inLog then
		if complete == true or ready == true then return "IN_LOG_COMPLETE" end
		return "IN_LOG_INCOMPLETE"
	end
	if flagStatus == "ok" and flagValue == true then return "FLAGGED_COMPLETED" end
	if flagStatus == "ok" and flagValue == false then return "ABSENT_NOT_FLAGGED" end
	return "UNDETERMINED"
end

-- ---------------------------------------------------------------- snapshot

local function readLog()
	local quests, order = {}, {}
	local stN, n = call("C_QuestLog", "GetNumQuestLogEntries")
	local count = (stN == "ok" and type(n) == "number") and n or 0
	for i = 1, count do
		local st, info = call("C_QuestLog", "GetInfo", i)
		if st == "ok" and type(info) == "table" and not info.isHeader and type(info.questID) == "number" and info.questID > 0 then
			local qid = info.questID
			local objs = {}
			local stO, list = call("C_QuestLog", "GetQuestObjectives", qid)
			if stO == "ok" and type(list) == "table" then
				for j, o in ipairs(list) do
					if type(o) == "table" then
						objs[j] = { text = o.text, type = o.type, finished = o.finished, have = o.numFulfilled, need = o.numRequired }
					end
				end
			end
			local _, complete = call("C_QuestLog", "IsComplete", qid)
			local _, ready = call("C_QuestLog", "ReadyForTurnIn", qid)
			local stF, flagV = flagged(qid)
			quests[qid] = { title = info.title, log_index = i, objectives_status = stO, objectives = objs,
				complete = complete, ready = ready, flagged_status = stF, flagged = flagV,
				state = classify(true, complete, ready, stF, flagV) }
			table.insert(order, qid)
		end
	end
	table.sort(order)
	return { entries_status = stN, entries = count, quests = quests, order = order }
end

local function readReference(log)
	local out = {}
	for _, r in ipairs(REFERENCE) do
		local inLog = log.quests[r.id] ~= nil
		local stOn, onQuest = call("C_QuestLog", "IsOnQuest", r.id)
		local stF, flagV, src = flagged(r.id)
		local q = log.quests[r.id]
		out[r.id] = { expect = r.expect, in_log = inLog, is_on_quest_status = stOn, is_on_quest = onQuest,
			flagged_status = stF, flagged = flagV, flagged_source = src,
			state = classify(inLog, q and q.complete, q and q.ready, stF, flagV) }
	end
	return out
end

local function completedList()
	local st, list = call("C_QuestLog", "GetAllCompletedQuestIDs")
	if st == "ok" and type(list) == "table" then
		local set, n = {}, 0
		for _, id in ipairs(list) do set[id] = true; n = n + 1 end
		local hits = {}
		for _, r in ipairs(REFERENCE) do hits[r.id] = set[r.id] == true end
		return { status = st, count = n, reference_hits = hits }
	end
	return { status = st }
end

local function digest(log, ref)
	local parts = { "n=" .. tostring(log.entries) }
	for _, qid in ipairs(log.order) do
		local q = log.quests[qid]
		local o = {}
		for _, ob in ipairs(q.objectives) do
			table.insert(o, tostring(ob.have) .. "/" .. tostring(ob.need) .. (ob.finished and "F" or ""))
		end
		table.insert(parts, qid .. ":" .. q.state .. ":" .. table.concat(o, ","))
	end
	for _, r in ipairs(REFERENCE) do
		table.insert(parts, "r" .. r.id .. ":" .. ref[r.id].state)
	end
	return table.concat(parts, "|")
end

local function snapshot(name, extra)
	if not session then return nil end
	local log = readLog()
	local ref = readReference(log)
	local snap = {
		name = name, t = now(), apis = apiInventory(), log = log, reference = ref,
		completed_list = completedList(), extra = extra,
	}
	snap.digest = digest(log, ref)
	table.insert(session.checkpoints, snap)
	return snap
end

-- ---------------------------------------------------------------- reporting

local function flagSummary(ref)
	local okC, okN, bad, undet = 0, 0, 0, 0
	for _, r in ipairs(REFERENCE) do
		local x = ref[r.id]
		if x.flagged_status ~= "ok" then
			undet = undet + 1
		elseif r.expect == "completed" then
			if x.flagged == true then okC = okC + 1 else bad = bad + 1 end
		elseif r.expect == "not_completed" then
			if x.flagged == false then okN = okN + 1 else bad = bad + 1 end
		end
	end
	return okC, okN, bad, undet
end

local function checkpointLine(s)
	local okC, okN, bad, undet = flagSummary(s.reference)
	return string.format("%s: log entries %d, quests %d | ref completed-as-expected %d/8, not-completed-as-expected %d/2, unexpected %d, undetermined %d",
		s.name, s.log.entries, #s.log.order, okC, okN, bad, undet)
end

local function finalize()
	if not session or session.finalized then return end
	session.finalized = true
	local final = session.checkpoints[#session.checkpoints]
	for _, s in ipairs(session.checkpoints) do
		s.same_as_last = (s.digest == final.digest)
	end
	say("startup capture complete. Type /fprobe812 for the summary.")
end

-- ---------------------------------------------------------------- inspection commands

local function inspect(qid)
	local log = readLog()
	local q = log.quests[qid]
	local stF, flagV, src = flagged(qid)
	local stOn, onQuest = call("C_QuestLog", "IsOnQuest", qid)
	local stT, title = call("C_QuestLog", "GetTitleForQuestID", qid)
	say(string.format("quest %d \"%s\" | in log: %s | IsOnQuest %s=%s | %s %s=%s | state %s", qid, tostring(title),
		tostring(q ~= nil), stOn, tostring(onQuest), src, stF, tostring(flagV),
		classify(q ~= nil, q and q.complete, q and q.ready, stF, flagV)))
	if q then
		local parts = {}
		for j, o in ipairs(q.objectives) do
			table.insert(parts, string.format("#%d %s/%s%s", j, tostring(o.have), tostring(o.need), o.finished and " done" or ""))
		end
		say(string.format("  objectives (%s): %s | IsComplete=%s ReadyForTurnIn=%s", q.objectives_status,
			#parts > 0 and table.concat(parts, "; ") or "none", tostring(q.complete), tostring(q.ready)))
	end
	table.insert(session.inspections, { t = now(), quest_id = qid, title_status = stT, title = title,
		in_log = q ~= nil, entry = q, is_on_quest_status = stOn, is_on_quest = onQuest,
		flagged_status = stF, flagged = flagV, flagged_source = src })
end

-- ---------------------------------------------------------------- bootstrap

local okF, f = pcall(CreateFrame, "Frame")
frame = okF and f or nil

session = { probe_version = VERSION, started_t = now(), checkpoints = {}, inspections = {}, qlu_log = {},
	registration = {},
	sv = { present_at_file_load = (svAtFileLoad ~= nil),
		sessions_at_file_load = (type(svAtFileLoad) == "table" and type(svAtFileLoad.sessions) == "table") and #svAtFileLoad.sessions or nil } }
ForeverProbeM812DB = svAtFileLoad or fileLoadTable

--- Called at ADDON_LOADED: attach this session to the table that will actually be saved.
local function attachSession()
	local restored = ForeverProbeM812DB
	session.sv.replaced_before_addon_loaded = (restored ~= (svAtFileLoad or fileLoadTable))
	session.sv.present_at_addon_loaded = (restored ~= nil)
	if type(restored) ~= "table" then
		restored = {}
		ForeverProbeM812DB = restored
	end
	restored.sessions = restored.sessions or {}
	session.sv.sessions_before_this = #restored.sessions
	table.insert(restored.sessions, session)
end
local okB, gv, build, bdate, toc = pcall(GetBuildInfo)
if okB then session.game_version, session.build, session.build_date, session.toc_version = gv, build, bdate, toc end

snapshot("file_load")

local function schedule(name, delay)
	local t = now()
	if t then table.insert(pending, { due = t + delay, name = name }) end
end

local function onEvent(self, event, ...)
	if event == "ADDON_LOADED" then
		if ... == addonName then
			attachSession()
			snapshot("ADDON_LOADED")
		end
	elseif event == "PLAYER_LOGIN" then
		snapshot("PLAYER_LOGIN")
	elseif event == "PLAYER_ENTERING_WORLD" then
		local isInitial, isReload = ...
		session.is_initial_login, session.is_reloading_ui = isInitial, isReload
		pewAt = now()
		snapshot("PLAYER_ENTERING_WORLD", { is_initial_login = isInitial, is_reloading_ui = isReload })
		schedule("PLAYER_ENTERING_WORLD+3.0s", 3.0)
	elseif event == "QUEST_LOG_UPDATE" then
		local log = readLog()
		if #session.qlu_log < MAX_QLU_LOG then
			table.insert(session.qlu_log, { t = now(), entries = log.entries, quests = #log.order })
		end
		if not firstQLU then
			firstQLU = now()
			snapshot("first_QUEST_LOG_UPDATE")
			schedule("first_QLU+0.5s", 0.5)
			schedule("first_QLU+2.0s", 2.0)
		end
	end
end

local function onUpdate()
	session.onupdate_ticks = (session.onupdate_ticks or 0) + 1
	if #pending == 0 then return end
	local t = now()
	if not t then return end
	local i = 1
	while i <= #pending do
		if t >= pending[i].due - 0.001 then
			local p = table.remove(pending, i)
			snapshot(p.name)
		else
			i = i + 1
		end
	end
	if #pending == 0 and firstQLU and pewAt then
		finalize()
	end
end

if frame then
	for _, ev in ipairs({ "ADDON_LOADED", "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "QUEST_LOG_UPDATE" }) do
		local ok, err = pcall(frame.RegisterEvent, frame, ev)
		session.registration[ev] = ok and "registered" or ("registration_error: " .. tostring(err))
	end
	frame:SetScript("OnEvent", onEvent)
	frame:SetScript("OnUpdate", onUpdate)
end

-- ---------------------------------------------------------------- slash command

SLASH_FOREVERPROBEM8121 = "/fprobe812"
SlashCmdList["FOREVERPROBEM812"] = function(msg)
	msg = (msg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
	local qid = tonumber(msg:match("^q%s+(%d+)$") or "")
	if qid then return inspect(qid) end
	if msg == "now" then
		local s = snapshot("manual")
		say(checkpointLine(s))
		return
	end
	say(string.format("%s | PLAYER_ENTERING_WORLD isInitialLogin=%s isReloadingUi=%s | QUEST_LOG_UPDATE seen %d time(s)",
		VERSION, tostring(session.is_initial_login), tostring(session.is_reloading_ui), #session.qlu_log))
	say(string.format("SavedVariables: present at file load=%s | replaced before ADDON_LOADED=%s | earlier sessions in file=%s",
		tostring(session.sv.present_at_file_load), tostring(session.sv.replaced_before_addon_loaded),
		tostring(session.sv.sessions_before_this)))
	local apis = session.checkpoints[1] and session.checkpoints[1].apis or {}
	say(string.format("IsQuestFlaggedCompleted: C_QuestLog %s, global %s | GetAllCompletedQuestIDs: %s",
		tostring(apis["C_QuestLog.IsQuestFlaggedCompleted"]), tostring(apis["IsQuestFlaggedCompleted"]),
		tostring(apis["C_QuestLog.GetAllCompletedQuestIDs"])))
	for _, s in ipairs(session.checkpoints) do
		local mark = (s.same_as_last == nil) and "" or (s.same_as_last and " [= final]" or " [differs from final]")
		say(checkpointLine(s) .. mark)
	end
	say("Now /reload to save.")
end

-- Test-only seam on the addon's private namespace (no new global). No in-game code path reads it.
ns._selftest = {
	getSession = function() return session end,
	onUpdate = function() onUpdate() end,
	slash = function(m) SlashCmdList["FOREVERPROBEM812"](m) end,
	reference = REFERENCE,
}
