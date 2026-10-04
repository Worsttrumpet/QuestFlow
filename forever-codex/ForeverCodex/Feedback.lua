-- ForeverCodex.Feedback: REPORT A PROBLEM. A player clicks one button, says what went wrong in a sentence, and Codex captures the technical context itself.
--
-- WHAT THE CLIENT ALLOWS (evidence boundary; docs/CODEX_FEEDBACK.md): a WoW addon runs in a sandbox with NO outbound network access, no arbitrary file writes, no clipboard
-- API and no way to open a URL or call a Discord webhook. Nothing in this repository shows Forever lifting any of that, and Codex does not pretend otherwise (F.Capabilities
-- looks for such functions and the report states what it found; it never calls them). What an addon CAN do, proven in this project:
--   * keep data in SavedVariables (written at /reload and at logout; /reload is reliable on Forever, logout saves have failed intermittently, M8.0), and
--   * show text in an EditBox the player copies with Ctrl+C (the existing /codex report window does this).
-- So the delivery is: the report is SAVED LOCALLY (ForeverCodexDB.feedback) and shown as one compact block the player copies and pastes where the developer asked. It is NEVER
-- described as "sent". The report is a stable, structured table (schema 1) with a deterministic JSON form, so a future helper, website or Discord relay can consume it unchanged.
--
-- This is REPORT A PROBLEM: small, targeted, written by the player. It is deliberately separate from a future opt-in HELP IMPROVE CODEX (richer telemetry export); both can share
-- the report id / session / schema conventions defined here.
--
-- PRIVACY: included: Codex version, build, interface, class, level, faction, race, map and position, zone, the quest log (ids, titles, completion), what the Codex window shows and
-- why, navigation state, a few recent telemetry events, up to three recent Codex error strings (file paths removed). NOT included: character name, realm, account or
-- Battle.net information, anything from outside the game, GUIDs, machine or filesystem information. The player's own sentence is included as written (length capped).

local _, ns = ...
local F = {}
ns.Feedback = F

F.SCHEMA = 1
F.MAX_TEXT = 600            -- characters of the player's sentence
F.MAX_JSON = 3500           -- bytes of the structured block (sections are dropped, least useful first, to fit)
F.MAX_STORED = 20           -- reports kept in SavedVariables (the oldest are dropped)
F.DUPLICATE_SECONDS = 5     -- the same report created twice within this many seconds is one report

F.CATEGORIES = {
	{ key = "wrong", label = "Codex recommended something wrong" },
	{ key = "missing", label = "A quest is missing" },
	{ key = "nav", label = "Navigation / arrow is wrong" },
	{ key = "spell", label = "Spell / profession issue" },
	{ key = "broken", label = "Something isn't working" },
	{ key = "suggestion", label = "Suggestion" },
	{ key = "other", label = "Other" },
}
local CATEGORY = {}
for _, c in ipairs(F.CATEGORIES) do CATEGORY[c.key] = c end

local function now() return type(_G.time) == "function" and _G.time() or 0 end

-- ---------------------------------------------------------------- session and ids

local session
function F.Session()
	if not session then
		local r = type(_G.math.random) == "function" and math.random(0, 0xFFFF) or 0
		session = string.format("%x%04x", now() % 0x1000000, r)
	end
	return session
end
function F._Reset() session = nil end

local function db()
	if type(ForeverCodexDB) ~= "table" then return nil end
	local s = ForeverCodexDB.feedback
	if type(s) ~= "table" then s = {}; ForeverCodexDB.feedback = s end
	s.v = s.v or F.SCHEMA
	s.seq = type(s.seq) == "number" and s.seq or 0
	s.reports = type(s.reports) == "table" and s.reports or {}
	return s
end

-- ---------------------------------------------------------------- privacy and size helpers

--- Removes filesystem-looking text from a string (drive paths, home directories, Interface / WTF paths) and control characters.
function F.Scrub(s, limit)
	s = tostring(s or "")
	s = s:gsub("%a:[\\/][^%s\"']*", "<path>"):gsub("/home/[^%s\"']*", "<path>"):gsub("[Ii]nterface[\\/][^%s:\"']*", "<path>"):gsub("WTF[\\/][^%s\"']*", "<path>")
	s = s:gsub("[%z\1-\8\11\12\14-\31]", "")
	if limit and #s > limit then s = s:sub(1, limit - 3) .. "..." end
	return s
