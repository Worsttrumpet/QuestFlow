-- run_probe_selftest.lua -- lua5.1 run_probe_selftest.lua (from this tests/ directory)
--
-- Exercises ForeverProbeM810 against a hand-built fake world: two zones on one continent, one zone on another,
-- a player who can move, and an optional game-side navigation layer that measures distance and auto-clears the
-- waypoint on arrival. Proves the probe's own logic only -- that it reads, computes, labels and records what it
-- is given, degrades when APIs are absent, and never touches quests. It proves NOTHING about Forever.

local passed, failed = 0, 0
local function check(cond, name)
	if cond then passed = passed + 1; print("[OK]   " .. name)
	else failed = failed + 1; print("[FAIL] " .. name) end
end

local function V(x, y)
	return { x = x, y = y, GetXY = function(self) return self.x, self.y end }
end

-- maps: id -> { continent, origin world x/y (yards), width, height (yards) }
local MAPS = {
	[1421] = { c = 0, ox = 0, oy = 0, w = 3000, h = 2000 },     -- "Silverpine"
	[1420] = { c = 0, ox = 3000, oy = 0, w = 3000, h = 2000 },  -- "Tirisfal", same continent
	[1413] = { c = 1, ox = 0, oy = 0, w = 4000, h = 6000 },     -- "Barrens", other continent
}

local function buildWorld(opts)
	opts = opts or {}
	local w = { chat = {}, questCalls = 0, player = { map = 1421, x = 0.5, y = 0.5 }, waypoint = nil }
	_G.ForeverProbeM810DB = opts.db
	_G.DEFAULT_CHAT_FRAME = { AddMessage = function(_, m) table.insert(w.chat, m) end }
	local clock = 100
	_G.GetTime = function() return clock end
	w.advance = function(dt) clock = clock + dt end
	_G.GetBuildInfo = function() return "1.60.1", "70124", "Sep 29 2026", 16001 end
	_G.CreateVector2D = function(x, y) return V(x, y) end
	local function toWorld(map, x, y) local m = MAPS[map]; return m.c, V(m.ox + x * m.w, m.oy + y * m.h) end
	w.worldDist = function()
		if not w.waypoint then return nil end
		local c1, a = toWorld(w.player.map, w.player.x, w.player.y)
		local c2, b = toWorld(w.waypoint.uiMapID, w.waypoint.position.x, w.waypoint.position.y)
		if c1 ~= c2 then return nil end
		return math.sqrt((a.x - b.x) ^ 2 + (a.y - b.y) ^ 2)
	end
	_G.C_Map = {
		GetBestMapForUnit = function() return w.player.map end,
		GetPlayerMapPosition = function(map) if w.noPosition then return nil end
			if map == w.player.map then return V(w.player.x, w.player.y) end end,
		GetWorldPosFromMapPos = function(map, v) return toWorld(map, v.x, v.y) end,
		GetMapWorldSize = function(map) return MAPS[map].w, MAPS[map].h end,
		GetMapInfo = function(map) return MAPS[map] and { name = "Map" .. map } end,
		HasUserWaypoint = function() return w.waypoint ~= nil end,
		GetUserWaypoint = function() return w.waypoint end,
		GetUserWaypointPositionForMap = function(map)
			if w.waypoint and w.waypoint.uiMapID == map then return w.waypoint.position end end,
		CanSetUserWaypointOnMap = function(map) return MAPS[map] ~= nil end,
		SetUserWaypoint = function(p) w.waypoint = p end,
		ClearUserWaypoint = function() w.waypoint = nil end,
	}
	_G.UiMapPoint = { CreateFromCoordinates = function(m, x, y) return { uiMapID = m, position = V(x, y) } end }
	_G.C_SuperTrack = {
		SetSuperTrackedUserWaypoint = function(on) w.tracking = on end,
		IsSuperTrackingUserWaypoint = function() return w.tracking == true and w.waypoint ~= nil end,
		IsSuperTrackingAnything = function() return w.tracking == true and w.waypoint ~= nil end,
	}
	if not opts.noNavigation then
		_G.C_Navigation = {
			GetDistance = function() return w.worldDist() or 0 end,
			GetFrame = function() return w.waypoint and {} or nil end,
		}
	else
		_G.C_Navigation = nil
	end
	_G.UnitPosition = function() local _, p = toWorld(w.player.map, w.player.x, w.player.y); return p.y, p.x, 0, 0 end
	-- quest functions exist; the probe must never call them
	for _, n in ipairs({ "AcceptQuest", "AbandonQuest", "CompleteQuest", "GetQuestReward" }) do
		_G[n] = function() w.questCalls = w.questCalls + 1 end
	end
	_G.SlashCmdList = {}
	_G.CreateFrame = function()
		local f = { registered = {}, scripts = {} }
		function f:RegisterEvent(ev)
			if opts.unknownEvents and opts.unknownEvents[ev] then error("unknown event " .. ev) end
			self.registered[ev] = true
		end
		function f:UnregisterEvent(ev) self.registered[ev] = nil end
		function f:SetScript(n, fn) self.scripts[n] = fn end
		w.frame = f
		return f
	end
	w.fire = function(ev, ...) if w.frame.registered[ev] then w.frame.scripts.OnEvent(w.frame, ev, ...) end end
	w.run = function(seconds)
		for _ = 1, math.floor(seconds / 0.1 + 0.5) do
			w.advance(0.1)
			w.frame.scripts.OnUpdate(w.frame, 0.1)
			-- game-side arrival: optionally auto-clear within 10 yards
			if opts.autoArrive and w.waypoint and (w.worldDist() or 1e9) < 10 then
				w.waypoint = nil
				w.fire("NAVIGATION_DESTINATION_REACHED")
				w.fire("USER_WAYPOINT_UPDATED")
			end
		end
	end
	local ns = {}
	assert(loadfile("../addon/ForeverProbeM810/ForeverProbeM810.lua"))("ForeverProbeM810", ns)
	w.ns = ns
	w.fire("ADDON_LOADED", "ForeverProbeM810")
	return w
