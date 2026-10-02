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

section("UI polish: every word still comes from the Presenter; the progress bar shows real counts only")
do
	local ns, W, c = uiWorld(QUEST, { [1] = { objectives = { { text = "4/6 Worgen Bits", have = 4, need = 6 } } } })
	local card = ns.Presenter.Card(ns.State.plan, ns.State.ctx)
	check(card.now and card.now.progress == "4 / 6", "(setup) the Presenter reports 4 / 6")
	check(text(c.nowTitle) == card.now.title and text(c.nowWho) == (card.now.who or "") and text(c.nowDetail) == (card.now.detail or "") and text(c.nowWhy) == (card.now.why or ""), "title, who, detail and why are exactly the Presenter's words")
	check(c.nowBar.__shown and c.nowBar.fraction and math.abs(c.nowBar.fraction - 4 / 6) < 1e-9 and text(c.nowBar.text) == "4 / 6", "the bar shows 4 / 6 with its numbers readable beside it")
	check(c.nowBar.fill.__w == math.floor((c.nowBar.trackW - 2) * (4 / 6) + 0.5), "and its fill is two thirds of the track")
	check(text(c.nowInfo):find("4 / 6", 1, true) == nil and text(c.nowInfo) == (card.now.where or ""), "the counts moved into the bar; the info line keeps the distance")
	-- 0 of 6: the bar is there, nothing is filled
	local ns2, _, c2 = uiWorld(QUEST, { [1] = { objectives = { { text = "0/6 Worgen Bits", have = 0, need = 6 } } } })
	check(c2.nowBar.__shown and text(c2.nowBar.text) == "0 / 6" and c2.nowBar.fraction == 0 and not c2.nowBar.fill.__shown, "0 of 6 shows an empty bar and the numbers")
	-- the quest log did not report counts: no bar, no invented numbers, the old behaviour
	local ns3, W3, c3 = uiWorld(QUEST, { [1] = {} })
	local card3 = ns3.Presenter.Card(ns3.State.plan, ns3.State.ctx)
	check(card3.now and card3.now.progress == nil, "(setup) no counts reported")
	check(not c3.nowBar.__shown and text(c3.nowBar.text) == "" and not text(c3.nowInfo):find("%d+ / %d+"), "no bar and no made-up numbers when progress is unknown")
	-- the bar only accepts real numbers
	local b = c.nowBar
	check(b:Set(nil, 6) == false and not b.__shown and b:Set(3, 0) == false and b:Set(-1, 5) == false and b:Set("3", 6) == false, "Set refuses missing, zero, negative and non-numeric counts")
	check(b:Set(9, 6) == true and b.fraction == 1, "more than needed is capped at a full bar")
	-- a plain quest with no progress, then an accept: nothing odd
	local ns4, _, c4 = uiWorld({ Q(2, "Plain pickup", 50, 0, { giverName = "Gornek" }) }, {})
	check(not c4.nowBar.__shown and text(c4.nowTitle):find("Accept", 1, true) ~= nil, "an accept has no bar")
	check(#ns.errors == 0 and #ns3.errors == 0 and #ns4.errors == 0, "no errors")
end

section("UI polish: type hierarchy and spacing in the NOW card")
do
	local ns, W, c = uiWorld(QUEST, { [1] = { objectives = { { text = "4/6 Worgen Bits", have = 4, need = 6 } } } })
	local f = function(fs) return fs.__font and fs.__font.size end
	check(f(c.nowTitle) == 16 and f(c.nowWho) == 12 and f(c.nowDetail) == 11 and f(c.nowWhy) == 10 and f(c.nowLabel) == 10, "section label 10 < supporting 10-11 < location 12 < the action 16")
	check(f(c.nowTitle) > f(c.nowWho) and f(c.nowWho) > f(c.nowDetail) and f(c.nowDetail) > f(c.nowWhy), "the action is the largest, metadata the smallest")
	check(c.nowTitle.__font.path == "Fonts\\FRIZQT__.TTF", "sizes use the game's own font file (no external font)")
	check(f(c.nearRows[1].title) and f(c.nearRows[1].title) < f(c.nowTitle), "NEARBY text is smaller than the NOW action")
	-- no overlap: every shown line starts below the previous one by at least its height
	local order = { c.nowTitle, c.nowWho, c.nowDetail, c.nowBar, c.nowInfo, c.nowWhy }
	local last, lastH = -1, 0
	local okOrder, shown = true, 0
	for _, el in ipairs(order) do
		if el.__shown ~= false and (text(el) ~= "" or el == c.nowBar) and (el ~= c.nowBar or c.nowBar.__shown) then
			local yy = y(el)
			shown = shown + 1
			if not yy or yy < last + lastH then okOrder = false end
			last, lastH = yy or last, (el == c.nowBar) and 12 or 12
		end
	end
	check(okOrder and shown >= 4, "lines run top to bottom without overlapping (" .. shown .. " lines)")
	check(c.nowBox.__h >= last + lastH + 10, "the card is tall enough for its last line plus the padding")
	-- the card shrinks to what it shows
	local nsE, WE, cE = uiWorld({}, {})
	check(cE.nowBox.__h <= 100 and cE.nowBox.__h >= 88, "an empty NOW is compact (" .. tostring(cE.nowBox.__h) .. " px) but never below its minimum")
	check(c.nowBox.__h > cE.nowBox.__h, "a NOW with progress is taller than an empty one")
	check(not cE.nowIcon.__shown and text(cE.nowTitle) == "Nothing to recommend right now", "the empty state hides the marker square and says so plainly")
	check(c.nowIcon.__shown and c.nowIcon.kind == "star", "a real recommendation shows the star")
	check(#ns.errors == 0 and #nsE.errors == 0, "no errors")
end

section("UI polish: NEARBY is smaller and fits its rows; NEW FOR YOU is narrower, secondary and fits its content")
do
	local ns, W, c = uiWorld(QUEST, { [1] = { objectives = { { text = "4/6 Worgen Bits", have = 4, need = 6 } } } })
	local UI = ns.UI
	check(c.nearBox.__h == 56, "NEARBY with nothing to say is the minimum height, not a big empty box (" .. tostring(c.nearBox.__h) .. ")")
	ns.Nearby.List = function() return { { title = "Rest here", detail = "A short stop.", where = "Right here", icon = "diamond" }, { title = "Second", detail = "More.", where = "Nearby", icon = "diamond" }, { title = "Third", detail = "Even more.", where = "Nearby", icon = "diamond" } } end
	UI.Refresh()
	check(c.nearBox.__h > 56 and y(c.nearRows[2].title) > y(c.nearRows[1].title) and y(c.nearRows[3].title) > y(c.nearRows[2].title), "three rows make it taller and are spaced evenly down")
	check(y(c.nearRows[1].detail) > y(c.nearRows[1].title), "each row's detail sits under its title")
	check(c.nearBox.__points[5] == -(22 + c.nowBox.__h + 8), "NEARBY starts one gap below NOW (the card height is the measured one)")
	-- NEW FOR YOU, one item and then three
	local active
	ns.NewForYou.Active = function() return active end
	active = { level = 6, items = { { title = "New quest: One" } } }
	UI.Refresh()
	check(c.nfyBox.__shown and c.nfyBox.__w == 192 and c.nowBox.__w == 304 and c.nfyBox.__w < c.nowBox.__w, "NEW FOR YOU is narrower than NOW")
	local h1 = c.nfyBox.__h
	active = { level = 6, items = { { title = "New quest: One", detail = "Talk to someone." }, { title = "New quest: Two", detail = "Elsewhere." }, { title = "New quest: Three" } } }
	UI.Refresh()
	check(c.nfyBox.__h > h1, "it grows with its content (1 item " .. h1 .. " px, 3 items " .. c.nfyBox.__h .. " px)")
	check(h1 < c.nowBox.__h + c.nearBox.__h + 8, "and a short one is not a full-height panel")
	check(c.nfyBox.__points[5] == c.nowBox.__points[5] and c.nfyBox.__points[4] == 312, "it sits level with NOW, in the right column")
	check(text(c.nfyLabel) == "NEW FOR YOU" and text(c.nfyLevel) == "Level 6", "its words are unchanged")
	-- it never replaces or moves NOW's content
	local nowTitle = text(c.nowTitle)
	active = nil
	UI.Refresh()
	check(not c.nfyBox.__shown and c.nowBox.__w == 504 and text(c.nowTitle) == nowTitle, "when it goes, NOW keeps its words and takes the full width")
	check(#ns.errors == 0, "no errors")
end

section("UI polish: restrained accents - warm gold NOW, cool NEARBY, neutral NEW FOR YOU; a texture border; nothing animated")
do
	local ns, W, c = uiWorld(QUEST, {})
	local Wd = ns.Widgets
	local a, n, f = Wd.STYLE_NOW.accent, Wd.STYLE_NEAR.accent, Wd.STYLE_NEW.accent
	check(a[1] > a[3] and a[1] > 0.8 and a[2] > a[3], "NOW's accent is warm gold/amber (red and green high, blue low)")
	check(n[3] > n[1] and n[3] > n[2] and n[1] < 0.6, "NEARBY's accent is a cool, muted violet-blue")
	check(f[1] > f[3] and f[1] < a[1] + 0.001 and Wd.STYLE_NEW.side == "top", "NEW FOR YOU is a quieter neutral gold with a top edge")
	for name, st in pairs({ now = Wd.STYLE_NOW, near = Wd.STYLE_NEAR, new = Wd.STYLE_NEW }) do
		local maxc = math.max(st.accent[1], st.accent[2], st.accent[3])
		local minc = math.min(st.accent[1], st.accent[2], st.accent[3])
		check(maxc - minc < 0.75 and st.bg[4] < 1, name .. ": no neon (a modest spread between the strongest and weakest channel) and a soft fill")
	end
	for _, box in ipairs({ c.nowBox, c.nearBox, c.nfyBox }) do
		check(box.edge and box.bg and box.accent, "each card has a 1 px border, a fill and a 2 px accent edge")
	end
	check(c.nowBox.accent.__w == 2 and c.nfyBox.accent.__h == 2, "the accent is 2 px (left for NOW and NEARBY, top for NEW FOR YOU)")
	local src = ""
	for _, f in ipairs({ "Widgets.lua", "PageCodex.lua", "Main.lua" }) do src = src .. H.readFile(H.addonDir .. "/UI/" .. f):gsub("%-%-[^\n]*", "") end
	check(not src:find("Animation", 1, true) and not src:find("SetAlpha", 1, true) and not src:find("AnimationGroup", 1, true), "no animation")
	check(#ns.errors == 0, "no errors")
end

section("UI polish: the shell keeps its behaviour (dropdown, drag, position) and gains a border and a title")
do
	local ns, W, c = uiWorld(QUEST, {})
	local UI = ns.UI
	check(UI.frame.__movable == true and UI.frame.__drag and UI.frame.__drag[1] == "LeftButton" and UI.frame.__clamped == true, "the window is still movable, drag-registered and clamped")
	check(UI.WIDTH == 520 and UI.HEIGHT == 430 and UI.frame.__w == 520, "the window width is unchanged (the height fits the Codex page, see below)")
	check(UI.main.nav.button.text.__text == "Codex  v", "the dropdown button is unchanged")
	local found
	for _, fs in ipairs(W.fonts) do if fs.__text == "FOREVER CODEX  v" .. ForeverCodex.VERSION then found = true end end
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
	check(c.nowTitle.__font == nil and text(c.nowTitle) ~= "" and c.nowBox.__h >= 88, "without the font file the text keeps its normal size and the card still lays out")
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
	for _, bad in ipairs({ "ns.Planner", "ns.Engine", "ns.Registry", "ns.Telemetry", "ns.Navigation", "ns.QuestieBridge", "ns.Contract", "ns.Markers", "ns.Pins", "ns.Arrow" }) do
		check(src:find(bad, 1, true) == nil, "PageCodex.lua does not touch " .. bad)
	end
	check(src:find("ns%.Prefs%.Set%u") == nil and src:find("ns%.Prefs%.Skip") == nil and src:find("ns%.Prefs%.Add") == nil, "and changes no preference (it only asks whether setup is done)")
	check(src:find("ns.Presenter", 1, true) and src:find("ns.Nearby", 1, true) and src:find("ns.NewForYou", 1, true) and src:find("ns.Party", 1, true), "it reads only the Presenter, Nearby, NewForYou and Party view models")
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
