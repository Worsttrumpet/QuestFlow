-- stale_evidence_tests.lua: a dialog observation with no progression stamp is never current evidence (0.7.5). Real-client finding (build 70205): 8-13 hour old unstamped "not offered" dialogs held
-- quests for a brand-new character. Stub-client tests of Codex's own rules.

local H = ...
local check, section, boot = H.check, H.section, H.boot

local function rec(id, name, x, y, o)
	local q = { id = id, name = name, map = 9001, x = x, y = y, req = 1 }
	for k, v in pairs(o or {}) do q[k] = v end
	return q
end
local function clearApis() for _, n in ipairs({ "C_GossipInfo", "GetQuestID", "GetTitleText", "UnitGUID" }) do _G[n] = nil end end
local function world(db)
	local ns = boot({ char = { level = 10, class = "Rogue", classToken = "ROGUE" }, synthetic = true, production = true, legacyUnknown = true, savedVars = db, loc = { map = 9001, x = 0.5, y = 0.5, zone = "F" } })
	clearApis()
	H.attPack(ns, { rec(1, "Hub Quest", 0.55, 0.5, { giverNpc = 7001, giverName = "Hub Giver" }), rec(2, "Far Quest", 0.95, 0.95, { giverNpc = 7002, giverName = "Far Giver" }) }, { { key = "zone-a", label = "A", map = 9001, quests = 2 } })
	ns.Prefs.FinishSetup()
	return ns
end
local function stubNpc(name, id)
	_G.UnitName = function(u) return u == "npc" and name or "Thrall" end
	_G.UnitGUID = function(u) return u == "npc" and ("Creature-0-1-2-3-" .. id .. "-ABCDEF") or nil end
end
local function listing(ns, entries, npc, id)
	stubNpc(npc, id)
	_G.C_GossipInfo = { GetAvailableQuests = function() return entries end, GetActiveQuests = function() return {} end, GetOptions = function() return {} end }
	ns.OfferProbe.OnEvent("GOSSIP_SHOW")
end
local function pickup(id) return { kind = "ACCEPT", quest = id } end
--- An old dialog as saved before progression stamps existed: an EMPTY available list at the NPC, no `prog`, a long time ago.
local function oldUnstampedEmpty(npcId, npcName)
	ForeverCodexDB.offers = ForeverCodexDB.offers or { v = 1, owner = ns.Prefs.CharKey() }
	local s = ForeverCodexDB.offers
	s.obs, s.proof, s.stats, s.quests = s.obs or {}, s.proof or {}, s.stats or {}, s.quests or {}
	s.npcs = s.npcs or {}
	s.seq = (s.seq or 0) + 1
	s.npcs["id:" .. npcId] = { name = npcName, id = npcId, first = 1, last = 1, n = 1, via = "GOSSIP_SHOW",
		avail = { state = "EMPTY", api = "C_GossipInfo.GetAvailableQuests", n = 0, ids = {}, entries = {}, at = 1, seq = s.seq },
		active = { state = "EMPTY", api = "C_GossipInfo.GetActiveQuests", n = 0, ids = {}, entries = {}, at = 1, seq = s.seq } }
end

