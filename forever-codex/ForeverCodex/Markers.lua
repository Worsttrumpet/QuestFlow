-- ForeverCodex.Markers: WoW-style world markers as an OUTPUT of the plan. Never a planner, never a dependency of it.
--
--   star     = NOW        at most one
--   diamond  = ALSO DO    at most one, only when there is one
--   triangle = the one relevant flight path (a flight hint that is NOW or ALSO DO)
--   moon     = the one relevant inn          (no inn data exists yet, so it is never set)
-- One marker per symbol (the game itself allows one icon of each kind), and only for an NPC Codex can identify by its
-- creature id. Nothing is marked "because it exists": an objective AREA has no NPC, and a turn-in whose NPC is only
-- ASSUMED (ATT has no turn-in NPC) is never marked.
--
-- WHAT FOREVER ALLOWS IS NOT VERIFIED. Raid-target icons (SetRaidTarget / GetRaidTargetIndex) act on a UNIT, not on a
-- map point, and nothing in this project's evidence says they work on Forever for an NPC you are not in a group with.
-- So placement is OFF until `/codex markers probe` (target an NPC first) has succeeded on this client AND the player
-- turned markers on (a passing probe turns them on). Until then Codex only computes what it WOULD mark (shown in /codex diag). Markers can only be set
-- on an NPC while it is your target or mouseover (that is when Codex sees its GUID); out-of-range markers are cleared the
-- next time that NPC is seen. The index numbers (star 1, diamond 3, triangle 4, moon 5) are the classic raid-target
-- indices and are part of what the probe checks.

local addonName, ns = ...
local P = ns.Prefs

local Mk = {}
ns.Markers = Mk

Mk.INDEX = { star = 1, diamond = 3, triangle = 4, moon = 5 }
Mk.SYMBOLS = { "star", "diamond", "triangle", "moon" }

local desired, applied, pendingClear = {}, {}, {}

--- The creature id of a GUID, or nil. The GUID itself is never kept.
local function creatureId(guid)
	if type(guid) ~= "string" then return nil end
	local kind, npc = guid:match("^(%a+)%-%d+%-%d+%-%d+%-%d+%-(%d+)%-")
	if (kind == "Creature" or kind == "Vehicle") and npc then return tonumber(npc) end
	return nil
end
Mk.CreatureId = creatureId

local function npcOf(a)
	if not a then return nil end
	for _, t in ipairs(a.targets or {}) do
		if t.entity and t.entity.kind == "npc" and type(t.entity.id) == "number" and not t.assumed and t.where and t.where.status ~= "unknown" then
			return t.entity.id
		end
	end
	return nil
end

--- What Codex WOULD mark for this plan: { star = {npc, action}, diamond = ..., triangle = ..., moon = nil }. Pure.
function Mk.Desired(plan)
	local d = {}
	if not plan then return d end
	local now, also = plan.now, plan.alsoDo
	local function put(sym, a)
		local npc = npcOf(a)
		if not npc then return end
		for _, v in pairs(d) do if v.npc == npc then return end end     -- one NPC, one symbol
		d[sym] = { npc = npc, action = a.id }
	end
	if now and now.type == "FLIGHT" then put("triangle", now) else put("star", now) end
	if also then
		if also.type == "FLIGHT" then
			if not d.triangle then put("triangle", also) end
		else
			put("diamond", also)
		end
	end
	return d
end

-- ---------------------------------------------------------------- the client, behind one table (tests replace it)

Mk.api = {
	available = function()
		return type(SetRaidTarget) == "function" and type(GetRaidTargetIndex) == "function" and type(UnitGUID) == "function" and type(UnitExists) == "function"
	end,
	exists = function(unit) local ok, v = pcall(UnitExists, unit) return ok and v and true or false end,
	guid = function(unit) local ok, v = pcall(UnitGUID, unit) return ok and v or nil end,
	get = function(unit) local ok, v = pcall(GetRaidTargetIndex, unit) return ok and v or nil end,
	set = function(unit, idx) return (pcall(SetRaidTarget, unit, idx)) end,
}

local function probeRecord()
	local r = P.Root().ui
	return r.markerProbe
end

--- True only after a successful probe on this client AND the player's switch.
function Mk.Enabled()
	local pr = probeRecord()
	return P.MarkersOn() and pr ~= nil and pr.ok == true and Mk.api.available()
end

