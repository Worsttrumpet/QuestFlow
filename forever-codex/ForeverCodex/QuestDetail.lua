-- QUEST DETAILS: a small read-only description of ONE quest in the player's log, for the clickable fallback (quests Codex cannot place on the map).
-- Pure: it reads the quest-log snapshot (ctx.log, ctx.questTag) that Codex already has and makes NO client call. It is not a quest journal: there is no story or
-- description text (no API for it is proven on Forever), and it never opens the game's own quest UI.
--
--   QD.Describe(id, ctx, opts)  -> { id, title, header, state, status, objectives, tag, giver, turnIn, note } or nil when the quest is not in the log
--       opts.unplaced   true when Codex has no usable map position for the quest (adds the "no arrow" note)
--       opts.names      { giver = "...", turnIn = "..." } QuestieDB NPC names (third-party, unverified); omitted when absent
--   QD.ApiLines()               -> report lines about the game's own quest-UI functions: present or absent, NEVER called, so never claimed to work

local addonName, ns = ...
local QD = {}
ns.QuestDetail = QD

QD.NO_ARROW = "Codex has no usable map position for this quest, so there is no arrow."

local function trim(s) return (tostring(s):gsub("^%s+", ""):gsub("%s+$", "")) end

--- One objective as the quest log reports it: text plus the counts. A blank text is the game still loading it ("loading": shown as such, never invented).
local function objectiveOf(o)
	if type(o) ~= "table" then return nil end
	local text = type(o.text) == "string" and trim(o.text) or ""
	local have, need = tonumber(o.numFulfilled), tonumber(o.numRequired)
	return {
		text = text ~= "" and text or nil,
		loading = text == "",
		have = have, need = need,
		finished = o.finished == true,
	}
end

local function tagName(ctx, id)
	local t = ctx and ctx.questTag and ctx.questTag(id)
	if type(t) ~= "table" then return nil end
	local name = t.name
	if type(name) ~= "string" or name == "" then
		name = (t.id == 1 and "Elite") or (t.id == 81 and "Dungeon") or (t.id == 62 and "Raid") or nil
	end
	return name
end

function QD.Describe(id, ctx, opts)
	opts = opts or {}
	local e = type(id) == "number" and ctx and ctx.log and ctx.log[id] or nil
	if not e then return nil end
	local d = { id = id, title = e.title or ("quest " .. id), header = e.header, objectives = {} }
	for _, o in ipairs(e.objectives or {}) do
		local row = objectiveOf(o)
		if row then d.objectives[#d.objectives + 1] = row end
	end
	if e.complete then
		d.state, d.status = "READY", "Ready to turn in"
	else
		local left = 0
		for _, o in ipairs(d.objectives) do if not o.finished then left = left + 1 end end
		d.state = "IN_PROGRESS"
		d.status = #d.objectives == 0 and "In progress" or (left == 0 and "In progress" or string.format("In progress: %d objective%s left", left, left == 1 and "" or "s"))
	end
	d.tag = tagName(ctx, id)
	local names = opts.names
	if type(names) == "table" then
		if type(names.giver) == "string" and names.giver ~= "" then d.giver = "Quest giver: " .. names.giver .. " (QuestieDB, unverified)" end
		if type(names.turnIn) == "string" and names.turnIn ~= "" then d.turnIn = "Turn-in: " .. names.turnIn .. " (QuestieDB, unverified)" end
	end
	if opts.unplaced then d.note = QD.NO_ARROW end
	return d
end

--- One objective as a short line, e.g. "Kodo Hide: 1 / 4" (counts only when the log reported them).
function QD.ObjectiveLine(o)
	if o.loading then return "Objective still loading" end
	local text = o.text
	if o.need and o.need > 1 and o.have and not text:find("%d+%s*/%s*%d+") then
		return string.format("%s: %d / %d", text, o.have, o.need)
	end
	return text
end

-- ---------------------------------------------------------------- report: the game's own quest-UI functions (read-only; never called)

local function present(f) return type(f) == "function" end

function QD.ApiLines()
	local ql = type(C_QuestLog) == "table" and C_QuestLog or {}
	local list = {
		{ "QuestMapFrame_OpenToQuestDetails", present(QuestMapFrame_OpenToQuestDetails) },
		{ "QuestLogPopupDetailFrame_Show", present(QuestLogPopupDetailFrame_Show) },
		{ "ToggleQuestLog", present(ToggleQuestLog) },
		{ "OpenQuestLog", present(OpenQuestLog) },
		{ "C_QuestLog.SetSelectedQuest", present(ql.SetSelectedQuest) },
	}
	local out = { "game quest-UI functions (read only: Codex never calls them and has no button for them; a function that exists is not a function that works, so every state is unproven):" }
	for _, a in ipairs(list) do
		out[#out + 1] = string.format("  %s: %s, UNPROVEN (never called)", a[1], a[2] and "present" or "absent")
	end
	return out
end

return QD