section("stale evidence: an old UNSTAMPED 'not offered' dialog does not hold a quest back (the exact 0.7.4 playtest failure)")
do
	local ns = world()
	oldUnstampedEmpty(7001, "Hub Giver")
	ns.State.Recompute()
	local st, ev = ns.Planner.OfferState(pickup(1))
	check(st == "UNKNOWN" and ev and ev.kind == "EMPTY_AT_NPC" and ev.stale == true, "the old empty dialog is STALE evidence: the quest's state is UNKNOWN, not NOT_OFFERED  [" .. tostring(st) .. "]")
	local p = ns.State.plan
	check(not (p.diag.held and p.diag.held.n > 0) and p.now and p.now.id == "Q:1:ACCEPT", "it is not held back: the quest is the NOW pickup")
	local ex = ns.OfferProbe.Explain(1, 7001, "Hub Giver")
	check(ex.listing.noStamp == true and ex.listing.fresh == false, "the report data says: no stamp, not fresh")
	check(ns.OfferProbe.NpcContext(7001).avail.prog == nil, "no progression stamp was invented for it")
	local text = table.concat(ns.Diag.PlaytestLines(ns.Diag.Snapshot(), {}), "\n")
	check(text:find("no progression stamp stored on that dialog: treated as STALE", 1, true) ~= nil or text:find("no comparison possible: stale", 1, true) ~= nil, "the report says an unstamped dialog is treated as stale")
	-- a brand-new character of another name loading the same account-wide store
	local db = _G.ForeverCodexDB
	local ns2 = boot({ char = { level = 2, name = "Newbie", class = "Hunter", classToken = "HUNTER", race = "Tauren", raceToken = "Tauren" }, synthetic = true, production = true, legacyUnknown = true, savedVars = db, loc = { map = 9001, x = 0.5, y = 0.5, zone = "F" } })
	H.attPack(ns2, { rec(1, "Hub Quest", 0.55, 0.5, { giverNpc = 7001, giverName = "Hub Giver" }) }, { { key = "zone-a", label = "A", map = 9001, quests = 1 } })
	ns2.Prefs.FinishSetup(); ns2.State.Recompute()
	check(ns2.Planner.OfferState(pickup(1)) == "UNKNOWN" and ns2.State.plan.now and ns2.State.plan.now.id == "Q:1:ACCEPT", "a new character is not blocked by another character's old unstamped dialog")
end

section("stale evidence: a fresh STAMPED 'not offered' still holds, and a stale stamped negative ages out to UNKNOWN")
do
	local ns = world()
	listing(ns, {}, "Hub Giver", 7001)
	ns.State.Recompute()
	check(ns.Planner.OfferState(pickup(1)) == "NOT_OFFERED" and ns.State.plan.diag.held and ns.State.plan.diag.held.n == 1, "a fresh stamped empty list at the giver: NOT_OFFERED and held back")
	check(ns.OfferProbe.NpcContext(7001).avail.prog ~= nil, "(its stamp is stored)")
	H.world().char.level = 11
	ns.State.Recompute()
	check(ns.Planner.OfferState(pickup(1)) == "UNKNOWN" and not (ns.State.plan.diag.held and ns.State.plan.diag.held.n > 0), "a level later the negative is stale: UNKNOWN, not held")
	check(ns.Planner.Actionability(pickup(1)) == "UNKNOWN", "and never positively available")
end

section("stale evidence: positive evidence is unchanged (a fresh offer is a candidate; an old unstamped positive record is evidence but not an 'offered here' candidate)")
do
	local ns = world()
	stubNpc("Far Giver", 7002)
	_G.GetQuestID = function() return 2 end
	_G.GetTitleText = function() return "Far Quest" end
	ns.OfferProbe.OnEvent("QUEST_DETAIL")
	ns.State.Recompute()
	check(ns.Planner.OfferState(pickup(2)) == "OBSERVED", "a fresh offer: OBSERVED (the far pickup is routable)")
	local poss = ns.State.plan.diag.possible
	check(not poss or poss.n == 0, "and no longer only a possible pickup")
	-- an unknown quest offered now becomes an offered-here candidate; the same record without a stamp does not
	stubNpc("Talaanis", 7003)
	_G.GetQuestID = function() return 94001 end
	_G.GetTitleText = function() return "What Comes Next" end
	ns.OfferProbe.OnEvent("QUEST_DETAIL")
	ns.State.Recompute()
	local fresh = false
	for _, a in ipairs(ns.State.plan.reminders) do if a.quest == 94001 and a.offered then fresh = true end end
	check(fresh, "a fresh offer for a quest no pack knows is an offered-here candidate")
	ForeverCodexDB.offers.quests[94001].prog = nil
	ns.State.Recompute()
	local still = false
	for _, a in ipairs(ns.State.plan.reminders) do if a.quest == 94001 and a.offered then still = true end end
	check(not still and ns.Planner.Actionability({ kind = "ACCEPT", quest = 94001 }) == "OBSERVED", "the same record with no stamp is still positive evidence but is not offered as current")
	clearApis()
end
