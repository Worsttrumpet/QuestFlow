-- spell_purchase_tests.lua: the 0.7.7 purchase lifecycle. A trainer purchase is noticed by a post-hook on BuyTrainerService; the client's own learn event confirms it; a refused purchase (no learn
-- event) is dropped; the trainer's "used" row and the absence rule remain the fallback. The trainer rows are TEST FIXTURES in the shape Forever returned in the 0.7.x playtests; the names,
-- levels and costs are invented for the tests, Codex ships none of them. BuyTrainerService / hooksecurefunc / GetMoney are stubs here (their presence on Forever is NOT proven).

local H = ...
local check, section, boot = H.check, H.section, H.boot

local T = { rows = {}, money = 1000, now = 100 }
local saved = {}
local function setGlobals()
	for _, n in ipairs({ "GetNumTrainerServices", "GetTrainerServiceInfo", "GetTrainerServiceCost", "GetTrainerServiceLevelReq", "GetTrainerServiceItemLink", "IsTradeskillTrainer", "GetTrainerServiceTypeFilter", "hooksecurefunc", "BuyTrainerService", "GetMoney", "GetTime" }) do saved[n] = _G[n] end
	_G.GetNumTrainerServices = function() return #T.rows end
	_G.GetTrainerServiceInfo = function(i) local r = T.rows[i]; if r then return r.name, r.cat, 132000 + i, r.req, r.rank or "", "" end end
	_G.GetTrainerServiceCost = function(i) return T.rows[i] and T.rows[i].cost end
	_G.GetTrainerServiceLevelReq = function(i) local r = T.rows[i]; if r then return r.cat == "used" and 0 or r.req end end
	_G.GetTrainerServiceItemLink = function() return nil end
	_G.IsTradeskillTrainer = function() return T.tradeskill or false end
	_G.GetTrainerServiceTypeFilter = function(k) if T.filters then return T.filters[k] end return nil end
	_G.GetMoney = function() return T.money end
	_G.GetTime = function() return T.now end
	-- the real hooksecurefunc runs the hook AFTER the original; the original here does nothing (the server decides what a purchase does)
	_G.BuyTrainerService = function() end
	_G.hooksecurefunc = function(name, fn) local orig = _G[name]; _G[name] = function(...) local r = orig(...); fn(...); return r end end
end
local function restoreGlobals() for n, v in pairs(saved) do _G[n] = v end saved = {} end

local function row(name, cat, req, cost, rank) return { name = name, cat = cat, req = req, cost = cost, rank = rank } end
local SHAMAN = { name = "Another", class = "Shaman", classToken = "SHAMAN", race = "Tauren", raceToken = "Tauren", faction = "Horde", level = 1 }
local function session(level, char)
	local c = {}
	for k, v in pairs(char or SHAMAN) do c[k] = v end
	c.level = level
	_G.BuyTrainerService = function() end
	local ns = boot({ char = c, synthetic = true })
	ns.Prefs.FinishSetup()
	ns.State.Recompute()
	return ns
