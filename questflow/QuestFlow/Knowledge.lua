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
		if ns.Journey and ns.Journey.SawTurnIn(id) then return { label = "You did this", detail = "Quest Flow saw you turn it in." } end
		return { label = "Quest Flow does not know this quest", detail = "It is not in Quest Flow's data yet." }
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
		return { label = "Available", detail = "Quest Flow's data says you could pick this up." }
	elseif st.state == "BLOCKED" then
		local detail = "Not for your character right now."
		if st.why == "LEVEL_TOO_LOW" and view and view.req then detail = "You need level " .. view.req .. " first."
		elseif st.why == "PREREQ_MISSING" then detail = "Another quest comes first."
		elseif st.why == "FACTION" or st.why == "RACE" or st.why == "CLASS" then detail = "This one is for a different kind of character." end
		return { label = "Not yet", detail = detail }
	end
	return { label = "Quest Flow cannot tell", detail = "It could not read your quest log." }
end

-- WHAT CODEX KNOWS (0.7.8: rewritten against the implementation; the older "cannot yet see" lines were out of date). Every sentence below is something the code does or does not do TODAY:
--   trainers      SpellTraining.lua reads an open class-trainer window (name, rank text, cost, level requirement, available / locked / known); it needs a visit, remembers what it saw, and
--                 tries to notice a purchase made there. It cannot always tell that a spell was learned when the trainer's own filters hide learned or locked spells.
--   professions   Professions.lua reads the professions you have and their skill / maximum (GetProfessions), and a profession trainer's offer when its window is open. No recipe reader exists.
--   pets          nothing: no pet, pet-ability or pet-training reader exists (PetTraining.lua is only the visibility gate and card shape).
--   flight paths  Codex's data places many flight masters (unverified ATT data). Whether THIS character discovered one is not detectable (Providers/Flight.lua: DISCOVERY_UNDETECTABLE).
local SYSTEMS = {
	{ key = "trainers", label = "Trainers", status = "partly known",
		text = "When you open a class trainer, Quest Flow reads each spell's name, rank, cost, level requirement and whether you can learn it yet, and tries to notice spells you buy there (still being tested on Forever). It only knows what a trainer has shown it, and if the trainer's filters hide learned or locked spells it can miss that you learned one." },
	{ key = "recipes", label = "Professions and recipes", status = "partly known",
		text = "Quest Flow reads which professions you have and your skill in each (for example Herbalism 3/75), and what a profession trainer offers when you open one. It does not read your recipes, so it cannot tell which recipes you know." },
	{ key = "pets", label = "Pets", status = "not known yet",
		text = "Quest Flow does not read pet information yet: not your pet, its abilities or pet training. Pet features will only appear for pet classes, and only once Quest Flow can read them from the game." },
	{ key = "flight", label = "Flight paths", status = "partly known",
		text = "Quest Flow knows where many flight masters are, from its built-in data (not confirmed in the game). It cannot tell which flight paths your character has already discovered, so it may suggest one you have." },
}

