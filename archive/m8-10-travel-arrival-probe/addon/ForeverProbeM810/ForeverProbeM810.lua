-- ForeverProbeM810: disposable M8.10 research probe.
--
-- ONE question: can TRAVEL arrival be detected on WoW Forever? M8.6-B proved the game can DISPLAY a waypoint
-- (SetUserWaypoint + C_SuperTrack arrow). It did not show that an addon can READ that destination back,
-- measure a distance to it, or learn that the player arrived. Those are tested here, separately:
--
--   destination retrieval : C_Map.HasUserWaypoint / GetUserWaypoint / GetUserWaypointPositionForMap
--   distance              : C_Navigation.GetDistance (game-computed), and our own calculation from
--                           C_Map.GetPlayerMapPosition + C_Map.GetWorldPosFromMapPos / GetMapWorldSize /
--                           UnitPosition
--   arrival               : NAVIGATION_DESTINATION_REACHED, USER_WAYPOINT_UPDATED / the waypoint clearing
--                           itself, SUPER_TRACKING_CHANGED, NAVIGATION_FRAME_* events
--   cross-map             : the same readings with the waypoint on another zone / continent
--
-- No API is assumed to exist. Each is feature-checked and pcall'd, and its presence plus raw return values are
-- recorded, so "absent", "present but returned nil" and "returned a value" are distinguishable.
--
-- | Folder / files     | ForeverProbeM810 / ForeverProbeM810.lua, .toc |
-- | SavedVariables     | ForeverProbeM810DB                            |
-- | Slash command      | /fprobe810  (state | near | pin <map> <x> <y> | clear) |
-- | Chat prefix        | [FProbeM810] (orange)                         |
-- | Version            | m8-10-probe-0.1                               |
--
-- Quest-read-only: never calls any quest function. It DOES set and clear the game's own user waypoint, but
-- only when the operator types /fprobe810 near | pin | clear -- the same SetUserWaypoint call ForeverQuestGuide
-- v0.6's Show on Map already makes (validated M8.6-B). Nothing happens to the waypoint on its own.
--
-- Persistence: end the test with /reload (M8_0_SCOPE.md SS2).

local addonName, ns = ...
local VERSION = "m8-10-probe-0.1"
local PREFIX = "|cffff9933[FProbeM810]|r "

local EVENTS = {
	"USER_WAYPOINT_UPDATED", "SUPER_TRACKING_CHANGED", "NAVIGATION_FRAME_CREATED", "NAVIGATION_FRAME_DESTROYED",
	"NAVIGATION_DESTINATION_REACHED", "ZONE_CHANGED", "ZONE_CHANGED_NEW_AREA", "ZONE_CHANGED_INDOORS",
	"PLAYER_STARTED_MOVING", "PLAYER_STOPPED_MOVING",
}
local NEAR_YARDS = 30          -- /fprobe810 near places a waypoint about this far north of the player
local NEAR_FALLBACK_FRACTION = 0.01
local SAMPLE_INTERVAL = 0.5    -- seconds between samples while a waypoint exists
local STORE_EVERY = 2.0        -- store an unchanged sample at most this often
local CHAT_EVERY = 3.0         -- print distance to chat at most this often
local MAX_RECORDS = 2000

ForeverProbeM810DB = ForeverProbeM810DB or {}
ForeverProbeM810DB.sessions = ForeverProbeM810DB.sessions or {}

local session
local lastSampleAt, lastStoredAt, lastChatAt = 0, 0, 0
local lastStored        -- last stored sample, for change detection
local lastHasWaypoint   -- for arrival-by-clearing detection

-- ---------------------------------------------------------------- helpers

local function say(msg)
	if DEFAULT_CHAT_FRAME then
		DEFAULT_CHAT_FRAME:AddMessage(PREFIX .. msg)
	end
end

local function now()
	if type(GetTime) ~= "function" then return nil end
	local ok, t = pcall(GetTime)
	return ok and t or nil
end

local function api(ns_, name)
	local t = _G[ns_]
	return type(t) == "table" and type(t[name]) == "function" and t[name] or nil
end

