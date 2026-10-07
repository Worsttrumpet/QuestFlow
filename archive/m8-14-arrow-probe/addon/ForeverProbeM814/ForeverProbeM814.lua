-- ForeverProbeM814: disposable M8.14 research probe for the Guide Arrow and draggable UI.
--
-- Questions (none verified on Forever before this probe):
--   1. GetPlayerFacing(): does it exist and change as the player turns? What is its CONVENTION
--      (value at north, direction of increase)?                                              [v0.2: /fprobe814 face]
--   2. World axes: which of C_Map.GetWorldPosFromMapPos's x/y is north/east, and with what sign? [v0.2: /fprobe814 mark]
--   3. Built-in arrow textures: do candidate paths load, which way does each point at rotation 0, and does
--      Texture:SetRotation work?
--   4. Arrow glyphs (U+2191 etc.) in the game font: rendered, or blank boxes like emoji (M8.3)?
--   5. Right-button drag on a Frame AND on a Button whose left click must keep working (the minimap button case);
--      GetCursorPosition and Minimap geometry for ring positioning.                           [v0.2]
--   6. Bearing end to end: a test arrow aimed at a fixed destination, with every intermediate number shown.
-- Also records presence of GetCursorPosition, UnitPosition and Minimap geometry for later use.
--
-- | Folder / files     | ForeverProbeM814 / ForeverProbeM814.lua, .toc |
-- | SavedVariables     | ForeverProbeM814DB  (attached at ADDON_LOADED -- M8.12)  |
-- | Slash command      | /fprobe814 (toggle window) | report | calc | geo | mark start|north|east | face N|E|S|W |
-- |                    | tex A|B|C|D | target jorn|here | clear |
-- | Chat prefix        | [FProbeM814]                                  |
--
-- Read-only: creates one test window; no quest, map, or waypoint calls. This is NOT the Guide Arrow. The bearing
-- arrows here exist only to show, with the numbers beside them, which convention the real client reports.

local addonName, ns = ...
local VERSION = "m8-14-probe-0.2"
local PREFIX = "|cffffcc33[FProbeM814]|r "

local PI = math.pi
local TWO_PI = 2 * math.pi
local MIN_LEG_YARDS = 10      -- a mark leg shorter than this proves nothing about an axis
local MIN_LEG_RATIO = 2       -- a leg must be at least this much more along one axis than the other
local CONVENTION_TOLERANCE = 0.5 -- radians; how close a quarter-turn must be to pi/2 to be believed
local BEARING_LOG_EVERY = 3   -- seconds between saved bearing snapshots
local BEARING_LOG_MAX = 40

-- Candidate textures: built-in UI art that exists on Blizzard clients. Whether each path exists on Forever is
-- exactly what is being tested; nothing assumes any of them loads.
local TEXTURES = {
	{ key = "A", path = "Interface\\Minimap\\MinimapArrow" },
	{ key = "B", path = "Interface\\Minimap\\Rotating-MinimapGuideArrow" },
	{ key = "C", path = "Interface\\Buttons\\UI-SpellbookIcon-NextPage-Up" },
	{ key = "D", path = "Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Up" },
}
-- Glyph line: up, up-right, right, down-right, down, check mark, then ASCII fallbacks.
local GLYPHS = "\226\134\145 \226\134\151 \226\134\146 \226\134\152 \226\134\147 \226\156\147  ^ > v <"

-- Fixed bearing target: the M6-observed turn-in position of route step s4 (Jorn Skyseer, Barrens).
local TARGET_JORN = { label = "Jorn Skyseer turn-in (route step s4)", map = 1413, x = 0.448696494102478, y = 0.5909364223480225 }

-- The facing keys the player is asked to face, in the order they are most useful.
local FACE_KEYS = { N = true, E = true, S = true, W = true }
local MARK_KEYS = { start = true, north = true, east = true }

local session
local window
local results = { textures = {}, drag = {}, button = {}, geometry = {}, marks = {}, faces = {}, derived = {}, bearing_log = {} }
local arrowKey = "A"
local target -- { label, map, x, y, world = { continent, x, y } }
local clock = 0

local function say(msg)
	if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage(PREFIX .. msg) end
end

-- ---------------------------------------------------------------- pure helpers (no client access)

--- Numbers only: NaN and infinity are dropped so SavedVariables stays loadable.
local function num(v)
	if type(v) ~= "number" or v ~= v or v == math.huge or v == -math.huge then return nil end
	return v
end

--- Wraps an angle into [-pi, pi).
local function normPi(a) return (a + PI) % TWO_PI - PI end
--- Wraps an angle into [0, 2pi).
local function norm2pi(a) return a % TWO_PI end

local function deg(r) return r * 180 / PI end

local function signChar(s) return (s or 0) >= 0 and "+" or "-" end

