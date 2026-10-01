-- ForeverRecorder.lua: loaded last. A load-time self-check that exactly
-- the expected 6 proven observers registered. Safe to assert here: this
-- file is last in the .toc, so an error here cannot prevent any other
-- file from having already loaded.

local ForeverRecorder = _G.ForeverRecorder
assert(ForeverRecorder, "ForeverRecorder: core failed to load")

local EXPECTED_PROVEN = {
	"QuestMeta", "RewardsXPMoney", "RewardsItems", "RewardsReputation", "GiverIdentity", "Gossip",
}

for _, name in ipairs(EXPECTED_PROVEN) do
	local def = ForeverRecorder.Registry:Get(name)
	assert(def, "expected module '" .. name .. "' to be registered but it is missing")
	assert(def.status == "proven", "module '" .. name .. "' has status '" .. tostring(def.status)
		.. "', expected 'proven' -- M5 ships proven modules only")
end

assert(#ForeverRecorder.Registry.order == #EXPECTED_PROVEN,
	"M5 must ship exactly the " .. #EXPECTED_PROVEN .. " proven observers and nothing else -- found "
	.. #ForeverRecorder.Registry.order)
