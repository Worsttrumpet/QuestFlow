-- Started as a copy of m8-13-progression/ForeverQuestGuide/MinimapButton.lua (M8.13, real-client validated for the button
-- appearing and opening the window). It has since DIVERGED on purpose: the original could not be moved. This version adds
-- drag-to-move and a saved position (see "Moving the button" below). The icon, tooltip and click behaviour are unchanged.

-- ForeverCodex.MinimapButton (was ForeverQuestGuide.MinimapButton): a small, self-contained open/close button.
--
-- Deliberately does NOT use any minimap-button library or convention (LibDBIcon-style data-broker icons,
-- Blizzard's newer AddonCompartment feature, draggable-around-the-minimap-ring positioning). None of that
-- has been confirmed to exist or work on Forever -- ATT's own .toc (the one other real, larger addon this
-- project has inspected) wires its minimap button through `AddonCompartmentFunc`, a modern retail-only
-- Blizzard feature with no evidence of existing on this client's interface (16001), so it is not used as a
-- model here. Per M8.0/M8.2's standing findings, no map-pin/POI API has been confirmed either, and a
-- minimap BUTTON needs none of that -- it is just a clickable Button widget, built from the exact same
-- CreateFrame/CreateTexture/CreateFontString primitives every other part of this addon already uses.
--
-- Parenting/positioning: this button is anchored relative to the global `Minimap` frame if one exists.
-- `Minimap` has never been referenced anywhere else in this project and its existence on Forever is NOT
-- independently confirmed here -- only the outcome if it does or doesn't exist is reasoned about:
--   * CreateFrame(type, name, parent) with parent = nil is ALREADY a real-client-proven pattern in this
--     very codebase (Core.lua's own ADDON_LOADED listener: `CreateFrame("Frame")`, no parent at all) --
--     WoW's engine defaults a nil parent to UIParent, so passing `Minimap` when it happens to be nil is
--     no riskier than that already-validated call.
--   * Frame:SetPoint(point, relativeTo, ...) with relativeTo = nil is documented, ordinary UIObject
--     behavior (defaults to the frame's own parent) -- not something specific to Forever or unconfirmed
--     API surface, so anchoring to `Minimap` degrades to anchoring to this button's own parent (UIParent,
--     per the point above) if `Minimap` is absent.
-- Net effect: if `Minimap` doesn't exist on Forever, this button still appears (fixed near the top-right of
-- the screen, not floating off-screen or erroring) -- just not docked to a minimap ring. Which of these two
-- outcomes actually happens has NOT been observed yet; see docs/M8_5_COMPLETION_REPORT.md's real-client
-- test section for what was actually seen, once run.
--
-- (0.2.8: the icon is now a round picture, see build(). The older note that follows is kept for history.)
-- The icon was a plain colored square with a letter on it (the same CreateTexture/CreateFontString pattern
-- as every button already in this addon) rather than a game icon texture path, since no icon path has been
-- confirmed to exist on Forever and this addon has never needed one before. Self-contained on purpose
-- (a single small file, one exported function) so it can be swapped for a more sophisticated icon/dragging
-- implementation later without touching anything else.

local addonName, ns = ...

