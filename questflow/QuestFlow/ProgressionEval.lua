-- COPIED from m8-13-progression/ForeverQuestGuide/ProgressionEval.lua (M8.13, real-client validated).
-- Only the exported namespace name / user-facing strings were changed; the logic is untouched.
-- Re-copy rather than editing logic here, so fixes stay traceable to the M8.13 original.

-- ForeverCodex.Eval (was ForeverQuestGuide.ProgressionEval): pure step evaluators (M8.13).
--
-- evaluate(step, signal, reader) -> { state = "SATISFIED" | "WAITING" | "UNDETECTABLE", reason = string,
--                                     distance = yards or nil }
--
-- Evaluators decide one thing: is THIS step satisfied right now, given an optional signal (the event that
-- prompted the check) and a reader (read-only access to quest/position state). They keep no state, never
-- advance anything, and never call a quest-changing function. The controller (Progression.lua) owns latching,
-- confirmation, and the route pointer, so automatic advancement can be added later without touching this file.
--
-- Signals and evidence (all verified on the real Forever client):
--   ACCEPT     QUEST_ACCEPTED(questID)                         M8.7
--   TURN_IN    QUEST_TURNED_IN(questID, xp, money)             M8.8   -- QUEST_REMOVED is never used (M8.8/M8.9)
--   OBJECTIVE  UNIT_QUEST_LOG_CHANGED("player") + state read   M8.9   -- quest-level completion only (M8.13)
--   TRAVEL     addon-computed world distance, same continent   M8.10  -- no navigation/waypoint/arrow state
-- State reads (IsOnQuest, IsComplete, ReadyForTurnIn, IsQuestFlaggedCompleted) are valid from PLAYER_LOGIN on
-- (M8.12); the controller never evaluates before then.

local addonName, ns = ...

--- Provisional arrival radius for TRAVEL steps, in yards. A DESIGN VALUE, not a measurement: the route schema
-- has no radius field yet (M8.10/M8.11). The game's own arrival event fired at ~10 yd (M8.10), but route
-- destinations are approximate observed player positions, so the addon allows more slack. Replace with a
-- route-authored value once the schema has one.
local TRAVEL_RADIUS_YARDS = 20

local function result(state, reason, distance)
	return { state = state, reason = reason, distance = distance }
end

-- ---------------------------------------------------------------- default reader (read-only client access)

local function safeCall(f, ...)
	if type(f) ~= "function" then return nil end
	local ok, v1, v2 = pcall(f, ...)
	if ok then return v1, v2 end
	return nil
end

local function cq(name)
	return type(C_QuestLog) == "table" and C_QuestLog[name] or nil
end

--- Returns continent, worldX, worldY for a map position, or nil.
local function worldPos(mapID, x, y)
	if type(mapID) ~= "number" or type(x) ~= "number" or type(y) ~= "number" then return nil end
	if type(CreateVector2D) ~= "function" or type(C_Map) ~= "table" then return nil end
	local okV, v = pcall(CreateVector2D, x, y)
	if not okV or not v then return nil end
	local continent, wp = safeCall(C_Map.GetWorldPosFromMapPos, mapID, v)
	if not continent or type(wp) ~= "table" then return nil end
	local wx, wy
	if type(wp.GetXY) == "function" then
		local okXY, a, b = pcall(wp.GetXY, wp)
		if okXY then wx, wy = a, b end
	end
	wx, wy = wx or wp.x, wy or wp.y
	if not wx or not wy then return nil end
	return continent, wx, wy
end

local defaultReader = {
	isOnQuest = function(q) return safeCall(cq("IsOnQuest"), q) end,
	isComplete = function(q) return safeCall(cq("IsComplete"), q) end,
	readyForTurnIn = function(q) return safeCall(cq("ReadyForTurnIn"), q) end,
	isFlaggedCompleted = function(q) return safeCall(cq("IsQuestFlaggedCompleted"), q) end,
	playerWorldPos = function()
		if type(C_Map) ~= "table" then return nil end
		local map = safeCall(C_Map.GetBestMapForUnit, "player")
		if not map then return nil end
		local pos = safeCall(C_Map.GetPlayerMapPosition, map, "player")
		if type(pos) ~= "table" then return nil end
		local x, y
		if type(pos.GetXY) == "function" then
			local ok, a, b = pcall(pos.GetXY, pos)
			if ok then x, y = a, b end
		end
		return worldPos(map, x or pos.x, y or pos.y)
	end,
	destinationWorldPos = function(dest) return worldPos(dest.ui_map_id, dest.x, dest.y) end,
}

