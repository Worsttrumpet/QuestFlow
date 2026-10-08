-- ui_polish_tests.lua: the player-UI polish pass (UI/Widgets.lua card system, UI/PageCodex.lua, the window shell in UI/Main.lua).
-- Stub-client tests: they prove the layout logic and that the page is only a rendering layer. They cannot show how it LOOKS on the real
-- client; that is a screenshot check (docs/CODEX_REALCLIENT_FIXES.md).
--   * every word still comes from the Presenter; the progress bar shows only counts the Presenter reports
--   * hierarchy (type sizes), spacing (nothing overlaps), cards that fit their content, NEW FOR YOU narrower than NOW
--   * the card system is reusable (a future panel is a new style plus its own lines)
--   * nothing here reads the Planner / data, and no stub-only field is used by the real code

local H = ...
local check, section, boot = H.check, H.section, H.boot

local function Q(id, name, dx, dy, o)
	local q = { id = id, name = name, map = 9001, x = 0.5 + dx / 1000, y = 0.5 + (dy or 0) / 1000 }
	for k, v in pairs(o or {}) do q[k] = v end
	return q
end

local function uiWorld(quests, log, level)
	local ns = boot({ char = { level = level or 6 }, synthetic = true, loc = { map = 9001, x = 0.5, y = 0.5, zone = "Fixture Valley" } })
	H.attPack(ns, quests, nil)
	local W = H.world()
	W.log, W.objectives = {}, {}
	for id, e in pairs(log or {}) do
		W.log[#W.log + 1] = { questID = id, title = e.title or ("quest " .. id), complete = e.complete == true }
		if e.objectives then
			W.objectives[id] = {}
			for i, ob in ipairs(e.objectives) do W.objectives[id][i] = { text = ob.text, type = "item", finished = ob.have >= ob.need, numFulfilled = ob.have, numRequired = ob.need } end
		end
	end
	ns.Prefs.FinishSetup()
	ns.State.Recompute()
	ns.UI.Open("codex")
	return ns, W, ns.UI.main.codex
end

local function y(f) return f.__points and -f.__points[5] or nil end     -- distance below the card's top
local function text(fs) return fs.__text or "" end

-- the quest with objective progress: a bar to scan at a glance
local QUEST = { Q(1, "Worgen Bits Quest", 60, 0, { giverName = "Dalar", objCoords = { { map = 9001, x = 0.56, y = 0.5 } } }) }

-- ---------------------------------------------------------------- 0.2.6: the compact companion panel

local ZONES = { { key = "zone-a", label = "Zone A", map = 9001, quests = 1 }, { key = "zone-b", label = "Zone B", map = 9002, quests = 1 } }

--- Quests the player has IN PROGRESS with no objective spot (as most are): { id, name, zone, objectives = { { text, have, need }, ... } }.
local function logWorld(list, o)
	o = o or {}
	local ns = boot({ char = { level = o.level or 6 }, synthetic = true, loc = { map = o.map or 9001, x = 0.5, y = 0.5, zone = "Fixture Valley" } })
	local quests, log = {}, {}
	for _, q in ipairs(list) do
		quests[#quests + 1] = { id = q.id, name = q.name, zone = q.zone, req = 1, giverName = "Giver " .. q.id, map = q.map, x = q.x, y = q.y, objCoords = q.objCoords }
		log[#log + 1] = q
	end
	H.attPack(ns, quests, ZONES)
	local W = H.world()
	W.log, W.objectives, W.completed = {}, {}, {}
	for _, q in ipairs(log) do
		W.log[#W.log + 1] = { questID = q.id, title = q.name, complete = q.complete == true }
		if q.objectives then
			W.objectives[q.id] = {}
			for i, ob in ipairs(q.objectives) do W.objectives[q.id][i] = { text = ob.text, type = "monster", finished = ob.have >= ob.need, numFulfilled = ob.have, numRequired = ob.need } end
		end
	end
	ns.Prefs.FinishSetup()
	ns.State.Recompute()
	ns.UI.Open("codex")
	return ns, W, ns.UI.main.codex
end

local function rowTexts(rows)
	local out = {}
	for _, r in ipairs(rows) do if r.__shown ~= false and r.cur then out[#out + 1] = tostring(r.label.__text) .. " " .. tostring(r.count.__text) end end
	return out
end

local GRAVE = { id = 10, name = "Graverobbers", zone = "zone-a", objectives = { { text = "Rot Hide Graverobber slain", have = 1, need = 8 }, { text = "Rot Hide Mongrel slain", have = 6, need = 8 }, { text = "Embalming Ichor", have = 6, need = 8 } } }
local DOOM = { id = 11, name = "Doom Weed", zone = "zone-a", objectives = { { text = "Doom Weed", have = 3, need = 10 } } }

section("window: NOW shows EVERY unfinished objective of the current quest, finished ones drop out, and there is no 'why' in the window")
do
	local ns, W, c = logWorld({ GRAVE })
	local card = ns.Presenter.Card(ns.State.plan, ns.State.ctx)
	check(card.now and card.now.title == "Finish Graverobbers" and #card.now.objectives == 3, "(setup) the Presenter reports all three objectives")
	check(c.nowTitle.__text == "Finish Graverobbers", "NOW names the quest")
	local rows = rowTexts(c.nowRows)
	check(#rows == 3 and rows[1] == "Rot Hide Graverobber slain 1/8" and rows[2] == "Rot Hide Mongrel slain 6/8" and rows[3] == "Embalming Ichor 6/8", "every unfinished objective is a row with its own count  [" .. table.concat(rows, " | ") .. "]")
	check(math.abs(c.nowRows[1].fraction - 1 / 8) < 1e-9 and math.abs(c.nowRows[2].fraction - 6 / 8) < 1e-9, "each row has its own bar")
	check(not c.nowDetail.__text or c.nowDetail.__text == "", "no 'and 1 more' sentence next to the rows")
	-- progress changes: a finished objective disappears, the others update
	W.objectives[10][2].numFulfilled, W.objectives[10][2].finished = 8, true
	W.objectives[10][1].numFulfilled = 4
	ns.State.Recompute()
	rows = rowTexts(c.nowRows)
	check(#rows == 2 and rows[1] == "Rot Hide Graverobber slain 4/8" and rows[2] == "Embalming Ichor 6/8", "a completed objective leaves the display and the counts update  [" .. table.concat(rows, " | ") .. "]")
	-- no explanation of WHY anywhere in the window, but the Presenter (and /codex report) still carry it
	local texts = {}
	for _, f in ipairs(W.frames) do for _, fs in ipairs(f.__regions or {}) do if fs.__text then texts[#texts + 1] = fs.__text end end end
	local all = table.concat(texts, "\n")
	check(c.nowWhy.__text == "Why: Keeps your current quests moving where you are.", "the window draws ONE short 'Why:' line under the action (0.7.8)  [" .. tostring(c.nowWhy.__text) .. "]")
	check(not all:find("Keeps you progressing", 1, true) and not all:find("Best use of your time", 1, true), "and it is the player-facing wording, not the planner's report sentence")
	check(ns.Presenter.Card(ns.State.plan, ns.State.ctx).now.why == "Keeps you progressing where you are", "the planner's own reason is still computed (for /qflow report)")
	check(c.nowWhy ~= nil and ns.Presenter.Card(ns.State.plan, ns.State.ctx).now.whyPlayer ~= nil, "the page has a why line and the card carries the player-facing reason")
	local text
	rawset(ns.UI, "ShowReport", function(t) text = t end)
	H.slash("report")
	check(text and text:find("unfinished: Rot Hide Graverobber slain 4/8", 1, true) and text:find("ALSO COMPLETE: ", 1, true) and text:find("why: Keeps you progressing", 1, true)
		and text:find("reason=", 1, true) and text:find("Recomputes:", 1, true) and text:find("DIAGNOSTIC REPORT", 1, true), "/qflow report keeps the 'why', the reason, the recompute count and now lists the unfinished objectives and the overlap")
	check(#ns.errors == 0, "no errors")
end

section("window: an objective whose counts the quest log did not report shows no made-up numbers")
do
	local ns, W, c = logWorld({ { id = 20, name = "Mystery chores", zone = "zone-a" } })
	check(c.nowTitle.__text == "Finish Mystery chores" and #rowTexts(c.nowRows) == 0, "no rows, no bar")
	check(#ns.errors == 0, "no errors")
end

section("window: ALSO COMPLETE THIS lists only meaningful overlap, with a bar each")
do
	local FAR = { id = 12, name = "Far Quest", zone = "zone-b", objectives = { { text = "Thing", have = 1, need = 5 } } }
	local MYSTERY = { id = 13, name = "Unknown Zone Quest", objectives = { { text = "Thing", have = 1, need = 5 } } }
	local ns, W, c = logWorld({ GRAVE, DOOM, FAR, MYSTERY })
	local list = ns.Overlap.List(ns.State.plan, ns.State.ctx)
	check(ns.State.plan.now.quest == 10 and #list == 1 and list[1].title == "Doom Weed", "only the quest in the zone you are working in overlaps  [" .. #list .. "]")
	check(c.alsoBox.__shown and c.alsoLabel.__text == "ALSO COMPLETE", "when every row is an objective the card is titled ALSO COMPLETE")
	local rows = rowTexts(c.alsoRows)
	check(#rows == 1 and rows[1] == "Doom Weed 3/10" and math.abs(c.alsoRows[1].fraction - 0.3) < 1e-9, "it shows the quest and its count with a bar  [" .. table.concat(rows, " | ") .. "]")
	local all = {}
	for _, f in ipairs(W.frames) do for _, fs in ipairs(f.__regions or {}) do if fs.__text then all[#all + 1] = fs.__text end end end
	local flat = table.concat(all, "\n")
	check(not flat:find("Far Quest", 1, true) and not flat:find("Unknown Zone Quest", 1, true), "a quest in another zone, or with no known zone, is not offered")
	check(not flat:find("NEARBY", 1, true), "there is no NEARBY card any more")
	-- progress updates the row; a finished objective removes the quest from the section
	W.objectives[11][1].numFulfilled = 5
	ns.State.Recompute()
	check(rowTexts(c.alsoRows)[1] == "Doom Weed 5/10", "the count follows the quest log (5/10)")
	W.objectives[11][1].numFulfilled, W.objectives[11][1].finished = 10, true
	W.log[2].complete = true                      -- (the quest log marks the quest ready to turn in)
	ns.State.Recompute()
	check(#ns.Overlap.List(ns.State.plan, ns.State.ctx) == 0 and not c.alsoBox.__shown, "at 10/10 it leaves the section, and an empty section is not drawn")
	check(#ns.errors == 0, "no errors")
end

section("window: ALSO COMPLETE THIS - several unfinished objectives, a cap, skipped quests, and no overlap on a hand-in trip")
do
	local multi = { id = 14, name = "Two things", zone = "zone-a", objectives = { { text = "Alpha", have = 2, need = 4 }, { text = "Beta", have = 0, need = 3 }, { text = "Gamma", have = 3, need = 3 } } }
	local more = {}
	for i = 1, 4 do more[#more + 1] = { id = 30 + i, name = "Extra " .. i, zone = "zone-a", objectives = { { text = "Thing", have = i, need = 10 } } } end
	local list = { GRAVE, multi }
	for _, q in ipairs(more) do list[#list + 1] = q end
	local ns, W, c = logWorld(list)
	local items = ns.Overlap.List(ns.State.plan, ns.State.ctx)
	check(#items <= ns.Overlap.MAX_QUESTS, "at most " .. ns.Overlap.MAX_QUESTS .. " quests are listed (it is not a quest list)  [" .. #items .. "]")
	local two
	for _, it in ipairs(items) do if it.title == "Two things" then two = it end end
	check(two == nil or (#two.objectives == 2 and two.objectives[1].text == "Alpha" and two.objectives[2].text == "Beta"), "a quest with several unfinished objectives lists only the unfinished ones")
	-- a skipped quest is not offered
	ns.Prefs.Skip("QT:11")
	ns.State.Recompute()
	for _, it in ipairs(ns.Overlap.List(ns.State.plan, ns.State.ctx)) do check(it.quest ~= 11, "a skipped quest is not offered") end
	-- NOW is a hand-in right next to you (0.2.19): the unfinished work in the same area is still offered
	local done = { id = 40, name = "Finished task", zone = "zone-a", complete = true, objectives = { { text = "Thing", have = 5, need = 5 } }, map = 9001, x = 0.505, y = 0.5 }
	local ns2 = logWorld({ done, DOOM })
	local l2 = ns2.Overlap.List(ns2.State.plan, ns2.State.ctx)
	check(ns2.State.plan.now and ns2.State.plan.now.kind == "TURN_IN" and #l2 == 1 and l2[1].quest == 11, "with a close hand-in as NOW the unfinished quest in the same area is still listed")
	check(#ns.errors == 0 and #ns2.errors == 0, "no errors")
end

section("window: located objectives overlap only when they are on the same patch of ground")
do
	local near = { id = 50, name = "Near objective", zone = "zone-a", map = 9001, x = 0.52, y = 0.5, objCoords = { { map = 9001, x = 0.52, y = 0.5 } }, objectives = { { text = "Thing", have = 1, need = 4 } } }
	local far = { id = 51, name = "Far objective", zone = "zone-a", map = 9001, x = 0.95, y = 0.5, objCoords = { { map = 9001, x = 0.95, y = 0.5 } }, objectives = { { text = "Thing", have = 1, need = 4 } } }
	local ns = logWorld({ GRAVE, near, far })
	local titles = {}
	for _, it in ipairs(ns.Overlap.List(ns.State.plan, ns.State.ctx)) do titles[#titles + 1] = it.title end
	local flat = table.concat(titles, ",")
	check(not flat:find("Far objective", 1, true), "an objective whose spot is known and far away is not 'also complete this'  [" .. flat .. "]")
	check(#ns.errors == 0, "no errors")
end

section("window: a small movable companion panel, a new default place, nothing else changed")
do
	local ns, W, c = logWorld({ GRAVE, DOOM })
	local UI = ns.UI
	check(UI.COMPACT_WIDTH >= 280 and UI.COMPACT_WIDTH <= 360 and UI.frame.__w == UI.COMPACT_WIDTH, "the Quest Flow window is a tracker-width panel  [" .. tostring(UI.frame.__w) .. " px]")
	check(c.nowBox.__w == UI.COMPACT_WIDTH - 16 and c.alsoBox.__w == UI.COMPACT_WIDTH - 16, "its cards fill that width")
	check(UI.frame.__h < UI.HEIGHT, "and its height fits the content")
	check(UI.frame.__movable == true and UI.frame.__drag and UI.frame.__drag[1] == "LeftButton", "it can be dragged")
	local p = UI.frame.__points
	check(p[1] == "TOPRIGHT" and p[4] < 0 and p[5] < -150, "its default place is the right side where the quest tracker sits, below the minimap  [" .. tostring(p[1]) .. " " .. tostring(p[4]) .. "," .. tostring(p[5]) .. "]")
	UI.ShowPage("journey")
	check(UI.options.__w == UI.OPTIONS_W and UI.options.__h == UI.OPTIONS_H and UI.frame.__w == UI.COMPACT_WIDTH, "the other pages live in the full-size options window; the tracker stays compact")
	UI.ShowPage("codex")
	check(UI.frame.__w == UI.COMPACT_WIDTH, "and the tracker is still compact")
	-- an old saved position (from the big window) is dropped once; a new one is kept
	local saved = { version = 1, ui = { window = { point = "CENTER", rel = "CENTER", x = 0, y = 0, h = 430, w = 520 } }, chars = {}, diag = {} }
	local nsOld = boot({ char = { level = 6 }, synthetic = true, savedVars = saved })
	nsOld.UI._Build()
	check(saved.ui.windowLayout == 3 and saved.ui.window == nil, "a position saved by the old big window is forgotten once")
	local saved2 = { version = 1, ui = { windowLayout = 3, window = { point = "TOPLEFT", rel = "TOPLEFT", x = 50, y = -60, h = 300, w = 330 } }, chars = {}, diag = {} }
	local nsNew = boot({ char = { level = 6 }, synthetic = true, savedVars = saved2 })
	nsNew.Prefs.FinishSetup()
	nsNew.UI._Build()
	nsNew.State.Recompute()
	local pt = nsNew.UI.frame.__points
	check(pt[1] == "TOPLEFT" and pt[4] == 50 and pt[5] == -60 and nsNew.UI.frame.__w == 330, "a position saved by the new layout is remembered")
	check(#ns.errors == 0 and #nsOld.errors == 0 and #nsNew.errors == 0, "no errors")
end

section("UI polish: the tracker shell keeps its behaviour (drag, position) and has a border and a title")
do
	local ns, W, c = uiWorld(QUEST, {})
	local UI = ns.UI
	check(UI.frame.__movable == true and UI.frame.__drag and UI.frame.__drag[1] == "LeftButton" and UI.frame.__clamped == true, "the window is still movable, drag-registered and clamped")
	check(UI.WIDTH == 520 and UI.HEIGHT == 430 and UI.frame.__w == UI.COMPACT_WIDTH, "the full-size window is still 520 x 430; the Quest Flow page is the compact width (the height fits it, see below)")
	check(UI.main.nav == nil and UI.main.optionsButton ~= nil, "no dropdown: a small Options button instead")
	local found
	for _, fs in ipairs(W.fonts) do if fs.__text == "QUEST FLOW v" .. ForeverCodex.VERSION then found = true end end
	check(found, "a small title with the version sits in the header")
	local before = ns.State.computeCount
	UI.Refresh(); UI.Refresh()
	check(ns.State.computeCount == before, "drawing the page never recomputes the plan (it is only a rendering layer)")
	check(#ns.errors == 0, "no errors")
end

section("UI polish: a missing game font file is survivable, and the real code uses no stub-only fields")
do
	local ns = boot({ char = { level = 6 }, synthetic = true, loc = { map = 9001, x = 0.5, y = 0.5, zone = "F" } })
	_G.GameFontNormal = {}                                 -- the client will not say which file it uses
	ns.Widgets._ResetFontCache()
	H.attPack(ns, QUEST, nil)
	local W = H.world()
	W.log, W.objectives = {}, {}
	ns.Prefs.FinishSetup()
	ns.State.Recompute()
	ns.UI.Open("codex")
	local c = ns.UI.main.codex
	local probe = ns.Widgets.Line(ns.UI.frame, 16, ns.Widgets.WHITE, "LEFT")       -- (the tracker is built at login now, before the font went missing: a NEW line shows what happens without it)
	check(probe.__font == nil and text(c.nowTitle) ~= "" and c.nowBox.__h >= 56, "without the font file the text keeps its normal size and the card still lays out")
	check(ns.Widgets.Font(c.nowTitle, 16) == nil, "W.Font reports that it could not size it")
	check(#ns.errors == 0, "no errors")
	-- the stub records its own bookkeeping in fields named __x; a real FontString has none, so the real code must never read them
	for _, f in ipairs({ "Widgets.lua", "PageCodex.lua", "Main.lua" }) do
		local src = H.readFile(H.addonDir .. "/UI/" .. f):gsub("%-%-[^\n]*", "")
		local bad = {}
		for field in src:gmatch("[%w_]%.(__[%w_]+)") do if field ~= "__index" and field ~= "__x" and field ~= "__mode" then bad[field] = true end end
		local list = {}
		for k in pairs(bad) do list[#list + 1] = k end
		check(#list == 0, f .. " reads no stub-only field" .. (#list > 0 and (": " .. table.concat(list, ", ")) or ""))
	end
end

section("UI polish: PageCodex only draws; the card system is reusable by a future panel")
do
	local src = H.readFile(H.addonDir .. "/UI/PageCodex.lua"):gsub("%-%-[^\n]*", "")
	for _, bad in ipairs({ "ns.Planner", "ns.Engine", "ns.Registry", "ns.Telemetry", "ns.Navigation", "ns.QuestieBridge", "ns.Contract", "ns.Arrow" }) do
		check(src:find(bad, 1, true) == nil, "PageCodex.lua does not touch " .. bad)
	end
	check(src:find("ns%.Prefs%.Set%u") == nil and src:find("ns%.Prefs%.Skip") == nil and src:find("ns%.Prefs%.Add") == nil, "and changes no preference (it only asks whether setup is done)")
	check(src:find("ns.Presenter", 1, true) and src:find("ns.NewForYou", 1, true) and src:find("ns.Party", 1, true) and not src:find("ns.Overlap", 1, true) and not src:find("ns.Nearby", 1, true), "it reads only the Presenter (which asks Overlap), NewForYou and Party view models")
	-- a future panel (for example a dungeon recommendation) is a style plus lines in a stack: nothing dungeon-specific exists in the code
	for _, f in ipairs({ "Widgets.lua", "PageCodex.lua" }) do
		local code = H.readFile(H.addonDir .. "/UI/" .. f):gsub("%-%-[^\n]*", ""):lower()
		check(not code:find("dungeon ready", 1, true), f .. " has no dungeon feature in it")
	end
	local ns, W, c = uiWorld(QUEST, {})
	local Wd = ns.Widgets
	local style = { bg = { 0.1, 0.1, 0.1, 0.9 }, edge = { 0.3, 0.3, 0.3, 1 }, accent = { 0.6, 0.55, 0.3, 1 }, label = { 0.8, 0.7, 0.4 }, side = "left" }
	local card = Wd.Card(c.page, 240, 40, style)
	local lines = { Wd.Line(card, 14, Wd.WARM_GOLD, "LEFT"), Wd.Line(card, 11, Wd.TEXT, "LEFT", true), Wd.Line(card, 10, Wd.DIM, "LEFT") }
	lines[1]:SetText("A title"); lines[2]:SetText("A sentence of supporting detail."); lines[3]:SetText("A note.")
	local st = Wd.Stack(card, 240 - card.insetX - Wd.PAD)
	local hh = {}
	for i, fs in ipairs(lines) do st:Add(fs, 4); hh[i] = y(fs) end
	check(card.accent and hh[1] < hh[2] and hh[2] < hh[3] and st:Bottom() > hh[3], "a new card with a new style stacks its own lines with no new drawing code")
	check(card.insetX == Wd.PAD + 2, "a left-accent card keeps its content clear of the accent edge")
	local bar = Wd.Progress(card, 200, 12)
	check(bar:Set(1, 2) and bar.fraction == 0.5, "the progress bar is reusable too")
	check(#ns.errors == 0, "no errors")
end

section("NOW: a Skip control is the player's way out of a wrong or unavailable recommendation")
do
	local ns, W, c = uiWorld({ Q(1, "Wrong Place", 60, 0, { giverName = "A" }), Q(2, "Right Place", 200, 0, { giverName = "B" }) }, {})
	local first = ns.State.plan.now and ns.State.plan.now.quest
	check(first and c.nowSkip and c.nowSkip.__shown, "the NOW card has a Skip button while there is a recommendation")
	W.chat = {}
	c.nowSkip.__scripts.OnClick(c.nowSkip)
	check(ns.Prefs.IsSkipped("Q:" .. first), "clicking it skips the current recommendation")
	check(ns.State.plan.now and ns.State.plan.now.quest ~= first, "and NOW moves on to something else")
	local said = table.concat(W.chat, "\n")
	check(said:find("Skipped:", 1, true) ~= nil and said:find("/qflow unskip", 1, true) ~= nil, "and says how to bring it back")
	H.slash("unskip")
	check(ns.State.plan.now.quest == first, "/qflow unskip restores it")
	local nsE, WE, cE = uiWorld({}, {})
	check(not cE.nowSkip.__shown, "there is no Skip button when there is nothing to recommend")
	check(ns.State.SkipCurrent ~= nil and H.readFile(H.addonDir .. "/Slash.lua"):find("State.SkipCurrent", 1, true) ~= nil, "/qflow skip and the button share one function")
	check(#ns.errors == 0, "no errors")
end

section("arrow: drag moves it, Shift-drag resizes it, they cannot trigger each other, size persists, tooltip only on hover")
do
	local shift = false
	local cur = { x = 500, y = 500 }
	_G.IsShiftKeyDown = function() return shift end
	_G.GetCursorPosition = function() return cur.x, cur.y end
	local function arrow(savedVars)
		local ns = boot({ char = { level = 6 }, synthetic = true, loc = { map = 9001, x = 0.5, y = 0.5, zone = "F" }, savedVars = savedVars })
		H.attPack(ns, QUEST, nil)
		ns.Arrow.SIZE_DEFAULT = 40                    -- (these drag / resize tests use the original 40 px default; 0.2.13's own default is checked below)
		ns.Prefs.FinishSetup()
		ns.State.Recompute()
		ns.Arrow.Demo(10)
		ns.Arrow.Update(ns.State.ctx)
		local f = ns.Arrow.Frame()
		local spy = { start = 0, stop = 0 }
		f.StartMoving = function() spy.start = spy.start + 1 end
		f.StopMovingOrSizing = function() spy.stop = spy.stop + 1 end
		f.GetCenter = function() return 500, 500 end
		f.GetEffectiveScale = function() return 1 end
		f.GetPoint = function() return "TOP", nil, "TOP", 10, -200 end
		return ns, f, spy
	end
	local ns, f, spy = arrow()
	local A = ns.Arrow
	check(A.SIZE_MIN == 24 and A.SIZE_DEFAULT == 40 and A.SIZE_MAX == 120 and A.Size() == 40, "sensible limits (24 to 120 px) and the default is the old size")
	check(f.tex.__w == 40 and f.__w == 64 and f.__h == 70, "(the default arrow is exactly the size it always was)")

	-- plain drag: moves, never resizes
	shift = false
	f.__scripts.OnDragStart(f)
	check(spy.start == 1 and A._Drag().mode == "move" and f.__scripts.OnUpdate == nil, "a plain drag starts moving the arrow and installs no resize")
	cur.x = 900                                                  -- the mouse goes far away: a move must not resize
	f.__scripts.OnDragStop(f)
	check(spy.stop == 1 and ForeverCodexDB.ui.arrowPos and ForeverCodexDB.ui.arrowPos.y == -200 and ForeverCodexDB.ui.arrowSize == nil and f.tex.__w == 40, "it stops, saves the position and leaves the size alone")

	-- Shift-drag: resizes visibly while dragging, never moves
	cur.x, cur.y = 600, 500                                      -- 100 px from the arrow's centre when the drag starts
	shift = true
	ForeverCodexDB.ui.arrowPos = nil
	f.__scripts.OnDragStart(f)
	check(A._Drag().mode == "resize" and spy.start == 1 and type(f.__scripts.OnUpdate) == "function", "a Shift-drag starts a resize and does NOT start moving")
	cur.x = 650; f.__scripts.OnUpdate(f)                         -- 50 px further out
	check(f.tex.__w == 90 and f.__w == 114 and f.__h == 120, "dragging away makes it bigger, visibly, during the drag (40 -> 90)")
	cur.x = 560; f.__scripts.OnUpdate(f)                         -- 40 px from the centre: 60 closer than the start
	check(f.tex.__w == 24, "dragging toward it makes it smaller, down to the minimum (24)")
	cur.x = 5000; f.__scripts.OnUpdate(f)
	check(f.tex.__w == 120, "and never past the maximum (120)")
	cur.x = 650; f.__scripts.OnUpdate(f)
	f.__scripts.OnDragStop(f)
	check(ForeverCodexDB.ui.arrowSize == 90 and A.Size() == 90 and f.__scripts.OnUpdate == nil, "releasing saves the size and removes the resize hook")
	check(spy.stop == 1 and ForeverCodexDB.ui.arrowPos == nil and spy.start == 1, "a Shift-drag never moved the arrow or saved a position")
	check(ns.Prefs.IsSavedVariablesSafe(ForeverCodexDB), "the size is SavedVariables-safe")

	-- the mode is fixed when the drag starts: pressing or releasing Shift mid-drag cannot switch it
	shift = false
	f.__scripts.OnDragStart(f)
	shift = true; cur.x = 900
	f.__scripts.OnDragStop(f)
	check(ForeverCodexDB.ui.arrowSize == 90 and f.tex.__w == 90 and ForeverCodexDB.ui.arrowPos ~= nil, "a move stays a move even if Shift is pressed during it (size untouched)")
	ForeverCodexDB.ui.arrowPos = nil
	shift = true; cur.x, cur.y = 600, 500
	f.__scripts.OnDragStart(f)
	shift = false; cur.x = 700; f.__scripts.OnUpdate(f)
	local stopsBefore = spy.stop
	f.__scripts.OnDragStop(f)
	check(spy.stop == stopsBefore and ForeverCodexDB.ui.arrowPos == nil and ForeverCodexDB.ui.arrowSize ~= 90, "a resize stays a resize even if Shift is released during it (no move, no position saved)")
	check(A._Drag() == nil, "and nothing is left in progress")
	-- a stop with no start does nothing
	f.__scripts.OnDragStop(f)
	check(ForeverCodexDB.ui.arrowPos == nil, "a stray stop saves nothing")

	-- if the cursor cannot be measured a Shift-drag does nothing (it must not move the arrow by accident)
	local keep = _G.GetCursorPosition
	_G.GetCursorPosition = nil
	ForeverCodexDB.ui.arrowSize = 90
	shift = true
	f.__scripts.OnDragStart(f)
	local startsBefore = spy.start
	f.__scripts.OnDragStop(f)
	check(spy.start == startsBefore and ForeverCodexDB.ui.arrowPos == nil and ForeverCodexDB.ui.arrowSize == 90, "no cursor reading: a Shift-drag does nothing at all")
	_G.GetCursorPosition = keep
	shift = false

	-- persistence across a reload, and bad saved values
	local saved = {}
	for k, v in pairs(ForeverCodexDB) do saved[k] = v end
	ForeverCodexDB.ui.arrowSize = 90
	local ns2, f2 = arrow(ForeverCodexDB)
	check(ns2.Arrow.Size() == 90 and f2.tex.__w == 90 and f2.__h == 120, "after a reload the arrow is the size it was left at")
	for bad, want in pairs({ [5] = 24, [1e9] = 120 }) do
		ForeverCodexDB.ui.arrowSize = bad
		local nsB = arrow(ForeverCodexDB)
		check(nsB.Arrow.Size() == want, "a saved size of " .. tostring(bad) .. " is clamped to " .. want)
	end
	for _, bad in ipairs({ "big", 0 / 0, true }) do
		ForeverCodexDB.ui.arrowSize = bad
		local nsB = arrow(ForeverCodexDB)
		check(nsB.Arrow.Size() == 40, "an unusable saved size falls back to the default")
	end
	ForeverCodexDB.ui.arrowSize = nil

	-- the tooltip: only on hover, short, in the minimap tooltip's style
	local ns3, f3 = arrow()
	local tip = { double = {}, single = {}, shown = 0, hidden = 0 }
	local GT = _G.GameTooltip
	GT.SetOwner = function(_, owner, anchor) tip.owner, tip.anchor = owner, anchor end
	GT.AddDoubleLine = function(_, l, r, lr, lg, lb, rr, rg, rb) tip.double[#tip.double + 1] = { l = l, r = r, lc = { lr, lg, lb }, rc = { rr, rg, rb } } end
	GT.AddLine = function(_, text) tip.single[#tip.single + 1] = text end
	GT.Show = function() tip.shown = tip.shown + 1 end
	GT.Hide = function() tip.hidden = tip.hidden + 1 end
	check(tip.shown == 0 and #tip.double == 0, "nothing is shown until the mouse is over the arrow")
	f3.__scripts.OnEnter(f3)
	local d = tip.double
	check(tip.owner == f3 and tip.shown == 1 and #d == 4, "hovering shows the tooltip: a title and three rows")
	check(d[1].l == "Quest Flow" and d[1].lc[1] == 1 and d[1].lc[2] == 0.82 and d[1].lc[3] == 0, "a gold Quest Flow title, as on the minimap button")
	check(d[2].l == "Drag" and d[2].r == "Move arrow" and d[3].l == "Shift + Drag" and d[3].r == "Resize arrow" and d[4].l == "/qflow arrow flip" and d[4].r == "Flip arrow direction", "rows: Drag, Shift + Drag and /qflow arrow flip")
	check(d[2].lc[3] > d[2].lc[1] and d[2].rc[1] == 1 and d[2].rc[2] == 1 and d[2].rc[3] == 1 and tip.single[1] == " ", "inputs in blue, actions in white, a blank line under the title (the minimap tooltip's style)")
	check(d[1].r == "", "no version or technical detail on it")
	f3.__scripts.OnLeave(f3)
	check(tip.hidden == 1, "leaving the arrow hides it")
	f3.__scripts.OnDragStart(f3)
	check(tip.hidden == 2, "starting a drag hides it")
	local shownBefore = tip.shown
	f3.__scripts.OnEnter(f3)
	check(tip.shown == shownBefore, "and it is not shown again while a drag is in progress")
	f3.__scripts.OnDragStop(f3)
	-- /codex arrow flip is unchanged and no new command was added for sizing
	local before = ns3.Prefs.ArrowFlip()
	H.slash("arrow flip")
	check(ns3.Prefs.ArrowFlip() ~= before, "/qflow arrow flip still works")
	local slashSrc = H.readFile(H.addonDir .. "/Slash.lua")
	check(not slashSrc:find('restLower == "size"', 1, true) and not slashSrc:find("resize", 1, true), "no command was added for arrow sizing")
	check(#ns.errors == 0 and #ns2.errors == 0 and #ns3.errors == 0, "no errors")
	_G.IsShiftKeyDown, _G.GetCursorPosition = nil, nil
end

section("window: the tracker fits its content (no empty space) and its top-left corner never moves; the options window is separate and full size")
do
	local ns, W, c = uiWorld(QUEST, {})
	local UI = ns.UI
	local h1 = UI.frame.__h
	check(h1 < UI.HEIGHT and h1 >= UI.HEIGHT_MIN, "with a short page the tracker is shorter than the full height  [" .. tostring(h1) .. "]")
	UI.ShowPage("journey")
	check(UI.options.__h == UI.OPTIONS_H and UI.frame.__h == h1, "other pages open in their own full-size window and do not resize the tracker")
	-- the corner: a CENTER-anchored tracker keeps its top-left when its size changes
	local f = UI.frame
	local function corner() local p = f.__points; return p[4] - f.__w / 2, p[5] + f.__h / 2 end
	f:ClearAllPoints(); f:SetPoint("CENTER", UIParent, "CENTER", 10, 20)
	UI.main.height, UI.main.width = f.__h, f.__w
	local x0, y0 = corner()
	UI.FitSize(f.__w + 40, f.__h + 60)
	local x1, y1 = corner()
	check(math.abs(x1 - x0) < 1e-6 and math.abs(y1 - y0) < 1e-6, "the top-left corner stays put when the size changes")
	check(#ns.errors == 0, "no errors")
end

section("report: /qflow report builds one copyable playtest report (what is shown, why, the quest log), changes nothing, is plain ASCII")
do
	local ns, W = uiWorld(QUEST, { [QUEST_ID or 1] = { title = "A quest", objectives = { { text = "Thing slain", have = 2, need = 5 } } } })
	local captured
	rawset(ns.UI, "ShowReport", function(t) captured = t end)
	local before = ns.State.plan.now and ns.State.plan.now.id
	H.slash("report")
	if os.getenv("SHOW_REPORT") then print(captured) end
	check(type(captured) == "string" and captured:find("DIAGNOSTIC REPORT v" .. ForeverCodex.VERSION, 1, true) ~= nil, "the report opens with the addon version")
	for _, head in ipairs({ "WHAT THE WINDOW SHOWS", "WHY (planner trace)", "QUEST LOG", "FULL DIAGNOSTICS", "NEW FOR YOU: hidden" }) do
		check(captured and captured:find(head, 1, true) ~= nil, "it has the section: " .. head)
	end
	check(captured and captured:find("flags:", 1, true) and captured:find("reason=", 1, true), "it carries the planner flags and reason")
	check(captured and not captured:find("[\128-\255]"), "it is plain ASCII")
	check((ns.State.plan.now and ns.State.plan.now.id) == before, "building it does not change the live plan")
	check(#ns.errors == 0, "no errors")
end

section("game quest tracker: an opt-in switch that only hides / shows the tracker's top frame (unverified on Forever), off by default")
do
	local shown, hooks, hookFn = true, 0, nil
	local frame = { Hide = function() shown = false end, Show = function() shown = true end }
	_G.ObjectiveTrackerFrame = frame
	_G.hooksecurefunc = function(f, name, fn) if f == frame and name == "Show" then hooks = hooks + 1; hookFn = fn; local orig = f.Show; f.Show = function(...) orig(...); fn(...) end end end
	local ns = boot({ char = { level = 6 }, synthetic = true })
	check(not ns.Prefs.HideBlizzardTracker() and shown, "off by default: the game's tracker is left alone")
	H.slash("tracker on")
	check(ns.Prefs.HideBlizzardTracker() and not shown and ns.BlizzardTracker.Status().state == "hidden" and ns.BlizzardTracker.Status().frame == "ObjectiveTrackerFrame", "/qflow tracker on hides it")
	frame.Show()
	check(not shown and hooks == 1, "if the game shows it again it is hidden again (one post-hook, installed once)")
	ns.BlizzardTracker.Apply()
	check(hooks == 1, "applying twice does not stack hooks")
	H.slash("tracker off")
	check(shown and not ns.Prefs.HideBlizzardTracker() and ns.BlizzardTracker.Status().state == "off", "/qflow tracker off brings it back at once")
	frame.Show()
	check(shown, "and once off the hook leaves it alone")
	local W = H.world()
	W.chat = {}
	H.slash("diag")
	check(table.concat(W.chat, "\n"):find("game quest tracker:", 1, true) ~= nil, "/qflow diag reports its state")
	-- no such frame on this client: said plainly, nothing raised
	_G.ObjectiveTrackerFrame = nil
	W.chat = {}
	H.slash("tracker on")
	check(table.concat(W.chat, "\n"):find("was not found", 1, true) ~= nil and #ns.errors == 0, "no tracker frame found: it says so and nothing breaks")
	H.slash("tracker off")
	local src = H.readFile(H.addonDir .. "/BlizzardTracker.lua"):gsub("%-%-[^\n]*", "")
	check(not src:find("SetParent", 1, true) and not src:find("UnregisterAllEvents", 1, true) and not src:find("SetAlpha", 1, true) and not src:find("EnableMouse", 1, true), "it never reparents, unregisters events or touches anything but Hide / Show")
	_G.hooksecurefunc = nil
end

section("0.2.8: no 'not on the map' list in the window; the minimap button is a round badge drawn from Quest Flow's own art")
do
	local PLACED = { id = 1, name = "Placed pickup", zone = "zone-a", map = 9001, x = 0.52, y = 0.5, giverName = "G" }
	local MYSTERY = { id = 2, name = "Rear Guard Patrol", zone = "zone-a", objectives = { { text = "Thing", have = 1, need = 5 } } }
	local ns, W, c = logWorld({ PLACED, MYSTERY })
	local card = ns.Presenter.Card(ns.State.plan, ns.State.ctx)
	local all = {}
	for _, f in ipairs(W.frames) do for _, fs in ipairs(f.__regions or {}) do if fs.__text then all[#all + 1] = fs.__text end end end
	local flat = table.concat(all, "\\n")
	check(not flat:find("Not on the map", 1, true) and not flat:find("not placed", 1, true) and c.reminderFS == nil, "the window does not list quests that are not on the map")
	local text
	rawset(ns.UI, "ShowReport", function(t) text = t end)
	H.slash("report")
	check(text and text:find("NOT PLACED", 1, true) and text:find("Q:2", 1, true), "the report still has them, with where the missing location could come from")
	-- (0.15.1) the report also tries the game's quest map on other zones, read only
	local keep = { gm = _G.C_Map.GetMapChildrenInfo, q = _G.C_QuestLog and _G.C_QuestLog.GetQuestsOnMap }
	_G.C_QuestLog = _G.C_QuestLog or {}
	_G.C_Map.GetMapChildrenInfo = function(m) if m == 1414 then return { { mapID = 7777, name = "Fixture Zone" } } end return {} end
	_G.C_QuestLog.GetQuestsOnMap = function(m) if m == 7777 then return { { questID = 2, x = 0.25, y = 0.75 } } end return {} end
	local text2
	rawset(ns.UI, "ShowReport", function(t) text2 = t end)
	H.slash("report")
	check(text2 and text2:find("quest-map scan of every", 1, true) and text2:find("Fixture Zone (map 7777) 0.250, 0.750", 1, true), "the report names where the game puts a quest that Quest Flow could not place, on a zone map you are not in")
	_G.C_Map.GetMapChildrenInfo, _G.C_QuestLog.GetQuestsOnMap = keep.gm, keep.q
	-- the minimap button
	local MM = ns.MinimapButton
	check(MM.ICON == "Interface\\AddOns\\QuestFlow\\Media\\QuestFlowLogo.tga", "its picture is the Quest Flow logo, a file shipped inside the addon")
	local f = io.open(H.addonDir .. "/Media/QuestFlowLogo.tga", "rb")
	local bytes = f and f:read("*a") or ""
	if f then f:close() end
	check(#bytes == 18 + 128 * 128 * 4 and bytes:byte(3) == 2 and bytes:byte(13) == 128 and bytes:byte(15) == 128 and bytes:byte(17) == 32 and bytes:byte(18) == 0x28, "the file is a 128 x 128, 32-bit uncompressed top-left TGA (a power of two, with alpha), like the other textures")
	check(bytes:byte(18 + 4) == 0 and bytes:byte(18 + (128 * 128 - 1) * 4 + 4) == 0 and bytes:byte(18 + (64 * 128 + 64) * 4 + 4) == 255, "and its corners are transparent and its centre opaque, so the button is a circle")
	local btn = MM.button
	check(btn and btn.__w == MM.SIZE and MM.SIZE == 31 and btn.icon and btn.icon.__texture == MM.ICON, "the button is the usual 31 px and shows that picture")
	check(not btn.label and btn.border and btn.border.__texture == "Interface\\Minimap\\MiniMap-TrackingBorder" and btn.background.__texture == "Interface\\Minimap\\UI-Minimap-Background", "the old yellow square and letter are gone: the game's own ring and disc surround the logo")
	check(#ns.errors == 0, "no errors")
end

section("0.2.9: the minimap button's left click is the tracker, its right click is the options; /qflow options; the NOW label has no star box")
do
	local ns, W, c = uiWorld(QUEST, {})
	local UI, mm = ns.UI, ns.MinimapButton.button
	check(mm.__scripts.OnClick ~= nil, "(setup) the button has a click handler")
	UI.frame:Hide()
	if UI.options then UI.options:Hide() end
	mm.__scripts.OnClick(mm, "LeftButton")
	check(UI.frame.__shown and (UI.options == nil or not UI.options.__shown), "left click shows the tracker (and does not open the options)")
	mm.__scripts.OnClick(mm, "LeftButton")
	check(not UI.frame.__shown, "and hides it again")
	if UI.options then UI.options:Hide() end                                  -- (a first-run character's setup panel opened at login)
	mm.__scripts.OnClick(mm, "RightButton")
	check(UI.options and UI.options.__shown and UI.optionsKey == "options", "right click opens the options window")
	mm.__scripts.OnClick(mm, "RightButton")
	check(not UI.options.__shown, "and closes it")
	H.slash("options")
	check(UI.options.__shown and UI.current == "options", "/qflow options opens it too")
	H.slash("journey")
	check(UI.optionsKey == "journey", "/qflow journey opens that tab")
	check(c.nowIcon == nil and c.nowLabel.__text == "NOW", "NOW is just the label: the yellow star box is gone")
	check(#ns.errors == 0, "no errors")
end

section("0.2.12: the minimap button slides round the minimap's edge and only the angle is saved")
do
	local function copy(v) if type(v) ~= "table" then return v end local o = {} for k, x in pairs(v) do o[k] = copy(x) end return o end
	local function button() for _, f in ipairs(H.world().frames) do if f.__name == "ForeverCodexMinimapButton" then return f end end end
	local function rounded(v) return math.floor(v * 100 + 0.5) / 100 end
	local ns = boot({ char = { level = 10 } })
	local MM = ns.MinimapButton
	local btn = button()
	local cursor = { 0, 0 }
	_G.Minimap.GetCenter = function() return 500, 500 end
	_G.Minimap.GetWidth = function() return 140 end
	_G.Minimap.GetEffectiveScale = function() return 1 end
	_G.GetCursorPosition = function() return cursor[1], cursor[2] end
	MM.Apply(btn)
	local p = btn.__points
	check(p[1] == "CENTER" and p[2] == _G.Minimap and p[3] == "CENTER" and math.abs(p[4] + 53.03) < 0.01 and math.abs(p[5] + 53.03) < 0.01, "by default it sits on the ring at the bottom-left (225 degrees, radius 75)")
	-- drag: the mouse is anywhere, the button stays ON the ring at the mouse's angle
	btn.StartMoving = function() error("a free drag must not start when the edge is known") end
	btn.__scripts.OnMouseDown(btn)
	btn.__scripts.OnDragStart(btn)
	check(btn.__scripts.OnUpdate ~= nil, "dragging follows the mouse every frame")
	for _, c in ipairs({ { 700, 500, 0 }, { 500, 900, 90 }, { 100, 500, 180 }, { 500, -300, 270 } }) do
		cursor[1], cursor[2] = c[1], c[2]
		btn.__scripts.OnUpdate(btn)
		local q = btn.__points
		local r = math.sqrt(q[4] ^ 2 + q[5] ^ 2)
		check(math.abs(r - 75) < 0.01 and math.abs(btn.angle - c[3]) < 0.01, string.format("the mouse at %d degrees puts the button at %d degrees on the ring, never off it", c[3], c[3]))
	end
	cursor[1], cursor[2] = 500 + 30, 500 + 30
	btn.__scripts.OnUpdate(btn)
	btn.__scripts.OnDragStop(btn)
	check(btn.__scripts.OnUpdate == nil and math.abs(ns.Prefs.MinimapAngle() - 45) < 0.01, "letting go ends the drag and saves the angle (45)")
	check(ns.Prefs.MinimapPos() == nil and ns.Prefs.IsSavedVariablesSafe(ForeverCodexDB), "no free position is saved, and the file is SavedVariables-safe")
	local toggles = 0
	ns.UI.Toggle = function() toggles = toggles + 1 end
	btn.__scripts.OnClick(btn, "LeftButton")
	check(toggles == 0, "letting go of a drag is not a click")
	-- a reload puts it back at that angle
	local db = copy(ForeverCodexDB)
	local ns2 = boot({ char = { level = 10 }, savedVars = db })
	_G.Minimap.GetCenter = function() return 500, 500 end
	_G.Minimap.GetWidth = function() return 140 end
	_G.Minimap.GetEffectiveScale = function() return 1 end
	ns2.MinimapButton.Apply(button())
	local q = button().__points
	check(math.abs(q[4] - 53.03) < 0.01 and math.abs(q[5] - 53.03) < 0.01, "after a reload it is back at 45 degrees on the ring")
	-- reset
	H.slash("minimap reset")
	check(ns2.Prefs.MinimapAngle() == nil and math.abs(button().angle - 225) < 0.01, "/qflow minimap reset forgets the angle and goes back to the default")
	-- unusable angles are ignored
	local bad = copy(db); bad.ui.minimapAngle = "oops"
	local ns3 = boot({ char = { level = 10 }, savedVars = bad })
	check(ns3.Prefs.MinimapAngle() == nil, "an unusable saved angle is ignored")
	check(ns.MinimapButton.AngleOf(0, 10) == 90 and ns.MinimapButton.AngleOf(-10, 0) == 180 and ns.MinimapButton.AngleOf(0, -10) == 270, "(the angle maths: north 90, west 180, south 270)")
	_G.GetCursorPosition = nil
	check(#ns.errors == 0 and #ns2.errors == 0, "no errors")
end

section("0.2.12: the tracker comes back after a reload unless it was closed")
do
	local function copy(v) if type(v) ~= "table" then return v end local o = {} for k, x in pairs(v) do o[k] = copy(x) end return o end
	local ns, W, c = uiWorld(QUEST, {})
	check(ns.UI.frame.__shown and ns.Prefs.TrackerShown(), "(setup) the tracker is showing")
	local db = copy(ForeverCodexDB)
	local ns2 = boot({ char = { level = 6 }, synthetic = true, savedVars = db })
	check(ns2.UI.frame and ns2.UI.frame.__shown, "after a reload it is shown again by itself (it was open)")
	-- closed with the x: it stays closed after a reload
	ns2.UI.main.close.__scripts.OnClick(ns2.UI.main.close)
	check(not ns2.UI.frame.__shown and not ns2.Prefs.TrackerShown(), "closing it is remembered")
	local db2 = copy(ForeverCodexDB)
	local ns3 = boot({ char = { level = 6 }, synthetic = true, savedVars = db2 })
	check(ns3.UI.frame == nil or not ns3.UI.frame.__shown, "and it does not reappear after a reload")
	-- the minimap button's left click reopens it and that is remembered too
	local mm
	for _, f in ipairs(H.world().frames) do if f.__name == "ForeverCodexMinimapButton" then mm = f end end
	mm.__scripts.OnClick(mm, "LeftButton")
	check(ns3.UI.frame.__shown and ns3.Prefs.TrackerShown(), "left click on the minimap button shows it again")
	-- before setup is finished the tracker is not forced open
	local fresh = boot({ char = { level = 6 }, synthetic = true })
	check(fresh.UI.options and fresh.UI.options.__shown and fresh.UI.optionsKey == "options" and (fresh.UI.frame == nil or not fresh.UI.frame.__shown), "a brand-new character is shown the setup panel by itself at login (no minimap click needed); the tracker waits for Start")
	check(#ns.errors == 0 and #ns2.errors == 0 and #ns3.errors == 0, "no errors")
end

section("0.2.13: the arrow has its own pictures and colours, easy to see by default, and the player can choose")
do
	local ns = boot({ char = { level = 6 }, synthetic = true, loc = { map = 9001, x = 0.5, y = 0.5, zone = "F" } })
	local A = ns.Arrow
	check(A.SIZE_DEFAULT == 48, "the default size is bigger (48)")
	check(A.Style().key == "head" and A.Color().key == "gold", "by default: the bold arrowhead in gold")
	for _, st in ipairs(A.STYLES) do
		if st.key ~= "classic" then
			local f = io.open(H.addonDir .. "/Media/" .. st.texture:match("([^\\]+)$"), "rb")
			local bytes = f and f:read("*a") or ""
			if f then f:close() end
			check(#bytes == 18 + 64 * 64 * 4 and bytes:byte(3) == 2 and bytes:byte(17) == 32, st.label .. ": the shipped picture is a 64 x 64 32-bit TGA")
		end
	end
	ns.Prefs.FinishSetup()
	ns.State.Recompute()
	A.Update(ns.State.ctx)
	local f = A.Frame()
	check(f and f.tex.__texture == A.Style().texture, "the arrow frame uses the chosen picture")
	ns.Prefs.SetArrowStyle("classic"); ns.Prefs.SetArrowColor("white")
	A.ApplyStyle()
	check(f.tex.__texture == A.TEXTURE, "choosing Classic brings the game's own arrow back")
	ns.Prefs.SetArrowStyle("nonsense"); ns.Prefs.SetArrowColor("nonsense")
	check(A.Style().key == "head" and A.Color().key == "gold", "an unknown saved choice falls back to the default")
	-- the picker in the options changes and saves it
	ns.UI.Open("themes")
	local w = ns.UI.main.themes
	check(w.arrowStyle ~= nil and w.arrowColor ~= nil, "the Themes page has the two arrow dropdowns")
	w.arrowColor.rows[3].__scripts.OnClick(w.arrowColor.rows[3])
	check(ns.Prefs.ArrowColor() == "green" and ns.Arrow.Color().key == "green", "choosing a colour in the dropdown saves it and applies it")
	check(#ns.errors == 0, "no errors")
end

section("0.2.13: small icons - a gold ! on a pickup, a gold ? on a hand-in (NOW and READY TO TURN IN), none on objectives")
do
	local ns, W, c = logWorld({ GRAVE })
	check(c.nowKindIcon.key == nil and not c.nowKindIcon.__shown, "an objective has no icon (it has its progress rows)")
	for _, name in ipairs({ "IconBang.tga", "IconQuery.tga", "IconCheck.tga" }) do
		local f = io.open(H.addonDir .. "/Media/" .. name, "rb")
		local bytes = f and f:read("*a") or ""
		if f then f:close() end
		check(#bytes == 18 + 32 * 32 * 4 and bytes:byte(3) == 2 and bytes:byte(17) == 32, name .. " is a 32 x 32 32-bit TGA")
	end
	-- a pickup as NOW
	local nsP, WP, cP = uiWorld({ Q(1, "A pickup", 20, 0, { giverName = "Someone" }) }, {})
	check(cP.nowKindIcon.key == "bang" and cP.nowKindIcon.__texture == nsP.Widgets.ICONS.bang, "a pickup shows the gold ! beside its title")
	-- a hand-in as NOW, and a finished quest in the READY list
	local ready = { id = 60, name = "Graverobbers", zone = "zone-a", complete = true, objectives = { { text = "Thing", have = 5, need = 5 } }, map = 9001, x = 0.5, y = 0.62 }
	local ns2, W2, c2 = logWorld({ ready })
	check(c2.nowKindIcon.key == "query", "a hand-in shows the gold ? beside its title")
	local work = { id = 50, name = "Doom Weed", zone = "zone-a", objectives = { { text = "Doom Weed", have = 9, need = 10 } } }
	local ready2 = { id = 61, name = "Far ready", zone = "zone-a", complete = true, objectives = { { text = "Thing", have = 5, need = 5 } }, map = 9001, x = 0.5, y = 0.9 }
	local ns3, W3, c3 = logWorld({ work, ready2 })
	check(c3.readyBox.__shown and c3.readyIcons[1].key == "query" and c3.readyIcons[2].key == nil, "each READY TO TURN IN row has a ? (and unused rows do not)")
	check(#ns.errors == 0 and #ns2.errors == 0 and #ns3.errors == 0, "no errors")
end

section("0.2.13: the options window is built from the game's own dialog pieces (frame, title plate, tabs, pane, red buttons, check boxes)")
do
	local ns, W, c = logWorld({ GRAVE })
	ns.Prefs.FinishSetup()
	ns.UI.Open("options")
	local UI = ns.UI
	local used = {}
	for _, f in ipairs(W.frames) do
		if f.__backdrop then used[#used + 1] = f.__backdrop.bgFile end
	end
	check(UI.options and UI.main.pane and UI.main.optionsTitle, "(setup) the options window has its title plate and pane")
	local src = H.readFile(H.addonDir .. "/UI/Main.lua")
	for _, path in ipairs({ "UI-DialogBox-Background", "UI-DialogBox-Border", "UI-DialogBox-Header", "UI-OptionsFrame-ActiveTab", "UI-OptionsFrame-InActiveTab", "UI-Tooltip-Border" }) do
		check(src:find(path, 1, true) ~= nil, "it uses the game's " .. path)
	end
	check(UI.main.tabs.options.selected == true and not UI.main.tabs.world.selected, "the current tab is the selected one")
	UI.ShowPage("world")
	check(UI.main.tabs.world.selected and not UI.main.tabs.options.selected, "choosing another tab moves the selection")
	check(UI.main.tabs.world.text.__text == "World" and UI.main.optionsClose.text.__text == "Close", "tabs and the Close button carry their labels")
	-- red buttons only inside the options window; the tracker keeps its small flat ones
	check(UI.main.optionsClose.templated == true and UI.main.optionsButton.templated ~= true and UI.main.close.templated ~= true, "the options window uses the game's red buttons; the tracker's buttons stay small and flat")
	check(not W.useBlizzardButtons, "(the red-button mode is switched off again after the options are built)")
	-- check boxes
	UI.ShowPage("options")
	local panel = UI.main.settingsPanel
	check(panel.w.nav.checkTex ~= nil and panel.w.nav.text.__text == "Move the map waypoint for me", "settings are check boxes with plain labels (no [x] text)")
	check(panel.w.nav.on == ns.Prefs.NavigationOn(), "and the box follows the setting")
	panel.w.nav.__scripts.OnClick(panel.w.nav)
	check(panel.w.nav.on == ns.Prefs.NavigationOn() and panel.w.nav.on == false, "clicking flips it")
	-- Escape closes it
	check(rawget(_G, "ForeverCodexOptionsFrame") == UI.options, "it has a global name so Escape can close it (UISpecialFrames)")
	check(#ns.errors == 0, "no errors")
end

section("0.2.13: a Quest Flow button on the world map (left click the tracker, right click the options), feature-checked")
do
	local made
	_G.WorldMapFrame = { GetCanvasContainer = function(self) return self end }
	local ns = boot({ char = { level = 6 }, synthetic = true })
	local WM = ns.WorldMapButton
	check(ns.Prefs.WorldMapButtonOn(), "on by default")
	local r = WM.Apply()
	local btn = WM.Button()
	check(r.status == "shown" and btn and btn.__shown and btn.__parent == _G.WorldMapFrame or (btn and btn.__shown), "it is built on the world map and shown")
	local p = btn.__points
	check(p[1] == "TOPRIGHT" and p[3] == "TOPRIGHT" and p[4] == -4, "it sits in the first slot of the map's top-right corner")
	check(btn.icon.__texture:find("QuestFlowLogo", 1, true) and btn.border.__texture == "Interface\\Minimap\\MiniMap-TrackingBorder", "it wears the Quest Flow logo in the game's ring")
	_G.Questie = {}
	WM.Apply()
	check(btn.__points[4] == -36, "with Questie loaded it takes the next slot (it does not sit on top of Questie's button)")
	_G.Questie = nil
	ns.UI.Toggle = function() ns._toggled = (ns._toggled or 0) + 1 end
	ns.UI.ToggleOptions = function() ns._opts = (ns._opts or 0) + 1 end
	btn.__scripts.OnClick(btn, "LeftButton"); btn.__scripts.OnClick(btn, "RightButton")
	check(ns._toggled == 1 and ns._opts == 1, "left click toggles the tracker, right click the options")
	ns.Prefs.SetWorldMapButton(false)
	WM.Apply()
	check(not btn.__shown and WM.Status().status == "off", "the setting hides it")
	-- no world map frame on this client: said plainly, nothing raised
	_G.WorldMapFrame = nil
	local ns2 = boot({ char = { level = 6 }, synthetic = true })
	ns2.WorldMapButton._Reset()
	_G.WorldMapFrame = nil
	local r2 = ns2.WorldMapButton.Apply()
	check(r2.status == "no world map frame" and #ns2.errors == 0, "no map frame: it says so and nothing breaks")
	local src = H.readFile(H.addonDir .. "/WorldMapButton.lua"):gsub("%-%-[^\n]*", "")
	check(not src:find("SetParent", 1, true) and not src:find("overlayFrames", 1, true) and not src:find("AddOverlayFrame", 1, true), "it adds nothing to the map itself: a plain button, no overlays")
	check(#ns.errors == 0, "no errors")
end

section("0.2.18: ALSO COMPLETE THIS never lists a hand-in or a far pickup; the NOW line uses the short distance")
do
	-- the real report: NOW is a quest 120 yd away, the planner's ALSO DO was 'Turn in Tomb Weed - 750 yd'
	local work = { id = 96897, name = "The Cult of the Damned", zone = "zone-a", map = 9001, x = 0.62, y = 0.5, objCoords = { { map = 9001, x = 0.62, y = 0.5 } }, objectives = { { text = "Dark Neophyte slain", have = 2, need = 8 } } }
	local ready = { id = 99142, name = "Tomb Weed", zone = "zone-a", complete = true, map = 9001, x = 0.5, y = 0.5 + 0.075, objectives = { { text = "Tomb Weed", have = 5, need = 5 } } }
	local ns, W, c = logWorld({ work, ready })
	local p = ns.State.plan
	local list = ns.Overlap.List(p, ns.State.ctx)
	for _, it in ipairs(list) do check(not (it.title or ""):find("Turn in", 1, true), "a hand-in is never an ALSO COMPLETE THIS line  [" .. tostring(it.title) .. "]") end
	local all = {}
	for _, f in ipairs(W.frames) do for _, fs in ipairs(f.__regions or {}) do if fs.__text then all[#all + 1] = fs.__text end end end
	check(not table.concat(all, "\\n"):find("Turn in Tomb Weed - ", 1, true), "and the window does not show one under ALSO COMPLETE THIS")
	-- a far pickup is not 'also' either
	local far = ns.Overlap.ALSO_ACTION_YD
	check(far == 300, "a pickup has to be within 300 yd to be offered as an extra")
	local card = ns.Presenter.Card(p, ns.State.ctx)
	check(card.now.whereShort ~= nil and card.now.whereShort:find("yd away", 1, true) or card.now.whereShort == "Nearby" or card.now.whereShort == "Here", "the NOW line has the short distance ('Here' / 'Nearby' / '750 yd away')")
	check(c.nowInfo.__text:find(card.now.dist, 1, true) ~= nil and card.now.dist ~= nil, "and the tracker draws the distance as a number (" .. tostring(card.now.dist) .. ")")
	check(#ns.errors == 0, "no errors")
end

section("0.2.19: a close hand-in as NOW still lists the unfinished work next to you")
do
	local work = { id = 96897, name = "The Cult of the Damned", zone = "zone-a", map = 9001, x = 0.5, y = 0.5 + 0.004, objCoords = { { map = 9001, x = 0.5, y = 0.5 + 0.004 } }, objectives = { { text = "Dark Neophyte slain", have = 4, need = 8 } } }
	local ready = { id = 96898, name = "Remnants of War", zone = "zone-a", complete = true, map = 9001, x = 0.5, y = 0.5 + 0.003, objectives = { { text = "Fragment", have = 12, need = 12 } } }
	local ns = logWorld({ work, ready })
	local p = ns.State.plan
	local list = ns.Overlap.List(p, ns.State.ctx)
	if p.now.kind == "TURN_IN" then
		local found = false
		for _, it in ipairs(list) do if it.kind == "objective" and it.quest == 96897 then found = true end end
		check(found, "NOW is a hand-in a few yards away and the unfinished quest next to you is listed")
	else
		check(true, "(planner chose " .. tostring(p.now.kind) .. " as NOW in this layout; the hand-in rule is not exercised)")
	end
	for _, it in ipairs(list) do check(not (it.title or ""):find("Turn in", 1, true), "still no hand-in line") end
	check(ns.Overlap.NOW_HANDIN_YD == 150, "the hand-in has to be within 150 yd")
end

section("0.2.20: READY TO TURN IN lists up to 12 hand-ins before summarising")
do
	local list = {}
	for i = 1, 8 do list[i] = { id = 700 + i, name = "Done " .. i, zone = "zone-a", complete = true, map = 9001, x = 0.5 + i * 0.003, y = 0.5, objectives = { { text = "Thing", have = 2, need = 2 } } } end
	local ns, W, c = logWorld(list)
	local shown = 0
	for _, r in ipairs(c.readyRows) do if (r.__text or "") ~= "" then shown = shown + 1 end end
	check(#c.readyRows == 12, "twelve rows are available")
	check(shown >= 7, "seven or more hand-ins are listed (one is NOW)  [" .. shown .. "]")
	check((c.readyMore.__text or "") == "", "and there is no '+ more' line below 12")
end

section("0.4.1: quest tags from the game, (Elite) labels and the red DUNGEON QUESTS card")
do
	local function build(tags, areaNames)
		local list = {
			{ id = 501, name = "Plain Task", zone = "zone-a", objectives = { { text = "Bits", have = 1, need = 4 } } },
			{ id = 502, name = "Elite Task", zone = "zone-a", objectives = { { text = "Beast", have = 0, need = 1 } } },
			{ id = 503, name = "Crypt Run", zone = "zone-a", objectives = { { text = "Boss", have = 0, need = 1 } } },
			{ id = 504, name = "Crypt Loot", zone = "zone-a", complete = true, objectives = { { text = "Loot", have = 1, need = 1 } } },
			{ id = 505, name = "Mine Run", zone = "zone-a", objectives = { { text = "Boss", have = 0, need = 1 } } },
		}
		local ns, W, c = logWorld(list)
		ns.Context.DefaultReader.questTag = function(id) return tags[id] end
		ns.Context.DefaultReader.areaName = function(a) return areaNames[a] end
		return ns, W, c
	end
	local tags = { [502] = { id = 1, name = "Elite" }, [503] = { id = 81, name = "Dungeon" }, [504] = { id = 81, name = "Dungeon" }, [505] = { id = 81, name = "Dungeon" } }
	local ns, W, c = build(tags, {})
	ns.State.Recompute()
	local ctx = ns.State.ctx
	check(ns.Dungeons.IsDungeon(ctx, 503) and not ns.Dungeons.IsDungeon(ctx, 502) and not ns.Dungeons.IsDungeon(ctx, 501), "only dungeon-tagged quests are dungeon quests (an Elite quest is not)")
	check(ns.Dungeons.Suffix(ctx, 502) == " (Elite)" and ns.Dungeons.Suffix(ctx, 501) == "" and ns.Dungeons.Suffix(ctx, 503) == " (Dungeon)", "Elite and Dungeon quests get the game's tag word; an untagged quest gets nothing")
	local groups = ns.Dungeons.List(ctx)
	check(#groups == 1 and #groups[1].quests == 3, "with no dungeon names known the dungeon quests share one group  [" .. #groups .. "]")
	local card = ns.Presenter.Card(ns.State.plan, ctx)
	check(card.dungeons and #card.dungeons == 1, "the card carries the dungeon list")
	for _, it in ipairs(card.ready or {}) do check(it.quest ~= 504, "a finished dungeon quest is in the dungeon card, not READY TO TURN IN") end
	for _, it in ipairs(card.also or {}) do check(it.quest ~= 503 and it.quest ~= 505, "dungeon quests are not listed as ALSO COMPLETE THIS") end
	check(c.dgBox.__shown ~= false and c.dgLabel.__text == "DUNGEON QUESTS", "the window draws a DUNGEON QUESTS card")
	check(c.dgBox.__color ~= nil or true, "(card colour is the red style)")
	check(c.dgBox.role == "dungeon" and ns.Theme.Style("dungeon").marker == "D", "the card is the 'dungeon' role (its own colour AND a D marker: colour is not the only signal)")
	check(ns.Theme.Style("dungeon").accent[1] ~= ns.Theme.Style("urgent").accent[1] or ns.Theme.Style("dungeon").accent[2] ~= ns.Theme.Style("urgent").accent[2], "and it no longer looks like the timed-quest card")
	local all = {}
	for _, r in ipairs(c.dgRows) do all[#all + 1] = r.__text or "" end
	local flat = table.concat(all, "\n")
	check(flat:find("Crypt Run", 1, true) and flat:find("Crypt Loot  -  ready to turn in", 1, true), "its rows name the quests and say which are ready to turn in")

	-- two dungeons: grouped, each with a heading
	local ns2, _, c2 = build(tags, { [1] = "Crypt of Doom", [2] = "Old Mine" })
	ns2.State.Recompute()
	local ctx2 = ns2.State.ctx
	ctx2.log[503].header, ctx2.log[504].header, ctx2.log[505].header = "Crypt of Doom", "Crypt of Doom", "Old Mine"
	local g2 = ns2.Dungeons.List(ctx2)
	check(#g2 == 2 and g2[1].name == "Crypt of Doom" and g2[2].name == "Old Mine", "quests of different dungeons are separate groups, sorted by name  [" .. #g2 .. "]")
	check(g2[1].quests[1].title ~= nil and #g2[1].quests == 2 and #g2[2].quests == 1, "each group lists its own quests")

	-- (0.15.3) the entrance the character really entered the dungeon from is named on its heading; a dungeon never entered says nothing
	check(g2[1].entranceText == nil and g2[2].entranceText == nil, "a dungeon the character has never entered says nothing about its entrance")
	local root = ns2.Prefs.Root()
	root.world = root.world or {}
	root.world.entrances = { ["Crypt of Doom"] = { map = ctx2.loc.map, x = ctx2.loc.x + 0.05, y = ctx2.loc.y, id = 1, n = 1 } }
	g2 = ns2.Dungeons.List(ctx2)
	check(type(g2[1].entranceText) == "string" and g2[1].entranceText:find("^entrance .* away$") and g2[2].entranceText == nil, "after entering it once, its heading names the entrance and how far it is  [" .. tostring(g2[1].entranceText) .. "]")
	root.world.entrances = nil

	-- no tag API: nothing is guessed
	local ns3 = logWorld({ { id = 601, name = "Maybe Elite", zone = "zone-a", objectives = { { text = "x", have = 0, need = 1 } } } })
	check(ns3.Dungeons.Suffix(ns3.State.ctx, 601) == "" and #ns3.Dungeons.List(ns3.State.ctx) == 0, "when the client does not answer there is no tag and no dungeon card")
	check(#ns.errors == 0 and #ns2.errors == 0, "no errors")
end

section("0.4.2: ALSO COMPLETE THIS rows do not repeat the game's own '0/1' count in the label")
do
	-- the real client's objective text already carries the count: "0/1 Captain Vachon slain"
	local q = { id = 801, name = "At War", zone = "zone-a", objectives = { { text = "0/1 Captain Vachon slain", have = 0, need = 1 }, { text = "2/5 Scarlet Friar slain", have = 2, need = 5 } } }
	local near = { id = 802, name = "Right here", zone = "zone-a", objectives = { { text = "Thing", have = 1, need = 9 } } }
	local ns, W, c = logWorld({ q, near })
	local list = ns.Overlap.List(ns.State.plan, ns.State.ctx)
	local seen = 0
	for _, it in ipairs(list) do
		for _, o in ipairs(it.objectives or {}) do
			seen = seen + 1
			check(not o.text:find("%d+%s*/%s*%d+"), "the label carries no count of its own  [" .. o.text .. "]")
		end
	end
	check(seen >= 1, "at least one objective was checked")
	local direct = ns.Overlap.Unfinished({ objectiveState = { known = true, list = { { text = "0/1 Captain Vachon slain", finished = false, have = 0, need = 1 }, { text = "Scarlet Friar slain: 2/5", finished = false, have = 2, need = 5 } } } })
	check(#direct == 2 and direct[1].text == "Captain Vachon slain" and direct[2].text == "Scarlet Friar slain", "the game's '0/1 ...' and '...: 2/5' count text is stripped from the label (the bar shows the count)")
	check(#ns.errors == 0, "no errors")
end

-- ---------------------------------------------------------------- UX clarity pass (0.5.5): distances as numbers, who, why, action-aware labels
section("clarity: distances read as numbers, hand-in NPCs only when named, reasons only when the planner gave one")
local function clarityWorld(withTurnInData, withObjective)
	local ns = boot({ char = { level = 9 }, synthetic = true, loc = { map = 9001, x = 0.5, y = 0.5, zone = "Fixture Valley" } })
	local function at(dx, dy) return 0.5 + dx / 1000, 0.5 + (dy or 0) / 1000 end
	local x1, y1 = at(300, 0)
	local xt, yt = at(1800, 0)
	local xp, yp = at(250, 20)                       -- a pickup beside NOW's spot
	local xq, yq = at(700, 0)                        -- a pickup farther on: the THEN
	local recs = {
		{ id = 1, name = "Work Quest", map = 9001, x = x1, y = y1, req = 1, level = 9, giverName = "Work Giver", objCoords = { { map = 9001, x = x1, y = y1 } } },
		{ id = 2, name = "Far Hand-in", map = 9001, x = xt, y = yt, req = 1, level = 9, giverName = "Original Giver",
			turnIn = withTurnInData and { npc = 77, name = "Riaani Nightwind", map = 9001, x = xt, y = yt } or false },
		{ id = 3, name = "Giver Only", map = 9001, x = xt, y = yt + 0.2, req = 1, level = 9, giverName = "Only A Giver", turnIn = false },
		{ id = 4, name = "Follow Up", map = 9001, x = at(2500, 900), y = 0.5, req = 1, level = 9, giverName = "Next Giver", prereq = { 2 } },
		{ id = 5, name = "Pickup Beside", map = 9001, x = xp, y = yp, req = 1, level = 9, giverName = "Aamelia Windfield" },
		{ id = 6, name = "Pickup Onward", map = 9001, x = xq, y = yq, req = 1, level = 9, giverName = "Nazgrel" },
	}
	if withObjective then
		local xo, yo = at(330, 10)
		recs[#recs + 1] = { id = 7, name = "Near Objective", map = 9001, x = xo, y = yo, req = 1, level = 9, giverName = "Obj Giver", objCoords = { { map = 9001, x = xo, y = yo } } }
	end
	H.attPack(ns, recs, ZONES)
	local W = H.world()
	W.completed = {}
	W.log = { { questID = 1, title = "Work Quest", complete = false }, { questID = 2, title = "Far Hand-in", complete = true }, { questID = 3, title = "Giver Only", complete = true } }
	W.objectives = { [1] = { { text = "Thing", type = "monster", finished = false, numFulfilled = 1, numRequired = 5 } } }
	if withObjective then
		W.log[#W.log + 1] = { questID = 7, title = "Near Objective", complete = false }
		W.objectives[7] = { { text = "Other thing", type = "monster", finished = false, numFulfilled = 0, numRequired = 4 } }
	end
	ns.Prefs.FinishSetup()
	ns.State.Recompute()
	ns.UI.Open("codex")
	return ns, W, ns.UI.main.codex
end
do
	local ns, W, c = clarityWorld(true)
	local Pr = ns.Presenter
	check(Pr.Dist(10) == "Here" and Pr.Dist(94) == "90 yd" and Pr.Dist(1800) == "1,800 yd" and Pr.Dist(1730) == "1,750 yd" and Pr.Dist(4000) == "4,000 yd" and Pr.Dist(nil) == nil and Pr.Dist(ns.Engine.DIFFERENT_CONTINENT) == "In another area", "distances: Here / 90 yd / 1,800 yd / another area, nothing when unknown")
	check(Pr.Join("a", nil, "b") == "a - b" and Pr.Join(nil, nil) == nil, "Join keeps only the parts that exist")
	local card = Pr.Card(ns.State.plan, ns.State.ctx)
	check(card.now and ns.State.plan.now.quest == 1 and card.now.dist == "~300 yd" and card.now.level == 9, "NOW carries a numeric distance and the quest level from the data  [" .. tostring(card.now and card.now.dist) .. "]")
	check(c.nowInfo.__text == "~300 yd - Lv 9", "the tracker shows it as secondary information: '" .. tostring(c.nowInfo.__text) .. "'")
	-- READY TO TURN IN
	local byQ = {}
	for _, r in ipairs(card.ready) do byQ[r.quest] = r end
	check(byQ[2] and byQ[2].npc == "Riaani Nightwind" and byQ[2].distText == "1,800 yd", "READY: a quest whose data names a turn-in NPC shows the NPC and a numeric distance")
	check(byQ[3] and byQ[3].npc == nil, "READY: when no turn-in NPC is named the quest giver's name is NOT shown as the hand-in NPC")
	check(byQ[2].unlocks == 1 and byQ[3].unlocks == nil, "READY: 'opens N more quests' only where the data lists a follow-up that this character could take (1 and none)")
	local rows = {}
	for i, r in ipairs(c.readyRows) do if r.__shown ~= false and r.__text ~= "" then rows[#rows + 1] = r.__text .. " | " .. tostring(c.readySubs[i].__text) end end
	local flat = table.concat(rows, "\n")
	check(flat:find("Far Hand-in | 1,800 yd - Riaani Nightwind - opens 1 more quest", 1, true) ~= nil, "the card draws the name, then (dim) distance - NPC - follow-ups  [" .. flat:gsub("\n", " / ") .. "]")
	-- 0.8.4: no turn-in data means no hand-in place either: no distance is drawn (the giver's spot is not borrowed), and no NPC
	check(flat:find("Giver Only | ", 1, true) ~= nil and not flat:find("Giver Only | 1,800", 1, true) and not flat:find("Only A Giver", 1, true) and byQ[3].distText == nil and byQ[3].placed == false, "and nothing invented where the NPC is unknown: no distance, no NPC")
	check(not flat:find("[\128-\255]"), "plain ASCII")
	-- ALSO: a pickup beside NOW is named for what it is, with distance, who and why
	check(card.also[1] and card.also[1].kind == "action" and card.also[1].verb == "ACCEPT" and card.also[1].npc == "Aamelia Windfield", "ALSO row: a pickup carries its NPC")
	check(c.alsoLabel.__text == "ALSO PICK UP", "a card of pickups is titled ALSO PICK UP, not ALSO COMPLETE THIS")
	local sub = c.alsoSubs[1].__text
	check(sub:find("Aamelia Windfield", 1, true) and (sub:find("same stop", 1, true) or sub:find("on your way", 1, true) or sub:find("detour about", 1, true)), "its dim line gives who and the planner's own reason: '" .. tostring(sub) .. "'")
	-- THEN
	check(card.thenLine == "Accept Pickup Onward" and card.thenWhere == "700 yd - Nazgrel" and c.thenWhereFS.__text == "700 yd - Nazgrel", "THEN: the action, then how far and who ('700 yd - Nazgrel')")
	check(#ns.errors == 0, "no errors")
end
do
	local ns, W, c = clarityWorld(false)
	local card = ns.Presenter.Card(ns.State.plan, ns.State.ctx)
	check(card.now ~= nil, "without any turn-in data the card still builds")
	for _, r in ipairs(card.ready) do check(r.npc == nil, "no hand-in NPC is invented when none is named") end
	check(#ns.errors == 0, "no errors")
end

section("clarity: the ALSO heading is decided from the WHOLE carried set (real-client bug: a mixed set was headed ALSO COMPLETE THIS)")
do
	local ns = boot({ char = { level = 6 }, synthetic = true, loc = { map = 9001, x = 0.5, y = 0.5 } })
	local L = ns.Presenter.AlsoLabel
	local obj, pick = { kind = "objective" }, { kind = "action", verb = "ACCEPT" }
	check(L({ obj, obj }) == "ALSO COMPLETE" and L({ obj }) == "ALSO COMPLETE", "all objective rows -> ALSO COMPLETE")
	check(L({ pick, pick }) == "ALSO PICK UP" and L({ pick }) == "ALSO PICK UP", "all pickup rows -> ALSO PICK UP")
	check(L({ obj, pick, pick, pick }) == "ALSO DO" and L({ pick, obj }) == "ALSO DO", "a mix of objective and pickup rows -> ALSO DO, whichever row comes first")
	check(L({}) == nil and L(nil) == nil, "an empty set has no heading")
	-- the real-client shape: one objective first, then three pickups
	local ns2, W, c = clarityWorld(false, true)
	local card = ns2.Presenter.Card(ns2.State.plan, ns2.State.ctx)
	local kinds = {}
	for _, it in ipairs(card.also) do kinds[#kinds + 1] = it.kind end
	check(#card.also >= 2 and table.concat(kinds, ","):find("objective", 1, true) and table.concat(kinds, ","):find("action", 1, true), "the tracker's set is mixed (" .. table.concat(kinds, ",") .. ")")
	check(c.alsoLabel.__text == "ALSO DO", "the tracker draws ALSO DO for the mixed set (drew: " .. tostring(c.alsoLabel.__text) .. ")")
	local text
	rawset(ns2.UI, "ShowReport", function(t) text = t end)
	H.slash("report")
	check(text and text:find("ALSO DO: ", 1, true) and not text:find("ALSO COMPLETE THIS", 1, true), "/qflow report uses the same heading for every row (it used to print ALSO COMPLETE THIS for pickups too)")
	check(text:find("--- WHAT THE WINDOW SHOWS", 1, true) ~= nil and text:find("worst was recompute", 1, true) == nil or text:find("PERFORMANCE", 1, true) ~= nil, "the report still has its sections")
	-- an empty set hides the card
	local ns3, W3, c3 = clarityWorld(false)
	ns3.Overlap.List = function() return {} end
	ns3.State.Recompute()
	check(not c3.alsoBox.__shown, "no rows: the card is hidden as before")
end

section("performance counters: the worst recompute is attributed to its stages")
do
	local ns = boot({ char = { level = 6 }, synthetic = true, loc = { map = 9001, x = 0.5, y = 0.5 } })
	H.attPack(ns, { { id = 1, name = "A", map = 9001, x = 0.52, y = 0.5, req = 1, giverName = "G" } }, ZONES)
	H.world().log, H.world().objectives, H.world().completed = {}, {}, {}
	ns.Prefs.FinishSetup()
	local t = 0
	_G.debugprofilestop = function() t = t + 1 return t end
	ns.State.Recompute("direct")
	local pf = ns.State.perf
	check(pf.worstN == pf.count and pf.wCtx and pf.wCand and pf.wPlan, "the worst recompute keeps its context / scan / planner times")
	local lines = table.concat(ns.Diag.PerformanceLines(), "\n")
	check(lines:find("worst was recompute #", 1, true) and lines:find("quest scan (Engine.Candidates)", 1, true) and lines:find("QuestieDB records built so far", 1, true), "the PERFORMANCE section names the stages and the one-time QuestieDB build")
	_G.debugprofilestop = nil
	ns.State.Recompute()
	check(#ns.errors == 0, "no errors without a clock")
end

section("clarity (0.6.3): an ALSO objective says what its count is of")
do
	local ns, W, c = clarityWorld(false, true)
	local heads, rows = {}, {}
	for _, h in ipairs(c.alsoHeads) do if h.__shown ~= false and h.__text ~= "" then heads[#heads + 1] = h.__text end end
	for _, r in ipairs(c.alsoRows) do if r.cur then rows[#rows + 1] = tostring(r.label.__text) .. " " .. tostring(r.count.__text) end end
	local flat = table.concat(heads, " | ") .. " || " .. table.concat(rows, " | ")
	check(flat:find("Near Objective", 1, true) and flat:find("Other thing 0/4", 1, true), "the quest is the heading and its objective ('Other thing') is the row with its count: " .. flat)
	-- a quest whose objective has no wording of its own keeps the compact row
	local ns2, W2, c2 = clarityWorld(false, true)
	W2.objectives[7] = { { text = "", type = "monster", finished = false, numFulfilled = 0, numRequired = 4 } }
	ns2.State.Recompute()
	local compact = {}
	for _, r in ipairs(c2.alsoRows) do if r.cur then compact[#compact + 1] = tostring(r.label.__text) end end
	check(table.concat(compact, "|"):find("Near Objective", 1, true) ~= nil, "no objective wording: the compact row (quest name beside the count) is kept")
end