--- Describes one walked leg between two {v1, v2} positions: which component dominates, with which sign.
local function legInfo(a, b, names)
	local d1, d2 = b[1] - a[1], b[2] - a[2]
	local len = math.sqrt(d1 * d1 + d2 * d2)
	local idx, sign, ratio
	if math.abs(d1) >= math.abs(d2) then
		idx, sign, ratio = 1, (d1 >= 0) and 1 or -1, math.abs(d1) / math.max(math.abs(d2), 1e-9)
	else
		idx, sign, ratio = 2, (d2 >= 0) and 1 or -1, math.abs(d2) / math.max(math.abs(d1), 1e-9)
	end
	return { d1 = d1, d2 = d2, len = len, index = idx, axis = names[idx], sign = sign, ratio = ratio }
end

--- Derives which position component is north and which is east, from three marks (start, a walk north, a walk
-- east). positions are { v1, v2 }; names label the components ({"x","y"} for world coordinates). Nothing is
-- assumed: the result states what the walked legs show, and why it is not usable when they do not.
local function deriveAxes(start, north, east, names)
	local out = { status = "need marks", text = "axes: need marks start+north+east" }
	if not (start and north and east) then return out end
	local n, e = legInfo(start, north, names), legInfo(start, east, names)
	out.north = { axis = n.axis, index = n.index, sign = n.sign, len = n.len, ratio = n.ratio }
	out.east = { axis = e.axis, index = e.index, sign = e.sign, len = e.len, ratio = e.ratio }
	if n.len < MIN_LEG_YARDS or e.len < MIN_LEG_YARDS then
		out.status = "leg too short"
	elseif n.ratio < MIN_LEG_RATIO or e.ratio < MIN_LEG_RATIO then
		out.status = "leg not straight"
	elseif n.index == e.index then
		out.status = "same axis"
	else
		out.status = "ok"
	end
	out.text = string.format("axes: north=%s%s (%.1f yd) east=%s%s (%.1f yd) [%s]",
		signChar(n.sign), n.axis, n.len, signChar(e.sign), e.axis, e.len, out.status)
	return out
end

--- Derives GetPlayerFacing's convention from readings taken while facing N/E/S/W: the value at north, and
-- whether it increases counter-clockwise (the retail convention) or clockwise. samples = { N=, E=, S=, W= }
-- (radians, any subset that includes N plus at least one of E/W/S).
local function deriveFacing(samples)
	local out = { status = "need faces", text = "facing: need face N plus E or W" }
	if type(samples) ~= "table" or not samples.N then return out end
	local offset = samples.N
	out.offset = offset
	out.zero_at_north = (math.abs(normPi(offset)) <= CONVENTION_TOLERANCE)
	out.diffs = {}
	local ccwVotes, cwVotes = 0, 0
	-- Quarter turns expected from north if increasing counter-clockwise: W=+pi/2, S=pi, E=-pi/2.
	local expectCCW = { W = PI / 2, E = -PI / 2 }
	for key, want in pairs(expectCCW) do
		local v = samples[key]
		if v then
			local d = normPi(v - offset)
			out.diffs[key] = d
			if math.abs(normPi(d - want)) <= CONVENTION_TOLERANCE then ccwVotes = ccwVotes + 1 end
			if math.abs(normPi(d + want)) <= CONVENTION_TOLERANCE then cwVotes = cwVotes + 1 end
		end
	end
	if samples.S then out.diffs.S = normPi(samples.S - offset) end
	if out.diffs.W == nil and out.diffs.E == nil then
		out.status = "need E or W"
	elseif ccwVotes > 0 and cwVotes == 0 then
		out.status, out.direction = "ok", "CCW"
	elseif cwVotes > 0 and ccwVotes == 0 then
		out.status, out.direction = "ok", "CW"
	else
		out.status = "unclear"
	end
	out.text = string.format("facing: N=%.2f rad (zero at north: %s) increases %s [%s]", offset,
		tostring(out.zero_at_north), tostring(out.direction or "?"), out.status)
	return out
end

--- Computes the bearing from player to destination under an explicit convention, keeping every intermediate.
-- p, d: { x, y } world coordinates. axes: { north = { axis, sign }, east = { axis, sign } }.
-- fconv: { offset, direction } from deriveFacing. facing: the live GetPlayerFacing value (radians).
-- Rotation values assume the arrow art points UP at rotation 0 and that SetRotation is counter-clockwise on
-- screen; both are checked by the rest-orientation row and the screenshot, not assumed as fact here.
local function bearing(p, d, axes, fconv, facing)
	if not (p and d and axes and axes.north and axes.east and fconv and fconv.direction and facing) then
		return nil, "conventions not derived"
	end
	local dx, dy = d.x - p.x, d.y - p.y
	local nComp = axes.north.sign * ((axes.north.axis == "x") and dx or dy)
	local eComp = axes.east.sign * ((axes.east.axis == "x") and dx or dy)
	local compass = norm2pi(math.atan2(eComp, nComp)) -- clockwise from north to the destination
	local turned = facing - fconv.offset
	local playerCompass = norm2pi((fconv.direction == "CCW") and -turned or turned)
	local rel = normPi(compass - playerCompass) -- clockwise angle from where I face to the destination
	return {
		dx = dx, dy = dy, dist = math.sqrt(dx * dx + dy * dy), north_comp = nComp, east_comp = eComp,
		compass_cw = compass, player_compass_cw = playerCompass, rel_cw = rel,
		rot_derived = -rel, rot_mirrored = rel,
	}