function Kn.Systems()
	local out = {}
	for _, s in ipairs(SYSTEMS) do out[#out + 1] = { key = s.key, label = s.label, state = "partial", status = s.status, text = s.text } end
	return out
end

--- The slash commands worth knowing, in the order a new player needs them: { { command, what it does } }. Only commands that exist in Slash.lua.
function Kn.Commands()
	return {
		{ "/qflow", "Open or close the Quest Flow window" },
		{ "/qflow options", "Settings, themes and this reference" },
		{ "/qflow skip", "Skip the current recommendation (/qflow unskip brings it back)" },
		{ "/qflow spells", "What Quest Flow knows about your spells and trainer visits" },
		{ "/qflow professions", "What Quest Flow knows about your professions" },
		{ "/qflow report", "A copyable report to paste when something looks wrong" },
		{ "/qflow feedback", "Write a problem report (saved on your computer only)" },
		{ "/qflow help", "Every command" },
	}
end

-- ---------------------------------------------------------------- live knowledge status (0.11.0)
-- Kn.Categories(ctx) is the Options > Appendices "What Quest Flow knows" page: seven categories, each a short list of rows { label, status, text }, computed from
-- the evidence Quest Flow actually holds RIGHT NOW (counts come from the stores, not from a fixed sentence). Status words:
--   "known"        the client or Quest Flow's own logic answers it for your character
--   "learning"     Quest Flow records it as you play; the count says how much it has seen so far (unseen is UNKNOWN, never "no")
--   "partly known" built-in data covers part of it (unchecked in the game) or only some cases are read
--   "not known yet" nothing reads it today
-- Only systems that help a decision are listed. Everything here is a description of the code, and each row is covered by a test.
local function count(t) local n = 0 for _ in pairs(t or {}) do n = n + 1 end return n end

local function offerCounts()
	local db = type(ForeverCodexDB) == "table" and ForeverCodexDB.offers or nil
	if type(db) ~= "table" then return 0, 0 end
	return count(db.quests), count(db.npcs)
end

function Kn.Categories(ctx)
	local st = R.Stats()
	local offered, askedNpcs = offerCounts()
	local T, Sv, Tr = ns.Taxi, ns.Services, ns.Travel
	local ts = T and T.Summary() or { nodes = 0, discovered = 0, listed = 0, edges = 0, measured = 0, matched = 0, proof = {} }
	local sv = Sv and Sv.Summary() or { kinds = {}, entrances = 0 }
	local flightMasters = (st.flightNodes or 0)
	local char = ctx and ctx.char or {}
	local hs = Tr and Tr.HearthState(ctx) or "UNKNOWN"
	local bind = Tr and Tr.Bind()
	local cats = {}
	local function cat(key, label, rows) cats[#cats + 1] = { key = key, label = label, rows = rows } end
	local function seen(k) return sv.kinds and sv.kinds[k] or 0 end

	cat("quest", "Quest Knowledge", {
		{ label = "Quest data", status = "partly known", text = string.format("%d quests in Quest Flow's data (names, levels, chains, prerequisites, givers, turn-ins, objectives, rewards where the sources have them). This data has not been checked in the game; where it is missing, Quest Flow says unknown.", st.quests or 0) },
		{ label = "Is a quest really offered to you", status = "learning", text = string.format("The game's own offer lists are read when you open an NPC's window: %d quests seen offered, %d NPC windows read. A quest listed in the data but never seen offered stays unknown, and one an NPC was asked about and did not offer is held back.", offered, askedNpcs) },
		{ label = "Your quest log and the cap", status = "known", text = "Read from the game: what you have, your progress, what is ready to turn in, and how full your log is (the 40-quest limit is the project owner's figure, not read from the game). A full log changes what Quest Flow recommends." },
		{ label = "Quest-starting items", status = "known", text = "Items in your bags that start a quest are read, so the planner can offer them." },
		{ label = "Rewards and choices", status = "partly known", text = "When a quest offers a reward choice, Quest Flow compares each item with what you wear. It needs the item to be readable by the game, and it does not yet weigh reward usefulness in the route." },
		{ label = "Worth doing now", status = "known", text = "Grey (too low) quests, overlap with other quests, level fit and what a quest unlocks next are weighed by the planner." },
	})
	cat("world", "World Knowledge", {
		{ label = "Quest giver and turn-in places", status = "partly known", text = "Places come from the built-in data and the optional QuestieDB addon. Some quests have no place in any source." },
		{ label = "Vendors, repair, innkeepers", status = "learning", text = string.format("Seen by you so far: %d vendors, %d with repair, %d innkeepers. Quest Flow has no vendor or innkeeper table of its own: it remembers the ones you open.", seen("vendor"), seen("repair"), seen("innkeeper")) },
		{ label = "Class and profession trainers", status = "partly known", text = string.format("Seen by you so far: %d trainers. Opening a trainer records its spells or recipes and what you can learn.", seen("trainer")) },
		{ label = "Flight masters", status = "partly known", text = string.format("%d in the built-in data (ATT, unchecked) plus %d seen on your taxi maps; %d flight masters opened by you.", flightMasters, ts.nodes, seen("flightmaster")) },
		{ label = "Dungeon entrances", status = "learning", text = string.format("%d seen so far: entering a dungeon records where you were just before. Dungeon quests are held back while you are inside one.", sv.entrances or 0) },
	})
	cat("travel", "Travel", {
		{ label = "Flight paths that exist", status = "partly known", text = string.format("%d known to exist (built-in data and your taxi maps).", math.max(flightMasters, ts.nodes)) },
		{ label = "Flight paths YOU have", status = ts.discovered > 0 and "learning" or "not known yet", text = string.format("%d seen as yours on a taxi map, %d only listed. A path you have never seen on a taxi map is unknown, never assumed. Open a flight master's map to teach Quest Flow.", ts.discovered, ts.listed) },
		{ label = "Flight connections and times", status = ts.edges > 0 and "learning" or "not known yet", text = string.format("%d direct flights seen offered, %d with a time measured from a real flight. Others use a rough estimate and say so.", ts.edges, ts.measured) },
		{ label = "Walking", status = "known", text = "Straight-line distance at a typical run speed. There is no path finding, so a river or cliff is not accounted for." },
		{ label = "Hearthstone", status = (hs == "READY" and bind) and "known" or "partly known", text = string.format("Hearthstone: %s. Bind point: %s. It is offered only when ready and it saves a lot of walking.", hs == "UNKNOWN" and "not readable" or hs:lower(), bind and "learned from you binding" or "not learned (bind at an innkeeper while Quest Flow is running)") },
		{ label = "Boats and zeppelins", status = "not known yet", text = "No boat or zeppelin data is built in. When a quest's own text names one, Quest Flow tells you to follow it and shows no arrow." },
	})
	cat("player", "Player Knowledge", {
		{ label = "You and where you are", status = "known", text = "Level, class, race, faction, zone and position are read from the game." },
		{ label = "Money", status = char.money and "known" or "partly known", text = "Read so that a flight you cannot pay for is not offered." },
		{ label = "Bags and gear", status = "known", text = "Quest-starting items, reward comparisons and what you wear are read when they matter." },
		{ label = "Professions and recipes", status = "partly known", text = "Your professions and skill levels are read, and what a profession trainer offers. A recipe reader is not available yet." },
		{ label = "Spells you can learn", status = "partly known", text = "Read from an open class trainer: what is learnable, locked or already known." },
	})
	cat("planner", "Planner", {
		{ label = "How it chooses", status = "known", text = "First is it available, then may it be considered, then what kind of quest is it for you, then does it serve what you are doing, then is it worth the time. Being available never makes a quest a recommendation." },
		{ label = "Low and high level quests", status = "partly known", text = "A quest far below you (the game's grey range) or far above you is left out unless it has a reason: you added it, it is a dungeon quest, or it leads to a quest you hold or a fitting one. Quests with only a required level in the data are not judged by level." },
		{ label = "Your goal", status = "partly known", text = "If your log holds dungeon quests (as the game tags them), those quests and the ones that lead to them count for more and low quests need a reason. With no tag from the game there is no goal." },
		{ label = "Seasonal quests", status = "partly known", text = "Left out of the normal route (/qflow seasonal on to include them). Identified only by QuestieDB's holiday and world-event categories, and only routed when the game itself offers them." },
		{ label = "Trip time and rewards", status = "partly known", text = "Walking by default; a flight or hearth only when it is evidenced as yours. Quests that unlock a next quest count extra. Reward usefulness does not change the route yet." },
	})
	cat("navigation", "Navigation", {
		{ label = "Where to go", status = "known", text = "The map waypoint, minimap and arrow follow the step you are on, not a separate list." },
		{ label = "Flights as steps", status = "partly known", text = "When a flight is evidenced and quicker, the plan shows a Fly step that leads you to the flight master first. It does not take the flight for you." },
		{ label = "Dungeons", status = "known", text = "The arrow and quest pickups are held back inside an instance." },
		{ label = "Not handled", status = "not known yet", text = "No path finding around obstacles, no boats or zeppelins, and no automatic actions." },
	})
	cat("extra", "Additional Systems", {
		{ label = "Pets", status = "not known yet", text = "No pet, pet ability or pet training reader exists yet; pet features appear only for pet classes once it does." },
		{ label = "Party", status = "known", text = "Quest progress is shared with other Quest Flow users in your party." },
	})
	return cats
end
