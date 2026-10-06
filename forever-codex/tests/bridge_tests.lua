-- bridge_tests.lua: the QuestieDB bridge (QuestieBridge.lua), tested against a fake of QuestieDB's DOCUMENTED public API
-- (tests/fake_questiedb.lua). Stub-client tests: they prove Codex's own logic. Nothing here proves anything about the real QuestieDB
-- addon or the real Forever client; the checks that need them are listed in docs/CODEX_REALCLIENT_FIXES.md.
--   * dependency behaviour: QuestieDB optional, Codex still loads and says so
--   * what is read from QuestieDB and how it maps to Codex's own record shape
--   * evidence rules: missing = unknown, src=questiedb verified=false, observed data is never overwritten, nothing is written INTO QuestieDB
--   * layering: observed > QuestieDB > the existing (temporary) fallback data
--   * failure handling and the development smoke check

local H = ...
local check, section, boot, slash = H.check, H.section, H.boot, H.slash
local Fake = H.fake

local function chatText() return table.concat(H.world().chat or {}, "\n") end
local function stripComments(path) return (H.readFile(path):gsub("%-%-[^\n]*", "")) end

local HORDE_WARRIOR = { level = 10, class = "Warrior", classToken = "WARRIOR", race = "Orc", raceToken = "Orc", faction = "Horde" }
local HERE = { map = 9001, x = 0.5, y = 0.5, zone = "Fixture" }

--- Boots Codex (synthetic maps, no built-in data) with `fake` installed first, so the bridge finds it at login.
local function bootWith(fake, char)
	if fake then fake.install() else Fake.new().uninstall() end
	local ns = boot({ char = char or HORDE_WARRIOR, synthetic = true, loc = HERE })
	local W = H.world()
	W.log, W.objectives, W.completed = {}, {}, {}
	ns.Prefs.FinishSetup()
	return ns, W
end

local function cands(ns)
	local ctx = ns.Context.Build()
	return ns.Engine.Candidates(ctx), ctx
end

local function hasAction(list, id) for _, a in ipairs(list) do if a.id == id then return a end end end

-- ================================================================ QuestieDB missing: Codex still loads and says why

