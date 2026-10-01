-- Proven module: reputation rewards.
--
-- Confirmed real-client findings this module preserves:
--   - faction ID and raw amount are observable (quest 94411: id=2778, raw=10000)
--   - raw/100 == the amount actually shown in the "Reputation with X
--     increased by Y" chat message (10000/100 = 100, exact match) --
--     normalized_amount is computed LOCALLY from that arithmetic, never
--     from an API call
--   - a single quest can carry more than one faction reward (quest 92515:
--     two distinct factions)
--   - reputation is NOT universal -- several quests legitimately return 0
--   - GetFactionInfoByID does not exist on Forever (a real, confirmed
--     negative finding, not a guess)
--
-- This module does NOT invent or guess a replacement faction-name API.
-- If one is ever found, it belongs in the FactionNameResolution
-- experimental module, not here.

ForeverLab = ForeverLab or {}

local GET_FACTION_INFO_BY_ID_KNOWN_STATUS =
	"[V] confirmed absent on Forever as of the M4 reputation follow-up (call failed: "
	.. "'not a function (type=nil)'). Re-attempted every call in case a future patch changes this; "
	.. "not assumed absent without checking."

local function captureFactionRewards(count)
	local out = {}
	for i = 1, count do
		local okR, errR, vR = ForeverLab.SafeCall(GetQuestLogRewardFactionInfo, 6, i)
		local entry = {
			index = i, api = "GetQuestLogRewardFactionInfo", args = { i },
			ok = okR, error = (not okR) and errR or nil,
			r1 = vR[1], r2 = vR[2], r3 = vR[3], r4 = vR[4], r5 = vR[5], r6 = vR[6],
		}
		-- r1 is the presumed factionId, r2 the presumed raw amount, per
		-- Blizzard's own FrameXML usage -- not assumed beyond "worth trying".
		if okR and type(entry.r1) == "number" then
			entry.faction_id = entry.r1
			entry.raw_amount = entry.r2
			if type(entry.r2) == "number" then
				entry.normalized_amount = entry.r2 / 100 -- computed locally, matches the
				-- Blizzard FrameXML convention verified against real chat output (94411: 100)
			end
			local okF, errF, vF = ForeverLab.SafeCall(GetFactionInfoByID, 12, entry.r1)
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

ForeverLab.Registry:Register({
	name = "RewardsReputation",
	status = "proven",
	checkpoints = { "quest_detail", "quest_complete_immediate", "quest_complete_delayed" },
	capture = function(ctx)
		-- Guard added after the M4 repository audit: GetNumQuestLogRewardFactions/
		-- GetQuestLogRewardFactionInfo don't themselves require a quest ID
		-- argument (they read "whatever dialog is currently open"), which
		-- means a reputation observation could previously be recorded with
		-- a real-looking result but no quest_id to attribute it to, if
		-- GetQuestID() had failed at that checkpoint. Requiring a valid
		-- ctx.quest_id here, using the same ok=false pattern every other
		-- module already uses for this case, prevents that orphaned
		-- observation from being created at all.
		if type(ctx.quest_id) ~= "number" then
			return { ok = false, error = "no quest_id in context -- refusing to record a reputation "
				.. "observation that could not be attributed to a specific quest" }
		end
		local rec = { ok = true, api_source = "GetNumQuestLogRewardFactions/GetQuestLogRewardFactionInfo",
			faction_name_resolution_status = "unresolved -- " .. GET_FACTION_INFO_BY_ID_KNOWN_STATUS }
		local okN, errN, vN = ForeverLab.SafeCall(GetNumQuestLogRewardFactions, 1)
		rec.num_factions_ok, rec.num_factions = okN, okN and vN[1] or nil
		rec.num_factions_error = (not okN) and errN or nil
		rec.faction_rewards = {}
		if okN and type(vN[1]) == "number" and vN[1] > 0 then
			rec.faction_rewards = captureFactionRewards(vN[1])
		end
		return rec
	end,
})
