-- ForeverCodex.Providers.Flight: nearby flight-path HINTS from ATT flight-node data.
--
-- Honest limits: Codex cannot tell whether you have already discovered a flight path (the taxi APIs are not
-- verified on Forever), so these are only ever "while you're here" hints, labelled as such, never part of the
-- main route. Locations are ATT's (unverified).

local addonName, ns = ...
local C = ForeverCodex
local R = ns.Registry

C.RegisterActionType("FLIGHT", { label = "Flight path" })

local function generate(ctx, env)
	local out = {}
	local fac = ctx.char.faction
	for _, n in ipairs(R.FlightNodes()) do
		if not (n.faction and fac and n.faction ~= fac) then
			local label = (n.name or ("flight node " .. n.id))
			out[#out + 1] = R.NewAction({
				id = "FP:" .. n.id, type = "FLIGHT", kind = "DISCOVER", skipKey = "FP:" .. n.id, hereOnly = true,
				title = "Flight path: " .. label,
				lines = { "Flight master" .. (n.npc and (" (NPC #" .. n.npc .. ")") or "") .. " - " .. R.MapLabel(n.map),
					string.format("Location: %.1f, %.1f (ATT, unverified)", n.x * 100, n.y * 100),
					"Codex cannot tell whether you already have this flight path." },
				target = { map = n.map, x = n.x, y = n.y, label = label, src = n.src, verified = n.verified },
				src = n.src, verified = n.verified,
			})
		end
	end
	return out
end

-- system = "flight": the player can switch these hints off (on by default).
C.RegisterProvider({ key = "flight", type = "FLIGHT", system = "flight", label = "Flight path hints", generate = generate })
