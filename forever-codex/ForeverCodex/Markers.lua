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
-- turned markers on. Until then Codex only computes what it WOULD mark (shown in /codex diag). Markers can only be set
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

--- /codex markers probe: with an NPC targeted, does SetRaidTarget work, and does it read back? Restores the target's mark.
-- Returns ok, message. The result is saved so the player does not have to repeat it.
function Mk.Probe()
	local function done(ok, msg)
		P.Root().ui.markerProbe = { ok = ok, note = msg }
		return ok, msg
	end
	if not Mk.api.available() then return done(false, "this client has no SetRaidTarget / GetRaidTargetIndex / UnitGUID / UnitExists") end
	if not Mk.api.exists("target") then return false, "target an NPC first, then run the probe again" end
	local before = Mk.api.get("target")
	local okSet = Mk.api.set("target", Mk.INDEX.star)
	local read = Mk.api.get("target")
	Mk.api.set("target", before or 0)
	if not okSet then return done(false, "SetRaidTarget was refused on this client (error)") end
	if read ~= Mk.INDEX.star then return done(false, "SetRaidTarget ran but the mark did not read back (got " .. tostring(read) .. ")") end
	return done(true, "SetRaidTarget works on an NPC target: markers can be turned on")
end

local function apply(unit)
	if not Mk.Enabled() or not Mk.api.exists(unit) then return end
	local guid = Mk.api.guid(unit)
	local npc = creatureId(guid)
	if not npc then return end
	for sym, d in pairs(desired) do
		if d.npc == npc then
			if Mk.api.get(unit) ~= Mk.INDEX[sym] then Mk.api.set(unit, Mk.INDEX[sym]) end
			applied[sym] = guid
			pendingClear[sym] = nil
		end
	end
	for sym, g in pairs(pendingClear) do
		if g == guid then
			if Mk.api.get(unit) == Mk.INDEX[sym] then Mk.api.set(unit, 0) end
			pendingClear[sym] = nil
		end
	end
end

--- After every recompute: remember what should be marked and queue the removal of marks that are no longer wanted.
function Mk.OnPlan(plan)
	desired = Mk.Desired(plan)
	for sym, guid in pairs(applied) do
		if not desired[sym] or creatureId(guid) ~= desired[sym].npc then
			pendingClear[sym] = guid
			applied[sym] = nil
		end
	end
	if Mk.Enabled() then
		apply("target")
		apply("mouseover")
	end
end

--- PLAYER_TARGET_CHANGED / UPDATE_MOUSEOVER_UNIT
function Mk.OnUnit(unit) apply(unit) end

function Mk.Status()
	local pr = probeRecord()
	return { enabled = Mk.Enabled(), wanted = P.MarkersOn(), probe = pr and (pr.ok and "passed" or "failed") or "not run", desired = desired, note = pr and pr.note or nil }
end

function Mk._Reset() desired, applied, pendingClear = {}, {}, {} end
