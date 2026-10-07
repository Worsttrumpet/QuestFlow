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
		check(lit >= 8 and lit <= 36, id .. ": readable at small size (" .. lit .. " cells lit)")
		local key = table.concat(rows, "/")
		check(not seen[key], id .. ": no other icon has the same shape (colour is never the only signal)" .. (seen[key] and (" - same as " .. seen[key]) or ""))
		seen[key] = id
		check(I.WORD[id] ~= nil, id .. ": has its meaning in words for the tooltip")
	end
	check(count == 12, "ten classification icons plus the two stars  [" .. count .. "]")
	for _, name in ipairs({ "UPGRADE", "SLIGHT_UPGRADE", "MIXED", "COMBAT_UTILITY", "FUTURE_USE", "VENDOR", "NOT_USABLE", "UNKNOWN", "RECOMMENDED" }) do
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
		local shownBadges = #RO.Glyphs(RO.state.attached[i].row) + (RO.StarGlyph(RO.state.attached[i].row) and 1 or 0)
		check(st.frame.__w == shownBadges * (I.BadgeSize() + 2) - 2, "button " .. i .. ": the row is exactly as wide as its badges, so it cannot reach the item icon  [" .. tostring(st.frame.__w) .. "]")
	end
	local sp = RO.state.summary.frame.__points
	check(sp and sp[1] == "BOTTOMRIGHT" and sp[3] == "TOPRIGHT", "the verdict sits right-aligned on the line above the top row")
	check(RO.state.summary.frame.__w <= RO.VERDICT_MAX and #RO.state.summary.text.__text <= 30, "the verdict is short and capped in width  [" .. RO.state.summary.text.__text .. "]")
	-- the tooltip carries the words
	local lines = {}
	GameTooltip.AddLine = function(_, text) lines[#lines + 1] = text end
	b[2].hooks.OnEnter(b[2])
	local all = table.concat(lines, "|")
	check(all:find("tentative pick", 1, true) and all:find("Compared with what you wear", 1, true) and all:find("Codex: MIXED", 1, true), "the tooltip says the pick in words, with the stat comparison and the reason")
	GameTooltip.AddLine = nil
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
	check(not ov:find("CreateFontString", 1, true) or ov:find("summaryFont", 1, true), "the only text left in the overlay is the verdict line")
	local toc = assert(io.open(H.addonDir .. "/ForeverCodex.toc", "rb")):read("*a")
	local a, b2 = toc:find("UI\\CodexIcons.lua", 1, true), toc:find("UI\\RewardOverlay.lua", 1, true)
	check(a and b2 and a < b2, "the icon file loads before the overlay")
end
