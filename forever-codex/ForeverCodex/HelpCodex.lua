-- ForeverCodex.HelpCodex: the player-facing face of the local observation log ("Codex learns from your adventures").
-- It reads the existing Telemetry store and shows only what is really in it; it never rewrites Telemetry, never uploads
-- anything and never invents a count. Nothing leaves this machine: there is no export or sharing in this build.

local addonName, ns = ...

local H = {}
ns.HelpCodex = H

local LABEL = {
	QUEST_ACCEPT = "Quests you accepted", QUEST_COMPLETE = "Quests whose objectives you finished", QUEST_TURNIN = "Quests you turned in",
	XP_GAIN = "Experience gains", LEVEL_UP = "Level-ups", PLAYER_MOVE = "Stretches of travel",
	COMBAT_START = "Fights started", COMBAT_END = "Fights finished",
}
local ORDER = { "QUEST_ACCEPT", "QUEST_COMPLETE", "QUEST_TURNIN", "LEVEL_UP", "XP_GAIN", "COMBAT_END", "PLAYER_MOVE" }

local function counts()
	local by, total = {}, 0
	local T = ns.Telemetry
	for _, ev in ipairs(T and T.Events() or {}) do
		if ev.e ~= "SESSION" then
			by[ev.e] = (by[ev.e] or 0) + 1
			total = total + 1
		end
	end
	return by, total
end

--- { enabled, total, cap, text, lines }: lines are the plain-language headline for the section.
function H.Summary()
	local T = ns.Telemetry
	if not T then return { enabled = false, total = 0, cap = 0, text = "Codex is not recording on this client." } end
	local st = T.Status()
	local _, total = counts()
	local text
	if not st.enabled then
		text = "Codex is not recording right now."
	elseif total == 0 then
		text = "Codex has not learned anything on this character yet. Just play."
	else
		text = string.format("Codex has learned %d %s from this character.", total, total == 1 and "observation" or "observations")
	end
	return { enabled = st.enabled, total = total, cap = st.cap, text = text,
		note = string.format("Codex keeps the most recent %d. It stays on this character; nothing is uploaded or shared.", st.cap) }
end

--- What Codex learned: one line per kind of observation that has actually been recorded.
function H.Learned()
	local by = counts()
	local lines = {}
	for _, k in ipairs(ORDER) do
		if (by[k] or 0) > 0 then lines[#lines + 1] = string.format("%s: %d", LABEL[k] or k, by[k]) end
	end
	return lines
end

--- Clears the recorded observations of this character (the player's data to clear). Returns how many were removed.
function H.Clear()
	local T = ns.Telemetry
	if not T then return 0 end
	local _, total = counts()
	T.Reset()
	return total
end

H.COPY = {
	title = "Help Improve Codex",
	tagline = "Codex learns from your adventures.",
	body = "While you play, Codex can notice things it did not know: quests, the NPCs who give them, where objectives are, how you travel, and how quests and fights progress. You do not need to report anything. What Codex notices stays on this character unless you choose to export it later.",
}
