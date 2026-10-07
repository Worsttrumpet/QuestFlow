-- UI: CODEX ICONS (0.9.7). One small icon set for the reward advisor, drawn in code: every glyph is a 9 x 9 pixel grid painted with plain colour textures (the same SetColorTexture the
-- addon already uses), so there are no image files, no texture paths to get wrong on this client, and nothing new to prove.
--
--   VISUAL LANGUAGE (the same as the rest of Codex, see Theme.lua: a dark box, a thin edge, one small marker inside; colour is never the only signal)
--     - a classification is a SQUARE dark badge with a thin edge, the glyph inside in the category's colour family;
--     - SHAPE carries the meaning, colour only supports it: arrows are about gear (solid heavy arrow = upgrade, small head = slight, up+down = mixed, broken stem = temporary,
--       hollow = later), a bolt is combat use, an hourglass is later use, a coin is vendor, an X is not usable, a ? is unknown;
--     - the RECOMMENDATION is a STAR, the only gold glyph with a bright edge, drawn at the right end of the row (a solid star is the advisor's pick, a hollow one is a
--       tentative pick). It is never one of the classification shapes, so a MIXED item can be recommended and show both.
--   No two glyphs share a bitmap (a test enforces it), so no two meanings can be told apart by colour alone.
--
--   This file only DRAWS what it is told: it knows no advisor rule and reads no item data. Words for the tooltip (the accessible form of each icon) live in Icons.WORD.

local addonName, ns = ...

local Icons = {}
ns.CodexIcons = Icons

Icons.SIZE = 9                       -- glyph grid: 9 x 9 cells
Icons.CELL = 1.5                     -- pixels per cell (the badge is SIZE * CELL + 2 wide)

-- '#' = lit cell. Rows top to bottom.
Icons.GLYPHS = {
	UPGRADE = {                      -- solid arrow up
		"....#....",
		"...###...",
		"..#####..",
		".#######.",
		"...###...",
		"...###...",
		"...###...",
		"...###...",
		"...###...",
	},
	NOT_AN_UPGRADE = {               -- a heavy arrow down: nothing gained over what you wear
		"...###...",
		"...###...",
		"...###...",
		"...###...",
		".#######.",
		"..#####..",
		"...###...",
		"....#....",
		".........",
	},
	SLIGHT_UPGRADE = {               -- a small solid arrow head, no stem
		".........",
		".........",
		"....#....",
		"...###...",
		"..#####..",
		".#######.",
		".........",
		".........",
		".........",
	},
	MIXED = {                        -- one arrow up, one arrow down
		".##......",
		"####.....",
		".##...##.",
		".##...##.",
		".##...##.",
		".##...##.",
		".##...##.",
		".##..####",
		"......##.",
	},
	TEMPORARY_UPGRADE = {            -- an arrow whose stem is broken: it does not last
		"....#....",
		"...###...",
		"..#####..",
		".#######.",
		"...###...",
		".........",
		"...###...",
		".........",
		"...###...",
	},
	FUTURE_UPGRADE = {               -- a hollow arrow: an improvement that is not usable yet
		"....#....",
		"...#.#...",
		"..#...#..",
		".##...##.",
		"...#.#...",
		"...#.#...",
		"...#.#...",
		"...#.#...",
		"...###...",
	},
	COMBAT_UTILITY = {               -- a bolt
		"......##.",
		".....##..",
		"....##...",
		"...#####.",
		".....##..",
		"....##...",
		"...##....",
		"..##.....",
		".##......",
	},
	FUTURE_USE = {                   -- an hourglass
		"#########",
		".#.....#.",
		"..#...#..",
		"...#.#...",
		"....#....",
		"...#.#...",
		"..#####..",
		".#######.",
		"#########",
	},
	VENDOR = {                       -- a coin
		"..#####..",
		".#######.",
		"#########",
		"####.####",
		"####.####",
		"####.####",
		"#########",
		".#######.",
		"..#####..",
	},
	NOT_USABLE = {                   -- a heavy X
		"##.....##",
		"###...###",
		".###.###.",
		"..#####..",
		"...###...",
		"..#####..",
		".###.###.",
		"###...###",
		"##.....##",
	},
	UNKNOWN = {                      -- a question mark
		"..#####..",
		".##...##.",
		".##...##.",
		".....##..",
		"....##...",
		"....##...",
		".........",
		"....##...",
		"....##...",
	},
	RECOMMENDED = {                  -- a solid star: the advisor's pick
		"....#....",
		"....#....",
		"...###...",
		"#########",
		".#######.",
		"..#####..",
		"..##.##..",
		".##...##.",
		".#.....#.",
	},
	TENTATIVE = {                    -- a hollow star: a pick the advisor makes with its evidence incomplete
		"....#....",
		"...#.#...",
		"...#.#...",
		"###...###",
		".#.....#.",
		"..#...#..",
		"..#...#..",
		".#..#..#.",
		"#.......#",
	},
}

--- The advisor's category word (as Advisor.Display puts it in row.tags) -> the glyph for it.
Icons.FOR_TAG = {
	["UPGRADE"] = "UPGRADE", ["NOT AN UPGRADE"] = "NOT_AN_UPGRADE", ["SLIGHT UPGRADE"] = "SLIGHT_UPGRADE", ["MIXED"] = "MIXED", ["TEMPORARY"] = "TEMPORARY_UPGRADE", ["FUTURE UPGRADE"] = "FUTURE_UPGRADE",
	["COMBAT UTILITY"] = "COMBAT_UTILITY", ["FUTURE USE"] = "FUTURE_USE", ["VENDOR"] = "VENDOR", ["NOT USABLE"] = "NOT_USABLE", ["UNKNOWN"] = "UNKNOWN",
}

