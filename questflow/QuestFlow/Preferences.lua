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

-- SAVED DATA VERSION (see SavedData.lua for the migration steps). 1 = every build before the per-character observation stores; 2 = they belong to ONE character.
-- A save from a NEWER build (a higher number) is never touched. Additive defaults (ensureChar) still fill in anything missing; a migration step is only for a field that was MOVED, RENAMED, RESHAPED or REMOVED.
local DB_VERSION = 2
P.DB_VERSION = DB_VERSION
local charKey = "unknown"

local function root()
	if type(ForeverCodexDB) ~= "table" then
		ForeverCodexDB = {}
	end
	local db = ForeverCodexDB
	if db.version == nil then
		-- a save from before the version number existed is version 1; a table with nothing in it is a brand-new install (current)
		db.version = next(db) ~= nil and 1 or DB_VERSION
	end
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
	-- party chat output was removed (Questie already announces quest status): an old "party" / "both" choice, or anything unknown, becomes "ui"
	if c.partyNotify ~= "off" and c.partyNotify ~= "ui" then c.partyNotify = "ui" end
	if c.navigation == nil then c.navigation = true end
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

--- Whether seasonal / holiday / world-event quests may enter the normal pool (per character; default OFF). Even when on they are only routed on a client offer.
function P.IncludeSeasonal() return P.Char().includeSeasonal == true end
function P.SetIncludeSeasonal(on) P.Char().includeSeasonal = on and true or false end

--- Whether Codex may read quest knowledge from the QuestieDB addon when it is installed (account-wide; default ON, the way Codex has always worked). QuestieDB is third-party data: it is never copied
-- into Codex and never treated as confirmed on Forever (see docs/CODEX_DATA_SOURCES.md). Turning it off makes Codex use only its own observed data and its ATT-derived packs.
function P.UseQuestieDB() return root().ui.useQuestieDB ~= false end
function P.SetUseQuestieDB(on) root().ui.useQuestieDB = on and true or false end

--- The chosen look of the player window (see UI/Theme.lua): a theme key, or nil for the default. Account-wide (it is how the player wants Codex to look, not a character choice).
function P.ThemeKey() return root().ui.theme end
function P.SetThemeKey(k) root().ui.theme = type(k) == "string" and k or nil end


-- ---------------------------------------------------------------- character IDENTITY (0.7.5)
--
-- "Name-Realm" is NOT a character identity: deleting a character and creating another with the same name gave the new one the old one's skips, journey, turn-in count and dialog stamps
-- (found in the 0.7.4 playtest on build 70205). The client offers no account or character id that Codex can rely on: UnitGUID is proven to answer for an NPC, but whether UnitGUID("player")
-- returns a usable "Player-..." value on Forever is UNPROVEN. So identity is a DEFENCE, not a proof:
--   * if UnitGUID("player") returns a "Player-..." string it is stored ONLY as a one-way hash (never raw); a different hash is a different character, an equal hash is the same one;
--   * otherwise (or when there is nothing stored yet to compare) the stored fingerprint is class, race, faction and the highest level seen: a different class, race or faction, or a
--     level LOWER than the highest seen, cannot be the same character (levels never go down), so it is a new one;
--   * a legacy save with no fingerprint is judged by the highest level in its journey.
-- It CANNOT detect a deleted character recreated with the same name, class, race and faction whose level has not gone below the old one's highest (for example a level 1 re-roll of a
-- level 1 character, which has nothing to lose, or an old character that never got past the new one's level). A normal level-up never resets anything.
-- A new character gets a clean slate for GAMEPLAY state only: skips, added quests, journey and turn-ins, the saved waypoint, route zone, Spell Training and Professions state.
-- Window position and every other UI / route-style / toggle setting is kept; the account-wide stores (offers, items, telemetry, feedback) are never touched.

P.IDENTITY_VERSION = 1

--- A one-way hash for a GUID string (two independent polynomial hashes, 16 hex digits). Not cryptographic: it only has to be stable, short and not the GUID.
local function hashOf(s)
	local a, b = 7, 11
	for i = 1, #s do
		local c = s:byte(i)
		a = (a * 131 + c) % 2147483629
		b = (b * 137 + c * (i % 7 + 1)) % 2147483587
	end
	return string.format("%08x%08x", a, b)
end
P._hashOf = hashOf

