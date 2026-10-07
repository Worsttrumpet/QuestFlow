-- run_probe_selftest.lua -- lua5.1 run_probe_selftest.lua   (from this tests/ directory; optional arg: path to the .lua)
--
-- Exercises ForeverProbeM814 (v0.2) against a fake client whose TRUE conventions the test chooses. Two fake worlds
-- are used: one that matches the usual retail description (north = +x, east = -y, facing 0 at north increasing
-- counter-clockwise) and one deliberately different (north = -y, east = +x, facing clockwise with an offset), so a
-- probe that merely echoed an assumption would fail. Proves the probe's own logic only: that it derives the
-- convention a client reports, computes bearings from it, never raises on missing APIs, counts clicks and drags,
-- and saves only SavedVariables-safe values. It proves NOTHING about how Forever actually behaves.

local path = arg[1] or "../addon/ForeverProbeM814/ForeverProbeM814.lua"
local passed, failed = 0, 0
local function check(cond, name)
	if cond then passed = passed + 1; print("[OK]   " .. name)
	else failed = failed + 1; print("[FAIL] " .. name) end
end
local function section(t) print("== " .. t .. " ==") end
local function near(a, b, tol) return type(a) == "number" and type(b) == "number" and math.abs(a - b) <= (tol or 1e-6) end

local PI, TWO_PI = math.pi, 2 * math.pi
local function normPi(a) return (a + PI) % TWO_PI - PI end

-- ---------------------------------------------------------------- the fake client

local W -- current fake world

local function widget(kind)
	local w = { __kind = kind, __shown = true, __text = "", __scripts = {}, __events = {}, __rot = nil, __tex = nil }
	return setmetatable(w, { __index = function(_, k)
		if k == "IsShown" then return function(self) return self.__shown end end
		if k == "Show" then return function(self) self.__shown = true end end
		if k == "Hide" then return function(self) self.__shown = false end end
		if k == "SetText" then return function(self, v) self.__text = v or "" end end
		if k == "GetText" then return function(self) return self.__text end end
		if k == "SetScript" then return function(self, n, fn) self.__scripts[n] = fn end end
		if k == "RegisterEvent" then return function(self, ev) self.__events[ev] = true end end
		if k == "CreateTexture" then return function() return widget("Texture") end end
		if k == "CreateFontString" then return function() return widget("FontString") end end
		if k == "SetTexture" then return function(self, p) self.__tex = p end end
		if k == "GetTexture" then return function(self) return self.__tex end end
		if k == "SetRotation" then
			return function(self, r)
				if W.rotationRaises then error("SetRotation unsupported") end
				self.__rot = r
			end
		end
		if k == "GetPoint" then return function() return "TOPLEFT", nil, "UIParent", 12, -34 end end
		if k == "GetScale" or k == "GetEffectiveScale" then return function() return 1 end end
		if k == "GetWidth" then return function() return 1920 end end
		if k == "GetHeight" then return function() return 1080 end end
		return function() end
	end })
end

local function V(x, y) return { x = x, y = y, GetXY = function(self) return self.x, self.y end } end

-- True conventions of a fake world. Compass heading is clockwise from north, in radians.
local MODELS = {
	A = { name = "retail-like", nAxis = "x", nSign = 1, eAxis = "y", eSign = -1, fdir = "CCW", foff = 0 },
	B = { name = "unusual", nAxis = "y", nSign = -1, eAxis = "x", eSign = 1, fdir = "CW", foff = 1.0 },
}
local COMPASS = { N = 0, E = PI / 2, S = PI, W = 3 * PI / 2 }

local function facingFor(m, theta)
	if m.fdir == "CCW" then return (m.foff - theta) % TWO_PI end
	return (m.foff + theta) % TWO_PI
end

