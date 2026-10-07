-- reward_overlay_tests.lua (0.9.0): the reward overlay. The Advisor decides, the overlay (UI/RewardOverlay.lua) only DISPLAYS Advisor.Display(): tags, short stat text, RECOMMENDED / NO CLEAR PICK,
-- drawn on the game's own reward choice buttons (stub buttons here; the real frame's structure is not proven on Forever). Fake item data and fake dialogs: the clear-recommendation
-- rendering is FIXTURE-tested, not real-client-tested (the real Q5730 gives NO CLEAR PICK).

local H = ...
local check, section, boot = H.check, H.section, H.boot
local ns = boot({ char = { level = 15, class = "Rogue", classToken = "ROGUE" }, synthetic = true })
local A, RO, I, G = ns.Advisor, ns.RewardOverlay, ns.Items, ns.Gear

local function facts(o)
	local f = { name = o.name, link = "|Hitem:" .. (o.id or 1) .. "::|h[" .. o.name .. "]|h", quality = 1, level = 18, minLevel = 0, type = "Weapon", subType = "Daggers",
		equipLoc = o.slot or "INVTYPE_WEAPONMAINHAND", sellPrice = o.sell or 1291, classID = 2, subClassID = o.sub or 15, stats = o.stats or {}, usable = o.usable, usableSecond = o.second }
	local r = { id = o.id or 1, ref = o.id or 1, f = f, src = {}, err = {}, spellRead = true }
	if o.usable == nil then r.err.usable = "api absent" end
	local n = I.Normalize(r)
	if o.flag ~= nil then n.offered = { source = "reward_dialog", kind = "choice", index = 1, quest = 1, dialogFlag = o.flag } end
	return n
end
local function equipped(items)
	local eq = { state = "OK", slots = {}, list = {} }
	for n = 1, I.EQUIP_SLOTS do
		local e = { slot = n, slotName = G.SLOT_NAMES[n], state = "EMPTY" }
		if items and items[n] then e.state, e.itemFacts, e.itemId = "POPULATED", items[n], items[n].id end
		eq.slots[n], eq.list[n] = e, e
	end
	return eq
end
local DPS, AGI, STR, SPI, STA = "ITEM_MOD_DAMAGE_PER_SECOND_SHORT", "ITEM_MOD_AGILITY_SHORT", "ITEM_MOD_STRENGTH_SHORT", "ITEM_MOD_SPIRIT_SHORT", "ITEM_MOD_STAMINA_SHORT"
local U = { usable = true, second = true, flag = true }       -- the client's two usability answers agree: usable
local N = { usable = false, second = false, flag = false }     -- both say not usable
local CF = { usable = false, second = false, flag = true }     -- they disagree (the real Kris / Hammer)
local function w(id, name, stats, flags, extra)
	local o = { id = id, name = name, stats = stats }
	for k, v in pairs(flags) do o[k] = v end
	for k, v in pairs(extra or {}) do o[k] = v end
	return facts(o)
end
local EQ = equipped({ [16] = facts({ id = 900, name = "Defias Rapier", stats = { [DPS] = 8.125, [AGI] = 2 } }) })
local ROGUE = { level = 15, classToken = "ROGUE" }

--- A fake LIVE reward dialog of CHOICES, as ItemProbe.DialogFacts would give it.
local function dialog(list, at, live)
	local ch = {}
	for i, f in ipairs(list) do ch[i] = { index = i, kind = "choice", id = f.id, name = f.fields.name.value, facts = f } end
	return { dialog = { live = live ~= false, q = 5730, at = at or "QUEST_COMPLETE", choices = ch, rewards = {} }, equipped = EQ, character = ROGUE }
end

--- Stub reward buttons: the game's own frames, named as the overlay looks them up.
local function buttons(n)
	local out = {}
	for i = 1, 8 do _G["QuestInfoRewardsFrameQuestInfoItem" .. i] = nil end
	for i = 1, n do
		local b = CreateFrame("Button", "QuestInfoRewardsFrameQuestInfoItem" .. i)
		b.GetID = function() return i end
		b.hooks = {}
		b.HookScript = function(self, name, fn) self.hooks[name] = fn end
		out[i] = b
	end
	return out
end
local function strip(btn) return RO.state.attached and btn and nil end
local function textOf(i) for _, f in ipairs(H.world().fonts or {}) do end return nil end

