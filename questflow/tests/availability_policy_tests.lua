-- availability_policy_tests.lua (0.14.0): an UNKNOWN pickup is an optional, unconfirmed opportunity, never a committed route step.
--   AVAILABLE  the game offered it (OfferProbe OBSERVED)   -> may be NOW / THEN
--   UNKNOWN    no client offer evidence                     -> OPTIONAL (listed / ALSO DO on the way), not a stop
--   HELD       a fresh not-offered observation              -> held back; a STALE one is UNKNOWN again, never a permanent block
-- Quests in the log (objectives, hand-ins) and quests the player added are not pickups and are unaffected.
-- These run in PRODUCTION mode (no legacy switch): the policy is what is under test. Every scenario with the policy switched off must come out DIFFERENT (mutation-style).

local H = ...
local check, section, boot = H.check, H.section, H.boot

local NAMES = { "C_GossipInfo", "UnitName", "UnitGUID", "GetQuestID", "GetTitleText" }
local function cleanup() for _, n in ipairs(NAMES) do _G[n] = nil end end

-- q: { id, name, dx, dy, level, giverNpc, giverName, prereq, turnIn }
local function rec(q)
	local r = { id = q.id, name = q.name or ("Quest " .. q.id), map = 9001, x = 0.5 + (q.dx or 0) / 1000, y = 0.5 + (q.dy or 0) / 1000, req = 1, level = q.level or 8,
		giverNpc = q.giverNpc or (7000 + q.id), giverName = q.giverName or ("Giver " .. q.id), prereq = q.prereq }
	r.objCoords = { { map = 9001, x = r.x, y = r.y } }
	return r