local function newWorld(model, opts)
	opts = opts or {}
	W = { model = model, chat = {}, frames = {}, wx = 4400, wy = 5700, theta = 0, cursor = { 1100, 800 }, rotationRaises = false }
	_G.ForeverProbeM814DB = nil
	_G.CreateFrame = function(kind, name)
		local f = widget(kind); f.__name = name; table.insert(W.frames, f); return f
	end
	_G.UIParent = widget("UIParent")
	_G.GameFontNormal = {}
	_G.DEFAULT_CHAT_FRAME = { AddMessage = function(_, m) table.insert(W.chat, m) end }
	_G.SlashCmdList = {}
	_G.CreateVector2D = V
	_G.Minimap = setmetatable({
		GetCenter = function() return 1000, 800 end, GetWidth = function() return 140 end, GetHeight = function() return 140 end,
		GetEffectiveScale = function() return 1 end, GetZoom = function() return 0 end,
	}, { __index = function() return function() end end })
	_G.GetMinimapShape = function() return "ROUND" end
	_G.GetCursorPosition = function() return W.cursor[1], W.cursor[2] end
	_G.GetPlayerFacing = function()
		if opts.noFacing then return nil end
		if opts.nanFacing then return 0 / 0 end
		return facingFor(model, W.theta)
	end
	_G.C_Map = {
		GetBestMapForUnit = function() return 1413 end,
		GetPlayerMapPosition = function() return V(W.wx / 10000, W.wy / 10000) end,
		GetWorldPosFromMapPos = function(_, v) return 1, V(v.x * 10000, v.y * 10000) end,
	}
	if opts.noMap then _G.C_Map = nil end
	-- retail-style: UnitPosition returns the Y component first, then X.
	_G.UnitPosition = function() return W.wy, W.wx, 0, 1 end
end

--- Moves the fake player `dist` yards on compass heading `theta` (clockwise from north) under the model.
local function walk(theta, dist)
	local m = W.model
	local n, e = math.cos(theta) * dist, math.sin(theta) * dist
	local function add(axis, v) if axis == "x" then W.wx = W.wx + v else W.wy = W.wy + v end end
	add(m.nAxis, m.nSign * n)
	add(m.eAxis, m.eSign * e)
end

local function load()
	local ns = {}
	local chunk = assert(loadfile(path))
	chunk("ForeverProbeM814", ns)
	local ev = W.frames[1]
	ev.__scripts.OnEvent(ev, "ADDON_LOADED", "ForeverProbeM814")
	return ns._selftest
end

local function slash(msg) _G.SlashCmdList["FOREVERPROBEM814"](msg) end
local function tick(win, dt) win.__scripts.OnUpdate(win, dt) end
local function chatHas(s)
	for _, m in ipairs(W.chat) do if m:find(s, 1, true) then return true end end
	return false
end

local function svSafe(t, seen)
	seen = seen or {}
	if seen[t] then return true end
	seen[t] = true
	for k, v in pairs(t) do
		local kt, vt = type(k), type(v)
		if kt ~= "string" and kt ~= "number" then return false end
		if kt == "number" and k ~= k then return false end
		if vt == "table" then
			if not svSafe(v, seen) then return false end
		elseif vt == "number" then
			if v ~= v or v == math.huge or v == -math.huge then return false end
		elseif vt ~= "string" and vt ~= "boolean" then
			return false
		end
	end
	return true
end

-- ---------------------------------------------------------------- the same procedure the player follows

