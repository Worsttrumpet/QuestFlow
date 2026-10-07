-- onboarding_tests.lua (0.13.0): the first-run welcome. The state is per character (Preferences: setupDone + onboarded), the welcome is three short steps on the existing setup panel, and finishing it
-- only ever ADDS the completion flag: no existing choice, skip, journey or evidence is reset. A relog / reload is a second boot over the same SavedVariables table.
-- Stub-client tests: they prove Quest Flow's own logic, not how the screen looks in the game (that is the manual checklist, Part J).

local H = ...
local check, section, boot = H.check, H.section, H.boot

local function char(name, level) return { name = name, class = "Rogue", classToken = "ROGUE", race = "Orc", raceToken = "Orc", faction = "Horde", level = level or 8 } end
local function session(name, db, level)
	return boot({ char = char(name, level), synthetic = true, savedVars = db, loc = { map = 9001, x = 0.5, y = 0.5, zone = "Test" } })
end
local function click(b) b.__scripts.OnClick(b) end
local function recs() return { { id = 1, name = "Near Quest", map = 9001, x = 0.52, y = 0.5, req = 1, level = 8 } } end
local function key(ns) return ns.Prefs.CharKey() end

section("onboarding: a brand-new character needs setup, and the welcome is what opens (nothing else is blocked)")
do
	local db = {}
	local ns = session("Newbie", db)
	check(ns.Prefs.SetupDone() == false, "a brand-new character has not completed setup")
	check(ns.UI.Init() == "setup" and ns.UI.options and ns.UI.options.__shown, "the welcome (setup on the options window) is what opens at login")
	local setup = ns.UI.main.setupPanel
	check(setup.frame.__shown and setup.w.title.__text == "Welcome to Quest Flow" and setup.w.tagline.__text == "See what's available. Choose what comes next.", "it carries the Quest Flow name and the tagline")
	check(setup.w.logo ~= nil, "and the logo")
	check(setup.w.step == 1 and setup.w.groups[1].__shown and not setup.w.groups[2].__shown and not setup.w.groups[3].__shown, "it starts on step 1 only")
	local text = table.concat({ setup.w.welcome.__text, setup.w.nowHead.__text, setup.w.nowText.__text, setup.w.alsoHead.__text, setup.w.alsoText.__text, setup.w.honestText.__text }, " ")
	check(text:find("NOW", 1, true) and text:find("ALSO DO", 1, true) and text:find("what the game itself offers", 1, true), "step 1 explains NOW, ALSO DO and that availability comes from the game")
	check(not text:lower():find("questie") and not text:lower():find("att") and not text:lower():find("telemetry"), "and says nothing technical (no data-source names)")
	check(#text < 700, "and is short (" .. #text .. " characters)")
	-- the addon works while the welcome is open
	H.attPack(ns, recs(), nil)
	ns.State.Recompute()
	check(ns.State.plan.now ~= nil and ns.State.plan.now.id == "Q:1:ACCEPT", "the planner plans while the welcome is open")
	check(ns.OfferProbe ~= nil and ns.Taxi ~= nil and ns.Services ~= nil and ns.Telemetry ~= nil and #ns.errors == 0, "observation systems are loaded and nothing errored")
	_G.UnitName = function(u) return u == "npc" and "Hand Giver" or "Someone" end
	_G.UnitGUID = function(u) return u == "npc" and "Creature-0-1-2-3-4321-ABCDEF" or nil end
	_G.C_GossipInfo = { GetAvailableQuests = function() return { { questID = 1, title = "Near Quest" } } end, GetActiveQuests = function() return {} end, GetOptions = function() return {} end }
	ns.OfferProbe.OnEvent("GOSSIP_SHOW")
	check(ns.OfferProbe.QuestEvidence(1) ~= nil and ns.Prefs.SetupDone() == false, "an NPC dialog is still recorded as offer evidence during setup")
end

section("onboarding: the steps, the theme and the basic settings")
do
	local db = {}
	local ns = session("Walker", db)
	local setup = ns.UI.main.setupPanel
	local w = setup.w
	click(w.next1)
	check(w.step == 2 and w.groups[2].__shown and not w.groups[1].__shown, "Next shows step 2")
	check(w.theme.text.__text ~= "" and w.trackerOn ~= nil and w.navOn ~= nil and w.arrowOn ~= nil, "step 2 offers the theme and the on-screen choices")
	-- theme
	local before = ns.Theme.Key()
	click(w.theme)
	local other
	for _, r in ipairs(w.theme.rows) do if r.__shown and r.key and r.key ~= before then other = r break end end
	check(other ~= nil, "the theme list offers a theme other than the current one (only the existing themes: " .. #ns.Theme.ORDER .. ")")
	click(other)
	check(ns.Theme.Key() == other.key and ns.Prefs.ThemeKey() == other.key, "choosing a theme applies it and stores it")
	-- basic settings
	local navBefore, arrowBefore, trackerBefore = ns.Prefs.NavigationOn(), ns.Prefs.ArrowOn(), ns.Prefs.TrackerShown()
	click(w.navOn) click(w.arrowOn) click(w.trackerOn)
	check(ns.Prefs.NavigationOn() ~= navBefore and ns.Prefs.ArrowOn() ~= arrowBefore and ns.Prefs.TrackerShown() ~= trackerBefore, "the waypoint, arrow and tracker choices flip")
	click(w.next2)
	check(w.step == 3 and w.groups[3].__shown, "Next shows step 3")
	local styleBefore = ns.Prefs.GetStyle()
	click(w.style)
	local s2
	for _, r in ipairs(w.style.rows) do if r.__shown and r.key ~= styleBefore then s2 = r break end end
	if s2 then click(s2) end
	click(w.back3)
	check(w.step == 2, "Back goes back a step")
	click(w.next2)
	-- finish
	click(w.start)
	local saved = db.chars[key(ns)]
	check(ns.Prefs.SetupDone() and saved.setupDone == true and saved.onboarded == ns.Prefs.ONBOARDING_VERSION and saved.onboardedAt ~= nil, "Get Started stores the completion on the character")
	check(not setup.frame.__shown or ns.UI.options == nil or not ns.UI.options.__shown or ns.UI.main.settingsPanel.frame.__shown, "and leaves the normal options (the welcome closed)")
	check(db.ui.theme == other.key and saved.navigation == (not navBefore) and saved.arrow == (not arrowBefore) and db.ui.trackerShown == (not trackerBefore) and saved.style ~= nil, "the chosen theme and settings are in the saved data")
	check(w.step == 1, "the welcome is back on step 1 for the next time")
	check(#ns.errors == 0, "no errors")
	-- with the tracker turned off, Get Started closes the welcome instead of opening the tracker
	check(ns.Prefs.TrackerShown() == false and not (ns.UI.frame and ns.UI.frame.__shown), "a tracker the player turned off stays closed")
end

section("onboarding: reload and relog do not bring the welcome back; a second character has its own")
do
	local db = {}
	local ns = session("Alpha", db)
	click(ns.UI.main.setupPanel.w.start)
	check(ns.Prefs.SetupDone(), "(setup) Alpha finished the welcome")
	-- /reload: the same character, a second boot over the same saved table
	local again = session("Alpha", db)
	check(again.Prefs.SetupDone() == true and again.UI.Init() ~= "setup", "after /reload the welcome does not return")
	check(not (again.UI.main.setupPanel and again.UI.main.setupPanel.frame.__shown), "and its panel is not showing")
	local third = session("Alpha", db)
	check(third.Prefs.SetupDone() == true and third.UI.Init() ~= "setup", "nor after a third login (relog / restart)")
	-- closing and reopening the Quest Flow windows
	third.UI.Open("codex") third.UI.Open("options") third.UI.Open("themes")
	check(third.Prefs.SetupDone() == true, "opening and closing the windows does not reopen it")
	-- another character on the same account
	local beta = session("Beta", db)
	check(beta.Prefs.SetupDone() == false and beta.UI.Init() == "setup", "a second character gets its own welcome")
	click(beta.UI.main.setupPanel.w.start)
	check(beta.Prefs.SetupDone() and db.chars["Alpha-" .. (beta.Prefs.CharKey():match("%-(.+)$") or "")] ~= nil and db.chars[key(beta)].onboarded == 1, "and finishing it records on Beta only")
	local alphaAgain = session("Alpha", db)
	check(alphaAgain.Prefs.SetupDone() == true, "Alpha is unaffected")
end

section("onboarding: a character saved before the welcome existed is shown it once, and nothing it saved is touched")
do
	local db = { version = 2, ui = { theme = "contrast", trackerShown = true },
		chars = { ["Veteran-Forever"] = { style = "fast", routeZone = "auto", setupDone = true, navigation = false, skipped = { ["Q:5"] = true }, added = { [9] = true },
			journey = { entries = { { k = "start", lvl = 3 } }, turnedIn = { [9] = true } } } } }
	local ns = session("Veteran", db)
	local c = db.chars["Veteran-Forever"]
	check(c.setupDone == true and c.onboarded == nil, "(setup) the saved character has the old flag and no welcome version")
	check(ns.Prefs.SetupDone() == false and ns.UI.Init() == "setup", "it is shown the welcome once")
	check(c.style == "fast" and c.skipped["Q:5"] == true and c.added[9] == true and c.journey.turnedIn[9] == true and c.navigation == false and db.ui.theme == "contrast", "its style, skips, added quests, journey, navigation choice and theme are all still there")
	click(ns.UI.main.setupPanel.w.start)
	check(c.onboarded == 1 and c.style == "fast" and c.skipped["Q:5"] == true and c.journey.turnedIn[9] == true, "finishing records the version and keeps everything")
	local again = session("Veteran", db)
	check(again.Prefs.SetupDone() == true and again.UI.Init() ~= "setup", "and it is not shown again")
	check(db.chars["Veteran-Forever"].style == "fast", "the saved style survived the relog")
end

section("onboarding: reopening setup never wipes anything")
do
	local db = {}
	local ns = session("Reopener", db)
	click(ns.UI.main.setupPanel.w.start)
	ns.Prefs.SetStyle("completionist") ns.Prefs.Skip("Q:7") ns.Prefs.SetNavigation(false)
	local c = db.chars[key(ns)]
	H.slash("setup")
	check(ns.Prefs.SetupDone() == false and ns.UI.options.__shown and ns.UI.main.setupPanel.frame.__shown, "/qflow setup reopens the welcome")
	check(c.style == "completionist" and c.skipped["Q:7"] == true and c.navigation == false and c.onboarded == 1, "every choice, skip and the earlier completion record are untouched")
	click(ns.UI.main.settingsPanel.w.again or ns.UI.main.setupPanel.w.start)
	ns.Prefs.FinishSetup()
	check(ns.Prefs.SetupDone() == true and c.style == "completionist", "finishing it again changes nothing else")
	local ns2 = session("Reopener", db)
	check(ns2.Prefs.SetupDone() == true, "and it stays done across a relog")
	check(ns.Prefs.IsSavedVariablesSafe(db) == true, "the saved data is still writable")
end

section("onboarding: the report states the setup state")
do
	local db = {}
	local ns = session("Reporter", db)
	local _, lines = ns.Diag.Report()
	check(table.concat(lines, "\n"):find("setup NOT done", 1, true) ~= nil, "before: setup NOT done")
	click(ns.UI.main.setupPanel.w.start)
	_, lines = ns.Diag.Report()
	check(table.concat(lines, "\n"):find("setup done", 1, true) ~= nil, "after: setup done")
end
