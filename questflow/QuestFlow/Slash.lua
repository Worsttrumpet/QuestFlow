-- ForeverCodex.Slash: /codex (alias /fcodex). Every command is a thin wrapper over Preferences / State / Diag,
-- mirroring what the window's buttons do, so everything the window offers is scriptable and testable.

local addonName, ns = ...
local R = ns.Registry
local P = ns.Prefs

local say = ns.Say

local function helpLines()
	say("Quest Flow commands:")
	say("  /qflow                 show / hide the Quest Flow tracker;  /qflow options | world | journey | appendices opens that tab of the options window (right click the minimap button too)")
	say("  /qflow setup           show the welcome / setup again (nothing is reset);  /qflow dev = the advanced window")
	say("  /qflow arrow [on|off|flip|reset|test]   Quest Flow's own small direction arrow")
	say("  /qflow tracker [on|off]   hide the game's quest tracker so Quest Flow's replaces it")
	say("  /qflow nav [on|off]    the waypoint that follows what Quest Flow recommends")
	say("  /qflow party [off|ui|log]   the Party card (what other Quest Flow users in your party finished); log = what Quest Flow saw and why it did or did not share")
	say("  /qflow next            print the recommended next action")
	say("  /qflow report          the diagnostic report in a copyable window (Ctrl+C, paste) for bug reports; /qflow diag = same facts in chat")
	say("  /qflow style [key]     list or set the route style (efficient, fast, questing_only, completionist)")
	say("  /qflow zone [key|auto] list or set your route zone (your choice, not tied to your race or location)")
	say("  /qflow skip | unskip   skip the current recommendation | bring all skipped items back")
	say("  /qflow add <id|name>   add a quest to your route;  /qflow remove <id>")
	say("  /qflow sys <key> on|off   toggle a system;  /qflow hardcore on|off")
	say("  /qflow telemetry [status|summary|events|on|off|reset]   observation log (does not affect recommendations)")
	say("  /qflow planner [on|off]   the sequence planner (default on); off = the previous one-action-at-a-time engine")
	say("  /qflow questiedb [on|off | quest id] [npc id]   turn QuestieDB data on or off, and whether the QuestieDB addon is in use, and a check of what it knows")
	say("  /qflow minimap reset   put the (draggable) minimap button back at its default spot")
	say("  /qflow spells [restore]   SPELL TRAINING: what the client reported; restore = bring back spells you marked Don't Want to Learn")
	say("  /qflow feedback [status|list]   REPORT A PROBLEM (also the Feedback button in the window); /qflow report is the full diagnostic")
	say("  /qflow professions [hide <name>|restore]   PROFESSIONS: what the client reported")
	say("  /qflow services [vendor|trainer|flight|inn|repair|dungeon]   what Quest Flow has seen of services, flights and dungeon entrances from your own visits;  /qflow travel = same")
	say("  /qflow seasonal [on|off]   include seasonal / holiday quests in the route (default off)")
	say("  /qflow where | reset | help")
end

--- Shows lines in the copyable window (the same one /codex report uses: the text is selected, press Ctrl+C, paste it anywhere); in chat when the window cannot be built.
local function showLines(lines)
	local text = table.concat(lines, "\n")
	if ns.UI and ns.UI.ShowReport then
		local ok = pcall(ns.UI.ShowReport, text)
		if ok then say("Opened a window with the text selected: press Ctrl+C, then paste it.") return end
	end
	for _, l in ipairs(lines) do say(l) end
end

local function printNext()
	local plan = ns.State.Recompute()
	local a = plan and plan.next
	if not a then
		say("Nothing to recommend right now.")
		for _, w in ipairs(plan and plan.warnings or {}) do say("  " .. w) end
		return
	end
	say("NEXT: " .. a.title)
	for _, l in ipairs(a.lines) do say("  " .. l) end
	if #a.reasons > 0 then say("  Why: " .. table.concat(a.reasons, "; ")) end
	say("  " .. (ns.UI.ProvenanceText(a)))
end

