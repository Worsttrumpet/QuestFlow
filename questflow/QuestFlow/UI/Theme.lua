-- ForeverCodex.Theme (0.7.8): the SEMANTIC VISUAL SYSTEM. Features never pick a colour: a card, a label or a marker asks for a ROLE ("urgent", "training", ...) and the ACTIVE THEME says
-- how that role looks. A theme can change every colour without changing what the UI means, and a new kind of information is one new role here, not a new look somewhere else.
--
--   ROLES (what a thing IS, not what colour it is):
--     primary      the one recommended action (NOW)                    optional     work that fits with it (ALSO COMPLETE / ALSO DO)
--     later        what comes after (THEN)                              urgent       time-sensitive (TIMED QUEST): the only loud role
--     ready        finished, waiting to be handed in (READY TO TURN IN) discovery    something new (NEW FOR YOU, NEW QUEST ITEM)
--     training     class spells to learn (SPELL TRAINING)              profession   professions (PROFESSIONS)
--     dungeon      dungeon quests (DUNGEON QUESTS)                      world        what is around you (WORLD)
--     progression  your adventure so far (JOURNEY)
--
--   Colour is never the only signal. Every role also has a MARKER (one ASCII character in a small box, drawn next to the label), a LABEL WORD, a card edge (accent on the left or on top)
--   and an accent WEIGHT in pixels: primary and urgent are heavier. The glyph markers are plain letters because arrow / check glyphs render as boxes on this client.
--
--   THEMES: "codex" (the look Codex has always had) and "contrast" (brighter edges and labels, heavier accents, for readability). A theme is a table of role definitions; one that leaves a role
--   out falls back to the default theme's, so a partial theme can never break the UI. The choice is stored account-wide (Preferences ui.theme).

local addonName, ns = ...

local T = {}
ns.Theme = T

T.ROLES = { "primary", "optional", "later", "urgent", "ready", "discovery", "training", "profession", "dungeon", "world", "progression" }

--- Marker character per role (the same in every theme: the MEANING must not move when the palette does).
T.MARKER = { primary = ">", optional = "+", later = "-", urgent = "!", ready = "?", discovery = "*", training = "T", profession = "P", dungeon = "D", world = "o", progression = "^" }

--- The player-facing name of each role (the legend in Appendices).
T.NAME = { primary = "Now", optional = "Also complete", later = "Then", urgent = "Timed quest", ready = "Ready to turn in", discovery = "New for you", training = "Spell training",
	profession = "Professions", dungeon = "Dungeon quests", world = "World", progression = "Journey" }

--- Accent weight (px) per role: how heavy the card edge is. Primary and urgent are the heaviest; everything else stays light so the window is not loud.
T.WEIGHT = { primary = 3, urgent = 3 }

local function def(bg, edge, accent, label, side)
	return { bg = bg, edge = edge, accent = accent, label = label, side = side or "left" }
end

