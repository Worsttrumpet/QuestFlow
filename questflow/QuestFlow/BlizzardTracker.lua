-- ForeverCodex.BlizzardTracker: an OPTIONAL switch that hides the game's own quest tracker so the Codex tracker can take its place.
--
-- Off by default. It only ever calls Hide / Show on the tracker's top frame (plain methods of an ordinary, unprotected frame), and
-- keeps it hidden by a post-hook on that frame's Show (hooksecurefunc: it runs AFTER the game's own code and never replaces it). It does
-- not reparent, unregister events, or touch any child frame, and it never runs while the setting is off. Turning the setting off shows the
-- tracker again at once; a /reload always restores the game's default.
--
-- NOT VERIFIED ON FOREVER: which frame is the tracker (the live client shows the retail-style "All Objectives" header, so
-- ObjectiveTrackerFrame is tried first, then the Classic names) and whether the game ever re-shows it by other means. Every call is
-- feature-checked and pcall-wrapped; /codex tracker and /codex report say which frame was found and what state it is in. If another
-- addon (Questie's own tracker) also manages the Blizzard tracker, the two may fight: leave this off while that is on.

local addonName, ns = ...
local P = ns.Prefs

local T = {}
ns.BlizzardTracker = T

T.FRAMES = { "ObjectiveTrackerFrame", "QuestWatchFrame", "WatchFrame" }

local hooked = {}                 -- frame -> true once the post-hook is installed
local last = { state = "off" }    -- what the last Apply did

local function find()
	for _, name in ipairs(T.FRAMES) do
		local f = rawget(_G, name)
		if type(f) == "table" and type(f.Hide) == "function" and type(f.Show) == "function" then return f, name end
	end
	return nil
end

local function wanted() return P.HideBlizzardTracker() end

-- IN COMBAT the game restricts what addons may do to frames it manages, and a Hide on the tracker's frame from an addon's call path during combat is the classic source of "action blocked" taint reports.
-- So no Hide or Show is attempted while InCombatLockdown() is true: the change is REMEMBERED and applied when combat ends (PLAYER_REGEN_ENABLED, via T.OnCombatEnd). Out of combat nothing changes.
local function locked() return type(_G.InCombatLockdown) == "function" and _G.InCombatLockdown() == true end
T.pending = false

--- Brings the tracker in line with the setting. Safe to call any time (login, a toggle, a re-show).
function T.Apply()
	if locked() then
		T.pending = true
		last = { state = "waiting for combat to end", frame = nil, hooked = false }
		return last
	end
	T.pending = false
	local f, name = find()
	if not f then
		last = { state = wanted() and "not found" or "off", frame = nil }
		return last
	end
	if wanted() then
		if type(hooksecurefunc) == "function" and not hooked[f] then
			local ok = pcall(hooksecurefunc, f, "Show", function()
				if not wanted() then return end
				if locked() then T.pending = true return end
				pcall(f.Hide, f)
			end)
			if ok then hooked[f] = true end
		end
		local ok = pcall(f.Hide, f)
		last = { state = ok and "hidden" or "hide failed", frame = name, hooked = hooked[f] == true }
	else
		if last.state == "hidden" or last.hiddenByUs then pcall(f.Show, f) end
		last = { state = "off", frame = name }
	end
	return last
end

--- PLAYER_REGEN_ENABLED: apply what was postponed during combat.
function T.OnCombatEnd()
	if T.pending then T.Apply() end
end

function T.Status()
	local f, name = find()
	return { setting = wanted(), frame = name, found = f ~= nil, state = last.state, hooked = f ~= nil and hooked[f] == true }
end
