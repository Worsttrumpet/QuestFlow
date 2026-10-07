-- ForeverCodex.Rides: boats and zeppelins, learned ONLY from rides the player made. Quest Flow ships no boat or zeppelin table and guesses none.
--
-- A ride is recorded when ALL of this was seen:
--   * the character was on foot outdoors, then a loading screen moved it to a DIFFERENT continent (the client's instance id changed),
--   * nothing else explains the jump: no Hearthstone cast pending, not on a flight, not dead or a ghost, not entering an instance, no spell cast
--     or summon accepted in the seconds before (a portal / summon is not a ride),
--   * the character had been MOVING without stopping for a short, bounded run before the loading screen (a platform carries you; walking to it
--     and waiting does not move you). The ride STARTS at the last place the character stood still before that run,
--   * after the loading screen the character stood still again (the dock) on a zone-level map within ARRIVE_WAIT seconds. That place is the end.
-- The time is from the start to the dock. If anything above is missing, nothing is recorded: unknown stays unknown.
--
-- Only the direction ridden is known: a ride Orgrimmar -> Undercity says nothing about the way back. Rides are stored per faction, because the
-- transports differ. Stored: ForeverCodexDB.world.rides = { key -> { from = { map, x, y, name }, to = { ... }, secs (shortest seen), n, faction, seen } }.
-- Each stored ride is registered with Travel as a fixed transport, so the planner may use it when it beats the walking estimate.

local addonName, ns = ...
local P = ns.Prefs

local R = {}
ns.Rides = R

R.SAMPLE_SECONDS = 2
R.BUFFER = 90                   -- samples kept (about three minutes)
R.STILL_YD_PER_S = 1.0          -- slower than this counts as standing still
R.MAX_RUN_SECONDS = 150         -- the moving run before the loading screen must be shorter than this
R.ARRIVE_WAIT = 150             -- seconds after the loading screen in which the dock must be seen
R.MIN_SECS, R.MAX_SECS = 20, 600
R.RECENT_CAST = 20              -- a spell cast this many seconds before the loading screen explains it as something else
R.SUMMON_WINDOW = 120
R.MAX_RIDES = 40

local buf = {}                  -- recent on-foot samples
local pending                   -- { origin, loaded, still, prev }
local lastCast, lastSummon
R.rejected = {}                 -- reason -> count (report)

local function isSecret(v) return type(issecretvalue) == "function" and issecretvalue(v) end
local function now() return type(GetTime) == "function" and GetTime() or (type(time) == "function" and time() or 0) end
local function reject(why) R.rejected[why] = (R.rejected[why] or 0) + 1 end

--- One reading: { t, y, x, cont, point, flags }, or nil when the client will not say.
function R.Read()
	if type(UnitPosition) ~= "function" then return nil end
	local ok, y, x, _, cont = pcall(UnitPosition, "player")
	if not ok or type(y) ~= "number" or type(x) ~= "number" or type(cont) ~= "number" or isSecret(y) or isSecret(x) then return nil end
	local s = { t = now(), y = y, x = x, cont = cont, point = ns.Services and ns.Services.PlayerPoint() or nil }
	local function flag(fn) if type(fn) ~= "function" then return false end local o, v = pcall(fn) return o and v == true end
	s.taxi = flag(function() return UnitOnTaxi("player") end)
	s.dead = flag(function() return UnitIsDeadOrGhost("player") end)
	s.inst = flag(function() local a = IsInInstance() return a == true or a == 1 end)
	return s
end

local function speed(a, b)
	local dt = b.t - a.t
	if dt <= 0 then return 0 end
	return math.sqrt((a.y - b.y) ^ 2 + (a.x - b.x) ^ 2) / dt
end

--- Feed one sample. While a ride is pending this looks for the dock.
function R.Feed(s)
	if not s then return end
	if pending then
		local p = pending
		if s.t - p.loaded > R.ARRIVE_WAIT then pending = nil reject("no dock seen") return R.Feed(s) end
		if p.prev and s.cont == p.cont and speed(p.prev, s) < R.STILL_YD_PER_S then
			p.still = p.still + 1
		else
			p.still = 0
		end
		p.prev = s
		if p.still >= 2 and s.point and not s.dead and not s.inst and ns.Services and ns.Services.IsAreaMap(s.point.map) then
			pending = nil
			R.Complete(p, s)
		end
		return
	end
	if s.inst or s.dead then return end
	buf[#buf + 1] = s
	if #buf > R.BUFFER then table.remove(buf, 1) end
end

--- The place the character last stood still before the final moving run, or nil.
function R.FindOrigin()
	local n = #buf
	if n < 3 then return nil end
	local last = buf[n]
	local i = n
	while i > 1 and speed(buf[i - 1], buf[i]) >= R.STILL_YD_PER_S do
		if buf[i - 1].cont ~= last.cont or buf[i - 1].taxi then return nil end
		i = i - 1
	end
	if i == 1 and speed(buf[1], buf[2]) >= R.STILL_YD_PER_S then return nil end   -- never stood still in the buffer
	local o = buf[i]
	if i == n then return nil end                                                   -- no moving run at all
	if last.t - o.t > R.MAX_RUN_SECONDS or not o.point then return nil end
	return o
end

--- A loading screen finished (not the first login / a reload). `first` is the reading taken right after it.
function R.OnLoaded(first)
	first = first or R.Read()
	local before = buf[#buf]
	if not (first and before) then reject("no reading") buf = {} return false end
	local origin = R.FindOrigin()
	buf = {}
	pending = nil
	if first.cont == before.cont then return false end                  -- same continent: not what this records
	if first.inst or first.dead then reject("instance or dead") return false end
	if before.taxi or first.taxi then reject("flight") return false end
	if ns.Services and ns.Services.HearthPending and ns.Services.HearthPending() then reject("hearthstone") return false end
	local t = now()
	if lastCast and t - lastCast <= R.RECENT_CAST then reject("spell just cast") return false end
	if lastSummon and t - lastSummon <= R.SUMMON_WINDOW then reject("summon") return false end
	if not origin then reject("no standing start") return false end
	pending = { origin = origin, loaded = first.t, still = 0, cont = first.cont, prev = first }
	return true
end

local function zoneName(map)
	if type(C_Map) ~= "table" or type(C_Map.GetMapInfo) ~= "function" then return nil end
	local ok, info = pcall(C_Map.GetMapInfo, map)
	if ok and type(info) == "table" and type(info.name) == "string" and not isSecret(info.name) then return info.name:sub(1, 40) end
	return nil
end

local function faction()
	if type(UnitFactionGroup) ~= "function" then return nil end
	local ok, f = pcall(UnitFactionGroup, "player")
	return ok and type(f) == "string" and f or nil
end

local function store()
	if not (P and P.Root) then return nil end
	local r = P.Root()
	if type(r) ~= "table" then return nil end
	r.world = type(r.world) == "table" and r.world or {}
	r.world.rides = type(r.world.rides) == "table" and r.world.rides or {}
	return r.world.rides
end

local function cell(p) return string.format("%d:%d:%d", p.map, math.floor(p.x * 50), math.floor(p.y * 50)) end

function R.Complete(p, dock)
	local secs = dock.t - p.origin.t
	if secs < R.MIN_SECS or secs > R.MAX_SECS then reject("implausible time") return false end
	local st = store()
	if not st then return false end
	local from, to = p.origin.point, dock.point
	local key = (faction() or "?") .. "|" .. cell(from) .. ">" .. cell(to)
	local e = st[key]
	if not e then
		local n = 0
		for _ in pairs(st) do n = n + 1 end
		if n >= R.MAX_RIDES then reject("store full") return false end
		e = { from = { map = from.map, x = from.x, y = from.y, name = zoneName(from.map) }, to = { map = to.map, x = to.x, y = to.y, name = zoneName(to.map) },
			faction = faction(), n = 0 }
		st[key] = e
	end
	e.n = e.n + 1
	e.secs = (e.secs and e.secs < secs) and e.secs or secs
	e.seen = type(time) == "function" and time() or 0
	R.Register()
	return true
end

function R.List()
	local out = {}
	local st = store()
	if not st then return out end
	for key, e in pairs(st) do
		if type(e) == "table" and type(e.from) == "table" and type(e.to) == "table" and type(e.secs) == "number" then out[#out + 1] = { key = key, ride = e } end
	end
	table.sort(out, function(a, b) return a.key < b.key end)
	return out
end

--- Hand every stored ride of this character's faction to Travel as a fixed transport.
function R.Register()
	if not ns.Travel then return 0 end
	local f = faction()
	local n = 0
	for _, it in ipairs(R.List()) do
		local e = it.ride
		if e.faction == nil or f == nil or e.faction == f then
			local a, b = e.from.name or "here", e.to.name or "there"
			if ns.Travel.AddTransport({ id = "ride:" .. it.key, label = "the ride from " .. a .. " to " .. b, from = e.from, to = e.to, secs = e.secs, src = "observed",
				evidence = string.format("a boat or zeppelin you rode (%d time%s, %d s from standing to dock)", e.n or 1, (e.n or 1) == 1 and "" or "s", math.floor(e.secs)) }) then n = n + 1 end
		end
	end
	return n
end

function R.Summary()
	local rej = 0
	for _, c in pairs(R.rejected) do rej = rej + c end
	return { rides = #R.List(), rejected = rej }
end

function R.ReportLines()
	local sm = R.Summary()
	local L = { string.format("Boat and zeppelin rides you have made: %d (a ride is recorded only when a loading screen took you to another continent, nothing else explains it, and you stood still at both ends); %d jump(s) not recorded.", sm.rides, sm.rejected) }
	for _, it in ipairs(R.List()) do
		local e = it.ride
		L[#L + 1] = string.format("  %s -> %s: %d s shortest, ridden %d time(s) (%s)", e.from.name or ("map " .. e.from.map), e.to.name or ("map " .. e.to.map), math.floor(e.secs), e.n or 1, e.faction or "faction unknown")
	end
	local reasons = {}
	for why, c in pairs(R.rejected) do reasons[#reasons + 1] = why .. " x" .. c end
	table.sort(reasons)
	if #reasons > 0 then L[#L + 1] = "  not recorded because: " .. table.concat(reasons, ", ") end
	return L
end

function R._Reset() buf, pending, lastCast, lastSummon, R.rejected = {}, nil, nil, nil, {} end

-- ---------------------------------------------------------------- events

local frame = CreateFrame("Frame")
for _, ev in ipairs({ "PLAYER_ENTERING_WORLD", "CONFIRM_SUMMON", "UNIT_SPELLCAST_SUCCEEDED", "PLAYER_LOGIN" }) do pcall(frame.RegisterEvent, frame, ev) end
frame:SetScript("OnEvent", function(_, event, a1, a2)
	local ok, err = pcall(function()
		if event == "PLAYER_LOGIN" then R.Register()
		elseif event == "PLAYER_ENTERING_WORLD" then
			if a1 == true or a2 == true then buf = {} pending = nil R.Register() return end    -- first login or a reload: no ride
			R.OnLoaded()
		elseif event == "CONFIRM_SUMMON" then lastSummon = now()
		elseif event == "UNIT_SPELLCAST_SUCCEEDED" then if a1 == "player" then lastCast = now() end
		end
	end)
	if not ok and ns.RecordError then ns.RecordError("rides " .. tostring(event), err) end
end)
local since = 0
frame:SetScript("OnUpdate", function(_, elapsed)
	since = since + (elapsed or 0)
	if since < R.SAMPLE_SECONDS then return end
	since = 0
	pcall(function() R.Feed(R.Read()) end)
end)
R.frame = frame