end
local function world(quests, o)
	o = o or {}
	cleanup()
	local ns = boot({ char = { level = o.level or 8 }, synthetic = true, production = true, loc = { map = 9001, x = 0.5, y = 0.5, zone = "Test" } })
	local recs = {}
	for i, q in ipairs(quests) do recs[i] = rec(q) end
	H.attPack(ns, recs, nil)
	local W = H.world()
	W.log, W.objectives = {}, {}
	for _, q in ipairs(o.log or {}) do
		W.log[#W.log + 1] = { questID = q.id, title = q.name or ("Quest " .. q.id), complete = q.complete == true }
		W.objectives[q.id] = { { text = "Do it", type = "monster", finished = q.complete == true, numFulfilled = q.complete and 5 or 1, numRequired = 5 } }
	end
	if o.completed then for _, id in ipairs(o.completed) do W.completed[id] = true end end
	if o.tags then ns.Context.DefaultReader.questTag = function(id) return o.tags[id] end end
	if o.setup then o.setup(ns) end
	ForeverCodexDB.offers = nil
	ns.Prefs.FinishSetup()
	ns.State.Recompute()
	return ns
end
local function npc(name, id)
	_G.UnitName = function(u) return u == "npc" and name or nil end
	_G.UnitGUID = function(u) return u == "npc" and ("Creature-0-1-2-3-" .. id .. "-ABCDEF") or nil end
end
local function offered(ns, quest, title, giverName, giverNpc)
	npc(giverName or ("Giver " .. quest), giverNpc or (7000 + quest))
	_G.C_GossipInfo = { GetAvailableQuests = function() return { { questID = quest, title = title or ("Quest " .. quest), questLevel = 8 } } end, GetActiveQuests = function() return {} end, GetOptions = function() return {} end }
	ns.OfferProbe.OnEvent("GOSSIP_SHOW")
	ns.State.Recompute()
end
local function emptyListing(ns, giverName, giverNpc)
	npc(giverName, giverNpc)
	_G.C_GossipInfo = { GetAvailableQuests = function() return {} end, GetActiveQuests = function() return {} end, GetOptions = function() return {} end }
	ns.OfferProbe.OnEvent("GOSSIP_SHOW")
	ns.State.Recompute()
end
local function seq(ns) local t = {} for _, id in ipairs(ns.State.plan.diag.sequence or {}) do t[#t + 1] = id end return " " .. table.concat(t, " ") .. " " end
local function nowId(ns) return ns.State.plan.now and ns.State.plan.now.id end
local function thenId(ns) return ns.State.plan.thenAction and ns.State.plan.thenAction.id end
local function possible(ns, id) for _, e in ipairs(ns.State.plan.diag.possible and ns.State.plan.diag.possible.list or {}) do if e.id == id then return e end end end
local function reportText(ns) local _, lines = ns.Diag.Report() return table.concat(lines, "\n") end
local function routable(ns, on) ns.Planner.UNKNOWN_PICKUPS_ROUTABLE = on ns.State.Recompute() end

section("availability policy: a pickup the game offered can be a committed step")
do
	local ns = world({ { id = 1, dx = 100 } })
	offered(ns, 1)
	check(ns.Planner.OfferState({ kind = "ACCEPT", quest = 1, id = "Q:1:ACCEPT" }) == "OBSERVED", "(setup) the client offered quest 1")
	check(nowId(ns) == "Q:1:ACCEPT" and seq(ns):find("Q:1:ACCEPT", 1, true), "it is NOW and in the committed sequence")
	check(possible(ns, "Q:1:ACCEPT") == nil, "and it is not merely an optional extra")
end

section("availability policy: an UNKNOWN pickup is not a committed step, whatever its location data says")
do
	local ns = world({ { id = 1, dx = 100 } })
	check(ns.Planner.OfferState({ kind = "ACCEPT", quest = 1, id = "Q:1:ACCEPT" }) == "UNKNOWN", "(setup) no offer evidence: UNKNOWN")
	check(nowId(ns) == nil and not seq(ns):find("Q:1:ACCEPT", 1, true), "100 yd away with a known giver and location: still not NOW and not in the sequence")
	local e = possible(ns, "Q:1:ACCEPT")
	check(e and e.why == "UNKNOWN_AVAILABILITY", "it is kept as an OPTIONAL possible pickup with the reason UNKNOWN_AVAILABILITY (not deleted from the planner's universe)")
	routable(ns, true)
	check(nowId(ns) == "Q:1:ACCEPT", "MUTATION: with the policy switched off the same pickup is NOW again (the policy is what changed it)")
	routable(ns, false)
	check(nowId(ns) == nil, "and back")
	-- a chosen route zone is intent, not availability
	local nsz = world({ { id = 1, dx = 100 } }, { setup = function(n) n.Prefs.SetRouteZone("zone-a") end })
	check(nowId(nsz) == nil, "a route zone the player chose does not make an unknown pickup a committed step")
end

section("availability policy: the exact 0.13.0 shape (NOW offered, THEN unknown)")
do
	local ns = world({ { id = 3301, name = "Offered One", dx = 60 }, { id = 6981, name = "Unknown One", dx = 260 } })
	offered(ns, 3301, "Offered One")
	check(nowId(ns) == "Q:3301:ACCEPT", "NOW is the offered quest")
	check(thenId(ns) ~= "Q:6981:ACCEPT" and not seq(ns):find("Q:6981:ACCEPT", 1, true), "the unknown quest is not THEN and not in the sequence")
	check(possible(ns, "Q:6981:ACCEPT") ~= nil, "it is listed as optional")
	routable(ns, true)
	check(seq(ns):find("Q:6981:ACCEPT", 1, true) ~= nil, "MUTATION: with the policy off it joins the sequence, as in the report")
end

section("availability policy: an unknown pickup right beside the route is an ALSO DO suggestion, labelled, never a stop")
do
	local ns = world({ { id = 1, name = "Offered One", dx = 100 }, { id = 2, name = "Unknown Beside", dx = 106 } })
	offered(ns, 1, "Offered One")
	local p = ns.State.plan
	check(seq(ns):find("Q:1:ACCEPT", 1, true) and not seq(ns):find("Q:2:ACCEPT", 1, true), "only the offered quest is in the committed sequence")
	check(p.alsoDo and p.alsoDo.id == "Q:2:ACCEPT", "the unknown one beside it is the ALSO DO (an optional extra)")
	local r = reportText(ns)
	check(r:find("ALSO DO is the pickup Accept: Unknown Beside: UNKNOWN: no client offer evidence", 1, true), "the report labels it UNKNOWN: no client offer evidence")
	check(r:find("NOW is the pickup Accept: Offered One: AVAILABLE: client offered", 1, true), "and the offered one AVAILABLE: client offered")
	local card = ns.Presenter.Card(p, ns.State.ctx)
	check(card.alsoDo and card.alsoDo.unconfirmed == true and card.alsoDo.offerState == "UNKNOWN", "the ALSO DO card is marked unconfirmed (the tracker adds 'not offered yet' to its dim line)")
	check(card.now and not card.now.unconfirmed, "while the offered NOW is not")
end

section("availability policy: fresh not-offered evidence holds a pickup back; stale evidence is not a permanent block")
do
	local ns = world({ { id = 1, name = "Held One", dx = 100, giverName = "Hub", giverNpc = 7777 } })
	emptyListing(ns, "Hub", 7777)
	check(ns.Planner.OfferState({ kind = "ACCEPT", quest = 1, id = "Q:1:ACCEPT" }) == "NOT_OFFERED", "(setup) the giver was asked and listed nothing")
	check(ns.State.plan.diag.held and ns.State.plan.diag.held.n == 1 and nowId(ns) == nil and possible(ns, "Q:1:ACCEPT") == nil, "it is HELD: not a candidate and not even listed as optional")
	check(reportText(ns):find("HELD (fresh not-offered evidence) 1", 1, true), "the report counts it as HELD")
	-- progress changes the stamp: the old negative is stale
	H.world().char.level = 9
	ns.State.Recompute()
	check(ns.Planner.OfferState({ kind = "ACCEPT", quest = 1, id = "Q:1:ACCEPT" }) == "UNKNOWN", "after a level the old 'not listed' is stale: UNKNOWN again (never a permanent block)")
	check(not (ns.State.plan.diag.held and ns.State.plan.diag.held.n > 0) and possible(ns, "Q:1:ACCEPT") ~= nil and nowId(ns) == nil, "it is released from HELD, and is optional (still not a committed step)")
	offered(ns, 1, "Held One", "Hub", 7777)
	check(nowId(ns) == "Q:1:ACCEPT", "and once the game offers it, it is NOW")
end

section("availability policy: quests in the log, hand-ins and added quests are not pickups")
do
	local ns = world({ { id = 1, name = "Held Objective", dx = 80 } }, { log = { { id = 1 } } })
	check(nowId(ns) == "Q:1:OBJECTIVE", "an objective of a quest you hold is NOW with no offer evidence at all")
	local ns2 = world({ { id = 1, name = "Done", dx = 80 } }, { log = { { id = 1, complete = true } } })
	check(nowId(ns2) == "Q:1:TURN_IN", "a hand-in is NOW with no offer evidence")
	local ns3 = world({ { id = 1, name = "Held Objective", dx = 80, giverName = "Hub", giverNpc = 7777 } }, { log = { { id = 1 } } })
	emptyListing(ns3, "Hub", 7777)
	check(nowId(ns3) == "Q:1:OBJECTIVE", "even a fresh 'not offered' from its giver does not touch a quest you already hold")
	local ns4 = world({ { id = 1, name = "Added", dx = 80 } }, { setup = function(n) n.Prefs.Add(1) end })
	check(nowId(ns4) == "Q:1:ACCEPT", "a quest the player added is their call, not an availability claim")
	check(reportText(ns4):find("NOW is the pickup Added: ADDED by you", 1, true) or reportText(ns4):find("ADDED by you", 1, true), "and the report says it was added by you")
end

section("availability policy: a dungeon goal does not bypass it")
do
	local DUNGEON = { id = 81, name = "Dungeon" }
	local quests = { { id = 5, name = "Lead In", dx = 100, level = 8 }, { id = 8, name = "Crypt Run", dx = 400, level = 8, prereq = { 5 } } }
	local ns = world(quests, { log = { { id = 8 } }, tags = { [8] = DUNGEON } })
	check(ns.State.plan.diag.goal ~= nil, "(setup) there is a dungeon goal")
	check(not seq(ns):find("Q:5:ACCEPT", 1, true), "the pickup that leads to the dungeon quest is not committed while the game has not offered it")
	check(possible(ns, "Q:5:ACCEPT") ~= nil, "it is listed as optional")
	offered(ns, 5, "Lead In")
	check(seq(ns):find("Q:5:ACCEPT", 1, true) ~= nil, "once offered, the goal boost applies and it is committed")
end

section("availability policy: prerequisites and chains still decide what is a candidate")
do
	local quests = { { id = 1, name = "First", dx = 100 }, { id = 2, name = "Second", dx = 120, prereq = { 1 } } }
	local ns = world(quests)
	offered(ns, 2, "Second")
	check(not seq(ns):find("Q:2:ACCEPT", 1, true), "an offered quest whose prerequisite is not done is still not a candidate")
	local ns2 = world(quests, { completed = { 1 } })
	offered(ns2, 2, "Second")
	check(seq(ns2):find("Q:2:ACCEPT", 1, true) ~= nil, "with the prerequisite done and the quest offered it is committed")
	cleanup()
end