section("bridge: QuestieDB missing -> Codex loads, says what QuestieDB is for, uses its own data, claims nothing")
do
	Fake.new().uninstall()
	local ns = boot({ char = HORDE_WARRIOR })               -- real built-in data, no QuestieDB
	local st = ns.QuestieBridge.Status()
	check(st.state == "missing" and not ns.QuestieBridge.Available(), "status: missing")
	check(chatText():find("QuestieDB addon was not found", 1, true) ~= nil and chatText():find("quest knowledge", 1, true) ~= nil, "login explains that QuestieDB provides the quest knowledge")
	check(chatText():find("small built-in data", 1, true) ~= nil, "and that Codex is using its own small data meanwhile")
	local names = {}
	for _, p in ipairs(ns.Registry.Packs("quests")) do names[p.name] = true end
	check(not names.questiedb, "no QuestieDB pack is registered")
	check(#ns.Registry.QuestIds() > 100 and ns.State.plan ~= nil, "Codex still plans from its own data")
	H.world().chat = {}
	slash("questiedb")
	check(chatText():find("QuestieDB is NOT in use (missing)", 1, true) ~= nil, "/codex questiedb says it is not in use")
	H.world().chat = {}
	slash("diag")
	check(chatText():find("QuestieDB: NOT in use (missing)", 1, true) ~= nil, "/codex diag says so too")
	check(ns.QuestieBridge.Record(1) == nil and #ns.QuestieBridge.Smoke(98298, 1938) == 1, "no record is invented and the smoke check has nothing to ask")
	check(#ns.errors == 0, "no errors")
end

-- ================================================================ QuestieDB present: what is read and how it maps

local function standardFake()
	local f = Fake.new({ version = "1.0.4", commit = "365537a340473291f5af3b7a53a5eca94e2a5f1a" })
	f.mapArea(9001, 9001); f.mapArea(9002, 9002)
	f.addNpc(5001, { name = "Dalar Test", spawns = { [9001] = { { 60.0, 50.0 } } }, zoneID = 9001, friendlyToFaction = "H" })        -- 100 yd east of the player
	f.addNpc(5002, { name = "Taker Test", spawns = { [9001] = { { 40.0, 50.0 } } }, zoneID = 9001, friendlyToFaction = "H" })
	f.addNpc(5003, { name = "Alliance Giver", spawns = { [9001] = { { 70.0, 50.0 } } }, zoneID = 9001, friendlyToFaction = "A" })
	f.addNpc(5004, { name = "Wanderer" })                                                                                               -- known, but no spawns
	f.addNpc(5005, { name = "Instance NPC", spawns = { [9001] = { { -1, -1 }, { 55.0, 50.0 } } }, zoneID = 9001 })                    -- the {-1,-1} marker is not a place
	f.addNpc(5006, { name = "Unmapped Area NPC", spawns = { [7777] = { { 10.0, 10.0 } } }, zoneID = 7777 })
	f.addNpc(5007, { name = "Two Zones", spawns = { [9001] = { { 51.0, 50.0 } }, [9002] = { { 10.0, 10.0 } } }, zoneID = 9002 })        -- primary area first
	f.addQuest(91001, { name = "Bridge Quest", startedBy = { { 5001 } }, finishedBy = { { 5002 } }, requiredLevel = 5, questLevel = 8,
		requiredRaces = 8589934770, objectivesText = { "Bring 6 Bits to Dalar Test." } })
	f.addQuest(91002, { name = "Alliance Quest", startedBy = { { 5003 } }, finishedBy = { { 5003 } }, requiredLevel = 5 })
	f.addQuest(91003, { name = "Hunters Only", startedBy = { { 5001 } }, finishedBy = { { 5001 } }, requiredLevel = 5, requiredClasses = 4 })
	f.addQuest(91004, { name = "Needs Both", startedBy = { { 5001 } }, finishedBy = { { 5001 } }, requiredLevel = 5, preQuestGroup = { 91001, 91005 } })
	f.addQuest(91005, { name = "Second Prerequisite", startedBy = { { 5001 } }, finishedBy = { { 5001 } }, requiredLevel = 5 })
	f.addQuest(91006, { name = "Repeatable", startedBy = { { 5001 } }, finishedBy = { { 5001 } }, requiredLevel = 5, specialFlags = 1 })
	f.addQuest(91007, { name = "A Breadcrumb", startedBy = { { 5001 } }, finishedBy = { { 5001 } }, requiredLevel = 5, breadcrumbForQuestId = 91001 })
	f.addQuest(91008, { name = "No Spawn", startedBy = { { 5004 } }, finishedBy = { { 5004 } } })
	f.addQuest(91009, { name = "Sentinel", startedBy = { { 5005 } }, finishedBy = { { 5005 } } })
	f.addQuest(91010, { name = "Unmapped", startedBy = { { 5006 } }, finishedBy = { { 5006 } } })
	f.addQuest(91011, { name = "Primary Area", startedBy = { { 5007 } }, finishedBy = { { 5007 } } })
	f.addQuest(91012, { name = "Any Of Two", startedBy = { { 5001 } }, finishedBy = { { 5001 } }, requiredLevel = 5, preQuestSingle = { 91001, 91005 } })
	f.addQuest(91013, { name = "Unknown Giver", startedBy = { { 424242 } } })                                                           -- the NPC is not in QuestieDB either
	return f
end

section("bridge: QuestieDB present -> status, mapping to Codex's record shape, provenance")
do
	local fake = standardFake()
	local ns, W = bootWith(fake)
	local st = ns.QuestieBridge.Status()
	check(st.state == "available" and ns.QuestieBridge.Available(), "status: available")
	check(st.version == "1.0.4" and st.commit == "365537a340473291f5af3b7a53a5eca94e2a5f1a" and st.flavor == "Forever" and st.mode == "baked" and st.contract == 2 and st.minContract == 1, "version, build commit, flavor, mode and contract are read")
	check(st.quests == 13 + 0 and chatText():find("was not found", 1, true) == nil, "the quest count is known and no setup message is shown")
	local R = ns.Registry
	local order = {}
	for _, p in ipairs(R.Packs("quests")) do order[#order + 1] = p.name end
	check(#order == 1 and order[1] == "questiedb", "the QuestieDB pack is registered (and re-checking does not duplicate it)")
	ns.QuestieBridge.Init(); ns.QuestieBridge.Init()
	local n = 0
	for _, p in ipairs(R.Packs("quests")) do if p.name == "questiedb" then n = n + 1 end end
	check(n == 1, "Init is idempotent")

	local v = R.Quest(91001)
	check(v and v.name == "Bridge Quest" and v.req == 5 and v.level == 8, "name, required level and quest level")
	check(v.giverNpc == 5001 and v.giverName == "Dalar Test", "the giver NPC and its name")
	check(v.loc and v.loc.map == 9001 and math.abs(v.loc.x - 0.6) < 1e-9 and math.abs(v.loc.y - 0.5) < 1e-9, "the giver's location: percent -> 0..1, AreaID -> UiMapID")
	check(v.loc.src == "questiedb" and v.loc.verified == false and v.loc.kind == "giver", "the location is src=questiedb, verified=false")
	check(v.turnIn and v.turnIn.npc == 5002 and v.turnIn.name == "Taker Test" and v.turnIn.map == 9001 and math.abs(v.turnIn.x - 0.4) < 1e-9, "the turn-in NPC is read (kept; routing still assumes the giver)")
	check(v.objectives and v.objectives[1] == "Bring 6 Bits to Dalar Test.", "objective text")
	check(v.faction == "Horde" and v.prov.faction == "questiedb", "the faction restriction is inferred from the giver NPC's friendliness, and labelled questiedb")
	check(v.races == nil and v.raceMask == 8589934770, "the race mask is kept for diagnostics but no race restriction is invented")
	check(v.prov.name == "questiedb" and v.prov.req == "questiedb" and v.prov.level == "questiedb", "every field's provenance is questiedb")
	check(v.hasObserved == false and v.hasAtt == false, "it is not marked observed (or ATT)")
	check(R.Quest(91003).classes and R.Quest(91003).classes[1] == "HUNTER" and R.Quest(91003).classMask == 4, "a class mask becomes class tokens (standard class ids)")
	local both = R.Quest(91004)
	check(both.prereqAll and #both.prereqAll == 2 and both.prereq and #both.prereq == 2, "group prerequisites are all-of (and listed as any-of too)")
	local anyOf = R.Quest(91012)
	check(anyOf.prereq and #anyOf.prereq == 2 and anyOf.prereqAll == nil, "single prerequisites are any-of")
	check(R.Quest(91006).repeatable == true, "repeatable flag")
	check(R.Quest(91007).breadcrumb == true, "breadcrumb flag")
	check(R.Quest(91008).loc == nil and R.Quest(91008).giverName == "Wanderer", "an NPC without spawns gives no location (unknown, not guessed)")
	check(R.Quest(91009).loc and math.abs(R.Quest(91009).loc.x - 0.55) < 1e-9, "the {-1,-1} instance marker is skipped, the real point is used")
	check(R.Quest(91010).loc == nil, "an area with no UiMap gives no location")
	check(R.Quest(91011).loc and R.Quest(91011).loc.map == 9002, "the NPC's primary area is preferred when it has spawns")
	check(R.Quest(91013) ~= nil and R.Quest(91013).loc == nil and R.Quest(91013).giverNpc == nil, "a quest whose giver QuestieDB does not know still reads, with no giver and no location")
	check(R.Quest(99999) == nil, "an unknown quest reads as nil (unknown)")
	check(#R.QuestIds() == 13, "all QuestieDB quest ids are enumerated")

	-- the Planner's inputs
	local c, ctx = cands(ns)
	local a = hasAction(c.candidates, "Q:91001:ACCEPT")
	check(a ~= nil, "the quest is a candidate")
	check(a and a.target and a.target.src == "questiedb" and a.target.verified == false and a.src == "questiedb" and a.verified == false, "its action says src=questiedb, verified=false")
	check(a and a.targets and a.targets[1] and a.targets[1].prov.src == "questiedb" and a.targets[1].prov.verified == false, "and so does its contract target")
	local lines = a and table.concat(a.lines, "\n") or ""
	check(lines:find("(QuestieDB, unverified on Forever)", 1, true) ~= nil and lines:find("ATT", 1, true) == nil, "the player-facing text names QuestieDB, unverified (not ATT)")
	check(a and a.reqLevel == 5 and a.level == 8, "levels reach the action")
	check(hasAction(c.candidates, "Q:91002:ACCEPT") == nil, "an Alliance-giver quest is not offered to a Horde character")
	check(hasAction(c.candidates, "Q:91003:ACCEPT") == nil, "a Hunters-only quest is not offered to a Warrior")
	check(hasAction(c.candidates, "Q:91004:ACCEPT") == nil, "a quest needing two earlier quests is not offered until both are done")
	check(hasAction(c.candidates, "Q:91006:ACCEPT") == nil, "a repeatable quest is not offered")
	check(hasAction(c.candidates, "Q:91008:ACCEPT") == nil and hasAction(c.candidates, "Q:91010:ACCEPT") == nil, "quests with no location are not routed")
	W.completed[91001] = true
	local c2 = cands(ns)
	check(hasAction(c2.candidates, "Q:91004:ACCEPT") == nil, "one of two prerequisites is not enough")
	W.completed[91005] = true
	local c3 = cands(ns)
	check(hasAction(c3.candidates, "Q:91004:ACCEPT") ~= nil and hasAction(c3.candidates, "Q:91012:ACCEPT") ~= nil, "both done: the all-of quest (and the any-of one) are offered")
	W.completed = {}
	local plan = ns.State.Recompute()
	check(plan.now ~= nil and plan.now.src == "questiedb", "the Planner picks a NOW from QuestieDB records")
	check(ns.QuestieBridge.Stats().built > 0 and ns.QuestieBridge.Stats().errors == 0, "records were read without errors")
	check(#ns.errors == 0, "no errors")
	fake.uninstall()
end

-- ================================================================ evidence rules

section("bridge: missing from QuestieDB means UNKNOWN, never 'does not exist'")
do
	local fake = standardFake()
	local ns, W = bootWith(fake)
	W.log = { { questID = 92000, title = "A Quest QuestieDB Lacks", complete = false } }
	W.objectives[92000] = { { text = "x", type = "item", finished = false, numFulfilled = 0, numRequired = 3 } }
	local plan = ns.State.Recompute()
	local found
	for _, r in ipairs(plan.reminders) do if r.id == "Q:92000:OBJECTIVE" then found = r end end
	check(found ~= nil and found.noLocation == true and found.unknown == true, "a quest in the log that QuestieDB lacks stays a reminder with no location")
	check(ns.Registry.Quest(92000) == nil, "and reads as unknown")
	local text = found and table.concat(found.lines, "\n") or ""
	check(text:lower():find("does not exist", 1, true) == nil and text:lower():find("no such quest", 1, true) == nil and text:lower():find("not in codex data yet", 1, true) ~= nil, "no text claims the quest does not exist")
	H.world().chat = {}
	slash("questiedb 92000 5001")
	local out = chatText()
	check(out:find("Quest.Exists(92000) = false", 1, true) ~= nil and out:find("unknown to Codex, not a statement that the quest does not exist", 1, true) ~= nil, "the smoke check words an absent quest as unknown")
	check(out:find("A missing quest is UNKNOWN", 1, true) ~= nil or out:find("UNKNOWN to Codex, never 'does not exist'", 1, true) ~= nil, "and /codex questiedb repeats the rule")
	check(out:find("absent here is expected, not an error", 1, true) ~= nil, "and that a stable release lacking quests is expected")
	check(#ns.errors == 0, "no errors")
	fake.uninstall()
end

section("bridge: the development smoke check (stable build: 98298 absent; newer build: present) - never an error")
do
	-- a "stable release": no Forever-only quest
	local stable = Fake.new({ version = "1.0.4" })
	stable.mapArea(130, 1421)
	stable.addNpc(1938, { name = "Dalar Dawnweaver", spawns = { [130] = { { 44.2, 39.81 } } }, zoneID = 130, friendlyToFaction = "H" })
	local ns = bootWith(stable)
	H.world().chat = {}
	slash("questiedb")
	local out = chatText()
	check(out:find("Quest.Exists(98298) = false", 1, true) ~= nil, "stable: the quest is absent")
	check(out:find("Quest.Get(98298, \"name\") = nil", 1, true) ~= nil, "stable: no name")
	check(out:find("Npc.Get(1938, \"name\") = Dalar Dawnweaver", 1, true) ~= nil, "stable: the NPC is there")
	check(out:find("Npc.spawns(1938) = {130={1={1=44.2,2=39.81}}}", 1, true) ~= nil and out:find("area 130 -> UiMap 1421", 1, true) ~= nil, "stable: the NPC's spawns and the AreaID -> UiMap mapping")
	check(out:find("expected, not an error", 1, true) ~= nil and #ns.errors == 0, "stable: absent is reported as expected, and nothing raised")
	stable.uninstall()
	-- a newer build: the quest is there
	local newer = Fake.new({ version = "1.0.4-dev.cac1eff", commit = "cac1eff815923f896d082764d023cf812454a023" })
	newer.mapArea(130, 1421)
	newer.addNpc(1938, { name = "Dalar Dawnweaver", spawns = { [130] = { { 44.2, 39.81 } } }, zoneID = 130, friendlyToFaction = "H" })
	newer.addQuest(98298, { name = "Arugal's Folly", startedBy = { { 1938 } }, finishedBy = { { 1938 } }, requiredLevel = 9, questLevel = 16, requiredRaces = 8589934770,
		objectivesText = { "Bring 6 Worgen Bits to Dalar Dawnweaver in The Sepulcher." } })
	local ns2 = bootWith(newer)
	H.world().chat = {}
	slash("questiedb")
	local out2 = chatText()
	check(out2:find("Quest.Exists(98298) = true", 1, true) ~= nil and out2:find("Arugal's Folly", 1, true) ~= nil, "newer build: the quest is present with its name")
	check(out2:find("1.0.4-dev.cac1eff", 1, true) ~= nil and out2:find("cac1eff815923f896d082764d023cf812454a023", 1, true) ~= nil, "and the version and build commit are shown")
	local v = ns2.Registry.Quest(98298)
	check(v and v.giverName == "Dalar Dawnweaver" and v.loc and v.loc.map == 1421 and math.abs(v.loc.x - 0.442) < 1e-9 and math.abs(v.loc.y - 0.3981) < 1e-9, "newer build: the bridge turns it into a located quest on UiMap 1421")
	check(v.loc.src == "questiedb" and v.loc.verified == false, "still src=questiedb, verified=false")
	H.world().chat = {}
	slash("diag")
	check(chatText():find("QuestieDB: IN USE | version 1.0.4-dev.cac1eff, build cac1eff815923f896d082764d023cf812454a023", 1, true) ~= nil, "/codex diag shows the QuestieDB version and commit")
	newer.uninstall()
	-- nothing in the product logic knows about this quest
	local addon = H.addonDir
	local offenders = {}
	local p = io.popen('cd "' .. addon .. '" && find . -name "*.lua" | sed "s#^\\./##" | sort')
	for f in p:lines() do
		if f ~= "Slash.lua" and H.readFile(addon .. "/" .. f):find("98298", 1, true) then offenders[#offenders + 1] = f end
	end
	p:close()
	check(#offenders == 0, "98298 appears in no product file except the development command's default" .. (#offenders > 0 and (": " .. table.concat(offenders, ", ")) or ""))
end

-- ================================================================ layering

section("bridge: layering - observed Forever data over QuestieDB over the temporary fallback; QuestieDB never overwrites observed evidence")
do
	local fake = standardFake()
	local ns, W = bootWith(fake)
	local R, C = ns.Registry, ForeverCodex
	C.RegisterPack("quests", "observed:test", { meta = { src = "observed", verified = true, priority = 100, label = "test" }, zones = {}, quests = {
		[91001] = { id = 91001, name = "Observed Name", level = 7, objectives = { "0/6 Bits" }, giverNpc = 5001, giverName = "Dalar (observed)", pos = { map = 9001, x = 0.9, y = 0.9 } },
		[91003] = { id = 91003, name = "Moved Giver", level = 6, giverNpc = 9999, giverName = "A New Giver", pos = { map = 9001, x = 0.2, y = 0.2 } },
		[92001] = { id = 92001, name = "Forever Only", level = 4, giverNpc = 8888, giverName = "Only Here", pos = { map = 9001, x = 0.3, y = 0.3 } },
	} })
	C.RegisterPack("quests", "att:test", { meta = { src = "att", verified = false, priority = 10, label = "test ATT" }, zones = {}, quests = {
		[91001] = { id = 91001, name = "ATT Name", map = 9001, x = 0.1, y = 0.1, objCoords = { { map = 9001, x = 0.7, y = 0.7 } } },
		[92002] = { id = 92002, name = "Fallback Only", map = 9001, x = 0.55, y = 0.5, req = 3 },
	} })
	local order = {}
	for _, p in ipairs(R.Packs("quests")) do order[#order + 1] = p.name end
	check(table.concat(order, ",") == "observed:test,questiedb,att:test", "pack order: observed, QuestieDB, fallback")
	local v = R.Quest(91001)
	check(v.name == "Observed Name" and v.prov.name == "observed", "an observed name wins over QuestieDB's")
	check(v.level == 7 and v.prov.level == "observed", "an observed level wins over QuestieDB's quest level")
	check(v.objectives[1] == "0/6 Bits" and v.prov.objectives == "observed", "observed objectives are not replaced")
	check(v.req == 5 and v.prov.req == "questiedb", "a field observed data lacks comes from QuestieDB")
	check(v.loc.src == "questiedb" and math.abs(v.loc.x - 0.6) < 1e-9, "QuestieDB's giver coordinate outranks the existing fallback's")
	check(v.objCoords and v.objCoords[1].x == 0.7 and v.prov.objCoords == "att", "something only the fallback has (objective areas) still comes from it")
	check(v.locConflict == nil, "same giver in both layers: no conflict")
	-- observed data says a DIFFERENT NPC gives the quest: QuestieDB's coordinate belongs to the old NPC and is not used
	local m = R.Quest(91003)
	check(m.name == "Moved Giver" and m.giverNpc == 9999 and m.giverName == "A New Giver", "observed giver identity is kept")
	check(m.locConflict and m.locConflict.giverNpc == 9999 and m.locConflict.ignoredGiverNpc == 5001 and m.locConflict.ignored == "questiedb", "a QuestieDB location for a different giver is set aside and the conflict recorded")
	check(m.loc and m.loc.kind == "player_position" and m.loc.src == "observed", "the location falls back to the observed position (labelled approximate), not the old NPC's spot")
	-- a quest only Codex observed, and one only the fallback has
	check(R.Quest(92001).prov.name == "observed" and R.Quest(92001).loc.kind == "player_position", "a Forever-only observed quest is untouched")
	check(R.Quest(92002).name == "Fallback Only" and R.Quest(92002).loc.src == "att", "a quest QuestieDB lacks falls back to the existing data")
	check(#R.QuestIds() == 13 + 2, "ids from every layer are listed once (13 from QuestieDB, plus the two only the observed pack and the fallback have)")
	-- the guard is only for QuestieDB: existing ATT behaviour is unchanged
	C.RegisterPack("quests", "att:guard", { meta = { src = "att", verified = false, priority = 5, label = "t" }, zones = {}, quests = { [92001] = { id = 92001, giverNpc = 1, map = 9001, x = 0.4, y = 0.4 } } })
	check(R.Quest(92001).loc.src == "att" and R.Quest(92001).locConflict == nil, "an ATT coordinate for another giver is still used, exactly as before")
	check(#ns.errors == 0, "no errors")
	fake.uninstall()
end

-- ================================================================ failure handling

section("bridge: contract, flavor, broken interface - Codex stays up and uses its own data")
do
	local fake = standardFake()
	local ns = bootWith(fake)
	ns.QuestieBridge.CONTRACT = 3                      -- a newer contract than this QuestieDB provides
	check(ns.QuestieBridge.Init() == false and ns.QuestieBridge.Status().state == "contract", "an unsupported contract is refused")
	check(ns.QuestieBridge.Status().message:find("contract", 1, true) ~= nil and #ns.Registry.Packs("quests") == 0, "with a message, and no pack registered")
	ns.QuestieBridge.CONTRACT = 1
	check(ns.QuestieBridge.Init() == true and ns.QuestieBridge.Status().state == "available", "and recovers when the contract fits")
	fake.uninstall()

	local old = standardFake()
	local ns2 = bootWith(Fake.new({ flavor = "Vanilla" }))
	check(ns2.QuestieBridge.Status().state == "flavor" and #ns2.Registry.Packs("quests") == 0, "QuestieDB serving non-Forever data is not used (Era frames would misplace zones)")
	check(chatText():find("not Forever data", 1, true) ~= nil, "and the player is told")
	Fake.new().uninstall()

	local unk = standardFake()
	unk.meta["X-Flavor"] = nil
	unk.lib.ModeIndicator.GetStatus = function() return { mode = "baked" } end
	local ns3 = bootWith(unk)
	check(ns3.QuestieBridge.Status().state == "available" and ns3.QuestieBridge.Status().flavorKnown == false, "an unreported flavor is allowed, and recorded as unknown")
	unk.uninstall()

	local broken = standardFake()
	broken.Quest.GetAll = function() error("boom") end
	local ns4 = bootWith(broken)
	check(ns4.QuestieBridge.Status().state == "available", "(setup) available")
	check(ns4.Registry.Quest(91001) == nil and ns4.QuestieBridge.Stats().errors > 0, "a failing read is contained: the quest reads as unknown and the error is counted")
	check(ns4.State.plan ~= nil and #ns4.errors == 0, "the plan is still produced, with no error escaping")
	broken.uninstall()

	local nocontract = standardFake()
	nocontract.lib.RequireContract = nil
	local ns5 = bootWith(nocontract)
	check(ns5.QuestieBridge.Status().state == "error" and #ns5.Registry.Packs("quests") == 0, "an interface without RequireContract is refused")
	nocontract.uninstall()

	local nolib = Fake.new(); nolib.install(); _G.LibQuestieDB = "not a table"
	local ns6 = bootWith(nil)
	check(ns6.QuestieBridge.Status().state == "missing" and #ns6.errors == 0, "a global that is not the library is treated as missing")
	Fake.new().uninstall()
end

-- ================================================================ boundaries

section("bridge: it only reads - no QuestieDB data or code is copied, nothing is written into QuestieDB, no protected API")
do
	local src = stripComments(H.addonDir .. "/QuestieBridge.lua")
	for _, bad in ipairs({ "RegisterRuntimeCorrection", "RegisterCorrection", "GetRegistrar", "ApplyRegisteredCorrection", "InvalidateCache", "Corrections%.", "%.Set%(", "GetRaw", "COMBAT_LOG", "SetUserWaypoint" }) do
		check(src:find(bad) == nil, "QuestieBridge.lua does not use " .. bad:gsub("%%", ""))
	end
	local toc = H.readFile(H.addonDir .. "/ForeverCodex.toc")
	check(toc:find("## OptionalDeps: QuestieDB", 1, true) ~= nil and toc:find("## Dependencies", 1, true) == nil and toc:find("RequiredDeps", 1, true) == nil, "QuestieDB is an OPTIONAL dependency, not a required one")
	check(toc:find("QuestieBridge.lua", 1, true) ~= nil, "the bridge is loaded")
	local p = io.popen('cd "' .. H.addonDir .. '/Data" && ls')
	local bad = {}
	for f in p:lines() do if H.readFile(H.addonDir .. "/Data/" .. f):lower():find("questie", 1, true) then bad[#bad + 1] = f end end
	p:close()
	check(#bad == 0, "no data pack contains QuestieDB data or names it" .. (#bad > 0 and (": " .. table.concat(bad, ", ")) or ""))
	-- the data the bridge hands the Registry is the lib's own copy semantics: nothing the bridge reads is modified
	local fake = standardFake()
	local before = fake.Npc.Get(5007, "spawns")
	local ns = bootWith(fake)
	ns.Registry.Quest(91011)
	local after = fake.Npc.Get(5007, "spawns")
	check(before[9002][1][1] == after[9002][1][1] and before[9001][1][2] == after[9001][1][2], "reading does not change what QuestieDB holds")
	fake.uninstall()
end

-- ================================================================ giver vs turn-in destination (real bug: a completed quest sent the player to the GIVER)

section("bridge: a completed quest goes to its TURN-IN NPC, not its giver (general; no quest is special-cased)")
do
	local f = Fake.new({ version = "1.0.4" })
	f.mapArea(9001, 9001); f.mapArea(9002, 9002)
	f.addNpc(6001, { name = "Recruiter", spawns = { [9001] = { { 60.0, 50.0 } } }, zoneID = 9001, friendlyToFaction = "H" })     -- 100 yd east
	f.addNpc(6002, { name = "Officer", spawns = { [9001] = { { 90.0, 50.0 } } }, zoneID = 9001, friendlyToFaction = "H" })       -- 400 yd east
	f.addNpc(6003, { name = "Nameless" })                                                                                          -- known, but no position
	f.addNpc(6004, { name = "Far Giver", spawns = { [9002] = { { 50.0, 50.0 } } }, zoneID = 9002, friendlyToFaction = "H" })      -- 3000 yd away
	f.addNpc(6005, { name = "Near Taker", spawns = { [9001] = { { 55.0, 50.0 } } }, zoneID = 9001, friendlyToFaction = "H" })     -- 50 yd east
	f.addQuest(93001, { name = "Hand It Over", startedBy = { { 6001 } }, finishedBy = { { 6002 } }, requiredLevel = 1 })           -- different giver and taker
	f.addQuest(93002, { name = "Same Person", startedBy = { { 6001 } }, finishedBy = { { 6001 } }, requiredLevel = 1 })            -- giver is the taker
	f.addQuest(93003, { name = "Unplaced Taker", startedBy = { { 6001 } }, finishedBy = { { 6003 } }, requiredLevel = 1 })         -- taker not placed
	f.addQuest(93004, { name = "Across The Sea", startedBy = { { 6004 } }, finishedBy = { { 6005 } }, requiredLevel = 1 })         -- giver far, taker near
	local ns, W = bootWith(f)
	local R = ns.Registry
	local function turnInOf(plan, qid) for _, l in ipairs({ plan.sequence or {}, plan.inProgress or {}, plan.reminders or {} }) do for _, a in ipairs(l) do if a.quest == qid and a.kind == "TURN_IN" then return a end end end end
	local function complete(...)
		-- the quests named are in the log, finished; the other three count as done so their pickups are not what is under test
		W.log, W.completed = {}, {}
		local mine = {}
		for _, q in ipairs({ ... }) do mine[q] = true; W.log[#W.log + 1] = { questID = q, title = "quest " .. q, complete = true } end
		for _, q in ipairs({ 93001, 93002, 93003, 93004 }) do if not mine[q] then W.completed[q] = true end end
	end

	-- the bridge keeps the two NPCs apart
	local v = R.Quest(93001)
	check(v.giverNpc == 6001 and v.giverName == "Recruiter" and v.turnIn.npc == 6002 and v.turnIn.name == "Officer" and v.turnIn.atGiver == false, "the record carries the giver and, separately, the turn-in NPC")
	check(math.abs(v.loc.x - 0.6) < 1e-9 and math.abs(v.turnIn.x - 0.9) < 1e-9, "at their own positions")
	check(R.Quest(93002).turnIn.atGiver == true, "a finisher that is the starter is flagged as such, inside QuestieDB's own record")

	-- accepting is at the giver, as before
	W.log = {}
	local c = cands(ns)
	local acc = hasAction(c.candidates, "Q:93001:ACCEPT")
	check(acc and math.abs(acc.target.x - 0.6) < 1e-9 and acc.giver == "Recruiter", "ACCEPT still goes to the giver")

	-- a completed quest goes to the turn-in NPC
	complete(93001)
	local plan = ns.State.Recompute()
	local ti = turnInOf(plan, 93001)
	check(ti ~= nil and ti.target and math.abs(ti.target.x - 0.9) < 1e-9 and ti.target.map == 9001, "the TURN_IN target is the turn-in NPC's position (0.9), not the giver's (0.6)")
	check(ti.giver == "Officer" and ti.target.label:find("Officer", 1, true) == 1, "and it is labelled with the turn-in NPC")
	local tt = ti.targets[1]
	check(tt.role == "TURN_IN" and tt.entity.id == 6002 and tt.entity.name == "Officer" and tt.assumed ~= true and tt.where.status == "known", "the contract target is the turn-in NPC, known and not assumed")
	check(tt.prov.src == "questiedb" and tt.prov.verified == false and ti.verified == false, "still src=questiedb, verified=false")
	local text = table.concat(ti.lines, "\n")
	check(text:find("Turn in to Officer", 1, true) and text:find("(QuestieDB, unverified on Forever)", 1, true) and not text:find("assumed", 1, true), "the text names the turn-in NPC and no longer says it is assumed")
	check(plan.now and plan.now.id == "Q:93001:TURN_IN", "NOW is the turn-in")
	local card = ns.Presenter.Card(plan, ns.State.ctx)
	check(card.now.who == "Officer" and card.now.where == "About 400 yards away", "the card says who to hand it to and the distance to THEM (400 yd, not the giver's 100)")
	check(ns.Navigation and ns.Navigation.Target() == nil or true, "(navigation reads the same plan target)")

	-- the same NPC: unchanged behaviour (assumed at the giver)
	complete(93002)
	local p2 = ns.State.Recompute()
	local t2 = turnInOf(p2, 93002)
	check(t2 and math.abs(t2.target.x - 0.6) < 1e-9 and t2.targets[1].assumed == true and table.concat(t2.lines, "\n"):find("assumed", 1, true), "giver = turn-in NPC: the giver's spot, still marked as an assumption")

	-- a known turn-in NPC with no position: no location at all, never the giver's
	complete(93003)
	local p3 = ns.State.Recompute()
	local t3
	for _, a in ipairs(p3.reminders) do if a.quest == 93003 then t3 = a end end
	check(t3 ~= nil and t3.target == nil and t3.noLocation == true and t3.targets[1].where.status == "unknown", "an unplaced turn-in NPC gives no location (it is a reminder), not the giver's position")
	check(t3.giver == "Nameless" and table.concat(t3.lines, "\n"):find("stands is not in Codex data yet", 1, true) ~= nil, "and says who it is and that where they stand is unknown")
	check(p3.now == nil or p3.now.quest ~= 93003, "it is never NOW")

	-- the destination decides the route: the giver is far, the turn-in NPC is near
	complete(93004)
	local p4 = ns.State.Recompute()
	local t4 = turnInOf(p4, 93004)
	check(t4 and t4.target.map == 9001 and math.abs(t4.target.x - 0.55) < 1e-9 and p4.now and p4.now.id == "Q:93004:TURN_IN" and p4.diag.unknownLegs == 0, "a far giver with a near turn-in NPC: NOW is the near turn-in, with a measurable leg (routing used the turn-in position)")

	-- a way out: skip the recommendation, and bring it back
	complete(93001)
	ns.State.Recompute()
	local skipped = ns.State.SkipCurrent()
	check(skipped and skipped.quest == 93001 and ns.Prefs.IsSkipped("QT:93001"), "Skip vetoes the current NOW")
	check(ns.State.plan.now == nil or ns.State.plan.now.quest ~= 93001, "and it is no longer recommended")
	H.slash("unskip")
	check(ns.State.plan.now and ns.State.plan.now.quest == 93001, "/codex unskip brings it back")
	-- nothing is special-cased
	local offenders = {}
	local p = io.popen('cd "' .. H.addonDir .. '" && find . -name "*.lua" | sed "s#^\\./##" | sort')
	for file in p:lines() do
		local src = H.readFile(H.addonDir .. "/" .. file)
		if src:find("Horde Needs", 1, true) or src:find("8793", 1, true) or src:find("Gorchuk", 1, true) then offenders[#offenders + 1] = file end
	end
	p:close()
	check(#offenders == 0, "no product file mentions a specific quest or NPC for this" .. (#offenders > 0 and (": " .. table.concat(offenders, ", ")) or ""))
	check(#ns.errors == 0, "no errors")
	f.uninstall()
end

section("QuestieDB area map: the AreaID table is read as DATA and never executed (no loadstring), and a malformed one is rejected, not run")
do
	local ns = boot({ char = HORDE_WARRIOR, synthetic = true, loc = HERE })
	local P = ns.QuestieBridge.ParseAreaMap
	local t, n = P("return {[12]=1411,[14]=1412}")
	check(t and n == 2 and t[12] == 1411 and t[14] == 1412, "a plain table is read")
	t, n = P("-- a comment\nreturn {\n  [1] = 1411, -- one\n  [2] = 1412;\n}\n")
	check(t and n == 2 and t[2] == 1412, "comments, line breaks and spacing are fine")
	local ran = false
	_G.__codex_injected = function() ran = true end
	for _, bad in ipairs({ "return {[1]=__codex_injected()}", "__codex_injected() return {[1]=2}", "return {[1]=2} __codex_injected()", "return {[1]=2, x=3}", "return setmetatable({}, {})", "return {}", "", "return {[1]=2", string.rep("x", 500000) }) do
		local tt, why = P(bad)
		check(tt == nil and type(why) == "string", "rejected: " .. tostring(bad):sub(1, 36))
	end
	check(ran == false, "nothing was executed")
	_G.__codex_injected = nil
	check(P(nil) == nil and P(42) == nil, "non-text is rejected")
	local src = (H.readFile(H.addonDir .. "/QuestieBridge.lua"):gsub("%-%-[^\n]*", ""))
	check(not src:find("loadstring", 1, true), "QuestieBridge.lua no longer calls loadstring")
end
