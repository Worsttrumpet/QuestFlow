-- ForeverCodex.Contract: the structured ACTION / TARGET contract (Planner migration, Phase 1).
--
-- PURE: no client calls, no saved state, no scoring. It defines the shapes, builds them, classifies quest state,
-- and checks them. Providers dual-write these fields next to the legacy ones (id, type, kind, title, lines,
-- target, src, verified, ...), so the Engine and the UI behave exactly as before; a future Planner reads only this.
--
-- An action is an immutable FACT record. Nothing in it is a score, a distance, a rank or a recommendation. (The
-- Engine still writes its own "_"-prefixed scratch fields and `reasons` on the action table during Compute; it
-- never touches the contract fields, and the tests assert that.)
--
--   contract = 1
--   ref          { kind = "quest"|"flightNode"|..., id = <number> }   identity of the thing; NEVER a name
--   state        AVAILABLE | ACTIVE | READY | COMPLETED | BLOCKED | UNKNOWN     (what the game says; see QuestState)
--   stateWhy     optional reason code (BLOCKED / UNKNOWN)
--   skip         { logical = bool, keys = { "Q:12", "QT:12" } }       the player's veto, across BOTH legacy keys
--   targets      list of Target (may be empty). A quest has a GIVER, OBJECTIVE and/or TURN_IN target.
--   requirements list of { kind, ..., result = true|false|nil, prov }  nil = unknown, never coerced
--   completion   { watch = "quest", id = <questID>, reaches = "ACCEPTED"|"OBJECTIVES"|"TURNED_IN" } | nil
--   objectiveState  { known, list = { {text,type,finished,have,need} }, summary }   quest-LOG state; never in a Target
--   optional     true for opportunities that are never required (e.g. flight discovery)
--   prov         per-field provenance: { name = "att"|"observed"|nil, state = "client"|"log"|... }
--   evidence     "observed" | "mixed" | "unverified" | "unknown"   DERIVED weakest link; never set by hand
--
-- Target
--   role         GIVER | OBJECTIVE | TURN_IN | SERVICE | AREA | DESTINATION
--   service      for SERVICE: "FLIGHT" | "TRAINER" | "VENDOR" | "INN" | ...
--   entity       { kind = "npc"|"object"|"area"|"unknown", id = number|nil, name = string|nil, prov = string|nil }
--   where        { status = "known"|"approx"|"unknown", points = { {map,x,y}, ... }, kind = "exact"|"area"|
--                  "player_position"|"assumed_giver" }.   status "unknown" carries NO coordinates.
--   assumed      true when the location is an assumption (a turn-in assumed to be at the giver)
--   prov         { src = "att"|"observed"|"estimated"|"log"|"player"|..., verified = bool }
--
-- Provenance rule: `verified` is true only for src == "observed". This module never upgrades it: Evidence() can
-- only be as strong as the weakest input.

local addonName, ns = ...

local K = {}
ns.Contract = K

K.VERSION = 1

K.STATES = { AVAILABLE = true, ACTIVE = true, READY = true, COMPLETED = true, BLOCKED = true, UNKNOWN = true }
K.ROLES = { GIVER = true, OBJECTIVE = true, TURN_IN = true, SERVICE = true, AREA = true, DESTINATION = true }
K.STATUS = { known = true, approx = true, unknown = true }
K.EVIDENCE = { observed = true, mixed = true, unverified = true, unknown = true }

-- ---------------------------------------------------------------- provenance

--- { src, verified }. `verified` is true ONLY for observed Forever data; ATT, estimated, log, player data never is.
function K.Prov(src)
	return { src = src, verified = src == "observed" }
end

-- ---------------------------------------------------------------- targets

local function pointsOf(map, x, y)
	if type(map) == "number" and type(x) == "number" and type(y) == "number" then
		return { { map = map, x = x, y = y } }
	end
	return nil
end

--- A where-record. status "unknown" never has coordinates.
function K.Where(status, points, kind)
	if status == "unknown" or not points or #points == 0 then
		return { status = "unknown" }
	end
	return { status = status, points = points, kind = kind or "exact" }
end

--- Builds a Target. spec: role, service, entity, where, assumed, prov.
function K.Target(spec)
	local t = { role = spec.role, where = spec.where or K.Where("unknown") }
	t.service = spec.service
	t.entity = spec.entity or { kind = "unknown" }
	t.assumed = spec.assumed or nil
	t.prov = spec.prov or { src = "unknown", verified = false }
	return t
end

