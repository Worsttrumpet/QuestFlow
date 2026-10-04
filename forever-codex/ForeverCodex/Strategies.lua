-- ForeverCodex.Strategies: route STYLES. A style is a set of scoring weights and filters applied to the SAME
-- actions from the SAME data; there is no per-style database. Adding a style = registering one more table.
--
-- Active in First Light: Efficient, Fast, Questing-only, Completionist.
-- Planned (listed, greyed, not selectable): Solo, Dungeon-friendly, Hardcore. They need group/dungeon data that
-- does not exist yet. Hardcore RESTRICTIONS already work independently of the style: the per-character Hardcore
-- toggle removes RESPAWN_SKIP actions in the engine, so intentional-death shortcuts can never be recommended.
--
-- Weights (all in "score points"):
--   base[kind]    how urgent a kind of action is: finish what you started before starting more
--   distScale     yards of travel that cost one point; distCap caps the total distance penalty
--   zoneBonus     with route zone "auto": bonus (x0.6) for staying in the zone you are in
--   routeZoneBonus  with an explicit route zone: a strong bonus for targets in the zone the PLAYER chose, large
--                 enough to outweigh walking there (the player's choice should win over convenience)
--   cluster       points per other quest-giver in the same neighbourhood (hubs), up to clusterCap
--   levelFit      prefer quests whose required level is close to yours; fitMul scales that preference
--   maxGap        hide quests more than this many levels below you (false = never hide: completionist)

local addonName, ns = ...
local C = ForeverCodex

local function weights(over)
	local w = {
		base = { TURN_IN = 100, TURN_IN_NOLOC = 60, OBJECTIVE = 70, ACCEPT = 40, DISCOVER = 10 },
		distScale = 25, distCap = 60, zoneBonus = 25, routeZoneBonus = 80, cluster = 2, clusterCap = 8,
		levelFit = true, fitMul = 1, maxGap = 14, breadcrumb = -5,
	}
	for k, v in pairs(over or {}) do w[k] = v end
	return w
end

C.RegisterStrategy({
	key = "efficient", label = "Efficient", active = true,
	desc = "Balanced: turn in what you finished, then nearby quests that fit your level, favouring quest hubs.",
	w = weights(),
})

C.RegisterStrategy({
	key = "fast", label = "Fast", active = true,
	desc = "Speed-focused: tighter level fit and less walking; skips quests well below your level.",
	w = weights({ distScale = 15, cluster = 1, fitMul = 1.5, maxGap = 10 }),
})

C.RegisterStrategy({
	key = "questing_only", label = "Questing-only", active = true,
	desc = "Only quest actions (plus the travel between them): no flight or other hints.",
	w = weights(),
	allow = { QUEST = true, TRAVEL = true, QUEST_ITEM = true },
})

C.RegisterStrategy({
	key = "completionist", label = "Completionist", active = true,
	desc = "Everything you can take in the zone, nearest first; never hides low-level quests.",
	w = weights({ distScale = 60, cluster = 0, levelFit = false, maxGap = false, zoneBonus = 40, routeZoneBonus = 90 }),
})

C.RegisterStrategy({ key = "solo", label = "Solo", active = false, desc = "Planned: avoids group content.", w = weights() })
C.RegisterStrategy({ key = "dungeon_friendly", label = "Dungeon-friendly", active = false, desc = "Planned: weaves in dungeon runs.", w = weights() })
C.RegisterStrategy({ key = "hardcore", label = "Hardcore", active = false, desc = "Planned as a full style. The Hardcore toggle already removes respawn skips.", w = weights() })
