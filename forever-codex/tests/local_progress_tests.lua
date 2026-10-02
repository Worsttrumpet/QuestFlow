-- local_progress_tests.lua: "local progression first" (Planner), the in-progress-work fallback, and that nothing is hardcoded to a zone.
-- Synthetic maps only (9001 / 9002 are 3000 yd apart on one continent): no zone, quest or NPC of the real game is named by the planner.
--   * with useful located work on the player's own map, a better-looking distant stop is not chosen as NOW
--   * with none, travel is still allowed (the player is never trapped)
--   * work already underway here (in the log, objective spot unknown) is NOW rather than a trip elsewhere
--   * a chosen route zone and a quest the player added still win

local H = ...
local check, section, boot = H.check, H.section, H.boot

local function Q(id, name, map, x, y, o)
	local q = { id = id, name = name, map = map, x = x, y = y, req = 1 }
	for k, v in pairs(o or {}) do q[k] = v end
	return q
end
local ZONES = { { key = "zone-a", label = "Zone A", map = 9001, quests = 1 }, { key = "zone-b", label = "Zone B", map = 9002, quests = 1 } }

--- Boots a synthetic world, the player standing at the centre of `map`, and returns ns, W.
local function world(level, map, quests, o)
	o = o or {}
	local ns = boot({ char = { level = level, class = o.class or "Warrior", classToken = o.classToken or "WARRIOR", race = "Orc", raceToken = "Orc", faction = "Horde" },
		synthetic = true, loc = { map = map, x = 0.5, y = 0.5, zone = "Somewhere" } })
	H.attPack(ns, quests, ZONES)
	local W = H.world()
	W.log, W.objectives, W.completed = {}, {}, {}
	for id, e in pairs(o.log or {}) do
		W.log[#W.log + 1] = { questID = id, title = e.title or ("quest " .. id), complete = e.complete == true }
		if e.objectives then
			W.objectives[id] = {}
			for i, ob in ipairs(e.objectives) do W.objectives[id][i] = { text = ob.text, type = "monster", finished = ob.have >= ob.need, numFulfilled = ob.have, numRequired = ob.need } end
		end
	end
	ns.Prefs.FinishSetup()
	if o.routeZone then ns.Prefs.SetRouteZone(o.routeZone) end
	for _, id in ipairs(o.added or {}) do ns.Prefs.Add(id) end
	return ns, W
end

local function plan(ns) return ns.State.Recompute() end
local function mapOf(a) return a and a.target and a.target.map end

--- A local pickup 300 yd on the side AWAY from the other map (so reaching the distant stop does not pass through it).
local function awayFrom(farMap, id, name, localMap) return Q(id, name, localMap, farMap == 9002 and 0.2 or 0.8, 0.5) end

--- A rich distant stop: many pickups at one spot on the far map (worth more than a single local pickup, even after the walk).
local function distantBundle(map, n, base)
	local out = {}
	for i = 1, n do out[#out + 1] = Q(base + i, "Far pickup " .. i, map, 0.02 + i * 0.0001, 0.5) end
	return out
end

section("local progression: useful work on the player's own map comes before a trip that looks better on paper")
do
	local quests = { awayFrom(9002, 1, "Local pickup", 9001) }
	for _, q in ipairs(distantBundle(9002, 14, 100)) do quests[#quests + 1] = q end
	local ns = world(6, 9001, quests)
	-- the scenario means something only if, without the rule, the distant bundle wins
	ns.Planner.LOCAL_FIRST = false
	local without = plan(ns)
	check(mapOf(without.now) == 9002, "(setup) without the local rule the distant bundle would be NOW (it looks better on paper)")
	ns.Planner.LOCAL_FIRST = true
	local with = plan(ns)
	check(with.now and with.now.id == "Q:1:ACCEPT" and mapOf(with.now) == 9001, "with it, the local pickup is NOW")
	check(with.diag.localOnly == true, "and the plan says it kept to the local area")
	check(with.diag.reasons["Q:1:ACCEPT"] and with.diag.reasons["Q:1:ACCEPT"][2] and with.diag.reasons["Q:1:ACCEPT"][2].code == "LOCAL_PROGRESS", "with the reason LOCAL_PROGRESS")
	check(#ns.errors == 0, "no errors")
end

section("local progression: nothing is tied to a zone, a level, a class or a direction")
do
	for _, case in ipairs({
		{ level = 2, map = 9001, far = 9002, class = "Warrior", token = "WARRIOR" },
		{ level = 6, map = 9002, far = 9001, class = "Paladin", token = "PALADIN" },    -- the mirror image: the other map is the local one
		{ level = 14, map = 9001, far = 9002, class = "Mage", token = "MAGE" },
		{ level = 19, map = 9002, far = 9001, class = "Hunter", token = "HUNTER" },
	}) do
		local quests = { awayFrom(case.far, 1, "Local pickup", case.map) }
		for _, q in ipairs(distantBundle(case.far, 14, 100)) do quests[#quests + 1] = q end
		for _, q in ipairs(quests) do q.req = math.max(1, case.level - 1) end        -- level-appropriate for this character
		local ns = world(case.level, case.map, quests, { class = case.class, classToken = case.token })
		local p = plan(ns)
		check(p.now and p.now.id == "Q:1:ACCEPT" and mapOf(p.now) == case.map, string.format("level %d %s on map %d: the local pickup, not the distant bundle", case.level, case.class, case.map))
	end
	-- no zone is named in the planner itself
	local src = H.readFile(H.addonDir .. "/Planner.lua"):gsub("%-%-[^\n]*", "")
	check(not src:lower():find("tirisfal", 1, true) and not src:lower():find("deathknell", 1, true) and not src:find("1420", 1, true) and not src:find("1454", 1, true), "the planner names no zone and no map id")
end

section("local progression: when nothing local is worth doing the player is sent elsewhere (never trapped)")
do
	-- the only local stop is 900 yd away for a single pickup: it does not pay for its own walk
	local quests = { Q(1, "Poor local pickup", 9001, 0.5 + 0.9, 0.5) }
	quests[1].x = 0.5 + 0.45; quests[1].y = 0.5 + 0.45                      -- ~640 yd diagonally: low value, long walk
	for _, q in ipairs(distantBundle(9002, 14, 100)) do quests[#quests + 1] = q end
	local ns = world(6, 9001, quests)
	local p = plan(ns)
	check(p.diag.localOnly ~= true, "a local stop that is not worth its own walk does not hold the player back")
	check(p.now ~= nil, "(there is a recommendation)")
	-- nothing local at all
	local ns2 = world(6, 9001, distantBundle(9002, 14, 100))
	local p2 = plan(ns2)
	check(p2.now and mapOf(p2.now) == 9002 and p2.diag.localOnly ~= true, "with no local work at all the distant stop is NOW")
	check(#ns.errors == 0 and #ns2.errors == 0, "no errors")
end

section("local progression: a chosen route zone and a quest the player added still win")
do
	local quests = { awayFrom(9002, 1, "Local pickup", 9001) }
	for _, q in ipairs(distantBundle(9002, 14, 100)) do quests[#quests + 1] = q end
	local ns = world(6, 9001, quests, { routeZone = "zone-b" })
	local p = plan(ns)
	check(p.now and mapOf(p.now) == 9002, "the player's chosen route zone (the far map) beats the local-first rule")
	local ns2 = world(6, 9001, quests, { added = { 105 } })
	local p2 = plan(ns2)
	check(p2.now and p2.now.quest == 105 and mapOf(p2.now) == 9002, "a distant quest the player added is still NOW")
end

section("local progression: work already underway here (objective spot unknown) is NOW, not a trip elsewhere")
do
	-- the player has a quest in progress in this area; Codex does not know where its objective is; the only located stops are far away
	local quests = { Q(50, "Clear the area", 9001, nil, nil, { zone = "zone-a", giverName = "Someone" }) }
	quests[1].map, quests[1].x, quests[1].y = nil, nil, nil
	for _, q in ipairs(distantBundle(9002, 14, 100)) do quests[#quests + 1] = q end
	local ns, W = world(3, 9001, quests, { log = { [50] = { title = "Clear the area", objectives = { { text = "Zombie slain", have = 2, need = 8 } } } } })
	local p = plan(ns)
	check(p.now and p.now.quest == 50 and p.now.kind == "OBJECTIVE", "NOW is the quest already in progress here")
	check(p.now and p.now.target == nil and p.now.noLocation == true, "with no map location (its objective spot is not known)")
	check(p.now and p.diag.reason == "LOCAL_WORK" and p.diag.localWork == true and p.diag.reasons[p.now.id][1].code == "LOCAL_PROGRESS", "and the plan says why")
	local card = ns.Presenter.Card(p, ns.State.ctx)
	check(card.now and card.now.title == "Finish Clear the area" and card.now.where == nil and card.now.progress == "2 / 8" and card.now.why == "Keeps you progressing where you are", "the card says: finish it, 2 / 8, and why (no distance is invented)")
	check(p.alsoDo == nil and p.thenAction == nil, "no ALSO DO or THEN is invented around it")
	check(ns.Navigation.Target() == nil and ns.Pins.Desired(p)[1] == nil, "nothing is sent to the arrow, the waypoint or the map")
	-- the player can get out of it
	local skipped = ns.State.SkipCurrent()
	check(skipped and skipped.quest == 50 and ns.State.plan.now and mapOf(ns.State.plan.now) == 9002, "Skip moves on: the distant stop becomes NOW")
	H.slash("unskip")
	check(ns.State.plan.now and ns.State.plan.now.quest == 50, "and unskip brings the local work back")
	-- finishing it releases the player
	W.log = { { questID = 50, title = "Clear the area", complete = true } }
	W.completed[50] = true
	ns.UI.Open("codex")
	check(#ns.errors == 0, "no errors (the page draws a NOW with no location)")
	-- a useful LOCATED local stop is preferred to unlocated local work (it can be navigated to)
	local q2 = { Q(50, "Clear the area", nil, nil, nil, { zone = "zone-a" }), Q(1, "Local pickup", 9001, 0.52, 0.5) }
	q2[1].map, q2[1].x, q2[1].y = nil, nil, nil
	for _, q in ipairs(distantBundle(9002, 14, 100)) do q2[#q2 + 1] = q end
	local ns2 = world(3, 9001, q2, { log = { [50] = { title = "Clear the area", objectives = { { text = "x", have = 0, need = 3 } } } } })
	local p2 = plan(ns2)
	check(p2.now and p2.now.id == "Q:1:ACCEPT", "a located local pickup is NOW; the unlocated quest stays a reminder")
	-- work in ANOTHER area does not hold the player here
	local q3 = { Q(50, "Elsewhere work", nil, nil, nil, { zone = "zone-b" }) }
	q3[1].map, q3[1].x, q3[1].y = nil, nil, nil
	for _, q in ipairs(distantBundle(9002, 14, 100)) do q3[#q3 + 1] = q end
	local ns3 = world(3, 9001, q3, { log = { [50] = { title = "Elsewhere work", objectives = { { text = "x", have = 0, need = 3 } } } } })
	local p3 = plan(ns3)
	check(p3.now and p3.now.quest ~= 50 and p3.diag.localWork ~= true, "an in-progress quest in a different area does not become NOW here")
	-- the most advanced one first
	local q4 = { Q(60, "Barely started", nil, nil, nil, { zone = "zone-a" }), Q(61, "Nearly done", nil, nil, nil, { zone = "zone-a" }) }
	for _, q in ipairs(q4) do q.map, q.x, q.y = nil, nil, nil end
	local ns4 = world(3, 9001, q4, { log = { [60] = { objectives = { { text = "a", have = 1, need = 10 } } }, [61] = { objectives = { { text = "b", have = 9, need = 10 } } } } })
	local p4 = plan(ns4)
	check(p4.now and p4.now.quest == 61, "with two, the one furthest along comes first")
	check(#ns.errors == 0 and #ns2.errors == 0 and #ns3.errors == 0 and #ns4.errors == 0, "no errors")
end

section("local progression through QuestieDB: a distant, event-style hand-in does not pull a starter-area player away")
do
	-- Shaped like the real report, with invented ids and places: a quest in progress in the local area (objective spot unknown), and a quest
	-- that is complete the moment it is held, given in one place and handed in on another continent.
	local f = H.fake.new({ version = "1.0.4" })
	f.mapArea(9001, 9001); f.mapArea(9003, 9003)
	f.addNpc(7001, { name = "Local Giver", spawns = { [9001] = { { 51.0, 50.0 } } }, zoneID = 9001, friendlyToFaction = "H" })
	f.addNpc(7002, { name = "Recruiter", spawns = { [9001] = { { 60.0, 50.0 } } }, zoneID = 9001, friendlyToFaction = "H" })
	f.addNpc(7003, { name = "Overseas Officer", spawns = { [9003] = { { 50.0, 50.0 } } }, zoneID = 9003, friendlyToFaction = "H" })
	f.addQuest(94001, { name = "Clear The Local Area", startedBy = { { 7001 } }, finishedBy = { { 7001 } }, requiredLevel = 1, questLevel = 2, zoneOrSort = 9001,
		objectivesText = { "Slay 8 monsters near the camp." } })
	f.addQuest(94002, { name = "A Far Request", startedBy = { { 7002 } }, finishedBy = { { 7003 } }, requiredLevel = 1, questLevel = 2, zoneOrSort = 9001,
		objectivesText = { "Speak with the officer overseas." } })
	f.install()
	local ns = boot({ char = { level = 3, class = "Paladin", classToken = "PALADIN", race = "Orc", raceToken = "Orc", faction = "Horde" }, synthetic = true, loc = { map = 9001, x = 0.5, y = 0.5, zone = "Somewhere" } })
	local W = H.world()
	W.log = { { questID = 94001, title = "Clear The Local Area", complete = false }, { questID = 94002, title = "A Far Request", complete = true } }
	W.objectives = { [94001] = { { text = "0/8 Monster slain", type = "monster", finished = false, numFulfilled = 3, numRequired = 8 } } }
	ns.Prefs.FinishSetup()
	local R = ns.Registry
	check(R.Quest(94001).zoneMap == 9001, "the bridge carries the quest's broad area (zoneOrSort -> map)")
	local p = ns.State.Recompute()
	-- the far hand-in is located on the other continent, through the turn-in NPC (not the giver standing next to the player)
	local ti
	local cands = ns.Engine.Candidates(ns.Context.Build())
	for _, l in ipairs({ cands.candidates, cands.inProgress }) do for _, a in ipairs(l) do if a.quest == 94002 and a.kind == "TURN_IN" then ti = a end end end
	check(ti and ti.target and ti.target.map == 9003 and ti.giver == "Overseas Officer", "the far request is routed to its turn-in NPC overseas, not to the recruiter next to the player")
	check(p.now and p.now.quest == 94001 and p.now.kind == "OBJECTIVE" and p.now.target == nil, "NOW is the quest in progress here, not the trip overseas")
	local card = ns.Presenter.Card(p, ns.State.ctx)
	check(card.now and card.now.title == "Finish Clear The Local Area" and card.now.progress == "3 / 8", "the card says what to do and how far along it is")
	-- once it is skipped the player is not trapped: Codex does not invent a recommendation, and the far hand-in is not forced on them either
	-- (a trip to another continent for nothing else is refused by the existing rule), but they can still add it themselves
	ns.State.SkipCurrent()
	check(ns.State.plan.now == nil and ns.State.plan.diag.reason == "ONLY_DISTANT_UNMEASURED", "after Skip nothing is forced: the overseas trip alone is not recommended")
	ns.Prefs.Add(94002)
	check(ns.State.Recompute().now and ns.State.plan.now.quest == 94002 and ns.State.plan.now.target.map == 9003, "but a quest the player adds is routed to the turn-in NPC overseas")
	check(#ns.errors == 0, "no errors")
	f.uninstall()
end

-- ================================================================ quest-state priority: a finished quest to hand in vs a new pickup

section("quest state: a finished quest's hand-in comes before a new pickup (not buried in NEARBY), priced by real walking")
do
	local function ready(id, name, x, y, o) return Q(id, name, 9001, x, y, o or {}) end
	local function at(dx, dy) return 0.5 + dx / 1000, 0.5 + (dy or 0) / 1000 end
	local DONE = { [2] = { title = "Finished quest", complete = true } }
	local function titles(p) return (p.now and p.now.id or "-") .. " | " .. (p.alsoDo and p.alsoDo.id or "-") .. " | " .. (p.thenAction and p.thenAction.id or "-") end

	-- 1. the same spot: a pickup and a hand-in from the same NPC (the real report: "NOW: Accept ... NEARBY: Turn in ...")
	local x1, y1 = at(30, 0)
	local ns = world(6, 9001, { Q(1, "New pickup", 9001, x1, y1, { giverName = "Quest NPC" }), Q(2, "Finished quest", 9001, x1, y1, { giverName = "Quest NPC" }) }, { log = DONE })
	local p = plan(ns)
	check(p.now and p.now.id == "Q:2:TURN_IN" and p.alsoDo and p.alsoDo.id == "Q:1:ACCEPT", "at one spot: NOW is the hand-in and the pickup is the ALSO DO (not the other way round)  [" .. titles(p) .. "]")

	-- 2. the stickiness trap: the pickup was NOW, then the other quest became ready to hand in: the hand-in takes over
	local nsS, WS = world(6, 9001, { Q(1, "New pickup", 9001, x1, y1, { giverName = "Quest NPC" }), Q(2, "Finished quest", 9001, x1, y1, { giverName = "Quest NPC" }) }, {})
	nsS.Prefs.Skip("Q:2")
	local before = plan(nsS)
	check(before.now and before.now.id == "Q:1:ACCEPT", "(setup) the pickup is NOW first")
	nsS.Prefs.Unskip("Q:2")
	WS.log = { { questID = 2, title = "Finished quest", complete = true } }
	local after = plan(nsS)
	check(after.now and after.now.id == "Q:2:TURN_IN", "when the other quest becomes ready, the remembered pickup does not keep NOW")

	-- 3. two spots close together: the hand-in 80 yd from the pickup goes first (the pickup is 20 yd east, the hand-in 60 yd west)
	local xa, ya = at(20, 0)
	local xb, yb = at(-60, 0)
	local ns3 = world(6, 9001, { Q(1, "New pickup", 9001, xa, ya, { giverName = "A" }), Q(2, "Finished quest", 9001, xb, yb, { giverName = "B" }) }, { log = DONE })
	ns3.Planner.TURN_IN_FIRST = false
	local without = plan(ns3)
	check(without.now and without.now.id == "Q:1:ACCEPT", "(setup) without the rule the nearer pickup would be NOW")
	ns3.Planner.TURN_IN_FIRST = true
	local with = plan(ns3)
	check(with.now and with.now.id == "Q:2:TURN_IN" and with.diag.turnInFirst == true, "with it, the nearby hand-in is NOW  [" .. titles(with) .. "]")
	check(with.alsoDo == nil or with.alsoDo.id == "Q:1:ACCEPT", "and the pickup follows")

	-- 4. not blindly forced: a hand-in far out of the way does not pre-empt a pickup beside you
	local xf, yf = at(600, 0)
	local xn, yn = at(20, 0)
	local ns4 = world(6, 9001, { Q(1, "New pickup", 9001, xn, yn, { giverName = "A" }), Q(2, "Finished quest", 9001, xf, yf, { giverName = "B" }) }, { log = DONE })
	local p4 = plan(ns4)
	check(p4.now and p4.now.id == "Q:1:ACCEPT" and p4.diag.turnInFirst ~= true, "a hand-in 600 yd away does not pre-empt a pickup 20 yd away  [" .. titles(p4) .. "]")
	-- ... and across the sea (an unmeasurable leg) it never goes first
	local ns4b = world(6, 9001, { Q(1, "New pickup", 9001, xn, yn, { giverName = "A" }), Q(2, "Overseas hand-in", 9003, 0.5, 0.5, { giverName = "B" }) }, { log = DONE })
	local p4b = plan(ns4b)
	check(p4b.now and p4b.now.id == "Q:1:ACCEPT", "an overseas hand-in is never forced in front of local work")

	-- 5. objectives in progress keep their own rule: finished here first, the hand-in 300 yd away waits (the trip is batched)
	local xo, yo = at(40, 0)
	local xh, yh = at(340, 0)
	local ns5 = world(6, 9001, { Q(1, "In progress", 9001, nil, nil, { giverName = "A", objCoords = { { map = 9001, x = xo, y = yo } } }), Q(2, "Finished quest", 9001, xh, yh, { giverName = "B" }) },
		{ log = { [1] = { objectives = { { text = "Thing slain", have = 1, need = 5 } } }, [2] = { complete = true, title = "Finished quest" } } })
	local p5 = plan(ns5)
	check(p5.now and p5.now.id == "Q:1:OBJECTIVE", "objectives right here are still done before a hand-in 300 yd away  [" .. titles(p5) .. "]")
	-- ... but at one spot the order is hand-in, objectives, pickups
	local ns5b = world(6, 9001, { Q(1, "In progress", 9001, nil, nil, { giverName = "A", objCoords = { { map = 9001, x = xo, y = yo } } }), Q(2, "Finished quest", 9001, xo, yo, { giverName = "B" }),
		Q(3, "New pickup", 9001, xo, yo, { giverName = "C" }) }, { log = { [1] = { objectives = { { text = "Thing slain", have = 1, need = 5 } } }, [2] = { complete = true, title = "Finished quest" } } })
	local p5b = plan(ns5b)
	check(p5b.now and p5b.now.id == "Q:2:TURN_IN", "at one spot the hand-in leads (state 1)  [" .. titles(p5b) .. "]")
	local ns5c = world(6, 9001, { Q(1, "In progress", 9001, nil, nil, { giverName = "A", objCoords = { { map = 9001, x = xo, y = yo } } }), Q(3, "New pickup", 9001, xo, yo, { giverName = "C" }) },
		{ log = { [1] = { objectives = { { text = "Thing slain", have = 1, need = 5 } } } } })
	check(plan(ns5c).now.id == "Q:1:OBJECTIVE", "then objectives in progress (state 2) before a new pickup (state 3)")

	-- 6. nothing is tied to a map, a level or a class
	for _, case in ipairs({ { 9002, 3, "Mage", "MAGE" }, { 9001, 12, "Paladin", "PALADIN" }, { 9002, 19, "Hunter", "HUNTER" } }) do
		local map, lvl, cls, tok = case[1], case[2], case[3], case[4]
		local qa = Q(1, "New pickup", map, xa, ya, { giverName = "A", req = math.max(1, lvl - 1) })
		local qb = Q(2, "Finished quest", map, xb, yb, { giverName = "B", req = math.max(1, lvl - 1) })
		local nsC = world(lvl, map, { qa, qb }, { log = DONE, class = cls, classToken = tok })
		local pc = plan(nsC)
		check(pc.now and pc.now.id == "Q:2:TURN_IN", string.format("level %d %s on map %d: the nearby hand-in is NOW", lvl, cls, map))
	end
	check(#ns.errors == 0 and #ns3.errors == 0 and #ns4.errors == 0 and #ns5.errors == 0, "no errors")
end

section("quest state: the hand-in destination is the TURN-IN NPC's, not the giver's (the planner uses the right place for each action)")
do
	local f = H.fake.new({ version = "1.0.4" })
	f.mapArea(9001, 9001)
	f.addNpc(8001, { name = "Pickup NPC", spawns = { [9001] = { { 50.5, 50.0 } } }, zoneID = 9001, friendlyToFaction = "H" })             -- 5 yd from the player
	f.addNpc(8002, { name = "Far Giver", spawns = { [9001] = { { 95.0, 50.0 } } }, zoneID = 9001, friendlyToFaction = "H" })           -- 450 yd east
	f.addNpc(8003, { name = "Near Taker", spawns = { [9001] = { { 47.0, 50.0 } } }, zoneID = 9001, friendlyToFaction = "H" })           -- 30 yd west
	f.addNpc(8004, { name = "Near Giver", spawns = { [9001] = { { 52.0, 50.0 } } }, zoneID = 9001, friendlyToFaction = "H" })           -- 20 yd east
	f.addNpc(8005, { name = "Far Taker", spawns = { [9001] = { { 95.0, 50.0 } } }, zoneID = 9001, friendlyToFaction = "H" })           -- 450 yd east
	f.addQuest(95001, { name = "Take A Pickup", startedBy = { { 8001 } }, finishedBy = { { 8001 } }, requiredLevel = 1 })
	f.addQuest(95002, { name = "Given Far, Taken Near", startedBy = { { 8002 } }, finishedBy = { { 8003 } }, requiredLevel = 1 })       -- the giver is far, the turn-in NPC is near
	f.addQuest(95003, { name = "Given Near, Taken Far", startedBy = { { 8004 } }, finishedBy = { { 8005 } }, requiredLevel = 1 })       -- the giver is near, the turn-in NPC is far
	f.install()
	local function fresh(done)
		local ns = boot({ char = { level = 6, class = "Paladin", classToken = "PALADIN", race = "Orc", raceToken = "Orc", faction = "Horde" }, synthetic = true, loc = { map = 9001, x = 0.5, y = 0.5, zone = "F" } })
		local W = H.world()
		W.log, W.objectives, W.completed = { { questID = done, title = "Finished", complete = true } }, {}, {}
		ns.Prefs.FinishSetup()
		for _, q in ipairs({ 95002, 95003 }) do if q ~= done then W.completed[q] = true end end      -- only the quest under test competes with the pickup
		return ns
	end
	local ns = fresh(95002)
	local p = ns.State.Recompute()
	check(p.now and p.now.id == "Q:95002:TURN_IN" and math.abs(p.now.target.x - 0.47) < 1e-9, "the hand-in is routed to the NEAR turn-in NPC (30 yd), though the giver is 450 yd away: NOW")
	local card = ns.Presenter.Card(p, ns.State.ctx)
	check(card.now.who == "Near Taker" and card.now.where == "Right here" or card.now.where == "Nearby", "and the card names the turn-in NPC and the distance to THEM")
	local ns2 = fresh(95003)
	local p2 = ns2.State.Recompute()
	check(p2.now and p2.now.id == "Q:95001:ACCEPT", "a near giver with a FAR turn-in NPC is not a near hand-in: the pickup beside you is NOW")
	local ti2
	for _, l in ipairs({ p2.sequence or {}, p2.inProgress or {}, p2.reminders or {} }) do for _, a in ipairs(l) do if a.quest == 95003 and a.kind == "TURN_IN" then ti2 = a end end end
	check(ti2 == nil or math.abs(ti2.target.x - 0.95) < 1e-9, "(its hand-in, where shown, is at the far turn-in NPC, never at the near giver)")
	check(#ns.errors == 0 and #ns2.errors == 0, "no errors")
	f.uninstall()
end
