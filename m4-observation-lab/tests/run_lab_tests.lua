-- Run from the tests/ directory: lua5.1 run_lab_tests.lua
dofile("stub_env.lua")

local ADDON = "../addon/ForeverObservationLab/"
local LOAD_ORDER = {
	ADDON .. "core/SafeCall.lua", ADDON .. "core/Describe.lua", ADDON .. "core/GuidUtil.lua",
	ADDON .. "core/PositionUtil.lua", ADDON .. "core/Bootstrap.lua", ADDON .. "core/Registry.lua",
	ADDON .. "core/Dispatcher.lua", ADDON .. "core/Export.lua", ADDON .. "core/Slash.lua",
	ADDON .. "modules/proven/QuestMeta.lua", ADDON .. "modules/proven/RewardsXPMoney.lua",
	ADDON .. "modules/proven/RewardsItems.lua", ADDON .. "modules/proven/RewardsReputation.lua",
	ADDON .. "modules/proven/GiverIdentity.lua", ADDON .. "modules/proven/Gossip.lua",
	ADDON .. "modules/experimental/RewardsCurrency.lua", ADDON .. "modules/experimental/RewardsSpell.lua",
	ADDON .. "modules/experimental/RewardsTitle.lua", ADDON .. "modules/experimental/RewardsHonor.lua",
	ADDON .. "modules/experimental/FactionNameResolution.lua",
	ADDON .. "ForeverObservationLab.lua",
}
for _, f in ipairs(LOAD_ORDER) do
	local ok, err = pcall(dofile, f)
	if not ok then
		print("LOAD ERROR in " .. f .. ": " .. tostring(err))
		os.exit(1)
	end
