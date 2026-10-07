-- progression_tests.lua (0.12.0): "technically available" is not "recommended". The planner's funnel (Progression.lua) classifies a quest (level band, seasonal, dungeon, chain) and
-- checks its relevance (the current goal, the chains it belongs to) BEFORE valuing it, and says why. Level 16 player in every scenario unless stated.
-- Fixture-tested: quests, levels and tags here are invented. Whether Forever's data and client give these inputs is checked by the report (see docs/PLANNER_FUNNEL.md).
-- MUTATION-STYLE: each behaviour is also run with Planner.PROGRESSION = false (the stage removed) and must come out DIFFERENT, so the tests prove the stage is what decides.

local H = ...
local check, section, boot = H.check, H.section, H.boot

local NAMES = { "C_GossipInfo", "UnitName", "UnitGUID", "GetQuestID", "GetTitleText", "GetQuestGreenRange" }
local function cleanup() for _, n in ipairs(NAMES) do _G[n] = nil end end

-- q: { id, name, dx, dy (yards from the player), level, req, prereq, event, giverNpc }
H.defMap(9201, 0, 1000, 0, 1000, 1000)       -- the map next door: its west edge is 500 yd from the player's spot on map 9001 (one neighbourhood, two map ids)
local function rec(q)
	local r = { id = q.id, name = q.name or ("Quest " .. q.id), map = q.map or 9001, x = q.x or (0.5 + (q.dx or 0) / 1000), y = q.y or (0.5 + (q.dy or 0) / 1000), req = q.req or 1, level = q.level,
		prereq = q.prereq, event = q.event, giverNpc = q.giverNpc, giverName = q.giverName }
	r.objCoords = { { map = r.map, x = r.x, y = r.y } }
	return r
