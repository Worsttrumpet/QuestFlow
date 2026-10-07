-- ForeverQuestGuide.Progression: the progression controller (M8.13, semi-automatic).
--
-- Owns the route pointer (route ID + step ID), the current step's state, latching, pause, skip, reset, undo,
-- and persistence. Game events reach it only through thin adapters (bottom of this file) that turn them into
-- small signal tables; step logic lives in ProgressionEval.lua; UI.lua only renders and forwards clicks.
--
-- SEMI-AUTOMATIC: a satisfied step is latched and shown as complete, but the pointer moves ONLY on an explicit
-- player action (Next/Confirm, Skip, Previous, Undo, Reset). Nothing here advances on its own. Automatic
-- advancement could later be added at the single point marked AUTO-ADVANCE HOOK without changing detection.
--
-- Step states: NOT_READY (before PLAYER_LOGIN) | WAITING | UNDETECTABLE | SATISFIED (latched) | ROUTE_COMPLETE,
-- with PAUSED as an overlay (detection ignored, manual controls still work).
--
-- Startup (M8.12, real-client verified): SavedVariables exist at ADDON_LOADED, not at file load, so the saved
-- position is read at ADDON_LOADED. Quest state is only valid from PLAYER_LOGIN (before it the log is empty and
-- IsQuestFlaggedCompleted returns false for completed quests), so nothing is evaluated before PLAYER_LOGIN.
--
-- Persistence: ForeverQuestGuideDB.progress = { routeID, stepID, complete, paused, skipped = {[routeID] = {[stepID]
-- = true}} }. Account-wide (shared by all characters). A HINT, not truth: validated on load; logout persistence is
-- not guaranteed on this client (M8.0 SS2). Detection results and latches are never persisted.

local addonName, ns = ...

local MAX_HISTORY = 20
local TICK_SECONDS = 0.5

local routeID, stepIndex = nil, 1
local complete, paused, ready = false, false, false
local latched = {}      -- [stepID] = true while that step instance is satisfied
local current = nil     -- last evaluation result for the current step
local history = {}      -- { kind = "confirm"|"manual"|"skip"|"finish", fromIndex, toIndex, wasComplete, stepID }
local skipped = {}      -- [routeID] = { [stepID] = true }
local onChange = nil
local loadNote = nil
local reader = nil      -- nil = ProgressionEval's default reader; tests inject their own

-- ---------------------------------------------------------------- helpers

local function say(msg)
	if ns.Say then ns.Say(msg) end
end

local function route()
	return routeID and ns.Routes and ns.Routes[routeID] or nil
end

local function order()
	local r = route()
	return r and r.step_order or {}
end

local function stepAt(i)
	local r = route()
	local id = r and r.step_order[i]
	return id and r.steps[id] or nil, id
end

local function currentStepID()
	local _, id = stepAt(stepIndex)
	return id
end

local function db()
	if type(ForeverQuestGuideDB) ~= "table" then return nil end
	ForeverQuestGuideDB.progress = type(ForeverQuestGuideDB.progress) == "table" and ForeverQuestGuideDB.progress or {}
	return ForeverQuestGuideDB.progress
end

local function save()
	local p = db()
	if not p then return end
	p.routeID, p.stepID, p.complete, p.paused, p.skipped = routeID, currentStepID(), complete, paused, skipped
end

local function notify()
	if onChange then pcall(onChange) end
end

local function firstRouteID()
	return ns.RouteOrder and ns.RouteOrder[1] or nil
end

-- ---------------------------------------------------------------- evaluation

--- Evaluates the current step. Latched steps stay satisfied (the M8.9 turn-in reset cannot undo them).
local function evaluate(signal)
	if not ready or paused or complete then return end
	local step, id = stepAt(stepIndex)
	if not step then return end
	if latched[id] then return end
	local res = ns.ProgressionEval.Evaluate(step, signal, reader)
	local changed = not current or current.state ~= res.state or current.reason ~= res.reason
	current = res
	if res.state == "SATISFIED" then
		latched[id] = true
		say(string.format("Step %d complete: %s. Press CONFIRM to continue.", stepIndex, res.reason))
		-- AUTO-ADVANCE HOOK: a future automatic mode would advance here. Semi-automatic mode waits.
	end
	if changed then notify() end
end

