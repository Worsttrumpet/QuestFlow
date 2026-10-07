-- saved_data_tests.lua (audit hardening): per-character telemetry and NPC offer evidence (no leak from character A to character B), the central saved-data migration (old saves keep their data),
-- and the QuestieDB on/off switch. Stub-client tests: they prove Codex's own storage logic, not the real client.

local H = ...
local check, section, boot = H.check, H.section, H.boot

local function char(name, class) return { name = name, class = class or "Warrior", classToken = (class or "Warrior"):upper(), race = "Orc", raceToken = "Orc", faction = "Horde", level = 5 } end
local function session(name, db, class)
	local ns = boot({ char = char(name, class), synthetic = true, savedVars = db })
	ns.Prefs.FinishSetup()
	return ns
end
local function stubNpc(name, id)
	_G.UnitName = function(u) return u == "npc" and name or "Someone" end
	_G.UnitGUID = function(u) return u == "npc" and ("Creature-0-1-2-3-" .. id .. "-ABCDEF") or nil end
end
local function offerQuest(ns, qid, title, npc, id)
	stubNpc(npc, id)
	_G.C_GossipInfo = { GetAvailableQuests = function() return { { questID = qid, title = title } } end, GetActiveQuests = function() return {} end, GetOptions = function() return {} end }
	ns.OfferProbe.OnEvent("GOSSIP_SHOW")
