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

--- Brings the tracker in line with the setting. Safe to call any time (login, a toggle, a re-show).
function T.Apply()
	local f, name = find()
	if not f then
		last = { state = wanted() and "not found" or "off", frame = nil }
		return last
	end
	if wanted() then
		if type(hooksecurefunc) == "function" and not hooked[f] then
			local ok = pcall(hooksecurefunc, f, "Show", function()
				if wanted() then pcall(f.Hide, f) end
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

function T.Status()
	local f, name = find()
	return { setting = wanted(), frame = name, found = f ~= nil, state = last.state, hooked = f ~= nil and hooked[f] == true }
end