--- What each glyph means in words (the tooltip legend: an icon is never the only way to learn it).
Icons.WORD = {
	UPGRADE = "Upgrade", NOT_AN_UPGRADE = "Not an upgrade", SLIGHT_UPGRADE = "Slight upgrade", MIXED = "Mixed: gains and losses", TEMPORARY_UPGRADE = "Temporary upgrade", FUTURE_UPGRADE = "Future upgrade",
	COMBAT_UTILITY = "Combat utility", FUTURE_USE = "Future use", VENDOR = "Vendor", NOT_USABLE = "Not usable", UNKNOWN = "Unknown: usability unclear",
	RECOMMENDED = "Codex recommends this choice", TENTATIVE = "Codex's tentative pick (evidence incomplete)",
}

--- Colour families (the advisor's own family word per category). Shape does the work; these only support it.
Icons.COLORS = {
	green = { 0.56, 0.80, 0.52 }, yellow = { 1, 0.84, 0.36 }, red = { 0.92, 0.38, 0.32 }, blue = { 0.50, 0.72, 1.0 },
	purple = { 0.78, 0.60, 0.92 }, gold = { 0.85, 0.72, 0.40 }, grey = { 0.70, 0.68, 0.62 },
}
--- The colour family of each glyph (the advisor's own family per category; used for a badge that is not the row's main one).
Icons.FAMILY_OF = { NOT_USABLE = "red", NOT_AN_UPGRADE = "grey", UPGRADE = "green", TEMPORARY_UPGRADE = "yellow", FUTURE_UPGRADE = "yellow", SLIGHT_UPGRADE = "yellow", MIXED = "yellow",
	COMBAT_UTILITY = "blue", FUTURE_USE = "purple", VENDOR = "gold", UNKNOWN = "grey" }
Icons.STAR = { 1, 0.82, 0.20 }                     -- the recommendation: brighter than any family
local BOX = { 0.09, 0.09, 0.10, 0.92 }             -- Theme "later" box: dark, quiet
local EDGE = { 0.38, 0.33, 0.20, 0.95 }            -- Theme "discovery" edge: the thin gold-brown line Codex boxes have
local STAR_EDGE = { 1, 0.82, 0.20, 1 }

--- The glyph for an advisor tag word (nil for a word with no glyph: the caller draws UNKNOWN, never nothing).
function Icons.GlyphFor(tag) return Icons.FOR_TAG[tag] end

--- Badge outer size in pixels.
function Icons.BadgeSize() return Icons.SIZE * Icons.CELL + 2 end

local function safe(f, ...) local ok = pcall(f, ...); return ok end

--- A new badge: a small frame (mouse off) with a dark box, a thin edge and a pool of pixel textures. Pure drawing.
function Icons.NewBadge(parent)
	local f = CreateFrame("Frame", nil, parent)
	safe(f.EnableMouse, f, false)
	local size = Icons.BadgeSize()
	safe(f.SetWidth, f, size)
	safe(f.SetHeight, f, size)
	local b = { frame = f, px = {}, edge = {} }
	b.box = f:CreateTexture(nil, "BACKGROUND")
	safe(b.box.SetAllPoints, b.box)
	for n = 1, 4 do b.edge[n] = f:CreateTexture(nil, "BORDER") end
	local function e(t, p1, p2, w, h)
		safe(t.ClearAllPoints, t)
		safe(t.SetPoint, t, p1, f, p1, 0, 0)
		safe(t.SetPoint, t, p2, f, p2, 0, 0)
		if w then safe(t.SetWidth, t, w) end
		if h then safe(t.SetHeight, t, h) end
	end
	e(b.edge[1], "TOPLEFT", "TOPRIGHT", nil, 1)
	e(b.edge[2], "BOTTOMLEFT", "BOTTOMRIGHT", nil, 1)
	e(b.edge[3], "TOPLEFT", "BOTTOMLEFT", 1, nil)
	e(b.edge[4], "TOPRIGHT", "BOTTOMRIGHT", 1, nil)
	return b
end

--- Paints glyph `id` in colour `c` onto a badge made by NewBadge. `star` = true uses the bright edge (the recommendation). Returns the number of cells lit.
function Icons.Paint(b, id, c, star)
	local rows = Icons.GLYPHS[id] or Icons.GLYPHS.UNKNOWN
	c = c or Icons.COLORS.grey
	safe(b.box.SetColorTexture, b.box, BOX[1], BOX[2], BOX[3], BOX[4])
	local ec = star and STAR_EDGE or EDGE
	for _, t in ipairs(b.edge) do safe(t.SetColorTexture, t, ec[1], ec[2], ec[3], ec[4]) end
	local cell, lit = Icons.CELL, 0
	for y = 1, Icons.SIZE do
		local row = rows[y] or ""
		for x = 1, Icons.SIZE do
			if row:sub(x, x) == "#" then
				lit = lit + 1
				local t = b.px[lit]
				if not t then
					t = b.frame:CreateTexture(nil, "ARTWORK")
					b.px[lit] = t
				end
				safe(t.ClearAllPoints, t)
				safe(t.SetPoint, t, "TOPLEFT", b.frame, "TOPLEFT", 1 + (x - 1) * cell, -(1 + (y - 1) * cell))
				safe(t.SetWidth, t, cell)
				safe(t.SetHeight, t, cell)
				safe(t.SetColorTexture, t, c[1], c[2], c[3], 1)
				safe(t.Show, t)
			end
		end
	end
	for n = lit + 1, #b.px do safe(b.px[n].Hide, b.px[n]) end
	b.glyph, b.lit = id, lit
	return lit
end

return Icons
