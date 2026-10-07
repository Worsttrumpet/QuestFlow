-- guidance_tests.lua: Fix 1 (0.7.1) "active and ready quests always get guidance". A quest the player is working on, or has finished, is never answered with
-- "Nothing to recommend": when the planner has no NOW (no usable location, or a leg Codex cannot measure) the card names the quest and shows the quest log's own
-- words. It never invents a location, never changes the planner's decision and never places a waypoint or arrow. Stub-client tests of Codex's own logic only.

local H = ...
local check, section, boot = H.check, H.section, H.boot

local function Q(id, name, dx, dy, o)
	local q = { id = id, name = name, map = 9001, x = 0.5 + dx / 1000, y = 0.5 + (dy or 0) / 1000 }
	for k, v in pairs(o or {}) do q[k] = v end
	return q
end

--- A world: quests in the synthetic ATT pack, a quest log { [id] = { title, complete, objectives = { { text, have, need } } } }, the player's map/position.
local function world(quests, log, loc)
	local ns = boot({ char = { level = 10 }, synthetic = true, loc = loc or { map = 9001, x = 0.5, y = 0.5, zone = "Fixture Valley" } })
	H.attPack(ns, quests, nil)
	local W = H.world()
	W.log, W.objectives = {}, {}
	for id, e in pairs(log or {}) do
		W.log[#W.log + 1] = { questID = id, title = e.title or ("quest " .. id), complete = e.complete == true }
		if e.objectives then
			W.objectives[id] = {}
			for i, ob in ipairs(e.objectives) do
				W.objectives[id][i] = { text = ob.text, type = "item", finished = (ob.have or 0) >= (ob.need or 1), numFulfilled = ob.have or 0, numRequired = ob.need or 1 }
			end
		end
	end
	ns.Prefs.FinishSetup()
	ns.Prefs.SetNavigation(true)
	ns.State.Recompute()
	return ns, W
end
local function card(ns) return ns.Presenter.Card(ns.State.plan, ns.State.ctx) end

section("guidance: an active quest Quest Flow cannot place gets its objective text instead of 'Nothing to recommend'")
do
	local ns, W = world({}, { [900] = { title = "The Earthen Ring", objectives = { { text = "Take the Skycutter to Mulgore", have = 0, need = 1 } } } })
	local p = ns.State.plan
	local c = card(ns)
	check(p.now == nil and p.diag.reason == "NO_LOCATED_ACTION", "(setup) the planner has no NOW: the quest has no usable location")
	check(c.empty == nil and c.guidance == true and c.now and c.now.guidance == true, "the card is guidance, not the empty card")
	check(c.now.title == "Finish The Earthen Ring", "it names the quest  [" .. tostring(c.now.title) .. "]")
	check(c.now.objectives and #c.now.objectives == 1 and c.now.objectives[1].text == "Take the Skycutter to Mulgore", "the quest log's own objective text is shown, unchanged")
	check(c.now.who:find("no map location", 1, true) ~= nil and c.now.who:find("no arrow", 1, true) ~= nil, "and it says honestly that Quest Flow has no location and there is no arrow")
	check(c.now.where == nil and c.now.dist == nil and c.now.whereShort == nil, "no distance or place is claimed")
	check(p.now == nil and #p.sequence == 0 and ns.Navigation.Target() == nil and ns.Navigation.Owned() == nil and W.waypointCalls == 0, "no coordinate, no waypoint and no arrow target were made")
	check(#ns.errors == 0, "no errors")
end

section("guidance: an objective with no counts still shows the quest log's text; with no text at all it points at the quest log (nothing is invented)")
do
	local ns = world({}, { [901] = { title = "Plain Quest" } })
	local c = card(ns)
	check(c.now and c.now.guidance and c.now.detail == "Open your quest log for what this quest asks.", "no objective text known: a plain pointer to the quest log  [" .. tostring(c.now and c.now.detail) .. "]")
	local ns2 = world({}, { [902] = { title = "Wordy", objectives = { { text = "Speak with the old woman", have = 0, need = 1 } } } })
	check(card(ns2).now.objectives[1].text == "Speak with the old woman", "the objective's words are the game's")
end

section("guidance: a finished quest whose hand-in Quest Flow cannot place is guidance, and the READY list does not repeat it")
do
	local ns = world({}, { [903] = { title = "Done Deal", complete = true } })
	local c = card(ns)
	check(ns.State.plan.now == nil and c.guidance and c.now.title == "Turn in Done Deal" and c.now.kind == "TURN_IN", "turn-in guidance names the quest")
	check(c.now.detail:find("Hand the quest in", 1, true) ~= nil and c.now.where == nil, "without a place or a NPC being claimed")
	check(#c.ready == 0, "the READY TO TURN IN list does not list it a second time")
	check(ns.State.plan.turnIns[1] and ns.State.plan.turnIns[1].quest == 903, "the plan's own ready list still has it")
end

section("guidance: a located quest with an unmeasurable leg (player map has no world conversion) is guidance, with no arrow")
do
	-- the pack knows the hand-in on map 9001; the player stands on a map Codex cannot convert, so the leg is unknown
	local ns, W = world({ Q(7, "Far Hand-in", 0, 0, { giverName = "Gornek", turnIn = true }) }, { [7] = { title = "Far Hand-in", complete = true } },
		{ map = 7777, x = 0.5, y = 0.5, zone = "Nowhere" })
	local p, c = ns.State.plan, card(ns)
	if p.now == nil then
		check(c.guidance == true and c.now.kind == "TURN_IN" and c.empty == nil, "NOW is empty and the card is guidance, not 'Nothing'")
		check(ns.Navigation.Target() == nil and W.waypointCalls == 0, "no waypoint or arrow was made for an unmeasured destination")
		check(c.now.who:find("could not measure", 1, true) ~= nil or c.now.who:find("no map location", 1, true) ~= nil, "it explains why there is no arrow")
	else
		check(true, "(this fixture routes normally here: guidance not needed)")
	end
end

section("guidance: located active quests and located hand-ins still route normally (guidance is only for a planner with no NOW)")
do
	local ns, W = world({ Q(1, "Near Quest", 100, 0, { objCoords = { { map = 9001, x = 0.6, y = 0.5 } } }) }, { [1] = { title = "Near Quest", objectives = { { text = "Boars", have = 1, need = 5 } } } })
	local c = card(ns)
	check(ns.State.plan.now ~= nil and c.guidance == nil and c.now.title == "Finish Near Quest", "an objective with a location is NOW as before")
	local ns2 = world({ Q(2, "Near Hand-in", 100, 0, { giverName = "Hanna" }) }, { [2] = { title = "Near Hand-in", complete = true } })
	local c2 = card(ns2)
	check(ns2.State.plan.now ~= nil and c2.guidance == nil and c2.now.kind == "TURN_IN", "a located turn-in is NOW as before")
	check(ns2.Navigation.Target() ~= nil, "and still gets its navigation target")
end

section("guidance: nothing in the log is still an honest empty card")
do
	local ns = world({}, {})
	local c = card(ns)
	check(c.now == nil and c.guidance == nil and c.empty and c.empty.title == "Nothing urgent right now", "no quests, nothing to say")
end
