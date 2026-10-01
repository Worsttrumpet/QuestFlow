-- Proven module: item rewards (guaranteed and choice).
--
-- Preserves, unchanged in substance:
--   - the nil-OR-empty-string "unresolved" condition (M4 item-retry follow-up)
--   - the bounded (max 3) GET_ITEM_INFO_RECEIVED retry
--
-- HONEST STATUS, carried in every record via retry_status: the retry
-- mechanism has been stub-tested but has NOT been observed fixing a real
-- empty-string case on the actual client -- the one real retest (quest
-- 92515) resolved immediately with no unresolved value ever occurring, so
-- the retry path was never exercised for real. This module does not, and
-- must not, claim otherwise.

ForeverLab = ForeverLab or {}

local MAX_RETRIES = 3
local pendingRetryQuestID = nil
local retryCount = 0

local function captureItemsForKind(kind, count)
	local out = {}
	local sawUnresolved = false
	for i = 1, count do
		local ok, err, v = ForeverLab.SafeCall(GetQuestItemInfo, 6, kind, i)
		local v1 = v[1]
		local unresolved = ok and (v1 == nil or v1 == "")
		table.insert(out, {
			index = i, ok = ok, error = (not ok) and err or nil,
			v1_unresolved = unresolved,
			r1 = v[1], r2 = v[2], r3 = v[3], r4 = v[4], r5 = v[5], r6 = v[6],
		})
		if unresolved then
			sawUnresolved = true
		end
	end
	return out, sawUnresolved
end

local function captureCheckpoint(questID)
	local rec = { ok = true, api_source = "GetNumQuestRewards/GetNumQuestChoices/GetQuestItemInfo",
		retry_status = "stub_tested_only_not_yet_observed_fixing_a_real_case" }

	local okNR, errNR, vNR = ForeverLab.SafeCall(GetNumQuestRewards, 1)
	rec.num_rewards_ok, rec.num_rewards = okNR, okNR and vNR[1] or nil
	rec.num_rewards_error = (not okNR) and errNR or nil

	local okNC, errNC, vNC = ForeverLab.SafeCall(GetNumQuestChoices, 1)
	rec.num_choices_ok, rec.num_choices = okNC, okNC and vNC[1] or nil
	rec.num_choices_error = (not okNC) and errNC or nil

	local sawUnresolved = false
	rec.reward_items = {}
	if okNR and type(vNR[1]) == "number" and vNR[1] > 0 then
		local items, flag = captureItemsForKind("reward", vNR[1])
		rec.reward_items = items
		sawUnresolved = sawUnresolved or flag
	end
	rec.choice_items = {}
	if okNC and type(vNC[1]) == "number" and vNC[1] > 0 then
		local items, flag = captureItemsForKind("choice", vNC[1])
		rec.choice_items = items
		sawUnresolved = sawUnresolved or flag
	end
	rec.saw_unresolved_first_value = sawUnresolved
	return rec
end

local function maybeArmRetry(questID, rec)
	if rec.saw_unresolved_first_value then
		pendingRetryQuestID = questID
		retryCount = 0
	end
end

ForeverLab.Registry:Register({
	name = "RewardsItems",
	status = "proven",
	checkpoints = { "quest_detail", "quest_complete_immediate", "quest_complete_delayed" },
	events = { "GET_ITEM_INFO_RECEIVED" },
	capture = function(ctx)
		if type(ctx.quest_id) ~= "number" then
			return { ok = false, error = "no quest_id in context" }
		end
		local rec = captureCheckpoint(ctx.quest_id)
		maybeArmRetry(ctx.quest_id, rec)
		return rec
	end,
	on_event = function(ctx, eventName, ...)
		if not pendingRetryQuestID or retryCount >= MAX_RETRIES then
			return nil -- no-op: nothing pending, don't record noise
		end
		local questID = pendingRetryQuestID
		retryCount = retryCount + 1
		local rec = captureCheckpoint(questID)
		rec.retry_attempt = retryCount
		if not rec.saw_unresolved_first_value then
			pendingRetryQuestID = nil -- resolved; stop retrying
		end
		ctx.checkpoint = "retry_after_get_item_info_received_" .. retryCount
		ctx.quest_id = questID
		return rec
	end,
})
