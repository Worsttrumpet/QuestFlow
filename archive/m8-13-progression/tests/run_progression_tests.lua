-- run_progression_tests.lua <addonDir>     (lua5.1)
--
-- Stub-environment tests for M8.13 progression: evaluators (pure), the controller (driven by real event
-- dispatch through the addon's own frames), and the UI integration (driven through the real buttons).
-- Startup order mirrors what M8.12 verified on Forever: addon files run, THEN SavedVariables are restored,
-- THEN ADDON_LOADED, THEN PLAYER_LOGIN. Proves the addon's logic only, not Forever behaviour.

local dir = arg[1] or "../ForeverQuestGuide"
local passed, failed = 0, 0
local function check(cond, name)
	if cond then passed = passed + 1; print("[OK]   " .. name)
	else failed = failed + 1; print("[FAIL] " .. name) end
end
local function section(t) print("== " .. t .. " ==") end

-- ---------------------------------------------------------------- stub client

local W  -- current world

local function widget(kind)
	local w = { __kind = kind, __shown = true, __text = "", __scripts = {}, __events = {}, __alpha = 1 }
	return setmetatable(w, { __index = function(t, k)
		if k == "IsShown" then return function(self) return self.__shown end end
		if k == "GetText" then return function(self) return self.__text end end
		if k == "GetStringHeight" then return function() return 12 end end
		if k == "Show" then return function(self) self.__shown = true end end
		if k == "Hide" then return function(self) self.__shown = false end end
		if k == "SetText" then return function(self, v) self.__text = v or "" end end
		if k == "SetAlpha" then return function(self, a) self.__alpha = a end end
		if k == "SetScript" then return function(self, n, fn) self.__scripts[n] = fn end end
		if k == "RegisterEvent" then return function(self, ev) self.__events[ev] = true end end
		if k == "UnregisterEvent" then return function(self, ev) self.__events[ev] = nil end end
		if k == "CreateTexture" then return function() return widget("Texture") end end
		if k == "CreateFontString" then return function() return widget("FontString") end end
		return function() end
	end })
end

local function V(x, y) return { x = x, y = y, GetXY = function(self) return self.x, self.y end } end
-- maps: continent + world origin/size in yards
local MAPS = { [1413] = { c = 1, ox = 0, oy = 0, w = 4000, h = 6000 }, [1411] = { c = 1, ox = 4000, oy = 0, w = 3000, h = 3000 },
	[1421] = { c = 0, ox = 0, oy = 0, w = 3000, h = 2000 } }

local function newWorld(opts)
	opts = opts or {}
	W = { frames = {}, chat = {}, quest = {}, flagged = {}, player = { map = 1413, x = 0.5, y = 0.5 }, questCalls = 0 }
	_G.CreateFrame = function(kind) local f = widget(kind); table.insert(W.frames, f); return f end
	_G.UIParent, _G.Minimap, _G.WorldMapFrame = widget("UIParent"), widget("Minimap"), widget("WorldMapFrame")
	_G.GameFontNormal, _G.GameTooltip = {}, widget("GameTooltip")
	_G.DEFAULT_CHAT_FRAME = { AddMessage = function(_, m) table.insert(W.chat, m) end }
	_G.GetBuildInfo = function() return "1.60.1", "70124", "Sep 29 2026", 16001 end
	_G.GetTime = function() return 100 end
	_G.SlashCmdList = {}
	_G.ToggleWorldMap = function() end
	_G.CreateVector2D = V
	_G.C_QuestLog = {
		IsOnQuest = function(q) return W.quest[q] ~= nil end,
		IsComplete = function(q) return W.quest[q] == "complete" end,
		ReadyForTurnIn = function(q) return W.quest[q] == "complete" end,
		IsQuestFlaggedCompleted = function(q) return W.flagged[q] == true end,
	}
	_G.C_Map = {
		GetBestMapForUnit = function() return W.player.map end,
		GetPlayerMapPosition = function(m) if W.noPosition then return nil end return V(W.player.x, W.player.y) end,
		GetWorldPosFromMapPos = function(m, v) local d = MAPS[m]; if not d then return nil end
			return d.c, V(d.ox + v.x * d.w, d.oy + v.y * d.h) end,
		SetUserWaypoint = function(p) W.pinned = p.uiMapID end,
		CanSetUserWaypointOnMap = function() return true end,
		ClearUserWaypoint = function() end,
	}
	_G.C_SuperTrack = { SetSuperTrackedUserWaypoint = function() end }
	_G.UiMapPoint = { CreateFromCoordinates = function(m, x, y) return { uiMapID = m, position = V(x, y) } end }
	for _, n in ipairs({ "AcceptQuest", "AbandonQuest", "CompleteQuest", "GetQuestReward" }) do
		_G[n] = function() W.questCalls = W.questCalls + 1 end
	end
	C_QuestLog.AbandonQuest = function() W.questCalls = W.questCalls + 1 end
	_G.ForeverQuestGuideDB = nil  -- SavedVariables are NOT present while the files run (M8.12)
	W.ns = {}
	local toc = io.open(dir .. "/ForeverQuestGuide.toc"):read("*a")
	for line in toc:gmatch("[^\r\n]+") do
		if line:match("%.lua$") then assert(loadfile(dir .. "/" .. line))("ForeverQuestGuide", W.ns) end
	end
	W.fire = function(ev, ...)
		for _, f in ipairs(W.frames) do
			if f.__events[ev] and f.__scripts.OnEvent then f.__scripts.OnEvent(f, ev, ...) end
		end
	end
	W.P, W.T = W.ns.Progression, W.ns._progressionTest
	if opts.saved ~= nil then _G.ForeverQuestGuideDB = opts.saved end  -- WoW restores SavedVariables here
	if not opts.noAddonLoaded then W.fire("ADDON_LOADED", "ForeverQuestGuide") end
	if opts.login then W.fire("PLAYER_LOGIN") end
	return W
end

local function state() return W.P.GetStatus().state end
local function index() local _, i = W.P.GetPosition(); return i end

-- ---------------------------------------------------------------- evaluators (pure)

newWorld()
local E = W.ns.ProgressionEval
local function fakeReader(t)
	t = t or {}
	return {
		isOnQuest = function(q) return t.onQuest end, isComplete = function(q) return t.complete end,
		readyForTurnIn = function(q) return t.ready end, isFlaggedCompleted = function(q) return t.flagged end,
		playerWorldPos = function() if t.player then return unpack(t.player) end end,
		destinationWorldPos = function() if t.dest then return unpack(t.dest) end end,
	}
end

section("ACCEPT")
local acc = { kind = "ACCEPT", quest_id = 907 }
check(E.Evaluate(acc, { type = "QUEST_ACCEPTED", questID = 907 }, fakeReader()).state == "SATISFIED", "QUEST_ACCEPTED with the step's quest ID satisfies")
check(E.Evaluate(acc, { type = "QUEST_ACCEPTED", questID = 1 }, fakeReader()).state == "WAITING", "QUEST_ACCEPTED for another quest does not")
check(E.Evaluate(acc, nil, fakeReader({ onQuest = true })).state == "SATISFIED", "quest already in the log satisfies (reconciliation)")
check(E.Evaluate(acc, nil, fakeReader({ flagged = true })).state == "SATISFIED", "quest already completed satisfies")
check(E.Evaluate({ kind = "ACCEPT" }, nil, fakeReader()).state == "UNDETECTABLE", "no quest ID is undetectable")

section("TURN_IN")
local ti = { kind = "TURN_IN", quest_id = 907 }
check(E.Evaluate(ti, { type = "QUEST_TURNED_IN", questID = 907 }, fakeReader()).state == "SATISFIED", "QUEST_TURNED_IN with the step's quest ID satisfies")
check(E.Evaluate(ti, nil, fakeReader({ flagged = true })).state == "SATISFIED", "flagged completed satisfies (reconciliation)")
check(E.Evaluate(ti, { type = "QUEST_REMOVED", questID = 907 }, fakeReader({ onQuest = false })).state == "WAITING", "QUEST_REMOVED / absence never counts as a turn-in")

section("OBJECTIVE (quest-level completion)")
local ob = { kind = "OBJECTIVE", quest_id = 907, objective_index = 1 }
check(E.Evaluate(ob, nil, fakeReader({ onQuest = true, complete = true })).state == "SATISFIED", "in log and complete satisfies")
check(E.Evaluate(ob, nil, fakeReader({ onQuest = true, ready = true })).state == "SATISFIED", "ready for turn-in satisfies")
check(E.Evaluate(ob, nil, fakeReader({ onQuest = true })).state == "WAITING", "in log, in progress waits")
check(E.Evaluate(ob, nil, fakeReader({ onQuest = false })).state == "WAITING", "not in log waits")
check(E.Evaluate(ob, nil, fakeReader({ flagged = true })).state == "SATISFIED", "already turned in satisfies")
check(E.Evaluate({ kind = "OBJECTIVE", quest_id = 907, objective_index = 99 }, nil, fakeReader({ onQuest = true, complete = true })).state == "SATISFIED",
	"objective_index is not used (quest-level only)")

section("TRAVEL (addon-computed distance, real read layer)")
local R = E.DefaultReader
local tr = { kind = "TRAVEL", destination = { kind = "OBSERVED_PLAYER_POSITION", ui_map_id = 1413, x = 0.5, y = 0.5 } }
W.player = { map = 1413, x = 0.5, y = 0.5 + 10 / 6000 }
local r1 = E.Evaluate(tr, nil, R)
check(r1.state == "SATISFIED" and math.abs(r1.distance - 10) < 0.01, "same map, 10 yd away: satisfied")
W.player = { map = 1413, x = 0.5, y = 0.5 + 100 / 6000 }
local r2 = E.Evaluate(tr, nil, R)
check(r2.state == "WAITING" and math.abs(r2.distance - 100) < 0.01, "same map, 100 yd away: waiting with distance")
W.player = { map = 1411, x = 0.0, y = 0.5 }
local r3 = E.Evaluate({ kind = "TRAVEL", destination = { ui_map_id = 1413, x = 1.0, y = 0.25 } }, nil, R)
check(r3.state == "SATISFIED" and r3.distance < 0.01, "same continent, different map: distance computed across maps")
W.player = { map = 1411, x = 0.5, y = 0.5 }
local r4 = E.Evaluate(tr, nil, R)
check(r4.state == "WAITING" and math.abs(r4.distance - math.sqrt(3500 ^ 2 + 1500 ^ 2)) < 0.5, "same continent, far: waiting")
check(E.Evaluate({ kind = "TRAVEL" }, nil, R).state == "UNDETECTABLE", "missing destination: undetectable")
W.player = { map = 1421, x = 0.5, y = 0.5 }
check(E.Evaluate(tr, nil, R).reason:find("another continent") ~= nil, "cross-continent: undetectable")
W.noPosition = true
check(E.Evaluate(tr, nil, R).state == "UNDETECTABLE", "player position unavailable: undetectable")
W.noPosition = nil
check(E.Evaluate({ kind = "WHATEVER" }, nil, R).state == "UNDETECTABLE", "unknown step kind: undetectable")

-- ---------------------------------------------------------------- controller

section("before ADDON_LOADED")
newWorld({ noAddonLoaded = true })
check(W.P.GetPosition() == "thunder-lizards-test-route" and index() == 1, "controller has a sane position before ADDON_LOADED")
check(state() == "NOT_READY", "and does not evaluate")

section("startup: no saved state")
newWorld()
check(W.P.GetPosition() == "thunder-lizards-test-route" and index() == 1, "no saved progress: first route, step 1")
check(state() == "NOT_READY", "nothing evaluated before PLAYER_LOGIN")
W.quest[907] = "active"
W.fire("QUEST_ACCEPTED", 907)
check(state() == "NOT_READY", "a quest event before PLAYER_LOGIN is ignored")
check(ForeverQuestGuideDB.progress and ForeverQuestGuideDB.progress.stepID == "s1", "position persisted as route + step ID")
check(ForeverQuestGuideDB.theme == "classic", "preference defaults applied to the restored table at ADDON_LOADED")
W.fire("PLAYER_LOGIN")
check(state() == "SATISFIED" and index() == 1, "PLAYER_LOGIN reconciles: quest already in log -> step 1 complete, not advanced")

section("detection, latching, manual confirmation")
newWorld({ login = true })
check(state() == "WAITING", "step 1 ACCEPT waiting")
W.fire("QUEST_ACCEPTED", 12345)
check(state() == "WAITING", "another quest's accept is ignored")
W.quest[907] = "active"
W.fire("QUEST_ACCEPTED", 907)
check(state() == "SATISFIED" and index() == 1, "accept detected and latched; no automatic advance")
local sawMsg = false
for _, m in ipairs(W.chat) do if m:find("Step 1 complete") then sawMsg = true end end
check(sawMsg, "chat tells the player the step is complete")
W.quest[907] = nil
W.fire("QUEST_LOG_UPDATE")
check(state() == "SATISFIED", "latched: a later state change does not un-satisfy the step")
check(W.P.Next() and index() == 2 and W.T.getHistory()[1].kind == "confirm", "confirmation advances exactly one step")
check(state() == "UNDETECTABLE" and W.P.GetStatus().reason:find("no destination"), "step 2 TRAVEL without destination: undetectable, not complete")
check(W.P.Next() and index() == 3 and W.T.getHistory()[2].kind == "manual", "manual NEXT advances exactly one step")

section("OBJECTIVE via UNIT_QUEST_LOG_CHANGED and the turn-in reset trap")
W.quest[907] = "active"
W.fire("QUEST_LOG_UPDATE")
check(state() == "WAITING", "objective in progress")
W.quest[907] = "complete"
W.fire("UNIT_QUEST_LOG_CHANGED", "targettarget")
check(state() == "WAITING", "UNIT_QUEST_LOG_CHANGED for another unit is ignored")
W.fire("UNIT_QUEST_LOG_CHANGED", "player")
check(state() == "SATISFIED", "UNIT_QUEST_LOG_CHANGED(player) + complete quest: satisfied")
W.quest[907] = "active"  -- M8.9 trap: quest briefly reads un-complete at turn-in
W.fire("UNIT_QUEST_LOG_CHANGED", "player")
check(state() == "SATISFIED", "turn-in reset cannot undo a satisfied step")

section("TURN_IN, pause, reset")
W.P.Next()
check(index() == 4 and state() == "WAITING", "step 4 TURN_IN waiting")
W.P.SetPaused(true)
W.quest[907] = nil; W.flagged[907] = true
W.fire("QUEST_TURNED_IN", 907, 5300, 0)
check(state() == "PAUSED" and not W.P.GetStatus().satisfied, "paused: detection ignored")
check(ForeverQuestGuideDB.progress.paused == true, "pause persisted")
W.P.SetPaused(false)
check(state() == "SATISFIED", "resume re-evaluates from game state (turned in)")
W.flagged[907] = nil
check(W.P.ResetStep() and state() == "WAITING", "reset clears the latch and re-evaluates")
check(W.chat[#W.chat]:find("Step 4 reset and re%-checked: quest not turned in yet"), "reset reports its result in chat")
W.fire("QUEST_TURNED_IN", 907, 5300, 0)
check(state() == "SATISFIED", "QUEST_TURNED_IN(907) satisfies the TURN_IN step")

section("skip, undo, route completion")
W.P.Next()
check(index() == 5, "on step 5")
check(W.P.Skip() and W.P.GetStatus().complete and state() == "ROUTE_COMPLETE", "skip on the last step completes the route")
check(ForeverQuestGuideDB.progress.skipped["thunder-lizards-test-route"].s5 == true, "skip persisted")
check(not W.P.Next(), "NEXT after route completion does nothing")
check(W.P.Undo() and not W.P.GetStatus().complete and index() == 5, "undo reverses the skip")
check(not ForeverQuestGuideDB.progress.skipped["thunder-lizards-test-route"].s5, "undo clears the skip mark")
check(W.P.Next() and W.P.GetStatus().complete, "NEXT on the last step finishes the route")
check(W.P.Previous() and not W.P.GetStatus().complete and index() == 5, "previous from completion returns to the last step")
check(not W.P.Undo() and not W.P.GetStatus().canUndo, "previous clears undo history (no stale undo)")
check(W.P.Next() and W.P.Undo() and not W.P.GetStatus().complete and index() == 5, "undo reverses the advance just made")
check(W.P.Previous() and index() == 4 and W.P.Previous() and index() == 3, "previous moves back one step at a time")
local stored = ForeverQuestGuideDB.progress
check(stored.latched == nil and stored.current == nil, "detection results and latches are never persisted")

section("startup: valid and stale saved state")
newWorld({ saved = { progress = { routeID = "thunder-lizards-test-route", stepID = "s4" } }, login = false })
check(index() == 4 and state() == "NOT_READY", "saved step restored at ADDON_LOADED, not evaluated yet")
W.flagged[907] = true
W.fire("PLAYER_LOGIN")
check(state() == "SATISFIED" and index() == 4, "reconciled at PLAYER_LOGIN: turned in before load -> complete, not advanced")
newWorld({ saved = { progress = { routeID = "thunder-lizards-test-route", stepID = "s9" } }, login = true })
check(index() == 1, "saved step missing from the route: falls back to step 1")
newWorld({ saved = { progress = { routeID = "gone-route", stepID = "s3" } }, login = true })
check(W.P.GetPosition() == "thunder-lizards-test-route" and index() == 1, "saved route missing: first route, step 1")
newWorld({ saved = { theme = "dark" }, login = true })
check(ForeverQuestGuideDB.theme == "dark" and ForeverQuestGuideDB.uiMode == "detailed", "restored preferences kept; only missing keys defaulted")

section("TRAVEL step with a destination (ticks)")
newWorld({ login = true })
W.ns.Routes["thunder-lizards-test-route"].steps.s2.destination = { ui_map_id = 1413, x = 0.5, y = 0.5 }
W.player = { map = 1413, x = 0.5, y = 0.6 }
W.P.Next()
W.T.tick(0.6)
check(state() == "WAITING", "far from destination: waiting")
W.player = { map = 1413, x = 0.5, y = 0.5 + 5 / 6000 }
W.T.tick(0.6)
check(state() == "SATISFIED" and index() == 2, "arrival detected by position tick; not advanced")
W.ns.Routes["thunder-lizards-test-route"].steps.s2.destination = nil

section("UI integration")
newWorld({ login = true })
W.ns.UI.Toggle()
W.ns._selftest.setActiveTab("ROUTE")
local pw = W.ns._selftest.getProgressWidgets()
local rb = W.ns._selftest.getRouteButtons()
check(pw.status:GetText():find("in progress"), "status line shows the step state")
check(rb.next.text:GetText() == "NEXT ->", "NEXT label while waiting")
W.quest[907] = "active"
W.fire("QUEST_ACCEPTED", 907)
check(pw.status:GetText():find("STEP COMPLETE"), "status line shows STEP COMPLETE (re-rendered on detection)")
check(rb.next.text:GetText() == "CONFIRM ->", "NEXT becomes CONFIRM")
rb.next.__scripts.OnClick()
check(index() == 2, "one click on CONFIRM advances exactly one step")
check(pw.buttons.undo.__alpha == 1, "Undo enabled after an advance")
pw.buttons.undo.__scripts.OnClick()
check(index() == 1, "Undo button works")
pw.buttons.pause.__scripts.OnClick()
check(W.P.IsPaused() and pw.buttons.pause.text:GetText() == "Resume", "Pause button toggles and relabels")
pw.buttons.pause.__scripts.OnClick()
pw.buttons.skip.__scripts.OnClick()
check(index() == 2, "Skip button advances")
rb.prev.__scripts.OnClick()
check(index() == 1, "Previous button still works")
for _ = 1, 3 do rb.next.__scripts.OnClick() end
rb.map.__scripts.OnClick()
check(W.pinned == 1413, "route Show on Map still pins step 4's destination")
local f = W.ns._selftest.getFrame()
for _, b in ipairs(W.ns._selftest.getListButtons()) do if b.questID then b.__scripts.OnClick(b); break end end
W.ns._selftest.setActiveTab("QUESTS")
f.questMapBtn.__scripts.OnClick()
check(W.pinned == 1411, "quest Show on Map still works")
SlashCmdList.FOREVERQUESTGUIDE("progress status")
check(W.chat[#W.chat]:find("progress: route thunder%-lizards%-test%-route"), "/fguide progress status reports the position")
check(W.questCalls == 0, "no quest-changing function was ever called")

print(string.format("\n%d passed, %d failed", passed, failed))
os.exit(failed == 0 and 0 or 1)
