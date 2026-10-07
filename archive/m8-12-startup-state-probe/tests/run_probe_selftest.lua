-- run_probe_selftest.lua -- lua5.1 run_probe_selftest.lua (from this tests/ directory)
--
-- Exercises ForeverProbeM812 against a fake client whose quest log is EMPTY until a chosen moment, as a real
-- client's might be early in startup. Proves the probe's own logic only: that every checkpoint is captured in
-- order, that absence is never classified as turn-in, that stability against the final checkpoint is marked,
-- and that missing APIs degrade to UNDETERMINED. It proves NOTHING about Forever.

local passed, failed = 0, 0
local function check(cond, name)
	if cond then passed = passed + 1; print("[OK]   " .. name)
	else failed = failed + 1; print("[FAIL] " .. name) end
end

local function buildWorld(opts)
	opts = opts or {}
	local w = { chat = {}, questCalls = 0, logReady = false }
	w.log = {
		{ isHeader = true, title = "Silverpine Forest" },
		{ questID = 1013, title = "The Book of Ur", objectives = { { text = "0/1 The Book of Ur", type = "item", finished = false, numFulfilled = 0, numRequired = 1 } }, complete = false },
		{ questID = 447, title = "A Recipe For Death", objectives = { { text = "6/6 Grizzled Bear Heart", type = "item", finished = true, numFulfilled = 6, numRequired = 6 } }, complete = true },
	}
	w.completed = { [92421] = true, [92422] = true, [92401] = true, [95216] = true, [97288] = true, [97291] = true, [95204] = true, [428] = true }
	-- Real client order (v0.2): the addon's files run with the SavedVariable still unset; WoW then restores the
	-- saved table from disk, replacing whatever global the file created; then ADDON_LOADED fires.
	_G.ForeverProbeM812DB = nil
	_G.DEFAULT_CHAT_FRAME = { AddMessage = function(_, m) table.insert(w.chat, m) end }
	local clock = 100
	_G.GetTime = function() return clock end
	w.advance = function(dt) clock = clock + dt end
	_G.GetBuildInfo = function() return "1.60.1", "70124", "Sep 29 2026", 16001 end
	local function entry(id) if not w.logReady then return nil end for _, e in ipairs(w.log) do if e.questID == id then return e end end end
	_G.C_QuestLog = {
		GetNumQuestLogEntries = function() return w.logReady and #w.log or 0 end,
		GetInfo = function(i) local e = w.logReady and w.log[i]; return e and { questID = e.questID, title = e.title, isHeader = e.isHeader } end,
		GetQuestObjectives = function(id) local e = entry(id); if not e then return nil end
			local out = {} for i, o in ipairs(e.objectives) do out[i] = { text = o.text, type = o.type, finished = o.finished, numFulfilled = o.numFulfilled, numRequired = o.numRequired } end return out end,
		IsComplete = function(id) local e = entry(id); return e and e.complete or false end,
		ReadyForTurnIn = function(id) local e = entry(id); return e and e.complete or false end,
		IsOnQuest = function(id) return entry(id) ~= nil end,
		GetTitleForQuestID = function(id) local e = entry(id); return e and e.title end,
		AbandonQuest = function() w.questCalls = w.questCalls + 1 end,
	}
	if not opts.noFlagAPI then
		C_QuestLog.IsQuestFlaggedCompleted = function(id)
			if opts.flagsLate and not w.logReady then return false end
			return w.completed[id] == true
		end
	end
	for _, n in ipairs({ "AcceptQuest", "AbandonQuest", "CompleteQuest", "GetQuestReward" }) do
		_G[n] = function() w.questCalls = w.questCalls + 1 end
	end
	_G.SlashCmdList = {}
	_G.CreateFrame = function()
		local f = { registered = {}, scripts = {} }
		function f:RegisterEvent(ev) self.registered[ev] = true end
		function f:SetScript(n, fn) self.scripts[n] = fn end
		w.frame = f
		return f
	end
	w.fire = function(ev, ...) if w.frame.registered[ev] then w.frame.scripts.OnEvent(w.frame, ev, ...) end end
	w.run = function(seconds)
		for _ = 1, math.floor(seconds / 0.05 + 0.5) do w.advance(0.05); w.frame.scripts.OnUpdate(w.frame, 0.05) end
	end
	local ns = {}
	assert(loadfile("../addon/ForeverProbeM812/ForeverProbeM812.lua"))("ForeverProbeM812", ns)
	w.ns = ns
	w.fileLoadTable = _G.ForeverProbeM812DB
	if opts.db then _G.ForeverProbeM812DB = opts.db end   -- WoW restores SavedVariables here
	-- startup sequence; the log becomes readable just before the first QUEST_LOG_UPDATE
	w.fire("ADDON_LOADED", "ForeverProbeM812")
	w.fire("PLAYER_LOGIN")
	w.fire("PLAYER_ENTERING_WORLD", opts.initial ~= false, opts.initial == false)
	w.advance(0.3)
	if not opts.neverReady then w.logReady = true end
	w.fire("QUEST_LOG_UPDATE")
	w.run(0.2); w.fire("QUEST_LOG_UPDATE")
	w.run(4)
	return w
end

local function cp(s, name) for _, c in ipairs(s.checkpoints) do if c.name == name then return c end end end

