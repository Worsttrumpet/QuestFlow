-- ForeverCodex.Travel: the shared travel model. One place that answers "what is the cheapest EVIDENCED way to get from here to there, and how long?"
--
--   Quest -> NPC -> Location -> Travel options -> Transportation -> Destination -> Objective
--
-- The Planner asks it through its single travel-time choke point (Planner.lua seconds()); PlanAdapter asks it for the steps to show; Navigation then
-- points at the first step's target (the flight master, or the place to walk to). Nothing here is a second planner.
--
-- OPTIONS (each is an edge in a small graph; walking is always the baseline):
--   WALK       straight-line distance / run speed (the same estimate the planner always used). Unchanged.
--   FLIGHT     fly from a node the character has DISCOVERED to a node the client OFFERED from there (Taxi.Edges). Only evidenced edges exist:
--              no edge, no route. Time = the measured flight when one was timed, else distance / FLY_SPEED, flagged `estimated`. Money:
--              an edge whose cost is known and not affordable (ctx.char.money) is not offered.
--   HEARTH     only when the Hearthstone is in the bags, off cooldown (both read from the client) AND a bind point was learned by watching the
--              character bind. It spends a one-hour cooldown, so it is offered only when it saves a lot (HEARTH_MIN_GAIN).
--   TRANSPORT  boats, zeppelins, portals and other fixed transports: edges registered with Travel.AddTransport (from data or tests). Quest Flow ships NO
--              boat or zeppelin data (none is verified), so none is ever routed; the quest's own text still names them (Navigation SPECIAL_TRAVEL).
-- A route is returned only when it beats walking by MIN_GAIN seconds (or walking is impossible), so ordinary short trips never change, and
-- with no taxi / bind / transport evidence Travel does nothing at all (planner results, goldens and saved data are unchanged).
--
-- Honest limits: walking is a straight line (no pathing); a flight edge is one the map OFFERED from a node, in that direction only; the estimated flight
-- speed is a rough constant until a real flight of that edge has been timed.

local addonName, ns = ...
local P = ns.Prefs

local Tr = {}
ns.Travel = Tr

Tr.RUN_SPEED = 7                 -- yards per second, the planner's own (Planner.RUN_SPEED); kept in step by a test
Tr.FLY_SPEED = 25                -- yards per second: ROUGH, used only for an edge never timed (reported as estimated)
Tr.BOARD_SECONDS = 12            -- finding the flight master and taking the flight
Tr.HEARTH_CAST_SECONDS = 15
Tr.MIN_GAIN = 60                 -- a flight / transport must save this many seconds over walking
Tr.HEARTH_MIN_GAIN = 300         -- the hearth must save this many (it has a one-hour cooldown)
Tr.MIN_WALK_SECONDS = 90         -- walks shorter than this are never compared (cheap, and the common case)
Tr.HEARTHSTONE_ITEM = 6948

local transports = {}            -- registered fixed-transport edges

