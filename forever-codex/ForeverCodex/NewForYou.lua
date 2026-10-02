-- ForeverCodex.NewForYou: a temporary card for NEW CLASS ABILITIES (spells, abilities) the player can learn at their current level
-- ("New abilities available: ... Visit your class trainer."). It is NOT a quest list: quests belong to NOW and NEARBY. Event-driven,
-- never a standing list.
--
--   * Checked only when the character's level rises to an EVEN level (2, 4, 6, ...), for every even level crossed.
--   * Asks each registered provider "is there something real and reliably known?". No items = no card (an even level alone
--     shows nothing).
--   * When there is something: visible for exactly DURATION seconds (60), then gone. No dismissal, nothing persisted.
--   * The first context after login is only a baseline (logging in at level 20 is not "reaching" level 20).
--
-- Providers are plain functions registered here; a class-ability provider (and later professions, pet skills, travel) adds its own.
-- WHAT EXISTS TODAY: NO provider. Forever's spell and trainer APIs are unverified, and Codex does not invent progression or assume that
-- Classic spell availability is identical on Forever, so the card simply stays hidden until a provider that can be verified exists. (There
-- used to be a "quests" provider here; it was wrong for this card and was removed rather than made smarter.) A level-up never shows a quest.

local addonName, ns = ...

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

--- The registered provider keys (none ships today).
function N.Providers()
	local out = {}
	for i, k in ipairs(order) do out[i] = k end
	return out
end

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
