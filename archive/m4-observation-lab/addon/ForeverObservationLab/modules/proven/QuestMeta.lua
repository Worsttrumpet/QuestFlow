-- Proven module: quest ID, title, level, objectives array.
-- Reused from the M4 pre-experiment's captureQuestLogFields, with the
-- explicit-field-extraction fix that replaced the lossy Describe()-based
-- summary (that summary is what silently dropped "title" originally).

ForeverLab = ForeverLab or {}

local function findQuestLogIndexByID(questID)
	local ok, err, v = ForeverLab.SafeCall(C_QuestLog and C_QuestLog.GetNumQuestLogEntries, 1)
	if not ok or type(v[1]) ~= "number" then
		return nil, "GetNumQuestLogEntries failed: " .. tostring(err)
	end
	for i = 1, v[1] do
		local ok2, _, v2 = ForeverLab.SafeCall(C_QuestLog and C_QuestLog.GetInfo, 1, i)
		if ok2 and type(v2[1]) == "table" and v2[1].questID == questID then
			return i
		end
	end
	return nil, "not found among " .. v[1] .. " entries"
end

ForeverLab.Registry:Register({
	name = "QuestMeta",
	status = "proven",
	checkpoints = { "quest_detail", "quest_complete_immediate", "quest_complete_delayed" },
	capture = function(ctx)
		local rec = { api_source = "C_QuestLog.GetInfo / C_QuestLog.GetQuestObjectives" }
		if type(ctx.quest_id) ~= "number" then
			rec.ok = false
			rec.error = "no quest_id in context"
			return rec
		end

		local index, idxErr = findQuestLogIndexByID(ctx.quest_id)
		rec.quest_log_index, rec.quest_log_index_error = index, idxErr

		if index then
			local ok, err, v = ForeverLab.SafeCall(C_QuestLog and C_QuestLog.GetInfo, 1, index)
			rec.get_info_ok = ok
			if ok and type(v[1]) == "table" then
				local info = v[1]
				rec.title = info.title
				rec.level = info.level
				rec.quest_id_from_info = info.questID
			else
				rec.get_info_error = err
			end
		end

		local okObj, errObj, vObj = ForeverLab.SafeCall(C_QuestLog and C_QuestLog.GetQuestObjectives, 1, ctx.quest_id)
		rec.objectives_ok = okObj
		if okObj then
			rec.objectives = vObj[1] -- the full array, as returned, uninterpreted
		else
			rec.objectives_error = errObj
		end

		rec.ok = true
		return rec
	end,
})
