-- ForeverCodex.Pins: the reusable layer that shows WHERE the things in the plan are, on the maps. An OUTPUT of the plan
-- (like Navigation, Arrow and Markers): the Planner knows nothing about it.
--
--   Pins.Desired(plan)   pure: what Codex would show: NOW's and ALSO DO's quest giver / objective area / turn-in / flight
--                        master, each with a trust level. Nothing is shown "because it exists": only the plan's own targets.
--   Pins.OnPlan(plan)    after every recompute: rebuilds Codex's pins
--   Pins.Tick(dt)        about twice a second while the world map is open: re-places pins when the shown map changes
--
-- TRUST. A pin is "observed" only for a location Codex's own Forever observations support (verified, exact, not assumed).
-- Everything else (ATT-derived coordinates, an area, a turn-in assumed at the giver, a player-position fallback) is
-- "approximate": drawn dim with a "?" and described as approximate in its tooltip. Never as a confirmed spot.
--
-- OWNERSHIP. Codex creates its own small frames and only ever hides / reuses frames from its own pool. It never walks the map's
-- children, never touches the game's user waypoint (Navigation owns that, separately), another addon's pins or the player's.
--
-- WHAT FOREVER ALLOWS (verified vs not):
--   world map  : NOT verified. The only proven world-map pin is the single user waypoint (M8.6-B / M8.10). Codex's own pins parent
--                to WorldMapFrame's canvas, which needs WorldMapFrame:GetCanvas() and :GetMapID(): neither has been probed on Forever.
--                They are feature-checked; if absent, no world-map pins and no error. `/codex pins` reports which case you are in.
--   minimap    : NOT supported. Placing a pin on the minimap needs the minimap's zoom, radius in yards and rotation setting; none of
--                that is verified on Forever and guessing would put pins in the wrong place. Omitted, and reported as such.

local addonName, ns = ...
local P = ns.Prefs

local Pins = {}
ns.Pins = Pins

Pins.MAX = 8
Pins.PERIOD = 0.5
Pins.SIZE = 14

local desired, pool, shownMap = {}, {}, nil
local since = 0

-- ---------------------------------------------------------------- what to show (pure)

local KIND = { GIVER = "giver", OBJECTIVE = "objective", TURN_IN = "turnin" }
local LETTER = { giver = "!", objective = "x", turnin = "?", flight = "^", destination = "o" }
local COLOR = { giver = { 1, 0.82, 0 }, objective = { 0.9, 0.35, 0.35 }, turnin = { 0.45, 0.95, 0.45 }, flight = { 0.35, 0.9, 0.35 }, destination = { 1, 1, 1 } }
Pins.LETTER, Pins.COLOR = LETTER, COLOR

local function trustOf(t)
	local w = t.where
	if t.prov and t.prov.verified == true and not t.assumed and w.status == "known" and w.kind ~= "player_position" and w.kind ~= "area" then return "observed" end
	return "approx"
end

local function labelOf(a, kind)
	local name = (a.name and a.name ~= "") and a.name or "quest"
	if kind == "giver" then return "Accept: " .. name end
	if kind == "turnin" then return "Turn in: " .. name end
	if kind == "objective" then return name .. " (objective area)" end
	if kind == "flight" then return "Flight master" .. (a.name and (": " .. a.name) or "") end
	return name
end

--- plan -> list of { key, kind, map, x, y, trust, label, action, role } (at most Pins.MAX). NOW's pins first.
function Pins.Desired(plan)
	local out = {}
	if not plan then return out end
	for slot, a in ipairs({ plan.now or false, plan.alsoDo or false }) do
		if a then
			for ti, t in ipairs(a.targets or {}) do
				local w = t.where
				if w and w.status ~= "unknown" and w.points then
					local kind = (t.role == "SERVICE" and t.service == "FLIGHT") and "flight" or KIND[t.role] or "destination"
					local trust = trustOf(t)
					for pi, pt in ipairs(w.points) do
						if #out < Pins.MAX and type(pt.map) == "number" and type(pt.x) == "number" and type(pt.y) == "number" then
							out[#out + 1] = { key = a.id .. "#" .. ti .. "." .. pi, kind = kind, map = pt.map, x = pt.x, y = pt.y, trust = trust,
								label = labelOf(a, kind), action = a.id, role = slot == 1 and "now" or "alsoDo" }
						end
					end
				end
			end
		end
	end
	return out
end

-- ---------------------------------------------------------------- the client, behind one table (tests replace it)

