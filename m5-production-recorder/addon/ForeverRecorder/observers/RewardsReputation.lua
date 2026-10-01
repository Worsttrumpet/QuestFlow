-- Ported unchanged from the Observation Lab's proven RewardsReputation
-- module. [V] repeatedly reproduced (reputation follow-up, cross-checked
-- against real chat math, and the real M4-validating export: quests
-- 92550, 93926, 92551, all showing the same faction pair 2778/2779).
-- GetFactionInfoByID is [V] confirmed absent on Forever; no replacement
-- API is assumed. Faction names are never invented.

ForeverRecorder = ForeverRecorder or {}

local GET_FACTION_INFO_BY_ID_KNOWN_STATUS =
	"[V] confirmed absent on Forever as of the M4 reputation follow-up (call failed: " ..
	"'not a function (type=nil)'). Re-attempted every call in case a future patch changes this; " ..
	"not assumed absent without checking."

local function captureFactionRewards(count)
	local out = {}
	for i = 1, count do
		local okR, errR, vR = ForeverRecorder.SafeCall(GetQuestLogRewardFactionInfo, 6, i)
		local entry = {
			index = i, api = "GetQuestLogRewardFactionInfo", args = { i },
			ok = okR, error = (not okR) and errR or nil,
			r1 = vR[1], r2 = vR[2], r3 = vR[3], r4 = vR[4], r5 = vR[5], r6 = vR[6],
		}
		if okR and type(entry.r1) == "number" then
			entry.faction_id = entry.r1
			entry.raw_amount = entry.r2
			if type(entry.r2) == "number" then
				entry.normalized_amount = entry.r2 / 100
			end
			local okF, errF, vF = ForeverRecorder.SafeCall(GetFactionInfoByID, 12, entry.r1)
			entry.faction_info_lookup = {
				api = "GetFactionInfoByID", args = { entry.r1 }, ok = okF,
				error = (not okF) and errF or nil,
				known_status = GET_FACTION_INFO_BY_ID_KNOWN_STATUS,
				f1 = vF[1], f2 = vF[2], f3 = vF[3], f4 = vF[4], f5 = vF[5], f6 = vF[6],
				f7 = vF[7], f8 = vF[8], f9 = vF[9], f10 = vF[10], f11 = vF[11], f12 = vF[12],
			}
		else
			entry.faction_info_lookup = { attempted = false,
				reason = "first return value was not a number: " .. tostring(entry.r1) }
		end
		table.insert(out, entry)
	end
	return out
end

ForeverRecorder.Registry:Register({
	name = "RewardsReputation",
	status = "proven",
	checkpoints = { "quest_detail", "quest_complete_immediate", "quest_complete_delayed" },
	capture = function(ctx)
		local rec = { ok = true, api_source = "GetNumQuestLogRewardFactions/GetQuestLogRewardFactionInfo",
			faction_name_resolution_status = "unresolved -- " .. GET_FACTION_INFO_BY_ID_KNOWN_STATUS }
		local okN, errN, vN = ForeverRecorder.SafeCall(GetNumQuestLogRewardFactions, 1)
		rec.num_factions_ok, rec.num_factions = okN, okN and vN[1] or nil
		rec.num_factions_error = (not okN) and errN or nil
		rec.faction_rewards = {}
		if okN and type(vN[1]) == "number" and vN[1] > 0 then
			rec.faction_rewards = captureFactionRewards(vN[1])
		end
		return rec
	end,
})
