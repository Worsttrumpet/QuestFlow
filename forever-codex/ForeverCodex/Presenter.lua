-- ForeverCodex.Presenter: turns the Planner's plan into what a PLAYER should read. Pure: no frames, no client calls.
--
-- "Hide the machinery, show the decision." Nothing here emits an id, a coordinate, a source label, a confidence, a
-- score, a raw state or a map id. Titles and sentences are built from structured action facts and reason codes; where a
-- fact is unknown the sentence is simply omitted (it is never invented).
--
--   Presenter.Card(plan, ctx) -> {
--     now    = { title, who, detail, progress, objectives = { { text, have, need } }, where, why, icon, kind } | nil
--              (`why` is for /codex report: the window does not draw it)
--     alsoDo = same | nil          (at most ONE, exactly the Planner's alsoDo)
--     ready  = { { title, who, where } }     READY TO TURN IN: finished quests that are not NOW
--     also   = { { kind = "objective", title, objectives = { { text, have, need } } } | { kind = "action", title, where } }   ALSO COMPLETE THIS
--     thenLine = "Turn in X" | nil (omitted when it is far away or says little)
--     empty  = { title, lines } | nil
--     reminders = { "Quest name", ... }    quests in the log Codex cannot place on the map
--   }

local addonName, ns = ...
local R = ns.Registry
local E = ns.Engine
local Pl = ns.Planner

local Pr = {}
ns.Presenter = Pr

Pr.THEN_MAX_YD = 600      -- a THEN farther than this is not worth a line in the window (a presentation choice, not a planner rule)

local function trim(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end

--- "10/10 Mottled Boar slain" / "Mottled Boar slain: 3/10" -> "Mottled Boar slain"; nil if nothing is left.
function Pr.CleanObjective(text)
	if type(text) ~= "string" then return nil end
	local t = text:gsub("^%s*%d+%s*/%s*%d+%s*:?%s*", ""):gsub("%s*:?%s*%d+%s*/%s*%d+%s*$", "")
	t = trim(t)
	return t ~= "" and t or nil
end

local function questName(a)
	if a.name and a.name ~= "" then return a.name end
	if a.title then
		local t = a.title:match("^[^:]*:%s*(.+)$")
		if t and not t:match("^quest %d+$") then return t end
	end
	return "a quest"
end

--- The first unfinished objective's counts, e.g. "4 / 6", or nil when the quest log did not report them.
function Pr.Progress(a)
	local os = a.objectiveState
	if not (os and os.known) then return nil end
	for _, o in ipairs(os.list) do
		if not o.finished and type(o.have) == "number" and type(o.need) == "number" and o.need > 0 then
			return string.format("%d / %d", o.have, o.need)
		end
	end
	return nil
end

local function unfinished(a)
	local out = {}
	local os = a.objectiveState
	if os and os.known then
		for _, o in ipairs(os.list) do if not o.finished then out[#out + 1] = o end end
	end
	return out
end

--- Coarse, human distance from the player to an action's target. nil when it cannot be said.
function Pr.Where(a, ctx)
	local pos = Pl.Locate(a)
	local me = ctx.loc and ctx.loc.available and { map = ctx.loc.map, x = ctx.loc.x, y = ctx.loc.y, world = ctx.loc.world or false } or nil
	if not pos or not me then return nil end
	local d = E.Distance(ctx, me, pos)
	if d == nil or d >= E.DIFFERENT_CONTINENT then return "In another area" end
	if d < 30 then return "Right here" end
	if d < 150 then return "Nearby" end
	return string.format("About %d yards away", math.floor(d / 50 + 0.5) * 50)
end

--- The heading for the carried also-rows, decided from the WHOLE set (never the first row): all objectives -> "ALSO COMPLETE", all pickups ->
-- "ALSO PICK UP", anything else (a mix) -> "ALSO DO". Used by the tracker and by /codex report so they cannot disagree. nil for an empty set.
function Pr.AlsoLabel(items)
	if not items or #items == 0 then return nil end
	local nObj, nAccept = 0, 0
	for _, it in ipairs(items) do
		if it.kind == "objective" then nObj = nObj + 1 elseif it.verb == "ACCEPT" then nAccept = nAccept + 1 end
	end
	if nObj == #items then return "ALSO COMPLETE" end
	if nAccept == #items then return "ALSO PICK UP" end
	return "ALSO DO"
end

--- The distance as the tracker prints it: "Here" (under 30 yd), "90 yd", "1,800 yd", "In another area"; nil when it cannot be said.
function Pr.Dist(d, area)
	if type(d) ~= "number" then return nil end
	if d >= E.DIFFERENT_CONTINENT then return "In another area" end
	if d < 30 then return "Here" end
	local r = d < 1000 and math.floor(d / 10 + 0.5) * 10 or math.floor(d / 50 + 0.5) * 50
	local t = tostring(r)
	if r >= 1000 then t = t:sub(1, #t - 3) .. "," .. t:sub(-3) end
	-- an objective is an AREA the game marks with one point (the real spawns can be anywhere in it): its distance is to that point, so it is marked approximate
	return (area and "~" or "") .. t .. " yd"
end

--- "a - b" for the parts that exist (nil when none do).
function Pr.Join(...)
	local out = {}
	for i = 1, select("#", ...) do
		local v = select(i, ...)
		if type(v) == "string" and v ~= "" then out[#out + 1] = v end
	end
	return #out > 0 and table.concat(out, " - ") or nil
end

--- How many follow-up quests turning this one in would open for THIS character, by the rules Codex already applies to every pickup (the same
-- eligibility check, run as if the quest were done). Quests already done or in the log, repeatables and anything the rules exclude are not counted.
-- nil when the data names none. (QuestieDB prerequisite lists: unverified, so this says "Codex knows of", never more.)
--- The names (at most two) of the follow-up quests turning this one in would open for this character (the same rules as Pr.Unlocks), or an empty list.
function Pr.UnlockNames(a, ctx)
	local out = {}
	if not (a and a.quest and ctx and Pl.Unlocks and ns.QuestProvider) then return out end
	local after = setmetatable({ isCompleted = function(id) return id == a.quest or ctx.isCompleted(id) end }, { __index = ctx })
	local strategy = R.Strategy(ctx.prefs and ctx.prefs.style)
	for _, qid in ipairs(Pl.Unlocks(a.quest)) do
		local v = R.Quest(qid)
		if v and not ctx.log[qid] and not ctx.isCompleted(qid) and ns.QuestProvider.Eligibility(v, after, strategy) and v.name then
			out[#out + 1] = v.name
			if #out >= 2 then break end
		end
	end
	return out
end

function Pr.Unlocks(a, ctx)
	if not (a and a.quest and ctx and Pl.Unlocks and ns.QuestProvider) then return nil end
	local after = setmetatable({ isCompleted = function(id) return id == a.quest or ctx.isCompleted(id) end }, { __index = ctx })
	local strategy = R.Strategy(ctx.prefs and ctx.prefs.style)
	local n = 0
	for _, qid in ipairs(Pl.Unlocks(a.quest)) do
		local v = R.Quest(qid)
		if v and not ctx.log[qid] and not ctx.isCompleted(qid) and ns.QuestProvider.Eligibility(v, after, strategy) then n = n + 1 end
	end
	return n > 0 and n or nil
end

--- The short reason the planner put an action beside the route (from its own reason codes), or nil. Never invented.
function Pr.AlsoWhy(plan, a)
	local why = plan and plan.diag and plan.diag.reasons and plan.diag.reasons[a.id]
	for _, o in ipairs(plan and plan.onTheWay or {}) do
		if o.id == a.id then why = { o.reason } break end        -- the opportunity carries its own reason code (every on-the-way row, not only the ALSO DO)
	end
	for _, r in ipairs(why or {}) do
		if r.code == "SAME_STOP" then return "Same stop." end
		if r.code == "ON_THE_WAY" then return "On your way." end
		if r.code == "SMALL_DETOUR" then return string.format("Detour about %d s.", r.seconds or 0) end
	end
	return nil
end

local function describe(a, plan, ctx, icon)
	local name = questName(a) .. (ns.Dungeons and ns.Dungeons.Suffix(ctx, a.quest) or "")
	local it = { kind = a.kind, icon = icon, where = Pr.Where(a, ctx), progress = Pr.Progress(a) }
	-- the tracker's short form of the same distance ("Here", "Nearby", "750 yd away"); nil when it cannot be said
	local pos0 = Pl.Locate(a)
	local me0 = ctx.loc and ctx.loc.available and { map = ctx.loc.map, x = ctx.loc.x, y = ctx.loc.y, world = ctx.loc.world or false } or nil
	local d0 = pos0 and me0 and E.Distance(ctx, me0, pos0) or nil
	local sw = ns.Overlap and ns.Overlap.ShortWhere(d0)
	if sw then it.whereShort = (sw == "here" and "Here") or (sw == "nearby" and "Nearby") or (sw .. " away") end
	if pos0 and d0 and d0 >= E.DIFFERENT_CONTINENT then it.whereShort = "In another area" end
	it.dist = Pr.Dist(d0, a.kind == "OBJECTIVE")          -- the number the tracker prints ("90 yd", "1,800 yd", "Here")
	if type(a.level) == "number" and a.quest then it.level = a.level end
	if a.type == "FLIGHT" then
		it.title = "Visit the flight master"
		it.detail = a.name and ("Flight path: " .. a.name .. ".") or nil
		it.who = nil
	elseif a.kind == "ACCEPT" then
		it.title = "Accept " .. name
		it.who = a.giver
		it.npc = a.giver
		-- a quest that starts from an item or a world object: no NPC is named as its giver, and the card says where it starts
		if a.sourceKind == "ITEM" or a.sourceKind == "OBJECT" then
			it.who, it.npc = nil, nil
		end
		-- the quest giver's own dialog declined to offer it when last asked (OfferProbe, at the character's current progression): say so instead of promising an accept
		local st, ev = Pl.OfferState(a)
		it.offerState = st
		if st == "NOT_OFFERED" then it.caution = "Not offered by " .. tostring((ev and ev.npc) or a.giver or "its quest giver") .. " the last time you asked." end
		local view = a.quest and R.Quest(a.quest)
		local obj = view and view.objectives and Pr.CleanObjective(view.objectives[1])
		it.detail = obj and ("Goal: " .. obj .. ".") or (a.giver and ("Talk to " .. a.giver .. ".") or nil)
		if a.sourceKind == "ITEM" or a.sourceKind == "OBJECT" then
			it.detail = a.sourceKind == "ITEM" and ("Starts from an item" .. (a.sourceItem and (": " .. a.sourceItem) or "") .. ". Not from an NPC.") or "Starts from a world object. Not from an NPC."
		end
	elseif a.kind == "OBJECTIVE" then
		it.title = "Finish " .. name
		local todo = unfinished(a)
		local first = todo[1] and Pr.CleanObjective(todo[1].text)
		if first then
			it.detail = first .. (#todo > 1 and string.format(" (and %d more)", #todo - 1) or "") .. "."
		end
		-- EVERY unfinished objective the quest log reports (finished ones are left out), so the player sees all that remains
		it.objectives = {}
		for _, o in ipairs(todo) do it.objectives[#it.objectives + 1] = { text = Pr.CleanObjective(o.text) or "objective", have = o.have, need = o.need } end
	elseif a.kind == "TURN_IN" then
		it.title = "Turn in " .. name
		it.npc = a.turnInNpc and a.giver or nil           -- only a NAMED turn-in NPC; the quest giver's name is not assumed to be where it is handed in
		it.who = it.npc
		it.detail = a.giver and ("Hand it in near " .. a.giver .. ".") or "Your objectives are done."
		-- READY -> TURN IN -> UNLOCK -> THEN: say what the hand-in opens, so the order makes sense (the THEN line names the next step)
		local names = Pr.UnlockNames(a, ctx)
		if #names > 0 then it.unlocks = names; it.detail = it.detail .. " It opens " .. table.concat(names, " and ") .. "." end
	else
		it.title = name
	end
	-- when Codex will not point at the destination (or only as a straight line), say why in the player's words; the arrow and the waypoint follow the same assessment
	if ns.Navigation and ns.Navigation.Assess and a.type ~= "FLIGHT" then
		local as = ns.Navigation.Assess(a, ctx)
		if Pl.Locate(a) and (as.reason or as.straight) then it.navNote, it.navReason = as.text, as.reason end
		if as.inArea then it.dist, it.whereShort = "In the objective area", "In the objective area" end
	end
	it.whyPlayer = Pr.WhyPlayer(a, it, plan)
	local why = ns.PlanAdapter.Sentences(plan, a)
	it.why = why[1]
	if why[1] == "Best available option" then it.why = nil end
	return it
end

--- ONE short, player-facing reason for a recommendation, or nil: why is Codex suggesting this? Built from facts the planner already established (its reason codes, the quest's own timer,
-- what a hand-in opens, the objective area), never from scores, and never invented. The window shows it under the action as "Why".
function Pr.WhyPlayer(a, it, plan)
	if not a then return nil end
	local codes = {}
	for _, r in ipairs(plan and plan.diag and plan.diag.reasons and plan.diag.reasons[a.id] or {}) do codes[r.code] = r end
	if a.timer and type(a.timer.remaining) == "number" and a.timer.remaining <= 600 then return "This quest is timed and running out of time." end
	if a.kind == "TURN_IN" and it and it.unlocks and #it.unlocks > 0 then return "Handing it in opens " .. table.concat(it.unlocks, " and ") .. "." end
	if it and it.dist == "In the objective area" then return "You are already in the area for this objective." end
	if codes.PLAYER_ADDED then return "You chose this one." end
	if codes.CHAIN_UNLOCK then return "It unlocks a follow-up quest nearby." end
	if codes.LOCAL_PROGRESS then return "Keeps your current quests moving where you are." end
	if codes.ON_THE_WAY then return "It is right on your way." end
	if codes.SAME_STOP then return "Several things can be done at this stop." end
	if codes.BEST_SEQUENCE then return (codes.BEST_SEQUENCE.stops and codes.BEST_SEQUENCE.stops > 1) and "The best first step of a short route." or "The best use of your time right now." end
	return nil
end

Pr.Describe = describe

--- The NEW QUEST ITEM rows: quest-starting items in the bags that are actionable (the candidate funnel already removed completed / in-log / skipped / ineligible ones).
function Pr.QuestItems(plan)
	local out = {}
	for _, a in ipairs(plan and plan.questItems or {}) do
		local verified = a.verified == true
		out[#out + 1] = { title = a.name or "Quest item", id = a.id, quest = a.quest, questName = a.questName, verified = verified,
			detail = (verified and "This item starts a quest." or "Codex's data says this item starts a quest.") .. " Use it to continue your progression." }
	end
	return out
end

--- GUIDANCE for a quest the player is working on when the planner has no NOW: the quest log's own wording, never a location. Pure presentation:
-- the planner's decision (no NOW), the waypoint and the arrow are untouched, so nothing here can point anywhere. Returns a card item or nil.
-- Order: a finished quest to hand in, then an unfinished objective (each by quest id, skipped and dungeon-card quests left out).
function Pr.Guidance(plan, ctx)
	if not plan then return nil end
	local P = ns.Prefs
	local function usable(a)
		if not a.quest or (P and a.skipKey and P.IsSkipped(a.skipKey)) then return false end
		return not (ns.Dungeons and ns.Dungeons.IsDungeon(ctx, a.quest))
	end
	local pick
	for _, a in ipairs(plan.turnIns or {}) do if usable(a) then pick = a break end end
	if not pick then
		for _, a in ipairs(plan.objectives or {}) do
			if a.kind == "OBJECTIVE" and usable(a) and #unfinished(a) + (a.objectiveState and a.objectiveState.known and 0 or 1) > 0 then
				-- a quest with a live countdown comes first (the soonest deadline), otherwise the first by id
				if not pick or (a.timer and (not pick.timer or a.timer.remaining < pick.timer.remaining)) then pick = a end
			end
		end
	end
	if not pick then return nil end
	local it = describe(pick, plan, ctx, "star")
	it.guidance, it.quest = true, pick.quest
	local placed = Pl.Locate(pick) ~= nil
	it.who = placed and "Codex could not measure the way there from here, so there is no arrow."
		or "Codex has no map location for this quest, so there is no arrow. Use the quest's own text."
	if not placed then it.dist, it.whereShort, it.where = nil, nil, nil end
	-- the quest log's own objective text; the quest is never given a place Codex does not have
	if pick.kind == "TURN_IN" then
		it.detail = "Your objectives are done. Hand the quest in."
	elseif it.objectives and #it.objectives > 0 then
		it.detail = nil                                       -- the rows carry the objective text
	else
		local entry = ctx and ctx.log and ctx.log[pick.quest]
		local text
		for _, o in ipairs(entry and entry.objectives or {}) do
			local t = type(o) == "table" and Pr.CleanObjective(o.text) or nil
			if t then text = t break end
		end
		it.detail = text and (text .. ".") or "Open your quest log for what this quest asks."
	end
	return it
end

--- OFFERED HERE: quests the game is offering (OfferProbe evidence, no pack knows them) that have no location. As ALSO PICK UP rows: the NPC who offered them, never a place.
function Pr.Offers(plan)
	local out = {}
	for _, a in ipairs(plan and plan.reminders or {}) do
		if a.offered and a.quest then
			out[#out + 1] = { kind = "action", title = "Accept " .. questName(a), npc = a.giver, verb = "ACCEPT", quest = a.quest, offered = true,
				why = a.giver and ("Offered to you by " .. a.giver .. ".") or "Offered to you by the game." }
		end
	end
	return out
end

--- A feature card behind the relevance gate: nil when the feature is not relevant to this character (the card is then ABSENT, never a "not applicable" card), else whatever the feature's own
-- Card(ctx) returns (nil when it has nothing to say). See Relevance.lua.
function Pr.Feature(key, ctx, cardFn)
	if type(cardFn) ~= "function" then return nil end
	if not (ns.Relevance and ns.Relevance.Applies(key, ctx)) then return nil end
	return cardFn(ctx)
end

function Pr.Card(plan, ctx)
	local card = { reminders = {} }
	card.questItems = Pr.QuestItems(plan)
	for _, a in ipairs(plan and plan.reminders or {}) do
		if not a.offered and #card.reminders < 3 then card.reminders[#card.reminders + 1] = questName(a) end
	end
	local offers = Pr.Offers(plan)
	card.timers = ns.QuestTimers and ns.QuestTimers.List(ctx) or {}          -- TIMED QUEST: the game's own countdown, shown whatever NOW is
	if not (plan and plan.now) then
		local g = Pr.Guidance(plan, ctx)
		if not g and offers[1] then
			-- nothing to route, but the game is offering a quest: say so, with the NPC, and no place
			local o = offers[1]
			g = { guidance = true, kind = "ACCEPT", quest = o.quest, title = o.title, who = o.npc, detail = o.why .. " Codex has no location for it, so there is no arrow.", icon = "star" }
			local rest = {}
			for i = 2, #offers do rest[#rest + 1] = offers[i] end
			offers = rest
		end
		if g then
			-- the player has a quest to work on: say what it is, in the game's own words, instead of "nothing"; the READY list does not repeat it
			card.now, card.guidance = g, true
			card.also = offers
			card.ready = {}
			for _, r in ipairs(ns.Overlap and ns.Overlap.Ready(plan, ctx) or {}) do
				if r.quest ~= g.quest or g.kind ~= "TURN_IN" then card.ready[#card.ready + 1] = r end
			end
			card.slots = Pr.Slots(ctx)
			card.dungeons = ns.Dungeons and ns.Dungeons.List(ctx) or {}
			card.spells = Pr.Feature("spellTraining", ctx, ns.SpellTraining and ns.SpellTraining.Card)
		card.pets = Pr.Feature("petTraining", ctx, ns.PetTraining and ns.PetTraining.Card)
			card.professions = Pr.Feature("professions", ctx, ns.Professions and ns.Professions.Card)
			return card
		end
		local lines = {}
		if not plan then
			lines[1] = "Codex is still reading your character and quest log."
		elseif #card.reminders > 0 then
			lines[1] = "You have quests Codex cannot place on the map yet."
		else
			lines[1] = "Codex has no higher-priority action for you right now. Explore or pick up a quest and it will take it from there."
		end
		local pn = plan and plan.diag and plan.diag.possible and plan.diag.possible.n or 0
		if pn > 0 then lines[#lines + 1] = string.format("%d pickup%s Codex knows of %s far away and not confirmed by the game; /codex report lists %s.", pn, pn == 1 and "" or "s", pn == 1 and "is" or "are", pn == 1 and "it" or "them") end
		for _, w in ipairs(plan and plan.warnings or {}) do
			if #lines < 3 and not w:find("^Not available on this client") then lines[#lines + 1] = w end
		end
		card.empty = { title = plan and "Nothing urgent right now" or "Gathering information...", lines = lines }
		card.also, card.ready = {}, ns.Overlap and ns.Overlap.Ready(plan, ctx) or {}
		card.slots = Pr.Slots(ctx)
		card.dungeons = ns.Dungeons and ns.Dungeons.List(ctx) or {}
		card.spells = Pr.Feature("spellTraining", ctx, ns.SpellTraining and ns.SpellTraining.Card)
			card.pets = Pr.Feature("petTraining", ctx, ns.PetTraining and ns.PetTraining.Card)
		card.professions = Pr.Feature("professions", ctx, ns.Professions and ns.Professions.Card)
		return card
	end
	card.now = describe(plan.now, plan, ctx, "star")
	-- ALSO COMPLETE THIS: other unfinished objectives that fit with NOW (ns.Overlap), plus the planner's own ALSO DO
	card.also = ns.Overlap and ns.Overlap.List(plan, ctx) or {}
	for _, o in ipairs(offers) do card.also[#card.also + 1] = o end          -- the game's own offers with no location: the NPC, never a place
	-- READY TO TURN IN: finished quests waiting for the right moment (never promoted to NOW just because they are finished)
	card.ready = ns.Overlap and ns.Overlap.Ready(plan, ctx) or {}
	card.slots = Pr.Slots(ctx)
	card.dungeons = ns.Dungeons and ns.Dungeons.List(ctx) or {}
	card.professions = Pr.Feature("professions", ctx, ns.Professions and ns.Professions.Card)    -- PROFESSIONS: status and reminders only, never an input to the plan
	card.spells = Pr.Feature("spellTraining", ctx, ns.SpellTraining and ns.SpellTraining.Card)     -- SPELL TRAINING: a persistent, informational section below DUNGEON QUESTS; never an input to the plan
	card.pets = Pr.Feature("petTraining", ctx, ns.PetTraining and ns.PetTraining.Card)               -- PET TRAINING: only for pet classes, and only when a pet source has something to say
	if plan.alsoDo then
		card.alsoDo = describe(plan.alsoDo, plan, ctx, plan.alsoDo.type == "FLIGHT" and "triangle" or "diamond")
	end
	local t = plan.thenAction
	if t then
		local show = false                                -- (a THEN hand-in would repeat READY TO TURN IN)
		if t.kind ~= "TURN_IN" then
			local a, b = Pl.Locate(plan.now), Pl.Locate(t)
			local d = a and b and E.Distance(ctx, a, b) or nil
			show = d ~= nil and d < E.DIFFERENT_CONTINENT and d <= Pr.THEN_MAX_YD
		end
		if show then
			local th = describe(t, plan, ctx, nil)
			card.thenLine = th.title
			card.thenWhere = Pr.Join(th.dist, th.npc)
		end
	end
	return card
end

--- The normal quest-log usage the quest log reports: { used, max, free, full } or nil when it cannot be read.
function Pr.Slots(ctx)
	if not (ctx and ctx.logAvailable and type(ctx.logCount) == "number") then return nil end
	local max = E.QUEST_LOG_MAX
	return { used = ctx.logCount, max = max, free = math.max(0, max - ctx.logCount), full = ctx.logCount >= max }
end

--- "Thrall - level 25 Troll Warrior"
function Pr.Header(ctx)
	local c = ctx and ctx.char or {}
	local parts = {}
	if c.level then parts[#parts + 1] = "level " .. c.level end
	if c.race then parts[#parts + 1] = c.race end
	if c.class then parts[#parts + 1] = c.class end
	return (c.name or "Your character") .. (#parts > 0 and (" - " .. table.concat(parts, " ")) or "")
end
