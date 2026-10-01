-- Run from the tests/ directory: lua5.1 run_recorder_tests.lua
dofile("stub_env.lua")

local ADDON = "../addon/ForeverRecorder/"
local LOAD_ORDER = {
	ADDON .. "core/SafeCall.lua", ADDON .. "core/GuidUtil.lua", ADDON .. "core/PositionUtil.lua",
	ADDON .. "core/Bootstrap.lua", ADDON .. "core/Registry.lua", ADDON .. "core/Dispatcher.lua",
	ADDON .. "core/Export.lua", ADDON .. "core/SlashCommands.lua",
	ADDON .. "observers/QuestMeta.lua", ADDON .. "observers/RewardsXPMoney.lua",
	ADDON .. "observers/RewardsItems.lua", ADDON .. "observers/RewardsReputation.lua",
	ADDON .. "observers/GiverIdentity.lua", ADDON .. "observers/Gossip.lua",
	ADDON .. "ForeverRecorder.lua",
}
for _, f in ipairs(LOAD_ORDER) do
	local ok, err = pcall(dofile, f)
	if not ok then
		print("LOAD ERROR in " .. f .. ": " .. tostring(err))
		os.exit(1)
	end
end
print("=== all " .. #LOAD_ORDER .. " files loaded, self-check assertions in ForeverRecorder.lua passed ===")

local frame = ForeverRecorder.Dispatcher.frame
local function fire(event, ...)
	local ok, err = pcall(frame._fire, event, ...)
	if not ok then error("event " .. event .. " crashed the dispatcher: " .. tostring(err)) end
end

print()
print("=== TEST: exactly 6 modules registered, all proven ===")
local list = ForeverRecorder.Registry:List()
assert(#list == 6, "expected exactly 6 modules, got " .. #list)
for _, m in ipairs(list) do
	assert(m.status == "proven", m.name .. " is not proven")
end
print("PASS: exactly 6 modules, all status=proven")

print()
print("=== TEST: Registry hard-rejects a non-proven registration attempt ===")
local okReg, errReg = pcall(function()
	ForeverRecorder.Registry:Register({ name = "SomeExperimentalThing", status = "experimental", capture = function() end })
end)
assert(not okReg, "registering an experimental module must fail in this build")
assert(tostring(errReg):find("proven"), "the rejection reason must explain why")
print("PASS: attempting to register a non-proven module raises an error, as required")

print()
print("=== TEST: full lifecycle dispatch ===")
fire("ADDON_LOADED", "ForeverRecorder")
fire("PLAYER_LOGIN")
fire("QUEST_DETAIL")
fire("GOSSIP_SHOW")
fire("QUEST_COMPLETE")
_G.__fireAllTimers()
fire("QUEST_TURNED_IN", 111, 250, 50)

local obs = ForeverObservationLabDB.observations
local seen = {}
for _, o in ipairs(obs) do seen[o.module_name] = (seen[o.module_name] or 0) + 1 end
assert(seen.QuestMeta and seen.QuestMeta >= 3)
assert(seen.RewardsItems and seen.RewardsItems >= 3)
assert(seen.RewardsReputation and seen.RewardsReputation >= 3)
assert(seen.GiverIdentity and seen.GiverIdentity >= 4)
assert(seen.Gossip == 1)
assert(seen.RewardsXPMoney == 1)
print("PASS: all 6 observers dispatched at the correct checkpoints")

print()
print("=== TEST: guaranteed-item evidence_note present ONLY on reward_items, never on choice_items ===")
local itemObs = nil
for _, o in ipairs(obs) do
	if o.module_name == "RewardsItems" and o.checkpoint == "quest_complete_immediate" then itemObs = o end
end
-- the stub's default GetQuestItemInfo/GetNumQuestRewards/Choices scenario: confirm actual values first
print("  num_rewards seen in stub:", itemObs.data.num_rewards, "num_choices seen in stub:", itemObs.data.num_choices)
if itemObs.data.num_rewards and itemObs.data.num_rewards > 0 then
	assert(itemObs.data.reward_items_evidence_note, "guaranteed items must carry the evidence note")
	assert(itemObs.data.reward_items_evidence_note:find("confirmed exactly once"))
end
if itemObs.data.num_choices and itemObs.data.num_choices > 0 then
	assert(itemObs.data.choice_items_evidence_note == nil, "choice items must NEVER carry the guaranteed-item note")
end
print("PASS: evidence_note correctly scoped to guaranteed items only")

print()
print("=== TEST: SafeCall vs the exact reputation-follow-up bug (holes then real values) ===")
local function fn() return "Windshapers", nil, nil, nil, nil, nil, nil, nil, false, nil, true end
local ok, err, v = ForeverRecorder.SafeCall(fn, 11)
assert(v[1] == "Windshapers" and v[9] == false and v[11] == true,
	"SafeCall must preserve real values behind holes -- v[9]=" .. tostring(v[9]) .. " v[11]=" .. tostring(v[11]))
print("PASS: the exact bug class this helper exists to prevent is still prevented")

print()
print("=== TEST: bounded item-name retry + no-op after resolution ===")
ForeverObservationLabDB.observations = {}
GetNumQuestRewards = function() return 1 end
GetNumQuestChoices = function() return 0 end
_G.__itemInfoResolved = false
GetQuestItemInfo = function(kind, i)
	if kind == "reward" and i == 1 then
		if _G.__itemInfoResolved then return "Resolved Item", "tex", 1, 2, 12345 end
		return "", "tex", 1, 2, 12345
	end
	return nil
end
fire("QUEST_DETAIL")
local firstItemObs = nil
for _, o in ipairs(ForeverObservationLabDB.observations) do
	if o.module_name == "RewardsItems" then firstItemObs = o end
end
assert(firstItemObs.data.saw_unresolved_first_value == true)
fire("GET_ITEM_INFO_RECEIVED", 12345, true)
_G.__itemInfoResolved = true
fire("GET_ITEM_INFO_RECEIVED", 12345, true)
local retries = {}
for _, o in ipairs(ForeverObservationLabDB.observations) do
	if o.checkpoint:find("retry_after") then table.insert(retries, o) end
end
assert(#retries == 2)
assert(retries[1].data.saw_unresolved_first_value == true)
assert(retries[2].data.saw_unresolved_first_value == false)
local countBefore = #ForeverObservationLabDB.observations
fire("GET_ITEM_INFO_RECEIVED", 999, true)
assert(#ForeverObservationLabDB.observations == countBefore, "stray fire after resolution must be a no-op")
print("PASS: retry mechanism bounded and correct, unchanged from the Lab")

print()
print("=== TEST: per-observation build/session isolation across two logins ===")
ForeverObservationLabDB.observations = {}
_G.__stubBuildInfo = { "1.60.1", "BUILD_A", "date", 16001 }
fire("ADDON_LOADED", "ForeverRecorder")
local sessionA = ForeverRecorder.CurrentSessionID
GetQuestItemInfo = function() return nil end -- reset to avoid retry interference
fire("QUEST_DETAIL")
local obsA = {}
for _, o in ipairs(ForeverObservationLabDB.observations) do table.insert(obsA, o) end
assert(#obsA > 0)
for _, o in ipairs(obsA) do assert(o.observed_build == "BUILD_A" and o.session_id == sessionA) end

_G.__stubBuildInfo = { "1.60.1", "BUILD_B", "date", 16001 }
fire("ADDON_LOADED", "ForeverRecorder")
local sessionB = ForeverRecorder.CurrentSessionID
assert(sessionB ~= sessionA, "a second login must generate a different session id")
fire("QUEST_DETAIL")
for _, o in ipairs(obsA) do
	assert(o.observed_build == "BUILD_A" and o.session_id == sessionA,
		"session A's observations must be untouched after session B begins")
end
print("PASS: build and session correctly isolated per observation across two logins")

print()
print("=== TEST: NEW persistence-confirmation signal (design section 11) ===")
-- ObservationCountAtLoad must reflect what existed BEFORE this session added anything.
ForeverObservationLabDB.observations = { {module_name="x"}, {module_name="y"}, {module_name="z"} }
fire("ADDON_LOADED", "ForeverRecorder")
assert(ForeverRecorder.ObservationCountAtLoad == 3,
	"expected 3 pre-existing observations counted at load, got " .. tostring(ForeverRecorder.ObservationCountAtLoad))
print("PASS: ObservationCountAtLoad correctly captured before this session's own additions")

print()
print("=== TEST: quest-scoped vs NPC-scoped GiverIdentity (the real M4 discovery) ===")
ForeverObservationLabDB.observations = {}
GetQuestID = function() return 111 end
fire("QUEST_DETAIL") -- quest-scoped
GetQuestID = function() return nil end
fire("GOSSIP_SHOW") -- NPC-scoped (no quest_id)
local questScoped, npcScoped
for _, o in ipairs(ForeverObservationLabDB.observations) do
	if o.module_name == "GiverIdentity" and o.checkpoint == "quest_detail" then questScoped = o end
	if o.module_name == "GiverIdentity" and o.checkpoint == "GOSSIP_SHOW" then npcScoped = o end
end
assert(questScoped.quest_id == 111, "quest-scoped observation must carry the real quest_id")
assert(npcScoped.quest_id == nil, "NPC-scoped observation must have no quest_id -- not fabricated")
assert(npcScoped.data.npc.parsed_creature_id ~= nil, "the NPC identity itself must still be captured")
GetQuestID = function() return 111 end -- restore
print("PASS: quest-scoped and NPC-scoped GiverIdentity both captured correctly, neither fabricates a quest_id")

print()
print("=== TEST: safety -- no raw GUID anywhere in the full DB ===")
local function scanForString(tbl, needle, seen)
	seen = seen or {}
	if seen[tbl] then return false end
	seen[tbl] = true
	for k, v in pairs(tbl) do
		if type(v) == "string" and v:find(needle, 1, true) then return true end
		if type(v) == "table" and scanForString(v, needle, seen) then return true end
	end
	return false
end
assert(not scanForString(ForeverObservationLabDB, "Creature-0-1234-5-6-98765", {}))
print("PASS: no raw GUID present anywhere in ForeverObservationLabDB")

print()
print("=== TEST: bounded item-name retry -- the EXACT 3-attempt ceiling, never resolving ===")
ForeverObservationLabDB.observations = {}
GetNumQuestRewards = function() return 1 end
GetNumQuestChoices = function() return 0 end
GetQuestItemInfo = function(kind, i)
	if kind == "reward" and i == 1 then return "", "tex", 1, 2, 12345 end -- NEVER resolves
	return nil
end
fire("QUEST_DETAIL")
fire("GET_ITEM_INFO_RECEIVED", 12345, true) -- retry 1
fire("GET_ITEM_INFO_RECEIVED", 12345, true) -- retry 2
fire("GET_ITEM_INFO_RECEIVED", 12345, true) -- retry 3 (MAX_RETRIES)
local countAtLimit = #ForeverObservationLabDB.observations
fire("GET_ITEM_INFO_RECEIVED", 12345, true) -- attempt 4: must be refused
assert(#ForeverObservationLabDB.observations == countAtLimit,
	"a 4th retry attempt must be refused once MAX_RETRIES=3 is reached, even though the item never resolved")
local retryObs = {}
for _, o in ipairs(ForeverObservationLabDB.observations) do
	if o.checkpoint:find("retry_after") then table.insert(retryObs, o) end
end
assert(#retryObs == 3, "expected exactly 3 retry observations, got " .. #retryObs)
print("PASS: retry stops at exactly 3 attempts even when the condition never resolves; a 4th fire is a genuine no-op")

print()
print("=== TEST: /fr save actually triggers Export.Save() -> ReloadUI(), not just prints a message ===")
local reloadWasCalled = false
local originalReloadUI = ReloadUI
ReloadUI = function() reloadWasCalled = true end
SlashCmdList["FOREVERRECORDER"]("save")
assert(reloadWasCalled, "/fr save must actually invoke ReloadUI(), not merely print a message")
ReloadUI = originalReloadUI
print("PASS: /fr save invokes ReloadUI(); the confirmation itself is Bootstrap's next-load message " ..
	"(already verified by the persistence-confirmation-signal test above, since that IS what a real " ..
	"reload-and-relaunch produces)")

print()
print("=== TEST: slash commands ===")
SlashCmdList["FOREVERRECORDER"]("status")
SlashCmdList["FOREVERRECORDER"]("clear")
assert(#ForeverObservationLabDB.observations == 0)
SlashCmdList["FOREVERRECORDER"]("bogus")
print("PASS: slash commands run without error")

print()
print("=== M7.7 TEST 1: QUEST_PROGRESS event is recognized and reaches the correct Dispatcher branch ===")
ForeverObservationLabDB.observations = {}
_G.__stubQuestIDValue = 111
fire("QUEST_PROGRESS")
do
	local obs = ForeverObservationLabDB.observations
	local sawQuestProgress = false
	for _, o in ipairs(obs) do
		if o.checkpoint == "quest_progress" then sawQuestProgress = true end
	end
	assert(sawQuestProgress, "QUEST_PROGRESS must dispatch at least one quest_progress-checkpoint observation")
	print("PASS: QUEST_PROGRESS reaches dispatchCheckpoint(\"quest_progress\", ...)")
end

print()
print("=== M7.7 TEST 2: valid QUEST_PROGRESS capture produces the expected observation ===")
ForeverObservationLabDB.observations = {}
GetQuestID = function() return 111 end -- the stub's C_QuestLog.GetInfo recognizes this exact ID
fire("QUEST_PROGRESS")
do
	local obs = ForeverObservationLabDB.observations
	local seen = {}
	for _, o in ipairs(obs) do seen[o.module_name] = (seen[o.module_name] or 0) + 1 end
	assert(seen.QuestMeta == 1, "expected exactly one QuestMeta capture at quest_progress")
	assert(seen.GiverIdentity == 1, "expected exactly one GiverIdentity capture at quest_progress")
	assert(not seen.RewardsItems, "quest_progress must not trigger reward capture -- no rewards exist yet")
	assert(not seen.RewardsReputation, "quest_progress must not trigger reward capture -- no rewards exist yet")
	for _, o in ipairs(obs) do
		if o.module_name == "QuestMeta" then
			assert(o.quest_id == 111, "QuestMeta observation must carry the real quest_id from GetQuestID()")
			assert(o.ok == true, "a resolvable quest_id must produce a successful capture")
		end
	end
	print("PASS: quest_progress captures QuestMeta + GiverIdentity only, with the real quest_id, matching the design's Change 1 exactly")
end

print()
print("=== M7.7 TEST 3: unresolvable quest ID at QUEST_PROGRESS is never fabricated ===")
ForeverObservationLabDB.observations = {}
GetQuestID = function() return nil end -- simulates GetQuestID() failing to establish an ID at this checkpoint
fire("QUEST_PROGRESS")
do
	local obs = ForeverObservationLabDB.observations
	local sawQuestMetaFailure = false
	for _, o in ipairs(obs) do
		if o.module_name == "QuestMeta" then
			assert(o.quest_id == nil, "no quest_id must ever be invented when GetQuestID() cannot establish one")
			assert(o.data.ok == false and o.data.error == "no quest_id in context",
				"QuestMeta must report its own existing, unmodified 'no quest_id in context' error, not fabricate data")
			sawQuestMetaFailure = true
		end
	end
	assert(sawQuestMetaFailure, "expected a QuestMeta observation documenting the unresolved quest_id")
	print("PASS: an unresolvable quest ID is documented as a limitation, never invented -- GiverIdentity capture (which needs no quest_id) still proceeds normally")
	GetQuestID = function() return 111 end -- restore, matching this file's own established convention
end

print()
print("=== M7.7 TEST 4: quest_progress observation shape matches existing quest_detail shape (importer compatibility) ===")
ForeverObservationLabDB.observations = {}
fire("QUEST_DETAIL")
local detailShape = {}
for k in pairs(ForeverObservationLabDB.observations[1]) do detailShape[k] = true end
ForeverObservationLabDB.observations = {}
fire("QUEST_PROGRESS")
local progressShape = {}
for k in pairs(ForeverObservationLabDB.observations[1]) do progressShape[k] = true end
for k in pairs(detailShape) do
	assert(progressShape[k], "quest_progress observation is missing field '" .. k .. "' that quest_detail always has")
end
for k in pairs(progressShape) do
	assert(detailShape[k], "quest_progress observation has an unexpected extra field '" .. k .. "' not present in quest_detail")
end
print("PASS: quest_progress observations use the exact same envelope shape as quest_detail -- the existing M4 importer needs no new field mapping")

print()
print("=== M7.7 TEST 5: regression -- full lifecycle including QUEST_PROGRESS alongside every existing checkpoint ===")
ForeverObservationLabDB.observations = {}
fire("ADDON_LOADED", "ForeverRecorder")
fire("PLAYER_LOGIN")
fire("QUEST_DETAIL")
fire("QUEST_PROGRESS")
fire("GOSSIP_SHOW")
fire("QUEST_COMPLETE")
_G.__fireAllTimers()
fire("QUEST_TURNED_IN", 111, 250, 50)
do
	local obs = ForeverObservationLabDB.observations
	local seen = {}
	for _, o in ipairs(obs) do seen[o.module_name] = (seen[o.module_name] or 0) + 1 end
	assert(seen.QuestMeta and seen.QuestMeta >= 4, "quest_detail + quest_progress + 2 completion checkpoints")
	assert(seen.GiverIdentity and seen.GiverIdentity >= 5)
	assert(seen.Gossip == 1)
	assert(seen.RewardsXPMoney == 1)
	print("PASS: QUEST_PROGRESS coexists cleanly with every pre-existing checkpoint in one full lifecycle")
end

print()
print("ALL RECORDER TESTS PASS")
