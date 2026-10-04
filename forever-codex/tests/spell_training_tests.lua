-- spell_training_tests.lua: the SPELL TRAINING section (SpellTraining.lua). A stub trainer window and a stub spellbook stand in for the client. They prove
-- Codex's OWN logic (what is listed, known-spell filtering, rank handling, totals, per-character persistence, hiding, isolation from the planner). They
-- say nothing about how the real Forever client answers the trainer and spell APIs: that is reported separately (/codex spells, docs/CODEX_SPELL_TRAINING.md).

local H = ...
local check, section, boot = H.check, H.section, H.boot

-- ---------------------------------------------------------------- stub trainer / spellbook

local T = {}
local function resetClient()
	T.services, T.known, T.book, T.tradeskill, T.noIds = {}, {}, {}, false, false
	_G.GetNumTrainerServices = function() return #T.services end
	_G.GetTrainerServiceInfo = function(i) local s = T.services[i]; if s then return s.name, s.rank or "", s.cat or "available", false end end
	_G.GetTrainerServiceCost = function(i) local s = T.services[i]; return s and s.cost or nil end
	_G.GetTrainerServiceLevelReq = function(i) local s = T.services[i]; return s and (s.req or 0) or nil end
	_G.GetTrainerServiceItemLink = function(i)
		local s = T.services[i]
		if not s or T.noIds or not s.id then return nil end
		return "|cff71d5ff|Hspell:" .. s.id .. "|h[" .. s.name .. "]|h|r"
	end
	_G.IsTradeskillTrainer = function() return T.tradeskill end
	_G.IsPlayerSpell = function(id) return T.known[id] == true end
	_G.IsSpellKnown = function(id) return T.known[id] == true end
	_G.GetNumSpellTabs = function() return 1 end
	_G.GetSpellTabInfo = function() return "General", "", 0, #T.book end
	_G.GetSpellBookItemName = function(i) local b = T.book[i]; if b then return b[1], b[2] or "" end end
end
local function clearClient()
	for _, n in ipairs({ "GetNumTrainerServices", "GetTrainerServiceInfo", "GetTrainerServiceCost", "GetTrainerServiceLevelReq", "GetTrainerServiceItemLink",
		"IsTradeskillTrainer", "IsPlayerSpell", "IsSpellKnown", "GetNumSpellTabs", "GetSpellTabInfo", "GetSpellBookItemName" }) do _G[n] = nil end
end
resetClient()

local function svc(id, name, rank, cost, req, cat) return { id = id, name = name, rank = rank, cost = cost, req = req, cat = cat } end

local ROGUE = { class = "Rogue", classToken = "ROGUE", level = 10, name = "Sneak" }

local function rogue(opts)
	opts = opts or {}
	local ns = boot({ char = ROGUE, synthetic = true, savedVars = opts.savedVars })
	ns.Prefs.FinishSetup()
	return ns
