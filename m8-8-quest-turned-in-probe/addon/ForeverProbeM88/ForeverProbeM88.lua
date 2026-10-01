-- ForeverProbeM88: disposable M8.8 research probe.
--
-- ONE question: is QUEST_TURNED_IN a reliable progression signal on WoW Forever -- does it fire exactly once
-- per successful turn-in, promptly after the reward is actually taken, identifying the right quest, and never
-- for a turn-in window that was merely opened and closed? It does not design or implement route progression.
--
-- M3 already recorded QUEST_TURNED_IN firing with (questID, xp, money) on 16 turn-ins. That establishes
-- existence only. It never measured exactly-once firing, timing against the player's click, or false fires,
-- so none of those are assumed here.
--
-- Same convention as ForeverProbeM87 and the M3/M4 probes: a standalone, uniquely named addon.
--
-- | Folder / files     | ForeverProbeM88 / ForeverProbeM88.lua, .toc |
-- | SavedVariables     | ForeverProbeM88DB                           |
-- | Slash command      | /fprobe88                                   |
-- | Chat prefix        | [FProbeM88] (magenta)                       |
-- | Version            | m8-8-probe-0.1                              |
--
-- READ-ONLY. This file never calls GetQuestReward, CompleteQuest, AcceptQuest, AbandonQuest or any other
-- quest-state-changing function. GetQuestReward (the reward screen's "Complete Quest" button) and
-- CompleteQuest (the progress screen's "Continue" button) are only OBSERVED via hooksecurefunc post-hooks,
-- which run after Blizzard's own function and cannot change what it does. That timestamps the player's own
-- click -- the ground truth QUEST_TURNED_IN is measured against.
--
-- Persistence: logout/character-select SavedVariables saves are unreliable on this client (M8_0_SCOPE.md SS2);
-- /reload saves are confirmed. The test procedure ends with /reload.

local addonName, ns = ...
local VERSION = "m8-8-probe-0.1"
local PREFIX = "|cffdd66ff[FProbeM88]|r "

local TARGET_EVENT = "QUEST_TURNED_IN"
-- Controls: tell "never fired" apart from "probe was not running", and place the event on the interaction's
-- timeline. QUEST_PROGRESS / QUEST_COMPLETE confirmed M3-M7.7; QUEST_REMOVED confirmed M8.7 (on abandon only).
local CONTROL_EVENTS = {
	"QUEST_PROGRESS",         -- confirmed: "items needed" / Continue screen of a turn-in
	"QUEST_COMPLETE",         -- confirmed: reward screen opened (window OPEN, not reward taken)
	"QUEST_FINISHED",         -- unconfirmed: quest dialog closed (by completing OR by cancelling)
	"QUEST_REMOVED",          -- confirmed on abandon (M8.7); whether it also fires on turn-in is recorded
	"QUEST_LOG_UPDATE",       -- throttled
	"UNIT_QUEST_LOG_CHANGED", -- throttled
}
local THROTTLED = { QUEST_LOG_UPDATE = true, UNIT_QUEST_LOG_CHANGED = true }
local ANNOUNCED = { QUEST_PROGRESS = true, QUEST_COMPLETE = true, QUEST_FINISHED = true, QUEST_REMOVED = true }

local MAX_EVENTS_PER_SESSION = 300
local WINDOW_SECONDS = 5
local MAX_THROTTLED_PER_WINDOW = 5

ForeverProbeM88DB = ForeverProbeM88DB or {}
ForeverProbeM88DB.sessions = ForeverProbeM88DB.sessions or {}

local session
local lastInterestingAt = -1000
local throttledInWindow = 0
-- Most recent reward-screen context and Complete click, so each QUEST_TURNED_IN can be compared against both.
local lastComplete = nil   -- { t, quest_id, title }
local lastRewardClick = nil -- { t, choice }

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

local function dialogQuest()
	local okID, qid = safe(GetQuestID)
	local okT, title = safe(GetTitleText)
	return okID and qid or nil, okT and title or nil
end

--- Read-only lookups for a numeric argument. After a turn-in the quest has left the log, so IsOnQuest is
-- expected false; IsQuestFlaggedCompleted is the direct "was this quest just completed" check.
local function resolveNumber(v)
	local r = { value = v }
	if type(C_QuestLog) == "table" then
		local ok1, title = safe(C_QuestLog.GetTitleForQuestID, v)
		if ok1 then r.title_for_quest_id = title end
		local ok2, onQuest = safe(C_QuestLog.IsOnQuest, v)
		if ok2 then r.is_on_quest = onQuest end
		local ok3, done = safe(C_QuestLog.IsQuestFlaggedCompleted, v)
		if ok3 then r.is_flagged_completed = done end
	end
	if r.is_flagged_completed == nil then
		local ok4, done2 = safe(IsQuestFlaggedCompleted, v)
		if ok4 then r.legacy_is_flagged_completed = done2 end
	end
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

local function since(t0)
	local t = now()
	if t and t0 then
		return t - t0
	end
	return nil
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
	local fields = { event = TARGET_EVENT, args = args, resolved = resolved }
	if lastComplete then
		fields.reward_screen_quest_id = lastComplete.quest_id
		fields.reward_screen_title = lastComplete.title
		fields.seconds_since_reward_screen = since(lastComplete.t)
	end
	if lastRewardClick then
		fields.seconds_since_complete_click = since(lastRewardClick.t)
	end
	local matchIndex
	for i = 1, args.n do
		if lastComplete and args[i].value ~= nil and args[i].value == lastComplete.quest_id then
			matchIndex = i
			break
		end
	end
	fields.arg_matching_reward_screen = matchIndex
	record("event", fields)

	local parts = {}
	for i = 1, args.n do
		local a = args[i]
		table.insert(parts, (a.value ~= nil) and tostring(a.value) or ("<" .. a.type .. ">"))
	end
	local match = matchIndex
		and string.format(" | arg %d matches reward screen quest \"%s\"", matchIndex, tostring(lastComplete.title))
		or " | no arg matches the last reward screen"
	local delay = fields.seconds_since_complete_click
		and string.format(" | %.2fs after Complete click", fields.seconds_since_complete_click) or " | no Complete click seen"
	say(string.format("QUEST_TURNED_IN fired (#%d). args: %s%s%s", session.counts[TARGET_EVENT],
		(#parts > 0) and table.concat(parts, ", ") or "(none)", match, delay))
end

local function onControl(event, ...)
	bump(event)
	if THROTTLED[event] then
		local t = now()
		if not t or (t - lastInterestingAt) > WINDOW_SECONDS or throttledInWindow >= MAX_THROTTLED_PER_WINDOW then
			return
		end
		throttledInWindow = throttledInWindow + 1
		record("event", { event = event, args = captureArgs(...) })
		return
	end

	markInteresting()
	local fields = { event = event, args = captureArgs(...) }
	if event == "QUEST_PROGRESS" or event == "QUEST_COMPLETE" then
		local qid, title = dialogQuest()
		fields.get_quest_id, fields.title_text = qid, title
		if event == "QUEST_COMPLETE" then
			lastComplete = { t = now(), quest_id = qid, title = title }
			say(string.format("QUEST_COMPLETE: reward screen OPEN for \"%s\" (id %s). Not turned in yet.",
				tostring(title), tostring(qid)))
		else
			say(string.format("QUEST_PROGRESS: turn-in screen for \"%s\" (id %s).", tostring(title), tostring(qid)))
		end
	elseif event == "QUEST_FINISHED" then
		say("QUEST_FINISHED: quest dialog closed.")
	elseif event == "QUEST_REMOVED" then
		local a = fields.args
		say("QUEST_REMOVED fired. first arg: " .. tostring(a[1] and a[1].value))
	end
	record("event", fields)
end

-- ---------------------------------------------------------------- ground-truth hooks

local function installHooks()
	session.hooks = {}
	local ok, err = safe(hooksecurefunc, "GetQuestReward", function(...)
		markInteresting()
		local fields = { hook = "GetQuestReward", args = captureArgs(...) }
		fields.get_quest_id, fields.title_text = dialogQuest()
		lastRewardClick = { t = now() }
		record("hook", fields)
		bump("hook:GetQuestReward")
		say("Complete Quest clicked (reward taken).")
	end)
	session.hooks.GetQuestReward = ok and "installed" or ("failed: " .. tostring(err))

	local ok2, err2 = safe(hooksecurefunc, "CompleteQuest", function(...)
		markInteresting()
		local fields = { hook = "CompleteQuest", args = captureArgs(...) }
		fields.get_quest_id, fields.title_text = dialogQuest()
		record("hook", fields)
		bump("hook:CompleteQuest")
	end)
	session.hooks.CompleteQuest = ok2 and "installed" or ("failed: " .. tostring(err2))
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
	table.insert(ForeverProbeM88DB.sessions, session)
	registerAll()
	installHooks()
	say(string.format("%s loaded (session %d). QUEST_TURNED_IN: %s. Complete-click hook: %s.",
		VERSION, #ForeverProbeM88DB.sessions, session.registration[TARGET_EVENT], session.hooks.GetQuestReward))
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

SLASH_FOREVERPROBEM881 = "/fprobe88"
SlashCmdList["FOREVERPROBEM88"] = function()
	if not session then
		say("no session started.")
		return
	end
	local c = session.counts
	say(string.format("QUEST_TURNED_IN registration: %s | Complete-click hook: %s",
		tostring(session.registration[TARGET_EVENT]), tostring(session.hooks.GetQuestReward)))
	say(string.format("this session: QUEST_TURNED_IN=%d | Complete clicks=%d | reward screens opened=%d | dialogs closed=%d | QUEST_REMOVED=%d",
		c[TARGET_EVENT] or 0, c["hook:GetQuestReward"] or 0, c["QUEST_COMPLETE"] or 0,
		c["QUEST_FINISHED"] or 0, c["QUEST_REMOVED"] or 0))
	say(string.format("events stored: %d%s. Now /reload to save the result.", #session.events,
		session.cap_reached and " (cap reached)" or ""))
end

-- Test-only seam on the addon's private namespace (no new global). No in-game code path reads it.
ns._selftest = {
	getSession = function() return session end,
	slash = function() SlashCmdList["FOREVERPROBEM88"]() end,
}