print("== scenario 1: login; log readable from the first QUEST_LOG_UPDATE ==")
local w = buildWorld()
local s = w.ns._selftest.getSession()
local names = {}
for _, c in ipairs(s.checkpoints) do table.insert(names, c.name) end
check(table.concat(names, ",") == "file_load,ADDON_LOADED,PLAYER_LOGIN,PLAYER_ENTERING_WORLD,first_QUEST_LOG_UPDATE,first_QLU+0.5s,first_QLU+2.0s,PLAYER_ENTERING_WORLD+3.0s",
	"all eight checkpoints captured in order")
check(s.is_initial_login == true and s.is_reloading_ui == false, "PLAYER_ENTERING_WORLD login/reload flags recorded")
check(cp(s, "PLAYER_LOGIN").log.entries == 0 and cp(s, "first_QUEST_LOG_UPDATE").log.entries == 3, "empty early log vs populated later log recorded")
check(cp(s, "PLAYER_LOGIN").same_as_last == false and cp(s, "first_QLU+0.5s").same_as_last == true, "stability against the final checkpoint marked")
local fin = cp(s, "PLAYER_ENTERING_WORLD+3.0s")
check(fin.log.quests[1013].state == "IN_LOG_INCOMPLETE" and fin.log.quests[447].state == "IN_LOG_COMPLETE", "in-log quests classified")
check(fin.log.quests[447].objectives[1].finished == true and fin.log.quests[447].objectives[1].have == 6, "objective state captured")
check(fin.reference[92421].state == "FLAGGED_COMPLETED" and fin.reference[783].state == "ABSENT_NOT_FLAGGED", "flagged vs absent-not-flagged")
check(#s.qlu_log == 2 and s.qlu_log[1].entries == 3, "QUEST_LOG_UPDATE timeline recorded")
w.ns._selftest.slash("")
local saw = false
for _, m in ipairs(w.chat) do if m:find("PLAYER_LOGIN: log entries 0") and m:find("differs from final") then saw = true end end
check(saw, "summary shows each checkpoint and its stability")

print("== scenario 2: absence is never read as turn-in ==")
local early = cp(s, "PLAYER_LOGIN")
check(early.reference[783].state == "ABSENT_NOT_FLAGGED", "never-completed control: absent and not flagged")
for _, r in ipairs(w.ns._selftest.reference) do
	local st = fin.reference[r.id].state
	check(st ~= "TURNED_IN", "no TURNED_IN classification exists for " .. r.id)
end

print("== scenario 3: flags only correct after the log is ready ==")
w = buildWorld({ flagsLate = true })
s = w.ns._selftest.getSession()
check(cp(s, "PLAYER_LOGIN").reference[92421].flagged == false and cp(s, "first_QLU+2.0s").reference[92421].flagged == true,
	"a flag that changes during startup is visible per checkpoint")

print("== scenario 4: reload; flag API absent; log never ready ==")
w = buildWorld({ initial = false, noFlagAPI = true, neverReady = true })
s = w.ns._selftest.getSession()
check(s.is_reloading_ui == true, "reload flag recorded")
fin = cp(s, "PLAYER_ENTERING_WORLD+3.0s")
check(fin.apis["C_QuestLog.IsQuestFlaggedCompleted"] == "absent", "absent flag API recorded")
check(fin.reference[92421].state == "UNDETERMINED" and fin.reference[783].state == "UNDETERMINED", "without the flag API, absent quests are UNDETERMINED")
check(fin.log.entries == 0, "empty log recorded, nothing invented")

print("== scenario 5: manual inspection and snapshot ==")
w = buildWorld()
s = w.ns._selftest.getSession()
w.ns._selftest.slash("q 447")
local ins = s.inspections[1]
check(ins and ins.quest_id == 447 and ins.in_log and ins.entry.complete == true, "q <id> inspects an in-log quest")
w.ns._selftest.slash("q 783")
check(s.inspections[2].in_log == false and s.inspections[2].flagged == false, "q <id> inspects an absent quest")
local before = #s.checkpoints
w.ns._selftest.slash("now")
check(#s.checkpoints == before + 1 and s.checkpoints[#s.checkpoints].name == "manual", "manual snapshot")
check(w.questCalls == 0, "no quest-changing function called")

print("== scenario 6: SavedVariables restored after file load (the v0.1 bug) ==")
local restored = { sessions = { { probe_version = "earlier" } } }
w = buildWorld({ db = restored })
s = w.ns._selftest.getSession()
check(ForeverProbeM812DB == restored, "the restored table is the one that will be saved")
check(#restored.sessions == 2 and restored.sessions[1].probe_version == "earlier" and restored.sessions[2] == s,
	"new session attached to the restored table, earlier session kept")
check(s.sv.present_at_file_load == false and s.sv.replaced_before_addon_loaded == true and s.sv.sessions_before_this == 1,
	"SavedVariables timing recorded as evidence")
check(s.checkpoints[1].name == "file_load", "file_load checkpoint still captured before the restore")

print("== scenario 7: first install, nothing on disk ==")
w = buildWorld()
s = w.ns._selftest.getSession()
check(ForeverProbeM812DB and ForeverProbeM812DB.sessions[1] == s, "session saved when no earlier file exists")
check(s.sv.replaced_before_addon_loaded == false and s.sv.sessions_before_this == 0, "no replacement recorded")

print(string.format("\n%d passed, %d failed", passed, failed))
os.exit(failed == 0 and 0 or 1)
