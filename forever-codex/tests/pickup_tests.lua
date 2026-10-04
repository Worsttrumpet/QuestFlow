-- pickup_tests.lua: pickup knowledge (0.7.1): Fix 2 restriction-known versus restriction-unknown pickups, Fix 3 fresh offers as a candidate source, Fix 5 UNKNOWN
-- availability is not AVAILABLE. Stub-client tests of Codex's OWN decisions: they say nothing about what the real Forever client offers.

local H = ...
local check, section, boot = H.check, H.section, H.boot

local function stubNpc(name, id)
	_G.UnitName = function(u) return u == "npc" and name or (u == "player" and "Thrall" or nil) end
	_G.UnitGUID = function(u) return u == "npc" and id and ("Creature-0-1-2-3-" .. id .. "-ABCDEF") or nil end
end
local function clearApis()
	for _, n in ipairs({ "C_GossipInfo", "GetNumAvailableQuests", "GetAvailableTitle", "GetNumActiveQuests", "GetActiveTitle", "GetQuestID", "GetTitleText", "UnitGUID" }) do _G[n] = nil end
end

local function rec(id, name, x, y, o)
	local q = { id = id, name = name, map = 9001, x = x, y = y, req = 1 }
	for k, v in pairs(o or {}) do q[k] = v end
	return q
end

