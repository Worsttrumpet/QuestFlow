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

--- While true, W.Button makes the game's own red button (UIPanelButtonTemplate: the one Questie's and most addons' options use). The options
-- window turns it on while it builds its pages; the compact tracker keeps the small flat buttons. If the template cannot be created, the flat button is used.
W.useBlizzardButtons = false

local function blizzardButton(parent, w, h, label, onClick)
	local ok, b = pcall(CreateFrame, "Button", nil, parent, "UIPanelButtonTemplate")
	if not ok or type(b) ~= "table" then return nil end
	b:SetSize(w, h)
	pcall(b.SetText, b, label or "")
	local okF, fs = pcall(b.GetFontString, b)
	b.text = (okF and type(fs) == "table") and fs or W.Text(b, W.GOLD)
	if not (okF and type(fs) == "table") then b.text:SetPoint("CENTER"); b.text:SetText(label or "") end
	b.enabled = true
	b.templated = true
	b:SetScript("OnClick", function(self)
		if self.enabled and onClick then onClick(self) end
	end)
	return b
end

--- A clickable button: dark background, centred label. `onClick` runs on a left click.
function W.Button(parent, w, h, label, onClick)
	if W.useBlizzardButtons then
		local t = blizzardButton(parent, w, h, label, onClick)
		if t then return t end
	end
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
	if b.templated then pcall(enabled and b.Enable or b.Disable, b) return end
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

-- ---------------------------------------------------------------- the card system (Codex page and future panels)
--
-- A small, restrained vocabulary: a CARD (1 px border, a dark tinted fill, a 2 px accent edge), a section LABEL (small, upper case),
-- a STACK (lays lines out top to bottom by their real height, so cards fit their content), a PROGRESS bar (a flat track and fill) and a
-- divider. Only primitives already proven on Forever are used: Frame, CreateTexture + SetColorTexture, two-point texture anchors,
-- SetSize, CreateFontString. A texture border is drawn as an outer texture with an inset one on top (no template, no backdrop).
-- A future panel (for example DUNGEON READY) is a new STYLE passed to W.Card plus its own lines; nothing here knows about quests.

W.PAD, W.GAP = 10, 8                         -- inner padding of a card, space between cards

W.TEXT = { 0.93, 0.91, 0.84 }                -- body text: warm off-white
W.DIM = { 0.62, 0.60, 0.54 }                 -- supporting detail and metadata
W.WARM_GOLD = { 1, 0.84, 0.36 }              -- the primary action: gold, not yellow
W.ALERT = { 0.92, 0.38, 0.32 }                 -- a full quest log
W.SOFT_GREEN = { 0.56, 0.80, 0.52 }          -- distance / good news: muted, not neon

--- Card styles are SEMANTIC (UI/Theme.lua): a card asks for a role ("primary", "urgent", "training", ...) and the active theme decides how it looks. The W.STYLE_* names below stay as the
-- default theme's role styles for code that still passes a style table; new code passes the role name.
local Theme = ns.Theme
W.STYLE_NOW = Theme.Style("primary", Theme.DEFAULT)
W.STYLE_NEAR = Theme.Style("optional", Theme.DEFAULT)
W.STYLE_DUNGEON = Theme.Style("dungeon", Theme.DEFAULT)
W.STYLE_READY = Theme.Style("ready", Theme.DEFAULT)
W.STYLE_NEW = Theme.Style("discovery", Theme.DEFAULT)

local sizes = setmetatable({}, { __mode = "k" })       -- FontString -> the size W.Font gave it

local function textOf(fs)
	local ok, t = pcall(fs.GetText, fs)
	return ok and type(t) == "string" and t or ""
end
W.TextOf = textOf

local fontPathCache
local function fontPath()
	if fontPathCache == nil then
		fontPathCache = false
		local obj = rawget(_G, "GameFontNormal")
		if type(obj) == "table" and type(obj.GetFont) == "function" then
			local ok, path = pcall(obj.GetFont, obj)
			if ok and type(path) == "string" and path ~= "" then fontPathCache = path end
		end
	end
	return fontPathCache or nil