end

-- ---------------------------------------------------------------- client readers (all guarded)

local function exists(name)
	return type(_G[name]) == "function" and "function" or "absent"
end

--- Calls a global function or a field of a global table without raising: returns status, then results.
local function call(tbl, name, ...)
	local f
	if tbl then
		local t = _G[tbl]
		f = type(t) == "table" and t[name] or nil
	else
		f = _G[name]
	end
	if type(f) ~= "function" then return "absent" end
	local ok, a, b, c, d = pcall(f, ...)
	if not ok then return "error", tostring(a) end
	return "ok", a, b, c, d
end

local function xyOf(pos)
	if type(pos) ~= "table" then return nil, nil end
	if type(pos.GetXY) == "function" then
		local ok, a, b = pcall(pos.GetXY, pos)
		if ok then return a, b end
	end
	return pos.x, pos.y
end

local function readFacing()
	if type(GetPlayerFacing) ~= "function" then return "absent" end
	local ok, v = pcall(GetPlayerFacing)
	if not ok then return "error", tostring(v) end
	if v == nil then return "nil" end
	if num(v) == nil then return "bad" end -- NaN or infinity: never stored, never rotated with
	return "ok", v
end

--- World position for a map position, or nil. Same call chain as the M8.10 probe (real-client validated for
-- distance); here it is also used for direction, which M8.10 never needed.
local function worldPos(mapID, x, y)
	if not (mapID and x and y) or type(CreateVector2D) ~= "function" then return nil end
	local okV, v = pcall(CreateVector2D, x, y)
	if not okV then return nil end
	local st, continent, wp = call("C_Map", "GetWorldPosFromMapPos", mapID, v)
	if st ~= "ok" then return nil end
	local wx, wy = xyOf(wp)
	wx, wy = num(wx), num(wy)
	if not (wx and wy) then return nil end
	return { continent = continent, x = wx, y = wy }
end

local function readPlayer()
	local p = {}
	local _, map = call("C_Map", "GetBestMapForUnit", "player")
	p.map = num(map)
	if p.map then
		local _, pos = call("C_Map", "GetPlayerMapPosition", p.map, "player")
		p.mapx, p.mapy = xyOf(pos)
		p.mapx, p.mapy = num(p.mapx), num(p.mapy)
		p.world = worldPos(p.map, p.mapx, p.mapy)
	end
	-- UnitPosition returns two horizontal components whose order is itself something to learn: kept raw.
	local st, r1, r2, r3, inst = call(nil, "UnitPosition", "player")
	if st == "ok" then
		p.unit = { r1 = num(r1), r2 = num(r2), r3 = num(r3), instance = num(inst) }
		if not (p.unit.r1 and p.unit.r2) then p.unit = nil end
	end
	return p
end

local function readGeometry()
	local g = results.geometry
	g.uiparent_scale = num(UIParent and UIParent.GetScale and UIParent:GetScale())
	g.uiparent_effective_scale = num(UIParent and UIParent.GetEffectiveScale and UIParent:GetEffectiveScale())
	g.uiparent_width = num(UIParent and UIParent.GetWidth and UIParent:GetWidth())
	g.uiparent_height = num(UIParent and UIParent.GetHeight and UIParent:GetHeight())
	if type(Minimap) == "table" then
		local function m(name, ...)
			if type(Minimap[name]) ~= "function" then return nil end
			local ok, a, b = pcall(Minimap[name], Minimap, ...)
			if ok then return a, b end
			return nil
		end
		g.minimap_exists = true
		g.minimap_center_x, g.minimap_center_y = m("GetCenter")
		g.minimap_center_x, g.minimap_center_y = num(g.minimap_center_x), num(g.minimap_center_y)
		g.minimap_width, g.minimap_height = num(m("GetWidth")), num(m("GetHeight"))
		g.minimap_effective_scale = num(m("GetEffectiveScale"))
		g.minimap_zoom = num(m("GetZoom"))
	else
		g.minimap_exists = false
	end
	g.get_minimap_shape = exists("GetMinimapShape")
	if g.get_minimap_shape == "function" then
		local ok, shape = pcall(GetMinimapShape)
		g.minimap_shape = ok and type(shape) == "string" and shape or nil
	end
	g.get_cursor_position = exists("GetCursorPosition")
	return g
