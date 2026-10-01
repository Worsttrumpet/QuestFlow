-- Proven module: gossip quest lists. [V] confirmed working with rich data
-- (M3 session 1 partial, M4 pre-experiment full confirmation: questID,
-- questLevel, title, questInfoID, repeatable, isTrivial, frequency, and
-- the flag fields). Uses an explicit-key extractor, not the generic
-- Describe() summarizer, since that summarizer's arbitrary 6-key cap is
-- exactly what caused the separate title-capture bug found in M3/M4-pre.

ForeverLab = ForeverLab or {}

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

ForeverLab.Registry:Register({
	name = "Gossip",
	status = "proven",
	checkpoints = { "GOSSIP_SHOW" },
	capture = function(ctx)
		local rec = { ok = true, api_source = "C_GossipInfo.GetAvailableQuests/GetActiveQuests" }
		local okA, errA, vA = ForeverLab.SafeCall(C_GossipInfo and C_GossipInfo.GetAvailableQuests, 1)
		rec.available_quests = okA and extractQuestList(vA[1]) or { ok = false, error = errA }
		local okB, errB, vB = ForeverLab.SafeCall(C_GossipInfo and C_GossipInfo.GetActiveQuests, 1)
		rec.active_quests = okB and extractQuestList(vB[1]) or { ok = false, error = errB }
		return rec
	end,
})
