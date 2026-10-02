-- ForeverCodex.Slash: /codex (alias /fcodex). Every command is a thin wrapper over Preferences / State / Diag,
-- mirroring what the window's buttons do, so everything the window offers is scriptable and testable.

local addonName, ns = ...
local R = ns.Registry
local P = ns.Prefs

local say = ns.Say

local function helpLines()
	say("Forever Codex commands:")
	say("  /codex                 open / close the Codex window;  /codex world | journey | appendices opens that tab")
	say("  /codex setup           run the first-time setup again;  /codex dev = the developer window")
	say("  /codex arrow [on|off|flip|reset|test]   Codex's own small direction arrow;  /codex pins [on|off]   Codex's pins on the world map")
	say("  /codex nav [on|off]    the waypoint that follows what Codex recommends;  /codex markers [probe|on|off]")
	say("  /codex party [off|ui|party|both|log]   what Codex does when party members (or you) finish quests; log = what it saw and why it did or did not send")
	say("  /codex next            print the recommended next action")
	say("  /codex diag            print diagnostics (for bug reports); /codex report = copyable box")
	say("  /codex style [key]     list or set the route style (efficient, fast, questing_only, completionist)")
	say("  /codex zone [key|auto] list or set your route zone (your choice, not tied to your race or location)")
	say("  /codex skip | unskip   skip the current recommendation | bring all skipped items back")
	say("  /codex add <id|name>   add a quest to your route;  /codex remove <id>")
	say("  /codex sys <key> on|off   toggle a system;  /codex hardcore on|off")
	say("  /codex telemetry [status|summary|events|on|off|reset]   observation log (does not affect recommendations)")
	say("  /codex planner [on|off]   the sequence planner (default on); off = the previous one-action-at-a-time engine")
	say("  /codex minimap reset   put the (draggable) minimap button back at its default spot")
	say("  /codex where | reset | help")
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
		say("usage: /codex telemetry [status | summary [seconds] | events [n] | on | off | reset]")
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
	elseif cmd == "world" or cmd == "journey" or cmd == "appendices" then
		ns.UI.Open(cmd)
	elseif cmd == "setup" then
		P.ReopenSetup()
		ns.UI.Open("codex")
	elseif cmd == "nav" then
		local on = onOff(restLower)
		if on == nil then
			say("Waypoint following is " .. (P.NavigationOn() and "on" or "off") .. " (" .. ns.Navigation.Status() .. "). Usage: /codex nav on|off")
		else
			P.SetNavigation(on)
			say("Waypoint following " .. (on and "on." or "off. Codex clears its own waypoint and leaves yours alone."))
			ns.State.Recompute()
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
			say("Arrow test: a spinning arrow should appear near the top of the screen for 10 seconds. If you see nothing, tell us (/codex arrow shows the details).")
		else
			local i = ns.Arrow.Info()
			local cal = ns.Arrow.Calibration()
			say(string.format("Arrow is %s (%s). It only appears while Codex has a destination (a NOW with a known location) and waypoint following is %s.", i.arrowOn and "on" or "off", tostring(i.reason), i.navOn and "on" or "OFF"))
			say(string.format("  destination: %s | frame created: %s, shown: %s%s | GetPlayerFacing: %s%s", i.destination and "yes" or "NO", tostring(i.frame), tostring(i.shown),
				i.point and (" at " .. i.point) or "", i.facingApi and "available" or "MISSING", i.facing and string.format(" (now %.2f)", i.facing) or " (no value)"))
			say(string.format("  facing convention learned: %s (%d samples this session). Walk in a few directions to learn it. Unproven on the real client. Usage: /codex arrow on|off|flip|reset|test",
				cal and string.format("yes, %d samples", cal.n or 0) or "no", i.samples))
		end
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
			say("The Codex minimap button can be dragged with the left mouse button; its position is saved. /codex minimap reset puts it back at the default spot.")
		end
	elseif cmd == "pins" then
		if restLower == "on" or restLower == "off" then
			P.SetPins(restLower == "on")
			ns.State.Recompute()
			say("Map pins " .. restLower .. ".")
		else
			local st = ns.Pins.Status()
			say(string.format("Map pins: %s | world map: %s | minimap: %s | pins for the current plan: %d", st.on and "on" or "off", st.worldMap, st.minimap, st.desired))
		end
	elseif cmd == "markers" then
		if restLower == "probe" then
			local ok, msg = ns.Markers.Probe()
			say((ok and "markers probe passed: " or "markers probe: ") .. msg)
		elseif restLower == "on" or restLower == "off" then
			if restLower == "on" and ns.Markers.Status().probe ~= "passed" then
				say("World markers need the quick test first: target an NPC and type /codex markers probe.")
			else
				P.SetMarkers(restLower == "on")
				say("World markers " .. restLower .. ".")
			end
			ns.State.Recompute()
		else
			local st = ns.Markers.Status()
			say(string.format("World markers: %s (test %s). Placement is off until /codex markers probe has passed on this client.", st.enabled and "on" or "off", st.probe))
		end
	elseif cmd == "party" then
		if restLower == "log" then
			local tr = ns.Party.Trace()
			if #tr == 0 then say("Party log: nothing observed yet (it records every objective / quest completion Codex sees, and why it was or was not sent).") end
			for _, e in ipairs(tr) do
				say(string.format("  %s %s%s | in group: %s | mode %s | addon msg: %s | chat: %s%s", e.kind, tostring(e.quest), e.name and (" " .. e.name) or "", tostring(e.inGroup), e.mode,
					tostring(e.addon), tostring(e.chat), e.why and (" | " .. e.why) or ""))
			end
		elseif restLower == "" then
			say("Party news: " .. P.PartyNotify() .. ". Usage: /codex party off|ui|party|both")
		elseif P.SetPartyNotify(restLower) then
			say("Party news: " .. restLower .. ".")
		else
			say("usage: /codex party off|ui|party|both|log")
		end
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
		local plan = ns.State.plan or ns.State.Recompute()
		local a = plan and plan.next
		if a and P.Skip(a.skipKey) then
			say("skipped: " .. a.title)
			ns.State.Recompute()
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
			say("added quest " .. id .. (q and (" (" .. tostring(q.name) .. ")") or " (not in Codex data)") .. " to your route.")
			ns.State.Recompute()
		else
			say("usage: /codex add <quest id or part of its name>")
		end
	elseif cmd == "remove" then
		local id = tonumber(restLower)
		if id then
			P.RemoveAdded(id)
			say("removed quest " .. id .. " from your added list.")
			ns.State.Recompute()
		else
			say("usage: /codex remove <quest id>")
		end
	elseif cmd == "sys" or cmd == "system" then
		local key, word = restLower:match("^(%S+)%s*(%S*)$")
		local on = onOff(word)
		if not key or on == nil then
			say("usage: /codex sys <key> on|off")
		else
			local ok, why = P.SetSystem(key, on)
			say(ok and (key .. (on and " on." or " off.")) or ("could not change " .. tostring(key) .. ": " .. tostring(why)))
			ns.State.Recompute()
		end
	elseif cmd == "hardcore" then
		local on = onOff(restLower)
		if on == nil then
			say("Hardcore is " .. (P.IsHardcore() and "on" or "off") .. ". Usage: /codex hardcore on|off")
		else
			P.SetHardcore(on)
			say("Hardcore " .. (on and "on: respawn skips will never be recommended." or "off."))
			ns.State.Recompute()
		end
	elseif cmd == "where" then
		local ctx = ns.State.Recompute() and ns.State.ctx
		if ctx then
			local c, l = ctx.char, ctx.loc
			say(string.format("%s: level %s %s %s (%s). Race origin: %s. Route zone (your choice): %s. Now in: %s%s.", tostring(c.name),
				tostring(c.level), tostring(c.race), tostring(c.class), tostring(c.faction), tostring(c.race), P.GetRouteZone(),
				tostring(l.zone), l.subzone and (" / " .. l.subzone) or ""))
		end
	elseif cmd == "planner" then
		local on = onOff(restLower)
		if on == nil then
			say("Planner is " .. (ns.State.mode == "planner" and "on" or "off") .. ". Usage: /codex planner on|off (not saved; on again at every login)")
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
		say("unknown command '" .. cmd .. "'. Try /codex help.")
	end
end

ns.Slash = { Handle = handle }

SLASH_FOREVERCODEX1 = "/codex"
SLASH_FOREVERCODEX2 = "/fcodex"
SlashCmdList["FOREVERCODEX"] = function(msg)
	local ok, err = pcall(handle, msg)
	if not ok then
		ns.RecordError("slash", err)
		say("something went wrong (" .. tostring(err) .. "). /codex diag will include this.")
	end
end