end

local function cursorPos()
	if type(GetCursorPosition) ~= "function" then return nil end
	local ok, x, y = pcall(GetCursorPosition)
	if not ok then return nil end
	x, y = num(x), num(y)
	if not (x and y) then return nil end
	return x, y
end

--- Angle in degrees, counter-clockwise from east, of the cursor around the Minimap centre (the quantity a
-- ring-positioned minimap button would save). Returns nil if either input is unavailable.
local function ringAngle()
	local cx, cy = cursorPos()
	local g = readGeometry()
	if not (cx and cy and g.minimap_center_x and g.minimap_center_y) then return nil end
	local s = g.minimap_effective_scale or 1
	if s == 0 then s = 1 end
	return deg(math.atan2(cy / s - g.minimap_center_y, cx / s - g.minimap_center_x)), cx, cy
end

-- ---------------------------------------------------------------- derived state

local function marksAsPositions(kind)
	local m = results.marks
	local function pick(name)
		local e = m[name]
		if not e then return nil end
		if kind == "world" then return e.world and { e.world.x, e.world.y } or nil end
		return e.unit and { e.unit.r1, e.unit.r2 } or nil
	end
	return pick("start"), pick("north"), pick("east")
end

local function recompute()
	local d = results.derived
	local s, n, e = marksAsPositions("world")
	d.axes_world = deriveAxes(s, n, e, { "x", "y" })
	local su, nu, eu = marksAsPositions("unit")
	d.axes_unit = deriveAxes(su, nu, eu, { "r1", "r2" })
	d.facing = deriveFacing(results.faces)
	return d
end

local function currentTarget()
	return target
end

local function setTarget(t)
	target = { label = t.label, map = t.map, x = t.x, y = t.y, world = worldPos(t.map, t.x, t.y) }
	results.target = { label = target.label, map = target.map, x = num(target.x), y = num(target.y), world = target.world }
end

--- Live bearing under (a) the conventions this probe derived and (b) a clearly labelled BASELINE ASSUMPTION
-- (north = +x, east = -y, facing zero at north increasing counter-clockwise). The baseline is NOT evidence; it
-- is shown only so the screenshot can compare "what retail documentation would predict" with what was derived.
local BASELINE_AXES = { north = { axis = "x", sign = 1 }, east = { axis = "y", sign = -1 } }
local BASELINE_FACING = { offset = 0, direction = "CCW" }

local function liveBearing()
	local st, facing = readFacing()
	local p = readPlayer()
	local t = currentTarget()
	local live = { facing_status = st, facing = facing, player = p }
	if not (t and t.world and p.world) then
		live.reason = "player or target world position unavailable"
		return live
	end
	if t.world.continent ~= p.world.continent then
		live.reason = "target is on another continent"
		return live
	end
	local d = results.derived
	if d.axes_world and d.axes_world.status == "ok" and d.facing and d.facing.status == "ok" and st == "ok" then
		live.derived = bearing(p.world, t.world, d.axes_world, d.facing, facing)
	end
	if st == "ok" then
		live.baseline = bearing(p.world, t.world, BASELINE_AXES, BASELINE_FACING, facing)
	end
	return live
end

-- ---------------------------------------------------------------- window

local function setRot(tex, r)
	if not tex or r == nil then return false end
	return (pcall(tex.SetRotation, tex, r))
end

local function arrowPath()
	for _, t in ipairs(TEXTURES) do
		if t.key == arrowKey then return t.path end
	end
	return TEXTURES[1].path
end

local function f2(v) return v and string.format("%.2f", v) or "-" end
local function f1(v) return v and string.format("%.1f", v) or "-" end

local function formatBearing(label, b)
	if not b then return label .. ": -" end
	return string.format("%s: compass %.0f  me %.0f  rel %+.0f deg | rot D=%+.2f M=%+.2f", label,
		deg(b.compass_cw), deg(b.player_compass_cw), deg(b.rel_cw), b.rot_derived, b.rot_mirrored)
end

local function refreshText(live)
	if not window or not window.info then return end
	local d = results.derived
	local lines = {}
	local p = live.player
	local t = currentTarget()
	lines[1] = string.format("me world (%s, %s)  target %s (%s, %s)", f1(p.world and p.world.x), f1(p.world and p.world.y),
		t and t.label or "none", f1(t and t.world and t.world.x), f1(t and t.world and t.world.y))
	local b = live.derived or live.baseline
	if b then
		lines[2] = string.format("dx %.1f dy %.1f dist %.1f yd | north_comp %.1f east_comp %.1f", b.dx, b.dy, b.dist, b.north_comp, b.east_comp)
	else
		lines[2] = "bearing: " .. tostring(live.reason or "waiting for facing")
	end
	lines[3] = (d.axes_world and d.axes_world.text) or "axes: need marks"
	lines[4] = (d.facing and d.facing.text) or "facing: need faces"
	lines[5] = formatBearing("derived", live.derived)
	lines[6] = formatBearing("baseline*", live.baseline) .. "  (*assumed, not evidence)"
	window.info:SetText(table.concat(lines, "\n"))