end
local function ev(ns, e) ns._selftest.boot.onEvent(nil, e); ns.State.Recompute() end
local function titles(ns)
	local card = ns.Presenter.Card(ns.State.plan, ns.State.ctx)
	local out = {}
	for _, r in ipairs(card.spells and card.spells.rows or {}) do out[#out + 1] = r.title end
	return table.concat(out, ";")
end
--- the player clicks Train on service #i: the client takes the price and, when it works, fires the learn event; what the window then lists is `after`
local function buy(ns, i, opts)
	opts = opts or {}
	local price = T.rows[i].cost
	_G.BuyTrainerService(i)
	if opts.fail then return end                                       -- refused: nothing is taken and no event fires
	T.money = T.money - price
	if opts.after then T.rows = opts.after end
	if opts.event ~= false then ev(ns, opts.event or "LEARNED_SPELL_IN_TAB") end
end

setGlobals()

section("purchase: the post-hook is installed at login and says so; Rockbiter bought with an EMPTY window afterwards (the 0.7.6 bug) leaves the list")
do
	T.rows = { row("Rockbiter Weapon", "available", 1, 10, "Rank 1") }
	T.money, T.now = 1000, 100
	local ns = session(2)
	check(ns.SpellTraining.hook == "hooked", "the BuyTrainerService post-hook is installed  [" .. tostring(ns.SpellTraining.hook) .. "]")
	ev(ns, "TRAINER_SHOW")
	check(titles(ns) == "Rockbiter Weapon Rank 1", "(setup) listed after the visit  [" .. titles(ns) .. "]")
	buy(ns, 1, { after = {} })                                         -- "Already Known" is off: the learned row is not listed any more
	ev(ns, "TRAINER_UPDATE")                                           -- (the 0.7.6 failure: an empty read told Codex nothing)
	check(titles(ns) == "", "learned: it leaves the list although the window now lists nothing  [" .. titles(ns) .. "]")
	local st = ns.Prefs.Char().spellTraining
	local learnedBy
	for _, e in pairs(st.entries) do learnedBy = e.learnedBy end
	check(learnedBy and learnedBy:find("bought", 1, true), "and the entry says HOW it was learned  [" .. tostring(learnedBy) .. "]")
	check(ns.SpellTraining.stats.bought == 1 and ns.SpellTraining.stats.confirmed == 1 and #ns.SpellTraining.pending == 0, "counters: 1 bought, 1 confirmed, none waiting")
	local ns2 = session(2)
	check(titles(ns2) == "" or titles(ns2) == "Rockbiter Weapon Rank 1", "(a fresh stub session has its own store)")
	check(#ns.errors == 0, "no errors")
end

section("purchase: SPELLS_CHANGED alone confirms when the price was paid; the learned state survives a reload")
do
	T.rows = { row("Rockbiter Weapon", "available", 1, 10, "Rank 1") }
	T.money, T.now = 1000, 100
	local ns = session(2)
	ev(ns, "TRAINER_SHOW")
	buy(ns, 1, { after = {}, event = "SPELLS_CHANGED" })
	check(titles(ns) == "", "SPELLS_CHANGED with the price paid confirms the purchase  [" .. titles(ns) .. "]")
	local db = ForeverCodexDB
	local st = ns.Prefs.Char().spellTraining
	local n = 0
	for _, e in pairs(st.entries) do if e.learned then n = n + 1 end end
	check(n == 1, "the entry is stored as learned (that is what a reload reads back)")
end

section("purchase: a REFUSED purchase (not enough money): no learn event, nothing is marked, the spell stays listed, and the pending purchase expires")
do
	T.rows = { row("Earth Shock", "available", 4, 100, "Rank 1") }
	T.money, T.now = 5, 100
	local ns = session(4)
	ev(ns, "TRAINER_SHOW")
	buy(ns, 1, { fail = true })
	check(#ns.SpellTraining.pending == 1, "the click was remembered as pending")
	check(titles(ns) == "Earth Shock Rank 1", "but it is not learned  [" .. titles(ns) .. "]")
	ev(ns, "SPELLS_CHANGED")                                           -- an unrelated spell change, and the money did NOT drop
	check(titles(ns) == "Earth Shock Rank 1", "an unrelated SPELLS_CHANGED without the price paid confirms nothing  [" .. titles(ns) .. "]")
	H.world().now = H.world().now + 30                                 -- (boot installs its own clock: the world's)
	ns.State.Recompute()
	titles(ns)                                                         -- (the card is rebuilt on every refresh: that is when a stale purchase is dropped)
	check(#ns.SpellTraining.pending == 0 and ns.SpellTraining.stats.expired == 1, "after the wait the pending purchase is dropped and counted")
	check(titles(ns) == "Earth Shock Rank 1", "and the spell is still listed")
	ev(ns, "LEARNED_SPELL_IN_TAB")                                     -- a late event with nothing pending changes nothing
	check(titles(ns) == "Earth Shock Rank 1", "a learn event with nothing pending is ignored")
end

section("purchase: a learn event is not enough on its own when the price was visibly NOT paid")
do
	T.rows = { row("Earth Shock", "available", 4, 100, "Rank 1") }
	T.money, T.now = 1000, 100
	local ns = session(4)
	ev(ns, "TRAINER_SHOW")
	_G.BuyTrainerService(1)                                            -- clicked; the money never moves (a refused buy) ...
	ev(ns, "LEARNED_SPELL_IN_TAB")                                     -- ... while some other spell is learned (a quest reward)
	check(titles(ns) == "Earth Shock Rank 1", "the listed spell is not marked learned by an unrelated learn event  [" .. titles(ns) .. "]")
end

section("purchase: ranks: buying Rank 2 retires Rank 1 for good; buying Rank 1 only never retires Rank 2")
do
	T.rows = { row("Earth Shock", "available", 4, 100, "Rank 1"), row("Earth Shock", "unavailable", 8, 300, "Rank 2") }
	T.money, T.now = 5000, 100
	local ns = session(8)
	ev(ns, "TRAINER_SHOW")
	check(titles(ns) == "Earth Shock Rank 1", "only the lowest rank still to learn is listed  [" .. titles(ns) .. "]")
	buy(ns, 1, { after = { row("Earth Shock", "used", 0, 100, "Rank 1"), row("Earth Shock", "available", 8, 300, "Rank 2") } })
	check(titles(ns) == "Earth Shock Rank 2", "Rank 1 bought: Rank 2 is next  [" .. titles(ns) .. "]")
	-- Rank 2 is bought and the window (known filter off) lists nothing
	buy(ns, 2, { after = {} })
	check(titles(ns) == "", "Rank 2 bought: nothing left to train  [" .. titles(ns) .. "]")
	-- a character that skipped straight to the higher rank in the store: lower rank must be retired by the purchase itself
	T.rows = { row("Frost Shock", "available", 6, 100, "Rank 1"), row("Frost Shock", "available", 6, 150, "Rank 2") }
	T.money, T.now = 5000, 100
	local ns2 = session(8)
	ev(ns2, "TRAINER_SHOW")
	buy(ns2, 2, { after = {} })
	local lower
	for _, e in pairs(ns2.Prefs.Char().spellTraining.entries) do if e.rank == "Rank 1" then lower = e end end
	check(lower and lower.learned and lower.learnedBy:find("higher rank", 1, true), "the lower rank is MARKED learned by the higher purchase (not just hidden)  [" .. tostring(lower and lower.learnedBy) .. "]")
	check(titles(ns2) == "", "nothing of Frost Shock is listed  [" .. titles(ns2) .. "]")
end

section("purchase: ranks without rank text (as Forever returned them): the level requirement orders them")
do
	T.rows = { row("Serpent Sting", "available", 4, 100), row("Serpent Sting", "available", 10, 400) }
	T.money, T.now = 5000, 100
	local ns = session(10)
	ev(ns, "TRAINER_SHOW")
	buy(ns, 2, { after = {} })
	check(titles(ns) == "", "buying the level-10 version retires the level-4 one  [" .. titles(ns) .. "]")
end

section("purchase: only AVAILABLE class-trainer rows count: an unavailable row, a profession trainer, a bad index")
do
	T.rows = { row("Earth Shock", "unavailable", 20, 100, "Rank 1") }
	T.money, T.now = 5000, 100
	local ns = session(4)
	ev(ns, "TRAINER_SHOW")
	check(ns.SpellTraining.OnPurchase(1) == false, "an unavailable row is not a purchase")
	check(ns.SpellTraining.OnPurchase(9) == false and ns.SpellTraining.OnPurchase("x") == false and ns.SpellTraining.OnPurchase(nil) == false, "a missing row or a bad index is ignored")
	T.rows, T.tradeskill = { row("Herb Lore", "available", 1, 10, "Apprentice") }, true
	check(ns.SpellTraining.OnPurchase(1) == false, "a profession trainer is not class training")
	T.tradeskill = false
	check(#ns.SpellTraining.pending == 0 and #ns.errors == 0, "nothing pending, no errors")
end

section("purchase: a double click is one purchase")
do
	T.rows = { row("Rockbiter Weapon", "available", 1, 10, "Rank 1") }
	T.money, T.now = 1000, 100
	local ns = session(2)
	ev(ns, "TRAINER_SHOW")
	_G.BuyTrainerService(1); _G.BuyTrainerService(1)
	check(#ns.SpellTraining.pending == 1 and ns.SpellTraining.stats.bought == 1, "one pending purchase")
end

section("purchase: character isolation: a purchase never lands on another character, and the 0.7.5 identity reset still clears spell state")
do
	T.rows = { row("Rockbiter Weapon", "available", 1, 10, "Rank 1") }
	T.money, T.now = 1000, 100
	local ns = session(2)
	ev(ns, "TRAINER_SHOW")
	_G.BuyTrainerService(1)
	ns.Prefs.SetCharKey("Other-Realm")                                 -- the player switched character before the learn event arrived
	T.money = T.money - 10
	ev(ns, "LEARNED_SPELL_IN_TAB")
	check(#ns.SpellTraining.pending == 0 and ns.SpellTraining.stats.confirmed == 0, "the purchase was dropped, not applied to the other character")
	local other = ns.Prefs.Char().spellTraining
	local any = false
	for _, e in pairs(other and other.entries or {}) do if e.learned then any = true end end
	check(not any, "the other character has no learned spell from it")
	ns.Prefs.SetCharKey("Another-Realm")
	local ns3 = session(2)
	ev(ns3, "TRAINER_SHOW")
	check(titles(ns3) == "Rockbiter Weapon Rank 1", "a different (fresh) character is unaffected: the spell is listed for it  [" .. titles(ns3) .. "]")
end

section("purchase: the trainer's own 'used' row still retires a spell (fallback) and the absence rule still works; both with no hook at all")
do
	T.rows = { row("Rockbiter Weapon", "available", 1, 10, "Rank 1"), row("Earth Shock", "available", 4, 100, "Rank 1") }
	T.money, T.now = 5000, 100
	_G.hooksecurefunc, _G.BuyTrainerService = nil, nil
	local ns = session(4)
	_G.BuyTrainerService = nil
	check(ns.SpellTraining.hook ~= "hooked", "no hooksecurefunc / BuyTrainerService: the hook is simply not installed  [" .. tostring(ns.SpellTraining.hook) .. "]")
	ev(ns, "TRAINER_SHOW")
	check(titles(ns) == "Earth Shock Rank 1;Rockbiter Weapon Rank 1" or titles(ns):find("Rockbiter", 1, true) and titles(ns):find("Earth Shock", 1, true), "(setup) both listed  [" .. titles(ns) .. "]")
	T.rows = { row("Rockbiter Weapon", "used", 0, 10, "Rank 1"), row("Earth Shock", "available", 4, 100, "Rank 1") }
	ev(ns, "TRAINER_UPDATE")
	check(titles(ns) == "Earth Shock Rank 1", "a 'used' row retires Rockbiter without any hook  [" .. titles(ns) .. "]")
	T.rows = { row("Rockbiter Weapon", "used", 0, 10, "Rank 1") }         -- Earth Shock is bought and no longer listed (known filter on, available filter on)
	T.filters = { available = true, unavailable = true, used = true }
	ev(ns, "TRAINER_UPDATE")
	T.filters = nil
	check(titles(ns) == "", "the absence rule still retires Earth Shock when other stored spells appear in the window  [" .. titles(ns) .. "]")
	check(#ns.errors == 0, "no errors")
	setGlobals()
end

section("purchase: the report shows the hook and the purchase counters")
do
	T.rows = { row("Rockbiter Weapon", "available", 1, 10, "Rank 1") }
	T.money, T.now = 1000, 100
	local ns = session(2)
	ev(ns, "TRAINER_SHOW")
	buy(ns, 1, { after = {} })
	local text = table.concat(ns.SpellTraining.ReportLines(ns.State.ctx), "\n")
	check(text:find("purchase hook (BuyTrainerService): hooked", 1, true) and text:find("purchases seen 1, matched by a learn event 1", 1, true), "the report names the hook state and the counters")
end

restoreGlobals()
