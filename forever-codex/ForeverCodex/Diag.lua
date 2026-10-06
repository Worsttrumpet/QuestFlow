-- ForeverCodex.Diag: everything a tester (or a developer reading a screenshot) needs to understand a report.
--
--   /codex diag     prints the snapshot to chat and stores it (last 5) in ForeverCodexDB.diag
--   /codex report   the playtest report (what the window shows, why, the quest log, the full diagnostics) in a copyable box (falls back to chat)
--
-- The snapshot carries: addon/client versions, which APIs exist on this client, the character, location,
-- the player's choices, which data packs are loaded (with provenance), the current plan and WHY, filter counts,
-- and the last caught errors. It contains no account data beyond the character name the game already shows.

local addonName, ns = ...
local C = ForeverCodex
local R = ns.Registry
local P = ns.Prefs

local D = {}
ns.Diag = D

local API_CHECKS = {
	{ "UnitLevel" }, { "UnitName" }, { "UnitClass" }, { "UnitRace" }, { "UnitFactionGroup" }, { "GetRealmName" },
	{ "GetZoneText" }, { "GetSubZoneText" }, { "GetNumGroupMembers" }, { "IsInGroup" }, { "GetPlayerFacing" },
	{ "GetBindLocation" }, { "CreateVector2D" },
	{ "C_Map", "GetBestMapForUnit" }, { "C_Map", "GetPlayerMapPosition" }, { "C_Map", "GetWorldPosFromMapPos" },
	{ "C_Map", "CanSetUserWaypointOnMap" }, { "C_Map", "SetUserWaypoint" }, { "C_SuperTrack", "SetSuperTrackedUserWaypoint" },
	{ "C_QuestLog", "GetNumQuestLogEntries" }, { "C_QuestLog", "GetInfo" }, { "C_QuestLog", "IsComplete" },
	{ "C_QuestLog", "IsQuestFlaggedCompleted" }, { "C_TaxiMap", "GetAllTaxiNodes" },
}

local function present(path)
	local v = _G[path[1]]
	if #path == 2 then
		v = type(v) == "table" and v[path[2]] or nil
	end
	return type(v) == "function"
end