end
function W._ResetFontCache() fontPathCache = nil end

--- Sets a FontString to `size` using the SAME font file the game's own GameFontNormal uses (no external font). When the client will
-- not say which file that is, the text keeps its normal size: the layout still works, it is just less varied. Returns the size or nil.
function W.Font(fs, size)
	local path = fontPath()
	if path and size then
		local ok = pcall(fs.SetFont, fs, path, size, "")
		if ok then sizes[fs] = size return size end
	end
	return nil
end

--- A line of text with a size, colour and justification. Wraps when `wrap`.
function W.Line(parent, size, color, justify, wrap)
	local fs = W.Text(parent, color)
	W.Font(fs, size)
	ns.Safe(fs.SetJustifyH, fs, justify or "LEFT")
	if wrap then ns.Safe(fs.SetWordWrap, fs, true) end
	return fs
end

--- A small upper-case section label ("NOW", "NEARBY").
function W.Label(parent, text, color)
	local fs = W.Line(parent, 10, color or W.DIM, "LEFT")
	fs:SetText(text or "")
	return fs
end

--- A role marker: a small box in the role's accent colour with its one-character marker (">" primary, "!" urgent, "T" training ...). m:Set(role) re-reads the active theme.
function W.Marker(parent, role, size)
	local f = CreateFrame("Frame", nil, parent)
	size = size or 12
	f:SetSize(size, size)
	f.bg = f:CreateTexture(nil, "ARTWORK")
	f.bg:SetAllPoints()
	f.letter = W.Line(f, size - 2, { 0.05, 0.05, 0.05 }, "CENTER")
	f.letter:SetPoint("CENTER", f, "CENTER", 0, 0)
	function f:Set(r)
		self.role = r
		local st = Theme.Style(r)
		self.bg:SetColorTexture(st.accent[1], st.accent[2], st.accent[3], 1)
		self.letter:SetText(st.marker)
	end
	f:Set(role)
	return f
end

--- A card's section label with its role marker in front: "[T] SPELL TRAINING". Returns the label; card.marker and card.labelFS are set so a theme change repaints them.
function W.CardLabel(card, text, size)
	card.marker = W.Marker(card, card.role or "optional", size or 11)
	card.marker:SetPoint("TOPLEFT", card, "TOPLEFT", card.insetX, -(card.insetY - 1))
	local fs = W.Label(card, text, card.style and card.style.label)
	fs:SetPoint("TOPLEFT", card, "TOPLEFT", card.insetX + (size or 11) + 5, -(card.insetY))
	card.labelFS = fs
	return fs
end

local function tex(f, layer, c)
	local t = f:CreateTexture(nil, layer)
	if c then t:SetColorTexture(c[1], c[2], c[3], c[4] or 1) end
	return t
end

local cards = setmetatable({}, { __mode = "k" })       -- card -> true (so a theme change can restyle what is on screen)

local function paintCard(f, style)
	f.style = style
	f.edge:SetColorTexture(style.edge[1], style.edge[2], style.edge[3], style.edge[4] or 1)
	f.bg:SetColorTexture(style.bg[1], style.bg[2], style.bg[3], style.bg[4] or 1)
	f.accent:SetColorTexture(style.accent[1], style.accent[2], style.accent[3], style.accent[4] or 1)
	local wgt = style.weight or 2
	f.accent:ClearAllPoints()
	if style.side == "top" then
		f.accent:SetPoint("TOPLEFT", f, "TOPLEFT", 1, -1)
		f.accent:SetPoint("TOPRIGHT", f, "TOPRIGHT", -1, -1)
		f.accent:SetSize(1, wgt)
	else
		f.accent:SetPoint("TOPLEFT", f, "TOPLEFT", 1, -1)
		f.accent:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 1, 1)
		f.accent:SetSize(wgt, 1)
	end
	if f.marker then f.marker:Set(f.role) end
	if f.labelFS then W.SetColor(f.labelFS, style.label) end