Pins.api = {
	worldMapAvailable = function()
		return type(WorldMapFrame) == "table" and type(WorldMapFrame.GetCanvas) == "function" and type(WorldMapFrame.GetMapID) == "function"
	end,
	canvas = function() local ok, c = pcall(WorldMapFrame.GetCanvas, WorldMapFrame) return ok and c or nil end,
	mapId = function() local ok, id = pcall(WorldMapFrame.GetMapID, WorldMapFrame) return ok and type(id) == "number" and id or nil end,
	mapShown = function() local ok, v = pcall(WorldMapFrame.IsShown, WorldMapFrame) return ok and v == true end,
	minimapSupported = function() return false end,     -- see the header: nothing verified, so nothing guessed
}

-- ---------------------------------------------------------------- frames (Codex's own pool only)

local function newPinFrame(canvas)
	local f = CreateFrame("Frame", nil, canvas)
	f:SetSize(Pins.SIZE, Pins.SIZE)
	f:SetFrameStrata("HIGH")
	f.bg = f:CreateTexture(nil, "ARTWORK")
	f.bg:SetAllPoints()
	f.letter = f:CreateFontString(nil, "OVERLAY")
	local ok = ns.Safe(f.letter.SetFontObject, f.letter, GameFontNormal)
	if not ok then ns.Safe(f.letter.SetFont, f.letter, "Fonts\\FRIZQT__.TTF", 10, "") end
	f.letter:SetPoint("CENTER")
	f:EnableMouse(true)
	f:SetScript("OnEnter", function(self)
		if GameTooltip and self.info then
			local ok2 = ns.Safe(GameTooltip.SetOwner, GameTooltip, self, "ANCHOR_RIGHT")
			if ok2 then
				ns.Safe(GameTooltip.AddLine, GameTooltip, self.info.label)
				if self.info.trust ~= "observed" then ns.Safe(GameTooltip.AddLine, GameTooltip, "Approximate location", 0.8, 0.8, 0.8) end
				ns.Safe(GameTooltip.Show, GameTooltip)
			end
		end
	end)
	f:SetScript("OnLeave", function() if GameTooltip then ns.Safe(GameTooltip.Hide, GameTooltip) end end)
	f.codexOwned = true
	return f
end

local function hideAll()
	for _, f in ipairs(pool) do f:Hide(); f.info = nil; f.active = false end
end

local function place()
	hideAll()
	if not P.PinsOn() or not Pins.api.worldMapAvailable() then return end
	local canvas = Pins.api.canvas()
	local map = Pins.api.mapId()
	shownMap = map
	if not canvas or not map then return end
	local w, h = 0, 0
	local okW, cw = pcall(canvas.GetWidth, canvas)
	local okH, ch = pcall(canvas.GetHeight, canvas)
	if okW and okH and type(cw) == "number" and type(ch) == "number" then w, h = cw, ch end
	if w <= 0 or h <= 0 then return end
	local used = 0
	for _, d in ipairs(desired) do
		if d.map == map then
			used = used + 1
			local f = pool[used]
			if not f then f = newPinFrame(canvas); pool[used] = f end
			f.info = d
			f.active = true
			local c = COLOR[d.kind] or COLOR.destination
			local alpha = d.trust == "observed" and 0.95 or 0.5
			f.bg:SetColorTexture(c[1], c[2], c[3], alpha)
			f.letter:SetText(d.trust == "observed" and (LETTER[d.kind] or "") or "?")
			f:ClearAllPoints()
			f:SetPoint("CENTER", canvas, "TOPLEFT", d.x * w, -d.y * h)
			f:Show()
		end
	end
end

function Pins.OnPlan(plan)
	desired = Pins.Desired(plan)
	local ok, err = pcall(place)
	if not ok then ns.RecordError("pins", err) end
end

function Pins.Tick(elapsed)
	since = since + (elapsed or 0)
	if since < Pins.PERIOD then return end
	since = 0
	if #desired == 0 or not Pins.api.worldMapAvailable() or not Pins.api.mapShown() then return end
	if Pins.api.mapId() ~= shownMap then
		local ok, err = pcall(place)
		if not ok then ns.RecordError("pins", err) end
	end
end

--- Frames Codex currently shows (its own only).
function Pins.Shown()
	local out = {}
	for _, f in ipairs(pool) do if f.active and f.info then out[#out + 1] = f.info end end
	return out
end

function Pins.Status()
	return { on = P.PinsOn(), worldMap = Pins.api.worldMapAvailable() and "available (unverified on Forever)" or "unavailable on this client",
		minimap = Pins.api.minimapSupported() and "on" or "not supported (minimap placement has not been proven on Forever)", desired = #desired, pool = #pool }
end

function Pins._Reset() desired, pool, shownMap, since = {}, {}, nil, 0 end
