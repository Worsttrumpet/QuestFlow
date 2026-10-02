-- ForeverCodex.Providers.Quest: turns quest data + your quest log into QUEST actions.
--
--   not in your log, available to you  -> ACCEPT   (at the giver's location)
--   in your log, objectives complete   -> TURN_IN  (assumed at the giver: ATT has no turn-in NPC field)
--   in your log, objectives incomplete -> OBJECTIVE
--
-- Eligibility uses ONLY facts the data actually has. ATT's `lvl` is a REQUIRED level (stored as `req`), never a
-- quest level. Class / race / faction come from ATT restrictions. Prerequisites come from ATT `sourceQuest`
-- (treated as ANY-OF when several are listed, because the parser does not distinguish a single sourceQuest from a
-- list; this errs towards showing a quest rather than hiding it, and the player can always Skip).
--
-- Provenance: an action's `src` / `verified` describe where its LOCATION came from. ATT locations are never
-- marked verified; the observed layer's `pos` (a player position at a recorder checkpoint) is used only as a
-- labelled approximate fallback.

local addonName, ns = ...
local C = ForeverCodex
local R = ns.Registry
local P = ns.Prefs
local K = ns.Contract

local Q = {}
ns.QuestProvider = Q

C.RegisterActionType("QUEST", { label = "Quest" })

local function bump(stats, key)
	stats.filtered[key] = (stats.filtered[key] or 0) + 1
end

local function contains(list, value)
	for _, v in ipairs(list) do
		if v == value then return true end
	end
	return false
end

--- Can this character take this quest? Returns true, or false + the reason key used in diagnostics.
function Q.Eligibility(view, ctx, strategy)
	local ch = ctx.char
	if view.repeatable then return false, "repeatable" end
	if view.faction and ch.faction and view.faction ~= ch.faction then return false, "faction" end
	if view.races and ch.raceKey and not contains(view.races, ch.raceKey) then return false, "race" end
	if view.classes and ch.classToken and not contains(view.classes, ch.classToken:upper()) then return false, "class" end
	local lvl = ch.level
	if lvl and view.req and lvl < view.req then return false, "level" end
	local maxGap = strategy and strategy.w and strategy.w.maxGap
	local fit = view.level or view.req
	if lvl and fit and maxGap and (lvl - fit) > maxGap then return false, "tooLow" end
	if not view.loc then return false, "noLocation" end
	if view.prereq then
		local any = false
		for _, pid in ipairs(view.prereq) do
			if ctx.isCompleted(pid) then any = true break end
		end
		if not any then return false, "prereq" end
	end
	-- a quest that needs SEVERAL earlier quests (QuestieDB's "group" prerequisites): all of them
	if view.prereqAll then
		for _, pid in ipairs(view.prereqAll) do
			if not ctx.isCompleted(pid) then return false, "prereq" end
		end
	end
	return true
end

local function placeLabel(view)
	local npc = view.giverName or (view.giverNpc and ("NPC #" .. view.giverNpc)) or "quest giver"
	if view.loc then
		return npc .. " (" .. R.MapLabel(view.loc.map) .. ")"
	end
	return npc
end

local function coordText(loc)
	return string.format("%.1f, %.1f", loc.x * 100, loc.y * 100)
end

--- The player-facing name of a data source (never says "confirmed": only observed Forever data is ever treated as verified).
local SRC_NAMES = { att = "ATT", questiedb = "QuestieDB" }
local function srcName(src) return SRC_NAMES[src] or tostring(src or "unknown source") end

--- Provenance wording shown to the player. Third-party data is "unverified"; nothing here says "confirmed" about it.
local function provenanceLines(view)
	local lines = {}
	local loc = view.loc
	if loc then
		if loc.src == "observed" then
			lines[#lines + 1] = "Location: approx " .. coordText(loc) .. " (player position seen on Forever, not the NPC)"
		else
			lines[#lines + 1] = "Location: " .. coordText(loc) .. " (" .. srcName(loc.src) .. ", unverified on Forever)"
		end
	end
	if view.req then
		lines[#lines + 1] = "Requires level " .. view.req .. " (" .. srcName(view.prov and view.prov.req) .. ", unverified)"
	end
	if view.level and view.prov.level == "observed" then
		lines[#lines + 1] = "Quest level " .. view.level .. " (observed on Forever)"
	end
	return lines
end

local function target(view, label)
	local loc = view.loc
	if not loc then return nil end
	return { map = loc.map, x = loc.x, y = loc.y, label = label, src = loc.src, verified = loc.verified,
		approx = loc.kind == "player_position" }
end

local function describeObjectives(view, lines)
	if view.objectives then
		for _, o in ipairs(view.objectives) do
			if o and o ~= "" then lines[#lines + 1] = "Objective: " .. o end
		end
	end
end

local function prereqLine(view)
	if not view.prereq then return nil end
	local names = {}
	for _, pid in ipairs(view.prereq) do
		local pv = R.Quest(pid)
		names[#names + 1] = pv and pv.name or ("quest " .. pid)
		if #names >= 2 then break end
	end
	return "Follows: " .. table.concat(names, " / ")
end


-- ---------------------------------------------------------------- structured contract (dual-written, Phase 1)
-- The legacy fields above are what the Engine and the UI use and are unchanged. These add the structured
-- Action/Target contract (see Contract.lua) next to them. Nothing here changes a decision.

local REACHES = { ACCEPT = "ACCEPTED", OBJECTIVE = "OBJECTIVES", TURN_IN = "TURNED_IN" }

local function giverEntity(view)
	if view and (view.giverNpc or view.giverName) then
		return { kind = "npc", id = view.giverNpc, name = view.giverName, prov = view.prov and (view.prov.giverNpc or view.prov.giverName) or nil }
	end
	return { kind = "unknown" }
end

--- The targets of one quest action. `t` is the LEGACY target the action already carries (or nil).
local function questTargets(a, view, t)
	if a.kind == "ACCEPT" then
		return { K.FromLegacyTarget(t, "GIVER", { entity = giverEntity(view) }) }
	elseif a.kind == "TURN_IN" then
		-- ATT has no turn-in NPC: the turn-in is ASSUMED to be at the giver, so it is at best approximate
		return { K.FromLegacyTarget(t, "TURN_IN", { entity = giverEntity(view), assumed = true, status = t and "approx" or nil, kind = "assumed_giver" }) }
	end
	-- OBJECTIVE: every known objective coordinate, as ONE area target. ATT's coordinate list is not indexed by
	-- objective (the mapping has no evidence), so the points are not alternatives and are not tied to an objective.
	local pts = {}
	for _, oc in ipairs(view and view.objCoords or {}) do
		if type(oc.map) == "number" and type(oc.x) == "number" and type(oc.y) == "number" then pts[#pts + 1] = { map = oc.map, x = oc.x, y = oc.y } end
	end
	local src = view and view.prov and view.prov.objCoords or "att"
	local target = K.Target({ role = "OBJECTIVE", entity = { kind = "area" }, where = K.Where("approx", pts, "area"), prov = K.Prov(src) })
	if target.where.status ~= "unknown" then target.where.indexed = false end
	if target.where.status == "unknown" then target.entity = { kind = "unknown" }; target.prov = { src = "unknown", verified = false } end
	return { target }
end

local function attach(a, id, view, ctx, t)
	local st = K.QuestState(id, view, ctx)
	local entry = ctx.log[id]
	return K.Attach(a, {
		ref = { kind = "quest", id = id }, state = st.state, stateWhy = st.why, skip = P.QuestSkipState(id),
		targets = questTargets(a, view, t), requirements = st.requirements,
		completion = { watch = "quest", id = id, reaches = REACHES[a.kind] },
		objectiveState = entry and K.ObjectiveState(entry.objectives) or nil,
		optional = false, prov = { name = view and view.prov and view.prov.name or nil, state = "client" },
	})
end

local function acceptAction(view, pinned, ctx)
	local label = placeLabel(view)
	local lines = {}
	lines[1] = "Talk to " .. label
	for _, l in ipairs(provenanceLines(view)) do lines[#lines + 1] = l end
	describeObjectives(view, lines)
	local pl = prereqLine(view)
	if pl then lines[#lines + 1] = pl end
	local t = target(view, label)
	return attach(R.NewAction({
		id = "Q:" .. view.id .. ":ACCEPT", type = "QUEST", kind = "ACCEPT", quest = view.id, skipKey = "Q:" .. view.id, name = view.name,
		title = "Accept: " .. (view.name or ("quest " .. view.id)), reqLevel = view.req, level = view.level,
		breadcrumb = view.breadcrumb, target = t, pinned = pinned or false, lines = lines,
		src = t and t.src or view.src, verified = t and t.verified or false, nameSrc = view.prov.name,
		giver = view.giverName,
	}), view.id, view, ctx, t)
end

local function progressAction(view, entry, pinned, ctx)
	local complete = entry.complete
	local name = view.name or entry.title or ("quest " .. entry.id)
	local label = placeLabel(view)
	local lines = {}
	local t
	if complete then
		lines[1] = "Objectives complete. Turn in to " .. label
		for _, l in ipairs(provenanceLines(view)) do lines[#lines + 1] = l end
		lines[#lines + 1] = "Turn-in location is assumed to be the giver's (no turn-in data)."
		t = target(view, label)
	else
		describeObjectives(view, lines)
		if #lines == 0 then lines[1] = "In your quest log. Objective details are not in Codex data." end
		local oc = view.objCoords and view.objCoords[1]
		if oc then
			t = { map = oc.map, x = oc.x, y = oc.y, label = "objective area (" .. R.MapLabel(oc.map) .. ")", src = "att", verified = false }
			lines[#lines + 1] = "Objective area: " .. coordText(oc) .. " (ATT, unverified)"
		end
	end
	return attach(R.NewAction({
		id = "Q:" .. view.id .. (complete and ":TURN_IN" or ":OBJECTIVE"), type = "QUEST", kind = complete and "TURN_IN" or "OBJECTIVE",
		quest = view.id, skipKey = "QT:" .. view.id, name = view.name or entry.title, title = (complete and "Turn in: " or "Continue: ") .. name,
		level = view.level, reqLevel = view.req, target = t, pinned = pinned or false, lines = lines,
		src = t and t.src or view.src, verified = t and t.verified or false, nameSrc = view.prov.name, giver = view.giverName,
		noLocation = t == nil,
	}), view.id, view, ctx, t)
end

--- A quest in the player's log that no pack knows: still worth a reminder (e.g. turn-in), never a guess at where.
local function unknownLogAction(entry, ctx)
	local complete = entry.complete
	return attach(R.NewAction({
		id = "Q:" .. entry.id .. (complete and ":TURN_IN" or ":OBJECTIVE"), type = "QUEST", kind = complete and "TURN_IN" or "OBJECTIVE",
		quest = entry.id, skipKey = "QT:" .. entry.id, name = entry.title, title = (complete and "Turn in: " or "Continue: ") .. (entry.title or ("quest " .. entry.id)),
		lines = { "This quest is not in Codex data yet, so there is no location to show." }, src = "log", verified = false,
		noLocation = true, unknown = true,
	}), entry.id, nil, ctx, nil)
end

local function addedUnknown(id, ctx)
	return attach(R.NewAction({
		id = "Q:" .. id .. ":ACCEPT", type = "QUEST", kind = "ACCEPT", quest = id, skipKey = "Q:" .. id,
		title = "Added by you: quest " .. id, pinned = true, noLocation = true, unknown = true, src = "player", verified = false,
		lines = { "You added this quest. It is not in Codex data, so there is no location to show." },
	}), id, nil, ctx, nil)
end

function Q.Generate(ctx, env)
	local out = {}
	local stats = env.stats
	local strategy = env.strategy
	local added = {}
	for _, id in ipairs(P.AddedList()) do added[id] = true end

	for _, id in ipairs(R.QuestIds()) do
		local view = R.Quest(id)
		local entry = ctx.log[id]
		local pinned = added[id] == true
		if not view then
			-- a live source (QuestieDB) can list an id it then cannot read: unknown, skipped here. (A quest in the player's log or added
			-- by the player is still handled below as one no pack knows.)
			bump(stats, "unreadable")
		elseif entry then
			if P.IsSkipped("QT:" .. id) then
				bump(stats, "skipped")
			else
				out[#out + 1] = progressAction(view, entry, pinned, ctx)
			end
		elseif pinned then
			if not ctx.isCompleted(id) then
				out[#out + 1] = acceptAction(view, true, ctx)
			else
				bump(stats, "completed")
			end
		elseif P.IsSkipped("Q:" .. id) then
			bump(stats, "skipped")
		else
			local ok, why = Q.Eligibility(view, ctx, strategy)
			if not ok then
				bump(stats, why)
			elseif ctx.isCompleted(id) then
				bump(stats, "completed")
			else
				out[#out + 1] = acceptAction(view, false, ctx)
			end
		end
	end

	-- Quests the player holds or added that no pack knows.
	for id, entry in pairs(ctx.log) do
		if not R.Quest(id) and not P.IsSkipped("QT:" .. id) then
			out[#out + 1] = unknownLogAction(entry, ctx)
		end
	end
	for id in pairs(added) do
		if not R.Quest(id) and not ctx.log[id] and not P.IsSkipped("Q:" .. id) then
			out[#out + 1] = addedUnknown(id, ctx)
		end
	end
	return out
end

C.RegisterProvider({ key = "quest", type = "QUEST", label = "Quests", generate = Q.Generate })
