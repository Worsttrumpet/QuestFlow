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
	check(ns.Navigation.Target() == nil, "nothing is sent to the arrow or the waypoint")
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

-- ================================================================ deferred turn-ins (a finished quest is not "go back now")

local function unplaced(id, name, have, need, zone)
	local q = Q(id, name, 9001, nil, nil, { zone = zone or "zone-a", giverName = "Giver " .. id })
	q.map, q.x, q.y = nil, nil, nil
	return q, { title = name, objectives = { { text = name .. " thing", have = have, need = need } } }
end
local function handIn(id, name, dx, who)
	return Q(id, name, 9001, 0.5 + dx, 0.5, { giverName = who or ("Taker " .. id) })
end

section("deferred turn-ins: a finished quest waits while work is underway here, and is listed as READY TO TURN IN")
do
	local work, workLog = unplaced(50, "Doom Weed", 9, 10)
	local ready = handIn(60, "Graverobbers", 0.30, "Coleman")
	local ns, W = world(6, 9001, { work, ready }, { log = { [50] = workLog, [60] = { title = "Graverobbers", complete = true } } })
	local p = plan(ns)
	check(p.now and p.now.quest == 50 and p.now.kind == "OBJECTIVE" and p.diag.deferredTurnIn == true, "work underway here stays NOW; the hand-in 300 yd back waits  [" .. tostring(p.now and p.now.id) .. "]")
	local card = ns.Presenter.Card(p, ns.State.ctx)
	check(#card.ready == 1 and card.ready[1].title == "Graverobbers", "the finished quest is listed under READY TO TURN IN")
	check(card.now and card.now.title == "Finish Doom Weed", "and the card's NOW is the work")
	check(card.thenLine == nil, "a hand-in is not shown as THEN either")
	-- the switch
	ns.Planner.DEFER_TURN_INS = false
	local p2 = plan(ns)
	check(p2.now and p2.now.id == "Q:60:TURN_IN", "(proof the rule is what does it) without it the hand-in is NOW")
	ns.Planner.DEFER_TURN_INS = true
	check(#ns.errors == 0, "no errors")
end

section("deferred turn-ins: not forced - with no work underway, or a short walk away, the hand-in is NOW")
do
	-- nothing else to do: the finished quest is simply the best thing to do
	local ready = handIn(60, "Graverobbers", 0.30)
	local ns = world(6, 9001, { ready }, { log = { [60] = { title = "Graverobbers", complete = true } } })
	local p = plan(ns)
	check(p.now and p.now.id == "Q:60:TURN_IN" and p.diag.deferredTurnIn ~= true, "with nothing else going on, the hand-in is NOW")
	check(#ns.Presenter.Card(p, ns.State.ctx).ready == 0, "and it is not also listed as 'ready' (it is NOW)")
	-- a short walk: promoted even with work underway
	local work, workLog = unplaced(50, "Doom Weed", 9, 10)
	local near = handIn(61, "Close hand-in", 0.08)
	local ns2 = world(6, 9001, { work, near }, { log = { [50] = workLog, [61] = { title = "Close hand-in", complete = true } } })
	check(plan(ns2).now.id == "Q:61:TURN_IN", "a hand-in a short walk away (80 yd) is promoted even while work is underway")
	-- work that has not been started is not 'underway': it does not hold a hand-in back
	local idle, idleLog = unplaced(51, "Not started", 0, 10)
	local ns3 = world(6, 9001, { idle, ready }, { log = { [51] = idleLog, [60] = { title = "Graverobbers", complete = true } } })
	local p3 = plan(ns3)
	check(p3.now and p3.now.id == "Q:60:TURN_IN", "a quest with no progress yet does not hold a hand-in back  [" .. tostring(p3.now and p3.now.id) .. "]")
	-- a hand-in the player ADDED themselves is their call
	local work4, work4Log = unplaced(50, "Doom Weed", 9, 10)
	local ns4 = world(6, 9001, { work4, ready }, { log = { [50] = work4Log, [60] = { title = "Graverobbers", complete = true } }, added = { 60 } })
	check(plan(ns4).now.quest == 60, "a quest the player added is never deferred")
	check(#ns.errors == 0 and #ns2.errors == 0 and #ns3.errors == 0 and #ns4.errors == 0, "no errors")
end

section("deferred turn-ins: located objective work on this map defers a far hand-in too, and the ready quests are batched once the work is done")
do
	local obj = Q(70, "Near objective", 9001, 0.56, 0.5, { objCoords = { { map = 9001, x = 0.56, y = 0.5 } }, giverName = "Obj giver" })
	local ready = handIn(60, "Graverobbers", 0.35, "Coleman")
	local ns = world(6, 9001, { obj, ready }, { log = { [70] = { title = "Near objective", objectives = { { text = "Thing", have = 2, need = 6 } } }, [60] = { title = "Graverobbers", complete = true } } })
	local p = plan(ns)
	check(p.now and p.now.id == "Q:70:OBJECTIVE", "a located objective right here is done before the far hand-in  [" .. tostring(p.now and p.now.id) .. "]")
	-- the work finishes: now two ready quests at one NPC are ONE trip
	local a, b = handIn(80, "First ready", 0.35, "Coleman"), handIn(81, "Second ready", 0.352, "Coleman")
	local ns2 = world(6, 9001, { a, b }, { log = { [80] = { title = "First ready", complete = true }, [81] = { title = "Second ready", complete = true } } })
	local p2 = plan(ns2)
	check(p2.now and p2.now.kind == "TURN_IN", "with the work done the hand-ins become NOW")
	local both = 0
	for _, st in ipairs(ns2.State.plan.diag.sequence or {}) do both = both + 1 end
	check(both == 1, "and the two quests at the same NPC are a single stop of the route (one trip)  [" .. both .. " stop]")
	local card = ns2.Presenter.Card(p2, ns2.State.ctx)
	check(#card.ready == 1, "the other finished quest is listed under READY TO TURN IN beside NOW  [" .. #card.ready .. "]")
	check(#ns.errors == 0 and #ns2.errors == 0, "no errors")
end

section("READY TO TURN IN: nearest first, skipped quests left out, plain ASCII, drawn as its own card")
do
	local work, workLog = unplaced(50, "Doom Weed", 9, 10)
	local far = handIn(60, "Far ready", 0.35)
	local nearer = handIn(61, "Nearer ready", -0.30)     -- on the other side of the player: two far hand-ins that are NOT a batch
	local ns, W = world(6, 9001, { work, far, nearer }, { log = { [50] = workLog, [60] = { title = "Far ready", complete = true }, [61] = { title = "Nearer ready", complete = true } } })
	local p = plan(ns)
	local card = ns.Presenter.Card(p, ns.State.ctx)
	check(#card.ready == 2 and card.ready[1].title == "Nearer ready" and card.ready[2].title == "Far ready", "nearest first")
	ns.Prefs.Skip("QT:60")
	p = plan(ns)
	check(#ns.Presenter.Card(p, ns.State.ctx).ready == 1, "a skipped quest is not listed")
	ns.Prefs.Unskip("QT:60")
	plan(ns)
	ns.UI.Open("codex")
	local c = ns.UI.main.codex
	check(c.readyBox.__shown and c.readyLabel.__text == "READY TO TURN IN" and c.readyRows[1].__text:find("Nearer ready", 1, true) and not c.readyRows[1].__text:find("[\128-\255]"), "the window draws it as a card of its own, in plain ASCII")
	check(c.nowTitle.__text == "Finish Doom Weed", "with NOW above it")
	check(c.readyBox.__points[5] < c.nowBox.__points[5], "and READY TO TURN IN below NOW")
	-- nothing ready: no card
	local ns2 = world(6, 9001, { work }, { log = { [50] = workLog } })
	plan(ns2)
	ns2.UI.Open("codex")
	check(not ns2.UI.main.codex.readyBox.__shown, "with nothing finished the card is not drawn")
	check(#ns.errors == 0 and #ns2.errors == 0, "no errors")
end

section("quest log capacity: the 40-quest log is an input; a full log never recommends a new quest, and the count is exposed")
do
	local function manyLog(n, extra)
		local log, quests = {}, {}
		for i = 1, n do
			local id = 1000 + i
			quests[#quests + 1] = Q(id, "Filler " .. i, 9001, nil, nil, { zone = "zone-a" })
			quests[#quests].map, quests[#quests].x, quests[#quests].y = nil, nil, nil
			log[id] = { title = "Filler " .. i, objectives = { { text = "Thing", have = 0, need = 5 } } }
		end
		quests[#quests + 1] = Q(1, "A fresh pickup", 9001, 0.52, 0.5, { giverName = "Someone" })
		return quests, log
	end
	local quests, log = manyLog(39)
	local ns = world(6, 9001, quests, { log = log })
	local p = plan(ns)
	local slots = ns.Presenter.Card(p, ns.State.ctx).slots
	check(slots and slots.used == 39 and slots.max == 40 and slots.free == 1 and not slots.full, "the quest count is exposed: 39/40, one free")
	local hasPickup = false
	for _, a in ipairs(p.sequence) do if a.id == "Q:1:ACCEPT" then hasPickup = true end end
	check(p.now and (p.now.id == "Q:1:ACCEPT" or (p.alsoDo and p.alsoDo.id == "Q:1:ACCEPT") or hasPickup or p.diag.localWork), "with a slot free the pickup is still a normal candidate")
	local quests2, log2 = manyLog(40)
	local ns2 = world(6, 9001, quests2, { log = log2 })
	local p2 = plan(ns2)
	local s2 = ns2.Presenter.Card(p2, ns2.State.ctx).slots
	check(s2 and s2.used == 40 and s2.full and s2.free == 0, "40/40 is reported as full")
	local offered = false
	for _, a in ipairs(p2.sequence) do if a.kind == "ACCEPT" then offered = true end end
	check(not offered and not (p2.now and p2.now.kind == "ACCEPT") and (p2.stats.filtered.logFull or 0) >= 1, "a full log recommends no new quest, and the filter is counted for the report")
	-- a finished quest still holds a slot; handing it in is what frees one (it is still a normal candidate)
	log2[1001] = { title = "Filler 1", complete = true }
	local ns3 = world(6, 9001, quests2, { log = log2 })
	local c3 = ns3.Presenter.Card(plan(ns3), ns3.State.ctx)
	check(c3.slots.full and #c3.ready + (c3.now and c3.now.kind == "TURN_IN" and 1 or 0) >= 1, "a completed quest still counts toward the 40 and is offered as a hand-in")
	-- no readable quest log: nothing is assumed
	check(ns.Presenter.Slots({ logAvailable = false, logCount = 0 }) == nil, "an unreadable quest log gives no count (nothing is invented)")
	local text
	rawset(ns3.UI, "ShowReport", function(t) text = t end)
	H.slash("report")
	check(text and text:find("Quest log: 40/40 quests (0 free) - FULL", 1, true) ~= nil, "/qflow report shows the quest-log count")
	check(#ns.errors == 0 and #ns2.errors == 0 and #ns3.errors == 0, "no errors")
end

section("quest log pressure: with the log nearly full a finished quest is not left waiting; and the report shows the candidate funnel")
do
	local function fillers(n)
		local quests, log = {}, {}
		for i = 1, n do
			local id = 1000 + i
			local q = Q(id, "Filler " .. i, 9001, nil, nil, { zone = "zone-a" })
			q.map, q.x, q.y = nil, nil, nil
			quests[#quests + 1] = q
			log[id] = { title = "Filler " .. i, objectives = { { text = "Thing", have = i == 1 and 3 or 0, need = 5 } } }
		end
		return quests, log
	end
	local ready = handIn(60, "Graverobbers", 0.30, "Coleman")
	-- plenty of room: the finished quest waits behind the work underway
	local q1, l1 = fillers(10)
	q1[#q1 + 1] = ready; l1[60] = { title = "Graverobbers", complete = true }
	local ns1 = world(6, 9001, q1, { log = l1 })
	local p1 = plan(ns1)
	check(p1.now and p1.now.kind == "OBJECTIVE" and p1.diag.deferredTurnIn == true and p1.diag.slotPressure ~= true, "with room in the log the hand-in waits behind work underway")
	-- 39/40: a free slot is worth a hand-in, so it is no longer deferred
	local q2, l2 = fillers(38)
	q2[#q2 + 1] = ready; l2[60] = { title = "Graverobbers", complete = true }
	local ns2 = world(6, 9001, q2, { log = l2 })
	local p2 = plan(ns2)
	check(p2.diag.slotPressure == true and p2.diag.deferredTurnIn ~= true, "at 39/40 the planner no longer defers hand-ins  [" .. tostring(p2.now and p2.now.id) .. "]")
	check(p2.now and p2.now.id == "Q:60:TURN_IN", "and the ready hand-in is NOW (it frees a slot)")
	-- never forced: a log that is full of work but whose only hand-in is across the sea is not sent there
	local over = Q(61, "Overseas", 9003, 0.5, 0.5, { giverName = "Far" })
	local q3, l3 = fillers(38)
	q3[#q3 + 1] = over; l3[61] = { title = "Overseas", complete = true }
	local ns3 = world(6, 9001, q3, { log = l3 })
	local p3 = plan(ns3)
	check(not (p3.now and p3.now.id == "Q:61:TURN_IN"), "an unmeasurable far hand-in is still not forced, even with the log nearly full")
	-- the report's funnel
	local text
	rawset(ns3.UI, "ShowReport", function(t) text = t end)
	H.slash("report")
	check(text and text:find("CANDIDATE FUNNEL", 1, true) and text:find("known quests in the data:", 1, true) and text:find("FUTURE (known, not actionable yet): level too high", 1, true)
		and text:find("CURRENT:", 1, true) and text:find("CONDITIONAL", 1, true), "/qflow report lays out the funnel: known -> not for this character -> FUTURE -> CURRENT -> CONDITIONAL")
	check(#ns1.errors == 0 and #ns2.errors == 0 and #ns3.errors == 0, "no errors")
end

section("report: a hand-in's travel line names the TURN-IN NPC, and READY TO TURN IN is listed")
do
	local f = H.fake.new({ version = "1.0.4" })
	f.mapArea(9001, 9001)
	f.addNpc(8101, { name = "The Giver", spawns = { [9001] = { { 51.0, 50.0 } } }, zoneID = 9001, friendlyToFaction = "H" })
	f.addNpc(8102, { name = "The Taker", spawns = { [9001] = { { 80.0, 50.0 } } }, zoneID = 9001, friendlyToFaction = "H" })
	f.addQuest(97101, { name = "Deliver it", startedBy = { { 8101 } }, finishedBy = { { 8102 } }, requiredLevel = 1 })
	f.install()
	local ns = boot({ char = { level = 6, class = "Paladin", classToken = "PALADIN", race = "Orc", raceToken = "Orc", faction = "Horde" }, synthetic = true, loc = { map = 9001, x = 0.5, y = 0.5, zone = "F" } })
	local W = H.world()
	W.log, W.objectives, W.completed = { { questID = 97101, title = "Deliver it", complete = true } }, {}, {}
	ns.Prefs.FinishSetup()
	ns.State.Recompute()
	local text
	rawset(ns.UI, "ShowReport", function(t) text = t end)
	H.slash("report")
	check(text and text:find("Travel to The Taker", 1, true) and not text:find("Travel to The Giver", 1, true), "the travel line for a hand-in names the turn-in NPC, not the giver")
	-- with other work NOW the finished quest is listed as READY
	W.log[#W.log + 1] = { questID = 97102, title = "Work", complete = false }
	W.objectives[97102] = { { text = "Thing", type = "monster", finished = false, numFulfilled = 2, numRequired = 5 } }
	f.addQuest(97102, { name = "Work", startedBy = { { 8101 } }, finishedBy = { { 8101 } }, requiredLevel = 1, zoneOrSort = 9001 })
	ns.State.Recompute()
	H.slash("report")
	check(text and text:find("READY TO TURN IN:", 1, true) ~= nil, "the report has a READY TO TURN IN line")
	check(#ns.errors == 0, "no errors")
	f.uninstall()
end

section("tracker: a quest-log counter (14/40) on the header line, quiet normally, gold at 38+, red at 40/40")
do
	local function filled(n)
		local quests, log = {}, {}
		for i = 1, n do
			local id = 1000 + i
			local q = Q(id, "Filler " .. i, 9001, nil, nil, { zone = "zone-a" })
			q.map, q.x, q.y = nil, nil, nil
			quests[#quests + 1] = q
			log[id] = { title = "Filler " .. i, objectives = { { text = "Thing", have = 0, need = 5 } } }
		end
		return quests, log
	end
	local function counter(n)
		local q, l = filled(n)
		local ns = world(6, 9001, q, { log = l })
		plan(ns)
		ns.UI.Open("codex")
		return ns, ns.UI.main.codex
	end
	local ns, c = counter(14)
	check(c.slots.__text == "14/40" and c.slots.__justify == "RIGHT", "it reads 14/40, right-aligned on the character line")
	local quiet = c.slots.__color
	local ns2, c2 = counter(39)
	check(c2.slots.__text == "39/40" and c2.slots.__color ~= quiet, "at 39/40 it turns gold")
	local ns3, c3 = counter(40)
	check(c3.slots.__text == "40/40" and c3.slots.__color ~= c2.slots.__color, "at 40/40 it turns red")
	check(c.header.__text:find("Thrall", 1, true) ~= nil, "the character line is still there")
	local ns4 = world(6, 9001, {}, {})
	ns4.State.ctx.logAvailable = false
	ns4.UI.Open("codex")
	check(#ns.errors == 0 and #ns2.errors == 0 and #ns3.errors == 0, "no errors")
end

-- ================================================================ the game's own quest-map points (real report: v0.2.10, Tirisfal)

section("game quest-map points: a quest with no known place gets one from the game's own quest map (provenance 'game', never verified)")
do
	local work, workLog = unplaced(50, "Rear Guard Patrol", 2, 8)
	local ns, W = world(6, 9001, { work }, { log = { [50] = workLog } })
	local p0 = plan(ns)
	check(p0.now and p0.now.quest == 50 and p0.now.target == nil and ns.Navigation.Target() == nil, "(setup) without the game's point the quest has no place: no arrow destination")
	W.questPoints = { [9001] = { { questID = 50, x = 0.56, y = 0.5 } } }
	local p = plan(ns)
	check(p.now and p.now.quest == 50 and p.now.target and math.abs(p.now.target.x - 0.56) < 1e-9 and p.now.target.src == "game" and p.now.target.verified == false, "with it, NOW has a place from the game's quest map, labelled 'game' and unverified")
	check(p.diag.reason ~= "LOCAL_WORK", "it is planned as located work now, not as 'work somewhere here'")
	local tgt = ns.Navigation.Target()
	check(tgt and math.abs(tgt.x - 0.56) < 1e-9, "the arrow has a destination (it no longer disappears for this quest)")
	local card = ns.Presenter.Card(p, ns.State.ctx)
	check(card.now.where ~= nil, "and the card can say how far it is")
	-- the answer is for one map only
	W.questPoints = { [9002] = { { questID = 50, x = 0.56, y = 0.5 } } }
	check(plan(ns).now.target == nil, "a point on another map is not used")
	check(#ns.errors == 0, "no errors")
end

section("game quest-map points: quests the data does not know, and hand-ins whose NPC position is unknown, are placed too")
do
	-- an unknown (Forever-only) quest in the log: no pack knows it
	local ns, W = world(6, 9001, {}, { log = { [91209] = { title = "A new Forever quest", objectives = { { text = "Thing", have = 1, need = 4 } } } } })
	local pU = plan(ns)
	check(pU.now == nil or pU.now.target == nil, "(setup) an unknown quest has no place")
	W.questPoints = { [9001] = { { questID = 91209, x = 0.52, y = 0.5 } } }
	local p = plan(ns)
	check(p.now and p.now.quest == 91209 and p.now.target and p.now.target.src == "game", "an unknown quest is placed from the game's point")
	-- an unknown finished quest: its hand-in is placed (and shown with a distance in READY TO TURN IN)
	local work, workLog = unplaced(50, "Rear Guard Patrol", 2, 8)
	local ns2, W2 = world(6, 9001, { work }, { log = { [50] = workLog, [91282] = { title = "A Second Home", complete = true } } })
	W2.questPoints = { [9001] = { { questID = 91282, x = 0.92, y = 0.5 } } }
	local p2 = plan(ns2)
	local card = ns2.Presenter.Card(p2, ns2.State.ctx)
	check(#card.ready == 1 and card.ready[1].title == "A Second Home" and card.ready[1].where ~= nil, "a finished quest of unknown hand-in place shows how far it is (before: 'distance unknown')")
	check(#ns.errors == 0 and #ns2.errors == 0, "no errors")
end

section("game quest-map points: a known turn-in NPC position is never replaced, and overlap uses the real distance")
do
	local f = H.fake.new({ version = "1.0.4" })
	f.mapArea(9001, 9001)
	f.addNpc(8201, { name = "Giver", spawns = { [9001] = { { 51.0, 50.0 } } }, zoneID = 9001, friendlyToFaction = "H" })
	f.addNpc(8202, { name = "Taker With A Place", spawns = { [9001] = { { 80.0, 50.0 } } }, zoneID = 9001, friendlyToFaction = "H" })
	f.addQuest(97201, { name = "Hand me in", startedBy = { { 8201 } }, finishedBy = { { 8202 } }, requiredLevel = 1 })
	f.install()
	local ns = boot({ char = { level = 6, class = "Paladin", classToken = "PALADIN", race = "Orc", raceToken = "Orc", faction = "Horde" }, synthetic = true, loc = { map = 9001, x = 0.5, y = 0.5, zone = "F" } })
	local W = H.world()
	W.log, W.objectives, W.completed = { { questID = 97201, title = "Hand me in", complete = true } }, {}, {}
	W.questPoints = { [9001] = { { questID = 97201, x = 0.2, y = 0.2 } } }
	ns.Prefs.FinishSetup()
	local p = plan(ns)
	check(p.now and p.now.id == "Q:97201:TURN_IN" and math.abs(p.now.target.x - 0.80) < 1e-9 and p.now.target.src == "questiedb", "the turn-in NPC's own position wins over the game's point")
	f.uninstall()
	-- overlap: with real points, only objectives on the same patch of ground
	local a, aLog = unplaced(50, "Primary work", 5, 8)
	local near, nearLog = unplaced(51, "Near work", 1, 4)
	local far, farLog = unplaced(52, "Far work", 1, 4)
	local ns2, W2 = world(6, 9001, { a, near, far }, { log = { [50] = aLog, [51] = nearLog, [52] = farLog } })
	W2.questPoints = { [9001] = { { questID = 50, x = 0.50, y = 0.55 }, { questID = 51, x = 0.52, y = 0.57 }, { questID = 52, x = 0.95, y = 0.9 } } }
	local p2 = plan(ns2)
	local titles = {}
	for _, it in ipairs(ns2.Overlap.List(p2, ns2.State.ctx)) do titles[#titles + 1] = it.title end
	local flat = table.concat(titles, ",")
	check(p2.now.quest == 50 and flat:find("Near work", 1, true) and not flat:find("Far work", 1, true), "ALSO COMPLETE THIS offers the quest on the same patch of ground, not the one across the zone  [" .. flat .. "]")
	-- the report no longer lists placed quests as 'not placed'
	local text
	rawset(ns2.UI, "ShowReport", function(t) text = t end)
	H.slash("report")
	local np = text and text:match("%-%-%- NOT PLACED.-\n%-%-%- QUEST LOG") or ""
	check(not np:find("Q:50 ", 1, true) and not np:find("Q:51 ", 1, true), "placed quests are not in the NOT PLACED list")
	check(#ns.errors == 0 and #ns2.errors == 0, "no errors")
end

section("real report (v0.2.10, Crusader Outpost): next to two unfinished quests, a hand-in 600 yd away does not pull the player back")
do
	local ns = boot({ char = { level = 10, class = "Paladin", classToken = "PALADIN", race = "Undead", raceToken = "Scourge", faction = "Horde" }, synthetic = true, loc = { map = 9001, x = 0.2, y = 0.5, zone = "Tirisfal" } })
	local war, warLog = unplaced(370, "At War With The Scarlet Crusade", 0, 3)
	local proof, proofLog = unplaced(374, "Proof of Demise", 0, 10)
	local rear = Q(356, "Rear Guard Patrol", 9001, 0.8, 0.5, { giverName = "Deathguard Linnea" })
	H.attPack(ns, { war, proof, rear }, ZONES)
	local W = H.world()
	W.log, W.objectives, W.completed = { { questID = 370, title = "At War With The Scarlet Crusade" }, { questID = 374, title = "Proof of Demise" }, { questID = 356, title = "Rear Guard Patrol", complete = true } }, {}, {}
	W.objectives[370] = { { text = "Scarlet Zealot slain", type = "monster", finished = false, numFulfilled = 0, numRequired = 3 } }
	W.objectives[374] = { { text = "Scarlet Insignia Ring", type = "item", finished = false, numFulfilled = 0, numRequired = 10 } }
	W.questPoints = { [9001] = { { questID = 370, x = 0.22, y = 0.5 }, { questID = 374, x = 0.221, y = 0.5 } } }
	ns.Prefs.FinishSetup()
	local p = plan(ns)
	check(p.now and p.now.kind == "OBJECTIVE" and (p.now.quest == 370 or p.now.quest == 374), "NOW is one of the two quests right here, not the hand-in 600 yd away  [" .. tostring(p.now and p.now.id) .. "]")
	local card = ns.Presenter.Card(p, ns.State.ctx)
	check(#card.ready == 1 and card.ready[1].title == "Rear Guard Patrol", "the finished quest waits under READY TO TURN IN")
	local titles = {}
	for _, it in ipairs(card.also) do titles[#titles + 1] = it.title end
	check(table.concat(titles, ","):find("Proof of Demise", 1, true) or table.concat(titles, ","):find("At War", 1, true), "and the other quest next to it is offered under ALSO COMPLETE THIS  [" .. table.concat(titles, ",") .. "]")
	-- (0.7.6) standing at the objective area's marker is being IN the area: the arrow no longer steers toward the marker (see AreaEvidence)
	check(ns.Navigation.Target() == nil and card.now.dist == "In the objective area", "the player is at the objective area: no arrow toward its marker, and the card says so")
	check(#ns.errors == 0, "no errors")
end

-- ================================================================ holiday / world-event quests (seasonal filter)

section("seasonal filter: holiday and world-event quests (a QuestSort category, from QuestieDB) are not offered; quests in the log or added still are")
do
	local f = H.fake.new({ version = "1.0.4" })
	f.mapArea(9001, 9001)
	for i, p in ipairs({ { 8301, 51.0 }, { 8302, 52.0 }, { 8303, 53.0 }, { 8304, 54.0 }, { 8305, 55.0 }, { 8306, 56.0 } }) do
		f.addNpc(p[1], { name = "NPC " .. i, spawns = { [9001] = { { p[2], 50.0 } } }, zoneID = 9001, friendlyToFaction = "H" })
	end
	f.addQuest(97301, { name = "Highpeak the Elder", startedBy = { { 8301 } }, finishedBy = { { 8301 } }, requiredLevel = 1, zoneOrSort = -366 })     -- Lunar Festival
	f.addQuest(97302, { name = "Greatfather Winter is Here!", startedBy = { { 8302 } }, finishedBy = { { 8302 } }, requiredLevel = 1, zoneOrSort = -22 })  -- Seasonal
	f.addQuest(97303, { name = "A plain local pickup", startedBy = { { 8303 } }, finishedBy = { { 8303 } }, requiredLevel = 1, zoneOrSort = 9001 })
	f.addQuest(97304, { name = "A Paladin class quest", startedBy = { { 8304 } }, finishedBy = { { 8304 } }, requiredLevel = 1, zoneOrSort = -141 })     -- a class category, NOT an event
	f.addQuest(97305, { name = "A professions quest", startedBy = { { 8305 } }, finishedBy = { { 8305 } }, requiredLevel = 1, zoneOrSort = -181 })
	f.addQuest(97306, { name = "Midsummer in the log", startedBy = { { 8306 } }, finishedBy = { { 8306 } }, requiredLevel = 1, zoneOrSort = -369 })
	f.install()
	local function fresh(o)
		local ns = boot({ char = { level = 6, class = "Paladin", classToken = "PALADIN", race = "Orc", raceToken = "Orc", faction = "Horde" }, synthetic = true, loc = { map = 9001, x = 0.5, y = 0.5, zone = "F" } })
		local W = H.world()
		W.log, W.objectives, W.completed = o and o.log or {}, {}, {}
		ns.Prefs.FinishSetup()
		for _, id in ipairs(o and o.added or {}) do ns.Prefs.Add(id) end
		return ns, W
	end
	local function ids(ns)
		local p = ns.State.Recompute()
		local out = {}
		for _, a in ipairs(p.sequence) do if a.quest then out[a.quest] = true end end
		return p, out
	end
	local ns = fresh()
	local p, offered = ids(ns)
	check(not offered[97301] and not offered[97302], "the Lunar Festival and Seasonal quests are not offered")
	check(offered[97303] or p.now and p.now.quest == 97303, "a plain pickup is")
	check((p.stats.filtered.event or 0) == 3, "and the three event quests (Lunar Festival, Seasonal, Midsummer) are counted as filtered for the report  [" .. tostring(p.stats.filtered.event) .. "]")
	local all = {}
	for _, a in ipairs(p.sequence) do all[#all + 1] = a.quest end
	check(ns.QuestieBridge.EVENT_SORTS[-366] and ns.QuestieBridge.EVENT_SORTS[-22] and ns.QuestieBridge.EVENT_SORTS[-369] and not ns.QuestieBridge.EVENT_SORTS[-141] and not ns.QuestieBridge.EVENT_SORTS[-181] and not ns.QuestieBridge.EVENT_SORTS[9001],
		"class (-141) and profession (-181) categories and real areas are not events")
	-- class and profession categories are offered as normal
	local anyClass = ns.Registry.Quest(97304)
	check(anyClass and not anyClass.event and anyClass.sort == -141, "a class quest keeps its category but is not an event")
	-- an event quest the player is already on still shows (it is in the log)
	local ns2, W2 = fresh({ log = { { questID = 97306, title = "Midsummer in the log", complete = false } } })
	W2.objectives[97306] = { { text = "Thing", type = "monster", finished = false, numFulfilled = 1, numRequired = 4 } }
	local p2 = ns2.State.Recompute()
	local seen = false
	for _, a in ipairs(p2.objectives or {}) do if a.quest == 97306 then seen = true end end
	check(seen, "an event quest already in the log is still tracked (only OFFERING new ones is stopped)")
	-- one the player added themselves is their call
	local ns3 = fresh({ added = { 97301 } })
	local p3, offered3 = ids(ns3)
	check(offered3[97301] or (p3.now and p3.now.quest == 97301), "an event quest the player added is offered")
	-- the report says how many were filtered
	local text
	rawset(ns.UI, "ShowReport", function(t) text = t end)
	ns = fresh()
	rawset(ns.UI, "ShowReport", function(t) text = t end)
	ns.State.Recompute()
	H.slash("report")
	check(text and text:find("holiday / world-event quests (only possible while their event runs, so not offered): 3", 1, true) ~= nil, "/qflow report counts them in the candidate funnel")
	check(#ns.errors == 0 and #ns2.errors == 0 and #ns3.errors == 0, "no errors")
	f.uninstall()
end

section("tracker: the pickup line under ALSO DO uses the short distance (no cut-off text)")
do
	local a = { id = "Q:7:ACCEPT", type = "QUEST", kind = "ACCEPT", quest = 7, name = "Escorting Erland", title = "Accept: Escorting Erland" }
	local ns = boot({ char = { level = 6 }, synthetic = true, loc = { map = 9001, x = 0.5, y = 0.5 } })
	check(ns.Overlap.ShortWhere(10) == "here" and ns.Overlap.ShortWhere(100) == "nearby" and ns.Overlap.ShortWhere(1750) == "1750 yd" and ns.Overlap.ShortWhere(4999) == "5000 yd" and ns.Overlap.ShortWhere(5000) == nil and ns.Overlap.ShortWhere(nil) == nil,
		"here / nearby / '1750 yd' and nothing when the distance is unknown or in another area")
end

section("work here: started work within a short walk is finished before leaving the area, in every style (real report: 'fast' sent the player 1800 yd away)")
do
	local function scenario(style)
		local ns = boot({ char = { level = 10, class = "Paladin", classToken = "PALADIN", race = "Undead", raceToken = "Scourge", faction = "Horde" }, synthetic = true, loc = { map = 9001, x = 0.1, y = 0.5, zone = "Tirisfal" } })
		local here = Q(370, "At War With The Scarlet Crusade", 9001, 0.12, 0.5, { zone = "zone-a", giverName = "Zygand", objCoords = { { map = 9001, x = 0.12, y = 0.5 } } })
		local quests = { here }
		for i = 1, 6 do quests[#quests + 1] = Q(500 + i, "Far pickup " .. i, 9001, 0.9 + i * 0.0005, 0.5, { giverName = "Far giver" }) end     -- a rich pickup bundle 800 yd away
		H.attPack(ns, quests, ZONES)
		local W = H.world()
		W.log, W.objectives, W.completed = { { questID = 370, title = "At War With The Scarlet Crusade" } }, {}, {}
		W.objectives[370] = { { text = "Scarlet Zealot slain", type = "monster", finished = false, numFulfilled = 0, numRequired = 3 } }
		ns.Prefs.FinishSetup()
		ns.Prefs.SetStyle(style)
		return ns
	end
	for _, style in ipairs({ "fast", "efficient" }) do
		local ns = scenario(style)
		ns.Planner.WORK_HERE = false
		local before = plan(ns)
		ns.Planner.WORK_HERE = true
		local p = plan(ns)
		check(p.now and p.now.quest == 370 and p.now.kind == "OBJECTIVE", style .. ": the started quest beside the player is NOW  [" .. tostring(p.now and p.now.id) .. "; without the rule: " .. tostring(before.now and before.now.id) .. "]")
		check(#ns.errors == 0, style .. ": no errors")
	end
	-- never against the player's own choices
	local ns2 = scenario("fast")
	ns2.Prefs.Add(501)
	check(plan(ns2).now.quest == 501, "a quest the player added is still NOW (it is their call)")
	local ns3 = scenario("fast")
	check(ns3.Planner.WORK_HERE_YD == 150 and ns3.Planner.WORK_LEAVE_YD == 500, "(the two distances are named constants: 150 yd to be 'here', 500 yd to count as 'leaving')")
	-- far-away started work does not hold the player
	local ns4 = scenario("fast")
	local q = ns4.Registry.Quest(370)
	check(q ~= nil, "(setup)")
end

section("work here: an objective right beside the player is done before running to another quest's objectives far away (real report: v0.2.16)")
do
	local function scenario()
		local ns = boot({ char = { level = 11, class = "Paladin", classToken = "PALADIN", race = "Undead", raceToken = "Scourge", faction = "Horde" }, synthetic = true, loc = { map = 9001, x = 0.3, y = 0.5, zone = "Tirisfal" } })
		local near = Q(369, "A New Plague", 9001, 0.27, 0.5, { zone = "zone-a", giverName = "Johaan", objCoords = { { map = 9001, x = 0.27, y = 0.5 } } })
		local far1 = Q(96897, "The Cult of the Damned", 9001, 0.95, 0.5, { zone = "zone-a", giverName = "Someone", objCoords = { { map = 9001, x = 0.95, y = 0.5 } } })
		local far2 = Q(96898, "Remnants of War", 9001, 0.951, 0.5, { zone = "zone-a", giverName = "Someone", objCoords = { { map = 9001, x = 0.951, y = 0.5 } } })
		local done = Q(374, "Proof of Demise", 9001, 0.9, 0.5, { zone = "zone-a", giverName = "Burgess" })
		local quests, log = { near, far1, far2, done }, { { questID = 369, title = "A New Plague" }, { questID = 96897, title = "The Cult of the Damned" }, { questID = 96898, title = "Remnants of War" }, { questID = 374, title = "Proof of Demise", complete = true } }
		for i = 1, 4 do                                           -- more started quests whose objectives are in the same far place: a rich far stop
			quests[#quests + 1] = Q(96900 + i, "Far extra " .. i, 9001, 0.952 + i * 0.0001, 0.5, { zone = "zone-a", giverName = "Someone", objCoords = { { map = 9001, x = 0.952 + i * 0.0001, y = 0.5 } } })
			log[#log + 1] = { questID = 96900 + i, title = "Far extra " .. i }
		end
		H.attPack(ns, quests, ZONES)
		local W = H.world()
		W.log = log
		W.objectives, W.completed = {}, {}
		for i = 1, 4 do W.objectives[96900 + i] = { { text = "Thing", type = "monster", finished = false, numFulfilled = 1, numRequired = 6 } } end
		W.objectives[369] = { { text = "Vicious Night Web Spider Venom", type = "item", finished = false, numFulfilled = 1, numRequired = 4 } }
		W.objectives[96897] = { { text = "Dark Neophyte slain", type = "monster", finished = false, numFulfilled = 1, numRequired = 8 }, { text = "Dark Enforcer slain", type = "monster", finished = false, numFulfilled = 0, numRequired = 8 } }
		W.objectives[96898] = { { text = "Necrotic Crystal Fragment", type = "item", finished = false, numFulfilled = 1, numRequired = 12 } }
		ns.Prefs.FinishSetup()
		return ns
	end
	local ns = scenario()
	ns.Planner.DEPTH = 1          -- (single-stop plans, as when the nearby stop is not worth chaining: the real report's best plan from A New Plague was 130 s long)
	ns.Planner.WORK_HERE = false
	local before = plan(ns)
	ns.Planner.WORK_HERE = true
	local p = plan(ns)
	check(p.now and p.now.quest == 369, "the objective 30 yd away is NOW, not the quests 750 yd away  [" .. tostring(p.now and p.now.id) .. "; without the rule: " .. tostring(before.now and before.now.id) .. "]")
	check(before.now and before.now.quest ~= 369, "(proof the rule is what does it) without it the plan runs to the far quests  [" .. tostring(before.now and before.now.id) .. "]")
	ns.Planner.DEPTH = 3
	check(#ns.errors == 0, "no errors")
end


-- ================================================================ 0.4.3: the hand-in-can-wait principle (route-level, not UI)
-- READY TO TURN IN = finished but can wait; NOW = the best productive thing at this point in the route. A hand-in is promoted when it is close, on
-- the route, part of a batch, or the log is nearly full; otherwise productive work (anywhere on the route) comes first.

section("hand-in can wait: productive work + a distant lone hand-in -> the hand-in waits (the work need not be close)")
do
	-- the 0.4.1 real-client shape: work 100 yd away, a second quest further on, a lone ready hand-in 1000 yd back
	local w1 = Q(70, "Rear Guard", 9001, 0.60, 0.5, { objCoords = { { map = 9001, x = 0.60, y = 0.5 } }, giverName = "G1" })
	local w2 = Q(71, "At War", 9001, 0.72, 0.5, { objCoords = { { map = 9001, x = 0.72, y = 0.5 } }, giverName = "G2" })
	local ready = handIn(60, "Lich", -1.0, "Bethor")
	local ns = world(6, 9001, { w1, w2, ready }, { log = { [70] = { title = "Rear Guard", objectives = { { text = "Heart", have = 0, need = 1 } } }, [71] = { title = "At War", objectives = { { text = "Friar", have = 0, need = 5 } } }, [60] = { title = "Lich", complete = true } } })
	local p = plan(ns)
	check(p.now and p.now.id == "Q:70:OBJECTIVE" and p.diag.deferredTurnIn ~= false, "NOW is the nearest productive work  [" .. tostring(p.now and p.now.id) .. "]")
	local card = ns.Presenter.Card(p, ns.State.ctx)
	check(#card.ready == 1 and card.ready[1].title == "Lich", "the far hand-in is listed as READY TO TURN IN")
	-- work further away than the hand-in still wins for a lone hand-in off the route
	local far = Q(72, "Far work", 9001, 0.95, 0.5, { objCoords = { { map = 9001, x = 0.95, y = 0.5 } }, giverName = "G3" })
	local ready2 = handIn(61, "Behind", -0.30, "Behind NPC")
	local ns2 = world(6, 9001, { far, ready2 }, { log = { [72] = { title = "Far work", objectives = { { text = "Thing", have = 1, need = 4 } } }, [61] = { title = "Behind", complete = true } } })
	local p2 = plan(ns2)
	check(p2.now and p2.now.id == "Q:72:OBJECTIVE" and p2.diag.deferredTurnIn == true, "the work does not have to be close: a hand-in 300 yd BEHIND waits for work 450 yd ahead  [" .. tostring(p2.now and p2.now.id) .. "]")
	check(#ns.errors == 0 and #ns2.errors == 0, "no errors")
end

section("hand-in can wait: a close hand-in is promoted")
do
	local work = Q(70, "Work", 9001, 0.62, 0.5, { objCoords = { { map = 9001, x = 0.62, y = 0.5 } }, giverName = "G1" })
	local near = handIn(60, "Close", -0.08, "Close NPC")
	local ns = world(6, 9001, { work, near }, { log = { [70] = { title = "Work", objectives = { { text = "Thing", have = 1, need = 4 } } }, [60] = { title = "Close", complete = true } } })
	check(plan(ns).now.id == "Q:60:TURN_IN", "a hand-in 80 yd away is NOW even with productive work available")
	check(#ns.errors == 0, "no errors")
end

section("hand-in can wait: a hand-in naturally on the route to the work is included, not deferred")
do
	-- player at x=.50; hand-in at .70 (200 yd), work at .90 (400 yd): the hand-in is on the straight line there
	local work = Q(70, "Work ahead", 9001, 0.90, 0.5, { objCoords = { { map = 9001, x = 0.90, y = 0.5 } }, giverName = "G1" })
	local onWay = handIn(60, "On the way", 0.20, "Way NPC")
	local ns = world(6, 9001, { work, onWay }, { log = { [70] = { title = "Work ahead", objectives = { { text = "Thing", have = 1, need = 4 } } }, [60] = { title = "On the way", complete = true } } })
	local p = plan(ns)
	check(p.now and p.now.id == "Q:60:TURN_IN" and p.diag.handInOnRoute == true and p.diag.deferredTurnIn ~= true, "the hand-in 200 yd out, on the line to the work 400 yd out, is done first  [" .. tostring(p.now and p.now.id) .. "]")
	local seq = p.diag.sequence or {}
	check(seq[1] == "Q:60:TURN_IN" and seq[2] == "Q:70:OBJECTIVE", "and the route goes hand-in, then the work")
	-- the same hand-in on the OTHER side of the player is a backtrack and waits
	local back = handIn(61, "Backtrack", -0.20, "Back NPC")
	local ns2 = world(6, 9001, { work, back }, { log = { [70] = { title = "Work ahead", objectives = { { text = "Thing", have = 1, need = 4 } } }, [61] = { title = "Backtrack", complete = true } } })
	local p2 = plan(ns2)
	check(p2.now and p2.now.id == "Q:70:OBJECTIVE" and p2.diag.deferredTurnIn == true and p2.diag.handInOnRoute ~= true, "the same distance behind the player is a backtrack: the work comes first")
	check(#ns.errors == 0 and #ns2.errors == 0, "no errors")
end

section("hand-in can wait: several hand-ins near each other are one trip (batched)")
do
	local work = Q(70, "Work", 9001, 0.50, 0.9, { objCoords = { { map = 9001, x = 0.50, y = 0.9 } }, giverName = "G1" })
	-- two hand-ins 100 yd apart, 350 yd to the west (off the line to the work)
	local a, b = handIn(60, "Ready A", -0.35, "NPC A"), handIn(61, "Ready B", -0.35, "NPC B")
	b.y = 0.52
	local log = { [70] = { title = "Work", objectives = { { text = "Thing", have = 1, need = 4 } } }, [60] = { title = "Ready A", complete = true }, [61] = { title = "Ready B", complete = true } }
	local ns = world(6, 9001, { work, a, b }, { log = log })
	local p = plan(ns)
	check(p.now and p.now.kind == "TURN_IN" and p.diag.handInBatched == true and p.diag.deferredTurnIn ~= true, "two hand-ins that are a short walk apart are one trip: the batch is NOW  [" .. tostring(p.now and p.now.id) .. "]")
	-- one of them alone is a lone far hand-in: it waits
	local ns2 = world(6, 9001, { work, a }, { log = { [70] = log[70], [60] = log[60] } })
	local p2 = plan(ns2)
	check(p2.now and p2.now.id == "Q:70:OBJECTIVE" and p2.diag.deferredTurnIn == true, "(proof the batch is what changed it) the same hand-in alone waits  [" .. tostring(p2.now and p2.now.id) .. "]")
	-- two hand-ins on opposite sides of the player are not a batch
	local c = handIn(62, "Ready C", 0.35, "NPC C")
	local ns3 = world(6, 9001, { work, a, c }, { log = { [70] = log[70], [60] = log[60], [62] = { title = "Ready C", complete = true } } })
	local p3 = plan(ns3)
	check(p3.diag.handInBatched ~= true and p3.now.id == "Q:70:OBJECTIVE", "hand-ins far from each other are not a batch  [" .. tostring(p3.now and p3.now.id) .. "]")
	check(#ns.errors == 0 and #ns2.errors == 0 and #ns3.errors == 0, "no errors")
end

section("hand-in can wait: at 38/40 and above the log is nearly full, so the hand-in is not deferred")
do
	local function fill(n)
		local quests, log = {}, {}
		for i = 1, n do
			local id = 2000 + i
			local q = Q(id, "Filler " .. i, 9001, nil, nil, { zone = "zone-a" })
			q.map, q.x, q.y = nil, nil, nil
			quests[#quests + 1] = q
			log[id] = { title = "Filler " .. i, objectives = { { text = "Thing", have = i == 1 and 3 or 0, need = 5 } } }
		end
		return quests, log
	end
	local ready = handIn(60, "Graverobbers", -0.30, "Coleman")
	for _, used in ipairs({ 38, 39, 40 }) do
		-- `used - 1` quests in progress (one of them started) + the ready one = `used` entries in the log
		local q, l = fill(used - 1)
		q[#q + 1] = ready; l[60] = { title = "Graverobbers", complete = true }
		local ns = world(6, 9001, q, { log = l })
		local p = plan(ns)
		check(p.diag.slotPressure == true and p.diag.deferredTurnIn ~= true and p.now.id == "Q:60:TURN_IN", used .. "/40 in the log: no deferral, the hand-in is NOW (it frees a slot)  [" .. tostring(p.now and p.now.id) .. "]")
	end
	-- 37/40: still three free, the lone far hand-in waits
	local q, l = fill(36)
	q[#q + 1] = ready; l[60] = { title = "Graverobbers", complete = true }
	local ns = world(6, 9001, q, { log = l })
	local p = plan(ns)
	check(p.diag.slotPressure ~= true and p.diag.deferredTurnIn == true, "37/40: there is still room, so the hand-in waits")
	check(#ns.errors == 0, "no errors")
end