-- ---------------------------------------------------------------- moving the button
--
-- Why the original could not be moved: it never called SetMovable / RegisterForDrag and had no OnDragStart / OnDragStop, so
-- there was nothing to start a drag; it had no saved position; and Boot re-anchored it to a fixed spot at every login.
--
-- Moving it uses the same mechanism that is already proven on Forever for Codex's own window and arrow (SetMovable +
-- RegisterForDrag("LeftButton") + StartMoving / StopMovingOrSizing, then GetPoint saved to SavedVariables). The position is
-- stored against UIParent, so it does not depend on where the minimap is. It is NOT a ring-orbit position (that needs the
-- minimap's geometry, which has not been verified on Forever). The button stays clamped to the screen, and
-- /codex minimap reset puts it back at the default spot.

local DEFAULT = { point = "TOPLEFT", rel = "TOPRIGHT", x = 6, y = -34 }   -- on the Minimap, 34 px down so the Quest Guide's button is not covered

local MM = { DEFAULT = DEFAULT }
MM.ICON = "Interface\\AddOns\\QuestFlow\\Media\\QuestFlowLogo.tga"
ns.MinimapButton = MM

-- ON THE EDGE. When the minimap's geometry can be read, the button does not float freely: dragging slides it round the minimap's edge (it
-- follows the mouse's angle from the minimap's centre, at the ring's radius) and only the angle is saved. When the geometry cannot be read it
-- falls back to the free drag below.
MM.ANGLE_DEFAULT = 225        -- bottom-left of the ring (degrees, 0 = east, counter-clockwise)
MM.SIZE = 31
MM.EDGE_PAD = 5               -- how far the button's centre sits outside the minimap's own radius

--- The minimap's centre, width and effective scale, or nil when any of them cannot be read.
function MM.Geometry()
	local m = rawget(_G, "Minimap")
	if type(m) ~= "table" then return nil end
	local okC, cx, cy = pcall(m.GetCenter, m)
	local okW, w = pcall(m.GetWidth, m)
	local okS, sc = pcall(m.GetEffectiveScale, m)
	if not (okC and okW and type(cx) == "number" and type(cy) == "number" and type(w) == "number" and w > 0) then return nil end
	if not okS or type(sc) ~= "number" or sc <= 0 then sc = 1 end
	return cx, cy, w, sc
end

--- Pure: the offset from the minimap's centre for an angle (degrees) and a radius.
function MM.Offset(angle, radius)
	local r = math.rad(angle)
	return math.cos(r) * radius, math.sin(r) * radius
end

--- Pure: the angle (degrees, 0..360) of a point relative to a centre.
function MM.AngleOf(dx, dy)
	local a = math.deg(math.atan2(dy, dx))
	if a < 0 then a = a + 360 end
	return a
end

local function placeOnEdge(btn, angle)
	local _, _, w = MM.Geometry()
	local x, y = MM.Offset(angle, w / 2 + MM.EDGE_PAD)
	btn:ClearAllPoints()
	btn:SetPoint("CENTER", Minimap, "CENTER", x, y)
	btn.angle = angle
end

--- Anchors the button at its saved spot, or the default when none (or an unusable one) is saved.
function MM.Apply(btn)
	btn = btn or MM.button
	if not btn then return end
	if MM.Geometry() then
		placeOnEdge(btn, (ns.Prefs and ns.Prefs.MinimapAngle()) or MM.ANGLE_DEFAULT)
		return
	end
	local pos = ns.Prefs and ns.Prefs.MinimapPos()
	btn:ClearAllPoints()
	if pos then
		btn:SetPoint(pos.point, UIParent, pos.rel, pos.x, pos.y)
	else
		btn:SetPoint(DEFAULT.point, Minimap, DEFAULT.rel, DEFAULT.x, DEFAULT.y)
	end
end

--- Saves where a finished drag left the button. Returns true when something usable was stored.
function MM.SavePosition(btn)
	btn = btn or MM.button
	if not btn then return false end
	local ok, point, _, rel, x, y = pcall(btn.GetPoint, btn, 1)
	if not ok or type(point) ~= "string" or type(x) ~= "number" or type(y) ~= "number" then return false end
	ns.Prefs.SetMinimapPos({ point = point, rel = rel or point, x = x, y = y })
	if not ns.Prefs.MinimapPos() then ns.Prefs.ClearMinimapPos() return false end   -- not something we could restore: keep the default
	return true
end

--- Back to the default spot (the saved position is forgotten).
function MM.Reset()
	ns.Prefs.ClearMinimapPos()
	ns.Prefs.ClearMinimapAngle()
	MM.Apply()
end

-- ---------------------------------------------------------------- tooltip
--
-- A two-column tooltip in the style of Questie's minimap button (seen working on the Forever client): the title with the version on the
-- right, then one row per action, the input on the left in blue and what it does on the right in white. To add an action later, add a row
-- to MM.TOOLTIP_ROWS: only inputs that really do something belong here.

MM.TOOLTIP_ROWS = {
	{ "Left Click", "Show / hide the tracker" },
	{ "Right Click", "Options" },
	{ "Drag", "Move this button" },
}

--- The tooltip as data: { title, version, rows = { { input, action }, ... } }. Pure, so it can be tested without a tooltip frame.
function MM.TooltipLines()
	local v = tostring(ForeverCodex and ForeverCodex.VERSION or "")
	return { title = "Quest Flow", version = v ~= "" and ("v" .. v) or "", rows = MM.TOOLTIP_ROWS }
end

function MM.ShowTooltip(owner)
	if ns.Widgets and ns.Widgets.ShowTooltip then ns.Widgets.ShowTooltip(owner, "ANCHOR_LEFT", MM.TooltipLines()) end
end

local function build()
	local btn = CreateFrame("Button", "ForeverCodexMinimapButton", Minimap)
	btn:SetSize(MM.SIZE, MM.SIZE)
	MM.button = btn
	MM.Apply(btn)
	btn:SetFrameStrata("MEDIUM")

	-- the same pieces every minimap button is made of: the game's own dark disc, gold ring and hover glow (they exist on this client: other
	-- addons' buttons use them), with the Quest Flow logo (Media/QuestFlowLogo.tga, made from docs/release/questflow-logo.png by generator/make_logo.py) inside.
	btn.background = btn:CreateTexture(nil, "BACKGROUND")
	btn.background:SetSize(20, 20)
	btn.background:SetPoint("TOPLEFT", 7, -5)
	ns.Safe(btn.background.SetTexture, btn.background, "Interface\\Minimap\\UI-Minimap-Background")
	btn.icon = btn:CreateTexture(nil, "ARTWORK")
	btn.icon:SetSize(21, 21)
	btn.icon:SetPoint("TOPLEFT", 6, -5)
	ns.Safe(btn.icon.SetTexture, btn.icon, MM.ICON)
	btn.border = btn:CreateTexture(nil, "OVERLAY")
	btn.border:SetSize(53, 53)
	btn.border:SetPoint("TOPLEFT")
	ns.Safe(btn.border.SetTexture, btn.border, "Interface\\Minimap\\MiniMap-TrackingBorder")
	ns.Safe(btn.SetHighlightTexture, btn, "Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

	-- drag to move
	btn:SetMovable(true)
	btn:EnableMouse(true)
	btn:RegisterForDrag("LeftButton")
	ns.Safe(btn.SetClampedToScreen, btn, true)
	local dragged = false
	btn:SetScript("OnMouseDown", function() dragged = false end)
	btn:SetScript("OnDragStart", function(self)
		dragged = true
		if GameTooltip then ns.Safe(GameTooltip.Hide, GameTooltip) end
		if MM.Geometry() and type(GetCursorPosition) == "function" then
			-- slide round the edge: follow the mouse's angle from the minimap's centre
			self.edgeDrag = true
			self:SetScript("OnUpdate", function(f)
				local cx, cy, _, sc = MM.Geometry()
				local okP, px, py = pcall(GetCursorPosition)
				if cx and okP and type(px) == "number" and type(py) == "number" then
					placeOnEdge(f, MM.AngleOf(px / sc - cx, py / sc - cy))
				end
			end)
		else
			self.edgeDrag = false
			ns.Safe(self.StartMoving, self)
		end
	end)
	btn:SetScript("OnDragStop", function(self)
		if self.edgeDrag then
			self.edgeDrag = false
			self:SetScript("OnUpdate", nil)               -- always release the drag first, whatever happens next
			if type(self.angle) == "number" then ns.Prefs.SetMinimapAngle(self.angle) end
			return
		end
		ns.Safe(self.StopMovingOrSizing, self)
		ns.Safe(MM.SavePosition, self)
	end)

	ns.Safe(btn.RegisterForClicks, btn, "LeftButtonUp", "RightButtonUp")
	btn:SetScript("OnClick", function(_, mouse)
		if dragged then dragged = false return end     -- releasing a drag over the button is not a click
		if mouse == "RightButton" then
			if ns.UI and ns.UI.ToggleOptions then ns.UI.ToggleOptions() end
		elseif ns.UI and ns.UI.Toggle then
			ns.UI.Toggle()
		end
	end)

	btn:SetScript("OnEnter", function(self)
		MM.ShowTooltip(self)
	end)
	btn:SetScript("OnLeave", function()
		if GameTooltip then
			ns.Safe(GameTooltip.Hide, GameTooltip)
		end
	end)

	return btn
end

MM.Build = build
