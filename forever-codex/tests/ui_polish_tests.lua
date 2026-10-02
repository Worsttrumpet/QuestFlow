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
	check(not all:find("Keeps you progressing", 1, true) and not all:find("Best use of your time", 1, true) and not all:find("Why", 1, true), "no 'why' text is drawn in the window")
	check(ns.Presenter.Card(ns.State.plan, ns.State.ctx).now.why == "Keeps you progressing where you are", "the reason is still computed (for /codex report)")
	check(c.nowWhy == nil, "the page has no 'why' line at all")
	local text
	rawset(ns.UI, "ShowReport", function(t) text = t end)
	H.slash("report")
	check(text and text:find("unfinished: Rot Hide Graverobber slain 4/8", 1, true) and text:find("ALSO COMPLETE THIS:", 1, true) and text:find("why: Keeps you progressing", 1, true)
		and text:find("reason=", 1, true) and text:find("Recomputes:", 1, true) and text:find("PLAYTEST REPORT", 1, true), "/codex report keeps the 'why', the reason, the recompute count and now lists the unfinished objectives and the overlap")
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
	check(c.alsoBox.__shown and c.alsoLabel.__text == "ALSO COMPLETE THIS", "the card is titled ALSO COMPLETE THIS")
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
	-- NOW is a hand-in: working objectives elsewhere is not 'overlap' with it
	local done = { id = 40, name = "Finished task", zone = "zone-a", complete = true, objectives = { { text = "Thing", have = 5, need = 5 } }, map = 9001, x = 0.505, y = 0.5 }
	local ns2 = logWorld({ done, DOOM })
	check(ns2.State.plan.now and ns2.State.plan.now.kind == "TURN_IN" and #ns2.Overlap.List(ns2.State.plan, ns2.State.ctx) == 0, "with a hand-in as NOW there is no objective overlap")
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
	check(UI.COMPACT_WIDTH >= 280 and UI.COMPACT_WIDTH <= 360 and UI.frame.__w == UI.COMPACT_WIDTH, "the Codex window is a tracker-width panel  [" .. tostring(UI.frame.__w) .. " px]")
	check(c.nowBox.__w == UI.COMPACT_WIDTH - 16 and c.alsoBox.__w == UI.COMPACT_WIDTH - 16, "its cards fill that width")
	check(UI.frame.__h < UI.HEIGHT, "and its height fits the content")
	check(UI.frame.__movable == true and UI.frame.__drag and UI.frame.__drag[1] == "LeftButton", "it can be dragged")
	local p = UI.frame.__points
	check(p[1] == "TOPRIGHT" and p[4] < 0 and p[5] < -150, "its default place is the right side where the quest tracker sits, below the minimap  [" .. tostring(p[1]) .. " " .. tostring(p[4]) .. "," .. tostring(p[5]) .. "]")
	UI.ShowPage("journey")
	check(UI.frame.__w == UI.WIDTH, "the other pages keep the full width")
	UI.ShowPage("codex")
	check(UI.frame.__w == UI.COMPACT_WIDTH, "and the Codex page is compact again")
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

section("UI polish: the shell keeps its behaviour (dropdown, drag, position) and gains a border and a title")
do
	local ns, W, c = uiWorld(QUEST, {})
	local UI = ns.UI
	check(UI.frame.__movable == true and UI.frame.__drag and UI.frame.__drag[1] == "LeftButton" and UI.frame.__clamped == true, "the window is still movable, drag-registered and clamped")
	check(UI.WIDTH == 520 and UI.HEIGHT == 430 and UI.frame.__w == UI.COMPACT_WIDTH, "the full-size window is still 520 x 430; the Codex page is the compact width (the height fits it, see below)")
	check(UI.main.nav.button.text.__text == "Codex  v", "the dropdown button is unchanged")
	local found
	for _, fs in ipairs(W.fonts) do if fs.__text == "FOREVER CODEX v" .. ForeverCodex.VERSION then found = true end end
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
	check(c.nowTitle.__font == nil and text(c.nowTitle) ~= "" and c.nowBox.__h >= 56, "without the font file the text keeps its normal size and the card still lays out")
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
	check(said:find("Skipped:", 1, true) ~= nil and said:find("/codex unskip", 1, true) ~= nil, "and says how to bring it back")
	H.slash("unskip")
	check(ns.State.plan.now.quest == first, "/codex unskip restores it")
	local nsE, WE, cE = uiWorld({}, {})
	check(not cE.nowSkip.__shown, "there is no Skip button when there is nothing to recommend")
	check(ns.State.SkipCurrent ~= nil and H.readFile(H.addonDir .. "/Slash.lua"):find("State.SkipCurrent", 1, true) ~= nil, "/codex skip and the button share one function")
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
	check(d[1].l == "Forever Codex" and d[1].lc[1] == 1 and d[1].lc[2] == 0.82 and d[1].lc[3] == 0, "a gold Forever Codex title, as on the minimap button")
	check(d[2].l == "Drag" and d[2].r == "Move arrow" and d[3].l == "Shift + Drag" and d[3].r == "Resize arrow" and d[4].l == "/codex arrow flip" and d[4].r == "Flip arrow direction", "rows: Drag, Shift + Drag and /codex arrow flip")
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
	check(ns3.Prefs.ArrowFlip() ~= before, "/codex arrow flip still works")
	local slashSrc = H.readFile(H.addonDir .. "/Slash.lua")
	check(not slashSrc:find('restLower == "size"', 1, true) and not slashSrc:find("resize", 1, true), "no command was added for arrow sizing")
	check(#ns.errors == 0 and #ns2.errors == 0 and #ns3.errors == 0, "no errors")
	_G.IsShiftKeyDown, _G.GetCursorPosition = nil, nil
end

section("window: the Codex page fits its content (no empty space), other pages keep the full height, the top edge never moves")
do
	local ns, W, c = uiWorld(QUEST, {})
	local UI = ns.UI
	local h1 = UI.frame.__h
	check(h1 < UI.HEIGHT and h1 >= UI.HEIGHT_MIN, "with a short page the window is shorter than the full height  [" .. tostring(h1) .. "]")
	local ns2 = uiWorld(QUEST, {}, 6)
	-- more content (a log reminder line and a second card row) makes it taller, never shorter than the content
	ns2.UI.ShowPage("journey")
	check(ns2.UI.frame.__h == ns2.UI.HEIGHT, "other pages use the full height")
	ns2.UI.ShowPage("codex")
	check(ns2.UI.frame.__h < ns2.UI.HEIGHT, "back on the Codex page it fits again")
	-- the top edge: a CENTER-anchored window keeps its top when the height changes
	local f = ns2.UI.frame
	local function top() local p = f.__points; return p[5] + f.__h / 2 end
	f:ClearAllPoints(); f:SetPoint("CENTER", UIParent, "CENTER", 10, 20)
	ns2.UI.main.height = f.__h
	local before = top()
	ns2.UI.ShowPage("journey")
	check(math.abs(top() - before) < 1e-6, "the top edge stays put when the page changes the height")
	ns2.UI.ShowPage("codex")
	check(math.abs(top() - before) < 1e-6, "and when it fits again")
	check(#ns.errors == 0 and #ns2.errors == 0, "no errors")
end

section("report: /codex report builds one copyable playtest report (what is shown, why, the quest log), changes nothing, is plain ASCII")
do
	local ns, W = uiWorld(QUEST, { [QUEST_ID or 1] = { title = "A quest", objectives = { { text = "Thing slain", have = 2, need = 5 } } } })
	local captured
	rawset(ns.UI, "ShowReport", function(t) captured = t end)
	local before = ns.State.plan.now and ns.State.plan.now.id
	H.slash("report")
	if os.getenv("SHOW_REPORT") then print(captured) end
	check(type(captured) == "string" and captured:find("PLAYTEST REPORT v" .. ForeverCodex.VERSION, 1, true) ~= nil, "the report opens with the addon version")
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
	check(ns.Prefs.HideBlizzardTracker() and not shown and ns.BlizzardTracker.Status().state == "hidden" and ns.BlizzardTracker.Status().frame == "ObjectiveTrackerFrame", "/codex tracker on hides it")
	frame.Show()
	check(not shown and hooks == 1, "if the game shows it again it is hidden again (one post-hook, installed once)")
	ns.BlizzardTracker.Apply()
	check(hooks == 1, "applying twice does not stack hooks")
	H.slash("tracker off")
	check(shown and not ns.Prefs.HideBlizzardTracker() and ns.BlizzardTracker.Status().state == "off", "/codex tracker off brings it back at once")
	frame.Show()
	check(shown, "and once off the hook leaves it alone")
	local W = H.world()
	W.chat = {}
	H.slash("diag")
	check(table.concat(W.chat, "\n"):find("game quest tracker:", 1, true) ~= nil, "/codex diag reports its state")
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
