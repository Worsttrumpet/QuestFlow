-- Ported unchanged from the Observation Lab's proven Gossip module.
-- Explicit-key extraction, not a generic table-summarizer -- the same
-- class of arbitrary-key-cap bug that dropped "title" during the earlier
-- M3/M4 title-capture failure is avoided here by design, not by luck.

ForeverRecorder = ForeverRecorder or {}

local KNOWN_FIELDS = {
	"questID", "questLevel", "isTrivial", "isLegendary", "isMeta", "isImportant",
	"isIgnored", "isTask", "isBounty", "isStory", "frequency", "title", "questInfoID", "repeatable",
}

local function extractQuestList(list)
	if type(list) ~= "table" then
		return { ok = false, note = "not a table", observed_type = type(list) }
	end
	local total = 0
	for _ in pairs(list) do
		total = total + 1
	end
	local sample = {}
	local shown = 0
	for _, entry in pairs(list) do
		if shown >= 5 then
			break
		end
		if type(entry) == "table" then
			local keys = {}
			for k in pairs(entry) do
				table.insert(keys, tostring(k))
			end
			local row = { all_keys = keys }
			for _, f in ipairs(KNOWN_FIELDS) do
				if entry[f] ~= nil then
					row[f] = entry[f]
				end
			end
			table.insert(sample, row)
		else
			table.insert(sample, { non_table_entry_type = type(entry) })
		end
		shown = shown + 1
	end
	return { ok = true, total_count = total, sample = sample }
end

ForeverRecorder.Registry:Register({
	name = "Gossip",
	status = "proven",
	checkpoints = { "GOSSIP_SHOW" },
	capture = function(ctx)
		local rec = { ok = true, api_source = "C_GossipInfo.GetAvailableQuests/GetActiveQuests" }
		local okA, errA, vA = ForeverRecorder.SafeCall(C_GossipInfo and C_GossipInfo.GetAvailableQuests, 1)
		rec.available_quests = okA and extractQuestList(vA[1]) or { ok = false, error = errA }
		local okB, errB, vB = ForeverRecorder.SafeCall(C_GossipInfo and C_GossipInfo.GetActiveQuests, 1)
		rec.active_quests = okB and extractQuestList(vB[1]) or { ok = false, error = errB }
		return rec
	end,
})
