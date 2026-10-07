-- run_probe_selftest.lua -- lua5.1 run_probe_selftest.lua (from this tests/ directory)
--
-- Exercises ForeverProbeM88 against a hand-built fake of the narrow WoW API slice it uses. Proves the probe's
-- own logic only: that it records and compares what it is given, distinguishes a cancelled reward screen from
-- a real turn-in, survives a client lacking the event or the hook target, and never calls a
-- quest-state-changing function. It proves NOTHING about the real Forever client.

local passed, failed = 0, 0
local function check(cond, name)
	if cond then passed = passed + 1; print("[OK]   " .. name)
	else failed = failed + 1; print("[FAIL] " .. name) end
end

local function buildWorld(opts)
	opts = opts or {}
	local w = { chat = {}, hooks = {}, forbiddenCalls = 0, questLog = {}, completed = {} }
	_G.ForeverProbeM88DB = opts.db
	_G.DEFAULT_CHAT_FRAME = { AddMessage = function(_, m) table.insert(w.chat, m) end }
	local clock = 100
	_G.GetTime = function() return clock end
	w.advance = function(dt) clock = clock + dt end
	_G.time = function() return 1790000000 end
	_G.GetBuildInfo = function() return "1.60.1", "70124", "Sep 29 2026", 16001 end
	_G.GetQuestID = function() return w.dialogID or 0 end
	_G.GetTitleText = function() return w.dialogTitle or "" end
	w.titles = { [1013] = "The Book of Ur", [92421] = "Light's Justice" }
	_G.C_QuestLog = {
		GetTitleForQuestID = function(id) return w.titles[id] end,
		IsOnQuest = function(id) return w.questLog[id] == true end,
		IsQuestFlaggedCompleted = function(id) return w.completed[id] == true end,
	}
	_G.hooksecurefunc = function(name, fn)
		if opts.missingFunctions and opts.missingFunctions[name] then
			error("hooksecurefunc(): " .. name .. " is not a function")
		end
		w.hooks[name] = fn
	end
	-- Exist on the client; the probe must only hook them, never call them.
	_G.GetQuestReward = function() w.forbiddenCalls = w.forbiddenCalls + 1 end
	_G.CompleteQuest = function() w.forbiddenCalls = w.forbiddenCalls + 1 end
	_G.AcceptQuest = function() w.forbiddenCalls = w.forbiddenCalls + 1 end
	_G.SlashCmdList = {}
	_G.CreateFrame = function()
		local f = { registered = {} }
		function f:RegisterEvent(ev)
			if opts.unknownEvents and opts.unknownEvents[ev] then
				error("Attempt to register unknown event \"" .. ev .. "\"")
			end
			self.registered[ev] = true
		end
		function f:UnregisterEvent(ev) self.registered[ev] = nil end
		function f:SetScript(_, fn) self.onEvent = fn end
		w.frame = f
		return f
	end
	w.fire = function(ev, ...)
		if w.frame.registered[ev] then w.frame.onEvent(w.frame, ev, ...) end
	end
	w.openRewardScreen = function(id)
		w.dialogID, w.dialogTitle = id, w.titles[id]
		w.fire("QUEST_PROGRESS")
		if w.hooks.CompleteQuest then w.hooks.CompleteQuest() end
		w.fire("QUEST_COMPLETE")
	end
	w.closeDialog = function()
		w.dialogID, w.dialogTitle = nil, nil
		w.fire("QUEST_FINISHED")
	end
	-- a real turn-in: click Complete, server confirms, quest leaves the log
	w.clickComplete = function(id, turnedInArgs)
		if w.hooks.GetQuestReward then w.hooks.GetQuestReward(1) end
		w.dialogID, w.dialogTitle = 0, ""
		w.advance(0.35)
		w.questLog[id] = nil
		w.completed[id] = true
		w.fire("QUEST_TURNED_IN", unpack(turnedInArgs))
		w.fire("QUEST_REMOVED", id, false)
		w.fire("QUEST_LOG_UPDATE")
		w.closeDialog()
	end
	local ns = {}
	assert(loadfile("../addon/ForeverProbeM88/ForeverProbeM88.lua"))("ForeverProbeM88", ns)
	w.ns = ns
	w.fire("ADDON_LOADED", "ForeverProbeM88")
	return w
end

local function findAll(s, name)
	local out = {}
	for _, e in ipairs(s.events) do if e.event == name then table.insert(out, e) end end
	return out
end