end

local function esc(s)
	return (s:gsub('[%c"\\]', function(c)
		if c == '"' then return '\\"' elseif c == "\\" then return "\\\\" elseif c == "\n" then return "\\n" elseif c == "\r" then return "\\r" elseif c == "\t" then return "\\t" end
		return string.format("\\u%04x", c:byte())
	end))
end

--- Deterministic JSON (sorted keys). Tables whose keys are 1..n are arrays. nil values are skipped; numbers keep up to 4 decimals; functions and userdata are dropped.
function F.ToJson(v)
	local t = type(v)
	if t == "string" then return '"' .. esc(v) .. '"' end
	if t == "boolean" then return v and "true" or "false" end
	if t == "number" then
		if v ~= v or v == math.huge or v == -math.huge then return "null" end
		if v == math.floor(v) then return string.format("%d", v) end
		return (string.format("%.4f", v):gsub("0+$", ""):gsub("%.$", ""))
	end
	if t ~= "table" then return "null" end
	local n = 0
	for _ in pairs(v) do n = n + 1 end
	if n == 0 then return "[]" end
	if #v == n then
		local out = {}
		for i = 1, n do out[i] = F.ToJson(v[i]) end
		return "[" .. table.concat(out, ",") .. "]"
	end
	local keys = {}
	for k in pairs(v) do if type(k) == "string" or type(k) == "number" then keys[#keys + 1] = tostring(k) end end
	table.sort(keys)
	local out = {}
	for _, k in ipairs(keys) do
		local val = v[k]
		if val == nil then val = v[tonumber(k)] end
		local j = F.ToJson(val)
		if j ~= "null" or val ~= nil then out[#out + 1] = '"' .. esc(k) .. '":' .. j end
	end
	return "{" .. table.concat(out, ",") .. "}"
end

-- ---------------------------------------------------------------- what the client can and cannot do (read-only look; nothing here is ever CALLED)

--- { { name, group, present } } for the functions that would be needed to send a report out of the game. A presence check only.
function F.Capabilities()
	local probes = {
		{ "C_HTTP", "http" }, { "HttpRequest", "http" }, { "C_WebRequest", "http" }, { "SendHttpRequest", "http" },
		{ "OpenURL", "url" }, { "LaunchURL", "url" }, { "C_System.OpenURL", "url" },
		{ "CopyToClipboard", "clipboard" }, { "C_Clipboard", "clipboard" },
		{ "io", "file" },
	}
	local out = {}
	for _, p in ipairs(probes) do
		local present
		local a, b = p[1]:match("^(.-)%.(.*)$")
		if a then present = type(_G[a]) == "table" and _G[a][b] ~= nil else present = _G[p[1]] ~= nil end
		out[#out + 1] = { name = p[1], group = p[2], present = present and true or false }
	end
	return out
end

-- ---------------------------------------------------------------- the report

local function safeSection(report, name, fn)
	local ok, v = pcall(fn)
	if ok then report[name] = v else
		report.errors = report.errors or {}
		report.errors[#report.errors + 1] = name .. ": " .. F.Scrub(v, 80)
	end
end

local function round(n, p) if type(n) ~= "number" then return nil end local m = 10 ^ (p or 0) return math.floor(n * m + 0.5) / m end

--- The facts about ONE planner action that explain why Codex showed it (reusing the planner's own reason codes and offer evidence; no second explanation engine).
local function describeAction(a, plan, ctx)
	if not a then return nil end
	local Pl = ns.Planner
	local out = { id = a.id, quest = a.quest, kind = a.kind, type = a.type, name = a.name, npc = a.giver, evidence = a.evidence, state = a.state, stateWhy = a.stateWhy }
	if a.kind == "ACCEPT" then
		local st, ev = Pl.OfferState(a)
		out.offerState, out.actionability = st, Pl.Actionability(a)
		if ev then out.offer = { kind = ev.kind, via = ev.via, npc = ev.npc, stale = ev.stale, contradicted = ev.contradicted } end
		out.restrictionUnknown = a.restrictionUnknown
		out.offered = a.offered
	end
	local pos, status, assumed = Pl.Locate(a)
	if pos then
		local kind, src
		for _, t in ipairs(a.targets or {}) do
			if t.where and t.where.points and t.where.points[1] then kind, src = t.where.kind, t.prov and t.prov.src break end
		end
		out.where = { map = pos.map, x = round(pos.x, 3), y = round(pos.y, 3), status = status, kind = kind, src = src, assumed = assumed or nil }
		local me = ctx and ctx.loc and ctx.loc.available and { map = ctx.loc.map, x = ctx.loc.x, y = ctx.loc.y, world = ctx.loc.world or false }
		if me then
			local d = ns.Engine.Distance(ctx, me, pos)
			if d and d < ns.Engine.DIFFERENT_CONTINENT then out.yards = round(d, 0) else out.yards = "unmeasured" end
		end
	else
		out.where = "none"
	end
	local reasons = plan and plan.diag and plan.diag.reasons and plan.diag.reasons[a.id]
	if reasons then
		out.codes = {}
		for _, r in ipairs(reasons) do out.codes[#out.codes + 1] = r.code end
	end
	return out
end

local function windowSection(plan, ctx)
	local card = ns.Presenter.Card(plan, ctx)
	local out = { guidance = card.guidance or nil }
	if card.now then out.now = { title = card.now.title, who = card.now.who, dist = card.now.dist or card.now.whereShort or card.now.where, why = card.now.why, note = card.now.navNote } end
	if plan and plan.now then out.nowAction = describeAction(plan.now, plan, ctx) end
	out.ready = {}
	for i, r in ipairs(card.ready or {}) do if i <= 5 then out.ready[#out.ready + 1] = { title = r.title, quest = r.quest, who = r.who, where = r.where } end end
	out.also = {}
	for i, r in ipairs(card.also or {}) do if i <= 4 then out.also[#out.also + 1] = { title = r.title, quest = r.quest, kind = r.kind, dist = r.dist, offered = r.offered } end end
	out.spells = card.spells and #card.spells.rows or 0
	out.professions = card.professions and #card.professions.rows or 0
	if card.thenLine then out.thenLine = card.thenLine end
	if plan and plan.alsoDo then out.alsoDo = describeAction(plan.alsoDo, plan, ctx) end
	if not (card.now) and card.empty then out.empty = card.empty.title end
	return out
end

local function questLog(ctx)
	local ids = {}
	for id in pairs(ctx and ctx.log or {}) do ids[#ids + 1] = id end
	table.sort(ids)
	local out = {}
	for i, id in ipairs(ids) do
		if i > 25 then out.more = #ids - 25 break end
		local e = ctx.log[id]
		local obj
		for _, o in ipairs(e.objectives or {}) do
			if type(o) == "table" and not o.finished and type(o.have) == "number" and type(o.need) == "number" then obj = (obj and (obj .. " ") or "") .. o.have .. "/" .. o.need end
		end
		out[#out + 1] = { id = id, title = F.Scrub(e.title, 40), done = e.complete or nil, obj = obj }
	end
	return out
end

--- Builds (does not store) a report. opts = { category, text, from = "NOW" | "READY" | "WINDOW" | nil }. Never raises; a failing section is named in report.errors.
function F.Build(opts)
	opts = opts or {}
	local ctx, plan = ns.State and ns.State.ctx, ns.State and ns.State.plan
	local cat = CATEGORY[opts.category] and opts.category or "other"
	local report = { schema = F.SCHEMA, session = F.Session(), at = now(), category = cat, from = opts.from or "WINDOW", text = F.Scrub(opts.text, F.MAX_TEXT) }
	report.version = ForeverCodex and ForeverCodex.VERSION
	safeSection(report, "client", function()
		local ok, v, build, _, iface = pcall(_G.GetBuildInfo)
		return { build = ok and build or nil, game = ok and v or nil, interface = ok and iface or nil }
	end)
	if ctx then
		safeSection(report, "char", function()
			local c = ctx.char or {}
			return { class = c.classToken or c.class, level = c.level, faction = c.faction, race = c.raceKey or c.race }
		end)
		safeSection(report, "loc", function()
			local l = ctx.loc or {}
			if not l.available then return { available = false } end
			return { map = l.map, x = round(l.x, 3), y = round(l.y, 3), zone = F.Scrub(l.zone, 40), subzone = F.Scrub(l.subzone, 40) }
		end)
		safeSection(report, "window", function() return windowSection(plan, ctx) end)
		safeSection(report, "log", function() return questLog(ctx) end)
	else
		report.note = "Codex had not computed a plan yet"
	end
	safeSection(report, "plan", function()
		local d = plan and plan.diag or {}
		return { reason = d.reason, candidates = d.candidates, unlocated = d.unlocated, held = d.held and d.held.n or 0, possible = d.possible and d.possible.n or 0,
			strategy = plan and plan.strategy, routeZone = plan and plan.routeZone }
	end)
	safeSection(report, "nav", function()
		local N = ns.Navigation
		local np = N.NoPin and N.NoPin()
		return { status = N.Status(), noPin = np and np.reason or nil, hasTarget = N.Target() ~= nil }
	end)
	safeSection(report, "events", function()
		local out = {}
		if ns.Telemetry then
			local list = ns.Telemetry.Events()
			for i = math.max(1, #list - 7), #list do local e = list[i]; out[#out + 1] = { e = e.e, t = round(e.t, 0), q = e.q or e.quest } end
		end
		return out
	end)
	if cat == "spell" then
		safeSection(report, "extra", function()
			local lines = {}
			for _, mod in ipairs({ ns.Professions, ns.SpellTraining }) do
				for _, l in ipairs(mod and mod.ReportLines(ctx) or {}) do lines[#lines + 1] = F.Scrub(l, 160) end
			end
			return lines
		end)
	end
	if #ns.errors > 0 then
		report.codexErrors = {}
		for i = math.max(1, #ns.errors - 2), #ns.errors do report.codexErrors[#report.codexErrors + 1] = F.Scrub(ns.errors[i], 160) end
	end
	return report
end

-- sections dropped, in this order, until the structured block fits MAX_JSON
local DROP_ORDER = { "extra", "events", "codexErrors", "log", "plan", "nav" }

--- Shrinks a report to fit F.MAX_JSON. Returns the JSON string; report.trimmed lists what was dropped.
function F.Compact(report)
	local json = F.ToJson(report)
	local i = 1
	while #json > F.MAX_JSON and DROP_ORDER[i] do
		if report[DROP_ORDER[i]] ~= nil then
			report[DROP_ORDER[i]] = nil
			report.trimmed = report.trimmed or {}
			report.trimmed[#report.trimmed + 1] = DROP_ORDER[i]
			json = F.ToJson(report)
		end
		i = i + 1
	end
	if #json > F.MAX_JSON and report.window then      -- last resort: the window section keeps only what the player was looking at
		report.window.ready, report.window.also = nil, nil
		report.trimmed = report.trimmed or {}
		report.trimmed[#report.trimmed + 1] = "window.lists"
		json = F.ToJson(report)
	end
	return json
end

--- A short readable summary of the report (a developer reads this first).
local function summary(r)
	local L = {}
	local w = r.window or {}
	L[#L + 1] = string.format("FOREVER CODEX FEEDBACK  id %s  codex %s  build %s", tostring(r.id), tostring(r.version), tostring(r.client and r.client.build))
	L[#L + 1] = string.format("category: %s | from: %s | session %s", (CATEGORY[r.category] or {}).label or r.category, r.from, r.session)
	L[#L + 1] = "player said: " .. (r.text ~= "" and r.text or "(nothing written)")
	if r.char then L[#L + 1] = string.format("character: level %s %s %s %s | map %s at %s, %s", tostring(r.char.level), tostring(r.char.faction), tostring(r.char.race), tostring(r.char.class), tostring(r.loc and r.loc.map), tostring(r.loc and r.loc.x), tostring(r.loc and r.loc.y)) end
	local a = w.nowAction
	if w.now then
		L[#L + 1] = string.format("NOW shown: %s | %s | %s%s", tostring(w.now.title), a and (tostring(a.kind) .. " Q" .. tostring(a.quest)) or "no action", tostring(w.now.dist), w.guidance and " | guidance only" or "")
		if a then L[#L + 1] = string.format("  evidence %s | state %s | offer %s | where %s | planner reasons %s", tostring(a.evidence), tostring(a.state), tostring(a.offerState), type(a.where) == "table" and (tostring(a.where.kind) .. "/" .. tostring(a.where.status)) or "none", a.codes and table.concat(a.codes, ",") or "-") end
	elseif w.empty then
		L[#L + 1] = "NOW shown: nothing (" .. w.empty .. ")"
	end
	for _, rd in ipairs(w.ready or {}) do L[#L + 1] = string.format("READY shown: %s (Q%s)", tostring(rd.title), tostring(rd.quest)) end
	return table.concat(L, "\n")
end

--- The text the player copies: a readable summary, then the structured JSON on one line.
function F.Export(report)
	local json = F.Compact(report)
	return summary(report) .. "\n--- data (schema " .. F.SCHEMA .. ") ---\n" .. json, json
end

-- ---------------------------------------------------------------- creating and storing

local lastSig, lastAt, lastReport

--- Creates, stores and returns a report: { id, report, export, json, delivery = "SAVED_LOCAL", sent = false, duplicate }. The same category, text and origin created twice within
-- F.DUPLICATE_SECONDS returns the first report (no second copy). Never raises.
function F.Create(opts)
	opts = opts or {}
	local sig = tostring(opts.category) .. "|" .. tostring(opts.from) .. "|" .. tostring(opts.text)
	if lastReport and sig == lastSig and now() - lastAt <= F.DUPLICATE_SECONDS then
		local dup = {}
		for k, v in pairs(lastReport) do dup[k] = v end
		dup.duplicate = true
		return dup
	end
	local s = db()
	local report = F.Build(opts)
	if s then
		s.seq = s.seq + 1
		report.id = string.format("FC-%s-%d", report.session, s.seq)
	else
		report.id = string.format("FC-%s-0", report.session)
	end
	local export, json = F.Export(report)
	local out = { id = report.id, report = report, export = export, json = json, delivery = "SAVED_LOCAL", sent = false, bytes = #export }
	if s then
		s.reports[#s.reports + 1] = { id = report.id, at = report.at, category = report.category, from = report.from, version = report.version, export = export, sent = false }
		while #s.reports > F.MAX_STORED do table.remove(s.reports, 1) end
	else
		out.delivery = "EXPORT_ONLY"                -- no SavedVariables table: the text is only shown
	end
	lastSig, lastAt, lastReport = sig, now(), out
	return out
end

--- The stored reports, oldest first: { { id, at, category, from, version, export, sent } }.
function F.Stored()
	local s = db()
	return s and s.reports or {}
end

--- What the player is told after creating a report. Never says "sent": nothing here sends anything.
function F.StatusText(result)
	if result.delivery == "SAVED_LOCAL" then
		return "Feedback report created and saved locally. It is written to disk at /reload or logout. Copy the text below and send it to the Codex developer; Codex cannot send it for you."
	end
	return "Feedback report ready to export. Copy the text below and send it to the Codex developer; Codex cannot send it for you."
end

function F.ReportLines()
	local L = { "FEEDBACK (Report a problem; Codex cannot send anything out of the game)" }
	local present = {}
	for _, c in ipairs(F.Capabilities()) do if c.present then present[#present + 1] = c.name end end
	L[#L + 1] = "  client functions that could send data out: " .. (#present > 0 and table.concat(present, ", ") .. " (present, NOT used by Codex)" or "none found (http, url, clipboard, file)")
	L[#L + 1] = string.format("  reports stored locally: %d (newest %s) | session %s", #F.Stored(), #F.Stored() > 0 and F.Stored()[#F.Stored()].id or "none", F.Session())
	return L
end
