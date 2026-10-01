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
		else
			-- The copied M8.13 button anchors exactly where ForeverQuestGuide's does; move ours down so both can coexist.
			local btn = _G["ForeverCodexMinimapButton"]
			if btn and Minimap then
				pcall(function()
					btn:ClearAllPoints()
					btn:SetPoint("TOPLEFT", Minimap, "TOPRIGHT", 6, -34)
				end)
			end
		end
	end
	local plan = ns.State.Recompute()
	local n = ns.Registry.Stats()
	ns.Say(string.format("data: %d quests (ATT-derived, unverified, plus %d observed on Forever). /codex diag if anything looks wrong.", n.quests,
		(function() local c = 0 for _, p in ipairs(n.packs) do if p.src == "observed" then c = c + p.count end end return c end)()))
	if plan and plan.next then
		ns.Say("next: " .. plan.next.title)
	end
end

local function onEvent(_, event, arg1)
	local ok, err = pcall(function()
		if event == "ADDON_LOADED" then
			onAddonLoaded(arg1)
		elseif event == "PLAYER_LOGIN" then
			onLogin()
		elseif event == "UNIT_QUEST_LOG_CHANGED" then
			if arg1 == "player" then ns.State.MarkDirty() end
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
end)

ns._selftest.boot = { frame = frame, onEvent = onEvent }
