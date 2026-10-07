-- run_probe_selftest.lua -- lua5.1 run_probe_selftest.lua (from this tests/ directory)
--
-- Exercises ForeverProbeM89 against a hand-built fake quest log. Proves the probe's own logic only: that it
-- distinguishes state that is already updated when an event fires from state that lags, catches changes no
-- event announced, separates objectives within one quest, records completion, falls back to the legacy
-- leaderboard API, keeps text availability separate from progress, and never changes quest state.
-- It proves NOTHING about the real Forever client.

local passed, failed = 0, 0
local function check(cond, name)
	if cond then passed = passed + 1; print("[OK]   " .. name)
	else failed = failed + 1; print("[FAIL] " .. name) end
end

local function buildWorld(opts)
	opts = opts or {}
	local w = { chat = {}, forbiddenCalls = 0 }
	-- log: ordered list of entries; header rows included, as on the real client
	w.log = {
		{ isHeader = true, title = "The Barrens" },
		{ questID = 907, title = "Enraged Thunder Lizards",
			objectives = { { text = "Thunder Lizard Blood: 0/3", type = "item", finished = false, numFulfilled = 0, numRequired = 3 } } },
		{ questID = 500, title = "Two Things",
			objectives = {
				{ text = "Raptor slain: 1/4", type = "monster", finished = false, numFulfilled = 1, numRequired = 4 },
				{ text = "0/1  ", type = "item", finished = false, numFulfilled = 0, numRequired = 1 },
			} },
	}
	w.complete = {}
	_G.ForeverProbeM89DB = opts.db
	_G.DEFAULT_CHAT_FRAME = { AddMessage = function(_, m) table.insert(w.chat, m) end }
	local clock = 100
	_G.GetTime = function() return clock end
	w.advance = function(dt) clock = clock + dt end
	_G.GetBuildInfo = function() return "1.60.1", "70124", "Sep 29 2026", 16001 end
	local function byID(id) for _, e in ipairs(w.log) do if e.questID == id then return e end end end
	w.byID = byID
	_G.C_QuestLog = {
		GetNumQuestLogEntries = function() return #w.log end,
		GetInfo = function(i) local e = w.log[i]; return e and { questID = e.questID, title = e.title, isHeader = e.isHeader } end,
		IsComplete = function(id) return w.complete[id] == true end,
		ReadyForTurnIn = function(id) return w.complete[id] == true end,
		GetTitleForQuestID = function(id) local e = byID(id); return e and e.title end,
		AbandonQuest = function() w.forbiddenCalls = w.forbiddenCalls + 1 end,
	}
	if not opts.legacyOnly then
		C_QuestLog.GetQuestObjectives = function(id)
			local e = byID(id); if not e then return nil end
			local out = {}
			for i, o in ipairs(e.objectives) do
				out[i] = { text = o.text, type = o.type, finished = o.finished, numFulfilled = o.numFulfilled, numRequired = o.numRequired }
			end
			return out
		end
	else
		_G.GetNumQuestLeaderBoards = function(i) local e = w.log[i]; return e and e.objectives and #e.objectives or 0 end
		_G.GetQuestLogLeaderBoard = function(j, i) local o = w.log[i].objectives[j]; return o.text, o.type, o.finished end
	end
	_G.AcceptQuest = function() w.forbiddenCalls = w.forbiddenCalls + 1 end
	_G.AbandonQuest = function() w.forbiddenCalls = w.forbiddenCalls + 1 end
	_G.CompleteQuest = function() w.forbiddenCalls = w.forbiddenCalls + 1 end
	_G.GetQuestReward = function() w.forbiddenCalls = w.forbiddenCalls + 1 end
	_G.SlashCmdList = {}
	_G.CreateFrame = function()
		local f = { registered = {}, scripts = {} }
		function f:RegisterEvent(ev)
			if opts.unknownEvents and opts.unknownEvents[ev] then
				error("Attempt to register unknown event \"" .. ev .. "\"")
			end
			self.registered[ev] = true
		end
		function f:UnregisterEvent(ev) self.registered[ev] = nil end
		function f:SetScript(name, fn) self.scripts[name] = fn end
		w.frame = f
		return f
	end
	w.fire = function(ev, ...)
		if w.frame.registered[ev] then w.frame.scripts.OnEvent(w.frame, ev, ...) end
	end
	-- advance game time in small frames, running OnUpdate each frame
	w.run = function(seconds)
		local steps = math.floor(seconds / 0.05 + 0.5)
		for _ = 1, steps do
			w.advance(0.05)
			if w.frame.scripts.OnUpdate then w.frame.scripts.OnUpdate(w.frame, 0.05) end
		end
	end
	w.setObj = function(id, idx, have)
		local o = byID(id).objectives[idx]
		o.numFulfilled = have
		o.finished = have >= o.numRequired
		o.text = o.text:gsub("%d+/", have .. "/", 1)
	end
	local ns = {}
	assert(loadfile("../addon/ForeverProbeM89/ForeverProbeM89.lua"))("ForeverProbeM89", ns)
	w.ns = ns
	w.fire("ADDON_LOADED", "ForeverProbeM89")
	w.fire("PLAYER_ENTERING_WORLD")
	w.run(3.5)  -- settle + baseline
	return w
