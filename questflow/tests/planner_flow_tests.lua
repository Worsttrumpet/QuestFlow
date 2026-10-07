-- planner_flow_tests.lua: "available is not the same as best right now" (distant pickups wait for objective work already underway) and "a hand-in that opens a quest comes first".
-- General rules over the fixture map: no quest id or name is known to the planner. Stub-client tests of Codex's own decisions.

local H = ...
local check, section, boot = H.check, H.section, H.boot

local function rec(id, name, x, y, o)
	local q = { id = id, name = name, map = 9001, x = 0.5 + x / 1000, y = 0.5 + y / 1000, req = 1 }
	for k, v in pairs(o or {}) do q[k] = v end
	return q
end
local function area(x, y) return { { map = 9001, x = 0.5 + x / 1000, y = 0.5 + y / 1000 } } end
local function world(quests, log, opts)
	opts = opts or {}
	local ns = boot({ char = { level = 10 }, synthetic = true, loc = { map = 9001, x = 0.5, y = 0.5, zone = "F" } })
	H.attPack(ns, quests, { { key = "zone-a", label = "A", map = 9001, quests = #quests } })
	local W = H.world()
	W.log, W.objectives = {}, {}
	local ids = {}
	for id in pairs(log) do ids[#ids + 1] = id end
	table.sort(ids)
	for _, id in ipairs(ids) do
		local e = log[id]
		W.log[#W.log + 1] = { questID = id, title = e.title or ("quest " .. id), complete = e.complete == true }
		W.objectives[id] = { { text = "Do it", type = "monster", finished = e.complete == true, numFulfilled = e.complete and 5 or 1, numRequired = 5 } }
	end
	if opts.setup then opts.setup(ns) end
	ns.Prefs.FinishSetup()
	ns.State.Recompute()
	return ns
end
local function nowId(ns) return ns.State.plan.now and ns.State.plan.now.id end
local function thenId(ns) return ns.State.plan.thenAction and ns.State.plan.thenAction.id end

section("planner flow: a distant new pickup waits while objective work of the quests in the log is underway (and only then)")
do
	local work = rec(1, "Local Cluster", 300, 0, { objCoords = area(300, 0) })
	local pickup = rec(2, "Side Pickup", 150, 200)
	local ns = world({ work, pickup }, { [1] = {} })
	check(nowId(ns) == "Q:1:OBJECTIVE" and thenId(ns) == "Q:2:ACCEPT" and ns.State.plan.diag.deferredPickup == true, "an available pickup 250 yd away, off the path: the work in the log is NOW, the pickup comes after  [" .. tostring(nowId(ns)) .. "]")
	-- with no objective work in the log the pickup is simply the best thing
	local ns2 = world({ pickup }, {})
	check(nowId(ns2) == "Q:2:ACCEPT" and not ns2.State.plan.diag.deferredPickup, "with nothing underway the pickup is NOW")
	-- a pickup close to the player is not deferred
	local ns3 = world({ work, rec(3, "Close Pickup", 60, 20) }, { [1] = {} })
	check(nowId(ns3) == "Q:3:ACCEPT" and not ns3.State.plan.diag.deferredPickup, "a pickup within the near distance is still NOW")
	-- a pickup on the way to the work costs nothing and is not deferred
	local ns4 = world({ work, rec(4, "On The Way", 150, 10) }, { [1] = {} })
	check(nowId(ns4) == "Q:4:ACCEPT" and not ns4.State.plan.diag.deferredPickup, "a pickup on the way to the work still comes first")
	-- a quest the player added is their call
	local ns5 = world({ work, pickup }, { [1] = {} }, { setup = function(n) n.Prefs.Add(2) end })
	check(nowId(ns5) == "Q:2:ACCEPT", "a quest the player added is not deferred")
	-- the rule can be switched off (tests), and the deferred pickup is not lost
	local ns6 = world({ work, pickup }, { [1] = {} }, { setup = function(n) n.Planner.DEFER_PICKUPS = false end })
	check(nowId(ns6) == "Q:2:ACCEPT", "with the rule off the old order returns")
	check(#ns.errors == 0, "no errors")
end

section("planner flow: a hand-in that opens a quest says so (NOW card and READY list), and an opening hand-in is not deferred behind work elsewhere")
do
	local ready = rec(10, "Finished Quest", 400, 0, { giverName = "Hanna" })
	local opened = rec(11, "Follow-up Quest", 420, 10, { prereq = { 10 } })
	local work = rec(12, "Local Work", 0, 100, { objCoords = area(0, 100) })
	-- the hand-in is where the player is: NOW, and the card says what it opens
	local ns = boot({ char = { level = 10 }, synthetic = true, loc = { map = 9001, x = 0.9, y = 0.5, zone = "F" } })
	H.attPack(ns, { ready, opened }, { { key = "zone-a", label = "A", map = 9001, quests = 2 } })
	H.world().log = { { questID = 10, title = "Finished Quest", complete = true } }
	H.world().objectives = { [10] = { { text = "x", finished = true, numFulfilled = 5, numRequired = 5 } } }
	ns.Prefs.FinishSetup(); ns.State.Recompute()
	local card = ns.Presenter.Card(ns.State.plan, ns.State.ctx)
	check(nowId(ns) == "Q:10:TURN_IN" and card.now.detail:find("It opens Follow-up Quest.", 1, true) ~= nil and card.now.unlocks[1] == "Follow-up Quest", "the NOW card for a hand-in says what it opens")
	-- with work elsewhere the READY list carries the same fact
	local ns2 = world({ ready, opened, work }, { [10] = { complete = true }, [12] = {} })
	local c2 = ns2.Presenter.Card(ns2.State.plan, ns2.State.ctx)
	local r
	for _, x in ipairs(c2.ready) do if x.quest == 10 then r = x end end
	check((r and r.unlocks == 1) or nowId(ns2) == "Q:10:TURN_IN", "READY TO TURN IN says it opens 1 more quest")
	-- a hand-in that opens nothing carries no "opens" flag
	local ns3 = world({ ready, work }, { [10] = { complete = true }, [12] = {} })
	check(not ns3.State.plan.diag.handInOpens, "nothing opened: no flag")
end