print("== scenario 1: cancel first, then a real turn-in, then a second quest ==")
local w = buildWorld()
local s = w.ns._selftest.getSession()
check(s.registration.QUEST_TURNED_IN == "registered", "QUEST_TURNED_IN registration recorded")
check(s.hooks.GetQuestReward == "installed", "Complete-click (GetQuestReward) hook installed")
w.questLog[1013] = true
w.openRewardScreen(1013)
w.advance(3)
w.closeDialog()   -- cancelled: window opened and closed, no Complete click
check((s.counts.QUEST_TURNED_IN or 0) == 0, "cancelled reward screen produced no QUEST_TURNED_IN in the probe's record")
check(s.counts.QUEST_COMPLETE == 1 and s.counts.QUEST_FINISHED == 1, "cancel is visible as open + close")
w.advance(5)
w.openRewardScreen(1013)
w.advance(2)
w.clickComplete(1013, { 1013, 360, 1200 })
check(s.counts.QUEST_TURNED_IN == 1, "one turn-in -> one QUEST_TURNED_IN")
check(s.counts["hook:GetQuestReward"] == 1, "one Complete click recorded")
local ti = findAll(s, "QUEST_TURNED_IN")[1]
check(ti.args.n == 3 and ti.args[1].value == 1013 and ti.args[2].value == 360, "all args stored with count")
check(ti.arg_matching_reward_screen == 1, "arg 1 matched against the reward-screen quest ID")
check(ti.reward_screen_title == "The Book of Ur", "reward-screen title stored with the event")
check(ti.seconds_since_complete_click and math.abs(ti.seconds_since_complete_click - 0.35) < 1e-6, "delay after Complete click recorded")
check(ti.seconds_since_reward_screen and ti.seconds_since_reward_screen > ti.seconds_since_complete_click, "delay after window open recorded separately")
check(ti.resolved[1].is_flagged_completed == true and ti.resolved[1].is_on_quest == false, "completion flag and log state recorded")
check(s.counts.QUEST_REMOVED == 1, "QUEST_REMOVED on turn-in recorded (context only)")
local saw = false
for _, m in ipairs(w.chat) do if m:find("QUEST_TURNED_IN fired %(#1%)") and m:find("The Book of Ur") and m:find("after Complete click") then saw = true end end
check(saw, "live chat line shows ID match and delay")
w.advance(30)
w.questLog[92421] = true
w.openRewardScreen(92421)
w.clickComplete(92421, { 92421, 500, 0 })
check(s.counts.QUEST_TURNED_IN == 2 and findAll(s, "QUEST_TURNED_IN")[2].arg_matching_reward_screen == 1, "second turn-in matched its own quest")
w.ns._selftest.slash()
check(w.chat[#w.chat]:find("/reload"), "summary command reminds to /reload")
check(w.forbiddenCalls == 0, "no quest-state-changing function was ever called")

print("== scenario 2: event arrives with an ID that does not match the reward screen ==")
w = buildWorld()
s = w.ns._selftest.getSession()
w.openRewardScreen(1013)
w.clickComplete(1013, { 92421, 0, 0 })
local ti2 = findAll(s, "QUEST_TURNED_IN")[1]
check(ti2.arg_matching_reward_screen == nil, "mismatch recorded as no matching arg")
local sawNo = false
for _, m in ipairs(w.chat) do if m:find("no arg matches") then sawNo = true end end
check(sawNo, "mismatch shown in chat")

print("== scenario 3: event with no Complete click seen ==")
w = buildWorld()
s = w.ns._selftest.getSession()
w.fire("QUEST_TURNED_IN", 1013, 0, 0)
local ti3 = findAll(s, "QUEST_TURNED_IN")[1]
check(ti3.seconds_since_complete_click == nil and ti3.arg_matching_reward_screen == nil, "unexplained fire recorded without invented context")

print("== scenario 4: client without the event or the hook target ==")
w = buildWorld({ unknownEvents = { QUEST_TURNED_IN = true }, missingFunctions = { GetQuestReward = true } })
s = w.ns._selftest.getSession()
check(s.registration.QUEST_TURNED_IN:find("^registration_error") ~= nil, "unknown event recorded as a finding, no crash")
check(s.hooks.GetQuestReward:find("^failed") ~= nil, "missing hook target recorded as a finding, no crash")
check(s.registration.QUEST_COMPLETE == "registered", "controls still registered")

print("== scenario 5: existing SavedVariables are appended to ==")
w = buildWorld({ db = { sessions = { { probe_version = "earlier" } } } })
check(#ForeverProbeM88DB.sessions == 2 and ForeverProbeM88DB.sessions[1].probe_version == "earlier", "earlier session preserved")

print("== scenario 6: background log updates throttled ==")
w = buildWorld()
s = w.ns._selftest.getSession()
w.advance(60)
for _ = 1, 40 do w.fire("QUEST_LOG_UPDATE") end
check(s.counts.QUEST_LOG_UPDATE == 40 and #findAll(s, "QUEST_LOG_UPDATE") == 0, "counted, not stored, outside an interaction")

print(string.format("\n%d passed, %d failed", passed, failed))
os.exit(failed == 0 and 0 or 1)