end

local function logBearing(live)
	if clock - (results.last_bearing_log or -999) < BEARING_LOG_EVERY then return end
	if not (live.derived or live.baseline) then return end
	results.last_bearing_log = clock
	local log = results.bearing_log
	if #log >= BEARING_LOG_MAX then return end
	local p = live.player
	local entry = {
		t = num(clock), facing = num(live.facing),
		px = num(p.world and p.world.x), py = num(p.world and p.world.y),
	}
	local b = live.derived
	if b then
		entry.derived = { dist = num(b.dist), compass_cw = num(b.compass_cw), rel_cw = num(b.rel_cw), north_comp = num(b.north_comp), east_comp = num(b.east_comp) }
	end
	local base = live.baseline
	if base then
		entry.baseline = { dist = num(base.dist), compass_cw = num(base.compass_cw), rel_cw = num(base.rel_cw) }
	end
	table.insert(log, entry)
end

local function buildTestButton()
	local tb = CreateFrame("Button", "ForeverProbeM814TestButton", window)
	tb:SetSize(96, 24)
	tb:SetPoint("BOTTOMLEFT", window, "BOTTOMLEFT", 12, 10)
	local bg = tb:CreateTexture(nil, "BACKGROUND")
	bg:SetAllPoints()
	bg:SetColorTexture(0.2, 0.2, 0.5, 1)
	local label = tb:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	label:SetPoint("CENTER")
	label:SetText("L-click R-drag")

	local b = results.button
	local api = {}
	for _, m in ipairs({ "RegisterForClicks", "RegisterForDrag", "SetMovable", "StartMoving", "StopMovingOrSizing", "GetPoint" }) do
		api[m] = type(tb[m]) == "function"
	end
	b.api = api
	pcall(tb.SetMovable, tb, true)
	b.register_clicks_ok = (pcall(tb.RegisterForClicks, tb, "LeftButtonUp", "RightButtonUp"))
	b.register_drag_ok = (pcall(tb.RegisterForDrag, tb, "RightButton"))
	b.left_clicks, b.right_clicks, b.drag_started, b.drag_stopped, b.drag_updates = 0, 0, 0, 0, 0

	tb:SetScript("OnClick", function(_, button)
		if button == "LeftButton" then b.left_clicks = b.left_clicks + 1
		elseif button == "RightButton" then b.right_clicks = b.right_clicks + 1 end
		window.btnStatus:SetText(string.format("L=%d R=%d drag=%d/%d", b.left_clicks, b.right_clicks, b.drag_started, b.drag_stopped))
	end)
	tb:SetScript("OnDragStart", function(self)
		b.drag_started = b.drag_started + 1
		self.dragging = true
		local angle, cx, cy = ringAngle()
		b.start_cursor_x, b.start_cursor_y, b.start_ring_angle_deg = num(cx), num(cy), num(angle)
		pcall(self.StartMoving, self)
	end)
	tb:SetScript("OnDragStop", function(self)
		self.dragging = false
		pcall(self.StopMovingOrSizing, self)
		b.drag_stopped = b.drag_stopped + 1
		local angle, cx, cy = ringAngle()
		b.stop_cursor_x, b.stop_cursor_y, b.stop_ring_angle_deg = num(cx), num(cy), num(angle)
		local ok, point, _, rel, x, y = pcall(self.GetPoint, self, 1)
		b.last_point = ok and { point = point, rel = rel, x = num(x), y = num(y) } or { error = tostring(point) }
		window.btnStatus:SetText(string.format("L=%d R=%d drag=%d/%d ring=%s", b.left_clicks, b.right_clicks,
			b.drag_started, b.drag_stopped, angle and string.format("%.0f deg", angle) or "n/a"))
	end)
	tb:SetScript("OnUpdate", function(self)
		if not self.dragging then return end
		b.drag_updates = b.drag_updates + 1
		local angle = ringAngle()
		if angle then b.last_ring_angle_deg = num(angle) end
	end)

	window.btnStatus = window:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	window.btnStatus:SetPoint("LEFT", tb, "RIGHT", 8, 0)
	window.btnStatus:SetText("button: not yet")
	window.testButton = tb
end