--- Converts a LEGACY action target ({ map, x, y, label, src, verified, approx } or nil) into a contract Target.
-- A nil legacy target becomes an explicit "unknown" target: an action can exist without a usable location.
-- opts: entity, assumed (turn-in assumed at the giver), kind, status (override), service.
function K.FromLegacyTarget(t, role, opts)
	opts = opts or {}
	if not t or type(t.map) ~= "number" then
		return K.Target({ role = role, service = opts.service, entity = opts.entity, assumed = opts.assumed })
	end
	local status = opts.status or (t.approx and "approx" or "known")
	local kind = opts.kind or (t.approx and "player_position" or "exact")
	local src = t.src or "unknown"
	return K.Target({
		role = role, service = opts.service, entity = opts.entity, assumed = opts.assumed,
		where = K.Where(status, pointsOf(t.map, t.x, t.y), kind),
		-- the legacy `verified` flag is honoured only if it agrees with the rule (never upgraded)
		prov = { src = src, verified = (src == "observed") and t.verified == true },
	})
end

-- ---------------------------------------------------------------- requirements

--- true/false when the character field is known, nil when it is not. (`a and b or nil` would turn false into nil.)
local function tri(known, value)
	if not known then return nil end
	return value
end

local function req(kind, fields, result, src)
	local r = { kind = kind, result = result, prov = { src = src, verified = src == "observed" } }
	for k, v in pairs(fields) do r[k] = v end
	return r
end

