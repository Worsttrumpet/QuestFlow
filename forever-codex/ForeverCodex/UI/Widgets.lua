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
W.SOFT_GREEN = { 0.56, 0.80, 0.52 }          -- distance / good news: muted, not neon

--- Card styles. bg = fill, edge = 1 px border, accent = the 2 px edge, label = section label colour, side = which edge carries the accent.
W.STYLE_NOW  = { bg = { 0.17, 0.13, 0.07, 0.92 }, edge = { 0.52, 0.40, 0.14, 0.95 }, accent = { 0.92, 0.70, 0.20, 1 }, label = { 0.92, 0.74, 0.30 }, side = "left" }
W.STYLE_NEAR = { bg = { 0.08, 0.09, 0.14, 0.88 }, edge = { 0.22, 0.23, 0.36, 0.85 }, accent = { 0.46, 0.42, 0.78, 0.95 }, label = { 0.62, 0.60, 0.86 }, side = "left" }
W.STYLE_READY = { bg = { 0.07, 0.12, 0.08, 0.88 }, edge = { 0.20, 0.34, 0.22, 0.85 }, accent = { 0.45, 0.72, 0.42, 0.95 }, label = { 0.56, 0.80, 0.52 }, side = "left" }
W.STYLE_NEW  = { bg = { 0.12, 0.11, 0.08, 0.88 }, edge = { 0.38, 0.33, 0.20, 0.85 }, accent = { 0.74, 0.64, 0.32, 0.95 }, label = { 0.82, 0.72, 0.40 }, side = "top" }

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

local function tex(f, layer, c)
	local t = f:CreateTexture(nil, layer)
	if c then t:SetColorTexture(c[1], c[2], c[3], c[4] or 1) end
	return t
end

--- A card: border, fill and a 2 px accent edge. `style` is one of W.STYLE_* (or any table of the same shape).
function W.Card(parent, w, h, style)
	local f = CreateFrame("Frame", nil, parent)
	f:SetSize(w, h)
	f.style = style
	f.edge = tex(f, "BACKGROUND", style.edge)
	f.edge:SetAllPoints()
	f.bg = tex(f, "BORDER", style.bg)
	f.bg:SetPoint("TOPLEFT", f, "TOPLEFT", 1, -1)
	f.bg:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -1, 1)
	f.accent = tex(f, "ARTWORK", style.accent)
	if style.side == "top" then
		f.accent:SetPoint("TOPLEFT", f, "TOPLEFT", 1, -1)
		f.accent:SetPoint("TOPRIGHT", f, "TOPRIGHT", -1, -1)
		f.accent:SetSize(1, 2)
	else
		f.accent:SetPoint("TOPLEFT", f, "TOPLEFT", 1, -1)
		f.accent:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 1, 1)
		f.accent:SetSize(2, 1)
	end
	-- where content may start: inside the border and past the accent edge
	f.insetX = W.PAD + (style.side == "left" and 2 or 0)
	f.insetY = W.PAD + (style.side == "top" and 2 or 0)
	return f
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