local function buildWindow()
	window = CreateFrame("Frame", "ForeverProbeM814Window", UIParent)
	window:SetSize(440, 410)
	window:SetPoint("TOP", UIParent, "TOP", 0, -100)
	window:SetFrameStrata("HIGH")
	local bg = window:CreateTexture(nil, "BACKGROUND")
	bg:SetAllPoints()
	bg:SetColorTexture(0, 0, 0, 0.85)

	local title = window:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	title:SetPoint("TOP", window, "TOP", 0, -8)
	title:SetText("M8.14 probe v0.2 - right-drag the window")

	window.facing = window:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	window.facing:SetPoint("TOP", title, "BOTTOM", 0, -4)

	-- Row 1: each candidate texture at rest (rotation 0) beside a copy rotated by the raw facing value.
	window.tex, window.restTex = {}, {}
	for i, t in ipairs(TEXTURES) do
		local x0 = 16 + (i - 1) * 104
		local rest = window:CreateTexture(nil, "ARTWORK")
		rest:SetSize(32, 32)
		rest:SetPoint("TOPLEFT", window, "TOPLEFT", x0, -52)
		local okSet, setRet = pcall(rest.SetTexture, rest, t.path)
		local okGet, got = pcall(function() return rest:GetTexture() end)
		local tex = window:CreateTexture(nil, "ARTWORK")
		tex:SetSize(32, 32)
		tex:SetPoint("TOPLEFT", window, "TOPLEFT", x0 + 40, -52)
		pcall(tex.SetTexture, tex, t.path)
		local label = window:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		label:SetPoint("TOPLEFT", window, "TOPLEFT", x0, -86)
		label:SetText(t.key .. ": rest | raw facing")
		results.textures[t.key] = {
			path = t.path,
			set_ok = okSet, set_return = (type(setRet) == "boolean" or type(setRet) == "number") and setRet or nil,
			get_texture = okGet and (type(got) == "string" or type(got) == "number") and got or nil,
			rotation_api = type(tex.SetRotation) == "function",
		}
		window.tex[i], window.restTex[i] = tex, rest
	end

	-- Row 2: three bearing arrows using the chosen texture: derived, mirrored, baseline (assumed).
	window.arrows = {}
	local arrowLabels = { "D derived", "M mirrored", "B baseline*" }
	for i, name in ipairs(arrowLabels) do
		local a = window:CreateTexture(nil, "ARTWORK")
		a:SetSize(40, 40)
		a:SetPoint("TOPLEFT", window, "TOPLEFT", 16 + (i - 1) * 104, -112)
		pcall(a.SetTexture, a, arrowPath())
		local l = window:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		l:SetPoint("TOPLEFT", window, "TOPLEFT", 16 + (i - 1) * 104, -156)
		l:SetText(name)
		window.arrows[i] = a
	end
	window.arrowNote = window:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	window.arrowNote:SetPoint("TOPLEFT", window, "TOPLEFT", 340, -120)
	window.arrowNote:SetText("texture " .. arrowKey)

	window.info = window:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	window.info:SetPoint("TOPLEFT", window, "TOPLEFT", 16, -178)
	window.info:SetWidth(410)
	if window.info.SetJustifyH then window.info:SetJustifyH("LEFT") end

	local glyphs = window:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	glyphs:SetPoint("BOTTOM", window, "BOTTOM", 0, 74)
	glyphs:SetText(GLYPHS)

	window.drag = window:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	window.drag:SetPoint("BOTTOM", window, "BOTTOM", 0, 50)
	window.drag:SetText("window drag: not yet")

	-- Right-click drag on the window (the interaction the Guide Arrow will use).
	local api = {}
	for _, m in ipairs({ "SetMovable", "EnableMouse", "RegisterForDrag", "StartMoving", "StopMovingOrSizing", "GetPoint", "SetClampedToScreen" }) do
		api[m] = type(window[m]) == "function"
	end
	results.drag.api = api
	pcall(window.SetMovable, window, true)
	pcall(window.EnableMouse, window, true)
	pcall(window.SetClampedToScreen, window, true)
	results.drag.register_ok = (pcall(window.RegisterForDrag, window, "RightButton"))
	window:SetScript("OnDragStart", function(self)
		results.drag.started = (results.drag.started or 0) + 1
		pcall(self.StartMoving, self)
	end)
	window:SetScript("OnDragStop", function(self)
		pcall(self.StopMovingOrSizing, self)
		local ok, point, _, rel, x, y = pcall(self.GetPoint, self, 1)
		results.drag.stopped = (results.drag.stopped or 0) + 1
		results.drag.last_point = ok and { point = point, rel = rel, x = num(x), y = num(y) } or { error = tostring(point) }
		window.drag:SetText(string.format("window drag: %s %.0f, %.0f", tostring(point), x or 0, y or 0))
	end)
	window:SetScript("OnMouseUp", function(_, button)
		results.drag.clicks = results.drag.clicks or {}
		results.drag.clicks[button or "?"] = (results.drag.clicks[button or "?"] or 0) + 1
	end)

	buildTestButton()
	readGeometry()

	-- Facing readout and rotation, 10x per second; bearing text/arrows about 5x per second.
	local acc, accSlow = 0, 0
	window:SetScript("OnUpdate", function(_, elapsed)
		elapsed = elapsed or 0
		clock = clock + elapsed
		acc = acc + elapsed
		accSlow = accSlow + elapsed
		if acc < 0.1 then return end
		acc = 0
		local st, v = readFacing()
		local f = results.facing
		if st == "ok" then
			window.facing:SetText(string.format("facing %.2f rad (%.0f deg)", v, deg(v)))
			f.min, f.max = math.min(f.min or v, v), math.max(f.max or v, v)
			f.samples = (f.samples or 0) + 1
			if f.last_ok_clock then f.max_gap = math.max(f.max_gap or 0, clock - f.last_ok_clock) end
			f.last_ok_clock = clock
			f.last = num(v)
			for i, tex in ipairs(window.tex) do
				results.textures[TEXTURES[i].key].rotation_ok = setRot(tex, v)
			end
		else
			window.facing:SetText("facing: " .. st)
			f.non_ok = (f.non_ok or 0) + 1
			f["non_ok_" .. st] = (f["non_ok_" .. st] or 0) + 1
		end
		if accSlow >= 0.2 then
			accSlow = 0
			local live = liveBearing()
			refreshText(live)
			setRot(window.arrows[1], live.derived and live.derived.rot_derived)
			setRot(window.arrows[2], live.derived and live.derived.rot_mirrored)
			setRot(window.arrows[3], live.baseline and live.baseline.rot_derived)
			results.bearing_last = {
				facing = num(live.facing), reason = live.reason,
				derived = live.derived and { rel_cw = num(live.derived.rel_cw), compass_cw = num(live.derived.compass_cw), dist = num(live.derived.dist) } or nil,
				baseline = live.baseline and { rel_cw = num(live.baseline.rel_cw), compass_cw = num(live.baseline.compass_cw), dist = num(live.baseline.dist) } or nil,
			}
			logBearing(live)
		end
	end)
