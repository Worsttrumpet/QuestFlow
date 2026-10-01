-- ForeverCodex.Widgets: the few widget helpers the window needs, built ONLY from primitives M8.1-M8.13 already
-- proved on the real Forever client (CreateFrame "Frame"/"Button"/"EditBox", CreateTexture + SetColorTexture,
-- CreateFontString + GameFontNormal, SetScript OnClick/OnEnter/OnLeave). No Blizzard templates (dropdowns etc. are
-- unverified here), and ASCII only: the arrow/check glyphs render as blank boxes on this client (M8.14 v0.1).

local addonName, ns = ...

local W = {}
ns.Widgets = W

W.GOLD = { 1, 0.82, 0 }
W.WHITE = { 1, 1, 1 }
W.GREY = { 0.55, 0.55, 0.55 }
W.GREEN = { 0.45, 0.95, 0.45 }
W.ORANGE = { 1, 0.65, 0.2 }
W.RED = { 1, 0.4, 0.4 }

--- A FontString with the game's own font and a colour.
function W.Text(parent, color)
	local fs = parent:CreateFontString(nil, "OVERLAY")
	local ok = ns.Safe(fs.SetFontObject, fs, GameFontNormal)
	if not ok then
		ns.Safe(fs.SetFont, fs, "Fonts\\FRIZQT__.TTF", 12, "")
	end
	if color then
		ns.Safe(fs.SetTextColor, fs, color[1], color[2], color[3], 1)
	end
	ns.Safe(fs.SetJustifyH, fs, "LEFT")
	ns.Safe(fs.SetWordWrap, fs, false)
	return fs
end

function W.Place(fs, parent, x, y, width)
	fs:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
	if width then fs:SetWidth(width) end
end

function W.SetColor(fs, color)
	ns.Safe(fs.SetTextColor, fs, color[1], color[2], color[3], 1)
end

--- A clickable button: dark background, centred label. `onClick` runs on a left click.
function W.Button(parent, w, h, label, onClick)
	local b = CreateFrame("Button", nil, parent)
	b:SetSize(w, h)
	b.bg = b:CreateTexture(nil, "BACKGROUND")
	b.bg:SetAllPoints()
	b.bg:SetColorTexture(0.22, 0.22, 0.22, 0.95)
	b.text = W.Text(b, W.GOLD)
	b.text:SetPoint("CENTER")
	ns.Safe(b.text.SetJustifyH, b.text, "CENTER")
	b.text:SetText(label or "")
	b.enabled = true
	b:SetScript("OnClick", function(self)
		if self.enabled and onClick then onClick(self) end
	end)
	b:SetScript("OnEnter", function(self)
		if self.enabled then self.bg:SetColorTexture(0.35, 0.35, 0.2, 0.95) end
	end)
	b:SetScript("OnLeave", function(self)
		self.bg:SetColorTexture(0.22, 0.22, 0.22, 0.95)
	end)
	return b
end

--- Enables or greys out a button. A disabled button ignores clicks.
function W.SetEnabled(b, enabled)
	b.enabled = enabled and true or false
	W.SetColor(b.text, enabled and W.GOLD or W.GREY)
end

--- A full-width, left-aligned, clickable text row (used for the Coming up / While you're here lists).
function W.Row(parent, w, h, onClick)
	local b = CreateFrame("Button", nil, parent)
	b:SetSize(w, h)
	b.bg = b:CreateTexture(nil, "BACKGROUND")
	b.bg:SetAllPoints()
	b.bg:SetColorTexture(0, 0, 0, 0)
	b.text = W.Text(b, W.WHITE)
	b.text:SetPoint("LEFT", b, "LEFT", 4, 0)
	b.text:SetWidth(w - 8)
	b:SetScript("OnClick", function(self)
		if self.action and onClick then onClick(self.action) end
	end)
	b:SetScript("OnEnter", function(self) self.bg:SetColorTexture(1, 1, 1, 0.12) end)
	b:SetScript("OnLeave", function(self) self.bg:SetColorTexture(0, 0, 0, 0) end)
	return b
end
