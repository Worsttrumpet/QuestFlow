-- ForeverProbeM87: disposable M8.7 research probe.
--
-- ONE question: does WoW Forever expose a QUEST_ACCEPTED event, and does it fire reliably, once per accept,
-- with enough information to identify the accepted quest? Nothing else. It does not design or implement
-- route progression.
--
-- Follows the M3/M4 probe convention (ForeverProbe, ForeverProbeM4, ForeverProbeM4Rep, ForeverProbeM4Retry):
-- a standalone, uniquely named addon with its own SavedVariables global, slash command, chat prefix and
-- version string, so it can sit beside ForeverRecorder and ForeverQuestGuide without touching either.
--
-- | Folder / files     | ForeverProbeM87 / ForeverProbeM87.lua, .toc |
-- | SavedVariables     | ForeverProbeM87DB                           |
-- | Slash command      | /fprobe87                                   |
-- | Chat prefix        | [FProbeM87] (cyan)                          |
-- | Version            | m8-7-probe-0.1                              |
--
-- READ-ONLY. This file never calls AcceptQuest, AbandonQuest, CompleteQuest, GetQuestReward or any other
-- quest-state-changing function. AcceptQuest/AbandonQuest are only OBSERVED via hooksecurefunc (a post-hook
-- that runs after Blizzard's own function and cannot change what it does), to timestamp the moment the
-- player clicked -- an independent ground truth to compare QUEST_ACCEPTED against.
--
-- Persistence: docs/M8_0_SCOPE.md SS2 records that SavedVariables written at logout/character-select are
-- NOT reliably persisted on this client, while /reload saves are. The test procedure therefore ends with
-- /reload. Nothing here tries to work around that.
--
-- Everything is pcall-wrapped. An event name the client does not know makes RegisterEvent raise an error;
-- that error is RECORDED as a finding (registration_error), not allowed to break the probe.

local addonName, ns = ...
local VERSION = "m8-7-probe-0.1"
local PREFIX = "|cff33ddff[FProbeM87]|r "

-- The event under test, then control events. Controls exist so an absent QUEST_ACCEPTED can be told apart
-- from "the probe was not running": QUEST_DETAIL and QUEST_TURNED_IN are already real-client confirmed by
-- M3-M7, so if they fire and QUEST_ACCEPTED does not, the probe was live and the absence is real.
local TARGET_EVENT = "QUEST_ACCEPTED"
local CONTROL_EVENTS = {
	"QUEST_DETAIL",           -- confirmed (M3+): quest offer screen opened
	"QUEST_ACCEPT_CONFIRM",   -- unconfirmed: escort/shared-quest confirmation; recorded if it happens
	"QUEST_LOG_UPDATE",       -- unconfirmed here: generic log change; throttled (see below)
	"QUEST_REMOVED",          -- unconfirmed: expected on abandon
	"QUEST_TURNED_IN",        -- confirmed (M3+): not expected in this test; recorded if it happens
	"UNIT_QUEST_LOG_CHANGED", -- unconfirmed: generic per-unit log change; throttled like QUEST_LOG_UPDATE
}
local THROTTLED = { QUEST_LOG_UPDATE = true, UNIT_QUEST_LOG_CHANGED = true }

local MAX_EVENTS_PER_SESSION = 300  -- hard cap: this is a minimal test, not broad data collection
local WINDOW_SECONDS = 5            -- throttled events are kept only this long after an interesting moment
local MAX_THROTTLED_PER_WINDOW = 5

ForeverProbeM87DB = ForeverProbeM87DB or {}
ForeverProbeM87DB.sessions = ForeverProbeM87DB.sessions or {}

local session
local lastInterestingAt = -1000
local throttledInWindow = 0

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

local function wallclock()
	local ok, t = safe(time)
	return ok and t or nil
end

--- Stores every vararg by position with its Lua type, plus an explicit count, so a nil in the middle of the
-- argument list is never silently lost (the same reason M4 stored v1..v6 + v1_is_nil).
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

local function questLogCount()
	if type(C_QuestLog) == "table" then
		local ok, n = safe(C_QuestLog.GetNumQuestLogEntries)
		if ok and n then
			return n, "C_QuestLog.GetNumQuestLogEntries"
		end
	end
	local ok, n = safe(GetNumQuestLogEntries)
	if ok and n then
		return n, "GetNumQuestLogEntries"
	end
	return nil, "unavailable"
end

--- For a numeric event argument, asks the client (read-only) whether it names a quest the player now has.
-- Tried for every numeric argument, because QUEST_ACCEPTED's argument shape differs between WoW versions
-- (questID alone vs questLogIndex + questID) and nothing about Forever's shape is confirmed.
local function resolveNumber(v)
	local r = { value = v }
	if type(C_QuestLog) == "table" then
		local ok1, title = safe(C_QuestLog.GetTitleForQuestID, v)
		if ok1 then r.title_for_quest_id = title end
		local ok2, onQuest = safe(C_QuestLog.IsOnQuest, v)
		if ok2 then r.is_on_quest = onQuest end
		local ok3, idx = safe(C_QuestLog.GetLogIndexForQuestID, v)
		if ok3 then r.log_index_for_quest_id = idx end
	end
	local ok4, idx2 = safe(GetQuestLogIndexByID, v)
	if ok4 then r.legacy_log_index_by_id = idx2 end
	local ok5, t = safe(GetQuestLogTitle, v)  -- only meaningful if v is a log INDEX (legacy clients)
	if ok5 and type(t) == "string" then r.legacy_title_if_log_index = t end
	return r
end

local function record(kind, fields)
	if not session then
		return
	end
	if #session.events >= MAX_EVENTS_PER_SESSION then
		session.cap_reached = true
		return
	end
	fields = fields or {}
	fields.kind = kind
	fields.t = now()
	fields.seq = #session.events + 1
	table.insert(session.events, fields)
end

local function bump(name)
	session.counts[name] = (session.counts[name] or 0) + 1
end

local function markInteresting()
	lastInterestingAt = now() or lastInterestingAt
	throttledInWindow = 0
end

-- ---------------------------------------------------------------- event handling

local function onTarget(...)
	bump(TARGET_EVENT)
	markInteresting()
	local args = captureArgs(...)
	local resolved = {}
	for i = 1, args.n do
		if args[i].type == "number" then
			resolved[i] = resolveNumber(args[i].value)
		end
	end
	local count, countSource = questLogCount()
	record("event", { event = TARGET_EVENT, args = args, resolved = resolved,
		quest_log_count = count, quest_log_count_source = countSource })

	-- Live chat line so the operator can see the result without opening any file.
	local parts = {}
	for i = 1, args.n do
		local a = args[i]
		local shown = (a.value ~= nil) and tostring(a.value) or ("<" .. a.type .. ">")
		local r = resolved[i]
		if r and r.title_for_quest_id then
			shown = shown .. " = \"" .. tostring(r.title_for_quest_id) .. "\""
		elseif r and r.legacy_title_if_log_index then
			shown = shown .. " (log index -> \"" .. r.legacy_title_if_log_index .. "\")"
		end
		table.insert(parts, shown)
	end
	say(string.format("QUEST_ACCEPTED fired (#%d). args: %s", session.counts[TARGET_EVENT],
		(#parts > 0) and table.concat(parts, ", ") or "(none)"))
end

local function onControl(event, ...)
	bump(event)
	if THROTTLED[event] then
		local t = now()
		if not t or (t - lastInterestingAt) > WINDOW_SECONDS or throttledInWindow >= MAX_THROTTLED_PER_WINDOW then
			return  -- counted, not stored
		end
		throttledInWindow = throttledInWindow + 1
		record("event", { event = event, args = captureArgs(...) })
		return
	end

	markInteresting()
	local fields = { event = event, args = captureArgs(...) }
	if event == "QUEST_DETAIL" then
		local okID, qid = safe(GetQuestID)
		if okID then fields.get_quest_id = qid end
		local okT, title = safe(GetTitleText)
		if okT then fields.title_text = title end
		say(string.format("QUEST_DETAIL: offer screen for \"%s\" (id %s).", tostring(title), tostring(qid)))
	elseif event == "QUEST_REMOVED" then
		local a = fields.args
		say("QUEST_REMOVED fired. first arg: " .. tostring(a[1] and a[1].value))
	end
	local count = questLogCount()
	fields.quest_log_count = count
	record("event", fields)
end

-- ---------------------------------------------------------------- ground-truth hooks

local function installHooks()
	session.hooks = {}
	local targets = { "AcceptQuest", "AbandonQuest", "SetAbandonQuest" }
	for _, fnName in ipairs(targets) do
		local ok, err = safe(hooksecurefunc, fnName, function(...)
			markInteresting()
			local fields = { hook = fnName, args = captureArgs(...) }
			if fnName == "AcceptQuest" then
				local okID, qid = safe(GetQuestID)
				if okID then fields.get_quest_id = qid end
				local okT, title = safe(GetTitleText)
				if okT then fields.title_text = title end
			end
			fields.quest_log_count = questLogCount()
			record("hook", fields)
			bump("hook:" .. fnName)
		end)
		session.hooks[fnName] = ok and "installed" or ("failed: " .. tostring(err))
	end
	if type(C_QuestLog) == "table" and type(C_QuestLog.AbandonQuest) == "function" then
		local ok, err = safe(hooksecurefunc, C_QuestLog, "AbandonQuest", function()
			markInteresting()
			record("hook", { hook = "C_QuestLog.AbandonQuest", quest_log_count = questLogCount() })
			bump("hook:C_QuestLog.AbandonQuest")
		end)
		session.hooks["C_QuestLog.AbandonQuest"] = ok and "installed" or ("failed: " .. tostring(err))
	end
end

-- ---------------------------------------------------------------- bootstrap

local frame = CreateFrame("Frame")

local function registerAll()
	session.registration = {}
	local ok, err = safe(frame.RegisterEvent, frame, TARGET_EVENT)
	session.registration[TARGET_EVENT] = ok and "registered" or ("registration_error: " .. tostring(err))
	for _, ev in ipairs(CONTROL_EVENTS) do
		local okC, errC = safe(frame.RegisterEvent, frame, ev)
		session.registration[ev] = okC and "registered" or ("registration_error: " .. tostring(errC))
	end
end

local function startSession()
	local okB, gameVersion, build, buildDate, tocVersion = safe(GetBuildInfo)
	session = {
		probe_version = VERSION,
		started_wallclock = wallclock(),
		started_t = now(),
		game_version = okB and gameVersion or nil,
		build = okB and build or nil,
		build_date = okB and buildDate or nil,
		toc_version = okB and tocVersion or nil,
		counts = {},
		events = {},
	}
	table.insert(ForeverProbeM87DB.sessions, session)
	registerAll()
	installHooks()
	local count, countSource = questLogCount()
	session.quest_log_count_at_start = count
	session.quest_log_count_source = countSource

	local reg = session.registration[TARGET_EVENT]
	say(string.format("%s loaded (session %d). QUEST_ACCEPTED: %s. Accept one quest, then /fprobe87 for a summary, then /reload.",
		VERSION, #ForeverProbeM87DB.sessions, reg))
end

frame:SetScript("OnEvent", function(self, event, ...)
	if event == "ADDON_LOADED" then
		if ... == addonName then
			self:UnregisterEvent("ADDON_LOADED")
			startSession()
		end
		return
	end
	if not session then
		return
	end
	if event == TARGET_EVENT then
		onTarget(...)
	else
		onControl(event, ...)
	end
end)
frame:RegisterEvent("ADDON_LOADED")

-- ---------------------------------------------------------------- summary command

SLASH_FOREVERPROBEM871 = "/fprobe87"
SlashCmdList["FOREVERPROBEM87"] = function()
	if not session then
		say("no session started.")
		return
	end
	local c = session.counts
	say(string.format("QUEST_ACCEPTED registration: %s", tostring(session.registration[TARGET_EVENT])))
	say(string.format("fired: QUEST_ACCEPTED=%d | AcceptQuest clicks=%d | QUEST_DETAIL=%d | QUEST_REMOVED=%d | abandon hooks=%d",
		c[TARGET_EVENT] or 0, c["hook:AcceptQuest"] or 0, c["QUEST_DETAIL"] or 0, c["QUEST_REMOVED"] or 0,
		(c["hook:AbandonQuest"] or 0) + (c["hook:C_QuestLog.AbandonQuest"] or 0)))
	say(string.format("events stored: %d%s. Now /reload to save the result.", #session.events,
		session.cap_reached and " (cap reached)" or ""))
end

-- Test-only seam for tests/run_probe_selftest.lua, on the addon's private namespace (no new global).
-- No in-game code path reads it.
ns._selftest = {
	getSession = function() return session end,
	slash = function() SlashCmdList["FOREVERPROBEM87"]() end,
}