end

-- ---------------------------------------------------------------- commands

local function printDerived()
	local d = recompute()
	say(d.axes_world.text)
	say((d.axes_unit.text:gsub("^axes:", "UnitPosition axes:")))
	say(d.facing.text)
end

local function doMark(name)
	if not MARK_KEYS[name] then return say("usage: /fprobe814 mark start|north|east") end
	local p = readPlayer()
	if not p.world then return say("mark " .. name .. ": world position unavailable here") end
	local _, facing = readFacing()
	results.marks[name] = {
		map = p.map, mapx = p.mapx, mapy = p.mapy,
		world = { continent = p.world.continent, x = p.world.x, y = p.world.y },
		unit = p.unit, facing = num(facing),
	}
	say(string.format("marked %s: world (%.1f, %.1f)%s", name, p.world.x, p.world.y,
		p.unit and string.format(" unit (%.1f, %.1f)", p.unit.r1, p.unit.r2) or ""))
	printDerived()
end

local function doFace(key)
	key = (key or ""):upper()
	if not FACE_KEYS[key] then return say("usage: /fprobe814 face N|E|S|W (stand facing that compass direction)") end
	local st, v = readFacing()
	if st ~= "ok" then return say("face " .. key .. ": GetPlayerFacing " .. st) end
	results.faces[key] = v
	say(string.format("faced %s: GetPlayerFacing = %.3f rad", key, v))
	printDerived()
end

local function report()
	local st = readFacing()
	local f = results.facing
	say(string.format("GetPlayerFacing: %s | range %.2f..%.2f rad, %d samples, max gap %.2fs, non-ok %d", st,
		f.min or -1, f.max or -1, f.samples or 0, f.max_gap or 0, f.non_ok or 0))
	for _, t in ipairs(TEXTURES) do
		local r = results.textures[t.key]
		if r then
			say(string.format("texture %s: set=%s getTexture=%s rotationAPI=%s rotated=%s", t.key, tostring(r.set_ok),
				tostring(r.get_texture), tostring(r.rotation_api), tostring(r.rotation_ok)))
		end
	end
	local d = results.drag
	say(string.format("window drag: register=%s started=%s stopped=%s last=%s", tostring(d.register_ok), tostring(d.started),
		tostring(d.stopped), d.last_point and string.format("%s %.0f,%.0f", tostring(d.last_point.point), d.last_point.x or 0, d.last_point.y or 0) or "none"))
	local b = results.button
	say(string.format("button: register clicks=%s drag=%s | left=%s right=%s | drag started=%s stopped=%s updates=%s | ring start=%s stop=%s",
		tostring(b.register_clicks_ok), tostring(b.register_drag_ok), tostring(b.left_clicks), tostring(b.right_clicks),
		tostring(b.drag_started), tostring(b.drag_stopped), tostring(b.drag_updates), tostring(b.start_ring_angle_deg), tostring(b.stop_ring_angle_deg)))
	local g = readGeometry()
	say(string.format("geometry: minimap=%s center=(%s,%s) size=%sx%s scale=%s | uiparent scale=%s eff=%s | shape=%s",
		tostring(g.minimap_exists), f1(g.minimap_center_x), f1(g.minimap_center_y), f1(g.minimap_width), f1(g.minimap_height),
		f2(g.minimap_effective_scale), f2(g.uiparent_scale), f2(g.uiparent_effective_scale), tostring(g.minimap_shape or g.get_minimap_shape)))
	printDerived()
	say("Screenshot the window (which of A-D show an arrow and which way each points at rest, which glyphs render, "
		.. "the D/M/B arrows and the numbers), then /reload to save.")
