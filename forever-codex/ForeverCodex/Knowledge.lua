-- ForeverCodex.Knowledge: human answers to "what is the state of this thing for MY character?". It only says what Codex can
-- actually establish on Forever; everything else is reported as unknown, with the reason, never guessed.
--
--   Quest(id, ctx)  -> { label, detail }      from the quest log, the completion flag, and Codex's own turn-in ledger
--   Systems()       -> trainers, recipes, pets, flight paths: each "Codex cannot see this yet" (the client APIs for them
--                      are unverified on Forever), so the UI can say so instead of pretending
--
-- Quest wording: "You did this", "In progress", "Ready to turn in", "Available" (You haven't found this yet),
-- "Not yet" (needs a level / another quest / is for someone else), "Codex does not know this quest".
-- "You did this" rests on C_QuestLog.IsQuestFlaggedCompleted (still UNVERIFIED on Forever at startup) or on Codex having
-- seen the turn-in itself; the planner is not changed by this.

local addonName, ns = ...
local R = ns.Registry
local K = ns.Contract

local Kn = {}
ns.Knowledge = Kn

function Kn.Quest(id, ctx)
	local view = R.Quest(id)
	if not view and not (ctx.log and ctx.log[id]) then
		if ns.Journey and ns.Journey.SawTurnIn(id) then return { label = "You did this", detail = "Codex saw you turn it in." } end
		return { label = "Codex does not know this quest", detail = "It is not in Codex's data yet." }
	end
	local st = K.QuestState(id, view, ctx)
	if st.state == "COMPLETED" or (ns.Journey and ns.Journey.SawTurnIn(id) and st.state ~= "ACTIVE" and st.state ~= "READY") then
		return { label = "You did this" }
	elseif st.state == "READY" then
		return { label = "Ready to turn in", detail = "Your objectives are done." }
	elseif st.state == "ACTIVE" then
		local e = ctx.log[id]
		local os = e and K.ObjectiveState(e.objectives)
		local prog = os and ns.Presenter and ns.Presenter.Progress({ objectiveState = os })
		return { label = "In progress", detail = prog and ("Progress " .. prog .. ".") or nil }
	elseif st.state == "AVAILABLE" then
		return { label = "Available", detail = "You haven't found this yet." }
	elseif st.state == "BLOCKED" then
		local detail = "Not for your character right now."
		if st.why == "LEVEL_TOO_LOW" and view and view.req then detail = "You need level " .. view.req .. " first."
		elseif st.why == "PREREQ_MISSING" then detail = "Another quest comes first."
		elseif st.why == "FACTION" or st.why == "RACE" or st.why == "CLASS" then detail = "This one is for a different kind of character." end
		return { label = "Not yet", detail = detail }
	end
	return { label = "Codex cannot tell", detail = "It could not read your quest log." }
end

local SYSTEMS = {
	{ key = "trainers", label = "Trainers", text = "Codex cannot yet see what your class trainer can teach you." },
	{ key = "recipes", label = "Recipes and professions", text = "Codex cannot yet see which recipes you have learned." },
	{ key = "pets", label = "Pets", text = "Codex cannot yet see pet abilities." },
	{ key = "flight", label = "Flight paths", text = "Codex cannot yet tell which flight paths you have found." },
}

function Kn.Systems()
	local out = {}
	for _, s in ipairs(SYSTEMS) do out[#out + 1] = { key = s.key, label = s.label, state = "unknown", text = s.text } end
	return out
end
