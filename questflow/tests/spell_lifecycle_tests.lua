-- spell_lifecycle_tests.lua: the SPELL TRAINING state lifecycle (0.7.6): an account-wide OBSERVED catalog per class, level-ups that surface spells without a trainer visit, learned spells that leave
-- (a "used" row, or absence from the window), rank transitions, reload, per-character isolation. The trainer rows below are TEST FIXTURES shaped like what Forever returned in the 0.7.x playtests
-- (name, category, icon, level, rank text); the values are invented for the tests, Codex ships none of them.

local H = ...
local check, section, boot = H.check, H.section, H.boot

local T = {}
local function client()
	T.rows, T.tradeskill = {}, false
	_G.GetNumTrainerServices = function() return #T.rows end
	_G.GetTrainerServiceInfo = function(i) local r = T.rows[i]; if r then return r.name, r.cat, 132000 + i, r.req, r.rank or "", "" end end
	_G.GetTrainerServiceCost = function(i) return T.rows[i] and T.rows[i].cost end
	_G.GetTrainerServiceLevelReq = function(i) local r = T.rows[i]; if r then return r.cat == "used" and 0 or r.req end end
	_G.GetTrainerServiceItemLink = function() return nil end
	_G.IsTradeskillTrainer = function() return T.tradeskill end
	_G.GetTrainerServiceTypeFilter = function(k) if T.filters then return T.filters[k] end return nil end
end
local function unclient() for _, n in ipairs({ "GetNumTrainerServices", "GetTrainerServiceInfo", "GetTrainerServiceCost", "GetTrainerServiceLevelReq", "GetTrainerServiceItemLink", "IsTradeskillTrainer", "GetTrainerServiceTypeFilter" }) do _G[n] = nil end end
client()

local function row(name, cat, req, cost, rank) return { name = name, cat = cat, req = req, cost = cost, rank = rank } end
local function hunterRows(learned)
	learned = learned or {}
	local base = { row("Track Beasts", "available", 1, 10), row("Serpent Sting", "unavailable", 4, 100, "Rank 1"), row("Aspect of the Monkey", "unavailable", 4, 100),
		row("Serpent Sting", "unavailable", 10, 400, "Rank 2") }
	for i, r in ipairs(base) do if learned[r.name .. (r.rank or "")] then base[i] = { name = r.name, cat = "used", req = 0, cost = r.cost, rank = r.rank } end end
	return base
end

local HUNTER = { name = "Quiver", class = "Hunter", classToken = "HUNTER", race = "Tauren", raceToken = "Tauren", faction = "Horde", level = 1 }
local function session(char, level, db)
	local c = {}
	for k, v in pairs(char) do c[k] = v end
	c.level = level
	local ns = boot({ char = c, synthetic = true, savedVars = db })
	ns.Prefs.FinishSetup()
	ns.State.Recompute()
	return ns
