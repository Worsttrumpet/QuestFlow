-- Ported from the Observation Lab's proven RewardsItems module. Logic is
-- UNCHANGED (nil-or-empty "unresolved" detection, bounded retry, max 3).
--
-- ONE addition, per M5 design §6: an explicit evidence_note on the
-- GUARANTEED (non-choice) item-reward case only, never on choice items.
-- This distinguishes two genuinely different evidence strengths that the
-- Lab's own code treated identically:
--   - choice items: [V], independently reproduced across three real
--     sessions (M4 pre-experiment, item-retry follow-up, and the real
--     M4-validating export itself: quests 92528, 92550, 93926).
--   - guaranteed items: [V] exactly ONCE (the item-retry follow-up, quest
--     92515, "Simple Leather Satchel"), never reproduced since -- the
--     real M4-validating export contained zero guaranteed-item-reward
--     quests (every real quest tested had num_rewards=0).
-- The collection CODE is identical for both; only the evidence basis
-- differs, and only the export should say so -- not a code-path change.
--
-- The retry mechanism itself remains labeled exactly as honestly as
-- before: it has fixed a real failure zero times in any real session to
-- date (the empty-string condition it exists for was observed once, in
-- the very first real session, and has not recurred since).

ForeverRecorder = ForeverRecorder or {}

local MAX_RETRIES = 3
local pendingRetryQuestID = nil
local retryCount = 0

local GUARANTEED_ITEM_EVIDENCE_NOTE =
	"[V] confirmed exactly once (M4 item-retry follow-up, quest 92515) -- not yet independently " ..
	"reproduced. The real M4-validating export contained zero guaranteed-item-reward quests. Do not " ..
	"treat this as equivalently proven to choice-item rewards."

local function captureItemsForKind(kind, count)
	local out = {}
	local sawUnresolved = false
	for i = 1, count do
		local ok, err, v = ForeverRecorder.SafeCall(GetQuestItemInfo, 6, kind, i)
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

	local okNR, errNR, vNR = ForeverRecorder.SafeCall(GetNumQuestRewards, 1)
	rec.num_rewards_ok, rec.num_rewards = okNR, okNR and vNR[1] or nil
	rec.num_rewards_error = (not okNR) and errNR or nil

	local okNC, errNC, vNC = ForeverRecorder.SafeCall(GetNumQuestChoices, 1)
	rec.num_choices_ok, rec.num_choices = okNC, okNC and vNC[1] or nil
	rec.num_choices_error = (not okNC) and errNC or nil

	local sawUnresolved = false
	rec.reward_items = {}
	if okNR and type(vNR[1]) == "number" and vNR[1] > 0 then
		local items, flag = captureItemsForKind("reward", vNR[1])
		rec.reward_items = items
		rec.reward_items_evidence_note = GUARANTEED_ITEM_EVIDENCE_NOTE
		sawUnresolved = sawUnresolved or flag
	end
	rec.choice_items = {}
	if okNC and type(vNC[1]) == "number" and vNC[1] > 0 then
		local items, flag = captureItemsForKind("choice", vNC[1])
		rec.choice_items = items
		-- Deliberately NO evidence_note here -- choice items are the
		-- repeatedly-reproduced case and should not carry the same caveat.
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

ForeverRecorder.Registry:Register({
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
			return nil
		end
		local questID = pendingRetryQuestID
		retryCount = retryCount + 1
		local rec = captureCheckpoint(questID)
		rec.retry_attempt = retryCount
		if not rec.saw_unresolved_first_value then
			pendingRetryQuestID = nil
		end
		ctx.checkpoint = "retry_after_get_item_info_received_" .. retryCount
		ctx.quest_id = questID
		return rec
	end,
})