end
local function world(quests, o)
	o = o or {}
	cleanup()
	local ns = boot({ char = { level = o.level or 16 }, synthetic = true, loc = { map = 9001, x = 0.5, y = 0.5, zone = "Test" } })
	local recs = {}
	for i, q in ipairs(quests) do recs[i] = rec(q) end
	H.attPack(ns, recs, nil)
	local W = H.world()
	W.log, W.objectives = {}, {}
	for _, q in ipairs(o.log or {}) do
		W.log[#W.log + 1] = { questID = q.id, title = q.name or ("Quest " .. q.id), complete = q.complete == true }
		W.objectives[q.id] = { { text = "Do it", type = "monster", finished = q.complete == true, numFulfilled = q.complete and 5 or 1, numRequired = 5 } }
	end
	if o.setup then o.setup(ns) end
	if o.tags then ns.Context.DefaultReader.questTag = function(id) return o.tags[id] end end
	ForeverCodexDB.offers = nil
	ns.Prefs.FinishSetup()
	ns.State.Recompute()
	return ns
end
local function nowId(ns) return ns.State.plan.now and ns.State.plan.now.id end
local function funnelOf(ns, id) for _, e in ipairs(ns.State.plan.diag.funnel.list) do if e.id == id then return e end end end
local function off(ns) ns.Planner.PROGRESSION = false ns.State.Recompute() end
local function on(ns) ns.Planner.PROGRESSION = true ns.State.Recompute() end
local DUNGEON = { id = 81, name = "Dungeon" }

section("progression: a level 16 player is not sent to a level 6 quest just because it is the closest")
do
	local ns = world({ { id = 1, name = "Gray Errand", dx = 20, level = 6 }, { id = 2, name = "Fitting Work", dx = 300, level = 15 } })
	check(nowId(ns) == "Q:2:ACCEPT", "NOW is the level 15 quest 300 yd away, not the level 6 quest 20 yd away  [" .. tostring(nowId(ns)) .. "]")
	local e = funnelOf(ns, "Q:1:ACCEPT")
	check(e and e.verdict == "EXCLUDED" and e.why == "GRAY" and e.band == "GRAY", "the level 6 quest is EXCLUDED as GRAY, with the reason recorded")
	check(ns.State.plan.diag.filtered["progression:GRAY"] == 1, "and counted in the planner's filter totals")
	off(ns)
	check(nowId(ns) == "Q:1:ACCEPT", "MUTATION: with the stage off the nearest quest wins again (so the stage is what changed it)")
	on(ns)
	check(nowId(ns) == "Q:2:ACCEPT", "and back on")
end

section("progression: proximity alone cannot make a terrible quest the top recommendation")
do
	local ns = world({ { id = 1, name = "Gray Errand", dx = 5, level = 5 } })
	check(nowId(ns) == nil and ns.State.plan.diag.reason == "NO_CANDIDATES", "the only quest is gray and beside the player: NOW is empty, not that quest")
	off(ns)
	check(nowId(ns) == "Q:1:ACCEPT", "MUTATION: stage off, the same quest is NOW")
end

section("progression: the level bands (current, low, gray, above) and what each does")
do
	local qs = { { id = 11, level = 16 }, { id = 12, level = 12 }, { id = 13, level = 10 }, { id = 14, level = 7 }, { id = 15, level = 21 }, { id = 16, level = 25 }, { id = 17, level = nil, req = 12 } }
	local ns = world(qs)
	local Pg = ns.Progression
	local function band(l, req) return Pg.Band({ level = l, reqLevel = req }, 16) end
	check(band(16).band == "CURRENT" and band(11).band == "CURRENT", "level 16 and level 11 (5 below) are CURRENT")
	check(band(10).band == "LOW" and band(8).band == "LOW", "level 10 (6 below) and level 8 (8 below) are LOW")
	check(band(7).band == "GRAY" and band(6).band == "GRAY", "level 7 (9 below) and level 6 are GRAY")
	check(band(21).band == "ABOVE" and band(24).band == "ABOVE_FAR", "five over is ABOVE, eight over is ABOVE_FAR")
	local u = band(nil, 12)
	check(u.band == "UNKNOWN" and u.basis:find("only a required level", 1, true), "only a required level: UNKNOWN band, and it says why (nothing is invented)")
	check(Pg.MULT.UNKNOWN == 1 and Pg.MULT.CURRENT == 1 and Pg.MULT.LOW < 1 and Pg.MULT.GRAY < Pg.MULT.LOW, "bands only ever lower a value, gray lowest")
	local ns2 = world({ { id = 13, level = 10, dx = 10 } })
	check(nowId(ns2) == "Q:13:ACCEPT" and ns2.State.plan.diag.items == nil, "a LOW quest is allowed on its own merit when nothing else is there")
	local e = funnelOf(ns2, "Q:13:ACCEPT")
	check(e and e.verdict == "PENALIZED" and e.band == "LOW", "but it is PENALIZED")
	local ns3 = world({ { id = 17, level = nil, req = 12, dx = 10 } })
	check(nowId(ns3) == "Q:17:ACCEPT", "a quest with no known level is not excluded on a guess")
	local ns4 = world({ { id = 15, level = 25, dx = 10 } })
	check(nowId(ns4) == nil and funnelOf(ns4, "Q:15:ACCEPT").why == "TOO_HIGH", "a quest nine levels above the player is rejected as TOO_HIGH without a reason")
end

section("progression: the green range comes from the client when it answers, else a stated default")
do
	local ns = world({ { id = 1, level = 10, dx = 10 } })
	local Pg = ns.Progression
	local g, src = Pg.GreenRange()
	check(g == 8 and src:find("default", 1, true), "no GetQuestGreenRange: the default, and the source says so")
	_G.GetQuestGreenRange = function() return 5 end
	g, src = Pg.GreenRange()
	check(g == 5 and src == "client", "an answering client sets it")
	check(Pg.Band({ level = 10 }, 16).band == "GRAY", "and the band follows (6 below is gray with a green range of 5)")
	_G.GetQuestGreenRange = function() return "bad" end
	check(Pg.GreenRange() == 8, "an unusable answer falls back to the default")
	_G.GetQuestGreenRange = nil
end

section("progression: a required prerequisite overrides the level filter, and only because of its reason")
do
	local ns = world({ { id = 1, name = "Old Start", dx = 15, level = 6 }, { id = 2, name = "Fitting Finish", dx = 400, level = 15, prereq = { 1 } },
		{ id = 3, name = "Dead End", dx = 25, level = 6 } })
	local e1, e3 = funnelOf(ns, "Q:1:ACCEPT"), funnelOf(ns, "Q:3:ACCEPT")
	check(nowId(ns) == "Q:1:ACCEPT", "the gray starter of a chain that leads to a level 15 quest is NOW  [" .. tostring(nowId(ns)) .. "]")
	local ok = false
	for _, r in ipairs(e1 and e1.reasons or {}) do if r == "LEADS_TO_FIT" then ok = true end end
	check(ok, "and the funnel names the reason: LEADS_TO_FIT")
	check(e3 and e3.verdict == "EXCLUDED" and e3.why == "GRAY", "a gray quest with no such reason, equally close, is EXCLUDED")
	local nj = ns.State.plan.diag.nowJudgement
	check(nj and nj.band == "GRAY" and nj.verdict ~= "EXCLUDED" and #nj.reasons > 0, "NOW's judgement is recorded: band, verdict and reasons")
	local ns2 = world({ { id = 1, name = "Old Start", dx = 15, level = 6 }, { id = 2, name = "Far Finish", dx = 400, level = 30, prereq = { 1 } } })
	check(nowId(ns2) == nil, "MUTATION: when what follows it is not appropriate either, the reason disappears and so does the quest")
end

section("progression: a quest the player added, or already holds, is never rejected for its level")
do
	local ns = world({ { id = 1, name = "Gray Errand", dx = 20, level = 6 } }, { setup = function(n) n.Prefs.Add(1) end })
	check(nowId(ns) == "Q:1:ACCEPT", "a gray quest the player added is still NOW (PINNED is a reason)")
	local ns2 = world({ { id = 1, name = "Gray Held", dx = 20, level = 6 }, { id = 2, name = "Fitting Work", dx = 20, level = 15 } }, { log = { { id = 1 } } })
	check(ns2.State.plan.diag.filtered["progression:GRAY"] == nil, "a gray quest already in the log is not rejected")
	local ns3 = world({ { id = 1, name = "Gray Held", dx = 20, level = 6 } }, { log = { { id = 1, complete = true } } })
	check(nowId(ns3) == "Q:1:TURN_IN", "its hand-in is full value: NOW")
	local ns4 = world({ { id = 1, name = "Gray Held", dx = 200, level = 6 }, { id = 2, name = "Fitting Held", dx = 200, level = 15 } }, { log = { { id = 1 }, { id = 2 } } })
	check(nowId(ns4) == "Q:2:OBJECTIVE", "objectives of a gray quest in the log rank below an equally close fitting one")
end

section("progression: seasonal quests stay out of the normal pool unless the player opts in, and are then only routed on a client offer")
do
	local ns = world({ { id = 1, name = "Festival Fun", dx = 20, level = 16, event = true, giverNpc = 700, giverName = "Festival Fan" }, { id = 2, name = "Fitting Work", dx = 300, level = 15 } })
	check(nowId(ns) == "Q:2:ACCEPT" and ns.State.plan.diag.items == nil, "seasonal off: the seasonal quest is not a candidate (filtered as event)")
	local ev = ns.Engine.Candidates(ns.State.ctx)
	check(ev.env.stats.filtered.event == 1, "the engine counts it as filtered: event")
	ns.Prefs.SetIncludeSeasonal(true)
	ns.State.Recompute()
	check(nowId(ns) == "Q:2:ACCEPT", "seasonal on, but nothing says the event is running: the seasonal quest is still NOT NOW")
	local pos = ns.State.plan.diag.possible
	check(pos and pos.list[1] and pos.list[1].why == "SEASONAL_UNPROVEN", "it is a POSSIBLE pickup with the reason SEASONAL_UNPROVEN (unknown availability is not proven availability)")
	-- the client offers it: now it is real
	_G.UnitName = function(u) return u == "npc" and "Festival Fan" or nil end
	_G.UnitGUID = function(u) return u == "npc" and "Creature-0-1-2-3-700-ABCDEF" or nil end
	_G.C_GossipInfo = { GetAvailableQuests = function() return { { questID = 1, title = "Festival Fun", questLevel = 16 } } end, GetActiveQuests = function() return {} end, GetOptions = function() return {} end }
	ns.OfferProbe.OnEvent("GOSSIP_SHOW")
	ns.State.Recompute()
	check(nowId(ns) == "Q:1:ACCEPT", "once the game itself offers it, it can be NOW (it is closer and fits)")
	ns.Prefs.SetIncludeSeasonal(false)
	ns.State.Recompute()
	check(nowId(ns) == "Q:2:ACCEPT", "turning seasonal off removes it again, offer or not")
	cleanup()
	H.slash("seasonal on")
	check(ns.Prefs.IncludeSeasonal() == true, "/qflow seasonal on")
	H.slash("seasonal off")
	check(ns.Prefs.IncludeSeasonal() == false, "/qflow seasonal off")
end

section("progression: available is not the same as recommended (an offered quest can still be rejected)")
do
	local ns = world({ { id = 1, name = "Gray Errand", dx = 20, level = 6, giverNpc = 800, giverName = "Old Hand" }, { id = 2, name = "Fitting Work", dx = 300, level = 15 } })
	_G.UnitName = function(u) return u == "npc" and "Old Hand" or nil end
	_G.UnitGUID = function(u) return u == "npc" and "Creature-0-1-2-3-800-ABCDEF" or nil end
	_G.C_GossipInfo = { GetAvailableQuests = function() return { { questID = 1, title = "Gray Errand", questLevel = 6 } } end, GetActiveQuests = function() return {} end, GetOptions = function() return {} end }
	ns.OfferProbe.OnEvent("GOSSIP_SHOW")
	ns.State.Recompute()
	check(ns.Planner.OfferState({ kind = "ACCEPT", quest = 1, id = "Q:1:ACCEPT" }) == "OBSERVED", "(setup) the game offered the gray quest: its availability is PROVEN")
	check(nowId(ns) == "Q:2:ACCEPT" and funnelOf(ns, "Q:1:ACCEPT").verdict == "EXCLUDED", "and it is still rejected as a recommendation")
	cleanup()
end

section("progression: the current goal (a dungeon in the quest log) changes priorities")
do
	-- no goal: a LOW quest is merely penalised and is NOW when alone
	local alone = world({ { id = 1, name = "Low Errand", dx = 20, level = 9 } })
	check(nowId(alone) == "Q:1:ACCEPT" and alone.State.plan.diag.goal == nil, "no dungeon quest in the log: no goal, and the LOW quest is still allowed")
	-- with a dungeon quest in the log (the game tags it): the same quest needs a reason
	local ns = world({ { id = 1, name = "Low Errand", dx = 20, level = 9 }, { id = 9, name = "Crypt Run", dx = 900, level = 16 } }, { log = { { id = 9 } }, tags = { [9] = DUNGEON } })
	local g = ns.State.plan.diag.goal
	check(g and g.kind == "DUNGEON" and g.count == 1, "the goal is derived from the log: a dungeon quest, as the game tags it")
	local e = funnelOf(ns, "Q:1:ACCEPT")
	check(e and e.verdict == "EXCLUDED" and e.why == "LOW_WITH_GOAL", "the same LOW quest is now rejected: LOW_WITH_GOAL")
	check(nowId(ns) ~= "Q:1:ACCEPT", "so it is not NOW")
	-- mutation: remove the tag answer and the goal vanishes, so does the rejection
	local ns2 = world({ { id = 1, name = "Low Errand", dx = 20, level = 9 }, { id = 9, name = "Crypt Run", dx = 900, level = 16 } }, { log = { { id = 9 } } })
	check(ns2.State.plan.diag.goal == nil and nowId(ns2) == "Q:1:ACCEPT", "MUTATION: with no tag from the client there is no goal (never guessed) and the quest is allowed again")
end

section("progression: goal quests and what leads to them outrank nearby irrelevant work")
do
	-- four ordinary pickups close to the player (a depth-3 plan cannot hold them all plus the hand-in) and a finished dungeon quest 300 yd away
	local function junk() return { { id = 1, dx = -100, dy = 0, level = 14 }, { id = 2, dx = 0, dy = -100, level = 14 }, { id = 3, dx = 0, dy = 100, level = 14 }, { id = 4, dx = -100, dy = 100, level = 14 } } end
	local function withDungeon()
		local q = junk()
		q[#q + 1] = { id = 9, name = "Crypt Report", dx = 300, dy = 0, level = 16 }
		return q
	end
	local function ids(ns) local t = {} for _, s in ipairs(ns.State.plan.sequence) do t[#t + 1] = s.id end return " " .. table.concat(t, " ") .. " " end
	local log = { { id = 9, complete = true } }
	local ns = world(withDungeon(), { log = log, tags = { [9] = DUNGEON } })
	check(nowId(ns) == "Q:9:TURN_IN", "the dungeon quest's hand-in 300 yd away is NOW, ahead of four ordinary pickups beside the player  [" .. tostring(nowId(ns)) .. "]")
	local nj = ns.State.plan.diag.nowJudgement
	check(nj and nj.verdict == "BOOSTED" and nj.reasons[1] == "GOAL_QUEST", "and the report says why: BOOSTED, GOAL_QUEST")
	local ns2 = world(withDungeon(), { log = log })
	check(not ids(ns2):find("Q:9:TURN_IN", 1, true), "MUTATION: with no tag from the client there is no goal, and the same hand-in is not even in the plan (only the pickups are)")
	local ns3 = world(withDungeon(), { log = log, tags = { [9] = DUNGEON } })
	ns3.Planner.PROGRESSION = false
	ns3.State.Recompute()
	check(not ids(ns3):find("Q:9:TURN_IN", 1, true), "MUTATION: with the funnel stage off the goal changes nothing")
	-- a chain step that leads to a dungeon quest the player holds
	local q = junk()
	q[#q + 1] = { id = 5, name = "Lead In", dx = 100, dy = 0, level = 14 }
	q[#q + 1] = { id = 8, name = "Crypt Run", dx = 0, dy = 300, level = 16, prereq = { 5 } }
	local ns4 = world(q, { log = { { id = 8 } }, tags = { [8] = DUNGEON } })
	local e = funnelOf(ns4, "Q:5:ACCEPT")
	local reasons = e and table.concat(e.reasons, ",") or ""
	check(reasons:find("LEADS_TO_DUNGEON", 1, true) ~= nil and e.verdict == "BOOSTED", "a quest whose successor is a dungeon quest is BOOSTED with the reason LEADS_TO_DUNGEON")
	check(nowId(ns4) == "Q:5:ACCEPT", "and it is NOW, ahead of the nearer pickups")
	local ns5 = world(q, { log = { { id = 8 } } })
	check(nowId(ns5) == "Q:1:ACCEPT", "MUTATION: without the goal the nearest pickup is NOW instead")
	local ns6 = world(q, { log = { { id = 8 } }, tags = { [8] = DUNGEON } })
	ns6.Planner.PROGRESSION = false
	ns6.State.Recompute()
	check(ns6.State.plan.diag.funnel.judged == 0 and ns6.State.plan.diag.goal == nil, "MUTATION: with the stage off nothing is judged and there is no goal (the boost above came from the stage)")
end

section("progression: a neighbouring map is part of the neighbourhood (the 0.12.0 Ruins of Lordaeron report)")
do
	-- junk beside the player on map 9001; a finished dungeon quest to hand in 520 yd away on the NEXT map. The old test (same map id) dropped that stop from the plan.
	local quests = { { id = 1, dx = -60, dy = 0, level = 16 }, { id = 2, dx = 0, dy = -60, level = 16 }, { id = 9, name = "Crypt Report", map = 9201, x = 0.02, y = 0.5, level = 17 } }
	-- the planner's whole chosen sequence (the plan's own list shows only NOW / ALSO DO / THEN)
	local function ids(ns) local t = {} for _, id in ipairs(ns.State.plan.diag.sequence or {}) do t[#t + 1] = id end return " " .. table.concat(t, " ") .. " " end
	local ns = world(quests, { log = { { id = 9, complete = true } }, tags = { [9] = DUNGEON } })
	check(ids(ns):find("Q:9:TURN_IN", 1, true) ~= nil, "with a goal, a hand-in on the next map is in the plan  [" .. ids(ns) .. "]")
	local ns2 = world(quests, { log = { { id = 9, complete = true } } })
	check(ids(ns2):find("Q:9:TURN_IN", 1, true) ~= nil, "even with no goal, work 520 yd away on the next map is within the neighbourhood and is planned")
	local ns3 = world(quests, { log = { { id = 9, complete = true } }, setup = function(n) n.Planner.LOCAL_NEAR_YD = 0 end })
	check(not ids(ns3):find("Q:9:TURN_IN", 1, true) and ns3.State.plan.diag.localOnly == true, "MUTATION: with the neighbourhood radius at 0 (the old map-id rule) the same hand-in is dropped as 'not local'")
	local ns4 = world(quests, { log = { { id = 9, complete = true } }, tags = { [9] = DUNGEON }, setup = function(n) n.Planner.LOCAL_NEAR_YD = 0 end })
	check(ids(ns4):find("Q:9:TURN_IN", 1, true) ~= nil, "but goal work is never dropped for being on another map, whatever the radius")
end

section("progression: a quest that survives only by leading to a weakly fitting quest is not a reason")
do
	local Pg = world({}).Progression
	check(Pg.FIT_GAP < Pg.LOW_FROM and Pg.FIT_MULT < 1, "the fit needed for a chain reason is tighter than a LOW band, and such a survivor is discounted")
	-- successor 4 below the player (LOW, not a fit): the gray starter has no reason
	local ns = world({ { id = 1, name = "Old Start", dx = 15, level = 6 }, { id = 2, name = "Weak Finish", dx = 400, level = 12, prereq = { 1 } } })
	check(funnelOf(ns, "Q:1:ACCEPT").verdict == "EXCLUDED", "a gray quest whose successor is only 4 levels below is EXCLUDED")
	local ns2 = world({ { id = 1, name = "Old Start", dx = 15, level = 6 }, { id = 2, name = "Good Finish", dx = 400, level = 14, prereq = { 1 } } })
	local e = funnelOf(ns2, "Q:1:ACCEPT")
	check(e and e.verdict == "PENALIZED" and table.concat(e.reasons, ","):find("LEADS_TO_FIT", 1, true), "one whose successor is 2 below survives, PENALIZED (worth less than the fitting quest itself)")
end

section("progression: the report explains itself")
do
	local ns = world({ { id = 1, name = "Gray Errand", dx = 20, level = 6 }, { id = 2, name = "Fitting Work", dx = 300, level = 15 } })
	local _, lines = ns.Diag.Report()
	local r = table.concat(lines, "\n")
	check(r:find("PLANNER FUNNEL", 1, true) and r:find("Green range 8 (default", 1, true), "the section and the green range with its source")
	check(r:find("EXCLUDED Accept: Gray Errand (GRAY): GRAY", 1, true), "a rejected quest is listed with its band and reason")
	check(r:find("NOW is Accept: Fitting Work: band CURRENT", 1, true), "NOW's band and basis are stated")
	check(r:find("Seasonal / event quests: not in the normal pool", 1, true) and r:find("Goal: none known", 1, true), "seasonal status and goal status are stated")
	check(r:find("Judged 2 action(s)", 1, true), "the count of judged actions")
end

section("progression: no regressions in what the funnel is not about")
do
	local ns = world({ { id = 1, name = "Fitting Work", dx = 100, level = 15 } })
	check(nowId(ns) == "Q:1:ACCEPT" and ns.State.plan.diag.funnel.excluded == 0, "an ordinary appropriate quest is untouched")
	check(#ns.errors == 0, "no errors")
	cleanup()
end

section("navigation: an assumed hand-in at a named NPC gets an arrow from farther away than an objective area (the 0.12.0 report: none at 850 yd)")
do
	local ns = world({ { id = 1, dx = 20, level = 16 } })
	local N, ctx = ns.Navigation, ns.State.ctx
	-- (the fixture map is 1000 yd wide: use a second, wide map for long distances)
	H.defMap(9301, 0, 5000, 0, 10000, 10000)
	local function far(yd, kind, assumed)
		ctx.loc.map, ctx.loc.x, ctx.loc.y, ctx.loc.world = 9301, 0.1, 0.5, nil
		ctx.loc.world = ctx.worldOf(9301, 0.1, 0.5)
		return { id = "T", kind = "TURN_IN", contract = true, targets = { { assumed = assumed, where = { status = "approx", kind = kind, points = { { map = 9301, x = 0.1 + yd / 10000, y = 0.5 } } } } } }
	end
	check(N.Assess(far(850, nil, true), ctx).pin == true, "assumed hand-in at 850 yd: arrow")
	check(N.Assess(far(1400, nil, true), ctx).pin == true, "assumed hand-in at 1400 yd: arrow")
	local r = N.Assess(far(1700, nil, true), ctx)
	check(r.pin == false and r.reason == "APPROX_FAR", "beyond MAX_ASSUMED_YD: no arrow, and it says why")
	check(N.Assess(far(850, "area", false), ctx).pin == false, "an objective AREA at 850 yd: still no arrow (an area centre is not a place)")
	check(N.Assess(far(850, nil, false), ctx).pin == false, "an approximate point that is not an assumed NPC spot: still limited to MAX_APPROX_YD")
	check(N.MAX_ASSUMED_YD > N.MAX_APPROX_YD and N.MAX_ASSUMED_YD < N.MAX_EXACT_YD, "the assumed reach sits between the approximate and the exact reach")
end

section("local work: a quest with no known place and no progress is not 'work here' (the 0.14.0 Sacred Flame report)")
do
	H.defMap(9401, 0, 3000, 0, 1000, 1000)       -- a map 2500+ yd away: not the player's neighbourhood
	-- player on map 9001 with a ready hand-in far away, and an in-log quest whose objective has no place (no objCoords, no turn-in place) and NO progress
	local function setup(progress)
		return function(ns) end
	end
	local function build(started)
		cleanup()
		local ns = boot({ char = { level = 20 }, synthetic = true, production = true, loc = { map = 9001, x = 0.5, y = 0.5, zone = "Test" } })
		H.attPack(ns, { { id = 1, name = "Placeless Work", map = 9001, x = 0.5, y = 0.5, req = 1, level = 20, areaId = nil, zoneMap = 9001 },
			{ id = 2, name = "Ready Hand In", map = 9401, x = 0.5, y = 0.5, req = 1, level = 20, objCoords = { { map = 9401, x = 0.5, y = 0.5 } } } }, nil)
		H.world().log = { { questID = 1, title = "Placeless Work", complete = false }, { questID = 2, title = "Ready Hand In", complete = true } }
		H.world().objectives = { [1] = { { text = "Thing", type = "item", finished = false, numFulfilled = started and 1 or 0, numRequired = 5 } },
			[2] = { { text = "Done", type = "item", finished = true, numFulfilled = 1, numRequired = 1 } } }
		ns.Prefs.FinishSetup()
		ns.State.Recompute()
		return ns
	end
	local ns = build(false)
	local a = ns.State.plan
	check(a.now and a.now.id == "Q:2:TURN_IN", "no progress on the placeless quest: the located hand-in is NOW, not an instruction with no destination  [" .. tostring(a.now and a.now.id) .. "]")
	check(ns.Planner.StartedWork({ objectiveState = { known = true, list = { { have = 0, finished = false } } } }) == false and ns.Planner.StartedWork({ objectiveState = { known = true, list = { { have = 2, finished = false } } } }) == true
		and ns.Planner.StartedWork({ objectiveState = { known = true, list = { { finished = true } } } }) == true and ns.Planner.StartedWork({}) == false, "StartedWork: counts above zero or a finished objective; nothing known is not progress")
	local card = ns.Presenter.Card(a, ns.State.ctx)
	check(card.now and card.now.kind == "TURN_IN", "and the card shows the hand-in")
	local started = build(true)
	check(started.State.plan.now and started.State.plan.now.id == "Q:1:OBJECTIVE" and started.State.plan.diag.reason == "LOCAL_WORK", "MUTATION-pair: once the log shows progress on it, the placeless quest IS local work again (the original rule, unchanged)")
	local sc = started.Presenter.Card(started.State.plan, started.State.ctx)
	check(sc.now and sc.now.noPlace == true and sc.now.whereShort:find("not known", 1, true), "and its NOW row says the place is not known")
end

section("tracker: the 'not on the map' list is the last card and can be minimised (remembered)")
do
	cleanup()
	local ns = boot({ char = { level = 20 }, synthetic = true, production = true, loc = { map = 9001, x = 0.5, y = 0.5, zone = "Test" } })
	H.attPack(ns, { { id = 1, name = "Placeless One", map = 9001, x = 0.5, y = 0.5, req = 1, level = 20 }, { id = 2, name = "Ready Hand In", map = 9001, x = 0.55, y = 0.5, req = 1, level = 20, objCoords = { { map = 9001, x = 0.55, y = 0.5 } } } }, nil)
	H.world().log = { { questID = 1, title = "Placeless One", complete = false }, { questID = 2, title = "Ready Hand In", complete = true } }
	H.world().objectives = { [1] = { { text = "Thing", type = "item", finished = false, numFulfilled = 1, numRequired = 5 } }, [2] = { { text = "Done", type = "item", finished = true, numFulfilled = 1, numRequired = 1 } } }
	ns.Prefs.FinishSetup()
	ns.State.Recompute()
	ns.UI.Open("codex")
	local c = ns.UI.main.codex
	check(ns.Prefs.UnplacedCollapsed() == false and c.unHint.__text ~= "" and c.unRows[1].__text:find("Placeless One", 1, true), "open by default: the hint and the row are shown")
	check(c.unLabel.__text:find("IN YOUR LOG, NOT ON THE MAP  (1)", 1, true), "the header carries the count")
	check(c.unToggle.__text == "[-]", "and a [-] mark")
	-- the click on the header row
	c.unHead.__scripts.OnClick(c.unHead)
	check(ns.Prefs.UnplacedCollapsed() == true and ForeverCodexDB.ui.unplacedCollapsed == true, "clicking the header minimises it and stores that")
	check(c.unHint.__text == "" and c.unRows[1].__text == "" and c.unToggle.__text == "[+]", "only the header remains, with [+]")
	check(c.unLabel.__text:find("(1)", 1, true), "the count stays visible when minimised")
	c.unHead.__scripts.OnClick(c.unHead)
	check(ns.Prefs.UnplacedCollapsed() == false and c.unRows[1].__text:find("Placeless One", 1, true), "clicking again opens it")
	check(#ns.errors == 0, "no errors")
end

section("tracker: the NOW title opens the quest's details for any quest in the log")
do
	cleanup()
	local ns = boot({ char = { level = 20 }, synthetic = true, production = true, loc = { map = 9001, x = 0.5, y = 0.5, zone = "Test" } })
	H.attPack(ns, { { id = 2, name = "Ready Hand In", map = 9001, x = 0.55, y = 0.5, req = 1, level = 20, objCoords = { { map = 9001, x = 0.55, y = 0.5 } } } }, nil)
	H.world().log = { { questID = 2, title = "Ready Hand In", complete = true } }
	H.world().objectives = { [2] = { { text = "Done", type = "item", finished = true, numFulfilled = 1, numRequired = 1 } } }
	ns.Prefs.FinishSetup()
	ns.State.Recompute()
	ns.UI.Open("codex")
	local c = ns.UI.main.codex
	check(ns.State.plan.now and ns.State.plan.now.id == "Q:2:TURN_IN", "(setup) NOW is a located hand-in")
	check(c.nowHits[1] and c.nowHits[1].__shown, "its title has a click area (before 0.14.3 only placeless guidance had one)")
	c.nowHits[1].__scripts.OnClick(c.nowHits[1])
	check(ns.UI.main.detailQuest == 2, "clicking it opens the quest's details")
	c.nowHits[1].__scripts.OnClick(c.nowHits[1])
	check(ns.UI.main.detailQuest == nil, "and clicking again closes them")
end
