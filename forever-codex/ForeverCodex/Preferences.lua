-- ForeverCodex.Preferences: the one SavedVariable, ForeverCodexDB.
--
--   ForeverCodexDB = {
--     version = 1,
--     ui      = { ... window position, welcome flag ... },
--     chars   = { ["Name-Realm"] = { routeZone, style, hardcore, hereRadius, systems{}, skipped{}, added{} } },
--     diag    = { ...last few /codex diag snapshots... },
--   }
--
-- Route choices are PER CHARACTER (a Troll Warrior and a Gnome Mage on one account want different routes). Race
-- origin (what the character IS), route zone (where the player CHOSE to level) and current location (where the
-- character IS NOW) are three separate concepts: only the route zone lives here, the other two are read live.
--
-- Persistence caveat (docs/M8_0_SCOPE.md): /reload saves are reliable on Forever; logout/character-select saves
-- have been observed to fail intermittently, root cause unknown. Codex stores only choices, never data, and can
-- rebuild everything else, so a lost save costs the player their skips/toggles, nothing more.
--
-- SavedVariables are restored AFTER the addon's files run and BEFORE ADDON_LOADED (M8.12), so ApplyDefaults() is
-- called from ADDON_LOADED (and again at PLAYER_LOGIN once the character key is known). Defaults are per key and
-- never overwrite a saved value.

local addonName, ns = ...
local R = ns.Registry

local P = {}
ns.Prefs = P

local DB_VERSION = 1
local charKey = "unknown"

local function root()
	if type(ForeverCodexDB) ~= "table" then
		ForeverCodexDB = {}
	end
	local db = ForeverCodexDB
	db.version = db.version or DB_VERSION
	db.ui = type(db.ui) == "table" and db.ui or {}
	db.chars = type(db.chars) == "table" and db.chars or {}
	db.diag = type(db.diag) == "table" and db.diag or {}
	return db
end

local function ensureChar(key)
	local db = root()
	local c = db.chars[key]
	if type(c) ~= "table" then
		c = {}
		db.chars[key] = c
	end
	if c.routeZone == nil then c.routeZone = "auto" end
	if c.style == nil then c.style = "efficient" end
	if c.hardcore == nil then c.hardcore = false end
	if c.hereRadius == nil then c.hereRadius = 200 end
	c.systems = type(c.systems) == "table" and c.systems or {}
	for _, s in ipairs(R.Systems()) do
		if c.systems[s.key] == nil then c.systems[s.key] = s.default == true end
	end
	c.skipped = type(c.skipped) == "table" and c.skipped or {}
	c.added = type(c.added) == "table" and c.added or {}
	-- Phase 3 (player-facing build): setup, notifications, navigation, history. All additive; nothing above changes.
	if c.setupDone == nil then c.setupDone = false end
	if c.partyNotify == nil then c.partyNotify = "ui" end
	if c.navigation == nil then c.navigation = true end
	if c.markers == nil then c.markers = false end          -- stays off until the marker probe has succeeded on this client
	c.journey = type(c.journey) == "table" and c.journey or {}
	c.journey.entries = type(c.journey.entries) == "table" and c.journey.entries or {}
	return c
end

function P.ApplyDefaults()
	root()
	ensureChar(charKey)
end

--- Sets which character's choices are active (called at PLAYER_LOGIN).
function P.SetCharKey(key)
	charKey = type(key) == "string" and key ~= "" and key or "unknown"
	P.ApplyDefaults()
end

function P.CharKey() return charKey end
function P.Root() return root() end
function P.Char() return ensureChar(charKey) end
function P.UI() return root().ui end

-- ---------------------------------------------------------------- setup, notifications, navigation, window (Phase 3)

function P.SetupDone() return P.Char().setupDone == true end
function P.FinishSetup() P.Char().setupDone = true end
function P.ReopenSetup() P.Char().setupDone = false end

P.PARTY_MODES = { "off", "ui", "party", "both" }
function P.PartyNotify() return P.Char().partyNotify end
function P.SetPartyNotify(mode)
	for _, m in ipairs(P.PARTY_MODES) do
		if m == mode then P.Char().partyNotify = mode return true end
	end
	return false
end

