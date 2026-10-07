-- ui_roles_tests.lua (0.7.8): the semantic visual system (UI/Theme.lua), the relevance gate (Relevance.lua / PetTraining.lua), the resizable Codex window and startup (UI.Init).

local H = ...
local check, section, boot = H.check, H.section, H.boot

local function newNs(char) local ns = boot({ char = char or { level = 6 }, synthetic = true }) return ns end

section("relevance: Pet Training is only relevant to pet classes; nothing is shown (no N/A card) for the others")
do
	local ns = newNs()
	local R = ns.Relevance
	local function applies(class) return R.Applies("petTraining", { char = { classToken = class } }) end
	check(applies("HUNTER") and applies("WARLOCK"), "Hunter and Warlock are eligible")
	for _, c in ipairs({ "SHAMAN", "WARRIOR", "PRIEST", "MAGE", "ROGUE", "DRUID", "PALADIN" }) do check(not applies(c), c .. " is not eligible") end
	check(not R.Applies("petTraining", { char = {} }) and not R.Applies("petTraining", nil) and not R.Applies("nonsense", { char = { classToken = "HUNTER" } }), "an unknown class, no context or an unknown feature is never relevant (unknown stays unknown)")
	check(R.Applies("spellTraining", { char = { classToken = "SHAMAN" } }) and R.Applies("professions", { char = { classToken = "WARRIOR" } }), "spell training and professions apply to every class")
	local PT = ns.PetTraining
	PT._ClearSources()
	check(PT.Card({ char = { classToken = "HUNTER" } }) == nil, "an eligible Hunter with NO pet source has no card (no placeholder: Quest Flow reads no pet information on Forever yet)")
	PT.RegisterSource(function() return {} end)
	check(PT.Card({ char = { classToken = "HUNTER" } }) == nil, "a source with nothing useful to say still gives no card")
	PT.RegisterSource(function() return { { text = "Test pet row", detail = "from a test source" } } end)
	check(PT.Card({ char = { classToken = "HUNTER" } }) and PT.Card({ char = { classToken = "HUNTER" } }).rows[1].text == "Test pet row", "a Hunter with a source that has something to say gets the card")
	check(PT.Card({ char = { classToken = "WARLOCK" } }) ~= nil, "a Warlock is eligible by the same rule")
	check(PT.Card({ char = { classToken = "SHAMAN" } }) == nil and PT.Card({ char = { classToken = "WARRIOR" } }) == nil, "the same source never shows for a Shaman or a Warrior")
	PT.RegisterSource(function() error("boom") end)
	check(PT.Card({ char = { classToken = "HUNTER" } }) ~= nil, "a source that raises is contained")
	PT._ClearSources()
end