--- Registers a fixed transport edge: { id, label, from = {map,x,y}, to = {map,x,y}, secs, src, evidence }. `evidence` must say where it came from.
function Tr.AddTransport(e)
	if type(e) ~= "table" or type(e.from) ~= "table" or type(e.to) ~= "table" or type(e.secs) ~= "number" or type(e.evidence) ~= "string" then return false end
	transports[#transports + 1] = e
	return true
end
function Tr.Transports() return transports end
function Tr.ClearTransports() transports = {} end

-- ---------------------------------------------------------------- node points

local pointCache, cacheVersion
local function nodePoints()
	local T = ns.Taxi
	if not T then return {} end
	local v = T.Version()
	if pointCache and cacheVersion == v then return pointCache end
	local att = {}
	if ns.Registry and ns.Registry.FlightNodes then for _, n in ipairs(ns.Registry.FlightNodes()) do att[n.id] = n end end
	local out = {}
	for _, n in ipairs(T.Nodes()) do
		local pt
		if n.map and n.x and n.y then pt = { map = n.map, x = n.x, y = n.y, src = "client taxi map" }
		elseif n.att and att[n.att] then pt = { map = att[n.att].map, x = att[n.att].x, y = att[n.att].y, src = "ATT (unverified)" } end
		out[n.key] = { key = n.key, name = n.name or (n.att and att[n.att] and att[n.att].name) or n.key, disc = n.disc, point = pt }
	end
	pointCache, cacheVersion = out, v
	return out
end
Tr._nodePoints = nodePoints

-- Engine.Distance answers exactly DIFFERENT_CONTINENT (a sentinel) when two points cannot be compared; any other number is a real straight-line distance, even a long
-- one. The Planner's own walk estimate treats every distance from that value up as "cannot be known", which is right for walking and wrong for a flight, so Travel
-- keeps the real long distances and drops only the sentinel.
local function dist(ctx, a, b)
	local d = ns.Engine.Distance(ctx, a, b)
	if d == nil or d == ns.Engine.DIFFERENT_CONTINENT then return nil end
	return d
end

local function walkSecs(ctx, a, b)
	local d = dist(ctx, a, b)
	if d == nil then return nil, nil end
	return d / (ns.Planner and ns.Planner.RUN_SPEED or Tr.RUN_SPEED), d
end

-- ---------------------------------------------------------------- hearth

--- The bind point, learned from watching the character bind: { map, x, y, name } or nil.
function Tr.Bind()
	if not (P and P.Char) then return nil end
	local c = P.Char()
	local b = type(c) == "table" and type(c.travel) == "table" and c.travel.bind or nil
	if type(b) == "table" and type(b.map) == "number" and type(b.x) == "number" and type(b.y) == "number" then return b end
	return nil
end

function Tr.SetBind(map, x, y, name)
	if not (P and P.Char) or type(map) ~= "number" or type(x) ~= "number" or type(y) ~= "number" then return false end
	local c = P.Char()
	c.travel = type(c.travel) == "table" and c.travel or {}
	c.travel.bind = { map = map, x = x, y = y, name = type(name) == "string" and name:sub(1, 60) or nil, t = type(time) == "function" and time() or 0 }
	return true
end

--- Hearthstone state from the context: "READY" / "COOLDOWN" / "ABSENT" / "UNKNOWN".
function Tr.HearthState(ctx)
	local h = ctx and ctx.char and ctx.char.hearth
	if type(h) ~= "table" then return "UNKNOWN" end
	if h.has == false then return "ABSENT" end
	if h.has == true and h.ready == true then return "READY" end
	if h.has == true and h.ready == false then return "COOLDOWN" end
	return "UNKNOWN"
end

-- ---------------------------------------------------------------- routes

--- Best EVIDENCED way from `a` to `b` that beats walking, or nil when walking is best / nothing is evidenced.
-- Returns { mode = "FLIGHT" | "HEARTH" | "TRANSPORT", seconds, walkSeconds, saves, estimated, legs = { ... }, why }.
-- legs: { mode = "WALK"|"FLIGHT"|"HEARTH"|"TRANSPORT", from = point, to = point, label, secs, estimated }
function Tr.Route(ctx, a, b)
	if not (ctx and a and b and ns.Engine) then return nil end
	local walk = walkSecs(ctx, a, b)
	if walk and walk < Tr.MIN_WALK_SECONDS then return nil end
	local best
	local function consider(route, minGain)
		if not route then return end
		if walk and walk - route.seconds < minGain then return end
		if not best or route.seconds < best.seconds then best = route end
	end
	-- FLIGHT
	local T = ns.Taxi
	if T then
		local pts = nodePoints()
		local money = ctx.char and type(ctx.char.money) == "number" and ctx.char.money or nil
		local toStart = {}
		for _, e in ipairs(T.Edges()) do
			local f, t = pts[e.from], pts[e.to]
			if f and t and f.point and t.point and f.disc == "YES" and t.disc == "YES" and not (money and e.cost and e.cost > money) then
				local w1 = toStart[e.from]
				if w1 == nil then w1 = walkSecs(ctx, a, f.point) or false toStart[e.from] = w1 end
				if w1 and (not walk or w1 < walk) then
					local w2 = walkSecs(ctx, t.point, b)
					if w2 then
						local fly, est = e.secs, false
						if not fly then
							local d = dist(ctx, f.point, t.point)
							if d then fly, est = d / Tr.FLY_SPEED, true end
						end
						if fly then
							local total = w1 + Tr.BOARD_SECONDS + fly + w2
							consider({ mode = "FLIGHT", seconds = total, walkSeconds = walk, estimated = est, cost = e.cost,
								legs = { { mode = "WALK", to = f.point, label = f.name, secs = w1 },
									{ mode = "FLIGHT", from = f.point, to = t.point, label = f.name .. " to " .. t.name, secs = fly + Tr.BOARD_SECONDS, estimated = est, cost = e.cost },
									{ mode = "WALK", from = t.point, to = b, secs = w2 } },
								why = "flight offered by the taxi map" }, Tr.MIN_GAIN)
						end
					end
				end
			end
		end
	end
	-- TRANSPORT (registered fixed edges)
	for _, e in ipairs(transports) do
		local w1 = walkSecs(ctx, a, e.from)
		local w2 = walkSecs(ctx, e.to, b)
		if w1 and w2 then
			consider({ mode = "TRANSPORT", seconds = w1 + e.secs + w2, walkSeconds = walk,
				legs = { { mode = "WALK", to = e.from, label = e.label, secs = w1 }, { mode = "TRANSPORT", from = e.from, to = e.to, label = e.label, secs = e.secs },
					{ mode = "WALK", from = e.to, to = b, secs = w2 } }, why = e.evidence }, walk and Tr.MIN_GAIN or 0)
		end
	end
	-- HEARTH
	if Tr.HearthState(ctx) == "READY" then
		local bind = Tr.Bind()
		if bind then
			local w2 = walkSecs(ctx, bind, b)
			if w2 then
				consider({ mode = "HEARTH", seconds = Tr.HEARTH_CAST_SECONDS + w2, walkSeconds = walk,
					legs = { { mode = "HEARTH", to = bind, label = bind.name or "your bind point", secs = Tr.HEARTH_CAST_SECONDS }, { mode = "WALK", from = bind, to = b, secs = w2 } },
					why = "Hearthstone ready, bind point learned" }, walk and Tr.HEARTH_MIN_GAIN or 0)
			end
		end
	end
	if best then best.saves = walk and (walk - best.seconds) or nil end
	return best
end

--- Seconds the planner should use for a leg: the better of walking and an evidenced route. `walk` is the walking estimate (nil = cannot walk).
function Tr.Seconds(ctx, a, b, walk)
	local r = Tr.Route(ctx, a, b)
	if r and (walk == nil or r.seconds < walk) then return r.seconds, r end
	return walk, nil
end

-- ---------------------------------------------------------------- steps for the plan

local function secsText(s)
	if s >= 90 then return string.format("about %d minutes", math.floor(s / 60 + 0.5)) end
	return string.format("about %d seconds", math.floor(s + 0.5))
end

--- The TRAVEL step(s) that carry out `route` toward `chosen`. Returns { steps = {...}, endPoint = point the character will be at afterwards }.
-- The first step's target is where the character must go first (the flight master, the bind teleport has none), so navigation leads there.
function Tr.Steps(route, chosen, d)
	local R = ns.Registry
	local first
	for _, leg in ipairs(route.legs) do if leg.mode ~= "WALK" then first = leg break end end
	if not first then return nil end
	local lines, title, target
	if route.mode == "FLIGHT" then
		local walkLeg = route.legs[1]
		target = { map = walkLeg.to.map, x = walkLeg.to.x, y = walkLeg.to.y, label = "Flight master: " .. tostring(walkLeg.label) }
		title = "Fly: " .. first.label
		lines = { "Go to the flight master at " .. tostring(walkLeg.label) .. ", then take the flight to " .. (tostring(first.label):match(" to (.+)$") or tostring(first.label)),
			string.format("About %s in all%s.", secsText(route.seconds), first.estimated and " (flight time is an estimate until you have flown it)" or ""),
			"Then: " .. chosen.title }
	elseif route.mode == "HEARTH" then
		target = nil
		title = "Use your Hearthstone"
		lines = { "Your Hearthstone is ready and takes you to " .. tostring(first.label) .. ".", string.format("Saves %s of walking. It has a long cooldown: skip it if you want to keep it.", secsText(route.saves or 0)),
			"Then: " .. chosen.title }
	else
		local walkLeg = route.legs[1]
		target = { map = walkLeg.to.map, x = walkLeg.to.x, y = walkLeg.to.y, label = tostring(first.label) }
		title = "Take " .. tostring(first.label)
		lines = { "Go to " .. tostring(first.label) .. ".", string.format("About %s in all.", secsText(route.seconds)), "Then: " .. chosen.title }
	end
	local step = R.NewAction({
		id = "T:" .. chosen.id, type = "TRAVEL", kind = "TRAVEL", forId = chosen.id, skipKey = chosen.skipKey, travelMode = route.mode,
		title = title, target = target, dist = d, src = chosen.src, verified = chosen.verified, lines = lines,
		reasons = { "Quicker than walking: " .. route.why },
	})
	local lastLeg = route.legs[#route.legs]
	local endPoint
	for i = #route.legs, 1, -1 do
		local leg = route.legs[i]
		if leg.mode ~= "WALK" then endPoint = leg.to break end
	end
	return { steps = { step }, endPoint = endPoint or lastLeg.to }
end

function Tr.ReportLines(ctx)
	local L = {}
	local nodes = 0
	for _ in pairs(nodePoints()) do nodes = nodes + 1 end
	local bind = Tr.Bind()
	local offered, completed = 0, 0
	for _, e in ipairs(ns.Taxi and ns.Taxi.Edges() or {}) do
		if e.state == "COMPLETED" then completed = completed + 1 else offered = offered + 1 end
	end
	L[#L + 1] = string.format("Travel model: walking baseline (%d yd/s); %d flight node(s) with a position; edges the planner can use: %d registered fixed transport(s) (boats / zeppelins: none ship), %d flight(s) completed and measured, %d flight(s) only offered (estimated time); hearth %s; bind point %s.",
		Tr.RUN_SPEED, nodes, #transports, completed, offered, Tr.HearthState(ctx), bind and string.format("learned (map %d)", bind.map) or "not learned")
	L[#L + 1] = "Travel limits: flights come only from edges a taxi map offered; no boat/zeppelin data is shipped, so none is routed; walking is a straight line."
	return L
end

--- Real-client checks for this system, one line each, with a plain result: PASS (the client answered / evidence exists), FAIL (the client cannot do it or answered nothing
-- useful) or PENDING (not tried yet: do the named thing in the game). A PENDING line is not a failure.
function Tr.Validation(ctx)
	local T, Sv = ns.Taxi, ns.Services
	local ts = T and T.Summary() or { nodes = 0, discovered = 0, listed = 0, edges = 0, measured = 0, matched = 0, proof = {}, opens = 0 }
	local sv = Sv and Sv.Summary() or { kinds = {}, entrances = 0, bind = false }
	local L = {}
	local function add(state, what, how) L[#L + 1] = string.format("[%s] %s%s", state, what, (state == "PENDING" and how) and (" -> " .. how) or "") end
	local anyApi = T and (T.Resolve("C_TaxiMap.GetAllTaxiNodes") or T.Resolve("C_TaxiMap.GetTaxiNodesForMap") or T.Resolve("NumTaxiNodes")) and true or false
	add(anyApi and "PASS" or "FAIL", "a taxi API exists on this client (C_TaxiMap or NumTaxiNodes)")
	local proven = false
	for _, v in pairs(ts.proof or {}) do if v == "PROVEN" then proven = true end end
	if proven then add("PASS", "the taxi map listed nodes when opened")
	elseif (ts.opens or 0) > 0 or (ts.stats and ts.stats.opened) then add("FAIL", "the taxi map was opened but no node could be read")
	else add("PENDING", "the taxi map listed nodes when opened", "open a flight master's map once") end
	add(ts.discovered > 0 and "PASS" or "PENDING", "discovered flight paths recorded (" .. ts.discovered .. ")", "open a flight master's map")
	add(ts.matched > 0 and "PASS" or (ts.nodes > 0 and "FAIL" or "PENDING"), "taxi nodes matched to Quest Flow's own flight data (" .. ts.matched .. " of " .. ts.nodes .. ")", "open a flight master's map")
	add(ts.nodes > 0 and "PASS" or "PENDING", "flight paths LISTED by the taxi map (" .. ts.nodes .. ")", "open a flight master's map")
	add(ts.offered > 0 and "PASS" or "PENDING", "direct flights recorded from where you stood, OFFERED by the map (" .. ts.offered .. ")", "open the map at a flight master that has a destination you have")
	add(ts.taken > 0 and (ts.unresolved < ts.taken and "PASS" or "FAIL") or "PENDING", "a flight was SELECTED and its destination resolved (" .. ts.taken .. " selected, " .. ts.unresolved .. " unresolved)", "take one flight")
	add(ts.started > 0 and "PASS" or ((ts.taken > 0) and "FAIL" or "PENDING"), "a flight STARTED (" .. ts.started .. ")", "take one flight")
	add(ts.completed > 0 and "PASS" or ((ts.started > 0) and "FAIL" or "PENDING"), "a flight COMPLETED (" .. ts.completed .. ", " .. ts.aborted .. " aborted)", "take one flight and wait to land")
	add(ts.measured > 0 and "PASS" or "PENDING", "a real flight time measured (" .. ts.measured .. ") - the MEASURED duration is recorded", "complete one flight")
	add(ts.measured > 0 and "PASS" or "PENDING", "an observed transport edge is registered for the planner (src client observation)", "complete one flight")
	add((T and T._hooked) and "PASS" or ((type(_G.TakeTaxiNode) == "function") and "FAIL" or "FAIL"), "the flight timer hook is installed (TakeTaxiNode post-hook)")
	for _, k in ipairs({ { "vendor", "a vendor window" }, { "trainer", "a trainer window" }, { "flightmaster", "a flight master" }, { "innkeeper", "an innkeeper" } }) do
		local n = sv.kinds[k[1]] or 0
		add(n > 0 and "PASS" or "PENDING", k[2] .. " recorded (" .. n .. ")", "open one")
	end
	add(sv.entrances > 0 and "PASS" or "PENDING", "a dungeon entrance recorded (" .. sv.entrances .. ")", "enter a dungeon from outside")
	add(sv.bind and "PASS" or "PENDING", "a bind point learned from binding", "bind at an innkeeper")
	local hs = Tr.HearthState(ctx)
	add(hs ~= "UNKNOWN" and "PASS" or "FAIL", "the Hearthstone state is readable (" .. hs:lower() .. ")")
	add((ctx and ctx.char and type(ctx.char.money) == "number") and "PASS" or "FAIL", "money is readable")
	return L
end

function Tr._Reset() pointCache, cacheVersion = nil, nil end
