-- ForeverCodex.Boot: event wiring. Loaded last.
--
-- Events used (all verified on Forever in M8.x): ADDON_LOADED, PLAYER_LOGIN, QUEST_ACCEPTED, QUEST_TURNED_IN,
-- UNIT_QUEST_LOG_CHANGED, QUEST_LOG_UPDATE, ZONE_CHANGED*. PLAYER_ENTERING_WORLD and PLAYER_LEVEL_UP are standard
-- Classic events not yet observed on Forever: each registration is feature-checked, and a refused registration is
-- ignored (Codex also re-reads the level on every recompute, so a missed level-up event only delays a refresh).
--
-- Events never compute anything directly: they mark the state dirty and State.Tick (below) recomputes after a
-- short delay, so a burst of quest-log events costs one engine run.

local addonName, ns = ...
local C = ForeverCodex
local P = ns.Prefs

local EVENTS = {
	"ADDON_LOADED", "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "PLAYER_LEVEL_UP", "QUEST_ACCEPTED", "QUEST_TURNED_IN",
	"UNIT_QUEST_LOG_CHANGED", "QUEST_LOG_UPDATE", "ZONE_CHANGED", "ZONE_CHANGED_INDOORS", "ZONE_CHANGED_NEW_AREA",
	-- Phase 3. USER_WAYPOINT_UPDATED is proven (M8.10). The rest are standard Classic events NOT yet observed on Forever:
	-- each registration is feature-checked and a refusal is ignored (GROUP_ROSTER_UPDATE: party; CHAT_MSG_ADDON: Codex users
	-- sharing progress; PLAYER_TARGET_CHANGED / UPDATE_MOUSEOVER_UNIT: world markers, which are off until probed).
	"USER_WAYPOINT_UPDATED", "GROUP_ROSTER_UPDATE", "CHAT_MSG_ADDON", "PLAYER_TARGET_CHANGED", "UPDATE_MOUSEOVER_UNIT",
}

local frame = CreateFrame("Frame")

local function characterKey()
	local name = type(UnitName) == "function" and UnitName("player") or nil
	local realm = type(GetRealmName) == "function" and GetRealmName() or nil
	if type(name) == "string" and name ~= "" then
		return name .. "-" .. tostring(realm or "?")
	end
	return "unknown"
end

local function onAddonLoaded(name)
	if name ~= addonName then return end
	P.ApplyDefaults()
	ns.Say(string.format("%s loaded. Type /codex to open it, /codex help for commands. Recommendations are suggestions: you stay in control.", C.VERSION))
end

local function onLogin()
	P.SetCharKey(characterKey())
	if ns.MinimapButton and ns.MinimapButton.Build then
		local ok, err = pcall(ns.MinimapButton.Build)
		if not ok then
			ns.Say("minimap button failed to initialize: " .. tostring(err))
		end
		-- (its position, saved or default, is applied by the button itself: nothing here may re-anchor it, or a saved spot would be lost at every login)
	end
	if ns.Navigation then ns.Safe(ns.Navigation.Restore) end
	if ns.Party then ns.Safe(ns.Party.Register) end
	ns.State.Recompute()
	-- the player-facing build stays quiet: the engineering summary (data counts, provenance, the plan) is /codex diag
	if not P.SetupDone() then ns.Say("Welcome! Type /codex to set up Forever Codex.") end
end

local function onEvent(_, event, arg1, arg2, arg3, arg4)
	local ok, err = pcall(function()
		if event == "ADDON_LOADED" then
			onAddonLoaded(arg1)
		elseif event == "PLAYER_LOGIN" then
			onLogin()
		elseif event == "UNIT_QUEST_LOG_CHANGED" then
			if arg1 == "player" then ns.State.MarkDirty() end
		elseif event == "QUEST_TURNED_IN" then
			-- (questID, xp, money): the proven turn-in event feeds the Journey and the party announcement
			ns.Journey.OnQuestTurnedIn(arg1, arg2)
			ns.Party.OnTurnedIn(arg1, ns.State.ctx)
			ns.State.MarkDirty()
		elseif event == "USER_WAYPOINT_UPDATED" then
			ns.Navigation.OnWaypointEvent()
			ns.State.MarkDirty()
		elseif event == "CHAT_MSG_ADDON" then
			ns.Party.OnAddonMessage(arg1, arg2, arg3, arg4)
			if ns.UI and ns.UI.Refresh then ns.UI.Refresh() end
		elseif event == "PLAYER_TARGET_CHANGED" then
			ns.Markers.OnUnit("target")
		elseif event == "UPDATE_MOUSEOVER_UNIT" then
			ns.Markers.OnUnit("mouseover")
		else
			ns.State.MarkDirty()
		end
	end)
	if not ok then ns.RecordError("event " .. tostring(event), err) end
end

for _, ev in ipairs(EVENTS) do
	ns.Safe(frame.RegisterEvent, frame, ev)
end
frame:SetScript("OnEvent", onEvent)
frame:SetScript("OnUpdate", function(_, elapsed)
	local ok, err = pcall(ns.State.Tick, elapsed)
	if not ok then ns.RecordError("tick", err) end
	local okN, errN = pcall(ns.Navigation.Tick, elapsed)
	if not okN then ns.RecordError("navigation tick", errN) end
	ns.Arrow.Tick(elapsed)                 -- (self-protecting: it pcalls its own update)
	if ns.Pins then ns.Pins.Tick(elapsed) end
end)

ns._selftest.boot = { frame = frame, onEvent = onEvent }