--- Calls ns_.name(...) if it exists. Returns a status string plus up to 4 results:
--  "absent" | "error" | "nil" | "ok". Status is recorded with every reading.
local function call(ns_, name, ...)
	local f
	if ns_ then f = api(ns_, name) else f = _G[name] end  -- a missing C_X.name must never fall back to a global
	if type(f) ~= "function" then return "absent" end
	local r = { pcall(f, ...) }
	if not r[1] then return "error", tostring(r[2]) end
	if r[2] == nil then return "nil" end
	return "ok", r[2], r[3], r[4], r[5]
end

--- Vector2D (table with x/y and :GetXY) -> x, y
local function xy(v)
	if type(v) ~= "table" then return nil, nil end
	if type(v.GetXY) == "function" then
		local ok, x, y = pcall(v.GetXY, v)
		if ok then return x, y end
	end
	return v.x, v.y
end

local function record(fields)
	if not session then return end
	if #session.records >= MAX_RECORDS then
		session.cap_reached = true
		return
	end
	fields.seq = #session.records + 1
	fields.t = fields.t or now()
	table.insert(session.records, fields)
end

local function bump(name)
	session.counts[name] = (session.counts[name] or 0) + 1
end

-- ---------------------------------------------------------------- readings

local function worldPos(mapID, x, y)
	if not (mapID and x and y) or type(CreateVector2D) ~= "function" then return nil end
	local okV, v = pcall(CreateVector2D, x, y)
	if not okV then return nil end
	local st, continent, wp = call("C_Map", "GetWorldPosFromMapPos", mapID, v)
	if st ~= "ok" then return { status = st } end
	local wx, wy = xy(wp)
	return { status = st, continent = continent, x = wx, y = wy }
end

local function readPlayer()
	local p = {}
	local st, map = call("C_Map", "GetBestMapForUnit", "player")
	p.map_status, p.map = st, map
	if map then
		local st2, pos = call("C_Map", "GetPlayerMapPosition", map, "player")
		p.pos_status = st2
		p.x, p.y = xy(pos)
		p.world = worldPos(map, p.x, p.y)
		local st3, w, h = call("C_Map", "GetMapWorldSize", map)
		p.map_size_status, p.map_w, p.map_h = st3, w, h
	end
	local st4, uy, ux, uz, inst = call(nil, "UnitPosition", "player")
	p.unitpos_status, p.unit_x, p.unit_y, p.unit_z, p.instance = st4, ux, uy, uz, inst
	return p
end

local function readWaypoint(playerMap)
	local w = {}
	w.has_status, w.has = call("C_Map", "HasUserWaypoint")
	local st, point = call("C_Map", "GetUserWaypoint")
	w.get_status = st
	if type(point) == "table" then
		w.map = point.uiMapID
		w.x, w.y = xy(point.position)
		w.z = point.z
		w.world = worldPos(w.map, w.x, w.y)
	end
	if playerMap then
		local st2, pos = call("C_Map", "GetUserWaypointPositionForMap", playerMap)
		w.on_player_map_status = st2
		w.on_player_map_x, w.on_player_map_y = xy(pos)
	end
	return w
end

local function readTracking()
	local s = {}
	s.st_user_status, s.st_user = call("C_SuperTrack", "IsSuperTrackingUserWaypoint")
	s.st_any_status, s.st_any = call("C_SuperTrack", "IsSuperTrackingAnything")
	s.st_quest_status, s.st_quest = call("C_SuperTrack", "GetSuperTrackedQuestID")
	s.nav_dist_status, s.nav_dist = call("C_Navigation", "GetDistance")
	s.nav_frame_status = call("C_Navigation", "GetFrame")
	s.nav_state_status, s.nav_state = call("C_Navigation", "GetTargetState")
	s.nav_clamped_status, s.nav_clamped = call("C_Navigation", "WasClampedToScreen")
	return s
end

local function dist(ax, ay, bx, by)
	if not (ax and ay and bx and by) then return nil end
	return math.sqrt((ax - bx) ^ 2 + (ay - by) ^ 2)
end

