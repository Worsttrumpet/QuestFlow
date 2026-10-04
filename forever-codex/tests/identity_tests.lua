-- identity_tests.lua: character-state isolation (Preferences.CheckIdentity, 0.7.5). Name-Realm is not a character identity: a deleted character's name can be reused. Stub-client tests of
-- Codex's OWN rules; they do not show that Forever returns a usable UnitGUID("player") (unproven), so the GUID path is tested with a stub and the heuristic path is the one relied on.

local H = ...
local check, section, boot = H.check, H.section, H.boot

local ROGUE = { name = "Codex", class = "Rogue", classToken = "ROGUE", race = "Skyborne", raceToken = "Skyborne", faction = "Horde", level = 14 }
local HUNTER = { name = "Codex", class = "Hunter", classToken = "HUNTER", race = "Tauren", raceToken = "Tauren", faction = "Horde", level = 2 }

local function session(char, db, guid)
	_G.UnitGUID = guid and function(u) if u == "player" then return guid end end or nil
	local ns = boot({ char = char, synthetic = true, savedVars = db })
	ns.State.Recompute()
	return ns
end
--- Gameplay state for the current character: skips, an added quest, a journey (via levels), a turn-in, Spell Training and Professions state, and a chosen route zone.
local function play(ns)
	local P = ns.Prefs
	P.Skip("Q:92481"); P.Skip("QT:93836"); P.Add(777)
	ns.Journey.OnQuestTurnedIn(1000, 50); ns.Journey.OnQuestTurnedIn(1001, 50)
	local c = P.Char()
	c.spellTraining = { class = c.spellTraining and c.spellTraining.class or "ROGUE", entries = { ["S:1"] = { name = "Sprint", levelReq = 10, cost = 100 } }, dismissed = { ["S:1"] = { name = "Sprint" } } }
	c.professions = { rankUps = { ["S:393"] = { service = "Journeyman Skinning", maxAt = 75 } }, hidden = { fishing = true } }
	c.routeZone = "zephras-isle"
	P.SetStyle("fast")
	P.SetSystem("flight", false)
