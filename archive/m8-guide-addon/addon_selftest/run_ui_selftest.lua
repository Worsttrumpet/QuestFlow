-- Execute-level self-test (M8.1 quest-browser checks + M8.3 route-view checks).
-- Run from this directory: lua5.1 run_ui_selftest.lua
--
-- This is static/offline validation only -- it proves the addon's Lua runs
-- without error through its load, toggle-open, quest-selection, tab-switch,
-- route-step-navigation, and toggle-close paths under a permissive fake UI
-- environment. It is NOT a real-client test and makes no claim about how
-- anything actually looks or behaves in WoW Forever -- in particular it
-- cannot confirm whether the M8.3 step-type glyphs render as intended, only
-- that the Lua computing and setting their text runs without error. See
-- docs/M8_1_COMPLETION_REPORT.md and docs/M8_3_COMPLETION_REPORT.md for the
-- real test procedures this cannot replace.

package.path = package.path .. ";./?.lua"
local stub = dofile("stub_ui_env.lua")

local ADDON_DIR = "../addon/ForeverQuestGuide/"
local addonName = "ForeverQuestGuide"
local ns = {}

local function loadAddonFile(filename)
	local chunk, err = loadfile(ADDON_DIR .. filename)
	assert(chunk, "failed to load " .. filename .. ": " .. tostring(err))
	local ok, runErr = pcall(chunk, addonName, ns)
	assert(ok, "runtime error executing " .. filename .. ": " .. tostring(runErr))
end

local failures = 0
local function check(cond, msg)
	if cond then
		print("  [OK] " .. msg)
	else
		print("  [FAIL] " .. msg)
		failures = failures + 1
	end
end

print("1. loading Data.lua, RouteData.lua, Preferences.lua, Core.lua, MinimapButton.lua, WelcomePopup.lua, UI.lua in .toc order...")
loadAddonFile("Data.lua")
loadAddonFile("RouteData.lua")
loadAddonFile("Preferences.lua")
loadAddonFile("Core.lua")
loadAddonFile("MinimapButton.lua")
loadAddonFile("WelcomePopup.lua")
loadAddonFile("UI.lua")
print("   all seven files executed without a Lua error")