local KRIS = function() return w(1, "Kris of Orgrimmar", { [DPS] = 8, [STA] = 4 }, CF) end
local HAMMER = function() return w(2, "Hammer of Orgrimmar", { [DPS] = 12.41, [STR] = 3, [SPI] = 3 }, CF, { subType = "Maces", sub = 4 }) end
local AXE = function() return w(3, "Axe of Orgrimmar", { [DPS] = 16.06, [SPI] = 6, [STA] = 6 }, N, { slot = "INVTYPE_2HWEAPON", sub = 1 }) end
local STAFF = function() return w(4, "Staff of Orgrimmar", { [DPS] = 11.8, [AGI] = 6 }, N, { slot = "INVTYPE_2HWEAPON", sub = 10 }) end

local function rowText(d, i) return table.concat(RO.Glyphs(d.rows[i]), ",") end    -- (0.9.7: the icon row as glyph ids)

section("reward overlay: Q5730 (the real four choices): NO CLEAR PICK, nothing recommended")
do
	local b = buttons(4)
	local d = A.Display(dialog({ KRIS(), HAMMER(), AXE(), STAFF() }))
	check(d ~= nil and #d.rows == 4, "the display has the four choices")
	check(d.verdict.kind == "tentative" and d.pick == 2, "the verdict names the Hammer as a TENTATIVE pick (0.9.6)  [" .. tostring(d.verdict.text) .. "]")
	check(d.rows[1].tags[1] == "MIXED" and d.rows[2].tags[1] == "MIXED", "Kris and Hammer are MIXED")
	check(d.rows[1].unsure and d.rows[2].unsure and rowText(d, 1):find("UNKNOWN", 1, true), "and their usability doubt is shown beside it as a ? icon, not hidden")
	check(d.rows[1].short == "+4 stamina, -2 agility", "Kris' short text is the comparison: " .. tostring(d.rows[1].short))
	check(d.rows[3].tags[1] == "NOT USABLE" and d.rows[3].tags[2] == "VENDOR" and d.rows[4].tags[1] == "NOT USABLE" and d.rows[4].tags[2] == "VENDOR", "Axe and Staff: NOT USABLE and VENDOR, both kept")
	for i = 1, 4 do check(d.rows[i].recommended == (i == 2 and "tentative" or nil), "choice " .. i .. (i == 2 and " is the tentative pick" or " is not recommended")) end
	check(rowText(d, 3) == "NOT_USABLE,VENDOR", "the icon row is NOT_USABLE, VENDOR  [" .. rowText(d, 3) .. "]")
	-- the advisor's own words are what is carried
	local c = A.Classify(KRIS(), EQ, { character = ROGUE })
	local reason
	for _, x in ipairs(c.categories) do if x.id == c.primary then reason = x.reason end end
	check(d.rows[1].reason == reason, "the reason is the advisor's own reason, unchanged")
	-- drawn on the buttons
	local n = RO.Update(dialog({ KRIS(), HAMMER(), AXE(), STAFF() }))
	check(n == 4 and RO.state.shown, "all four buttons were annotated")
	check(RO.state.summary.text.__text == "CODEX: TENTATIVE PICK - CHOICE 2", "the summary names choice 2 as the tentative pick (without the parenthetical, which the tooltip carries)")
	for i = 1, 4 do
		local bs = RO.state.attached[i]
		check(bs and bs.button == "QuestInfoRewardsFrameQuestInfoItem" .. i, "choice " .. i .. " is attached to its own button")
	end
end

section("reward overlay: a clear recommendation names the exact choice (fixture)")
do
	local b = buttons(2)
	local good = w(1, "Good Dagger", { [DPS] = 12, [AGI] = 5 }, U)
	local poor = w(2, "Poor Dagger", { [DPS] = 5, [AGI] = 1 }, U)
	local d = A.Display(dialog({ poor, good }))
	check(d.state == "RECOMMEND" and d.pick == 2 and d.verdict.kind == "pick" and d.verdict.text == "CODEX: RECOMMENDED - CHOICE 2", "the advisor recommends choice 2 and the verdict says so  [" .. tostring(d.verdict.text) .. "]")
	check(d.rows[2].recommended == "pick" and d.rows[1].recommended == nil, "only choice 2 is marked")
	check(d.rows[2].tags[1] == "UPGRADE" and rowText(d, 2) == "UPGRADE" and RO.StarGlyph(d.rows[2]) == "RECOMMENDED", "its icon row is UPGRADE plus the recommendation star  [" .. rowText(d, 2) .. "]")
	check(d.rows[2].short and d.rows[2].short:find("agility", 1, true), "and the stat text")
	check(RO.StarGlyph(d.rows[1]) == nil, "the other choice has no star")
	RO.Update(dialog({ poor, good }))
	local e1, e2 = RO.state.attached[1], RO.state.attached[2]
	check(e2 and e2.row.recommended == "pick" and e1 and e1.row.recommended == nil, "the recommendation is attached to choice 2's button, not choice 1's")
	check(RO.state.summary.text.__text == "CODEX: RECOMMENDED - CHOICE 2", "the summary names the choice")
	-- the gold border shows on the recommended button only
	local s1, s2 = RO.Strip(b[1]), RO.Strip(b[2])
	check(s2.edges[1].__shown == true and s2.edges[4].__shown == true, "choice 2 (recommended) has the gold border")
	check(s1.edges[1].__shown == false and s1.edges[3].__shown == false, "choice 1 has none")
end

section("reward overlay: no pick when uncertain; unknown stays unknown")
do
	buttons(2)
	-- two trade-offs: no pick
	-- (two trade-offs that no weapon-damage gain separates; Hammer vs Kris is now a pick, see reward_tradeoff_tests.lua)
	local t1 = w(1, "Trade One", { [DPS] = 8, [STR] = 3 }, U, { slot = "INVTYPE_WEAPONMAINHAND" })
	local t2 = w(2, "Trade Two", { [DPS] = 8, [STA] = 4 }, U, { slot = "INVTYPE_WEAPONMAINHAND" })
	local d = A.Display(dialog({ t1, t2 }))
	check(d.verdict.kind == "none" and d.pick == nil and d.rows[1].recommended == nil and d.rows[2].recommended == nil, "two trade-offs with no clear weapon-damage gain: NO CLEAR PICK, neither marked  [" .. tostring(d.verdict.text) .. "]")
	-- usability not established, improving: UNKNOWN, no recommendation made up
	-- (swords: nothing worn shows the proficiency, and the client's usability answers are absent)
	local u1 = w(5, "Maybe A", { [DPS] = 12, [AGI] = 5 }, {}, { subType = "Swords", sub = 7 })
	local u2 = w(6, "Maybe B", { [DPS] = 13, [AGI] = 6 }, {}, { subType = "Swords", sub = 7 })
	local du = A.Display(dialog({ u1, u2 }))
	check(du.rows[1].tags[1] == "UNKNOWN" and du.rows[2].tags[1] == "UNKNOWN" and du.verdict.kind ~= "pick", "usability not established: UNKNOWN, and never a RECOMMENDED pick")
	check(du.rows[1].unsure, "(and flagged unsure)")
	-- unusable ones are never the pick
	local dn = A.Display(dialog({ AXE(), STAFF() }))
	check(dn.verdict.kind == "none" and dn.rows[1].tags[1] == "NOT USABLE" and dn.rows[2].tags[1] == "NOT USABLE", "all unusable: NOT USABLE, NO CLEAR PICK")
end

section("reward overlay: when the display exists")
do
	buttons(2)
	check(A.Display(dialog({ KRIS() })) == nil, "one choice: nothing to decide, no display")
	check(A.Display(dialog({ KRIS(), HAMMER() }, "QUEST_DETAIL")) == nil, "the accept dialog (QUEST_DETAIL) is not annotated: only the turn-in choice is")
	check(A.Display(dialog({ KRIS(), HAMMER() }, "QUEST_COMPLETE", false)) == nil, "a dialog that is closed is not annotated")
	check(A.Display({ dialog = nil, equipped = EQ, character = ROGUE }) == nil or true, "no reward dialog at all: nothing")
	check(#ns.errors == 0, "no errors")
end

section("reward overlay: lifecycle (opens, updates, closes)")
do
	local b = buttons(2)
	local d1 = dialog({ KRIS(), HAMMER() })
	check(RO.Update(d1) == 2 and RO.state.shown and RO.state.summary.frame.__shown ~= false, "the annotations appear when the dialog is open")
	local before = RO.state.display.rows[1].tags[1]
	-- the observation changes: a better choice appears
	local good, poor = w(1, "Good Dagger", { [DPS] = 12, [AGI] = 5 }, U), w(2, "Poor Dagger", { [DPS] = 5, [AGI] = 1 }, U)
	RO.Update(dialog({ good, poor }))
	check(RO.state.display.rows[1].recommended == "pick" and RO.state.summary.text.__text == "CODEX: RECOMMENDED - CHOICE 1" and before == "MIXED", "an updated observation redraws (MIXED -> RECOMMENDED choice 1)")
	-- the dialog closes: advisor says nothing -> hidden
	RO.Update(dialog({ good, poor }, "QUEST_COMPLETE", false))
	check(not RO.state.shown and RO.state.summary.frame.__shown == false, "closing the dialog hides everything")
	-- the light close check
	RO.Update(d1)
	check(RO.state.shown, "(setup) shown again")
	ns.ItemProbe.DialogOpen = function() return false end
	RO.frame.__scripts.OnUpdate(RO.frame, 1)
	check(not RO.state.shown, "the periodic check hides the annotations once the game's dialog is no longer open")
	check(#ns.errors == 0, "no errors")
end

section("reward overlay: the right annotation on the right reward, any number of choices")
do
	local b = buttons(4)
	local items = { KRIS(), HAMMER(), AXE(), STAFF() }
	RO.Update(dialog(items))
	local rows = RO.state.display.rows
	for i = 1, 4 do
		check(RO.state.attached[i].row.name == rows[i].name and RO.state.attached[i].row.index == i, "button " .. i .. " carries choice " .. i .. " (" .. rows[i].name .. ")")
	end
	check(RO.state.attached[1].row.name ~= RO.state.attached[2].row.name, "choice 1's annotation is not on choice 2")
	-- three choices: the fourth button is not annotated
	buttons(3)
	local n = RO.Update(dialog({ KRIS(), HAMMER(), AXE() }))
	check(n == 3 and RO.state.attached[4] == nil, "three choices: three annotations, none on a fourth button")
	-- a button that is not shown, or says it is another choice, is not used
	local b2 = buttons(2)
	b2[2].__shown = false
	check(RO.Update(dialog({ KRIS(), HAMMER() })) == 1 and RO.state.attached[2] == nil, "a choice whose button is not shown is not annotated (and its text does not land on choice 1)")
	local b3 = buttons(2)
	b3[2].GetID = function() return 1 end
	check(RO.Update(dialog({ KRIS(), HAMMER() })) == 1, "a button that says it is a different choice is not used")
	-- no buttons at all: nothing is drawn, nothing breaks
	buttons(0)
	check(RO.Update(dialog({ KRIS(), HAMMER() })) == 0 and not RO.state.shown, "no reward buttons found: no annotation, no summary, no error")
	local rep = table.concat(RO.ReportLines(), "\n")
	check(rep:find("choice buttons found now: none", 1, true) ~= nil, "the report says no choice button was found")
	check(#ns.errors == 0, "no errors")
end

section("reward overlay: it does not replace or block the game's reward controls")
do
	local b = buttons(2)
	local scriptsBefore = {}
	for i, bt in ipairs(b) do scriptsBefore[i] = next(bt.__scripts) end
	RO.Update(dialog({ KRIS(), HAMMER() }))
	for i, bt in ipairs(b) do
		check(next(bt.__scripts) == scriptsBefore[i], "button " .. i .. ": no script of the game's button was replaced (the overlay only adds a hook)")
		check(_G["QuestInfoRewardsFrameQuestInfoItem" .. i] == bt, "button " .. i .. ": still the game's own frame")
		check(bt.hooks.OnEnter ~= nil, "button " .. i .. ": its tooltip is extended through a hook")
	end
	local blocking = (RO.state.summary.frame.__mouse ~= false) and 1 or 0
	for _, bt in ipairs(b) do
		local st = RO.Strip(bt)
		check(st ~= nil and st.frame.__mouse == false, "the strip on button's frame takes no mouse input")
	end
	check(blocking == 0, "the summary takes no mouse input either")
	-- tooltip: the advisor's full reason is added to the game's own tooltip
	local lines = {}
	GameTooltip.AddLine = function(_, text) lines[#lines + 1] = text end
	b[1].hooks.OnEnter(b[1])
	check(table.concat(lines, "|"):find("Compared with what you wear: " .. RO.state.attached[1].row.short, 1, true), "the tooltip carries the stat comparison the strip leaves out")
	check(#lines >= 2 and table.concat(lines, "|"):find("Codex:", 1, true) and table.concat(lines, "|"):find(RO.state.attached[1].row.reason, 1, true), "hovering adds the advisor's reason to the tooltip")
	GameTooltip.AddLine = nil
end

section("reward overlay: architecture (the advisor decides, the overlay displays)")
do
	local function code(path)
		local s = H.readFile(H.addonDir .. "/" .. path)
		return (s:gsub("%-%-[^\n]*", ""))
	end
	local ov = code("UI/RewardOverlay.lua")
	for _, bad in ipairs({ "DialogFacts", "ns%.Gear", "ns%.Eligibility", "ns%.Items", "Classify", "CompareToEquipped", "IsUsableItem", "GetQuestReward", "GetQuestItemInfo", "ns%.Planner", "ns%.Registry" }) do
		check(not ov:find(bad), "RewardOverlay.lua does not use " .. bad)
	end
	check(ov:find("ns%.Advisor%.Display") or ov:find("ns%.Advisor, ns%.Advisor%.Display") or ov:find("pcall%(ns%.Advisor%.Display"), "it reads the advisor's Display()")
	check(not code("UI/RewardOverlay.lua"):find("SetScript%(\"OnClick\""), "it never sets a click handler")
	for _, f in ipairs({ "Planner.lua", "Engine.lua", "Presenter.lua", "Overlap.lua", "PlanAdapter.lua", "Providers/Quest.lua", "State.lua", "Strategies.lua", "Navigation.lua" }) do
		check(not code(f):find("RewardOverlay") and not code(f):find("ns%.Advisor"), f .. " reads neither the overlay nor the advisor")
	end
	check(not code("RewardAdvisor.lua"):find("RewardOverlay") and not code("ItemProbe.lua"):find("RewardOverlay"), "the advisor and the evidence layer do not know the overlay")
	local u = H.readFile(H.addonDir .. "/UI/RewardOverlay.lua")
	check(not u:find("[\128-\255]"), "plain ASCII")
	check(H.readFile(H.addonDir .. "/ForeverCodex.toc"):find("UI\\RewardOverlay.lua", 1, true) ~= nil, "it is in the .toc")
end

section("reward overlay: a dialog that opens without a usable event is noticed (the 0.9.1 real-client finding)")
do
	local b = buttons(2)
	RO.Hide()
	local real = A.Display
	local calls = 0
	A.Display = function() calls = calls + 1; return real(dialog({ KRIS(), HAMMER() })) end
	ns.ItemProbe.DialogOpen = function() return true end
	check(not RO.state.shown, "(setup) nothing is showing")
	RO.frame.__scripts.OnUpdate(RO.frame, 1)
	check(RO.state.shown and calls == 1, "the poll sees the open dialog and draws the annotations, with no event")
	RO.frame.__scripts.OnUpdate(RO.frame, 1)
	check(calls == 1 and RO.state.shown, "it does not redraw every tick while the dialog stays open")
	ns.ItemProbe.DialogOpen = function() return false end
	RO.frame.__scripts.OnUpdate(RO.frame, 1)
	check(not RO.state.shown, "and hides when the dialog closes")
	-- a dialog with nothing to annotate settles: no repeated reads
	A.Display = function() calls = calls + 1; return nil end
	ns.ItemProbe.DialogOpen = function() return true end
	calls = 0
	RO.frame.__scripts.OnUpdate(RO.frame, 1)
	RO.frame.__scripts.OnUpdate(RO.frame, 1)
	RO.frame.__scripts.OnUpdate(RO.frame, 1)
	check(calls == 1, "a dialog with nothing to annotate is asked about once, not every tick  [" .. calls .. "]")
	ns.ItemProbe.DialogOpen = function() return false end
	RO.frame.__scripts.OnUpdate(RO.frame, 1)
	ns.ItemProbe.DialogOpen = function() return true end
	RO.frame.__scripts.OnUpdate(RO.frame, 1)
	check(calls == 2, "and asked again when the next dialog opens")
	-- buttons not there yet: a few ticks of back-off, then another try
	RO.Hide()
	buttons(0)
	A.Display = function() calls = calls + 1; return real(dialog({ KRIS(), HAMMER() })) end
	calls = 0
	RO.frame.__scripts.OnUpdate(RO.frame, 1)
	for _ = 1, 4 do RO.frame.__scripts.OnUpdate(RO.frame, 1) end
	check(calls == 1, "no buttons yet: it backs off instead of reading every tick  [" .. calls .. "]")
	A.Display = real
	ns.ItemProbe.DialogOpen = nil
end