end

local function handleSlash(msg)
	msg = (msg or ""):lower()
	local cmd, arg, arg2 = msg:match("^%s*(%S*)%s*(%S*)%s*(%S*)")
	if cmd == "report" then return report()
	elseif cmd == "calc" then return printDerived()
	elseif cmd == "geo" then
		readGeometry()
		return say("geometry recorded (see /fprobe814 report)")
	elseif cmd == "mark" then return doMark(arg)
	elseif cmd == "face" then return doFace(arg)
	elseif cmd == "tex" then
		local key = arg:upper()
		for _, t in ipairs(TEXTURES) do
			if t.key == key then
				arrowKey = key
				if window then
					for _, a in ipairs(window.arrows) do pcall(a.SetTexture, a, t.path) end
					window.arrowNote:SetText("texture " .. key)
				end
				return say("bearing arrows now use texture " .. key)
			end
		end
		return say("usage: /fprobe814 tex A|B|C|D")
	elseif cmd == "target" then
		if arg == "here" then
			local p = readPlayer()
			if not (p.map and p.mapx and p.mapy) then return say("target here: position unavailable") end
			setTarget({ label = "here (set by player)", map = p.map, x = p.mapx, y = p.mapy })
			return say(string.format("target set to current position; walk away and the arrow should point back (%s)", target.world and "world ok" or "world UNAVAILABLE"))
		end
		setTarget(TARGET_JORN)
		return say("target set to " .. TARGET_JORN.label .. (target.world and "" or " (world position UNAVAILABLE)"))
	elseif cmd == "clear" then
		results.marks, results.faces, results.derived = {}, {}, {}
		results.bearing_log, results.last_bearing_log = {}, nil
		recompute()
		return say("marks, faces and bearing log cleared")
	end
	if not window then buildWindow() elseif window:IsShown() then window:Hide() else window:Show() end
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(_, event, name)
	if name ~= addonName then return end
	ForeverProbeM814DB = type(ForeverProbeM814DB) == "table" and ForeverProbeM814DB or {}
	ForeverProbeM814DB.sessions = ForeverProbeM814DB.sessions or {}
	results.facing = {}
	local mm = type(Minimap) == "table" and Minimap or nil
	session = { probe_version = VERSION, results = results, apis = {
		GetPlayerFacing = exists("GetPlayerFacing"), GetCursorPosition = exists("GetCursorPosition"),
		UnitPosition = exists("UnitPosition"), GetMinimapShape = exists("GetMinimapShape"),
		MinimapGetCenter = (mm and type(mm.GetCenter) == "function") and "function" or "absent",
		C_Map_GetWorldPosFromMapPos = (type(C_Map) == "table" and type(C_Map.GetWorldPosFromMapPos) == "function") and "function" or "absent",
		C_Map_GetPlayerMapPosition = (type(C_Map) == "table" and type(C_Map.GetPlayerMapPosition) == "function") and "function" or "absent",
		CreateVector2D = exists("CreateVector2D"), math_atan2 = type(math.atan2) == "function" and "function" or "absent",
	} }
	table.insert(ForeverProbeM814DB.sessions, session)
	recompute()
	setTarget(TARGET_JORN)
	say(VERSION .. " loaded. /fprobe814 opens the test window; see M8_14_PROBE_GUIDE.md.")
end)

SLASH_FOREVERPROBEM8141 = "/fprobe814"
SlashCmdList["FOREVERPROBEM814"] = handleSlash

-- Test-only seam (no in-game code path reads it).
ns._selftest = {
	results = results, getWindow = function() return window end, report = report, handle = handleSlash,
	deriveAxes = deriveAxes, deriveFacing = deriveFacing, bearing = bearing, normPi = normPi,
	liveBearing = liveBearing, getTarget = function() return target end,
}
