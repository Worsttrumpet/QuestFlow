-- ForeverCodex.Arrow: a small directional arrow that points at Codex's current destination. Codex's OWN frame: it does not
-- place, move, read-to-claim or clear any waypoint, so it can never interfere with the game's or another addon's pins.
--
-- WHAT WAS VERIFIED ON FOREVER (M8.14 v0.1 real-client evidence): GetPlayerFacing exists; Texture:SetRotation works and the
-- art "Interface\Minimap\MinimapArrow" loads. WHAT WAS NOT: which number GetPlayerFacing returns when facing north, and
-- whether it grows clockwise or counter-clockwise (M8.14 v0.2 results are still outstanding). So this arrow does NOT assume
-- a convention: it LEARNS it from the player walking. While you move, Codex compares the compass direction of your
-- movement (from map positions, proven M8.10) with GetPlayerFacing and solves  facing = s * compass + offset  (s = +1 or -1).
-- Until that fit is clean (several different headings, tight agreement) the arrow stays hidden and the label says to walk a
-- few steps. The solved convention is remembered (it is a property of the client, not of the character).
-- Still assumed (unverified): the art points up at rotation 0, and positive SetRotation turns it counter-clockwise on screen.
-- If the arrow looks mirrored on the real client, `/codex arrow flip` inverts it.
--
-- No secure or protected frames, no hooks on Blizzard frames; plain CreateFrame/CreateTexture/CreateFontString, as everywhere.

local addonName, ns = ...
local P = ns.Prefs
local E = ns.Engine

local A = {}
ns.Arrow = A

A.TEXTURE = "Interface\\Minimap\\MinimapArrow"
A.MIN_STEP = 5            -- yards of movement that count as a calibration sample
A.MIN_SAMPLES = 6
A.MIN_FIT = 0.92          -- how tightly the samples must agree (0..1, circular mean resultant)
A.PERIOD = 0.1            -- seconds between updates
A.state = { visible = false, reason = "idle" }

local TWO_PI = 2 * math.pi
local function wrap(a)       -- to (-pi, pi]
	a = a % TWO_PI
	if a > math.pi then a = a - TWO_PI end
	return a
end

-- ---------------------------------------------------------------- geometry (pure)

--- World vectors of one full map width east (E) and one full map height south (S) for a map, or nil.
local function basis(ctx, map)
	local a, b, c = ctx.worldOf(map, 0.25, 0.25), ctx.worldOf(map, 0.75, 0.25), ctx.worldOf(map, 0.25, 0.75)
	if not (a and b and c) or a.continent ~= b.continent or a.continent ~= c.continent then return nil end
	return { ex = (b.x - a.x) / 0.5, ey = (b.y - a.y) / 0.5, sx = (c.x - a.x) / 0.5, sy = (c.y - a.y) / 0.5 }
end

--- Compass bearing (radians, 0 = north, clockwise) and yards from point `from` to point `to` (both { map, x, y }).
-- Uses map x = east and map y = south (map conventions) and the world conversion only to learn the map's real proportions.
-- Returns nil when the two points cannot be compared (another continent, no conversion and different maps).
function A.Bearing(ctx, from, to)
	if not (from and to and from.map and to.map) then return nil end
	local wf, wt = ctx.worldOf(from.map, from.x, from.y), ctx.worldOf(to.map, to.x, to.y)
	local east, south, dist
	if wf and wt then
		if wf.continent ~= wt.continent then return nil end
		local dx, dy = wt.x - wf.x, wt.y - wf.y
		local b = basis(ctx, from.map)
		if not b then return nil end
		local det = b.ex * b.sy - b.ey * b.sx
		if det == 0 then return nil end
		local u = (dx * b.sy - dy * b.sx) / det
		local v = (b.ex * dy - b.ey * dx) / det
		east = u * math.sqrt(b.ex * b.ex + b.ey * b.ey)
		south = v * math.sqrt(b.sx * b.sx + b.sy * b.sy)
		dist = math.sqrt(dx * dx + dy * dy)
	elseif from.map == to.map then
		east, south = (to.x - from.x) * 3000, (to.y - from.y) * 3000      -- the Engine's rough fallback
		dist = math.sqrt(east * east + south * south)
	else
		return nil
	end
	if dist < 1e-6 then return 0, 0 end
	return math.atan2(east, -south), dist
end

-- ---------------------------------------------------------------- learning the facing convention (pure)

local function resultant(angles)
	local c, s = 0, 0
	for _, a in ipairs(angles) do c, s = c + math.cos(a), s + math.sin(a) end
	local n = #angles
	return math.sqrt(c * c + s * s) / n, math.atan2(s, c)
end

