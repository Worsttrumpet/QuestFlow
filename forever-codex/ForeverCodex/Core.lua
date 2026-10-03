-- ForeverCodex.Core: namespace, chat output, a small defensive-call helper.
--
-- Forever Codex is a dynamic, character-aware progression COMPANION. It recommends; the player decides. It is
-- read-only with respect to the game: it never accepts, completes or turns in a quest and never calls
-- GetQuestReward(). The only game-visible effect it can have is placing ONE map waypoint when the player clicks
-- "Show on Map" (the same proven path as ForeverQuestGuide's M8.6-B).
--
-- Data provenance is a first-class concept here: every record and every recommendation carries `src`
-- ("att" or "observed") and `verified` (true/false). ATT-derived data is NEVER presented as a confirmed Forever
-- fact. See docs/CODEX_ARCHITECTURE.md.

local addonName, ns = ...

ForeverCodex = ForeverCodex or {}
local C = ForeverCodex
C.VERSION = "0.5.0"       -- must equal ## Version in ForeverCodex.toc (the packager checks); bump both for every packaged change
C.EXPECTED_INTERFACE = 16001

ns.errors = {}
local MAX_ERRORS = 20

--- Records a caught error for /codex diag. Never raises.
function ns.RecordError(where, err)
	local msg = tostring(where) .. ": " .. tostring(err)
	if #msg > 300 then msg = msg:sub(1, 300) end
	table.insert(ns.errors, msg)
	while #ns.errors > MAX_ERRORS do
		table.remove(ns.errors, 1)
	end
end

local function say(msg)
	if DEFAULT_CHAT_FRAME then
		DEFAULT_CHAT_FRAME:AddMessage("|cff33cc99[Codex]|r " .. (tostring(msg):gsub("|", "||")))   -- a literal pipe must be doubled or chat reads "|r" etc. as a colour code
	end
end
ns.Say = say

--- Defensive call: returns ok, results... Same contract as ForeverQuestGuide's ns.Safe (M8.13), so the copied
-- modules (ProgressionEval, MapPin, MinimapButton) work unchanged. A raised error is also recorded for diag.
local function safe(fn, ...)
	if type(fn) ~= "function" then
		return false, "function not available"
	end
	local ok, a, b, c, d = pcall(fn, ...)
	if not ok then
		ns.RecordError("safe", a)
		return false, a
	end
	return true, a, b, c, d
end
ns.Safe = safe

--- Plain-text truncation for single-line UI strings.
function ns.Trunc(s, n)
	s = tostring(s or "")
	if #s <= n then
		return s
	end
	return s:sub(1, n - 3) .. "..."
end

--- Test-only seam (no in-game code path reads it).
ns._selftest = ns._selftest or {}
