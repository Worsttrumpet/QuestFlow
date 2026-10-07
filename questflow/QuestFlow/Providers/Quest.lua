-- ForeverCodex.Providers.Quest: turns quest data + your quest log into QUEST actions.
--
--   not in your log, available to you  -> ACCEPT   (at the giver's location)
--   in your log, objectives complete   -> TURN_IN  (at the turn-in NPC when the data names one; at the giver only when the data says they are the same NPC; else no location)
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
	-- a holiday / world-event quest is only possible while its event is on, and Codex cannot tell that: it is not offered. (A quest in the
	-- log, or one the player added, never comes through here, so those still show. The player can opt in to seasonal quests (/qflow seasonal on); they are then only routed on a client offer.)
	if view.event and not (P.IncludeSeasonal and P.IncludeSeasonal()) then return false, "event" end
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

--- The map a quest broadly belongs to (QuestieDB's zone for it, else the zone of an ATT record), or nil. Not a destination: only "around here or not".
local function areaMapOf(view)
	if not view then return nil end
	if view.zoneMap then return view.zoneMap end
	local z = view.zone and R.ZoneByKey(view.zone)
	return z and z.map or nil
end

--- Where a COMPLETED quest is handed in, kept separate from where it was given. The giver and the turn-in NPC are different
-- things and are often in different places (a recruiter in one city sends you to an officer in another):
--   "known"     QuestieDB names a turn-in NPC that is not the giver and says where it stands: route to THAT place
--   "unplaced"  the turn-in NPC is known and is not the giver, but its position is not: no location at all (the giver's spot would be wrong)
--   "assumed"   the data says the turn-in NPC IS the giver: the giver's location (QuestieDB's own record, unverified on Forever; trusted a little less)
--   "unknown"   there is no turn-in data (ATT has no turn-in field; QuestieDB may not name a creature finisher): NO location. A known giver position is evidence of where the
--               quest was given, not of where it is handed in, so it is never borrowed for the hand-in (Q264: the giver stood in Thunder Bluff, the hand-in was in Silverpine).
--               The game's own quest-map point, when it shows one, is still used (progressAction).
local function turnInPlace(view)
	local ti = view and view.turnIn                        -- (a quest in the log that no pack knows has no view at all)
	if type(ti) ~= "table" or not (ti.npc or ti.name) then return "unknown" end
	if ti.atGiver or (ti.atGiver == nil and ti.npc and view.giverNpc and ti.npc == view.giverNpc) then return "assumed" end
	local name = ti.name or ("NPC #" .. tostring(ti.npc))
	if type(ti.map) == "number" and type(ti.x) == "number" and type(ti.y) == "number" then
		return "known", { npc = ti.npc, name = name, loc = { map = ti.map, x = ti.x, y = ti.y, src = (view.prov and view.prov.turnIn) or "questiedb", verified = false, kind = "turn_in" } }
	end
	return "unplaced", { npc = ti.npc, name = name }
end

--- Provenance wording shown to the player. Third-party data is "unverified"; nothing here says "confirmed" about it.
-- `loc` is the location to describe (default: the giver's); false = none.
local function provenanceLines(view, loc)
	local lines = {}
	if loc == nil then loc = view.loc end
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
	local fromGame = t and t.src == "game"
	if a.kind == "TURN_IN" and fromGame then
		-- the game's quest map says where this hand-in is (used only when no turn-in NPC position is known)
		return { K.FromLegacyTarget(t, "TURN_IN", { entity = giverEntity(view), status = "approx", kind = "game_point" }) }
	end
	if a.kind == "ACCEPT" then
		return { K.FromLegacyTarget(t, "GIVER", { entity = giverEntity(view) }) }
	elseif a.kind == "TURN_IN" then
		local kind, place = turnInPlace(view)
		if kind == "known" then
			return { K.FromLegacyTarget(t, "TURN_IN", { entity = { kind = "npc", id = place.npc, name = place.name, prov = view.prov and view.prov.turnIn or nil } }) }
		elseif kind == "unplaced" then
			return { K.FromLegacyTarget(nil, "TURN_IN", { entity = { kind = "npc", id = place.npc, name = place.name, prov = view.prov and view.prov.turnIn or nil } }) }
		end
		if kind == "unknown" then
			-- nothing says who takes the quest back: no location, and no NPC (the giver is not named as the hand-in)
			return { K.FromLegacyTarget(nil, "TURN_IN", { entity = { kind = "unknown" } }) }
		end
		-- the data says the turn-in NPC is the giver: that spot is the hand-in, approximate and unverified
		return { K.FromLegacyTarget(t, "TURN_IN", { entity = giverEntity(view), assumed = true, status = t and "approx" or nil, kind = "assumed_giver" }) }
	end
	-- OBJECTIVE: every known objective coordinate, as ONE area target. ATT's coordinate list is not indexed by
	-- objective (the mapping has no evidence), so the points are not alternatives and are not tied to an objective.
	local pts = {}
	for _, oc in ipairs(view and view.objCoords or {}) do
		if type(oc.map) == "number" and type(oc.x) == "number" and type(oc.y) == "number" then pts[#pts + 1] = { map = oc.map, x = oc.x, y = oc.y } end
	end
	local src = view and view.prov and view.prov.objCoords or "att"
	if #pts == 0 and fromGame then
		pts[1] = { map = t.map, x = t.x, y = t.y }          -- no objective coordinates anywhere else: the game's own quest-map point
		src = "game"
	end
	local target = K.Target({ role = "OBJECTIVE", entity = { kind = "area" }, where = K.Where("approx", pts, "area"), prov = K.Prov(src) })
	if target.where.status ~= "unknown" then target.where.indexed = false end
	if target.where.status == "unknown" then target.entity = { kind = "unknown" }; target.prov = { src = "unknown", verified = false } end
	return { target }
end

local function attach(a, id, view, ctx, t)
	local st = K.QuestState(id, view, ctx)
	local entry = ctx.log[id]
	return K.Attach(a, {
		ref = { kind = "quest", id = id }, state = st.state, stateWhy = st.why, skip = K.SkipState(ctx.prefs.skipped, id),
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
	-- a quest that starts from a world object or an item is not given by a person: say what it starts from (QuestieDB, reference data, unverified on Forever) and name no giver
	local fromThing = view.startKind == "OBJECT" or view.startKind == "ITEM"
	if fromThing then
		lines[1] = view.startKind == "ITEM" and ("Starts from an item" .. (view.startItemName and (": " .. view.startItemName) or "") .. " (QuestieDB, unverified on Forever)")
			or "Starts from a world object (QuestieDB, unverified on Forever)"
	end
	return attach(R.NewAction({
		id = "Q:" .. view.id .. ":ACCEPT", type = "QUEST", kind = "ACCEPT", quest = view.id, skipKey = "Q:" .. view.id, name = view.name,
		title = "Accept: " .. (view.name or ("quest " .. view.id)), reqLevel = view.req, level = view.level,
		breadcrumb = view.breadcrumb, target = t, pinned = pinned or false, lines = lines, seasonal = view.event or nil,
		src = t and t.src or view.src, verified = t and t.verified or false, nameSrc = view.prov.name,
		giver = (not fromThing) and view.giverName or nil,
		sourceKind = view.startKind, sourceItem = view.startItemName, sourceObject = view.startObject,
		-- no layer that covers this quest carries class / race restriction data: "none listed" is then NOT "unrestricted" (the planner will not send the player far for it)
		restrictionUnknown = view.restrictionKnown ~= true or nil,
	}), view.id, view, ctx, t)
end

local function progressAction(view, entry, pinned, ctx)
	local complete = entry.complete
	local name = view.name or entry.title or ("quest " .. entry.id)
	local label = placeLabel(view)
	local lines = {}
	local t
	local who = view.giverName                          -- who the player hands it to (shown by the Presenter)
	if complete then
		local kind, place = turnInPlace(view)
		if kind == "known" then
			label = place.name .. " (" .. R.MapLabel(place.loc.map) .. ")"
			lines[1] = "Objectives complete. Turn in to " .. label
			for _, l in ipairs(provenanceLines(view, place.loc)) do lines[#lines + 1] = l end
			t = target({ loc = place.loc }, label)
			who = place.name
		elseif kind == "unplaced" then
			lines[1] = "Objectives complete. Turn in to " .. place.name .. "."
			for _, l in ipairs(provenanceLines(view, false)) do lines[#lines + 1] = l end
			lines[#lines + 1] = "Where " .. place.name .. " stands is not in Quest Flow data yet."
			who = place.name
		elseif kind == "unknown" then
			lines[1] = "Objectives complete. Hand the quest in."
			lines[#lines + 1] = "Who takes this quest back is not in Quest Flow data, so there is no hand-in location (the quest giver's spot is not assumed)."
			who = nil
		else
			lines[1] = "Objectives complete. Turn in to " .. label
			for _, l in ipairs(provenanceLines(view)) do lines[#lines + 1] = l end
			lines[#lines + 1] = "The turn-in NPC is the quest giver (QuestieDB, unverified on Forever)."
			t = target(view, label)
		end
	else
		describeObjectives(view, lines)
		if #lines == 0 then lines[1] = "In your quest log. Objective details are not in Quest Flow data." end
		local oc = view.objCoords and view.objCoords[1]
		if oc then
			t = { map = oc.map, x = oc.x, y = oc.y, label = "objective area (" .. R.MapLabel(oc.map) .. ")", src = "att", verified = false }
			lines[#lines + 1] = "Objective area: " .. coordText(oc) .. " (ATT, unverified)"
		else
			local gp = ctx.questPoints and ctx.questPoints[entry.id]
			if gp then
				t = { map = gp.map, x = gp.x, y = gp.y, label = "objective area (game quest map)", src = "game", verified = false }
				lines[#lines + 1] = "Objective area: where the game's quest map shows it."
			end
		end
	end
	if complete and ctx.questPoints and ctx.questPoints[entry.id] then
		local kind0 = turnInPlace(view)
		if kind0 ~= "known" then
			local gp = ctx.questPoints[entry.id]
			t = { map = gp.map, x = gp.x, y = gp.y, label = "hand-in (game quest map)", src = "game", verified = false }
			lines[#lines + 1] = "Hand-in: where the game's quest map shows it."
		end
	end
	-- the NPC shown for a hand-in is only a TURN-IN NPC when the data names one; otherwise `giver` is just who gave the quest (the spot is assumed to be theirs)
	local ti = view.turnIn
	local turnInNpc = complete and type(ti) == "table" and (ti.npc ~= nil or ti.name ~= nil) or nil
	return attach(R.NewAction({
		id = "Q:" .. view.id .. (complete and ":TURN_IN" or ":OBJECTIVE"), turnInNpc = turnInNpc, type = "QUEST", kind = complete and "TURN_IN" or "OBJECTIVE",
		quest = view.id, skipKey = "QT:" .. view.id, name = view.name or entry.title, title = (complete and "Turn in: " or "Continue: ") .. name,
		level = view.level, reqLevel = view.req, target = t, pinned = pinned or false, lines = lines,
		src = t and t.src or view.src, verified = t and t.verified or false, nameSrc = view.prov.name, giver = who,
		noLocation = t == nil, areaMap = (not complete) and areaMapOf(view) or nil,
		-- a quest with a live countdown (the client's own, never quest data): the planner reads it to raise this action's value as the deadline nears
		timer = (not complete) and ns.QuestTimers and ns.QuestTimers.Get(view.id) or nil,
	}), view.id, view, ctx, t)
end

--- A quest in the player's log that no pack knows: still worth a reminder (e.g. turn-in), never a guess at where.
local function unknownLogAction(entry, ctx)
	local complete = entry.complete
	local gp = ctx.questPoints and ctx.questPoints[entry.id]
	local t = gp and { map = gp.map, x = gp.x, y = gp.y, label = (complete and "hand-in" or "objective area") .. " (game quest map)", src = "game", verified = false } or nil
	return attach(R.NewAction({
		id = "Q:" .. entry.id .. (complete and ":TURN_IN" or ":OBJECTIVE"), type = "QUEST", kind = complete and "TURN_IN" or "OBJECTIVE",
		quest = entry.id, skipKey = "QT:" .. entry.id, name = entry.title, title = (complete and "Turn in: " or "Continue: ") .. (entry.title or ("quest " .. entry.id)),
		lines = { t and "This quest is not in Quest Flow data; the game's quest map shows where it is." or "This quest is not in Quest Flow data yet, so there is no location to show." },
		target = t, src = t and "game" or "log", verified = false, noLocation = t == nil, unknown = not t and true or nil, unknownData = true,
		timer = (not complete) and ns.QuestTimers and ns.QuestTimers.Get(entry.id) or nil,
	}), entry.id, nil, ctx, t)
end

local function addedUnknown(id, ctx)
	return attach(R.NewAction({
		id = "Q:" .. id .. ":ACCEPT", type = "QUEST", kind = "ACCEPT", quest = id, skipKey = "Q:" .. id,
		title = "Added by you: quest " .. id, pinned = true, noLocation = true, unknown = true, src = "player", verified = false,
		lines = { "You added this quest. It is not in Quest Flow data, so there is no location to show." },
	}), id, nil, ctx, nil)
end

--- A quest the client is OFFERING that no pack knows (it exists only as OfferProbe evidence): an "offered here" pickup with NO location. The client gave an id, a title and
-- the NPC who offered it, nothing else, so there is no coordinate, no level, no requirement and no objective text; none is guessed.
local function offeredAction(o, ctx)
	local a = attach(R.NewAction({
		id = "Q:" .. o.quest .. ":ACCEPT", type = "QUEST", kind = "ACCEPT", quest = o.quest, skipKey = "Q:" .. o.quest, name = o.title, title = "Accept: " .. o.title,
		giver = o.npcName, offered = true, offerVia = o.via, noLocation = true, src = "client", verified = false,
		lines = { "The game is offering this quest" .. (o.npcName and (" (" .. o.npcName .. ")") or "") .. ". It is not in Quest Flow data, so there is no location to show." },
	}), o.quest, nil, ctx, nil)
	-- the client's own offer is the availability evidence (a quest no pack knows would otherwise be state UNKNOWN / NO_DATA and not plannable)
	a.state, a.stateWhy = "AVAILABLE", "CLIENT_OFFER"
	return a
end

function Q.Generate(ctx, env)
	local out = {}
	local stats = env.stats
	local strategy = env.strategy
	local added = {}
	-- the player's veto list, read ONCE: P.IsSkipped would rebuild the preferences table (P.Char) for every one of thousands of ids
	local skipped = ctx.prefs.skipped or {}
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
			if skipped["QT:" .. id] == true then
				bump(stats, "skipped")
			else
				out[#out + 1] = progressAction(view, entry, pinned, ctx)
			end
		elseif skipped["Q:" .. id] == true then
			-- A SKIP WINS over "added" (0.8.0): the player's latest explicit choice is what counts, and the only way back is /codex unskip or adding it again (which clears the skip).
			-- This check used to come AFTER the pinned branch, so a quest the player had added and then skipped stayed in the route as PLAYER_ADDED.
			bump(stats, "skipped")
		elseif pinned then
			if not ctx.isCompleted(id) then
				out[#out + 1] = acceptAction(view, true, ctx)
			else
				bump(stats, "completed")
			end
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
		if not R.Quest(id) and skipped["QT:" .. id] ~= true then
			out[#out + 1] = unknownLogAction(entry, ctx)
		end
	end
	for id in pairs(added) do
		if not R.Quest(id) and not ctx.log[id] and skipped["Q:" .. id] ~= true then
			out[#out + 1] = addedUnknown(id, ctx)
		end
	end
	-- Quests the client is offering right now that no pack knows (one action per quest id, however many times the dialog fired).
	if ns.OfferProbe and ns.OfferProbe.FreshOffers then
		for _, o in ipairs(ns.OfferProbe.FreshOffers(ctx)) do
			local id = o.quest
			if not R.Quest(id) and not ctx.log[id] and not added[id] and skipped["Q:" .. id] ~= true then
				if ctx.isCompleted(id) then bump(stats, "completed") else out[#out + 1] = offeredAction(o, ctx) bump(stats, "offered") end
			end
		end
	end
	return out
end

C.RegisterProvider({ key = "quest", type = "QUEST", label = "Quests", generate = Q.Generate })
