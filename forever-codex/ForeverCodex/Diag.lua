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
		journeyEntries = #P.Char().journey.entries, markers = ns.Markers and ns.Markers.Status() or nil,
		arrow = ns.Arrow and { on = P.ArrowOn(), reason = ns.Arrow.state.reason, calibrated = ns.Arrow.Calibration() ~= nil, flip = P.ArrowFlip() } or nil,
		pins = ns.Pins and ns.Pins.Status() or nil }
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
		else
			L[#L + 1] = "QuestieDB: NOT in use (" .. tostring(q.state) .. "). " .. tostring(q.message)
		end
	end
	if s.player then
		local p = s.player
		L[#L + 1] = string.format("Player experience: setup %s | waypoint following %s (%s%s) | journey entries %d", p.setupDone and "done" or "NOT done", p.navigation and "on" or "off",
			tostring(p.navStatus), p.navOwned and (", Codex pin placed for " .. tostring(p.navOwned.action)) or "", p.journeyEntries)
		if p.arrow then
			L[#L + 1] = string.format("  arrow: %s (%s), calibrated %s, flip %s | map pins: %s, world map %s, minimap %s, pins now %s (UNPROVEN on Forever)", p.arrow.on and "on" or "off", tostring(p.arrow.reason),
				tostring(p.arrow.calibrated), tostring(p.arrow.flip), p.pins and (p.pins.on and "on" or "off") or "?", p.pins and p.pins.worldMap or "?", p.pins and p.pins.minimap or "?", p.pins and p.pins.desired or "?")
		end
		if p.party then
			L[#L + 1] = string.format("  party news: %s | addon messages %s | party chat %s | shared items this session %d | markers: %s (test %s)", p.party.mode,
				p.party.addonMessages and "available" or "UNAVAILABLE", p.party.chat and "available" or "UNAVAILABLE", p.party.feed,
				p.markers and (p.markers.enabled and "on" or "off") or "?", p.markers and p.markers.probe or "?")
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

local MAX_STORED = 5

--- Stores a snapshot in ForeverCodexDB.diag (kept to the last 5).
function D.Store(snap)
	local list = P.Root().diag
	list[#list + 1] = snap
	while #list > MAX_STORED do table.remove(list, 1) end
end

--- Takes a fresh snapshot, prints it, stores it. Returns the snapshot and its lines.
function D.Print()
	if ns.State then ns.State.Recompute() end
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
	local okC, card = pcall(ns.Presenter.Card, plan, ctx)
	if okC and card then
		local function show(label, it)
			if not it then return end
			add(string.format("%s: %s | who: %s | where: %s | detail: %s | why: %s", label, tostring(it.title), tostring(it.who), tostring(it.where), tostring(it.detail), tostring(it.why)))
			if it.progress then add("    progress: " .. tostring(type(it.progress) == "table" and (tostring(it.progress.have) .. "/" .. tostring(it.progress.need)) or it.progress)) end
		end
		if card.now then show("NOW", card.now) else add("NOW: " .. tostring(card.empty and card.empty.title or "nothing")) end
		show("ALSO DO", card.alsoDo)
		if card.thenLine then add("THEN: " .. tostring(card.thenLine)) end
		local okN, near = pcall(ns.Nearby.List, plan, ctx)
		if okN and #near > 0 then
			for _, n in ipairs(near) do add(string.format("NEARBY: %s | %s | %s", tostring(n.title), tostring(n.detail), tostring(n.where))) end
		else
			add("NEARBY: nothing")
		end
		if #card.reminders > 0 then add("In your log, not placed on the map: " .. table.concat(card.reminders, ", ")) end
	end
	local nfy = ns.NewForYou and ns.NewForYou.Active()
	add("NEW FOR YOU: " .. (nfy and (#nfy.items .. " item(s) at level " .. tostring(nfy.level)) or "hidden"))
	if ns.UI and ns.UI.main then add(string.format("Window height: %s", tostring(ns.UI.main.height))) end

	-- why the planner chose it (a traced re-run on the same context)
	add("")
	add("--- WHY (planner trace) ---")
	local okT, traced = pcall(ns.PlanAdapter.Compute, ctx, { prevNowId = plan.now and plan.now.id or nil, trace = true })
	local d = okT and traced and traced.diag or plan.diag
	if d then
		local flags = {}
		for _, k in ipairs({ "localOnly", "localWork", "turnInFirst", "stuck", "pinnedFirst", "routeZoneOnly" }) do if d[k] then flags[#flags + 1] = k end end
		add(string.format("reason=%s | flags: %s | net %s over ~%s s | unknown legs %s | %s stops, %s sequences", tostring(d.reason), #flags > 0 and table.concat(flags, ",") or "none",
			num(d.net), num(d.seconds, "%.0f"), tostring(d.unknownLegs), tostring(d.stops), tostring(d.sequences)))
		add("sequence: " .. (d.sequence and #d.sequence > 0 and table.concat(d.sequence, " > ") or "(none)"))
		local me = l.available and { map = l.map, x = l.x, y = l.y, world = l.world or false } or nil
		for _, st in ipairs(d.stopList or {}) do
			local dist = me and ns.Engine.Distance(ctx, me, { map = st.map, x = st.x, y = st.y }) or nil
			local first = d.bestByFirst and d.bestByFirst[st.id]
			add(string.format("  stop %s [%s] map %s | %s yd away | best plan starting here: net %s over %s s%s", tostring(st.id), table.concat(st.items, ","), tostring(st.map),
				dist and (dist >= 1e8 and "unmeasurable" or string.format("%.0f", dist)) or "?", first and num(first.net) or "?", first and num(first.secs, "%.0f") or "?",
				first and first.unknown > 0 and (" (" .. first.unknown .. " unknown legs)") or ""))
		end
		local rej = {}
		for _, r in ipairs(d.rejected or {}) do rej[#rej + 1] = r.id .. ":" .. r.code .. (r.seconds and ("(" .. r.seconds .. "s)") or "") end
		if #rej > 0 then add("rejected ALSO DO: " .. table.concat(rej, " ")) end
		if d.unlocatedIds and #d.unlocatedIds > 0 then add("no location (reminders): " .. table.concat(d.unlocatedIds, " ")) end
		add("params: " .. (d.params and string.format("timeValue=%s stickiness=%s", tostring(d.params.timeValue), tostring(d.params.stickiness)) or "?"))
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
		add(string.format("  %s %s%s%s", tostring(id), tostring(e.title), e.complete and " [READY TO TURN IN]" or "", #obj > 0 and (" | " .. table.concat(obj, "; ")) or ""))
	end
	local sk = P.SkippedKeys()
	add("skipped: " .. (#sk > 0 and table.concat(sk, " ") or "none"))

	add("")
	add("--- FULL DIAGNOSTICS ---")
	for _, line in ipairs(lines) do add(line) end
	return L
end

--- Takes a fresh snapshot and shows the playtest report in a copyable window (falls back to chat when the window cannot be built).
function D.Report()
	if ns.State then ns.State.Recompute() end
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
