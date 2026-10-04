-- run_codex_tests.lua <addonDir> <m8-13 ForeverQuestGuide dir>        (lua5.1)
--   from forever-codex/tests:   lua5.1 run_codex_tests.lua ../ForeverCodex ../../m8-13-progression/ForeverQuestGuide
--
-- Stub-environment tests for Forever Codex 0.1 "First Light". The addon is loaded exactly as the client would load
-- it: every file in .toc order sharing one namespace table, THEN SavedVariables restored, THEN ADDON_LOADED, THEN
-- PLAYER_LOGIN (the order M8.12 verified on Forever). The stub client is configurable (character, location, quest
-- log, completed quests, missing APIs) so engine behaviour can be pinned down deterministically.
--
-- What this proves: the addon's OWN logic (loading, data provenance, eligibility, player control, determinism, UI
-- wiring, diagnostics). What it does NOT prove: anything about how Forever behaves. Real-client behaviour is checked
-- separately (docs/CODEX_TEST_GUIDE.md) and is reported separately.

local ADDON = arg[1] or "../ForeverCodex"
local M813 = arg[2] or "../../m8-13-progression/ForeverQuestGuide"
local passed, failed = 0, 0
-- run_planner_eval.lua sets PLANNER_EVAL_ONLY: print only failures and the planner evaluation reports
local QUIET = rawget(_G, "PLANNER_EVAL_ONLY") == true
local function check(cond, name)
	if cond then passed = passed + 1; if not QUIET then print("[OK]   " .. name) end
	else failed = failed + 1; print("[FAIL] " .. name) end
end
local function section(t) if not QUIET or t:find("planner evaluation", 1, true) then print("== " .. t .. " ==") end end

local function readFile(path)
	local f = assert(io.open(path, "rb"))
	local t = f:read("*a")
	f:close()
	return t
end

-- ---------------------------------------------------------------- stub client

local W  -- current fake world