--- Our own distance estimates, each labelled with how it was derived. Never mixed silently.
local function computeDistances(p, w)
	local d = {}
	if p.map and w.map and p.map == w.map then
		d.same_map = true
		d.map_fraction = dist(p.x, p.y, w.x, w.y)
		if p.map_w and p.map_h and p.x and w.x then
			d.yards_from_map_size = dist(p.x * p.map_w, p.y * p.map_h, w.x * p.map_w, w.y * p.map_h)
		end
	else
		d.same_map = false
	end
	if p.world and w.world and p.world.continent and w.world.continent then
		d.same_continent = (p.world.continent == w.world.continent)
		if d.same_continent then
			d.yards_from_world_pos = dist(p.world.x, p.world.y, w.world.x, w.world.y)
		end
	end
	if w.on_player_map_x and p.x then
		d.fraction_via_player_map = dist(p.x, p.y, w.on_player_map_x, w.on_player_map_y)
	end
	return d
end

local function reading()
	local p = readPlayer()
	local w = readWaypoint(p.map)
	local s = readTracking()
	return { player = p, waypoint = w, tracking = s, distances = computeDistances(p, w) }
end

-- ---------------------------------------------------------------- sampling

local function fmt(v, f)
	return v and string.format(f or "%.1f", v) or "-"
end

local function sampleLine(r)
	local d, s = r.distances, r.tracking
	return string.format("nav=%s yd | world=%s yd | mapsize=%s yd | frac=%s | same map=%s",
		fmt(s.nav_dist), fmt(d.yards_from_world_pos), fmt(d.yards_from_map_size), fmt(d.map_fraction, "%.4f"),
		tostring(d.same_map))
end

local function changedEnough(r)
	if not lastStored then return true end
	local a, b = r.player, lastStored.player
	if a.map ~= b.map or (a.x and b.x and dist(a.x, a.y, b.x, b.y) > 0.0005) then return true end
	if r.waypoint.has ~= lastStored.waypoint.has then return true end
	if (r.tracking.nav_dist or -1) ~= (lastStored.tracking.nav_dist or -1) then return true end
	return false
end

local function sample(reason)
	local t = now() or 0
	local r = reading()
	local hasNow = r.waypoint.has == true
	if lastHasWaypoint == true and not hasNow then
		bump("waypoint_disappeared")
		say(string.format("waypoint is GONE (%s). Last distances: %s", reason,
			lastStored and sampleLine(lastStored) or "none"))
		record({ kind = "waypoint_disappeared", reason = reason, last = lastStored, now = r })
	end
	lastHasWaypoint = hasNow
	if reason ~= "tick" or (hasNow and (changedEnough(r) or t - lastStoredAt >= STORE_EVERY)) then
		r.kind, r.reason = "sample", reason
		record(r)
		lastStored, lastStoredAt = r, t
		bump("samples_stored")
	end
	if hasNow and reason == "tick" and t - lastChatAt >= CHAT_EVERY then
		lastChatAt = t
		say(sampleLine(r))
	end
	return r
end

local function onUpdate()
	if not session then return end
	session.onupdate_ticks = (session.onupdate_ticks or 0) + 1
	local t = now()
	if not t or t - lastSampleAt < SAMPLE_INTERVAL then return end
	lastSampleAt = t
	if lastHasWaypoint or lastHasWaypoint == nil then
		sample("tick")
	end
end

-- ---------------------------------------------------------------- waypoint commands (operator-initiated only)

local function mapName(mapID)
	local st, info = call("C_Map", "GetMapInfo", mapID)
	return (st == "ok" and type(info) == "table" and info.name) or ("(" .. st .. ")")
end

local function setWaypoint(mapID, x, y, label)
	local stCan, can = call("C_Map", "CanSetUserWaypointOnMap", mapID)
	if stCan == "ok" and not can then
		say(string.format("map %s does not accept waypoints (CanSetUserWaypointOnMap=false).", tostring(mapID)))
		record({ kind = "command", command = label, map = mapID, x = x, y = y, result = "map_refused" })
		return
	end
	local point
	if api("UiMapPoint", "CreateFromCoordinates") then
		local ok, p = pcall(UiMapPoint.CreateFromCoordinates, mapID, x, y)
		if ok then point = p end
	end
	if not point and type(CreateVector2D) == "function" then
		point = { uiMapID = mapID, position = CreateVector2D(x, y) }
	end
	local st, err = call("C_Map", "SetUserWaypoint", point)
	call("C_SuperTrack", "SetSuperTrackedUserWaypoint", true)
	local name = mapName(mapID)
	record({ kind = "command", command = label, map = mapID, map_name = name, x = x, y = y, set_status = st, set_error = err })
	bump("command:" .. label)
	say(string.format("%s: waypoint set on map %s \"%s\" at %.3f, %.3f (%s).", label, tostring(mapID), name, x, y, st))
	sample("after_set")