end
print("=== all " .. #LOAD_ORDER .. " files loaded, self-check assertions in ForeverObservationLab.lua passed ===")

local frame = ForeverLab.Dispatcher.frame
local function fire(event, ...)
	local ok, err = pcall(frame._fire, event, ...)
	if not ok then error("event " .. event .. " crashed the dispatcher: " .. tostring(err)) end
end

print()
print("=== TEST: module registration ===")
local list = ForeverLab.Registry:List()
assert(#list == 11, "expected 11 registered modules, got " .. #list)
local byName = {}
for _, m in ipairs(list) do byName[m.name] = m end
assert(byName.QuestMeta.status == "proven" and byName.QuestMeta.active == true)
assert(byName.RewardsSpell.status == "experimental" and byName.RewardsSpell.active == false)
print("PASS: 11 modules registered; proven modules active by default; experimental modules inactive by default")

print()
print("=== TEST: full lifecycle dispatch (proven modules only, nothing enabled) ===")
fire("ADDON_LOADED", "ForeverObservationLab")
fire("PLAYER_LOGIN")
fire("QUEST_DETAIL")
fire("GOSSIP_SHOW")
fire("QUEST_COMPLETE")
_G.__fireAllTimers()
fire("QUEST_TURNED_IN", 111, 250, 50)

local obs = ForeverObservationLabDB.observations
local seenModules = {}
for _, o in ipairs(obs) do seenModules[o.module_name] = (seenModules[o.module_name] or 0) + 1 end
print("observation counts per module:")
for name, n in pairs(seenModules) do print("  " .. name .. " = " .. n) end

assert(seenModules.QuestMeta and seenModules.QuestMeta >= 3, "QuestMeta should fire at all 3 checkpoints")
assert(seenModules.RewardsItems and seenModules.RewardsItems >= 3)
assert(seenModules.RewardsReputation and seenModules.RewardsReputation >= 3)
assert(seenModules.GiverIdentity and seenModules.GiverIdentity >= 4) -- 3 quest checkpoints + gossip
assert(seenModules.Gossip == 1)
assert(seenModules.RewardsXPMoney == 1)
-- experimental modules must NOT have produced any observation yet
assert(not seenModules.RewardsSpell, "RewardsSpell must not run while disabled")
assert(not seenModules.RewardsTitle, "RewardsTitle must not run while disabled")
assert(not seenModules.RewardsHonor, "RewardsHonor must not run while disabled")
assert(not seenModules.RewardsCurrency, "RewardsCurrency must not run while disabled")
print("PASS: all proven modules dispatched at the right checkpoints; zero experimental observations while disabled")

print()
print("=== TEST: evidence-status separation (module status != observation ok) ===")
local repObs = nil
for _, o in ipairs(obs) do
	if o.module_name == "RewardsReputation" and o.checkpoint == "quest_detail" then repObs = o end
end
assert(repObs.module_status == "proven")
assert(repObs.ok == true) -- the envelope: module ran without a Lua error
local fr1 = repObs.data.faction_rewards[1]
assert(fr1.faction_id == 2778 and fr1.raw_amount == 10000 and fr1.normalized_amount == 100)
assert(fr1.faction_info_lookup.ok == false, "GetFactionInfoByID must report ok=false (it's nil in the stub)")
print("PASS: proven module + a failed underlying API call coexist correctly: module_status='proven', " ..
	"envelope ok=true (module ran fine), inner faction_info_lookup.ok=false (the API itself doesn't exist) -- " ..
	"neither flag overwrites the other")

print()
print("=== TEST: reputation math matches the real 94411 cross-check exactly ===")
assert(fr1.normalized_amount == 100, "10000/100 must equal 100, matching the real chat message")
local fr2 = repObs.data.faction_rewards[2]
assert(fr2.faction_id == 2779 and fr2.raw_amount == 5000 and fr2.normalized_amount == 50)
print("PASS: multi-faction reward capture correct (2778->100, 2779->50), matching the real M4 findings' shape")

print()
print("=== TEST: item nil-or-empty-string unresolved detection + bounded retry ===")
local itemObsImmediate = nil
for _, o in ipairs(obs) do
	if o.module_name == "RewardsItems" and o.checkpoint == "quest_complete_immediate" then itemObsImmediate = o end
end
assert(itemObsImmediate.data.saw_unresolved_first_value == true, "stub returns '' -- must be flagged unresolved")
assert(itemObsImmediate.data.reward_items[1].v1_unresolved == true)
assert(itemObsImmediate.data.reward_items[1].r1 == "", "raw empty string must be preserved, not nil'd out")
assert(itemObsImmediate.data.retry_status == "stub_tested_only_not_yet_observed_fixing_a_real_case",
	"the honesty caveat must travel with every item observation")

fire("GET_ITEM_INFO_RECEIVED", 12345, true)
_G.__itemInfoResolved = true
fire("GET_ITEM_INFO_RECEIVED", 12345, true)
local retryObs = {}
for _, o in ipairs(ForeverObservationLabDB.observations) do
	if o.module_name == "RewardsItems" and o.checkpoint:find("retry_after") then table.insert(retryObs, o) end
end
assert(#retryObs == 2, "expected exactly 2 retry observations, got " .. #retryObs)
assert(retryObs[1].data.saw_unresolved_first_value == true, "retry 1: stub not yet resolved")
assert(retryObs[2].data.saw_unresolved_first_value == false, "retry 2: stub now resolved")
assert(retryObs[2].data.reward_items[1].r1 == "Resolved Item")

local countBefore = #ForeverObservationLabDB.observations
fire("GET_ITEM_INFO_RECEIVED", 999, true) -- stray fire after resolution
assert(#ForeverObservationLabDB.observations == countBefore, "a stray fire after resolution must add nothing")
print("PASS: unresolved detection (nil OR ''), bounded retry, and post-resolution no-op all correct")

print()
print("=== TEST: experimental enable/disable ===")
local okEn, errEn = ForeverLab.Registry:EnableExperimental("RewardsSpell")
assert(okEn)
ForeverObservationLabDB.observations = {}
fire("QUEST_COMPLETE")
_G.__fireAllTimers()
local haveSpell = false
for _, o in ipairs(ForeverObservationLabDB.observations) do
	if o.module_name == "RewardsSpell" then haveSpell = true end
end
assert(haveSpell, "RewardsSpell must run once enabled")

ForeverLab.Registry:DisableExperimental("RewardsSpell")
ForeverObservationLabDB.observations = {}
fire("QUEST_COMPLETE")
_G.__fireAllTimers()
haveSpell = false
for _, o in ipairs(ForeverObservationLabDB.observations) do
	if o.module_name == "RewardsSpell" then haveSpell = true end
end
assert(not haveSpell, "RewardsSpell must stop running once disabled again")

-- case-insensitive enable, and unknown-module error path
local okCI = ForeverLab.Registry:EnableExperimental(ForeverLab.ResolveModuleNameCaseInsensitive("rewardsspell"))
assert(okCI, "case-insensitive resolution must find RewardsSpell from 'rewardsspell'")
local okBad, errBad = ForeverLab.Registry:EnableExperimental("NotARealModule")
assert(not okBad and errBad:find("no such module"))
local okProven, errProven = ForeverLab.Registry:EnableExperimental("QuestMeta")
assert(not okProven and errProven:find("already always active"))
print("PASS: enable/disable works, is session-only, case-insensitive lookup works, " ..
	"bad names and proven-module names are rejected with clear errors")

print()
print("=== TEST: safety -- no raw GUID anywhere in the exported DB ===")
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
assert(not scanForString(ForeverObservationLabDB, "Creature-0-1234-5-6-98765", {}),
	"raw GUID must never appear anywhere in stored data")
print("PASS: no raw GUID present anywhere in ForeverObservationLabDB")

print()
print("=== TEST: export schema consistency ===")
for _, o in ipairs(ForeverObservationLabDB.observations) do
	assert(o.module_name and o.module_status and o.checkpoint and o.recorded_at ~= nil, "missing envelope field")
	assert(o.module_status == "proven" or o.module_status == "experimental")
	assert(type(o.ok) == "boolean")
end
print("PASS: every observation has the required envelope fields (module_name, module_status, checkpoint, " ..
	"recorded_at, ok)")

print()
print("=== TEST: meta fields present ===")
local m = ForeverObservationLabDB.meta
assert(m.lab_version and m.session_id and m.locale == "enUS" and m.observed_build == "69977")
print("PASS: meta captured correctly (lab_version, session_id, locale, build)")

print()
print("=== TEST: slash commands ===")
SlashCmdList["FOREVEROBSERVATIONLAB"]("list")
SlashCmdList["FOREVEROBSERVATIONLAB"]("status")
SlashCmdList["FOREVEROBSERVATIONLAB"]("clear")
assert(#ForeverObservationLabDB.observations == 0)
print("PASS: slash commands run without error")

print()
print("ALL LAB TESTS PASS")
