-- ForeverCodex.NewForYou: a temporary card for MEANINGFUL progression that just opened up. Event-driven, never a standing list.
--
--   * Checked only when the character's level rises to an EVEN level (2, 4, 6, ...), for every even level crossed.
--   * Asks each registered provider "is there something real and reliably known?". No items = no card (an even level alone
--     shows nothing).
--   * When there is something: visible for exactly DURATION seconds (60), then gone. No dismissal, nothing persisted.
--   * The first context after login is only a baseline (logging in at level 20 is not "reaching" level 20).
--
-- Providers are plain functions registered here; later systems (class abilities, professions, pet skills, travel) add theirs.
-- WHAT EXISTS TODAY: one provider, "quests": quests the game's own data shows on Forever (an observed record) whose required
-- level (ATT) has just been met and that the character can take. No spell, trainer, recipe or pet provider ships: Forever's spell and
-- trainer APIs are unverified, and Codex does not invent progression. A new quest never changes NOW (the Planner decides).

local addonName, ns = ...
local R = ns.Registry
local K = ns.Contract

local N = {}
ns.NewForYou = N

N.DURATION = 60
N.MAX_ITEMS = 3

local providers, order = {}, {}
local lastLevel, active = nil, nil

local function now() return type(GetTime) == "function" and GetTime() or 0 end

--- fn(ctx, fromLevel, toLevel) -> list of { title, detail? }
function N.Register(key, fn)
	if not providers[key] then order[#order + 1] = key end
	providers[key] = fn
end

function N.Unregister(key)
	providers[key] = nil
	for i, k in ipairs(order) do if k == key then table.remove(order, i) break end end
end

N.Register("quests", function(ctx, from, to)
	local out = {}
	for _, id in ipairs(R.QuestIds()) do
		local v = R.Quest(id)
		if v and v.hasObserved and v.req and v.req > from and v.req <= to and not v.repeatable and not ctx.log[id] then
			local st = K.QuestState(id, v, ctx)
			if st.state == "AVAILABLE" then out[#out + 1] = { title = "New quest: " .. (v.name or "a quest"), id = id } end
		end
	end
	table.sort(out, function(a, b) if a.title ~= b.title then return a.title < b.title end return a.id < b.id end)
	return out
end)

--- Called with every fresh Context.
function N.OnContext(ctx)
	local lvl = ctx and ctx.char and ctx.char.level
	if type(lvl) ~= "number" then return end
	if lastLevel == nil then lastLevel = lvl return end
	if lvl <= lastLevel then lastLevel = lvl return end
	local from, to = lastLevel, lvl
	lastLevel = lvl
	local top
	for L = to, from + 1, -1 do if L % 2 == 0 then top = L break end end
	if not top then return end
	local items = {}
	for _, key in ipairs(order) do
		local ok, list = pcall(providers[key], ctx, from, to)
		if ok and type(list) == "table" then
			for _, it in ipairs(list) do if #items < N.MAX_ITEMS and type(it.title) == "string" then items[#items + 1] = { title = it.title, detail = it.detail } end end
		elseif not ok then
			ns.RecordError("newforyou " .. key, list)
		end
	end
	if #items > 0 then active = { level = top, items = items, expires = now() + N.DURATION } end
end

--- The card to show right now, or nil (expired cards disappear completely).
function N.Active()
	if active and now() >= active.expires then active = nil end
	return active
end

function N._Reset() lastLevel, active = nil, nil end