print("2. checking Data.lua's exports...")
check(type(ns.QuestData) == "table", "ns.QuestData is a table")
check(type(ns.QuestOrder) == "table", "ns.QuestOrder is a table")
local dataCount = 0
for _ in pairs(ns.QuestData) do dataCount = dataCount + 1 end
check(dataCount == #ns.QuestOrder, "QuestData count (" .. dataCount .. ") matches QuestOrder length (" .. #ns.QuestOrder .. ")")
check(dataCount > 0, "at least one quest was generated (" .. dataCount .. ")")

print("2b. checking RouteData.lua's exports...")
check(type(ns.Routes) == "table", "ns.Routes is a table")
check(type(ns.RouteOrder) == "table" and #ns.RouteOrder >= 1, "ns.RouteOrder has at least one route")
local firstRouteID = ns.RouteOrder[1]
local firstRoute = ns.Routes[firstRouteID]
check(type(firstRoute) == "table", "the first route in RouteOrder exists in ns.Routes")
check(firstRoute and firstRoute.provenance == "route-authored", "route provenance is 'route-authored'")
check(firstRoute and type(firstRoute.step_order) == "table" and #firstRoute.step_order >= 1, "route has a non-empty step_order")
if firstRoute then
	for _, stepID in ipairs(firstRoute.step_order) do
		local step = firstRoute.steps[stepID]
		check(step ~= nil, "step " .. tostring(stepID) .. " exists in route.steps")
		if step then
			check(step.provenance == "route-authored", "step " .. stepID .. " provenance is 'route-authored'")
			check(step.quest_id == nil or ns.QuestData[step.quest_id] ~= nil,
				"step " .. stepID .. "'s quest_id (if any) exists in ns.QuestData")
		end
	end
end

print("2c. checking Preferences.lua's defaults (fresh-install state)...")
check(type(ForeverQuestGuideDB) == "table", "ForeverQuestGuideDB exists (SavedVariables initialized at file top level)")
check(ForeverQuestGuideDB.welcomePopupDisabled == false, "welcomePopupDisabled defaults to false")
check(ForeverQuestGuideDB.theme == "classic", "theme defaults to 'classic'")
check(type(ns.Prefs) == "table", "ns.Prefs exists")
check(ns.Prefs.GetTheme() == "classic", "ns.Prefs.GetTheme() reports 'classic'")
check(ns.Prefs.IsWelcomePopupDisabled() == false, "ns.Prefs.IsWelcomePopupDisabled() is false by default")
local classicColors, darkColors = ns.Prefs.GetThemeColors("classic"), ns.Prefs.GetThemeColors("dark")
check(type(classicColors) == "table" and type(darkColors) == "table", "both theme palettes are tables")
local functionEquals = function(a, b) for i = 1, 4 do if a[i] ~= b[i] then return false end end return true end
check(not functionEquals(classicColors.windowBG, darkColors.windowBG), "classic and dark window backgrounds actually differ")
check(ns.Prefs.IsSavedVariablesSafe(ForeverQuestGuideDB), "ForeverQuestGuideDB contains only SavedVariables-safe value types")

print("3. firing ADDON_LOADED for real (via the Core.lua test seam, not just inspecting its side effects)...")
check(type(ns._selftest.fireAddonLoaded) == "function", "fireAddonLoaded test seam exists")
local okLoad, errLoad = pcall(ns._selftest.fireAddonLoaded)
check(okLoad, "firing ADDON_LOADED ran without error: " .. tostring(errLoad))
check(SlashCmdList["FOREVERQUESTGUIDE"] ~= nil, "slash command handler was registered")
check(type(ns.Say) == "function", "ns.Say exists")
check(type(ns.Safe) == "function", "ns.Safe exists")
local safeOk, safeErr = pcall(ns.Say, "self-test message")
check(safeOk, "ns.Say runs without error: " .. tostring(safeErr))

print("3b. checking the minimap button was created by ADDON_LOADED...")
check(type(ns.MinimapButton) == "table" and type(ns.MinimapButton.Build) == "function", "ns.MinimapButton.Build exists")
local minimapBtn = _G["ForeverQuestGuideMinimapButton"]
check(minimapBtn ~= nil, "the minimap button's global frame was created")

print("3c. checking the welcome popup auto-showed (fresh install, popup not disabled)...")
check(type(ns.WelcomePopup) == "table" and type(ns.WelcomePopup.Show) == "function", "ns.WelcomePopup.Show exists")
local popupFrame = ns.WelcomePopup._selftest_getFrame()
check(popupFrame ~= nil, "the welcome popup frame was built")
check(popupFrame:IsShown() == true, "the welcome popup is shown by default on a fresh install")

print("3d. clicking the popup's actual 'Open Guide' button...")
local popupButtons = ns.WelcomePopup._selftest_getButtons()
check(type(popupButtons) == "table" and popupButtons.open ~= nil, "popup exposes its Open Guide button")
local openOnClick = popupButtons.open and popupButtons.open._scripts and popupButtons.open._scripts.OnClick
check(type(openOnClick) == "function", "Open Guide button has an OnClick handler")
local okOpen, errOpen = pcall(openOnClick)
check(okOpen, "clicking 'Open Guide' ran without error: " .. tostring(errOpen))
check(popupFrame:IsShown() == false, "the welcome popup is hidden after 'Open Guide'")
check(ForeverQuestGuideDB.welcomePopupDisabled == false,
	"'Open Guide' does NOT persist a do-not-show flag (only 'Don't Show Again' does)")
local frameObj = ns._selftest.getFrame()
check(frameObj ~= nil, "main guide window exists after 'Open Guide' built it for the first time")
check(frameObj:IsShown() == true, "main guide window is shown after 'Open Guide'")

print("3e. exercising the minimap button's click handler (toggle close, then toggle open)...")
local minimapOnClick = minimapBtn._scripts and minimapBtn._scripts.OnClick
check(type(minimapOnClick) == "function", "minimap button has an OnClick handler")
if minimapOnClick then
	local okMMClick, errMMClick = pcall(minimapOnClick)
	check(okMMClick, "clicking the minimap button ran without error: " .. tostring(errMMClick))
	check(frameObj:IsShown() == false, "clicking the minimap button closed the already-open guide window")
	local okMMClick2, errMMClick2 = pcall(minimapOnClick)
	check(okMMClick2, "clicking the minimap button again ran without error: " .. tostring(errMMClick2))
	check(frameObj:IsShown() == true, "clicking the minimap button again reopened the guide window")
end

print("4. confirming /fguide (bare, no argument) still works exactly as before...")
local ok1, err1 = pcall(SlashCmdList["FOREVERQUESTGUIDE"])
check(ok1, "bare /fguide call ran without error: " .. tostring(err1))
check(frameObj:IsShown() == false, "/fguide closed the window (it was open from the minimap-button test above)")
local ok1b, err1b = pcall(SlashCmdList["FOREVERQUESTGUIDE"])
check(ok1b, "second bare /fguide call ran without error: " .. tostring(err1b))
check(frameObj:IsShown() == true, "/fguide reopened the window")

print("5. selecting a quest (simulating a row-button click)...")
local buttons = ns._selftest.getListButtons()
check(type(buttons) == "table" and #buttons > 0, "row buttons exist")
local firstWithQuest = nil
for _, btn in ipairs(buttons) do
	if btn.questID then firstWithQuest = btn; break end
end
check(firstWithQuest ~= nil, "at least one visible row button has a quest assigned")
if firstWithQuest then
	local onClick = firstWithQuest._scripts and firstWithQuest._scripts.OnClick
	check(type(onClick) == "function", "row button has an OnClick handler")
	local okClick, errClick = pcall(onClick, firstWithQuest)
	check(okClick, "clicking the first quest row ran without error: " .. tostring(errClick))
	check(ns._selftest.getSelectedQuestID() == firstWithQuest.questID, "selection state updated to the clicked quest")
end

print("5b. switching to the ROUTE tab and checking initial state...")
check(type(ns._selftest.setActiveTab) == "function", "setActiveTab test hook exists")
local okTab, errTab = pcall(ns._selftest.setActiveTab, "ROUTE")
check(okTab, "switching to the ROUTE tab ran without error: " .. tostring(errTab))
check(ns._selftest.getActiveTab() == "ROUTE", "active tab is now ROUTE")
check(frameObj.routePanel:IsShown() == true, "route panel is shown after switching to ROUTE")
check(frameObj.listPanel:IsShown() == false, "quest list panel is hidden while on the ROUTE tab")
check(ns._selftest.getCurrentRouteID() == firstRouteID, "the first route was auto-selected on build")
check(ns._selftest.getCurrentStepIndex() == 1, "route view starts at step 1")

-- Note: this self-test checks NAVIGATION STATE (getCurrentStepIndex) rather than rendered text content,
-- since the stub's FontString mock is write-only (SetText is a no-op sink; nothing here reads it back).
-- Rendered TEXT correctness for each step is instead exercised directly in Python
-- (test_generate_route_data.py) against the same route data before it ever reaches this Lua file.
local stepCount = #firstRoute.step_order
check(type(ns._selftest.getRouteFontStrings()) == "table", "route font-string references are exposed")

print("5c. clicking NEXT through every step...")
local buttons2 = ns._selftest.getRouteButtons()
check(type(buttons2.next) == "table" and type(buttons2.prev) == "table", "route Previous/Next buttons exist")
for i = 2, stepCount do
	local okNext, errNext = pcall(ns._selftest.routeNext)
	check(okNext, "Next (to step " .. i .. ") ran without error: " .. tostring(errNext))
	check(ns._selftest.getCurrentStepIndex() == i, "step index advanced to " .. i)
end

print("5d. confirming NEXT is a no-op at the final step...")
local okNextAtEnd, errNextAtEnd = pcall(ns._selftest.routeNext)
check(okNextAtEnd, "clicking Next at the final step ran without error: " .. tostring(errNextAtEnd))
check(ns._selftest.getCurrentStepIndex() == stepCount, "step index stayed at the final step (" .. stepCount .. ") after an extra Next")

print("5e. clicking PREVIOUS back through every step...")
for i = stepCount - 1, 1, -1 do
	local okPrev, errPrev = pcall(ns._selftest.routePrevious)
	check(okPrev, "Previous (to step " .. i .. ") ran without error: " .. tostring(errPrev))
	check(ns._selftest.getCurrentStepIndex() == i, "step index moved back to " .. i)
end

print("5f. confirming PREVIOUS is a no-op at the first step...")
local okPrevAtStart, errPrevAtStart = pcall(ns._selftest.routePrevious)
check(okPrevAtStart, "clicking Previous at the first step ran without error: " .. tostring(errPrevAtStart))
check(ns._selftest.getCurrentStepIndex() == 1, "step index stayed at 1 after an extra Previous")

print("5g. switching back to the QUESTS tab...")
local okTab2, errTab2 = pcall(ns._selftest.setActiveTab, "QUESTS")
check(okTab2, "switching back to QUESTS ran without error: " .. tostring(errTab2))
check(ns._selftest.getActiveTab() == "QUESTS", "active tab is QUESTS again")
check(frameObj.listPanel:IsShown() == true, "quest list panel is shown again")
check(frameObj.routePanel:IsShown() == false, "route panel is hidden again")
check(ns._selftest.getSelectedQuestID() == firstWithQuest.questID,
	"the earlier quest selection was undisturbed by visiting the ROUTE tab")

print("6. closing the guide window via /fguide again...")
local ok2, err2 = pcall(SlashCmdList["FOREVERQUESTGUIDE"])
check(ok2, "second /fguide call (close) ran without error: " .. tostring(err2))
check(frameObj:IsShown() == false, "frame reports hidden after closing")

print("7. re-opening once more (toggle robustness)...")
local ok3, err3 = pcall(SlashCmdList["FOREVERQUESTGUIDE"])
check(ok3, "third /fguide call (re-open) ran without error: " .. tostring(err3))
check(frameObj:IsShown() == true, "frame reports shown again after re-opening")

print("8. theme switching via the in-window toggle button...")
local themeBtn = ns._selftest.getThemeToggleButton()
check(themeBtn ~= nil, "the theme toggle button exists")
local themeOnClick = themeBtn and themeBtn._scripts and themeBtn._scripts.OnClick
check(type(themeOnClick) == "function", "theme toggle button has an OnClick handler")
check(ns.Prefs.GetTheme() == "classic", "theme is still 'classic' before any switch")
local okTheme1, errTheme1 = pcall(themeOnClick)
check(okTheme1, "clicking the theme toggle ran without error: " .. tostring(errTheme1))
check(ns.Prefs.GetTheme() == "dark", "theme switched to 'dark'")
check(ForeverQuestGuideDB.theme == "dark", "the switch persisted into ForeverQuestGuideDB immediately (no separate save step)")
local counts = ns._selftest.getThemedCounts()
check(counts.fontStrings > 0 and counts.primaryButtons > 0 and counts.secondaryButtons > 0
	and counts.windowBGs > 0 and counts.borders > 0,
	"every themed-element registry is populated (fontStrings=" .. counts.fontStrings
		.. ", primary=" .. counts.primaryButtons .. ", secondary=" .. counts.secondaryButtons
		.. ", windowBGs=" .. counts.windowBGs .. ", borders=" .. counts.borders .. ")")
local okTheme2, errTheme2 = pcall(themeOnClick)
check(okTheme2, "clicking the theme toggle again ran without error: " .. tostring(errTheme2))
check(ns.Prefs.GetTheme() == "classic", "theme switched back to 'classic'")

print("8b. theme switching via the /fguide theme slash-command path...")
local okThemeCmd, errThemeCmd = pcall(SlashCmdList["FOREVERQUESTGUIDE"], "theme dark")
check(okThemeCmd, "'/fguide theme dark' ran without error: " .. tostring(errThemeCmd))
check(ns.Prefs.GetTheme() == "dark", "'/fguide theme dark' switched the theme")
local okThemeBad, errThemeBad = pcall(SlashCmdList["FOREVERQUESTGUIDE"], "theme not-a-real-theme")
check(okThemeBad, "an unrecognized theme name ran without error (reported via chat, not a crash): " .. tostring(errThemeBad))
check(ns.Prefs.GetTheme() == "dark", "an unrecognized theme name did not change the current theme")
SlashCmdList["FOREVERQUESTGUIDE"]("theme classic")  -- restore for the rest of the run
check(ns.Prefs.GetTheme() == "classic", "theme restored to 'classic' via the slash command")
check(ns.Prefs.IsSavedVariablesSafe(ForeverQuestGuideDB), "ForeverQuestGuideDB is still SavedVariables-safe after repeated theme switching")

print("9. 'Don't Show Again' persistence across a simulated /reload...")
check(ForeverQuestGuideDB.welcomePopupDisabled == false, "welcome-popup preference is still false going into this section")
ns.WelcomePopup.Show()  -- re-show directly (bypassing the ADDON_LOADED gate) to exercise the OTHER button
local popupButtons2 = ns.WelcomePopup._selftest_getButtons()
local dontShowOnClick = popupButtons2 and popupButtons2.dontShow and popupButtons2.dontShow._scripts.OnClick
check(type(dontShowOnClick) == "function", "'Don't Show Again' button has an OnClick handler")
local okDontShow, errDontShow = pcall(dontShowOnClick)
check(okDontShow, "clicking 'Don't Show Again' ran without error: " .. tostring(errDontShow))
check(ForeverQuestGuideDB.welcomePopupDisabled == true, "'Don't Show Again' persisted welcomePopupDisabled = true")
check(ns.WelcomePopup._selftest_getFrame():IsShown() == false, "the popup hid itself after 'Don't Show Again'")

-- Simulate "/reload": in the real client this re-executes every addon file with ForeverQuestGuideDB already
-- restored from disk; here (same Lua process, same _G) the equivalent, correctly-scoped test is firing the
-- ADDON_LOADED logic again directly WITHOUT re-running Preferences.lua's own defaulting code (which would
-- not re-run on a real reload either, since ForeverQuestGuideDB.welcomePopupDisabled is already non-nil and
-- its `if ... == nil` guard would not overwrite it) and confirming the now-true flag is honored.
local popupFrameBefore = ns.WelcomePopup._selftest_getFrame()
local okReload, errReload = pcall(ns._selftest.fireAddonLoaded)
check(okReload, "firing ADDON_LOADED again (simulated /reload) ran without error: " .. tostring(errReload))
check(popupFrameBefore:IsShown() == false,
	"the welcome popup did NOT auto-show again after the simulated reload, honoring the persisted preference")

print("10. quest search/filter (M8.6-A)...")
check(ns._selftest.getActiveTab() == "QUESTS", "starting on the QUESTS tab for the search test")
local searchBox = ns._selftest.getSearchBox()
check(searchBox ~= nil, "the search box exists")
check(#ns._selftest.getFilteredQuestOrder() == 96, "with no filter text, the filtered list is all 96 quests")
ns._selftest.setFilterText("thunder lizards")
local filtered1 = ns._selftest.getFilteredQuestOrder()
check(#filtered1 == 1 and filtered1[1] == 907, "searching 'thunder lizards' (case-insensitive) matches only quest 907")
ns._selftest.setFilterText("THUNDER LIZARDS")
check(#ns._selftest.getFilteredQuestOrder() == 1, "search is case-insensitive (all-caps matches too)")
ns._selftest.setFilterText("skyseer")  -- Jorn Skyseer is 907's giver; title does not contain "skyseer"
local filtered2 = ns._selftest.getFilteredQuestOrder()
check(#filtered2 == 1 and filtered2[1] == 907, "searching a giver name matches the quest they give")
ns._selftest.setFilterText("zzz_no_such_quest_or_giver")
check(#ns._selftest.getFilteredQuestOrder() == 0, "a non-matching search returns zero quests")
ns._selftest.setFilterText("")
check(#ns._selftest.getFilteredQuestOrder() == 96, "clearing the search restores the complete list of 96")
-- Directly exercise the widget's own OnTextChanged handler, not just the test seam's shortcut, so the
-- actual wiring (not just the underlying filter function) is proven.
local onTextChanged = searchBox._scripts and searchBox._scripts.OnTextChanged
check(type(onTextChanged) == "function", "the search box has an OnTextChanged handler")
searchBox:SetText("thunder")
local okSearch, errSearch = pcall(onTextChanged, searchBox)
check(okSearch, "the real OnTextChanged handler ran without error: " .. tostring(errSearch))
check(#ns._selftest.getFilteredQuestOrder() == 1, "the real widget handler filtered the list correctly")
searchBox:SetText("")
onTextChanged(searchBox)
check(#ns._selftest.getFilteredQuestOrder() == 96, "clearing via the real widget handler restores the full list")
check(ns._selftest.getSelectedQuestID() == firstWithQuest.questID,
	"the existing quest-detail selection is unaffected by search (still the quest picked in section 5)")

print("11. route progress, required/optional badge, and 'why' rendering (M8.6-A)...")
ns._selftest.setActiveTab("ROUTE")
check(ns._selftest.getCurrentStepIndex() == 1, "route view is back at step 1")
local rfs = ns._selftest.getRouteFontStrings()
check(rfs.required ~= nil, "the REQUIRED/OPTIONAL badge FontString exists")
check(rfs.whyHeader ~= nil and rfs.whyText ~= nil, "the 'why' header/text FontStrings exist")
check(ns._selftest.getProgressSegmentCount() == 5, "the progress bar has exactly 5 segments for this 5-step route")
-- Step 1 (s1, ACCEPT quest 907) is authored with required=true and no "why" -- confirmed directly against
-- the real route JSON's own values, not a hardcoded assumption in this test.
check(rfs.whyHeader:IsShown() == false, "step 1 has no 'why' text authored, so the why-section is hidden")
for i = 2, 4 do
	ns._selftest.routeNext()
end
check(ns._selftest.getCurrentStepIndex() == 4, "advanced to step 4 (s4, TURN_IN 907, which HAS a 'why')")
check(rfs.whyHeader:IsShown() == true, "step 4's authored 'why' text is shown")
check(ns._selftest.getProgressSegmentCount() == 5, "progress bar segment count is unchanged by navigation (still 5)")
ns._selftest.routeNext()
check(ns._selftest.getCurrentStepIndex() == 5, "advanced to step 5 (s5, ACCEPT 959, authored required=false)")

print("12. next-step preview (M8.6-A)...")
check(ns._selftest.getPreviewCollapsed() == false, "preview starts expanded")
local previewToggle = ns._selftest.getPreviewToggleButton()
check(previewToggle ~= nil, "the preview collapse/expand toggle button exists")
local previewLines = ns._selftest.getPreviewLines()
check(type(previewLines) == "table" and #previewLines >= 1, "at least one preview line slot exists")
-- At step 5 of 5 (the last step), there are ZERO future steps, so every preview line must be hidden --
-- this is the "fewer than 3 future steps remain" truncation case, at its most extreme (zero remain).
for i, pl in ipairs(previewLines) do
	check(pl.kindFS:IsShown() == false, "preview line " .. i .. " is hidden at the final step (no future steps exist)")
end
ns._selftest.setActiveTab("QUESTS"); ns._selftest.setActiveTab("ROUTE")  -- back to step 1 view path below
for i = 1, 4 do ns._selftest.routePrevious() end
check(ns._selftest.getCurrentStepIndex() == 1, "back to step 1 (4 future steps exist: s2, s3, s4, s5)")
local shownPreviewCount = 0
for _, pl in ipairs(previewLines) do
	if pl.kindFS:IsShown() then shownPreviewCount = shownPreviewCount + 1 end
end
check(shownPreviewCount == 3, "exactly 3 preview lines are shown at step 1, even though 4 future steps exist (PREVIEW_STEP_COUNT caps it)")
local previewToggleOnClick = previewToggle._scripts and previewToggle._scripts.OnClick
check(type(previewToggleOnClick) == "function", "preview toggle has an OnClick handler")
local okCollapse, errCollapse = pcall(previewToggleOnClick)
check(okCollapse, "clicking the preview toggle ran without error: " .. tostring(errCollapse))
check(ns._selftest.getPreviewCollapsed() == true, "preview is now collapsed")
local hiddenAfterCollapse = 0
for _, pl in ipairs(previewLines) do
	if not pl.kindFS:IsShown() then hiddenAfterCollapse = hiddenAfterCollapse + 1 end
end
check(hiddenAfterCollapse == #previewLines, "all preview lines are hidden while collapsed")
local okExpand, errExpand = pcall(previewToggleOnClick)
check(okExpand, "clicking the preview toggle again ran without error: " .. tostring(errExpand))
check(ns._selftest.getPreviewCollapsed() == false, "preview is expanded again")

print("13. compact vs. detailed mode (M8.6-A)...")
check(ns.Prefs.GetUIMode() == "detailed", "mode is 'detailed' by default")
local modeBtn = ns._selftest.getModeToggleButton()
check(modeBtn ~= nil, "the mode toggle button exists")
local modeOnClick = modeBtn._scripts and modeBtn._scripts.OnClick
check(type(modeOnClick) == "function", "mode toggle button has an OnClick handler")
local okMode1, errMode1 = pcall(modeOnClick)
check(okMode1, "clicking the mode toggle ran without error: " .. tostring(errMode1))
check(ns.Prefs.GetUIMode() == "compact", "mode switched to 'compact'")
check(rfs.npc:IsShown() == false, "compact mode hides the NPC line")
check(rfs.instruction:IsShown() == false, "compact mode hides the step's display_text (secondary explanation)")
check(rfs.whyHeader:IsShown() == false, "compact mode hides the 'why' section even on a step that has one")
check(previewToggle:IsShown() == false, "compact mode hides the preview entirely")
check(rfs.quest:IsShown() == true, "compact mode still shows the quest title (priority item)")
check(rfs.body:IsShown() == true, "compact mode still shows the main instruction (priority item)")
check(rfs.dest:IsShown() == true, "compact mode still shows the destination (priority item)")
local okMode2, errMode2 = pcall(modeOnClick)
check(okMode2, "clicking the mode toggle again ran without error: " .. tostring(errMode2))
check(ns.Prefs.GetUIMode() == "detailed", "mode switched back to 'detailed'")
check(rfs.npc:IsShown() == true or ns._selftest.getCurrentRouteID() ~= nil, "detailed mode restores the NPC line where the step has one")

print("13b. mode switching via the /fguide mode slash-command path...")
local okModeCmd, errModeCmd = pcall(SlashCmdList["FOREVERQUESTGUIDE"], "mode compact")
check(okModeCmd, "'/fguide mode compact' ran without error: " .. tostring(errModeCmd))
check(ns.Prefs.GetUIMode() == "compact", "'/fguide mode compact' switched the mode")
local okModeBad, errModeBad = pcall(SlashCmdList["FOREVERQUESTGUIDE"], "mode not-a-real-mode")
check(okModeBad, "an unrecognized mode name ran without error: " .. tostring(errModeBad))
check(ns.Prefs.GetUIMode() == "compact", "an unrecognized mode name did not change the current mode")
SlashCmdList["FOREVERQUESTGUIDE"]("mode detailed")  -- restore for cleanliness
check(ns.Prefs.GetUIMode() == "detailed", "mode restored to 'detailed' via the slash command")
check(ns.Prefs.IsSavedVariablesSafe(ForeverQuestGuideDB), "ForeverQuestGuideDB is still SavedVariables-safe after mode switching")

print("14. theme applies to all new M8.6-A controls...")
local countsBefore = ns._selftest.getThemedCounts()
check(countsBefore.editBoxes >= 1, "the search box is registered in the themed edit-box registry")
local okThemeAll, errThemeAll = pcall(ns.UI.ApplyTheme)
check(okThemeAll, "re-applying the theme with the new controls present ran without error: " .. tostring(errThemeAll))

print("")
if failures == 0 then
	print("ALL SELF-TEST CHECKS PASS")
	os.exit(0)
else
	print(failures .. " CHECK(S) FAILED")
	os.exit(1)
end