end
local function gameplay(ns)
	local c = ns.Prefs.Char()
	local nSkip, nAdd = 0, 0
	for _ in pairs(c.skipped) do nSkip = nSkip + 1 end
	for _ in pairs(c.added) do nAdd = nAdd + 1 end
	return { skips = nSkip, added = nAdd, turned = ns.Journey.TurnedInCount(), journey = #c.journey.entries, spells = c.spellTraining, profs = c.professions, zone = c.routeZone }
end

section("identity: a reused name with a different class and race starts clean (skips, added quests, journey, turn-ins, Spell Training, Professions, route zone)")
do
	local ns = session(ROGUE)
	play(ns)
	local g = gameplay(ns)
	check(g.skips == 2 and g.added == 1 and g.turned == 2 and g.journey >= 1 and g.spells and g.profs, "(setup) the Rogue has accumulated state")
	ForeverCodexDB.ui.window = { point = "CENTER", rel = "CENTER", x = 10, y = 20, w = 330, h = 300 }
	ForeverCodexDB.offers = { v = 1, quests = { [5] = { title = "kept" } } }
	ForeverCodexDB.telemetry = { v = 1, enabled = true, events = { { e = "X" } }, accepted = {}, cap = 300 }
	local db = _G.ForeverCodexDB
	local ns2 = session(HUNTER, db)
	local g2 = gameplay(ns2)
	check(g2.skips == 0 and g2.added == 0 and g2.turned == 0 and g2.spells == nil and g2.profs == nil and g2.zone == "auto", "the new Tauren Hunter inherits no skips, added quests, turn-ins, Spell Training, Professions or route zone")
	check(g2.journey <= 1, "and no journey (only its own start entry)  [" .. g2.journey .. "]")
	check(ns2.Prefs.lastIdentity.result == "RESET" and ns2.Prefs.lastIdentity.signal == "class", "the check says why: a different class")
	local said = false
	for _, m in ipairs(H.world().chat) do if m:find("new character with a name Codex has seen before", 1, true) then said = true end end
	check(said, "and tells the player once")
	check(ns2.Prefs.Char().identityReset and ns2.Prefs.Char().identityReset.was.class == "ROGUE", "the reset is recorded (what it replaced, no gameplay data)")
	check(db.ui.window and db.ui.window.x == 10 and db.offers.quests[5].title == "kept" and db.telemetry.events[1].e == "X", "the window position and the account-wide stores are untouched")
	check(ns2.Prefs.GetStyle() == "fast" and ns2.Prefs.IsSystemOn("flight") == false, "route style and system toggles are kept")
	check(#ns2.errors == 0, "no errors")
end

section("identity: a reused name with the same class and race but a LOWER level is a new character; normal level progression is not")
do
	local ns = session({ name = "Codex", class = "Rogue", classToken = "ROGUE", race = "Skyborne", raceToken = "Skyborne", faction = "Horde", level = 14 })
	play(ns)
	local db = _G.ForeverCodexDB
	local nsLow = session({ name = "Codex", class = "Rogue", classToken = "ROGUE", race = "Skyborne", raceToken = "Skyborne", faction = "Horde", level = 2 }, db)
	check(gameplay(nsLow).skips == 0 and nsLow.Prefs.lastIdentity.signal == "level", "level 2 after a level 14 history: reset (levels never go down)  [" .. tostring(nsLow.Prefs.lastIdentity.reason) .. "]")
	-- the same character levelling normally
	local a = session({ name = "Codex", class = "Rogue", classToken = "ROGUE", race = "Skyborne", raceToken = "Skyborne", faction = "Horde", level = 10 })
	play(a)
	local db2 = _G.ForeverCodexDB
	local before = gameplay(a)
	local a2 = session({ name = "Codex", class = "Rogue", classToken = "ROGUE", race = "Skyborne", raceToken = "Skyborne", faction = "Horde", level = 11 }, db2)
	local a3 = session({ name = "Codex", class = "Rogue", classToken = "ROGUE", race = "Skyborne", raceToken = "Skyborne", faction = "Horde", level = 11 }, db2)
	local after = gameplay(a3)
	check(a3.Prefs.lastIdentity.result == "SAME" and after.skips == before.skips and after.added == before.added and after.turned == before.turned and after.zone == "zephras-isle" and after.spells ~= nil and after.profs ~= nil,
		"a normal level-up and a relog keep everything (skips, added, turn-ins, route zone, Spell Training, Professions)")
	check(a3.Prefs.Char().identity.maxLevel == 11, "the highest level seen follows the character up")
end

section("identity: Spell Training and Professions state are per character and survive a relog of the same character")
do
	local ns = session(ROGUE)
	play(ns)
	local db = _G.ForeverCodexDB
	local same = session(ROGUE, db)
	check(same.Prefs.Char().spellTraining.dismissed["S:1"] ~= nil and same.Prefs.Char().professions.hidden.fishing == true, "the same character keeps its dismissals and hidden reminders")
	local other = session({ name = "Other", class = "Rogue", classToken = "ROGUE", race = "Skyborne", raceToken = "Skyborne", faction = "Horde", level = 14 }, db)
	check(other.Prefs.Char().spellTraining == nil and other.Prefs.Char().professions == nil, "another name never had them")
	check(db.chars["Codex-Forever"].spellTraining.dismissed["S:1"] ~= nil, "and the first character's are still stored")
end

section("identity: a hashed character id, when the client gives one, is stronger than the fingerprint; the raw id is never stored")
do
	local ns = session(ROGUE, nil, "Player-1234-0ABCDEF1")
	play(ns)
	local db = _G.ForeverCodexDB
	local same = session(ROGUE, db, "Player-1234-0ABCDEF1")
	check(same.Prefs.lastIdentity.result == "SAME" and same.Prefs.lastIdentity.signal == "guid" and gameplay(same).skips == 2, "the same id: same character")
	local re = session(ROGUE, db, "Player-1234-0FFFFFF2")
	check(re.Prefs.lastIdentity.result == "RESET" and re.Prefs.lastIdentity.signal == "guid" and gameplay(re).skips == 0, "a different id under the same name, class, race and level: reset (the case the fingerprint cannot see)")
	local function scan(t, d) for k, v in pairs(t) do if type(v) == "string" and v:find("Player-", 1, true) then return true end if type(v) == "table" and d < 8 and scan(v, d + 1) then return true end end return false end
	check(not scan(db, 0), "no raw Player GUID appears anywhere in the saved variables")
	check(type(re.Prefs.Char().identity.guid) == "string" and #re.Prefs.Char().identity.guid == 16, "only a 16-digit hash is kept")
	_G.UnitGUID = nil
end

section("identity: legacy saves (no fingerprint) are judged by the highest level in their journey; nothing is reset without evidence")
do
	local ns = session(ROGUE)
	play(ns)
	local db = _G.ForeverCodexDB
	db.chars["Codex-Forever"].identity = nil                      -- as saved by 0.7.4 and earlier
	local nsNew = session(HUNTER, db)
	check(nsNew.Prefs.lastIdentity.result == "RESET" and nsNew.Prefs.lastIdentity.signal == "legacy-level" and gameplay(nsNew).skips == 0, "a legacy save with a level 14 journey and a level 2 character: reset")
	local ns3 = session({ name = "Codex", class = "Rogue", classToken = "ROGUE", race = "Skyborne", raceToken = "Skyborne", faction = "Horde", level = 14 })
	play(ns3)
	local db3 = _G.ForeverCodexDB
	db3.chars["Codex-Forever"].identity = nil
	local ns4 = session({ name = "Codex", class = "Rogue", classToken = "ROGUE", race = "Skyborne", raceToken = "Skyborne", faction = "Horde", level = 14 }, db3)
	check(ns4.Prefs.lastIdentity.result == "FIRST" and gameplay(ns4).skips == 2 and ns4.Prefs.Char().identity.maxLevel == 14, "a legacy save that nothing contradicts is kept and gets a fingerprint")
	check(ns3.Prefs.lastIdentity.result == "FIRST", "a character with no earlier state is FIRST")
end