local function highestLevelSeen(c)
	local m = type(c.journey) == "table" and type(c.journey.lastLevel) == "number" and c.journey.lastLevel or 0
	for _, e in ipairs(type(c.journey) == "table" and c.journey.entries or {}) do
		if type(e) == "table" and type(e.lvl) == "number" and e.lvl > m then m = e.lvl end
	end
	return m
end

--- The gameplay state of a character, cleared (see the comment above for what stays).
function P.ResetCharacterState()
	local c = P.Char()
	if ns.SavedData then ns.SavedData.ClearLive(charKey) end        -- a re-created character with the same name inherits none of the old one's observations either
	c.skipped, c.added, c.nav = {}, {}, nil
	c.routeZone = "auto"
	c.journey = { entries = {} }
	c.spellTraining, c.professions = nil, nil
end

--- Decides whether the character logging in is the one this entry was saved for, and resets the gameplay state when it clearly is not.
-- snap = { class, race, faction, level, guid } as the client reports them (any may be nil). Returns { result = "FIRST" | "SAME" | "RESET", reason, signal }.
function P.CheckIdentity(snap)
	snap = snap or {}
	local c = P.Char()
	local guid = (type(snap.guid) == "string" and snap.guid:find("^Player%-")) and hashOf(snap.guid) or nil
	local level = (type(snap.level) == "number" and snap.level >= 1) and snap.level or nil
	local id = type(c.identity) == "table" and c.identity or nil
	local verdict
	if id and id.v == P.IDENTITY_VERSION then
		if guid and id.guid then
			if guid ~= id.guid then verdict = { "RESET", "a different character id (hashed) under the same name", "guid" } else verdict = { "SAME", "same character id (hashed)", "guid" } end
		end
		if not verdict then
			if snap.class and id.class and snap.class ~= id.class then verdict = { "RESET", "different class: " .. tostring(id.class) .. " -> " .. tostring(snap.class), "class" }
			elseif snap.race and id.race and snap.race ~= id.race then verdict = { "RESET", "different race: " .. tostring(id.race) .. " -> " .. tostring(snap.race), "race" }
			elseif snap.faction and id.faction and snap.faction ~= id.faction then verdict = { "RESET", "different faction", "faction" }
			elseif level and type(id.maxLevel) == "number" and level < id.maxLevel then verdict = { "RESET", string.format("level %d is below the highest level seen (%d)", level, id.maxLevel), "level" }
			else verdict = { "SAME", "class, race, faction and level are consistent", "fingerprint" } end
		end
	else
		-- no fingerprint stored: a first run of this feature, or a character never seen. A legacy save is judged by its journey's highest level.
		local seen = highestLevelSeen(c)
		if seen > 0 and level and level < seen then verdict = { "RESET", string.format("legacy save: level %d is below the highest level in its journey (%d)", level, seen), "legacy-level" }
		elseif seen > 0 then verdict = { "FIRST", "legacy save with no fingerprint; nothing contradicts it", "legacy" }
		else verdict = { "FIRST", "no earlier state", "none" } end
	end
	local result = { result = verdict[1], reason = verdict[2], signal = verdict[3], guidAvailable = guid ~= nil }
	if result.result == "RESET" then
		local old = id and { class = id.class, race = id.race, maxLevel = id.maxLevel } or { maxLevel = highestLevelSeen(c) }
		P.ResetCharacterState()
		id = nil
		c.identityReset = { at = type(_G.time) == "function" and _G.time() or 0, reason = verdict[2], signal = verdict[3], was = old }
	end
	if not id then id = { v = P.IDENTITY_VERSION }; c.identity = id end
	id.class, id.race, id.faction = snap.class or id.class, snap.race or id.race, snap.faction or id.faction
	if guid then id.guid = guid end
	if level and (type(id.maxLevel) ~= "number" or level > id.maxLevel) then id.maxLevel = level end
	P.lastIdentity = result
	return result
end

--- Keeps the highest level seen current (called with every fresh context; a level-up is never a reset).
function P.NoteLevel(level)
	local id = P.Char().identity
	if type(id) == "table" and type(level) == "number" and (type(id.maxLevel) ~= "number" or level > id.maxLevel) then id.maxLevel = level end
end

-- ---------------------------------------------------------------- setup, notifications, navigation, window (Phase 3)

function P.SetupDone() return P.Char().setupDone == true end
function P.FinishSetup() P.Char().setupDone = true end
function P.ReopenSetup() P.Char().setupDone = false end