end

local function cmdNear()
	local p = readPlayer()
	if not (p.map and p.x and p.y) then
		say("near: player position unavailable on this map; cannot place a nearby waypoint.")
		record({ kind = "command", command = "near", result = "no_player_position", player = p })
		return
	end
	local dy = (p.map_h and p.map_h > 0) and (NEAR_YARDS / p.map_h) or NEAR_FALLBACK_FRACTION
	setWaypoint(p.map, p.x, math.max(0, p.y - dy), "near")
end

local function cmdPin(msg)
	local m, x, y = msg:match("^pin%s+(%d+)%s+([%d%.]+)%s+([%d%.]+)")
	m, x, y = tonumber(m), tonumber(x), tonumber(y)
	if not (m and x and y) or x > 1 or y > 1 then
		say("usage: /fprobe810 pin <mapID> <x 0-1> <y 0-1>   e.g. /fprobe810 pin 1413 0.449 0.591")
		return
	end
	setWaypoint(m, x, y, "pin")
end

local function cmdClear()
	local st = call("C_Map", "ClearUserWaypoint")
	record({ kind = "command", command = "clear", status = st })
	say("waypoint cleared by operator (" .. st .. ").")
	sample("after_clear")
end

local function cmdState()
	local r = sample("state_command")
	local p, w, s = r.player, r.waypoint, r.tracking
	say(string.format("player: map %s (%s) at %s, %s | world %s | UnitPosition %s", tostring(p.map), p.map_status,
		fmt(p.x, "%.4f"), fmt(p.y, "%.4f"), p.world and p.world.status or "-", p.unitpos_status))
	say(string.format("waypoint: HasUserWaypoint %s=%s | GetUserWaypoint %s -> map %s at %s, %s | on player map %s",
		w.has_status, tostring(w.has), w.get_status, tostring(w.map), fmt(w.x, "%.4f"), fmt(w.y, "%.4f"),
		w.on_player_map_status or "-"))
	say(string.format("super-track: user %s=%s any %s=%s | C_Navigation: distance %s=%s frame %s state %s=%s",
		s.st_user_status, tostring(s.st_user), s.st_any_status, tostring(s.st_any), s.nav_dist_status,
		tostring(s.nav_dist), s.nav_frame_status, s.nav_state_status, tostring(s.nav_state)))
	say("distances: " .. sampleLine(r))
end

-- ---------------------------------------------------------------- bootstrap

local frame = CreateFrame("Frame")

local function inventory()
	local list = {
		{ "C_Map", "GetBestMapForUnit" }, { "C_Map", "GetPlayerMapPosition" }, { "C_Map", "GetWorldPosFromMapPos" },
		{ "C_Map", "GetMapWorldSize" }, { "C_Map", "GetMapInfo" }, { "C_Map", "HasUserWaypoint" },
		{ "C_Map", "GetUserWaypoint" }, { "C_Map", "GetUserWaypointPositionForMap" },
		{ "C_Map", "GetUserWaypointHyperlink" }, { "C_Map", "SetUserWaypoint" }, { "C_Map", "ClearUserWaypoint" },
		{ "C_Map", "CanSetUserWaypointOnMap" }, { "C_SuperTrack", "IsSuperTrackingUserWaypoint" },
		{ "C_SuperTrack", "IsSuperTrackingAnything" }, { "C_SuperTrack", "GetSuperTrackedQuestID" },
		{ "C_SuperTrack", "SetSuperTrackedUserWaypoint" }, { "C_Navigation", "GetDistance" },
		{ "C_Navigation", "GetFrame" }, { "C_Navigation", "GetTargetState" }, { "C_Navigation", "WasClampedToScreen" },
		{ "UiMapPoint", "CreateFromCoordinates" },
	}
	local out = {}
	for _, e in ipairs(list) do
		out[e[1] .. "." .. e[2]] = api(e[1], e[2]) and "function" or "absent"
	end
	out.UnitPosition = type(UnitPosition) == "function" and "function" or "absent"
	out.CreateVector2D = type(CreateVector2D) == "function" and "function" or "absent"
	return out
