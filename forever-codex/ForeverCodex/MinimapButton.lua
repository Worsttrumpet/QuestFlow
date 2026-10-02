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
-- The icon is a plain colored square with a letter on it (the same CreateTexture/CreateFontString pattern
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
ns.MinimapButton = MM

--- Anchors the button at its saved spot, or the default when none (or an unusable one) is saved.
function MM.Apply(btn)
	btn = btn or MM.button
	if not btn then return end
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
	MM.Apply()
end

-- ---------------------------------------------------------------- tooltip
--
-- A two-column tooltip in the style of Questie's minimap button (seen working on the Forever client): the title with the version on the
-- right, then one row per action, the input on the left in blue and what it does on the right in white. To add an action later, add a row
-- to MM.TOOLTIP_ROWS: only inputs that really do something belong here.

MM.TOOLTIP_ROWS = {
	{ "Left Click", "Open / close Codex" },
	{ "Drag", "Move this button" },
}

local TIP_TITLE, TIP_VERSION, TIP_KEY, TIP_ACTION = { 1, 0.82, 0 }, { 0.6, 0.6, 0.6 }, { 0.25, 0.65, 0.95 }, { 1, 1, 1 }

--- The tooltip as data: { title, version, rows = { { input, action }, ... } }. Pure, so it can be tested without a tooltip frame.
function MM.TooltipLines()
	local v = tostring(ForeverCodex and ForeverCodex.VERSION or "")
	return { title = "Forever Codex", version = v ~= "" and ("v" .. v) or "", rows = MM.TOOLTIP_ROWS }
end

function MM.ShowTooltip(owner)
	if not GameTooltip then return end
	if not ns.Safe(GameTooltip.SetOwner, GameTooltip, owner, "ANCHOR_LEFT") then return end
	local t = MM.TooltipLines()
	local function double(left, right, lc, rc)
		-- AddDoubleLine is what Questie's tooltip uses on this client; if it is ever missing, fall back to one plain line
		local ok = ns.Safe(GameTooltip.AddDoubleLine, GameTooltip, left, right, lc[1], lc[2], lc[3], rc[1], rc[2], rc[3])
		if not ok then ns.Safe(GameTooltip.AddLine, GameTooltip, left .. (right ~= "" and (": " .. right) or ""), lc[1], lc[2], lc[3]) end
	end
	double(t.title, t.version, TIP_TITLE, TIP_VERSION)
	ns.Safe(GameTooltip.AddLine, GameTooltip, " ")
	for _, row in ipairs(t.rows) do double(row[1], row[2], TIP_KEY, TIP_ACTION) end
	ns.Safe(GameTooltip.Show, GameTooltip)
end

local function build()
	local btn = CreateFrame("Button", "ForeverCodexMinimapButton", Minimap)
	btn:SetSize(28, 28)
	MM.button = btn
	MM.Apply(btn)
	btn:SetFrameStrata("MEDIUM")

	btn.bg = btn:CreateTexture(nil, "BACKGROUND")
	btn.bg:SetAllPoints()
	btn.bg:SetColorTexture(0.1, 0.1, 0.1, 0.9)

	btn.border = btn:CreateTexture(nil, "BORDER")
	btn.border:SetPoint("TOPLEFT", -1, 1)
	btn.border:SetPoint("BOTTOMRIGHT", 1, -1)
	btn.border:SetColorTexture(1, 0.82, 0, 1)

	btn.label = btn:CreateFontString(nil, "OVERLAY")
	local okFont = ns.Safe(btn.label.SetFontObject, btn.label, GameFontNormal)
	if not okFont then
		ns.Safe(btn.label.SetFont, btn.label, "Fonts\\FRIZQT__.TTF", 14, "")
	end
	btn.label:SetPoint("CENTER")
	btn.label:SetText("C")

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
		ns.Safe(self.StartMoving, self)
	end)
	btn:SetScript("OnDragStop", function(self)
		ns.Safe(self.StopMovingOrSizing, self)     -- always release the drag first, whatever happens next
		ns.Safe(MM.SavePosition, self)
	end)

	btn:SetScript("OnClick", function()
		if dragged then dragged = false return end     -- releasing a drag over the button is not a click
		if ns.UI and ns.UI.Toggle then
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