section("relevance: the Presenter drops a card for a class that is not eligible, and the page reflows (the pet card is hidden)")
do
	local ns = newNs({ level = 6, class = "Shaman", classToken = "SHAMAN" })
	ns.PetTraining.RegisterSource(function() return { { text = "Pet row" } } end)
	ns.Prefs.FinishSetup()
	ns.State.Recompute()
	ns.UI.Open("codex")
	check(ns.Presenter.Card(ns.State.plan, ns.State.ctx).pets == nil and ns.UI.main.codex.ptBox.__shown == false, "Shaman: no pet card even when a source exists")
	local hunter = newNs({ level = 6, class = "Hunter", classToken = "HUNTER" })
	hunter.PetTraining.RegisterSource(function() return { { text = "Pet row" } } end)
	hunter.Prefs.FinishSetup()
	hunter.State.Recompute()
	hunter.UI.Open("codex")
	check(hunter.Presenter.Card(hunter.State.plan, hunter.State.ctx).pets ~= nil and hunter.UI.main.codex.ptBox.__shown ~= false, "Hunter: the card appears when a source has something to say")
	check(#hunter.errors == 0 and #ns.errors == 0, "no errors")
end

section("theme: every role is defined in every theme, markers are unique and theme-independent, the choice persists, and urgency gets louder without changing meaning")
do
	local ns = newNs()
	local T = ns.Theme
	local seen = {}
	for _, role in ipairs(T.ROLES) do
		check(T.MARKER[role] and T.NAME[role], "role " .. role .. " has a marker and a name")
		check(not seen[T.MARKER[role]], "marker for " .. role .. " is unique (colour is not the only signal)")
		seen[T.MARKER[role]] = true
		for _, key in ipairs(T.ORDER) do
			local s = T.Style(role, key)
			check(s.bg and s.edge and s.accent and s.label and s.marker == T.MARKER[role], role .. " in " .. key .. " has a complete style and the same marker")
		end
	end
	check(T.Style("nonsense").role == "optional", "an unknown role falls back to the quiet 'optional' look")
	check(T.Style("primary").weight > T.Style("optional").weight and T.Style("urgent").weight > T.Style("ready").weight, "primary and urgent are the heavy roles")
	local calm, critical = T.Urgency("OK"), T.Urgency("CRITICAL")
	check(critical.weight > calm.weight and critical.edge[1] == critical.accent[1], "a timer about to run out is louder than a calm one")
	check(T.Urgency("EXPIRED").role == "later", "an expired timer goes quiet")
	check(T.Key() == "codex", "the default theme is the classic Quest Flow look")
	check(T.Set("contrast") and ns.Prefs.ThemeKey() == "contrast" and T.Key() == "contrast", "choosing a theme saves it")
	check(not T.Set("nonsense") and T.Key() == "contrast", "an unknown theme is refused")
	ns.Prefs.SetThemeKey("garbage")
	check(T.Key() == "codex", "an unknown saved theme falls back to the default")
	check(T.Style("urgent", "codex").accent[1] ~= T.Style("dungeon", "codex").accent[1] or T.Style("urgent", "codex").accent[2] ~= T.Style("dungeon", "codex").accent[2], "the timed-quest and dungeon roles no longer look alike")
end

section("window: width is clamped, reflows the page, is saved with the position, and Reset puts it back")
do
	local ns = newNs()
	ns.Prefs.FinishSetup()
	ns.State.Recompute()
	ns.UI.Open("codex")
	local UI = ns.UI
	check(UI.ClampWidth(10) == UI.WIDTH_MIN and UI.ClampWidth(5000) == UI.WIDTH_MAX and UI.ClampWidth(400) == 400 and UI.ClampWidth("x") == UI.COMPACT_WIDTH and UI.ClampWidth(0 / 0) == UI.COMPACT_WIDTH, "widths are kept inside the allowed range; junk is the default")
	local before = UI.main.codex.nowBox.__w
	check(UI.SetWidth(460) == 460 and UI.frame.__w == 460, "SetWidth resizes the window")
	check(UI.main.codex.nowBox.__w == 460 - 16 and UI.main.codex.nowBox.__w > before, "and every card follows (the page reflowed)")
	check(UI.SetWidth(9999) == UI.WIDTH_MAX and UI.SetWidth(1) == UI.WIDTH_MIN, "even a drag past the ends stops at the limits")
	UI.SetWidth(420)
	UI.main.sizing = { x = 0, w = 420 }
	UI.EndResize()
	check(ns.Prefs.WindowPos() and ns.Prefs.WindowPos().w == 420 and UI.main.sizing == nil, "ending a drag saves the width with the window position")
	_G.GetCursorPosition = function() return 50, 0 end
	UI.main.sizing = { x = 0, w = 420 }
	UI.TickResize()
	check(UI.frame.__w == 470, "dragging the grip follows the mouse")
	UI.EndResize()
	_G.GetCursorPosition = nil
	ns.Prefs.SetWindowPos({ point = "TOPLEFT", rel = "TOPLEFT", x = 10, y = -10, w = 90000, h = 300 })
	local ns3 = newNs()
	ns3.Prefs.FinishSetup(); ns3.State.Recompute(); ns3.UI.Open("codex")
	check(ns3.UI.frame.__w <= ns3.UI.WIDTH_MAX, "a damaged saved width never restores outside the range")
	UI.ResetWindow()
	check(UI.frame.__w == UI.COMPACT_WIDTH and ns.Prefs.WindowPos() ~= nil, "Reset window puts the default width back")
	check(#ns.errors == 0 and #ns3.errors == 0, "no errors")
end

section("startup: the window (or first-time setup) appears by itself at login; nothing waits for a minimap click")
do
	local first = newNs({ level = 3 })
	check(first.UI.options and first.UI.options.__shown and first.UI.optionsKey == "options" and (first.UI.frame == nil or not first.UI.frame.__shown), "a first-time character gets the setup panel at login")
	check(first.UI.Init() == "setup", "Init says so")
	first.Prefs.FinishSetup(); first.State.Recompute()
	if first.UI.options then first.UI.options:Hide() end
	check(first.UI.Init() == "tracker" and first.UI.frame.__shown, "a character that has finished setup gets the tracker")
	first.Prefs.SetTrackerShown(false); first.UI.frame:Hide()
	check(first.UI.Init() == "hidden" and not first.UI.frame.__shown, "one that closed the tracker last time does not get it forced open")
	check(first.UI.main.grip ~= nil, "the tracker has its resize grip from the start")
	check(#first.errors == 0, "no errors")
end
