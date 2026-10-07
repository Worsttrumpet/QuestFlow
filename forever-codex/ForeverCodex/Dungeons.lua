-- Dungeons.lua: quest tags (Elite, Dungeon, Raid, ...) as the GAME reports them, and the dungeon-quest list for the tracker.
--
-- Everything here is read-only display. The tag comes from the game (ctx.questTag, a safe read of C_QuestLog.GetQuestTagInfo / GetQuestTagInfo); when the
-- client does not answer, a quest simply has no tag: nothing is guessed from names or from QuestieDB. This is UNVERIFIED on Forever until a report shows
-- it answering (the playtest report prints whether the API exists and how many quests came back tagged). The planner uses them in ONE place: a dungeon objective is not NOW while the player is outside that dungeon (Planner stage 1; Dg.PlayerInside).
local _, ns = ...
local Dg = {}
ns.Dungeons = Dg

local R = ns.Registry

-- the game's quest tag ids (the same ids Questie documents; only the ones that matter for display)
Dg.TAG_ELITE = 1
Dg.DUNGEON_TAGS = { [81] = true, [62] = true, [85] = true, [88] = true, [89] = true, [83] = true }   -- dungeon, raid, heroic, raid 10/25, legendary
Dg.LABEL_TAGS = { [1] = true, [81] = true, [62] = true, [85] = true, [88] = true, [89] = true, [83] = true }

local function tagOf(ctx, quest)
	return ctx and ctx.questTag and quest and ctx.questTag(quest) or nil
end

--- True when the game tags this quest as a dungeon / raid style quest.
function Dg.IsDungeon(ctx, quest)
	local t = tagOf(ctx, quest)
	return t ~= nil and Dg.DUNGEON_TAGS[t.id] == true
end

--- " (Elite)" / " (Dungeon)" ... after a quest name, or "" for an untagged or unlabelled quest. The word is the game's own tag name; a plain
-- English word is used only when the game gave a tag id without a name.
function Dg.Suffix(ctx, quest)
	local t = tagOf(ctx, quest)
	if not t or not Dg.LABEL_TAGS[t.id] then return "" end
	local name = t.name
	if not name or name == "" then name = (t.id == 1 and "Elite") or (t.id == 81 and "Dungeon") or (t.id == 62 and "Raid") or "Group" end
	return " (" .. name .. ")"
end

--- The dungeon a quest belongs to, by name: the game's name for the quest data's area (a dungeon quest's zone is the dungeon), else the quest log's own
-- section heading, else nil.
local function dungeonName(ctx, entry)
	local view = R and R.Quest(entry.id)
	if view and view.areaId and ctx.areaName then
		local n = ctx.areaName(view.areaId)
		if n then return n, "area" end
	end
	if entry.header then return entry.header, "log" end
	return nil
end

--- Is the player inside the dungeon this dungeon quest belongs to? Only the client's own instance state counts (ctx.instance, Context.lua); an unknown state is "not inside" (the player is
-- almost always outside, and a dungeon objective must not become NOW from a guess). Inside an instance, the quest's dungeon (the game's area name, else the quest log heading) is compared with the
-- instance's name when both are known (by either of its names); when either is missing the player is taken to be inside it (a dungeon quest is not blocked while the player is in a dungeon and the names cannot be compared).
function Dg.PlayerInside(ctx, quest)
	local inst = ctx and ctx.instance
	if not (inst and inst.known and inst.inInstance == true) then return false end
	local e = ctx.log and ctx.log[quest]
	local here = inst.name
	if type(here) ~= "string" or here == "" or not e then return true end
	-- the quest's dungeon by either name the game gives it (its area name, or its quest log heading): a match on either is enough
	local names, known = {}, false
	local view = R and R.Quest(e.id)
	if view and view.areaId and ctx.areaName then names[#names + 1] = ctx.areaName(view.areaId) end
	names[#names + 1] = e.header
	for _, n in ipairs(names) do
		if type(n) == "string" and n ~= "" then
			known = true
			if n:lower() == here:lower() then return true end
		end
	end
	return not known
end

--- Dungeon quests in the quest log, grouped by dungeon:
-- { { name = "Dungeon name" or "Dungeon quests", via = "area"|"log"|"none", quests = { { quest, title, complete, objectives } } } }, sorted by name.
function Dg.List(ctx)
	local groups, byName = {}, {}
	if not (ctx and ctx.log) then return groups end
	local ids = {}
	for id in pairs(ctx.log) do ids[#ids + 1] = id end
	table.sort(ids)
	for _, id in ipairs(ids) do
		local e = ctx.log[id]
		if Dg.IsDungeon(ctx, id) then
			local name, via = dungeonName(ctx, e)
			local key = name or "Dungeon quests"
			local g = byName[key]
			if not g then
				g = { name = key, via = via or "none", quests = {} }
				byName[key] = g
				groups[#groups + 1] = g
			end
			g.quests[#g.quests + 1] = { quest = id, title = e.title or ("quest " .. id), complete = e.complete == true, objectives = e.objectives }
		end
	end
	table.sort(groups, function(a, b) return a.name < b.name end)
	for _, g in ipairs(groups) do
		table.sort(g.quests, function(a, b) if a.title ~= b.title then return a.title < b.title end return a.quest < b.quest end)
	end
	return groups
end
