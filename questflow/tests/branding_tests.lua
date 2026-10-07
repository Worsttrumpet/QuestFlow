-- branding_tests.lua (0.10.4): nothing a player can SEE says Codex. The internal identifiers that keep the old working name (global ForeverCodex, saved variable ForeverCodexDB, frame names,
-- the party prefix, the CODEX_OBSERVED data tag, the theme key "codex", the feedback key codexErrors, the /codex and /fcodex aliases) are not text a player reads, so they are not
-- scanned for; the one report line that names the real saved variable for /dump is allowed by name. The scan drives the addon (slash commands, the pages, the report, the feedback
-- window, the reward tooltip) and fails on any other "codex" in chat, in the windows' texts, in the report or in a tooltip.

local H = ...
local check, section, boot = H.check, H.section, H.boot

local ALLOWED = { "ForeverCodexDB", "/codex", "/fcodex", "codexErrors" }     -- codexErrors: a key of the pasted feedback JSON (schema 1), kept so reports stay readable by the same tools
local function leaks(s)
	if type(s) ~= "string" then return nil end
	local t = s
	for _, a in ipairs(ALLOWED) do t = t:gsub(a:gsub("%p", "%%%0"), "") end
	if t:lower():find("codex", 1, true) then return s end
end

section("branding: nothing a player can see says Codex")
do
	local ns = boot({ char = { level = 15, class = "Rogue", classToken = "ROGUE", name = "Thrall" }, synthetic = true })
	local W = H.world()
	local seen, bad = 0, {}
	local function scan(s, where) seen = seen + 1; local l = leaks(s); if l then bad[#bad + 1] = where .. ": " .. l:sub(1, 90) end end

	-- chat output of every slash command a player can type
	local captured = {}
	rawset(ns.UI, "ShowReport", function(t) captured[#captured + 1] = t end)
	for _, cmd in ipairs({ "", "help", "next", "report", "diag", "setup", "options", "world", "journey", "appendices", "style", "zone", "where", "questiedb", "telemetry summary", "feedback",
		"spells", "professions", "party", "arrow", "tracker", "nav", "planner", "hardcore", "minimap", "skip", "unskip", "nonsense-command" }) do
		pcall(H.slash, cmd)
	end
	for _, m in ipairs(W.chat) do scan(m, "chat") end
	for _, t in ipairs(captured) do for line in (t .. "\n"):gmatch("([^\n]*)\n") do scan(line, "report") end end
	check(#captured >= 1, "(setup) the report window was filled")

	-- the windows' texts: walk the UI tables for fontstring text
	local visited = {}
	local function walk(t, path, depth)
		if type(t) ~= "table" or visited[t] or depth > 6 then return end
		visited[t] = true
		if type(t.__text) == "string" and t.__text ~= "" then scan(t.__text, path) end
		for k, v in pairs(t) do
			if type(v) == "table" and type(k) ~= "table" then walk(v, path .. "." .. tostring(k), depth + 1) end
		end
	end
	for _, f in ipairs(W.frames) do walk(f, "frame:" .. tostring(f.__name or "?"), 0) end
	walk(ns.UI, "UI", 0)
	walk(ns.DevUI, "DevUI", 0)

	-- names and labels registered for display
	for key, th in pairs(ns.Theme.THEMES) do scan(th.name, "theme " .. key); scan(th.desc, "theme desc " .. key) end
	for _, def in ipairs(ns.UI.pageDefs or {}) do scan(def.label, "page label " .. tostring(def.key)) end
	check(seen > 200, "the scan really looked at the interface (" .. seen .. " texts)")
	check(#bad == 0, "no player-visible text says Codex  [" .. table.concat(bad, " | ", 1, math.min(#bad, 5)) .. "]")
end

section("branding: the report and the feedback text")
do
	local ns = boot({ char = { level = 15, class = "Rogue", classToken = "ROGUE", name = "Thrall" }, synthetic = true })
	local text
	rawset(ns.UI, "ShowReport", function(t) text = t end)
	H.slash("report")
	check(type(text) == "string" and text:find("=== QUEST FLOW DIAGNOSTIC REPORT v", 1, true) == 1, "the report opens with the Quest Flow title and the version")
	check(not leaks(text), "nothing in the whole report says Codex  [" .. tostring(leaks(text) and (text:lower():match(".-codex.-\n") or "")) .. "]")
	check(not text:find("PLAYTEST", 1, true), "and it is not called a playtest report")
	local res = ns.Feedback.Create({ category = "other", text = "test report" })
	check(res and type(res.export) == "string" and res.export ~= "", "(setup) a feedback report was created")
	check(not leaks(res.export), "the feedback text a player copies says Quest Flow, not Codex  [" .. tostring(leaks(res.export) and res.export:lower():match(".-codex.-\n") or "") .. "]")
	check(res.export:find("QUEST FLOW FEEDBACK", 1, true) ~= nil, "and it is headed QUEST FLOW FEEDBACK")
end

section("branding: package and metadata")
do
	local toc = H.readFile(H.addonDir .. "/QuestFlow.toc")
	check(toc:find("## Title: Quest Flow\n", 1, true) ~= nil, "the .toc title is Quest Flow")
	local rest = toc:gsub("ForeverCodexDB", ""):gsub("\n[^\n#][^\n]*", "")
	check(not rest:lower():find("codex", 1, true), "no Codex in the .toc metadata lines  [" .. (rest:lower():match(".-codex.-\n") or "") .. "]")
	local manifest = H.readFile(H.addonDir .. "/Data/MANIFEST.txt")
	check(manifest:find("^Quest Flow data manifest") ~= nil, "the shipped data manifest is titled Quest Flow")
end

section("character name: a first and last name (UnitName returns two values on Forever) is shown in full, and the saved-data key is untouched")
do
	local function report(ns)
		local text
		rawset(ns.UI, "ShowReport", function(t) text = t end)
		H.slash("report")
		return text
	end
	-- the real client: UnitName("player") -> "Codex", "Runner"
	local ns = boot({ char = { level = 16, class = "Rogue", classToken = "ROGUE", name = "Codex", second = "Runner" }, synthetic = true })
	local text = report(ns)
	check(text:find("\nCodex Runner | level 16", 1, true) ~= nil, "the report's first line carries the full name  [" .. tostring(text:match("\n([^\n]*)\n")) .. "]")
	check(text:find("Character: Codex Runner level 16", 1, true) ~= nil, "and so does the Character line")
	local ctx = ns.State.Recompute and ns.Context.Build and ns.Context.Build() or nil
	local char = ctx and ctx.char or {}
	check(char.name == "Codex" and char.fullName == "Codex Runner", "the context keeps name = the first value and fullName = both  [" .. tostring(char.name) .. " | " .. tostring(char.fullName) .. "]")
	check(ns.Prefs.CharKey() == "Codex-Forever" or tostring(ns.Prefs.CharKey()):find("^Codex%-") ~= nil, "the saved-data key still uses the first name only  [" .. tostring(ns.Prefs.CharKey()) .. "]")
	check(char.key == nil or tostring(char.key):find("^Codex%-") ~= nil, "(and so does the context key)")

	-- a client that returns the REALM as the second value changes nothing
	local ns2 = boot({ char = { level = 16, class = "Rogue", classToken = "ROGUE", name = "Thrall", second = "Forever" }, synthetic = true })
	local t2 = report(ns2)
	check(t2:find("\nThrall | level 16", 1, true) ~= nil and not t2:find("Thrall Forever", 1, true), "a realm in the second value is not taken for a last name")

	-- a single-word name is unchanged
	local ns3 = boot({ char = { level = 16, class = "Rogue", classToken = "ROGUE", name = "Thrall" }, synthetic = true })
	check(report(ns3):find("\nThrall | level 16", 1, true) ~= nil, "a one-word name is shown as it is")
end