--- samples: list of { compass, facing } (radians). Returns { s = +1|-1, o = offset, fit, n } or nil when not (yet) determined:
-- needs enough samples, several different headings (else the sign cannot be told), and one sign that fits clearly better.
function A.Solve(samples)
	if #samples < A.MIN_SAMPLES then return nil end
	local headings = {}
	for i, p in ipairs(samples) do headings[i] = p[1] end
	if resultant(headings) > 0.9 then return nil end      -- all the same direction
	local best
	local fits = {}
	for _, sign in ipairs({ 1, -1 }) do
		local diffs = {}
		for i, p in ipairs(samples) do diffs[i] = p[2] - sign * p[1] end
		local r, o = resultant(diffs)
		fits[sign] = r
		if not best or r > best.fit then best = { s = sign, o = o, fit = r, n = #samples } end
	end
	local other = fits[-best.s]
	if best.fit < A.MIN_FIT or best.fit - other < 0.1 then return nil end
	return best
end

--- Angle from where you face to the destination, clockwise positive (target to your right), given the learned convention.
function A.Relative(cal, facing, targetBearing)
	local heading = cal.s * (facing - cal.o)
	return wrap(targetBearing - heading)
end

function A.Words(r)
	local a = math.abs(r)
	if a < 0.35 then return "straight ahead" end
	local side = r > 0 and "right" or "left"
	if a < 1.2 then return "ahead, to your " .. side end
	if a < 2.0 then return "to your " .. side end
	if a < 2.8 then return "behind you, to your " .. side end
	return "behind you"
end

-- ---------------------------------------------------------------- the client, behind one table (tests replace it)

A.api = {
	facing = function()
		if type(GetPlayerFacing) ~= "function" then return nil end
		local ok, f = pcall(GetPlayerFacing)
		if ok and type(f) == "number" then return f end
		return nil
	end,
	position = function()
		if not (ns.Context and ns.Context.DefaultReader) then return nil end
		local l = ns.Context.DefaultReader.location()
		if l and l.available then return { map = l.map, x = l.x, y = l.y } end
		return nil
	end,
	now = function() return type(GetTime) == "function" and GetTime() or 0 end,
}

local samples, prev = {}, nil
local MAX_SAMPLES = 24

local function calibration() return P.Root().ui.arrowCal end

function A.Calibration() return calibration() end

local function feed(ctx, pos, facing, t)
	if prev and facing and prev.facing then
		local b, d = A.Bearing(ctx, prev.pos, pos)
		local turned = math.abs(wrap(facing - prev.facing))
		if b and d and d >= A.MIN_STEP and d <= 40 and t - prev.t <= 1.6 and turned < 0.3 then
			samples[#samples + 1] = { b, facing }
			while #samples > MAX_SAMPLES do table.remove(samples, 1) end
			prev = { pos = pos, facing = facing, t = t }
			local sol = A.Solve(samples)
			if sol then P.Root().ui.arrowCal = { s = sol.s, o = sol.o, fit = sol.fit, n = sol.n } end
			return
		elseif d and d < A.MIN_STEP then
			return                                  -- standing still: keep the old reference point
		end
	end
	prev = { pos = pos, facing = facing, t = t }
end

-- ---------------------------------------------------------------- the frame

local frame

local function build()
	frame = CreateFrame("Frame", "ForeverCodexArrow", UIParent)
	frame:SetSize(64, 70)
	frame:SetFrameStrata("MEDIUM")
	frame:SetMovable(true)
	frame:EnableMouse(true)
	frame:RegisterForDrag("LeftButton")
	frame:SetScript("OnDragStart", frame.StartMoving)
	frame:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
		local ok, point, _, rel, x, y = pcall(self.GetPoint, self, 1)
		if ok and type(x) == "number" then P.Root().ui.arrowPos = { point = point, rel = rel or point, x = x, y = y } end
	end)
	ns.Safe(frame.SetClampedToScreen, frame, true)
	local pos = P.Root().ui.arrowPos
	frame:ClearAllPoints()
	if type(pos) == "table" and pos.point then frame:SetPoint(pos.point, UIParent, pos.rel or pos.point, pos.x, pos.y) else frame:SetPoint("TOP", UIParent, "TOP", 0, -140) end
	frame.tex = frame:CreateTexture(nil, "ARTWORK")
	frame.tex:SetSize(40, 40)
	frame.tex:SetPoint("TOP", frame, "TOP", 0, 0)
	ns.Safe(frame.tex.SetTexture, frame.tex, A.TEXTURE)
	ns.Safe(frame.tex.SetVertexColor, frame.tex, 1, 0.82, 0)
	ns.Safe(frame.tex.SetAlpha, frame.tex, 0.9)
	frame.label = frame:CreateFontString(nil, "OVERLAY")
	local okF = ns.Safe(frame.label.SetFontObject, frame.label, GameFontNormal)
	if not okF then ns.Safe(frame.label.SetFont, frame.label, "Fonts\\FRIZQT__.TTF", 11, "") end
	frame.label:SetPoint("TOP", frame.tex, "BOTTOM", 0, -2)
	frame:Hide()
end

local function show(rotation, text, showArt)
	if not frame then build() end
	if showArt then
		frame.tex:Show()
		frame.tex:SetRotation(rotation or 0)
	else
		frame.tex:Hide()
	end
	frame.label:SetText(text or "")
	frame:Show()
end

local function hide(reason)
	if frame and A.state.visible then frame:Hide() end
	A.state = { visible = false, reason = reason }
end

local demoUntil = nil

--- /codex arrow test: shows the arrow frame for `seconds`, sweeping round, WITHOUT a destination and without touching navigation.
-- It exists to prove on the real client that the frame appears, the texture loads and rotation works.
function A.Demo(seconds)
	demoUntil = A.api.now() + (seconds or 10)
	if not frame then build() end
end

--- One update. Public so tests can drive it. ctx supplies worldOf; returns the new state.
-- The arrow is intentionally HIDDEN while Codex has no destination (no NOW with a location), but the facing convention is learned
-- from walking whenever the arrow is switched on, so it is already calibrated by the time a destination exists.
function A.Update(ctx)
	if not frame then build() end                       -- created hidden at the first update, so /codex arrow can say it exists
	local t = A.api.now()
	if demoUntil then
		if t < demoUntil then
			local ang = (t * 1.5) % (2 * math.pi)
			show(ang, "Arrow test", true)
			A.state = { visible = true, reason = "demo", art = true, rotation = ang }
			return A.state
		end
		demoUntil = nil
	end
	local target = ns.Navigation and ns.Navigation.Target()
	if not P.NavigationOn() then return hide("nav off") or A.state end
	if not P.ArrowOn() then return hide("arrow off") or A.state end
	local pos = A.api.position()
	local f = A.api.facing()
	if pos and f and ctx and ctx.worldOf then feed(ctx, pos, f, t) end
	if not target then return hide("no destination") or A.state end
	if not (pos and ctx and ctx.worldOf) then return hide("no position") or A.state end
	local b, d = A.Bearing(ctx, pos, target)
	if not b then
		show(0, "In another area", false)
		A.state = { visible = true, reason = "other area", art = false }
		return A.state
	end
	local yards = math.floor(d / 10 + 0.5) * 10
	local cal = calibration()
	if not f then
		show(0, yards .. " yd", false)
		A.state = { visible = true, reason = "no facing", art = false, yards = d }
	elseif not cal then
		show(0, "Walk a few steps to aim the arrow", false)
		A.state = { visible = true, reason = "calibrating", art = false, yards = d, samples = #samples }
	else
		local r = A.Relative(cal, f, b)
		local rot = P.ArrowFlip() and r or -r          -- SetRotation: positive = counter-clockwise (retail convention, unverified here)
		show(rot, yards .. " yd", true)
		A.state = { visible = true, reason = "pointing", art = true, rel = r, rotation = rot, yards = d, words = A.Words(r) }
	end
	return A.state
end

--- What /codex arrow reports: does the frame exist, is it shown, where, can facing be read, is there a destination, is it calibrated.
function A.Info()
	local shown, point
	if frame then
		local ok, v = pcall(frame.IsShown, frame)
		shown = ok and v == true
		local ok2, pt, _, _, x, y = pcall(frame.GetPoint, frame, 1)
		if ok2 and pt then point = string.format("%s %+d,%+d", pt, math.floor((x or 0) + 0.5), math.floor((y or 0) + 0.5)) end
	end
	local f = A.api.facing()
	local cal = calibration()
	return { frame = frame ~= nil, shown = shown, point = point, facingApi = type(GetPlayerFacing) == "function", facing = f,
		destination = ns.Navigation and ns.Navigation.Target() ~= nil, calibrated = cal ~= nil, samples = #samples, reason = A.state.reason,
		navOn = P.NavigationOn(), arrowOn = P.ArrowOn(), demo = demoUntil ~= nil }
end

local since = 0
function A.Tick(elapsed)
	since = since + (elapsed or 0)
	local period = (ns.Navigation and ns.Navigation.Target()) and A.PERIOD or 0.25     -- learning while idle can be slower
	if since < period then return end
	since = 0
	local base = ns.State and ns.State.ctx
	if not base then return end
	local ok, err = pcall(A.Update, base)
	if not ok then ns.RecordError("arrow", err) end
end

function A.Frame() return frame end
function A._Reset() samples, prev, since, demoUntil = {}, nil, 0, nil; A.state = { visible = false, reason = "idle" }; if frame then frame:Hide() end end
