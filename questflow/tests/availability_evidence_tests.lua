-- availability_evidence_tests.lua (0.8.5): how far a piece of offer evidence may be trusted (OfferProbe.lua header, THE RULES).
--   G1  a newer current negative overrides an older positive; when that negative goes stale the result is UNKNOWN, never the old positive again
--   G2  an offer seen at a DIFFERENT known NPC than the quest's data giver is history, not routing evidence: UNKNOWN, never NOT_OFFERED
--   G3  names match only when an id is missing on at least one side; two known, different creature ids never match
-- Stub-client tests of Codex's own logic. Whether Forever ever opens a quest dialog at an NPC other than the data giver is not known.

local H = ...
local check, section, boot = H.check, H.section, H.boot

local NAMES = { "C_GossipInfo", "UnitName", "UnitGUID", "GetQuestID", "GetTitleText" }
local function world(quests)
	local ns = boot({ char = { level = 11 }, synthetic = true, loc = { map = 9001, x = 0.5, y = 0.5 } })
	for _, n in ipairs(NAMES) do _G[n] = nil end
	H.attPack(ns, quests, nil)
	ns.Prefs.FinishSetup()
	ForeverCodexDB.offers = nil
	ns.State.Recompute()
	return ns
end
local function npc(name, id)
	_G.UnitName = function(u) return u == "npc" and name or nil end
	_G.UnitGUID = function(u) return u == "npc" and id and ("Creature-0-1-2-3-" .. id .. "-ABCDEF") or nil end
end
local function gossip(ns, avail)
	_G.C_GossipInfo = { GetAvailableQuests = function() return avail end, GetActiveQuests = function() return {} end, GetOptions = function() return {} end }
	ns.OfferProbe.OnEvent("GOSSIP_SHOW")
end
local function detail(ns, qid, title)
	_G.GetQuestID = function() return qid end
	_G.GetTitleText = function() return title end
	ns.OfferProbe.OnEvent("QUEST_DETAIL")
end
local function e(id, t) return { questID = id, title = t, questLevel = 11 } end
local function pick(q) return { kind = "ACCEPT", quest = q, id = "Q:" .. q .. ":ACCEPT" } end
local function rec(id, name, x, giverNpc, giverName) return { id = id, name = name, map = 9001, x = x, y = 0.5, req = 1, giverNpc = giverNpc, giverName = giverName } end
local function cleanup() for _, n in ipairs(NAMES) do _G[n] = nil end end

