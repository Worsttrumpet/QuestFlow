-- ForeverQuestGuide.Core: bootstrap, chat output, a small defensive-call
-- helper, minimap-button/welcome-popup wiring, and the addon's slash command.
--
-- This addon is READ-ONLY with respect to the game: it never accepts,
-- completes, or turns in a quest, and never calls GetQuestReward(). As of
-- M8.5 it has ONE SavedVariable, ForeverQuestGuideDB (see Preferences.lua),
-- used only for two UI preferences (theme, welcome-popup dismissal) -- never
-- for quest, route, or evidence data, all of which remain in the generated,
-- static Data.lua/RouteData.lua files. See docs/M8_0_SCOPE.md for why
-- persistence itself is a real, twice-reproduced open question on this
-- client (root cause unknown for logout/character-select saves specifically)
-- and docs/M8_5_COMPLETION_REPORT.md for what was actually tested.

local addonName, ns = ...

ForeverQuestGuide = ForeverQuestGuide or {}
ForeverQuestGuide.VERSION = "m8-guide-addon-0.5"
ForeverQuestGuide.EXPECTED_INTERFACE = 16001

local function say(msg)
	if DEFAULT_CHAT_FRAME then
		DEFAULT_CHAT_FRAME:AddMessage("|cff33cc99[ForeverQuestGuide]|r " .. msg)
	end
end
ns.Say = say

-- A small local defensive-call helper, in the spirit of the project's
-- existing ForeverRecorder.SafeCall pattern (m5-production-recorder), but
-- deliberately NOT a dependency on that addon -- this addon must not assume
-- ForeverRecorder is installed. Always pass the receiver (self) explicitly
-- as the first vararg, exactly as the recorder's own pattern does.
local function safe(fn, ...)
	if type(fn) ~= "function" then
		return false, "function not available"
	end
	local ok, a, b, c, d = pcall(fn, ...)
	if not ok then
		return false, a
	end
	return true, a, b, c, d
end
ns.Safe = safe

local function questCount()
	local n = 0
	for _ in pairs(ns.QuestData or {}) do
		n = n + 1
	end
	return n
end

local function routeCount()
	local n = 0
	for _ in pairs(ns.Routes or {}) do
		n = n + 1
	end
	return n
end

local function onAddonLoaded(self, event, loadedAddonName)
	if loadedAddonName ~= addonName then
		return
	end
	self:UnregisterEvent("ADDON_LOADED")

	say(string.format(
		"v%s loaded. Read-only quest browser, %d guide-ready quest(s) available, %d hand-authored route(s). "
			.. "Never accepts/completes/turns in quests, never calls GetQuestReward(). No auto-progression, "
			.. "no directional arrow, no map pins. Theme: %s.",
		ForeverQuestGuide.VERSION, questCount(), routeCount(), ns.Prefs and ns.Prefs.GetTheme() or "classic"))

	local okB, _version, _build, _date, tocVersion = safe(GetBuildInfo)
	if okB and tocVersion and tocVersion ~= ForeverQuestGuide.EXPECTED_INTERFACE then
		say(string.format(
			"NOTE: running on interface %s, not the %d this addon was tested against. "
				.. "Reporting the real value, not treating this as an error.",
			tostring(tocVersion), ForeverQuestGuide.EXPECTED_INTERFACE))
	end

	say("type /fguide to open or close the guide, or use the minimap button. "
		.. "/fguide theme classic|dark switches appearance; /fguide mode compact|detailed switches layout.")

	if ns.MinimapButton and ns.MinimapButton.Build then
		local okMM, errMM = pcall(ns.MinimapButton.Build)
		if not okMM then
			say("minimap button failed to initialize: " .. tostring(errMM))
		end
	end

	if ns.Prefs and not ns.Prefs.IsWelcomePopupDisabled() and ns.WelcomePopup and ns.WelcomePopup.Show then
		ns.WelcomePopup.Show()
	end
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:SetScript("OnEvent", onAddonLoaded)

-- Test-only seam (matches UI.lua's existing ns._selftest pattern): lets the Lua self-test actually fire
-- the ADDON_LOADED path (minimap button build, welcome-popup check) without needing to assume :GetScript()
-- is safe to call -- onAddonLoaded is called directly, the same function the real event would call.
-- ns._selftest is MERGED into, never reassigned wholesale, since UI.lua (loaded after this file) populates
-- its own keys on the same table -- either file reassigning it outright would silently erase the other's.
ns._selftest = ns._selftest or {}
ns._selftest.fireAddonLoaded = function()
	onAddonLoaded(loader, "ADDON_LOADED", addonName)
end

SLASH_FOREVERQUESTGUIDE1 = "/fguide"
SlashCmdList["FOREVERQUESTGUIDE"] = function(msg)
	msg = (msg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
	local themeArg = msg:match("^theme%s+(%a+)$")
	if themeArg then
		if ns.Prefs and ns.Prefs.SetTheme(themeArg) then
			if ns.UI and ns.UI.ApplyTheme then
				ns.UI.ApplyTheme()
			end
			say("theme set to " .. themeArg .. ".")
		else
			say("unknown theme '" .. themeArg .. "'. Try: classic, dark.")
		end
		return
	end

	-- M8.6-A: a second, scriptable path to the same compact/detailed switch as the in-window button,
	-- mirroring the existing "theme" argument exactly.
	local modeArg = msg:match("^mode%s+(%a+)$")
	if modeArg then
		if ns.Prefs and ns.Prefs.SetUIMode(modeArg) then
			if ns.UI and ns.UI.ApplyUIMode then
				ns.UI.ApplyUIMode()
			end
			say("view mode set to " .. modeArg .. ".")
		else
			say("unknown mode '" .. modeArg .. "'. Try: detailed, compact.")
		end
		return
	end

	-- Bare "/fguide" (msg == ""), and anything else unrecognized, falls through to the original,
	-- unchanged M8.1/M8.3 behavior: plain open/close toggle. This is deliberate -- "/fguide must continue
	-- working exactly as it does now" -- so an unrecognized argument still toggles rather than erroring or
	-- silently doing nothing.
	if ns.UI and ns.UI.Toggle then
		ns.UI.Toggle()
	else
		say("UI failed to initialize (see any earlier error).")
	end
end