--- /codex markers probe: with an NPC (not a player) targeted, does SetRaidTarget exist, run, place the mark, and can it be cleared again?
-- Restores whatever mark the NPC had. Returns ok, message. The result is saved. A passing probe also switches markers on (the player
-- ran the test on purpose). WHAT THIS CANNOT SEE: taint. A protected-action popup is shown by the client, not returned to Lua, so the
-- tester must watch for one while running it (the note says so).
function Mk.Probe()
	local function done(ok, msg)
		P.Root().ui.markerProbe = { ok = ok, note = msg, when = type(time) == "function" and time() or nil }
		if ok then P.SetMarkers(true) end
		return ok, msg
	end
	if not Mk.api.available() then return done(false, "this client has no SetRaidTarget / GetRaidTargetIndex / UnitGUID / UnitExists") end
	if not Mk.api.exists("target") then return false, "target an NPC first, then run the probe again" end
	if not creatureId(Mk.api.guid("target")) then return false, "target an NPC (not a player or pet), then run the probe again" end
	local before = Mk.api.get("target")
	if before and before ~= 0 then return false, "that NPC already has a raid mark that is not Codex's: target an unmarked NPC so nothing of yours is touched" end
	local okSet = Mk.api.set("target", Mk.INDEX.star)
	local read = Mk.api.get("target")
	local okClear = Mk.api.set("target", 0)
	local after = Mk.api.get("target")
	if not okSet then return done(false, "SetRaidTarget was refused on this client (error)") end
	if read ~= Mk.INDEX.star then return done(false, "SetRaidTarget ran but the mark did not read back (got " .. tostring(read) .. ")") end
	if not okClear or (after and after ~= 0) then return done(false, "the mark was placed but could not be cleared again, so markers stay off") end
	return done(true, "SetRaidTarget placed and cleared a mark on an NPC. Markers are on. (If the game showed a blocked-action popup, tell us: Lua cannot see that.)")
end

-- OWNERSHIP. `applied[sym] = guid` means: CODEX placed that symbol on that unit. Codex never claims a mark it did not place, never
-- replaces a mark of any other kind on a unit, never clears a mark that is not recorded as its own, and does not fight the player:
-- if its own mark is gone when it next sees the unit, the player removed it and Codex yields until the plan for that symbol changes.
local yielded = {}      -- [sym] = action id Codex stopped marking because the player removed its mark

local function apply(unit)
	if not Mk.api.available() or not Mk.api.exists(unit) then return end
	local guid = Mk.api.guid(unit)
	local npc = creatureId(guid)
	if not npc then return end
	local cur = Mk.api.get(unit)
	for sym, g in pairs(pendingClear) do
		if g == guid then
			if cur == Mk.INDEX[sym] then Mk.api.set(unit, 0); cur = 0 end        -- only ever a mark recorded as Codex's own
			pendingClear[sym] = nil
		end
	end
	if not Mk.Enabled() then return end
	for sym, d in pairs(desired) do
		if d.npc == npc and yielded[sym] ~= d.action then
			local idx = Mk.INDEX[sym]
			if applied[sym] == guid then
				if cur ~= idx then
					yielded[sym] = d.action        -- ours is gone or changed by the player: leave it alone
					applied[sym] = nil
				end
			elseif cur == nil or cur == 0 then
				if Mk.api.set(unit, idx) then applied[sym] = guid end
			end                                     -- any other mark (the player's, another addon's, even the same icon) is left strictly alone
		end
	end
end

--- After every recompute: remember what should be marked and queue the removal of marks that are no longer wanted.
function Mk.OnPlan(plan)
	local old = desired
	desired = Mk.Desired(plan)
	for sym, a in pairs(yielded) do
		if not desired[sym] or desired[sym].action ~= a then yielded[sym] = nil end     -- a new plan for that symbol: try again
	end
	for sym, guid in pairs(applied) do
		if not desired[sym] or creatureId(guid) ~= desired[sym].npc then
			pendingClear[sym] = guid
			applied[sym] = nil
		end
	end
	apply("target")
	apply("mouseover")
end

--- PLAYER_TARGET_CHANGED / UPDATE_MOUSEOVER_UNIT
function Mk.OnUnit(unit) apply(unit) end

function Mk.Status()
	local pr = probeRecord()
	return { enabled = Mk.Enabled(), wanted = P.MarkersOn(), probe = pr and (pr.ok and "passed" or "failed") or "not run", desired = desired, note = pr and pr.note or nil }
end

function Mk._Reset() desired, applied, pendingClear, yielded = {}, {}, {}, {} end