section("availability evidence G1: a stale negative never resurrects the old positive")
do
	local ns = world({ rec(1, "Yorana's Task", 0.52, 9003, "Yorana") })
	local Pl = ns.Planner
	npc("Yorana", 9003); gossip(ns, { e(1, "Yorana's Task") }); ns.State.Recompute()
	check(Pl.OfferState(pick(1)) == "OBSERVED" and Pl.Actionability(pick(1)) == "OBSERVED", "1-2: the giver offered it: OBSERVED")
	-- the giver is asked again, at the same progression, and the quest is not in the list
	gossip(ns, {}); ns.State.Recompute()
	local st, ev = Pl.OfferState(pick(1))
	check(st == "NOT_OFFERED" and ev.contradicted and ev.newer == "EMPTY_AT_NPC", "3-4: a newer current negative overrides the older positive: NOT_OFFERED")
	check(ns.State.plan.diag.held and ns.State.plan.diag.held.n == 1, "(and the quest is held back, not routed)")
	-- progress: the negative goes stale
	H.world().char.level = 12
	ns.State.Recompute()
	local st2, ev2 = Pl.OfferState(pick(1))
	check(st2 == "UNKNOWN" and ev2.kind == "SUPERSEDED" and ev2.stale, "5-6: once the negative is stale the quest is UNKNOWN, not OBSERVED")
	check(Pl.Actionability(pick(1)) == "UNKNOWN", "and actionability is UNKNOWN too")
	check(not (ns.State.plan.diag.held and ns.State.plan.diag.held.n > 0), "(not held either: UNKNOWN is not unavailable)")
	check(ns.OfferProbe.QuestEvidence(1) ~= nil and ns.OfferProbe.QuestEvidence(1).via == "QUEST_DETAIL" or ns.OfferProbe.QuestEvidence(1).via == "AVAILABLE_LIST", "the historical positive record is kept")
	local ex = ns.OfferProbe.Explain(1, 9003, "Yorana")
	check(ex.positive and ex.positive.relation == "ID" and ex.evidence.kind == "SUPERSEDED", "Explain still shows the positive history and the superseding listing")
	local text = table.concat(ns.Diag.PickupEvidenceLines({ kind = "ACCEPT", quest = 1, id = "Q:1:ACCEPT", title = "Accept: Yorana's Task", giver = "Yorana" }, "NOW"), "\n")
	check(text:find("positive client offer: yes", 1, true) and text:find("NOT USED as current evidence", 1, true), "the report says positive evidence existed and why it is not used now")
	-- a fresh observation that lists it again restores OBSERVED
	gossip(ns, { e(1, "Yorana's Task") })
	check(Pl.OfferState(pick(1)) == "OBSERVED", "only a NEW observation that lists the quest makes it OBSERVED again")
	check(#ns.errors == 0, "no errors")
	cleanup()
end

section("availability evidence G1: progress alone does not erase a positive")
do
	local ns = world({ rec(2, "Plain Offer", 0.52, 9003, "Yorana") })
	local Pl = ns.Planner
	npc("Yorana", 9003); detail(ns, 2, "Plain Offer"); ns.State.Recompute()
	check(Pl.OfferState(pick(2)) == "OBSERVED", "(setup) offered")
	H.world().char.level = 14
	ns.State.Recompute()
	check(Pl.OfferState(pick(2)) == "OBSERVED" and Pl.Actionability(pick(2)) == "OBSERVED", "a level later, with no new observation, it is still OBSERVED")
	ns.Journey.OnQuestTurnedIn(990, 100)
	ns.State.Recompute()
	check(Pl.OfferState(pick(2)) == "OBSERVED", "and after a turn-in too")
	cleanup()
end

section("availability evidence G2: an offer seen at a different NPC is history, not evidence about the giver")
do
	local ns = world({ rec(3, "Mismatch Quest", 0.52, 9003, "Yorana") })
	local Pl = ns.Planner
	npc("Somebody Else", 9777); detail(ns, 3, "Mismatch Quest"); ns.State.Recompute()
	local st, ev = Pl.OfferState(pick(3))
	check(st == "UNKNOWN" and ev.kind == "OBSERVED_ELSEWHERE" and ev.npc == "Somebody Else", "UNKNOWN, with the observation kept as OBSERVED_ELSEWHERE")
	check(st ~= "NOT_OFFERED" and not (ns.State.plan.diag.held and ns.State.plan.diag.held.n > 0), "never NOT_OFFERED, never held back")
	check(Pl.Actionability(pick(3)) == "UNKNOWN", "and not actionability OBSERVED")
	check(ns.OfferProbe.QuestEvidence(3) ~= nil, "the observation is retained")
	check(math.abs(Pl.Confidence(pick(3)) - Pl.Confidence(pick(3), Pl.Params("efficient"))) < 1e-9 and Pl.Confidence(pick(3)) < 1, "it is valued as any unknown pickup (the small discount), not as an offered one")
	local ex = ns.OfferProbe.Explain(3, 9003, "Yorana")
	check(ex.positive.relation == "MISMATCH", "Explain names the mismatch")
	local text = table.concat(ns.Diag.PickupEvidenceLines({ kind = "ACCEPT", quest = 3, id = "Q:3:ACCEPT", title = "Accept: Mismatch Quest", giver = "Yorana" }, "NOW"), "\n")
	check(text:find("NOT USED as routing evidence", 1, true) and text:find("DIFFERENT NPC", 1, true) and text:find("(not negative)", 1, true), "the report says why, and that it is not negative")
	-- the same NPC (by id) is a match
	local ns2 = world({ rec(3, "Mismatch Quest", 0.52, 9003, "Yorana") })
	npc("Yorana", 9003); detail(ns2, 3, "Mismatch Quest"); ns2.State.Recompute()
	check(ns2.Planner.OfferState(pick(3)) == "OBSERVED", "(proof) at the giver itself the same observation is OBSERVED")
	check(#ns.errors == 0 and #ns2.errors == 0, "no errors")
	cleanup()
end

section("availability evidence G3: names match only when an id is missing")
do
	local O = boot({ char = { level = 10 }, synthetic = true }).OfferProbe
	check(O.Relate(9003, "Guard", 9555, "Guard") == "MISMATCH", "two known, different ids: no match, whatever the names")
	check(O.Relate(9003, "Guard", 9003, "Other") == "ID", "the same id matches whatever the names")
	check(O.Relate(nil, "Guard", 9555, "Guard") == "NAME" and O.Relate(9003, "Guard", nil, "Guard") == "NAME", "a missing id on either side allows the name fallback")
	check(O.Relate(nil, "High Priest Rohan <Priest Trainer>", 1, "High Priest Rohan") == "NAME", "a guild line in quest data does not break the name fallback")
	check(O.Relate(nil, "A", nil, "B") == "MISMATCH" and O.Relate(nil, nil, 5, "B") == nil, "different names with no ids differ; nothing to compare says nothing")

	local ns = world({ rec(4, "Guard Duty", 0.52, 9003, "Guard") })
	local Pl = ns.Planner
	npc("Guard", 9555); gossip(ns, {}); ns.State.Recompute()
	check(Pl.OfferEvidence(pick(4)) == nil and Pl.OfferState(pick(4)) == "UNKNOWN" and not (ns.State.plan.diag.held and ns.State.plan.diag.held.n > 0), "an empty dialog at a same-named Guard with another creature id holds nothing")
	npc("Guard", 9003); gossip(ns, {}); ns.State.Recompute()
	check(Pl.OfferState(pick(4)) == "NOT_OFFERED", "(proof) the same dialog at the real Guard (same id) does")

	-- fallback: the client gave no creature id for the observed NPC; the data giver has one: the name still matches
	local ns2 = world({ rec(5, "No Guid", 0.52, 9003, "Yorana") })
	npc("Yorana", nil); gossip(ns2, {}); ns2.State.Recompute()
	check(ns2.Planner.OfferState(pick(5)) == "NOT_OFFERED", "observed NPC without an id, data giver with one, same name: matched by name")
	-- the reverse: the data names no creature id
	local ns3 = world({ rec(6, "No Giver Id", 0.52, nil, "Yorana") })
	npc("Yorana", 9003); gossip(ns3, {}); ns3.State.Recompute()
	check(ns3.Planner.OfferState(pick(6)) == "NOT_OFFERED", "data giver without an id, observed NPC with one, same name: matched by name")
	-- a positive through the name fallback is routing evidence
	local ns4 = world({ rec(7, "Named Positive", 0.52, nil, "Yorana") })
	npc("Yorana", 9003); detail(ns4, 7, "Named Positive"); ns4.State.Recompute()
	check(ns4.Planner.OfferState(pick(7)) == "OBSERVED", "a positive from an NPC matched by name is OBSERVED")
	check(#ns.errors + #ns2.errors + #ns3.errors + #ns4.errors == 0, "no errors")
	cleanup()
end