end

--- A card: border, fill and an accent edge. `style` is a ROLE NAME ("primary", "urgent", ...: the active theme decides the look and the card follows a theme change) or a style table
-- (fixed). The accent's weight is part of the style (heavier for primary and urgent): the weight, the marker and the label say what the card is even without the colour.
function W.Card(parent, w, h, style)
	local f = CreateFrame("Frame", nil, parent)
	f:SetSize(w, h)
	if type(style) == "string" then f.role, style = style, Theme.Style(style) end
	f.edge = tex(f, "BACKGROUND", style.edge)
	f.edge:SetAllPoints()
	f.bg = tex(f, "BORDER", style.bg)
	f.bg:SetPoint("TOPLEFT", f, "TOPLEFT", 1, -1)
	f.bg:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -1, 1)
	f.accent = tex(f, "ARTWORK", style.accent)
	paintCard(f, style)
	-- where content may start: inside the border and past the accent edge
	f.insetX = W.PAD + (style.side == "left" and 2 or 0)
	f.insetY = W.PAD + (style.side == "top" and 2 or 0)
	if f.role then cards[f] = true end
	return f
end

--- Changes a role card's role (a card whose meaning changes, e.g. the timed card under urgency): style, marker and label follow.
function W.SetCardStyle(card, style)
	if not card then return end
	paintCard(card, style)
end

--- Re-applies the ACTIVE theme to every role card and marker that exists (called when the player picks another theme).
function W.Restyle()
	for f in pairs(cards) do
		if f.role then
			local st = (f.styleOverride and f.styleOverride()) or Theme.Style(f.role)
			paintCard(f, st)
		end
	end
	if W.OnRestyle then W.OnRestyle() end
end