--- Requirements the DATA states for a quest view, evaluated against the context. result is true / false / nil
-- (nil = cannot tell: the character field or the data is missing). Same facts, same order, as the quest
-- provider's eligibility test.
function K.QuestRequirements(view, ctx)
	local out = {}
	local ch = ctx.char
	local pv = view.prov or {}
	if view.faction then
		out[#out + 1] = req("faction", { value = view.faction }, tri(ch.faction, ch.faction == view.faction), pv.faction)
	end
	if view.races then
		local r
		if ch.raceKey then
			r = false
			for _, k in ipairs(view.races) do if k == ch.raceKey then r = true break end end
		end
		out[#out + 1] = req("race", { anyOf = view.races }, r, pv.races)
	end
	if view.classes then
		local r
		if ch.classToken then
			r = false
			for _, k in ipairs(view.classes) do if k == ch.classToken:upper() then r = true break end end
		end
		out[#out + 1] = req("class", { anyOf = view.classes }, r, pv.classes)
	end
	if view.req then
		-- ATT `lvl` is a REQUIRED level, never a quest level
		out[#out + 1] = req("level", { min = view.req }, tri(ch.level, ch.level and ch.level >= view.req), pv.req)
	end
	if view.prereq then
		-- ATT does not distinguish one sourceQuest from a list, so several are treated as ANY-OF
		local any = false
		for _, pid in ipairs(view.prereq) do
			if ctx.isCompleted(pid) then any = true break end
		end
		out[#out + 1] = req("prereqQuest", { anyOf = view.prereq }, any, pv.prereq)
	end
	return out
end

-- ---------------------------------------------------------------- quest state

local FALSE_ORDER = { faction = 1, race = 2, class = 3, level = 4, prereqQuest = 5 }
local WHY = { faction = "FACTION", race = "RACE", class = "CLASS", level = "LEVEL_TOO_LOW", prereqQuest = "PREREQ_MISSING" }

--- Classifies one quest by ID from game state. Returns { state, why, requirements, repeatable }.
--   in the quest log, objectives done   READY
--   in the quest log                    ACTIVE
--   flagged completed                   COMPLETED   (relies on C_QuestLog.IsQuestFlaggedCompleted, which is NOT yet
--                                                    verified on Forever at startup; see CODEX_PLANNER_DESIGN.md)
--   no data and not in the log          UNKNOWN (NO_DATA)
--   quest log unreadable                UNKNOWN (LOG_UNAVAILABLE): we cannot tell available from active
--   a stated requirement is false       BLOCKED (first false, in the eligibility order)
--   otherwise                           AVAILABLE
-- SKIPPED is not a game state: it is the player's veto, reported separately (see K.Effective).
function K.QuestState(id, view, ctx)
	local entry = ctx.log and ctx.log[id]
	local out = { requirements = {} }
	if entry then
		out.state = entry.complete and "READY" or "ACTIVE"
		if view then out.requirements = K.QuestRequirements(view, ctx) end
		return out
	end
	if ctx.isCompleted(id) then
		out.state = "COMPLETED"
		return out
	end
	if not view then
		out.state, out.why = "UNKNOWN", "NO_DATA"
		return out
	end
	out.repeatable = view.repeatable == true
	out.requirements = K.QuestRequirements(view, ctx)
	if not ctx.logAvailable then
		out.state, out.why = "UNKNOWN", "LOG_UNAVAILABLE"
		return out
	end
	local worst
	for _, r in ipairs(out.requirements) do
		if r.result == false and (not worst or FALSE_ORDER[r.kind] < FALSE_ORDER[worst.kind]) then worst = r end
	end
	if worst then
		out.state, out.why = "BLOCKED", WHY[worst.kind]
	else
		out.state = "AVAILABLE"
	end
	return out
end

local PLANNABLE = { AVAILABLE = true, ACTIVE = true, READY = true }

--- The state the player's veto turns a plannable state into. COMPLETED / BLOCKED / UNKNOWN stay as they are.
function K.Effective(state, skipped)
	if skipped and PLANNABLE[state] then return "SKIPPED" end
	return state
end

--- A future planner may only sequence an action whose effective state is AVAILABLE, ACTIVE or READY.
function K.Plannable(state, skipped)
	return PLANNABLE[state] == true and not skipped
end

-- ---------------------------------------------------------------- skip: one logical state over two legacy keys

local function questKeys(id) return "Q:" .. id, "QT:" .. id end

--- { logical, keys } for a quest, given the raw skipped table ({ ["Q:12"] = true, ["QT:12"] = true, ["FP:25"] = true }).
function K.SkipState(skipped, id)
	local keys = {}
	local a, b = questKeys(id)
	if skipped[a] == true then keys[#keys + 1] = a end
	if skipped[b] == true then keys[#keys + 1] = b end
	return { logical = #keys > 0, keys = keys }
end

--- Collapses the legacy keys into one logical entry per quest ID. Returns a NEW table { quests = { [id] = true },
-- other = { "FP:25", ... } }. Pure; nothing in the addon applies it yet (the saved table is left exactly as it is).
function K.LogicalSkips(skipped)
	local out = { quests = {}, other = {} }
	for key, v in pairs(skipped or {}) do
		if v == true then
			local id = key:match("^QT?:(%d+)$")
			if id then out.quests[tonumber(id)] = true else out.other[#out.other + 1] = key end
		end
	end
	table.sort(out.other)
	return out
end

--- What the saved table would look like after migration to ONE canonical "Q:<id>" key per skipped quest.
-- Returns a NEW table; unrelated keys are kept as they are.
function K.CollapseSkips(skipped)
	local l = K.LogicalSkips(skipped)
	local out = {}
	for id in pairs(l.quests) do out["Q:" .. id] = true end
	for _, k in ipairs(l.other) do out[k] = true end
	return out
end

--- "Add clears Skip": a NEW table with both legacy keys of the quest removed.
function K.AddClearsSkip(skipped, id)
	local out = {}
	local a, b = questKeys(id)
	for k, v in pairs(skipped or {}) do
		if k ~= a and k ~= b then out[k] = v end
	end
	return out
end

-- ---------------------------------------------------------------- objective progress (quest-log state)

--- Normalises the client's objective list ({ text, type, finished, numFulfilled, numRequired }) into
-- { known, list, summary }. summary: "none" | "partial" | "complete" | "unknown". An empty/absent list is UNKNOWN
-- (not "complete"): an empty list proves nothing.
function K.ObjectiveState(raw)
	if type(raw) ~= "table" or #raw == 0 then
		return { known = false, list = {}, summary = "unknown" }
	end
	local list, done, started = {}, 0, false
	for i, o in ipairs(raw) do
		local have, need = o.numFulfilled or o.have, o.numRequired or o.need
		local finished = o.finished == true or (type(have) == "number" and type(need) == "number" and need > 0 and have >= need)
		list[i] = { text = o.text, type = o.type, finished = finished, have = have, need = need }
		if finished then done = done + 1 end
		if finished or (type(have) == "number" and have > 0) then started = true end
	end
	local summary = "none"
	if done == #list then summary = "complete" elseif started then summary = "partial" end
	return { known = true, list = list, summary = summary }
end

-- ---------------------------------------------------------------- evidence (derived, weakest link)

--- observed: every input is verified observed data and nothing is assumed
--- unverified: no input is verified
--- mixed: some are
--- unknown: the action has no known location and no stated requirement to judge
-- Inputs are the targets whose location is known/approx and the requirements whose result is known. An ASSUMED
-- location counts as unverified whatever its source. Adding an input can never make the label stronger.
function K.Evidence(a)
	local n, verified = 0, 0
	for _, t in ipairs(a.targets or {}) do
		if t.where and t.where.status ~= "unknown" then
			n = n + 1
			if t.prov and t.prov.verified == true and not t.assumed then verified = verified + 1 end
		end
	end
	for _, r in ipairs(a.requirements or {}) do
		if r.result ~= nil then
			n = n + 1
			if r.prov and r.prov.verified == true then verified = verified + 1 end
		end
	end
	if n == 0 then return "unknown" end
	if verified == n then return "observed" end
	if verified == 0 then return "unverified" end
	return "mixed"
end

-- ---------------------------------------------------------------- attach / validate

--- Writes the contract fields onto a legacy action. f: ref, state, stateWhy, skip, targets, requirements,
-- completion, objectiveState, optional, prov. Existing fields are never touched.
function K.Attach(a, f)
	a.contract = K.VERSION
	a.ref, a.state, a.stateWhy, a.skip = f.ref, f.state, f.stateWhy, f.skip
	a.targets, a.requirements = f.targets or {}, f.requirements or {}
	a.completion, a.objectiveState = f.completion, f.objectiveState
	a.optional = f.optional == true
	a.prov = f.prov or {}
	a.evidence = K.Evidence(a)
	return a
end

local function isNum(v) return type(v) == "number" and v == v and v ~= math.huge and v ~= -math.huge end

--- Structural check. Returns a list of problems (empty = valid). Used by the tests over every provider output.
function K.Validate(a)
	local p = {}
	local function bad(msg) p[#p + 1] = tostring(a.id) .. ": " .. msg end
	if a.contract ~= K.VERSION then bad("no contract version") return p end
	if type(a.id) ~= "string" or a.id == "" then bad("id") end
	if type(a.type) ~= "string" then bad("type") end
	if type(a.ref) ~= "table" or type(a.ref.kind) ~= "string" or not isNum(a.ref.id) then bad("ref must be { kind, id = number }") end
	if not K.STATES[a.state] then bad("state " .. tostring(a.state)) end
	if a.state == "BLOCKED" and type(a.stateWhy) ~= "string" then bad("BLOCKED needs stateWhy") end
	if type(a.skip) ~= "table" and a.ref and a.ref.kind == "quest" then bad("quest action needs skip") end
	if a.ref and a.ref.kind == "quest" then
		if a.id:find("^Q:" .. a.ref.id .. ":") == nil then bad("quest action id must embed the quest ID") end
		if type(a.completion) ~= "table" or a.completion.id ~= a.ref.id then bad("quest action needs completion by quest ID") end
	end
	if type(a.targets) ~= "table" then bad("targets") return p end
	for i, t in ipairs(a.targets) do
		local w = "target " .. i .. ": "
		if not K.ROLES[t.role] then bad(w .. "role " .. tostring(t.role)) end
		if t.progress ~= nil then bad(w .. "objective progress must not live on a Target") end
		local where = t.where
		if type(where) ~= "table" or not K.STATUS[where.status] then bad(w .. "where.status") else
			if where.status == "unknown" then
				if where.points ~= nil or where.x ~= nil or where.y ~= nil or where.map ~= nil then bad(w .. "unknown location must carry no coordinates") end
			else
				if type(where.points) ~= "table" or #where.points == 0 then bad(w .. "known/approx needs points") else
					for _, pt in ipairs(where.points) do
						if not (isNum(pt.map) and isNum(pt.x) and isNum(pt.y)) then bad(w .. "point needs map, x, y") end
					end
				end
				if not (t.prov and t.prov.src and t.prov.src ~= "unknown") then bad(w .. "a located target needs a provenance source") end
			end
		end
		if t.prov and t.prov.verified == true and t.prov.src ~= "observed" then bad(w .. "flagged trusted without an observed source") end
	end
	for i, r in ipairs(a.requirements) do
		if type(r.kind) ~= "string" then bad("requirement " .. i .. " kind") end
		if r.result ~= nil and type(r.result) ~= "boolean" then bad("requirement " .. i .. " result must be true/false/nil") end
		if r.prov and r.prov.verified == true and r.prov.src ~= "observed" then bad("requirement " .. i .. " flagged trusted without an observed source") end
	end
	if not K.EVIDENCE[a.evidence] then bad("evidence") end
	if a.evidence ~= K.Evidence(a) then bad("evidence is derived and does not match its inputs") end
	return p
end
