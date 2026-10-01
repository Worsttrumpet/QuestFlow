-- ForeverObservationLab.lua: loaded last. A load-time self-check that every
-- expected module actually registered with the expected status -- catches
-- a typo or a missing Register() call loudly rather than silently missing
-- a capability. Safe to assert here: this file is last in the .toc, so an
-- error here cannot prevent any other file from having already loaded.

local ForeverLab = _G.ForeverLab
assert(ForeverLab, "ForeverObservationLab: core failed to load")

local EXPECTED_PROVEN = {
	"QuestMeta", "RewardsXPMoney", "RewardsItems", "RewardsReputation", "GiverIdentity", "Gossip",
}
local EXPECTED_EXPERIMENTAL = {
	"RewardsCurrency", "RewardsSpell", "RewardsTitle", "RewardsHonor", "FactionNameResolution",
}

local function assertRegistered(name, expectedStatus)
	local def = ForeverLab.Registry:Get(name)
	assert(def, "expected module '" .. name .. "' to be registered but it is missing")
	assert(def.status == expectedStatus,
		"module '" .. name .. "' has status '" .. tostring(def.status) .. "', expected '" .. expectedStatus .. "'")
end

for _, name in ipairs(EXPECTED_PROVEN) do
	assertRegistered(name, "proven")
end
for _, name in ipairs(EXPECTED_EXPERIMENTAL) do
	assertRegistered(name, "experimental")
end
