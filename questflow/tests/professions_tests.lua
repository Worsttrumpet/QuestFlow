-- professions_tests.lua: the PROFESSIONS section (Professions.lua). A stub client answers the profession and trainer APIs. They prove Codex's OWN logic (what is shown, hiding,
-- per-character state, rank-up detection from a profession trainer, no routes or leveling advice); they say nothing about which profession API the real Forever client answers.

local H = ...
local check, section, boot = H.check, H.section, H.boot

local T = {}
local function resetClient()
	T.prof = {}                       -- list of { name, rank, max, skillLine } in GetProfessions() order slots 1..5 (nil = empty slot); see slots()
	T.services, T.tradeskill = {}, true
	_G.GetProfessions = function()
		local out = {}
		for pos = 1, 5 do out[pos] = T.prof[pos] and pos or nil end
		return out[1], out[2], out[3], out[4], out[5]
	end
	_G.GetProfessionInfo = function(i) local p = T.prof[i]; if p then return p.name, "icon", p.rank, p.max, 0, 0, p.skillLine, 0 end end
	_G.GetNumTrainerServices = function() return #T.services end
	_G.GetTrainerServiceInfo = function(i) local s = T.services[i]; if s then return s.name, "", s.cat or "available", false end end
	_G.GetTrainerServiceCost = function(i) return 100 end
	_G.GetTrainerServiceLevelReq = function(i) return 5 end
	_G.IsTradeskillTrainer = function() return T.tradeskill end
end
local function clearClient()
	for _, n in ipairs({ "GetProfessions", "GetProfessionInfo", "GetNumSkillLines", "GetSkillLineInfo", "GetNumTrainerServices", "GetTrainerServiceInfo", "GetTrainerServiceCost", "GetTrainerServiceLevelReq", "IsTradeskillTrainer" }) do _G[n] = nil end
end
resetClient()

-- GetProfessions() order in the retail shape: primary, primary, (archaeology), fishing, cooking. Secondaries are classified by skill-line id here.
local LEATHER = { name = "Leatherworking", rank = 37, max = 75, skillLine = 165 }
local SKINNING = { name = "Skinning", rank = 51, max = 75, skillLine = 393 }
local FISHING = { name = "Fishing", rank = 1, max = 75, skillLine = 356 }
local COOKING = { name = "Cooking", rank = 1, max = 75, skillLine = 185 }
local FIRSTAID = { name = "First Aid", rank = 65, max = 150, skillLine = 129 }

local function char(name, class) return { name = name, class = class or "Rogue", classToken = (class or "Rogue"):upper(), level = 20 } end
local function world(c, db)
	local ns = boot({ char = c or char("Crafty"), synthetic = true, savedVars = db })
	ns.Prefs.FinishSetup()
	ns.State.Recompute()
	return ns
