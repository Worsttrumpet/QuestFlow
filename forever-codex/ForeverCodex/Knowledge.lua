-- ForeverCodex.Knowledge: human answers to "what is the state of this thing for MY character?". It only says what Codex can
-- actually establish on Forever; everything else is reported as unknown, with the reason, never guessed.
--
--   Quest(id, ctx)  -> { label, detail }      from the quest log, the completion flag, and Codex's own turn-in ledger
--   Systems()       -> trainers, professions and recipes, pets, flight paths: what Codex can and cannot actually see of each TODAY (see the notes above SYSTEMS)
--   Commands()      -> the few slash commands a player should know about
--
-- Quest wording: "You did this", "In progress", "Ready to turn in", "Available" (Codex's data says you could pick it up),
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
		return { label = "Available", detail = "Codex's data says you could pick this up." }
	elseif st.state == "BLOCKED" then
		local detail = "Not for your character right now."
		if st.why == "LEVEL_TOO_LOW" and view and view.req then detail = "You need level " .. view.req .. " first."
		elseif st.why == "PREREQ_MISSING" then detail = "Another quest comes first."
		elseif st.why == "FACTION" or st.why == "RACE" or st.why == "CLASS" then detail = "This one is for a different kind of character." end
		return { label = "Not yet", detail = detail }
	end
	return { label = "Codex cannot tell", detail = "It could not read your quest log." }
end

-- WHAT CODEX KNOWS (0.7.8: rewritten against the implementation; the older "cannot yet see" lines were out of date). Every sentence below is something the code does or does not do TODAY:
--   trainers      SpellTraining.lua reads an open class-trainer window (name, rank text, cost, level requirement, available / locked / known); it needs a visit, remembers what it saw, and
--                 tries to notice a purchase made there. It cannot always tell that a spell was learned when the trainer's own filters hide learned or locked spells.
--   professions   Professions.lua reads the professions you have and their skill / maximum (GetProfessions), and a profession trainer's offer when its window is open. No recipe reader exists.
--   pets          nothing: no pet, pet-ability or pet-training reader exists (PetTraining.lua is only the visibility gate and card shape).
--   flight paths  Codex's data places many flight masters (unverified ATT data). Whether THIS character discovered one is not detectable (Providers/Flight.lua: DISCOVERY_UNDETECTABLE).
local SYSTEMS = {
	{ key = "trainers", label = "Trainers", status = "partly known",
		text = "When you open a class trainer, Codex reads each spell's name, rank, cost, level requirement and whether you can learn it yet, and tries to notice spells you buy there (still being tested on Forever). It only knows what a trainer has shown it, and if the trainer's filters hide learned or locked spells it can miss that you learned one." },
	{ key = "recipes", label = "Professions and recipes", status = "partly known",
		text = "Codex reads which professions you have and your skill in each (for example Herbalism 3/75), and what a profession trainer offers when you open one. It does not read your recipes, so it cannot tell which recipes you know." },
	{ key = "pets", label = "Pets", status = "not known yet",
		text = "Codex does not read pet information yet: not your pet, its abilities or pet training. Pet features will only appear for pet classes, and only once Codex can read them from the game." },
	{ key = "flight", label = "Flight paths", status = "partly known",
		text = "Codex knows where many flight masters are, from its built-in data (not confirmed in the game). It cannot tell which flight paths your character has already discovered, so it may suggest one you have." },
}

function Kn.Systems()
	local out = {}
	for _, s in ipairs(SYSTEMS) do out[#out + 1] = { key = s.key, label = s.label, state = "partial", status = s.status, text = s.text } end
	return out
end

--- The slash commands worth knowing, in the order a new player needs them: { { command, what it does } }. Only commands that exist in Slash.lua.
function Kn.Commands()
	return {
		{ "/codex", "Open or close the Codex window" },
		{ "/codex options", "Settings, themes and this reference" },
		{ "/codex skip", "Skip the current recommendation (/codex unskip brings it back)" },
		{ "/codex spells", "What Codex knows about your spells and trainer visits" },
		{ "/codex professions", "What Codex knows about your professions" },
		{ "/codex report", "A copyable report to paste when something looks wrong" },
		{ "/codex feedback", "Write a problem report (saved on your computer only)" },
		{ "/codex help", "Every command" },
	}
end