--- A level-10 character at the middle of the 1000 x 1000 yd fixture map with `att` (restriction-carrying fixture pack) and `observed` (observed-pack records).
local function world(att, observed, char)
	local c = { level = 10, class = "Rogue", classToken = "ROGUE" }
	for k, v in pairs(char or {}) do c[k] = v end
	local ns = boot({ char = c, synthetic = true, loc = { map = 9001, x = 0.5, y = 0.5, zone = "Fixture" } })
	clearApis()
	H.attPack(ns, att or {}, { { key = "zone-a", label = "Zone A", map = 9001, quests = #(att or {}) } })
	if observed then
		local recs = {}
		for _, o in ipairs(observed) do recs[o.id] = o end
		ForeverCodex.RegisterPack("quests", "observed:t", { meta = { src = "observed", verified = true, priority = 100, label = "test observed pack" }, zones = {}, quests = recs })
	end
	ns.Prefs.FinishSetup()
	ns.State.Recompute()
	return ns
end
--- An observed-pack record: no class, race, zone or prerequisite fields (the shipped pack has none), a PLAYER position as `pos`.
local function obs(id, name, x, y, giverNpc, giverName)
	return { id = id, name = name, level = 2, objectives = { "" }, giverNpc = giverNpc or (id + 1000), giverName = giverName or ("Giver " .. id), pos = { map = 9001, x = x, y = y } }
end
local function nowId(ns) local p = ns.State.plan return p.now and p.now.id or nil end
local function possibleIds(ns)
	local out = {}
	for _, h in ipairs(ns.State.plan.diag.possible and ns.State.plan.diag.possible.list or {}) do out[h.id] = h end
	return out
end
local function candidateIds(ns)
	local c = ns.Engine.Candidates(ns.Context.Build())
	local out = {}
	for _, a in ipairs(c.candidates) do out[a.id] = true end
	return out
end

local NEAR = rec(1, "Near Pickup", 0.55, 0.5)

-- ================================================================ Fix 2: restriction-known versus restriction-unknown

section("restriction knowledge: a pack shows whether it carries class / race data, and a quest is restriction-known only when a layer covering it does")
do
	local ns = world({ rec(1, "Plain", 0.55, 0.5, { classes = { "ROGUE" } }) }, { obs(500, "Observed Only", 0.9, 0.9) })
	ForeverCodex.RegisterPack("quests", "att:norestrictions", { meta = { src = "att", verified = false, priority = 10 }, zones = {}, quests = { [700] = rec(700, "No Restriction Fields", 0.6, 0.5) } })
	check(ns.Registry.Quest(1).restrictionKnown == true, "a quest covered by a pack that carries class data is restriction-known")
	check(ns.Registry.Quest(500).restrictionKnown == nil, "an observed-pack-only quest is restriction-UNKNOWN (the observed pack has no class or race fields)")
	check(ns.Registry.Quest(700).restrictionKnown == nil, "a quest from a pack with no sign of restriction data is restriction-UNKNOWN too")
	check(ns.Registry.Quest(500) ~= nil and ns.Registry.Quest(500).name == "Observed Only", "the observed data is kept: nothing is discarded or marked invalid")
	-- a live source (QuestieDB) declares that it carries restriction data
	ForeverCodex.RegisterPack("quests", "live:t", { meta = { src = "questiedb", verified = false, priority = 50, restrictions = true }, zones = {}, get = function(id) if id == 500 then return { id = 500, name = "Observed Only" } end end, ids = function() return { 500 } end })
	check(ns.Registry.Quest(500).restrictionKnown == true, "a layer that declares restriction data (QuestieDB) makes the quest restriction-known")
end

section("restriction-unknown pickups: not a far NOW for a Rogue or a Hunter, but a short walk, a fresh offer, a chosen zone or an added quest are fine")
do
	for _, cls in ipairs({ { class = "Rogue", classToken = "ROGUE" }, { class = "Hunter", classToken = "HUNTER" } }) do
		local tag = "[" .. cls.class .. "] "
		local ns = world({ NEAR }, { obs(500, "The Warrior's Path", 0.95, 0.95), obs(501, "Taming the Beast", 0.9, 0.1) }, cls)
		local p = ns.State.plan
		local poss = possibleIds(ns)
		check(nowId(ns) == "Q:1:ACCEPT", tag .. "NOW is the restriction-known pickup nearby, not a far class-less record  [" .. tostring(nowId(ns)) .. "]")
		check(poss["Q:500:ACCEPT"] and poss["Q:501:ACCEPT"] and poss["Q:500:ACCEPT"].why == "RESTRICTION_UNKNOWN", tag .. "the far restriction-unknown pickups are kept as POSSIBLE, with the reason")
		local inSeq = false
		for _, a in ipairs(p.sequence) do if a.quest == 500 or a.quest == 501 then inSeq = true end end
		check(not inSeq, tag .. "and neither is in the route")
		check(p.diag.possible.n == 2 and #ns.errors == 0, tag .. "counted in the diagnostics; no errors")
	end
	-- only restriction-unknown work is left: NOW is nothing, with an honest reason
	local ns = world({}, { obs(500, "The Warrior's Path", 0.95, 0.95) })
	check(nowId(ns) == nil and ns.State.plan.diag.possible and ns.State.plan.diag.possible.n == 1, "when only far restriction-unknown pickups exist, NOW is empty and they are reported as possible")
	-- a short walk (about 100 yd) is allowed
	local nsNear = world({}, { obs(502, "Close By", 0.6, 0.5) })
	check(nowId(nsNear) == "Q:502:ACCEPT", "a restriction-unknown pickup a short walk away can still be NOW")
	-- the limit lifts for stronger evidence or intent
	local nsAdd = world({ NEAR }, { obs(500, "Added By Player", 0.95, 0.95) })
	nsAdd.Prefs.Add(500); nsAdd.State.Recompute()
	check(possibleIds(nsAdd)["Q:500:ACCEPT"] == nil, "a quest the player added is not limited")
	local nsZone = world({ NEAR }, { obs(500, "In Chosen Zone", 0.95, 0.95) })
	nsZone.Prefs.SetRouteZone("zone-a"); nsZone.State.Recompute()
	check(possibleIds(nsZone)["Q:500:ACCEPT"] == nil, "a route zone the player chose lifts the limit inside it")
end

section("a fresh offer from the client lifts the restriction-unknown limit (observed offer = positive evidence)")
do
	local ns = world({ NEAR }, { obs(500, "Offered Quest", 0.95, 0.95, 7001, "Brakk") })
	check(possibleIds(ns)["Q:500:ACCEPT"] ~= nil and nowId(ns) == "Q:1:ACCEPT", "(setup) far, restriction-unknown, no offer evidence: possible only")
	stubNpc("Brakk", 7001)
	_G.GetQuestID = function() return 500 end
	_G.GetTitleText = function() return "Offered Quest" end
	ns.OfferProbe.OnEvent("QUEST_DETAIL")
	ns.State.Recompute()
	check(ns.Planner.OfferState({ kind = "ACCEPT", quest = 500 }) == "OBSERVED", "the client offered it: OBSERVED")
	check(possibleIds(ns)["Q:500:ACCEPT"] == nil and candidateIds(ns)["Q:500:ACCEPT"], "it is now a normal routable pickup")
	clearApis()
end

section("restriction-known filtering is unchanged (class, faction, race, level, prerequisites)")
do
	local ns = world({ rec(10, "Warrior Only", 0.55, 0.5, { classes = { "WARRIOR" } }), rec(11, "Alliance Only", 0.55, 0.5, { faction = "Alliance" }),
		rec(12, "Orc Only", 0.55, 0.5, { races = { "ORC" } }), rec(13, "Too High", 0.55, 0.5, { req = 40 }), rec(14, "Needs Prereq", 0.55, 0.5, { prereq = { 999 } }),
		rec(15, "For Rogues", 0.55, 0.5, { classes = { "ROGUE" } }) })
	local ids = candidateIds(ns)
	check(not ids["Q:10:ACCEPT"] and not ids["Q:11:ACCEPT"] and not ids["Q:12:ACCEPT"] and not ids["Q:13:ACCEPT"] and not ids["Q:14:ACCEPT"], "a Warrior-only, Alliance-only, Orc-only, too-high-level and prerequisite-locked quest are still filtered for this Horde Rogue")
	check(ids["Q:15:ACCEPT"] ~= nil, "and the Rogue quest is offered")
end