end
local function card(ns) return ns.Presenter.Card(ns.State.plan, ns.State.ctx).professions end
local function texts(ns)
	local c = card(ns)
	local out = {}
	for _, r in ipairs(c and c.rows or {}) do out[#out + 1] = r.text end
	return table.concat(out, ";"), c
end
local function visit(ns, services, tradeskill)
	T.services, T.tradeskill = services, tradeskill ~= false
	ns._selftest.boot.onEvent(nil, "TRAINER_SHOW")
	ns.State.Recompute()
end

section("professions: two primaries and all three secondaries are listed with skill and cap, and nothing is missing")
do
	resetClient()
	-- GetProfessions returns positional slots (the stub returns the slot numbers that are filled); secondaries are classified by skill-line id wherever they sit
	T.prof = { [1] = LEATHER, [2] = SKINNING, [3] = FIRSTAID, [4] = FISHING, [5] = COOKING }
	local ns = world()
	local s, c = texts(ns)
	check(s == "Leatherworking 37/75;Skinning 51/75;Cooking 1/75;First Aid 65/150;Fishing 1/75", "name, current skill and the client's own cap for every profession  [" .. s .. "]")
	check(c.free == 0 and not s:find("Not Learned", 1, true) and not s:find("slot", 1, true), "nothing is missing and no slot is free")
	check(c.via == "GetProfessions" and #ns.errors == 0, "read through GetProfessions, no errors")
end

section("professions: one primary leaves a slot; none leaves two; the slot line follows the character")
do
	resetClient(); T.prof = { [1] = LEATHER }
	local ns = world()
	local s = texts(ns)
	check(s:find("1 primary profession slot available", 1, true) ~= nil and s:find("2 primary", 1, true) == nil, "one primary: '1 primary profession slot available'  [" .. s .. "]")
	T.prof = {}
	ns.State.Recompute()
	local s0, c0 = texts(ns)
	check(s0:find("2 primary profession slots available", 1, true) and c0.primaries == 0, "no primary: 2 slots available (an informational line, never a choice of profession)")
	check(not s0:lower():find("choose") and not s0:lower():find("mining") and not s0:lower():find("recommend"), "and nothing says which profession to learn")
	T.prof = { [1] = LEATHER, [2] = SKINNING }
	ns.State.Recompute()
	check(not (texts(ns)):find("slot", 1, true), "learning the second primary removes the slot line")
end

section("professions: a missing secondary is a quiet 'Not Learned' line that disappears when learned, and can be hidden by the player")
do
	for _, case in ipairs({ { FISHING, "Fishing" }, { COOKING, "Cooking" }, { FIRSTAID, "First Aid" } }) do
		resetClient()
		T.prof = { [1] = LEATHER, [2] = SKINNING }
		local others = {}
		for _, p in ipairs({ FISHING, COOKING, FIRSTAID }) do if p ~= case[1] then others[#others + 1] = p end end
		T.prof[3], T.prof[4] = others[1], others[2]
		local ns = world()
		local s = texts(ns)
		check(s:find(case[2] .. " - Not Learned", 1, true) ~= nil and select(2, s:gsub("Not Learned", "")) == 1, "missing " .. case[2] .. ": exactly one 'Not Learned' line")
		T.prof[5] = case[1]
		ns.State.Recompute()
		check(not (texts(ns)):find("Not Learned", 1, true) and (texts(ns)):find(case[2] .. " ", 1, true) ~= nil, case[2] .. " learned: the reminder is replaced by its status, with no reload")
	end
	resetClient(); T.prof = { [1] = LEATHER, [2] = SKINNING, [3] = COOKING, [4] = FIRSTAID }
	local ns = world()
	check((texts(ns)):find("Fishing - Not Learned", 1, true), "(setup) Fishing is not learned")
	check(ns.Professions.Hide("fishing") == true and not (texts(ns)):find("Fishing", 1, true), "Hide: the player is done being reminded")
	check(ns.Prefs.Char().professions.hidden.fishing == true and ns.Professions.RestoreAll() == 1 and (texts(ns)):find("Fishing - Not Learned", 1, true), "and it can be restored")
end

section("professions: a rank-up is reported only from a profession trainer's own 'available' service, and clears when the cap rises")
do
	resetClient(); T.prof = { [1] = LEATHER, [2] = { name = "Skinning", rank = 50, max = 75, skillLine = 393 } }
	local ns = world()
	check(not (texts(ns)):find("available", 1, true) or (texts(ns)):find("slot", 1, true) == nil, "(setup) no rank-up is claimed from the skill alone (no hard-coded threshold)")
	check(not (texts(ns)):find("Journeyman", 1, true), "no reminder before any trainer window has been read")
	visit(ns, { { name = "Journeyman Skinning", cat = "available" }, { name = "Apprentice Mining", cat = "available" }, { name = "Cured Light Hide", cat = "available" } })
	local s, c = texts(ns)
	check(s:find("Skinning 50/75;Journeyman Skinning available", 1, true) ~= nil, "the trainer's available rank service is shown under the profession  [" .. s .. "]")
	check(not s:find("Mining", 1, true) and not s:find("Cured", 1, true), "a profession the character lacks, and a recipe, are not rank-up reminders")
	for _ = 1, 3 do ns.State.Recompute() end
	check(select(2, (texts(ns)):gsub("Journeyman Skinning available", "")) == 1, "recomputing does not duplicate or re-announce it")
	-- the player trains it: the cap rises
	T.prof[2] = { name = "Skinning", rank = 50, max = 150, skillLine = 393 }
	ns.State.Recompute()
	local s2 = texts(ns)
	check(s2:find("Skinning 50/150", 1, true) and not s2:find("available", 1, true), "after training: the new cap is shown and the reminder is gone  [" .. s2 .. "]")
	check(next(ns.Prefs.Char().professions.rankUps) == nil, "and it is not stored any more")
	-- later: the next rank
	visit(ns, { { name = "Expert Skinning", cat = "available" }, { name = "Journeyman Skinning", cat = "used" } })
	check((texts(ns)):find("Expert Skinning available", 1, true) and not (texts(ns)):find("Journeyman", 1, true), "the next rank appears when the trainer offers it")
	-- a class trainer window (not a profession trainer) never creates a rank-up
	resetClient(); T.prof = { [1] = LEATHER }
	local ns2 = world()
	visit(ns2, { { name = "Journeyman Leatherworking", cat = "available" } }, false)
	check(not (texts(ns2)):find("Journeyman", 1, true), "a window the client does not call a profession trainer is ignored")
end

section("professions: state is per character (one character's rank-up and hidden reminders never reach another)")
do
	resetClient(); T.prof = { [1] = { name = "Skinning", rank = 50, max = 75, skillLine = 393 } }
	local a = world(char("Alpha"))
	visit(a, { { name = "Journeyman Skinning", cat = "available" } })
	a.Professions.Hide("fishing")
	local db = _G.ForeverCodexDB
	check((texts(a)):find("Journeyman Skinning available", 1, true) and not (texts(a)):find("Fishing", 1, true), "(setup) Alpha has a rank-up and hid Fishing")
	local b = world(char("Bravo"), db)
	T.prof = { [1] = { name = "Skinning", rank = 50, max = 75, skillLine = 393 } }
	b.State.Recompute()
	local s = texts(b)
	check(not s:find("Journeyman", 1, true) and s:find("Fishing - Not Learned", 1, true), "Bravo sees no rank-up and still sees Fishing: nothing leaked")
	check(db.chars["Alpha-Forever"].professions.rankUps["S:393"] and not db.chars["Bravo-Forever"].professions.rankUps["S:393"], "stored under each character's own key, by skill-line id")
	local a2 = world(char("Alpha"), db)
	check((texts(a2)):find("Journeyman Skinning available", 1, true), "and Alpha's reminder survives a reload")
end

section("professions: the section hides itself when there is nothing to say or the client cannot say")
do
	clearClient()
	local ns = world()
	check(card(ns) == nil, "no profession API: no section (unknown stays unknown)")
	ns.UI.Open("codex")
	ns.State.Recompute()
	local c = ns.UI.main.codex
	check(c.pfBox.__shown == false, "and no empty PROFESSIONS header is drawn")
	check(table.concat(ns.Professions.ReportLines(ns.State.ctx), "\n"):find("FAILED", 1, true) ~= nil, "the report says the reader failed")
	-- a working client: the card is shown below SPELL TRAINING and drawn with its rows
	resetClient(); T.prof = { [1] = LEATHER, [2] = SKINNING, [3] = FISHING, [4] = COOKING, [5] = FIRSTAID }
	local ns2 = world()
	ns2.UI.Open("codex"); ns2.State.Recompute()
	local c2 = ns2.UI.main.codex
	check(c2.pfBox.__shown == true and c2.pfLabel.__text == "PROFESSIONS" and c2.pfRows[1].line.__text == "Leatherworking 37/75", "the card is drawn with the first profession row")
	local y1, yd = c2.pfBox.__points and c2.pfBox.__points[5], c2.dgBox.__points and c2.dgBox.__points[5]
	check(y1 ~= nil and (yd == nil or y1 <= yd), "and it sits below the dungeon card")
	local btn = false
	for _, r in ipairs(c2.pfRows) do if r.btn.__shown then btn = true end end
	check(not btn, "with nothing missing there is no Hide button")
end

section("professions: the classic skill-line shape is read too (header rows name the section), and it never touches the planner")
do
	resetClient()
	_G.GetProfessions, _G.GetProfessionInfo = nil, nil
	local lines = { { "Class Skills", true }, { "Backstab", false, 1, 5, 0, 0, 300 }, { "Professions", true }, { "Mining", false, 1, 80, 0, 0, 150 }, { "Secondary Skills", true }, { "Cooking", false, 1, 20, 0, 0, 75 }, { "Weapon Skills", true }, { "Swords", false, 1, 100, 0, 0, 300 } }
	_G.GetNumSkillLines = function() return #lines end
	_G.GetSkillLineInfo = function(i) local l = lines[i]; return l[1], l[2], 1, l[4], 0, 0, l[7] end
	local ns = world()
	local s, c = texts(ns)
	check(c.via == "GetSkillLineInfo" and s:find("Mining 80/150", 1, true) and s:find("Cooking 20/75", 1, true) and not s:find("Swords", 1, true) and not s:find("Backstab", 1, true), "only the Professions and Secondary Skills sections are read  [" .. s .. "]")
	check(s:find("Fishing - Not Learned", 1, true) and s:find("First Aid - Not Learned", 1, true) and s:find("1 primary profession slot available", 1, true), "missing secondaries and the free slot follow")
	local p1 = ns.State.plan
	local before = p1.now and p1.now.id
	_G.GetNumSkillLines, _G.GetSkillLineInfo = nil, nil
	ns.State.Recompute()
	check((ns.State.plan.now and ns.State.plan.now.id) == before, "the plan does not depend on professions")
	local src = H.readFile(H.addonDir .. "/Planner.lua") .. H.readFile(H.addonDir .. "/PlanAdapter.lua") .. H.readFile(H.addonDir .. "/Engine.lua") .. H.readFile(H.addonDir .. "/Navigation.lua")
	check(not src:find("Professions", 1, true), "the planner, adapter, engine and navigation do not reference Professions")
	check(#ns.errors == 0, "no errors")
end
clearClient()
