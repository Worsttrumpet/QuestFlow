-- reward_icons_tests.lua (0.9.7): the reward overlay. The Advisor decides, the overlay (UI/RewardOverlay.lua) only DISPLAYS Advisor.Display(): tags, short stat text, RECOMMENDED / NO CLEAR PICK,
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
local EQ = equipped({ [16] = facts({ id = 900, name = "Defias Rapier", stats = { [DPS] = 8.125, [AGI] = 2 } }),
	[17] = facts({ id = 901, name = "Quickblade's Dagger", slot = "INVTYPE_WEAPON", stats = { [DPS] = 6.76, [AGI] = 1 } }) })
local ROGUE = { level = 15, classToken = "ROGUE" }

local I = ns.CodexIcons
local function dialog(list, char)
	local ch = {}
	for i, f in ipairs(list) do ch[i] = { index = i, kind = "choice", id = f.id, name = f.fields.name.value, facts = f } end
	return { dialog = { live = true, q = 5730, at = "QUEST_COMPLETE", choices = ch, rewards = {} }, equipped = EQ, character = char or ROGUE }
end
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

section("codex icons: the set is complete, well-formed, and every glyph is a different shape")
do
	local need = {}
	for id, c in pairs(A.CATEGORIES) do need[#need + 1] = { id = id, tag = c.tag } end
	for _, n in ipairs(need) do
		check(I.FOR_TAG[n.tag] ~= nil, "advisor category " .. n.id .. " (" .. n.tag .. ") has an icon: " .. tostring(I.FOR_TAG[n.tag]))
	end
	local seen, count = {}, 0
	for id, rows in pairs(I.GLYPHS) do
		count = count + 1
		local ok, lit = #rows == I.SIZE, 0
		for _, r in ipairs(rows) do
			if #r ~= I.SIZE or r:find("[^#%.]") then ok = false end
			for _ in r:gmatch("#") do lit = lit + 1 end
		end
		check(ok, id .. ": a " .. I.SIZE .. " x " .. I.SIZE .. " grid of # and .")
		check(lit >= 8 and lit <= 70, id .. ": readable at small size (" .. lit .. " cells lit)")
		local key = table.concat(rows, "/")
		check(not seen[key], id .. ": no other icon has the same shape (colour is never the only signal)" .. (seen[key] and (" - same as " .. seen[key]) or ""))
		seen[key] = id
		check(I.WORD[id] ~= nil, id .. ": has its meaning in words for the tooltip")
	end
	check(count == 13, "eleven classification icons plus the two stars  [" .. count .. "]")
	for _, name in ipairs({ "UPGRADE", "NOT_AN_UPGRADE", "SLIGHT_UPGRADE", "MIXED", "COMBAT_UTILITY", "FUTURE_USE", "VENDOR", "NOT_USABLE", "UNKNOWN", "RECOMMENDED" }) do
		check(I.GLYPHS[name] ~= nil, "the requested icon " .. name .. " exists")
	end
	check(I.GLYPHS.RECOMMENDED ~= I.GLYPHS.TENTATIVE and table.concat(I.GLYPHS.RECOMMENDED) ~= table.concat(I.GLYPHS.TENTATIVE), "the solid star (pick) and the hollow star (tentative) differ")
	check(I.FOR_TAG["RECOMMENDED"] == nil and I.FOR_TAG["TENTATIVE"] == nil, "no classification word maps to a star: the recommendation is its own thing")
end

section("codex icons: the overlay shows icons, not text")
do
	local b = buttons(4)
	local kris = w(1, "Kris of Orgrimmar", { [DPS] = 8, [STA] = 4 }, CF, { slot = "INVTYPE_WEAPON" })
	local hammer = w(2, "Hammer of Orgrimmar", { [DPS] = 12.41, [STR] = 3, [SPI] = 3 }, CF, { subType = "Maces", sub = 4 })
	local axe = w(3, "Axe of Orgrimmar", { [DPS] = 16.06, [SPI] = 6, [STA] = 6 }, N, { slot = "INVTYPE_2HWEAPON", sub = 1 })
	local staff = w(4, "Staff of Orgrimmar", { [DPS] = 11.8, [AGI] = 6 }, N, { slot = "INVTYPE_2HWEAPON", sub = 10 })
	check(RO.Update(dialog({ kris, hammer, axe, staff })) == 4, "four choices annotated")
	local function glyphs(i) return table.concat(RO.Glyphs(RO.state.attached[i].row), ",") end
	check(glyphs(1) == "MIXED,UNKNOWN", "Kris: MIXED and a ? (usability unclear)  [" .. glyphs(1) .. "]")
	check(glyphs(2) == "MIXED,UNKNOWN" and RO.StarGlyph(RO.state.attached[2].row) == "TENTATIVE", "Hammer: MIXED and ?, and ALSO the tentative star (a mixed item can be the pick)  [" .. glyphs(2) .. "]")
	check(glyphs(3) == "NOT_USABLE,VENDOR" and glyphs(4) == "NOT_USABLE,VENDOR", "Axe and Staff: two badges, NOT_USABLE then VENDOR")
	check(RO.StarGlyph(RO.state.attached[1].row) == nil and RO.StarGlyph(RO.state.attached[3].row) == nil, "only the Hammer has a star")
	-- what is drawn
	local s1, s2, s3 = RO.Strip(b[1]), RO.Strip(b[2]), RO.Strip(b[3])
	check(s1.text == nil and s2.text == nil and s3.text == nil, "no text strip remains on any button")
	check(#s3.badges == 2 and s3.badges[1].glyph == "NOT_USABLE" and s3.badges[2].glyph == "VENDOR", "Axe: two badges drawn, in order")
	check(s3.badges[1].lit > 8, "the glyph's cells are painted")
	check(s2.star and s2.star.glyph == "TENTATIVE" and s2.star.frame.__shown ~= false, "the Hammer's star is drawn")
	check(s1.star == nil or s1.star.frame.__shown == false, "Kris has no star showing")
	check(s2.edges[1].__shown == true, "the recommended button also has the gold border")
	for i = 1, 4 do
		local st = RO.Strip(b[i])
		check(st.frame.__mouse == false, "button " .. i .. ": the icon row takes no mouse input")
		for _, bd in ipairs(st.badges) do check(bd.frame.__mouse == false, "button " .. i .. ": a badge takes no mouse input") end
	end
	-- WHERE they are drawn (0.9.7 shipped with the old anchor and no test for it): the bottom-right corner of the button, only as wide as the badges
	for i = 1, 4 do
		local st = RO.Strip(b[i])
		local pt = st.frame.__points
		check(pt and pt[1] == "BOTTOMRIGHT" and pt[2] == b[i] and pt[3] == "BOTTOMRIGHT", "button " .. i .. ": the icon row is anchored to the button's bottom-right corner")
		local n = #st.badges + (RO.StarGlyph(RO.state.attached[i].row) and 1 or 0)
		local row = RO.state.attached[i].row
		local nb = #RO.Glyphs(row)
		local expect = nb * (I.BadgeSize() + 2) - 2 + (RO.StarGlyph(row) and (I.BadgeSize() + 2) or 0) + (row.vendor and (st.price.__w_est or (st.priceWidth + 3)) or 0)
		check(math.abs((st.frame.__w or 0) - expect) < 0.01, "button " .. i .. ": the row is exactly as wide as its badges (and price), so it cannot reach the item icon  [" .. tostring(st.frame.__w) .. " vs " .. expect .. "]")
	end
	check(RO.state.summary == nil, "there is no verdict line at all (the star and the gold border mark a pick)")
	-- the tooltip carries the words
	local lines = {}
	GameTooltip.AddLine = function(_, text) lines[#lines + 1] = text end
	b[2].hooks.OnEnter(b[2])
	local all = table.concat(lines, "|")
	check(all:find("CODEX: MIXED", 1, true) and not all:find("dps", 1, true) and #lines <= 2, "the tooltip is just CODEX: MIXED, no numbers, no pick sentence  [" .. all .. "]")
	GameTooltip.AddLine = nil
end

section("simple reward display: an icon row, the sell value beside the coin, a one-line tooltip, no numbers, no verdict line")
do
	local AR = "RESISTANCE0_NAME"
	local b = buttons(3)
	local cuffs = facts({ id = 950, name = "Prospector's Cuffs", slot = "INVTYPE_WRIST", type = "Armor", stats = { [AR] = 32, [AGI] = 2, [STA] = 1 } })
	local eq2 = equipped({ [9] = cuffs })
	local function dlg(list)
		local ch = {}
		for i, f in ipairs(list) do ch[i] = { index = i, kind = "choice", id = f.id, name = f.fields.name.value, facts = f } end
		return { dialog = { live = true, q = 5724, at = "QUEST_COMPLETE", choices = ch, rewards = {} }, equipped = eq2, character = ROGUE }
	end
	local function armorPiece(id, name, stats, flags)
		local o = { id = id, name = name, stats = stats, slot = "INVTYPE_WRIST", sub = 1, sell = 215 }
		for k, v in pairs(flags) do o[k] = v end
		return facts(o)
	end
	local feather = armorPiece(1, "Featherbead Bracers", { [AR] = 14 }, U)
	local better = armorPiece(2, "Savannah Bracers", { [AR] = 33, [AGI] = 2, [STA] = 3 }, U)
	local junk = armorPiece(3, "Garrison Cuffs", { [AR] = 10 }, N)
	local d = A.Display(dlg({ feather, better, junk }))
	check(d ~= nil and #d.rows == 3, "three rows")
	local r1, r2, r3 = d.rows[1], d.rows[2], d.rows[3]
	check(r2.headline == "UPGRADE", "an upgrade says UPGRADE  [" .. tostring(r2.headline) .. "]")
	check(r1.headline == "NOT AN UPGRADE" and r1.tags[1] == "NOT AN UPGRADE", "a downgrade says NOT AN UPGRADE and gets its own icon  [" .. tostring(r1.headline) .. "]")
	check(r3.headline == "NOT USABLE" and r3.vendor and r3.vendor:find("2s 15c", 1, true), "an unusable item says NOT USABLE and carries its sell value  [" .. tostring(r3.headline) .. " | " .. tostring(r3.vendor) .. "]")
	check(r1.compare == nil and r2.compare == nil and r3.compare == nil, "no stat or % comparison is built: Blizzard's tooltip has the stats")
	RO.Update(dlg({ feather, better, junk }))
	check(table.concat(RO.Glyphs(r1), ",") == "NOT_AN_UPGRADE,VENDOR" or table.concat(RO.Glyphs(r1), ",") == "NOT_AN_UPGRADE", "the downgrade's icons: down arrow (and the coin when vendor)  [" .. table.concat(RO.Glyphs(r1), ",") .. "]")
	local s3 = RO.Strip(b[3])
	check(s3.price and s3.price.__text == r3.vendor and s3.price.__shown ~= false, "the sell value is drawn on the window beside the coin  [" .. tostring(s3.price and s3.price.__text) .. "]")
	check(RO.Strip(b[2]).price == nil or RO.Strip(b[2]).price.__shown == false, "an upgrade shows no price")
	-- the price sits right after the coin badge, and the row is wide enough for it
	local coin
	for _, bd in ipairs(s3.badges) do if bd.glyph == "VENDOR" then coin = bd end end
	check(coin and s3.price.__points and s3.price.__points[1] == "LEFT" and s3.price.__points[4] >= coin.frame.__points[4] + I.BadgeSize(), "the price starts after the coin's right edge")
	check(s3.frame.__w >= coin.frame.__points[4] + I.BadgeSize() + #r3.vendor * 4, "the row is wide enough for coin and price  [" .. tostring(s3.frame.__w) .. "]")
	local lines = {}
	GameTooltip.AddLine = function(_, text) lines[#lines + 1] = text end
	b[3].hooks.OnEnter(b[3])
	local all = table.concat(lines, "|")
	check(all:find("CODEX: NOT USABLE", 1, true), "the tooltip says CODEX: NOT USABLE")
	check(not all:find("Sells", 1, true) and not all:find("%%", 1, true) and not all:find("armor", 1, true) and #lines <= 2, "and nothing else (no price, no numbers)  [" .. all .. "]")
	GameTooltip.AddLine = nil
	check(RO.state.summary == nil, "no verdict line, with or without a pick")
end


section("golden recommendation border: rendered on the right buttons, in both columns, and only for a real recommendation")
do
	local function pickCase(pickIndex)
		local b = buttons(4)
		local list = {}
		for i = 1, 4 do list[i] = (i == pickIndex) and w(i, "Good Dagger " .. i, { [DPS] = 12, [AGI] = 5 }, U) or w(i, "Poor Dagger " .. i, { [DPS] = 5, [AGI] = 1 }, U) end
		RO.Update(dialog(list))
		return b
	end
	for _, pick in ipairs({ 1, 2, 3, 4 }) do          -- 1 and 3 are the left column, 2 and 4 the right one
		local b = pickCase(pick)
		check(RO.state.display.pick == pick, "(setup) the advisor picks choice " .. pick)
		for i = 1, 4 do
			local st = RO.Strip(b[i])
			local on = (i == pick)
			for n = 1, 4 do
				check((st.edges[n].__shown == true) == on and (st.inner[n].__shown == true) == on, "pick " .. pick .. ", button " .. i .. ", side " .. n .. ": the gold border is " .. (on and "drawn" or "not drawn"))
			end
			check((RO.StarGlyph(RO.state.attached[i].row) ~= nil) == on and ((st.star and st.star.frame.__shown ~= false) == on or (not on and (st.star == nil or st.star.frame.__shown == false))), "pick " .. pick .. ", button " .. i .. ": the star is " .. (on and "drawn" or "not drawn"))
		end
		-- the shape of the border on the picked button: bright 3 px outside, a thin dark line inside it, anchored to the button's own four corners, nothing outside the button
		local sp = RO.Strip(b[pick]).edgeSpec
		check(sp.outer1.p1 == "TOPLEFT" and sp.outer1.p2 == "TOPRIGHT" and sp.outer1.h == RO.BORDER and sp.outer1.inset == 0, "pick " .. pick .. ": top side spans the button's top edge, " .. RO.BORDER .. " px")
		check(sp.outer2.p1 == "BOTTOMLEFT" and sp.outer2.p2 == "BOTTOMRIGHT" and sp.outer2.h == RO.BORDER and sp.outer2.inset == 0, "pick " .. pick .. ": bottom side")
		check(sp.outer3.p1 == "TOPLEFT" and sp.outer3.p2 == "BOTTOMLEFT" and sp.outer3.w == RO.BORDER and sp.outer3.inset == 0, "pick " .. pick .. ": left side")
		check(sp.outer4.p1 == "TOPRIGHT" and sp.outer4.p2 == "BOTTOMRIGHT" and sp.outer4.w == RO.BORDER and sp.outer4.inset == 0, "pick " .. pick .. ": right side (inside the button, so the scroll area cannot clip it)")
		check(sp.inner1.inset == RO.BORDER and sp.inner1.h == 1 and sp.inner3.w == 1, "pick " .. pick .. ": the thin dark line sits just inside the gold")
		-- the border is not the icon row: they never share a frame or an anchor corner area
		check(RO.Strip(b[pick]).frame.__points[1] == "BOTTOMRIGHT" and RO.Strip(b[pick]).frame.__points[4] == -RO.INSET, "pick " .. pick .. ": the icon row is clear of the border (inset " .. RO.INSET .. " > border " .. RO.BORDER .. ")")
	end
	check(RO.INSET > RO.BORDER + 1, "the icon row's inset is wider than the border and its inner line")
	-- no recommendation: no border and no star anywhere
	local b = buttons(2)
	local t1 = w(1, "Trade One", { [DPS] = 8, [STR] = 3 }, U, { slot = "INVTYPE_WEAPONMAINHAND" })
	local t2 = w(2, "Trade Two", { [DPS] = 8, [STA] = 4 }, U, { slot = "INVTYPE_WEAPONMAINHAND" })
	RO.Update(dialog({ t1, t2 }))
	check(RO.state.display.pick == nil, "(setup) the advisor makes no recommendation")
	for i = 1, 2 do
		local st = RO.Strip(b[i])
		for n = 1, 4 do check(st.edges[n].__shown ~= true and st.inner[n].__shown ~= true, "no recommendation: button " .. i .. " has no gold border (side " .. n .. ")") end
		check(st.star == nil or st.star.frame.__shown == false, "no recommendation: button " .. i .. " has no star")
		check(#st.badges >= 1 and st.badges[1].frame.__shown ~= false, "the classification icons are still drawn")
	end
	-- the border follows the recommendation when it changes, and goes away with the dialog
	local b4 = pickCase(2)
	RO.Hide()
	for i = 1, 4 do for n = 1, 4 do check(RO.Strip(b4[i]).edges[n].__shown ~= true, "hidden dialog: no border left behind (" .. i .. "," .. n .. ")") end end
end

section("codex icons: placement clear of the window edge, and the tooltip repair")
do
	local b = buttons(2)
	local a = w(1, "Good Dagger", { [DPS] = 12, [AGI] = 5 }, U)
	local c = w(2, "Poor Dagger", { [DPS] = 5, [AGI] = 1 }, U)
	RO.Update(dialog({ c, a }))
	for i = 1, 2 do
		local pt = RO.Strip(b[i]).frame.__points
		check(pt and pt[4] == -RO.INSET and RO.INSET >= 10, "button " .. i .. ": the icon row stays " .. RO.INSET .. " px in from the button's right edge (the scroll area clips the right column)")
	end
	-- the game rebuilds its tooltip after our hook: the lines are added again, a few times at most
	local lines = {}
	GameTooltip.AddLine = function(_, text) lines[#lines + 1] = text end
	GameTooltip.NumLines = function() return #lines end
	for n = 1, 12 do
		_G["GameTooltipTextLeft" .. n] = { GetText = function() return lines[n] end }
	end
	b[2].hooks.OnEnter(b[2])
	check(RO.state.hover == b[2] and RO.state.tipHooks >= 1, "hovering records the button")
	local before = #lines
	RO.CheckTooltip()
	check(RO.state.tipScan == "readable" and #lines == before and RO.state.tipKept >= 1, "our lines present: nothing is added again")
	for i = #lines, 1, -1 do lines[i] = nil end              -- the game rebuilt its tooltip
	local lostBefore = RO.state.tipLost
	RO.CheckTooltip()
	check(RO.state.tipLost == lostBefore + 1 and #lines > 0 and table.concat(lines, "|"):find("CODEX: ", 1, true), "our lines gone: they are added again")
	for n = 1, 20 do for i = #lines, 1, -1 do lines[i] = nil end; RO.CheckTooltip() end
	check(RO.state.hoverFixes <= 5, "at most five repairs per hover  [" .. RO.state.hoverFixes .. "]")
	b[2].hooks.OnLeave(b[2])
	check(RO.state.hover == nil, "leaving the button stops the checking")
	local rep = table.concat(RO.ReportLines(), "\n")
	check(rep:find("tooltip check:", 1, true), "the report says what the tooltip check saw")
	GameTooltip.AddLine, GameTooltip.NumLines = nil, nil
	for n = 1, 12 do _G["GameTooltipTextLeft" .. n] = nil end
end

section("codex icons: the tooltip build hook (the real client rebuilds the tooltip constantly)")
do
	local b = buttons(2)
	local a = w(1, "Good Dagger", { [DPS] = 12, [AGI] = 5 }, U)
	local c = w(2, "Poor Dagger", { [DPS] = 5, [AGI] = 1 }, U)
	RO.Update(dialog({ c, a }))
	local lines, hooked = {}, nil
	_G.Enum = { TooltipDataType = { Item = 0 } }
	_G.TooltipDataProcessor = { AddTooltipPostCall = function(kind, fn) hooked = fn end }
	RO.postCall = nil
	RO.InstallPostCall()
	check(RO.postCall == "registered" and hooked ~= nil, "the build hook is registered when the client has it")
	GameTooltip.AddLine = function(_, text) lines[#lines + 1] = text end
	GameTooltip.NumLines = function() return #lines end
	GameTooltip.GetOwner = function() return b[2] end
	for n = 1, 12 do _G["GameTooltipTextLeft" .. n] = { GetText = function() return lines[n] end } end
	-- the game builds the tooltip (our lines go in during the build), then our OnEnter hook runs
	hooked(GameTooltip)
	local after = #lines
	check(table.concat(lines, "|"):find("CODEX: ", 1, true) and RO.state.postHits >= 1, "a build for a reward button gets our lines")
	b[2].hooks.OnEnter(b[2])
	check(#lines == after, "the OnEnter hook does not add them a second time  [" .. #lines .. " vs " .. after .. "]")
	-- the game rebuilds (clears and builds again), over and over: our lines are there every time, nothing needs repairing
	local lostBefore = RO.state.tipLost
	for n = 1, 10 do
		for i = #lines, 1, -1 do lines[i] = nil end
		hooked(GameTooltip)
		check(table.concat(lines, "|"):find("CODEX: ", 1, true), "rebuild " .. n .. ": our lines are in the build")
		RO.CheckTooltip()
	end
	check(RO.state.tipLost == lostBefore, "the repair loop stayed out of the way (no repair while the build hook works)")
	-- a tooltip that is not one of ours is left alone
	for i = #lines, 1, -1 do lines[i] = nil end
	GameTooltip.GetOwner = function() return {} end
	hooked(GameTooltip)
	check(#lines == 0, "a tooltip owned by something else is not touched")
	hooked({})
	check(#lines == 0, "and a different tooltip frame is not touched")
	-- without the hook the OnEnter + repair path still works
	RO.postCall = "unavailable"
	GameTooltip.GetOwner = function() return b[1] end
	b[1].hooks.OnEnter(b[1])
	check(table.concat(lines, "|"):find("CODEX: ", 1, true), "no build hook: the OnEnter path adds the lines")
	check(table.concat(RO.ReportLines(), "\n"):find("tooltip build hook", 1, true), "the report says whether the build hook is installed")
	RO.postCall = nil
	GameTooltip.AddLine, GameTooltip.NumLines, GameTooltip.GetOwner = nil, nil, nil
	_G.Enum, _G.TooltipDataProcessor = nil, nil
	for n = 1, 12 do _G["GameTooltipTextLeft" .. n] = nil end
end

section("codex icons: a plain recommendation, and more than four classifications")
do
	local b = buttons(2)
	local good = w(1, "Good Dagger", { [DPS] = 12, [AGI] = 5 }, U)
	local poor = w(2, "Poor Dagger", { [DPS] = 5, [AGI] = 1 }, U)
	RO.Update(dialog({ poor, good }))
	local row = RO.state.attached[2].row
	check(RO.StarGlyph(row) == "RECOMMENDED" and table.concat(RO.Glyphs(row), ",") == "UPGRADE", "UPGRADE badge plus the solid star")
	check(RO.Strip(b[2]).star.glyph == "RECOMMENDED", "the solid star is painted")
	local many = RO.Glyphs({ tags = { "UPGRADE", "COMBAT UTILITY", "FUTURE USE", "VENDOR", "MIXED", "NOT USABLE" }, unsure = true })
	check(#many == 4, "at most four badges fit under a button (the tooltip lists them all)  [" .. #many .. "]")
	check(table.concat(RO.Glyphs({ tags = { "SOMETHING NEW" } }), ",") == "UNKNOWN", "a classification word with no icon draws ?, never nothing")
	check(table.concat(RO.Glyphs({ tags = { "UNKNOWN" }, unsure = true }), ",") == "UNKNOWN", "a ? is not drawn twice")
	-- redraw: fewer badges than before hides the extras
	RO.Update(dialog({ poor, good }))
	RO.Hide()
	check(RO.Strip(b[2]).frame.__shown == false, "hiding the overlay hides the icons")
end

section("codex icons: architecture (drawing only, nothing decided here)")
do
	local function code(path)
		local f = assert(io.open(H.addonDir .. "/" .. path, "rb")); local t = f:read("*a"); f:close()
		return (t:gsub("%-%-[^\n]*", ""))
	end
	local src = code("UI/CodexIcons.lua")
	for _, bad in ipairs({ "ns.Advisor", "ns.ItemProbe", "ns.Eligibility", "ns.Gear", "ns.Items", "ns.Planner" }) do
		check(not src:find(bad, 1, true), "CodexIcons.lua does not touch " .. bad)
	end
	check(not src:find("CreateFontString", 1, true) and not src:find("SetText", 1, true), "CodexIcons.lua draws no text")
	local ov = code("UI/RewardOverlay.lua")
	check(not ov:find("summaryFont", 1, true), "no verdict line code is left; the only text the overlay draws is the sell value")
	local toc = assert(io.open(H.addonDir .. "/ForeverCodex.toc", "rb")):read("*a")
	local a, b2 = toc:find("UI\\CodexIcons.lua", 1, true), toc:find("UI\\RewardOverlay.lua", 1, true)
	check(a and b2 and a < b2, "the icon file loads before the overlay")
end