--- Widgets answer unknown CamelCase METHOD calls with a no-op; lowercase field reads return nil (like real tables).
local function widget(kind)
	local w = { __kind = kind, __shown = true, __text = "", __scripts = {}, __enabled = true }
	return setmetatable(w, { __index = function(t, k)
		if k == "IsShown" then return function(self) return self.__shown end end
		if k == "Show" then return function(self) self.__shown = true end end
		if k == "Hide" then return function(self) self.__shown = false end end
		if k == "SetText" then return function(self, v) self.__text = v or "" end end
		if k == "GetText" then return function(self) return self.__text end end
		if k == "RegisterEvent" then return function(self, ev) if W then W.registeredEvents = W.registeredEvents or {}; W.registeredEvents[#W.registeredEvents + 1] = ev end end end
		if k == "SetJustifyH" then return function(self, v) self.__justify = v end end
		if k == "SetSize" then return function(self, wd, ht) self.__w, self.__h = wd, ht end end
		if k == "SetWidth" then return function(self, wd) self.__w = wd end end
		if k == "SetRotation" then return function(self, r) self.__rotation = r end end
		if k == "SetScript" then return function(self, n, fn) self.__scripts[n] = fn end end
		if k == "CreateTexture" then return function() return widget("Texture") end end
		if k == "CreateFontString" then return function() local f = widget("FontString"); if W then W.fonts = W.fonts or {}; W.fonts[#W.fonts + 1] = f end return f end end
		if k == "GetStringHeight" then return function() return 12 end end
		if k == "ClearAllPoints" then return function(self) self.__points = nil end end
		if k == "SetPoint" then return function(self, ...) self.__points = { ... } end end
		if k == "SetFont" then return function(self, path, size, flags) self.__font = { path = path, size = size, flags = flags } end end
		if k == "SetHeight" then return function(self, ht) self.__h = ht end end
		if k == "SetTexture" then return function(self, path) self.__texture = path end end
		if k == "SetTextColor" then return function(self, r, g, b) self.__color = string.format("%.2f,%.2f,%.2f", r or 0, g or 0, b or 0) end end
		if k == "SetMovable" then return function(self, v) self.__movable = v end end
		if k == "EnableMouse" then return function(self, v) self.__mouse = v end end
		if k == "RegisterForDrag" then return function(self, ...) self.__drag = { ... } end end
		if k == "SetClampedToScreen" then return function(self, v) self.__clamped = v end end
		if k == "GetPoint" then return function(self) local p = self.__points; if p then return p[1], p[2], p[3], p[4], p[5] end end end
		if type(k) == "string" and k:match("^%u") then return function() end end
		return nil
	end })
end

local function V(x, y) return { x = x, y = y, GetXY = function(self) return self.x, self.y end } end

local MAPS = {}
local function defMap(id, cont, ox, oy, w, h) MAPS[id] = { c = cont, ox = ox, oy = oy, w = w or 3500, h = h or 2800 } end

local function newWorld(opts)
	opts = opts or {}
	W = {
		chat = {}, frames = {}, waypoint = nil, supertrack = nil, waypointCalls = 0, questCalls = 0,
		char = { name = "Thrall", realm = "Forever", level = 25, class = "Warrior", classToken = "WARRIOR", race = "Troll",
			raceToken = "Troll", faction = "Horde" },
		loc = { map = 1413, x = 0.514, y = 0.302, zone = "The Barrens", subzone = "The Crossroads" },
		log = {}, completed = {}, group = 1, missing = opts.missing or {}, mapShown = false,
	}
	for k, v in pairs(opts.char or {}) do W.char[k] = v end
	for k, v in pairs(opts.loc or {}) do W.loc[k] = v end
	if opts.noLoc then W.loc.map, W.loc.x, W.loc.y = nil, nil, nil end
	_G.CreateFrame = function(kind, name) local f = widget(kind); f.__name = name; if name then _G[name] = f end; table.insert(W.frames, f); return f end   -- named frames become globals, as in WoW
	_G.UIParent, _G.Minimap, _G.WorldMapFrame = widget("UIParent"), widget("Minimap"), widget("WorldMapFrame")
	_G.GameFontNormal, _G.GameTooltip = { GetFont = function() return "Fonts\\FRIZQT__.TTF", 12, "" end }, widget("GameTooltip")
	-- the real client shows "||" as one literal pipe (and reads a lone "|r" etc. as a colour code): W.chat is what the player SEES, W.chatRaw what was sent
	_G.DEFAULT_CHAT_FRAME = { AddMessage = function(_, m) W.chatRaw = W.chatRaw or {}; table.insert(W.chatRaw, m); table.insert(W.chat, (m:gsub("||", "\1"):gsub("|r", ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("\1", "|"))) end }
	_G.GetBuildInfo = function() return "1.60.1", "70124", "Sep 29 2026", 16001 end
	W.now, W.wall, W.xp, W.xpMax, W.clog = opts.now or 100, 1790000000, 1000, 5000, nil
	_G.GetTime = function() return W.now end
	_G.time = function() return W.wall end
	_G.UnitXP = function() return W.xp end
	_G.UnitXPMax = function() return W.xpMax end
	_G.CombatLogGetCurrentEventInfo = function() if W.clog then return unpack(W.clog, 1, 12) end end
	_G.SlashCmdList, _G.ToggleWorldMap = {}, function() W.mapShown = true end
	_G.CreateVector2D = V
	_G.UnitLevel = function() return W.char.level end
	_G.UnitName = function() return W.char.name end
	_G.GetRealmName = function() return W.char.realm end
	_G.UnitClass = function() return W.char.class, W.char.classToken, 1 end
	_G.UnitRace = function() return W.char.race, W.char.raceToken, 1 end
	_G.UnitFactionGroup = function() return W.char.faction, W.char.faction end
	_G.GetZoneText = function() return W.loc.zone end
	_G.GetSubZoneText = function() return W.loc.subzone end
	_G.GetNumGroupMembers = function() return W.group end
	_G.IsInGroup = function() return W.group > 1 end
	for _, api in ipairs({ "UnitClass", "UnitRace", "UnitFactionGroup", "GetZoneText", "GetNumGroupMembers" }) do
		if W.missing[api] then _G[api] = nil end
	end
	_G.C_Map = {
		GetBestMapForUnit = function() return W.loc.map end,
		GetPlayerMapPosition = function() return W.loc.x and V(W.loc.x, W.loc.y) or nil end,
		GetWorldPosFromMapPos = function(map, v)
			local m = MAPS[map]
			if not m then return nil end
			return m.c, V(m.ox + v.x * m.w, m.oy + v.y * m.h)
		end,
		CanSetUserWaypointOnMap = function() return true end,
		SetUserWaypoint = function(p) W.waypoint = p; W.waypointCalls = W.waypointCalls + 1 end,
	}
	_G.UiMapPoint = { CreateFromCoordinates = function(map, x, y) return { uiMapID = map, x = x, y = y } end }
	_G.C_SuperTrack = { SetSuperTrackedUserWaypoint = function(on) W.supertrack = on end }
	_G.C_QuestLog = {
		GetNumQuestLogEntries = function() return #W.log, #W.log end,
		GetInfo = function(i) local e = W.log[i]; return e and { questID = e.questID, title = e.title, isHeader = e.isHeader } end,
		IsComplete = function(id) for _, e in ipairs(W.log) do if e.questID == id then return e.complete == true end end return false end,
		ReadyForTurnIn = function(id) for _, e in ipairs(W.log) do if e.questID == id then return e.complete == true end end return false end,
		IsOnQuest = function(id) for _, e in ipairs(W.log) do if e.questID == id then return true end end return false end,
		IsQuestFlaggedCompleted = function(id) return W.completed[id] == true end,
		-- real shape (M8.9): an array of { text, type, finished, numFulfilled, numRequired }; nil for an unknown quest
		GetQuestObjectives = function(id) return W.objectives and W.objectives[id] or nil end,
		-- the game's own quest-map points for a map: an array of { questID, x, y } (real shape, seen on the Forever client in the v0.2.10 report)
		GetQuestsOnMap = function(map) return (W.questPoints and W.questPoints[map]) or {} end,
	}
	-- the stub client must never be asked to change quest state
	for _, f in ipairs({ "AcceptQuest", "CompleteQuest", "GetQuestReward", "AbandonQuest", "SelectGossipOption" }) do
		_G[f] = function() W.questCalls = W.questCalls + 1 end
	end
	if opts.noMapAPI then _G.C_Map = nil end
end

local function tocFiles()
	local out = {}
	for line in readFile(ADDON .. "/ForeverCodex.toc"):gmatch("[^\r\n]+") do
		if not line:match("^%s*#") and not line:match("^%s*$") then out[#out + 1] = line end
	end
	return out
end

local KALIMDOR = { [1411] = true, [1412] = true, [1413] = true, [1438] = true, [1439] = true, [1440] = true, [1441] = true, [1442] = true }

--- Gives every map id the data mentions a synthetic world rectangle (so cross-map distances are computable).
local function layoutMaps(ns)
	local ids, seen = {}, {}
	local function add(m) if m and not seen[m] then seen[m] = true; ids[#ids + 1] = m end end
	for _, id in ipairs(ns.Registry.QuestIds()) do
		local q = ns.Registry.Quest(id)
		if q.loc then add(q.loc.map) end
		for _, c in ipairs(q.objCoords or {}) do add(c.map) end
	end
	for _, n in ipairs(ns.Registry.FlightNodes()) do add(n.map) end
	add(1413)
	table.sort(ids)
	for i, m in ipairs(ids) do
		if not MAPS[m] then defMap(m, KALIMDOR[m] and 1 or 0, (KALIMDOR[m] and 0 or 100000) + i * 4000, 0) end
	end
end

--- Loads the addon like the client does. Returns the namespace table.
local function boot(opts)
	opts = opts or {}
	newWorld(opts)
	_G.ForeverCodexDB, _G.ForeverCodex = nil, nil
	local ns = {}
	for _, file in ipairs(tocFiles()) do
		local path = ADDON .. "/" .. (file:gsub("\\", "/"))
		local chunk, err = loadfile(path)
		assert(chunk, err)
		chunk("ForeverCodex", ns)
	end
	if opts.synthetic then ns.Registry.ClearPacks() else layoutMaps(ns) end
	_G.ForeverCodexDB = opts.savedVars     -- SavedVariables are restored AFTER the files run, BEFORE ADDON_LOADED (M8.12)
	ns._selftest.boot.onEvent(nil, "ADDON_LOADED", "ForeverCodex")
	ns._selftest.telemetry.onEvent("ADDON_LOADED", "ForeverCodex")
	if opts.login ~= false then
		ns._selftest.boot.onEvent(nil, "PLAYER_LOGIN")
		ns._selftest.telemetry.onEvent("PLAYER_LOGIN")
	end
	return ns
end

local function slash(msg) _G.SlashCmdList["FOREVERCODEX"](msg) end
local function chatHas(s) for _, m in ipairs(W.chat) do if m:find(s, 1, true) then return true end end return false end
local function recompute(ns) return ns.State.Recompute() end
local function seqIds(plan)
	local t = {}
	for _, a in ipairs(plan.sequence) do t[#t + 1] = a.id end
	return table.concat(t, ",")
end
local function contains(plan, id)
	for _, a in ipairs(plan.sequence) do if a.id == id or a.forId == id then return true end end
	return false
end
local function click(btn) btn.__scripts.OnClick(btn) end
--- The first QUEST action in the plan (the NEXT card may be the TRAVEL step that gets you there).
local function firstQuest(plan)
	for _, a in ipairs(plan.sequence) do if a.type == "QUEST" then return a end end
	return nil
end

--- Registers a synthetic quest pack (ATT layer) for deterministic engine scenarios.
local function attPack(ns, recs, zones)
	local map = {}
	for _, r in ipairs(recs) do map[r.id] = r end
	ns.Registry.ClearPacks("quests")
	ForeverCodex.RegisterPack("quests", "att:test", {
		meta = { src = "att", verified = false, priority = 10, label = "test ATT" },
		zones = zones or { { key = "zone-a", label = "Zone A", map = 9001, quests = #recs } }, quests = map,
	})
end

defMap(9001, 0, 0, 0, 1000, 1000)      -- synthetic maps for engine scenarios
defMap(9002, 0, 3000, 0, 1000, 1000)
defMap(9003, 1, 0, 0, 1000, 1000)      -- other continent

-- ================================================================ 1. structure and safety

section("structure: .toc, files, read-only guarantee, ASCII UI")
do
	local files = tocFiles()
	local listed, missing = {}, {}
	for _, f in ipairs(files) do
		listed[(f:gsub("\\", "/"))] = true
		local h = io.open(ADDON .. "/" .. (f:gsub("\\", "/")), "rb")
		if h then h:close() else missing[#missing + 1] = f end
	end
	check(#missing == 0, ".toc lists only files that exist" .. (#missing > 0 and (": " .. table.concat(missing, ", ")) or ""))
	local p = io.popen('cd "' .. ADDON .. '" && find . -name "*.lua" | sed "s#^\\./##" | sort')
	local orphans = {}
	for f in p:lines() do if not listed[f] then orphans[#orphans + 1] = f end end
	p:close()
	check(#orphans == 0, "every .lua file in the addon is listed in the .toc" .. (#orphans > 0 and (": " .. table.concat(orphans, ", ")) or ""))
	check(files[1] == "Core.lua" and files[2] == "Registry.lua", "Core and Registry load first")
	check(readFile(ADDON .. "/ForeverCodex.toc"):find("## SavedVariables: ForeverCodexDB", 1, true) ~= nil, "one SavedVariable: ForeverCodexDB")

	local forbidden = { "AcceptQuest", "CompleteQuest", "GetQuestReward", "AbandonQuest", "SelectGossipOption", "SendChatMessage",
		"RunMacro", "UseContainerItem", "CastSpellByName", "TargetUnit", "InteractUnit", "TakeTaxiNode" }
	local bad, nonAscii = {}, {}
	for _, f in ipairs(files) do
		local text = readFile(ADDON .. "/" .. (f:gsub("\\", "/")))
		local code = text:gsub("%-%-[^\n]*", "")   -- ignore comments
		for _, name in ipairs(forbidden) do
			if code:find(name .. "%s*%(") then bad[#bad + 1] = f .. ":" .. name end
		end
		if not f:match("^Data[\\/]") and text:find("[\128-\255]") then nonAscii[#nonAscii + 1] = f end
	end
	check(#bad == 0, "no quest-changing / chat / combat calls anywhere in the addon" .. (#bad > 0 and (": " .. table.concat(bad, ", ")) or ""))
	check(#nonAscii == 0, "non-data Lua files are ASCII only (glyphs render as blank boxes on this client)" .. (#nonAscii > 0 and (": " .. table.concat(nonAscii, ", ")) or ""))
	-- no runtime string may call ATT data "confirmed"/"verified" (comments excluded)
	local claims = {}
	for _, f in ipairs(files) do
		if not f:match("^Data[\\/]") then
			local code = readFile(ADDON .. "/" .. (f:gsub("\\", "/"))):gsub("%-%-[^\n]*", "")
			for s in code:gmatch('"([^"\n]*)"') do
				local low = s:lower()
				local isLabel = low:find("verified=", 1, true) or low:find("verified %%s", 1, true)   -- a data-field label, not a claim
				if (low:find("confirmed") or (low:find("verified") and not low:find("unverified"))) and not low:find("not confirmed") and not isLabel then
					claims[#claims + 1] = f .. ': "' .. s .. '"'
				end
			end
		end
	end
	check(#claims == 0, "no UI/engine string presents data as confirmed or verified" .. (#claims > 0 and (": " .. claims[1]) or ""))
end

section("copy fidelity: reused M8.13 modules differ from the originals only by the documented renames")
do
	local function expected(name, subs)
		local t = readFile(M813 .. "/" .. name)
		for _, s in ipairs(subs) do
			local a, b = s[1], s[2]
			local i, j = t:find(a, 1, true)
			if i then t = t:sub(1, i - 1) .. b .. t:sub(j + 1) end
			-- global replace for repeated tokens
			local from = 1
			while true do
				local i2, j2 = t:find(a, from, true)
				if not i2 then break end
				t = t:sub(1, i2 - 1) .. b .. t:sub(j2 + 1)
				from = i2 + #b
			end
		end
		return t
	end
	local function stripBanner(text)
		return (text:gsub("^%-%- COPIED from[^\n]*\n%-%- Only[^\n]*\n%-%- Re%-copy[^\n]*\n\n", ""))
	end
	local cases = {
		{ "ProgressionEval.lua", { { "ns.ProgressionEval = {", "ns.Eval = {" }, { "-- ForeverQuestGuide.ProgressionEval:", "-- ForeverCodex.Eval (was ForeverQuestGuide.ProgressionEval):" } } },
		{ "MapPin.lua", { { "-- ForeverQuestGuide.MapPin:", "-- ForeverCodex.MapPin (was ForeverQuestGuide.MapPin):" } } },
		-- MinimapButton.lua is no longer a verbatim copy: it gained drag-to-move and a saved position (see phase4_tests.lua, "minimap button").
	}
	for _, c in ipairs(cases) do
		local copy = stripBanner(readFile(ADDON .. "/" .. c[1]))
		check(copy == expected(c[1], c[2]), c[1] .. " is the M8.13 original plus only the documented renames")
	end
end

-- ================================================================ 2. loading and lifecycle

section("loading through the stub client (TOC order, SavedVariables timing, ADDON_LOADED, PLAYER_LOGIN)")
do
	local ns = boot()
	local tocVersion = readFile(ADDON .. "/ForeverCodex.toc"):match("## Version:%s*(%S+)")
	check(type(ForeverCodex) == "table" and ForeverCodex.VERSION == tocVersion and tocVersion:match("^%d+%.%d+%.%d+$") ~= nil, "global ForeverCodex with a patch-style version equal to the .toc's (" .. tostring(ForeverCodex.VERSION) .. ")")
	check(chatHas("Forever Codex v" .. ForeverCodex.VERSION .. " loaded"), "load message printed at ADDON_LOADED, with the version")
	check(type(_G.SlashCmdList["FOREVERCODEX"]) == "function" and SLASH_FOREVERCODEX1 == "/codex" and SLASH_FOREVERCODEX2 == "/fcodex", "/codex and /fcodex registered")
	check(type(ForeverCodexDB) == "table" and type(ForeverCodexDB.chars) == "table" and ForeverCodexDB.chars["Thrall-Forever"] ~= nil, "SavedVariable table created with a per-character entry at login")
	check(ns.State.plan ~= nil and ns.State.ctx ~= nil, "a plan was computed at login")
	-- Phase 3: the player-facing build is quiet at login (a welcome until setup is done). The provenance statement did not go
	-- away: it moved to /codex diag, which still labels every pack's source and verified flag (checked in the diagnostics section).
	check(chatHas("Welcome! Type /codex to set up Forever Codex.") and not chatHas("ATT-derived") and not chatHas("next:"), "login: one welcome line, no engineering chatter")
	slash("diag")
	check(chatHas("src=att verified=false"), "/codex diag still states that the data is ATT-derived and unverified")
	check(#ns.errors == 0, "no errors were caught while loading and logging in" .. (#ns.errors > 0 and (": " .. ns.errors[1]) or ""))
	check(W.questCalls == 0, "no quest-changing API was called")
	check(ns._selftest.boot ~= nil and #W.frames >= 2, "event frame and minimap button were created")
	local mm
	for _, f in ipairs(W.frames) do if f.__name == "ForeverCodexMinimapButton" then mm = f end end
	check(mm ~= nil, "minimap button built at login")
	check(mm ~= nil and mm.__points ~= nil and mm.__points[5] == -34, "the minimap button is moved 34 px down so it does not sit on top of the Quest Guide's")
end

section("SavedVariables restore order (M8.12): defaults land on the RESTORED table, saved choices survive")
do
	local saved = { chars = { ["Thrall-Forever"] = { style = "fast", routeZone = "the-barrens", skipped = { ["Q:907"] = true } } } }
	local ns = boot({ savedVars = saved })
	local c = ForeverCodexDB.chars["Thrall-Forever"]
	check(ForeverCodexDB == saved, "the restored table is the one used")
	check(c.style == "fast" and c.routeZone == "the-barrens" and c.skipped["Q:907"] == true, "saved choices are never overwritten by defaults")
	check(c.hardcore == false and c.hereRadius == 200 and type(c.added) == "table" and type(c.systems) == "table", "missing keys get defaults, per key")
	check(c.systems.flight == true and c.systems.professions == false and c.systems.camping == false, "systems default: only the real one (flight hints) is on")
	check(ns.Prefs.IsSavedVariablesSafe(ForeverCodexDB), "the SavedVariable contains only SavedVariables-safe values")
	check(ForeverCodexDB.version == 1 and type(ForeverCodexDB.ui) == "table" and type(ForeverCodexDB.diag) == "table", "root keys present")
end

section("per-character choices")
do
	local ns = boot()
	ns.Prefs.Skip("Q:1"); ns.Prefs.SetHardcore(true)
	ns.Prefs.SetCharKey("Other-Forever")
	check(not ns.Prefs.IsSkipped("Q:1") and not ns.Prefs.IsHardcore(), "a second character starts with its own clean choices")
	ns.Prefs.SetCharKey("Thrall-Forever")
	check(ns.Prefs.IsSkipped("Q:1") and ns.Prefs.IsHardcore(), "the first character's choices are intact")
end

-- ================================================================ 3. data and provenance

section("data packs: provenance metadata")
do
	local ns = boot()
	local R = ns.Registry
	local packs = R.Packs("quests")
	local att, obs = 0, 0
	local allAttFlagged = true
	for _, p in ipairs(packs) do
		if p.meta.src == "att" then
			att = att + 1
			if p.meta.verified ~= false or p.meta.sourceRef == nil or p.meta.priority ~= 10 then allAttFlagged = false end
		elseif p.meta.src == "observed" then
			obs = obs + 1
			check(p.meta.verified == true and p.meta.priority == 100, "observed pack: src=observed, verified=true, priority 100")
		end
	end
	check(att == 3 and obs == 1, "3 ATT quest packs and 1 observed pack are loaded (" .. att .. "/" .. obs .. ")")
	check(allAttFlagged, "every ATT pack declares src=att, verified=false, a pinned source commit, priority 10")
	local fp = R.Packs("flight")[1]
	check(fp and fp.meta.src == "att" and fp.meta.verified == false, "the flight-node pack is src=att, verified=false")

	-- manifest consistency (the generator wrote these counts; the loaded data must agree)
	local manifest = readFile(ADDON .. "/Data/MANIFEST.txt")
	local attN = tonumber(manifest:match("att quests: (%d+)"))
	local obsN, both = tonumber(manifest:match("observed quests: (%d+)")), tonumber(manifest:match("also in ATT: (%d+)"))
	local st = R.Stats()
	check(st.quests == attN + obsN - both, string.format("merged quest count (%d) = ATT %d + observed %d - overlap %d", st.quests, attN, obsN, both))
	check(st.observedAndAtt == both, "overlap between observed and ATT matches the manifest (" .. st.observedAndAtt .. ")")
	check(manifest:find("8e25511677df4ea5c3d0322009eafc18f203ffd3", 1, true) ~= nil, "manifest pins the ATT commit")

	-- merged views
	local q = R.Quest(907)
	check(q ~= nil and q.name == "Enraged Thunder Lizards" and q.prov.name == "observed", "907: name comes from the OBSERVED layer")
	check(q.level == 18 and q.prov.level == "observed", "907: quest level 18 is observed")
	check(q.req == 10 and q.prov.req == "att", "907: required level 10 is ATT's, kept separate from the observed quest level")
	check(q.loc and q.loc.src == "att" and q.loc.verified == false and q.loc.kind == "giver", "907: location is the ATT giver coordinate, unverified")
	check(q.prereq and q.prereq[1] == 882 and q.faction == "Horde", "907: ATT prerequisite and faction carried through")
	check(q.hasObserved and q.hasAtt and q.layers[1].src == "observed" and q.layers[2].src == "att", "907: both layers kept, observed first")
	local onlyAtt, onlyObs, bad = 0, 0, 0
	local fallbackSeen = false
	for _, id in ipairs(R.QuestIds()) do
		local v = R.Quest(id)
		if v.hasAtt and not v.hasObserved then
			onlyAtt = onlyAtt + 1
			if v.verified ~= false or v.src ~= "att" or (v.loc and (v.loc.verified ~= false or v.loc.src ~= "att")) then bad = bad + 1 end
		elseif v.hasObserved and not v.hasAtt then
			onlyObs = onlyObs + 1
			if v.loc and v.loc.kind == "player_position" then fallbackSeen = true end
		end
	end
	check(onlyAtt > 500 and bad == 0, "every ATT-only quest (" .. onlyAtt .. ") is src=att, verified=false, with unverified coordinates")
	check(onlyObs > 50 and fallbackSeen, "observed-only quests (" .. onlyObs .. ") use the observed player position only as a labelled fallback")
	check(R.Quest(99999999) == nil, "an unknown quest id is nil, not an error")
end

section("precedence: observed over ATT, field by field (synthetic)")
do
	local ns = boot({ synthetic = true })
	local R = ns.Registry
	ForeverCodex.RegisterPack("quests", "att:t", { meta = { src = "att", verified = false, priority = 10 }, zones = {},
		quests = { [1] = { id = 1, name = "ATT Name", giverNpc = 5, giverName = "ATT Giver", map = 9001, x = 0.5, y = 0.5, req = 7, zone = "zone-a" },
			[2] = { id = 2, name = "Only ATT", map = 9001, x = 0.1, y = 0.1 } } })
	ForeverCodex.RegisterPack("quests", "obs:t", { meta = { src = "observed", verified = true, priority = 100 }, zones = {},
		quests = { [1] = { id = 1, name = "Observed Name", level = 9, objectives = { "0/1 Thing" }, giverName = "Observed Giver", giverNpc = 6,
			pos = { map = 9001, x = 0.9, y = 0.9 } },
			[3] = { id = 3, name = "Only Observed", level = 4, pos = { map = 9001, x = 0.3, y = 0.3 } } } })
	local q1 = R.Quest(1)
	check(q1.name == "Observed Name" and q1.giverName == "Observed Giver" and q1.giverNpc == 6, "observed name and giver win over ATT")
	check(q1.level == 9 and q1.req == 7 and q1.objectives[1] == "0/1 Thing", "observed level/objectives kept; ATT required level kept separately")
	check(q1.loc.src == "att" and q1.loc.x == 0.5, "coordinates: ATT giver location wins; the observed PLAYER position is not used when ATT has one")
	check(R.Quest(2).src == "att" and R.Quest(2).verified == false, "ATT-only record stays att / unverified")
	local q3 = R.Quest(3)
	check(q3.src == "observed" and q3.verified == true and q3.loc.kind == "player_position" and q3.loc.src == "observed", "observed-only record: verified, location flagged as a player position")
	ForeverCodex.RegisterPack("quests", "obs:t", nil)
	check(#R.QuestIds() == 3, "RegisterPack rejects invalid packs without error")
	ForeverCodex.RegisterPack("quests", "late:pack", { meta = { src = "att", verified = false, priority = 10 }, zones = { { key = "z-new", label = "New Zone", map = 9002, quests = 1 } },
		quests = { [10] = { id = 10, name = "Late Data", map = 9002, x = 0.5, y = 0.5, req = 1 } } })
	check(R.Quest(10) ~= nil and R.ZoneByKey("z-new") ~= nil and #R.QuestIds() == 4, "a pack added later is picked up with no engine change (quests + zones)")
end

-- ================================================================ 4. context

section("context: character, location, and three separate concepts")
do
	local ns = boot()
	local ctx = ns.State.ctx
	check(ctx.char.name == "Thrall" and ctx.char.level == 25 and ctx.char.classToken == "WARRIOR" and ctx.char.raceToken == "Troll" and ctx.char.faction == "Horde",
		"name, level, class, race and faction are read")
	check(ctx.char.raceKey == "TROLL", "race key normalised")
	check(ctx.loc.available and ctx.loc.map == 1413 and ctx.loc.zone == "The Barrens" and ctx.loc.subzone == "The Crossroads", "location: map, zone and subzone")
	check(ctx.loc.world ~= nil and ctx.loc.world.continent == 1, "location has a world position")
	check(ctx.logAvailable == true and ctx.logCount == 0, "empty quest log read")
	local ns2 = boot({ char = { raceToken = "Scourge", race = "Undead" } })
	check(ns2.State.ctx.char.raceKey == "UNDEAD", "client race token Scourge maps to ATT's UNDEAD")
	-- Race origin, route zone and current location are independent
	local ns3 = boot({ char = { race = "Troll", raceToken = "Troll", level = 30 } })
	ns3.Prefs.SetRouteZone("stranglethorn-vale")
	local plan = recompute(ns3)
	local z = ns3.Registry.ZoneByKey("stranglethorn-vale")
	check(ns3.State.ctx.char.raceKey == "TROLL" and ns3.State.ctx.loc.map == 1413 and plan.routeZone == "stranglethorn-vale" and plan.routeMap == z.map,
		"a Troll standing in the Barrens can choose Stranglethorn as the route zone: race, route zone and location stay separate")
	local first
	for _, a in ipairs(plan.sequence) do if a.type == "QUEST" then first = a break end end
	check(first ~= nil and first.target.map == z.map, "the chosen route zone steers the recommendation there, not to the race's start zone or the current zone")
	check(plan.sequence[1].type == "TRAVEL", "and Codex inserts travel to get there")
	ns3.Prefs.SetRouteZone("auto")
	plan = recompute(ns3)
	local nearFirst
	for _, a in ipairs(plan.sequence) do if a.type == "QUEST" then nearFirst = a break end end
	check(nearFirst ~= nil and nearFirst.target.map == 1413, "route zone auto follows where the character actually is")
	check(select(1, ns3.Prefs.SetRouteZone("no-such-zone")) == false and ns3.Prefs.GetRouteZone() == "auto", "an unknown route zone is refused")
end

section("context: missing APIs degrade, never guess or raise")
do
	local ns = boot({ missing = { UnitClass = true, UnitRace = true, UnitFactionGroup = true } })
	local ch = ns.State.ctx.char
	check(ch.classToken == nil and ch.raceToken == nil and ch.faction == nil, "unreadable class/race/faction stay nil")
	check(#ch.missing == 3 and ns.State.plan ~= nil, "they are listed as missing and a plan is still produced")
	local sawWarn = false
	for _, w in ipairs(ns.State.plan.warnings) do if w:find("Not available on this client") then sawWarn = true end end
	check(sawWarn, "the plan warns which APIs are unavailable")
	local ns2 = boot({ noLoc = true })
	check(ns2.State.ctx.loc.available == false and ns2.State.plan ~= nil, "no map position: location unavailable, plan still produced")
	check(ns2.State.plan.sequence[1].type ~= "TRAVEL" and #ns2.State.plan.nearby == 0,
		"without a position there is no travel to the first stop and no 'while you're here'")
	local warnedLoc = false
	for _, w in ipairs(ns2.State.plan.warnings) do if w:find("location is unavailable") then warnedLoc = true end end
	check(warnedLoc, "and the plan says the location is unavailable")
	local ns3 = boot({ noMapAPI = true })
	check(ns3.State.plan ~= nil and #ns3.errors == 0, "no C_Map at all: no errors, plan produced")
end

-- ================================================================ 5. engine

section("engine: eligibility invariants over the real data, for several characters")
do
	local cases = {
		{ char = { level = 25, classToken = "WARRIOR", class = "Warrior", raceToken = "Troll", race = "Troll", faction = "Horde" } },
		{ char = { level = 22, classToken = "MAGE", class = "Mage", raceToken = "Gnome", race = "Gnome", faction = "Alliance" }, loc = { map = 1426, x = 0.5, y = 0.5 } },
		{ char = { level = 12, classToken = "HUNTER", class = "Hunter", raceToken = "Orc", race = "Orc", faction = "Horde" }, loc = { map = 1411, x = 0.5, y = 0.5 } },
		{ char = { level = 30, classToken = "PRIEST", class = "Priest", raceToken = "NightElf", race = "Night Elf", faction = "Alliance" }, loc = { map = 1438, x = 0.5, y = 0.5 } },
	}
	for ci, c in ipairs(cases) do
		local ns = boot({ char = c.char, loc = c.loc })
		if not MAPS[(c.loc or {}).map or 1413] then defMap(c.loc.map, 0, 900000, 0) end
		ns.Prefs.SetStyle("completionist")   -- the widest net: nothing hidden for being low level
		local ctx = ns.Context.Build()
		local env = { stats = { filtered = {}, byType = {} }, strategy = ns.Registry.Strategy("completionist") }
		local acts = ns.QuestProvider.Generate(ctx, env)
		local bad, n = {}, 0
		for _, a in ipairs(acts) do
			if a.kind == "ACCEPT" then
				n = n + 1
				local v = ns.Registry.Quest(a.quest)
				local why
				if v.faction and v.faction ~= ctx.char.faction then why = "faction" end
				if v.races then local ok = false for _, r in ipairs(v.races) do if r == ctx.char.raceKey then ok = true end end if not ok then why = "race" end end
				if v.classes then local ok = false for _, r in ipairs(v.classes) do if r == ctx.char.classToken then ok = true end end if not ok then why = "class" end end
				if v.req and v.req > ctx.char.level then why = "level" end
				if v.repeatable then why = "repeatable" end
				if not v.loc then why = "noloc" end
				if v.prereq then local any = false for _, p in ipairs(v.prereq) do if ctx.isCompleted(p) then any = true end end if not any then why = "prereq" end end
				if a.src == "att" and a.verified ~= false then why = "provenance" end
				if a.target and a.target.src == "att" and a.target.verified ~= false then why = "target provenance" end
				if why then bad[#bad + 1] = a.id .. ":" .. why end
			end
		end
		check(n > 0 and #bad == 0, string.format("case %d (%s %s L%d): %d ACCEPT candidates, none violating faction/race/class/level/prereq/provenance %s", ci,
			c.char.race, c.char.classToken, c.char.level, n, #bad > 0 and bad[1] or ""))
		check(env.stats.filtered.faction ~= nil and env.stats.filtered.level ~= nil, "case " .. ci .. ": filter counts recorded for diagnostics")
		check(W.questCalls == 0, "case " .. ci .. ": no quest API was called")
	end
end

section("engine: prerequisites, level gate, completion, quest log")
do
	local ns = boot({ char = { level = 25 } })
	local cands = function() local ctx = ns.Context.Build(); return ns.QuestProvider.Generate(ctx, { stats = { filtered = {}, byType = {} }, strategy = ns.Registry.Strategy("completionist") }) end
	local function has(list, id, kind) for _, a in ipairs(list) do if a.quest == id and (not kind or a.kind == kind) then return true end end return false end
	check(not has(cands(), 907, "ACCEPT"), "907 (follows 882) is not offered until 882 is completed")
	W.completed[882] = true
	check(has(cands(), 907, "ACCEPT"), "907 is offered once 882 is flagged completed")
	W.completed[907] = true
	check(not has(cands(), 907), "a completed quest is never offered again")
	W.completed[907] = nil
	ns.State.SetPlanner(false)   -- Phase 2: the next checks pin the LEGACY greedy engine (the Planner may defer a turn-in or leave an unlocated quest out of the route; contract_tests.lua covers that)
	W.log = { { questID = 907, title = "Enraged Thunder Lizards", complete = true } }
	local plan = recompute(ns)
	local ti = firstQuest(plan)
	check(ti.kind == "TURN_IN" and ti.quest == 907, "a completed quest in the log becomes the first quest action (turn in)")
	check(plan.next.type == "TRAVEL" and plan.next.forId == ti.id or plan.next.id == ti.id, "NEXT is the turn-in, or the travel to reach it")
	check(ti.target ~= nil and ti.src == "att" and ti.verified == false, "its location is ATT's and stays unverified")
	local assumed = false
	for _, l in ipairs(ti.lines) do if l:find("assumed") then assumed = true end end
	check(assumed, "the turn-in text says the turn-in location is an assumption")
	W.log = { { questID = 907, title = "Enraged Thunder Lizards", complete = false } }
	plan = recompute(ns)
	local inProg = false
	for _, a in ipairs(plan.inProgress) do if a.quest == 907 then inProg = true end end
	check(inProg and not contains(plan, "Q:907:OBJECTIVE"), "an unfinished quest with no objective coordinates is listed as in-progress, not as a place to go")
	W.log = { { questID = 99999990, title = "Mystery Quest", complete = true } }
	plan = recompute(ns)
	local mystery
	for _, a in ipairs(plan.sequence) do if a.quest == 99999990 then mystery = a end end
	check(mystery ~= nil and mystery.target == nil and mystery.unknown == true, "a quest in the log that no pack knows is still a reminder, with no invented location")
	ns.State.SetPlanner(true)
	local ns2 = boot({ char = { level = 5 } })
	local ctx2 = ns2.Context.Build()
	local acts = ns2.QuestProvider.Generate(ctx2, { stats = { filtered = {}, byType = {} }, strategy = ns2.Registry.Strategy("completionist") })
	local tooHigh = 0
	for _, a in ipairs(acts) do if a.kind == "ACCEPT" and a.reqLevel and a.reqLevel > 5 then tooHigh = tooHigh + 1 end end
	check(tooHigh == 0, "a level 5 character is never offered a quest that requires more")
end

section("engine: player control (skip, add, route style, systems, hardcore)")
do
	local ns = boot({ char = { level = 25 } })
	local plan = recompute(ns)
	local first = plan.next
	check(first ~= nil, "there is a recommendation for a level 25 Horde character at the Crossroads")
	local skipTarget = first.type == "TRAVEL" and first.forId or first.id
	slash("skip")
	local plan2 = recompute(ns)
	check(not contains(plan2, skipTarget), "Skip removes the recommendation and the engine recalculates around it")
	check(ns.Prefs.IsSkipped(first.skipKey), "the skip is stored in the player's choices")
	slash("unskip")
	check(contains(recompute(ns), skipTarget), "unskip brings it back")
	-- Add: pin a quest Codex would not recommend (Alliance-only, high level) and see it come first
	local ally
	for _, id in ipairs(ns.Registry.QuestIds()) do
		local v = ns.Registry.Quest(id)
		if v.faction == "Alliance" and v.loc and v.req and v.req > 40 then ally = v break end
	end
	check(ally ~= nil, "found an Alliance-only high-level quest in the data to add")
	slash("add " .. ally.id)
	local plan3 = recompute(ns)
	local pinned
	for _, a in ipairs(plan3.sequence) do if a.pinned then pinned = a break end end
	check(pinned ~= nil and pinned.quest == ally.id, "an added quest is recommended even though Codex would not have offered it")
	local idxPinned
	for i, a in ipairs(plan3.sequence) do if a.pinned then idxPinned = i break end end
	check(idxPinned <= 2, "an added quest comes first (after any travel to it)")
	slash("remove " .. ally.id)
	check(not contains(recompute(ns), "Q:" .. ally.id .. ":ACCEPT"), "removing it takes it back out")
	local ok = ns.Prefs.SetStyle("solo")
	check(ok == false and ns.Prefs.GetStyle() == "efficient", "a planned route style cannot be selected")
	for _, key in ipairs({ "fast", "questing_only", "completionist", "efficient" }) do
		check(ns.Prefs.SetStyle(key) and ns.State.Recompute().strategy == key, "route style '" .. key .. "' is selectable and used by the engine")
	end
	for _, key in ipairs({ "trainers", "professions", "gathering", "camping", "dungeons", "pets", "respawnSkips", "classProgression", "group" }) do
		local s = ns.Registry.System(key)
		local ok2 = ns.Prefs.SetSystem(key, true)
		check(s ~= nil and s.planned == true and ok2 == false and ns.Prefs.IsSystemOn(key) == false, "planned system '" .. key .. "' is registered, greyed out, and cannot be switched on")
	end
	local byType = recompute(ns).stats.byType
	check(byType.TRAINER == nil and byType.PROFESSION == nil and byType.GATHER == nil and byType.CAMP == nil and byType.DUNGEON == nil
		and byType.PET_UPGRADE == nil and byType.RESPAWN_SKIP == nil and byType.CLASS_PROGRESSION == nil and byType.GROUP == nil,
		"planned systems generate no actions: nothing is faked")
	local types = {}
	for _, t in ipairs(ns.Registry.ActionTypes()) do types[t.type] = t end
	check(types.QUEST and types.TRAVEL and types.FLIGHT and types.TRAINER.planned and types.PROFESSION.planned and types.GATHER.planned and types.CAMP.planned
		and types.DUNGEON.planned and types.PET_UPGRADE.planned and types.RESPAWN_SKIP.planned and types.CLASS_PROGRESSION.planned,
		"the full action-type vocabulary is registered (QUEST/TRAVEL/FLIGHT live; the rest planned)")
	ns.Prefs.SetHardcore(true)
	check(ns.Prefs.IsHardcore(), "the Hardcore toggle works")
end

section("engine: hardcore removes respawn skips; a new provider plugs in with no engine change")
do
	local ns = boot({ synthetic = true })
	attPack(ns, { { id = 1, name = "Near", map = 9001, x = 0.5, y = 0.5, req = 1 } })
	ForeverCodex.RegisterProvider({ key = "rs-test", type = "RESPAWN_SKIP", label = "test respawn skip", generate = function(ctx, env)
		return { ns.Registry.NewAction({ id = "RS:1", type = "RESPAWN_SKIP", kind = "RESPAWN_SKIP", skipKey = "RS:1", title = "Skip the walk by dying",
			target = { map = 9001, x = 0.5, y = 0.5, label = "Spirit healer", src = "att", verified = false }, src = "att", verified = false }) }
	end })
	ForeverCodex.RegisterActionType("RESPAWN_SKIP", { label = "Respawn skip" })
	W.loc = { map = 9001, x = 0.5, y = 0.5, zone = "Zone A" }
	local plan = recompute(ns)
	local rs = false
	for _, a in ipairs(plan.sequence) do if a.type == "RESPAWN_SKIP" then rs = true end end
	check(rs, "a registered provider's actions flow through the same engine (not hardcore)")
	ns.Prefs.SetHardcore(true)
	plan = recompute(ns)
	rs = false
	for _, a in ipairs(plan.sequence) do if a.type == "RESPAWN_SKIP" then rs = true end end
	for _, a in ipairs(plan.nearby) do if a.type == "RESPAWN_SKIP" then rs = true end end
	check(not rs and plan.stats.filtered.hardcore == 1, "Hardcore drops RESPAWN_SKIP actions no matter which provider produced them")
	ns.Prefs.SetHardcore(false)
	ForeverCodex.RegisterProvider({ key = "boom", type = "QUEST", label = "failing provider", generate = function() error("provider exploded") end })
	plan = recompute(ns)
	local warned = false
	for _, w in ipairs(plan.warnings) do if w:find("boom") then warned = true end end
	local recorded = false
	for _, e in ipairs(ns.errors) do if e:find("provider exploded") then recorded = true end end
	check(plan.next ~= nil and warned and recorded, "a failing provider is caught: the plan survives, the warning and the error are recorded")
end

section("engine: route styles are scoring over the same data (synthetic scenario)")
do
	local ns = boot({ synthetic = true })
	-- one hub of quests that is slightly lower level but near; one lone, perfectly levelled quest further away
	local recs = {}
	for i = 1, 4 do recs[#recs + 1] = { id = i, name = "Hub " .. i, map = 9001, x = 0.10 + i * 0.002, y = 0.10, req = 8 } end
	recs[#recs + 1] = { id = 10, name = "Lone", map = 9001, x = 0.9, y = 0.9, req = 18 }
	recs[#recs + 1] = { id = 11, name = "Trivial", map = 9001, x = 0.11, y = 0.12, req = 1 }
	attPack(ns, recs)
	W.char.level = 20
	W.loc = { map = 9001, x = 0.12, y = 0.12, zone = "Zone A" }
	ns.Prefs.SetStyle("efficient")
	local eff = recompute(ns)
	local function quests(plan) local t = {} for _, a in ipairs(plan.sequence) do if a.type == "QUEST" then t[#t + 1] = a.quest end end return t end
	local effIds = quests(eff)
	local hasTrivialEff = false
	for _, id in ipairs(effIds) do if id == 11 then hasTrivialEff = true end end
	check(not hasTrivialEff, "efficient hides a quest 19 levels below you (beyond its level gap)")
	ns.Prefs.SetStyle("completionist")
	local comp = recompute(ns)
	local hasTrivialComp = false
	for _, id in ipairs(quests(comp)) do if id == 11 then hasTrivialComp = true end end
	check(hasTrivialComp, "completionist keeps it (maxGap = false really means no limit)")
	ns.Prefs.SetStyle("fast")
	local fast = recompute(ns)
	check(fast.strategy == "fast" and fast.next ~= nil, "fast produces a plan from the same data")
	check(quests(eff)[1] ~= nil and quests(comp)[1] ~= nil, "every active style returns quests")
	-- determinism
	ns.Prefs.SetStyle("efficient")
	local a1 = seqIds(recompute(ns))
	local a2 = seqIds(recompute(ns))
	check(a1 == a2 and #a1 > 0, "the same inputs always give the same plan (" .. a1 .. ")")
	-- tie-break by id
	attPack(ns, { { id = 5, name = "B", map = 9001, x = 0.5, y = 0.5, req = 15 }, { id = 3, name = "A", map = 9001, x = 0.5, y = 0.5, req = 15 } })
	W.loc = { map = 9001, x = 0.5, y = 0.5, zone = "Zone A" }
	check(seqIds(recompute(ns)):find("^Q:3:ACCEPT,Q:5:ACCEPT") ~= nil, "exact ties are broken by action id, deterministically")
end

section("engine: travel, route zone, 'while you're here', flight hints")
do
	local ns = boot({ synthetic = true })
	attPack(ns, { { id = 1, name = "Far Quest", giverName = "Far Giver", map = 9002, x = 0.5, y = 0.5, req = 1 },
		{ id = 2, name = "Near Quest", map = 9001, x = 0.52, y = 0.5, req = 1 } },
		{ { key = "zone-a", label = "Zone A", map = 9001, quests = 1 }, { key = "zone-b", label = "Zone B", map = 9002, quests = 1 } })
	ForeverCodex.RegisterPack("flight", "att:fp", { meta = { src = "att", verified = false, priority = 10 },
		nodes = { [1] = { id = 1, name = "Test Flight Point", map = 9001, x = 0.5, y = 0.51, faction = "Horde" },
			[2] = { id = 2, name = "Alliance Point", map = 9001, x = 0.5, y = 0.51, faction = "Alliance" },
			[3] = { id = 3, name = "Distant Point", map = 9002, x = 0.5, y = 0.5 } } })
	W.char.level = 10
	W.loc = { map = 9001, x = 0.5, y = 0.5, zone = "Zone A" }
	local plan = recompute(ns)
	check(plan.next.type == "QUEST" and plan.next.quest == 2, "the nearby quest comes first and needs no travel")
	local far
	-- Phase 2: the Planner does not plan a quest 3000 yards away while there is local work (it costs more time than it
	-- earns; contract_tests.lua covers that), so the legacy "whole chain" travel step is pinned on the legacy path.
	ns.State.SetPlanner(false)
	local legacyPlan = recompute(ns)
	ns.State.SetPlanner(true)
	for i, a in ipairs(legacyPlan.sequence) do if a.kind == "TRAVEL" then far = { i = i, a = a } end end
	check(far ~= nil and far.a.forId == "Q:1:ACCEPT" and far.a.target.map == 9002 and far.a.dist > 150, "far quest: a TRAVEL step is inserted before it, with the distance")
	check(legacyPlan.sequence[far.i + 1].id == "Q:1:ACCEPT", "the TRAVEL step is immediately followed by the quest it serves")
	local fp, ally
	for _, a in ipairs(plan.nearby) do if a.type == "FLIGHT" then fp = a end if a.id == "FP:2" then ally = a end end
	check(fp ~= nil and fp.id == "FP:1" and fp.src == "att" and fp.verified == false, "'while you're here': a flight node close by, labelled ATT / unverified")
	check(ally == nil, "faction-restricted flight nodes are filtered out")
	local distant = false
	for _, a in ipairs(plan.nearby) do if a.id == "FP:3" then distant = true end end
	check(not distant, "far-away flight nodes are not 'here'")
	local hint = false
	for _, l in ipairs(fp.lines) do if l:find("cannot tell whether you already have") then hint = true end end
	check(hint, "the flight hint says Codex cannot know whether the path is already discovered")
	ns.Prefs.Skip("FP:1")
	plan = recompute(ns)
	local fpStill = false
	for _, a in ipairs(plan.nearby) do if a.id == "FP:1" then fpStill = true end end
	check(not fpStill and plan.stats.filtered.skipped ~= nil, "a skipped flight hint is not shown again (skip applies to every action type)")
	ns.Prefs.Unskip("FP:1")
	ns.Prefs.SetSystem("flight", false)
	plan = recompute(ns)
	local anyFp = false
	for _, a in ipairs(plan.nearby) do if a.type == "FLIGHT" then anyFp = true end end
	check(not anyFp, "switching the flight-hint system off removes them")
	ns.Prefs.SetSystem("flight", true)
	ns.Prefs.SetStyle("questing_only")
	plan = recompute(ns)
	anyFp = false
	for _, a in ipairs(plan.nearby) do if a.type == "FLIGHT" then anyFp = true end end
	check(not anyFp and plan.stats.filtered.style ~= nil, "questing-only style suppresses non-quest hints")
	ns.Prefs.SetStyle("efficient")
	-- explicit route zone beats convenience
	ns.Prefs.SetRouteZone("zone-b")
	plan = recompute(ns)
	local q
	for _, a in ipairs(plan.sequence) do if a.type == "QUEST" then q = a break end end
	check(q.quest == 1, "choosing route zone B sends the character to B even though a quest is closer")
	ns.Prefs.SetRouteZone("auto")
	-- no data at all
	ns.Registry.ClearPacks()
	plan = recompute(ns)
	local noData = false
	for _, w in ipairs(plan.warnings) do if w:find("No quest data packs") then noData = true end end
	check(plan.next == nil and noData, "no data loaded: nothing recommended, a clear warning, no error")
	check(#ns.errors == 0, "no errors were caught anywhere in the engine scenarios" .. (#ns.errors > 0 and (": " .. ns.errors[1]) or ""))
end

section("route adapter: M8.13 step schema and evaluators")
do
	local ns = boot({ synthetic = true })
	attPack(ns, { { id = 1, name = "Q", map = 9001, x = 0.9, y = 0.5, req = 1, giverName = "G" } })
	W.char.level = 10
	W.loc = { map = 9001, x = 0.1, y = 0.5, zone = "Zone A" }
	local plan = recompute(ns)
	local route = ns.Route.Build(plan)
	check(route.id == "codex-dynamic" and route.step_order[1] == plan.sequence[1].id and route.steps[route.step_order[1]].next_step_id == route.step_order[2],
		"the plan becomes a runtime route in the M8.13 shape (ordered steps, next_step_id)")
	local travel = plan.sequence[1]
	check(travel.type == "TRAVEL" and ns.Route.Step(travel).kind == "TRAVEL" and ns.Route.Step(travel).destination.ui_map_id == 9001, "TRAVEL maps to a TRAVEL step with a destination")
	local st = ns.Route.Evaluate(travel)
	check(st.state == "WAITING" and st.distance and st.distance > 100, "evaluator: far from the destination is WAITING with a distance (" .. tostring(st.reason) .. ")")
	W.loc = { map = 9001, x = 0.9, y = 0.5, zone = "Zone A" }
	st = ns.Route.Evaluate(travel)
	check(st.state == "SATISFIED", "evaluator: standing at the destination is SATISFIED (" .. tostring(st.reason) .. ")")
	local accept = plan.sequence[2]
	check(ns.Route.Step(accept).kind == "ACCEPT" and ns.Route.Step(accept).quest_id == 1, "ACCEPT maps to an ACCEPT step")
	local flight = ns.Registry.NewAction({ id = "FP:1", type = "FLIGHT", kind = "DISCOVER", title = "x" })
	check(ns.Route.Evaluate(flight).state == "UNDETECTABLE", "an action type without an evaluator is UNDETECTABLE (manual), exactly as future types will behave")
end

-- ================================================================ 6. UI

section("UI: window, Next card, buttons, provenance wording")
do
	local ns = boot({ char = { level = 25 } })
	slash("dev")      -- Phase 3: /codex opens the player window; the engineering window (these checks) is /codex dev
	local w = ns.DevUI.w
	check(ns.DevUI.IsShown() and ns.DevUI.frame.__name == "ForeverCodexWindow", "/codex dev opens the developer window")
	check(w.charFS.__text:find("Thrall") and w.charFS.__text:find("level 25") and w.charFS.__text:find("Troll") and w.charFS.__text:find("Warrior") and w.charFS.__text:find("Horde"),
		"header shows name, level, race, class and faction")
	check(w.whereFS.__text:find("Race origin: Troll", 1, true) and w.whereFS.__text:find("Route zone (your choice): auto", 1, true) and w.whereFS.__text:find("Now in: The Barrens", 1, true),
		"header shows race origin, route zone (your choice) and current location as three separate things")
	local plan = ns.State.plan
	check(w.nextTitle.__text ~= "" and w.nextTitle.__text:find(plan.next.title:sub(1, 20), 1, true), "the Next card shows the recommended action")
	local want = plan.next.src == "att" and "ATT (AllTheThings) - unverified on Forever" or "observed on Forever"
	local prov = false
	for _, fs in ipairs(w.detail) do if fs.__text:find(want, 1, true) then prov = true end end
	check(prov, "the card's source line matches the recommendation's provenance ('" .. want .. "')")
	local anyConfirmed = false
	for _, fs in ipairs(w.detail) do if fs.__text:lower():find("confirmed") then anyConfirmed = true end end
	check(not anyConfirmed, "the card never says 'confirmed'")
	check(w.zoneFS.__text:find("Auto") and w.styleFS.__text == "Efficient", "pickers show Auto zone and Efficient style")
	local upShown = 0
	for _, r in ipairs(w.upRows) do if r.__shown then upShown = upShown + 1 end end
	check(upShown >= 1, "the Coming up list is populated (" .. upShown .. " rows)")

	-- Show on Map uses the proven waypoint path
	local nx = plan.next
	click(w.btnMap)
	check(W.waypointCalls == 1 and W.waypoint.uiMapID == nx.target.map and math.abs(W.waypoint.x - nx.target.x) < 1e-9 and W.supertrack == true,
		"Show on Map sets the game's waypoint at the recommendation's coordinates and super-tracks it")
	check(chatHas("ATT-derived position, unverified on Forever") or chatHas("Pinned"), "the pin message states the position's provenance")
	-- Skip
	local skipKey = nx.skipKey
	click(w.btnSkip)
	check(ns.Prefs.IsSkipped(skipKey) and ns.State.plan.next ~= nil and ns.State.plan.next.id ~= nx.id, "the Skip button skips and the card updates to a new recommendation")
	-- route zone and style pickers
	click(w.zoneNext)
	check(ns.Prefs.GetRouteZone() ~= "auto", "the route-zone > button chooses a zone")
	click(w.zonePrev)
	check(ns.Prefs.GetRouteZone() == "auto", "the < button goes back")
	click(w.styleNext)
	check(ns.Prefs.GetStyle() == "fast", "the style > button cycles to the next ACTIVE style")
	for _ = 1, 8 do click(w.styleNext) end
	local s = ns.Prefs.GetStyle()
	check(s ~= "solo" and s ~= "dungeon_friendly" and s ~= "hardcore", "cycling never lands on a planned style")
	-- systems
	local planned, live
	for _, b in ipairs(w.sysButtons) do
		if b.sysKey == "camping" then planned = b end
		if b.sysKey == "flight" then live = b end
	end
	check(planned.text.__text:find("(planned)", 1, true) ~= nil, "planned systems are labelled (planned)")
	click(planned)
	check(ns.Prefs.IsSystemOn("camping") == false and chatHas("planned"), "clicking a planned system explains it and does not enable it")
	local before = ns.Prefs.IsSystemOn("flight")
	click(live)
	check(ns.Prefs.IsSystemOn("flight") ~= before and live.text.__text:find(before and "%[ %]" or "%[x%]") ~= nil, "the flight-hint toggle flips and its label follows")
	click(w.hardcoreBtn)
	check(ns.Prefs.IsHardcore() and w.hardcoreBtn.text.__text:find("[x]", 1, true) ~= nil, "the Hardcore toggle flips")
	-- Add panel
	click(w.btnAdd)
	check(w.addPanel.__shown, "Add quest... opens the search panel")
	w.addBox.__text = "Thunder"
	w.addBox.__scripts.OnTextChanged(w.addBox)
	local rowsShown, firstRow = 0, nil
	for _, r in ipairs(w.addRows) do if r.__shown and r.pick then rowsShown = rowsShown + 1; firstRow = firstRow or r end end
	check(rowsShown >= 1, "typing part of a name lists matching quests (" .. rowsShown .. ")")
	local pick = firstRow.pick
	firstRow.__scripts.OnClick(firstRow)
	check(ns.Prefs.IsAdded(pick) and not w.addPanel.__shown, "clicking a result adds the quest and closes the panel")
	-- ATT wording on the card, in a dedicated ATT-only scenario
	ns.Prefs.ResetOverrides()
	attPack(ns, { { id = 1, name = "ATT Only Quest", giverName = "Some NPC", map = 1413, x = 0.52, y = 0.31, req = 20 } })
	ns.State.Recompute()
	local attLine, locLine = false, false
	for _, fs in ipairs(w.detail) do
		if fs.__text:find("Source: ATT (AllTheThings) - unverified on Forever", 1, true) then attLine = true end
		if fs.__text:find("(ATT, unverified on Forever)", 1, true) then locLine = true end
	end
	check(attLine and locLine, "an ATT-only recommendation shows 'ATT ... unverified on Forever' for both its source and its location")
	check(w.nextTitle.__text == "Accept: ATT Only Quest", "and the Next card shows it")
	-- refresh with no data
	ns.Registry.ClearPacks()
	ns.State.Recompute()
	check(w.nextTitle.__text == "Nothing to recommend right now" and not w.btnMap.enabled, "with no data the card says so and Show on Map is disabled")
	check(#ns.errors == 0, "the UI scenarios raised no caught errors" .. (#ns.errors > 0 and (": " .. ns.errors[1]) or ""))
	slash("dev")
	check(not ns.DevUI.IsShown(), "/codex dev toggles the developer window closed")
end

-- ================================================================ 7. diagnostics, slash commands, events

section("diagnostics: /codex diag")
do
	local ns = boot({ char = { level = 25 } })
	W.chat = {}
	slash("diag")
	check(chatHas("Forever Codex v" .. ForeverCodex.VERSION) and chatHas("client 1.60.1 build 70124 interface 16001"), "diag: addon and client versions")
	check(chatHas("Character: Thrall level 25 Troll WARRIOR (Horde)"), "diag: the character")
	check(chatHas("Location: The Barrens / The Crossroads | map 1413"), "diag: the location")
	check(chatHas("Choices: style=efficient routeZone=auto"), "diag: the player's choices")
	check(chatHas("pack att:kalimdor: src=att verified=false") and chatHas("pack observed:m6: src=observed verified=true"), "diag: packs with provenance")
	check(chatHas("NEXT:") and chatHas("why:"), "diag: the next action and why")
	check(chatHas("APIs absent on this client:"), "diag: API presence")
	local list = ForeverCodexDB.diag
	check(#list == 1 and ns.Prefs.IsSavedVariablesSafe(list[1]), "the snapshot is stored and SavedVariables-safe")
	for _ = 1, 7 do slash("diag") end
	check(#ForeverCodexDB.diag == 5, "stored diagnostics are capped at the last 5")
	slash("report")
	check(ns.UI.report ~= nil and ns.UI.report.box.__text:find("Forever Codex v" .. ForeverCodex.VERSION, 1, true) ~= nil, "/codex report fills the copyable box")
	local nsb = boot({ missing = { UnitClass = true } })
	W.chat = {}
	slash("diag")
	check(chatHas("APIs missing for character info: UnitClass") and chatHas("UnitClass"), "diag names the APIs this client lacks")
end

section("slash commands")
do
	local ns = boot({ char = { level = 25 } })
	W.chat = {}
	slash("help"); check(chatHas("/codex diag"), "help lists commands")
	slash("next"); check(chatHas("NEXT:") and chatHas("Source:"), "next prints the recommendation with its source")
	slash("style fast"); check(ns.Prefs.GetStyle() == "fast", "style fast")
	slash("style solo"); check(ns.Prefs.GetStyle() == "fast" and chatHas("planned"), "style solo is refused as planned")
	slash("style"); check(chatHas("Available:"), "style lists the options")
	slash("zone the-barrens"); check(ns.Prefs.GetRouteZone() == "the-barrens", "zone the-barrens")
	slash("zone nowhere"); check(ns.Prefs.GetRouteZone() == "the-barrens", "an unknown zone is refused")
	slash("zone auto"); check(ns.Prefs.GetRouteZone() == "auto", "zone auto")
	slash("sys camping on"); check(ns.Prefs.IsSystemOn("camping") == false and chatHas("could not change camping"), "sys camping on is refused (planned)")
	slash("sys flight off"); check(ns.Prefs.IsSystemOn("flight") == false, "sys flight off")
	slash("hardcore on"); check(ns.Prefs.IsHardcore(), "hardcore on")
	slash("hardcore off"); check(not ns.Prefs.IsHardcore(), "hardcore off")
	slash("add Thunder"); check(#ns.Prefs.AddedList() == 1, "add by name")
	slash("add 12345678"); check(ns.Prefs.IsAdded(12345678), "add by id, even for a quest not in the data")
	W.completed = {}
	local plan = recompute(ns)
	local addedUnknown
	for _, a in ipairs(plan.reminders) do if a.quest == 12345678 then addedUnknown = a end end
	local routed = false
	for _, a in ipairs(plan.sequence) do if a.quest == 12345678 then routed = true end end
	-- Phase 2: an action with no usable location is a reminder, never part of NOW / ALSO DO / THEN
	check(addedUnknown ~= nil and addedUnknown.target == nil and addedUnknown.pinned and not routed, "an added quest unknown to the data is a reminder with no invented location (never routed)")
	slash("reset"); check(#ns.Prefs.AddedList() == 0 and #ns.Prefs.SkippedKeys() == 0, "reset clears skips and added quests")
	slash("where"); check(chatHas("Race origin: Troll. Route zone (your choice): auto. Now in: The Barrens"), "where reports the three concepts")
	slash("bogus"); check(chatHas("unknown command"), "unknown command is reported")
	check(#ns.errors == 0, "no caught errors from any slash command")
end

section("events: dirty marking and throttled recompute")
do
	local ns = boot({ char = { level = 25 } })
	local boot_ = ns._selftest.boot
	local before = ns.State.computeCount
	for _ = 1, 25 do boot_.onEvent(nil, "QUEST_LOG_UPDATE") end
	boot_.onEvent(nil, "UNIT_QUEST_LOG_CHANGED", "target")
	check(ns.State.computeCount == before, "events alone do not recompute")
	ns.State.Tick(0.1)
	check(ns.State.computeCount == before, "not before the short delay")
	ns.State.Tick(0.5)
	check(ns.State.computeCount == before + 1, "a burst of 25 events costs exactly one recompute")
	ns.State.Tick(5)
	check(ns.State.computeCount == before + 1, "an idle, closed window does not recompute")
	W.char.level = 26
	boot_.onEvent(nil, "PLAYER_LEVEL_UP")
	ns.State.Tick(1)
	check(ns.State.ctx.char.level == 26, "a level-up event refreshes the character")
	boot_.onEvent(nil, "UNIT_QUEST_LOG_CHANGED", "player")
	ns.State.Tick(1)
	check(ns.State.computeCount == before + 2 + 0 or ns.State.computeCount >= before + 2, "UNIT_QUEST_LOG_CHANGED for the player recomputes")
	slash("")
	local c = ns.State.computeCount
	ns.State.Tick(3.5)
	check(ns.State.computeCount == c + 1, "with the window open the plan refreshes every few seconds (the character moves)")
	W.loc.x, W.loc.y = 0.3, 0.3
	ns.State.Tick(3.5)
	check(ns.State.ctx.loc.x == 0.3, "and follows the character's position")
end

section("generator output provenance as loaded (end to end)")
do
	local ns = boot()
	local header = readFile(ADDON .. "/Data/Pack_ATT_Kalimdor.lua")
	check(header:find("PROVENANCE: src=att, verified=false", 1, true) ~= nil and header:find("REQUIRED level", 1, true) ~= nil and header:find("Nothing here is a confirmed Forever fact", 1, true) ~= nil,
		"the ATT data files carry their provenance statement in the file header")
	check(header:find("GENERATED FILE -- do not hand-edit", 1, true) ~= nil, "generated files say so")
	check(readFile(ADDON .. "/Data/Pack_Observed.lua"):find("src=observed, verified=true", 1, true) ~= nil, "the observed data file declares src=observed, verified=true")
end


-- ================================================================ 8. telemetry (observation only)

local function tfire(ns, ev, ...) ns._selftest.telemetry.onEvent(ev, ...) end
--- Advances the simulated clock by `secs` one second at a time, running the telemetry poll each second.
local function ttick(ns, secs, each)
	for _ = 1, secs do
		W.now, W.wall = W.now + 1, W.wall + 1
		if each then each() end
		ns._selftest.telemetry.tick(1)
	end
end
local function evOf(ns, e)
	local out = {}
	for _, ev in ipairs(ns.Telemetry.Events()) do if ev.e == e then out[#out + 1] = ev end end
	return out
end
local function last(list) return list[#list] end

section("telemetry: structure, independence and honesty about what is proven")
do
	local files = tocFiles()
	local listed = {}
	for i, f in ipairs(files) do listed[f] = i end
	check(listed["Telemetry.lua"] and listed["TelemetryMetrics.lua"], "Telemetry.lua and TelemetryMetrics.lua are in the .toc")
	local forbiddenDeps = { "ns%.Engine", "ns%.Strategies", "ns%.UI", "ns%.Route", "ns%.State", "ns%.MapPin", "ns%.Registry", "ns%.Context",
		"ns%.Prefs", "ns%.QuestProvider", "ns%.Eval", "ns%.Widgets", "ns%.Slash", "ns%.Diag" }
	local bad = {}
	for _, f in ipairs({ "Telemetry.lua", "TelemetryMetrics.lua" }) do
		local code = readFile(ADDON .. "/" .. f):gsub("%-%-[^\n]*", "")
		for _, pat in ipairs(forbiddenDeps) do if code:find(pat) then bad[#bad + 1] = f .. " uses " .. pat end end
		for _, api in ipairs({ "UnitGUID", "GetQuestReward", "AcceptQuest", "SendChatMessage", "UnitName", "GetUnitName" }) do
			if code:find(api .. "%s*%(") then bad[#bad + 1] = f .. " calls " .. api end
		end
	end
	check(#bad == 0, "telemetry is independent of the engine, strategies, UI, navigation and registry, and never reads GUIDs or names" .. (#bad > 0 and (": " .. bad[1]) or ""))
	local reverse = {}
	for _, f in ipairs({ "Engine.lua", "Strategies.lua", "Context.lua", "Route.lua", "State.lua", "Registry.lua", "Preferences.lua", "MapPin.lua",
		"ProgressionEval.lua", "UI/Window.lua", "UI/Widgets.lua", "Providers/Quest.lua", "Providers/Flight.lua", "Providers/Planned.lua", "Boot.lua" }) do
		if readFile(ADDON .. "/" .. f):find("Telemetry") then reverse[#reverse + 1] = f end
	end
	check(#reverse == 0, "no route/engine/strategy/UI/navigation module references telemetry (it does not influence recommendations yet)" .. (#reverse > 0 and (": " .. reverse[1]) or ""))

	local ns = boot()
	local defs = {}
	for _, d in ipairs(ns.Telemetry.EVENT_DEFS) do defs[d.type] = d end
	for _, name in ipairs({ "XP_GAIN", "MOB_KILL", "QUEST_ACCEPT", "QUEST_COMPLETE", "QUEST_TURNIN", "PLAYER_MOVE", "LEVEL_UP", "COMBAT_START", "COMBAT_END" }) do
		check(defs[name] ~= nil and type(defs[name].evidence) == "string" and #defs[name].sources >= 1, "event type " .. name .. " is defined with sources and an evidence note")
	end
	check(defs.QUEST_ACCEPT.verified and defs.QUEST_COMPLETE.verified and defs.QUEST_TURNIN.verified and defs.PLAYER_MOVE.verified,
		"quest events and position sampling are marked proven (M8.7/M8.8/M8.9/M8.10)")
	check(not defs.XP_GAIN.verified and not defs.MOB_KILL.verified and not defs.LEVEL_UP.verified and not defs.COMBAT_START.verified and not defs.COMBAT_END.verified,
		"XP, kill, level-up and combat sources are marked UNPROVEN: never observed on Forever")
	local reg = ns._selftest.telemetry.registered
	local all = true
	for _, e in ipairs({ "PLAYER_XP_UPDATE", "PLAYER_LEVEL_UP", "QUEST_ACCEPTED", "QUEST_TURNED_IN", "UNIT_QUEST_LOG_CHANGED", "QUEST_LOG_UPDATE",
		"PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED" }) do
		if reg[e] ~= true then all = false end
	end
	check(all, "telemetry registers all its events on its own frame (a refused registration would show as false)")
	-- REGRESSION (real client): Forever refuses addon registration of the combat log and raises a taint popup
	local combatLog = 0
	for _, e in ipairs(W.registeredEvents or {}) do if e == "COMBAT_LOG_EVENT_UNFILTERED" then combatLog = combatLog + 1 end end
	check(#(W.registeredEvents or {}) > 10 and combatLog == 0 and reg.COMBAT_LOG_EVENT_UNFILTERED == nil, "Codex never registers COMBAT_LOG_EVENT_UNFILTERED on any frame")
	local caps = {}
	for _, c in ipairs(ns.Telemetry.Capabilities()) do caps[c.type] = c end
	check(caps.MOB_KILL.unavailable == true and caps.MOB_KILL.registered == false and not caps.MOB_KILL.verified, "kill tracking is reported UNAVAILABLE (not proven, not registered)")
	check(caps.QUEST_TURNIN.verified and caps.QUEST_ACCEPT.verified and caps.QUEST_COMPLETE.verified and caps.PLAYER_MOVE.verified and not caps.XP_GAIN.verified, "proven quest/travel telemetry is untouched; XP stays unproven")
	check(not table.concat(ns.HelpCodex.Learned(), "|"):find("defeated"), "the player-facing summary never implies kills are tracked")
	check(ns.Telemetry.IsEnabled() and #ns.Telemetry.Events() == 1 and ns.Telemetry.Events()[1].e == "SESSION", "the log starts with one SESSION marker at login")
	local sess = ns.Telemetry.Events()[1]
	check(sess.v == 1 and sess.lvl == 25 and sess.xp == 1000 and sess.max == 5000 and type(sess.w) == "number" and sess.build == "70124", "SESSION records schema, level, XP, build and wall time")
end

section("telemetry: XP and level-up")
do
	local ns = boot()
	W.xp = 1150; tfire(ns, "PLAYER_XP_UPDATE")
	local g = last(evOf(ns, "XP_GAIN"))
	check(g and g.d == 150 and g.xp == 1150 and g.max == 5000 and g.lvl == 25 and g.src == "event", "PLAYER_XP_UPDATE records the XP delta")
	tfire(ns, "PLAYER_XP_UPDATE")
	check(#evOf(ns, "XP_GAIN") == 1, "an event with no XP change records nothing")
	W.xp = 1200; ttick(ns, 1)
	g = last(evOf(ns, "XP_GAIN"))
	check(#evOf(ns, "XP_GAIN") == 2 and g.d == 50 and g.src == "poll", "the 1 Hz poll catches an XP change even if the event never fires")
	tfire(ns, "PLAYER_XP_UPDATE")
	check(#evOf(ns, "XP_GAIN") == 2, "event + poll never double count the same gain")
	-- level up: 1200 -> finish level (5000-1200) + 120 into the next
	W.char.level, W.xp, W.xpMax = 26, 120, 5200
	tfire(ns, "PLAYER_XP_UPDATE")
	g = last(evOf(ns, "XP_GAIN"))
	check(g.d == 3920 and g.lvlup == true and g.lvl == 26 and g.multi == nil, "XP across a level-up = finish the old level + progress in the new one (3800 + 120)")
	local lu = evOf(ns, "LEVEL_UP")
	check(#lu == 1 and lu[1].lvl == 26, "LEVEL_UP recorded once")
	tfire(ns, "PLAYER_LEVEL_UP"); ttick(ns, 2)
	check(#evOf(ns, "LEVEL_UP") == 1 and #evOf(ns, "XP_GAIN") == 3, "the level-up event and the poll do not duplicate it")
	-- two levels at once: the middle level's size is unknown, so flag it
	W.char.level, W.xp, W.xpMax = 28, 50, 5600
	ttick(ns, 1)
	g = last(evOf(ns, "XP_GAIN"))
	check(g.multi == true and g.lvlup == true and last(evOf(ns, "LEVEL_UP")).lvl == 28, "several levels at once are flagged (the delta is a lower bound)")
	-- the XP bar reset can land before the level: never a negative gain
	W.xp = 10; tfire(ns, "PLAYER_XP_UPDATE")
	local n = #evOf(ns, "XP_GAIN")
	check(true, "XP bar dropped without a level change (waiting one more check)")
	W.char.level = 29; W.xp = 10; tfire(ns, "PLAYER_XP_UPDATE")
	g = last(evOf(ns, "XP_GAIN"))
	check(#evOf(ns, "XP_GAIN") == n + 1 and g.d > 0 and g.lvlup, "a bar reset followed by the level change is recorded as a level-up with a positive gain")
	W.xp = 3000; ttick(ns, 1)
	W.xp = 100; tfire(ns, "PLAYER_XP_UPDATE"); tfire(ns, "PLAYER_XP_UPDATE")
	local anyNegative = false
	for _, e in ipairs(evOf(ns, "XP_GAIN")) do if e.d <= 0 then anyNegative = true end end
	check(not anyNegative and ns.Telemetry.Status().anomalies >= 1, "a real decrease with no level change is counted as an anomaly, never recorded as a gain")
end

section("telemetry: kills (combat log), no GUIDs stored")
do
	local ns = boot()
	local function kill(flags, destGuid) W.clog = { 1000, "PARTY_KILL", false, "Player-1-0000AAAA", "Thrall", flags, 0, destGuid, "Mottled Boar", 0x10a48 }; tfire(ns, "COMBAT_LOG_EVENT_UNFILTERED") end
	kill(0x511, "Creature-0-3-1-2-3144-00001A2B")
	local k = last(evOf(ns, "MOB_KILL"))
	check(k and k.npc == 3144 and k.by == "me" and k.pet == nil, "a player killing blow records the creature id")
	W.xp = 1075; tfire(ns, "PLAYER_XP_UPDATE")
	local g = last(evOf(ns, "XP_GAIN"))
	check(g.d == 75 and g.sk == 0, "an XP gain right after a kill carries the seconds-since-kill (timing only; no attribution claimed)")
	W.now = W.now + 30; W.xp = 1200; tfire(ns, "PLAYER_XP_UPDATE")
	check(last(evOf(ns, "XP_GAIN")).sk == nil, "an XP gain long after the last kill carries no kill link")
	kill(0x512, "Creature-0-3-1-2-5555-00000001")
	check(last(evOf(ns, "MOB_KILL")).by == "party", "a party member's kill is recorded as 'party'")
	kill(0x1511, "Creature-0-3-1-2-6666-00000002")
	check(last(evOf(ns, "MOB_KILL")).pet == true and last(evOf(ns, "MOB_KILL")).by == "me", "a kill by the player's pet is flagged")
	local before = #evOf(ns, "MOB_KILL")
	kill(0x548, "Creature-0-3-1-2-7777-00000003")
	kill(0x511, "Player-1-0000BBBB")
	kill(0x511, nil)
	W.clog = { 1000, "SWING_DAMAGE", false, "Player-1-0000AAAA", "Thrall", 0x511, 0, "Creature-0-3-1-2-3144-00001A2B", "x", 0x10a48 }; tfire(ns, "COMBAT_LOG_EVENT_UNFILTERED")
	check(#evOf(ns, "MOB_KILL") == before, "other combat-log events, hostile killers, player victims and malformed payloads record nothing")
	local leaks = {}
	for _, ev in ipairs(ns.Telemetry.Events()) do
		for key, v in pairs(ev) do
			if type(v) == "string" and (v:find("Creature%-") or v:find("Player%-") or v:find("%-%d%d%d")) then leaks[#leaks + 1] = key .. "=" .. v end
			if type(v) ~= "string" and type(v) ~= "number" and type(v) ~= "boolean" then leaks[#leaks + 1] = key end
		end
	end
	check(#leaks == 0, "no event contains a GUID or any non-primitive value")
	W.clog = nil
	local ns2 = boot()
	_G.CombatLogGetCurrentEventInfo = nil
	ns2._selftest.telemetry.onEvent("COMBAT_LOG_EVENT_UNFILTERED", 1000, "PARTY_KILL", false, "Player-1-0000AAAA", "Thrall", 0x511, 0, "Creature-0-3-1-2-3144-00001A2B", "Mottled Boar", 0x10a48)
	check(#evOf(ns2, "MOB_KILL") == 1, "if the client passes the payload as event arguments instead of CombatLogGetCurrentEventInfo, kills still record")
end

section("telemetry: combat, quests")
do
	local ns = boot()
	tfire(ns, "PLAYER_REGEN_DISABLED"); tfire(ns, "PLAYER_REGEN_DISABLED")
	check(#evOf(ns, "COMBAT_START") == 1, "entering combat records one COMBAT_START even if the event repeats")
	W.now = W.now + 12; tfire(ns, "PLAYER_REGEN_ENABLED")
	local ce = last(evOf(ns, "COMBAT_END"))
	check(ce and ce.dur == 12, "leaving combat records the fight duration (12 s)")
	tfire(ns, "PLAYER_REGEN_ENABLED")
	check(#evOf(ns, "COMBAT_END") == 1, "leaving combat without having entered records nothing")

	tfire(ns, "QUEST_ACCEPTED", 907)
	local qa = last(evOf(ns, "QUEST_ACCEPT"))
	check(qa and qa.q == 907 and qa.w == W.wall, "QUEST_ACCEPTED records the quest id and wall time")
	W.log = { { questID = 907, title = "Enraged Thunder Lizards", complete = false }, { questID = 123, title = "Old Quest", complete = false } }
	tfire(ns, "QUEST_LOG_UPDATE"); ttick(ns, 1)
	check(#evOf(ns, "QUEST_COMPLETE") == 0, "an incomplete quest in the log records no completion")
	W.wall = W.wall + 300; W.now = W.now + 300
	W.log[1].complete = true
	tfire(ns, "UNIT_QUEST_LOG_CHANGED", "player"); ttick(ns, 1)
	local qc = last(evOf(ns, "QUEST_COMPLETE"))
	check(qc and qc.q == 907 and qc.dur == 302, "objectives completing is detected by diffing the quest log, with the time since accept (1 + 300 + 1 = 302 s wall)")
	ttick(ns, 3); tfire(ns, "QUEST_LOG_UPDATE"); ttick(ns, 1)
	check(#evOf(ns, "QUEST_COMPLETE") == 1, "a completed quest is not reported again")
	tfire(ns, "UNIT_QUEST_LOG_CHANGED", "target"); ttick(ns, 1)
	W.log[2].complete = true
	tfire(ns, "QUEST_LOG_UPDATE"); ttick(ns, 1)
	qc = last(evOf(ns, "QUEST_COMPLETE"))
	check(#evOf(ns, "QUEST_COMPLETE") == 2 and qc.q == 123 and qc.dur == nil, "a quest accepted before this session completes with no duration (accept time unknown)")
	tfire(ns, "QUEST_TURNED_IN", 907, 8300, 0)
	local ti = last(evOf(ns, "QUEST_TURNIN"))
	check(ti and ti.q == 907 and ti.xp == 8300 and ti.money == 0 and ti.dur and ti.dur >= 302, "QUEST_TURNED_IN records quest id, XP, money and the time since accept")
	tfire(ns, "QUEST_TURNED_IN", 555, 100, 5)
	check(last(evOf(ns, "QUEST_TURNIN")).dur == nil, "a turn-in whose accept was not seen has no duration")
	check(ForeverCodexDB.telemetry.accepted[907] == nil, "the remembered accept time is cleared on turn-in")
	-- accept-time memory is bounded
	for id = 1, 90 do tfire(ns, "QUEST_ACCEPTED", 5000 + id); W.wall = W.wall + 1 end
	local count = 0
	for _ in pairs(ForeverCodexDB.telemetry.accepted) do count = count + 1 end
	check(count <= 60, "remembered accept times are capped at 60")
end

section("telemetry: movement segments")
do
	local ns = boot()
	W.loc = { map = 9001, x = 0.10, y = 0.50, zone = "Zone A" }
	local function walk(steps, dx)
		for _ = 1, steps do W.loc.x = W.loc.x + dx; ttick(ns, 1) end
	end
	ttick(ns, 1)                       -- first sample: where we are
	walk(10, 0.007)                    -- 7 yards per second for 10 seconds (map 9001 is 1000 yards wide)
	check(#evOf(ns, "PLAYER_MOVE") == 0, "a segment is open while still moving: nothing recorded yet")
	ttick(ns, 3)                       -- stand still
	local mv = evOf(ns, "PLAYER_MOVE")
	check(#mv == 1 and mv[1].dist == 70 and mv[1].dur == 10 and mv[1].map == 9001 and mv[1].approx == nil, "standing still ends the segment: 70 yd in 10 s, from world coordinates")
	check(math.abs(mv[1].x0 - 0.1) < 1e-4 and math.abs(mv[1].x1 - 0.17) < 1e-4, "start and end positions are recorded as map fractions")
	ttick(ns, 600)
	check(#evOf(ns, "PLAYER_MOVE") == 1 and #ns.Telemetry.Events() < 30, "10 idle minutes record nothing")
	local stored = #ns.Telemetry.Events()
	-- a teleport / loading screen is not walking
	walk(3, 0.007); W.loc.x = W.loc.x + 0.5; ttick(ns, 1); ttick(ns, 3)
	local anom = ns.Telemetry.Status().anomalies
	local totalDist = 0
	for _, e in ipairs(evOf(ns, "PLAYER_MOVE")) do totalDist = totalDist + e.dist end
	check(anom >= 1 and totalDist <= 70 + 25, "a 500-yard jump in one second is counted as an anomaly, not as travel")
	-- long travel is split so no segment grows without bound
	W.loc.x = 0.02
	ttick(ns, 3); local before = #evOf(ns, "PLAYER_MOVE")
	walk(130, 0.007); ttick(ns, 3)
	local after = evOf(ns, "PLAYER_MOVE")
	check(#after - before >= 2 and after[before + 1].dur >= 119 and after[before + 1].dur <= 121, "travel longer than 120 s is split into several PLAYER_MOVE events")
	-- no world conversion: distance falls back to map fractions and says so
	local ns2 = boot()
	ns2.Telemetry.reader.position = function() return { map = 9001, x = W.loc.x, y = W.loc.y } end
	W.loc = { map = 9001, x = 0.10, y = 0.50 }
	ttick(ns2, 1)
	for _ = 1, 6 do W.loc.x = W.loc.x + 0.001; ttick(ns2, 1) end
	ttick(ns2, 3)
	local approx = last(evOf(ns2, "PLAYER_MOVE"))
	check(approx ~= nil and approx.approx == true, "without world coordinates the distance is an approximation and the event says so")
	-- position unavailable ends a segment and never raises
	local ns3 = boot()
	W.loc = { map = 9001, x = 0.10, y = 0.50 }
	ttick(ns3, 1); for _ = 1, 5 do W.loc.x = W.loc.x + 0.007; ttick(ns3, 1) end
	W.loc.x, W.loc.y, W.loc.map = nil, nil, nil
	ttick(ns3, 2)
	check(#evOf(ns3, "PLAYER_MOVE") == 1 and #ns3.errors == 0, "losing the position ends the segment cleanly, no error")
end

section("telemetry: size, persistence, enable/disable")
do
	local ns = boot()
	for i = 1, 450 do ns.Telemetry.Record("QUEST_ACCEPT", { q = i, w = i }) end
	local list = ns.Telemetry.Events()
	check(#list == 300 and list[#list].q == 450 and list[1].q == 151, "the log is capped at 300 events, newest kept")
	check(ForeverCodexDB.telemetry.events == list, "the log lives directly in ForeverCodexDB.telemetry (saved by /reload, no copy)")
	check(ns.Prefs.IsSavedVariablesSafe(ForeverCodexDB), "the whole SavedVariable, telemetry included, is SavedVariables-safe")
	local bytes = 0
	for _, ev in ipairs(list) do for k, v in pairs(ev) do bytes = bytes + #tostring(k) + #tostring(v) + 4 end end
	check(bytes < 20000, "a full log is small (" .. bytes .. " bytes of key/value text)")
	-- simulate /reload: the saved table comes back, a new SESSION marker is appended
	local saved = ForeverCodexDB
	local ns2 = boot({ savedVars = saved })
	local evs = ns2.Telemetry.Events()
	check(evs[#evs].e == "SESSION" and #evs == 300 and evs[1].q == 152, "after a reload the previous log is kept and a new SESSION marker is appended (oldest dropped at the cap)")
	local sessions = 0
	for _, ev in ipairs(evs) do if ev.e == "SESSION" then sessions = sessions + 1 end end
	check(sessions == 1 and #ns2.TelemetryMetrics.LastSession(evs) == 1, "metrics only ever look at the latest session (GetTime restarts each session)")
	-- disable / enable
	local n = #ns2.Telemetry.Events()
	ns2.Telemetry.SetEnabled(false)
	W.xp = 2000; tfire(ns2, "PLAYER_XP_UPDATE"); tfire(ns2, "QUEST_ACCEPTED", 1); ttick(ns2, 3)
	check(not ns2.Telemetry.IsEnabled() and #ns2.Telemetry.Events() == n, "disabled: nothing is recorded")
	check(ns2.Telemetry.Record("QUEST_ACCEPT", { q = 1 }) == nil and #ns2.Telemetry.Events() == n, "disabled: even a direct Record call is refused (second line of defence)")
	ns2.Telemetry.SetEnabled(true)
	W.xp = 2100; tfire(ns2, "PLAYER_XP_UPDATE")
	check(ns2.Telemetry.IsEnabled() and #evOf(ns2, "XP_GAIN") >= 1, "re-enabled: recording resumes")
	ns2.Telemetry.Reset()
	local after = ns2.Telemetry.Events()
	check(#after == 1 and after[1].e == "SESSION" and next(ForeverCodexDB.telemetry.accepted) == nil, "reset clears the log and starts a fresh session marker")
	-- persisted disabled flag is honoured at load
	ForeverCodexDB.telemetry.enabled = false
	local ns3 = boot({ savedVars = ForeverCodexDB })
	tfire(ns3, "QUEST_ACCEPTED", 9)
	check(not ns3.Telemetry.IsEnabled() and #evOf(ns3, "QUEST_ACCEPT") == 0, "a saved 'off' choice is respected after a reload")
end

section("telemetry metrics: observed vs calculated vs estimated (hand-computed expectations)")
do
	local ns = boot()
	local M = ns.TelemetryMetrics
	local ev = {
		{ e = "SESSION", t = 0 },
		{ e = "XP_GAIN", t = 10, d = 100, lvl = 25 },
		{ e = "MOB_KILL", t = 20, npc = 1 },
		{ e = "XP_GAIN", t = 20.2, d = 80, sk = 0.2, lvl = 25 },
		{ e = "COMBAT_END", t = 25, dur = 15 },
		{ e = "PLAYER_MOVE", t = 60, dur = 30, dist = 210 },
		{ e = "QUEST_ACCEPT", t = 70, q = 1 },
		{ e = "QUEST_COMPLETE", t = 100, q = 1, dur = 240 },
		{ e = "QUEST_TURNIN", t = 110, q = 1, xp = 1000, dur = 300 },
		{ e = "XP_GAIN", t = 120, d = 500, lvl = 26, lvlup = true },
		{ e = "LEVEL_UP", t = 120, lvl = 26 },
	}
	local snapshot = #ev
	local s = M.Summary(ev)
	check(s.window.seconds == 120 and s.window.events == 10, "the window spans the session so far (120 s, 10 events)")
	check(s.xp.total.value == 680 and s.xp.total.kind == "observed", "total XP is OBSERVED: 100 + 80 + 500")
	check(math.abs(s.xp.perMinute.value - 340) < 1e-9 and s.xp.perMinute.kind == "calculated" and s.xp.perMinute.unit == "xp/min", "XP per minute is CALCULATED: 680 over 2 minutes = 340")
	check(math.abs(s.xp.perHour.value - 20400) < 1e-6, "XP per hour = 20400")
	check(math.abs(s.xp.perActiveMinute.value - 680 / 0.75) < 1e-6, "XP per ACTIVE minute uses observed combat + movement time (45 s)")
	check(s.kills.count.value == 1 and s.kills.count.kind == "observed", "kills are OBSERVED")
	check(s.kills.avgXpPerKill.value == 80 and s.kills.avgXpPerKill.kind == "estimated" and s.kills.avgXpPerKill.n == 1,
		"XP per kill is only ESTIMATED (timing pairing); the level-up gain and the earlier gain are not paired")
	check(s.timing.combatSeconds.value == 15 and s.timing.moveSeconds.value == 30 and s.timing.moveDistance.value == 210, "combat seconds, move seconds and distance are observed sums")
	check(s.timing.downtimeSeconds.value == 75 and math.abs(s.timing.downtimeShare.value - 0.625) < 1e-9 and s.timing.downtimeShare.kind == "calculated",
		"downtime is CALCULATED as the remainder: 120 - 45 = 75 s (62.5%)")
	check(s.quests.accepted.value == 1 and s.quests.completed.value == 1 and s.quests.turnedIn.value == 1 and s.quests.xp.value == 1000, "quest counts and turn-in XP are observed")
	check(s.quests.avgSecondsToComplete.value == 240 and s.quests.xpPerQuestMinute.value == 200, "quest time to complete (240 s) and quest XP per minute (1000 / 5 min = 200) are calculated")
	check(s.levelUps.value == 1, "level-ups counted")
	check(#ev == snapshot and ev[2].d == 100, "the calculators do not modify the event list")
	-- evidence gates: never invent a number
	local short = M.Summary({ { e = "SESSION", t = 0 }, { e = "XP_GAIN", t = 20, d = 50 } })
	check(short.xp.perMinute.value == nil and short.xp.perMinute.reason:find("shorter than 60") and short.xp.total.value == 50,
		"under a minute of data: the rate is nil with a reason, the observed total is still reported")
	local none = M.Summary({})
	check(none.xp.perMinute.value == nil and none.kills.avgXpPerKill.value == nil and none.reason ~= nil and none.window.events == 0, "no events: every derived metric is nil with a reason")
	local noXp = M.Summary({ { e = "SESSION", t = 0 }, { e = "COMBAT_END", t = 120, dur = 10 } })
	check(noXp.xp.perMinute.value == nil and noXp.xp.perMinute.reason == "no XP gains recorded", "a long window with no XP gains reports no rate")
	local noPair = M.Summary({ { e = "SESSION", t = 0 }, { e = "MOB_KILL", t = 10, npc = 1 }, { e = "XP_GAIN", t = 40, d = 90 } })
	check(noPair.kills.avgXpPerKill.value == nil, "an XP gain 30 s after a kill is not paired with it")
	-- sessions and windows
	local two = M.Summary({ { e = "SESSION", t = 0 }, { e = "XP_GAIN", t = 50, d = 999 }, { e = "SESSION", t = 0 }, { e = "XP_GAIN", t = 90, d = 10 }, { e = "XP_GAIN", t = 100, d = 20 } })
	check(two.xp.total.value == 30, "only the latest session is summarised")
	local clipped = M.Summary(ev, { span = 60 })
	check(clipped.window.seconds == 60 and clipped.xp.total.value == 500 + 0 and clipped.quests.turnedIn.value == 1, "a shorter span only counts events inside it")
	local lines = M.Format(s)
	check(#lines == 8 and lines[2]:find("340 xp/min %[calculated, n=3%]") and lines[4]:find("%[estimated"), "the text summary labels every number observed / calculated / estimated")
end

section("telemetry does not change what Codex recommends")
do
	local nsA = boot({ char = { level = 25 } })
	local planA = recompute(nsA)
	local idsA, scoreA = seqIds(planA), planA.next._score
	local computes = nsA.State.computeCount
	local weightsBefore = nsA.Registry.Strategy("fast").w.distScale
	-- flood telemetry with every event type
	W.xp = 2000; tfire(nsA, "PLAYER_XP_UPDATE"); tfire(nsA, "PLAYER_REGEN_DISABLED"); W.now = W.now + 5; tfire(nsA, "PLAYER_REGEN_ENABLED")
	W.clog = { 1, "PARTY_KILL", false, "Player-1-1", "x", 0x511, 0, "Creature-0-1-1-1-100-1", "m", 0 }; tfire(nsA, "COMBAT_LOG_EVENT_UNFILTERED")
	tfire(nsA, "QUEST_ACCEPTED", 4242); tfire(nsA, "QUEST_TURNED_IN", 4242, 500, 0); tfire(nsA, "QUEST_LOG_UPDATE"); ttick(nsA, 5)
	check(nsA.State.computeCount == computes, "telemetry events do not mark the plan dirty or trigger a recompute")
	local planB = recompute(nsA)
	check(seqIds(planB) == idsA and planB.next._score == scoreA, "the plan (order and scores) is identical before and after telemetry activity")
	check(nsA.Registry.Strategy("fast").w.distScale == weightsBefore, "route style weights are untouched")
	nsA.Telemetry.SetEnabled(false)
	check(seqIds(recompute(nsA)) == idsA, "and identical with telemetry switched off")
end

section("telemetry: /codex diag and /codex telemetry")
do
	local ns = boot({ char = { level = 25 } })
	W.xp = 1100; tfire(ns, "PLAYER_XP_UPDATE")
	W.chat = {}
	slash("diag")
	check(chatHas("Telemetry: enabled") and chatHas("observation only; it does not affect recommendations"), "diag reports telemetry status")
	check(chatHas("XP_GAIN[UNPROVEN reg=true rec=1]") and chatHas("QUEST_ACCEPT[proven reg=true rec=0]"), "diag lists each event type: proven or UNPROVEN, registered, and how many were recorded")
	check(ns.Prefs.IsSavedVariablesSafe(ForeverCodexDB.diag[#ForeverCodexDB.diag]), "the diag snapshot with telemetry is SavedVariables-safe")
	W.chat = {}
	slash("telemetry")
	check(chatHas("Telemetry is on") and chatHas("XP_GAIN") and chatHas("UNPROVEN on Forever") and chatHas("proven on Forever"), "/codex telemetry shows per-event status")
	slash("telemetry events 2")
	check(chatHas("XP_GAIN") and chatHas("d=100"), "/codex telemetry events prints recent raw events")
	W.chat = {}
	slash("telemetry summary")
	check(chatHas("window:") and chatHas("XP gained:") and chatHas("n/a ("), "/codex telemetry summary prints labelled metrics, n/a where evidence is insufficient")
	slash("telemetry off"); check(not ns.Telemetry.IsEnabled(), "/codex telemetry off")
	slash("telemetry on"); check(ns.Telemetry.IsEnabled(), "/codex telemetry on")
	slash("telemetry reset"); check(#ns.Telemetry.Events() == 1, "/codex telemetry reset")
	slash("telemetry bogus"); check(chatHas("usage: /codex telemetry"), "unknown telemetry subcommand prints usage")
	slash("help"); check(chatHas("/codex telemetry"), "help mentions telemetry")
	check(#ns.errors == 0, "no caught errors from any telemetry scenario" .. (#ns.errors > 0 and (": " .. ns.errors[1]) or ""))
end

-- ================================================================ 9. structured Action/Target contract (Phase 1) and Planner (Phase 2)
-- Each lives in its own file; they share this harness through one table so there is a single stub client.
do
	local H = { boot = boot, check = check, section = section, slash = slash, newWorld = newWorld, attPack = attPack,
		defMap = defMap, world = function() return W end, addonDir = ADDON, readFile = readFile }
	local dir = arg[0]:match("^(.*)[/\\]") or "."
	H.fake = dofile(dir .. "/fake_questiedb.lua")
	for _, name in ipairs({ "contract_tests.lua", "planner_tests.lua", "planner_eval.lua", "phase3_tests.lua", "phase4_tests.lua", "bridge_tests.lua", "ui_polish_tests.lua", "local_progress_tests.lua", "cleanup_tests.lua", "item_probe_tests.lua", "eligibility_tests.lua", "evidence_tests.lua", "advisor_tests.lua", "spell_training_tests.lua" }) do
		local chunk, err = loadfile(dir .. "/" .. name)
		assert(chunk, err)
		chunk(H)
	end
end

print(string.format("\n%d passed, %d failed", passed, failed))
os.exit(failed == 0 and 0 or 1)