function D.Apis()
	local out = {}
	for _, p in ipairs(API_CHECKS) do
		out[#out + 1] = { name = table.concat(p, "."), present = present(p) }
	end
	return out
end

local function summarize(a)
	if not a then return nil end
	return { id = a.id, type = a.type, kind = a.kind, title = a.title, src = a.src, verified = a.verified == true,
		score = a._score and math.floor(a._score * 10 + 0.5) / 10 or nil, dist = a._dist and math.floor(a._dist + 0.5) or nil,
		map = a.target and a.target.map or nil, x = a.target and a.target.x or nil, y = a.target and a.target.y or nil,
		reasons = a.reasons }
end

--- A plain-table snapshot (SavedVariables-safe).
function D.Snapshot()
	local ctx, plan = ns.State and ns.State.ctx, ns.State and ns.State.plan
	local okB, ver, build, date, toc = pcall(GetBuildInfo)
	local snap = {
		addon = { version = C.VERSION, expectedInterface = C.EXPECTED_INTERFACE },
		client = { version = okB and ver or nil, build = okB and build or nil, interface = okB and toc or nil },
		apis = D.Apis(), data = R.Stats(), choices = {}, errors = {}, time = type(GetTime) == "function" and GetTime() or 0,
		computeCount = ns.State and ns.State.computeCount or 0,
	}
	if ns.QuestieBridge then
		local st = ns.QuestieBridge.Status()
		snap.questiedb = { state = st.state, message = st.message, version = st.version, commit = st.commit, mode = st.mode, flavor = st.flavor,
			contract = st.contract, minContract = st.minContract, quests = st.quests, stats = ns.QuestieBridge.Stats() }
	end
	local c = P.Char()
	snap.choices = { charKey = P.CharKey(), style = c.style, routeZone = c.routeZone, hardcore = c.hardcore == true,
		skipped = #P.SkippedKeys(), added = #P.AddedList(), systems = {} }
	for _, s in ipairs(R.Systems()) do
		snap.choices.systems[#snap.choices.systems + 1] = { key = s.key, on = c.systems[s.key] == true, planned = s.planned }
	end
	if ctx then
		snap.character = { name = ctx.char.name, realm = ctx.char.realm, class = ctx.char.classToken, race = ctx.char.raceToken,
			raceKey = ctx.char.raceKey, faction = ctx.char.faction, level = ctx.char.level, missing = ctx.char.missing }
		snap.location = { map = ctx.loc.map, x = ctx.loc.x, y = ctx.loc.y, zone = ctx.loc.zone, subzone = ctx.loc.subzone,
			available = ctx.loc.available, world = ctx.loc.world ~= nil }
		snap.group = { size = ctx.group.size, inGroup = ctx.group.inGroup }
		snap.questLog = { count = ctx.logCount, available = ctx.logAvailable }
	end
	if plan then
		snap.plan = { strategy = plan.strategy, routeZone = plan.routeZone, routeMap = plan.routeMap, candidates = plan.stats.candidates,
			filtered = plan.stats.filtered, byType = plan.stats.byType, warnings = plan.warnings, next = summarize(plan.next),
			sequence = {}, nearby = {}, inProgress = #plan.inProgress }
		for i, a in ipairs(plan.sequence) do
			if i <= 6 then snap.plan.sequence[#snap.plan.sequence + 1] = summarize(a) end
		end
		for _, a in ipairs(plan.nearby) do snap.plan.nearby[#snap.plan.nearby + 1] = summarize(a) end
	end
	snap.planner = { mode = ns.State and ns.State.mode or "legacy" }
	if plan and plan.diag then
		local function copy(v)
			if type(v) ~= "table" then return v end
			local out = {}
			for k, x in pairs(v) do out[k] = copy(x) end
			return out
		end
		snap.planner.diag = copy(plan.diag)
	end
	snap.player = { setupDone = P.SetupDone(), navigation = P.NavigationOn(), navStatus = ns.Navigation and ns.Navigation.Status() or nil,
		navOwned = ns.Navigation and ns.Navigation.Owned() or nil, party = ns.Party and ns.Party.Status() or nil,
		journeyEntries = #P.Char().journey.entries,
		arrow = ns.Arrow and { on = P.ArrowOn(), reason = ns.Arrow.state.reason, calibrated = ns.Arrow.Calibration() ~= nil, flip = P.ArrowFlip() } or nil }
	if ns.Telemetry then
		local st = ns.Telemetry.Status()
		snap.telemetry = { enabled = st.enabled, stored = st.stored, cap = st.cap, anomalies = st.anomalies, types = {} }
		for _, c in ipairs(ns.Telemetry.Capabilities()) do
			snap.telemetry.types[#snap.telemetry.types + 1] = { type = c.type, verified = c.verified, registered = c.registered, unavailable = c.unavailable, recorded = c.recorded }
		end
	end
	for _, e in ipairs(ns.errors) do snap.errors[#snap.errors + 1] = e end
	return snap
end

local function sortedFiltered(f)
	local keys = {}
	for k in pairs(f or {}) do keys[#keys + 1] = k end
	table.sort(keys)
	local out = {}
	for _, k in ipairs(keys) do out[#out + 1] = k .. "=" .. f[k] end
	return table.concat(out, " ")
end

--- Human-readable lines for a snapshot.
function D.Lines(s)
	local L = {}
	L[#L + 1] = string.format("Forever Codex v%s | client %s build %s interface %s (addon expects %s)", s.addon.version,
		tostring(s.client.version), tostring(s.client.build), tostring(s.client.interface), tostring(s.addon.expectedInterface))
	if s.character then
		local c = s.character
		L[#L + 1] = string.format("Character: %s level %s %s %s (%s) | race key %s | group %d%s", tostring(c.name), tostring(c.level),
			tostring(c.race), tostring(c.class), tostring(c.faction), tostring(c.raceKey), s.group.size, s.group.inGroup and " (in group)" or "")
		if #c.missing > 0 then L[#L + 1] = "  APIs missing for character info: " .. table.concat(c.missing, ", ") end
	else
		L[#L + 1] = "Character: not read yet"
	end
	if s.location then
		local l = s.location
		L[#L + 1] = string.format("Location: %s / %s | map %s at %s, %s | position available: %s | world coords: %s", tostring(l.zone),
			tostring(l.subzone), tostring(l.map), l.x and string.format("%.1f", l.x * 100) or "?", l.y and string.format("%.1f", l.y * 100) or "?",
			tostring(l.available), tostring(l.world))
	end
	local ch = s.choices
	local on = {}
	for _, sys in ipairs(ch.systems) do
		if sys.on then on[#on + 1] = sys.key end
	end
	L[#L + 1] = string.format("Choices: style=%s routeZone=%s hardcore=%s skipped=%d added=%d systems on: %s", tostring(ch.style), tostring(ch.routeZone),
		tostring(ch.hardcore), ch.skipped, ch.added, #on > 0 and table.concat(on, ",") or "none")
	local d = s.data
	L[#L + 1] = string.format("Data: %d quests (%d in both ATT and observed), %d flight nodes, %d zones", d.quests, d.observedAndAtt, d.flightNodes, d.zones)
	for _, p in ipairs(d.packs) do
		L[#L + 1] = string.format("  pack %s: src=%s verified=%s, %d records (%d with location)", p.name, tostring(p.src), tostring(p.verified), p.count, p.withLocation)
	end
	if s.questiedb then
		local q = s.questiedb
		if q.state == "available" then
			L[#L + 1] = string.format("QuestieDB: IN USE | version %s, build %s | mode %s, flavor %s, contract %s (supports from %s) | %s quests known; %d records read so far, %d with a location, %d errors | unverified on Forever; a quest missing from it is UNKNOWN, not absent",
				tostring(q.version or "?"), tostring(q.commit or "?"), tostring(q.mode or "?"), tostring(q.flavor or "?"), tostring(q.contract or "?"), tostring(q.minContract or "?"),
				tostring(q.quests or "?"), q.stats.built, q.stats.withLocation, q.stats.errors)
			local am = q.stats and q.stats.areaMap
			if am then L[#L + 1] = "  QuestieDB area map (AreaID -> map): " .. tostring(am.state) .. (am.n and am.n > 0 and (" (" .. am.n .. " entries)") or "") .. (am.reason and (" - " .. am.reason .. ": NPC areas cannot be placed on a map until this is fixed") or "") end
		else
			L[#L + 1] = "QuestieDB: NOT in use (" .. tostring(q.state) .. "). " .. tostring(q.message)
		end
	end
	if s.player then
		local p = s.player
		L[#L + 1] = string.format("Player experience: setup %s | waypoint following %s (%s%s) | journey entries %d", p.setupDone and "done" or "NOT done", p.navigation and "on" or "off",
			tostring(p.navStatus), p.navOwned and (", Codex pin placed for " .. tostring(p.navOwned.action)) or "", p.journeyEntries)
		if p.arrow then
			L[#L + 1] = string.format("  arrow: %s (%s), calibrated %s, flip %s", p.arrow.on and "on" or "off", tostring(p.arrow.reason),
				tostring(p.arrow.calibrated), tostring(p.arrow.flip))
		end
		if ns.BlizzardTracker then
			local b = ns.BlizzardTracker.Status()
			L[#L + 1] = string.format("  game quest tracker: Codex hides it = %s | frame %s | state %s%s (UNVERIFIED on Forever)", b.setting and "on" or "off", tostring(b.frame or "not found"), tostring(b.state), b.hooked and ", re-hide hook installed" or "")
		end
		if ns.WorldMapButton then
			local wm = ns.WorldMapButton.Status()
			L[#L + 1] = string.format("  world map button: setting %s | %s%s (UNVERIFIED on Forever)", wm.setting and "on" or "off", tostring(wm.status), wm.slot and (", slot " .. wm.slot) or "")
		end
		if p.party then
			L[#L + 1] = string.format("  party news: %s | addon messages %s | party chat %s | shared items this session %d", p.party.mode,
				p.party.addonMessages and "available" or "UNAVAILABLE", p.party.chat and "available" or "UNAVAILABLE", p.party.feed)
		end
	end
	if s.planner and s.planner.diag then
		local d = s.planner.diag
		local function codes(id)
			local out = {}
			for _, r in ipairs(d.reasons and d.reasons[id] or {}) do out[#out + 1] = r.code end
			return #out > 0 and (" [" .. table.concat(out, ",") .. "]") or ""
		end
		L[#L + 1] = string.format("Planner (%s): %s candidates, %s optional, %s unlocated -> %s stops, %s considered, %s sequences searched | value is policy points, not XP",
			tostring(s.planner.mode), tostring(d.candidates), tostring(d.optional), tostring(d.unlocated), tostring(d.stops), tostring(d.considered), tostring(d.sequences))
		if d.nowId then
			L[#L + 1] = string.format("  NOW %s%s | ALSO DO %s%s | THEN %s%s", d.nowId, codes(d.nowId), tostring(d.alsoDoId), d.alsoDoId and codes(d.alsoDoId) or "",
				tostring(d.thenId), d.thenId and codes(d.thenId) or "")
			L[#L + 1] = string.format("  sequence %s | net %.1f over ~%.0f s | ALSO DO interruption %s s | unknown legs %s%s", table.concat(d.sequence or {}, " > "),
				d.net or 0, d.seconds or 0, tostring(d.interruption), tostring(d.unknownLegs), d.stuck and " | kept previous NOW" or "")
			local rej = {}
			for _, r in ipairs(d.rejected or {}) do rej[#rej + 1] = r.id .. ":" .. r.code .. (r.seconds and ("(" .. r.seconds .. "s)") or "") end
			local alt = {}
			for _, r in ipairs(d.alternatives or {}) do alt[#alt + 1] = r.id .. "(-" .. tostring(r.deficit) .. ")" end
			L[#L + 1] = string.format("  nearest %s | alternatives %s | rejected ALSO DO %s", tostring(d.nearestId), #alt > 0 and table.concat(alt, " ") or "none",
				#rej > 0 and table.concat(rej, " ") or "none")
		else
			L[#L + 1] = "  NOW none: " .. tostring(d.reason or "nothing eligible")
		end
		for _, w in ipairs(d.warnings or {}) do L[#L + 1] = "  planner warning: " .. w end
		if d.held and d.held.n > 0 then L[#L + 1] = string.format("  held back (recently not offered by their giver, still known): %d pickup(s) | detail in OPPORTUNITIES", d.held.n) end
	end
	if s.plan then
		local p = s.plan
		L[#L + 1] = string.format("Plan: strategy=%s candidates=%d in-progress(no location)=%d | filtered: %s", p.strategy, p.candidates, p.inProgress, sortedFiltered(p.filtered))
		if p.next then
			L[#L + 1] = string.format("  NEXT: [%s/%s] %s | src=%s verified=%s score=%s dist=%s", tostring(p.next.type), tostring(p.next.kind), tostring(p.next.title),
				tostring(p.next.src), tostring(p.next.verified), tostring(p.next.score), tostring(p.next.dist))
			if p.next.reasons then L[#L + 1] = "  why: " .. table.concat(p.next.reasons, "; ") end
		else
			L[#L + 1] = "  NEXT: nothing to recommend"
		end
		for i, a in ipairs(p.sequence) do
			if i > 1 then L[#L + 1] = string.format("  then %d: [%s] %s", i, tostring(a.kind), tostring(a.title)) end
		end
		for _, w in ipairs(p.warnings) do L[#L + 1] = "  warning: " .. w end
	else
		L[#L + 1] = "Plan: not computed yet"
	end
	if s.telemetry then
		local tl = s.telemetry
		L[#L + 1] = string.format("Telemetry: %s, %d/%d events stored, %d anomalies (observation only; it does not affect recommendations)",
			tl.enabled and "enabled" or "OFF", tl.stored, tl.cap, tl.anomalies)
		local parts = {}
		for _, ty in ipairs(tl.types) do
			parts[#parts + 1] = string.format("%s[%s reg=%s rec=%d]", ty.type, ty.unavailable and "UNAVAILABLE" or (ty.verified and "proven" or "UNPROVEN"), tostring(ty.registered), ty.recorded)
		end
		L[#L + 1] = "  " .. table.concat(parts, " ")
	end
	local miss = {}
	for _, a in ipairs(s.apis) do
		if not a.present then miss[#miss + 1] = a.name end
	end
	L[#L + 1] = "APIs absent on this client: " .. (#miss > 0 and table.concat(miss, ", ") or "none of the ones Codex checks")
	L[#L + 1] = string.format("Recomputes: %d | caught errors: %d", s.computeCount, #s.errors)
	for _, e in ipairs(s.errors) do L[#L + 1] = "  error: " .. e end
	return L
end

--- OPPORTUNITIES (Phase 1, diagnostics only): every candidate chooseAlsoDo priced against the chosen route, kept from this recompute only (not saved).
-- Reads plan.diag.opps; nothing here feeds back into the planner.
D.OPP_SHOW = 24            -- candidate lines printed (of the Planner.OPP_CAP kept, cheapest extra time first); the counts cover all of them

-- ---------------------------------------------------------------- availability and location evidence for a pickup (report only)
-- Everything below READS: it never feeds the planner, changes no state and uses no new client function.

local function nowSecs() return type(time) == "function" and time() or 0 end
local function ageOf(t) return t and string.format("%ds ago", math.max(0, nowSecs() - t)) or "age unknown" end

local HOW_TEXT = {
	ID = "matched by creature id",
	NAME_IDS_DIFFER = "matched BY NAME ONLY (both creature ids are known and they differ)",
	NAME_QUEST_HAS_NO_ID = "matched by name (the quest data has no creature id)",
	NAME_LISTING_HAS_NO_ID = "matched by name (the dialog was recorded without a creature id)",
}

--- The giver as quest data names it, plus the OfferProbe facts for that giver: { view, ex, gnpc, gname }.
local function giverFacts(qid)
	local view = qid and ns.Registry.Quest(qid) or nil
	local gnpc, gname = view and view.giverNpc, view and view.giverName
	local ex = ns.OfferProbe and ns.OfferProbe.Explain and ns.OfferProbe.Explain(qid, gnpc, gname) or nil
	return { view = view, ex = ex, gnpc = gnpc, gname = gname }
end

--- "creature 252383 'Valennia Stormfist'" (either part may be missing).
local function npcText(id, name)
	return string.format("%s%s", name and ("'" .. tostring(name) .. "'") or "name unknown", id and (" (creature " .. tostring(id) .. ")") or " (no creature id)")
end

--- How the giver's dialog was matched, and whether it was read at the CURRENT progression stamp. One short phrase for list lines.
local function matchBrief(ex)
	local l = ex and ex.listing
	if not l then return "no dialog recorded for this giver" end
	local how = HOW_TEXT[l.how] or tostring(l.how)
	local fresh = l.noStamp and "no progression stamp stored on that dialog: treated as STALE (never a fresh negative)" or
		(l.fresh and ("FRESH: read at the current progression " .. tostring(ex.stamp)) or ("STALE: read at progression " .. tostring(l.prog) .. ", now " .. tostring(ex.stamp) .. "; ignored by the planner until the NPC is asked again"))
	return how .. "; dialog with " .. npcText(l.id, l.name) .. " | " .. fresh
end

local SRC_TEXT = {
	observed = "observed pack (recorded on the Forever client by ForeverRecorder)",
	att = "ATT static data (unverified on Forever)",
	questiedb = "QuestieDB static baseline (unverified on Forever)",
}

--- Where the merged location of a quest comes from, in plain words. Never calls a recorder position an NPC coordinate.
local function locationText(view)
	local loc = view and view.loc
	if not loc then return "unknown (no data layer has a coordinate for this quest)" end
	local where = string.format("map %s at %.1f, %.1f", tostring(loc.map), (loc.x or 0) * 100, (loc.y or 0) * 100)
	local text
	if loc.kind == "player_position" then
		text = where .. " | source: the PLAYER's position at a recorder checkpoint when a quest dialog was seen (src=" .. tostring(loc.src) .. "); this is NOT an NPC coordinate; approximate"
	else
		text = where .. " | source: giver coordinate from " .. (SRC_TEXT[loc.src] or tostring(loc.src)) .. (loc.verified and "" or "; unverified on Forever as the NPC's position")
	end
	if view.locConflict then
		text = text .. string.format(" | a %s coordinate for a different giver (creature %s) was ignored", tostring(view.locConflict.ignored), tostring(view.locConflict.ignoredGiverNpc))
	end
	return text
end

--- The report lines for ONE pickup the plan currently shows (NOW / ALSO DO / THEN): what Codex can and cannot say about whether it is offered, and where its data comes from.
function D.PickupEvidenceLines(a, role)
	local L = {}
	local Pl = ns.Planner
	L[#L + 1] = string.format("  %s %s %s", role, tostring(a.id), tostring(a.title or a.name or "?"))
	if a.kind ~= "ACCEPT" or not a.quest then
		L[#L + 1] = "    " .. tostring(a.kind) .. ": a quest you already have; offer evidence does not apply to it"
		return L
	end
	local f = giverFacts(a.quest)
	local view, ex = f.view, f.ex
	local state = Pl.OfferState(a)
	local act = Pl.Actionability(a)
	local meaning = state == "OBSERVED" and "the client has offered it to this character"
		or state == "NOT_OFFERED" and "held back: the giver was asked at the current progression and did not offer it"
		or "availability is not proven either way"
	L[#L + 1] = string.format("    actionability: %s | planner offer state: %s (%s)", tostring(act), tostring(state), meaning)
	-- positive client evidence
	local pos = ex and ex.positive
	if pos then
		L[#L + 1] = string.format("    positive client offer: yes | %s | seen at %s | %d time(s), last %s | progression when seen: %s", tostring(pos.via), npcText(pos.npcId, pos.npcName), pos.n or 1, ageOf(pos.last), tostring(pos.prog or "not stored"))
	else
		L[#L + 1] = "    positive client offer: none (no quest dialog or available list for this quest has been recorded)"
	end
	-- negative client evidence
	local ev = ex and ex.evidence
	if ev and (ev.kind == "EMPTY_AT_NPC" or ev.kind == "NOT_LISTED_AT_NPC") then
		L[#L + 1] = string.format("    negative client evidence: %s at %s, %s | %s", ev.kind, tostring(ev.npc), ageOf(ev.last), matchBrief(ex))
	elseif ev and ev.newer then
		L[#L + 1] = string.format("    negative client evidence: a NEWER dialog at %s shows %s%s", tostring(ev.npc), ev.newer, ev.contradicted and " (read at the current progression, so it contradicts the earlier offer)" or " (read at a different progression: the earlier offer stands)")
	elseif ex and ex.listing then
		L[#L + 1] = string.format("    negative client evidence: none | the giver's latest dialog gives no verdict on this quest (state %s%s) | %s", tostring(ex.listing.state), ex.listing.complete == false and ", incomplete list" or "", matchBrief(ex))
	else
		L[#L + 1] = "    negative client evidence: none | " .. matchBrief(ex)
	end
	-- who the data says gives it, against who the client talked to
	local gprov = view and view.prov and (view.prov.giverNpc or view.prov.giverName)
	L[#L + 1] = string.format("    quest giver in quest data: %s | from %s", npcText(f.gnpc, f.gname or a.giver), tostring(gprov or "no data layer"))
	local l = ex and ex.listing
	if l then
		L[#L + 1] = string.format("    NPC dialog used for the hold check: %s | %s (this is the dialog the planner would use; %s)", npcText(l.id, l.name), HOW_TEXT[l.how] or tostring(l.how),
			l.how == "NAME_IDS_DIFFER" and "the quest data's giver and the NPC you talked to have DIFFERENT creature ids" or "ids agree or one side has none")
	else
		L[#L + 1] = "    NPC dialog used for the hold check: none (no dialog recorded for the quest's giver by creature id or by name)"
	end
	-- progression stamps
	if ex then
		local stampLine = string.format("    progression stamp (level : turn-ins Codex saw : quests ready to hand in): current %s", tostring(ex.stamp))
		if l then
			stampLine = stampLine .. string.format(" | that NPC dialog was read at %s | %s", l.noStamp and "no stamp stored" or tostring(l.prog),
				l.noStamp and "no comparison possible: stale" or (l.fresh and "they MATCH: fresh" or "they DIFFER: stale"))
		else
			stampLine = stampLine .. " | no NPC dialog to compare"
		end
		L[#L + 1] = stampLine
	end
	if view and view.hasObserved then
		L[#L + 1] = "    observed-pack record: it carries no progression stamp and no timestamp, so Codex cannot tell at which progression or when it was seen"
	end
	-- location, layers, prerequisites
	L[#L + 1] = "    location: " .. locationText(view)
	if view then
		local layers = {}
		for _, ly in ipairs(view.layers or {}) do layers[#layers + 1] = string.format("%s (src=%s, verified=%s)", tostring(ly.pack), tostring(ly.src), ly.verified and "yes" or "no") end
		L[#L + 1] = "    data layers that know this quest: " .. (#layers > 0 and table.concat(layers, "; ") or "none")
		if view.hasObserved then
			L[#L + 1] = "    'verified=yes' on the observed pack means its title, level, objectives and giver were recorded on the Forever client. It does NOT mean the position is an NPC's position"
		end
		local pre = {}
		for _, p in ipairs(view.prereq or {}) do pre[#pre + 1] = tostring(p) end
		local preAll = {}
		for _, p in ipairs(view.prereqAll or {}) do preAll[#preAll + 1] = tostring(p) end
		if #pre > 0 or #preAll > 0 then
			L[#L + 1] = "    prerequisites in the data: " .. (#pre > 0 and ("any of quest " .. table.concat(pre, ", ")) or "") .. (#preAll > 0 and (" all of quest " .. table.concat(preAll, ", ")) or "") .. " (from " .. tostring(view.prov.prereq or view.prov.prereqAll) .. ")"
		else
			L[#L + 1] = "    prerequisites in the data: none known (no layer lists one; that is not evidence that there is none)"
		end
		L[#L + 1] = string.format("    requirements in the data: level %s | quest level %s", tostring(view.req or "none"), tostring(view.level or "unknown"))
	else
		L[#L + 1] = "    data layers that know this quest: none (no pack has a record: no giver, location or prerequisite data)"
	end
	if state == "UNKNOWN" then
		L[#L + 1] = "    why it can be recommended: availability is UNKNOWN and the planner allows unknown pickups (existing policy, with its small discounts). Only a FRESH not-offered observation at the giver's dialog holds a pickup back"
	end
	return L
end

--- The report section for the plan's own pickups: NOW, ALSO DO and THEN.
function D.AvailabilityLines()
	local L = {}
	L[#L + 1] = "NOW CANDIDATE EVIDENCE (read-only: how the pickups the window shows got their availability and location. Nothing here changes the plan)"
	local plan = ns.State and ns.State.plan
	if not plan then L[#L + 1] = "  no plan yet"; return L end
	local stamp = ns.OfferProbe and ns.OfferProbe.Stamp and ns.OfferProbe.Stamp() or "?"
	L[#L + 1] = "  current progression stamp: " .. tostring(stamp) .. " (level : quests turned in that Codex saw : quests ready to hand in). An NPC dialog read at a different stamp is STALE."
	local any = false
	for _, e in ipairs({ { "NOW", plan.now }, { "ALSO DO", plan.alsoDo }, { "THEN", plan.thenAction } }) do
		if e[2] then
			any = true
			for _, line in ipairs(D.PickupEvidenceLines(e[2], e[1])) do L[#L + 1] = line end
		end
	end
	if not any then L[#L + 1] = "  the plan has no NOW, ALSO DO or THEN action" end
	return L
end

local function oppProvenance(o)
	local parts = { "evidence=" .. tostring(o.evidence or "?"), "location=" .. tostring(o.status or "?") .. (o.assumed and " (assumed)" or "") }
	local view = o.qid and ns.Registry.Quest(o.qid) or nil
	if view then
		if view.loc and view.loc.kind == "player_position" then parts[#parts + 1] = "location source: recorder PLAYER position (not an NPC coordinate)" end
		local src = view.layers and view.layers[1]
		parts[#parts + 1] = "known from " .. (src and (tostring(src.src) .. (src.verified and ", verified=yes" or ", verified=no")) or "?")
		if o.kind == "ACCEPT" then
			parts[#parts + 1] = string.format("classMask=%s raceMask=%s classes=%s races=%s faction=%s", tostring(view.classMask), tostring(view.raceMask),
				view.classes and table.concat(view.classes, "/") or "none", view.races and table.concat(view.races, "/") or "none", tostring(view.faction))
		end
	end
	if o.kind == "ACCEPT" and o.qid then
		-- client evidence only (never database presence): OBSERVED when the client showed the quest; a contextual negative is reported as evidence, not as a verdict
		local act = ns.Planner.Actionability({ kind = "ACCEPT", quest = o.qid })
		local ev = ns.Planner.OfferEvidence({ kind = "ACCEPT", quest = o.qid })
		if act == "OBSERVED" then
			parts[#parts + 1] = ((ev and ev.via == "AVAILABLE_LIST") and "actionability OBSERVED (listed as available in an NPC dialog)" or "actionability OBSERVED (a quest dialog for it was seen)")
				.. ((ev and ev.newer) and (" | a NEWER dialog at " .. tostring(ev.npc) .. " shows " .. ev.newer .. " (history kept)") or "")
		elseif act == "IN_LOG" then
			parts[#parts + 1] = "actionability IN_LOG (the quest is in your log)"
		elseif ev and (ev.kind == "EMPTY_AT_NPC" or ev.kind == "NOT_LISTED_AT_NPC") then
			parts[#parts + 1] = string.format("actionability UNKNOWN | offer evidence: %s at %s (%ds ago): %s; this does not prove the quest is unavailable | %s", ev.kind, tostring(ev.npc),
				math.max(0, (type(time) == "function" and time() or 0) - (ev.last or 0)), ev.kind == "EMPTY_AT_NPC" and "no available quests were listed in that dialog" or "that dialog's complete list did not include this quest",
				matchBrief(giverFacts(o.qid).ex))
		else
			parts[#parts + 1] = "actionability UNKNOWN (never seen offered; database presence is not client evidence)"
		end
	end
	return table.concat(parts, " | ")
end

function D.OpportunityLines()
	local L = {}
	local plan = ns.State and ns.State.plan
	local d = plan and plan.diag
	L[#L + 1] = "OPPORTUNITIES (diagnostic only: what the planner priced against the CURRENT route; nothing here changes the plan; not saved)"
	if not d then L[#L + 1] = "  no plan yet"; return L end
	L[#L + 1] = "  core route: " .. ((d.sequence and #d.sequence > 0) and table.concat(d.sequence, " > ") or "none") .. (plan.now and (" | NOW " .. tostring(plan.now.title)) or "")
	if d.possible and d.possible.n > 0 then
		L[#L + 1] = string.format("  POSSIBLE PICKUPS (%d not routed: the client has not confirmed them and they are far away or nothing says they are for this character; kept as on-the-way extras only):", d.possible.n)
		for _, h in ipairs(d.possible.list or {}) do
			L[#L + 1] = string.format("    Q%s %s | %s | %s", tostring(h.quest), tostring(h.title), h.why == "RESTRICTION_UNKNOWN" and "no data layer covering it carries class / race restrictions" or (h.why == "UNKNOWN_AVAILABILITY" and "the client has not offered it (availability UNKNOWN)" or tostring(h.why)),
				type(h.dist) == "number" and string.format("%d yd away", math.floor(h.dist + 0.5)) or "distance unknown")
		end
		if d.possible.n > #(d.possible.list or {}) then L[#L + 1] = string.format("    + %d more", d.possible.n - #d.possible.list) end
	end
	if d.held and d.held.n > 0 then
		-- pickups the planner did not route because their giver, asked at this same progression, did not offer them (still known; they return when that goes stale)
		L[#L + 1] = string.format("  HELD BACK (%d pickup(s) not routed: the giver was asked at your current progression and did not offer them; still known, they return after your next level / turn-in / finished quest, or once the client offers them):", d.held.n)
		for _, h in ipairs(d.held.list or {}) do
			L[#L + 1] = string.format("    %s %s | %s at %s (%ds ago)%s | %s", tostring(h.id), tostring(h.title), tostring(h.kind or "?"), tostring(h.npc or "?"),
				math.max(0, (type(time) == "function" and time() or 0) - (h.last or 0)), h.contradicted and " | was observed before; a newer dialog no longer lists it" or "",
				matchBrief(giverFacts(h.quest).ex))
		end
		if d.held.n > #(d.held.list or {}) then L[#L + 1] = string.format("    + %d more held back", d.held.n - #d.held.list) end
	end
	local o = d.opps
	if not o then
		L[#L + 1] = "  not priced this time: " .. tostring(d.reason or (d.deferredTurnIn and "a hand-in was deferred for local work" or (d.localWork and "LOCAL_WORK" or "no route was chosen")))
		return L
	end
	local function counts(t, order)
		local out = {}
		for _, k in ipairs(order) do if t[k] then out[#out + 1] = k .. " " .. t[k] end end
		return #out > 0 and table.concat(out, ", ") or "none"
	end
	L[#L + 1] = string.format("  priced: %d | by cost: %s | decisions: %s", o.total, counts(o.class, { "FREE", "CHEAP", "MODERATE", "EXPENSIVE", "UNKNOWN" }),
		counts(o.decision, { "ACCEPTED", "OUTRANKED", "TOO_FAR", "LOW_VALUE", "UNKNOWN_TRANSIT" }))
	do
		local ow = {}
		for _, e in ipairs(plan.onTheWay or {}) do ow[#ow + 1] = string.format("%s (%s, %s, %s)", e.id, e.costClass or "?", e.reason and e.reason.code or "?", e.actionability or "?") end
		L[#L + 1] = string.format("  on the way (%d cleared both bars; up to %d carried to the tracker, best net first; the first is the ALSO DO): %s", d.onTheWayTotal or 0, ns.Planner.ON_THE_WAY_MAX, #ow > 0 and table.concat(ow, " | ") or "none")
	end
	L[#L + 1] = string.format("  planner limits in force: detour %s s | ALSO DO floor %s pts | time value %.2f pts/s | route has %d stop(s). Cost = extra seconds to insert it into that route (0 within the first stop).", tostring(o.route.detour), tostring(o.route.alsoFloor), o.route.timeValue, o.route.stops)
	L[#L + 1] = string.format("  listed: %d of %d priced (cheapest extra time first, then id; cap %d stored, %d shown). Relation: DIRECTLY_ON_ROUTE <= 0.5 s or same stop | RECONNECTING_DETOUR leaves and rejoins | AFTER_ROUTE one-way past the last stop.",
		#o.list, o.total, o.cap, D.OPP_SHOW)
	for n, e in ipairs(o.list) do
		if n > D.OPP_SHOW then break end
		local where = e.same and "same stop as NOW" or (e.from and (e.to and ("between " .. e.from .. " and " .. e.to) or ("after " .. e.from)) or "unplaced")
		L[#L + 1] = string.format("  %-9s %s %s [%s] extra=%s | %s | %s | %s | net %s (value %s, dwell %s s)", e.cls, e.id, tostring(e.title), e.kind,
			e.cost and string.format("%.0fs", e.cost) or "unknown", e.rel, where, e.dec, e.net and string.format("%.1f", e.net) or "n/a", string.format("%.1f", e.val or 0), string.format("%.0f", e.dwell or 0))
		L[#L + 1] = string.format("      %s%s", e.stop and string.format("stop %s holds %d action(s) | ", e.stop, e.stopSize or 1) or "optional hint, no stop | ", oppProvenance(e))
	end
	if #o.hubs > 0 then
		L[#L + 1] = "  off-route stops with 2+ actions priced AS A WHOLE (diagnostic only: the planner prices these one by one when it picks an ALSO DO):"
		for _, h in ipairs(o.hubs) do
			L[#L + 1] = string.format("    stop %s: %d actions (%s) | extra=%.0fs | summed value %.1f, dwell %.0f s | net as one trip %.1f", h.stop, h.size, table.concat(h.ids, " "), h.cost, h.val, h.dwell, h.net)
		end
	end
	return L
end

--- PERFORMANCE: counters kept by State/Boot (no timers). Times are the client's debugprofilestop milliseconds around State.Recompute.
function D.PerformanceLines()
	local S, pf = ns.State, ns.State.perf
	local L = {}
	local function byList(t)
		local keys = {}
		for k in pairs(t) do keys[#keys + 1] = k end
		table.sort(keys, function(a, b) if t[a] ~= t[b] then return t[a] > t[b] end return a < b end)
		local out = {}
		for _, k in ipairs(keys) do out[#out + 1] = k .. "=" .. t[k] end
		return #out > 0 and table.concat(out, " ") or "none"
	end
	local timed = pf.last ~= nil
	if ns.SavedData then for _, line in ipairs(ns.SavedData.SavedDataLines()) do L[#L + 1] = line end end
	L[#L + 1] = "PERFORMANCE (counters only; times are real client milliseconds, not stub)"
	L[#L + 1] = string.format("  recomputes: %d | last %s | worst %s%s | total %s | average %s", pf.count,
		timed and string.format("%.2f ms", pf.last) or "n/a", timed and string.format("%.2f ms", pf.worst) or "n/a",
		pf.worstReason and (" (" .. pf.worstReason .. ")") or "", timed and string.format("%.1f ms", pf.total) or "n/a",
		(timed and pf.count > 0) and string.format("%.2f ms", pf.total / pf.count) or "n/a")
	if timed and pf.worstN then
		local function ms(v) return v and string.format("%.1f ms", v) or "n/a" end
		local rest = (pf.worst and pf.wCtx and pf.wCand and pf.wPlan) and (pf.worst - pf.wCtx - pf.wCand - pf.wPlan) or nil
		L[#L + 1] = string.format("  worst was recompute #%d (%s): context %s | quest scan (Engine.Candidates) %s | planner (incl. opportunity pricing) %s | the rest (observers, adapter, UI refresh) %s | first recompute %s",
			pf.worstN, tostring(pf.worstReason), ms(pf.wCtx), ms(pf.wCand), ms(pf.wPlan), ms(rest), ms(pf.firstMs))
		local qb = ns.QuestieBridge and ns.QuestieBridge.Stats and ns.QuestieBridge.Stats()
		if qb then L[#L + 1] = string.format("  QuestieDB records built so far: %s in %s (a one-time cost per session: each record is read and cached the first time it is needed)", tostring(qb.built), qb.ms and string.format("%.0f ms", qb.ms) or "n/a") end
	end
	L[#L + 1] = "  recomputes by cause: " .. byList(pf.recomputeBy) .. "   (dirty = after an event or choice; periodic = a refresh while a Codex window is open AND the player moved or a timed quest is counting down; direct = a command or button; report = this report itself)"
	do
		local w = ns.State.warmup or {}
		local wtxt
		if w.state == "done" then wtxt = string.format("first scan spread over %d frame(s), %s ms of work in total%s", w.frames or 0, w.ms and string.format("%.0f", w.ms) or "?", w.early and " (a command needed the plan first, so it finished early)" or "")
		elseif w.state == "running" then wtxt = string.format("first scan in progress: %d of %d quests warmed", (w.i or 1) - 1, w.n or 0)
		elseif w.state == "skipped" then wtxt = string.format("not needed (%d known quests: recomputed at once)", w.n or 0)
		else wtxt = "not started" end
		L[#L + 1] = "  login warm-up: " .. wtxt .. string.format(" | idle refreshes skipped (window open, nothing changed): %d", pf.skippedIdle or 0)
	end
	L[#L + 1] = "  events that marked the plan stale: " .. byList(pf.dirtyBy)
	local now = type(_G.GetTime) == "function" and _G.GetTime() or nil
	if now and pf.startedAt then
		local secs = now - pf.startedAt
		local per = pf.recomputeBy.periodic or 0
		L[#L + 1] = string.format("  since load: %.0f s | periodic (window-open) recomputes %d (%.1f per minute; the 3 s rule gives at most 20 per minute) | all recomputes %.1f per minute",
			secs, per, secs > 0 and per * 60 / secs or 0, secs > 0 and pf.count * 60 / secs or 0)
	end
	local cur = S.AddonMemoryKb and S.AddonMemoryKb()
	L[#L + 1] = string.format("  Codex memory: %s now | %s after the first recompute (GetAddOnMemoryUsage: %s; garbage included until the next collection)",
		cur and string.format("%.1f MB", cur / 1024) or "unavailable", type(pf.memFirstKb) == "number" and string.format("%.1f MB", pf.memFirstKb / 1024) or "unavailable",
		type(_G.GetAddOnMemoryUsage) == "function" and "present" or "absent")
	return L
end

local MAX_STORED = 5

--- Stores a snapshot in ForeverCodexDB.diag (kept to the last 5).
function D.Store(snap)
	local list = P.Root().diag
	list[#list + 1] = snap
	while #list > MAX_STORED do table.remove(list, 1) end
end

--- Takes a fresh snapshot, prints it, stores it. Returns the snapshot and its lines.
function D.Print()
	if ns.State then ns.State.Recompute("report") end
	local snap = D.Snapshot()
	local lines = D.Lines(snap)
	for _, l in ipairs(lines) do ns.Say(l) end
	D.Store(snap)
	return snap, lines
end

--- The playtest report: what the window shows, why the planner chose it, the quest log, and the full diagnostics, as plain lines to copy.
-- It re-runs the planner on the CURRENT context with the trace on (the same inputs as the live plan: it changes nothing and the live plan is kept).
function D.PlaytestLines(snap, lines)
	local L = {}
	local ctx, plan = ns.State and ns.State.ctx, ns.State and ns.State.plan
	local function add(s) L[#L + 1] = s end
	local function num(v, f) return type(v) == "number" and string.format(f or "%.1f", v) or "?" end
	add(string.format("=== FOREVER CODEX PLAYTEST REPORT v%s ===", tostring(C.VERSION)))
	if not (ctx and plan) then
		add("(the plan has not been computed yet: open /codex once and run the report again)")
		for _, l in ipairs(lines) do add(l) end
		return L
	end
	local c, l = ctx.char or {}, ctx.loc or {}
	add(string.format("%s | level %s %s %s (%s) | map %s at %s, %s | %s / %s", tostring(c.name), tostring(c.level), tostring(c.race), tostring(c.class), tostring(c.faction),
		tostring(l.map), l.x and num(l.x * 100) or "?", l.y and num(l.y * 100) or "?", tostring(l.zone), tostring(l.subzone)))

	-- what the window shows
	add("")
	add("--- WHAT THE WINDOW SHOWS ---")
	local slots = ns.Presenter.Slots(ctx)
	add("Quest log: " .. (slots and string.format("%d/%d quests (%d free)%s", slots.used, slots.max, slots.free, slots.full and " - FULL: new quests are not recommended" or "") or "unreadable")
		.. " | quest-starting items in your bags do not use these slots; Codex lists the ones the game says start a quest as NEW QUEST ITEM")
	local okC, card = pcall(ns.Presenter.Card, plan, ctx)
	if okC and card then
		local function show(label, it)
			if not it then return end
			add(string.format("%s: %s | who: %s | where: %s | detail: %s | why: %s", label, tostring(it.title), tostring(it.who), tostring(it.where), tostring(it.detail), tostring(it.why)))
			if it.progress then add("    progress: " .. tostring(type(it.progress) == "table" and (tostring(it.progress.have) .. "/" .. tostring(it.progress.need)) or it.progress)) end
		end
		if card.now then show(card.guidance and "NOW (guidance only: the planner has no NOW, no arrow)" or "NOW", card.now) else add("NOW: " .. tostring(card.empty and card.empty.title or "nothing")) end
		for _, o in ipairs(card.now and card.now.objectives or {}) do
			add(string.format("    unfinished: %s %s/%s", tostring(o.text), tostring(o.have), tostring(o.need)))
		end
		for _, g in ipairs(card.dungeons or {}) do
			for _, q in ipairs(g.quests) do
				add(string.format("DUNGEON QUEST: %s (Q:%s) | %s%s | dungeon named by: %s", tostring(q.title), tostring(q.quest), tostring(g.name), q.complete and " | ready to turn in" or "", g.via == "area" and "the game's area name" or (g.via == "log" and "the quest log heading" or "nothing (unknown)")))
			end
		end
		if #(card.ready or {}) == 0 then add("READY TO TURN IN: nothing") end
		for _, r in ipairs(card.ready or {}) do
			add(string.format("READY TO TURN IN: %s (Q:%s) | %s | %s", tostring(r.title), tostring(r.quest), tostring(r.who or "turn-in NPC unknown"), tostring(r.where or "distance unknown")))
		end
		local alsoLabel = ns.Presenter.AlsoLabel(card.also or {})
		if #(card.also or {}) == 0 then add("ALSO COMPLETE: nothing") end
		for _, it in ipairs(card.also or {}) do
			if it.kind == "objective" then
				local parts = {}
				for _, o in ipairs(it.objectives) do parts[#parts + 1] = string.format("%s %s/%s", tostring(o.text), tostring(o.have), tostring(o.need)) end
				add(string.format("%s: %s (Q:%s) | %s", alsoLabel, tostring(it.title), tostring(it.quest), table.concat(parts, "; ")))
			else
				add(string.format("%s: %s | %s", alsoLabel, tostring(it.title), tostring(it.dist or it.where)))
			end
		end
		show("planner ALSO DO", card.alsoDo)
		if card.thenLine then add("THEN: " .. tostring(card.thenLine)) end
		local okN, near = pcall(ns.Nearby.List, plan, ctx)
		if okN and #near > 0 then
			for _, n in ipairs(near) do add(string.format("old nearby list (not shown in the window): %s | %s | %s", tostring(n.title), tostring(n.detail), tostring(n.where))) end
		else
			add("old nearby list (not shown in the window): nothing")
		end
		if #card.reminders > 0 then add("In your log, not placed on the map: " .. table.concat(card.reminders, ", ")) end
		for _, a in ipairs(plan.reminders or {}) do
			if a.offered then add(string.format("OFFERED HERE (the game showed this offer at your current progression; no pack knows it; NO location): Q%s %s | by %s via %s", tostring(a.quest), tostring(a.name), tostring(a.giver or "an NPC with no name"), tostring(a.offerVia))) end
		end
	end
	local nfy = ns.NewForYou and ns.NewForYou.Active()
	add("NEW FOR YOU: " .. (nfy and (#nfy.items .. " item(s) at level " .. tostring(nfy.level)) or "hidden"))
	if ns.UI and ns.UI.main and ns.UI.main.height then add("Window height: " .. tostring(ns.UI.main.height)) end

	-- why the planner chose it (a traced re-run on the same context)
	local okT, traced = pcall(ns.PlanAdapter.Compute, ctx, { prevNowId = plan.now and plan.now.id or nil, trace = true })
	local d = okT and traced and traced.diag or plan.diag
	local R = ns.Registry
	local ACTION = { ACCEPT = "Accept", TURN_IN = "Turn in", OBJECTIVE = "Finish" }
	local ORDER = { TURN_IN = 1, OBJECTIVE = 2, ACCEPT = 3 }
	local function questName(qid)
		local v = R.Quest(qid)
		return (v and v.name) or (ctx.log and ctx.log[qid] and ctx.log[qid].title) or "?"
	end
	--- "Q:362 The Haunted Mills - TURN_IN" for a quest action id; other ids are shown as they are.
	local function label(id)
		local qid, kind = tostring(id):match("^Q:(%d+):([%u_]+)")
		if not qid then return tostring(id) end
		return string.format("Q:%s %s - %s", qid, questName(tonumber(qid)), kind)
	end
	local function sentence(id)
		local qid, kind = tostring(id):match("^Q:(%d+):([%u_]+)")
		if not qid then return tostring(id) end
		return string.format("%s %s [Q:%s]", ACTION[kind] or kind, questName(tonumber(qid)), qid)
	end
	local function itemsOf(st)
		local list = {}
		for _, id in ipairs(st.items) do list[#list + 1] = id end
		table.sort(list, function(x, y)
			local kx, ky = ORDER[tostring(x):match(":([%u_]+)$")] or 9, ORDER[tostring(y):match(":([%u_]+)$")] or 9
			if kx ~= ky then return kx < ky end
			return tostring(x) < tostring(y)
		end)
		return list
	end
	local me = l.available and { map = l.map, x = l.x, y = l.y, world = l.world or false } or nil
	local UNMEASURED = ns.Engine.DIFFERENT_CONTINENT
	local stops = {}
	for i, st in ipairs(d and d.stopList or {}) do
		local dist = me and ns.Engine.Distance(ctx, me, { map = st.map, x = st.x, y = st.y }) or nil
		stops[i] = { st = st, dist = dist, measured = dist ~= nil and dist ~= UNMEASURED, first = d.bestByFirst and d.bestByFirst[st.id] }
	end
	local byId = {}
	for _, e in ipairs(stops) do byId[e.st.id] = e end

	add("")
	add("--- WHY (planner trace) ---")
	if d then
		local flags = {}
		for _, k in ipairs({ "localOnly", "localWork", "turnInFirst", "stuck", "pinnedFirst", "routeZoneOnly", "deferredTurnIn", "handInOnRoute", "handInBatched", "slotPressure", "workHere" }) do if d[k] then flags[#flags + 1] = k end end
		add(string.format("reason=%s | flags: %s | net %s over ~%s s | unknown legs %s | %s stops, %s sequences", tostring(d.reason), #flags > 0 and table.concat(flags, ",") or "none",
			num(d.net), num(d.seconds, "%.0f"), tostring(d.unknownLegs), tostring(d.stops), tostring(d.sequences)))
		local rej = {}
		for _, r in ipairs(d.rejected or {}) do rej[#rej + 1] = label(r.id) .. (r.code and (" " .. r.code) or "") .. (r.seconds and (" (" .. r.seconds .. " s)") or "") end
		add("rejected ALSO DO: " .. (#rej > 0 and table.concat(rej, "; ") or "none"))
		add(string.format("params: timeValue=%s stickiness=%s", tostring(d.params and d.params.timeValue), tostring(d.params and d.params.stickiness)))

		add("")
		add("--- SEQUENCE (what Codex wants you to do, in order) ---")
		if d.sequence and #d.sequence > 0 then
			local n = 0
			for _, sid in ipairs(d.sequence) do
				local e = byId[sid]
				if e then
					n = n + 1
					local items = itemsOf(e.st)
					local qid = tostring(items[1] or ""):match("^Q:(%d+)")
					local v = qid and R.Quest(tonumber(qid)) or nil
					-- a hand-in is at the TURN-IN NPC (not the giver); a pickup is at the giver
					local kind = tostring(items[1] or ""):match(":([%u_]+)$")
					local who = v and (kind == "TURN_IN" and ((v.turnIn and v.turnIn.name) or v.giverName) or (v.giverName or (v.turnIn and v.turnIn.name))) or nil
					add(string.format("%d. Travel to %s%s", n, who and tostring(who) or "the next stop", e.measured and string.format(" (%.0f yd from you)", e.dist) or " (distance not measured)"))
					for _, id in ipairs(items) do add("   " .. sentence(id)) end
				end
			end
		else
			add("(none)")
		end

		-- the stops nearest to you (plus every stop in the sequence); the rest is counted, not listed
		local inSeq = {}
		for _, sid in ipairs(d.sequence or {}) do inSeq[sid] = true end
		local shown, measuredRest, unmeasured = {}, {}, 0
		for _, e in ipairs(stops) do
			if inSeq[e.st.id] then shown[#shown + 1] = e
			elseif e.measured then measuredRest[#measuredRest + 1] = e
			else unmeasured = unmeasured + 1 end
		end
		table.sort(measuredRest, function(x, y) if x.dist ~= y.dist then return x.dist < y.dist end return x.st.id < y.st.id end)
		local LIMIT = 15
		local k = 1
		while #shown < LIMIT and measuredRest[k] do shown[#shown + 1] = measuredRest[k]; k = k + 1 end
		local farther = #measuredRest - (k - 1)
		table.sort(shown, function(x, y)
			local dx, dy = x.measured and x.dist or math.huge, y.measured and y.dist or math.huge
			if dx ~= dy then return dx < dy end
			return x.st.id < y.st.id
		end)
		add("")
		add("--- NEAREST RELEVANT STOPS ---")
		for _, e in ipairs(shown) do
			local dtext = e.measured and string.format("%.0f yd", e.dist) or "distance not measured"
			local net = e.first and string.format(" | best plan from here: net %s over %s s%s", num(e.first.net), num(e.first.secs, "%.0f"), inSeq[e.st.id] and " (in the plan)" or "") or (inSeq[e.st.id] and " | (in the plan)" or "")
			for i, id in ipairs(itemsOf(e.st)) do add(string.format("%s - %s%s", label(id), dtext, i == 1 and net or "")) end
		end
		if #shown == 0 then add("(none)") end
		local omitted = farther + unmeasured
		add(string.format("+ %d additional stops omitted (%d farther away, %d with no measurable distance)", omitted, farther, unmeasured))

		-- the candidate funnel: from every known quest down to what is actionable now (counts only; the planner works from the last stage)
		local f = (plan.stats and plan.stats.filtered) or {}
		local function n(k) return f[k] or 0 end
		local kinds = { ACCEPT = 0, TURN_IN = 0, OBJECTIVE = 0 }
		for _, it in pairs(d.items or {}) do if kinds[it.kind] then kinds[it.kind] = kinds[it.kind] + 1 end end
		local known = 0
		for _ in pairs(R.QuestIds()) do known = known + 1 end
		add("")
		add("--- CANDIDATE FUNNEL (known quests -> what is actionable now) ---")
		add(string.format("known quests in the data: %d (this is a universe to filter, not a route)", known))
		add(string.format("in your quest log: %s (active work, from the quest log itself)", tostring(ctx.logCount)))
		add(string.format("not for this character: faction %d, race %d, class %d, repeatable %d | completed already %d | skipped by you %d", n("faction"), n("race"), n("class"), n("repeatable"), n("completed"), n("skipped")))
		add(string.format("holiday / world-event quests (only possible while their event runs, so not offered): %d", n("event")))
		add(string.format("FUTURE (known, not actionable yet): level too high %d, earlier quest in the chain not finished %d | too low to be useful %d | no usable location %d | quest log full %d",
			n("level"), n("prereq"), n("tooLow"), n("noLocation"), n("logFull")))
		add(string.format("CURRENT: %d pickups, %d objectives, %d hand-ins -> %s stops -> %s sequences searched%s", kinds.ACCEPT, kinds.OBJECTIVE, kinds.TURN_IN, tostring(d.stops), tostring(d.sequences),
			d.slotPressure and " | quest log nearly full: hand-ins are not deferred" or ""))
		add("CONDITIONAL: quest-starting items already in your bags are listed (NEW QUEST ITEM); quest-starting DROPS you have not picked up are not modelled, and none is treated as a current quest")

		-- quests Codex cannot place: which layer lacks the data (provenance, never a guess)
		add("")
		add("--- NOT PLACED (no usable location) ---")
		local unplaced = d.unlocatedIds or {}
		if #unplaced == 0 then add("(none)") end
		local QB = ns.QuestieBridge
		local qdb = QB and QB.Available() or false
		-- the game's own quest-map points for the map you are on (read only; present on Forever but never probed, so shown raw): another possible source
		local poi, poiCount, poiState = {}, 0, "API not present"
		if type(C_QuestLog) == "table" and type(C_QuestLog.GetQuestsOnMap) == "function" and l.map then
			local okP, list = pcall(C_QuestLog.GetQuestsOnMap, l.map)
			if okP and type(list) == "table" then
				poiState = "ok"
				for _, e in ipairs(list) do
					if type(e) == "table" and type(e.questID) == "number" then poi[e.questID] = e; poiCount = poiCount + 1 end
				end
			else
				poiState = okP and "returned nothing usable" or "error"
			end
		end
		if #unplaced > 0 then add("(objective slot meaning is unverified on Forever: a number that is really an item id can coincide with an NPC id, so the NPC counts are a ceiling, not a fact)") end
		if #unplaced > 0 then add(string.format("game quest-map points on map %s (C_QuestLog.GetQuestsOnMap): %s, %d quest(s)", tostring(l.map), poiState, poiCount)) end
		for _, id in ipairs(unplaced) do
			add(label(id))
			local qid = tonumber(tostring(id):match("^Q:(%d+)"))
			local v = qid and R.Quest(qid) or nil
			local pe = qid and poi[qid] or nil
			add("    game map point: " .. (pe and string.format("%s, %s", num(pe.x, "%.3f"), num(pe.y, "%.3f")) or (poiState == "ok" and "none on this map" or poiState)))
			if not v then
				add("    Codex data: no pack (observed, QuestieDB, ATT) knows this quest")
			else
				local pv = v.prov or {}
				local oc = v.objCoords and #v.objCoords or 0
				add(string.format("    Codex data: giver place %s | turn-in %s | objective places %s", v.loc and ("yes (" .. tostring(v.loc.src) .. ")") or "none",
					v.turnIn and (v.turnIn.map and ("yes (" .. tostring(pv.turnIn) .. ")") or ((v.turnIn.name or v.turnIn.npc) and "NPC known, no position" or "none")) or "none",
					oc > 0 and (oc .. " (" .. tostring(pv.objCoords) .. ")") or "none"))
			end
			if qdb and qid then
				local q = QB.Describe(qid)
				if q and q.error then
					add("    QuestieDB: error reading it: " .. q.error)
				elseif q and not q.known then
					add("    QuestieDB: does not have this quest (UNKNOWN, not 'no such quest')")
				elseif q then
					local function npcText(n) return n and string.format("%s%s", n.name or ("NPC #" .. tostring(n.npc)), n.known and (n.hasLocation and ", has a position" or ", NO position") or ", NPC not in QuestieDB") or "none" end
					local objs = {}
					for _, o in ipairs(q.objectives) do objs[#objs + 1] = string.format("slot %s: %d entries (%d NPCs with a position)", tostring(o.slot), o.entries, o.npcWithLocation) end
					add(string.format("    QuestieDB: giver %s | turn-in %s | objectives: %s", npcText(q.giver), npcText(q.turnIn), #objs > 0 and table.concat(objs, "; ") or "none listed"))
				end
			end
		end
		if qdb then
			local ents = QB.Entities()
			add("QuestieDB tables exposed: " .. (ents and #ents > 0 and table.concat(ents, ", ") or "none"))
		end
	end

	-- the quest log
	add("")
	add("--- QUEST LOG (" .. tostring(ctx.logCount) .. ") ---")
	local ids = {}
	for id in pairs(ctx.log or {}) do ids[#ids + 1] = id end
	table.sort(ids)
	for _, id in ipairs(ids) do
		local e = ctx.log[id]
		local obj = {}
		for _, o in ipairs(e.objectives or {}) do
			obj[#obj + 1] = string.format("%s %s/%s", tostring(o.text or "?"), tostring(o.numFulfilled or "?"), tostring(o.numRequired or "?"))
		end
		local tg = ctx.questTag and ctx.questTag(id)
		add(string.format("  %s %s%s%s%s", tostring(id), tostring(e.title), e.complete and " [READY TO TURN IN]" or "", tg and string.format(" [tag %s %s]", tostring(tg.id), tostring(tg.name)) or "", #obj > 0 and (" | " .. table.concat(obj, "; ")) or ""))
	end
	do
		local api = (type(C_QuestLog) == "table" and type(C_QuestLog.GetQuestTagInfo) == "function") and "C_QuestLog.GetQuestTagInfo" or (type(GetQuestTagInfo) == "function" and "GetQuestTagInfo" or "none found")
		local tagged, dungeon = 0, 0
		for _, id in ipairs(ids) do
			local tg = ctx.questTag and ctx.questTag(id)
			if tg then tagged = tagged + 1 end
			if ns.Dungeons and ns.Dungeons.IsDungeon(ctx, id) then dungeon = dungeon + 1 end
		end
		add(string.format("quest tags (game, unverified on Forever): API %s | %d of %d logged quests came back tagged | %d dungeon-style | area-name API %s", api, tagged, #ids, dungeon, (type(C_Map) == "table" and type(C_Map.GetAreaInfo) == "function") and "present" or "absent"))
	end
	if ns.QuestItems then
		local okQ, qlines = pcall(ns.QuestItems.ReportLines)
		if okQ then for _, l in ipairs(qlines) do add(l) end else add("QUEST-STARTING ITEMS: error: " .. tostring(qlines)) end
	end
	if ns.OfferProbe then
		local okF, flines = pcall(ns.OfferProbe.ReportLines)
		if okF then for _, l in ipairs(flines) do add(l) end else add("OFFERED QUESTS PROBE: error: " .. tostring(flines)) end
	end
	do
		local okN, nlines = pcall(D.AvailabilityLines)
		if okN then for _, l in ipairs(nlines) do add(l) end else add("NOW CANDIDATE EVIDENCE: error: " .. tostring(nlines)) end
	end
	do
		local okO, olines = pcall(D.OpportunityLines)
		if okO then for _, l in ipairs(olines) do add(l) end else add("OPPORTUNITIES: error: " .. tostring(olines)) end
	end
	if ns.State and ns.State.perf then
		local okP, plines = pcall(D.PerformanceLines)
		if okP then for _, l in ipairs(plines) do add(l) end else add("PERFORMANCE: error: " .. tostring(plines)) end
	end
	local sk = P.SkippedKeys()
	add("skipped: " .. (#sk > 0 and table.concat(sk, " ") or "none"))
	if ns.ItemProbe then
		local okI, lines = pcall(ns.ItemProbe.ReportLines)
		if okI then
			add("")
			for _, l in ipairs(lines) do add(l) end
		else
			add("ITEM PROBE: error: " .. tostring(lines))
		end
	end
	if ns.Gear then
		local okG, glines = pcall(ns.Gear.ReportLines)
		if okG then
			for _, l in ipairs(glines) do add(l) end
		else
			add("EQUIPPED ITEM FACTS: error: " .. tostring(glines))
		end
	end
	if ns.EligibilityEvidence then
		local extra = {}
		if ns.ItemProbe and ns.ItemProbe.EventStatus then
			extra[1] = "  events it relies on: " .. ns.ItemProbe.EventStatus("QUEST_DETAIL") .. " " .. ns.ItemProbe.EventStatus("QUEST_COMPLETE") .. " " .. ns.ItemProbe.EventStatus("PLAYER_EQUIPMENT_CHANGED")
				.. " (observations are recorded at those moments and when the report is made; detail: /dump ForeverCodexDB.items.evidence)"
		end
		local observed = function(name)
			if name == "IsUsableItem" and ns.ItemProbe and ns.ItemProbe.Status then
				local stt, detail = ns.ItemProbe.Status("usable")
				return stt .. " (" .. tostring(detail) .. ")"
			end
		end
		local okE, elines = pcall(ns.EligibilityEvidence.ReportLines, extra, { observed = observed })
		if okE then
			for _, l in ipairs(elines) do add(l) end
		else
			add("ELIGIBILITY EVIDENCE: error: " .. tostring(elines))
		end
	end
	if ns.Advisor then
		local okA, alines = pcall(ns.Advisor.ReportLines)
		if okA then
			for _, l in ipairs(alines) do add(l) end
		else
			add("REWARD ADVISOR: error: " .. tostring(alines))
		end
	end
	if ns.AreaEvidence then
		local okA, alines = pcall(ns.AreaEvidence.ReportLines)
		if okA then for _, l in ipairs(alines) do add(l) end end
	end
	if ns.QuestTimers then
		local okT, tlines = pcall(ns.QuestTimers.ReportLines, ns.State and ns.State.ctx)
		if okT then for _, l in ipairs(tlines) do add(l) end end
	end
	if ns.Feedback then
		local okF, flines = pcall(ns.Feedback.ReportLines)
		if okF then for _, l in ipairs(flines) do add(l) end end
	end
	if ns.Professions then
		local okP, plines = pcall(ns.Professions.ReportLines, ns.State and ns.State.ctx)
		if okP then
			for _, l in ipairs(plines) do add(l) end
		else
			add("PROFESSIONS: error: " .. tostring(plines))
		end
	end
	if ns.SpellTraining then
		local okS, slines = pcall(ns.SpellTraining.ReportLines, ns.State and ns.State.ctx)
		if okS then
			for _, l in ipairs(slines) do add(l) end
		else
			add("SPELL TRAINING: error: " .. tostring(slines))
		end
	end

	add("")
	add("--- FULL DIAGNOSTICS ---")
	for _, line in ipairs(lines) do add(line) end
	return L
end

--- Takes a fresh snapshot and shows the playtest report in a copyable window (falls back to chat when the window cannot be built).
function D.Report()
	if ns.State then ns.State.Recompute("report") end
	local snap = D.Snapshot()
	local lines = D.Lines(snap)
	D.Store(snap)
	local okL, report = pcall(D.PlaytestLines, snap, lines)
	if not okL then
		ns.RecordError("report", report)
		report = lines
	end
	local text = table.concat(report, "\n")
	if ns.UI and ns.UI.ShowReport then
		local ok = pcall(ns.UI.ShowReport, text)
		if ok then return snap, report end
	end
	for _, line in ipairs(report) do ns.Say(line) end
	return snap, report
end