--- Height of a FontString's current text: the client's own measurement when it gives one, else a line-count estimate.
function W.TextHeight(fs, width)
	local text = textOf(fs)
	if text == "" then return 0 end
	local ok, h = pcall(fs.GetStringHeight, fs)
	if ok and type(h) == "number" and h > 0 then return h end
	local size = sizes[fs] or 12
	local perLine = math.max(1, math.floor((width or 200) / (size * 0.55)))
	return math.ceil(#text / perLine) * (size + 3)
end

--- Lays lines out top to bottom inside a card. stack:Add(fs, gap) puts the line at the current y (hiding it when it has no text) and
-- moves down by its height + gap; stack:Bottom() is the card height that fits everything so far.
function W.Stack(card, width, justify)
	local st = { card = card, y = card.insetY, width = width }
	function st:Add(fs, gap, x, w)
		if textOf(fs) == "" then
			fs:Hide()
			return 0
		end
		fs:Show()
		fs:ClearAllPoints()
		fs:SetPoint("TOPLEFT", card, "TOPLEFT", x or card.insetX, -self.y)
		fs:SetWidth(w or width)
		local h = W.TextHeight(fs, w or width)
		self.y = self.y + h + (gap or 0)
		return h
	end
	function st:Skip(px) self.y = self.y + px end
	function st:Bottom() return self.y + W.PAD - (self.lastGap or 0) end
	return st
end

--- The Codex tooltip: a gold title (with an optional grey version on the right), a blank line, then one row per action with the input
-- on the left in blue and what it does on the right in white. t = { title, version, rows = { { input, action }, ... } }. Shared by the minimap
-- button and the arrow so they look the same. AddDoubleLine is what Questie's tooltip uses on this client; if it is ever missing each row falls
-- back to one plain line. Shown only while the mouse is over the owner (the caller hides it on leave).
local TIP_TITLE, TIP_VERSION, TIP_KEY, TIP_ACTION = { 1, 0.82, 0 }, { 0.6, 0.6, 0.6 }, { 0.25, 0.65, 0.95 }, { 1, 1, 1 }
function W.ShowTooltip(owner, anchor, t)
	local tip = rawget(_G, "GameTooltip")
	if not tip then return end
	if not ns.Safe(tip.SetOwner, tip, owner, anchor or "ANCHOR_LEFT") then return end
	local function double(left, right, lc, rc)
		local ok = ns.Safe(tip.AddDoubleLine, tip, left, right, lc[1], lc[2], lc[3], rc[1], rc[2], rc[3])
		if not ok then ns.Safe(tip.AddLine, tip, left .. (right ~= "" and (": " .. right) or ""), lc[1], lc[2], lc[3]) end
	end
	double(t.title, t.version or "", TIP_TITLE, TIP_VERSION)
	ns.Safe(tip.AddLine, tip, " ")
	for _, row in ipairs(t.rows) do double(row[1], row[2], TIP_KEY, TIP_ACTION) end
	ns.Safe(tip.Show, tip)
end

--- A flat progress bar: a dark track with a muted fill and "have / need" beside it. Set(have, need) shows it; Clear() hides it.
-- It never invents numbers: Set needs real counts, and anything else hides the bar.
function W.Progress(parent, width, height)
	local b = CreateFrame("Frame", nil, parent)
	b.barH = height
	b.edge = tex(b, "BACKGROUND", { 0.30, 0.28, 0.20, 0.95 })
	b.edge:SetPoint("TOPLEFT", b, "TOPLEFT", 0, 0)
	b.track = tex(b, "BORDER", { 0.05, 0.05, 0.05, 0.95 })
	b.track:SetPoint("TOPLEFT", b, "TOPLEFT", 1, -1)
	b.fill = tex(b, "ARTWORK", { 0.50, 0.68, 0.34, 0.95 })
	b.fill:SetPoint("TOPLEFT", b, "TOPLEFT", 1, -1)
	b.text = W.Line(b, 12, W.TEXT, "LEFT")
	b.text:SetPoint("LEFT", b, "LEFT", 0, 0)
	b.text:SetWidth(46)
	--- Fits the bar to `w` pixels: the track takes all but 52 (the numbers sit to its right).
	function b:Resize(w)
		self:SetSize(w, self.barH)
		self.trackW = w - 52
		self.edge:SetSize(self.trackW, self.barH)
		self.track:SetSize(self.trackW - 2, self.barH - 2)
		self.text:ClearAllPoints()
		self.text:SetPoint("LEFT", self, "LEFT", self.trackW + 6, 0)
	end
	function b:Set(have, need)
		if type(have) ~= "number" or type(need) ~= "number" or need <= 0 or have < 0 then self:Clear() return false end
		local frac = math.min(1, have / need)
		self.fraction = frac
		local fw = math.floor((self.trackW - 2) * frac + 0.5)
		self.fill:SetSize(math.max(1, fw), self.barH - 2)
		if fw <= 0 then self.fill:Hide() else self.fill:Show() end
		self.text:SetText(string.format("%d / %d", have, need))
		self:Show()
		return true
	end
	function b:Clear()
		self.fraction = nil
		self.text:SetText("")
		self:Hide()
	end
	b:Resize(width)
	b:Hide()
	return b
end

--- A 1 px horizontal divider across a card's content width.
function W.Divider(card, color)
	local d = tex(card, "ARTWORK", color or { 0.40, 0.34, 0.18, 0.55 })
	d:SetSize(1, 1)
	return d
end

--- A compact progress row: a label on the left, "have/need" on the right and a thin bar under both (about 23 px tall).
-- It never invents numbers: without real counts the label is shown alone and the bar stays hidden.
-- row:Set(label, have, need) shows it; row:Place(card, x, y, width) puts it at an offset inside a card; row:Clear() hides it.
W.ROW_H = 23
function W.ProgressRow(parent)
	local r = CreateFrame("Frame", nil, parent)
	r.label = W.Line(r, 12, W.TEXT, "LEFT")
	r.count = W.Line(r, 12, W.DIM, "RIGHT")
	r.track = tex(r, "BORDER", { 0.05, 0.05, 0.05, 0.95 })
	r.fill = tex(r, "ARTWORK", { 0.50, 0.68, 0.34, 0.95 })
	function r:Place(card, x, y, width)
		self:ClearAllPoints()
		self:SetPoint("TOPLEFT", card, "TOPLEFT", x, -y)
		self:SetSize(width, W.ROW_H)
		self.width = width
		self.label:ClearAllPoints()
		self.label:SetPoint("TOPLEFT", self, "TOPLEFT", 0, 0)
		self.label:SetWidth(width - 44)
		self.count:ClearAllPoints()
		self.count:SetPoint("TOPRIGHT", self, "TOPRIGHT", 0, 0)
		self.count:SetWidth(44)
		self.track:ClearAllPoints()
		self.track:SetPoint("TOPLEFT", self, "TOPLEFT", 0, -17)
		self.track:SetSize(width, 5)
		self.fill:ClearAllPoints()
		self.fill:SetPoint("TOPLEFT", self, "TOPLEFT", 0, -17)
		self:Set(self.cur and self.cur[1], self.cur and self.cur[2], self.cur and self.cur[3])
	end
	function r:Set(label, have, need)
		self.cur = { label, have, need }
		self.label:SetText(label or "")
		if type(have) == "number" and type(need) == "number" and need > 0 and have >= 0 then
			local frac = math.min(1, have / need)
			self.fraction = frac
			self.count:SetText(string.format("%d/%d", have, need))
			local fw = math.floor((self.width or 100) * frac + 0.5)
			self.fill:SetSize(math.max(1, fw), 5)
			if fw <= 0 then self.fill:Hide() else self.fill:Show() end
			self.track:Show()
		else
			self.fraction = nil
			self.count:SetText("")
			self.track:Hide()
			self.fill:Hide()
		end
		self:Show()
	end
	function r:Clear()
		self.cur, self.fraction = nil, nil
		self.label:SetText("")
		self.count:SetText("")
		self:Hide()
	end
	r:Clear()
	return r
end

-- ---------------------------------------------------------------- Codex's own small icons (Media/*.tga, drawn by generator/make_art.py)
-- White pictures with a dark outline: the addon tints them (gold "!" to pick a quest up, gold "?" to hand one in, green check).
W.ICONS = {
	bang = "Interface\\AddOns\\QuestFlow\\Media\\IconBang.tga",
	query = "Interface\\AddOns\\QuestFlow\\Media\\IconQuery.tga",
	check = "Interface\\AddOns\\QuestFlow\\Media\\IconCheck.tga",
}
W.ICON_TINT = { bang = { 1, 0.82, 0 }, query = { 1, 0.82, 0 }, check = { 0.45, 0.9, 0.4 } }

--- A small picture on a frame. icon:Place(card, x, y) puts it at an offset (y is the distance below the top); icon:Set(key) swaps or hides it (nil hides).
function W.Icon(parent, size)
	local t = parent:CreateTexture(nil, "ARTWORK")
	t:SetSize(size, size)
	function t:Place(card, x, y)
		self:ClearAllPoints()
		self:SetPoint("TOPLEFT", card, "TOPLEFT", x, -y)
	end
	function t:Set(key)
		self.key = key
		if key and W.ICONS[key] then
			ns.Safe(self.SetTexture, self, W.ICONS[key])
			local c = W.ICON_TINT[key]
			ns.Safe(self.SetVertexColor, self, c[1], c[2], c[3])
			self:Show()
		else
			self:Hide()
		end
	end
	t:Hide()
	return t
end

-- ---------------------------------------------------------------- settings controls (0.7.8): one look for every option
--
-- A SECTION header (a small gold label with a thin rule), a CHECK ROW (a check box, a white label and one dim line saying what it changes) and a DROPDOWN (a
-- button showing the CURRENT choice, opening a short list with the current row marked). Built only from Frame / Button / CreateTexture + SetColorTexture /
-- CreateFontString, like everything else here: no Blizzard dropdown template (it is unverified on Forever). One list is open at a time; choosing a row, opening
-- another dropdown or hiding the page closes it.

W.ROW_H_CHECK = 38                     -- height of a check row (label line + description line)
W.ROW_H_DROP = 46                      -- height of a dropdown row (label + control, description under it)

--- A section header: SMALL GOLD CAPITALS and a thin rule under it, `width` wide. Returns the label; header.rule is the rule texture.
function W.Section(parent, text, x, y, width)
	local fs = W.Line(parent, 11, W.WARM_GOLD, "LEFT")
	fs:SetText(text or "")
	fs:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
	local rule = tex(parent, "ARTWORK", { 0.40, 0.34, 0.18, 0.55 })
	rule:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y - 15)
	rule:SetSize(width, 1)
	fs.rule = rule
	return fs