end

local function changes(s, how, kind)
	local out = {}
	for _, r in ipairs(s.records) do
		if r.kind == "change" and (not how or r.detected_by == how) then
			for _, c in ipairs(r.changes) do
				if not kind or c.kind == kind then table.insert(out, { rec = r, c = c }) end
			end
		end
	end
	return out
end

print("== scenario 1: baseline, APIs, registration ==")
local w = buildWorld()
local s = w.ns._selftest.getSession()
check(w.ns._selftest.isReady(), "baseline taken after settle delay")
check(s.baseline[907] and s.baseline[500] and not s.baseline[0], "baseline lists quests, skips header rows")
check(s.baseline[500].objectives[2].text_info == "count_only_no_name" and s.baseline[500].objectives[2].need == 1,
	"blank-name objective: text flagged, progress numbers still captured")
check(s.apis["C_QuestLog.GetQuestObjectives"] == "function", "API availability recorded")
check(s.registration.QUEST_LOG_UPDATE == "registered", "candidate events registered")
check(s.onupdate_install == "installed" and (s.onupdate_ticks or 0) > 0, "OnUpdate timer running and counted")

print("== scenario 2: state already updated when the event fires ==")
w.setObj(907, 1, 1)
w.fire("UNIT_QUEST_LOG_CHANGED", "player")
w.fire("QUEST_LOG_UPDATE")
local atEvent = changes(s, "event", "objective_changed")
check(#atEvent == 1 and atEvent[1].c.quest_id == 907 and atEvent[1].c.index == 1, "change attributed to quest 907 objective #1")
check(atEvent[1].c.from.have == 0 and atEvent[1].c.to.have == 1, "before/after values recorded")
check(atEvent[1].rec.trigger_event == "UNIT_QUEST_LOG_CHANGED", "first candidate event credited")
check(atEvent[1].rec.quest_snapshots[907] ~= nil, "affected quest's snapshot stored for ordering analysis")
w.run(2.5)

print("== scenario 3: state lags the event ==")
w.fire("QUEST_LOG_UPDATE")      -- event first
w.run(0.2)
w.setObj(907, 1, 2)             -- state updates ~0.2 s later
w.run(2.5)
local delayed = changes(s, "delayed", "objective_changed")
check(#delayed == 1 and delayed[1].rec.seconds_after_trigger == 0.25, "lagging state caught by the 0.25 s delayed read")
check(#changes(s, "poll", "objective_changed") == 0, "not double-reported by the poll")

print("== scenario 4: state changes with no candidate event ==")
w.run(3)
w.setObj(500, 1, 2)
w.run(1.5)
local polled = changes(s, "poll", "objective_changed")
check(#polled == 1 and polled[1].c.quest_id == 500, "silent change caught by the poll")
check(polled[1].rec.seconds_after_trigger and polled[1].rec.seconds_after_trigger > 2, "poll records time since last quest event")

print("== scenario 5: multiple objectives in one quest ==")
local q500 = changes(s, nil, "objective_changed")
local idxOk = true
for _, x in ipairs(q500) do if x.c.quest_id == 500 and x.c.index ~= 1 then idxOk = false end end
check(idxOk, "only objective #1 of quest 500 reported; #2 untouched")

print("== scenario 6: completion ==")
w.setObj(907, 1, 3)
w.complete[907] = true
w.fire("QUEST_LOG_UPDATE")
check(#changes(s, "event", "complete_changed") == 1, "IsComplete change recorded")
check(#changes(s, "event", "ready_changed") == 1, "ReadyForTurnIn change recorded")
local fin = changes(s, "event", "objective_changed")
check(fin[#fin].c.to.finished == true, "objective finished flag recorded")
w.run(2.5)

print("== scenario 7: unrelated log change and no-change events ==")
local before = #s.records
w.fire("QUEST_LOG_UPDATE")
local last = s.records[#s.records]
check(#s.records == before + 1 and last.immediate_change_count == 0, "no-change event recorded as such")
table.insert(w.log, { questID = 600, title = "New Quest", objectives = {} })
w.fire("QUEST_ACCEPTED", 600)
w.fire("QUEST_LOG_UPDATE")
check(#changes(s, nil, "quest_added") == 1 and #changes(s, nil, "objective_changed") == #fin + 2,
	"accepting a quest shows as quest_added, not as objective progress")
w.run(2.5)

print("== scenario 8: summary, snap, logout snapshot, read-only ==")
w.ns._selftest.slash("snap")
local sawSnap = false
for _, m in ipairs(w.chat) do if m:find("Two Things %(500%)") then sawSnap = true end end
check(sawSnap, "/fprobe89 snap prints objectives")
w.ns._selftest.slash("")
check(w.chat[#w.chat]:find("/reload"), "summary reminds to /reload")
w.fire("PLAYER_LOGOUT")
check(s.final_snapshot and s.final_snapshot[907], "final snapshot taken on logout/reload")
check(w.forbiddenCalls == 0, "no quest-state-changing function was ever called")

print("== scenario 9: legacy leaderboard API only ==")
w = buildWorld({ legacyOnly = true })
s = w.ns._selftest.getSession()
check(s.baseline[500].source == "GetQuestLogLeaderBoard", "falls back to legacy API")
check(s.baseline[500].objectives[1].have == 1 and s.baseline[500].objectives[1].need == 4, "counts parsed from legacy text")
w.setObj(500, 1, 3)
w.fire("QUEST_LOG_UPDATE")
check(#changes(s, "event", "objective_changed") == 1, "legacy path detects progress")

print("== scenario 10: QUEST_WATCH_UPDATE absent on the client ==")
w = buildWorld({ unknownEvents = { QUEST_WATCH_UPDATE = true } })
s = w.ns._selftest.getSession()
check(s.registration.QUEST_WATCH_UPDATE:find("^registration_error") ~= nil, "unknown event recorded, no crash")
w.setObj(907, 1, 1)
w.fire("QUEST_LOG_UPDATE")
check(#changes(s, "event", "objective_changed") == 1, "other candidates still work")

print("== scenario 10b: QUEST_WATCH_UPDATE argument resolved ==")
w = buildWorld()
s = w.ns._selftest.getSession()
w.setObj(907, 1, 1)
w.fire("QUEST_WATCH_UPDATE", 907)
local wev
for _, r in ipairs(s.records) do if r.event == "QUEST_WATCH_UPDATE" then wev = r end end
check(wev and wev.arg1_resolved and wev.arg1_resolved.title_if_quest_id == "Enraged Thunder Lizards", "QUEST_WATCH_UPDATE arg checked as a quest ID")
check(wev.immediate_change_count == 1, "its own immediate diff recorded")

print("== scenario 11: pre-baseline events are not diffed ==")
local ns2 = {}
_G.ForeverProbeM89DB = nil
local wp = buildWorld()
check(#changes(wp.ns._selftest.getSession(), nil, nil) == 0, "no changes invented at startup")

print("== scenario 12: existing SavedVariables appended ==")
w = buildWorld({ db = { sessions = { { probe_version = "earlier" } } } })
check(#ForeverProbeM89DB.sessions == 2 and ForeverProbeM89DB.sessions[1].probe_version == "earlier", "earlier session preserved")

print(string.format("\n%d passed, %d failed", passed, failed))
os.exit(failed == 0 and 0 or 1)
