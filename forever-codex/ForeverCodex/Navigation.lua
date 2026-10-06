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
local lastWant = nil          -- the destination of the current NOW (whether or not a waypoint could be placed for it)
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

local function playerDistanceTo(ctx, pt)
	local loc = ctx and ctx.loc
	if not (loc and loc.available) then return nil end
	local d = E.Distance(ctx, { map = loc.map, x = loc.x, y = loc.y, world = loc.world or false }, { map = pt.map, x = pt.x, y = pt.y })
	if d == nil or d >= E.DIFFERENT_CONTINENT then return nil end
	return d
end

-- ---------------------------------------------------------------- NAVIGATION SAFETY
-- The game's waypoint and Codex's arrow are STRAIGHT LINES: they know nothing about cliffs, water, portals, boats or zeppelins. Codex has no path, portal or transport data and
-- invents none. So a destination only gets a pin or arrow when Codex can say it is a sensible thing to walk toward in a straight line:
--   * it must be MEASURABLE (a known player position and a known distance: not another continent, not a map Codex cannot convert),
--   * an exact NPC coordinate may be far (MAX_EXACT_YD), an approximate one (an objective area, an assumed hand-in, the game's quest-map point) only moderately far (MAX_APPROX_YD),
--   * a position that is the recorder's PLAYER position (the observed pack) is not an NPC coordinate: only a short distance (MAX_PLAYER_POS_YD), where the last steps are visible,
--   * a far quest whose own objective text names special travel (a boat, portal, zeppelin ...) gets that text, not an arrow, and
--   * a pin farther than STRAIGHT_NOTE_YD is still labelled "straight line only".
-- Quest text, location and the plan are untouched: this only decides whether to POINT. Thresholds are design values, not game facts.
N.MAX_EXACT_YD = 2500
N.MAX_APPROX_YD = 600
N.MAX_PLAYER_POS_YD = 150
N.STRAIGHT_NOTE_YD = 1000
N.TRAVEL_NEAR_YD = 300       -- a target this close is walked to even when its text names a vehicle (the vehicle is probably right there)
N.TRAVEL_WORDS = { "skycutter", "boat", "ship", "zeppelin", "airship", "portal", "ferry", "teleport" }

--- Whether the quest's own objective text (the quest log's words, never Codex data) names special travel. Returns the matching word or nil.
function N.TravelWord(a)
	local texts = {}
	for _, o in ipairs(a and a.objectiveState and a.objectiveState.list or {}) do
		if not o.finished and type(o.text) == "string" then texts[#texts + 1] = o.text:lower() end
	end
	for _, t in ipairs(texts) do
		for _, w in ipairs(N.TRAVEL_WORDS) do
			if t:find("%f[%a]" .. w .. "%f[%A]") then return w end
		end
	end
	return nil
end

local REASON_TEXT = {
	UNMEASURED = "Codex cannot measure the way there from here, so there is no arrow.",
	APPROX_FAR = "Only an approximate area is known and it is far away, so there is no arrow.",
	PLAYER_POSITION_FAR = "Only a spot where someone once stood is known for this, not the NPC's own position, so there is no arrow.",
	IN_AREA = "You are in the objective area. Codex stops steering you toward its marker.",
	IN_INSTANCE = "You are inside an instance, so Codex cannot tell where you are on the outdoor map. There is no arrow until you leave.",
	SPECIAL_TRAVEL = "This quest's own text names special travel (a boat, portal or similar). Follow it: Codex has no route for that, so there is no arrow.",
}
N.REASON_TEXT = REASON_TEXT

--- The eight compass words for a bearing in radians (0 = north, clockwise). The only direction wording Codex uses when it withholds an arrow.
local POINTS = { "north", "north-east", "east", "south-east", "south", "south-west", "west", "north-west" }
function N.Compass(bearing)
	if type(bearing) ~= "number" or bearing ~= bearing then return nil end
	local i = math.floor(((bearing % (2 * math.pi)) / (math.pi / 4)) + 0.5) % 8
	return POINTS[i + 1]
end

-- When the arrow is withheld the player still deserves a direction when Codex can honestly give one: the compass direction from the player to the destination's representative point, said as "roughly", with a
-- rounded distance. It is the same measurement the arrow would use, so it is only given when that measurement exists (same continent, convertible map); it never shows a coordinate, and it never replaces the reason.
local HINT = {
	APPROX_FAR = function(dir, yd) return string.format("Head roughly %s, about %d yards. Only an approximate area is known and it is far away, so there is no arrow.", dir, yd) end,
	PLAYER_POSITION_FAR = function(dir, yd) return string.format("Head roughly %s, about %d yards. Only a spot where someone once stood is known for this, so there is no arrow.", dir, yd) end,
	UNMEASURED = function(dir, yd) return string.format("Head roughly %s, about %d yards. It is too far for a reliable arrow, so there is no arrow.", dir, yd) end,
}

local function withheld(out, reason, ctx, pos)
	out.reason = reason
	out.text = REASON_TEXT[reason]
	local loc = ctx and ctx.loc
	if HINT[reason] and loc and loc.available and ns.Arrow and ns.Arrow.Bearing then
		local ok, b, dist = pcall(ns.Arrow.Bearing, ctx, { map = loc.map, x = loc.x, y = loc.y }, { map = pos.map, x = pos.x, y = pos.y })
		local dir = ok and N.Compass(b)
		if dir and type(dist) == "number" and dist >= 50 then
			local yd = math.floor(dist / 10 + 0.5) * 10
			out.direction, out.hintYards = dir, yd
			out.text = HINT[reason](dir, yd)
		end
	end
	return out
end

--- Should Codex point at this action's destination? Returns { pin = true|false, reason = code|nil, straight = bool, distance = yards|nil, text = player-facing note|nil }.
-- (No location at all is not an assessment: the caller has nothing to point at.)
function N.Assess(a, ctx)
	local out = { pin = false }
	if not a then return out end
	local pos, status
	local kind
	for _, t in ipairs(a.targets or {}) do
		local w = t.where
		if w and w.status ~= "unknown" and w.points and w.points[1] then pos, status, kind = w.points[1], w.status, w.kind break end
	end
	if not pos then
		local p, st = Pl.Locate(a)
		if not p then return out end
		pos, status = p, st
	end
	-- a hand-in (or any target) placed at the observed pack's recorder position keeps that provenance in the quest view even when the contract calls it "assumed giver"
	if kind ~= "player_position" and a.quest and ns.Registry then
		local v = ns.Registry.Quest(a.quest)
		local l = v and v.loc
		if l and l.kind == "player_position" and l.map == pos.map and math.abs(l.x - pos.x) < 1e-6 and math.abs(l.y - pos.y) < 1e-6 then kind = "player_position" end
	end
	-- INSIDE AN INSTANCE the client's map position is not where the player stands (the outdoor map has no place for the inside of a dungeon), so any bearing from it is meaningless: no arrow, no waypoint.
	-- Only when the client SAYS the player is inside one (Context.instance); an unknown state changes nothing.
	if ctx and ctx.instance and ctx.instance.inInstance == true then
		out.reason, out.text = "IN_INSTANCE", REASON_TEXT.IN_INSTANCE
		return out
	end
	-- AN AREA is not a point: while the player is demonstrably inside the objective's area (progress made here, or arrived at its marker) the marker is NOT steered toward
	if kind == "area" and a.kind == "OBJECTIVE" and a.quest and ns.AreaEvidence then
		local inside, why = ns.AreaEvidence.Inside(a.quest, ctx, pos, pos.radius)
		if inside then
			out.reason, out.inArea, out.areaWhy = "IN_AREA", true, why
			out.text = "You are in the objective area. Codex stops steering you toward its marker: the area has no known boundary, so just carry on here."
			out.distance = playerDistanceTo(ctx, pos)
			return out
		end
	end
	local d = playerDistanceTo(ctx, pos)
	out.distance = d
	if d == nil then out.reason = "UNMEASURED" out.text = REASON_TEXT.UNMEASURED return out end
	if kind == "player_position" then
		if d > N.MAX_PLAYER_POS_YD then return withheld(out, "PLAYER_POSITION_FAR", ctx, pos) end
	elseif status ~= "known" then
		if d > N.MAX_APPROX_YD then return withheld(out, "APPROX_FAR", ctx, pos) end
	elseif d > N.MAX_EXACT_YD then
		return withheld(out, "UNMEASURED", ctx, pos)                      -- farther than a straight line means anything
	end
	if d > N.TRAVEL_NEAR_YD and N.TravelWord(a) then out.reason = "SPECIAL_TRAVEL" out.text = REASON_TEXT.SPECIAL_TRAVEL return out end
	out.pin = true
	if d > N.STRAIGHT_NOTE_YD then out.straight = true out.text = "Straight line only: Codex does not know the path, so the arrow ignores cliffs, water and portals." end
	return out
end

--- The point Codex would navigate to for this plan's NOW, or nil (also nil when the destination is not safe to point at; see N.Assess).
local function desired(plan, ctx)
	local a = plan and plan.now
	N.noPin = nil
	if not a then return nil end
	local pos = Pl.Locate(a)
	if not pos then return nil end
	local as = N.Assess(a, ctx)
	if not as.pin then
		N.noPin = { action = a.id, reason = as.reason, distance = as.distance }
		return nil
	end
	return { action = a.id, map = pos.map, x = pos.x, y = pos.y }
end

local function checkArrival(ctx)
	local t = owned or (N.state.status == "unavailable" and lastWant) or nil     -- no pin could be placed: the arrow still needs an arrival
	if not t then return end
	local d = playerDistanceTo(ctx, t)
	if d and d <= N.ARRIVE_RADIUS then
		arrivedFor = t.action
		if owned then clearOwned("arrived") else N.state = { status = "arrived", action = t.action } end
	end
end

--- The destination Codex's own arrow may point at: NOW's target while navigation is on and the player has not arrived. Never claims or
-- touches a waypoint. The arrow is Codex's own frame, so it does NOT depend on who owns the game's single waypoint: another pin
-- (the player's, or one a quest addon sets when a quest is accepted) or the removal of Codex's pin pauses the WAYPOINT, not the arrow.
function N.Target()
	if not (lastWant and P.NavigationOn()) then return nil end
	local st = N.state.status
	if st == "following" or st == "unavailable" or st == "paused-foreign" or st == "dismissed" then
		return { action = lastWant.action, map = lastWant.map, x = lastWant.x, y = lastWant.y }
	end
	return nil
end

function N.OnPlan(plan, ctx)
	lastWant = desired(plan, ctx)
	if arrivedFor and (not lastWant or lastWant.action ~= arrivedFor) then arrivedFor = nil end
	if not N.api.available() then
		N.state = (arrivedFor and lastWant and arrivedFor == lastWant.action) and { status = "arrived", action = arrivedFor } or { status = "unavailable", action = lastWant and lastWant.action }
		return
	end
	local want = lastWant
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
	local base = ns.State and ns.State.ctx
	if not (owned or N.state.status == "unavailable") or not base then return end
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
--- When NOW has a place but Codex chose not to point at it: { action, reason, distance } (reasons: see N.REASON_TEXT), else nil. For the report.
function N.NoPin() return N.noPin end

--- Test/diagnostic reset of the in-memory state only.
function N._Reset() owned, arrivedFor, dismissedFor, quietUntil, sinceCheck, lastWant = nil, nil, nil, 0, 0, nil; N.state = { status = "idle" } end