end

--- A check row at (x, y): b:SetOn(on, label, description). Clicking runs onClick(b); the caller re-reads the setting and calls SetOn again.
function W.CheckRow(parent, x, y, width, onClick)
	local b = CreateFrame("Button", nil, parent)
	b:SetSize(width, W.ROW_H_CHECK - 4)
	b:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
	b.box = b:CreateTexture(nil, "ARTWORK")
	b.box:SetSize(22, 22)
	b.box:SetPoint("TOPLEFT", b, "TOPLEFT", 0, 0)
	ns.Safe(b.box.SetTexture, b.box, "Interface\\Buttons\\UI-CheckBox-Up")
	b.checkTex = b:CreateTexture(nil, "OVERLAY")
	b.checkTex:SetSize(22, 22)
	b.checkTex:SetPoint("TOPLEFT", b, "TOPLEFT", 0, 0)
	ns.Safe(b.checkTex.SetTexture, b.checkTex, "Interface\\Buttons\\UI-CheckBox-Check")
	b.checkTex:Hide()
	ns.Safe(b.SetHighlightTexture, b, "Interface\\Buttons\\UI-CheckBox-Highlight", "ADD")
	b.label = W.Line(b, 12, W.WHITE, "LEFT")
	b.label:SetPoint("TOPLEFT", b, "TOPLEFT", 28, -2)
	b.label:SetWidth(width - 32)
	b.desc = W.Line(b, 11, W.DIM, "LEFT", true)
	b.desc:SetPoint("TOPLEFT", b, "TOPLEFT", 28, -17)
	b.desc:SetWidth(width - 32)
	b.enabled = true
	b:SetScript("OnClick", function(self) if self.enabled and onClick then onClick(self) end end)
	function b:SetOn(on, label, desc)
		self.on = on and true or false
		self.label:SetText(label or "")
		self.desc:SetText(desc or "")
		if self.on then self.checkTex:Show() else self.checkTex:Hide() end
	end
	return b