--- Arrive on a (possibly new) step: forget its old latch and evaluate it fresh from game state.
local function arrive()
	local id = currentStepID()
	if id then latched[id] = nil end
	current = nil
	save()
	evaluate(nil)
	notify()
end

local function pushHistory(entry)
	table.insert(history, entry)
	if #history > MAX_HISTORY then table.remove(history, 1) end
end

-- ---------------------------------------------------------------- manual controls (always available)

--- Advance exactly one step. From a satisfied step this is the player's confirmation; otherwise a manual advance.
local function next_()
	if not route() or complete then return false end
	local id = currentStepID()
	local kind = latched[id] and "confirm" or "manual"
	if stepIndex >= #order() then
		pushHistory({ kind = "finish", fromIndex = stepIndex, toIndex = stepIndex, wasComplete = false, stepID = id })
		complete = true
		current = nil
		save()
		say("Route complete.")
		notify()
		return true
	end
	pushHistory({ kind = kind, fromIndex = stepIndex, toIndex = stepIndex + 1, wasComplete = false, stepID = id })
	stepIndex = stepIndex + 1
	arrive()
	return true
end

--- Previous is itself a manual correction, so it clears the undo history: Undo only ever reverses the advance
-- the player just made, never a stale one from before they navigated back.
local function previous()
	if not route() then return false end
	history = {}
	if complete then
		complete = false
		arrive()
		return true
	end
	if stepIndex <= 1 then return false end
	stepIndex = stepIndex - 1
	arrive()
	return true
end

local function skip()
	if not route() or complete then return false end
	local id = currentStepID()
	skipped[routeID] = skipped[routeID] or {}
	skipped[routeID][id] = true
	if stepIndex >= #order() then
		pushHistory({ kind = "skip", fromIndex = stepIndex, toIndex = stepIndex, wasComplete = false, stepID = id })
		complete = true
		current = nil
		save()
		notify()
		return true
	end
	pushHistory({ kind = "skip", fromIndex = stepIndex, toIndex = stepIndex + 1, wasComplete = false, stepID = id })
	stepIndex = stepIndex + 1
	arrive()
	return true
end

--- Clear the current step's latch (e.g. after a false "complete") and re-evaluate it.
local function resetStep()
	if not route() or complete then return false end
	arrive()
	-- Visible feedback: on a step that was not complete, a reset re-checks to the same answer and would
	-- otherwise look like it did nothing (found in the M8.13 real-client run).
	local id = currentStepID()
	local outcome = (not ready and "waiting for login") or (paused and "detection paused")
		or (latched[id] and ("complete -- " .. (current and current.reason or "")))
		or (current and current.reason) or "checking"
	say(string.format("Step %d reset and re-checked: %s.", stepIndex, outcome))
	return true
end

--- Reverse the most recent Next/Confirm/Skip/Finish.
local function undo()
	local h = table.remove(history)
	if not h then return false end
	complete = h.wasComplete
	stepIndex = h.fromIndex
	if h.kind == "skip" and skipped[routeID] then skipped[routeID][h.stepID] = nil end
	arrive()
	return true
end

local function setPaused(on)
	paused = on and true or false
	current = nil
	save()
	if not paused then evaluate(nil) end
	notify()
end

local function selectRoute(id)
	if not (ns.Routes and ns.Routes[id]) then return false end
	routeID, stepIndex, complete = id, 1, false
	history = {}
	arrive()
	return true
end

-- ---------------------------------------------------------------- startup

--- ADDON_LOADED: read the saved position (a hint), validate it against the current route data.
local function loadSaved()
	local p = db() or {}
	skipped = type(p.skipped) == "table" and p.skipped or {}
	paused = p.paused == true
	routeID, stepIndex, complete = nil, 1, false
	if p.routeID and ns.Routes and ns.Routes[p.routeID] then
		routeID = p.routeID
		local found
		for i, sid in ipairs(ns.Routes[routeID].step_order) do
			if sid == p.stepID then found = i end
		end
		if found then
			stepIndex = found
			complete = p.complete == true
			loadNote = string.format("restored step %d", found)
		else
			loadNote = "saved step is no longer in this route; starting at step 1"
		end
	else
		routeID = firstRouteID()
		loadNote = p.routeID and "saved route no longer exists; starting at step 1" or "no saved progress; starting at step 1"
	end
	save()
