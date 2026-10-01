-- ForeverQuestGuide.Preferences: the addon's first SavedVariable (M8.1/M8.3 had none).
--
-- SavedVariables table: ForeverQuestGuideDB. Declared in the .toc. Initialized here at this file's own
-- top level, following the exact pattern already real-client-validated by the recorder
-- (m5-production-recorder/addon/ForeverRecorder/core/Bootstrap.lua's
-- "ForeverObservationLabDB = ForeverObservationLabDB or {...}"): WoW restores SavedVariables BEFORE any
-- addon file executes, so `ForeverQuestGuideDB or {}` correctly picks up an existing table on a returning
-- login and creates a fresh one on first install, with no ADDON_LOADED wait needed for this step.
--
-- Per-key defaulting (not a single `or {}` on the whole table) so a value the player already saved is
-- never silently overwritten by a later version of this file that adds a new key -- each preference
-- defaults independently, only when actually absent.
--
-- KNOWN LIMITATION, stated plainly rather than assumed away: docs/M8_0_SCOPE.md SS2 documents a real,
-- twice-reproduced SavedVariables logout/character-select persistence failure on this Forever client, root
-- cause unknown. `/reload`-triggered saves are confirmed reliable; logout/character-select saves are not.
-- This module cannot work around that -- it uses the same SavedVariables mechanism the recorder already
-- found this limitation in. See docs/M8_5_COMPLETION_REPORT.md for what was actually tested.

local addonName, ns = ...

ForeverQuestGuideDB = ForeverQuestGuideDB or {}

if ForeverQuestGuideDB.welcomePopupDisabled == nil then
	ForeverQuestGuideDB.welcomePopupDisabled = false
end
if ForeverQuestGuideDB.theme == nil then
	ForeverQuestGuideDB.theme = "classic"
end
if ForeverQuestGuideDB.uiMode == nil then
	ForeverQuestGuideDB.uiMode = "detailed"  -- M8.6-A: "detailed" or "compact"; detailed preserves the
end                                          -- exact M8.3/M8.5 layout, so a fresh install looks unchanged.

-- ---------------------------------------------------------------- theme palette

-- Plain color/font-color tables only -- no textures, no templates, nothing beyond what UI.lua already
-- proved safe (SetColorTexture, FontString:SetTextColor). "Classic" reproduces M8.1/M8.3's existing look
-- byte-for-byte (same literal color values already shipped), so switching TO Classic, or never switching at
-- all, changes nothing about the addon's current, already real-client-validated appearance.
local THEMES = {
	classic = {
		windowBG = { 0, 0, 0, 0.85 },
		border = { 1, 1, 1, 0.25 },
		panelText = { 1, 0.82, 0, 1 },        -- GameFontNormal's own default gold -- set explicitly here
		tabActiveBG = { 0.35, 0.35, 0.15, 1 }, -- so "classic" is a real, complete palette, not "leave alone"
		tabInactiveBG = { 0.15, 0.15, 0.15, 1 },
		primaryButtonBG = { 0.25, 0.25, 0.25, 0.9 },
		secondaryButtonBG = { 0.25, 0.25, 0.25, 0.9 },
		buttonText = { 1, 0.82, 0, 1 },
	},
	dark = {
		windowBG = { 0.04, 0.04, 0.05, 0.97 },
		border = { 0.5, 0.5, 0.55, 0.6 },
		panelText = { 0.92, 0.92, 0.95, 1 },
		tabActiveBG = { 0.20, 0.45, 0.65, 1 },   -- clearly distinct active-tab color, high contrast
		tabInactiveBG = { 0.10, 0.10, 0.12, 1 },
		primaryButtonBG = { 0.15, 0.55, 0.25, 1 }, -- NEXT: strong, high-emphasis green
		secondaryButtonBG = { 0.22, 0.22, 0.26, 1 }, -- PREVIOUS: visually distinct, lower emphasis
		buttonText = { 1, 1, 1, 1 },
	},
}

local function copyColor(c)
	return { c[1], c[2], c[3], c[4] }
end

--- Returns a fresh copy of the named theme's color table (never the live table itself, so a caller can
-- never accidentally mutate a shared palette entry).
local function getTheme(name)
	local t = THEMES[name] or THEMES.classic
	local out = {}
	for k, v in pairs(t) do
		out[k] = copyColor(v)
	end
	return out
end

-- ---------------------------------------------------------------- preference accessors

local function getTheme_Pref()
	return ForeverQuestGuideDB.theme
end

local function setTheme_Pref(name)
	if THEMES[name] then
		ForeverQuestGuideDB.theme = name
		return true
	end
	return false
end

local function isWelcomePopupDisabled()
	return ForeverQuestGuideDB.welcomePopupDisabled == true
end

local function disableWelcomePopup()
	ForeverQuestGuideDB.welcomePopupDisabled = true
end

local UI_MODES = { detailed = true, compact = true }

local function getUIMode()
	return ForeverQuestGuideDB.uiMode
end

local function setUIMode(mode)
	if UI_MODES[mode] then
		ForeverQuestGuideDB.uiMode = mode
		return true
	end
	return false
end

--- Returns true if every value reachable from `t` is a type WoW's SavedVariables writer can actually
-- persist (string, number, boolean, or a nested table of the same) -- no function, no userdata, nothing
-- HARVEST_CONTRACT.md's own documented SavedVariables grammar (a narrow table-literal format, "no function
-- calls, no expressions") could not round-trip. Used only by the self-test; not called at runtime.
local function isSavedVariablesSafe(t, seen)
	seen = seen or {}
	if seen[t] then
		return true
	end
	seen[t] = true
	for k, v in pairs(t) do
		local kt, vt = type(k), type(v)
		if kt ~= "string" and kt ~= "number" then
			return false
		end
		if vt == "table" then
			if not isSavedVariablesSafe(v, seen) then
				return false
			end
		elseif vt ~= "string" and vt ~= "number" and vt ~= "boolean" then
			return false
		end
	end
	return true
end

ns.Prefs = {
	THEME_NAMES = { "classic", "dark" },
	GetTheme = getTheme_Pref,
	SetTheme = setTheme_Pref,
	GetThemeColors = getTheme,
	IsWelcomePopupDisabled = isWelcomePopupDisabled,
	DisableWelcomePopup = disableWelcomePopup,
	UI_MODE_NAMES = { "detailed", "compact" },
	GetUIMode = getUIMode,
	SetUIMode = setUIMode,
	IsSavedVariablesSafe = isSavedVariablesSafe,
}