end
local function visit(ns, event) ns._selftest.boot.onEvent(nil, event or "TRAINER_SHOW") ; ns.State.Recompute() end
local function titles(ns)
	local card = ns.Presenter.Card(ns.State.plan, ns.State.ctx)
	local out = {}
	for _, r in ipairs(card.spells and card.spells.rows or {}) do out[#out + 1] = r.title .. "|" .. tostring(r.costText) end
	return table.concat(out, ";"), card.spells
end
local function click(b) b.__scripts.OnClick(b) end

local BASE = function()
	T.services = { svc(1752, "Sinister Strike", "Rank 3", 12 * 100, 6), svc(5277, "Evasion", nil, 18 * 100, 8), svc(2983, "Sprint", nil, 25 * 100, 10),
		svc(1856, "Vanish", nil, 40 * 100, 22, "unavailable") }
end

section("spell training: an available spell appears with name, rank and cost; the total is the sum of what is shown")
do
	resetClient(); BASE()
	local ns = rogue()
	check(titles(ns) == "", "before any trainer visit nothing is listed (there is no remote trainer query and Codex ships no spell data)")
	visit(ns)
	local s, sp = titles(ns)
	check(s == "Sinister Strike Rank 3|12s;Evasion|18s;Sprint|25s", "name, rank and cost for each spell, ordered by required level  [" .. s .. "]")
	check(sp.total == 5500 and sp.totalText == "Total training: 55s", "total training is the sum of the shown costs  [" .. sp.totalText .. "]")
	check(#sp.rows == 3, "multiple spells appear together; the level-22 spell is not listed at level 10")
	check(#ns.errors == 0, "no errors")
end

section("spell training: level filtering follows the character and a later level makes a stored spell appear")
do
	resetClient(); BASE()
	local ns = rogue()
	visit(ns)
	check(not (titles(ns)):find("Vanish", 1, true), "a spell above the character's level is not shown")
	H.world().char.level = 22
	ns.State.Recompute()
	local s = titles(ns)
	check(s:find("Vanish|40s", 1, true) ~= nil, "after the level is reached the spell is listed (newly available spell later appears)")
	H.world().char.level = 4
	ns.State.Recompute()
	check(titles(ns) == "", "and nothing is listed below every requirement: the section is gone")
end

section("spell training: a known spell does not appear; a learned spell leaves by itself and the total follows")
do
	resetClient(); BASE()
	T.known[2983] = true
	local ns = rogue()
	visit(ns)
	local s, sp = titles(ns)
	check(s == "Sinister Strike Rank 3|12s;Evasion|18s" and sp.totalText == "Total training: 30s", "an already-known spell is not listed  [" .. s .. "]")
	T.known[5277] = true                                   -- the player learns Evasion at the trainer (a spell change, no trainer event needed)
	ns._selftest.boot.onEvent(nil, "SPELLS_CHANGED")
	ns.State.Recompute()
	s, sp = titles(ns)
	check(s == "Sinister Strike Rank 3|12s" and sp.totalText == "Total training: 12s", "the learned spell disappears and the total updates automatically  [" .. s .. "]")
	-- the trainer itself reports "used" after a purchase while the window is open
	T.services[1].cat = "used"
	T.known[1752] = nil
	visit(ns, "TRAINER_UPDATE")
	check(titles(ns) == "", "a spell the trainer marks as already learned leaves too, and with nothing left the section is hidden")
end

section("spell training: rank handling (a rank is its own spell id, one rank at a time, a known higher rank retires a lower one)")
do
	resetClient()
	T.services = { svc(100, "Backstab", "Rank 1", 100, 4), svc(101, "Backstab", "Rank 2", 200, 6), svc(102, "Backstab", "Rank 3", 300, 8) }
	local ns = rogue()
	visit(ns)
	local s = titles(ns)
	check(s == "Backstab Rank 1|1s", "only the next rank to learn is listed, not every rank at once  [" .. s .. "]")
	T.known[100] = true
	ns.State.Recompute()
	check(titles(ns) == "Backstab Rank 2|2s", "after rank 1 is learned the next rank is a new opportunity")
	T.known[102] = true                                     -- a higher rank is known (learned elsewhere): lower ranks are not shown
	ns.State.Recompute()
	check(titles(ns) == "", "a known higher rank retires the lower ranks that were never learned")
	-- repeated recomputation never re-adds or duplicates
	for _ = 1, 5 do ns.State.Recompute() end
	check(titles(ns) == "", "repeated recomputation does not bring anything back")
	local n = 0
	for _ in pairs(ns.Prefs.Char().spellTraining.entries) do n = n + 1 end
	check(n == 3, "the same trainer read twice stores each rank once (" .. n .. " entries)")
	visit(ns); visit(ns)
	n = 0
	for _ in pairs(ns.Prefs.Char().spellTraining.entries) do n = n + 1 end
	check(n == 3, "re-reading the trainer does not duplicate entries")
end

section("spell training: Don't Want to Learn removes a spell at once, recalculates, and survives recompute, reload and relog")
do
	resetClient(); BASE()
	local ns = rogue()
	visit(ns)
	local _, sp = titles(ns)
	local evKey = sp.rows[2].key
	check(sp.rows[2].name == "Evasion" and evKey == "S:5277", "the stable key is the spell id, not the name  [" .. tostring(evKey) .. "]")
	check(ns.SpellTraining.Dismiss(evKey) == true, "Don't Want to Learn is accepted")
	local s, sp2 = titles(ns)
	check(s == "Sinister Strike Rank 3|12s;Sprint|25s" and sp2.totalText == "Total training: 37s", "the spell is gone immediately and the total is recalculated  [" .. s .. "]")
	for _ = 1, 4 do ns.State.Recompute() end
	visit(ns)                                                 -- the trainer lists it again: it stays dismissed
	check(not (titles(ns)):find("Evasion", 1, true), "it stays dismissed after recomputes and after the trainer lists it again")
	-- reload: SavedVariables survive
	local db = _G.ForeverCodexDB
	local ns2 = boot({ char = ROGUE, synthetic = true, savedVars = db })
	ns2.Prefs.FinishSetup(); ns2.State.Recompute()
	check(not (titles(ns2)):find("Evasion", 1, true) and (titles(ns2)):find("Sprint", 1, true) ~= nil, "it stays dismissed after a reload, while the other spells are still listed")
	check(ns2.Prefs.Char().spellTraining.dismissed["S:5277"] ~= nil, "the dismissal is stored per character under the spell id")
	-- a different character on the same account does not inherit it
	local ns3 = boot({ char = { class = "Rogue", classToken = "ROGUE", level = 10, name = "Other" }, synthetic = true, savedVars = db })
	ns3.Prefs.FinishSetup(); ns3.State.Recompute()
	check(titles(ns3) == "", "another character has its own list (nothing stored for it yet)")
	BASE()
	visit(ns3)
	check((titles(ns3)):find("Evasion|18s", 1, true) ~= nil, "the other character still sees Evasion: dismissals are not shared across characters")
	check(db.chars["Sneak-Forever"].spellTraining.dismissed["S:5277"] ~= nil and db.chars["Other-Forever"].spellTraining.dismissed["S:5277"] == nil, "storage is separate per character key")
	-- a new rank (a new spell id) is a new opportunity; the old dismissal does not hide it
	T.services = { svc(5277, "Evasion", nil, 1800, 8), svc(9999, "Evasion", "Rank 2", 5000, 10) }
	T.known[5277] = true
	visit(ns2)
	check((titles(ns2)):find("Evasion Rank 2|50s", 1, true) ~= nil and not (titles(ns2)):find("Evasion|", 1, true), "a genuinely new rank appears as a new opportunity despite the earlier dismissal")
	check(ns2.SpellTraining.RestoreAll() == 1 and (titles(ns2)):find("Evasion|", 1, true) == nil, "/codex spells restore brings dismissed spells back")
end

section("spell training: class handling")
do
	resetClient(); BASE()
	local ns = rogue()
	visit(ns)
	local db = _G.ForeverCodexDB
	check(db.chars["Sneak-Forever"].spellTraining.class == "ROGUE", "the store is stamped with the class that read the trainer")
	-- the same name re-created as another class (a deleted and re-rolled character) must not inherit a Rogue's spells
	local ns2 = boot({ char = { class = "Mage", classToken = "MAGE", level = 10, name = "Sneak" }, synthetic = true, savedVars = db })
	ns2.Prefs.FinishSetup(); ns2.State.Recompute()
	check(titles(ns2) == "", "a different class never shows the old class's spells")
	-- a profession trainer is not class training
	resetClient(); T.tradeskill = true; T.services = { svc(2018, "Journeyman Blacksmithing", nil, 500, 5) }
	local ns3 = rogue()
	visit(ns3)
	check(titles(ns3) == "", "a profession trainer's window is ignored")
	-- and a window the client cannot answer lists nothing and invents nothing
	clearClient()
	local ns4 = rogue()
	visit(ns4)
	check(titles(ns4) == "" and #ns4.errors == 0, "missing trainer APIs: nothing listed, no error")
	resetClient()
end

section("spell training: no spell id from the trainer falls back to name and rank, with the spellbook as the known-spell check")
do
	resetClient(); BASE(); T.noIds = true
	local ns = rogue()
	visit(ns)
	local _, sp = titles(ns)
	check(sp and sp.rows[1].key == "N:Sinister Strike|Rank 3|L6" and sp.rows[1].id == nil, "the key is name, rank and level requirement, flagged as having no spell id")
	T.book = { { "Evasion", "" } }
	ns.State.Recompute()
	check(not (titles(ns)):find("Evasion", 1, true), "a spell in the spellbook is known")
	T.book = { { "Sinister Strike", "Rank 5" } }
	ns.State.Recompute()
	check(not (titles(ns)):find("Sinister", 1, true), "a higher known rank in the spellbook counts as known")
	resetClient()
end

section("spell training: a cost the trainer did not report is shown as unknown and never invented")
do
	resetClient(); T.services = { svc(1, "Alpha", nil, nil, 2), svc(2, "Beta", nil, 300, 2) }
	local ns = rogue()
	visit(ns)
	local s, sp = titles(ns)
	check(s:find("Alpha|nil", 1, true) ~= nil and sp.partial == true and sp.totalText == "Total training: 3s (some costs unknown)", "unknown cost: stated, and the total says it is partial  [" .. sp.totalText .. "]")
	resetClient()
end

section("spell training: the window section is below DUNGEON QUESTS, has no Learn button, hides when empty, and never changes the other sections")
do
	resetClient(); BASE()
	local ns = rogue()
	ns.UI.Open("codex")
	local c = ns.UI.main.codex
	ns.State.Recompute()
	check(c.stBox.__shown == false, "no spells: the SPELL TRAINING card is hidden entirely (no empty header)")
	-- quest sections before and after
	local before = ns.Presenter.Card(ns.State.plan, ns.State.ctx)
	visit(ns)
	local after = ns.Presenter.Card(ns.State.plan, ns.State.ctx)
	check(c.stBox.__shown == true and c.stLabel.__text == "SPELL TRAINING", "after a trainer visit the card is shown with its header")
	local same = (before.now == nil) == (after.now == nil) and #before.ready == #after.ready and #before.also == #after.also and #before.dungeons == #after.dungeons
	check(same, "NOW, READY TO TURN IN, ALSO and DUNGEON sections are identical with and without spell entries")
	local rowsShown, learnBtn = 0, false
	for _, r in ipairs(c.stRows) do
		if r.line.__text ~= "" then rowsShown = rowsShown + 1 end
		if r.btn.text and r.btn.text.__text:lower():find("learn", 1, true) and not r.btn.text.__text:find("Don't Want to Learn", 1, true) then learnBtn = true end
	end
	check(rowsShown == 3 and c.stRows[1].btn.text.__text == "Don't Want to Learn" and not learnBtn, "one row per spell, each with Don't Want to Learn and no Learn button")
	check(c.stTotal.__text == "Total training: 55s", "the total line is drawn")
	local y1 = c.stBox.__points and c.stBox.__points[5]
	local yd = c.dgBox.__points and c.dgBox.__points[5]
	check(y1 ~= nil and (yd == nil or y1 <= yd), "the card is placed at or below the dungeon card (its y offset is lower on the page)")
	-- the button persists the choice and redraws
	click(c.stRows[2].btn)
	check(c.stRows[2].line.__text:find("Sprint", 1, true) ~= nil or c.stRows[3].line.__text == "", "clicking Don't Want to Learn redraws without that spell")
	click(c.stRows[1].btn); click(c.stRows[1].btn)
	check(c.stBox.__shown == false, "once every spell is dismissed or learned the whole section disappears")
	check(#ns.errors == 0, "no errors")
	resetClient()
end

section("spell training: it never alters the plan (same NOW, order and ready list with and without spell entries)")
do
	resetClient(); BASE()
	local ns = boot({ char = { level = 10, class = "Rogue", classToken = "ROGUE", name = "Sneak" } })
	ns.Prefs.FinishSetup()
	ns.State.Recompute()
	local p1 = ns.State.plan
	local n1 = p1.now and p1.now.id
	visit(ns)
	local p2 = ns.State.plan
	check((p2.now and p2.now.id) == n1 and #p2.sequence == #p1.sequence, "the planner's NOW and sequence are unchanged by spell entries")
	local src = H.readFile(H.addonDir .. "/Planner.lua") .. H.readFile(H.addonDir .. "/PlanAdapter.lua") .. H.readFile(H.addonDir .. "/Engine.lua")
	check(not src:find("SpellTraining", 1, true), "the planner, adapter and engine do not reference SpellTraining")
	resetClient()
end

clearClient()

section("spell training: Forever's GetTrainerServiceInfo order (name, category, icon number, ...) is read by what each value is; ranks of one spell without rank text are ordered by level")
do
	resetClient()
	-- the real Forever shape (build 70205): name, category string, an icon number; no rank text, no spell id in the link
	_G.GetTrainerServiceInfo = function(i) local s = T.services[i]; if s then return s.name, s.cat or "available", 132000 + i, nil end end
	T.services = {
		{ name = "Raptor Strike", cat = "available", cost = 4000, req = 8 }, { name = "Raptor Strike", cat = "unavailable", cost = 7200, req = 24 }, { name = "Beast Lore", cat = "unavailable", cost = 7200, req = 24 },
		{ name = "Mend Pet", cat = "Used", cost = 100, req = 2 }, { name = "Tame Beast", cat = "Header", cost = 0, req = 0 },
	}
	T.noIds = true
	local ns = rogue()
	H.world().char.level = 25
	visit(ns)
	local s, sp = titles(ns)
	check(s == "Raptor Strike|40s;Beast Lore|1g 72s" or s == "Raptor Strike|40s;Beast Lore|72s", "the lowest rank of Raptor Strike is listed, not both  [" .. s .. "]")
	check(sp and #sp.rows == 2 and sp.rows[1].key == "N:Raptor Strike||L8", "the key tells ranks apart by level requirement  [" .. tostring(sp and sp.rows[1].key) .. "]")
	local text = table.concat(ns.SpellTraining.ReportLines(ns.State.ctx), "\n")
	check(text:find("categories the client gave: available x1, none x1, unavailable x2, used x1", 1, true) ~= nil, "the report tallies the categories it understood and the ones it did not")
	check(text:find('#1 returns ["Raptor Strike", "available", number:132001, nil', 1, true) == nil and text:find('returns ["Raptor Strike", "available", number:132001', 1, true) ~= nil, "and prints the raw returns of the first services")
	T.services[1].cat = "used"                            -- Raptor Strike rank 1 learned at the trainer: the next rank becomes the one to learn
	visit(ns, "TRAINER_UPDATE")
	check((titles(ns)):find("Raptor Strike|72s", 1, true) ~= nil and not (titles(ns)):find("Raptor Strike|40s", 1, true), "after the trainer shows it as used, the next rank is the opportunity")
	-- an empty later read does not hide the good one
	T.services = {}
	visit(ns, "TRAINER_UPDATE")
	local after = table.concat(ns.SpellTraining.ReportLines(ns.State.ctx), "\n")
	check(after:find("latest trainer read was empty", 1, true) and after:find("5 service(s)", 1, true), "the report keeps the latest read that listed services")
	-- the Classic order (name, rank, category) is still understood
	resetClient(); BASE()
	local ns2 = rogue()
	visit(ns2)
	check(titles(ns2) ~= "", "the Classic order still works")
	resetClient()
end
