-- ForeverCodex.Party: party awareness that works with or without anyone else running Codex, and with Questie or nothing.
--
-- WHAT IS KNOWN. The base client does not tell Codex a party member's quest objectives, so Codex can only (a) notice its
-- OWN progress (objective finished, quest finished, quest turned in: from the quest log, proven M8.9, and QUEST_TURNED_IN,
-- proven M8.8) and (b) share it, and (c) show what other Codex users share. Nothing here reads another addon's data.
--
-- Setting (per character): off | ui | party | both. Default "ui". No party chat unless the player chooses it.
--   off    nothing is sent or shown
--   ui     Codex sends a small invisible addon message to the group (so other Codex users see it) and shows messages it receives
--   party  Codex says ONE plain line in party chat when you finish an objective, finish a quest or turn one in
--          ("Codex: Quest complete: The Weaver - 1/1 Ataeric's Staff"); works for
--          members without Codex; nothing is shown in the window
--   both   both of the above
--
-- UNVERIFIED on Forever: C_ChatInfo.SendAddonMessage / RegisterAddonMessagePrefix, the CHAT_MSG_ADDON event, and
-- SendChatMessage to PARTY. Every call is feature-checked and pcall-wrapped; if they are missing Codex still detects your
-- own events and simply has nobody to tell. Identity: a sender's SHORT NAME is kept in MEMORY for this session only to show
-- "Bob finished ...": never saved, no GUIDs, no realm. Messages carry only a quest id and numbers.
--
-- Protocol (prefix FCODEX, version 1):   v1|DONE|<questId>   v1|TURNIN|<questId>   v1|OBJ|<questId>|<have>|<need>

local addonName, ns = ...
local P = ns.Prefs
local R = ns.Registry
local K = ns.Contract

local Pt = {}
ns.Party = Pt

Pt.PREFIX = "FCODEX"
Pt.FEED_MAX = 10
Pt.THROTTLE = 5        -- seconds between two sends of the same event

local snap = nil
local trace = {}          -- the last decisions, newest first: what was seen and why it was or was not sent (/codex party log)
local feed = {}
local lastSent = {}
local lastChat = -100

local function now() return type(GetTime) == "function" and GetTime() or 0 end

-- ---------------------------------------------------------------- the client, behind one table (tests replace it)

Pt.api = {
	registerPrefix = function()
		if type(C_ChatInfo) == "table" and type(C_ChatInfo.RegisterAddonMessagePrefix) == "function" then
			return (pcall(C_ChatInfo.RegisterAddonMessagePrefix, Pt.PREFIX))
		elseif type(RegisterAddonMessagePrefix) == "function" then
			return (pcall(RegisterAddonMessagePrefix, Pt.PREFIX))
		end
		return false
	end,
	sendAddon = function(text)
		if type(C_ChatInfo) == "table" and type(C_ChatInfo.SendAddonMessage) == "function" then
			return (pcall(C_ChatInfo.SendAddonMessage, Pt.PREFIX, text, "PARTY"))
		elseif type(SendAddonMessage) == "function" then
			return (pcall(SendAddonMessage, Pt.PREFIX, text, "PARTY"))
		end
		return false
	end,
	sendChat = function(text)
		if type(SendChatMessage) == "function" then return (pcall(SendChatMessage, text, "PARTY")) end
		return false
	end,
	selfName = function()
		local ok, n = pcall(UnitName, "player")
		return ok and n or nil
	end,
}

local function questName(id)
	local v = R.Quest(id)
	return v and v.name or "a quest"
end

local function showsFeed() local m = P.PartyNotify() return m == "ui" or m == "both" end
local function sendsAddon() local m = P.PartyNotify() return m == "ui" or m == "both" end
local function sendsChat() local m = P.PartyNotify() return m == "party" or m == "both" end

function Pt.Register() return Pt.api.registerPrefix() end

-- ---------------------------------------------------------------- sending (your own progress)

local function note(ev, inGroup, result)
	table.insert(trace, 1, { kind = ev.type, quest = ev.quest, name = ev.name, line = ev.line, inGroup = inGroup and true or false, mode = P.PartyNotify(),
		addon = result.addon, chat = result.chat, why = result.why })
	while #trace > 10 do trace[#trace] = nil end
end

--- The one plain line used in party chat, e.g. "Codex: Quest complete: The Weaver - 1/1 Ataeric's Staff".
local function chatLine(ev)
	local name = ev.name or questName(ev.quest)
	if ev.type == "DONE" then return "Codex: Quest complete: " .. name .. (ev.line and (" - " .. ev.line) or "") end
	if ev.type == "TURNIN" then return "Codex: Turned in: " .. name end
	return "Codex: Objective done: " .. name .. (ev.line and (" - " .. ev.line) or "")
end

local function send(ev, inGroup)
	local result = {}
	if not inGroup then result.why = "not in a group" note(ev, inGroup, result) return false end
	if P.PartyNotify() == "off" then result.why = "party news is off" note(ev, inGroup, result) return false end
	local key = ev.type .. ":" .. tostring(ev.quest) .. ":" .. tostring(ev.idx or "")
	local t = now()
	if lastSent[key] and t - lastSent[key] < Pt.THROTTLE then result.why = "duplicate (same event within " .. Pt.THROTTLE .. " s)" note(ev, inGroup, result) return false end
	lastSent[key] = t
	local sent = false
	if sendsAddon() then
		local msg = "v1|" .. ev.type .. "|" .. ev.quest
		if ev.type == "OBJ" then msg = msg .. "|" .. tostring(ev.have or 0) .. "|" .. tostring(ev.need or 0) end
		result.addon = Pt.api.sendAddon(msg)
		sent = result.addon or sent
	end
	if sendsChat() then
		if t - lastChat >= 3 then
			lastChat = t
			result.chat = Pt.api.sendChat(chatLine(ev))
			sent = result.chat or sent
		else
			result.why = "chat rate limit"
		end
	end
	if not sendsChat() and not sendsAddon() then result.why = "no output mode" end
	if sendsChat() == false and P.PartyNotify() == "ui" then result.why = result.why or "mode 'ui' sends only an invisible addon message, not party chat" end
	note(ev, inGroup, result)
	return sent
