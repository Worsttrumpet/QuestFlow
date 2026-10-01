---------------------------------------------------
--          Z O N E S        M O D U L E         --
---------------------------------------------------

maproot(MAP.ZEPHRAS_ISLE, {
	lore = "Once a secluded island oasis in the sky, Zephras Isle now welcomes the next generation of WoW’s newest race – the Skyborne – to protect this floating island and secure its future.",
	--icon = ,	-- TODO: Add an icon for Zephras Isle
	timeline = { TIMELINE.ADDED_1_60_1 },
	["races"] = { SKYBORNE_ALLIANCE, SKYBORNE_HORDE },
	["groups"] = {
		n(QUESTS, {
			q(92460, {	-- Coming of Age
				["qg"] = 251362,	-- Ailee Farheart <Rangers of Thendal Grove>
				["coord"] = { 42.8, 23.4, MAP.ZEPHRAS_ISLE },
				["groups"] = {
					i(264908),	-- Ancient Heirloom
				},
			}),
			q(92461, {	-- Harmony in Balance
				["qg"] = 251361,	-- Rorian the Dayseeker
				["coords"] = { 42.1, 23.5, MAP.ZEPHRAS_ISLE },
				["sourceQuests"] = { 92460 },	-- Coming of Age
				["groups"] = {
					i(257281),	-- Fur-Lined Shoes
					i(257280),	-- Vuldren Hide Bracers
					objective(1, {	-- 0/8 Slay Juvenile Vuldren
						["provider"] = { "n", 250873 },	-- Juvenile Vuldren
					}),
				},
			}),
			q(92462, {	-- Infestation Investigation
				["qg"] = 251368,	-- Elatrell Featherlight <Rangers of Thendal Grove>
				["coords"] = { 43.4, 24.8, MAP.ZEPHRAS_ISLE },
				["sourceQuests"] = { 92460 },	-- Coming of Age
				["groups"] = {
					objective(1, {	-- 0/8 Slay Pesky Cirrusfly
						["provider"] = { "n", 251169 },	-- Pesky Cirrusfly
					}),
				},
			}),
			q(92465, {	-- Agitators
				["qg"] = 249363,	-- Yala Windwatcher
				["coords"] = { 47.3, 21.9, MAP.ZEPHRAS_ISLE },
				["sourceQuests"] = { 92460 },	-- Coming of Age
				["groups"] = {
					objective(1, {	-- 0/7 Slay Al'Aketh Convert
						["provider"] = { "n", 251160 },	-- Al'Aketh Convert
					}),
					objective(2, {	-- 0/6 Destroy Roiling Winds
						["provider"] = { "n", 251143 },	-- Roiling Winds
					}),
				},
			}),
			q(92481, {	-- A Student of the Arcane
				["qg"] = 251361,	-- Rorian the Dayseeker
				["coords"] = { 42.1, 23.5, MAP.ZEPHRAS_ISLE },
				["sourceQuests"] = { 92461 },	-- Harmony in Balance
				["qi"] = 282416,	-- Glowing Recall Crystal
			}),
		}),
	},
});