P.PARTY_MODES = { "off", "ui" }
function P.PartyNotify() return P.Char().partyNotify end
function P.SetPartyNotify(mode)
	for _, m in ipairs(P.PARTY_MODES) do
		if m == mode then P.Char().partyNotify = mode return true end
	end
	return false
end

function P.NavigationOn() return P.Char().navigation == true end
function P.SetNavigation(on) P.Char().navigation = on == true end
--- Hides the game's own quest tracker so the Codex tracker can take its place (off by default; see BlizzardTracker.lua).
function P.HideBlizzardTracker() return root().ui.hideBlizzardTracker == true end
function P.SetHideBlizzardTracker(on) root().ui.hideBlizzardTracker = on == true end
--- A small Codex button on the world map (on by default).
function P.WorldMapButtonOn() return root().ui.worldMapButton ~= false end
function P.SetWorldMapButton(on) root().ui.worldMapButton = on == true end
function P.ArrowOn() return P.Char().arrow ~= false end
function P.SetArrow(on) P.Char().arrow = on == true end
function P.ArrowFlip() return root().ui.arrowFlip == true end
--- The arrow's picture and colour (keys; Arrow.lua knows the list and falls back to its default for anything unknown).
function P.ArrowStyle() return root().ui.arrowStyle end
function P.SetArrowStyle(k) root().ui.arrowStyle = type(k) == "string" and k or nil end
function P.ArrowColor() return root().ui.arrowColor end
function P.SetArrowColor(k) root().ui.arrowColor = type(k) == "string" and k or nil end
function P.SetArrowFlip(on) root().ui.arrowFlip = on == true end

--- The player window's saved anchor: { point, relPoint, x, y } or nil.
function P.WindowPos() return root().ui.window end
function P.SetWindowPos(t) root().ui.window = t end

local ANCHORS = { TOPLEFT = true, TOP = true, TOPRIGHT = true, LEFT = true, CENTER = true, RIGHT = true, BOTTOMLEFT = true, BOTTOM = true, BOTTOMRIGHT = true }

--- The minimap button's saved anchor on UIParent: { point, rel, x, y }, or nil when none is saved or what is saved is not usable
-- (a hand-edited or damaged file must never leave the button off-screen: nil means "use the default spot").
function P.MinimapPos()
	local t = root().ui.minimapPos
	if type(t) ~= "table" or not ANCHORS[t.point] then return nil end
	local rel = t.rel == nil and t.point or t.rel
	if not ANCHORS[rel] then return nil end
	local x, y = t.x, t.y
	if type(x) ~= "number" or type(y) ~= "number" or x ~= x or y ~= y or math.abs(x) > 10000 or math.abs(y) > 10000 then return nil end
	return { point = t.point, rel = rel, x = x, y = y }
end
function P.SetMinimapPos(t) root().ui.minimapPos = t end
--- Where the minimap button sits ON the minimap's edge, as an angle in degrees (0 = east, counter-clockwise), or nil when none / unusable.
function P.MinimapAngle()
	local a = root().ui.minimapAngle
	if type(a) ~= "number" or a ~= a or a == math.huge or a == -math.huge then return nil end
	return a % 360
end
function P.SetMinimapAngle(a) root().ui.minimapAngle = type(a) == "number" and a or nil end
function P.ClearMinimapAngle() root().ui.minimapAngle = nil end
--- Whether the tracker was showing when the player last used it (shown by default; only an explicit close keeps it away after a reload).
function P.TrackerShown() return root().ui.trackerShown ~= false end
function P.SetTrackerShown(on) root().ui.trackerShown = on == true end
function P.ClearMinimapPos() root().ui.minimapPos = nil end

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
	local c = P.Char()
	c.skipped[key] = true
	-- skipping a quest the player had ADDED is a later, explicit choice: it takes the quest out of "added" (the mirror of P.Add clearing a skip), so it cannot stay pinned in the route
	local id = tonumber(key:match("^QT?:(%d+)"))
	if id then c.added[id] = nil end
	return true
end

--- Resolves a save in which the same quest is both ADDED and SKIPPED (a skip used to leave it pinned): the skip wins, as it would have if the player's choices had been applied in order. Returns how many were fixed.
function P.NormalizeOverrides()
	local c = P.Char()
	local n = 0
	for id in pairs(c.added) do
		if c.skipped["Q:" .. id] == true or c.skipped["QT:" .. id] == true then c.added[id] = nil n = n + 1 end
	end
	return n
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