end

local function startSession()
	local okB, gameVersion, build, buildDate, tocVersion = pcall(GetBuildInfo)
	session = {
		probe_version = VERSION, started_t = now(),
		game_version = okB and gameVersion or nil, build = okB and build or nil,
		build_date = okB and buildDate or nil, toc_version = okB and tocVersion or nil,
		counts = {}, records = {}, apis = inventory(), registration = {},
	}
	table.insert(ForeverProbeM810DB.sessions, session)
	for _, ev in ipairs(EVENTS) do
		local ok, err = pcall(frame.RegisterEvent, frame, ev)
		session.registration[ev] = ok and "registered" or ("registration_error: " .. tostring(err))
	end
	pcall(frame.RegisterEvent, frame, "PLAYER_LOGOUT")
	local okU = pcall(frame.SetScript, frame, "OnUpdate", onUpdate)
	session.onupdate_install = okU and "installed" or "failed"
	local present, absent = 0, 0
	for _, v in pairs(session.apis) do if v == "function" then present = present + 1 else absent = absent + 1 end end
	local reg = session.registration
	say(string.format("%s loaded (session %d). APIs present %d / absent %d. NAVIGATION_DESTINATION_REACHED: %s. Type /fprobe810 state.",
		VERSION, #ForeverProbeM810DB.sessions, present, absent, reg.NAVIGATION_DESTINATION_REACHED))
end

frame:SetScript("OnEvent", function(self, event, ...)
	if event == "ADDON_LOADED" then
		if ... == addonName then
			self:UnregisterEvent("ADDON_LOADED")
			startSession()
		end
		return
	end
	if not session then return end
	if event == "PLAYER_LOGOUT" then
		session.final = reading()
		return
	end
	bump(event)
	local args = { n = select("#", ...) }
	for i = 1, args.n do
		local v = select(i, ...)
		args[i] = (type(v) == "table") and "<table>" or v
	end
	record({ kind = "event", event = event, args = args })
	if event == "NAVIGATION_DESTINATION_REACHED" then
		say("NAVIGATION_DESTINATION_REACHED fired. " .. (lastStored and ("Last: " .. sampleLine(lastStored)) or ""))
	elseif event == "USER_WAYPOINT_UPDATED" or event == "SUPER_TRACKING_CHANGED" then
		say(event .. " fired.")
	end
	if event ~= "PLAYER_STARTED_MOVING" and event ~= "PLAYER_STOPPED_MOVING" then
		sample("event:" .. event)
	end
end)
frame:RegisterEvent("ADDON_LOADED")

-- ---------------------------------------------------------------- slash command

SLASH_FOREVERPROBEM8101 = "/fprobe810"
SlashCmdList["FOREVERPROBEM810"] = function(msg)
	if not session then
		say("no session started.")
		return
	end
	msg = (msg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
	if msg == "state" then return cmdState() end
	if msg == "near" then return cmdNear() end
	if msg == "clear" then return cmdClear() end
	if msg:match("^pin") then return cmdPin(msg) end
	local c = session.counts
	say(string.format("events: USER_WAYPOINT_UPDATED=%d SUPER_TRACKING_CHANGED=%d NAV_FRAME created=%d destroyed=%d NAV_DESTINATION_REACHED=%d",
		c.USER_WAYPOINT_UPDATED or 0, c.SUPER_TRACKING_CHANGED or 0, c.NAVIGATION_FRAME_CREATED or 0,
		c.NAVIGATION_FRAME_DESTROYED or 0, c.NAVIGATION_DESTINATION_REACHED or 0))
	say(string.format("waypoint disappeared on its own: %d | samples stored: %d | timer ticks: %d | records: %d%s. /reload to save.",
		c.waypoint_disappeared or 0, c.samples_stored or 0, session.onupdate_ticks or 0, #session.records,
		session.cap_reached and " (cap reached)" or ""))
end

-- Test-only seam on the addon's private namespace (no new global). No in-game code path reads it.
ns._selftest = {
	getSession = function() return session end,
	onUpdate = function() onUpdate() end,
	slash = function(msg) SlashCmdList["FOREVERPROBEM810"](msg) end,
}
