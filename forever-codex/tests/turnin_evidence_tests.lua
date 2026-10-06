-- turnin_evidence_tests.lua (0.8.4): a location is a routable hand-in only when the data says it belongs to the NPC who takes the quest back. Q264 "Until Death Do Us Part" is the shape: the
-- giver stands in one city, the hand-in is in another zone, and Codex used to borrow the giver's spot as an "assumed" hand-in and send the player there. Now:
--   a known turn-in NPC with a position       -> that place (never the giver's)
--   the data says giver and turn-in are the same NPC -> the giver's place (QuestieDB's claim, unverified, approximate)
--   a known turn-in NPC without a position    -> no location
--   no turn-in data at all (ATT, or a finisher that is not a creature) -> no location; the existing fallback (READY row, details card) takes over
-- Stub-client tests of Codex's own logic; the real Q264 record in QuestieDB on Forever has not been seen.

local H = ...
local check, section, boot = H.check, H.section, H.boot

local function qWorld(f, log, completed)
	f.mapArea(9001, 9001)
	f.install()
	local ns = boot({ char = { level = 10, class = "Paladin", classToken = "PALADIN", race = "Orc", raceToken = "Orc", faction = "Horde" }, synthetic = true, loc = { map = 9001, x = 0.5, y = 0.5, zone = "Fixture" } })
	local W = H.world()
	W.log, W.objectives, W.completed = {}, {}, {}
	for _, id in ipairs(log) do W.log[#W.log + 1] = { questID = id, title = "quest " .. id, complete = true } end
	for _, id in ipairs(completed or {}) do W.completed[id] = true end
	ns.Prefs.FinishSetup()
	ns.Prefs.SetNavigation(true)
	ns.State.Recompute()
	return ns, W
end
local function find(plan, id)
	for _, l in ipairs({ plan.sequence or {}, plan.inProgress or {}, plan.reminders or {} }) do
		for _, a in ipairs(l) do if a.id == id then return a end end
	end
end

section("turn-in evidence: no turn-in data (Q264 shape) is NOT the giver's spot")
do
	local f = H.fake.new({ version = "1.0.4" })
	f.addNpc(7001, { name = "Clarice-like Giver", spawns = { [9001] = { { 60.0, 50.0 } } }, zoneID = 9001, friendlyToFaction = "H" })
	f.addQuest(97264, { name = "Until Death Like", startedBy = { { 7001 } }, finishedBy = { {}, { 555 } }, requiredLevel = 1 })       -- the finisher is a world object: no creature, no position
	local ns, W = qWorld(f, { 97264 })
	local v = ns.Registry.Quest(97264)
	check(v.giverName == "Clarice-like Giver" and v.loc and math.abs(v.loc.x - 0.6) < 1e-9 and v.turnIn == nil, "(setup) the giver has a position and nothing names who takes the quest back")
	local p = ns.State.plan
	local a = find(p, "Q:97264:TURN_IN")
	check(a ~= nil and a.target == nil and a.noLocation == true, "the hand-in has NO location: the giver's position is not borrowed")
	local t = a.targets[1]
	check(t.role == "TURN_IN" and t.where.status == "unknown" and t.where.points == nil and t.assumed ~= true and t.entity.kind == "unknown", "the contract says so: unknown, no coordinates, no assumed giver entity")
	check(a.giver == nil and a.turnInNpc == nil, "and the giver is not named as the hand-in NPC")
	check(table.concat(a.lines, "\n"):find("not assumed", 1, true) ~= nil and not table.concat(a.lines, "\n"):find("Location:", 1, true), "the text says why, and prints no location")
	local inReminders = false
	for _, r in ipairs(p.reminders) do if r.id == "Q:97264:TURN_IN" then inReminders = true end end
	check(inReminders, "the planner holds it as a reminder (no usable location), never routed")
	local inSeq = false
	for _, s in ipairs(p.sequence) do if s.id == "Q:97264:TURN_IN" or s.forId == "Q:97264:TURN_IN" then inSeq = true end end
	check(p.now == nil and not inSeq, "it is not NOW and no travel leg is planned to the giver's spot")
	check(ns.Navigation.Target() == nil and W.waypointCalls == 0, "no arrow and no waypoint")
	-- the existing fallback: guidance names the quest and says there is no arrow; the details card explains it
	local card = ns.Presenter.Card(p, ns.State.ctx)
	check(card.guidance == true and card.now.kind == "TURN_IN" and card.now.unplaced == true and card.now.dist == nil and card.now.where == nil, "the NOW card is the guidance fallback, with no distance or place")
	check(card.now.who:find("no arrow", 1, true) ~= nil, "and it says there is no arrow")
	local d = ns.Presenter.QuestDetail(97264, card, ns.State.ctx)
	check(d and d.note == "Codex has no usable map position for this quest, so there is no arrow.", "the details card carries the no-arrow explanation")
	f.uninstall()
end

section("turn-in evidence: the giver IS the turn-in NPC: the giver's spot is the hand-in (QuestieDB's claim, unverified)")
do
	local f = H.fake.new({ version = "1.0.4" })
	f.addNpc(7101, { name = "Same Person", spawns = { [9001] = { { 60.0, 50.0 } } }, zoneID = 9001, friendlyToFaction = "H" })
	f.addQuest(97101, { name = "There And Back", startedBy = { { 7101 } }, finishedBy = { { 7101 } }, requiredLevel = 1 })
	local ns = qWorld(f, { 97101 })
	local a = find(ns.State.plan, "Q:97101:TURN_IN")
	check(a and a.target and math.abs(a.target.x - 0.6) < 1e-9 and a.noLocation == false, "routable at the giver's position")
	local t = a.targets[1]
	check(t.where.status == "approx" and t.assumed == true and t.prov.src == "questiedb" and t.prov.verified == false and a.verified == false, "approximate, flagged, and still QuestieDB and unverified")
	check(ns.State.plan.now and ns.State.plan.now.id == "Q:97101:TURN_IN", "it is a normal NOW")
	f.uninstall()
end

section("turn-in evidence: a different turn-in NPC wins; one without a position is no location at all")
do
	local f = H.fake.new({ version = "1.0.4" })
	f.addNpc(7201, { name = "Recruiter", spawns = { [9001] = { { 51.0, 50.0 } } }, zoneID = 9001, friendlyToFaction = "H" })           -- giver, right beside the player
	f.addNpc(7202, { name = "Officer", spawns = { [9001] = { { 90.0, 50.0 } } }, zoneID = 9001, friendlyToFaction = "H" })
	f.addNpc(7203, { name = "Nameless Officer" })                                                                                      -- known, no position
	f.addQuest(97201, { name = "Report In", startedBy = { { 7201 } }, finishedBy = { { 7202 } }, requiredLevel = 1 })
	f.addQuest(97202, { name = "Report Nowhere", startedBy = { { 7201 } }, finishedBy = { { 7203 } }, requiredLevel = 1 })
	local ns = qWorld(f, { 97201, 97202 })
	local p = ns.State.plan
	local a = find(p, "Q:97201:TURN_IN")
	check(a and a.target and math.abs(a.target.x - 0.9) < 1e-9 and a.giver == "Officer", "different NPCs: the hand-in is the OFFICER's position, not the giver's beside the player")
	check(a.targets[1].assumed ~= true and a.targets[1].where.status == "known" and a.targets[1].prov.verified == false, "known (the data's claim), not assumed, never verified")
	local b = find(p, "Q:97202:TURN_IN")
	check(b and b.target == nil and b.noLocation == true and b.targets[1].where.status == "unknown" and b.giver == "Nameless Officer", "a known turn-in NPC with no position: no location, and the OFFICER is named, not the giver")
	check(p.now == nil or p.now.quest ~= 97202, "it is never NOW")
	local ready = {}
	for _, r in ipairs(ns.Presenter.Card(p, ns.State.ctx).ready or {}) do ready[r.quest] = r end
	check(ready[97202] == nil or (ready[97202].placed == false and ready[97202].distText == nil), "and it shows no distance")
	f.uninstall()
end

section("turn-in evidence: ATT carries no turn-in field, so an ATT-only hand-in has no location; the game's own quest-map point still counts")
do
	local ns = boot({ char = { level = 10 }, synthetic = true, loc = { map = 9001, x = 0.5, y = 0.5, zone = "Fixture" } })
	H.attPack(ns, { { id = 1, name = "ATT Only", map = 9001, x = 0.6, y = 0.5, giverNpc = 11, giverName = "Some Giver", turnIn = false } }, nil)
	local W = H.world()
	W.log, W.objectives, W.completed = { { questID = 1, title = "ATT Only", complete = true } }, {}, {}
	ns.Prefs.FinishSetup(); ns.Prefs.SetNavigation(true)
	ns.State.Recompute()
	local a = find(ns.State.plan, "Q:1:TURN_IN")
	check(a and a.target == nil and a.noLocation == true and ns.State.plan.now == nil and ns.Navigation.Target() == nil, "an ATT-only hand-in is not routed to the giver")
	-- the game's own quest map says where the hand-in is: real client evidence, used (approximate, not verified)
	W.questPoints = { [9001] = { { questID = 1, x = 0.8, y = 0.5 } } }
	ns.State.Recompute()
	local b = find(ns.State.plan, "Q:1:TURN_IN")
	check(b and b.target and b.target.src == "game" and math.abs(b.target.x - 0.8) < 1e-9 and b.verified == false, "the game's quest-map point is the hand-in place, labelled as such")
	check(ns.State.plan.now and ns.State.plan.now.id == "Q:1:TURN_IN", "and then it is a normal stop")
	-- a fixture that says the NPC is the same one keeps the old behaviour (so the rule is what changed it)
	local ns2 = boot({ char = { level = 10 }, synthetic = true, loc = { map = 9001, x = 0.5, y = 0.5, zone = "Fixture" } })
	H.attPack(ns2, { { id = 1, name = "ATT Same", map = 9001, x = 0.6, y = 0.5, giverNpc = 11, giverName = "Some Giver", turnIn = { npc = 11, atGiver = true } } }, nil)
	local W2 = H.world()
	W2.log, W2.objectives, W2.completed = { { questID = 1, title = "ATT Same", complete = true } }, {}, {}
	ns2.Prefs.FinishSetup()
	ns2.State.Recompute()
	check(ns2.State.plan.now and ns2.State.plan.now.id == "Q:1:TURN_IN", "(proof) with the same-NPC fact in the data the same quest routes to the giver")
	check(#ns.errors == 0 and #ns2.errors == 0, "no errors")
end
