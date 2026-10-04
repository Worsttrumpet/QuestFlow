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
	-- sharing progress).
	"USER_WAYPOINT_UPDATED", "GROUP_ROSTER_UPDATE", "CHAT_MSG_ADDON",
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
	ns.Say(string.format("Forever Codex v%s loaded. Type /codex to open it, /codex help for commands. Recommendations are suggestions: you stay in control.", C.VERSION))
end

--- What the client says about the logged-in character, for the identity check (each read is pcall'd; anything missing is nil).
local function identitySnapshot()
	local function try(fn, ...) if type(fn) ~= "function" then return nil end local ok, a, b = pcall(fn, ...) if ok then return a, b end end
	local _, class = try(_G.UnitClass, "player")
	local _, race = try(_G.UnitRace, "player")
	return { class = class, race = race, faction = try(_G.UnitFactionGroup, "player"), level = try(_G.UnitLevel, "player"), guid = try(_G.UnitGUID, "player") }
end

local function onLogin()
	P.SetCharKey(characterKey())
	-- a deleted and re-created character can reuse a name: clear the old one's gameplay state before anything reads it (see Preferences.CheckIdentity)
	local okI, idRes = pcall(P.CheckIdentity, identitySnapshot())
	if not okI then ns.RecordError("identity", idRes)
	elseif idRes.result == "RESET" then ns.Say("This looks like a new character with a name Codex has seen before (" .. idRes.reason .. "): its old skips, journey and training state were cleared.") end
	-- quest knowledge from the optional QuestieDB addon; when it is not usable, say why once (Codex still works on its own small data)
	if ns.QuestieBridge then
		ns.Safe(ns.QuestieBridge.Init)
		if not ns.QuestieBridge.Available() then ns.Say(ns.QuestieBridge.Status().message) end
	end
	if ns.MinimapButton and ns.MinimapButton.Build then
		local ok, err = pcall(ns.MinimapButton.Build)
		if not ok then
			ns.Say("minimap button failed to initialize: " .. tostring(err))
		end
		-- (its position, saved or default, is applied by the button itself: nothing here may re-anchor it, or a saved spot would be lost at every login)
	end
	if ns.Navigation then ns.Safe(ns.Navigation.Restore) end
	if ns.Party then ns.Safe(ns.Party.Register) end
	if ns.BlizzardTracker then ns.Safe(ns.BlizzardTracker.Apply) end
	if ns.WorldMapButton then ns.Safe(ns.WorldMapButton.Apply) end
	ns.State.Recompute()
	-- the tracker comes back after a reload / login unless the player closed it
	if P.SetupDone() and P.TrackerShown() and ns.UI and ns.UI.Open then ns.Safe(ns.UI.Open, "codex") end
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
			if arg1 == "player" then ns.State.MarkDirty(event) end
		elseif event == "QUEST_TURNED_IN" then
			-- (questID, xp, money): the proven turn-in event feeds the Journey and the party announcement
			ns.Journey.OnQuestTurnedIn(arg1, arg2)
			ns.Party.OnTurnedIn(arg1, ns.State.ctx)
			ns.State.MarkDirty(event)
		elseif event == "TRAINER_SHOW" or event == "TRAINER_UPDATE" then
			if ns.SpellTraining then ns.SpellTraining.OnTrainerEvent() end
			if ns.Professions then ns.Professions.OnTrainerEvent() end
			ns.State.MarkDirty(event)
		elseif event == "USER_WAYPOINT_UPDATED" then
			ns.Navigation.OnWaypointEvent()
			ns.State.MarkDirty(event)
		elseif event == "CHAT_MSG_ADDON" then
			ns.Party.OnAddonMessage(arg1, arg2, arg3, arg4)
			if ns.UI and ns.UI.Refresh then ns.UI.Refresh() end
		else
			ns.State.MarkDirty(event)
		end
	end)
	if not ok then ns.RecordError("event " .. tostring(event), err) end
end

for _, ev in ipairs(EVENTS) do
	ns.Safe(frame.RegisterEvent, frame, ev)
end
-- SPELL TRAINING: standard Classic trainer / spellbook events, NOT yet observed on Forever. A refused registration is ignored (no error recorded): the
-- known-spell check also runs on every recompute, so a missed event only delays the section by one refresh.
for _, ev in ipairs({ "TRAINER_SHOW", "TRAINER_UPDATE", "LEARNED_SPELL_IN_TAB", "SPELLS_CHANGED", "SKILL_LINES_CHANGED", "CHAT_MSG_SKILL" }) do
	pcall(frame.RegisterEvent, frame, ev)
end
frame:SetScript("OnEvent", onEvent)
frame:SetScript("OnUpdate", function(_, elapsed)
	local ok, err = pcall(ns.State.Tick, elapsed)
	if not ok then ns.RecordError("tick", err) end
	local okN, errN = pcall(ns.Navigation.Tick, elapsed)
	if not okN then ns.RecordError("navigation tick", errN) end
	ns.Arrow.Tick(elapsed)                 -- (self-protecting: it pcalls its own update)
end)

ns._selftest.boot = { frame = frame, onEvent = onEvent }