-- ---------------------------------------------------------------- evaluators

local evaluators = {}

evaluators.ACCEPT = function(step, signal, r)
	local q = step.quest_id
	if type(q) ~= "number" then return result("UNDETECTABLE", "step has no quest ID") end
	if signal and signal.type == "QUEST_ACCEPTED" and signal.questID == q then
		return result("SATISFIED", "quest accepted")
	end
	if r.isOnQuest(q) == true then return result("SATISFIED", "quest is in your quest log") end
	if r.isFlaggedCompleted(q) == true then return result("SATISFIED", "quest already completed") end
	return result("WAITING", "quest not accepted yet")
end

evaluators.TURN_IN = function(step, signal, r)
	local q = step.quest_id
	if type(q) ~= "number" then return result("UNDETECTABLE", "step has no quest ID") end
	if signal and signal.type == "QUEST_TURNED_IN" and signal.questID == q then
		return result("SATISFIED", "quest turned in")
	end
	if r.isFlaggedCompleted(q) == true then return result("SATISFIED", "quest already turned in") end
	return result("WAITING", "quest not turned in yet")
end

--- Quest-level completion only: step.objective_index is deliberately ignored (the index-to-client mapping is
-- unproven, M8.9 Q8). A later milestone can add per-objective matching here without changing the controller.
evaluators.OBJECTIVE = function(step, signal, r)
	local q = step.quest_id
	if type(q) ~= "number" then return result("UNDETECTABLE", "step has no quest ID") end
	if r.isFlaggedCompleted(q) == true then return result("SATISFIED", "quest already turned in") end
	if r.isOnQuest(q) ~= true then return result("WAITING", "quest is not in your quest log") end
	if r.isComplete(q) == true or r.readyForTurnIn(q) == true then
		return result("SATISFIED", "quest objectives complete")
	end
	return result("WAITING", "quest objectives in progress")
end

evaluators.TRAVEL = function(step, signal, r)
	local d = step.destination
	if type(d) ~= "table" or type(d.ui_map_id) ~= "number" or type(d.x) ~= "number" or type(d.y) ~= "number" then
		return result("UNDETECTABLE", "no destination in route data")
	end
	local dc, dx, dy = r.destinationWorldPos(d)
	if not dc then return result("UNDETECTABLE", "destination position unavailable") end
	local pc, px, py = r.playerWorldPos()
	if not pc then return result("UNDETECTABLE", "your position is unavailable here") end
	if pc ~= dc then return result("UNDETECTABLE", "destination is on another continent") end
	local dist = math.sqrt((px - dx) ^ 2 + (py - dy) ^ 2)
	if dist <= TRAVEL_RADIUS_YARDS then
		return result("SATISFIED", string.format("arrived (%.0f yd)", dist), dist)
	end
	return result("WAITING", string.format("%.0f yd to go", dist), dist)
end

--- Evaluates one step. Never raises: an evaluator error becomes UNDETECTABLE with the error as the reason.
local function evaluate(step, signal, reader)
	if type(step) ~= "table" then return result("UNDETECTABLE", "no step") end
	local ev = evaluators[step.kind]
	if not ev then return result("UNDETECTABLE", "unknown step kind " .. tostring(step.kind)) end
	local ok, res = pcall(ev, step, signal, reader or defaultReader)
	if not ok then return result("UNDETECTABLE", "evaluation error: " .. tostring(res)) end
	return res
end

--- True when the step kind needs periodic position checks (and has the data for them).
local function needsPositionTicks(step)
	local d = type(step) == "table" and step.kind == "TRAVEL" and step.destination
	return type(d) == "table" and type(d.ui_map_id) == "number"
end

ns.Eval = {
	Evaluate = evaluate,
	NeedsPositionTicks = needsPositionTicks,
	DefaultReader = defaultReader,
	TRAVEL_RADIUS_YARDS = TRAVEL_RADIUS_YARDS,
}