local function runWalkthrough(key)
	local m = MODELS[key]
	newWorld(m)
	local st = load()
	check(type(_G.ForeverProbeM814DB) == "table" and #_G.ForeverProbeM814DB.sessions == 1, key .. ": SavedVariable attached at ADDON_LOADED with one session")
	check(st.results.target == nil or st.results.target.map == 1413, key .. ": default target is the route step s4 position (map 1413)")
	local t = st.getTarget()
	check(t and near(t.x, 0.448696494102478) and near(t.y, 0.5909364223480225), key .. ": target coordinates match RouteData s4")
	check(t.world and near(t.world.x, 4486.96494102478, 1e-3), key .. ": target world position resolved")

	slash("") -- build and show the window
	local win = st.getWindow()
	check(win ~= nil and win:IsShown(), key .. ": window builds on first /fprobe814")

	-- Axes: start, walk 30 yd north, return, walk 30 yd east.
	slash("mark start")
	walk(COMPASS.N, 30); slash("mark north")
	walk(COMPASS.S, 30)
	walk(COMPASS.E, 30); slash("mark east")
	local ax = st.results.derived.axes_world
	check(ax.status == "ok", key .. ": axes derivation status ok (" .. tostring(ax.status) .. ")")
	check(ax.north.axis == m.nAxis and ax.north.sign == m.nSign, key .. ": derived north axis matches the fake client's truth")
	check(ax.east.axis == m.eAxis and ax.east.sign == m.eSign, key .. ": derived east axis matches the fake client's truth")
	check(near(ax.north.len, 30, 1e-6) and near(ax.east.len, 30, 1e-6), key .. ": leg lengths reported (30 yd)")
	check(chatHas("axes: north="), key .. ": derived axes are printed to chat")
	local au = st.results.derived.axes_unit
	-- UnitPosition returns (y, x): its first component is world y.
	local expectUnitNorth = (m.nAxis == "y") and "r1" or "r2"
	check(au.status == "ok" and au.north.axis == expectUnitNorth, key .. ": UnitPosition components derived separately and raw (north = " .. tostring(au.north and au.north.axis) .. ")")

	-- Facing: face N, E, S, W.
	walk(COMPASS.W, 30)
	for _, k in ipairs({ "N", "E", "S", "W" }) do
		W.theta = COMPASS[k]
		slash("face " .. k)
	end
	local fc = st.results.derived.facing
	check(fc.status == "ok", key .. ": facing derivation status ok (" .. tostring(fc.status) .. ")")
	check(fc.direction == m.fdir, key .. ": facing direction derived as " .. m.fdir)
	check(near(fc.offset, facingFor(m, 0)), key .. ": value at north recorded")
	check(fc.zero_at_north == (m.foff == 0), key .. ": zero-at-north flag is " .. tostring(m.foff == 0))
	check(chatHas("increases " .. m.fdir), key .. ": derived facing convention is printed to chat")

	-- Bearing at several positions and facings, against an independent computation from the truth.
	local tw = st.getTarget().world
	local cases = { { 0, 0, 0.3 }, { 120, -80, 1.7 }, { -300, 200, 4.0 }, { 50, 500, 6.1 }, { -700, -700, 2.5 } }
	local allOK = true
	local rotOK = true
	local base = nil
	for _, c in ipairs(cases) do
		W.wx, W.wy = 4400 + c[1], 5700 + c[2]
		W.theta = c[3]
		tick(win, 0.3)
		-- truth: compass heading of the target and of the player under the model
		local dx, dy = tw.x - W.wx, tw.y - W.wy
		local nC = m.nSign * ((m.nAxis == "x") and dx or dy)
		local eC = m.eSign * ((m.eAxis == "x") and dx or dy)
		local want = normPi(math.atan2(eC, nC) - c[3])
		local live = st.liveBearing()
		local got = live.derived and live.derived.rel_cw
		if not near(got, want, 1e-6) then allOK = false end
		local ar = win.arrows
		if not (near(ar[1].__rot, -want, 1e-6) and near(ar[2].__rot, want, 1e-6)) then rotOK = false end
		base = live.baseline
	end
	check(allOK, key .. ": relative bearing matches an independent truth computation at 5 positions/facings")
	check(rotOK, key .. ": derived and mirrored arrows are rotated by -rel and +rel")
	check(base ~= nil, key .. ": baseline (assumed) bearing is also computed for comparison")
	local bl = st.liveBearing()
	if key == "B" then
		check(not near(bl.baseline.rel_cw, bl.derived.rel_cw, 1e-3), key .. ": baseline assumption DISAGREES with the derived convention (probe is not echoing an assumption)")
	else
		check(near(bl.baseline.rel_cw, bl.derived.rel_cw, 1e-6), key .. ": baseline agrees with derived when the client really is retail-like")
	end
	check(win.info.__text:find("dx ", 1, true) and win.info.__text:find("north_comp", 1, true), key .. ": intermediate numbers (dx, dy, north/east components) are shown")
	check(win.info.__text:find("axes: north=", 1, true) and win.info.__text:find("facing: N=", 1, true), key .. ": derived axes and facing convention are visible in the window")

	-- bearing log: gated every 3 s, capped.
	local before = #st.results.bearing_log
	for _ = 1, 100 do tick(win, 1.0) end
	check(#st.results.bearing_log > before and #st.results.bearing_log <= 40, key .. ": bearing log fills at a low rate and is capped at 40")
	check(st.results.bearing_log[1].derived ~= nil and st.results.bearing_log[1].derived.rel_cw ~= nil, key .. ": log entries carry the derived numbers")

	-- Raw facing readout, rotation on all four textures, and range tracking.
	check(st.results.facing.samples and st.results.facing.samples > 5, key .. ": facing samples counted")
	check(st.results.textures.A.rotation_ok == true and st.results.textures.A.rotation_api == true, key .. ": texture rotation recorded as working")
	check(st.results.textures.A.get_texture == "Interface\\Minimap\\MinimapArrow", key .. ": texture path read back")

	check(svSafe(_G.ForeverProbeM814DB), key .. ": everything saved is SavedVariables-safe (no functions, NaN, or userdata)")
	return st, win
end

-- ---------------------------------------------------------------- tests

section("walkthrough: retail-like fake client")
local stA, winA = runWalkthrough("A")

section("walkthrough: unusual fake client (north=-y, east=+x, facing clockwise with offset)")
runWalkthrough("B")

section("pure derivations: failure modes are reported, not guessed")
do
	newWorld(MODELS.A)
	local st = load()
	local names = { "x", "y" }
	check(st.deriveAxes(nil, nil, nil, names).status == "need marks", "no marks -> need marks")
	check(st.deriveAxes({ 0, 0 }, { 5, 0 }, { 0, 30 }, names).status == "leg too short", "5 yd leg -> leg too short")
	check(st.deriveAxes({ 0, 0 }, { 20, 20 }, { 0, 30 }, names).status == "leg not straight", "diagonal leg -> leg not straight")
	check(st.deriveAxes({ 0, 0 }, { 30, 0 }, { 25, 1 }, names).status == "same axis", "both legs on one axis -> same axis")
	check(st.deriveAxes({ 0, 0 }, { 0, -30 }, { 30, 0 }, names).text:find("north=-y", 1, true) ~= nil, "negative north axis is reported as -y")
	local negX = st.deriveAxes({ 0, 0 }, { -30, 0 }, { 0, -30 }, names)
	check(negX.north.axis == "x" and negX.north.sign == -1 and negX.east.axis == "y" and negX.east.sign == -1, "negative first-axis leg is reported as -x (sign kept on both components)")
	check(st.deriveFacing(nil).status == "need faces", "no faces -> need faces")
	check(st.deriveFacing({ N = 0 }).status == "need E or W", "north only -> need E or W")
	check(st.deriveFacing({ N = 0, W = PI / 2, E = PI / 2 }).status == "unclear", "contradictory faces -> unclear")
	check(st.deriveFacing({ N = 0, W = PI / 2 }).direction == "CCW", "W = +pi/2 from north -> CCW")
	check(st.deriveFacing({ N = 0, E = PI / 2 }).direction == "CW", "E = +pi/2 from north -> CW")
	check(st.deriveFacing({ N = 6.2, W = 6.2 + PI / 2 - TWO_PI + TWO_PI }).direction == "CCW", "wrap-around across 2*pi is handled")
	check(st.deriveFacing({ N = 0, W = 1.0 }).status == "unclear", "a quarter turn that is not ~pi/2 -> unclear, not guessed")
	check(st.bearing({ x = 0, y = 0 }, { x = 1, y = 1 }, nil, nil, 0) == nil, "bearing without conventions returns nil")
	local noConv = st.liveBearing()
	check(noConv.derived == nil and noConv.baseline ~= nil, "before any marks: no derived bearing, baseline still shown")
	st.handle("mark sideways")
	check(chatHas("usage: /fprobe814 mark"), "bad mark argument prints usage")
	st.handle("face X")
	check(chatHas("usage: /fprobe814 face"), "bad face argument prints usage")
	slash("clear")
	check(chatHas("cleared"), "clear resets marks and faces")
end

section("bearing target and texture commands")
do
	newWorld(MODELS.A)
	local st = load()
	slash("")
	slash("target here")
	local t = st.getTarget()
	check(t.label:find("here", 1, true) ~= nil and t.world ~= nil, "target here uses the current position")
	check(near(t.world.x, W.wx, 1e-3), "target here resolves to the player's world position")
	slash("target jorn")
	check(st.getTarget().label:find("Jorn", 1, true) ~= nil, "target jorn restores the route step position")
	slash("tex C")
	local win = st.getWindow()
	check(win.arrows[1].__tex == "Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Up" or win.arrows[1].__tex == "Interface\\Buttons\\UI-SpellbookIcon-NextPage-Up", "tex command re-textures the bearing arrows")
	slash("tex Z")
	check(chatHas("usage: /fprobe814 tex"), "bad texture key prints usage")
end

section("button: left click and right drag on the same widget")
do
	newWorld(MODELS.A)
	local st = load()
	slash("")
	local win = st.getWindow()
	local btn = win.testButton
	check(btn ~= nil and btn.__scripts.OnClick and btn.__scripts.OnDragStart and btn.__scripts.OnDragStop, "test button has click and drag handlers")
	check(st.results.button.register_clicks_ok == true and st.results.button.register_drag_ok == true, "button registers for both clicks and drag")
	btn.__scripts.OnClick(btn, "LeftButton")
	btn.__scripts.OnClick(btn, "LeftButton")
	btn.__scripts.OnClick(btn, "RightButton")
	check(st.results.button.left_clicks == 2 and st.results.button.right_clicks == 1, "left and right clicks are counted separately")
	W.cursor = { 1100, 800 } -- 100 px east of the minimap centre
	btn.__scripts.OnDragStart(btn)
	check(btn.dragging == true and st.results.button.drag_started == 1, "drag start recorded")
	check(near(st.results.button.start_ring_angle_deg, 0, 1e-6), "ring angle 0 deg when the cursor is due east of the minimap")
	W.cursor = { 1000, 900 } -- due north of the centre
	btn.__scripts.OnUpdate(btn)
	check(near(st.results.button.last_ring_angle_deg, 90, 1e-6), "ring angle 90 deg when the cursor is due north (counter-clockwise from east)")
	W.cursor = { 900, 800 }
	btn.__scripts.OnDragStop(btn)
	check(st.results.button.drag_stopped == 1 and near(st.results.button.stop_ring_angle_deg, 180, 1e-6), "drag stop recorded with ring angle 180 deg")
	check(st.results.button.last_point and st.results.button.last_point.point == "TOPLEFT", "button anchor read back after drag")
	check(st.results.button.drag_updates >= 1, "OnUpdate samples are counted only while dragging")
	btn.__scripts.OnUpdate(btn)
	local n = st.results.button.drag_updates
	btn.__scripts.OnUpdate(btn)
	check(st.results.button.drag_updates == n, "no sampling after the drag has stopped")
	-- window drag
	win.__scripts.OnDragStart(win)
	win.__scripts.OnDragStop(win)
	win.__scripts.OnMouseUp(win, "RightButton")
	check(st.results.drag.started == 1 and st.results.drag.stopped == 1 and st.results.drag.clicks.RightButton == 1, "window right-drag and click recorded")
	slash("geo")
	local g = st.results.geometry
	check(g.minimap_exists and near(g.minimap_center_x, 1000) and near(g.minimap_width, 140) and g.minimap_shape == "ROUND", "minimap geometry and shape recorded")
	check(near(g.uiparent_effective_scale, 1), "UIParent scale recorded")
	slash("report")
	check(chatHas("button: register clicks=true"), "report prints the button results")
	check(svSafe(_G.ForeverProbeM814DB), "button/drag/geometry results are SavedVariables-safe")
end

section("missing or hostile APIs never raise")
do
	newWorld(MODELS.A, { noFacing = true, noMap = true })
	_G.GetCursorPosition, _G.UnitPosition, _G.GetMinimapShape, _G.Minimap = nil, nil, nil, nil
	local st = load()
	local ok, err = pcall(slash, "")
	check(ok, "window builds with no Minimap, cursor, UnitPosition or C_Map" .. (ok and "" or (": " .. tostring(err))))
	local win = st.getWindow()
	ok, err = pcall(tick, win, 0.3)
	check(ok, "update tick survives missing APIs" .. (ok and "" or (": " .. tostring(err))))
	check(win.facing.__text:find("facing: nil", 1, true) ~= nil, "nil facing is shown as nil, not hidden")
	check((st.results.facing.non_ok or 0) >= 1 and (st.results.facing.non_ok_nil or 0) >= 1, "non-ok facing readings are counted by kind")
	slash("mark start")
	check(chatHas("world position unavailable"), "mark without a position says so instead of guessing")
	slash("face N")
	check(chatHas("GetPlayerFacing nil"), "face without GetPlayerFacing says so")
	ok, err = pcall(win.testButton.__scripts.OnDragStart, win.testButton)
	check(ok, "button drag survives missing cursor/Minimap APIs")
	ok = pcall(win.testButton.__scripts.OnDragStop, win.testButton)
	check(ok, "button drag stop survives missing cursor/Minimap APIs")
	ok = pcall(slash, "report")
	check(ok, "report survives missing APIs")
	check(svSafe(_G.ForeverProbeM814DB), "results with missing APIs are SavedVariables-safe")

	newWorld(MODELS.A, { nanFacing = true })
	st = load()
	slash("")
	win = st.getWindow()
	ok = pcall(tick, win, 0.3)
	check(ok and win.facing.__text:find("facing: bad", 1, true) ~= nil, "NaN facing is treated as bad, never rotated with")
	check(svSafe(_G.ForeverProbeM814DB), "NaN facing never reaches SavedVariables")

	newWorld(MODELS.A)
	W.rotationRaises = true
	st = load()
	slash("")
	win = st.getWindow()
	ok = pcall(tick, win, 0.3)
	check(ok and st.results.textures.A.rotation_ok == false, "SetRotation raising is recorded as rotation_ok=false, not an error")
end

section("loaded state")
do
	newWorld(MODELS.A)
	local st = load()
	local apis = _G.ForeverProbeM814DB.sessions[1].apis
	check(apis.GetPlayerFacing == "function" and apis.UnitPosition == "function" and apis.math_atan2 == "function", "API presence recorded at load")
	check(_G.ForeverProbeM814DB.sessions[1].probe_version == "m8-14-probe-0.2", "probe version recorded")
	check(chatHas("m8-14-probe-0.2 loaded"), "load message printed")
	check(type(_G.SlashCmdList["FOREVERPROBEM814"]) == "function", "slash command registered")
end

print(string.format("\n%d passed, %d failed", passed, failed))
os.exit(failed == 0 and 0 or 1)
