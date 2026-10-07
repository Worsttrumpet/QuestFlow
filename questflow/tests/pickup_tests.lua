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
	local ns = boot({ char = c, synthetic = true, production = true, loc = { map = 9001, x = 0.5, y = 0.5, zone = "Fixture" } })
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

-- ================================================================ Fix 3: fresh offers are a candidate source

local function detail(ns, qid, title, npc, npcId)
	stubNpc(npc, npcId)
	_G.GetQuestID = function() return qid end
	_G.GetTitleText = function() return title end
	ns.OfferProbe.OnEvent("QUEST_DETAIL")
	_G.GetQuestID, _G.GetTitleText = nil, nil
end
local function listing(ns, entries, npc, npcId)
	stubNpc(npc, npcId)
	_G.C_GossipInfo = { GetAvailableQuests = function() return entries end, GetActiveQuests = function() return {} end, GetOptions = function() return {} end }
	ns.OfferProbe.OnEvent("GOSSIP_SHOW")
end
local function offeredIn(ns, qid)
	local n, found = 0, nil
	for _, a in ipairs(ns.State.plan.reminders) do if a.quest == qid and a.offered then n = n + 1; found = a end end
	return n, found
end

section("offers: a quest the client offers through QUEST_DETAIL becomes an 'offered here' action even though no pack knows it, with no location")
do
	local ns = world({ NEAR }, nil)
	check(select(1, offeredIn(ns, 94001)) == 0, "(setup) nothing offered yet")
	detail(ns, 94001, "What Comes Next", "Valennia Stormfist", 8001)
	ns.State.Recompute()
	local n, a = offeredIn(ns, 94001)
	check(n == 1 and a.kind == "ACCEPT" and a.name == "What Comes Next" and a.giver == "Valennia Stormfist", "an ACCEPT action named by the client's title and the NPC who offered it")
	check(a.target == nil and a.noLocation == true and ns.Planner.Locate(a) == nil, "it has NO target: no coordinate was invented (the offer record carries none)")
	check(a.state == "AVAILABLE" and a.stateWhy == "CLIENT_OFFER", "its availability is the client's own offer")
	local c = ns.Presenter.Card(ns.State.plan, ns.State.ctx)
	local row
	for _, r in ipairs(c.also) do if r.quest == 94001 then row = r end end
	check(row and row.title == "Accept What Comes Next" and row.npc == "Valennia Stormfist" and row.offered and row.why == "Offered to you by Valennia Stormfist.", "ALSO PICK UP shows it with the NPC and no place")
	check(nowId(ns) == "Q:1:ACCEPT", "NOW is unchanged: the offer is an extra, not a re-ranking")
	check(#ns.errors == 0, "no errors")
	clearApis()
end

section("offers: with nothing else to route, an offered quest is the NOW card (guidance: the NPC, no place, no arrow)")
do
	local ns = world({}, nil)
	detail(ns, 94002, "The Earthen Ring", "Valennia Stormfist", 8001)
	ns.State.Recompute()
	local c = ns.Presenter.Card(ns.State.plan, ns.State.ctx)
	check(ns.State.plan.now == nil and c.guidance == true and c.now.title == "Accept The Earthen Ring" and c.now.kind == "ACCEPT", "the card names the offered quest instead of 'Nothing to recommend'")
	check(c.now.who == "Valennia Stormfist" and c.now.detail:find("no arrow", 1, true) ~= nil, "with the NPC and an honest 'no arrow'")
	check(ns.Navigation.Target() == nil and H.world().waypointCalls == 0, "no waypoint or arrow")
	clearApis()
end

section("offers: a complete available list from an NPC works the same, and repeated events never duplicate it")
do
	local ns = world({ NEAR }, nil)
	for _ = 1, 4 do listing(ns, { { questID = 94003, title = "Return to Valanaar" } }, "Hawk-Eye", 8002) end
	for _ = 1, 3 do detail(ns, 94003, "Return to Valanaar", "Hawk-Eye", 8002) end
	ns.State.Recompute(); ns.State.Recompute()
	check(select(1, offeredIn(ns, 94003)) == 1, "seven events and two recomputes: exactly ONE candidate for the quest")
	local count = 0
	for _, l in ipairs({ ns.State.plan.reminders, ns.State.plan.inProgress }) do for _, a in ipairs(l) do if a.quest == 94003 then count = count + 1 end end end
	check(count >= 1 and select(1, offeredIn(ns, 94003)) == 1, "(and the plan lists it once as a reminder)")
	local rows = 0
	for _, r in ipairs(ns.Presenter.Card(ns.State.plan, ns.State.ctx).also) do if r.quest == 94003 then rows = rows + 1 end end
	check(rows == 1, "one ALSO PICK UP row")
	clearApis()
end

section("offers: accepting the quest moves it into the normal active pipeline; a turn-in then a new offer works; a quest a pack knows is not duplicated")
do
	local ns = world({ NEAR }, nil)
	detail(ns, 94004, "What Comes Next", "Valennia Stormfist", 8001)
	ns.State.Recompute()
	check(select(1, offeredIn(ns, 94004)) == 1, "(setup) offered")
	-- the player accepts it: it is in the quest log now
	local W = H.world()
	W.log[#W.log + 1] = { questID = 94004, title = "What Comes Next", complete = false }
	W.objectives = { [94004] = { { text = "Speak with Halaan Hawk-Eye", type = "event", finished = false, numFulfilled = 0, numRequired = 1 } } }
	ns.State.Recompute()
	check(select(1, offeredIn(ns, 94004)) == 0, "once accepted it is no longer an offer")
	local active
	for _, l in ipairs({ ns.State.plan.reminders, ns.State.plan.inProgress, ns.State.plan.objectives }) do for _, a in ipairs(l) do if a.quest == 94004 and a.kind == "OBJECTIVE" then active = a end end end
	check(active and active.objectiveState and active.objectiveState.list[1].text == "Speak with Halaan Hawk-Eye", "it is an ACTIVE objective now, with the quest log's own words (the normal pipeline)")
	-- it is completed and handed in: the progression moves on, and the next quest the NPC offers appears
	W.log = {}
	W.completed[94004] = true
	ns.Journey.OnQuestTurnedIn(94004, 100)
	ns.State.Recompute()
	check(select(1, offeredIn(ns, 94004)) == 0, "the handed-in quest is not offered again")
	detail(ns, 94005, "The Anchors of Zephras", "Halaan Hawk-Eye", 8003)
	ns.State.Recompute()
	check(select(1, offeredIn(ns, 94005)) == 1, "the follow-up the next NPC offers enters the pipeline")
	-- a quest a pack knows already has its normal ACCEPT action: the offer source adds nothing
	local ns2 = world({ rec(300, "Known Quest", 0.6, 0.5, { giverNpc = 8100, giverName = "Known Giver" }) }, nil)
	detail(ns2, 300, "Known Quest", "Known Giver", 8100)
	ns2.State.Recompute()
	local copies = 0
	for _, l in ipairs({ ns2.State.plan.reminders, ns2.State.plan.sequence }) do for _, a in ipairs(l) do if a.quest == 300 and a.kind == "ACCEPT" then copies = copies + 1 end end end
	check(select(1, offeredIn(ns2, 300)) == 0 and copies == 1, "a quest the data knows is not duplicated by its offer")
	clearApis()
end

section("offers: an offer is only current at the progression it was seen at, and a newer complete listing that omits it withdraws it")
do
	local ns = world({ NEAR }, nil)
	detail(ns, 94006, "Stale Soon", "Valennia Stormfist", 8001)
	ns.State.Recompute()
	check(select(1, offeredIn(ns, 94006)) == 1, "(setup) offered")
	H.world().char.level = 11                              -- the character moved on
	ns.State.Recompute()
	check(select(1, offeredIn(ns, 94006)) == 0, "a level later the old offer is no longer treated as current")
	H.world().char.level = 10
	ns.State.Recompute()
	local ns2 = world({ NEAR }, nil)
	detail(ns2, 94007, "Withdrawn", "Valennia Stormfist", 8001)
	listing(ns2, {}, "Valennia Stormfist", 8001)         -- the same NPC, asked again at the same progression, lists nothing
	ns2.State.Recompute()
	check(select(1, offeredIn(ns2, 94007)) == 0, "the same NPC now listing nothing withdraws the offer")
	local ns3 = world({ NEAR }, nil)
	detail(ns3, 94008, "Already Done", "Valennia Stormfist", 8001)
	H.world().completed[94008] = true
	ns3.State.Recompute()
	check(select(1, offeredIn(ns3, 94008)) == 0, "a quest already completed is never offered")
	clearApis()
end

-- ================================================================ Fix 5: UNKNOWN availability is not AVAILABLE

local function far(id, name, extra) return rec(id, name, 0.95, 0.95, extra) end        -- about 636 yd from the middle of the fixture map

section("unknown availability: a far pickup the client has not offered is possible, never NOW, even with a known location, a good value and met prerequisites")
do
	-- Q10 is far, has a known giver coordinate, no requirements and unlocks three follow-ups (a high value); Q1 is a plain pickup 100 yd away
	local ns = world({ NEAR, far(10, "Far Chain Start", { giverNpc = 8010, giverName = "Far Giver" }), rec(11, "Follow One", 0.95, 0.9, { prereq = { 10 } }),
		rec(12, "Follow Two", 0.9, 0.95, { prereq = { 10 } }), rec(13, "Follow Three", 0.9, 0.9, { prereq = { 10 } }) })
	local poss = possibleIds(ns)
	check(nowId(ns) == "Q:1:ACCEPT", "NOW is the near pickup, not the far chain start with its known location and unlocks  [" .. tostring(nowId(ns)) .. "]")
	check(poss["Q:10:ACCEPT"] and poss["Q:10:ACCEPT"].why == "UNKNOWN_AVAILABILITY", "the far pickup is kept as possible, with the reason")
	check(ns.Planner.OfferState({ kind = "ACCEPT", quest = 10 }) == "UNKNOWN", "its offer state is UNKNOWN: nothing was lifted or invented")
	local inSeq = false
	for _, a in ipairs(ns.State.plan.sequence) do if a.quest == 10 then inSeq = true end end
	check(not inSeq, "it is not in the route")
	-- alone, far, unknown: NOW is empty and the empty card says so
	local ns2 = world({ far(10, "Far Only", { giverNpc = 8010, giverName = "Far Giver" }) })
	local c = ns2.Presenter.Card(ns2.State.plan, ns2.State.ctx)
	local said = false
	for _, l in ipairs(c.empty and c.empty.lines or {}) do if l:find("1 pickup Quest Flow knows of is far away and not confirmed by the game", 1, true) then said = true end end
	check(nowId(ns2) == nil and said, "alone, NOW is empty and the card says one far pickup is not confirmed")
	check(possibleIds(ns2)["Q:10:ACCEPT"] ~= nil, "UNKNOWN stays discoverable: it is listed in the diagnostics")
	local lines = table.concat(ns2.Diag.PlaytestLines(ns2.Diag.Snapshot(), {}), "\n")
	check(lines:find("POSSIBLE PICKUPS", 1, true) and lines:find("availability UNKNOWN", 1, true), "and the report names it as possible with the reason")
end

section("unknown availability: a short walk is fine, and the limit does not apply to what the player added or to a chosen route zone")
do
	local ns = world({ rec(1, "Near", 0.7, 0.5, { giverNpc = 8001, giverName = "Near Giver" }) })       -- 200 yd
	check(nowId(ns) == "Q:1:ACCEPT", "an unknown pickup 200 yd away is still NOW (nothing else to do)")
	local nsA = world({ NEAR, far(10, "Added", { giverNpc = 8010, giverName = "Far Giver" }) })
	nsA.Prefs.Add(10); nsA.State.Recompute()
	check(possibleIds(nsA)["Q:10:ACCEPT"] == nil, "a quest the player added is their call")
	local nsZ = world({ NEAR, far(10, "In Zone", { giverNpc = 8010, giverName = "Far Giver" }) })
	nsZ.Prefs.SetRouteZone("zone-a"); nsZ.State.Recompute()
	check(possibleIds(nsZ)["Q:10:ACCEPT"] == nil, "a route zone the player chose lifts the limit inside it")
end

section("unknown availability: fresh positive evidence makes it actionable; a fresh negative holds it back; a stale negative is UNKNOWN again, not positive")
do
	-- positive
	local ns = world({ NEAR, far(10, "Far Offered", { giverNpc = 8010, giverName = "Far Giver" }) })
	check(possibleIds(ns)["Q:10:ACCEPT"] ~= nil, "(setup) possible while unknown")
	detail(ns, 10, "Far Offered", "Far Giver", 8010)
	ns.State.Recompute()
	check(possibleIds(ns)["Q:10:ACCEPT"] == nil and candidateIds(ns)["Q:10:ACCEPT"], "a fresh offer from the client makes it a normal candidate")
	clearApis()
	-- negative: the giver, asked at this progression, lists nothing
	local nsN = world({ NEAR, rec(20, "Near Giver Quest", 0.55, 0.5, { giverNpc = 8020, giverName = "Hub Giver" }), rec(21, "Far Giver Quest", 0.95, 0.95, { giverNpc = 8021, giverName = "Other Giver" }) })
	listing(nsN, {}, "Hub Giver", 8020)
	nsN.State.Recompute()
	check(nsN.Planner.OfferState({ kind = "ACCEPT", quest = 20 }) == "NOT_OFFERED" and nsN.State.plan.diag.held and nsN.State.plan.diag.held.n >= 1, "a fresh empty list at the giver still holds the quest back (NOT_OFFERED)")
	-- the negative goes stale (the character levels): UNKNOWN again, never positive
	H.world().char.level = 11
	nsN.State.Recompute()
	check(nsN.Planner.OfferState({ kind = "ACCEPT", quest = 20 }) == "UNKNOWN", "a level later the negative is stale: UNKNOWN")
	check(nsN.Planner.Actionability({ kind = "ACCEPT", quest = 20 }) == "UNKNOWN", "and the quest is not positively available")
	check(possibleIds(nsN)["Q:21:ACCEPT"] ~= nil, "a far unknown pickup is still only possible after a stale negative elsewhere")
	-- a stale negative on a FAR quest does not turn it into a destination
	local nsF = world({ NEAR, far(30, "Far After Stale", { giverNpc = 8030, giverName = "Far Hub" }) })
	listing(nsF, {}, "Far Hub", 8030)
	H.world().char.level = 11
	nsF.State.Recompute()
	check(nsF.Planner.OfferState({ kind = "ACCEPT", quest = 30 }) == "UNKNOWN" and possibleIds(nsF)["Q:30:ACCEPT"] ~= nil and nowId(nsF) ~= "Q:30:ACCEPT", "a far quest whose negative went stale becomes UNKNOWN and still is not NOW")
	clearApis()
end

section("unknown availability: existing positive client evidence keeps working")
do
	local ns = world({ NEAR, rec(40, "Observed Near", 0.6, 0.55, { giverNpc = 8040, giverName = "Nearby Giver" }) })
	detail(ns, 40, "Observed Near", "Nearby Giver", 8040)
	ns.State.Recompute()
	check(ns.Planner.OfferState({ kind = "ACCEPT", quest = 40 }) == "OBSERVED" and possibleIds(ns)["Q:40:ACCEPT"] == nil, "an observed pickup is OBSERVED and routable")
	check(#ns.errors == 0, "no errors")
	clearApis()
end
