-- ForeverProbeM814: disposable M8.14 research probe for the Guide Arrow and draggable UI.
--
-- Questions (none verified on Forever before this probe):
--   1. GetPlayerFacing(): does it exist and change as the player turns? (needed for a relative arrow)
--   2. Built-in arrow textures: do candidate paths load, and does Texture:SetRotation work?
--   3. Arrow glyphs (U+2191 etc.) in the game font: rendered, or blank boxes like emoji (M8.3)?
--   4. Right-click drag: SetMovable / RegisterForDrag / StartMoving / StopMovingOrSizing / GetPoint.
-- Also records presence of GetCursorPosition and Minimap geometry for later use.
--
-- | Folder / files     | ForeverProbeM814 / ForeverProbeM814.lua, .toc |
-- | SavedVariables     | ForeverProbeM814DB  (attached at ADDON_LOADED -- M8.12)  |
-- | Slash command      | /fprobe814   (toggle test window) | /fprobe814 report |
-- | Chat prefix        | [FProbeM814]                                  |
--
-- Read-only: creates one test window; no quest, map, or waypoint calls.

local addonName, ns = ...
local VERSION = "m8-14-probe-0.1"
local PREFIX = "|cffffcc33[FProbeM814]|r "

-- Candidate textures: built-in UI art that exists on Blizzard clients. Whether each path exists on Forever is
-- exactly what is being tested; nothing assumes any of them loads.
local TEXTURES = {
	{ key = "A", path = "Interface\\Minimap\\MinimapArrow" },
	{ key = "B", path = "Interface\\Minimap\\Rotating-MinimapGuideArrow" },
	{ key = "C", path = "Interface\\Buttons\\UI-SpellbookIcon-NextPage-Up" },
	{ key = "D", path = "Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Up" },
}
-- Glyph line: up, up-right, right, down-right, down, check mark, then ASCII fallbacks.
local GLYPHS = "\226\134\145 \226\134\151 \226\134\146 \226\134\152 \226\134\147 \226\156\147  ^ > v <"

local session
local window
local results = { textures = {}, drag = {} }

local function say(msg)
	if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage(PREFIX .. msg) end
end

local function exists(name)
	return type(_G[name]) == "function" and "function" or "absent"
end

local function readFacing()
	if type(GetPlayerFacing) ~= "function" then return "absent" end
	local ok, v = pcall(GetPlayerFacing)
	if not ok then return "error", tostring(v) end
	if v == nil then return "nil" end
	return "ok", v
end