end

local function records(s, kind)
	local out = {}
	for _, r in ipairs(s.records) do if r.kind == kind then table.insert(out, r) end end
	return out
end

print("== scenario 1: inventory, registration, stationary state ==")
local w = buildWorld({ autoArrive = true })
local s = w.ns._selftest.getSession()
check(s.apis["C_Map.GetUserWaypoint"] == "function" and s.apis["C_Navigation.GetTargetState"] == "absent",
	"API inventory distinguishes present and absent")
check(s.registration.NAVIGATION_DESTINATION_REACHED == "registered", "arrival event registration recorded")
w.ns._selftest.slash("state")
local st = records(s, "sample")[#records(s, "sample")]
check(st.waypoint.has == false and st.waypoint.get_status == "nil", "no waypoint: HasUserWaypoint false, GetUserWaypoint nil")
check(st.tracking.nav_state_status == "absent", "absent C_Navigation.GetTargetState recorded as absent, not nil")
local sawState = 0
for _, m in ipairs(w.chat) do if m:find("player: map 1421") or m:find("waypoint: HasUserWaypoint") then sawState = sawState + 1 end end
check(sawState == 2, "/fprobe810 state prints player and waypoint lines")

print("== scenario 2: near waypoint, readback and distances ==")
w.ns._selftest.slash("near")
local cmd = records(s, "command")[1]
check(cmd and cmd.map_name == "Map1421", "map name recorded with the command")
check(cmd and cmd.command == "near" and cmd.map == 1421 and math.abs((0.5 - cmd.y) * 2000 - 30) < 0.01, "near places a waypoint 30 yards north")
local after = records(s, "sample")[#records(s, "sample")]
check(after.waypoint.has == true and after.waypoint.map == 1421, "waypoint read back with its map")
check(math.abs(after.distances.yards_from_world_pos - 30) < 0.01, "world-position distance = 30 yd")
check(math.abs(after.distances.yards_from_map_size - 30) < 0.01, "map-size distance = 30 yd")
check(math.abs(after.tracking.nav_dist - 30) < 0.01, "game navigation distance recorded")
check(after.distances.same_map == true and after.distances.same_continent == true, "same map / continent flags")

print("== scenario 3: walking toward it, then arrival ==")
for _ = 1, 30 do
	w.player.y = w.player.y - 1 / 2000   -- 1 yard per step
	w.run(0.2)
end
local gone = records(s, "waypoint_disappeared")
check(#gone == 1 and gone[1].reason:find("NAVIGATION_DESTINATION_REACHED"), "arrival: disappearance recorded with the event that caused it")
check(gone[1].last and gone[1].last.tracking.nav_dist < 12, "last distance before arrival preserved")
check(s.counts.NAVIGATION_DESTINATION_REACHED == 1, "arrival event counted")
local chatDist = 0
for _, m in ipairs(w.chat) do if m:find("nav=.* yd | world=") then chatDist = chatDist + 1 end end
check(chatDist >= 2, "distance printed to chat while moving")
local stored = #records(s, "sample")
w.run(5)
check(#records(s, "sample") == stored, "sampling stops once no waypoint exists")

print("== scenario 4: other continent and other zone ==")
w.ns._selftest.slash("pin 1413 0.449 0.591")
local far = records(s, "sample")[#records(s, "sample")]
check(far.waypoint.map == 1413 and far.distances.same_map == false and far.distances.same_continent == false,
	"cross-continent: waypoint read, flagged different map and continent")
check(far.waypoint.on_player_map_status == "nil", "waypoint not placeable on the player's map recorded as nil")
check(far.distances.yards_from_world_pos == nil, "no cross-continent distance invented")
w.ns._selftest.slash("pin 1420 0.1 0.5")
local adj = records(s, "sample")[#records(s, "sample")]
check(adj.distances.same_map == false and adj.distances.same_continent == true
	and math.abs(adj.distances.yards_from_world_pos - 1800) < 0.5, "same continent, other zone: world distance computed")

print("== scenario 5: operator clear is distinguishable from arrival ==")
w.ns._selftest.slash("clear")
local g2 = records(s, "waypoint_disappeared")
check(#g2 == 2 and g2[2].reason == "after_clear", "operator clear recorded as after_clear")

print("== scenario 6: bad input, refused map, no position ==")
w.ns._selftest.slash("pin 9999 0.5 0.5")
check(records(s, "command")[#records(s, "command")].result == "map_refused", "map refusing waypoints recorded")
local before = #records(s, "command")
w.ns._selftest.slash("pin 1413 5 5")
check(#records(s, "command") == before, "out-of-range coordinates rejected with usage")
w.noPosition = true
w.ns._selftest.slash("near")
check(records(s, "command")[#records(s, "command")].result == "no_player_position", "no player position handled")
w.noPosition = false

print("== scenario 7: summary, logout, read-only ==")
w.ns._selftest.slash("")
check(w.chat[#w.chat]:find("/reload"), "summary reminds to /reload")
w.fire("PLAYER_LOGOUT")
check(s.final and s.final.player.map == 1421, "final reading on logout/reload")
check(w.questCalls == 0, "no quest function was ever called")

print("== scenario 8: client without C_Navigation or the arrival event ==")
w = buildWorld({ noNavigation = true, unknownEvents = { NAVIGATION_DESTINATION_REACHED = true } })
s = w.ns._selftest.getSession()
check(s.registration.NAVIGATION_DESTINATION_REACHED:find("^registration_error"), "unknown event recorded, no crash")
w.ns._selftest.slash("near")
local r = records(s, "sample")[#records(s, "sample")]
check(r.tracking.nav_dist_status == "absent" and math.abs(r.distances.yards_from_world_pos - 30) < 0.01,
	"without C_Navigation, own distance still computed")
w.player.y = w.player.y - 30 / 2000
w.run(3)
check(#records(s, "waypoint_disappeared") == 0, "no arrival invented when the game does not clear the waypoint")

print("== scenario 9: SavedVariables appended ==")
w = buildWorld({ db = { sessions = { { probe_version = "earlier" } } } })
check(#ForeverProbeM810DB.sessions == 2 and ForeverProbeM810DB.sessions[1].probe_version == "earlier", "earlier session preserved")

print(string.format("\n%d passed, %d failed", passed, failed))
os.exit(failed == 0 and 0 or 1)