function P.NavigationOn() return P.Char().navigation == true end
function P.SetNavigation(on) P.Char().navigation = on == true end
function P.ArrowOn() return P.Char().arrow ~= false end
function P.SetArrow(on) P.Char().arrow = on == true end
function P.ArrowFlip() return root().ui.arrowFlip == true end
function P.SetArrowFlip(on) root().ui.arrowFlip = on == true end
function P.PinsOn() return P.Char().pins ~= false end
function P.SetPins(on) P.Char().pins = on == true end
function P.MarkersOn() return P.Char().markers == true end
function P.SetMarkers(on) P.Char().markers = on == true end

--- The player window's saved anchor: { point, relPoint, x, y } or nil.
function P.WindowPos() return root().ui.window end
function P.SetWindowPos(t) root().ui.window = t end

--- The waypoint Codex last placed for this character: { action, map, x, y } or nil (see Navigation).
function P.NavRecord() return P.Char().nav end
function P.SetNavRecord(t) P.Char().nav = t end

-- ---------------------------------------------------------------- route style / zone / systems

function P.GetStyle() return P.Char().style end

function P.SetStyle(key)
	local s = R.Strategy(key)
	if not s then return false, "unknown route style" end
	if s.active == false then return false, "that route style is planned, not available yet" end
	P.Char().style = key
	return true
end

function P.GetRouteZone() return P.Char().routeZone end

function P.SetRouteZone(key)
	if key ~= "auto" and not R.ZoneByKey(key) then
		return false, "no data for that zone"
	end
	P.Char().routeZone = key
	return true
end

function P.IsSystemOn(key) return P.Char().systems[key] == true end

function P.SetSystem(key, on)
	local s = R.System(key)
	if not s then return false, "unknown system" end
	if s.planned then return false, "planned: no reliable data for this system yet" end
	P.Char().systems[key] = on == true
	return true
end

function P.ToggleSystem(key)
	return P.SetSystem(key, not P.IsSystemOn(key))
end

function P.IsHardcore() return P.Char().hardcore == true end
function P.SetHardcore(on) P.Char().hardcore = on == true end

function P.HereRadius() return P.Char().hereRadius end

-- ---------------------------------------------------------------- player overrides: skip / add

--- Skip keys are strings such as "Q:907" (a quest) or "FP:25" (a flight node).
function P.Skip(key)
	if type(key) ~= "string" then return false end
	P.Char().skipped[key] = true
	return true
end

function P.Unskip(key) P.Char().skipped[key] = nil end
function P.IsSkipped(key) return P.Char().skipped[key] == true end

--- The player's veto on a quest across BOTH legacy keys ("Q:<id>" and "QT:<id>"), as { logical, keys }. Read-only: it
-- changes nothing, and the engine/provider still honour each key separately (migration to one key is a later phase).
function P.QuestSkipState(questId) return ns.Contract.SkipState(P.Char().skipped, questId) end
function P.ClearSkips() P.Char().skipped = {} end

function P.SkippedKeys()
	local out = {}
	for k in pairs(P.Char().skipped) do out[#out + 1] = k end
	table.sort(out)
	return out
end

function P.Add(questId)
	if type(questId) ~= "number" then return false end
	P.Char().added[questId] = true
	P.Char().skipped["Q:" .. questId] = nil
	return true
end

function P.RemoveAdded(questId) P.Char().added[questId] = nil end
function P.IsAdded(questId) return P.Char().added[questId] == true end

function P.AddedList()
	local out = {}
	for id in pairs(P.Char().added) do out[#out + 1] = id end
	table.sort(out)
	return out
end

function P.ResetOverrides()
	local c = P.Char()
	c.skipped, c.added = {}, {}
end

--- True when every value reachable from `t` can be written by SavedVariables (used by the self-test only).
function P.IsSavedVariablesSafe(t, seen)
	seen = seen or {}
	if seen[t] then return true end
	seen[t] = true
	for k, v in pairs(t) do
		local kt, vt = type(k), type(v)
		if kt ~= "string" and kt ~= "number" then return false end
		if vt == "table" then
			if not P.IsSavedVariablesSafe(v, seen) then return false end
		elseif vt == "number" then
			if v ~= v or v == math.huge or v == -math.huge then return false end
		elseif vt ~= "string" and vt ~= "boolean" then
			return false
		end
	end
	return true
end