local function listStyles()
	local keys = {}
	for _, s in ipairs(R.Strategies()) do
		keys[#keys + 1] = s.key .. (s.active == false and " (planned)" or "")
	end
	say("Route style: " .. P.GetStyle() .. ". Available: " .. table.concat(keys, ", "))
end

local function listZones()
	local keys = { "auto" }
	for _, z in ipairs(R.Zones()) do keys[#keys + 1] = z.key end
	say("Route zone: " .. P.GetRouteZone() .. ". Available: " .. table.concat(keys, ", "))
end

local function telemetryCommand(rest)
	local T = ns.Telemetry
	if not T then say("telemetry is not loaded.") return end
	local sub, arg = rest:match("^(%S*)%s*(.-)$")
	sub = sub:lower()
	if sub == "" or sub == "status" then
		local st = T.Status()
		say(string.format("Telemetry is %s: %d/%d events stored, %d anomalies. It only records observations; it does not change recommendations.",
			st.enabled and "on" or "OFF", st.stored, st.cap, st.anomalies))
		for _, c in ipairs(T.Capabilities()) do
			say(string.format("  %-13s %s | registered: %s | recorded this session: %d", c.type, c.unavailable and "UNAVAILABLE on Forever" or (c.verified and "proven on Forever" or "UNPROVEN on Forever"),
				tostring(c.registered), c.recorded))
		end
	elseif sub == "summary" then
		local span = tonumber(arg)
		for _, l in ipairs(ns.TelemetryMetrics.Format(ns.TelemetryMetrics.Summary(T.Events(), { span = span }))) do say("  " .. l) end
	elseif sub == "events" then
		local list, n = T.Events(), tonumber(arg) or 10
		for i = math.max(1, #list - n + 1), #list do
			local ev, parts = list[i], {}
			for k, v in pairs(ev) do if k ~= "e" and k ~= "t" then parts[#parts + 1] = k .. "=" .. tostring(v) end end
			table.sort(parts)
			say(string.format("  t=%s %s %s", tostring(ev.t), ev.e, table.concat(parts, " ")))
		end
	elseif sub == "on" or sub == "off" then
		T.SetEnabled(sub == "on")
		say("telemetry " .. sub .. ".")
	elseif sub == "reset" then
		T.Reset()
		say("telemetry log cleared.")
	else
		say("usage: /qflow telemetry [status | summary [seconds] | events [n] | on | off | reset]")
	end
end

local function onOff(word)
	if word == "on" or word == "1" or word == "true" then return true end
	if word == "off" or word == "0" or word == "false" then return false end
	return nil
end

local function handle(msg)
	msg = tostring(msg or "")
	local raw = msg:gsub("^%s+", ""):gsub("%s+$", "")
	local cmd, rest = raw:match("^(%S*)%s*(.-)$")
	cmd = (cmd or ""):lower()
	local restLower = (rest or ""):lower()

	if cmd == "" then
		ns.UI.Toggle()
	elseif cmd == "dev" then
		ns.DevUI.Toggle()
	elseif cmd == "world" or cmd == "journey" or cmd == "appendices" or cmd == "options" then
		ns.UI.Open(cmd)
	elseif cmd == "setup" then
		P.ReopenSetup()
		ns.UI.Open("options")
	elseif cmd == "nav" then
		local on = onOff(restLower)
		if on == nil then
			say("Waypoint following is " .. (P.NavigationOn() and "on" or "off") .. " (" .. ns.Navigation.Status() .. "). Usage: /qflow nav on|off")
		else
			P.SetNavigation(on)
			say("Waypoint following " .. (on and "on." or "off. Quest Flow clears its own waypoint and leaves yours alone."))
			ns.State.Recompute()
		end
	elseif cmd == "tracker" then
		local on = onOff(restLower)
		local st = ns.BlizzardTracker.Status()
		if on == nil then
			say(string.format("The game's own quest tracker is %s by Quest Flow (setting %s; frame: %s). Usage: /qflow tracker on|off   (on hides the game's tracker so Quest Flow's can replace it; /reload always restores it)",
				st.state == "hidden" and "hidden" or "left alone", st.setting and "on" or "off", tostring(st.frame or "not found")))
		else
			P.SetHideBlizzardTracker(on)
			local r = ns.BlizzardTracker.Apply()
			if on and r.state == "not found" then
				say("The game's quest tracker frame was not found on this client, so nothing was hidden.")
			else
				say(on and "The game's quest tracker is hidden." or "The game's quest tracker is back.")
			end
		end
	elseif cmd == "arrow" then
		if restLower == "flip" then
			P.SetArrowFlip(not P.ArrowFlip())
			say("Arrow direction " .. (P.ArrowFlip() and "inverted." or "back to normal.") .. " (Use this only if the arrow points the wrong way round.)")
		elseif restLower == "reset" then
			P.Root().ui.arrowCal = nil
			ns.Arrow._Reset()
			say("Arrow forgot which way you face: walk a few steps in different directions to teach it again.")
		elseif restLower == "on" or restLower == "off" then
			P.SetArrow(restLower == "on")
			say("Arrow " .. restLower .. ".")
		elseif restLower == "test" then
			ns.Arrow.Demo(10)
			say("Arrow test: a spinning arrow should appear near the top of the screen for 10 seconds. If you see nothing, tell us (/qflow arrow shows the details).")
		else
			local i = ns.Arrow.Info()
			local cal = ns.Arrow.Calibration()
			say(string.format("Arrow is %s (%s). It only appears while Quest Flow has a destination (a NOW with a known location) and waypoint following is %s.", i.arrowOn and "on" or "off", tostring(i.reason), i.navOn and "on" or "OFF"))
			say(string.format("  destination: %s | frame created: %s, shown: %s%s | GetPlayerFacing: %s%s", i.destination and "yes" or "NO", tostring(i.frame), tostring(i.shown),
				i.point and (" at " .. i.point) or "", i.facingApi and "available" or "MISSING", i.facing and string.format(" (now %.2f)", i.facing) or " (no value)"))
			say(string.format("  facing convention learned: %s (%d samples this session). Walk in a few directions to learn it. Unproven on the real client. Usage: /qflow arrow on|off|flip|reset|test",
				cal and string.format("yes, %d samples", cal.n or 0) or "no", i.samples))
		end
	elseif cmd == "questiedb" then
		-- /codex questiedb [quest id] [npc id]: what QuestieDB is, and a development check of the bridge. The defaults below are only the
		-- ids this check was written with (a Forever-only quest and its giver): nothing in the planner or product logic uses them.
		local QB = ns.QuestieBridge
		if restLower == "on" or restLower == "off" then
			P.SetUseQuestieDB(restLower == "on")
			ns.Safe(QB.Init)
			ns.State.Recompute()
			say("QuestieDB data is " .. restLower .. ". " .. tostring(QB.Status().message or ""))
			return
		end
		local st = QB.Status()
		if st.state ~= "available" then
			say("QuestieDB is NOT in use (" .. tostring(st.state) .. "). " .. tostring(st.message))
		else
			say(string.format("QuestieDB is in use: version %s, build %s, mode %s, flavor %s, contract %s, %s quests known.", tostring(st.version or "?"), tostring(st.commit or "?"),
				tostring(st.mode or "?"), tostring(st.flavor or "?"), tostring(st.contract or "?"), tostring(st.quests or "?")))
			say("It is a baseline, unverified on Forever. A quest missing from it is UNKNOWN to Quest Flow, never 'does not exist'.")
		end
		local q, n = restLower:match("^(%d+)%s*(%d*)$")
		for _, line in ipairs(QB.Smoke(tonumber(q) or 98298, tonumber(n) or 1938)) do say("  " .. line) end
		say("  (a stable QuestieDB release lacks some Forever-only quests that a newer build has: absent here is expected, not an error)")
	elseif cmd == "minimap" then
		if restLower == "reset" then
			if ns.MinimapButton and ns.MinimapButton.button then
				ns.MinimapButton.Reset()
				say("Minimap button put back at its default spot.")
			else
				P.ClearMinimapPos()
				say("Minimap button position forgotten; it will use its default spot.")
			end
		else
			say("The Quest Flow minimap button can be dragged with the left mouse button; its position is saved. /qflow minimap reset puts it back at the default spot.")
		end
	elseif cmd == "party" then
		if restLower == "log" then
			local tr = ns.Party.Trace()
			if #tr == 0 then say("Party log: nothing observed yet (it records every objective / quest completion Quest Flow sees, and why it was or was not sent).") end
			for _, e in ipairs(tr) do
				say(string.format("  %s %s%s | in group: %s | mode %s | addon msg: %s%s", e.kind, tostring(e.quest), e.name and (" " .. e.name) or "", tostring(e.inGroup), e.mode,
					tostring(e.addon), e.why and (" | " .. e.why) or ""))
			end
		elseif restLower == "" then
			say("Party news: " .. P.PartyNotify() .. " (ui = the Party card, shared by invisible addon messages; Quest Flow never writes quest status to chat). Usage: /qflow party off|ui")
		elseif P.SetPartyNotify(restLower) then
			say("Party news: " .. restLower .. ".")
		else
			say("usage: /qflow party off|ui|log")
		end
	elseif cmd == "spells" then
		if restLower == "catalog" then
			showLines(ns.SpellTraining.CatalogLines(ns.State.ctx))
		elseif restLower == "restore" then
			say(string.format("Brought back %d spell(s) marked Don't Want to Learn.", ns.SpellTraining.RestoreAll()))
		else
			local lines = ns.SpellTraining.ReportLines(ns.State.ctx)
			lines[#lines + 1] = "/qflow spells restore brings back spells you marked Don't Want to Learn."
			showLines(lines)
		end
	elseif cmd == "feedback" then
		if restLower == "status" then
			showLines(ns.Feedback.ReportLines())
		elseif restLower == "list" then
			local list = ns.Feedback.Stored()
			local lines = { #list == 0 and "No feedback reports are stored." or (#list .. " feedback report(s) stored locally:") }
			for _, r in ipairs(list) do lines[#lines + 1] = "  " .. r.id .. " | " .. tostring(r.category) .. " | not sent (Quest Flow cannot send reports)" end
			showLines(lines)
		else
			ns.UI.OpenFeedback({ from = "WINDOW" })
		end
	elseif cmd == "professions" then
		local a, b = restLower:match("^(%S+)%s*(%S*)")
		if a == "hide" and b ~= "" then
			say(ns.Professions.Hide(b) and ("Hiding " .. b .. " from PROFESSIONS.") or "usage: /qflow professions hide fishing|cooking|firstaid")
		elseif a == "restore" then
			say(string.format("Brought back %d hidden profession reminder(s).", ns.Professions.RestoreAll()))
		else
			local lines = ns.Professions.ReportLines(ns.State.ctx)
			lines[#lines + 1] = "/qflow professions hide fishing|cooking|firstaid  or  restore"
			showLines(lines)
		end
	elseif cmd == "seasonal" then
		local on = onOff(restLower)
		if on ~= nil then
			P.SetIncludeSeasonal(on)
			ns.State.Recompute()
		end
		say("Seasonal / holiday quests are " .. (P.IncludeSeasonal() and "INCLUDED (and still only routed when the game itself offers them)." or "left out of the normal route.") .. " Usage: /qflow seasonal on|off")
	elseif cmd == "services" or cmd == "travel" then
		-- what Quest Flow has seen of the world's services and your flights (read-only; the same facts as the report's world and travel section)
		local kinds = { vendor = "vendor", trainer = "trainer", flight = "flightmaster", flightmaster = "flightmaster", inn = "innkeeper", innkeeper = "innkeeper", repair = "repair" }
		local kind = kinds[restLower:match("^(%S+)") or ""]
		local lines = {}
		local ctx = ns.State.ctx
		local here = ctx and ctx.loc and ctx.loc.available and { map = ctx.loc.map, x = ctx.loc.x, y = ctx.loc.y } or nil
		if kind then
			local list = ns.Services.Find(kind)
			if #list == 0 then lines[1] = "Quest Flow has not seen any " .. kind .. " yet: it learns the ones you open."
			else
				lines[1] = #list .. " " .. kind .. "(s) seen by you:"
				for i, e in ipairs(list) do
					if i > 8 then lines[#lines + 1] = "  ..." break end
					local d = here and e.map and ns.Engine.Distance(ctx, here, { map = e.map, x = e.x, y = e.y })
					lines[#lines + 1] = string.format("  %s  (%s %.0f, %.0f)%s", e.name or e.key, ns.Registry.MapLabel(e.map), (e.x or 0) * 100, (e.y or 0) * 100,
						(d and d ~= ns.Engine.DIFFERENT_CONTINENT) and string.format("  about %d yards away", math.floor(d + 0.5)) or "")
				end
			end
		elseif restLower:match("^dungeon") then
			local list = ns.Services.Entrances()
			lines[1] = #list == 0 and "No dungeon entrance seen yet: it is recorded when you enter a dungeon from outside." or (#list .. " dungeon entrance(s) seen:")
			for _, e in ipairs(list) do lines[#lines + 1] = string.format("  %s  (%s %.0f, %.0f)", e.name, ns.Registry.MapLabel(e.map), (e.x or 0) * 100, (e.y or 0) * 100) end
		else
			for _, l in ipairs(ns.Taxi.ReportLines()) do lines[#lines + 1] = l end
			for _, l in ipairs(ns.Services.ReportLines()) do lines[#lines + 1] = l end
			lines[#lines + 1] = "/qflow services vendor | trainer | flight | inn | repair | dungeon"
		end
		showLines(lines)
	elseif cmd == "help" or cmd == "?" then
		helpLines()
	elseif cmd == "diag" then
		ns.Diag.Print()
	elseif cmd == "report" then
		ns.Diag.Report()
	elseif cmd == "next" then
		printNext()
	elseif cmd == "style" then
		if restLower == "" then
			listStyles()
		else
			local ok, why = P.SetStyle(restLower)
			say(ok and ("route style set to " .. restLower .. ".") or ("could not set style: " .. tostring(why)))
			ns.State.Recompute()
		end
	elseif cmd == "zone" then
		if restLower == "" then
			listZones()
		else
			local ok, why = P.SetRouteZone(restLower)
			say(ok and ("route zone set to " .. restLower .. ".") or ("could not set zone: " .. tostring(why)))
			ns.State.Recompute()
		end
	elseif cmd == "skip" then
		local a = ns.State.SkipCurrent()
		if a then
			say("skipped: " .. a.title)
		else
			say("nothing to skip.")
		end
	elseif cmd == "unskip" then
		P.ClearSkips()
		say("skipped items restored.")
		ns.State.Recompute()
	elseif cmd == "add" then
		local id = tonumber(restLower)
		if not id and restLower ~= "" then
			local found = R.Search(restLower, 1)[1]
			id = found and found.id
		end
		if id then
			P.Add(id)
			local q = R.Quest(id)
			say("added quest " .. id .. (q and (" (" .. tostring(q.name) .. ")") or " (not in Quest Flow data)") .. " to your route.")
			ns.State.Recompute()
		else
			say("usage: /qflow add <quest id or part of its name>")
		end
	elseif cmd == "remove" then
		local id = tonumber(restLower)
		if id then
			P.RemoveAdded(id)
			say("removed quest " .. id .. " from your added list.")
			ns.State.Recompute()
		else
			say("usage: /qflow remove <quest id>")
		end
	elseif cmd == "sys" or cmd == "system" then
		local key, word = restLower:match("^(%S+)%s*(%S*)$")
		local on = onOff(word)
		if not key or on == nil then
			say("usage: /qflow sys <key> on|off")
		else
			local ok, why = P.SetSystem(key, on)
			say(ok and (key .. (on and " on." or " off.")) or ("could not change " .. tostring(key) .. ": " .. tostring(why)))
			ns.State.Recompute()
		end
	elseif cmd == "hardcore" then
		local on = onOff(restLower)
		if on == nil then
			say("Hardcore is " .. (P.IsHardcore() and "on" or "off") .. ". Usage: /qflow hardcore on|off")
		else
			P.SetHardcore(on)
			say("Hardcore " .. (on and "on: respawn skips will never be recommended." or "off."))
			ns.State.Recompute()
		end
	elseif cmd == "where" then
		local ctx = ns.State.Recompute() and ns.State.ctx
		if ctx then
			local c, l = ctx.char, ctx.loc
			say(string.format("%s: level %s %s %s (%s). Race origin: %s. Route zone (your choice): %s. Now in: %s%s.", tostring(c.fullName or c.name),
				tostring(c.level), tostring(c.race), tostring(c.class), tostring(c.faction), tostring(c.race), P.GetRouteZone(),
				tostring(l.zone), l.subzone and (" / " .. l.subzone) or ""))
		end
	elseif cmd == "planner" then
		local on = onOff(restLower)
		if on == nil then
			say("Planner is " .. (ns.State.mode == "planner" and "on" or "off") .. ". Usage: /qflow planner on|off (not saved; on again at every login)")
		else
			ns.State.SetPlanner(on)
			say(on and "Planner on: NOW / ALSO DO / THEN decisions from short sequences." or "Planner off: using the previous one-action-at-a-time engine.")
			ns.State.Recompute()
		end
	elseif cmd == "telemetry" then
		telemetryCommand(rest or "")
	elseif cmd == "reset" then
		P.ResetOverrides()
		say("skips and added quests cleared.")
		ns.State.Recompute()
	else
		say("unknown command '" .. cmd .. "'. Try /qflow help.")
	end
end

ns.Slash = { Handle = handle }

-- /qflow and /questflow are the Quest Flow commands; /codex and /fcodex (the addon's earlier working name) keep working as aliases, so nothing a tester has typed or bound breaks.
SLASH_FOREVERCODEX1 = "/qflow"
SLASH_FOREVERCODEX2 = "/questflow"
SLASH_FOREVERCODEX3 = "/codex"
SLASH_FOREVERCODEX4 = "/fcodex"
SlashCmdList["FOREVERCODEX"] = function(msg)
	local ok, err = pcall(handle, msg)
	if not ok then
		ns.RecordError("slash", err)
		say("something went wrong (" .. tostring(err) .. "). /qflow diag will include this.")
	end
end
