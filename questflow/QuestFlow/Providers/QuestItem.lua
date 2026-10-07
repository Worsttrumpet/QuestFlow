-- ForeverCodex.Providers.QuestItem: a quest-starting item in the bags, as an optional "use it" action. It goes through the same candidate funnel as every provider
-- (skip list, strategy filter, diagnostics); QuestItems.lua decides what is a quest starter and whether it is actionable. The action has no map location of its own: it is
-- "wherever you are", so it carries the player's position and costs nothing to do on the way. It never competes for NOW or ALSO DO (kind USE has no planner value); the
-- tracker shows it as its own NEW QUEST ITEM card (Presenter / PlanAdapter read it from the candidate hints).

local addonName, ns = ...
local C = ForeverCodex
local R = ns.Registry

C.RegisterActionType("QUEST_ITEM", { label = "Quest item" })

local function generate(ctx, env)
	local out = {}
	local QI, G = ns.QuestItems, ns.Gear
	if not (QI and G and G.Get) then return out end
	local snap = G.Get()
	local list = snap and QI.Scan(snap.bags) or {}
	local stats = env.stats
	for _, e in ipairs(list) do
		local ok, why = QI.Actionable(e, ctx, env)
		if not ok then
			stats.filtered["questItem" .. why] = (stats.filtered["questItem" .. why] or 0) + 1
		else
			local view = R.Quest(e.quest)
			local qname = view and view.name or nil
			local target
			if ctx.loc and ctx.loc.available then
				target = { map = ctx.loc.map, x = ctx.loc.x, y = ctx.loc.y, label = "in your bags", src = e.src, verified = e.verified }
			end
			out[#out + 1] = R.NewAction({
				id = "QI:" .. e.itemId, type = "QUEST_ITEM", kind = "USE", skipKey = "QI:" .. e.itemId, hereOnly = true, quest = e.quest, itemId = e.itemId,
				name = e.name, title = "Use: " .. e.name, target = target, src = e.src, verified = e.verified, evidence = e.verified and "observed" or "unverified",
				questName = qname, starterVia = e.via,
				lines = { "Starts a quest" .. (qname and (": " .. qname) or "") .. ".", "Source: " .. (e.verified and "the game's own container quest info." or "QuestieDB (third-party data, unverified on Forever).") },
			})
		end
	end
	return out
end

C.RegisterProvider({ key = "questitem", type = "QUEST_ITEM", label = "Quest-starting items", generate = generate, quiet = true })
