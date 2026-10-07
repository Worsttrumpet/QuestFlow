-- run_probe_selftest.lua -- lua5.1 run_probe_selftest.lua (from this tests/ directory)
--
-- Exercises ForeverProbeM87 against a hand-built fake of the narrow WoW API slice it uses, in the style of
-- the project's existing stub environments. Proves the probe's own logic only: that it records what it is
-- given, survives a client that lacks QUEST_ACCEPTED, and never calls a quest-state-changing function.
-- It proves NOTHING about the real Forever client -- that is what the manual test is for.

local passed, failed = 0, 0
local function check(cond, name)
	if cond then passed = passed + 1; print("[OK]   " .. name)
	else failed = failed + 1; print("[FAIL] " .. name) end
end

local function buildWorld(opts)
	opts = opts or {}
	local w = { chat = {}, handlers = {}, hooks = {}, forbiddenCalls = 0, questLog = {} }
	_G.ForeverProbeM87DB = opts.db
	_G.DEFAULT_CHAT_FRAME = { AddMessage = function(_, m) table.insert(w.chat, m) end }
	local clock = 100
	_G.GetTime = function() return clock end
	w.advance = function(dt) clock = clock + dt end
	_G.time = function() return 1790000000 end
	_G.GetBuildInfo = function() return "1.16.1", "69977", "Sep 1 2026", 16001 end
	_G.GetQuestID = function() return w.offerID end
	_G.GetTitleText = function() return w.offerTitle end
	_G.C_QuestLog = {
		GetNumQuestLogEntries = function() local n = 0 for _ in pairs(w.questLog) do n = n + 1 end return n end,
		GetTitleForQuestID = function(id) return w.titles[id] end,
		IsOnQuest = function(id) return w.questLog[id] == true end,
		GetLogIndexForQuestID = function(id) return w.questLog[id] and 1 or nil end,
		AbandonQuest = function() w.forbiddenCalls = w.forbiddenCalls + 1 end,
	}
	w.titles = { [907] = "Enraged Thunder Lizards" }
	_G.hooksecurefunc = function(a, b, c)
		if type(a) == "string" then w.hooks[a] = b else w.hooks["C_QuestLog." .. b] = c end
	end
	-- These exist on the client; the probe must only hook them, never call them.
	_G.AcceptQuest = function() w.forbiddenCalls = w.forbiddenCalls + 1 end
	_G.AbandonQuest = function() w.forbiddenCalls = w.forbiddenCalls + 1 end
	_G.GetQuestReward = function() w.forbiddenCalls = w.forbiddenCalls + 1 end
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
	-- simulates the player: offer screen, click Accept (hook runs), server confirms (events fire)
	w.playerAccepts = function(id, title, eventArgsFn)
		w.offerID, w.offerTitle = id, title
		w.fire("QUEST_DETAIL")
		if w.hooks.AcceptQuest then w.hooks.AcceptQuest() end
		w.questLog[id] = true
		w.advance(0.3)
		w.fire("QUEST_ACCEPTED", eventArgsFn(id))
		w.fire("QUEST_LOG_UPDATE")
	end
	w.playerAbandons = function(id)
		if w.hooks.AbandonQuest then w.hooks.AbandonQuest() end
		w.questLog[id] = nil
		w.fire("QUEST_REMOVED", id)
		w.fire("QUEST_LOG_UPDATE")
	end
	local ns = {}
	assert(loadfile("../addon/ForeverProbeM87/ForeverProbeM87.lua"))("ForeverProbeM87", ns)
	w.ns = ns
	w.fire("ADDON_LOADED", "ForeverProbeM87")
	return w
end

