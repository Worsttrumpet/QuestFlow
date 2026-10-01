-- ForeverCodex.Navigation: the waypoint follows NOW. A CONSUMER of the plan: the Planner knows nothing about it.
--
--   Navigation.OnPlan(plan, ctx)   after every recompute (event-driven; never per frame)
--   Navigation.Tick(elapsed)       about once a second: only the arrival check (a distance, no placement)
--   Navigation.OnWaypointEvent()   USER_WAYPOINT_UPDATED
--
-- OWNERSHIP. The game has ONE user waypoint and no owner tag, so Codex remembers what it placed (action id + map + x + y)
-- and calls the waypoint its own only while the game reads back exactly that. Therefore it
--   * never overwrites a waypoint it does not own (a player-made pin pauses navigation instead),
--   * never clears a waypoint it does not own,
--   * places only when NOW changes, and does not fight the player: if its pin is removed or replaced it stays quiet for
--     that action (quests can reclaim super-tracking and one pin vanished without a command in M8.10: Codex does not
--     re-assert in a loop),
--   * clears its own pin when NOW completes, changes to something without a location, or the player arrives.
-- Arrival is measured with Codex's own distance (player position -> target), NOT C_Navigation.GetDistance (stale / 0.0
-- readings, M8.10). ARRIVE_RADIUS is a design value (the game's own is about 10 yd).
--
-- Proven on Forever: C_Map.SetUserWaypoint, HasUserWaypoint, GetUserWaypoint (map + x,y read back exactly, M8.10),
-- ClearUserWaypoint, C_SuperTrack.SetSuperTrackedUserWaypoint, UiMapPoint.CreateFromCoordinates, USER_WAYPOINT_UPDATED.
-- NOT proven: whether a waypoint survives /reload or relog (the last placed pin is saved per character and adopted at
-- login only if the game still shows exactly that pin), and cross-continent arrow behaviour.
-- The custom Codex arrow (M8.14) is not integrated: its real-client results are still outstanding.

local addonName, ns = ...
local P = ns.Prefs
local E = ns.Engine
local Pl = ns.Planner

local N = {}
ns.Navigation = N

N.ARRIVE_RADIUS = 20          -- yards
N.SAME = 1e-4                 -- map fractions: two readbacks closer than this are the same point
N.state = { status = "idle" } -- idle | following | paused-foreign | arrived | dismissed | unavailable | off

local owned, arrivedFor, dismissedFor, quietUntil = nil, nil, nil, 0
local sinceCheck = 0

local function now() return type(GetTime) == "function" and GetTime() or 0 end
--- Our own set / clear fires USER_WAYPOINT_UPDATED: events in the next second are not the player's doing.
local function mute() quietUntil = now() + 1 end

-- ---------------------------------------------------------------- the client, behind one table (tests replace it)

local function safe(fn, ...)
	if type(fn) ~= "function" then return false end
	local ok, a, b = pcall(fn, ...)
	if not ok then ns.RecordError("navigation", a) return false end
	return true, a, b
end

N.api = {
	available = function()
		return type(C_Map) == "table" and type(C_Map.SetUserWaypoint) == "function" and type(C_Map.HasUserWaypoint) == "function"
			and type(C_Map.GetUserWaypoint) == "function" and type(UiMapPoint) == "table" and type(UiMapPoint.CreateFromCoordinates) == "function"
	end,
	has = function()
		local ok, v = safe(C_Map.HasUserWaypoint)
		return ok and v == true
	end,
	get = function()
		local ok, p = safe(C_Map.GetUserWaypoint)
		if not ok or type(p) ~= "table" or type(p.uiMapID) ~= "number" then return nil end
		local x, y
		local pos = p.position
		if type(pos) == "table" then
			if type(pos.GetXY) == "function" then
				local ok2, a, b = pcall(pos.GetXY, pos)
				if ok2 then x, y = a, b end
			end
			x, y = x or pos.x, y or pos.y
		end
		if type(x) ~= "number" or type(y) ~= "number" then return nil end
		return { map = p.uiMapID, x = x, y = y }
	end,
	canSet = function(map)
		if type(C_Map.CanSetUserWaypointOnMap) ~= "function" then return true end
		local ok, v = safe(C_Map.CanSetUserWaypointOnMap, map)
		return ok and v == true
	end,
	set = function(map, x, y)
		local okP, pt = safe(UiMapPoint.CreateFromCoordinates, map, x, y)
		if not okP or not pt then return false end
		local ok = safe(C_Map.SetUserWaypoint, pt)
		if ok and type(C_SuperTrack) == "table" then safe(C_SuperTrack.SetSuperTrackedUserWaypoint, true) end
		return ok
	end,
	clear = function()
		local ok = safe(C_Map.ClearUserWaypoint)
		return ok
	end,
}

local function same(a, b)
	return a and b and a.map == b.map and math.abs(a.x - b.x) < N.SAME and math.abs(a.y - b.y) < N.SAME
end

local function save()
	P.SetNavRecord(owned and { action = owned.action, map = owned.map, x = owned.x, y = owned.y } or nil)
end

--- True only while the game reads back exactly the waypoint Codex placed.
local function ownsCurrent()
	if not owned or not N.api.has() then return false end
	return same(N.api.get(), owned)
end

local function clearOwned(status)
	if owned and ownsCurrent() then
		mute()
		N.api.clear()
	end
	owned = nil
	save()
	N.state = { status = status or "idle" }
end

--- The point Codex would navigate to for this plan's NOW, or nil.
local function desired(plan)
	local a = plan and plan.now
	if not a then return nil end
	local pos = Pl.Locate(a)
	if not pos then return nil end
	return { action = a.id, map = pos.map, x = pos.x, y = pos.y }
end

local function playerDistanceTo(ctx, pt)
	local loc = ctx and ctx.loc
	if not (loc and loc.available) then return nil end
	local d = E.Distance(ctx, { map = loc.map, x = loc.x, y = loc.y, world = loc.world or false }, { map = pt.map, x = pt.x, y = pt.y })
	if d == nil or d >= E.DIFFERENT_CONTINENT then return nil end
	return d
end

local function checkArrival(ctx)
	if not owned then return end
	local d = playerDistanceTo(ctx, owned)
	if d and d <= N.ARRIVE_RADIUS then
		arrivedFor = owned.action
		clearOwned("arrived")
	end
end

function N.OnPlan(plan, ctx)
	if not N.api.available() then N.state = { status = "unavailable" } return end
	local want = desired(plan)
	if not P.NavigationOn() then
		if owned then clearOwned("off") else N.state = { status = "off" } end
		return
	end
	if arrivedFor and (not want or want.action ~= arrivedFor) then arrivedFor = nil end
	if dismissedFor and (not want or want.action ~= dismissedFor) then dismissedFor = nil end
	if not want then
		if owned then clearOwned("idle") elseif N.state.status ~= "paused-foreign" then N.state = { status = "idle" } end
		return
	end
	if arrivedFor == want.action then N.state = { status = "arrived", action = want.action } return end
	if dismissedFor == want.action then N.state = { status = "dismissed", action = want.action } return end

	if owned then
		if ownsCurrent() then
			if owned.action == want.action and same(owned, want) then
				N.state = { status = "following", action = want.action }
				checkArrival(ctx)
				return
			end
			-- NOW changed: our own pin moves to the new target (never anyone else's)
		elseif N.api.has() then
			owned = nil                              -- the player (or a quest) put another pin there: it is theirs now
			save()
			N.state = { status = "paused-foreign" }
			return
		else
			dismissedFor = owned.action              -- our pin is gone: do not fight it for this action
			owned = nil
			save()
			N.state = { status = "dismissed", action = dismissedFor }
			return
		end
	elseif N.api.has() then
		N.state = { status = "paused-foreign" }      -- somebody else's pin: never overwrite it
		return
	end

	if not N.api.canSet(want.map) then N.state = { status = "unavailable", action = want.action } return end
	mute()
	if N.api.set(want.map, want.x, want.y) then
		local got = N.api.get()
		if same(got, want) then
			owned = { action = want.action, map = want.map, x = want.x, y = want.y }
			save()
			N.state = { status = "following", action = want.action }
			checkArrival(ctx)
			return
		end
	end
	owned = nil
	save()
	N.state = { status = "unavailable", action = want.action }
end

--- About once a second: has the player arrived? (A distance only; never places or re-places.)
function N.Tick(elapsed)
	sinceCheck = sinceCheck + (elapsed or 0)
	if sinceCheck < 1 then return end
	sinceCheck = 0
	if not owned then return end
	local base = ns.State and ns.State.ctx
	if not base then return end
	checkArrival({ loc = ns.Context.DefaultReader.location(), worldOf = base.worldOf })
end

--- USER_WAYPOINT_UPDATED: the waypoint changed. Ours (we just did it) is ignored; anything else may mean the player acted.
function N.OnWaypointEvent()
	if now() < quietUntil then return end
	if owned and not ownsCurrent() then
		if N.api.has() then
			owned = nil
			save()
			N.state = { status = "paused-foreign" }
		else
			dismissedFor = owned.action
			owned = nil
			save()
			N.state = { status = "dismissed", action = dismissedFor }
		end
	end
end

--- At login: adopt the saved pin only if the game still shows exactly that pin.
function N.Restore()
	local rec = P.NavRecord()
	if rec and N.api.available() and N.api.has() and same(N.api.get(), rec) then
		owned = { action = rec.action, map = rec.map, x = rec.x, y = rec.y }
	else
		owned = nil
		if rec then P.SetNavRecord(nil) end
	end
end

function N.Owned() return owned and { action = owned.action, map = owned.map, x = owned.x, y = owned.y } or nil end
function N.Status() return N.state.status end

--- Test/diagnostic reset of the in-memory state only.
function N._Reset() owned, arrivedFor, dismissedFor, quietUntil, sinceCheck = nil, nil, nil, 0, 0; N.state = { status = "idle" } end