local function buildWindow()
	window = CreateFrame("Frame", "ForeverProbeM814Window", UIParent)
	window:SetSize(300, 200)
	window:SetPoint("TOP", UIParent, "TOP", 0, -140)
	window:SetFrameStrata("HIGH")
	local bg = window:CreateTexture(nil, "BACKGROUND")
	bg:SetAllPoints()
	bg:SetColorTexture(0, 0, 0, 0.8)

	local title = window:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	title:SetPoint("TOP", window, "TOP", 0, -8)
	title:SetText("M8.14 probe - right-drag me")

	window.facing = window:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	window.facing:SetPoint("TOP", title, "BOTTOM", 0, -6)

	-- Four candidate textures, each labelled, each rotated by facing.
	window.tex = {}
	for i, t in ipairs(TEXTURES) do
		local tex = window:CreateTexture(nil, "ARTWORK")
		tex:SetSize(32, 32)
		tex:SetPoint("TOPLEFT", window, "TOPLEFT", 20 + (i - 1) * 70, -64)
		local okSet, setRet = pcall(tex.SetTexture, tex, t.path)
		local okGet, got = pcall(function() return tex:GetTexture() end)
		local label = window:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		label:SetPoint("TOP", tex, "BOTTOM", 0, -2)
		label:SetText(t.key)
		results.textures[t.key] = {
			path = t.path,
			set_ok = okSet, set_return = (type(setRet) == "boolean" or type(setRet) == "number") and setRet or nil,
			get_texture = okGet and (type(got) == "string" or type(got) == "number") and got or nil,
			rotation_api = type(tex.SetRotation) == "function",
		}
		window.tex[i] = tex
	end

	local glyphs = window:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	glyphs:SetPoint("BOTTOM", window, "BOTTOM", 0, 34)
	glyphs:SetText(GLYPHS)

	window.drag = window:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	window.drag:SetPoint("BOTTOM", window, "BOTTOM", 0, 12)
	window.drag:SetText("drag: not yet")

	-- Right-click drag (the interaction the minimap button and Guide Arrow will use).
	local api = {}
	for _, m in ipairs({ "SetMovable", "EnableMouse", "RegisterForDrag", "StartMoving", "StopMovingOrSizing", "GetPoint", "SetClampedToScreen" }) do
		api[m] = type(window[m]) == "function"
	end
	results.drag.api = api
	pcall(window.SetMovable, window, true)
	pcall(window.EnableMouse, window, true)
	pcall(window.SetClampedToScreen, window, true)
	results.drag.register_ok = pcall(window.RegisterForDrag, window, "RightButton")
	window:SetScript("OnDragStart", function(self)
		results.drag.started = (results.drag.started or 0) + 1
		pcall(self.StartMoving, self)
	end)
	window:SetScript("OnDragStop", function(self)
		pcall(self.StopMovingOrSizing, self)
		local ok, point, _, rel, x, y = pcall(self.GetPoint, self, 1)
		results.drag.stopped = (results.drag.stopped or 0) + 1
		results.drag.last_point = ok and { point = point, rel = rel, x = x, y = y } or { error = tostring(point) }
		window.drag:SetText(string.format("drag: %s %.0f, %.0f", tostring(point), x or 0, y or 0))
	end)
	window:SetScript("OnMouseUp", function(_, button)
		results.drag.clicks = results.drag.clicks or {}
		results.drag.clicks[button or "?"] = (results.drag.clicks[button or "?"] or 0) + 1
	end)

	-- Facing readout and rotation, 10x per second.
	local acc = 0
	window:SetScript("OnUpdate", function(_, elapsed)
		acc = acc + (elapsed or 0)
		if acc < 0.1 then return end
		acc = 0
		local st, v = readFacing()
		if st == "ok" then
			window.facing:SetText(string.format("facing %.2f rad (%.0f deg)", v, math.deg(v)))
			local f = results.facing
			f.min, f.max = math.min(f.min or v, v), math.max(f.max or v, v)
			f.samples = (f.samples or 0) + 1
			for i, tex in ipairs(window.tex) do
				local ok = pcall(tex.SetRotation, tex, v)
				results.textures[TEXTURES[i].key].rotation_ok = ok
			end
		else
			window.facing:SetText("facing: " .. st)
		end
	end)
end

local function report()
	local st = readFacing()
	local f = results.facing
	say(string.format("GetPlayerFacing: %s | range seen %.2f..%.2f rad over %d samples", st, f.min or -1, f.max or -1, f.samples or 0))
	for _, t in ipairs(TEXTURES) do
		local r = results.textures[t.key]
		if r then
			say(string.format("texture %s: set=%s getTexture=%s rotationAPI=%s rotated=%s", t.key, tostring(r.set_ok),
				tostring(r.get_texture), tostring(r.rotation_api), tostring(r.rotation_ok)))
		end
	end
	local d = results.drag
	say(string.format("drag: register=%s started=%s stopped=%s last=%s", tostring(d.register_ok), tostring(d.started),
		tostring(d.stopped), d.last_point and string.format("%s %.0f,%.0f", tostring(d.last_point.point), d.last_point.x or 0, d.last_point.y or 0) or "none"))
	say("Screenshot the window (which of A-D show an arrow, which glyphs render), then /reload to save.")
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(_, event, name)
	if name ~= addonName then return end
	ForeverProbeM814DB = type(ForeverProbeM814DB) == "table" and ForeverProbeM814DB or {}
	ForeverProbeM814DB.sessions = ForeverProbeM814DB.sessions or {}
	results.facing = {}
	session = { probe_version = VERSION, results = results, apis = {
		GetPlayerFacing = exists("GetPlayerFacing"), GetCursorPosition = exists("GetCursorPosition"),
		MinimapGetCenter = (type(Minimap) == "table" and type(Minimap.GetCenter) == "function") and "function" or "absent",
	} }
	table.insert(ForeverProbeM814DB.sessions, session)
	say(VERSION .. " loaded. /fprobe814 opens the test window.")
end)

SLASH_FOREVERPROBEM8141 = "/fprobe814"
SlashCmdList["FOREVERPROBEM814"] = function(msg)
	if (msg or ""):lower():match("report") then return report() end
	if not window then buildWindow() elseif window:IsShown() then window:Hide() else window:Show() end
end

-- Test-only seam (no in-game code path reads it).
ns._selftest = { results = results, getWindow = function() return window end, report = report }
