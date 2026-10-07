-- ForeverCodex.AreaEvidence: am I already IN the area an objective sends me to?
--
-- An area objective is drawn by the game as ONE representative point (the quest-map marker; ATT's objective coordinate). That point is not an exact destination and does not prove an area's
-- size or shape: the real area may be a camp, a region or a whole zone. Steering the player toward the marker while they are already killing the right mobs 120 yd away makes the arrow swing
-- around for no reason. Codex has no boundary data for any area (nothing in ATT, QuestieDB or the observed pack carries a radius), so it does not invent one. It uses two honest signals:
--   1. PROGRESS WHERE YOU STAND: when a quest's objective counts go up (the client's own quest log) the player is, by definition, somewhere that counts. Those positions are remembered for the
--      session; being within AREA_YD of one of them means "still in the area".
--   2. ARRIVAL AT THE MARKER: within ARRIVE_YD of the marker itself.
-- Both distances are design values, not game facts. A target that carries a real `radius` (none does today) would be used instead. Without either signal Codex keeps navigating toward the
-- marker, and says the place is approximate.
-- Session-only state: nothing is saved, and a quest that leaves the log or becomes ready to hand in forgets its positions.

local _, ns = ...
local A = {}
ns.AreaEvidence = A

A.AREA_YD = 80          -- how far from a place where progress was made still counts as the same area
A.ARRIVE_YD = 40        -- how close to the representative marker counts as having arrived
A.KEEP = 6              -- positions kept per quest

A.sightings = {}        -- [questID] = { { map, x, y }, ... } newest last
local lastSum = {}      -- [questID] = total `have` at the previous context

local function haveSum(entry)
	local n, any = 0, false
	for _, o in ipairs(entry.objectives or {}) do
		-- (the client's objective rows: numFulfilled / numRequired)
		local h = type(o) == "table" and (o.numFulfilled or o.have)
		if type(h) == "number" then n = n + h; any = true end
	end
	return any and n or nil
end

--- Called with every fresh context: remembers where the player was when a quest's objective counts rose.
function A.Observe(ctx)
	local log = ctx and ctx.log or {}
	local loc = ctx and ctx.loc
	for id, entry in pairs(log) do
		local sum = haveSum(entry)
		if entry.complete then
			A.sightings[id] = nil
		elseif sum ~= nil then
			if lastSum[id] ~= nil and sum > lastSum[id] and loc and loc.available then
				local list = A.sightings[id] or {}
				list[#list + 1] = { map = loc.map, x = loc.x, y = loc.y }
				while #list > A.KEEP do table.remove(list, 1) end
				A.sightings[id] = list
			end
			lastSum[id] = sum
		end
	end
	for id in pairs(lastSum) do if not log[id] then lastSum[id] = nil; A.sightings[id] = nil end end
end

--- Is the player inside the area of this quest's objective? `marker` = { map, x, y } (the representative point). Returns true, why ("progress" | "marker" | "radius") or false.
function A.Inside(questId, ctx, marker, radius)
	local loc = ctx and ctx.loc
	if not (loc and loc.available) then return false end
	local me = { map = loc.map, x = loc.x, y = loc.y, world = loc.world or false }
	local E = ns.Engine
	local function near(p, yd)
		local d = E.Distance(ctx, me, { map = p.map, x = p.x, y = p.y })
		return d ~= nil and d < E.DIFFERENT_CONTINENT and d <= yd
	end
	if marker and radius and near(marker, radius) then return true, "radius" end
	for _, s in ipairs(A.sightings[questId] or {}) do if near(s, A.AREA_YD) then return true, "progress" end end
	if marker and near(marker, A.ARRIVE_YD) then return true, "marker" end
	return false
end

function A.ReportLines()
	local L = { "AREA OBJECTIVES (an area is one representative point; Quest Flow knows no boundary and invents none)" }
	local n = 0
	for id, list in pairs(A.sightings) do
		n = n + 1
		L[#L + 1] = string.format("  Q%d: progress seen at %d place(s) this session (still in the area within %d yd of one; arrived within %d yd of the marker)", id, #list, A.AREA_YD, A.ARRIVE_YD)
	end
	if n == 0 then L[#L + 1] = "  no objective progress seen yet this session: the marker is treated as an approximate destination" end
	return L
end

function A._Reset() A.sightings, lastSum = {}, {} end