T.THEMES = {
	codex = {
		name = "Quest Flow",
		desc = "The classic Quest Flow look.",
		roles = {
			primary     = def({ 0.17, 0.13, 0.07, 0.92 }, { 0.52, 0.40, 0.14, 0.95 }, { 0.92, 0.70, 0.20, 1 }, { 0.98, 0.80, 0.34 }),
			optional    = def({ 0.08, 0.09, 0.14, 0.88 }, { 0.22, 0.23, 0.36, 0.85 }, { 0.46, 0.42, 0.78, 0.95 }, { 0.62, 0.60, 0.86 }),
			later       = def({ 0.09, 0.09, 0.10, 0.85 }, { 0.26, 0.26, 0.28, 0.80 }, { 0.50, 0.50, 0.54, 0.90 }, { 0.62, 0.62, 0.66 }),
			urgent      = def({ 0.22, 0.09, 0.05, 0.94 }, { 0.80, 0.32, 0.12, 0.98 }, { 1.00, 0.45, 0.15, 1 }, { 1.00, 0.58, 0.28 }),
			ready       = def({ 0.07, 0.12, 0.08, 0.88 }, { 0.20, 0.34, 0.22, 0.85 }, { 0.45, 0.72, 0.42, 0.95 }, { 0.56, 0.80, 0.52 }),
			discovery   = def({ 0.12, 0.11, 0.08, 0.88 }, { 0.38, 0.33, 0.20, 0.85 }, { 0.74, 0.64, 0.32, 0.95 }, { 0.82, 0.72, 0.40 }, "top"),
			training    = def({ 0.06, 0.12, 0.13, 0.88 }, { 0.16, 0.34, 0.37, 0.85 }, { 0.30, 0.72, 0.78, 0.95 }, { 0.46, 0.82, 0.86 }),
			profession  = def({ 0.13, 0.10, 0.07, 0.88 }, { 0.38, 0.28, 0.16, 0.85 }, { 0.72, 0.50, 0.28, 0.95 }, { 0.82, 0.62, 0.40 }),
			dungeon     = def({ 0.13, 0.07, 0.12, 0.90 }, { 0.40, 0.18, 0.36, 0.90 }, { 0.72, 0.34, 0.64, 0.95 }, { 0.82, 0.50, 0.74 }),
			world       = def({ 0.07, 0.11, 0.14, 0.88 }, { 0.20, 0.32, 0.40, 0.85 }, { 0.42, 0.62, 0.78, 0.95 }, { 0.58, 0.74, 0.88 }),
			progression = def({ 0.12, 0.11, 0.15, 0.88 }, { 0.34, 0.31, 0.44, 0.85 }, { 0.70, 0.64, 0.86, 0.95 }, { 0.80, 0.76, 0.92 }),
		},
	},
	contrast = {
		name = "High contrast",
		desc = "Brighter edges and labels, heavier accents.",
		weight = 1,                                           -- every accent is one pixel heavier
		roles = {
			primary     = def({ 0.10, 0.08, 0.02, 0.97 }, { 1.00, 0.84, 0.30, 1 }, { 1.00, 0.84, 0.30, 1 }, { 1.00, 0.90, 0.50 }),
			optional    = def({ 0.03, 0.04, 0.10, 0.95 }, { 0.55, 0.55, 1.00, 1 }, { 0.62, 0.62, 1.00, 1 }, { 0.78, 0.78, 1.00 }),
			later       = def({ 0.05, 0.05, 0.05, 0.93 }, { 0.70, 0.70, 0.70, 1 }, { 0.80, 0.80, 0.80, 1 }, { 0.85, 0.85, 0.85 }),
			urgent      = def({ 0.20, 0.02, 0.02, 0.98 }, { 1.00, 0.35, 0.20, 1 }, { 1.00, 0.35, 0.20, 1 }, { 1.00, 0.70, 0.45 }),
			ready       = def({ 0.02, 0.10, 0.04, 0.95 }, { 0.40, 1.00, 0.45, 1 }, { 0.40, 1.00, 0.45, 1 }, { 0.65, 1.00, 0.65 }),
			discovery   = def({ 0.10, 0.09, 0.03, 0.95 }, { 1.00, 0.95, 0.45, 1 }, { 1.00, 0.95, 0.45, 1 }, { 1.00, 0.97, 0.65 }, "top"),
			training    = def({ 0.02, 0.10, 0.11, 0.95 }, { 0.30, 0.95, 1.00, 1 }, { 0.30, 0.95, 1.00, 1 }, { 0.65, 1.00, 1.00 }),
			profession  = def({ 0.11, 0.07, 0.03, 0.95 }, { 1.00, 0.65, 0.30, 1 }, { 1.00, 0.65, 0.30, 1 }, { 1.00, 0.80, 0.55 }),
			dungeon     = def({ 0.11, 0.03, 0.10, 0.95 }, { 1.00, 0.45, 0.90, 1 }, { 1.00, 0.45, 0.90, 1 }, { 1.00, 0.70, 0.95 }),
			world       = def({ 0.03, 0.08, 0.12, 0.95 }, { 0.45, 0.80, 1.00, 1 }, { 0.45, 0.80, 1.00, 1 }, { 0.70, 0.90, 1.00 }),
			progression = def({ 0.08, 0.06, 0.12, 0.95 }, { 0.85, 0.75, 1.00, 1 }, { 0.85, 0.75, 1.00, 1 }, { 0.92, 0.88, 1.00 }),
		},
	},
}
T.ORDER = { "codex", "contrast" }
T.DEFAULT = "codex"

--- The active theme's key (the stored choice when it names a real theme, else the default).
function T.Key()
	local k = ns.Prefs and ns.Prefs.ThemeKey and ns.Prefs.ThemeKey()
	if T.THEMES[k] then return k end
	return T.DEFAULT
end

--- Chooses a theme and restyles what is already on screen. Returns true when the key names a theme.
function T.Set(key)
	if not T.THEMES[key] then return false end
	if ns.Prefs and ns.Prefs.SetThemeKey then ns.Prefs.SetThemeKey(key) end
	if ns.Widgets and ns.Widgets.Restyle then ns.Widgets.Restyle() end
	return true
end

--- The look of a role under the ACTIVE theme (or `themeKey`): { bg, edge, accent, label, side, weight, marker, role }. A role the theme leaves out falls back to the default theme's;
-- an unknown role falls back to "optional" (the quiet one), never to an error. Tables are copied: callers cannot change a theme by accident.
function T.Style(role, themeKey)
	local theme = T.THEMES[themeKey or T.Key()] or T.THEMES[T.DEFAULT]
	local base = T.THEMES[T.DEFAULT].roles
	if not (theme.roles[role] or base[role]) then role = "optional" end
	local d = theme.roles[role] or base[role]
	local function copy(c) return { c[1], c[2], c[3], c[4] } end
	return { bg = copy(d.bg), edge = copy(d.edge), accent = copy(d.accent), label = copy(d.label), side = d.side,
		weight = (T.WEIGHT[role] or 2) + (theme.weight or 0), marker = T.MARKER[role] or "", role = role }
end

--- A role's label colour (for text that sits outside a card, e.g. a page's section header).
function T.Color(role) return T.Style(role).label end

--- How urgent a timed quest looks: the card keeps the "urgent" role and gets LOUDER only as the deadline nears. level is QuestTimers' own: OK, WARN, CRITICAL, EXPIRED.
-- Returns the card style (a heavier, brighter edge when CRITICAL, a calm one once EXPIRED) and the time text colour. Nothing else on screen changes with it.
function T.Urgency(level, themeKey)
	local s = T.Style("urgent", themeKey)
	local timeColor = s.label
	if level == "CRITICAL" then
		s.edge = { s.accent[1], s.accent[2], s.accent[3], 1 }
		s.weight = s.weight + 1
		timeColor = { 1.00, 0.42, 0.32 }
	elseif level == "WARN" then
		timeColor = { 1.00, 0.84, 0.36 }
	elseif level == "EXPIRED" then
		s = T.Style("later", themeKey)
		timeColor = { 0.62, 0.60, 0.54 }
	else
		timeColor = { 0.93, 0.91, 0.84 }
	end
	return s, timeColor
end
