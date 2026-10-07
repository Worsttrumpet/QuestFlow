-- ForeverQuestGuide.UI: the addon's one window, now with two tabs.
--
-- QUESTS tab (M8.1, unchanged in behavior): a left-hand scrollable list of
-- guide-ready quests and a right-hand detail panel.
--
-- ROUTE tab (M8.3, new): displays one hand-authored route (ns.Routes,
-- generated from m8-guide-addon/routes/*_route.json -- see RouteData.lua's
-- own header) one step at a time, with manual Previous/Next controls. This
-- is STATIC DISPLAY ONLY:
--   * no quest-state tracking (the addon never reads C_QuestLog for this)
--   * no automatic step advancement -- the player always clicks Next
--   * no directional arrow, no distance, no map/minimap pin
--   * a step's quest title and objective text are looked up LIVE from
--     ns.QuestData (Data.lua) by quest_id/objective_index -- never
--     duplicated inside route data, so they can never drift from it
--
-- Built entirely from bare CreateFrame/CreateTexture/CreateFontString
-- primitives and standard Frame-object methods -- no XML template names are
-- referenced anywhere in this file, since none has been confirmed to exist
-- on Forever (see docs/M8_0_SCOPE.md, docs/M8_1_COMPLETION_REPORT.md). The
-- QUESTS tab was real-client validated in M8.1 (docs/M8_1_REAL_CLIENT_VALIDATION.md);
-- everything specific to the ROUTE tab is new, real-client-UNTESTED Lua
-- until docs/M8_3_COMPLETION_REPORT.md's manual test is actually run --
-- including whether the chosen step-type glyphs (below) render as intended.
--
-- "Show on Map" remains a placeholder only, per docs/M8_0_SCOPE.md SS5/SS9:
-- no map-pin API has been confirmed to exist on Forever.

local addonName, ns = ...

local ROW_HEIGHT = 18
local VISIBLE_ROWS = 16
local LIST_WIDTH = 240
local DETAIL_WIDTH = 240
-- Was -46 in M8.1; moved down to make room for the tab bar. -78 (not the original M8.3 draft's -64) --
-- real-client validation (docs/M8_3_REAL_CLIENT_VALIDATION.md) found -64 left the section header
-- ("Quests (...)" / "Route (...)") close enough to the tab buttons above it to visually overlap on the
-- actual client's font metrics (the stub environment can't catch this -- it has no real font/line-height
-- to measure against). The extra 14px was chosen generously rather than pared to the observed minimum.
local PANEL_TOP_OFFSET = -78
-- M8.6-A: the ROUTE tab's detailed-mode content (progress bar, required badge, why section, up to 3
-- preview entries) needs substantially more vertical room than M8.3's original route panel. This is a
-- generous, best-effort estimate, not a measured real-client value -- see docs/M8_6_A_COMPLETION_REPORT.md
-- for the same kind of spacing caveat M8.3 already had to correct once for the header/tab-bar gap.
local ROUTE_PANEL_HEIGHT = 480

local frame
local listButtons = {}
local detailObjectiveLines = {}
local detailTitle, detailLevel, detailGiver, detailPos, detailObjectivesHeader
local scrollOffset = 0
local selectedQuestID = nil

local activeTab = "QUESTS"
local questsTabBtn, routeTabBtn, themeToggleBtn, modeToggleBtn
local setActiveTabTheme  -- forward-declared: defined near setActiveTab, called from applyTheme (defined first)
local colorProgressSegments  -- forward-declared: defined near the route progress bar, called from applyTheme too
local renderRouteStep  -- forward-declared: applyUIMode (defined early) needs to re-render after a mode switch
local currentRouteID = nil
local currentStepIndex = 1  -- 1-based index into a route's own step_order array
local routeTitleFS, routeStepCounterFS, routeKindFS, routeRequiredFS, routeQuestFS, routeNpcFS, routeBodyFS, routeInstructionFS
local routeWhyHeaderFS, routeWhyTextFS, routeDestFS
local routePrevBtn, routeNextBtn
local routeProgressRow
local routeProgressSegments = {}
-- M8.6-A: the preview shows up to this many FUTURE steps (never past ones), following the authored
-- next_step_id chain only. The request's own wording allows 3-5; 3 was chosen as the lower end of that
-- range to keep the preview compact, matching the milestone's own "minimal clutter" framing for compact
-- mode and the request's own illustrative example (which itself showed only 2 future steps: UP NEXT, THEN).
local PREVIEW_STEP_COUNT = 3
local PREVIEW_LABELS = { "UP NEXT", "THEN", "AFTER THAT" }
local previewCollapsed = false
local previewToggleBtn
local previewLines = {}  -- previewLines[i] = { kindFS = ..., bodyFS = ... }, built lazily like detailObjectiveLines
local filterText = ""
local searchLabel, searchBox

-- ============================================================ M8.5 theme support
--
-- Every FontString created through newFontString() and every button created through newWideButton()
-- registers itself here automatically, so applyTheme() can recolor the whole window in one pass without
-- every construction site needing to know about theming individually. Window background/border textures are
-- registered directly at their two creation points in build() (there is only one of each). "Classic" (the
-- default, unchanged from M8.1/M8.3) and "Dark" are both real, complete palettes defined in
-- Preferences.lua -- this file only ever asks for "the current theme's colors," never hardcodes a color
-- literal for anything themedFontStrings/themedPrimaryButtons/themedSecondaryButtons/themedWindowBGs/
-- themedBorders cover.
local themedFontStrings = {}
local themedPrimaryButtons = {}   -- e.g. NEXT -- strong visual emphasis per the M8.5 request
local themedSecondaryButtons = {} -- e.g. PREVIOUS, Show on Map -- visible but visually secondary
local themedWindowBGs = {}
local themedBorders = {}
local themedEditBoxes = {}        -- M8.6-A: the search box (text color via SetTextColor on itself, plus a bg texture)

local function applyTheme()
	local theme = ns.Prefs.GetThemeColors(ns.Prefs.GetTheme())

	for _, fs in ipairs(themedFontStrings) do
		ns.Safe(fs.SetTextColor, fs, theme.panelText[1], theme.panelText[2], theme.panelText[3], theme.panelText[4])
	end
	for _, b in ipairs(themedPrimaryButtons) do
		b.bg:SetColorTexture(unpack(theme.primaryButtonBG))
		ns.Safe(b.text.SetTextColor, b.text, theme.buttonText[1], theme.buttonText[2], theme.buttonText[3], theme.buttonText[4])
	end
	for _, b in ipairs(themedSecondaryButtons) do
		b.bg:SetColorTexture(unpack(theme.secondaryButtonBG))
		ns.Safe(b.text.SetTextColor, b.text, theme.buttonText[1], theme.buttonText[2], theme.buttonText[3], theme.buttonText[4])
	end
	for _, t in ipairs(themedWindowBGs) do
		t:SetColorTexture(unpack(theme.windowBG))
	end
	for _, t in ipairs(themedBorders) do
		t:SetColorTexture(unpack(theme.border))
	end
	for _, eb in ipairs(themedEditBoxes) do
		eb.bg:SetColorTexture(unpack(theme.secondaryButtonBG))
		ns.Safe(eb.SetTextColor, eb, theme.buttonText[1], theme.buttonText[2], theme.buttonText[3], theme.buttonText[4])
	end

	if themeToggleBtn then
		themeToggleBtn.text:SetText("Theme: " .. (ns.Prefs.GetTheme() == "dark" and "Dark" or "Classic"))
	end
	if modeToggleBtn then
		modeToggleBtn.text:SetText("View: " .. (ns.Prefs.GetUIMode() == "compact" and "Compact" or "Detailed"))
	end

	-- Tab active/inactive coloring depends on which tab is active, not just the theme -- recompute it
	-- through the same single code path setActiveTab already uses, rather than duplicating that logic here.
	if frame then
		setActiveTabTheme()
	end
	if colorProgressSegments then
		colorProgressSegments()
	end
end

--- M8.6-A: switches between "detailed" and "compact" layouts. Unlike applyTheme() (pure recoloring, no
-- layout change), a mode switch changes which lines are shown AND how the remaining ones are anchored, so
-- it re-runs the full route-step render rather than looping over a themedXxx registry.
local function applyUIMode()
	if frame and renderRouteStep then
		renderRouteStep()
	end
	if themeToggleBtn and modeToggleBtn then
		modeToggleBtn.text:SetText("View: " .. (ns.Prefs.GetUIMode() == "compact" and "Compact" or "Detailed"))
	end
end

-- Step-kind -> glyph. Tried as real Unicode emoji first, per the M8.3 request's own vocabulary. This has
-- NOT been confirmed to render as a picture on Forever's default UI font (M8.1 only confirmed plain ASCII
-- text via GameFontNormal); if the manual real-client test in docs/M8_3_COMPLETION_REPORT.md finds these
-- render as blank boxes or missing glyphs, swap this one table for FALLBACK_KIND_GLYPH below -- nothing
-- else in this file needs to change, since every glyph lookup goes through kindGlyph().
local KIND_GLYPH = {
	ACCEPT = "\226\173\144",     -- U+2B50 WHITE MEDIUM STAR (UTF-8 bytes, avoids relying on the source
	TALK = "\226\173\144",       -- file's own encoding being preserved character-for-character in transit)
	TURN_IN = "\226\173\144",
	OBJECTIVE = "\226\154\148",  -- U+2694 CROSSED SWORDS
	TRAVEL = "\240\159\147\141", -- U+1F4CD ROUND PUSHPIN
}
local FALLBACK_KIND_GLYPH = {
	ACCEPT = "[*]", TALK = "[*]", TURN_IN = "[*]", OBJECTIVE = "[X]", TRAVEL = "[>]",
}
-- Real-client validation (docs/M8_3_REAL_CLIENT_VALIDATION.md) found all three emoji glyphs render as
-- blank/empty "tofu" boxes on Forever's default UI font -- confirmed on every kind (ACCEPT/TRAVEL/OBJECTIVE/
-- TURN_IN), not a per-glyph issue. Switched to the plain-text fallback as a result of that finding.
local USE_EMOJI_GLYPHS = false

local function kindGlyph(kind)
	local tbl = USE_EMOJI_GLYPHS and KIND_GLYPH or FALLBACK_KIND_GLYPH
	return tbl[kind] or "[?]"
end

local function questOrder()
	return ns.QuestOrder or {}
end

local function guideQuestCount()
	local n = 0
	for _ in pairs(ns.QuestData or {}) do
		n = n + 1
	end
	return n
end

-- M8.6-A: local, plain-substring filtering only (no fuzzy matching, no ranking, per the request). Matches
-- title OR giver name, case-insensitively. Uses string.find with plain=true so a quest title or giver name
-- containing a Lua pattern-magic character (e.g. a literal "%") can never turn into a malformed pattern or
-- error -- it is always treated as a literal substring search.
local function matchesFilter(q, needleLower)
	if needleLower == "" then
		return true
	end
	local title = (q.title or ""):lower()
	local giver = (q.giver and q.giver.name or ""):lower()
	return title:find(needleLower, 1, true) ~= nil or giver:find(needleLower, 1, true) ~= nil
end

--- Filters ns.QuestOrder by the current search text. Reads only from the existing, unmodified Data.lua --
-- no second quest-data source, no new fields, nothing written back to Data.lua or anywhere else.
local function filteredQuestOrder()
	local needleLower = filterText:lower()
	if needleLower == "" then
		return questOrder()
	end
	local out = {}
	for _, qid in ipairs(questOrder()) do
		local q = ns.QuestData and ns.QuestData[qid]
		if q and matchesFilter(q, needleLower) then
			table.insert(out, qid)
		end
	end
	return out
end

local function routeOrder()
	return ns.RouteOrder or {}
end

local function routeCount()
	local n = 0
	for _ in pairs(ns.Routes or {}) do
		n = n + 1
	end
	return n
end

-- Creates a FontString and tries to give it a readable font. GameFontNormal
-- is Blizzard's own default-UI font object and is expected to already exist
-- by the time an addon's ADDON_LOADED-triggered code runs; M8.1's real-client
-- test confirmed it renders correctly. Kept going through ns.Safe anyway,
-- unchanged from M8.1, since nothing here needs to re-verify that finding.
local function newFontString(parent, layer)
	local fs = parent:CreateFontString(nil, layer or "OVERLAY")
	local ok = ns.Safe(fs.SetFontObject, fs, GameFontNormal)
	if not ok then
		ns.Safe(fs.SetFont, fs, "Fonts\\FRIZQT__.TTF", 12, "")
	end
	table.insert(themedFontStrings, fs)  -- M8.5: applyTheme() recolors every registered FontString in one pass
	return fs
end

local function newRowButton(parent, w, h)
	local b = CreateFrame("Button", nil, parent)
	b:SetSize(w, h)
	b.bg = b:CreateTexture(nil, "BACKGROUND")
	b.bg:SetAllPoints()
	b.bg:SetColorTexture(0, 0, 0, 0)
	b.text = newFontString(b, "OVERLAY")
	b.text:SetPoint("LEFT", b, "LEFT", 4, 0)
	b.text:SetPoint("RIGHT", b, "RIGHT", -4, 0)
	b.text:SetJustifyH("LEFT")
	b:SetScript("OnEnter", function(self)
		self.bg:SetColorTexture(1, 1, 1, 0.15)
	end)
	b:SetScript("OnLeave", function(self)
		self.bg:SetColorTexture(0, 0, 0, 0)
	end)
	return b
end

-- ============================================================ QUESTS tab (M8.1, unchanged behavior)

local function renderDetail(questID)
	local q = questID and ns.QuestData and ns.QuestData[questID]

	if not q then
		detailTitle:SetText("(select a quest from the list)")
		detailLevel:SetText("")
		detailGiver:SetText("")
		detailPos:SetText("")
		for _, line in ipairs(detailObjectiveLines) do
			line:Hide()
		end
		return
	end

	detailTitle:SetText(string.format("[%d] %s", q.id, q.title))
	detailLevel:SetText("Level " .. tostring(q.level))
	detailGiver:SetText((q.giver and q.giver.name) and ("Giver: " .. q.giver.name) or "Giver: Unknown")
	if q.pos then
		detailPos:SetText(string.format("Position: map %d (%.3f, %.3f)", q.pos.ui_map_id, q.pos.x, q.pos.y))
	else
		detailPos:SetText("Position: Unknown")
	end

	for _, line in ipairs(detailObjectiveLines) do
		line:Hide()
	end
	for i, text in ipairs(q.objectives or {}) do
		local line = detailObjectiveLines[i]
		if not line then
			line = newFontString(frame.detailPanel, "OVERLAY")
			line:SetWidth(DETAIL_WIDTH)
			line:SetJustifyH("LEFT")
			line:SetPoint("TOPLEFT", detailObjectivesHeader, "BOTTOMLEFT", 0, -4 - (i - 1) * 14)
			detailObjectiveLines[i] = line
		end
		-- The recorder's own known blank-item-name pattern (M6/M7.9) means an
		-- objective's text can legitimately be "" -- shown as-is here, never
		-- replaced with fabricated content; only a plain notice that the
		-- text itself was not captured, distinct from the objective's own text.
		line:SetText((text ~= "" and text) or "(objective text not captured)")
		line:Show()
	end
end

local function refreshList()
	local order = filteredQuestOrder()  -- M8.6-A: was questOrder(); empty search text returns questOrder() unchanged
	for i = 1, VISIBLE_ROWS do
		local idx = i + scrollOffset
		local btn = listButtons[i]
		local questID = order[idx]
		local q = questID and ns.QuestData and ns.QuestData[questID]
		if q then
			btn.text:SetText(string.format("[%d] %s (Lvl %d)", q.id, q.title, q.level))
			btn.questID = questID
			btn:Show()
		else
			btn.questID = nil
			btn:Hide()
		end
	end
end

local function selectQuest(questID)
	selectedQuestID = questID
	renderDetail(questID)
end

-- ============================================================ ROUTE tab (M8.3, new)

--- Returns (route, order) for the currently selected route, or (nil, nil) if none exists.
local function currentRouteAndOrder()
	if not currentRouteID or not ns.Routes then
		return nil, nil
	end
	local route = ns.Routes[currentRouteID]
	if not route then
		return nil, nil
	end
	return route, route.step_order or {}
end

--- Formats a step's destination line. Provenance is always stated explicitly, never implied.
local function formatDestination(dest)
	if not dest then
		return "Destination: not captured (see step notes above)"
	end
	if dest.kind == "OBSERVED_PLAYER_POSITION" then
		return string.format(
			"Destination: map %d (%.3f, %.3f)  [M6-observed player position at this quest's own checkpoint -- not a surveyed NPC location]",
			dest.ui_map_id, dest.x, dest.y)
	elseif dest.kind == "ROUTE_AUTHORED" then
		return "Destination: " .. tostring(dest.text) .. "  [route-authored note]"
	elseif dest.kind == "SOURCE_DERIVED_ATT" then
		-- Not expected to ever appear (the generator refuses to emit one -- see
		-- generate_route_data.py's _forbid_source_derived), but labeled honestly if it somehow did.
		return string.format("Destination: map %d (%.3f, %.3f)  [ATT source-derived, unverified provenance]",
			dest.ui_map_id, dest.x, dest.y)
	end
	return "Destination: (unrecognized destination kind)"
end

--- Builds the main body line for a step by looking up LIVE quest content from ns.QuestData -- a step
-- never carries its own copy of a quest's title or objective text (see RouteData.lua's header comment).
local function formatStepBody(step)
	local q = step.quest_id and ns.QuestData and ns.QuestData[step.quest_id]
	if step.kind == "ACCEPT" then
		return "Accept: " .. (q and q.title or string.format("(quest %s not found in current data)", tostring(step.quest_id)))
	elseif step.kind == "TURN_IN" then
		return "Turn in: " .. (q and q.title or string.format("(quest %s not found in current data)", tostring(step.quest_id)))
	elseif step.kind == "TALK" then
		return step.npc and ("Talk to: " .. step.npc.name) or "Talk to NPC"
	elseif step.kind == "OBJECTIVE" then
		if q and step.objective_index and q.objectives and q.objectives[step.objective_index] then
			local text = q.objectives[step.objective_index]
			return "Objective: " .. ((text ~= "" and text) or "(objective text not captured)")
		end
		return "Objective: (not found in current data)"
	elseif step.kind == "TRAVEL" then
		return "Travel"
	end
	return ""
end

--- M8.6-A: builds/resizes the N-segment progress bar for the given step count, and colors every segment
-- (filled up through `filledCount`) using the CURRENT theme. Rebuilt whenever the step count could differ
-- (only relevant if a future route has a different length than the last one shown) and recolored on every
-- render and every theme change, via the same shared function so the two can never disagree.
colorProgressSegments = function()
	local theme = ns.Prefs.GetThemeColors(ns.Prefs.GetTheme())
	local _, order = currentRouteAndOrder()
	local total = order and #order or 0
	for i, seg in ipairs(routeProgressSegments) do
		if i <= total and i <= currentStepIndex then
			seg:SetColorTexture(unpack(theme.primaryButtonBG))
		else
			seg:SetColorTexture(unpack(theme.tabInactiveBG))
		end
	end
end

local function layoutProgressBar(total)
	local rowWidth = LIST_WIDTH + DETAIL_WIDTH + 16
	local gap = 2
	local segWidth = (rowWidth - gap * (total - 1)) / math.max(total, 1)
	for i = 1, total do
		local seg = routeProgressSegments[i]
		if not seg then
			seg = routeProgressRow:CreateTexture(nil, "ARTWORK")
			routeProgressSegments[i] = seg
		end
		seg:ClearAllPoints()
		seg:SetSize(segWidth, 6)
		seg:SetPoint("LEFT", routeProgressRow, "LEFT", (i - 1) * (segWidth + gap), 0)
		seg:Show()
	end
	for i = total + 1, #routeProgressSegments do
		routeProgressSegments[i]:Hide()
	end
end

--- Anchors a FontString below `anchorAbove` (or hides+skips it if `show` is false), returning whichever
-- widget the NEXT element in the chain should anchor below. This is what lets compact mode close the gaps
-- left by hidden lines instead of just leaving blank space -- WoW does not reflow layouts automatically, so
-- every anchor in the chain is recomputed explicitly, every render, based on what's actually visible.
local function chainBelow(anchorAbove, widget, show, gapY, widthOverride)
	if not show then
		widget:Hide()
		return anchorAbove
	end
	widget:ClearAllPoints()
	widget:SetPoint("TOPLEFT", anchorAbove, "BOTTOMLEFT", 0, -gapY)
	if widthOverride then
		widget:SetWidth(widthOverride)
	end
	widget:Show()
	return widget
end

local function getPreviewSteps(route, order)
	local out = {}
	for i = 1, PREVIEW_STEP_COUNT do
		local idx = currentStepIndex + i
		if idx > #order then
			break
		end
		table.insert(out, { label = PREVIEW_LABELS[i], step = route.steps[order[idx]] })
	end
	return out
end

local function renderPreviewToggleLabel()
	previewToggleBtn.text:SetText("UP NEXT " .. (previewCollapsed and "[+]" or "[-]"))
end

renderRouteStep = function()
	local route, order = currentRouteAndOrder()
	local ROW_WIDTH = LIST_WIDTH + DETAIL_WIDTH + 16
	local compact = (ns.Prefs.GetUIMode() == "compact")

	if not route or #order == 0 then
		routeTitleFS:SetText("(no route available)")
		routeStepCounterFS:SetText("")
		routeKindFS:SetText("")
		routeRequiredFS:SetText("")
		routeQuestFS:SetText("")
		routeNpcFS:Hide()
		routeBodyFS:SetText("")
		routeInstructionFS:Hide()
		routeWhyHeaderFS:Hide()
		routeWhyTextFS:Hide()
		routeDestFS:SetText("")
		layoutProgressBar(0)
		previewToggleBtn:Hide()
		for _, pl in ipairs(previewLines) do
			pl.kindFS:Hide()
			pl.bodyFS:Hide()
		end
		return
	end

	if currentStepIndex < 1 then
		currentStepIndex = 1
	elseif currentStepIndex > #order then
		currentStepIndex = #order
	end

	local stepID = order[currentStepIndex]
	local step = route.steps[stepID]
	local q = step.quest_id and ns.QuestData and ns.QuestData[step.quest_id]

	-- Priority order per the request's "Sticky current step" section: step number, step type, main
	-- instruction, quest title, objective, destination. Fixed-position elements (title, counter, progress,
	-- kind+badge) are always shown; everything from here down is chained via chainBelow() so hidden lines
	-- (compact mode) close up instead of leaving gaps.
	routeTitleFS:SetText(route.title)
	routeTitleFS:Show()
	routeStepCounterFS:SetText(string.format("STEP %d OF %d", currentStepIndex, #order))
	routeStepCounterFS:Show()
	layoutProgressBar(#order)
	colorProgressSegments()
	routeKindFS:SetText(string.format("%s %s", kindGlyph(step.kind), step.kind))
	routeKindFS:Show()
	if step.required == true then
		routeRequiredFS:SetText("REQUIRED")
	elseif step.required == false then
		routeRequiredFS:SetText("OPTIONAL")
	else
		routeRequiredFS:SetText("")  -- omitted by the author: no claim either way, per route_schema.py
	end

	routeQuestFS:SetText(q and string.format("Quest: [%d] %s (Lvl %d)", q.id, q.title, q.level) or "")
	routeQuestFS:Show()

	local cursor = routeQuestFS
	cursor = chainBelow(cursor, routeNpcFS, not compact and step.npc ~= nil, 6, ROW_WIDTH)
	if not compact and step.npc then
		routeNpcFS:SetText("NPC: " .. step.npc.name)
	end

	routeBodyFS:SetText(formatStepBody(step))
	cursor = chainBelow(cursor, routeBodyFS, true, 8, ROW_WIDTH)

	cursor = chainBelow(cursor, routeInstructionFS, not compact, 8, ROW_WIDTH)
	if not compact then
		routeInstructionFS:SetText(step.display_text or "")
	end

	local hasWhy = (not compact) and type(step.why) == "string" and step.why ~= ""
	cursor = chainBelow(cursor, routeWhyHeaderFS, hasWhy, 10, ROW_WIDTH)
	if hasWhy then
		routeWhyHeaderFS:SetText("Why this step?")
	end
	cursor = chainBelow(cursor, routeWhyTextFS, hasWhy, 2, ROW_WIDTH)
	if hasWhy then
		routeWhyTextFS:SetText(step.why)
	end

	routeDestFS:SetText(formatDestination(step.destination))
	cursor = chainBelow(cursor, routeDestFS, true, 10, ROW_WIDTH)

	-- Preview: hidden entirely in compact mode (per the request's "hide or minimize ... larger previews"),
	-- never shows a PAST step, and never advances/changes the authored route -- it is read-only display.
	if compact then
		previewToggleBtn:Hide()
		for _, pl in ipairs(previewLines) do
			pl.kindFS:Hide()
			pl.bodyFS:Hide()
		end
	else
		cursor = chainBelow(cursor, previewToggleBtn, true, 14, nil)
		renderPreviewToggleLabel()
		if previewCollapsed then
			for _, pl in ipairs(previewLines) do
				pl.kindFS:Hide()
				pl.bodyFS:Hide()
			end
		else
			local previews = getPreviewSteps(route, order)
			for i = 1, PREVIEW_STEP_COUNT do
				local entry = previews[i]
				local pl = previewLines[i]
				if not pl then
					pl = { kindFS = newFontString(frame.routePanel, "OVERLAY"), bodyFS = newFontString(frame.routePanel, "OVERLAY") }
					previewLines[i] = pl
				end
				if entry then
					pl.kindFS:SetText(string.format("%s %s %s", entry.label, kindGlyph(entry.step.kind), entry.step.kind))
					pl.bodyFS:SetText(formatStepBody(entry.step))
					cursor = chainBelow(cursor, pl.kindFS, true, (i == 1) and 6 or 10, ROW_WIDTH)
					cursor = chainBelow(cursor, pl.bodyFS, true, 2, ROW_WIDTH)
				else
					pl.kindFS:Hide()
					pl.bodyFS:Hide()
				end
			end
		end
	end

	if currentStepIndex >= #order then
		routeNextBtn.text:SetText("Route Complete")
	else
		routeNextBtn.text:SetText("NEXT ->")
	end
end

local function routeNext()
	local _, order = currentRouteAndOrder()
	if order and currentStepIndex < #order then
		currentStepIndex = currentStepIndex + 1
		renderRouteStep()
	end
	-- At the final step this is intentionally a no-op (not an error): the button already reads
	-- "Route Complete" per renderRouteStep(), so clicking it again simply does nothing.
end

local function routePrevious()
	if currentStepIndex > 1 then
		currentStepIndex = currentStepIndex - 1
		renderRouteStep()
	end
	-- At the first step this is intentionally a no-op.
end

local function selectRoute(routeID)
	currentRouteID = routeID
	currentStepIndex = 1
	renderRouteStep()
end

-- ============================================================ tab switching

-- Show()/Hide() only -- not :SetShown(bool), which M8.1's real-client test never exercised.
local function showOrHide(widget, shown)
	if shown then
		widget:Show()
	else
		widget:Hide()
	end
end

-- Colors the tab buttons for whichever tab is currently active, using the CURRENT theme -- the one piece
-- of coloring that depends on state (which tab) as well as theme, so it can't just be a themedXxx registry
-- loop like everything else applyTheme() handles. Called both from setActiveTab (tab changed) and from
-- applyTheme (theme changed, tab unchanged) so the two triggers never fall out of sync with each other.
setActiveTabTheme = function()
	local theme = ns.Prefs.GetThemeColors(ns.Prefs.GetTheme())
	local showQuests = (activeTab == "QUESTS")
	questsTabBtn.bg:SetColorTexture(unpack(showQuests and theme.tabActiveBG or theme.tabInactiveBG))
	routeTabBtn.bg:SetColorTexture(unpack((not showQuests) and theme.tabActiveBG or theme.tabInactiveBG))
end

local function setActiveTab(tab)
	activeTab = tab
	local showQuests = (tab == "QUESTS")
	showOrHide(frame.listPanel, showQuests)
	showOrHide(frame.detailPanel, showQuests)
	showOrHide(frame.listHeader, showQuests)
	showOrHide(frame.searchLabel, showQuests)  -- M8.6-A
	showOrHide(frame.searchBox, showQuests)    -- M8.6-A
	showOrHide(frame.routePanel, not showQuests)
	showOrHide(frame.routeHeader, not showQuests)
	setActiveTabTheme()
end

-- ============================================================ build

local function newTabButton(parent, label)
	local b = CreateFrame("Button", nil, parent)
	b:SetSize(90, 22)
	b.bg = b:CreateTexture(nil, "BACKGROUND")
	b.bg:SetAllPoints()
	b.bg:SetColorTexture(0.15, 0.15, 0.15, 1)
	b.text = newFontString(b, "OVERLAY")
	b.text:SetPoint("CENTER")
	b.text:SetText(label)
	return b
end

-- role: "primary" (strong visual emphasis, e.g. NEXT) or "secondary" (visible but less prominent, e.g.
-- PREVIOUS, Show on Map). Defaults to "secondary" if omitted. Registers into the matching themedXxx table
-- so applyTheme() colors it; the initial SetColorTexture below is only a neutral placeholder until the
-- build()-time applyTheme() call authoritatively sets every button's real color in one pass.
local function newWideButton(parent, w, h, label, role)
	local b = CreateFrame("Button", nil, parent)
	b:SetSize(w, h)
	b.bg = b:CreateTexture(nil, "BACKGROUND")
	b.bg:SetAllPoints()
	b.bg:SetColorTexture(0.25, 0.25, 0.25, 0.9)
	b.text = newFontString(b, "OVERLAY")
	b.text:SetPoint("CENTER")
	b.text:SetText(label)
	if role == "primary" then
		table.insert(themedPrimaryButtons, b)
	else
		table.insert(themedSecondaryButtons, b)
	end
	return b
end

local function build()
	frame = CreateFrame("Frame", "ForeverQuestGuideFrame", UIParent)
	local questsTabHeight = VISIBLE_ROWS * ROW_HEIGHT + 60 - PANEL_TOP_OFFSET - 46
	local routeTabHeight = -PANEL_TOP_OFFSET + ROUTE_PANEL_HEIGHT + 40  -- +40: bottom margin for Prev/Next
	frame:SetSize(LIST_WIDTH + DETAIL_WIDTH + 48, math.max(questsTabHeight, routeTabHeight))
	frame:SetPoint("CENTER")
	frame:SetMovable(true)
	frame:EnableMouse(true)
	frame:RegisterForDrag("LeftButton")
	frame:SetScript("OnDragStart", frame.StartMoving)
	frame:SetScript("OnDragStop", frame.StopMovingOrSizing)

	local bg = frame:CreateTexture(nil, "BACKGROUND")
	bg:SetAllPoints()
	bg:SetColorTexture(0, 0, 0, 0.85)
	table.insert(themedWindowBGs, bg)

	local border = frame:CreateTexture(nil, "BORDER")
	border:SetPoint("TOPLEFT", frame, "TOPLEFT", -1, 1)
	border:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 1, -1)
	border:SetColorTexture(1, 1, 1, 0.25)
	table.insert(themedBorders, border)

	local title = newFontString(frame, "OVERLAY")
	title:SetPoint("TOP", frame, "TOP", 0, -10)
	title:SetText("WoW Forever Guide (prototype)")

	local closeBtn = CreateFrame("Button", nil, frame)
	closeBtn:SetSize(20, 20)
	closeBtn:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -6, -6)
	closeBtn.text = newFontString(closeBtn, "OVERLAY")
	closeBtn.text:SetPoint("CENTER")
	closeBtn.text:SetText("X")
	closeBtn:SetScript("OnClick", function()
		frame:Hide()
	end)

	-- Discoverable appearance switch (M8.5): a small button, not a settings framework, per the request's
	-- own "do not build a large settings framework" -- clicking it cycles Classic <-> Dark and re-applies
	-- immediately. `/fguide theme classic|dark` (Core.lua) does the same thing as a second, scriptable path.
	themeToggleBtn = newWideButton(frame, 90, 20, "", "secondary")
	themeToggleBtn:SetPoint("TOPRIGHT", closeBtn, "BOTTOMRIGHT", 0, -4)
	themeToggleBtn:SetScript("OnClick", function()
		local nextTheme = (ns.Prefs.GetTheme() == "classic") and "dark" or "classic"
		ns.Prefs.SetTheme(nextTheme)
		applyTheme()
	end)

	-- M8.6-A: the same small, discoverable pattern as the theme toggle -- not a settings framework.
	modeToggleBtn = newWideButton(frame, 90, 20, "", "secondary")
	modeToggleBtn:SetPoint("TOPRIGHT", themeToggleBtn, "BOTTOMRIGHT", 0, -4)
	modeToggleBtn:SetScript("OnClick", function()
		local nextMode = (ns.Prefs.GetUIMode() == "detailed") and "compact" or "detailed"
		ns.Prefs.SetUIMode(nextMode)
		applyUIMode()
	end)

	-- tab bar
	questsTabBtn = newTabButton(frame, "QUESTS")
	questsTabBtn:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -30)
	questsTabBtn:SetScript("OnClick", function()
		setActiveTab("QUESTS")
	end)

	routeTabBtn = newTabButton(frame, "ROUTE")
	routeTabBtn:SetPoint("LEFT", questsTabBtn, "RIGHT", 4, 0)
	routeTabBtn:SetScript("OnClick", function()
		setActiveTab("ROUTE")
	end)

	-- left pane: quest list
	local listPanel = CreateFrame("Frame", nil, frame)
	listPanel:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, PANEL_TOP_OFFSET)
	listPanel:SetSize(LIST_WIDTH, VISIBLE_ROWS * ROW_HEIGHT)
	frame.listPanel = listPanel

	-- M8.6-A search box. Fits in the existing gap between the tab bar (bottom edge ~-52) and the quest
	-- list/header (top edge PANEL_TOP_OFFSET, -78) without needing to grow the window -- no layout change
	-- needed for the QUESTS tab beyond this one new row.
	searchLabel = newFontString(frame, "OVERLAY")
	searchLabel:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -58)
	searchLabel:SetText("Search:")

	searchBox = CreateFrame("EditBox", nil, frame)
	searchBox:SetSize(LIST_WIDTH - 54, 18)
	searchBox:SetPoint("LEFT", searchLabel, "RIGHT", 4, 0)
	searchBox:SetAutoFocus(false)
	ns.Safe(searchBox.SetMaxLetters, searchBox, 50)
	ns.Safe(searchBox.SetFontObject, searchBox, GameFontNormal)
	searchBox.bg = searchBox:CreateTexture(nil, "BACKGROUND")
	searchBox.bg:SetAllPoints()
	searchBox.bg:SetColorTexture(0.15, 0.15, 0.15, 0.9)
	table.insert(themedEditBoxes, searchBox)
	searchBox:SetScript("OnTextChanged", function(self)
		filterText = self:GetText() or ""
		scrollOffset = 0
		refreshList()
	end)
	searchBox:SetScript("OnEscapePressed", function(self)
		ns.Safe(self.ClearFocus, self)
	end)
	frame.searchLabel = searchLabel
	frame.searchBox = searchBox

	local listHeader = newFontString(frame, "OVERLAY")
	listHeader:SetPoint("BOTTOMLEFT", listPanel, "TOPLEFT", 0, 4)
	listHeader:SetText(string.format("Quests (%d guide-ready)", guideQuestCount()))
	frame.listHeader = listHeader

	for i = 1, VISIBLE_ROWS do
		local btn = newRowButton(listPanel, LIST_WIDTH, ROW_HEIGHT)
		btn:SetPoint("TOPLEFT", listPanel, "TOPLEFT", 0, -(i - 1) * ROW_HEIGHT)
		btn:SetScript("OnClick", function(self)
			if self.questID then
				selectQuest(self.questID)
			end
		end)
		listButtons[i] = btn
	end

	listPanel:EnableMouseWheel(true)
	listPanel:SetScript("OnMouseWheel", function(self, delta)
		local maxOffset = math.max(0, #filteredQuestOrder() - VISIBLE_ROWS)  -- M8.6-A: filtered, not total
		scrollOffset = math.min(maxOffset, math.max(0, scrollOffset - delta))
		refreshList()
	end)

	-- right pane: quest detail
	local detailPanel = CreateFrame("Frame", nil, frame)
	detailPanel:SetPoint("TOPLEFT", listPanel, "TOPRIGHT", 16, 0)
	detailPanel:SetSize(DETAIL_WIDTH, VISIBLE_ROWS * ROW_HEIGHT)
	frame.detailPanel = detailPanel

	detailTitle = newFontString(detailPanel, "OVERLAY")
	detailTitle:SetWidth(DETAIL_WIDTH)
	detailTitle:SetJustifyH("LEFT")
	detailTitle:SetPoint("TOPLEFT", detailPanel, "TOPLEFT", 0, 0)

	detailLevel = newFontString(detailPanel, "OVERLAY")
	detailLevel:SetPoint("TOPLEFT", detailTitle, "BOTTOMLEFT", 0, -6)

	detailGiver = newFontString(detailPanel, "OVERLAY")
	detailGiver:SetPoint("TOPLEFT", detailLevel, "BOTTOMLEFT", 0, -6)

	detailPos = newFontString(detailPanel, "OVERLAY")
	detailPos:SetPoint("TOPLEFT", detailGiver, "BOTTOMLEFT", 0, -6)

	detailObjectivesHeader = newFontString(detailPanel, "OVERLAY")
	detailObjectivesHeader:SetPoint("TOPLEFT", detailPos, "BOTTOMLEFT", 0, -10)
	detailObjectivesHeader:SetText("Objectives:")

	-- Inert placeholder: see file header. Never attempts a map API call. Built via newWideButton (not a
	-- one-off manual construction) so it registers for theming exactly like the route Previous/Next
	-- buttons -- an inert placeholder should still look consistent with the rest of the window.
	local mapBtn = newWideButton(detailPanel, 120, 20, "Show on Map", "secondary")
	mapBtn:SetPoint("BOTTOMLEFT", detailPanel, "BOTTOMLEFT", 0, 0)
	mapBtn:SetScript("OnClick", function()
		ns.Say("Show on Map: not implemented -- no map-pin API has been confirmed on Forever yet (see docs/M8_0_SCOPE.md).")
	end)

	-- route pane. Taller than listPanel/detailPanel as of M8.6-A (see ROUTE_PANEL_HEIGHT) to fit the
	-- expanded detailed-mode content; the QUESTS tab simply has some unused space below it as a result --
	-- a deliberate, disclosed trade-off rather than a per-tab dynamic frame resize (see the completion
	-- report for the reasoning).
	local routePanel = CreateFrame("Frame", nil, frame)
	routePanel:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, PANEL_TOP_OFFSET)
	routePanel:SetSize(LIST_WIDTH + DETAIL_WIDTH + 16, ROUTE_PANEL_HEIGHT)
	frame.routePanel = routePanel
	local ROW_WIDTH = LIST_WIDTH + DETAIL_WIDTH + 16

	local routeHeader = newFontString(frame, "OVERLAY")
	routeHeader:SetPoint("BOTTOMLEFT", routePanel, "TOPLEFT", 0, 4)
	routeHeader:SetText(string.format("Routes (%d available)", routeCount()))
	frame.routeHeader = routeHeader

	routeTitleFS = newFontString(routePanel, "OVERLAY")
	routeTitleFS:SetPoint("TOPLEFT", routePanel, "TOPLEFT", 0, 0)
	routeTitleFS:SetWidth(ROW_WIDTH)
	routeTitleFS:SetJustifyH("LEFT")

	routeStepCounterFS = newFontString(routePanel, "OVERLAY")
	routeStepCounterFS:SetPoint("TOPLEFT", routeTitleFS, "BOTTOMLEFT", 0, -8)

	-- M8.6-A progress bar: a thin row of segment textures, one per route step, rebuilt/recolored by
	-- layoutProgressBar()/colorProgressSegments() inside renderRouteStep() -- nothing here needs a fixed
	-- segment count, since it's computed from the current route's own step_order length.
	routeProgressRow = CreateFrame("Frame", nil, routePanel)
	routeProgressRow:SetPoint("TOPLEFT", routeStepCounterFS, "BOTTOMLEFT", 0, -6)
	routeProgressRow:SetSize(ROW_WIDTH, 6)

	routeKindFS = newFontString(routePanel, "OVERLAY")
	routeKindFS:SetPoint("TOPLEFT", routeProgressRow, "BOTTOMLEFT", 0, -8)

	-- M8.6-A REQUIRED/OPTIONAL badge: shown or left blank (never a default claim) -- see renderRouteStep().
	routeRequiredFS = newFontString(routePanel, "OVERLAY")
	routeRequiredFS:SetPoint("LEFT", routeKindFS, "RIGHT", 12, 0)

	routeQuestFS = newFontString(routePanel, "OVERLAY")
	routeQuestFS:SetPoint("TOPLEFT", routeKindFS, "BOTTOMLEFT", 0, -8)
	routeQuestFS:SetWidth(ROW_WIDTH)
	routeQuestFS:SetJustifyH("LEFT")

	-- Everything from here down is dynamically re-anchored every render via chainBelow() (see
	-- renderRouteStep()), so the anchors set here are only a harmless initial position before the first
	-- render call overwrites them -- compact mode needs this to close gaps left by hidden lines.
	routeNpcFS = newFontString(routePanel, "OVERLAY")
	routeNpcFS:SetPoint("TOPLEFT", routeQuestFS, "BOTTOMLEFT", 0, -6)

	routeBodyFS = newFontString(routePanel, "OVERLAY")
	routeBodyFS:SetPoint("TOPLEFT", routeNpcFS, "BOTTOMLEFT", 0, -8)
	routeBodyFS:SetWidth(ROW_WIDTH)
	routeBodyFS:SetJustifyH("LEFT")

	routeInstructionFS = newFontString(routePanel, "OVERLAY")
	routeInstructionFS:SetPoint("TOPLEFT", routeBodyFS, "BOTTOMLEFT", 0, -8)
	routeInstructionFS:SetWidth(ROW_WIDTH)
	routeInstructionFS:SetJustifyH("LEFT")

	-- M8.6-A "Why this step?" -- route-authored, optional, omitted entirely (not shown blank) when absent.
	routeWhyHeaderFS = newFontString(routePanel, "OVERLAY")
	routeWhyHeaderFS:SetPoint("TOPLEFT", routeInstructionFS, "BOTTOMLEFT", 0, -10)

	routeWhyTextFS = newFontString(routePanel, "OVERLAY")
	routeWhyTextFS:SetPoint("TOPLEFT", routeWhyHeaderFS, "BOTTOMLEFT", 0, -2)
	routeWhyTextFS:SetWidth(ROW_WIDTH)
	routeWhyTextFS:SetJustifyH("LEFT")

	routeDestFS = newFontString(routePanel, "OVERLAY")
	routeDestFS:SetPoint("TOPLEFT", routeWhyTextFS, "BOTTOMLEFT", 0, -10)
	routeDestFS:SetWidth(ROW_WIDTH)
	routeDestFS:SetJustifyH("LEFT")

	-- M8.6-A preview: a plain Button used only as a clickable collapse/expand header (not a route-step
	-- selector -- per the request, the preview is deliberately non-clickable for step inspection, avoiding
	-- the added complexity of a separate "BACK TO CURRENT STEP" control the request explicitly allows
	-- skipping in that case). Its own label text is set by renderPreviewToggleLabel() each render.
	previewToggleBtn = CreateFrame("Button", nil, routePanel)
	previewToggleBtn:SetSize(ROW_WIDTH, 16)
	previewToggleBtn:SetPoint("TOPLEFT", routeDestFS, "BOTTOMLEFT", 0, -14)
	previewToggleBtn.text = newFontString(previewToggleBtn, "OVERLAY")
	previewToggleBtn.text:SetPoint("LEFT", previewToggleBtn, "LEFT", 0, 0)
	previewToggleBtn:SetScript("OnClick", function()
		previewCollapsed = not previewCollapsed
		renderRouteStep()
	end)
	-- previewLines[1..PREVIEW_STEP_COUNT] are created lazily inside renderRouteStep(), the same pattern
	-- M8.1's detailObjectiveLines already established for a variable-length list of FontStrings.

	routePrevBtn = newWideButton(routePanel, 120, 24, "<- PREVIOUS", "secondary")
	routePrevBtn:SetPoint("BOTTOMLEFT", routePanel, "BOTTOMLEFT", 0, 0)
	routePrevBtn:SetScript("OnClick", routePrevious)

	-- "primary": the M8.5 request calls specifically for NEXT to carry strong visual emphasis.
	routeNextBtn = newWideButton(routePanel, 120, 24, "NEXT ->", "primary")
	routeNextBtn:SetPoint("BOTTOMLEFT", routePrevBtn, "BOTTOMRIGHT", 8, 0)
	routeNextBtn:SetScript("OnClick", routeNext)

	-- pick the first available route deterministically (ns.RouteOrder's own order, never re-sorted here)
	if routeOrder()[1] then
		selectRoute(routeOrder()[1])
	end

	refreshList()
	renderDetail(nil)
	setActiveTab("QUESTS")
	applyTheme()  -- authoritative single pass: colors every registered element per the saved/default theme
end

local function toggle()
	if not frame then
		build()
	end
	if frame:IsShown() then
		frame:Hide()
	else
		frame:Show()
	end
end

ns.UI = { Toggle = toggle, ApplyTheme = applyTheme, ApplyUIMode = applyUIMode }

-- Test-only seam for the Lua-level self-test (addon_selftest/run_ui_selftest.lua).
-- Exposes internal state for inspection only; changes nothing about how the
-- real addon behaves in-game, and no in-game code path reads this table.
-- MERGED into ns._selftest (never reassigned wholesale) -- Core.lua, loaded earlier, already populated its
-- own key (fireAddonLoaded) on this same table, and overwriting the table here would silently erase it.
ns._selftest = ns._selftest or {}
ns._selftest.getFrame = function() return frame end
ns._selftest.getListButtons = function() return listButtons end
ns._selftest.getSelectedQuestID = function() return selectedQuestID end
ns._selftest.refreshList = refreshList
ns._selftest.getActiveTab = function() return activeTab end
ns._selftest.setActiveTab = setActiveTab
ns._selftest.getCurrentStepIndex = function() return currentStepIndex end
ns._selftest.getCurrentRouteID = function() return currentRouteID end
ns._selftest.routeNext = routeNext
ns._selftest.routePrevious = routePrevious
ns._selftest.getRouteButtons = function() return { prev = routePrevBtn, next = routeNextBtn } end
ns._selftest.getRouteFontStrings = function()
	return { title = routeTitleFS, counter = routeStepCounterFS, kind = routeKindFS, required = routeRequiredFS,
		quest = routeQuestFS, npc = routeNpcFS, body = routeBodyFS, instruction = routeInstructionFS,
		whyHeader = routeWhyHeaderFS, whyText = routeWhyTextFS, dest = routeDestFS }
end
ns._selftest.getThemeToggleButton = function() return themeToggleBtn end
ns._selftest.getThemedCounts = function()
	return { fontStrings = #themedFontStrings, primaryButtons = #themedPrimaryButtons,
		secondaryButtons = #themedSecondaryButtons, windowBGs = #themedWindowBGs, borders = #themedBorders,
		editBoxes = #themedEditBoxes }
end
-- M8.6-A test-only seams
ns._selftest.getModeToggleButton = function() return modeToggleBtn end
ns._selftest.getSearchBox = function() return searchBox end
ns._selftest.setFilterText = function(text)
	filterText = text or ""
	scrollOffset = 0
	refreshList()
end
ns._selftest.getFilteredQuestOrder = filteredQuestOrder
ns._selftest.getPreviewCollapsed = function() return previewCollapsed end
ns._selftest.getPreviewToggleButton = function() return previewToggleBtn end
ns._selftest.getPreviewLines = function() return previewLines end
ns._selftest.getProgressSegmentCount = function()
	local n = 0
	for _, seg in ipairs(routeProgressSegments) do
		if seg:IsShown() then n = n + 1 end
	end
	return n
end