end

--- PLAYER_LOGIN: quest state is valid from here (M8.12). Reconcile the current step against game state.
local function onLogin()
	ready = true
	current = nil
	local r = route()
	if r then
		say(string.format("Progress: %s, step %d of %d (%s).", r.title or routeID, stepIndex, #r.step_order, loadNote or "?"))
	end
	evaluate(nil)
	notify()
end

-- ---------------------------------------------------------------- status for the UI

local function getStatus()
	local s = {
		ready = ready, paused = paused, complete = complete, canUndo = #history > 0,
		satisfied = latched[currentStepID() or ""] == true,
		skipped = skipped[routeID or ""] and skipped[routeID][currentStepID() or ""] == true or false,
	}
	if complete then s.state, s.reason = "ROUTE_COMPLETE", "route complete"
	elseif not ready then s.state, s.reason = "NOT_READY", "waiting for login"
	elseif paused then s.state, s.reason = "PAUSED", "detection paused"
	elseif s.satisfied then s.state, s.reason = "SATISFIED", current and current.reason or "step complete"
	elseif current then s.state, s.reason = current.state, current.reason
	else s.state, s.reason = "WAITING", "checking" end
	return s
end

-- Sane position before ADDON_LOADED (RouteData.lua loads before this file): step 1 of the first route. The
-- saved position, if any, replaces it at ADDON_LOADED.
routeID = firstRouteID()

-- ---------------------------------------------------------------- event adapters (no step logic here)

local frame = CreateFrame("Frame")
local registration = {}
local tickElapsed = 0

local function onEvent(_, event, ...)
	if event == "ADDON_LOADED" then
		if ... == addonName then loadSaved() end
	elseif event == "PLAYER_LOGIN" then
		onLogin()
	elseif event == "QUEST_ACCEPTED" then
		evaluate({ type = "QUEST_ACCEPTED", questID = (...) })
	elseif event == "QUEST_TURNED_IN" then
		evaluate({ type = "QUEST_TURNED_IN", questID = (...) })
	elseif event == "UNIT_QUEST_LOG_CHANGED" then
		if ... == "player" then evaluate({ type = "QUEST_STATE" }) end
	elseif event == "QUEST_LOG_UPDATE" then
		evaluate({ type = "QUEST_STATE" })
	else -- ZONE_CHANGED*
		evaluate({ type = "POSITION" })
	end
end

--- Position checks only while the current step is a TRAVEL step with a destination, not yet satisfied.
local function onUpdate(_, elapsed)
	if not ready or paused or complete then return end
	tickElapsed = tickElapsed + (elapsed or 0)
	if tickElapsed < TICK_SECONDS then return end
	tickElapsed = 0
	local step, id = stepAt(stepIndex)
	if step and not latched[id] and ns.ProgressionEval.NeedsPositionTicks(step) then
		evaluate({ type = "POSITION" })
	end
end

for _, ev in ipairs({ "ADDON_LOADED", "PLAYER_LOGIN", "QUEST_ACCEPTED", "QUEST_TURNED_IN", "UNIT_QUEST_LOG_CHANGED",
	"QUEST_LOG_UPDATE", "ZONE_CHANGED", "ZONE_CHANGED_NEW_AREA", "ZONE_CHANGED_INDOORS" }) do
	local ok, err = pcall(frame.RegisterEvent, frame, ev)
	registration[ev] = ok and "registered" or ("registration_error: " .. tostring(err))
end
frame:SetScript("OnEvent", onEvent)
frame:SetScript("OnUpdate", onUpdate)

ns.Progression = {
	GetPosition = function() return routeID, stepIndex end,
	GetStatus = getStatus,
	Next = next_,
	Previous = previous,
	Skip = skip,
	ResetStep = resetStep,
	Undo = undo,
	SetPaused = setPaused,
	IsPaused = function() return paused end,
	SelectRoute = selectRoute,
	SetOnChange = function(fn) onChange = fn end,
	GetRegistration = function() return registration end,
}

-- Test-only seam (no in-game code path reads it).
ns._progressionTest = {
	setReader = function(r) reader = r end,
	fire = function(event, ...) onEvent(frame, event, ...) end,
	tick = function(dt) onUpdate(frame, dt) end,
	getHistory = function() return history end,
	getLatched = function() return latched end,
}
