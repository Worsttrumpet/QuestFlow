---------------------------------------------------
--          Z O N E S        M O D U L E         --
---------------------------------------------------

maproot(MAP.KALIMDOR, MAP.MOUNT_HYJAL, {
	lore = "Threats both old and new stalk the slopes of the mountain, eager to claim its power and destroy anyone daring enough to get in their way.",
	timeline = { TIMELINE.ADDED_1_60_1 },
	icon = 409547,
	groups = {
		n(ACHIEVEMENTS, {
			ach(62356),	-- Explore Mount Hyjal
		}),
	},
});