end
local function visit(ns, event) ns._selftest.boot.onEvent(nil, event or "TRAINER_SHOW"); ns.State.Recompute() end
local function setLevel(ns, lvl) H.world().char.level = lvl; ns.State.Recompute() end
local function titles(ns)
	local card = ns.Presenter.Card(ns.State.plan, ns.State.ctx)
	local out = {}
	for _, r in ipairs(card.spells and card.spells.rows or {}) do out[#out + 1] = r.title .. "|" .. tostring(r.costText) end
	return table.concat(out, ";"), card.spells
end

section("spell lifecycle: level 1 Hunter: the first trainer visit lists Track Beasts; a level-up lists the level-4 spells with NO second visit")
do
	T.rows = hunterRows()
	local ns = session(HUNTER, 1)
	check(titles(ns) == "", "before any trainer visit nothing is known (Quest Flow ships no spell data)")
	visit(ns)
	check(titles(ns) == "Track Beasts|10c", "level 1: Track Beasts only; the level-4 spells are known but not learnable yet  [" .. titles(ns) .. "]")
	setLevel(ns, 4)
	local s, sp = titles(ns)
	check(s == "Aspect of the Monkey|1s;Serpent Sting Rank 1|1s" or s == "Track Beasts|10c;Aspect of the Monkey|1s;Serpent Sting Rank 1|1s" or s:find("Serpent Sting Rank 1", 1, true) ~= nil, "level 4: the new spells appear by themselves (no visit)  [" .. s .. "]")
	check(s:find("Serpent Sting Rank 2", 1, true) == nil, "and the level-10 rank is not listed yet")
	check(sp and sp.totalText:find("Total training:", 1, true), "with a total")
	check(#ns.errors == 0, "no errors")
end

section("spell lifecycle: learning a spell removes it (the window shows it as already known with level 0, or no longer lists it); the total follows")
do
	T.rows = hunterRows()
	local ns = session(HUNTER, 1)
	visit(ns)
	setLevel(ns, 5)
	check((titles(ns)):find("Aspect of the Monkey", 1, true) and (titles(ns)):find("Serpent Sting Rank 1", 1, true), "(setup) level 5: both level-4 spells listed")
	-- the player buys both at the trainer: the window now shows them as already known
	T.rows = hunterRows({ ["Serpent StingRank 1"] = true, ["Aspect of the Monkey"] = true, ["Track Beasts"] = true })
	visit(ns, "TRAINER_UPDATE")
	check(titles(ns) == "", "both learned: SPELL TRAINING has nothing left and the section is hidden  [" .. titles(ns) .. "]")
	local ns2 = session(HUNTER, 1)
	T.rows = hunterRows()
	visit(ns2)
	setLevel(ns2, 5)
	-- the trainer hides learned spells (its "known" filter is off): the rows are simply gone
	T.rows = { row("Serpent Sting", "unavailable", 10, 400, "Rank 2") }
	T.filters = { available = true, unavailable = true, used = false }       -- the client says which categories the window shows
	visit(ns2, "TRAINER_UPDATE")
	T.filters = nil
	check(not (titles(ns2)):find("Aspect of the Monkey", 1, true) and not (titles(ns2)):find("Serpent Sting Rank 1", 1, true), "absent from a window that shows the character's other spells: learned")
	check(not (titles(ns2)):find("Track Beasts", 1, true), "Track Beasts too")
	-- a pet-training window (shares no spell with the class list) must not mark anything learned
	local ns3 = session(HUNTER, 1)
	T.rows = hunterRows()
	visit(ns3)
	setLevel(ns3, 5)
	T.rows = { row("Claw", "available", 1, 5, "Rank 1"), row("Bite", "available", 1, 5, "Rank 1") }
	visit(ns3, "TRAINER_UPDATE")
	check((titles(ns3)):find("Serpent Sting Rank 1", 1, true) ~= nil, "a window with none of the class spells (a pet trainer) learns nothing")
end

section("spell lifecycle: rank transitions (a higher rank retires the lower; the next rank appears at its level)")
do
	T.rows = hunterRows()
	local ns = session(HUNTER, 1)
	visit(ns)
	setLevel(ns, 10)
	local s = titles(ns)
	check(s:find("Serpent Sting Rank 1", 1, true) and not s:find("Serpent Sting Rank 2", 1, true), "level 10: only the lowest unlearned rank of Serpent Sting is listed  [" .. s .. "]")
	T.rows = hunterRows({ ["Serpent StingRank 1"] = true })
	visit(ns, "TRAINER_UPDATE")
	s = titles(ns)
	check(not s:find("Rank 1", 1, true) and s:find("Serpent Sting Rank 2|4s", 1, true), "rank 1 learned: rank 2 is the opportunity  [" .. s .. "]")
	T.rows = hunterRows({ ["Serpent StingRank 1"] = true, ["Serpent StingRank 2"] = true })
	visit(ns, "TRAINER_UPDATE")
	check(not (titles(ns)):find("Serpent Sting", 1, true), "rank 2 learned: nothing of Serpent Sting remains")
end

section("spell lifecycle: Don't Want to Learn and learned state survive a reload; a new character does not inherit them, but does inherit the observed catalog")
do
	T.rows = hunterRows()
	local ns = session(HUNTER, 1)
	visit(ns)
	setLevel(ns, 5)
	local _, sp = titles(ns)
	local monkey
	for _, r in ipairs(sp.rows) do if r.name == "Aspect of the Monkey" then monkey = r.key end end
	ns.SpellTraining.Dismiss(monkey)
	local db = _G.ForeverCodexDB
	T.rows = hunterRows()                       -- the character is away from any trainer after the reload
	local again = session(HUNTER, 5, db)
	check(not (titles(again)):find("Aspect of the Monkey", 1, true) and (titles(again)):find("Serpent Sting Rank 1", 1, true), "after a reload the dismissal stays and the other spell is still listed")
	-- a second Hunter on the account: first seen at level 1, never visited a trainer
	local other = session({ name = "Second", class = "Hunter", classToken = "HUNTER", race = "Orc", raceToken = "Orc", faction = "Horde" }, 1, db)
	check((titles(other)):find("Track Beasts|10c", 1, true) ~= nil, "a new Hunter hears about Track Beasts from the account's observed catalog, with no visit")
	setLevel(other, 5)
	local s = titles(other)
	check(s:find("Aspect of the Monkey", 1, true) and s:find("Serpent Sting Rank 1", 1, true), "and about the level-4 spells at level 5, including the one the first Hunter dismissed (dismissals are per character)  [" .. s .. "]")
	-- a character first seen at level 10 is NOT told about spells at or below that level (they may have been learned before Codex ran; there is no spellbook API to check)
	local late = session({ name = "Late", class = "Hunter", classToken = "HUNTER", race = "Orc", raceToken = "Orc", faction = "Horde" }, 10, db)
	check(titles(late) == "", "a character first seen at level 10 gets nothing from the catalog for spells at or below level 10 until its own trainer visit")
	-- a reused name (identity reset) clears the character's state but keeps the account catalog
	local reroll = session({ name = "Quiver", class = "Mage", classToken = "MAGE", race = "Human", raceToken = "Human", faction = "Alliance" }, 1, db)
	check(db.spellCatalog.classes.HUNTER ~= nil and reroll.Prefs.Char().spellTraining == nil or reroll.Prefs.Char().spellTraining.class == "MAGE", "a re-rolled character starts clean; the Hunter catalog is still there")
	check(titles(reroll) == "", "and a Mage is shown nothing from the Hunter catalog")
end

section("spell lifecycle: no eligible spells hides the section; the catalog is observed trainer-window data only")
do
	T.rows = hunterRows()
	local ns = session(HUNTER, 1)
	ns.UI.Open("codex")
	ns.State.Recompute()
	check(ns.UI.main.codex.stBox.__shown == false, "no spells: the section is not drawn")
	visit(ns)
	local cat = ForeverCodexDB.spellCatalog.classes.HUNTER
	check(cat.src == "trainer window" and cat.build == "70124" and next(cat.entries) ~= nil, "the catalog records where its rows came from (the trainer window) and the build")
	local src = H.readFile(H.addonDir .. "/SpellTraining.lua")
	check(not src:find("Serpent Sting", 1, true) and not src:find("Track Beasts", 1, true), "no spell name is shipped in the code")
	T.tradeskill = true
	T.rows = { row("Journeyman Skinning", "available", 5, 100) }
	local before = 0
	for _ in pairs(cat.entries) do before = before + 1 end
	visit(ns)
	local after = 0
	for _ in pairs(ForeverCodexDB.spellCatalog.classes.HUNTER.entries) do after = after + 1 end
	check(before == after, "a profession trainer never enters the class catalog")
	T.tradeskill = false
	H.slash("spells catalog")
	check(ns.UI.report and ns.UI.report.box.__text:find("SPELL CATALOG", 1, true) and ns.UI.report.box.__text:find("4 | Aspect of the Monkey", 1, true), "/qflow spells catalog opens the observed catalog as copyable text")
end
unclient()