end

local openDropdown
local function closeDropdown(d)
	if d and d.list then d.list:Hide() end
	if openDropdown == d then openDropdown = nil end
end
W.CloseDropdowns = function() closeDropdown(openDropdown) end

--- A dropdown at (x, y): d:SetOptions({ { key, label, color? }, ... }), d:SetValue(key). Choosing a row runs onSelect(key). The closed button shows the current label.
function W.Dropdown(parent, x, y, width, onSelect)
	local d = CreateFrame("Button", nil, parent)
	d:SetSize(width, 22)
	d:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
	d.edge = tex(d, "BACKGROUND", { 0.45, 0.38, 0.18, 0.95 })
	d.edge:SetAllPoints()
	d.bg = tex(d, "BORDER", { 0.10, 0.10, 0.11, 0.97 })
	d.bg:SetPoint("TOPLEFT", d, "TOPLEFT", 1, -1)
	d.bg:SetPoint("BOTTOMRIGHT", d, "BOTTOMRIGHT", -1, 1)
	d.text = W.Line(d, 12, W.TEXT, "LEFT")
	d.text:SetPoint("LEFT", d, "LEFT", 8, 0)
	d.text:SetWidth(width - 30)
	d.caret = W.Line(d, 10, W.WARM_GOLD, "RIGHT")             -- a plain letter: the arrow glyphs render as boxes on this client
	d.caret:SetPoint("RIGHT", d, "RIGHT", -7, 0)
	d.caret:SetText("v")
	d.options, d.rows, d.enabled = {}, {}, true
	d.list = CreateFrame("Frame", nil, d)
	d.list:SetFrameStrata("FULLSCREEN_DIALOG")
	d.list:SetFrameLevel(200)
	d.list.edge = tex(d.list, "BACKGROUND", { 0.45, 0.38, 0.18, 0.98 })
	d.list.edge:SetAllPoints()
	d.list.bg = tex(d.list, "BORDER", { 0.07, 0.07, 0.08, 0.99 })
	d.list.bg:SetPoint("TOPLEFT", d.list, "TOPLEFT", 1, -1)
	d.list.bg:SetPoint("BOTTOMRIGHT", d.list, "BOTTOMRIGHT", -1, 1)
	d.list:Hide()
	function d:SetOptions(opts)
		self.options = opts or {}
		self.list:SetSize(width, #self.options * 20 + 2)
		self.list:ClearAllPoints()
		self.list:SetPoint("TOPLEFT", self, "BOTTOMLEFT", 0, 1)
		for i, o in ipairs(self.options) do
			local row = self.rows[i]
			if not row then
				row = CreateFrame("Button", nil, self.list)
				row:SetSize(width - 2, 20)
				row.hl = tex(row, "ARTWORK", { 1, 1, 1, 0 })
				row.hl:SetAllPoints()
				row.text = W.Line(row, 12, W.TEXT, "LEFT")
				row.text:SetPoint("LEFT", row, "LEFT", 14, 0)
				row.text:SetWidth(width - 20)
				row.mark = W.Line(row, 12, W.WARM_GOLD, "LEFT")
				row.mark:SetPoint("LEFT", row, "LEFT", 4, 0)
				row.mark:SetText(">")
				row:SetScript("OnEnter", function(r) r.hl:SetColorTexture(1, 1, 1, 0.12) end)
				row:SetScript("OnLeave", function(r) r.hl:SetColorTexture(1, 1, 1, 0) end)
				self.rows[i] = row
			end
			row:ClearAllPoints()
			row:SetPoint("TOPLEFT", self.list, "TOPLEFT", 1, -1 - (i - 1) * 20)
			row.key = o.key
			row.text:SetText(o.label or tostring(o.key))
			W.SetColor(row.text, o.color or W.TEXT)
			row:SetScript("OnClick", function(r)
				closeDropdown(self)
				if self.enabled and onSelect then onSelect(r.key) end
			end)
			row:Show()
		end
		for i = #self.options + 1, #self.rows do self.rows[i]:Hide() end
		if self.value ~= nil then self:SetValue(self.value) end
	end
	function d:SetValue(key)
		self.value = key
		local label
		for i, o in ipairs(self.options) do
			local cur = o.key == key
			if cur then label = o.label or tostring(o.key); W.SetColor(self.text, o.color or W.TEXT) end
			local row = self.rows[i]
			if row then if cur then row.mark:Show() else row.mark:Hide() end end
		end
		self.text:SetText(label or tostring(key or ""))
	end
	d:SetScript("OnClick", function(self)
		if not self.enabled then return end
		if openDropdown == self then closeDropdown(self) return end
		closeDropdown(openDropdown)
		self.list:Show()
		openDropdown = self
	end)
	d:SetScript("OnHide", function(self) closeDropdown(self) end)
	d:SetScript("OnEnter", function(self) self.bg:SetColorTexture(0.16, 0.15, 0.10, 0.97) end)
	d:SetScript("OnLeave", function(self) self.bg:SetColorTexture(0.10, 0.10, 0.11, 0.97) end)
	return d
end
