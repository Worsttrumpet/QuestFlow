---------------------------------------------------
--          Z O N E S        M O D U L E         --
---------------------------------------------------

maproot(MAP.EASTERN_KINGDOMS, MAP.RIVERGLADES, {
	lore = "A sprawling landscape in the Eastern Kingdom which shifts from lush hillsides to ruined keeps of old.",
	timeline = { TIMELINE.ADDED_1_60_1 },
	icon = 1032150,
	groups = {
		n(ACHIEVEMENTS, {
			ach(62354),	-- Explore Riverglades
		}),
		n(FLIGHT_PATHS, {
			fp(3276, {	-- Farholde Keep, Riverglades
				["cr"] = 257087,	-- Gretchen Mayberry <Gryphon Master>
				["coord"] = { 60.6, 81.6, MAP.RIVERGLADES },
				["races"] = ALLIANCE_ONLY,
			}),
		}),
	},
});