print("== scenario 1: modern shape, QUEST_ACCEPTED(questID) ==")
local w = buildWorld()
local s = w.ns._selftest.getSession()
check(s.registration.QUEST_ACCEPTED == "registered", "QUEST_ACCEPTED registration recorded as registered")
check(s.hooks.AcceptQuest == "installed", "AcceptQuest ground-truth hook installed")
w.playerAccepts(907, "Enraged Thunder Lizards", function(id) return id end)
w.advance(10)
w.playerAbandons(907)
w.advance(10)
w.playerAccepts(907, "Enraged Thunder Lizards", function(id) return id end)
check(s.counts.QUEST_ACCEPTED == 2, "QUEST_ACCEPTED counted once per accept (2)")
check(s.counts["hook:AcceptQuest"] == 2, "AcceptQuest clicks counted (2)")
check(s.counts.QUEST_REMOVED == 1, "QUEST_REMOVED counted on abandon")
local ev
for _, e in ipairs(s.events) do if e.event == "QUEST_ACCEPTED" then ev = e break end end
check(ev and ev.args.n == 1 and ev.args[1].value == 907, "raw argument stored with count")
check(ev and ev.resolved[1].title_for_quest_id == "Enraged Thunder Lizards", "numeric arg resolved to quest title")
check(ev and ev.resolved[1].is_on_quest == true, "IsOnQuest recorded")
local detail
for _, e in ipairs(s.events) do if e.event == "QUEST_DETAIL" then detail = e break end end
check(detail and detail.get_quest_id == 907, "QUEST_DETAIL control captured quest ID")
local sawChat = false
for _, m in ipairs(w.chat) do if m:find("QUEST_ACCEPTED fired %(#1%)") and m:find("Enraged Thunder Lizards") then sawChat = true end end
check(sawChat, "live chat line names the quest")
w.ns._selftest.slash()
check(w.chat[#w.chat]:find("/reload"), "summary command reminds to /reload")
check(w.forbiddenCalls == 0, "no quest-state-changing function was ever called")

print("== scenario 2: legacy shape, QUEST_ACCEPTED(logIndex, questID) ==")
w = buildWorld()
s = w.ns._selftest.getSession()
w.playerAccepts(907, "Enraged Thunder Lizards", function(id) return 3, id end)
ev = nil
for _, e in ipairs(s.events) do if e.event == "QUEST_ACCEPTED" then ev = e end end
check(ev.args.n == 2 and ev.args[2].value == 907, "both positional args kept")
check(ev.resolved[2].title_for_quest_id == "Enraged Thunder Lizards", "second arg resolved as quest ID")

print("== scenario 3: client without QUEST_ACCEPTED ==")
w = buildWorld({ unknownEvents = { QUEST_ACCEPTED = true } })
s = w.ns._selftest.getSession()
check(s.registration.QUEST_ACCEPTED:find("^registration_error") ~= nil, "unknown event recorded as a finding, no crash")
check(s.registration.QUEST_DETAIL == "registered", "control events still registered")
w.playerAccepts(907, "Enraged Thunder Lizards", function(id) return id end)
check((s.counts.QUEST_ACCEPTED or 0) == 0 and s.counts["hook:AcceptQuest"] == 1, "absence is distinguishable from a dead probe")

print("== scenario 4: existing SavedVariables are appended to, not replaced ==")
w = buildWorld({ db = { sessions = { { probe_version = "earlier" } } } })
check(#ForeverProbeM87DB.sessions == 2 and ForeverProbeM87DB.sessions[1].probe_version == "earlier", "earlier session preserved")

print("== scenario 5: QUEST_LOG_UPDATE throttling ==")
w = buildWorld()
s = w.ns._selftest.getSession()
w.advance(60)
for _ = 1, 50 do w.fire("QUEST_LOG_UPDATE") end
local stored = 0
for _, e in ipairs(s.events) do if e.event == "QUEST_LOG_UPDATE" then stored = stored + 1 end end
check(s.counts.QUEST_LOG_UPDATE == 50 and stored == 0, "background log updates counted but not stored")

print(string.format("\n%d passed, %d failed", passed, failed))
os.exit(failed == 0 and 0 or 1)