end
local function eventsOf(ns) local out = {} for _, e in ipairs(ns.Telemetry.Events()) do out[#out + 1] = e.e .. ":" .. tostring(e.q or "") end return table.concat(out, ",") end

section("isolation: character B never sees character A's telemetry or NPC offer evidence; A gets its own back")
do
	local db = {}
	local a = session("Alpha", db)
	a.Telemetry.Record("QUEST_ACCEPT", { q = 111 })
	offerQuest(a, 7001, "Alpha's Quest", "Alpha Giver", 5001)
	check(a.OfferProbe.QuestEvidence(7001) ~= nil and eventsOf(a):find("QUEST_ACCEPT:111", 1, true), "(setup) Alpha recorded an accept and an offered quest")
	check(db.telemetry.owner == "Alpha-Forever" and db.offers.owner == "Alpha-Forever", "the live stores are stamped with their owner")
	local b = session("Bravo", db)
	check(not eventsOf(b):find("111", 1, true) and b.OfferProbe.QuestEvidence(7001) == nil and b.OfferProbe.NpcContext(5001) == nil, "Bravo sees none of Alpha's events, offered quests or NPC dialogs")
	check(db.telemetry.owner == "Bravo-Forever" and db.offers.owner == "Bravo-Forever", "the live stores are Bravo's")
	check(db.chars["Alpha-Forever"].parked and db.chars["Alpha-Forever"].parked.telemetry and db.chars["Alpha-Forever"].parked.offers and db.chars["Alpha-Forever"].parked.offers.quests[7001], "Alpha's data is PARKED under Alpha, not lost")
	b.Telemetry.Record("QUEST_ACCEPT", { q = 222 })
	offerQuest(b, 7002, "Bravo's Quest", "Bravo Giver", 5002)
	local a2 = session("Alpha", db)
	check(eventsOf(a2):find("QUEST_ACCEPT:111", 1, true) and not eventsOf(a2):find("222", 1, true), "Alpha logs back in: its events are back and Bravo's are not mixed in")
	check(a2.OfferProbe.QuestEvidence(7001) ~= nil and a2.OfferProbe.QuestEvidence(7002) == nil, "and its offer evidence is its own")
	check(db.chars["Bravo-Forever"].parked.offers.quests[7002] ~= nil, "Bravo's is parked for Bravo")
	check(a2.Prefs.IsSavedVariablesSafe(db), "the save is still SavedVariables-safe")
	check(#a.errors == 0 and #b.errors == 0 and #a2.errors == 0, "no errors")
end

section("isolation: a dialog Alpha saw cannot hold back a quest for Bravo (the stale-evidence path stays closed)")
do
	local db = {}
	local a = session("Alpha", db)
	stubNpc("Hub Giver", 7001)
	_G.C_GossipInfo = { GetAvailableQuests = function() return {} end, GetActiveQuests = function() return {} end, GetOptions = function() return {} end }
	a.OfferProbe.OnEvent("GOSSIP_SHOW")
	check(a.OfferProbe.NpcContext(7001) ~= nil, "(setup) Alpha saw an empty listing at the hub NPC")
	local b = session("Bravo", db)
	check(b.OfferProbe.NpcContext(7001) == nil, "Bravo has no record of that dialog at all")
end

section("migration: an old single-character save keeps its telemetry and offers, stamped to that character, and reaches the current version")
do
	local db = { version = 1, ui = { windowLayout = 3, window = { point = "CENTER", rel = "CENTER", x = 5, y = 6, w = 330, h = 200 } },
		chars = { ["Solo-Forever"] = { style = "fast", routeZone = "auto", skipped = { ["Q:5"] = true }, setupDone = true, journey = { entries = { { k = "start", lvl = 3 } }, turnedIn = { [9] = true } } } },
		offers = { v = 1, quests = { [5] = { title = "kept offer" } }, npcs = {}, obs = {}, proof = {}, stats = {} },
		telemetry = { v = 1, enabled = true, events = { { e = "QUEST_ACCEPT", q = 9 } }, accepted = {}, cap = 300 } }
	local ns = session("Solo", db)
	check(db.version == ns.Prefs.DB_VERSION and db.version >= 2, "the save reached the current version")
	check(db.offers.owner == "Solo-Forever" and db.telemetry.owner == "Solo-Forever" and db.offers.quests[5].title == "kept offer" and db.telemetry.events[1].q == 9, "the only character in the save keeps its offers and telemetry")
	check(db.chars["Solo-Forever"].style == "fast" and db.chars["Solo-Forever"].skipped["Q:5"] == true and db.chars["Solo-Forever"].journey.turnedIn[9] == true and db.ui.window.x == 5, "choices, skips, journey and the window position are untouched")
	check(db.migrations and db.migrations[1].from == 1 and db.migrations[1].to == db.version and #db.migrations[1].steps >= 1, "the migration is recorded (what it did)")
	check(table.concat(ns.SavedData.SavedDataLines(), "\n"):find("migrated this session: 1 ->", 1, true) ~= nil, "and the report says so")
	local before = #db.migrations
	local again = session("Solo", db)
	check(#db.migrations == before and #again.errors == 0 and #ns.errors == 0, "logging in again migrates nothing (idempotent)")
end

section("migration: an old save with MORE THAN ONE character archives the ownerless stores (nothing deleted, nothing shared)")
do
	local db = { version = 1, ui = {}, chars = { ["One-Forever"] = { setupDone = true }, ["Two-Forever"] = { setupDone = true } },
		offers = { v = 1, quests = { [5] = { title = "whose?" } }, npcs = {}, obs = {}, proof = {}, stats = {} },
		telemetry = { v = 1, enabled = true, events = { { e = "QUEST_ACCEPT", q = 9 } }, accepted = {}, cap = 300 } }
	local ns = session("One", db)
	check(db.legacy and db.legacy.offers and db.legacy.offers.quests[5].title == "whose?" and db.legacy.telemetry and db.legacy.telemetry.events[1].q == 9, "both stores are archived under legacy, untouched")
	check(db.offers.owner == "One-Forever" and next(db.offers.quests) == nil and not eventsOf(ns):find("QUEST_ACCEPT:9", 1, true), "the logged-in character starts with its own empty stores, not the archive")
	local two = session("Two", db)
	check(two.OfferProbe.QuestEvidence(5) == nil and not eventsOf(two):find("QUEST_ACCEPT:9", 1, true), "neither character reads the archive")
	check(table.concat(ns.SavedData.SavedDataLines(), "\n"):find("archived, owner unknown", 1, true) ~= nil, "the report lists the archive")
end

section("migration: a save from before the version number existed is version 1; a brand-new install is current; a NEWER save is never touched; a failing step is contained")
do
	local old = { chars = { ["Solo-Forever"] = { setupDone = true } }, telemetry = { v = 1, enabled = true, events = { { e = "X" } }, accepted = {}, cap = 300 } }
	local ns = session("Solo", old)
	check(old.version == ns.Prefs.DB_VERSION and old.telemetry.owner == "Solo-Forever", "no version field: migrated from 1")
	local fresh = {}
	local ns2 = session("Fresh", fresh)
	check(fresh.version == ns2.Prefs.DB_VERSION and fresh.migrations == nil and fresh.legacy == nil, "an empty save is current: nothing to migrate")
	local newer = { version = 99, chars = { ["Solo-Forever"] = { setupDone = true } }, telemetry = { v = 1, enabled = true, events = { { e = "NEWER" } }, accepted = {}, cap = 300 } }
	local ns3 = session("Solo", newer)
	check(newer.version == 99 and newer.telemetry.events[1].e == "NEWER" and newer.telemetry.owner == "Solo-Forever" and #ns3.errors == 0, "a save from a NEWER Quest Flow keeps its version and its data (and no error)")
	check(ns3.SavedData.lastMigration.newer == true and table.concat(ns3.SavedData.SavedDataLines(), "\n"):find("NEWER Quest Flow", 1, true) ~= nil, "and the report says it was left alone")
end

section("QuestieDB switch: off means nothing is read from the addon at all; on restores it; the choice is account-wide")
do
	local fake = H.fake.new()
	fake.install()
	local ns = boot({ char = char("Qdb"), synthetic = true })
	local QB = ns.QuestieBridge
	check(ns.Prefs.UseQuestieDB() == true, "default: on (the way Quest Flow has always worked)")
	ns.Prefs.SetUseQuestieDB(false)
	QB.Init()
	check(QB.Status().state == "disabled" and QB.Available() == false and QB.Status().message:find("turned off", 1, true), "off: the bridge reports 'disabled' and is not available")
	check(ForeverCodexDB.ui.useQuestieDB == false, "the choice is stored account-wide (ui)")
	ns.Prefs.SetUseQuestieDB(true)
	QB.Init()
	check(QB.Status().state ~= "disabled", "on again: the bridge tries the addon again  [" .. tostring(QB.Status().state) .. "]")
	check(#ns.errors == 0, "no errors")
	fake.uninstall()
end

section("game quest tracker: no Hide or Show while in combat; it is postponed and applied when combat ends (audit L2)")
do
	local shown, combat = true, false
	local frame = { Hide = function() shown = false end, Show = function() shown = true end }
	_G.ObjectiveTrackerFrame = frame
	local hookFn
	_G.hooksecurefunc = function(f, name, fn) if f == frame and name == "Show" then hookFn = fn; local orig = f.Show; f.Show = function(...) orig(...); fn(...) end end end
	_G.InCombatLockdown = function() return combat end
	local ns = boot({ char = char("Tracker"), synthetic = true })
	ns.Prefs.SetHideBlizzardTracker(true)
	combat = true
	ns.BlizzardTracker.Apply()
	check(shown == true and ns.BlizzardTracker.pending == true and ns.BlizzardTracker.Status().state == "waiting for combat to end", "in combat: nothing is hidden, the request is remembered")
	combat = false
	ns._selftest.boot.onEvent(nil, "PLAYER_REGEN_ENABLED")
	check(shown == false and ns.BlizzardTracker.pending == false, "combat ends: it is hidden")
	combat = true
	frame.Show()
	local shownDuringCombat = shown
	check(shownDuringCombat == true and ns.BlizzardTracker.pending == true, "the re-hide hook does not Hide during combat either; it waits")
	combat = false
	ns._selftest.boot.onEvent(nil, "PLAYER_REGEN_ENABLED")
	check(shown == false, "and hides it when combat ends")
	ns.Prefs.SetHideBlizzardTracker(false)
	ns.BlizzardTracker.Apply()
	_G.ObjectiveTrackerFrame, _G.hooksecurefunc, _G.InCombatLockdown = nil, nil, nil
	check(#ns.errors == 0, "no errors")
end

section("caught errors are announced once per place, at most three per session, and still recorded")
do
	local ns = boot({ char = char("Errs"), synthetic = true })
	local W = H.world()
	W.chat = {}
	ns.RecordError("alpha", "boom")
	ns.RecordError("alpha", "boom again")
	ns.RecordError("beta", "x")
	ns.RecordError("gamma", "x")
	ns.RecordError("delta", "x")
	local said = 0
	for _, m in ipairs(W.chat) do if m:find("Quest Flow caught an error in", 1, true) then said = said + 1 end end
	check(said == 3, "three announcements: one per distinct place, no repeats, no fourth  [" .. said .. "]")
	local n = 0
	for _, e in ipairs(ns.errors) do if e:find("^alpha:") or e:find("^beta:") or e:find("^gamma:") or e:find("^delta:") then n = n + 1 end end
	check(n == 5, "all five are still recorded for /qflow diag")
	ns.errors = {}                                                 -- (these were deliberate: leave nothing for later checks to trip over)
end