end

local function objLines(entryObjectives)
	local os = K.ObjectiveState(entryObjectives)
	local lines = {}
	if os.known then
		for _, o in ipairs(os.list) do
			local label = ns.Presenter.CleanObjective(o.text)
			if type(o.have) == "number" and type(o.need) == "number" and o.need > 0 then
				lines[#lines + 1] = string.format("%d/%d%s", math.min(o.have, o.need), o.need, label and (" " .. label) or "")
			elseif label then
				lines[#lines + 1] = label
			end
		end
	end
	return os, lines
end

--- Called with every fresh Context: finds YOUR objective / quest completions by diffing the quest log. The first context
-- after login is only a baseline: nothing is announced for what was already true.
function Pt.OnContext(ctx)
	if not (ctx and ctx.logAvailable) then return end
	local cur = {}
	for id, e in pairs(ctx.log) do
		local os, lines = objLines(e.objectives)
		local done = {}
		if os.known then for i, o in ipairs(os.list) do if o.finished then done[i] = o end end end
		local view = R.Quest(id)
		cur[id] = { complete = e.complete == true, done = done, lines = lines, name = (view and view.name) or e.title }
	end
	if snap then
		local inGroup = ctx.group and ctx.group.inGroup
		for id, c in pairs(cur) do
			local p = snap[id]
			if p then
				if c.complete and not p.complete then
					send({ type = "DONE", quest = id, name = c.name, line = table.concat(c.lines, ", ") }, inGroup)
				else
					for i, o in pairs(c.done) do
						if not p.done[i] then
							local label = ns.Presenter.CleanObjective(o.text)
							local line = (type(o.have) == "number" and type(o.need) == "number" and o.need > 0) and string.format("%d/%d%s", math.min(o.have, o.need), o.need, label and (" " .. label) or "") or label
							send({ type = "OBJ", quest = id, idx = i, have = o.have, need = o.need, name = c.name, line = line }, inGroup)
						end
					end
				end
			end
		end
	end
	snap = cur
end

--- QUEST_TURNED_IN(questID): the proven turn-in event. The quest has already left the log, so its name comes from the last snapshot.
function Pt.OnTurnedIn(id, ctx)
	if type(id) ~= "number" then return end
	local p = snap and snap[id]
	send({ type = "TURNIN", quest = id, name = p and p.name or nil }, ctx and ctx.group and ctx.group.inGroup)
end

--- The last decisions: what Codex saw and whether/why it was sent. Newest first.
function Pt.Trace() return trace end

-- ---------------------------------------------------------------- receiving (what other Codex users share)

--- CHAT_MSG_ADDON(prefix, text, channel, sender)
function Pt.OnAddonMessage(prefix, text, channel, sender)
	if prefix ~= Pt.PREFIX or type(text) ~= "string" or not showsFeed() then return end
	local me = Pt.api.selfName()
	local who = type(sender) == "string" and sender:match("^([^-]+)") or nil
	if not who or who == me then return end
	local v, kind, q, a, b = text:match("^(v%d+)|(%u+)|(%d+)|?(%d*)|?(%d*)$")
	if v ~= "v1" or (kind ~= "DONE" and kind ~= "TURNIN" and kind ~= "OBJ") then return end
	table.insert(feed, 1, { who = who, type = kind, quest = tonumber(q), have = tonumber(a), need = tonumber(b), t = now() })
	while #feed > Pt.FEED_MAX do feed[#feed] = nil end
end

--- The Party card: what members finished, and where YOU stand on the same quest. Session memory only.
function Pt.View(ctx)
	local v = { lines = {}, note = nil }
	if not (ctx and ctx.group and ctx.group.inGroup) then return v end
	if P.PartyNotify() == "off" then v.note = "Party notifications are off." return v end
	for _, e in ipairs(feed) do
		local name = questName(e.quest)
		local head
		if e.type == "DONE" then head = e.who .. " finished: " .. name
		elseif e.type == "TURNIN" then head = e.who .. " turned in: " .. name
		else head = e.who .. " completed an objective of: " .. name end
		local mine
		local entry = ctx.log and ctx.log[e.quest]
		if entry then
			local prog = ns.Presenter.Progress({ objectiveState = K.ObjectiveState(entry.objectives) })
			mine = prog and ("Your progress: " .. prog) or (entry.complete and "You have finished it" or "You have it in your log")
		elseif ctx.isCompleted and ctx.isCompleted(e.quest) then
			mine = "You did this"
		else
			mine = "You have not started it"
		end
		v.lines[#v.lines + 1] = { head = head, mine = mine }
	end
	if #v.lines == 0 then v.note = "Party progress appears here for members who also use Codex." end
	return v
end

function Pt.Status()
	local hasAddon = (type(C_ChatInfo) == "table" and type(C_ChatInfo.SendAddonMessage) == "function") or type(SendAddonMessage) == "function"
	return { mode = P.PartyNotify(), addonMessages = hasAddon, chat = type(SendChatMessage) == "function", feed = #feed }
end

function Pt._Reset() snap, feed, lastSent, lastChat, trace = nil, {}, {}, -100, {} end
