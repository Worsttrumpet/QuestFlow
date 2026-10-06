-- ForeverCodex.SavedData (0.7.9): saved-data MIGRATION and the PER-CHARACTER observation stores. Kept out of Preferences (which stays a plain settings module) and out of the observation modules
-- (which must not depend on Preferences): they ask this module only who a freshly created store belongs to.

local addonName, ns = ...
local P = ns.Prefs

local SD = {}
ns.SavedData = SD

--
-- Telemetry (the observation log) and the NPC offer / dialog evidence describe what ONE character saw and did, so they must not follow the player to another character. They used to be single
-- account-wide tables, which is how a second character could read the first one's dialog evidence. The live tables keep their old names (ForeverCodexDB.telemetry / .offers, so every module and every test
-- is unchanged) but each one is stamped with an `owner` (the character key). At login the active character's tables are made live and the previous owner's are PARKED under chars[owner].parked,
-- so nothing is lost and nothing is shared. Everything else in the save stays account-wide ON PURPOSE: ui (window, minimap, theme), items (item facts are the game's, not a character's), spellCatalog (class data),
-- feedback and the stored diagnostic reports.

SD.PARTITIONED = { "offers", "telemetry" }

local function countOtherChars(db, key)
	local n = 0
	for k in pairs(db.chars or {}) do if k ~= key and k ~= "unknown" then n = n + 1 end end
	return n
end

local MIGRATIONS = {}

--- 1 -> 2: the two observation stores were account-wide and carry no owner. Whose are they? Unknowable in general. If this is the ONLY character the save has ever seen, they are unambiguously its own and it
-- keeps them. If other characters exist, giving them to whoever logs in first could re-create the very leak this fixes, so they are ARCHIVED, untouched, under db.legacy (nothing is deleted).
MIGRATIONS[1] = function(db, key, log)
	for _, name in ipairs(SD.PARTITIONED) do
		local live = db[name]
		if type(live) == "table" and live.owner == nil then
			if countOtherChars(db, key) == 0 then
				live.owner = key
				log[#log + 1] = name .. ": kept by " .. key .. " (the only character in this save)"
			else
				db.legacy = type(db.legacy) == "table" and db.legacy or {}
				db.legacy[name] = live
				db[name] = nil
				log[#log + 1] = name .. ": archived under legacy (more than one character, owner unknown)"
			end
		end
	end
end

--- Brings the saved data to the current version, one step at a time. Idempotent; never raises; a failing step stops the run and is recorded (the save is left at the last good version).
-- Returns { from, to, steps = { text }, error = text | nil, newer = true | nil }.
function SD.Migrate()
	local db = P.Root()
	local v = type(db.version) == "number" and db.version or 1
	local out = { from = v, to = v, steps = {} }
	if v > P.DB_VERSION then out.newer = true SD.lastMigration = out return out end
	while v < P.DB_VERSION do
		local step = MIGRATIONS[v]
		if not step then break end
		local ok, err = pcall(step, db, P.CharKey(), out.steps)
		if not ok then out.error = "step " .. v .. " failed: " .. tostring(err) break end
		v = v + 1
		db.version = v
		out.to = v
	end
	if out.to ~= out.from then
		db.migrations = type(db.migrations) == "table" and db.migrations or {}
		db.migrations[#db.migrations + 1] = { from = out.from, to = out.to, at = type(_G.time) == "function" and _G.time() or 0, by = P.CharKey(), steps = out.steps }
		while #db.migrations > 10 do table.remove(db.migrations, 1) end
	end
	SD.lastMigration = out
	return out
end

--- Makes the current character's partitions the live tables (parks the previous owner's). Call at login after the character key is set.
function SD.ActivatePartitions()
	local db = P.Root()
	local c = P.Char()
	for _, name in ipairs(SD.PARTITIONED) do
		local live = db[name]
		if type(live) == "table" and live.owner ~= nil and live.owner ~= P.CharKey() then
			local o = db.chars[live.owner]
			if type(o) ~= "table" then o = {}; db.chars[live.owner] = o end
			o.parked = type(o.parked) == "table" and o.parked or {}
			o.parked[name] = live
			db[name] = nil
			live = nil
		end
		if live == nil and type(c.parked) == "table" and type(c.parked[name]) == "table" then
			db[name] = c.parked[name]
			c.parked[name] = nil
			live = db[name]
		end
		if type(live) == "table" and live.owner == nil then live.owner = P.CharKey() end         -- (a table a module created without stamping: it is the current character's)
	end
	if type(c.parked) == "table" and next(c.parked) == nil then c.parked = nil end
end

--- "Name-Realm" of the logged-in character as the client reports it, or "unknown".
function SD.DetectCharKey()
	local name = type(_G.UnitName) == "function" and _G.UnitName("player") or nil
	local realm = type(_G.GetRealmName) == "function" and _G.GetRealmName() or nil
	if type(name) == "string" and name ~= "" then return name .. "-" .. tostring(realm or "?") end
	return "unknown"
end

--- Everything that must be true before ANY module stores something for this character: the character key, the saved data brought up to date, this character's observation stores live. Both Boot and Telemetry
-- (which has its own PLAYER_LOGIN handler: the order between two frames is not something to rely on) call it. `force` re-runs it (a new login in the same session, as the tests do); without it a second call is free.
function SD.PrepareLogin(force)
	if SD.prepared and not force then return end
	SD.prepared = true
	P.SetCharKey(SD.DetectCharKey())
	SD.Migrate()
	SD.ActivatePartitions()
	P.NormalizeOverrides()                                 -- a quest both added and skipped (saved by a build that let the skip lose): the skip wins
end

--- The key a freshly created partition table must carry (modules call this when they create their store).
function SD.Owner() return P.CharKey() end

--- Report lines: the save's version, the last migration, what was archived, and who owns each live store.
function SD.SavedDataLines()
	local db = P.Root()
	local L = { string.format("SAVED DATA: version %s (this build writes %d)%s", tostring(db.version), P.DB_VERSION, (type(db.version) == "number" and db.version > P.DB_VERSION) and " - saved by a NEWER Codex: left untouched" or "") }
	local m = SD.lastMigration
	if m and (m.to ~= m.from or m.error) then L[#L + 1] = string.format("  migrated this session: %d -> %d%s", m.from, m.to, m.error and (" | " .. m.error) or "") for _, t in ipairs(m.steps) do L[#L + 1] = "    " .. t end end
	local archived = {}
	for k, v in pairs(db.legacy or {}) do archived[#archived + 1] = k .. (type(v) == "table" and type(v.events) == "table" and (" (" .. #v.events .. " events)") or "") end
	table.sort(archived)
	if #archived > 0 then L[#L + 1] = "  archived, owner unknown (kept, not used): " .. table.concat(archived, ", ") end
	L[#L + 1] = string.format("  live stores belong to: telemetry=%s offers=%s | account-wide on purpose: ui, items, spellCatalog, feedback, diag", tostring(db.telemetry and db.telemetry.owner), tostring(db.offers and db.offers.owner))
	return L
end


--- A re-created character (same name, different character: see Preferences.CheckIdentity) must not inherit the old one's observation stores: drop the live ones and anything parked for it.
function SD.ClearLive(key)
	local db = P.Root()
	for _, name in ipairs(SD.PARTITIONED) do
		if type(db[name]) == "table" and (db[name].owner == nil or db[name].owner == key) then db[name] = nil end
	end
	local c = db.chars and db.chars[key]
	if type(c) == "table" then c.parked = nil end
end
