---------------------------------------------
--    C R A F T A B L E S   M O D U L E    --
---------------------------------------------
local function ClassicCost(cost)
	-- This data is provided by ReagentsDB in Retail
	-- #IF ANYCLASSIC
	return cost
	-- #ENDIF
end
root(ROOTS.Craftables, {
	prof(ALCHEMY, {
		n(COMMON_VENDOR_ITEMS, {
			["groups"] = appendAllGroups(
				{
					i(3371, {	-- Empty Vial for Vanilla, turns into Crystal Vial with Cataclysm and becomes the one vial to use in crafting recipes, deprecating all other vials.
						["description"] = "Can be bought from Alchemy Suppliers, as well as some Trade vendors around the world.",
						-- Danny Donkey: Disabling this for now, Common Vendor Items is being filled into Minilists when coords are given.
						--[[["coords"] = {
							{ 66.6, 54.6, MAP.IRONFORGE },
							{ 47.4, 33.73, MAP.THUNDER_BLUFF },
							{ 51.8, 74.6, MAP.UNDERCITY },
							{ 46.6, 78.8, MAP.STORMWIND_CITY },
							{ 55.8, 24.5, MAP.DARNASSUS },
							{ 56.2, 34.2, MAP.ORGRIMMAR },
						},]]
					}),
				},
				sharedData({	-- Leaded-/Crystal Vials for Vanilla
					["description"] = "Can be bought from Alchemy Suppliers, as well as some Trade vendors around the world.",
					["coords"] = {
						{ 55.8, 24.5, MAP.DARNASSUS },
						{ 66.6, 54.6, MAP.IRONFORGE },
						{ 56.2, 34.2, MAP.ORGRIMMAR },
						{ 47.4, 33.73, MAP.THUNDER_BLUFF },
						{ 51.8, 74.6, MAP.UNDERCITY },
						{ 46.6, 78.8, MAP.STORMWIND_CITY },
					},
					["timeline"] = { REMOVED_4_0_1 },
				}, {
					i(3372),	-- Leaded Vial, turns into Cracked Vial with Cataclysm.
					i(8925),	-- Crystal Vial, turns into Tainted Vial with Cataclysm.
				}),
				{
					i(18256, {	-- Imbued Vial for Vanilla/TBC/WotLK, turns into Melted Vial with Cataclysm.
						["description"] = "Can be bought from Alchemy Suppliers, as well as some Trade vendors around the world.",
						["coords"] = {
							{ 55.8, 24.5, MAP.DARNASSUS },
							{ 66.6, 54.6, MAP.IRONFORGE },
							{ 56.2, 34.2, MAP.ORGRIMMAR },
							{ 47.4, 33.73, MAP.THUNDER_BLUFF },
							{ 51.8, 74.6, MAP.UNDERCITY },
							{ 46.6, 78.8, MAP.STORMWIND_CITY },
						},
						["timeline"] = { REMOVED_4_0_1 },
					}),
				}
			)
		}),
		filter(CONSUMABLES, {
			i(6452, {["timeline"] = { ADDED_8_0_1 }}),	-- Anti-Venom
			i(9155),	-- Arcane Elixir
			i(10592),	-- Catseye Elixir
			i(4596, {["timeline"] = { REMOVED_4_0_3 }}),	-- Discolored Healing Potion
			i(12190),	-- Dreamless Sleep Potion
			i(8949),	-- Elixir of Agility
			-- #if SEASON_OF_DISCOVERY
			applyclassicphase(SOD_PHASE_SIX, i(233977, {["timeline"] = { ADDED_1_15_5 }})),	-- Elixir of Alacrity
			-- #endif
			i(13453),	-- Elixir of Brute Force
			-- #if SEASON_OF_DISCOVERY
			applyclassicphase(SOD_PHASE_ONE, i(210708, {["timeline"] = { ADDED_1_15_0 }})),	-- Elixir of Coelesced Regret
			-- #endif
			i(3389),	-- Elixir of Defense
			i(9224),	-- Elixir of Demonslaying
			i(9233),	-- Elixir of Detect Demon
			i(3828),	-- Elixir of Detect Lesser Invisibility
			i(9154),	-- Elixir of Detect Undead
			i(9197),	-- Elixir of Dream Vision
			i(6373),	-- Elixir of Firepower
			i(3825),	-- Elixir of Fortitude
			i(17708),	-- Elixir of Frost Power
			i(6662),	-- Elixir of Giant Growth
			i(9206),	-- Elixir of Giants
			i(9187),	-- Elixir of Greater Agility
			i(8951),	-- Elixir of Greater Defense
			i(21546, {["timeline"] = { ADDED_1_11_1, REMOVED_4_0_3, ADDED_10_1_7 }}),	-- Elixir of Greater Firepower
			i(9179),	-- Elixir of Greater Intellect
			i(18294),	-- Elixir of Greater Water Breathing
			i(3390),	-- Elixir of Lesser Agility
			i(2454),	-- Elixir of Lion's Strength
			i(45621, {["timeline"] = { ADDED_3_1_0 }}),	-- Elixir of Minor Accuracy
			i(2457),	-- Elixir of Minor Agility
			i(5997),	-- Elixir of Minor Defense
			i(2458),	-- Elixir of Minor Fortitude
			i(3391),	-- Elixir of Ogre's Strength
			i(9264),	-- Elixir of Shadow Power
			i(13445),	-- Elixir of Superior Defense
			-- #if SEASON_OF_DISCOVERY
			applyclassicphase(SOD_PHASE_SIX, i(233967, {["timeline"] = { ADDED_1_15_5 }})),	-- Elixir of the Honey Badger
			applyclassicphase(SOD_PHASE_SIX, i(233969, {["timeline"] = { ADDED_1_15_5 }})),	-- Elixir of the Ironside
			applyclassicphase(SOD_PHASE_SIX, i(233968, {["timeline"] = { ADDED_1_15_5 }})),	-- Elixir of the Mage-Lord
			-- #endif
			i(13452, {["timeline"] = { ADDED_1_11_1, REMOVED_4_0_3, ADDED_10_1_7 }}),	-- Elixir of the Mongoose
			i(13447),	-- Elixir of the Sages
			i(5996),	-- Elixir of Water Breathing
			i(3383),	-- Elixir of Wisdom
			i(6049),	-- Fire Protection Potion
			-- #if SEASON_OF_DISCOVERY
			applyclassicphase(SOD_PHASE_SIX, i(233964, {["timeline"] = { ADDED_1_15_5 }})),	-- Flask of Ancient Knowledge
			-- #endif
			i(13513, {["timeline"] = { REMOVED_5_0_4 }}),	-- Flask of Chromatic Resistance
			i(13511),	-- Flask of Distilled Wisdom
			-- #if SEASON_OF_DISCOVERY
			applyclassicphase(SOD_PHASE_THREE, i(221024, {["timeline"] = { ADDED_1_15_2 }})),	-- Flask of Everlasting Nightmares
			applyclassicphase(SOD_PHASE_SIX, i(233962, {["timeline"] = { ADDED_1_15_5 }})),	-- Flask of Madness
			applyclassicphase(SOD_PHASE_THREE, i(221313, {["timeline"] = { ADDED_1_15_2 }})),	-- Flask of Nightmarish Mojo
			applyclassicphase(SOD_PHASE_THREE, i(222952, {["timeline"] = { ADDED_1_15_2 }})),	-- Flask of Restless Dreams
			-- #endif
			i(13512),	-- Flask of Supreme Power
			-- #if SEASON_OF_DISCOVERY
			applyclassicphase(SOD_PHASE_SIX, i(233966, {["timeline"] = { ADDED_1_15_5 }})),	-- Flask of Unyielding Sorrow
			-- #endif
			i(13510),	-- Flask of the Titans
			-- #if SEASON_OF_DISCOVERY
			applyclassicphase(SOD_PHASE_SIX, i(233966, {["timeline"] = { ADDED_1_15_5 }})),	-- Flask of Unyielding Sorrow
			-- #endif
			i(5634),	-- Free Action Potion
			i(6050),	-- Frost Protection Potion
			i(9088, {["timeline"] = { REMOVED_4_0_3, ADDED_10_1_7 }}),	-- Gift of Arthas
			i(5633),	-- Great Rage Potion
			i(13454),	-- Greater Arcane Elixir
			i(13461, {["timeline"] = { REMOVED_4_0_3, ADDED_9_1_0 }}),	-- Greater Arcane Protection Potion
			applyclassicphase(PHASE_FOUR, i(20002, {["timeline"] = { REMOVED_4_0_3, ADDED_10_0_7 }})),	-- Greater Dreamless Sleep Potion
			i(13457),	-- Greater Fire Protection Potion
			i(13456, {["timeline"] = { ADDED_1_11_1, REMOVED_4_0_3, ADDED_10_1_7 }}),	-- Greater Frost Protection Potion
			i(1710),	-- Greater Healing Potion
			i(6149),	-- Greater Mana Potion
			i(13458),	-- Greater Nature Protection Potion
			i(13459, {["timeline"] = { ADDED_1_11_1, REMOVED_4_0_3, ADDED_10_1_7 }}),	-- Greater Shadow Protection Potion
			i(13455),	-- Greater Stoneshield Potion
			i(929),	-- Healing Potion
			i(6051),	-- Holy Protection Potion
			i(9172),	-- Invisibility Potion
			-- #if SEASON_OF_DISCOVERY
			applyclassicphase(SOD_PHASE_TWO, i(217398, {["timeline"] = { ADDED_1_15_1 }})),	-- Lesser Arcane Elixir
			-- #endif
			i(858),	-- Lesser Healing Potion
			i(3823),	-- Lesser Invisibility Potion
			i(3385),	-- Lesser Mana Potion
			i(4623, {["timeline"] = { REMOVED_4_0_3 }}),	-- Lesser Stoneshield Potion
			i(3387),	-- Limited Invulnerability Potion
			applyclassicphase(PHASE_FOUR, i(20008)),	-- Living Action Potion
			applyclassicphase(PHASE_FOUR, i(20007, {["timeline"] = { REMOVED_4_0_3, ADDED_10_0_7 }})),	-- Mageblood Elixir[2.1.0+] / Mageblood Potion
			i(9036, {["timeline"] = { REMOVED_5_0_4 }}),	-- Magic Resistance Potion
			-- #if SEASON_OF_DISCOVERY
			applyclassicphase(SOD_PHASE_EIGHT, i(241650, {["timeline"] = { ADDED_1_15_7 }})),	-- Major Discolored Healing Potion
			-- #endif
			i(13446),	-- Major Healing Potion
			i(13444),	-- Major Mana Potion
			i(18253),	-- Major Rejuvenation Potion
			applyclassicphase(PHASE_FOUR, i(3826)),	-- Major Troll's Blood Elixir[Wrath+] / Mighty Troll's Blood Potion
			i(3827),	-- Mana Potion
			i(13442),	-- Mighty Rage Potion
			i(20004),	-- Mighty Troll's Blood Elixir[Wrath+] / Major Troll's Blood Potion
			-- #if SEASON_OF_DISCOVERY
			applyclassicphase(SOD_PHASE_TWO, i(215162, {["timeline"] = { ADDED_1_15_1 }})),	-- Mildly Irradiated Rejuvenation Potion
			-- #endif
			i(118),	-- Minor Healing Potion
			i(3384, {["timeline"] = { REMOVED_5_0_4 }}),	-- Minor Magic Resistance Potion
			i(2455),	-- Minor Mana Potion
			i(2456),	-- Minor Rejuvenation Potion
			i(6052),	-- Nature Protection Potion
			i(8956),	-- Oil of Immolation
			i(3386),	-- Potion of Curing[TBC+] / Elixir of Poison Resistance
			i(13506),	-- Potion of Petrification[3.2.0+] / Flask of Petrification
			i(19440, {["timeline"] = { ADDED_8_0_1 }}),	-- Powerful Anti-Venom
			i(13462),	-- Purification Potion
			i(5631),	-- Rage Potion
			i(9030, {["timeline"] = { REMOVED_4_0_3 }}),	-- Restorative Potion
			i(6048),	-- Shadow Protection Potion
			i(6453, {["timeline"] = { ADDED_8_0_1 }}),	-- Strong Anti-Venom
			i(3388),	-- Strong Troll's Blood Elixir[Wrath+] / Strong Troll's Blood Potion
			i(3928),	-- Superior Healing Potion
			i(13443),	-- Superior Mana Potion
			i(2459),	-- Swiftness Potion
			i(6372),	-- Swim Speed Potion
			i(3382),	-- Weak Troll's Blood Elixir[Wrath+] / Weak Troll's Blood Potion
			i(9144, {["timeline"] = { REMOVED_4_0_3, ADDED_10_1_7 }}),	-- Wildvine Potion
		}),
		filter(REAGENTS, {
			i(12360),	-- Arcanite Bar
			i(6370),	-- Blackmouth Oil
			i(6371),	-- Fire Oil
			i(3829),	-- Frost Oil
			i(9210),	-- Ghost Dye
			i(9061),	-- Goblin Rocket Fuel
			applyclassicphase(PHASE_FOUR, i(19931, {	-- Gurubashi Mojo Madness
				["timeline"] = { REMOVED_4_0_3, ADDED_10_0_7 },
				-- #if AFTER 10.0.7
				["description"] = "Has to be used near the 'Brazier of Madness' Toy to receive the 'Succumbed to Madness' Buff.",
				-- #endif
			})),
			i(3577),	-- Gold Bar
			-- #if SEASON_OF_DISCOVERY
			applyclassicphase(SOD_PHASE_TWO, i(213372, {["timeline"] = { ADDED_1_15_1 }})),	-- Insulating Gniodine
			-- #endif
			i(3824, {["timeline"] = {REMOVED_4_0_3, ADDED_4_1_0}}),	-- Shadow Oil
			i(13423),	-- Stonescale Oil
			i(6037),	-- Truesilver Bar
		}),
		filter(TRINKET_F, {
			i(75525, {["timeline"] = {ADDED_5_0_4}}),	-- Alchemist's Flask
			i(9149),	-- Philosopher's Stone
		}),
	}),
	prof(BLACKSMITHING, {
		n(COMMON_VENDOR_ITEMS, {
			["groups"] = appendAllGroups(
				{
					i(5956, {	-- Blacksmithing Hammer
						["collectible"] = false,
						["description"] = "Can be bought from Blacksmithing- and Engineering Suppliers, as well as some Trade vendors around the world.",
					}),
				},
				sharedData({
					["description"] = "Can be bought from Blacksmithing Suppliers, as well as some Trade vendors around the world.",
					-- Danny Donkey: Disabling this for now, Common Vendor Items is being filled into Minilists when coords/providers are given.
					--[[["description"] = "Can be bought from Blacksmithing Suppliers, as well as some Trade vendors around the world. Coordinates are for select vendors.",
					["coords"] = {
						{ 51.8, 41.2, MAP.IRONFORGE },
						{ 39.8, 55.6, MAP.THUNDER_BLUFF },
						{ 61.4, 30.1, MAP.UNDERCITY },
						{ 56.3, 17.2, MAP.STORMWIND_CITY },
						{ 82.4, 23.8, MAP.ORGRIMMAR },
					},
					["providers"] = {
						{ "n", 5512},	-- Kaita Deepforge <Blacksmithing Supplies>
						{ "n", 4597},	-- Samuel Van Brunt <Blacksmithing Supplies>
						{ "n", 3356},	-- Sumi <Blacksmithing Supplies>
						{ "n", 2999},	-- Taur Stonehoof <Blacksmithing Supplies>
						{ "n", 4259},	-- Thurgrum Deepforge <Blacksmithing Supplies>
					},]]
				}, {
					i(2880),	-- Weak Flux
					i(3466),	-- Strong Flux
					i(18567),	-- Elemental Flux
					i(3857),	-- Coal
				})
			)
		}),
		-- #if BEFORE TBC
		prof(9788, {	-- Armorsmith
			["description"] = "These items can only be crafted by Blacksmiths who have completed the Art of the Armorsmith quest chain.",
			["groups"] = {
				applyclassicphase(PHASE_FOUR_DARKIRON_RECIPES, i(20039)),	-- Dark Iron Boots
				i(17014),	-- Dark Iron Bracers
				applyclassicphase(PHASE_THREE_RECIPES, i(19164)),	-- Dark Iron Gauntlets
				applyclassicphase(PHASE_THREE_RECIPES, i(19148)),	-- Dark Iron Helm
				i(17013),	-- Dark Iron Leggings
				i(11604, {	-- Dark Iron Plate
					-- #if SEASON_OF_DISCOVERY
					["timeline"] = { REMOVED_1_15_3 },
					-- #endif
				}),
				i(12628, {["timeline"] = { REMOVED_4_0_3 }}),	-- Demon Forged Breastplate
				applyclassicphase(PHASE_THREE_RECIPES, i(12618, {["timeline"] = { REMOVED_4_0_3 }})),	-- Enchanted Thorium Breastplate
				applyclassicphase(PHASE_THREE_RECIPES, i(12620, {["timeline"] = { REMOVED_4_0_3 }})),	-- Enchanted Thorium Helm
				applyclassicphase(PHASE_THREE_RECIPES, i(12619, {["timeline"] = { REMOVED_4_0_3 }})),	-- Enchanted Thorium Leggings
				i(12631, {	-- Fiery Plate Gauntlets
					["timeline"] = {
						-- #if SEASON_OF_DISCOVERY
						REMOVED_1_15_3,
						-- #else
						REMOVED_4_0_3,
						-- #endif
					},
				}),
				-- #if SEASON_OF_DISCOVERY
				applyclassicphase(SOD_PHASE_FOUR, i(227865, {["timeline"] = { ADDED_1_15_3 }})),	-- Fiery Plate Gauntlets of the Hidden Technique
				-- #endif
				i(16989),	-- Fiery Chain Girdle
				i(16988),	-- Fiery Chain Shoulders
				i(12636, {	-- Helm of the Great Chief
					-- #if SEASON_OF_DISCOVERY
					["timeline"] = { REMOVED_1_15_3 },
					-- #endif
				}),
				-- #if SEASON_OF_DISCOVERY
				applyclassicphase(SOD_PHASE_FOUR, i(227876, {["timeline"] = { ADDED_1_15_3 }})),	-- Invincible Mail
				-- #endif
				i(12641, {	-- Invulnerable Mail
					-- #if SEASON_OF_DISCOVERY
					-- CRIEVE NOTE: This item still drops apparently, I got this on my paladin.
					-- ["timeline"] = { REMOVED_1_15_3 },
					-- #endif
				}),
				i(12640),	-- Lionheart Helm
				-- #if SEASON_OF_DISCOVERY
				applyclassicphase(SOD_PHASE_SIX, i(233795, {["timeline"] = { ADDED_1_15_5 }})),	-- Razorspike Headcage
				applyclassicphase(SOD_PHASE_SIX, i(233793, {["timeline"] = { ADDED_1_15_5 }})),	-- Razorspike Shoulderplates
				applyclassicphase(SOD_PHASE_SIX, i(233492, {["timeline"] = { ADDED_1_15_5 }})),	-- Razorspike Battleplate
				-- #endif
				i(12632, {	-- Storm Gauntlets
					-- #if SEASON_OF_DISCOVERY
					["timeline"] = { REMOVED_1_15_3 },
					-- #endif
				}),
				i(12639),	-- Stronghold Gauntlets
				-- #if SEASON_OF_DISCOVERY
				applyclassicphase(SOD_PHASE_FOUR, i(227871, {["timeline"] = { ADDED_1_15_3 }})),	-- Tempered Dark Iron Plate
				applyclassicphase(SOD_PHASE_FOUR, i(227870, {["timeline"] = { ADDED_1_15_3 }})),	-- Tempest Gauntlets
				-- #endif
				applyclassicphase(PHASE_FIVE, i(22385)),	-- Titanic Leggings
				i(7939, {["timeline"] = { REMOVED_4_0_3 }}),	-- Truesilver Breastplate
				i(7938, {["timeline"] = { REMOVED_4_0_3 }}),	-- Truesilver Gauntlets
				-- #if SEASON_OF_DISCOVERY
				applyclassicphase(SOD_PHASE_FOUR, i(227872, {["timeline"] = { ADDED_1_15_3 }})),	-- Warcrest of the Great Chief
				-- #endif
				i(12633),	-- Whitesoul Helm
				i(12624),	-- Wildthorn Mail
			},
		}),
		prof(9787, {	-- Weaponsmith
			["description"] = "These items can only be crafted by Blacksmiths who have completed the Way of the Weaponsmith quest chain.",
			["groups"] = {
				prof(17041, {	-- Master Axesmith
					["description"] = "These items can only be crafted by Master Axesmith specialized Weaponsmiths.",
					["groups"] = {
						i(12798, {	-- Annihilator
							-- #if SEASON_OF_DISCOVERY
							["description"] = "Blizzard stated that Annihilator was an item that forced 1 member of the raid into a role that did not fit their design, so they've decided to not include Annihilator.",
							["timeline"] = { REMOVED_1_15_0 },
							-- #endif
						}),
						i(12784),	-- Arcanite Reaper
						i(17016),	-- Dark Iron Destroyer
						i(12774, {["timeline"] = { REMOVED_4_0_3, ADDED_7_1_5 }}),	-- Dawn's Edge
						applyclassicphase(PHASE_THREE_RECIPES, i(19169, {	-- Nightfall
							-- #if SEASON_OF_DISCOVERY
							["timeline"] = { REMOVED_1_15_0 },
							-- #endif
						})),
						-- #if SEASON_OF_DISCOVERY
						applyclassicphase(SOD_PHASE_SIX, i(233801, {["timeline"] = { ADDED_1_15_5 }})),	-- Obsidian Defender
						applyclassicphase(SOD_PHASE_SIX, i(233491, {["timeline"] = { ADDED_1_15_5 }})),	-- Obsidian Reaver
						applyclassicphase(SOD_PHASE_FOUR, i(227843, {	-- Reaving Nightfall
							["description"] = "Blizzard stated that Nightfall was an item that forced 1 member of the raid into a role that did not fit their design, so they've decided to not include Nightfall or this updated version of it.",
							["timeline"] = { CREATED_1_15_3 },
						})),
						-- #endif
					},
				}),
				prof(17040, {	-- Master Hammersmith
					["description"] = "These items can only be crafted by Master Hammersmith specialized Weaponsmiths.",
					["groups"] = {
						applyclassicphase(PHASE_THREE_RECIPES, i(19170)),	-- Ebon Hand
						i(12776, {	-- Enchanted Battlehammer
							["timeline"] = {
								-- #if SEASON_OF_DISCOVERY
								REMOVED_1_15_3,
								-- #else
								REMOVED_4_0_3,
								-- #endif
							}
						}),
						-- #if SEASON_OF_DISCOVERY
						applyclassicphase(SOD_PHASE_FOUR, i(227880, {["timeline"] = { ADDED_1_15_3 }})),	-- Finely-Enchanted Battlehammer
						-- #endif
						i(12796),	-- Hammer of the Titans
						i(12794, {	-- Masterwork Stormhammer
							["timeline"] = { REMOVED_6_0_2, ADDED_10_1_5 },
						}),
						applyclassicphase(PHASE_FIVE_RECIPES, i(22384)),	-- Persuader
						i(12781, {	-- Serenity
							-- #if SEASON_OF_DISCOVERY
							["timeline"] = { REMOVED_1_15_3 },
							-- #endif
						}),
						-- #if SEASON_OF_DISCOVERY
						applyclassicphase(SOD_PHASE_SIX, i(233796, {["timeline"] = { ADDED_1_15_5 }})),	-- Obsidian Destroyer
						applyclassicphase(SOD_PHASE_SIX, i(233797, {["timeline"] = { ADDED_1_15_5 }})),	-- Obsidian Stormhammer
						applyclassicphase(SOD_PHASE_FOUR, i(227886, {["timeline"] = { ADDED_1_15_3 }})),	-- Skyrider's Masterwork Stormhammer
						applyclassicphase(SOD_PHASE_FOUR, i(227881, {["timeline"] = { ADDED_1_15_3 }})),	-- Tranquility
						-- #endif
					},
				}),
				prof(17039, {	-- Master Swordsmith
					["description"] = "These items can only be crafted by Master Swordsmith specialized Weaponsmiths.",
					["groups"] = {
						i(12790, {["timeline"] = { REMOVED_6_0_2, ADDED_7_1_5 }}),	-- Arcanite Champion
						applyclassicphase(PHASE_THREE_RECIPES, i(19168)),	-- Blackguard
						i(12777, {["timeline"] = { REMOVED_4_0_3, ADDED_7_1_5 }}),	-- Blazing Rapier
						i(12782, {	-- Corruption
							-- #if SEASON_OF_DISCOVERY
							["timeline"] = { REMOVED_1_15_3 },
							-- #endif
						}),
						i(17015),	-- Dark Iron Reaver
						-- #if SEASON_OF_DISCOVERY
						applyclassicphase(SOD_PHASE_FOUR, i(227857, {["timeline"] = { ADDED_1_15_3 }})),	-- Desecration
						-- #endif
						i(12797),	-- Frostguard
						applyclassicphase(PHASE_FIVE_RECIPES, i(22383)),	-- Sageblade
						-- #if SEASON_OF_DISCOVERY
						applyclassicphase(SOD_PHASE_SIX, i(233490, {["timeline"] = { ADDED_1_15_5 }})),	-- Obsidian Champion
						applyclassicphase(SOD_PHASE_SIX, i(233798, {["timeline"] = { ADDED_1_15_5 }})),	-- Obsidian Sageblade
						-- #endif
					},
				}),
				n(WEAPONS, {
					["description"] = "These can be crafted by any Weaponsmith.",
					["groups"] = {
						applyclassicphase(PHASE_THREE_RECIPES, i(19166)),	-- Black Amnesty
						applyclassicphase(PHASE_THREE_RECIPES, i(19167)),	-- Blackfury
						i(7959, {["timeline"] = { REMOVED_4_0_3, ADDED_7_1_5 }}),	-- Blight
						i(11608),	-- Dark Iron Pulverizer
						i(11607),	-- Dark Iron Sunderer
						-- #if SEASON_OF_DISCOVERY
						applyclassicphase(SOD_PHASE_FOUR, i(227884, {["timeline"] = { ADDED_1_15_3 }})),	-- Deadly Heartseeker
						-- #endif
						i(12783, {	-- Heartseeker
							-- #if SEASON_OF_DISCOVERY
							["timeline"] = { REMOVED_1_15_3 },
							-- #endif
						}),
						-- #if SEASON_OF_DISCOVERY
						applyclassicphase(SOD_PHASE_SIX, i(234428, {["timeline"] = { ADDED_1_15_5 }})),	-- Obsidian Heartseeker
						-- #endif
						i(7961, {["timeline"] = { REMOVED_4_0_3, ADDED_4_3_0 }}),	-- Phantom Blade
						i(7954, {["timeline"] = { REMOVED_4_0_3 }}),	-- The Shatterer
						i(7960, {["timeline"] = { REMOVED_4_0_3 }}),	-- Truesilver Champion
					},
				}),
			},
		}),
		-- #endif
		n(ARMOR, {
			["groups"] = appendAllGroups(
				{
					-- #if SEASON_OF_DISCOVERY
					applyclassicphase(SOD_PHASE_THREE, i(220739, {["timeline"] = { ADDED_1_15_2 }})),	-- Baleful Pauldrons
					-- #endif
					i(7916),	-- Barbaric Iron Boots
					i(7914, {	-- Barbaric Iron Breastplate
						["requireSkill"] = BLACKSMITHING,
					}),
					i(7917),	-- Barbaric Iron Gloves
					i(7915),	-- Barbaric Iron Helm
					i(163964, {["timeline"] = { ADDED_8_0_1 }}),	-- Barbaric Iron Hauberk
					i(7913),	-- Barbaric Iron Shoulders
					i(206511, {["timeline"] = { ADDED_10_1_5 }}),	-- Belt of the Mentor
					applyclassicphase(PHASE_FIVE, i(22194, {	-- Black Grasp of the Destroyer
						-- #if SEASON_OF_DISCOVERY
						["timeline"] = { REMOVED_1_15_5 },
						-- #endif
					})),
					-- #if SEASON_OF_DISCOVERY
					applyclassicphase(SOD_PHASE_SIX, i(234086, {["timeline"] = { ADDED_1_15_5 }})),	-- Black Grasp of the Destroyer
					-- #endif
					applyclassicphase(PHASE_FOUR, i(19690, {["timeline"] = { REMOVED_4_0_3, ADDED_10_0_7 }})),	-- Bloodsoul Breastplate
					applyclassicphase(PHASE_FOUR, i(19692, {["timeline"] = { REMOVED_4_0_3, ADDED_10_0_7 }})),	-- Bloodsoul Gauntlets
					applyclassicphase(PHASE_FOUR, i(19691, {["timeline"] = { REMOVED_4_0_3, ADDED_10_0_7 }})),	-- Bloodsoul Shoulders
					i(206495, {["timeline"] = { ADDED_10_1_5 }}),	-- Bracers of Vengeance
					i(206787, {["timeline"] = { ADDED_10_1_5 }}),	-- Bucket Kickers
					i(2853),	-- Copper Bracers
					i(2851),	-- Copper Chain Belt
					i(3469),	-- Copper Chain Boots
					i(2852),	-- Copper Chain Pants
					i(3471),	-- Copper Chain Vest
					i(7166),	-- Copper Dagger
					-- #if AFTER TBC
					applyclassicphase(PHASE_FOUR_DARKIRON_RECIPES, i(20039)),	-- Dark Iron Boots
					i(17014),	-- Dark Iron Bracers
					applyclassicphase(PHASE_THREE_RECIPES, i(19164)),	-- Dark Iron Gauntlets
					applyclassicphase(PHASE_THREE_RECIPES, i(19148)),	-- Dark Iron Helm
					i(17013),	-- Dark Iron Leggings
					-- #endif
					i(11606),	-- Dark Iron Mail
					-- #if AFTER TBC
					i(11604, {	-- Dark Iron Plate
						["requireSkill"] = BLACKSMITHING,
					}),
					-- #endif
					i(11605),	-- Dark Iron Shoulders
					applyclassicphase(PHASE_FOUR, i(20550)),	-- Darkrune Breastplate
					applyclassicphase(PHASE_FOUR, i(20549)),	-- Darkrune Gauntlets
					applyclassicphase(PHASE_FOUR, i(20551)),	-- Darkrune Helm
					applyclassicphase(PHASE_FOUR, i(19693, {["timeline"] = { REMOVED_4_0_3, ADDED_10_0_7 }})),	-- Darksoul Breastplate
					applyclassicphase(PHASE_FOUR, i(19694, {["timeline"] = { REMOVED_4_0_3, ADDED_10_0_7 }})),	-- Darksoul Leggings
					applyclassicphase(PHASE_FOUR, i(19695, {["timeline"] = { REMOVED_4_0_3, ADDED_10_0_7 }})),	-- Darksoul Shoulders
					i(12625, {	-- Dawnbringer Shoulders
						["timeline"] = {
							-- #if SEASON_OF_DISCOVERY
							ADDED_1_15_3,
							-- #else
							CREATED_1_12_1, ADDED_2_0_1,
							-- #endif
						},
					}),
					-- #if AFTER TBC
					i(12628, {["timeline"] = { REMOVED_4_0_3 }}),	-- Demon Forged Breastplate
					applyclassicphase(PHASE_THREE_RECIPES, i(12618, {["timeline"] = { REMOVED_4_0_3 }})),	-- Enchanted Thorium Breastplate
					applyclassicphase(PHASE_THREE_RECIPES, i(12620, {["timeline"] = { REMOVED_4_0_3 }})),	-- Enchanted Thorium Helm
					applyclassicphase(PHASE_THREE_RECIPES, i(12619, {["timeline"] = { REMOVED_4_0_3 }})),	-- Enchanted Thorium Leggings
					-- #endif
					-- #if SEASON_OF_DISCOVERY
					applyclassicphase(SOD_PHASE_THREE, i(220740, {["timeline"] = { ADDED_1_15_2 }})),	-- Fearmonger's Shoulderguards
					-- #endif
					-- #if AFTER TBC
					i(12631, {["timeline"] = { REMOVED_4_0_3 }}),	-- Fiery Plate Gauntlets
					i(16989),	-- Fiery Chain Girdle
					i(16988),	-- Fiery Chain Shoulders
					-- #endif
					i(206508, {["timeline"] = { ADDED_10_1_5 }}),	-- Gauntlets of the Unrelenting
					i(3474),	-- Gemmed Copper Gauntlets
					applyclassicphase(PHASE_THREE_RECIPES, i(19051)),	-- Girdle of the Dawn
					applyclassicphase(PHASE_THREE_RECIPES, i(19057)),	-- Gloves of the Dawn
					-- #if SEASON_OF_DISCOVERY
					applyclassicphase(SOD_PHASE_TWO, i(217275, {["timeline"] = { ADDED_1_15_1 }})),	-- Golden Scale Boots
					i(3847, {["timeline"] = { REMOVED_1_15_1 }}),	-- Golden Scale Boots
					-- #else
					i(3847),	-- Golden Scale Boots
					-- #endif
					i(6040),	-- Golden Scale Bracers
					-- #if SEASON_OF_DISCOVERY
					applyclassicphase(SOD_PHASE_TWO, i(217279, {["timeline"] = { ADDED_1_15_1 }})),	-- Golden Scale Coif
					i(3837, {["timeline"] = { REMOVED_1_15_1 }}),	-- Golden Scale Coif
					applyclassicphase(SOD_PHASE_TWO, i(217277, {["timeline"] = { ADDED_1_15_1 }})),	-- Golden Scale Cuirass
					i(3845, {["timeline"] = { REMOVED_1_15_1 }}),	-- Golden Scale Cuirass
					applyclassicphase(SOD_PHASE_TWO, i(217273, {["timeline"] = { ADDED_1_15_1 }})),	-- Golden Scale Gauntlets
					i(9366, {["timeline"] = { REMOVED_1_15_1 }}),	-- Golden Scale Gauntlets
					applyclassicphase(SOD_PHASE_TWO, i(217285, {["timeline"] = { ADDED_1_15_1 }})),	-- Golden Scale Leggings
					i(3843, {["timeline"] = { REMOVED_1_15_1 }}),	-- Golden Scale Leggings
					applyclassicphase(SOD_PHASE_TWO, i(217283, {["timeline"] = { ADDED_1_15_1 }})),	-- Golden Scale Shoulders
					i(3841, {["timeline"] = { REMOVED_1_15_1 }}),	-- Golden Scale Shoulders
					-- #else
					i(3837),	-- Golden Scale Coif
					i(3845),	-- Golden Scale Cuirass
					i(9366, {["timeline"] = { REMOVED_4_0_3 }}),	-- Golden Scale Gauntlets
					i(3843),	-- Golden Scale Leggings
					i(3841),	-- Golden Scale Shoulders
					-- #endif
					i(3484),	-- Green Iron Boots
					i(3835),	-- Green Iron Bracers
					i(3485),	-- Green Iron Gauntlets
					i(3844),	-- Green Iron Hauberk
					i(3836),	-- Green Iron Helm
					i(3842),	-- Green Iron Leggings
					i(3840),	-- Green Iron Shoulders
					i(203817, {["timeline"] = { ADDED_10_0_7 }}),	-- Gurubashi Headplate
					i(7933),	-- Heavy Mithril Boots
					i(7930),	-- Heavy Mithril Breastplate
					i(7919),	-- Heavy Mithril Gauntlet
					i(7934),	-- Heavy Mithril Helm
					i(7921),	-- Heavy Mithril Pants
					i(7918),	-- Heavy Mithril Shoulder
					applyclassicphase(PHASE_FIVE, i(22197)),	-- Heavy Obsidian Belt
					applyclassicphase(PHASE_THREE_RECIPES, i(19043)),	-- Heavy Timbermaw Belt
					applyclassicphase(PHASE_THREE_RECIPES, i(19048)),	-- Heavy Timbermaw Boots
					-- #if AFTER TBC
					i(12636),	-- Helm of the Great Chief
					-- #endif
				},
				sharedData({
					-- #if AFTER 10.1.5
					["description"] = "Icebellow Anvil can be found on the right side of the second room of the Military Quarter in Naxxramas."
					-- #endif
				}, {
					applyclassicphase(PHASE_SIX, i(22671, {["timeline"] = { ADDED_1_11_1, REMOVED_3_0_2, ADDED_10_1_5 }})),	-- Icebane Bracers
					applyclassicphase(PHASE_SIX, i(22669, {["timeline"] = { ADDED_1_11_1, REMOVED_3_0_2, ADDED_10_1_5 }})),	-- Icebane Breastplate
					i(206444, {["timeline"] = { ADDED_10_1_5 }}),	-- Icebane Coif
					applyclassicphase(PHASE_SIX, i(22670, {["timeline"] = { ADDED_1_11_1, REMOVED_3_0_2, ADDED_10_1_5 }})),	-- Icebane Gauntlets
					i(206442, {["timeline"] = { ADDED_10_1_5 }}),	-- Icebane Leggings
					i(206443, {["timeline"] = { ADDED_10_1_5 }}),	-- Icebane Mantle
					i(206446, {["timeline"] = { ADDED_10_1_5 }}),	-- Icebane Trudgers
					i(206445, {["timeline"] = { ADDED_10_1_5 }}),	-- Icebane Waistguard
				}),
				{
					i(12424),	-- Imperial Plate Belt
					i(12426),	-- Imperial Plate Boots
					i(12425),	-- Imperial Plate Bracers
					i(12422),	-- Imperial Plate Chest
					i(12427),	-- Imperial Plate Helm
					i(12429),	-- Imperial Plate Leggings
					i(12428),	-- Imperial Plate Shoulders
					-- #if AFTER TBC
					i(12641),	-- Invulnerable Mail
					-- #endif
					applyclassicphase(PHASE_FIVE_CATCH_UP, i(22764)),	-- Ironvine Belt
					applyclassicphase(PHASE_FIVE_CATCH_UP, i(22762)),	-- Ironvine Breastplate
					applyclassicphase(PHASE_FIVE_CATCH_UP, i(22763)),	-- Ironvine Gloves
					applyclassicphase(PHASE_FIVE, i(22195)),	-- Light Obsidian Belt
					-- #if AFTER TBC
					i(12640),	-- Lionheart Helm
					-- #endif
					-- #if SEASON_OF_DISCOVERY
					applyclassicphase(SOD_PHASE_ONE, i(210773, {["timeline"] = { ADDED_1_15_0 }})),	-- Mantle of the Second War
					-- #endif
					i(7931),	-- Mithril Coif
					i(7924),	-- Mithril Scale Bracers
					i(7920),	-- Mithril Scale Pants
					i(7932),	-- Mithril Scale Shoulders
					applyclassicphase(PHASE_FIVE, i(22191, {	-- Obsidian Mail Tunic
						-- #if SEASON_OF_DISCOVERY
						["timeline"] = { REMOVED_1_15_5 },
						-- #endif
					})),
					-- #if SEASON_OF_DISCOVERY
					applyclassicphase(SOD_PHASE_SIX, i(234460, {["timeline"] = { ADDED_1_15_5 }})),	-- Obsidian Mail Tunic
					-- #endif
					i(7929, {["timeline"] = { REMOVED_4_0_3 }}),	-- Orcish War Leggings
					i(7936, {["timeline"] = { REMOVED_4_0_3 }}),	-- Ornate Mithril Boots
					i(7935, {["timeline"] = { REMOVED_4_0_3 }}),	-- Ornate Mithril Breastplate
					i(7927, {["timeline"] = { REMOVED_4_0_3 }}),	-- Ornate Mithril Gloves
					i(7937, {["timeline"] = { REMOVED_4_0_3 }}),	-- Ornate Mithril Helm
					i(7926, {["timeline"] = { REMOVED_4_0_3 }}),	-- Ornate Mithril Pants
					i(7928, {["timeline"] = { REMOVED_4_0_3 }}),	-- Ornate Mithril Shoulder
					i(2868),	-- Patterned Bronze Bracers
					i(206498, {["timeline"] = { ADDED_10_1_5 }}),	-- Plated Construct's Ribcage
					i(3846),	-- Polished Steel Boots
					i(12416),	-- Radiant Belt
					i(12419),	-- Radiant Boots
					i(12415),	-- Radiant Breastplate
					i(12417),	-- Radiant Circlet
					i(12418),	-- Radiant Gloves
					i(12420),	-- Radiant Leggings
					-- #if SEASON_OF_DISCOVERY
					applyclassicphase(SOD_PHASE_TWO, i(215167, {["timeline"] = { ADDED_1_15_1 }})),	-- Reflective Truesilver Braincage
					-- #endif
					i(6350),	-- Rough Bronze Boots
					i(2866),	-- Rough Bronze Cuirass
					i(2865),	-- Rough Bronze Leggings
					i(3480),	-- Rough Bronze Shoulders
					i(10421),	-- Rough Copper Vest
					i(2857),	-- Runed Copper Belt
					i(2854),	-- Runed Copper Bracers
					i(2864),	-- Runed Copper Breastplate
					i(3472),	-- Runed Copper Gauntlets
					i(3473),	-- Runed Copper Pants
					i(12611),	-- Runic Plate Boots
					i(12613, {["timeline"] = { ADDED_1_11_1, REMOVED_4_0_3, ADDED_10_1_7 }}),	-- Runic Breastplate
					i(12612),	-- Runic Plate Helm
					i(12614),	-- Runic Plate Leggings
					i(12610),	-- Runic Plate Shoulders
					-- #if SEASON_OF_DISCOVERY
					applyclassicphase(SOD_PHASE_SEVEN, i(238288, { ["timeline"] = { ADDED_1_15_6 }})),	-- Scarlet Soldier's Helmet
					applyclassicphase(SOD_PHASE_SEVEN, i(238289, { ["timeline"] = { ADDED_1_15_6 }})),	-- Scarlet Soldier's Spaulders
					applyclassicphase(SOD_PHASE_SEVEN, i(238290, { ["timeline"] = { ADDED_1_15_6 }})),	-- Scarlet Soldier's Chestplate
					applyclassicphase(SOD_PHASE_SEVEN, i(238291, { ["timeline"] = { ADDED_1_15_6 }})),	-- Scarlet Soldier's Protectors
					applyclassicphase(SOD_PHASE_SEVEN, i(238292, { ["timeline"] = { ADDED_1_15_6 }})),	-- Scarlet Soldier's Grips
					applyclassicphase(SOD_PHASE_SEVEN, i(238293, { ["timeline"] = { ADDED_1_15_6 }})),	-- Scarlet Soldier's Waistguard
					applyclassicphase(SOD_PHASE_SEVEN, i(238294, { ["timeline"] = { ADDED_1_15_6 }})),	-- Scarlet Soldier's Legplates
					applyclassicphase(SOD_PHASE_SEVEN, i(238295, { ["timeline"] = { ADDED_1_15_6 }})),	-- Scarlet Soldier's Stompers
					applyclassicphase(SOD_PHASE_ONE, i(210794, {["timeline"] = { ADDED_1_15_0 }})),	-- Shifting Silver Breastplate
					-- #endif
					i(2870),	-- Shining Silver Breastplate
					-- #if SEASON_OF_DISCOVERY
					applyclassicphase(SOD_PHASE_THREE, i(220738, {["timeline"] = { ADDED_1_15_2 }})),	-- Shoulderplates of Dread
					-- #endif
					i(3482),	-- Silvered Bronze Boots
					i(2869),	-- Silvered Bronze Breastplate
					i(3483),	-- Silvered Bronze Gauntlets
					i(10423),	-- Silvered Bronze Leggings
					i(3481),	-- Silvered Bronze Shoulders
					i(7963),	-- Steel Breastplate
					i(7922),	-- Steel Plate Helm
					-- #if AFTER TBC
					i(12632),	-- Storm Gauntlets
					i(12639),	-- Stronghold Gauntlets
					-- #endif
					-- #if SEASON_OF_DISCOVERY
					applyclassicphase(SOD_PHASE_TWO, i(215161, {["timeline"] = { ADDED_1_15_1 }})),	-- Tempered Interference-Negating Helmet
					-- #endif
					applyclassicphase(PHASE_FIVE, i(22196, {	-- Thick Obsidian Breastplate
						-- #if SEASON_OF_DISCOVERY
						["timeline"] = { REMOVED_1_15_5 },
						-- #endif
					})),
					-- #if SEASON_OF_DISCOVERY
					applyclassicphase(SOD_PHASE_SIX, i(235040, {["timeline"] = { ADDED_1_15_5 }})),	-- Thick Obsidian Breastplate
					-- #endif
					i(12405),	-- Thorium Armor
					i(12406),	-- Thorium Belt
					i(12409),	-- Thorium Boots
					i(12408),	-- Thorium Bracers
					i(12410),	-- Thorium Helm
					i(12414),	-- Thorium Leggings
					-- #if AFTER TBC
					applyclassicphase(PHASE_FIVE, i(22385)),	-- Titanic Leggings
					i(7939, {["timeline"] = { REMOVED_4_0_3 }}),	-- Truesilver Breastplate
					i(7938, {["timeline"] = { REMOVED_4_0_3 }}),	-- Truesilver Gauntlets
					i(12633),	-- Whitesoul Helm
					i(12624),	-- Wildthorn Mail
					-- #endif
				}
			),
		}),
		n(DECOR, sharedDataSelf({["timeline"] = { ADDED_11_2_7 }}, {
			i(246111),	-- Shadowforge Sconce (DECOR!)
			i(246489),	-- Steel Ironforge Emblem (DECOR!)
		})),
		filter(MISC, {
			i(15872),	-- Arcanite Skeleton Key
			-- #if SEASON_OF_DISCOVERY
			applyclassicphase(SOD_PHASE_ONE, i(211845, {["timeline"] = { ADDED_1_15_0 }})),	-- Blackfathom Sharpening Stone
			-- #endif
			i(3478),	-- Coarse Grinding Stone
			i(2863),	-- Coarse Sharpening Stone
			i(3240),	-- Coarse Weightstone
			i(12644),	-- Dense Grinding Stone
			i(12404),	-- Dense Sharpening Stone
			i(12643),	-- Dense Weightstone
			i(18262),	-- Elemental Sharpening Stone
			i(15870),	-- Golden Skeleton Key
			i(3486),	-- Heavy Grinding Stone
			i(2871),	-- Heavy Sharpening Stone
			i(3241),	-- Heavy Weightstone
			i(6043),	-- Iron Counterweight
			i(6042),	-- Iron Shield Spike
			i(7967),	-- Mithril Shield Spike
			i(7969),	-- Mithril Spurs
			-- #if SEASON_OF_DISCOVERY
			applyclassicphase(SOD_PHASE_SIX, i(234004, {["timeline"] = { ADDED_1_15_5 }})),	-- Obsidian Grinding Stone
			-- #endif
			i(3470),	-- Rough Grinding Stone
			i(2862),	-- Rough Sharpening Stone
			i(3239),	-- Rough Weightstone
			i(15869),	-- Silver Skeleton Key
			i(7966),	-- Solid Grinding Stone
			i(7964),	-- Solid Sharpening Stone
			i(7965),	-- Solid Weightstone
			i(6041),	-- Steel Weapon Chain
			i(12645),	-- Thorium Shield Spike
			i(15871),	-- Truesilver Skeleton Key
		}),
		filter(REAGENTS, {
			i(16206, {["timeline"] = { REMOVED_5_0_4 }}),	-- Arcanite Rod
			i(11128, {["timeline"] = { REMOVED_5_0_4 }}),	-- Golden Rod
			i(9060),	-- Inlaid Mithril Cylinder
			i(7071),	-- Iron Buckle
			-- #if SEASON_OF_DISCOVERY
			applyclassicphase(SOD_PHASE_TWO, i(213376, {["timeline"] = { ADDED_1_15_1 }})),	-- Low-Background Truesilver Plates
			-- #endif
			i(6338, {["timeline"] = { REMOVED_5_0_4 }}),	-- Silver Rod
			i(11144, {["timeline"] = { REMOVED_5_0_4 }}),	-- Truesilver Rod
			i(206648, {["timeline"] = { ADDED_10_1_5 }}),	-- Undeath Metal
		}),
		n(WEAPONS, {
			-- #if AFTER TBC
			i(12798),	-- Annihilator
			i(12790, {["timeline"] = { REMOVED_6_0_2, ADDED_7_1_5 }}),	-- Arcanite Champion
			i(12784),	-- Arcanite Reaper
			-- #endif
			i(206493, {["timeline"] = { ADDED_10_1_5 }}),	-- Axe of Sundered Bone
			i(7945),	-- Big Black Mace
			i(3848),	-- Big Bronze Knife
			-- #if AFTER TBC
			applyclassicphase(PHASE_THREE_RECIPES, i(19166)),	-- Black Amnesty
			applyclassicphase(PHASE_THREE_RECIPES, i(19167)),	-- Blackfury
			applyclassicphase(PHASE_THREE_RECIPES, i(19168)),	-- Blackguard
			-- #endif
			i(206492, {["timeline"] = { ADDED_10_1_5 }}),	-- Blade of Unholy Might
			i(206499, {["timeline"] = { ADDED_10_1_5 }}),	-- Blade of the Fallen Seraph
			-- #if AFTER TBC
			i(12777, {["timeline"] = { REMOVED_4_0_3, ADDED_7_1_5 }}),	-- Blazing Rapier
			-- #endif
			i(12769, {["timeline"] = { CREATED_1_11_0, ADDED_7_1_5 }}),	-- Bleakwood Hew
			-- #if AFTER TBC
			i(7959, {["timeline"] = { REMOVED_4_0_3, ADDED_7_1_5 }}),	-- Blight
			-- #endif
			i(203790, {["timeline"] = { ADDED_10_0_7 }}),	-- Bloodherald
			i(203793, {["timeline"] = { ADDED_10_0_7 }}),	-- Bloodlord's Reaver
			i(7942),	-- Blue Glittering Axe
			i(2849),	-- Bronze Axe
			i(7958),	-- Bronze Battle Axe
			i(7957),	-- Bronze Greatsword
			i(2848),	-- Bronze Mace
			i(2850),	-- Bronze Shortsword
			i(7956),	-- Bronze Warhammer
			i(2845),	-- Copper Axe
			i(3488),	-- Copper Battle Axe
			i(7955),	-- Copper Claymore
			i(2844),	-- Copper Mace
			i(2847),	-- Copper Shortsword
			-- #if AFTER TBC
			i(12782, {	-- Corruption
				["requireSkill"] = BLACKSMITHING,
			}),
			i(17016),	-- Dark Iron Destroyer
			i(11608),	-- Dark Iron Pulverizer
			i(17015),	-- Dark Iron Reaver
			i(11607),	-- Dark Iron Sunderer
			-- #endif
			i(12802, {["timeline"] = { CREATED_1_11_0, ADDED_7_1_5 }}),	-- Darkspear
			i(206478, {["timeline"] = { ADDED_10_1_5 }}),	-- Darrowdirk
			i(206479, {["timeline"] = { ADDED_10_1_5 }}),	-- Darrowshire Protector
			i(206506, {["timeline"] = { ADDED_10_1_5 }}),	-- Dawn of Demise
			-- #if AFTER TBC
			i(12774, {["timeline"] = { REMOVED_4_0_3, ADDED_7_1_5 }}),	-- Dawn's Edge
			-- #endif
			i(7944),	-- Dazzling Mithril Rapier
			i(3490),	-- Deadly Bronze Poniard
			i(206510, {["timeline"] = { ADDED_10_1_5 }}),	-- Death's Gamble
			-- #if AFTER TBC
			applyclassicphase(PHASE_THREE_RECIPES, i(19170)),	-- Ebon Hand
			-- #endif
			i(7947),	-- Ebon Shiv
			i(17704),	-- Edge of Winter
			i(206490, {["timeline"] = { ADDED_10_1_5 }}),	-- Edict of the Redeemed Crusader
			-- #if AFTER TBC
			i(12776, {["timeline"] = { REMOVED_4_0_3 }}),	-- Enchanted Battlehammer
			-- #endif
			applyclassicphase(TBC_PHASE_ONE, i(29203, {["timeline"] = { ADDED_2_0_5, REMOVED_5_0_4 }})),	-- Enchanted Thorium Blades
			i(203813, {["timeline"] = { ADDED_10_0_7 }}),	-- Fiery Vengeance
			i(3854),	-- Frost Tiger Blade
			-- #if AFTER TBC
			i(12797),	-- Frostguard
			-- #endif
			i(12259),	-- Glinting Steel Dagger
			i(3852),	-- Golden Iron Destroyer
			i(203810, {["timeline"] = { ADDED_10_0_7 }}),	-- Gurubashi Carver
			i(203806, {["timeline"] = { ADDED_10_0_7 }}),	-- Gurubashi Crusher
			i(203809, {["timeline"] = { ADDED_10_0_7 }}),	-- Gurubashi Grinder
			i(203797, {["timeline"] = { ADDED_10_0_7 }}),	-- Gurubashi HexXxer
			i(203812, {["timeline"] = { ADDED_10_0_7 }}),	-- Gurubashi Poker
			i(203801, {["timeline"] = { ADDED_10_0_7 }}),	-- Gurubashi Slicer
			-- #if AFTER TBC
			i(12796),	-- Hammer of the Titans
			-- #endif
			i(206503, {["timeline"] = { ADDED_10_1_5 }}),	-- Harbinger of Death
			i(3849),	-- Hardened Iron Shortsword
			-- #if AFTER TBC
			i(12783),	-- Heartseeker
			-- #endif
			i(3491),	-- Heavy Bronze Mace
			i(3487),	-- Heavy Copper Broadsword
			applyclassicphase(TBC_PHASE_ONE, i(33791, {["timeline"] = { ADDED_2_3_0 }})),	-- Heavy Copper Longsword
			i(6214),	-- Heavy Copper Maul
			i(7941),	-- Heavy Mithril Axe
			i(12775),	-- Huge Thorium Battleaxe
			i(207561, {["timeline"] = { ADDED_10_1_5 }}),	-- Ichor Slicer
			i(207555, {["timeline"] = { ADDED_10_1_5 }}),	-- Intrepid Shortblade
			i(5541),	-- Iridescent Hammer
			i(6731),	-- Ironforge Breastplate
			i(3850),	-- Jade Serpentblade
			applyclassicphase(PHASE_FIVE, i(22198, {	-- Jagged Obsidian Shield
				-- #if SEASON_OF_DISCOVERY
				["timeline"] = { REMOVED_1_15_5 },
				-- #endif
			})),
			-- #if SEASON_OF_DISCOVERY
			applyclassicphase(SOD_PHASE_SIX, i(234459, {["timeline"] = { ADDED_1_15_5 }})),	-- Jagged Obsidian Shield
			-- #endif
			-- #if AFTER CATA
			i(30071, {["timeline"] = { ADDED_2_0_5, REMOVED_4_0_3, ADDED_7_1_5 }}),	-- Light Earthforged Blade
			-- #endif
			i(3855),	-- Massive Iron Axe
			-- #if AFTER TBC
			i(12794, {["timeline"] = { REMOVED_6_0_2, ADDED_10_1_5 }}),	-- Masterwork Stormhammer
			-- #endif
			i(206486, {["timeline"] = { ADDED_10_1_5 }}),	-- Midnight's Graze
			i(3492),	-- Mighty Iron Hammer
			i(206480, {["timeline"] = { ADDED_10_1_5 }}),	-- Mirah's Lullaby
			-- #if SEASON_OF_DISCOVERY
			applyclassicphase(SOD_PHASE_TWO, i(217281, {["timeline"] = { ADDED_1_15_1 }})),	-- Moonsteel Broadsword
			-- #endif
			i(3853),	-- Moonsteel Broadsword
			-- #if AFTER TBC
			applyclassicphase(PHASE_THREE_RECIPES, i(19169)),	-- Nightfall
			-- #endif
			i(12773, {	-- Ornate Thorium Handaxe
				["requireSkill"] = BLACKSMITHING,
			}),
			-- #if AFTER TBC
			applyclassicphase(PHASE_FIVE_RECIPES, i(22384)),	-- Persuader
			i(7961, {["timeline"] = { REMOVED_4_0_3, ADDED_4_3_0 }}),	-- Phantom Blade
			-- #endif
			i(203811, {["timeline"] = { ADDED_10_0_7 }}),	-- Pitchfork of Madness
			i(5540),	-- Pearl-handled Dagger
			i(7946),	-- Runed Mithril Hammer
			i(207560, {["timeline"] = { ADDED_10_1_5 }}),	-- Sacred Guardian
			-- #if AFTER TBC
			applyclassicphase(PHASE_FIVE_RECIPES, i(22383)),	-- Sageblade
			-- #endif
			i(12260),	-- Searing Golden Blade
			-- #if AFTER TBC
			i(12781),	-- Serenity
			-- #endif
			i(203804, {["timeline"] = { ADDED_10_0_7 }}),	-- Sceptre of Hexing
			i(206489, {["timeline"] = { ADDED_10_1_5 }}),	-- Shade's Blade
			i(3856),	-- Shadow Crescent Axe
			i(3851),	-- Solid Iron Maul
			i(206484, {["timeline"] = { ADDED_10_1_5 }}),	-- Strength of Menethil
			-- #if SEASON_OF_DISCOVERY
			applyclassicphase(SOD_PHASE_FOUR, i(227684, {["timeline"] = { ADDED_1_15_3 }})),	-- Sulfuron Hammer
			-- #endif
			i(17193, {	-- Sulfuron Hammer
				-- #if SEASON_OF_DISCOVERY
				["timeline"] = { REMOVED_1_15_3 },
				-- #endif
			}),
			i(206513, {["timeline"] = { ADDED_10_1_5 }}),	-- Stygian Shield
			i(206502, {["timeline"] = { ADDED_10_1_5 }}),	-- The Face of Doom
			i(206497, {["timeline"] = { ADDED_10_1_5 }}),	-- The Final Dream
			i(206494, {["timeline"] = { ADDED_10_1_5 }}),	-- The Plague Belcher
			-- #if AFTER TBC
			i(7954, {["timeline"] = { REMOVED_4_0_3, ADDED_10_1_5 }}),	-- The Shatterer
			-- #endif
			applyclassicphase(TBC_PHASE_ONE, i(29201, {["timeline"] = { ADDED_2_0_5, REMOVED_5_0_4 }})),	-- Thick Bronze Darts
			i(3489),	-- Thick War Axe
			-- #if AFTER TBC
			i(7960, {["timeline"] = { REMOVED_4_0_3, ADDED_10_1_5 }}),	-- Truesilver Champion
			-- #endif
			i(207556, {["timeline"] = { ADDED_10_1_5 }}),	-- Valiant Shortblade
			i(203802, {["timeline"] = { ADDED_10_0_7 }}),	-- Venomfang
			i(203860, {["timeline"] = { ADDED_10_0_7 }}),	-- Venomreaver
			i(12792, {["timeline"] = { REMOVED_4_0_3, ADDED_10_1_7 }}),	-- Volcanic Hammer NOTE: This had a 7.3.5 removed tag, but I don't trust posters on WoWHead sometimes and this is one of those times where I'll go with my gut and say "PROVE IT" when Cataclysm comes around.
			i(207011, {["timeline"] = { ADDED_10_1_5 }}),	-- Warblades of the Hakkari, Reborn
			i(203791, {["timeline"] = { ADDED_10_0_7 }}),	-- Warblades of the Hakkari, Reborn (MH)
			i(203792, {["timeline"] = { ADDED_10_0_7 }}),	-- Warblades of the Hakkari, Reborn (OH)
			i(206477, {["timeline"] = { ADDED_10_1_5 }}),	-- Warsword of Caer Darrow
			i(206487, {["timeline"] = { ADDED_10_1_5 }}),	-- Weaver's Fang
			applyclassicphase(TBC_PHASE_ONE, i(29202, {["timeline"] = { ADDED_2_0_5, REMOVED_5_0_4 }})),	-- Whirling Steel Axes
			i(7943),	-- Wicked Mithril Blade
			i(206488, {["timeline"] = { ADDED_10_1_5 }}),	-- Widow's Weep
		}),
	}),
	prof(COOKING, {
		n(COMMON_VENDOR_ITEMS, {
			["groups"] = appendAllGroups(
				sharedData({	-- Vanilla cooking reagents
					["description"] = "Can be bought from Cooking Suppliers, as well as some Trade vendors around the world.",
				}, {
					i(159),	-- Refreshing Spring Water
					i(30817, {["timeline"] = { ADDED_2_0_1 }}),	-- Simple Flour
					i(2678),	-- Mild Spices
					i(2692, {["timeline"] = { REMOVED_3_0_2 }}),	-- Hot Spices
					i(3713, {["timeline"] = { REMOVED_3_0_2 }}),	-- Soothing Spices
				}),
				sharedData({
					-- #if AFTER CATA
					["description"] = "This item is only common among Alliance bartenders. Horde players only have a few sources.",
					-- #endif
					["providers"] = {
						{ "n", 1328 },	-- Elly Langston <Barmaid>
						-- #if AFTER TBC
						{ "n", 16442 },	-- Vinemaster Suntouched <Wine & Spirits Merchant>
						-- #endif
					},
				}, {
					i(2594),	-- Flagon of Dwarven Honeymead/Mead
					i(2593),	-- Flask of Stormwind Tawny
					i(2595),	-- Jug of Badlands Bourbon
					i(2596),	-- Skin of Dwarven Stout
				}),
				{
					i(1179, {	-- Ice Cold Milk
						["description"] = "Can be bought from bartenders, innkeepers and general goods vendors.",
					}),
				}
			),
		}),
		i(13935),	-- Baked Salmon
		i(4457),	-- Barbecued Buzzard Wing
		applyclassicphase(TBC_PHASE_ONE, i(27636, {["timeline"] = { ADDED_2_0_5 }})),	-- Bat Bites
		i(2888),	-- Beer Basted Boar Ribs
		i(3726, {["timeline"] = { REMOVED_4_0_3, ADDED_9_1_0 }}),	-- Big Bear Steak
		i(3220),	-- Blood Sausage
		i(5525),	-- Boiled Clams
		applyclassicphase(WRATH_PHASE_ONE, i(46691, {	-- Bread of the Dead [Day of the Dead]
			["description"] = "Ghostly Cooking Fire can be found near any graveyards with Day of the Dead-festivities.",
			["timeline"] = { ADDED_3_2_2 },
		})),
		i(6290),	-- Brilliant Smallfish
		i(4593),	-- Bristle Whisker Catfish
		applyclassicphase(WRATH_PHASE_ONE, i(44839, {["timeline"] = { ADDED_3_2_2 }})),	-- Candied Sweet Potato [Pilgrim's Bounty]
		applyclassicphase(TBC_PHASE_ONE, i(34832, {["timeline"] = { ADDED_2_4_0 }})),	-- Captain Rumsey's Lager
		i(12213),	-- Carrion Surprise
		applyclassicphase(TBC_PHASE_ONE, i(35563, {["timeline"] = { ADDED_2_4_0 }})),	-- Charred Bear Kabobs
		i(2679),	-- Charred Wolf Meat
		i(5526),	-- Clam Chowder
		applyclassicphase(WRATH_PHASE_ONE, i(33004, {["timeline"] = { ADDED_3_1_0 }})),	-- Clamlette Magnifique
		i(2682),	-- Cooked Crab Claw
		i(13927),	-- Cooked Glossy Mightfish
		i(2684),	-- Coyote Steak
		i(2683),	-- Crab Cake
		applyclassicphase(WRATH_PHASE_ONE, i(44840, {["timeline"] = { ADDED_3_2_2 }})),	-- Cranberry Chutney [Pilgrim's Bounty]
		i(12224),	-- Crispy Bat Wing
		i(5479),	-- Crispy Lizard Tail
		i(3664),	-- Crocolisk Gumbo
		i(3662),	-- Crocolisk Steak
		applyclassicphase(TBC_PHASE_ONE, i(22645, {["timeline"] = { ADDED_2_0_5 }})),	-- Crunchy Spider Surprise
		i(3665),	-- Curiously Tasty Omelet
		applyclassicphase(TBC_PHASE_ONE, i(33924, {["timeline"] = { ADDED_2_3_0 }})),	-- Delicious Chocolate Cake
		i(5478),	-- Dig Rat Stew
		applyclassicphase(PHASE_FIVE, i(21023, {["timeline"] = { REMOVED_4_0_3 }})),	-- Dirge's Kickin' Chimaerok Chops
		i(12217),	-- Dragonbreath Chili
		i(2687),	-- Dry Pork Ribs
		-- #if BEFORE 5.4.1
		i(17198),	-- Egg Nog / Winter Veil Egg Nog[5.4.1+]
		-- #endif
		i(184690, {["timeline"] = { ADDED_9_0_2_LAUNCH }}),	-- Extra Fancy Darkmoon Feast
		i(184682, {["timeline"] = { ADDED_9_0_2_LAUNCH }}),	-- Extra Lemony Herb Filet
		i(184624, {["timeline"] = { ADDED_9_0_2_LAUNCH }}),	-- Extra Sugary Fish Feast
		applyclassicphase(WOD_PHASE_ONE, i(126935, {["timeline"] = { ADDED_6_2_0 }})),	-- Fancy Darkmoon Feast
		i(13930),	-- Filet of Redgill
		i(5476),	-- Fillet of Frenzy
		i(6038),	-- Giant Clam Scorcho
		i(17197),	-- Gingerbread Cookie
		i(5527),	-- Goblin Deviled Clams
		i(10841, {["timeline"] = { REMOVED_6_0_2, ADDED_10_0_0 }}),	-- Goldthorn Tea
		i(3666),	-- Gooey Spider Cake
		i(724),	-- Goretusk Liver Pie
		i(13928),	-- Grilled Squid
		i(20074),	-- Heavy Crocolisk Stew
		i(12215),	-- Heavy Kodo Stew
		i(6888),	-- Herb Baked Egg
		applyclassicphase(TBC_PHASE_ONE, i(34411, {["timeline"] = { ADDED_2_3_0 }})),	-- Hot Apple Cider
		i(3727),	-- Hot Lion Chops
		i(13929),	-- Hot Smoked Bass
		i(13851),	-- Hot Wolf Ribs
		applyclassicphase(TBC_PHASE_ONE, i(35565, {["timeline"] = { ADDED_2_4_0 }})),	-- Juicy Bear Burger
		i(12212),	-- Jungle Stew
		i(5472),	-- Kaldorei Spider Kabob
		i(5480, {["timeline"] = { REMOVED_4_0_3, ADDED_9_1_0 }}),	-- Lean Venison
		i(12209, {["timeline"] = {REMOVED_5_0_4, ADDED_9_1_0}}),	-- Lean Wolf Steak
		applyclassicphase(WOD_PHASE_ONE, i(126934, {["timeline"] = { ADDED_6_2_0 }})),	-- Lemon Herb Filet
		i(13933),	-- Lobster Stew
		i(6316),	-- Loch Frenzy Delight
		i(4592),	-- Longjaw Mud Snapper
		applyclassicphase(TBC_PHASE_ONE, i(27635, {["timeline"] = { ADDED_2_0_5 }})),	-- Lynx Steak
		i(13934),	-- Mightfish Steak
		i(8364),	-- Mithril Head Trout
		i(12218),	-- Monster Omelet
		i(3663),	-- Murloc Fin Soup
		i(12214),	-- Mystery Stew
		i(13931),	-- Nightfin Soup
		i(13932),	-- Poached Sunscale Salmon
		applyclassicphase(WRATH_PHASE_ONE, i(44836, {["timeline"] = { ADDED_3_2_2 }})),	-- Pumpkin Pie [Pilgrim's Bounty]
		i(5095),	-- Rainbow Fin Albacore
		i(1082),	-- Redridge Goulash
		i(12210),	-- Roast Raptor
		i(2681),	-- Roasted Boar Meat
		i(5474),	-- Roasted Kodo Meat
		applyclassicphase(TBC_PHASE_ONE, i(24105, {["timeline"] = { ADDED_2_0_5 }})),	-- Roasted Moongraze Tenderloin
		i(4594),	-- Rockscale Cod
		applyclassicphase(PHASE_ONE_DIREMAUL, i(18254)),	-- Runn Tum Tuber Surprise
		i(21217),	-- Sagefish Delight
		i(6657),	-- Savory Deviate Delight
		i(5473),	-- Scorpid Surprise
		i(1017),	-- Seasoned Wolf Kabob
		i(787),	-- Slitherskin Mackerel
		applyclassicphase(WRATH_PHASE_ONE, i(44838, {["timeline"] = { ADDED_3_2_2 }})),	-- Slow-Roasted Turkey [Pilgrim's Bounty]
		i(6890),	-- Smoked Bear Meat
		applyclassicphase(PHASE_THREE_SILITHUS_EXPEDITION_QUESTS, i(20452)),	-- Smoked Desert Dumplings
		i(21072),	-- Smoked Sagefish
		i(3729),	-- Soothing Turtle Bisque
		applyclassicphase(TBC_PHASE_ONE, i(30816, {["timeline"] = { ADDED_2_0_5 }})),	-- Spice Bread
		applyclassicphase(WRATH_PHASE_ONE, i(44837, {["timeline"] = { ADDED_3_2_2 }})),	-- Spice Bread Stuffing [Pilgrim's Bounty]
		i(12216),	-- Spiced Chili Crab
		i(2680),	-- Spiced Wolf Meat
		i(17222),	-- Spider Sausage
		i(6887),	-- Spotted Yellowtail
		i(5477),	-- Strider Stew
		i(2685),	-- Succulent Pork Ribs
		applyclassicphase(WOD_PHASE_ONE, i(126936, {["timeline"] = { ADDED_6_2_0 }})),	-- Sugar-Crusted Fish Feast
		i(3728),	-- Tasty Lion Steak
		i(18045),	-- Tender Wolf Steak
		i(7676, {["timeline"] = {REMOVED_6_0_2, ADDED_7_1_0}}),	-- Thistle Tea
		i(16766),	-- Undermine Clam Chowder
		applyclassicphase(CATA_PHASE_ONE, i(67230, {["timeline"] = { ADDED_4_0_3 }})),	-- Venison Jerky
		i(733),	-- Westfall Stew
		-- #if AFTER 5.4.1
		i(17198),	-- Winter Veil Egg Nog[5.4.1+] / Egg Nog
		-- #endif
	}),
	prof(ENCHANTING, {
		n(COMMON_VENDOR_ITEMS, {
			["groups"] = appendAllGroups(
				sharedData({	-- Enchanting supplies
					["description"] = "Can be bought from Enchanting Suppliers, as well as some Trade vendors around the world.",
					-- Danny Donkey: Disabling this for now, Common Vendor Items is being filled into Minilists when coords/providers are given.
					--[[["coords"] = {
						{ 60.8, 44.2, MAP.IRONFORGE },
						{ 44.9, 37.7, MAP.THUNDER_BLUFF },
						{ 62.0, 60.8, MAP.UNDERCITY },
						{ 43.0, 64.2, MAP.STORMWIND_CITY },
						{ 58.6, 14.7, MAP.DARNASSUS },
						{ 53.6, 38.0, MAP.ORGRIMMAR },
					},
					["providers"] = {
						{ "n", 1318},	-- Jessara Cordell <Enchanting Supplies>
						{ "n", 3346},	-- Kithas <Enchanting Supplies>
						{ "n", 3012},	-- Nata Dawnstrider <Enchanting Supplies>
						{ "n", 4617},	-- Thaddeus Webb <Enchanting Supplies>
						{ "n", 5158},	-- Tilli Thistlefuzz <Enchanting Supplies>
						{ "n", 4228},	-- Vaean <Enchanting Supplies>
					},]]
				},{
					i(4470),	-- Simple Wood
					i(11291),	-- Star Wood
					-- #if AFTER CATA
					i(38682),	-- Enchanting Vellum
					-- #endif
				}),
				sharedData({	-- Runed Copper Rod reagents
					-- Danny Donkey:	This structure is used for Vanilla content as well as BFA and onwards when professions
					-- 					are split on an expansion-basis, but one still need to craft and use this basic rod.
					-- Danny Donkey: Disabling this for now, Common Vendor Items is being filled into Minilists when coords/providers are given.
					--[[["coords"] = {
						{ 60.8, 44.2, MAP.IRONFORGE },
						{ 44.9, 37.7, MAP.THUNDER_BLUFF },
						{ 62.0, 60.8, MAP.UNDERCITY },
						{ 43.0, 64.2, MAP.STORMWIND_CITY },
						{ 58.6, 14.7, MAP.DARNASSUS },
						{ 53.6, 38.0, MAP.ORGRIMMAR },
					},
					["providers"] = {
						{ "n", 1318},	-- Jessara Cordell <Enchanting Supplies>
						{ "n", 3346},	-- Kithas <Enchanting Supplies>
						{ "n", 3012},	-- Nata Dawnstrider <Enchanting Supplies>
						{ "n", 4617},	-- Thaddeus Webb <Enchanting Supplies>
						{ "n", 5158},	-- Tilli Thistlefuzz <Enchanting Supplies>
						{ "n", 4228},	-- Vaean <Enchanting Supplies>
					},]]
				},{
					i(6217, {	-- Copper Rod
						["description"] = "Can be bought from Enchanting Suppliers, as well as some Trade vendors around the world.",
					}),
					i(10938, { ["isLimited"] = true, }),	-- Lesser Magic Essence
					i(10940, { ["isLimited"] = true, }),	-- Strange Dust
				})
			)
		}),
		header(HEADERS.Spell, 13262, {	-- Disenchant
			-- Danny Donkey: We need ilvl data from WoD and BfA stat squishes.
			-- Dust:
			i(11176, {	-- Dream Dust (removed in retail)
				["timeline"] = { REMOVED_7_3_5 },
				-- #if BEFORE WOD
				["description"] = "Obtained from disenchanting uncommon (green) quality garments, amulets and rings within the ilvl bracket 46-55.",
				-- #endif
			}),
			i(16204, {	-- Legion+: Light Illusion Dust / CLASSIC: Illusion Dust
				-- #if AFTER 9.0.1
				["description"] = "Obtained from disenchanting uncommon (green) quality gear below max unscaled ilvl.",
				-- #elseif BEFORE WOD
				["description"] = "Obtained from disenchanting uncommon (green) quality garments, amulets and rings within the ilvl bracket 56-65.",
				-- #endif
			}),
			i(156930, {	-- Rich Illusion Dust
				["timeline"] = { ADDED_7_3_5 },
				-- #if AFTER 9.0.1
				["description"] = "Obtained from disenchanting uncommon (green) and rare (blue) qualities of vanilla gear.",
				-- #endif
			}),
			i(11083, {	-- Soul Dust (removed in retail)
				["timeline"] = { REMOVED_7_3_5 },
				-- #if BEFORE WOD
				["description"] = "Obtained from disenchanting uncommon (green) quality garments, amulets, rings, shields and off-hand frills within the ilvl bracket 26-35.",
				-- #endif
			}),
			i(10940, {	-- Strange Dust
				-- #if AFTER 9.0.1
				["description"] = "Obtained from disenchanting very low ilvl vanilla gear, or bought from enchanting suppliers.",
				-- #elseif BEFORE WOD
				["description"] = "Obtained from disenchanting uncommon (green) quality garments, amulets, rings, shields and off-hand frills within the ilvl bracket 10-25.",
				-- #endif
			}),
			i(11137, {	-- Vision Dust (removed in retail)
				["timeline"] = { REMOVED_7_3_5 },
				-- #if BEFORE WOD
				["description"] = "Obtained from disenchanting uncommon (green) quality garments, amulets, rings, shields and off-hand frills within the ilvl bracket 36-45.",
				-- #endif
			}),
			-- Essences:
			i(11082, {	-- Greater Astral Essence (removed in retail)
				["timeline"] = { REMOVED_7_3_5 },
				-- #if BEFORE WOD
				["description"] = "Obtained from disenchanting uncommon (green) quality garments, amulets, rings, shields and off-hand frills within the ilvl bracket 26-30.",
				-- #endif
			}),
			i(10998, {	-- Lesser Astral Essence (removed in retail)
				["timeline"] = { REMOVED_7_3_5 },
				-- #if BEFORE WOD
				["description"] = "Obtained from disenchanting uncommon (green) quality garments, amulets, rings, shields and off-hand frills within the ilvl bracket 21-25.",
				-- #endif
			}),
			i(16203, {	-- Greater Eternal Essence
				-- #if AFTER 9.0.1
				["description"] = "Obtained from disenchanting uncommon (green) and rare (blue) qualities of vanilla gear.",
				-- #elseif BEFORE WOD
				["description"] = "Obtained from disenchanting uncommon (green) quality weapons within the ilvl bracket 56-65, except shields and off-hand frills.",
				-- #endif
			}),
			i(16202, {	-- Lesser Eternal Essence
				-- #if AFTER 9.0.1
				["description"] = "Obtained from disenchanting uncommon (green) and rare (blue) qualities of vanilla gear.",
				-- #elseif BEFORE WOD
				["description"] = "Obtained from disenchanting all uncommon (green) quality gear within the ilvl bracket 51-55.",
				-- #endif
			}),
			i(10939, {	-- Greater Magic Essence
				-- #if AFTER 9.0.1
				["description"] = "Obtained from disenchanting uncommon (green) and rare (blue) qualities of vanilla gear below max unscaled ilvl. You can also buy Lesser Magic Essences from enchanting suppliers and use them to create Greater Magic Essence.",
				-- #elseif BEFORE WOD
				["description"] = "Obtained from disenchanting uncommon (green) quality weapons within the ilvl bracket 16-30, except shields and off-hand frills.",
				-- #endif
			}),
			i(10938, {	-- Lesser Magic Essence
				-- #if AFTER 9.0.1
				["description"] = "Obtained from disenchanting uncommon (green) and rare (blue) qualities of vanilla gear below max unscaled ilvl. You can also buy these from enchanting suppliers.",
				-- #elseif BEFORE WOD
				["description"] = "Obtained from disenchanting uncommon (green) quality weapons within the ilvl bracket 11-15, except shields and off-hand frills.",
				-- #endif
			}),
			i(11135, {	-- Greater Mystic Essence (removed in retail)
				["timeline"] = { REMOVED_7_3_5 },
				-- #if BEFORE WOD
				["description"] = "Obtained from disenchanting all uncommon (green) quality gear within the ilvl bracket 36-40.",
				-- #endif
			}),
			i(11134, {	-- Lesser Mystic Essence (removed in retail)
				["timeline"] = { REMOVED_7_3_5 },
				-- #if BEFORE WOD
				["description"] = "Obtained from disenchanting all uncommon (green) quality gear within the ilvl bracket 31-35.",
				-- #endif
			}),
			i(11175, {	-- Greater Nether Essence (removed in retail)
				["timeline"] = { REMOVED_7_3_5 },
				-- #if BEFORE WOD
				["description"] = "Obtained from disenchanting all uncommon (green) quality gear within the ilvl bracket 46-50.",
				-- #endif
			}),
			i(11174, {	-- Lesser Nether Essence (removed in retail)
				["timeline"] = { REMOVED_7_3_5 },
				-- #if BEFORE WOD
				["description"] = "Obtained from disenchanting all uncommon (green) quality gear within the ilvl bracket 41-45.",
				-- #endif
			}),
			-- Shards and crystals:
			i(14344, {	-- Large Brilliant Shard
				-- #if AFTER 9.0.1
				["description"] = "Obtained from disenchanting all rare (blue) and epic (purple) quality vanilla gear.",
				-- #elseif BEFORE WOD
				["description"] = "Obtained from disenchanting all rare (blue) quality gear within the ilvl bracket 56-71.",
				-- #endif
			}),
			i(14343, {	-- Small Brilliant Shard
				-- #if AFTER 9.0.1
				["description"] = "Obtained from disenchanting all rare (blue) and epic (purple) quality vanilla gear below max unscaled ilvl.",
				-- #elseif BEFORE WOD
				["description"] = "Obtained from disenchanting all rare (blue) and epic (purple) quality gear within the ilvl bracket 51-55.",
				-- #endif
			}),
			i(11084, {	-- Large Glimmering Shard (removed in retail)
				["timeline"] = { REMOVED_7_3_5 },
				-- #if BEFORE WOD
				["description"] = "Obtained from disenchanting all rare (blue) quality gear within the ilvl bracket 26-30.",
				-- #endif
			}),
			i(10978, {	-- Small Glimmering Shard (removed in retail)
				["timeline"] = { REMOVED_7_3_5 },
				-- #if BEFORE WOD
				["description"] = "Obtained from disenchanting all rare (blue) quality gear within the ilvl bracket 20-25.",
				-- #endif
			}),
			i(11139, {	-- Large Glowing Shard (removed in retail)
				["timeline"] = { REMOVED_7_3_5 },
				-- #if BEFORE WOD
				["description"] = "Obtained from disenchanting all rare (blue) quality gear within the ilvl bracket 36-40.",
				-- #endif
			}),
			i(11138, {	-- Small Glowing Shard (removed in retail)
				["timeline"] = { REMOVED_7_3_5 },
				-- #if BEFORE WOD
				["description"] = "Obtained from disenchanting all rare (blue) quality gear within the ilvl bracket 31-35.",
				-- #endif
			}),
			applyclassicphase(PHASE_FIVE, i(20725, {	-- Nexus Crystal (removed in retail)
				["timeline"] = { REMOVED_7_3_5 },
				-- #if BEFORE WOD
				["description"] = "Obtained from disenchanting all epic (purple) quality gear within the ilvl bracket 60-83.",
				-- #endif
			})),
			i(11178, {	-- Large Radiant Shard (removed in retail)
				["timeline"] = { REMOVED_7_3_5 },
				-- #if BEFORE WOD
				["description"] = "Obtained from disenchanting all rare (blue) and epic (purple) quality gear within the ilvl bracket 46-50.",
				-- #endif
			}),
			i(11177, {	-- Small Radiant Shard (removed in retail)
				["timeline"] = { REMOVED_7_3_5 },
				-- #if BEFORE WOD
				["description"] = "Obtained from disenchanting all rare (blue) and epic (purple) quality gear within the ilvl bracket 41-45.",
				-- #endif
			}),
		}),
		applyclassicphase(WRATH_PHASE_ONE, n(ARMOR_ENCHANTMENTS, sharedDataSelf({ ["timeline"] = { ADDED_3_0_2 } }, {
			i(38844),	-- Enchant Boots - Agility
			i(38863),	-- Enchant Boots - Greater Agility
			i(38862),	-- Enchant Boots - Greater Stamina
			i(45628, {["timeline"] = { ADDED_3_1_0 }}),	-- Enchant Boots - Lesser Accuracy
			i(38807),	-- Enchant Boots - Lesser Agility
			i(38810),	-- Enchant Boots - Lesser Stamina
			i(38819),	-- Enchant Boots - Lesser Versatility / WRATH: Enchant Boots - Lesser Spirit
			i(38786),	-- Enchant Boots - Minor Agility
			i(38837),	-- Enchant Boots - Minor Speed
			i(38785),	-- Enchant Boots - Minor Stamina
			i(38830),	-- Enchant Boots - Stamina
			i(38864),	-- Enchant Boots - Versatility / WRATH: Enchant Boots - Spirit
			i(38881),	-- Enchant Bracer - Argent Versatility / WRATH: Enchant Bracer - Mana Regeneration
			i(38842),	-- Enchant Bracer - Dodge
			i(38852),	-- Enchant Bracer - Greater Intellect
			i(38849),	-- Enchant Bracer - Greater Stamina
			i(38846),	-- Enchant Bracer - Greater Strength
			i(38832),	-- Enchant Bracer - Greater Versatility / WRATH: Enchant Bracer - Greater Spirit
			i(38882),	-- Enchant Bracer - Healing Power
			i(38829),	-- Enchant Bracer - Intellect
			i(38811),	-- Enchant Bracer - Lesser Dodge / WRATH: Enchant Bracer - Lesser Deflection
			i(38803),	-- Enchant Bracer - Lesser Intellect
			i(38793),	-- Enchant Bracer - Lesser Stamina
			i(38797),	-- Enchant Bracer - Lesser Strength
			i(38783),	-- Enchant Bracer - Lesser Versatility / WRATH: Enchant Bracer - Lesser Spirit
			i(38777),	-- Enchant Bracer - Minor Agility
			i(38768),	-- Enchant Bracer - Minor Dodge / WRATH: Enchant Bracer - Minor Deflection
			i(38679),	-- Enchant Bracer - Minor Health
			i(38771),	-- Enchant Bracer - Minor Stamina
			i(38778),	-- Enchant Bracer - Minor Strength
			i(38774),	-- Enchant Bracer - Minor Versatility / WRATH: Enchant Bracer - Minor Spirit
			i(38812),	-- Enchant Bracer - Stamina
			i(38817),	-- Enchant Bracer - Strength
			i(38855),	-- Enchant Bracer - Superior Stamina
			i(38854),	-- Enchant Bracer - Superior Strength
			i(38853),	-- Enchant Bracer - Superior Versatility / WRATH: Enchant Bracer - Superior Spirit
			i(38809),	-- Enchant Bracer - Versatility / WRATH: Enchant Bracer - Spirit
			i(38808),	-- Enchant Chest - Greater Health
			i(38818),	-- Enchant Chest - Greater Mana
			i(38865),	-- Enchant Chest - Greater Stats
			i(38782),	-- Enchant Chest - Health
			i(38798),	-- Enchant Chest - Lesser Absorption
			i(38773),	-- Enchant Chest - Lesser Health
			i(38776),	-- Enchant Chest - Lesser Mana
			i(38824),	-- Enchant Chest - Lesser Stats
			i(38866),	-- Enchant Chest - Major Health
			i(38867),	-- Enchant Chest - Major Mana
			i(38799),	-- Enchant Chest - Mana
			i(38767),	-- Enchant Chest - Minor Absorption
			i(38766),	-- Enchant Chest - Minor Health
			i(38769),	-- Enchant Chest - Minor Mana
			i(38804),	-- Enchant Chest - Minor Stats
			i(38847),	-- Enchant Chest - Stats
			i(38833),	-- Enchant Chest - Superior Health
			i(38841),	-- Enchant Chest - Superior Mana
			i(38806),	-- Enchant Cloak - Defense
			-- #if BEFORE BFA
			i(38895),	-- Enchant Cloak - Dodge
			-- #endif
			i(38815, {["timeline"] = { ADDED_3_0_2, REMOVED_5_0_4 }}),	-- Enchant Cloak - Fire Resistance
			i(38825),	-- Enchant Cloak - Greater Defense
			i(38891, {["timeline"] = { ADDED_3_0_2, REMOVED_5_0_4 }}),	-- Enchant Cloak - Greater Fire Resistance
			i(38892, {["timeline"] = { ADDED_3_0_2, REMOVED_5_0_4 }}),	-- Enchant Cloak - Greater Nature Resistance
			i(38858, {["timeline"] = { ADDED_3_0_2, REMOVED_5_0_4 }}),	-- Enchant Cloak - Greater Resistance
			i(38835, {["timeline"] = { ADDED_3_0_2, REMOVED_4_0_3, ADDED_4_2_0 }}),	-- Enchant Cloak - Lesser Agility
			i(38784, {["timeline"] = { ADDED_3_0_2, REMOVED_5_0_4 }}),	-- Enchant Cloak - Lesser Fire Resistance
			i(38790),	-- Enchant Cloak - Lesser Protection
			i(38795, {["timeline"] = { ADDED_3_0_2, REMOVED_5_0_4 }}),	-- Enchant Cloak - Lesser Shadow Resistance
			i(38789),	-- Enchant Cloak - Minor Agility
			i(38775),	-- Enchant Cloak - Minor Protection
			i(38770, {["timeline"] = { ADDED_3_0_2, REMOVED_5_0_4 }}),	-- Enchant Cloak - Minor Resistance
			i(38826, {["timeline"] = { ADDED_3_0_2, REMOVED_5_0_4 }}),	-- Enchant Cloak - Resistance
			-- #if BEFORE BFA
			i(38893),	-- Enchant Cloak - Stealth
			i(38894),	-- Enchant Cloak - Subtlety
			-- #endif
			i(38859),	-- Enchant Cloak - Superior Defense
			i(38834, {["timeline"] = { ADDED_3_0_2, REMOVED_4_0_3 }}),	-- Enchant Gloves - Advanced Herbalism
			i(38831),	-- Enchant Gloves - Advanced Mining
			i(38827),	-- Enchant Gloves - Agility
			i(38888),	-- Enchant Gloves - Fire Power
			i(38802),	-- Enchant Gloves - Fishing
			i(38887),	-- Enchant Gloves - Frost Power
			i(38856),	-- Enchant Gloves - Greater Agility
			i(38857),	-- Enchant Gloves - Greater Strength
			i(38889),	-- Enchant Gloves - Healing Power
			i(38801),	-- Enchant Gloves - Herbalism
			i(38800, {["timeline"] = { REMOVED_4_0_3, ADDED_6_1_0 }}),	-- Enchant Gloves - Mining
			i(38851),	-- Enchant Gloves - Minor Haste
			i(38850),	-- Enchant Gloves - Riding Skill
			i(38886),	-- Enchant Gloves - Shadow Power
			i(38823),	-- Enchant Gloves - Skinning
			i(38836),	-- Enchant Gloves - Strength
			-- #if BEFORE BFA
			i(38890),	-- Enchant Gloves - Superior Agility
			i(38885),	-- Enchant Gloves - Threat
			-- #endif
		}))),
		n(DECOR, sharedDataSelf({["timeline"] = { ADDED_11_2_7 }}, {
			i(263027),	-- Darkmaster's Mystical Brazier (DECOR!)
			i(253250),	-- Tirisfal Hollow Campfire (DECOR!)
		})),
		filter(ILLUSIONS, bubbleDownSelf({ ["timeline"] = { ADDED_7_0_3 } }, {
			i(138787, {	-- Tome of Illusions: Azeroth
				ill(803),	-- Fiery Weapon (ILLUSION!)
				ill(1899),	-- Unholy Weapon (ILLUSION!)
				ill(5863),	-- Coldlight (ILLUSION!)
			}),
		})),
		filter(MISC, {
			-- #if SEASON_OF_DISCOVERY
			applyclassicphase(SOD_PHASE_ONE, i(211848, {["timeline"] = { ADDED_1_15_0 }})),	-- Blackfathom Mana Oil
			-- #endif
			applyclassicphase(PHASE_FIVE, i(20748, {["timeline"] = { REMOVED_4_0_3 }})),	-- Brilliant Mana Oil / 10.0.7: Expired Mana Oil
			applyclassicphase(PHASE_FIVE, i(20749, {["timeline"] = { REMOVED_4_0_3 }})),	-- Brilliant Wizard Oil / 10.0.7: Expired Wizard Oil
			applyclassicphase(PHASE_FIVE, i(203862, {["timeline"] = { ADDED_10_0_7 }})),	-- Brilliant Mana Oil
			applyclassicphase(PHASE_FIVE, i(203865, {["timeline"] = { ADDED_10_0_7 }})),	-- Brilliant Wizard Oil
			-- #if SEASON_OF_DISCOVERY
			applyclassicphase(SOD_PHASE_FOUR, i(228980, {["timeline"] = { ADDED_1_15_3 }})),	-- Conductive Shield Coating
			-- #endif
			i(12810),	-- Enchanted Leather
			-- #if SEASON_OF_DISCOVERY
			applyclassicphase(SOD_PHASE_SIX, i(233996, {["timeline"] = { ADDED_1_15_5 }})),	-- Enchanted Repellent
			applyclassicphase(SOD_PHASE_TWO, i(217308, {["timeline"] = { ADDED_1_15_1 }})),	-- Enchanted Sigil: Innovation
			applyclassicphase(SOD_PHASE_THREE, i(221028, {["timeline"] = { ADDED_1_15_2 }})),	-- Enchanted Sigil: Living Dreams
			-- #endif
			i(12655),	-- Enchanted Thorium Bar
			applyclassicphase(PHASE_FIVE_RECIPES, i(20747)),	-- Lesser Mana Oil
			applyclassicphase(PHASE_FIVE_RECIPES, i(20746)),	-- Lesser Wizard Oil
			-- #if SEASON_OF_DISCOVERY
			applyclassicphase(SOD_PHASE_SIX, i(232611, {["timeline"] = { ADDED_1_15_5 }})),	-- Magnificent Trollshine
			-- #endif
			applyclassicphase(PHASE_FIVE, i(20745)),	-- Minor Mana Oil
			applyclassicphase(PHASE_FIVE, i(20744)),	-- Minor Wizard Oil
			-- #if SEASON_OF_DISCOVERY
			applyclassicphase(SOD_PHASE_THREE, i(220792, {["timeline"] = { ADDED_1_15_2 }})),	-- Scroll of Spatial Mending
			applyclassicphase(SOD_PHASE_SIX, i(233995, {["timeline"] = { ADDED_1_15_5 }})),	-- Scroll: Wrath of the Swarm
			-- #endif
			applyclassicphase(PHASE_FIVE, i(20750)),	-- Wizard Oil
		}),
		filter(PROFESSION_EQUIPMENT, {
			i(16207, {["timeline"] = { REMOVED_5_0_4 }}),	-- Runed Arcanite Rod
			i(6218),	-- Runed Copper Rod
			i(11130, {["timeline"] = { REMOVED_5_0_4 }}),	-- Runed Gold Rod
			i(6339, {["timeline"] = { REMOVED_5_0_4 }}),	-- Runed Silver Rod
			i(11145, {["timeline"] = { REMOVED_5_0_4 }}),	-- Runed Truesilver Rod
		}),
		-- #if SEASON_OF_DISCOVERY
		filter(RELICS_F, {
			applyclassicphase(SOD_PHASE_SIX, i(234002, {["timeline"] = { ADDED_1_15_5 }})),	-- Enchanted Mushroom
			applyclassicphase(SOD_PHASE_SIX, i(234000, {["timeline"] = { ADDED_1_15_5 }})),	-- Enchanted Prayer Tome
			applyclassicphase(SOD_PHASE_SIX, i(234001, {["timeline"] = { ADDED_1_15_5 }})),	-- Enchanted Totem
			applyclassicphase(SOD_PHASE_SIX, i(234469, {["timeline"] = { ADDED_1_15_5 }})),	-- Idol of Feline Ferocity
			applyclassicphase(SOD_PHASE_SIX, i(234474, {["timeline"] = { ADDED_1_15_5 }})),	-- Idol of Sidereal Wrath
			applyclassicphase(SOD_PHASE_SIX, i(234468, {["timeline"] = { ADDED_1_15_5 }})),	-- Idol of Ursin Power
			applyclassicphase(SOD_PHASE_SIX, i(234475, {["timeline"] = { ADDED_1_15_5 }})),	-- Libram of the Exorcist
			applyclassicphase(SOD_PHASE_SIX, i(234476, {["timeline"] = { ADDED_1_15_5 }})),	-- Libram of Sanctity
			applyclassicphase(SOD_PHASE_SIX, i(234477, {["timeline"] = { ADDED_1_15_5 }})),	-- Libram of Righteousness
			applyclassicphase(SOD_PHASE_SIX, i(234479, {["timeline"] = { ADDED_1_15_5 }})),	-- Totem of Flowing Magma
			applyclassicphase(SOD_PHASE_SIX, i(234480, {["timeline"] = { ADDED_1_15_5 }})),	-- Totem of Pyroclastic Thunder
			applyclassicphase(SOD_PHASE_SIX, i(234478, {["timeline"] = { ADDED_1_15_5 }})),	-- Totem of Thunderous Strikes
		}),
		-- #endif
		filter(TRINKET_F, {
			-- #if SEASON_OF_DISCOVERY
			applyclassicphase(SOD_PHASE_SIX, i(233993, {["timeline"] = { ADDED_1_15_5 }})),	-- Enchanted Stopwatch
			applyclassicphase(SOD_PHASE_SIX, i(233992, {["timeline"] = { ADDED_1_15_5 }})),	-- Lodestone of Retaliation
			applyclassicphase(SOD_PHASE_SIX, i(233994, {["timeline"] = { ADDED_1_15_5 }})),	-- Ruby-Encrusted Broach
			-- #endif
			i(11811),	-- Smoking Heart of the Mountain
			-- #if SEASON_OF_DISCOVERY
			applyclassicphase(SOD_PHASE_SIX, i(233990, {["timeline"] = { ADDED_1_15_5 }})),	-- Speedstone
			applyclassicphase(SOD_PHASE_SIX, i(233991, {["timeline"] = { ADDED_1_15_5 }})),	-- Tear of the Dreamer
			-- #endif
		}),
		applyclassicphase(WRATH_PHASE_ONE, n(WEAPON_ENCHANTMENTS, sharedDataSelf({ ["timeline"] = { ADDED_3_0_2 } }, {
			i(38843, {["timeline"] = { ADDED_3_0_2, REMOVED_5_0_4 }}),	-- Enchant Shield - Frost Resistance
			i(38861),	-- Enchant Shield - Greater Stamina
			i(38839),	-- Enchant Shield - Greater Versatility / WRATH: Enchant Shield - Greater Spirit
			i(38820),	-- Enchant Shield - Lesser Parry / WRATH: Enchant Shield - Lesser Block
			i(38791),	-- Enchant Shield - Lesser Protection
			i(38805),	-- Enchant Shield - Lesser Stamina
			i(38792),	-- Enchant Shield - Lesser Versatility / WRATH: Enchant Shield - Lesser Spirit
			i(38787),	-- Enchant Shield - Minor Stamina
			i(38828),	-- Enchant Shield - Stamina
			i(38816),	-- Enchant Shield - Versatility / WRATH: Enchant Shield - Spirit
			i(38860),	-- Enchant Shield - Vitality / WRATH: Enchant Shield - Superior Spirit
			i(38880),	-- Enchant Weapon - Agility
			i(38896),	-- Enchant 2H Weapon - Agility
			i(38873),	-- Enchant Weapon - Crusader
			i(38840),	-- Enchant Weapon - Demonslaying
			i(38838),	-- Enchant Weapon - Fiery Weapon
			i(38845),	-- Enchant 2H Weapon - Greater Impact
			i(38848),	-- Enchant Weapon - Greater Striking
			i(38878),	-- Enchant Weapon - Healing Power
			i(38868),	-- Enchant Weapon - Icy Chill
			i(38822),	-- Enchant 2H Weapon - Impact
			i(38813),	-- Enchant Weapon - Lesser Beastslayer
			i(38814),	-- Enchant Weapon - Lesser Elemental Slayer
			i(38796),	-- Enchant 2H Weapon - Lesser Impact
			i(38781),	-- Enchant 2H Weapon - Lesser Intellect
			i(38794),	-- Enchant Weapon - Lesser Striking
			i(38788),	-- Enchant 2H Weapon - Lesser Versatility / WRATH: Enchant 2H Weapon - Lesser Spirit
			i(38871, {["timeline"] = {ADDED_3_0_2, REMOVED_4_0_3, ADDED_10_1_5}}),	-- Enchant Weapon - Lifestealing
			i(38875),	-- Enchant 2H Weapon - Major Intellect
			i(38874),	-- Enchant 2H Weapon - Major Versatility / WRATH: Enchant 2H Weapon - Major Spirit
			i(38884),	-- Enchant Weapon - Mighty Intellect
			i(38883),	-- Enchant Weapon - Mighty Versatility / WRATH: Enchant Weapon - Mighty Spirit
			i(38779),	-- Enchant Weapon - Minor Beastslayer
			i(38772),	-- Enchant 2H Weapon - Minor Impact
			i(38780),	-- Enchant Weapon - Minor Striking
			i(38877),	-- Enchant Weapon - Spellpower
			i(38879),	-- Enchant Weapon - Strength
			i(38821),	-- Enchant Weapon - Striking
			i(38869, {["timeline"] = {ADDED_3_0_2, REMOVED_6_0_2}}),	-- Enchant 2H Weapon - Superior Impact
			i(38870),	-- Enchant Weapon - Superior Striking
			i(38872),	-- Enchant Weapon - Unholy Weapon
			i(38876),	-- Enchant Weapon - Winter's Might
		}))),
		n(WEAPONS, {
			i(11288),	-- Greater Magic Wand
			-- #if SEASON_OF_DISCOVERY
			applyclassicphase(SOD_PHASE_TWO, i(217287, {["timeline"] = { ADDED_1_15_1 }})),	-- Greater Mystic Wand
			-- #endif
			i(11290),	-- Greater Mystic Wand
			i(11287),	-- Lesser Magic Wand
			i(11289),	-- Lesser Mystic Wand
			i(207557, {["timeline"] = { ADDED_10_1_5 }}),	-- Magebane Nexus
			i(203808, {["timeline"] = { ADDED_10_0_7 }}),	-- Mindslave's Reach
			i(207558, {["timeline"] = { ADDED_10_1_5 }}),	-- Smoked Fireshooter
			i(207559, {["timeline"] = { ADDED_10_1_5 }}),	-- Stormwatcher
		}),
	}),
	prof(ENGINEERING, {
		n(COMMON_VENDOR_ITEMS, sharedData({
			["description"] = "Can be bought from Engineering Suppliers, as well as some Trade vendors around the world.",
			-- Danny Donkey: Disabling this for now, Common Vendor Items is being filled into Minilists when coords are given.
			--[[["description"] = "Can be bought from Engineering Suppliers, as well as some Trade vendors around the world. Coordinates are for select vendors.",
			["coords"] = {
				{ 67.8, 43.0, MAP.IRONFORGE },
				{ 75.5, 74.3, MAP.UNDERCITY },
				{ 55.0, 7.0, MAP.STORMWIND_CITY },
				{ 75.6, 25.2, MAP.ORGRIMMAR },
			},
			["providers"] = {
				{ "n", 5519},	-- Billibub Cogspinner <Engineering Supplies>
				{ "n", 4587},	-- Elizabeth Van Talen <Engineering Supplies>
				{ "n", 5175},	-- Gearcutter Cogspinner <Engineering Supplies>
				{ "n", 3413},	-- Sovik <Engineering Supplies>
			},]]
		}, {
			i(4400),	-- Heavy Stock
			i(4399),	-- Wooden Stock
		})),
		prof(GNOMISH_ENGINEERING, {
			["description"] = "These items can only be crafted by Engineers who have completed the Gnomish Engineering quest chain.",
			["groups"] = {
				n(ARMOR, {
					i(10545, {	-- Gnomish Goggles
					-- #IF BEFORE 10.1.0
						["requireSkill"] = GNOMISH_ENGINEERING,	-- (BOP - Required)
					-- #ENDIF
					}),
				}),
				-- #if BEFORE WRATH
				filter(BATTLE_PETS, {
					i(11826, {	-- Lil' Smoky (PET!)
						["requireSkill"] = GNOMISH_ENGINEERING,	-- (BOP - Required, until Wrath)
					}),
				}),
				-- #endif
				filter(MISC, {
					i(18645),	-- Gnomish Alarm-o-Bot
					i(10725, {	-- Gnomish Battle Chicken
						["requireSkill"] = GNOMISH_ENGINEERING,	-- (BOP - Required)
					}),
					i(10645, {	-- Gnomish Death Ray
						["requireSkill"] = GNOMISH_ENGINEERING,	-- (BOP - Required)
					}),
					i(10721),	-- Gnomish Harm Prevention Belt
					i(10726),	-- Gnomish Mind Control Cap
					i(10720),	-- Gnomish Net-o-Matic Projector
					i(10724),	-- Gnomish Rocket Boots
					i(10716),	-- Gnomish Shrink Ray
				}),
				filter(RECIPES, {
					i(10713, {	-- Plans: Inlaid Mithril Cylinder (RECIPE!)
						["description"] = "This recipe is crafted by Gnomish Engineers and given to Blacksmiths to learn so that the Blacksmith can craft the item needed by the Engineer.\n\nIf you are missing this recipe, ask a Gnomish Engineer to craft it for you.",
					}),
				}),
				filter(TOYS, {
					i(18986, {	-- Ultrasafe Transporter: Gadgetzan (TOY!)
						["requireSkill"] = GNOMISH_ENGINEERING,	-- (BOP - Required)
					}),
					i(18660, {	-- World Enlarger (TOY!)
						["requireSkill"] = GNOMISH_ENGINEERING,	-- (BOP - Required)
					}),
				}),
			},
		}),
		prof(GOBLIN_ENGINEERING, {
			["description"] = "These items can only be crafted by Engineers who have completed the Goblin Engineering quest chain.",
			["groups"] = {
				-- #if BEFORE WRATH
				filter(BATTLE_PETS, {
					i(11825, {	-- Pet Bombling (PET!)
						["requireSkill"] = GOBLIN_ENGINEERING,	-- (BOP - Required, until Wrath)
					}),
				}),
				-- #endif
				filter(MISC, {
					i(10587, {	-- Goblin Bomb Dispenser
						["requireSkill"] = GOBLIN_ENGINEERING,	-- (BOP - Required)
					}),
					i(10543, {	-- Goblin Construction Helmet
						["requireSkill"] = GOBLIN_ENGINEERING,	-- (BOP - Required)
					}),
					i(10727, {	-- Goblin Dragon Gun
						["requireSkill"] = GOBLIN_ENGINEERING,	-- (BOP - Required)
					}),
					i(18587),	-- Goblin Jumper Cables XL
					i(10542, {	-- Goblin Mining Helmet
						["requireSkill"] = GOBLIN_ENGINEERING,	-- (BOP - Required)
					}),
					i(10577),	-- Goblin Mortar
					i(7189),	-- Goblin Rocket Boots
					i(10588),	-- Goblin Rocket Helmet
					i(10646),	-- Goblin Sapper Charge
					i(10586),	-- The Big One
				}),
				filter(RECIPES, {
					i(10644, {	-- Recipe: Goblin Rocket Fuel (RECIPE!)
						["description"] = "This recipe is crafted by Goblin Engineers and given to Alchemists to learn so that the Alchemist can craft the item needed by the Engineer.\n\nIf you are missing this recipe, ask a Goblin Engineer to craft it for you.",
					}),
				}),
				filter(TOYS, {
					i(18984, {	-- Dimensional Ripper - Everlook (TOY!)
						["requireSkill"] = GOBLIN_ENGINEERING,	-- (BOP - Required)
					}),
				}),
			},
		}),
		n(ARMOR, {
			applyclassicphase(PHASE_FOUR, i(19999, {["timeline"] = { REMOVED_4_0_3, ADDED_10_0_7 }})),	-- Bloodvine Goggles
			applyclassicphase(PHASE_FOUR, i(19998, {["timeline"] = { REMOVED_4_0_3, ADDED_10_0_7 }})),	-- Bloodvine Lens
			i(10499),	-- Bright-Eye Goggles
			i(10501),	-- Catseye Ultra Goggles
			i(4393),	-- Craftsman's Monocle
			i(10506, {["timeline"] = { REMOVED_4_0_3, ADDED_4_1_0 }}),	-- Deepdive Helmet
			i(10500),	-- Fire Goggles
			i(4368),	-- Flying Tiger Goggles
			i(10504),	-- Green Lens
			i(4385),	-- Green Tinted Goggles
			-- #if SEASON_OF_DISCOVERY
			applyclassicphase(SOD_PHASE_TWO, i(215115, {	-- Hyperconductive Goldwrap
				["timeline"] = { ADDED_1_15_1 },
			})),
			-- #endif
			i(16008),	-- Master Engineer's Goggles
			i(10503),	-- Rose Colored Goggles
			i(4373),	-- Shadow Goggles
			i(10502),	-- Spellpower Goggles Xtreme
			i(15999),	-- Spellpower Goggles Xtreme Plus
			-- #if SEASON_OF_DISCOVERY
			applyclassicphase(SOD_PHASE_THREE, i(221025, {	-- Void-Powered Invoker's Vambraces
				["timeline"] = { ADDED_1_15_2 },
			})),
			applyclassicphase(SOD_PHASE_THREE, i(221027, {	-- Void-Powered Protector's Vambraces
				["timeline"] = { ADDED_1_15_2 },
			})),
			applyclassicphase(SOD_PHASE_THREE, i(221026, {	-- Void-Powered Slayer's Vambraces
				["timeline"] = { ADDED_1_15_2 },
			})),
			-- #endif
		}),
		filter(BATTLE_PETS, {
			i(15996),	-- Lifelike Toad (PET!)
			-- #if AFTER WRATH
			i(11826),	-- Lil' Smoky (PET!)
			-- #endif
			i(4401),	-- Mechanical Squirrel (PET!)
			-- #if AFTER WRATH
			i(11825),	-- Pet Bombling (PET!)
			-- #endif
			i(21277, {["timeline"] = {REMOVED_4_0_3, ADDED_10_0_2}}),	-- Tranquil Mechanical Yeti (PET!)
		}),
		n(DECOR, sharedDataSelf({["timeline"] = { ADDED_11_2_7 }}, {
			i(246410),	-- Dark Iron Table Saw (DECOR!)
			i(246700),	-- Gnomish Steam-Powered Bed (DECOR!)
		})),
		filter(MISC, {
			i(4392),	-- Advanced Target Dummy
			i(6533),	-- Aquadynamic Fish Attractor
			i(16040),	-- Arcane Bomb
			-- #if SEASON_OF_DISCOVERY
			applyclassicphase(SOD_PHASE_SIX, i(233987, { ["timeline"] = { ADDED_1_15_5 }, })),	-- Arcane Mega Bomb
			-- #endif
			i(4380),	-- Big Bronze Bomb
			i(4394),	-- Big Iron Bomb
			i(9312),	-- Blue Firework
			i(21571),	-- Blue Rocket Cluster
			i(6712),	-- Clockwork Box[4.3.0+] / Classic: Practice Lock
			i(21570),	-- Cluster Launcher
			i(4365),	-- Coarse Dynamite
			i(4391),	-- Compact Harvest Reaper Kit
			i(8068, {["timeline"] = { REMOVED_4_0_1 }}),	-- Crafted Heavy Shot
			i(8067, {["timeline"] = { REMOVED_4_0_1 }}),	-- Crafted Light Shot
			i(8069, {["timeline"] = { REMOVED_4_0_1 }}),	-- Crafted Solid Shot
			i(16005),	-- Dark Iron Bomb
			i(18641),	-- Dense Dynamite
			i(4388),	-- Discombobulator Ray
			i(4384),	-- Explosive Sheep
			i(6714),	-- EZ-Thro Dynamite
			i(18588),	-- EZ-Thro Dynamite II
			-- #if SEASON_OF_DISCOVERY
			applyclassicphase(SOD_PHASE_TWO, i(215168, {	-- Ez-Thro Radiation Bomb
				["timeline"] = { ADDED_1_15_1 },
			})),
			-- #endif
			i(18232),	-- Field Repair Bot 74A
			i(21569),	-- Firework Launcher
			i(4376),	-- Flame Deflector
			i(4852),	-- Flash Bomb
			-- #if SEASON_OF_DISCOVERY
			applyclassicphase(SOD_PHASE_SIX, i(233987, { ["timeline"] = { ADDED_1_15_5 }, })),	-- G00 DV-1B3 Generator
			-- #endif
			i(4397),	-- Gnomish Cloaking Device
			i(7506),	-- Gnomish Universal Remote
			i(7148),	-- Goblin Jumper Cables
			i(4395),	-- Goblin Land Mine
			i(9313),	-- Green Firework
			i(21574),	-- Green Rocket Cluster
			i(18634),	-- Gyrofreeze Ice Reflector
			i(4378),	-- Heavy Dynamite
			i(10562),	-- Hi-Explosive Bomb
			i(10512, {["timeline"] = { REMOVED_4_0_1 }}),	-- Hi-Impact Mithril Slugs
			-- #if SEASON_OF_DISCOVERY
			applyclassicphase(SOD_PHASE_TWO, i(215127, {	-- High-Yield Radiation Bomb
				["timeline"] = { ADDED_1_15_1 },
			})),
			-- #endif
			i(18638, {["timeline"] = { REMOVED_6_0_2 }}),	-- Hyper-Radiant Flame Reflector
			i(4386, {["timeline"] = { REMOVED_4_0_3, ADDED_9_1_0 }}),	-- Ice Deflector
			i(4390),	-- Iron Grenade
			i(21589),	-- Large Blue Rocket
			i(21714),	-- Large Blue Rocket Cluster
			i(4370),	-- Large Copper Bomb
			i(21590),	-- Large Green Rocket
			i(21716),	-- Large Green Rocket Cluster
			i(21592),	-- Large Red Rocket
			i(21718),	-- Large Red Rocket Cluster
			i(4398),	-- Large Seaforium Charge
			applyclassicphase(PHASE_ONE_DIREMAUL, i(18637)),	-- Major Recombobulator
			i(16023),	-- Masterwork Target Dummy
			i(11590),	-- Mechanical Repair Kit
			i(4381),	-- Minor Recombobulator
			i(10514),	-- Mithril Frag Bomb
			i(10513),	-- Mithril Gyro-Shot
			-- #if SEASON_OF_DISCOVERY
			applyclassicphase(SOD_PHASE_SIX, i(234005, { ["timeline"] = { ADDED_1_15_5 }, })),	-- Obsidian Blasting Powder
			applyclassicphase(SOD_PHASE_SIX, i(233986, { ["timeline"] = { ADDED_1_15_5 }, })),	-- Obsidian Bomb
			applyclassicphase(SOD_PHASE_SIX, i(235529, { ["timeline"] = { ADDED_1_15_5 }, })),	-- Obsidian Scope
			-- #endif
			i(5507),	-- Ornate Spyglass
			i(10518),	-- Parachute Cloak
			i(4403),	-- Portable Bronze Mortar
			i(18594),	-- Powerful Seaforium Charge
			i(9318),	-- Red Firework
			i(21576),	-- Red Rocket Cluster
			i(4360),	-- Rough Copper Bomb
			i(4358),	-- Rough Dynamite
			i(15846, {["timeline"] = { REMOVED_6_0_2 }}),	-- Salt Shaker
			-- #if SEASON_OF_DISCOVERY
			applyclassicphase(SOD_PHASE_ONE, i(210147, {	-- Shredder Autosalvage Unit
				["timeline"] = { ADDED_1_15_0 },
			})),
			-- #endif
			i(21558),	-- Small Blue Rocket
			i(4374),	-- Small Bronze Bomb
			i(21559),	-- Small Green Rocket
			i(21557),	-- Small Red Rocket
			i(4367),	-- Small Seaforium Charge
			i(19026),	-- Snake Burst Firework
			i(10507),	-- Solid Dynamite
			-- #if SEASON_OF_DISCOVERY
			applyclassicphase(SOD_PHASE_TWO, i(211427, {	-- Soul Vessel
				["timeline"] = { ADDED_1_15_1 },
			})),
			-- #endif
			applyclassicphase(TBC_PHASE_ONE, i(22728, {["timeline"] = { CREATED_1_10_0, ADDED_2_0_1 }})),	-- Steam Tonk Controller
			i(4366),	-- Target Dummy
			-- #if SEASON_OF_DISCOVERY
			applyclassicphase(SOD_PHASE_SIX, i(233985, { ["timeline"] = { ADDED_1_15_5 }, })),	-- The Fumigator
			-- #endif
			i(15993),	-- Thorium Grenade
			i(15997, {["timeline"] = { REMOVED_4_0_1 }}),	-- Thorium Shells
			i(18639),	-- Ultra-Flash Shadow Reflector
			i(16009),	-- Voice Amplification Modulator
		}),
		filter(PROFESSION_EQUIPMENT, {
			i(6219, {	-- Arclight Spanner
				["collectible"] = false,
			}),
			i(10498),	-- Gyromatic Micro-Adjustor
		}),
		filter(REAGENTS, {
			i(4382),	-- Bronze Framework
			i(4371),	-- Bronze Tube
			i(4364),	-- Coarse Blasting Powder
			-- #if BEFORE 4.3.0
			i(4363),	-- Copper Modulator
			i(4361),	-- Copper Tube
			-- #endif
			i(16006),	-- Delicate Arcanite Converter
			i(15992),	-- Dense Blasting Powder
			applyclassicphase(TBC_PHASE_ONE, i(7191, {["timeline"] = {ADDED_2_1_0}})),	-- Fused Wiring
			i(10558),	-- Gold Power Core
			i(4389),	-- Gyrochronatom
			i(4359),	-- Handful of Copper Bolts
			i(4377),	-- Heavy Blasting Powder
			i(4387),	-- Iron Strut
			i(10561),	-- Mithril Casing
			i(10559),	-- Mithril Tube
			-- #if SEASON_OF_DISCOVERY
			applyclassicphase(SOD_PHASE_TWO, i(213383, {	-- Polished Truesilver Gears
				["timeline"] = { ADDED_1_15_1 },
			})),
			-- #endif
			i(4357),	-- Rough Blasting Powder
			i(4404),	-- Silver Contact
			i(10505),	-- Solid Blasting Powder
			i(16000),	-- Thorium Tube
			i(15994),	-- Thorium Widget
			i(18631),	-- Truesilver Transformer
			i(10560),	-- Unstable Trigger
			i(4375),	-- Whirring Bronze Gizmo
		}),
		filter(TOYS, {
			i(17716),	-- Snowmaster 9000 (TOY!)
		}),
		filter(TRINKET_F, {
			i(16022),	-- Arcanite Dragonling
			applyclassicphase(WRATH_PHASE_ONE, i(45631, {["timeline"] = { ADDED_3_1_0 }})),	-- High-Powered Flashlight
			i(4396),	-- Mechanical Dragonling
			i(10576),	-- Mithril Mechanical Dragonling
		}),
		n(WEAPONS, {
			i(18282, {	-- Core Marksman Rifle
				-- #if SEASON_OF_DISCOVERY
				["timeline"] = { REMOVED_1_15_3 },
				-- #endif
			}),
			i(16004),	-- Dark Iron Rifle
			i(4369),	-- Deadly Blunderbuss
			-- #if SEASON_OF_DISCOVERY
			applyclassicphase(SOD_PHASE_FOUR, i(227849, {	-- Fiery Core Sharpshooter Rifle
				["timeline"] = { ADDED_1_15_3 },
			})),
			-- #endif
			i(16007, {["timeline"] = { REMOVED_4_0_3, ADDED_10_1_7 }}),	-- Flawless Arcanite Rifle
			i(18168),	-- Force Reactive Disk
			i(4372, {["timeline"] = { REMOVED_4_0_3, ADDED_4_1_0 }}),	-- Lovingly Crafted Boomstick
			i(10508),	-- Mithril Blunderbuss
			i(10510),	-- Mithril Heavy-Bore Rifle
			i(4383),	-- Moonsight Rifle
			-- #if SEASON_OF_DISCOVERY
			applyclassicphase(SOD_PHASE_SIX, i(234434, { ["timeline"] = { ADDED_1_15_5 }, })),	-- Obsidian Shotgun
			-- #endif
			i(207564, {["timeline"] = { ADDED_10_1_5 }}),	-- Refurbished Purifier
			i(206512, {["timeline"] = { ADDED_10_1_5 }}),	-- Replaced Servo Arm
			i(4362),	-- Rough Boomstick
			i(4379),	-- Silver-Plated Shotgun
			i(207562, {["timeline"] = { ADDED_10_1_5 }}),	-- Skullstone Bludgeon
			i(15995),	-- Thorium Rifle
			-- #if SEASON_OF_DISCOVERY
			applyclassicphase(SOD_PHASE_SIX, i(233988, { ["timeline"] = { ADDED_1_15_5 }, })),	-- Tuned Force Reactive Disk
			applyclassicphase(SOD_PHASE_TWO, i(213390, {	-- Whirling Truesilver Gearwall
				["timeline"] = { ADDED_1_15_1 },
			})),
			-- #endif
		}),
		n(WEAPON_ENCHANTMENTS, {
			i(4407),	-- Accurate Scope
			i(18283),	-- Biznicks 247x128 Accurascope
			i(4405),	-- Crude Scope
			i(10546),	-- Deadly Scope
			i(10548),	-- Sniper Scope
			i(4406),	-- Standard Scope
		}),
	}),
	prof(FIRST_AID, {
		i(6452),	-- Anti-Venom
		i(2581),	-- Heavy Linen Bandage
		i(8545),	-- Heavy Mageweave Bandage
		i(14530),	-- Heavy Runecloth Bandage
		i(6451),	-- Heavy Silk Bandage
		i(3531),	-- Heavy Wool Bandage
		i(1251),	-- Linen Bandage
		i(8544),	-- Mageweave Bandage
		applyclassicphase(PHASE_THREE_RECIPES, i(19440)),	-- Powerful Anti-Venom
		i(14529),	-- Runecloth Bandage
		i(6450),	-- Silk Bandage
		i(6453),	-- Strong Anti-Venom
		i(3530),	-- Wool Bandage
	}),
	prof(FISHING, {
		["description"] = "If you struggle to catch an open water fish in a given zone, try a different spot or a different body of water. There might be local variations of which fish you can reliably catch from a given spot.",
		["groups"] = {
			n(COMMON_VENDOR_ITEMS, sharedData({
				["description"] = "Can be bought from Fishing Suppliers, as well as some Trade vendors around the world.",
				-- Danny Donkey: Disabling this for now, Common Vendor Items is being filled into Minilists when coords/providers are given.
				--[[["coords"] = {
					{ 47.8, 6.6, MAP.IRONFORGE },
					{ 55.8, 47.0, MAP.THUNDER_BLUFF },
					{ 81.0, 30.8, MAP.UNDERCITY },
					{ 45.8, 58.5, MAP.STORMWIND_CITY },
					{ 46.9, 56.9, MAP.DARNASSUS },
					{ 66.6, 41.6, MAP.ORGRIMMAR },
				},
				["providers"] = {
					{ "n", 5494 },	-- Catherine Leland <Fishing Supplier>
					{ "n", 4574 },	-- Lizbeth Cromwell <Fishing Supplies> [TBC+] / Lizbeth Cromwell <Fishing Supplier>
					{ "n", 3029 },	-- Sewa Mistrunner <Fishing Supplies>
					{ "n", 3333 },	-- Shankys <Fishing Supplies>
					{ "n", 5162 },	-- Tansy Puddlefizz <Fishing Supplier>
					{ "n", 4222 },	-- Voloren <Fishing Supplies>
				},]]
			}, {
				i(6533, {["isLimited"] = true, }),	-- Aquadynamic Fish Attractor
				i(6532),	-- Bright Baubles
				i(6256),	-- Fishing Pole
				i(6530),	-- Nightcrawlers
				i(6529),	-- Shiny Bauble
				i(6365, {	-- Strong Fishing Pole
					["isLimited"] = true,
				}),
			})),
			filter(ONE_HANDED_MACES, {
				i(6360, {	-- Steelscale Crushfish
					["description"] = "Can be caught in open water in the given zones.",
					["maps_disp"] = {
						MAP.ASHENVALE,
						MAP.HILLSBRAD_FOOTHILLS,
						MAP.WETLANDS,
					},
				}),
			}),
			filter(FINGER_F, {
				i(8350, {	-- The 1 Ring
					["description"] = "Interestingly enough, you can fish this out of the lava in Ironforge. I guess the gnomes failed their quest...",
				}),
			}),
			filter(HELD_IN_OFF_HAND, sharedData({ ["collectible"] = false, }, {
				i(6292),	-- 10 Pound Mud Snapper
				i(6294),	-- 12 Pound Mud Snapper
				i(6295),	-- 15 Pound Mud Snapper
				i(13901),	-- 15 Pound Salmon
				i(6309),	-- 17 Pound Catfish
				i(13902),	-- 18 Pound Salmon
				i(6310),	-- 19 Pound Catfish
				i(6311),	-- 22 Pound Catfish
				i(13903),	-- 22 Pound Salmon
				i(13904),	-- 25 Pound Salmon
				i(6363),	-- 26 Pound Catfish
				i(13905),	-- 29 Pound Salmon
				i(6364),	-- 32 Pound Catfish
				i(13906),	-- 32 Pound Salmon
				i(13885),	-- 34 Pound Redgill
				i(13886),	-- 37 Pound Redgill
				i(13882),	-- 42 Pound Redgill
				i(13883),	-- 45 Pound Redgill
				i(13884),	-- 49 Pound Redgill
				i(13887),	-- 52 Pound Redgill
				i(13914),	-- 70 Pound Mightfish
				i(13915),	-- 85 Pound Mightfish
				i(13916),	-- 92 Pound Mightfish
				i(13917),	-- 103 Pound Mightfish
			})),
			filter(MISC, {
				-- Equippables:
				i(13907),	-- 7 Pound Lobster
				i(13908),	-- 9 Pound Lobster
				i(13909),	-- 12 Pound Lobster
				i(13910),	-- 15 Pound Lobster
				i(13911),	-- 19 Pound Lobster
				i(13912),	-- 21 Pound Lobster
				i(13913),	-- 22 Pound Lobster
				i(13876),	-- 40 Pound Grouper
				i(13877),	-- 47 Pound Grouper
				i(13878),	-- 53 Pound Grouper
				i(13879),	-- 59 Pound Grouper
				i(13880),	-- 68 Pound Grouper
				-- Bloated fish:
				i(6646),	-- Bloated Albacore
				i(6647),	-- Bloated Catfish
				i(21163),	-- Bloated Firefin
				i(6644),	-- Bloated Mackerel
				i(21243),	-- Bloated Mightfish
				i(6645),	-- Bloated Mud Snapper
				i(21162),	-- Bloated Oily Blackmouth
				i(13881, {	-- Bloated Redgill
					i(7551),	-- Entwined Opaline Talisman
					i(7549),	-- Fairy's Embrace
				}),
				i(21164, {	-- Bloated Rockscale Cod
					i(7909),	-- Aquamarine
					i(3864),	-- Citrine
					i(1529),	-- Jade
					i(1705),	-- Lesser Moonstone
				}),
				i(13891),	-- Bloated Salmon
				i(6643),	-- Bloated Smallfish
				i(8366),	-- Bloated Trout
				-- Containers:
				i(6351),	-- Dented Crate
				i(13874),	-- Heavy Crate
				i(21150, {	-- Iron Bound Trunk
					["maps_disp"] = {
						MAP.ARATHI_HIGHLANDS,
						MAP.ASHENVALE,
						MAP.AZSHARA,
						MAP.BLASTED_LANDS,
						MAP.DARKSHORE,
						MAP.DESOLACE,
						MAP.DUSTWALLOW_MARSH,
						MAP.FERALAS,
						MAP.HILLSBRAD_FOOTHILLS,
						MAP.SILVERPINE_FOREST,
						MAP.SWAMP_OF_SORROWS,
						MAP.TANARIS,
						MAP.ALTERAC_MOUNTAINS,
						MAP.STRANGLETHORN_VALE,
						MAP.THE_BARRENS,
						MAP.THE_HINTERLANDS,
						MAP.WESTFALL,
						MAP.WETLANDS,
					},
					["providers"] = {
						{ "o", 180901 },	-- Bloodsail Wreckage
						{ "o", 180683 },	-- Firefin Snapper School
						{ "o", 180683 },	-- Greater Sagefish School
						{ "o", 180682 },	-- Oily Blackmouth School
						{ "o", 180685 },	-- Waterlogged Wreckage
					},
					--[[["groups"] = {
						i(4339),	-- Bolt of Mageweave
						i(4305),	-- Bolt of Silk Cloth
						i(1710),	-- Greater Healing Potion
						i(4234),	-- Heavy Leather
						i(3827),	-- Mana Potion
						i(4304),	-- Thick Leather
					},]]
				}),
				i(6307),	-- Message in a Bottle
				i(21228, {	-- Mitril Bound Trunk
					["maps_disp"] = {
						MAP.BLASTED_LANDS,
						MAP.EASTERN_PLAGUELANDS,
						MAP.SWAMP_OF_SORROWS,
						MAP.TANARIS,
					},
					["providers"] = {
						{ "o", 180751 },	-- Floating Wreckage
						{ "o", 180712 },	-- Stonescale Eel Swarm
					},
					--[[["groups"] = {
						i(4339),	-- Bolt of Mageweave
						i(14048),	-- Bolt of Runecloth
						i(6149),	-- Greater Mana Potion
						i(8170),	-- Rugged Leather
						i(3928),	-- Superior Healing Potion
						i(4304),	-- Thick Leather
					},]]
				}),
				i(13918),	-- Reinforced Locked Chest
				i(6357),	-- Sealed Crate
				i(20708, {	-- Tightly Sealed Trunk
					["maps_disp"] = {
						MAP.DARKSHORE,
						MAP.DUSKWOOD,
						MAP.REDRIDGE_MOUNTAINS,
						MAP.SILVERPINE_FOREST,
						MAP.WESTFALL,
						MAP.THE_BARRENS,
					},
					["providers"] = {
						{ "o", 180655 },	-- Floating Debris
						{ "o", 180658 },	-- School of Deviate Fish
					},
					--[[["groups"] = {
						i(2996),	-- Bolt of Linen Cloth
						i(2997),	-- Bolt of Woolen Cloth
						i(858),	-- Lesser Healing Potion
						i(2318),	-- Light Leather
						i(2319),	-- Medium Leather
						i(2455),	-- Minor Mana Potion
					},]]
				}),
				i(6352),	-- Waterlogged Crate
				i(21113, {	-- Watertight Trunk
					["maps_disp"] = {
						MAP.ASHENVALE,
						MAP.HILLSBRAD_FOOTHILLS,
						MAP.STONETALON_MOUNTAINS,
						MAP.WETLANDS,
					},
					["providers"] = {
						{ "o", 180662 },	-- Schooner Wreckage / Pre WotLK: Floating Wreckage
					},
					--[[["groups"] = {
						i(4305),	-- Bolt of Silk Cloth
						i(2997),	-- Bolt of Woolen Cloth
						i(929),	-- Healing Potion
						i(4234),	-- Heavy Leather
						i(2319),	-- Medium Leather
						i(3385),	-- Lesser Mana Potion
					},]]
				}),
				-- Consumables:
				i(21151, {	-- Rumsey Rum Black Label
					["providers"] = {
						{ "o", 180901 },	-- Bloodsail Wreckage
						{ "o", 180683 },	-- Firefin Snapper School
						{ "o", 180655 },	-- Floating Debris
						{ "o", 180751 },	-- Floating Wreckage
						{ "o", 180683 },	-- Greater Sagefish School
						{ "o", 180682 },	-- Oily Blackmouth School
						{ "o", 180658 },	-- School of Deviate Fish
						{ "o", 180662 },	-- Schooner Wreckage / Pre WotLK: Floating Wreckage
						{ "o", 180712 },	-- Stonescale Eel Swarm
						{ "o", 180685 },	-- Waterlogged Wreckage
						{ "o", 180663 },	-- Sagefish School
						{ "o", 180656 },	-- Sagefish School
					},
				}),
				i(20709, {	-- Rumsey Rum Light
					["maps_disp"] = {
						MAP.DARKSHORE,
						MAP.DUSKWOOD,
						MAP.REDRIDGE_MOUNTAINS,
						MAP.SILVERPINE_FOREST,
						MAP.WESTFALL,
						MAP.THE_BARRENS,
					},
					["providers"] = {
						{ "o", 180655 },	-- Floating Debris
					},
				}),
			}),
			filter(PROFESSION_EQUIPMENT, {
				i(6366, {	-- Darkwood Fishing Pole
					["description"] = "Can be caught in Ashenvale, Arathi Highlands, Hillsbrad Foothills, Stranglethorn Vale, Redridge Mountains and Wetlands.",
					["maps_disp"] = {
						MAP.ASHENVALE,
						MAP.ARATHI_HIGHLANDS,
						MAP.HILLSBRAD_FOOTHILLS,
						MAP.STRANGLETHORN_VALE,
						MAP.REDRIDGE_MOUNTAINS,
						MAP.WETLANDS,
					},
				}),
			}),
			-- Danny Donkey: The post Cata data for fish and school locations is accurate for viability in retail and might deviate from Cata+ classic. Pre Cata data is also not validated in-game.
			-- Fish:
			i(13888, {	-- Darkclaw Lobster
				["description"] = "Can be caught on the seaside.",
				["maps_disp"] = {
					MAP.AZSHARA,
				},
			}),
			i(6522, {	-- Deviate Fish
				["_allowObjectProvider"] = true,
				["coords"] = {
					{ 56.0, 43.0, MAP.THE_BARRENS },	-- The Stagnant Oasis
					{ 46.0, 38.0, MAP.THE_BARRENS },	-- Lushwater Oasis
					{ 45.0, 22.0, MAP.THE_BARRENS },	-- The Forgotten Oasis
				},
				["provider"] = { "o", 180658 },	-- School of Deviate Fish
			}),
			i(6359, {	-- Firefin Snapper
				["description"] = "Schools can be found on the seaside.",
				["maps_disp"] = {
					MAP.ARATHI_HIGHLANDS,
					MAP.ASHENVALE,
					MAP.AZSHARA,
					MAP.BLASTED_LANDS,
					MAP.DARKSHORE,
					MAP.DESOLACE,
					MAP.DUSTWALLOW_MARSH,
					MAP.FERALAS,
					MAP.HILLSBRAD_FOOTHILLS,
					MAP.SILVERPINE_FOREST,
					MAP.SWAMP_OF_SORROWS,
					MAP.TANARIS,
					MAP.STRANGLETHORN_VALE,
					MAP.THE_BARRENS,
					MAP.THE_HINTERLANDS,
					MAP.WESTFALL,
					MAP.WETLANDS,
				},
				["providers"] = {
					{ "o", 180683 },	-- Firefin Snapper School
				},
			}),
			i(13893, {	-- Large Raw Mightfish
				["description"] = "Can be caught on the seaside.",
				["maps_disp"] = {
					-- #if AFTER 4.0.3
					MAP.BLASTED_LANDS,
					MAP.SWAMP_OF_SORROWS,
					-- #else
					MAP.AZSHARA,
					-- #endif
				},
			}),
			i(13757, {	-- Lightening Eel
				["coord"] = { 60.6, 71.7, MAP.SILITHUS },
				["description"] = "Can be caught in inland waters and waterways. This fish have a 5-10% drop rate.",
				["maps_disp"] = {
					-- #if BEFORE 4.0.3
					MAP.BURNING_STEPPES,
					MAP.EASTERN_PLAGUELANDS,
					-- #endif
					MAP.DEADWIND_PASS,
					MAP.WINTERSPRING,
				},
			}),
			i(6358, {	-- Oily Blackmouth
				["description"] = "Schools can be found on the seaside.",
				["maps_disp"] = {
					MAP.ARATHI_HIGHLANDS,
					MAP.ASHENVALE,
					MAP.AZSHARA,
					MAP.BLASTED_LANDS,
					MAP.DARKSHORE,
					MAP.DESOLACE,
					MAP.DUSTWALLOW_MARSH,
					MAP.FERALAS,
					MAP.HILLSBRAD_FOOTHILLS,
					MAP.SILVERPINE_FOREST,
					MAP.SWAMP_OF_SORROWS,
					MAP.TANARIS,
					MAP.STRANGLETHORN_VALE,
					MAP.THE_BARRENS,
					MAP.THE_HINTERLANDS,
					MAP.WESTFALL,
					MAP.WETLANDS,
				},
				["providers"] = {
					{ "o", 180682 },	-- Oily Blackmouth School
				},
			}),
			i(6291, {	-- Raw Brilliant Smallfish
				["description"] = "Can be caught in inland waters and waterways.",
				["maps_disp"] = {
					MAP.DUN_MOROGH,
					MAP.ELWYNN_FOREST,
					MAP.MULGORE,
					MAP.TIRISFAL_GLADES,
				},
			}),
			i(6308, {	-- Raw Bristle Whisker Catfish
				["description"] = "Can be caught in inland waters and waterways.",
				["maps_disp"] = {
					MAP.ASHENVALE,
					MAP.DUSKWOOD,
					MAP.REDRIDGE_MOUNTAINS,
					MAP.STONETALON_MOUNTAINS,
				},
			}),
			i(13754, {	-- Raw Glossy Mightfish
				["description"] = "Can be caught on the seaside.",
				["maps_disp"] = {
					MAP.TANARIS,
					-- #if BEFORE 4.0.3
					MAP.AZSHARA,
					MAP.FERALAS,
					MAP.THE_HINTERLANDS,
					-- #endif
				},
			}),
			i(21153, {	-- Raw Greater Sagefish
				["description"] = "Schools can be found in inland waters and waterways.",
				["maps_disp"] = {
					-- #if BEFORE 4.0.3
					MAP.ALTERAC_MOUNTAINS,
					MAP.STRANGLETHORN_VALE,
					-- #else
					MAP.ARATHI_HIGHLANDS,
					MAP.BLASTED_LANDS,
					MAP.DESOLACE,
					MAP.DUSTWALLOW_MARSH,
					MAP.EASTERN_PLAGUELANDS,
					MAP.FERALAS,
					MAP.MOONGLADE,
					MAP.STONETALON_MOUNTAINS,
					MAP.THE_HINTERLANDS,
					MAP.UNGORO_CRATER,
					MAP.WESTERN_PLAGUELANDS,
					-- #endif
				},
				["provider"] = { "o", 180684 },	-- Greater Sagefish School
			}),
			i(6317, {	-- Raw Loch Frenzy
				["description"] = "Can be caught in The Loch.",
				["maps_disp"] = { MAP.LOCH_MODAN },
			}),
			i(6289, {	-- Raw Longjaw Mud Snapper
				["description"] = "Can be caught in inland waters and waterways.",
				["maps_disp"] = {
					MAP.DARNASSUS,
					-- #if AFTER 4.0.3
					MAP.DUN_MOROGH,
					MAP.IRONFORGE,
					-- #endif
					MAP.ORGRIMMAR,
					MAP.STORMWIND_CITY,
					MAP.THUNDER_BLUFF,
				},
			}),
			i(8365, {	-- Raw Mithril Head Trout
				["description"] = "Can be caught in inland waters and waterways.",
				["maps_disp"] = {
					-- #if BEFORE 4.0.3
					MAP.ARATHI_HIGHLANDS,
					MAP.THOUSAND_NEEDLES,
					-- #else
					MAP.DESOLACE,
					MAP.DUSTWALLOW_MARSH,
					MAP.EASTERN_PLAGUELANDS,
					MAP.FERALAS,
					MAP.MOONGLADE,
					MAP.WESTERN_PLAGUELANDS,
					-- #endif
				},
			}),
			i(13759, {	-- Raw Nightfin Snapper
				["description"] = "Can be caught in inland waters and waterways during night time: 18:00/6pm to 12:00/12pm server time.",
				["maps_disp"] = {
					-- #if BEFORE 4.0.3
					MAP.DEADWIND_PASS,
					MAP.MOONGLADE,
					MAP.WESTERN_PLAGUELANDS,
					MAP.WINTERSPRING,
					-- #else
					MAP.BLASTED_LANDS,
					-- #endif
					MAP.EASTERN_PLAGUELANDS,
					MAP.FELWOOD,
					MAP.FERALAS,
					MAP.UNGORO_CRATER,
				},
			}),
			i(6361, {	-- Raw Rainbow Fin Albacore
				["description"] = "Can be caught on the seaside.",
				["maps_disp"] = {
					MAP.ASHENVALE,
					MAP.HILLSBRAD_FOOTHILLS,
					MAP.SILVERPINE_FOREST,
					MAP.THE_BARRENS,
					MAP.WESTFALL,
					MAP.WETLANDS,
					MAP.DARKSHORE,
				},
			}),
			i(13758, {	-- Raw Redgill
				["description"] = "Can be caught in inland waters and waterways.",
				["maps_disp"] = {
					MAP.FELWOOD,
					MAP.MOONGLADE,
					MAP.UNGORO_CRATER,
					MAP.WESTERN_PLAGUELANDS,
				},
			}),
			i(6362, {	-- Raw Rockscale Cod
				["description"] = "Can be caught on the seaside.",
				["maps_disp"] = {
					MAP.DUSTWALLOW_MARSH,
					MAP.SWAMP_OF_SORROWS,
				},
			}),
			i(21071, {	-- Raw Sagefish
				["coords"] = {
					{ 50.0, 40.0, MAP.STONETALON_MOUNTAINS },	-- Mirkfallon Lake
				},
				["description"] = "Schools can be found in inland waters and waterways.",
				["maps_disp"] = {
					MAP.ASHENVALE,
					MAP.HILLSBRAD_FOOTHILLS,
					MAP.LOCH_MODAN,
					MAP.SILVERPINE_FOREST,
				},
				["providers"] = {
					{ "o", 180663 },	-- Sagefish School
					{ "o", 180656 },	-- Sagefish School
				},
			}),
			i(6303, {	-- Raw Slitherskin Mackerel
				["description"] = "Can be caught on the seaside.",
				["maps_disp"] = {
					MAP.DUROTAR,
					MAP.TELDRASSIL,
				},
			}),
			i(4603, {	-- Raw Spotted Yellowtail
				["description"] = "Can be caught on the seaside.",
				["maps_disp"] = {
					MAP.TANARIS,
					MAP.SWAMP_OF_SORROWS,
					MAP.THE_HINTERLANDS,
				},
			}),
			-- i(13756),	-- Raw Summer Bass: Is properly sourced in 21 - Holidays/Seasonal Fish.lua.
			i(13760, {	-- Raw Sunscale Salmon
				["description"] = "Can be caught in inland waters and waterways during day time: 06:00/6am to 21:00/9pm server time.",
				["coord"] = { 60.6, 71.7, MAP.SILITHUS },
			}),
			i(13889, {	-- Raw Whitescale Salmon
				["description"] = "Can be caught in inland waters and waterways.",
				["maps_disp"] = {
					MAP.DEADWIND_PASS,
					MAP.EASTERN_PLAGUELANDS,
					MAP.SILITHUS,
					MAP.WINTERSPRING,
				},
			}),
			i(13422, {	-- Stonescale Eel
				["description"] = "Schools can be found on the seaside.",
				["maps_disp"] = {
					MAP.TANARIS,
					MAP.AZSHARA,
					MAP.FERALAS,
					MAP.THE_HINTERLANDS,
					MAP.STRANGLETHORN_VALE,
				},
				["provider"] = { "o", 180712 },	-- Stonescale Eel Swarm
			}),
			-- i(13755),	-- Winter Squid: Is properly sourced in 21 - Holidays/Seasonal Fish.lua.
			-- Fish schools:
			o(180683, {	-- Firefin Snapper School
				["description"] = "Can be found on the seaside.",
				["maps"] = {
					MAP.ARATHI_HIGHLANDS,
					MAP.ASHENVALE,
					MAP.AZSHARA,
					MAP.BLASTED_LANDS,
					MAP.DARKSHORE,
					MAP.DESOLACE,
					MAP.DUSTWALLOW_MARSH,
					MAP.FERALAS,
					MAP.HILLSBRAD_FOOTHILLS,
					MAP.SILVERPINE_FOREST,
					MAP.SWAMP_OF_SORROWS,
					MAP.TANARIS,
					MAP.THE_BARRENS,
					MAP.THE_HINTERLANDS,
					MAP.WESTFALL,
					MAP.WETLANDS,
				},
			}),
			-- These Firefin Snapper school IDs needs to be confirmed in game.
			o(180657),	-- Firefin Snapper School 2
			o(180683),	-- Firefin Snapper School 3
			o(180752),	-- Firefin Snapper School 4
			o(180902),	-- Firefin Snapper School 5
			o(180684, {	-- Greater Sagefish School
				["description"] = "Can be found in inland waters and waterways.",
				["maps"] = {
					MAP.ALTERAC_MOUNTAINS,
					MAP.STRANGLETHORN_VALE,
				},
			}),
			o(180682, {	-- Oily Blackmouth School
				["description"] = "Can be found on the seaside.",
				["maps_disp"] = {
					MAP.ARATHI_HIGHLANDS,
					MAP.ASHENVALE,
					MAP.AZSHARA,
					MAP.BLASTED_LANDS,
					MAP.DARKSHORE,
					MAP.DESOLACE,
					MAP.DUSTWALLOW_MARSH,
					MAP.FERALAS,
					MAP.HILLSBRAD_FOOTHILLS,
					MAP.SILVERPINE_FOREST,
					MAP.SWAMP_OF_SORROWS,
					MAP.TANARIS,
					MAP.THE_BARRENS,
					MAP.THE_HINTERLANDS,
					MAP.WESTFALL,
					MAP.WETLANDS,
				},
			}),
			-- The following pre-5.1.0 Sagefish school IDs needs to be confirmed in game.
			o(180656, {	-- Sagefish School
				["timeline"] = { REMOVED_5_1_0 },
			}),
			o(180663, {	-- Sagefish School
				["timeline"] = { REMOVED_5_1_0 },
			}),
			o(216764, {	-- Sagefish School
				["description"] = "Can be found in inland waters and waterways.",
				["maps"] = {
					MAP.ASHENVALE,
					MAP.HILLSBRAD_FOOTHILLS,
					MAP.LOCH_MODAN,
					MAP.SILVERPINE_FOREST,
					MAP.DUSKWOOD,
					MAP.REDRIDGE_MOUNTAINS,
					MAP.WETLANDS,
				},
				["timeline"] = { ADDED_5_1_0 },
			}),
			o(180658, {	-- School of Deviate Fish
				["coords"] = {
					{ 56.0, 43.0, MAP.THE_BARRENS },	-- The Stagnant Oasis
					{ 46.0, 38.0, MAP.THE_BARRENS },	-- Lushwater Oasis
					{ 45.0, 22.0, MAP.THE_BARRENS },	-- The Forgotten Oasis
				},
			}),
			o(180712, {	-- Stonescale Eel Swarm
				["description"] = "Can be found on the seaside.",
				["maps"] = {
					MAP.TANARIS,
					MAP.AZSHARA,
					MAP.FERALAS,
					MAP.THE_HINTERLANDS,
					MAP.STRANGLETHORN_VALE,
				},
			}),
			-- Wreckages:
			o(180901, {	-- Bloodsail Wreckage
				["description"] = "Wreckages can be found on the seaside, as well as inland waters near humanoid structures. If you cannot find any, fish out nearby fishing schools as they share spawns.",
				["maps"] = {
					MAP.STRANGLETHORN_VALE,
				},
			}),
			o(180655, {	-- Floating Debris
				["description"] = "Wreckages can be found on the seaside, as well as inland waters near humanoid structures. If you cannot find any, fish out nearby fishing schools as they share spawns.",
				["maps"] = {
					MAP.DARKSHORE,
					MAP.DUSKWOOD,
					MAP.REDRIDGE_MOUNTAINS,
					MAP.SILVERPINE_FOREST,
					MAP.WESTFALL,
					MAP.THE_BARRENS,
				},
			}),
			o(180751, {	-- Floating Wreckage
				["description"] = "Wreckages can be found on the seaside, as well as inland waters near humanoid structures. If you cannot find any, fish out nearby fishing schools as they share spawns.",
				["maps"] = {
					MAP.BLASTED_LANDS,
					MAP.EASTERN_PLAGUELANDS,
					MAP.SWAMP_OF_SORROWS,
					MAP.TANARIS,
				},
			}),
			o(180662, {	-- Schooner Wreckage / Pre WotLK: Floating Wreckage
				["description"] = "Wreckages can be found on the seaside, as well as inland waters near humanoid structures. If you cannot find any, fish out nearby fishing schools as they share spawns.",
				["maps"] = {
					MAP.ASHENVALE,
					MAP.HILLSBRAD_FOOTHILLS,
					MAP.STONETALON_MOUNTAINS,
					MAP.WETLANDS,
				},
			}),
			o(180685, {	-- Waterlogged Wreckage / Pre WotLK: Floating Wreckage
				["description"] = "Wreckages can be found on the seaside, as well as inland waters near humanoid structures. If you cannot find any, fish out nearby fishing schools as they share spawns.",
				["maps"] = {
					MAP.TANARIS,
					MAP.STRANGLETHORN_VALE,
				},
			}),
		},
	}),
	prof(HERBALISM, {
		["description"] = "It is beneficial to gather all herbs in the area even if you only need specific herbs because the node spawns are often connected.",
		["groups"] = {
			header(HEADERS.Spell, 2366, appendAllGroups(sharedData({ ["requireSkill"] = HERBALISM, }, {	-- Herb Gathering
				-- Nodes:
				o(142141, {	-- Arthas' Tears (Scourge)
					["learnedAt"] = 220,
					["maps"] = {
						MAP.EASTERN_PLAGUELANDS,
						MAP.RAZORFEN_DOWNS,
						MAP.STRATHOLME,
						MAP.WESTERN_PLAGUELANDS,
					},
				}),
				o(176642, {	-- Arthas' Tears (Felwood)
					["learnedAt"] = 220,
					["maps"] = { MAP.FELWOOD },
				}),
				o(176589, {	-- Black Lotus
					["description"] = "Black Lotus is a rare spawn, and can spawn in place of other herbs.",
					["learnedAt"] = 300,
					["maps"] = {
						MAP.SILITHUS,
						MAP.BURNING_STEPPES,
						MAP.EASTERN_PLAGUELANDS,
						MAP.WINTERSPRING,
					},
				}),
				o(142143, {	-- Blindweed
					["maps"] = { MAP.SWAMP_OF_SORROWS },
					["learnedAt"] = 235,
					["description"] = "Can be found near wet terrain and/or waterways, somehow Blizzard managed to make this very inconsistent in some zones.",
				}),
				o(1621, {	-- Briarthorn
					["learnedAt"] = 70,
					["maps"] = {
						MAP.DARKSHORE,
						MAP.DUSKWOOD,
						MAP.HILLSBRAD_FOOTHILLS,
						MAP.STONETALON_MOUNTAINS,
						MAP.WETLANDS,
						MAP.ASHENVALE,
						MAP.REDRIDGE_MOUNTAINS,
						MAP.SILVERPINE_FOREST,
					},
					["description"] = "Usually found near trees.",
				}),
				o(3729, {	-- Briarthorn (The Barrens)
					-- Note: This node get replaced by o(1621) at an unknown point between MOP and TWW.
					["learnedAt"] = 70,
					["maps"] = {
						MAP.THE_BARRENS
					},
				}),
				o(1622, {	-- Bruiseweed
					["learnedAt"] = 100,
					["maps"] = {
						MAP.ASHENVALE,
						MAP.DUSKWOOD,
						MAP.HILLSBRAD_FOOTHILLS,
						MAP.STONETALON_MOUNTAINS,
						MAP.REDRIDGE_MOUNTAINS,
						MAP.THOUSAND_NEEDLES,
						MAP.WETLANDS,
					},
					["description"] = "Usually found near hillsides, buildings and structures.",
				}),
				o(3730, {	-- Bruiseweed (The Barrens/Stonetalon Mountains)
					-- Note: This node get replaced by o(1622) at an unknown point between MOP and TWW.
					["learnedAt"] = 100,
					["maps"] = {
						MAP.THE_BARRENS
					},
				}),
				o(2044, {	-- Dragon's Teeth [CATA+] / Wintersbite
					["maps"] = { MAP.ALTERAC_MOUNTAINS },
					["learnedAt"] = 195,
				}),
				o(176584, {	-- Dreamfoil
					["learnedAt"] = 270,
					["maps"] = {
						MAP.BURNING_STEPPES,
						MAP.SILITHUS,
						MAP.AZSHARA,
						MAP.EASTERN_PLAGUELANDS,
						MAP.UNGORO_CRATER,
						MAP.WESTERN_PLAGUELANDS,
					},
					["description"] = "Can usually be found on flat open spaces.",
				}),
				o(176693, {	-- Dreamfoil (Felwood)
					-- #if BEFORE 6.0.0
					["learnedAt"] = 270,
					-- #endif
					["maps"] = { MAP.FELWOOD },
					["timeline"] = { REMOVED_4_0_3 },
				}),
				o(1619, {	-- Earthroot
					["learnedAt"] = 15,
					["maps"] = {
						MAP.DUN_MOROGH,
						MAP.DUROTAR,
						MAP.ELWYNN_FOREST,
						MAP.MULGORE,
						MAP.SILVERPINE_FOREST,
						MAP.TELDRASSIL,
						MAP.TIRISFAL_GLADES,
						MAP.WESTFALL,
						MAP.DARKSHORE,
						MAP.REDRIDGE_MOUNTAINS,
					},
					["description"] = "Can be found on uneven terrain and mountain sides.",
				}),
				-- #if ANYCLASSIC
				o(3726, {	-- Earthroot (The Barrens)
					-- Note: This node get replaced by o(1619) at an unknown point between MOP and TWW.
					["maps"] = { MAP.THE_BARRENS },
					["learnedAt"] = 15,
				}),
				-- #endif
				o(2042, {	-- Fadeleaf
					["learnedAt"] = 160,
					["maps"] = {
						MAP.ALTERAC_MOUNTAINS,
						MAP.ARATHI_HIGHLANDS,
						MAP.DUSTWALLOW_MARSH,
						MAP.STRANGLETHORN_VALE,
					},
					["description"] = "Can be found in fertile terrain and fields.",
				}),
				o(2866, {	-- Firebloom
					["learnedAt"] = 205,
					["maps"] = {
						MAP.BADLANDS,
						MAP.SEARING_GORGE,
						MAP.TANARIS,
						MAP.BLASTED_LANDS,
					},
					["description"] = "Can be found on hot deserts.",
				}),
				o(206085, {	-- Frozen Herb (Hillsbrad Foothills)
					["coord"] = { 47.0, 26.0, MAP.HILLSBRAD_FOOTHILLS },	-- Alterac Mountains
					["description"] = "Found all over Alterac Mountains",
					["learnedAt"] = 125,
					["timeline"] = { ADDED_4_0_3 },
				}),
				o(142144, {	-- Ghost Mushroom
					["coords"] = {
						{ 58.0, 41.2, MAP.THE_HINTERLANDS },
						{ 55.8, 68.1, MAP.THE_HINTERLANDS },
						{ 57.0, 81.0, MAP.THE_HINTERLANDS },
					},
					["description"] = "Can be found inside caves.",
					["learnedAt"] = 245,
				}),
				o(176583, {	-- Golden Sansam
					["learnedAt"] = 260,
					["maps"] = {
						MAP.SILITHUS,
						MAP.UNGORO_CRATER,
						MAP.AZSHARA,
						MAP.BURNING_STEPPES,
						MAP.EASTERN_PLAGUELANDS,
						MAP.FERALAS,
						MAP.THE_HINTERLANDS,
					},
					["description"] = "Can be found by trees and other natural structures.",
				}),
				o(176638, {	-- Golden Sansam (Felwood)
					["learnedAt"] = 260,
					["maps"] = { MAP.FELWOOD },
					["timeline"] = { REMOVED_4_0_3 },
				}),
				o(2046, {	-- Goldthorn
					["learnedAt"] = 170,
					["maps"] = {
						MAP.ARATHI_HIGHLANDS,
						MAP.DUSTWALLOW_MARSH,
						MAP.FERALAS,
						MAP.THE_HINTERLANDS,
						MAP.ALTERAC_MOUNTAINS,
						MAP.STRANGLETHORN_VALE,
						MAP.SWAMP_OF_SORROWS,
					},
					["description"] = "Can be found on uneven terrain and mountain sides.",
				}),
				o(1628, {	-- Grave Moss
					["coords"] = {
						{ 20.0, 40.0, MAP.DUSKWOOD },	-- Raven Hill Cemetery
						{ 50.0, 58.0, MAP.DESOLACE },
						{ 80.0, 71.0, MAP.DUSKWOOD },
					},
					["description"] = "Can be found on graves.",
					["learnedAt"] = 120,
				}),
				o(142145, {	-- Gromsblood
					["coords"] = {
						{ 84.1, 71.65, MAP.ASHENVALE },	-- Felfire Hill
						{ 53.5, 46.5, MAP.BLASTED_LANDS },
						{ 50.0, 80.0, MAP.DESOLACE },
					},
					["description"] = "Found in locations corrupted by the Burning Legion.",
					["learnedAt"] = 250,
				}),
				o(176637, {	-- Gromsblood (Felwood)
					["learnedAt"] = 250,
					["maps"] = { MAP.FELWOOD },
					["timeline"] = { REMOVED_4_0_3 },
				}),
				o(176588, {	-- Icecap
					["learnedAt"] = 290,
					["maps"] = { MAP.WINTERSPRING },
				}),
				o(2043, {	-- Khadgar's Whisker
					["learnedAt"] = 185,
					["maps"] = {
						MAP.ARATHI_HIGHLANDS,
						MAP.DUSTWALLOW_MARSH,
						MAP.FERALAS,
						MAP.ALTERAC_MOUNTAINS,
						MAP.AZSHARA,
						MAP.BADLANDS,
						MAP.STRANGLETHORN_VALE,
						MAP.SWAMP_OF_SORROWS,
					},
					["description"] = "Can be found near trees.",
				}),
				o(1624, {	-- Kingsblood
					["learnedAt"] = 125,
					["maps"] = {
						MAP.ARATHI_HIGHLANDS,
						MAP.DUSKWOOD,
						MAP.WETLANDS,
						MAP.ALTERAC_MOUNTAINS,
						MAP.ASHENVALE,
						MAP.BADLANDS,
						MAP.DESOLACE,
						MAP.DUSTWALLOW_MARSH,
						MAP.HILLSBRAD_FOOTHILLS,
						MAP.STONETALON_MOUNTAINS,
						MAP.STRANGLETHORN_VALE,
						MAP.SWAMP_OF_SORROWS,
						MAP.THOUSAND_NEEDLES,
					},
					["description"] = "Can be found in the woods.",
				}),
				o(2041, {	-- Liferoot
					["learnedAt"] = 150,
					["maps"] = {
						MAP.ARATHI_HIGHLANDS,
						MAP.DUSTWALLOW_MARSH,
						MAP.THE_HINTERLANDS,
						MAP.WETLANDS,
						MAP.ALTERAC_MOUNTAINS,
						MAP.DESOLACE,
						MAP.FERALAS,
						MAP.HILLSBRAD_FOOTHILLS,
						MAP.STRANGLETHORN_VALE,
						MAP.SWAMP_OF_SORROWS,
						MAP.WESTERN_PLAGUELANDS,
					},
					["description"] = "Can usually be found on fertile grounds by inland waters and waterways, but coherency is not Blizzard's forte.",
				}),
				o(1620, {	-- Mageroyal
					["learnedAt"] = 50,
					["maps"] = {
						MAP.DARKSHORE,
						MAP.LOCH_MODAN,
						MAP.SILVERPINE_FOREST,
						MAP.TELDRASSIL,
						MAP.WESTFALL,
						MAP.WETLANDS,
						MAP.ASHENVALE,
						MAP.REDRIDGE_MOUNTAINS,
					},
				}),
				o(3727, {	-- Mageroyal (The Barrens)
					-- Note: This node get replaced by o(1620) at an unknown point between MOP and TWW.
					["learnedAt"] = 50,
					["maps"] = {
						MAP.THE_BARRENS
					},
				}),
				o(176586, {	-- Mountain Silversage
					["learnedAt"] = 280,
					["maps"] = {
						MAP.AZSHARA,
						MAP.BURNING_STEPPES,
						MAP.EASTERN_PLAGUELANDS,
						MAP.SILITHUS,
						MAP.UNGORO_CRATER,
						MAP.WINTERSPRING,
					},
					["description"] = "Can be found on uneven terrain and mountain sides.",
				}),
				o(176640, {	-- Mountain Silversage (Felwood)
					["learnedAt"] = 280,
					["maps"] = { MAP.FELWOOD },
				}),
				o(1618, {	-- Peacebloom
					["maps"] = {
						MAP.DARKSHORE,
						MAP.DUN_MOROGH,
						MAP.DUROTAR,
						MAP.ELWYNN_FOREST,
						MAP.LOCH_MODAN,
						MAP.MULGORE,
						MAP.SILVERPINE_FOREST,
						MAP.TELDRASSIL,
						MAP.TIRISFAL_GLADES,
						MAP.WESTFALL,
					},
				}),
				o(3724, {	-- Peacebloom (The Barrens)
					-- Note: This node get replaced by o(1618) at an unknown point between MOP and TWW.
					["maps"] = {
						MAP.THE_BARRENS
					},
				}),
				o(142140, {	-- Purple Lotus
					["maps"] = {
						MAP.AZSHARA,
						MAP.FERALAS,
						MAP.STRANGLETHORN_VALE,
						MAP.TANARIS,
						MAP.THE_HINTERLANDS,
					},
					["description"] = "Can be found in elven or troll ruins.",
					["learnedAt"] = 210,
				}),
				o(1617, {	-- Silverleaf
					["maps"] = {
						MAP.DARKSHORE,
						MAP.DUN_MOROGH,
						MAP.DUROTAR,
						MAP.ELWYNN_FOREST,
						MAP.LOCH_MODAN,
						MAP.MULGORE,
						MAP.SILVERPINE_FOREST,
						MAP.TELDRASSIL,
						MAP.TIRISFAL_GLADES,
						MAP.WESTFALL,
					},
				}),
				o(3725, {	-- Silverleaf (The Barrens)
					-- Note: This node get replaced by o(1617) at an unknown point between MOP and TWW.
					["maps"] = {
						MAP.THE_BARRENS
					},
				}),
				o(176587, {	-- Sorrowmoss [CATA+] / Plaguebloom
					["learnedAt"] = 285,
					["maps"] = {
						MAP.EASTERN_PLAGUELANDS,
						MAP.WESTERN_PLAGUELANDS,
					},
				}),
				o(176641, {	-- Plaguebloom (Felwood)
					["learnedAt"] = 285,
					["maps"] = { MAP.FELWOOD },
				}),
				o(2045, {	-- Stranglekelp
					["learnedAt"] = 85,
					["maps"] = {
						MAP.ASHENVALE,
						MAP.DARKSHORE,
						MAP.DUSTWALLOW_MARSH,
						MAP.HILLSBRAD_FOOTHILLS,
						MAP.SILVERPINE_FOREST,
						MAP.SWAMP_OF_SORROWS,
						MAP.THE_HINTERLANDS,
						MAP.WESTFALL,
						MAP.WETLANDS,
						MAP.AZSHARA,
						MAP.DESOLACE,
						MAP.STRANGLETHORN_VALE,
						MAP.THE_BARRENS,
					},
					["description"] = "Can usually be found in the sea, but also sometimes in bodies of inland waters and waterways.",
				}),
				o(142142, {	-- Sungrass
					["learnedAt"] = 230,
					["maps"] = {
						MAP.AZSHARA,
						MAP.BLASTED_LANDS,
						MAP.FERALAS,
						MAP.THE_HINTERLANDS,
						MAP.UNGORO_CRATER,
						MAP.WESTERN_PLAGUELANDS,
						MAP.EASTERN_PLAGUELANDS,
					},
				}),
				o(176636, {	-- Sungrass (Felwood)
					["learnedAt"] = 230,
					["maps"] = { MAP.FELWOOD },
				}),
				o(1623, {	-- Wild Steelbloom
					["learnedAt"] = 115,
					["maps"] = {
						MAP.STRANGLETHORN_VALE,
						MAP.THOUSAND_NEEDLES,
						MAP.ARATHI_HIGHLANDS,
						MAP.STONETALON_MOUNTAINS,
						MAP.WETLANDS,
					},
					["description"] = "Can be found on uneven terrain and mountain sides.",
				}),
			}),
			{	-- Herbs:
				i(8836, {	-- Arthas' Tears
					["providers"] = {
						{ "o", 142141 },	-- Arthas' Tears (Scourge)
						{ "o", 176642 },	-- Arthas' Tears (Felwood)
					},
				}),
				i(13468, {	-- Black Lotus
					["maps_disp"] = {
						MAP.SILITHUS,
						MAP.BURNING_STEPPES,
						MAP.EASTERN_PLAGUELANDS,
						MAP.WINTERSPRING,
					},
					["providers"] = {
						{ "o", 176589 },	-- Black Lotus
						{ "o", 253069 },	-- Blacker Lotus
					},
				}),
				i(8839, {	-- Blindweed
					["maps_disp"] = {
						MAP.SWAMP_OF_SORROWS,
					},
					["provider"] = { "o", 142143 },	-- Blindweed
				}),
				i(2450, {	-- Briarthorn
					["maps_disp"] = {
						MAP.DARKSHORE,
						MAP.DUSKWOOD,
						MAP.HILLSBRAD_FOOTHILLS,
						MAP.STONETALON_MOUNTAINS,
						MAP.WETLANDS,
						MAP.ASHENVALE,
						MAP.REDRIDGE_MOUNTAINS,
						MAP.SILVERPINE_FOREST,
						MAP.THE_BARRENS,
					},
					["providers"] = {
						{ "o", 1621 },	-- Briarthorn
						{ "o", 3729 },	-- Briarthorn (The Barrens)
					},
				}),
				i(2453, {	-- Bruiseweed
					["maps_disp"] = {
						MAP.ASHENVALE,
						MAP.DUSKWOOD,
						MAP.HILLSBRAD_FOOTHILLS,
						MAP.STONETALON_MOUNTAINS,
						MAP.REDRIDGE_MOUNTAINS,
						MAP.THOUSAND_NEEDLES,
						MAP.WETLANDS,
					},
					["providers"] = {
						{ "o", 1622 },	-- Bruiseweed
						{ "o", 3730 },	-- Bruiseweed (The Barrens/Stonetalon Mountains)
					},
				}),
				i(3819, {	-- Dragon's Teeth [CATA+] / Wintersbite
					["maps_disp"] = {
						MAP.ALTERAC_MOUNTAINS,
					},
					["provider"] = { "o", 2044 },	-- Dragon's Teeth [CATA+] / Wintersbite
				}),
				i(13463, {	-- Dreamfoil
					["maps_disp"] = {
						MAP.BURNING_STEPPES,
						MAP.FELWOOD,
						MAP.SILITHUS,
						MAP.AZSHARA,
						MAP.EASTERN_PLAGUELANDS,
						MAP.UNGORO_CRATER,
						MAP.WESTERN_PLAGUELANDS,
						MAP.ZULGURUB,
					},
					["providers"] = {
						{ "o", 176584 },	-- Dreamfoil
						{ "o", 176693 },	-- Dreamfoil (Felwood)
						{ "o", 180168 },	-- Dreamfoil (Zul'Gurub)
					},
				}),
				i(2449, {	-- Earthroot
					["maps_disp"] = {
						MAP.DUN_MOROGH,
						MAP.DUROTAR,
						MAP.ELWYNN_FOREST,
						MAP.MULGORE,
						MAP.SILVERPINE_FOREST,
						MAP.TELDRASSIL,
						MAP.TIRISFAL_GLADES,
						MAP.WESTFALL,
						MAP.DARKSHORE,
						MAP.REDRIDGE_MOUNTAINS,
						MAP.THE_BARRENS,
					},
					["providers"] = {
						{ "o", 1619 },	-- Earthroot
						{ "o", 3726 },	-- Earthroot (The Barrens)
					},
				}),
				i(3818, {	-- Fadeleaf
					["maps_disp"] = {
						MAP.ALTERAC_MOUNTAINS,
						MAP.ARATHI_HIGHLANDS,
						MAP.DUSTWALLOW_MARSH,
						MAP.STRANGLETHORN_VALE,
					},
					["provider"] = { "o", 2042 },	-- Fadeleaf
				}),
				i(4625, {	-- Firebloom
					["maps_disp"] = {
						MAP.BADLANDS,
						MAP.SEARING_GORGE,
						MAP.TANARIS,
						MAP.BLASTED_LANDS,
					},
					["provider"] = { "o", 2866 },	-- Firebloom
				}),
				i(8845, {	-- Ghost Mushroom
					["maps_disp"] = {
						MAP.THE_HINTERLANDS,
					},
					["provider"] = { "o", 142144 },	-- Ghost Mushroom
				}),
				i(13464, {	-- Golden Sansam
					["maps_disp"] = {
						MAP.FELWOOD,
						MAP.SILITHUS,
						MAP.UNGORO_CRATER,
						MAP.AZSHARA,
						MAP.BURNING_STEPPES,
						MAP.EASTERN_PLAGUELANDS,
						MAP.FERALAS,
						MAP.THE_HINTERLANDS,
						MAP.ZULGURUB,
					},
					["providers"] = {
						{ "o", 176583 },	-- Golden Sansam
						{ "o", 176638 },	-- Golden Sansam (Felwood)
						{ "o", 180167 },	-- Golden Sansam (Zul'Gurub)
					},
				}),
				i(3821, {	-- Goldthorn
					["maps_disp"] = {
						MAP.ARATHI_HIGHLANDS,
						MAP.DUSTWALLOW_MARSH,
						MAP.FERALAS,
						MAP.THE_HINTERLANDS,
						MAP.ALTERAC_MOUNTAINS,
						MAP.STRANGLETHORN_VALE,
						MAP.SWAMP_OF_SORROWS,
					},
					["provider"] = { "o", 2046 },	-- Goldthorn
				}),
				i(3369, {	-- Grave Moss
					["maps_disp"] = {
						MAP.DESOLACE,
						MAP.DUSKWOOD,
					},
					["provider"] = { "o", 1628 },	-- Grave Moss
				}),
				i(8846, {	-- Gromsblood
					["maps_disp"] = {
						MAP.ASHENVALE,
						MAP.BLASTED_LANDS,
						MAP.DESOLACE,
					},
					["providers"] = {
						{ "o", 142145 },	-- Gromsblood
						{ "o", 176637 },	-- Gromsblood
					},
				}),
				i(13467, {	-- Icecap
					["maps_disp"] = { MAP.WINTERSPRING },
					["provider"] = { "o", 176588 },	-- Icecap
				}),
				i(3358, {	-- Khadgar's Whisker
					["maps_disp"] = {
						MAP.ARATHI_HIGHLANDS,
						MAP.DUSTWALLOW_MARSH,
						MAP.FERALAS,
						MAP.ALTERAC_MOUNTAINS,
						MAP.AZSHARA,
						MAP.BADLANDS,
						MAP.STRANGLETHORN_VALE,
						MAP.SWAMP_OF_SORROWS,
					},
					["provider"] = { "o", 2043 },	-- Khadgar's Whisker
				}),
				i(3356, {	-- Kingsblood
					["maps_disp"] = {
						MAP.ARATHI_HIGHLANDS,
						MAP.DUSKWOOD,
						MAP.WETLANDS,
						MAP.ALTERAC_MOUNTAINS,
						MAP.ASHENVALE,
						MAP.BADLANDS,
						MAP.DESOLACE,
						MAP.DUSTWALLOW_MARSH,
						MAP.HILLSBRAD_FOOTHILLS,
						MAP.STONETALON_MOUNTAINS,
						MAP.STRANGLETHORN_VALE,
						MAP.SWAMP_OF_SORROWS,
						MAP.THOUSAND_NEEDLES,
					},
					["provider"] = { "o", 1624 },	-- Kingsblood
				}),
				i(3357, {	-- Liferoot
					["maps_disp"] = {
						MAP.ARATHI_HIGHLANDS,
						MAP.DUSTWALLOW_MARSH,
						MAP.THE_HINTERLANDS,
						MAP.WETLANDS,
						MAP.ALTERAC_MOUNTAINS,
						MAP.DESOLACE,
						MAP.FERALAS,
						MAP.HILLSBRAD_FOOTHILLS,
						MAP.STRANGLETHORN_VALE,
						MAP.SWAMP_OF_SORROWS,
						MAP.WESTERN_PLAGUELANDS,
					},
					["provider"] = { "o", 2041 },	-- Liferoot
				}),
				i(785, {	-- Mageroyal
					["maps_disp"] = {
						MAP.DARKSHORE,
						MAP.LOCH_MODAN,
						MAP.SILVERPINE_FOREST,
						MAP.TELDRASSIL,
						MAP.WESTFALL,
						MAP.WETLANDS,
						MAP.ASHENVALE,
						MAP.REDRIDGE_MOUNTAINS,
					},
					["providers"] = {
						{ "o", 1620 },	-- Mageroyal
						{ "o", 3727 },	-- Mageroyal (The Barrens)
					},
				}),
				i(13465, {	-- Mountain Silversage
					["maps_disp"] = {
						MAP.AZSHARA,
						MAP.BURNING_STEPPES,
						MAP.EASTERN_PLAGUELANDS,
						MAP.ZULGURUB,
						MAP.FELWOOD,
						MAP.SILITHUS,
						MAP.UNGORO_CRATER,
						MAP.WINTERSPRING,
					},
					["providers"] = {
						{ "o", 176586 },	-- Mountain Silversage
						{ "o", 176640 },	-- Mountain Silversage (Felwood)
						{ "o", 180166 },	-- Mountain Silversage (Zul'Gurub)
					},
				}),
				i(2447, {	-- Peacebloom
					["maps_disp"] = {
						MAP.DARKSHORE,
						MAP.DUN_MOROGH,
						MAP.DUROTAR,
						MAP.ELWYNN_FOREST,
						MAP.LOCH_MODAN,
						MAP.MULGORE,
						MAP.SILVERPINE_FOREST,
						MAP.TELDRASSIL,
						MAP.TIRISFAL_GLADES,
						MAP.WESTFALL,
					},
					["providers"] = {
						{ "o", 1618 },	-- Peacebloom
						{ "o", 3724 },	-- Peacebloom (The Barrens)
					},
				}),
				i(8831, {	-- Purple Lotus
					["maps_disp"] = {
						MAP.AZSHARA,
						MAP.FERALAS,
						MAP.STRANGLETHORN_VALE,
						MAP.TANARIS,
						MAP.THE_HINTERLANDS,
						MAP.ZULGURUB,
					},
					["providers"] = {
						{ "o", 142140 },	-- Purple Lotus
						{ "o", 180165 },	-- Purple Lotus (Zul'Gurub)
					},
				}),
				i(765, {	-- Silverleaf
					["maps_disp"] = {
						MAP.DARKSHORE,
						MAP.DUN_MOROGH,
						MAP.DUROTAR,
						MAP.ELWYNN_FOREST,
						MAP.LOCH_MODAN,
						MAP.MULGORE,
						MAP.SILVERPINE_FOREST,
						MAP.TELDRASSIL,
						MAP.TIRISFAL_GLADES,
						MAP.WESTFALL,
					},
					["providers"] = {
						{ "o", 1617 },	-- Silverleaf
						{ "o", 3725 },	-- Silverleaf (The Barrens)
					},
				}),
				i(13466, {	-- Sorrowmoss [CATA+] / Plaguebloom
					["maps_disp"] = {
						MAP.EASTERN_PLAGUELANDS,
						MAP.FELWOOD,
						MAP.WESTERN_PLAGUELANDS,
					},
					["providers"] = {
						{ "o", 176587 },	-- Sorrowmoss [CATA+] / Plaguebloom
						{ "o", 176641 },	-- Plaguebloom (Felwood)
					},
				}),
				i(3820, {	-- Stranglekelp
					["maps_disp"] = {
						MAP.ASHENVALE,
						MAP.DARKSHORE,
						MAP.DUSTWALLOW_MARSH,
						MAP.HILLSBRAD_FOOTHILLS,
						MAP.SILVERPINE_FOREST,
						MAP.SWAMP_OF_SORROWS,
						MAP.THE_HINTERLANDS,
						MAP.WESTFALL,
						MAP.WETLANDS,
						MAP.AZSHARA,
						MAP.DESOLACE,
						MAP.STRANGLETHORN_VALE,
						MAP.THE_BARRENS,
					},
					["provider"] = { "o", 2045 },	-- Stranglekelp
				}),
				i(8838, {	-- Sungrass
					["maps_disp"] = {
						MAP.AZSHARA,
						MAP.BLASTED_LANDS,
						MAP.FERALAS,
						MAP.THE_HINTERLANDS,
						MAP.UNGORO_CRATER,
						MAP.WESTERN_PLAGUELANDS,
						MAP.EASTERN_PLAGUELANDS,
					},
					["providers"] = {
						{ "o", 142142 },	-- Sungrass
						{ "o", 176636 },	-- Sungrass (Felwood)
						{ "o", 180164 },	-- Sungrass (Zul'Gurub)
					},
				}),
				i(2452, {	-- Swiftthistle
					["maps_disp"] = {
						MAP.DARKSHORE,
						MAP.DUSKWOOD,
						MAP.HILLSBRAD_FOOTHILLS,
						MAP.LOCH_MODAN,
						MAP.SILVERPINE_FOREST,
						MAP.STONETALON_MOUNTAINS,
						MAP.TELDRASSIL,
						MAP.WESTFALL,
						MAP.WETLANDS,
						MAP.ASHENVALE,
						MAP.REDRIDGE_MOUNTAINS,
						MAP.THE_BARRENS,
					},
					["providers"] = {
						{ "o", 1621 },	-- Briarthorn
						{ "o", 1620 },	-- Mageroyal
						{ "o", 3729 },	-- Briarthorn (The Barrens)
						{ "o", 3727 },	-- Mageroyal (The Barrens)
					},
				}),
				i(3355, {	-- Wild Steelbloom
					["maps_disp"] = {
						MAP.STRANGLETHORN_VALE,
						MAP.THOUSAND_NEEDLES,
						MAP.ARATHI_HIGHLANDS,
						MAP.STONETALON_MOUNTAINS,
						MAP.WETLANDS,
					},
					["provider"] = { "o", 1623 },	-- Wild Steelbloom
				}),
				i(8153, {	-- Wildvine
					["provider"] = { "o", 142140 },	-- Purple Lotus
				}),
			})),
			filter(MISC, {
				i(11020, bubbleDownSelf({ ["timeline"] = { REMOVED_4_0_3 } }, {	-- Evergreen Pouch
					["cost"] = {
						{ "i", 11018, 2 },	-- Un'Goro Soil
						{ "i", 11022, 1 },	-- Packet of Tharlendris Seeds
					},
					["groups"] = {
						i(11024, {	-- Evergreen Herb Casing
							i(11040),	-- Morrowgrain
						}),
					},
				})),
			}),
		},
	}),
	prof(LEATHERWORKING, {
		n(COMMON_VENDOR_ITEMS, {
			["groups"] = appendAllGroups(
				{
					i(4289, {	-- Salt
						["description"] = "Can be bought from Leatherworking Suppliers, as well as some Trade vendors around the world.",
						-- Danny Donkey: Disabling this for now, Common Vendor Items is being filled into Minilists when providers are given.
						--[[["providers"] = {
							{ "n", 5128},	-- Bombus Finespindle <Leatherworking Supplies>
							{ "n", 5565},	-- Jillian Tanner <Leatherworking Supplies>
							{ "n", 4589},	-- Joseph Moore <Leatherworking Supplies>
							{ "n", 4225},	-- Saenorion <Leatherworking Supplies>
							{ "n", 3366},	-- Tamar <Leatherworking Supplies>
							{ "n", 3005},	-- Mahu <Tailoring Supplies> [CATA+] / <Leatherworking & Tailoring Supplies>
						},]]
					}),
				},
				sharedData({
					["description"] = "Can be bought from Leatherworking- and Tailoring Suppliers, as well as some Trade vendors around the world.",
					-- Danny Donkey: Disabling this for now, Common Vendor Items is being filled into Minilists when providers are given.
					--[[["providers"] = {
						{ "n", 1347},	-- Alexandra Bolero <Tailoring Supplies>
						{ "n", 5128},	-- Bombus Finespindle <Leatherworking Supplies>
						{ "n", 3364},	-- Borya <Tailoring Supplies>
						{ "n", 4168},	-- Elynna <Tailoring Supplies>
						{ "n", 5565},	-- Jillian Tanner <Leatherworking Supplies>
						{ "n", 4589},	-- Joseph Moore <Leatherworking Supplies>
						{ "n", 3005},	-- Mahu <Tailoring Supplies> [CATA+] / <Leatherworking & Tailoring Supplies>
						{ "n", 4577},	-- Millie Gregorian <Tailoring Supplies>
						{ "n", 8681},	-- Outfitter Eric <Speciality Tailoring Supplies>
						{ "n", 5154},	-- Poranna Snowbraid <Tailoring Supplies>
						{ "n", 4225},	-- Saenorion <Leatherworking Supplies>
						{ "n", 3366},	-- Tamar <Leatherworking Supplies>
					},]]
				}, {
					i(2325),	-- Black Dye
					i(6260),	-- Blue Dye
					i(2605),	-- Green Dye
					i(4340),	-- Grey Dye
					i(4342),	-- Purple Dye
					i(2604),	-- Red Dye
					i(2320),	-- Coarse Thread
					i(2321),	-- Fine Thread
					i(4291),	-- Silken Thread
					i(8343),	-- Heavy Silken Thread
					i(14341),	-- Rune Thread
				})
			)
		}),
		-- #if BEFORE TBC
		prof(10656, {	-- Dragonscale Leatherworking
			["description"] = "These items can only be crafted by Leatherworkers who have completed the associated quest.",
			["groups"] = {
				i(16984),	-- Black Dragonscale Boots
				i(15050, {	-- Black Dragonscale Breastplate
					-- #if SEASON_OF_DISCOVERY
					["timeline"] = { REMOVED_1_15_3 },
					-- #endif
				}),
				i(15052, {	-- Black Dragonscale Leggings
					-- #if SEASON_OF_DISCOVERY
					["timeline"] = { REMOVED_1_15_3 },
					-- #endif
				}),
				i(15051, {	-- Black Dragonscale Shoulders
					-- #if SEASON_OF_DISCOVERY
					["timeline"] = { REMOVED_1_15_3 },
					-- #endif
				}),
				i(15048, {	-- Blue Dragonscale Breastplate
					["timeline"] = {
						REMOVED_4_0_3,
						ADDED_11_1_5,
					}
				}),
				i(20295),	-- Blue Dragonscale Leggings
				i(15049, {	-- Blue Dragonscale Shoulders
					["timeline"] = {
						REMOVED_4_0_3,
						ADDED_10_1_7,
					}
				}),
				-- #if SEASON_OF_DISCOVERY
				applyclassicphase(SOD_PHASE_FOUR, i(227869, {	-- Brilliant Chromatic Cloak
					["timeline"] = { ADDED_1_15_3 },
				})),
				-- #endif
				applyclassicphase(PHASE_ONE_DIREMAUL, i(18509, {	-- Chromatic Cloak
					["timeline"] = {
						-- #if SEASON_OF_DISCOVERY
						REMOVED_1_15_3,
						-- #else
						REMOVED_4_0_3,
						ADDED_10_1_5,
						-- #endif
					}
				})),
				applyclassicphase(PHASE_THREE_RECIPES, i(19157)),	-- Chromatic Gauntlets
				i(8367),	-- Dragonscale Breastplate
				i(8347, {	-- Dragonscale Gauntlets
					["timeline"] = {
						REMOVED_4_0_3,
					}
				}),
				applyclassicphase(PHASE_FOUR, i(20380, {	-- Dreamscale Breastplate
					["timeline"] = {
						REMOVED_4_0_3,
						ADDED_10_1_5,
					}
				})),
				-- #if SEASON_OF_DISCOVERY
				applyclassicphase(SOD_PHASE_FOUR, i(227851, {	-- Hardened Black Dragonscale Breastplate
					["timeline"] = { ADDED_1_15_3 },
				})),
				applyclassicphase(SOD_PHASE_FOUR, i(227852, {	-- Hardened Black Dragonscale Leggings
					["timeline"] = { ADDED_1_15_3 },
				})),
				applyclassicphase(SOD_PHASE_FOUR, i(227853, {	-- Hardened Black Dragonscale Shoulders
					["timeline"] = { ADDED_1_15_3 },
				})),
				-- #endif
				i(15045, {	-- Green Dragonscale Breastplate
					["timeline"] = {
						REMOVED_4_0_3,
						ADDED_4_3_0,
					}
				}),
				i(20296),	-- Green Dragonscale Gauntlets
				i(15046, {	-- Green Dragonscale Leggings
					["timeline"] = {
						REMOVED_4_0_3,
						ADDED_4_3_0,
					}
				}),
				i(15047, {	-- Red Dragonscale Breastplate
					["timeline"] = {
						REMOVED_6_0_2,
					}
				}),
				-- #if SEASON_OF_DISCOVERY
				applyclassicphase(SOD_PHASE_SIX, i(233803, { ["timeline"] = { ADDED_1_15_5 }, })),	-- Sharpened Chitin Armor Kit
				-- #endif
			},
		}),
		prof(10658, {	-- Elemental Leatherworking
			["description"] = "These items can only be crafted by Leatherworkers who have completed the associated quest.",
			["groups"] = {
				i(8346),	-- Gauntlets of the Sea
				-- #if SEASON_OF_DISCOVERY
				applyclassicphase(SOD_PHASE_SIX, i(233802, { ["timeline"] = { ADDED_1_15_5 }, })),	-- Glowing Chitin Armor Kit
				-- #endif
				i(8348),	-- Helm of Fire
				i(15059, {	-- Living Breastplate
					["timeline"] = {
						REMOVED_4_0_3,
						ADDED_10_1_7,
					}
				}),
				i(15060, {	-- Living Leggings
					["timeline"] = {
						REMOVED_4_0_3,
						ADDED_10_1_7,
					}
				}),
				i(15061),	-- Living Shoulders
				-- #if SEASON_OF_DISCOVERY
				applyclassicphase(SOD_PHASE_FOUR, i(227854, {	-- Mastercrafted Shifting Cloak
					["timeline"] = { ADDED_1_15_3 },
				})),
				applyclassicphase(SOD_PHASE_FOUR, i(227868, {	-- Masterwork Volcanic Breastplate
					["timeline"] = { ADDED_1_15_3 },
				})),
				applyclassicphase(SOD_PHASE_FOUR, i(227867, {	-- Masterwork Volcanic Leggings
					["timeline"] = { ADDED_1_15_3 },
				})),
				applyclassicphase(SOD_PHASE_FOUR, i(227866, {	-- Masterwork Volcanic Shoulders
					["timeline"] = { ADDED_1_15_3 },
				})),
				-- #endif
				applyclassicphase(PHASE_THREE_RECIPES, i(19163)),	-- Molten Belt
				i(16983),	-- Molten Helm
				applyclassicphase(PHASE_ONE_DIREMAUL, i(18511, {	-- Shifting Cloak
					["timeline"] = {
						-- #if SEASON_OF_DISCOVERY
						REMOVED_1_15_3,
						-- #else
						REMOVED_4_0_3,
						ADDED_10_1_5,
						-- #endif
					}
				})),
				i(15056, {	-- Stormshroud Armor
					["timeline"] = {
						REMOVED_4_0_3,
						ADDED_9_1_0,
					}
				}),
				i(21278, {	-- Stormshroud Gloves
					["timeline"] = {
						REMOVED_4_0_3,
						ADDED_9_1_0,
					}
				}),
				i(15057),	-- Stormshroud Pants
				i(15058, {	-- Stormshroud Shoulders
					["timeline"] = {
						REMOVED_4_0_3,
						ADDED_9_1_0,
					}
				}),
				i(15053, {	-- Volcanic Breastplate
					-- #if SEASON_OF_DISCOVERY
					["timeline"] = { REMOVED_1_15_3 },
					-- #endif
				}),
				i(15054, {	-- Volcanic Leggings
					["timeline"] = {
						-- #if SEASON_OF_DISCOVERY
						REMOVED_1_15_3,
						-- #else
						REMOVED_4_0_3, ADDED_10_1_7,
						-- #endif
					},
				}),
				i(15055, {	-- Volcanic Shoulders
					-- #if SEASON_OF_DISCOVERY
					["timeline"] = { REMOVED_1_15_3 },
					-- #endif
				}),
			},
		}),
		prof(10660, {	-- Tribal Leatherworking
			["description"] = "These items can only be crafted by Leatherworkers who have completed the associated quest.",
			["groups"] = {
				i(15073),	-- Chimeric Boots
				i(15074, {["timeline"] = { REMOVED_4_0_3, ADDED_11_1_5 }}),	-- Chimeric Gloves
				i(15072),	-- Chimeric Leggings
				i(15075),	-- Chimeric Vest
				applyclassicphase(PHASE_THREE_RECIPES, i(19162)),	-- Corehound Belt
				i(16982),	-- Corehound Boots
				i(15063),	-- Devilsaur Gauntlets
				i(15062),	-- Devilsaur Leggings
				i(8349),	-- Feathered Breastplate
				i(15071),	-- Frostsaber Boots
				i(15070, {["timeline"] = { REMOVED_6_0_2, ADDED_10_1_7 }}),	-- Frostsaber Gloves
				i(15069, {["timeline"] = { REMOVED_6_0_2, ADDED_10_1_7 }}),	-- Frostsaber Leggings
				i(15068, {["timeline"] = { REMOVED_6_0_2, ADDED_10_1_7 }}),	-- Frostsaber Tunic
				applyclassicphase(PHASE_ONE_DIREMAUL, i(18510, {["timeline"] = { REMOVED_4_0_3, ADDED_10_1_5 }})),	-- Hide of the Wild
				i(15066, {["timeline"] = { REMOVED_4_0_3, ADDED_10_1_7 }}),	-- Ironfeather Breastplate
				i(15067),	-- Ironfeather Shoulders
				-- #if SEASON_OF_DISCOVERY
				applyclassicphase(SOD_PHASE_SIX, i(233804, { ["timeline"] = { ADDED_1_15_5 }, })),	-- Razorbramble Shoulderpads
				applyclassicphase(SOD_PHASE_SIX, i(233813, { ["timeline"] = { ADDED_1_15_5 }, })),	-- Razorbramble Leathers
				applyclassicphase(SOD_PHASE_SIX, i(233808, { ["timeline"] = { ADDED_1_15_5 }, })),	-- Razorbramble Cowl
				-- #endif
				i(15064),	-- Warbear Harness
				i(15065),	-- Warbear Woolies
				i(8345, {["timeline"] = { REMOVED_4_0_3 }}),	-- Wolfshead Helm
			},
		}),
		-- #endif
		n(ARMOR, {
			n(BACK, {
				i(8216),	-- Big Voodoo Cloak
				i(7283),	-- Black Whelp Cloak
				i(2316),	-- Dark Leather Cloak
				i(6466, {["timeline"] = { REMOVED_4_0_3, ADDED_10_1_5 }}),	-- Deviate Scale Cloak
				i(2310),	-- Embossed Leather Cloak
				i(2308),	-- Fine Leather Cloak
				i(7377),	-- Frost Leather Cloak
				i(5965),	-- Guardian Cloak
				i(7276),	-- Handstitched Leather Cloak
				i(3719),	-- Hillman's Cloak
				i(15138),	-- Onyxia Scale Cloak
				i(8215, {["timeline"] = { REMOVED_4_0_3 }}),	-- Wild Leather Cloak

				-- #if AFTER TBC
				-- #if SEASON_OF_DISCOVERY
				applyclassicphase(SOD_PHASE_FOUR, i(227869, {	-- Brilliant Chromatic Cloak
					["timeline"] = { ADDED_1_15_3 },
				})),
				-- #endif
				applyclassicphase(PHASE_ONE_DIREMAUL, i(18509, {	-- Chromatic Cloak
					["timeline"] = {
						-- #if SEASON_OF_DISCOVERY
						REMOVED_1_15_3,
						-- #else
						REMOVED_4_0_3,
						ADDED_10_1_5,
						-- #endif
					}
				})),
				applyclassicphase(PHASE_ONE_DIREMAUL, i(18510, {	-- Hide of the Wild
					["timeline"] = {
						REMOVED_4_0_3, ADDED_10_1_5
					},
				})),
				applyclassicphase(PHASE_ONE_DIREMAUL, i(18511, {	-- Shifting Cloak
					["timeline"] = {
						-- #if SEASON_OF_DISCOVERY
						REMOVED_1_15_3,
						-- #else
						REMOVED_4_0_3,
						ADDED_10_1_5,
						-- #endif
					}
				})),
				-- #endif
			}),
			filter(LEATHER, {
				i(203799, {["timeline"] = { ADDED_10_0_7 }}),	-- Animist's Footwraps
				i(203794, {["timeline"] = { ADDED_10_0_7 }}),	-- Animist's Legguards
				i(4264),	-- Barbaric Belt
				i(18948),	-- Barbaric Bracers
				i(4254),	-- Barbaric Gloves
				i(5739),	-- Barbaric Harness
				i(5963),	-- Barbaric Leggings
				i(5964),	-- Barbaric Shoulders
				-- #if SEASON_OF_DISCOVERY
				applyclassicphase(SOD_PHASE_TWO, i(217259, {	-- Big Voodoo Mask
					["timeline"] = { ADDED_1_15_1 },
				})),
				-- #endif
				i(8201),	-- Big Voodoo Mask
				i(8202),	-- Big Voodoo Pants
				-- #if SEASON_OF_DISCOVERY
				applyclassicphase(SOD_PHASE_TWO, i(217261, {	-- Big Voodoo Robe
					["timeline"] = { ADDED_1_15_1 },
				})),
				-- #endif
				i(8200),	-- Big Voodoo Robe
				i(20575),	-- Black Whelp Tunic
				applyclassicphase(PHASE_FOUR, i(19688, {["timeline"] = { REMOVED_4_0_3, ADDED_10_0_7 }})),	-- Blood Tiger Breastplate
				applyclassicphase(PHASE_FOUR, i(19689, {["timeline"] = { REMOVED_4_0_3, ADDED_10_0_7 }})),	-- Blood Tiger Shoulders
				applyclassicphase(PHASE_FIVE_CATCH_UP, i(22761)),	-- Bramblewood Belt
				applyclassicphase(PHASE_FIVE_CATCH_UP, i(22760)),	-- Bramblewood Boots
				applyclassicphase(PHASE_FIVE_CATCH_UP, i(22759)),	-- Bramblewood Helm
				i(8174),	-- Comfortable Leather Hat
				i(4249),	-- Dark Leather Belt
				i(2315),	-- Dark Leather Boots
				i(4248),	-- Dark Leather Gloves
				i(5961),	-- Dark Leather Pants
				i(4252),	-- Dark Leather Shoulders
				i(2317),	-- Dark Leather Tunic
				applyclassicphase(PHASE_THREE_RECIPES, i(19052)),	-- Dawn Treaders
				i(6468, {["timeline"] = { REMOVED_4_0_3, ADDED_10_1_5 }}),	-- Deviate Scale Belt
				i(6467, {["timeline"] = { REMOVED_4_0_3, ADDED_10_1_5 }}),	-- Deviate Scale Gloves
				i(206509, {["timeline"] = { ADDED_10_1_5 }}),	-- Displacement Boots
				i(7387),	-- Dusky Belt
				i(7390),	-- Dusky Boots
				i(7378),	-- Dusky Bracers
				i(7374),	-- Dusky Leather Armor
				i(7373),	-- Dusky Leather Leggings
				i(2309),	-- Embossed Leather Boots
				i(4239),	-- Embossed Leather Gloves
				i(4242),	-- Embossed Leather Pants
				i(2300),	-- Embossed Leather Vest
				i(7352),	-- Earthen Leather Shoulders
				i(4246),	-- Fine Leather Belt
				i(2307),	-- Fine Leather Boots
				i(2312),	-- Fine Leather Gloves
				i(5958),	-- Fine Leather Pants
				i(4243),	-- Fine Leather Tunic
				i(4262),	-- Gem-Studded Leather Belt
				-- #if SEASON_OF_DISCOVERY
				applyclassicphase(SOD_PHASE_FOUR, i(227882, {	-- Girdle of Arcane Insight
					["timeline"] = { ADDED_1_15_3 },
				})),
				-- #endif
				applyclassicphase(PHASE_ONE_DIREMAUL, i(18504, {	-- Girdle of Insight
					["timeline"] = {
						-- #if SEASON_OF_DISCOVERY
						REMOVED_1_15_3,
						-- #else
						REMOVED_4_0_3,
						ADDED_10_1_5,
						-- #endif
					}
				})),
				i(17721),	-- Gloves of the Greatfather
				applyclassicphase(PHASE_THREE_RECIPES, i(19058)),	-- Golden Mantle of the Dawn
				i(4255),	-- Green Leather Armor
				i(4257),	-- Green Leather Belt
				i(4259),	-- Green Leather Bracers
				i(7375),	-- Green Whelp Armor
				i(7386),	-- Green Whelp Bracers
				i(4256),	-- Guardian Armor
				-- #if SEASON_OF_DISCOVERY
				applyclassicphase(SOD_PHASE_TWO, i(217265, {	-- Guardian Belt
					["timeline"] = { ADDED_1_15_1 },
				})),
				-- #endif
				i(4258),	-- Guardian Belt
				i(5966),	-- Guardian Gloves
				-- #if SEASON_OF_DISCOVERY
				applyclassicphase(SOD_PHASE_TWO, i(217263, {	-- Guardian Leather Bracers
					["timeline"] = { ADDED_1_15_1 },
				})),
				-- #endif
				i(4260),	-- Guardian Leather Bracers
				-- #if SEASON_OF_DISCOVERY
				applyclassicphase(SOD_PHASE_TWO, i(217267, {	-- Guardian Pants
					["timeline"] = { ADDED_1_15_1 },
				})),
				-- #endif
				i(5962),	-- Guardian Pants
				i(4237),	-- Handstitched Leather Belt
				i(2302),	-- Handstitched Leather Boots
				i(7277),	-- Handstitched Leather Bracers
				i(2303),	-- Handstitched Leather Pants
				i(5957),	-- Handstitched Leather Vest
				i(7359),	-- Heavy Earthen Gloves
				i(7349),	-- Herbalist's Gloves
				i(4250),	-- Hillman's Belt
				i(4247),	-- Hillman's Leather Gloves
				i(4244),	-- Hillman's Leather Vest
				i(4251),	-- Hillman's Shoulders
				applyclassicphase(PHASE_THREE_RECIPES, i(19149)),	-- Lava Belt
				i(7281),	-- Light Leather Bracers
				i(7282),	-- Light Leather Pants
				i(206514, {["timeline"] = { ADDED_10_1_5 }}),	-- Lucien's Lost Soles
				-- #if SEASON_OF_DISCOVERY
				applyclassicphase(SOD_PHASE_THREE, i(220745, {	-- Membrane of Dark Neurosis
					["timeline"] = { ADDED_1_15_2 },
				})),
				-- #endif
				applyclassicphase(PHASE_THREE_RECIPES, i(19044)),	-- Might of the Timbermaw
				applyclassicphase(PHASE_ONE_DIREMAUL, i(18506, {["timeline"] = { REMOVED_4_0_3, ADDED_10_1_5 }})),	-- Mongoose Boots
				i(6709),	-- Moonglow Vest
				i(5780),	-- Murloc Scale Belt
				i(5783),	-- Murloc Scale Bracers
				i(5781),	-- Murloc Scale Breastplate
				i(8197),	-- Nightscape Boots
				i(8176),	-- Nightscape Headband
				i(8193),	-- Nightscape Pants
				i(8192),	-- Nightscape Shoulders
				i(8175),	-- Nightscape Tunic
				i(7285),	-- Nimble Leather Gloves
				-- #if SEASON_OF_DISCOVERY
				applyclassicphase(SOD_PHASE_THREE, i(220747, {	-- Paranoia Mantle
					["timeline"] = { ADDED_1_15_2 },
				})),
				-- #endif
				i(7358),	-- Pilferer's Gloves
				i(206435, {["timeline"] = { ADDED_10_1_5 }}),	-- Polar Belt
				applyclassicphase(PHASE_SIX, i(22663, {["timeline"] = { ADDED_1_11_1, REMOVED_3_0_2, ADDED_10_1_5 }})),	-- Polar Bracers
				i(206436, {["timeline"] = { ADDED_10_1_5 }}),	-- Polar Footwarmers
				applyclassicphase(PHASE_SIX, i(22662, {["timeline"] = { ADDED_1_11_1, REMOVED_3_0_2, ADDED_10_1_5 }})),	-- Polar Gloves
				i(206434, {["timeline"] = { ADDED_10_1_5 }}),	-- Polar Helm
				i(206432, {["timeline"] = { ADDED_10_1_5 }}),	-- Polar Leggings
				i(206433, {["timeline"] = { ADDED_10_1_5 }}),	-- Polar Spaulders
				applyclassicphase(PHASE_SIX, i(22661, {["timeline"] = { ADDED_1_11_1, REMOVED_3_0_2, ADDED_10_1_5 }})),	-- Polar Tunic
				applyclassicphase(PHASE_FOUR, i(19687, {["timeline"] = { REMOVED_4_0_3, ADDED_10_0_7 }})),	-- Primal Batskin Bracers
				applyclassicphase(PHASE_FOUR, i(19686, {["timeline"] = { REMOVED_4_0_3, ADDED_10_0_7 }})),	-- Primal Batskin Gloves
				applyclassicphase(PHASE_FOUR, i(19685, {["timeline"] = { REMOVED_4_0_3, ADDED_10_0_7 }})),	-- Primal Batskin Jerkin
				i(4456, {	-- Raptor Hide Belt
					["races"] = ALLIANCE_ONLY,
				}),
				i(4455, {	-- Raptor Hide Harness
					["races"] = HORDE_ONLY,
				}),
				i(7284),	-- Red Whelp Gloves
				i(7280),	-- Rugged Leather Pants
				i(15090),	-- Runic Leather Armor
				i(15093),	-- Runic Leather Belt
				i(15092),	-- Runic Leather Bracers
				i(15091),	-- Runic Leather Gauntlets
				i(15094),	-- Runic Leather Headband
				i(15095),	-- Runic Leather Pants
				i(15096),	-- Runic Leather Shoulders
				i(207565, {["timeline"] = { ADDED_10_1_5 }}),	-- Sanctified Leather Hat
				i(18238),	-- Shadowskin Gloves
				-- #if SEASON_OF_DISCOVERY
				applyclassicphase(SOD_PHASE_SEVEN, i(238272, { ["timeline"] = { ADDED_1_15_6 }})),	-- Scarlet Infiltrator's Bandana
				applyclassicphase(SOD_PHASE_SEVEN, i(238273, { ["timeline"] = { ADDED_1_15_6 }})),	-- Scarlet Infiltrator's Shoulderpads
				applyclassicphase(SOD_PHASE_SEVEN, i(238274, { ["timeline"] = { ADDED_1_15_6 }})),	-- Scarlet Infiltrator's Vest
				applyclassicphase(SOD_PHASE_SEVEN, i(238275, { ["timeline"] = { ADDED_1_15_6 }})),	-- Scarlet Infiltrator's Bracers
				applyclassicphase(SOD_PHASE_SEVEN, i(238276, { ["timeline"] = { ADDED_1_15_6 }})),	-- Scarlet Infiltrator's Gloves
				applyclassicphase(SOD_PHASE_SEVEN, i(238277, { ["timeline"] = { ADDED_1_15_6 }})),	-- Scarlet Infiltrator's Belt
				applyclassicphase(SOD_PHASE_SEVEN, i(238278, { ["timeline"] = { ADDED_1_15_6 }})),	-- Scarlet Infiltrator's Trousers
				applyclassicphase(SOD_PHASE_SEVEN, i(238279, { ["timeline"] = { ADDED_1_15_6 }})),	-- Scarlet Infiltrator's Shoes
				applyclassicphase(SOD_PHASE_THREE, i(220748, {	-- Shoulderpads of Obsession
					["timeline"] = { ADDED_1_15_2 },
				})),
				-- #endif
				i(7391),	-- Swift Boots
				i(5782),	-- Thick Murloc Armor
				applyclassicphase(PHASE_THREE_RECIPES, i(19049)),	-- Timbermaw Brawlers
				i(2314),	-- Toughened Leather Armor
				i(4253),	-- Toughened Leather Gloves
				-- #if SEASON_OF_DISCOVERY
				applyclassicphase(SOD_PHASE_ONE, i(211502, {	-- Void-Touched Leather Gauntlets
					["timeline"] = { ADDED_1_15_0 },
					["requireSkill"] = LEATHERWORKING,
				})),
				applyclassicphase(SOD_PHASE_ONE, i(211423, {	-- Void-Touched Leather Gloves
					["timeline"] = { ADDED_1_15_0 },
					["requireSkill"] = LEATHERWORKING,
				})),
				-- #endif
				i(2311),	-- White Leather Jerkin
				i(15085),	-- Wicked Leather Armor
				i(15088),	-- Wicked Leather Belt
				i(15084),	-- Wicked Leather Bracers
				i(15083),	-- Wicked Leather Gauntlets
				i(15086),	-- Wicked Leather Headband
				i(15087),	-- Wicked Leather Pants
				i(8213, {["timeline"] = { REMOVED_4_0_3 }}),	-- Wild Leather Boots
				i(8214, {["timeline"] = { REMOVED_4_0_3 }}),	-- Wild Leather Helmet
				i(8212, {["timeline"] = { REMOVED_4_0_3 }}),	-- Wild Leather Leggings
				i(8210, {["timeline"] = { REMOVED_4_0_3 }}),	-- Wild Leather Shoulders
				i(8211, {["timeline"] = { REMOVED_4_0_3 }}),	-- Wild Leather Vest

				-- #if AFTER TBC
				-- Tribal
				i(15073),	-- Chimeric Boots
				i(15074, {["timeline"] = { REMOVED_4_0_3, ADDED_11_1_5 }}),	-- Chimeric Gloves
				i(15072),	-- Chimeric Leggings
				i(15075),	-- Chimeric Vest
				applyclassicphase(PHASE_THREE_RECIPES, i(19162)),	-- Corehound Belt
				i(16982),	-- Corehound Boots
				i(15063),	-- Devilsaur Gauntlets
				i(15062),	-- Devilsaur Leggings
				i(8349),	-- Feathered Breastplate
				i(15071),	-- Frostsaber Boots
				i(15070, {["timeline"] = { REMOVED_6_0_2, ADDED_10_1_7 }}),	-- Frostsaber Gloves
				i(15069, {["timeline"] = { REMOVED_6_0_2, ADDED_10_1_7 }}),	-- Frostsaber Leggings
				i(15068, {["timeline"] = { REMOVED_6_0_2, ADDED_10_1_7 }}),	-- Frostsaber Tunic
				i(15066, {["timeline"] = { REMOVED_4_0_3, ADDED_10_1_7 }}),	-- Ironfeather Breastplate
				i(15067),	-- Ironfeather Shoulders
				i(15064),	-- Warbear Harness
				i(15065),	-- Warbear Woolies
				i(8345, {["timeline"] = { REMOVED_4_0_3 }}),	-- Wolfshead Helm
				-- Ele
				i(8346),	-- Gauntlets of the Sea
				i(8348),	-- Helm of Fire
				i(15059, {["timeline"] = { REMOVED_4_0_3, ADDED_10_1_7 }}),	-- Living Breastplate
				i(15060, {["timeline"] = { REMOVED_4_0_3, ADDED_10_1_7 }}),	-- Living Leggings
				i(15061),	-- Living Shoulders
				-- #if SEASON_OF_DISCOVERY
				applyclassicphase(SOD_PHASE_FOUR, i(227868, {	-- Masterwork Volcanic Breastplate
					["timeline"] = { ADDED_1_15_3 },
				})),
				applyclassicphase(SOD_PHASE_FOUR, i(227867, {	-- Masterwork Volcanic Leggings
					["timeline"] = { ADDED_1_15_3 },
				})),
				applyclassicphase(SOD_PHASE_FOUR, i(227866, {	-- Masterwork Volcanic Shoulders
					["timeline"] = { ADDED_1_15_3 },
				})),
				-- #endif
				applyclassicphase(PHASE_THREE_RECIPES, i(19163)),	-- Molten Belt
				i(16983),	-- Molten Helm
				i(15056, {["timeline"] = { REMOVED_4_0_3, ADDED_9_1_0 }}),	-- Stormshroud Armor
				i(21278, {["timeline"] = { REMOVED_4_0_3, ADDED_9_1_0 }}),	-- Stormshroud Gloves
				i(15057),	-- Stormshroud Pants
				i(15058, {["timeline"] = { REMOVED_4_0_3, ADDED_9_1_0 }}),	-- Stormshroud Shoulders
				i(15053, {	-- Volcanic Breastplate
					-- #if SEASON_OF_DISCOVERY
					["timeline"] = { REMOVED_1_15_3 },
					-- #endif
				}),
				i(15054, {	-- Volcanic Leggings
					["timeline"] = {
						-- #if SEASON_OF_DISCOVERY
						REMOVED_1_15_3,
						-- #else
						REMOVED_4_0_3, ADDED_10_1_7,
						-- #endif
					},
				}),
				i(15055, {	-- Volcanic Shoulders
					-- #if SEASON_OF_DISCOVERY
					["timeline"] = { REMOVED_1_15_3 },
					-- #endif
				}),
				-- #endif

				-- #if AFTER CATA
				applyclassicphase(TBC_PHASE_ONE, i(29964, {["requireSkill"] = LEATHERWORKING, ["timeline"] = { ADDED_2_0_5 }})),	-- Blackstorm Leggings
				applyclassicphase(TBC_PHASE_ONE, i(29970, {["requireSkill"] = LEATHERWORKING, ["timeline"] = { ADDED_2_0_5 }})),	-- Wildfeather Leggings
				-- #endif

				-- #if SEASON_OF_DISCOVERY
				applyclassicphase(SOD_PHASE_TWO, i(215166, {	-- Glowing Gneuro-Linked Cowl
					["timeline"] = { ADDED_1_15_1 },
					["requireSkill"] = LEATHERWORKING,
				})),
				applyclassicphase(SOD_PHASE_TWO, i(215381, {	-- Gneuro-Conductive Channeler's Hood
					["timeline"] = { ADDED_1_15_1 },
					["requireSkill"] = LEATHERWORKING,
				})),
				-- #endif
			}),
			filter(MAIL, {
				i(132547, {["timeline"] = { ADDED_7_0_3 }}),	-- Blue Chain Leggings
				-- #if SEASON_OF_DISCOVERY
				applyclassicphase(SOD_PHASE_THREE, i(220743, {	-- Cacophonous Chain Shoulderguards
					["timeline"] = { ADDED_1_15_2 },
				})),
				-- #endif
				i(132495, {["timeline"] = { ADDED_7_0_3 }}),	-- Chain Belt
				i(132494, {["timeline"] = { ADDED_7_0_3 }}),	-- Chain Boots
				i(132496, {["timeline"] = { ADDED_7_0_3 }}),	-- Chain Bracers
				i(132499, {["timeline"] = { ADDED_7_0_3 }}),	-- Chain Gauntlets
				i(132493, {["timeline"] = { ADDED_7_0_3 }}),	-- Chain Hauberk
				i(132497, {["timeline"] = { ADDED_7_0_3 }}),	-- Chain Leggings
				i(132498, {["timeline"] = { ADDED_7_0_3 }}),	-- Chain Pauldrons
				i(203966, {["timeline"] = { ADDED_10_0_7 }}),	-- Cord of Shriveled Heads
				i(132545, {["timeline"] = { ADDED_7_0_3 }}),	-- Crackling Scale Breastplate
				i(132546, {["timeline"] = { ADDED_7_0_3 }}),	-- Element Grips
				i(7348),	-- Fletcher's Gloves
				i(203819, {["timeline"] = { ADDED_10_0_7 }}),	-- Gloves of the Tormentor
				i(132522, {["timeline"] = { ADDED_7_0_3 }}),	-- Heavy Scale Belt
				i(132521, {["timeline"] = { ADDED_7_0_3 }}),	-- Heavy Scale Boots
				i(132533, {["timeline"] = { ADDED_7_0_3 }}),	-- Heavy Scale Gauntlets
				i(132536, {["timeline"] = { ADDED_7_0_3 }}),	-- Heavy Scale Hood
				i(132532, {["timeline"] = { ADDED_7_0_3 }}),	-- Heavy Scale Pants
				i(132535, {["timeline"] = { ADDED_7_0_3 }}),	-- Heavy Scale Pauldrons
				i(132520, {["timeline"] = { ADDED_7_0_3 }}),	-- Heavy Scale Shirt
				i(132534, {["timeline"] = { ADDED_7_0_3 }}),	-- Heavy Scale Wraps
				i(15082),	-- Heavy Scorpid Belt
				i(15077),	-- Heavy Scorpid Bracers
				i(15078, {["timeline"] = { ADDED_1_11_1, REMOVED_4_0_3, ADDED_10_0_5 }}),	-- Heavy Scorpid Gauntlets
				i(15079, {["timeline"] = { ADDED_1_11_1, REMOVED_4_0_3, ADDED_10_0_5 }}),	-- Heavy Scorpid Leggings
				i(15080),	-- Heavy Scorpid Helm
				i(15081, {["timeline"] = { ADDED_1_11_1, REMOVED_4_0_3, ADDED_5_0_4, REMOVED_6_0_2, ADDED_10_0_5 }}),	-- Heavy Scorpid Shoulders
				i(15076, {["timeline"] = { ADDED_1_11_1, REMOVED_4_0_3, ADDED_10_0_5 }}),	-- Heavy Scorpid Vest
				i(206482, {["timeline"] = { ADDED_10_1_5 }}),	-- Helm of Lingering Power
				applyclassicphase(PHASE_SIX, i(22665, {["timeline"] = { ADDED_1_11_1, REMOVED_3_0_2, ADDED_10_1_5 }})),	-- Icy Scale Bracers
				applyclassicphase(PHASE_SIX, i(22664, {["timeline"] = { ADDED_1_11_1, REMOVED_3_0_2, ADDED_10_1_5 }})),	-- Icy Scale Breastplate
				i(206439, {["timeline"] = { ADDED_10_1_5 }}),	-- Icy Scale Crown
				applyclassicphase(PHASE_SIX, i(22666, {["timeline"] = { ADDED_1_11_1, REMOVED_3_0_2, ADDED_10_1_5 }})),	-- Icy Scale Gauntlets
				i(206437, {["timeline"] = { ADDED_10_1_5 }}),	-- Icy Scale Leggings
				i(206438, {["timeline"] = { ADDED_10_1_5 }}),	-- Icy Scale Shoulderpads
				i(206441, {["timeline"] = { ADDED_10_1_5 }}),	-- Icy Scale Stompers
				i(206440, {["timeline"] = { ADDED_10_1_5 }}),	-- Icy Scale Waistwrap
				i(203814, {["timeline"] = { ADDED_10_0_7 }}),	-- Junglefury Gauntlets
				i(203816, {["timeline"] = { ADDED_10_0_7 }}),	-- Junglefury Leggings
				i(132489, {["timeline"] = { ADDED_7_0_3 }}),	-- Light Scale Belt
				i(132488, {["timeline"] = { ADDED_7_0_3 }}),	-- Light Scale Boots
				i(132491, {["timeline"] = { ADDED_7_0_3 }}),	-- Light Scale Bracers
				i(132490, {["timeline"] = { ADDED_7_0_3 }}),	-- Light Scale Gloves
				i(132487, {["timeline"] = { ADDED_7_0_3 }}),	-- Light Scale Jerkin
				i(132492, {["timeline"] = { ADDED_7_0_3 }}),	-- Light Scale Pants
				applyclassicphase(PHASE_FOUR, i(20476)),	-- Sandstalker Bracers
				applyclassicphase(PHASE_FOUR, i(20478)),	-- Sandstalker Breastplate
				applyclassicphase(PHASE_FOUR, i(20477)),	-- Sandstalker Gauntlets
				-- #if SEASON_OF_DISCOVERY
				applyclassicphase(SOD_PHASE_SEVEN, i(238280, { ["timeline"] = { ADDED_1_15_6 }})),	-- Scarlet Huntsman's Coif
				applyclassicphase(SOD_PHASE_SEVEN, i(238281, { ["timeline"] = { ADDED_1_15_6 }})),	-- Scarlet Huntsman's Pauldrons
				applyclassicphase(SOD_PHASE_SEVEN, i(238282, { ["timeline"] = { ADDED_1_15_6 }})),	-- Scarlet Huntsman's Chain
				applyclassicphase(SOD_PHASE_SEVEN, i(238283, { ["timeline"] = { ADDED_1_15_6 }})),	-- Scarlet Huntsman's Wristguards
				applyclassicphase(SOD_PHASE_SEVEN, i(238284, { ["timeline"] = { ADDED_1_15_6 }})),	-- Scarlet Huntsman's Handguards
				applyclassicphase(SOD_PHASE_SEVEN, i(238285, { ["timeline"] = { ADDED_1_15_6 }})),	-- Scarlet Huntsman's Clasp
				applyclassicphase(SOD_PHASE_SEVEN, i(238286, { ["timeline"] = { ADDED_1_15_6 }})),	-- Scarlet Huntsman's Legguards
				applyclassicphase(SOD_PHASE_SEVEN, i(238287, { ["timeline"] = { ADDED_1_15_6 }})),	-- Scarlet Huntsman's Boots
				applyclassicphase(SOD_PHASE_THREE, i(220741, {	-- Screaming Chain Pauldrons
					["timeline"] = { ADDED_1_15_2 },
				})),
				-- #endif
				i(132548, {["timeline"] = { ADDED_7_0_3 }}),	-- Shamanic Treads
				-- #if SEASON_OF_DISCOVERY
				applyclassicphase(SOD_PHASE_THREE, i(220742, {	-- Shrieking Spaulders
					["timeline"] = { ADDED_1_15_2 },
				})),
				-- #endif
				i(206483, {["timeline"] = { ADDED_10_1_5 }}),	-- Skyfury Headdress
				i(132544, {["timeline"] = { ADDED_7_0_3 }}),	-- Spritescale Boots
				i(132542, {["timeline"] = { ADDED_7_0_3 }}),	-- Spritescale Britches
				i(132539, {["timeline"] = { ADDED_7_0_3 }}),	-- Spritescale Cinch
				i(132537, {["timeline"] = { ADDED_7_0_3 }}),	-- Spritescale Circlet
				i(132543, {["timeline"] = { ADDED_7_0_3 }}),	-- Spritescale Epaulets
				i(132540, {["timeline"] = { ADDED_7_0_3 }}),	-- Spritescale Gloves
				i(132538, {["timeline"] = { ADDED_7_0_3 }}),	-- Spritescale Jerkin
				i(132541, {["timeline"] = { ADDED_7_0_3 }}),	-- Spritescale Wraps
				applyclassicphase(PHASE_FOUR, i(20481)),	-- Spitfire Bracers
				applyclassicphase(PHASE_FOUR, i(20479)),	-- Spitfire Breastplate
				applyclassicphase(PHASE_FOUR, i(20480)),	-- Spitfire Gauntlets
				applyclassicphase(PHASE_ONE_DIREMAUL, i(18508, {	-- Swift Flight Bracers
					["timeline"] = {
						-- #if SEASON_OF_DISCOVERY
						REMOVED_1_15_3,
						-- #else
						REMOVED_4_0_3, ADDED_10_1_5,
						-- #endif
					},
				})),
				-- #if SEASON_OF_DISCOVERY
				applyclassicphase(SOD_PHASE_FOUR, i(227883, {	-- Swift Flight Vambraces
					["timeline"] = { ADDED_1_15_3 },
				})),
				-- #endif
				i(8209, {["timeline"] = { REMOVED_4_0_3, ADDED_4_3_0 }}),	-- Tough Scorpid Boots
				i(8205, {["timeline"] = { REMOVED_4_0_3, ADDED_4_3_0 }}),	-- Tough Scorpid Bracers
				i(8203, {["timeline"] = { REMOVED_4_0_3, ADDED_4_3_0 }}),	-- Tough Scorpid Breastplate
				i(8204, {["timeline"] = { REMOVED_4_0_3, ADDED_4_3_0 }}),	-- Tough Scorpid Gloves
				i(8208, {["timeline"] = { REMOVED_4_0_3, ADDED_4_3_0 }}),	-- Tough Scorpid Helm
				i(8206, {["timeline"] = { REMOVED_4_0_3, ADDED_4_3_0 }}),	-- Tough Scorpid Leggings
				i(8207, {["timeline"] = { REMOVED_4_0_3, ADDED_4_3_0 }}),	-- Tough Scorpid Shoulders
				i(8198),	-- Turtle Scale Bracers
				-- #if SEASON_OF_DISCOVERY
				applyclassicphase(SOD_PHASE_TWO, i(217268, {	-- Turtle Scale Breastplate
					["timeline"] = { ADDED_1_15_1 },
				})),
				-- #endif
				i(8189),	-- Turtle Scale Breastplate
				-- #if SEASON_OF_DISCOVERY
				applyclassicphase(SOD_PHASE_TWO, i(217270, {	-- Turtle Scale Gloves
					["timeline"] = { ADDED_1_15_1 },
				})),
				-- #endif
				i(8187),	-- Turtle Scale Gloves
				i(8191),	-- Turtle Scale Helm
				i(8185),	-- Turtle Scale Leggings
				-- #if SEASON_OF_DISCOVERY
				applyclassicphase(SOD_PHASE_THREE, i(220744, {	-- Wailing Chain Mantle
					["timeline"] = { ADDED_1_15_2 },
				})),
				-- #endif
				-- #if AFTER TBC
				-- DragonScale
				i(16984),	-- Black Dragonscale Boots
				i(15050),	-- Black Dragonscale Breastplate
				i(15052),	-- Black Dragonscale Leggings
				i(15051),	-- Black Dragonscale Shoulders
				i(15048, {["timeline"] = { REMOVED_4_0_3, ADDED_11_1_5 }}),	-- Blue Dragonscale Breastplate
				i(20295),	-- Blue Dragonscale Leggings
				i(15049, {["timeline"] = { REMOVED_4_0_3, ADDED_10_1_7 }}),	-- Blue Dragonscale Shoulders
				applyclassicphase(PHASE_THREE_RECIPES, i(19157)),	-- Chromatic Gauntlets
				i(8367),	-- Dragonscale Breastplate
				applyclassicphase(PHASE_FOUR, i(20380, {	-- Dreamscale Breastplate
					-- #if AFTER 4.0.3
					-- #if BEFORE 10.1.5
					["description"] = "While this recipe is still available, the mats required to craft it are not.",
					-- #endif
					-- #endif
					["timeline"] = { REMOVED_4_0_3, ADDED_10_1_5 },
				})),
				i(8347, {["timeline"] = { REMOVED_4_0_3 }}),	-- Dragonscale Gauntlets
				i(15045, {["timeline"] = { REMOVED_4_0_3, ADDED_4_3_0 }}),	-- Green Dragonscale Breastplate
				i(20296),	-- Green Dragonscale Gauntlets
				i(15046, {["timeline"] = { REMOVED_4_0_3, ADDED_4_3_0 }}),	-- Green Dragonscale Leggings
				i(15047, {["timeline"] = { REMOVED_6_0_2 }}),	-- Red Dragonscale Breastplate
				-- #endif
				-- #if AFTER CATA
				applyclassicphase(TBC_PHASE_ONE, i(29971, {["requireSkill"] = LEATHERWORKING, ["timeline"] = { ADDED_2_0_5 }})),	-- Dragonstrike Leggings
				-- #endif

				-- #if SEASON_OF_DISCOVERY
				applyclassicphase(SOD_PHASE_TWO, i(215114, {	-- Glowing Hyperconductive Scale Coif
					["timeline"] = { ADDED_1_15_1 },
					["requireSkill"] = LEATHERWORKING,
				})),
				applyclassicphase(SOD_PHASE_TWO, i(215382, {	-- Rad-Resistant Scale Hood
					["timeline"] = { ADDED_1_15_1 },
					["requireSkill"] = LEATHERWORKING,
				})),
				-- #endif
			}),
		}),
		filter(COSMETIC, {
			i(34086, {["timeline"] = {ADDED_2_3_0, REMOVED_7_3_2}}),	-- Winter Boots
			i(151791, {["timeline"] = {ADDED_7_3_2}}),	-- Winter Boots
		}),
		n(DECOR, sharedDataSelf({["timeline"] = { ADDED_11_2_7 }}, {
			i(257725),	-- Camp Narache Rug (DECOR!)
			i(242948),	-- Loch Modan Bearskin Rug (DECOR!)
		})),
		filter(MISC, {
			i(18251),	-- Core Armor Kit
			i(4236),	-- Cured Heavy Hide
			i(4231),	-- Cured Light Hide
			i(4233),	-- Cured Medium Hide
			i(15407),	-- Cured Rugged Hide
			i(8172),	-- Cured Thick Hide
			applyclassicphase(PHASE_ONE_DIREMAUL, i(18258, {["timeline"] = { REMOVED_4_0_3, ADDED_10_1_5 }})),	-- Gordok Ogre Suit
			i(4265),	-- Heavy Armor Kit
			i(4234),	-- Heavy Leather
			i(7372, {["timeline"] = { REMOVED_4_0_1 }}),	-- Heavy Leather Ammo Pouch
			i(18662),	-- Heavy Leather Ball
			i(7371, {["timeline"] = { REMOVED_4_0_1 }}),	-- Heavy Quiver
			i(5081),	-- Kodo Hide Bag
			i(206646, {["timeline"] = { ADDED_10_1_5 }}),	-- Languished Leather
			i(2304),	-- Light Armor Kit
			i(2318),	-- Light Leather
			i(7278, {["timeline"] = { REMOVED_4_0_1 }}),	-- Light Leather Quiver
			i(2313),	-- Medium Armor Kit
			i(2319),	-- Medium Leather
			i(8217, {["timeline"] = { REMOVED_4_0_1 }}),	-- Quickdraw Quiver
			i(15564),	-- Rugged Armor Kit
			i(8170),	-- Rugged Leather
			i(206647, {["timeline"] = { ADDED_10_1_5 }}),	-- Scourged Scales
			i(7279, {["timeline"] = { REMOVED_4_0_1 }}),	-- Small Leather Ammo Pouch
			i(8173),	-- Thick Armor Kit
			i(4304),	-- Thick Leather
			i(8218, {["timeline"] = { REMOVED_4_0_1 }}),	-- Thick Leather Ammo Pouch
		}),
		-- #if AFTER 10.0.7
		n(WEAPONS, {
			i(203805, {["timeline"] = { ADDED_10_0_7 }}),	-- Gurubashi's Grasp
			i(206491, {["timeline"] = { ADDED_10_1_5 }}),	-- Nerubian Persuader
		}),
		-- #endif
	}),
	prof(MINING, {
		["description"] = "Mining veins are usually found on uneven terrain and mountainsides as well as inside caves. It is beneficial to mine all veins in the area even if you only need specific ore because the node spawns are often connected.",
		["groups"] = {
			spell(2575, {	-- Mining
				["groups"] = appendAllGroups(
					sharedData({ ["requireSkill"] = MINING, }, {	-- Nodes:
						-- Copper
						o(1731, {	-- Copper Vein
							["maps"] = {
								MAP.DARKSHORE,
								MAP.DUN_MOROGH,
								MAP.DUROTAR,
								MAP.ELWYNN_FOREST,
								MAP.LOCH_MODAN,
								MAP.MULGORE,
								MAP.SILVERPINE_FOREST,
								MAP.TIRISFAL_GLADES,
								MAP.WESTFALL,
								MAP.THE_BARRENS,
							},
						}),
						o(2055, {	-- Copper Vein (Redridge Mountains - Rethban Ore)
						-- Note: This node reportedly was replaced by o(1731) with Cata during retail, but the same is not happening on classic Cata+
							["coord"] = { 20.7, 27.0, MAP.REDRIDGE_MOUNTAINS },	-- Rethban Caverns
						}),
						o(103713, {	-- Copper Vein (The Barrens - Horde only)
							-- Note: This node get removed at an unknown point between MOP and TWW.
							["coord"] = { 47.9, 87.2, MAP.THE_BARRENS },	-- Bael Modan Excavation
							["races"] = HORDE_ONLY,
						}),
						o(3763, {	-- Copper Vein (The Barrens - Blood Shard)
							-- Note: This node get replaced by o(1731) at an unknown point between MOP and TWW.
							["maps"] = {
								MAP.THE_BARRENS,
							},
						}),
						-- Dark Iron Ore
						o(165658, {	-- Dark Iron Deposit
							["learnedAt"] = 230,
							["maps"] = {
								MAP.BLACKROCK_DEPTHS,
								MAP.MOLTEN_CORE,
								MAP.BURNING_STEPPES,
								MAP.SEARING_GORGE,
							},
						}),
						-- ____________________________________________
						-- Gold
						o(1734, {	-- Gold Vein
							["description"] = "Gold Vein is a rare spawn in place of Iron Deposits and Mithril Deposits.",
							["learnedAt"] = 155,
							["maps"] = {
								MAP.ARATHI_HIGHLANDS,
								MAP.BADLANDS,
								MAP.BURNING_STEPPES,
								MAP.DESOLACE,
								MAP.FERALAS,
								MAP.SEARING_GORGE,
								MAP.TANARIS,
								MAP.ALTERAC_MOUNTAINS,
								MAP.AZSHARA,
								MAP.FELWOOD,
								MAP.STRANGLETHORN_VALE,
								MAP.THOUSAND_NEEDLES,
							},
						}),
						o(150080, {	-- Gold Vein (Blasted Lands - Horde only)
							-- Note: This node get removed at an unknown point between MOP and TWW.
							["coord"] = { 50.4, 10.3, MAP.BLASTED_LANDS },	-- Nethergarde Mine
							["learnedAt"] = 155,
							["races"] = HORDE_ONLY,
						}),
						o(181109, {	-- Gold Vein (Felwood)
							-- Note: This node get replaced by o(1734) at an unknown point between MOP and TWW.
							["learnedAt"] = 155,
							["maps"] = { MAP.FELWOOD },
						}),
						o(73941, {	-- Ooze Covered Gold Vein
							["coords"] = {
								{ 76.8, 61.5, MAP.FERALAS },	-- The Writhing Deep - west
								{ 73.5, 63.5, MAP.FERALAS },	-- The Writhing Deep - east
								{ 66.1, 86.2, MAP.THOUSAND_NEEDLES },	-- Sunken Dig Site.
							},
							["learnedAt"] = 155,
						}),
						-- ____________________________________________
						-- Iron
						o(1735, {	-- Iron Deposit
							["learnedAt"] = 125,
							["maps"] = {
								MAP.ARATHI_HIGHLANDS,
								MAP.BADLANDS,
								MAP.DESOLACE,
								MAP.ALTERAC_MOUNTAINS,
								MAP.STRANGLETHORN_VALE,
								MAP.THOUSAND_NEEDLES,
							},
						}),
						-- ____________________________________________
						-- Mithril
						o(2040, {	-- Mithril Deposit
							["learnedAt"] = 175,
							["maps"] = {
								MAP.ARATHI_HIGHLANDS,
								MAP.BADLANDS,
								MAP.BURNING_STEPPES,
								MAP.FERALAS,
								MAP.SEARING_GORGE,
								MAP.TANARIS,
								MAP.AZSHARA,
							},
						}),
						o(150079, {	-- Mithril Deposit (Blasted Lands - Horde only)
							-- Note: This node get removed at an unknown point between MOP and TWW.
							["coord"] = { 50.4, 10.3, MAP.BLASTED_LANDS },	-- Nethergarde Mine
							["learnedAt"] = 175,
							["races"] = HORDE_ONLY,
						}),
						o(176645, {	-- Mithril Deposit (Felwood)
							-- Note: This node get replaced by o(2040) at an unknown point between MOP and TWW.
							["learnedAt"] = 175,
							["maps"] = { MAP.FELWOOD },
						}),
						o(123310, {	-- Ooze Covered Mithril Deposit
							["coords"] = {
								{ 76.8, 61.5, MAP.FERALAS },	-- The Writhing Deep - west
								{ 73.5, 63.5, MAP.FERALAS },	-- The Writhing Deep - east
								{ 66.1, 86.2, MAP.THOUSAND_NEEDLES },	-- Sunken Dig Site.
							},
							["learnedAt"] = 175,
						}),
						-- ____________________________________________
						-- Obsidian Chunk
						o(181069, {	-- Large Obsidian Chunk
							["learnedAt"] = 305,
							["maps"] = {
								MAP.RUINS_OF_AHNQIRAJ,
								MAP.TEMPLE_OF_AHNQIRAJ,
								MAP.SILITHUS,
							},
						}),
						o(181068, {	-- Small Obsidian Chunk
							["learnedAt"] = 305,
							["maps"] = {
								MAP.RUINS_OF_AHNQIRAJ,
								MAP.TEMPLE_OF_AHNQIRAJ,
								MAP.SILITHUS,
							},
						}),
						-- ____________________________________________
						-- Silver
						o(73940, {	-- Ooze Covered Silver Vein
							["learnedAt"] = 75,
							["coord"] = { 66.1, 86.2, MAP.THOUSAND_NEEDLES },	-- Sunken Dig Site.
						}),
						o(1733, {	-- Silver Vein
							["learnedAt"] = 75,
							["maps"] = {
								MAP.ARATHI_HIGHLANDS,
								MAP.ASHENVALE,
								MAP.BADLANDS,
								MAP.DESOLACE,
								MAP.DUSKWOOD,
								MAP.HILLSBRAD_FOOTHILLS,
								MAP.STONETALON_MOUNTAINS,
								MAP.WETLANDS,
								MAP.ALTERAC_MOUNTAINS,
								MAP.REDRIDGE_MOUNTAINS,
								MAP.STRANGLETHORN_VALE,
								MAP.THOUSAND_NEEDLES,
							},
						}),
						o(105569, {	-- Siler Vein (The Barrens/Hillsbrad Foothills - Horde only)
							-- Note: This node get removed at an unknown point between MOP and TWW.
							["coords"] = {
								{ 27.5, 57.5, MAP.HILLSBRAD_FOOTHILLS },	-- Azureload Mine
								{ 47.9, 87.2, MAP.THE_BARRENS },	-- Bael Modan Excavation
							},
							["learnedAt"] = 75,
							["races"] = HORDE_ONLY,
						}),
						-- ____________________________________________
						-- Thorium
						o(180215, {	-- Hakkari Thorium Vein
							["learnedAt"] = 275,
							["maps"] = { MAP.ZULGURUB },
						}),
						o(177388, {	-- Ooze Covered Rich Thorium Vein
							["learnedAt"] = 275,
							["maps"] = { MAP.SILITHUS },
						}),
						o(123848, {	-- Ooze Covered Thorium Vein
							["learnedAt"] = 245,
							["coord"] = { 50.0, 81.2, MAP.UNGORO_CRATER },	-- The Slithering Scar
						}),
						o(175404, {	-- Rich Thorium Vein
							["learnedAt"] = 275,
							["maps"] = {
								MAP.UNGORO_CRATER,
								MAP.WINTERSPRING,
								MAP.AZSHARA,
								MAP.BURNING_STEPPES,
								MAP.EASTERN_PLAGUELANDS,
							},
						}),
						o(324, {	-- Small Thorium Vein
							["learnedAt"] = 245,
							["maps"] = {
								MAP.SILITHUS,
								MAP.UNGORO_CRATER,
								MAP.WINTERSPRING,
								MAP.AZSHARA,
								MAP.BURNING_STEPPES,
								MAP.EASTERN_PLAGUELANDS,
								MAP.WESTERN_PLAGUELANDS,
							},
						}),
						-- #if ANYCLASSIC
						o(150082, {	-- Small Thorium Vein (Blasted Lands - Horde only)
							-- Note: This node get replaced by o(324) at an unknown point between MOP and TWW.
							["learnedAt"] = 245,
							["maps"] = { MAP.BLASTED_LANDS },
							["races"] = HORDE_ONLY,
						}),
						o(176643, {	-- Small Thorium Vein (Felwood)
							-- Note: This node get removed at an unknown point between MOP and TWW.
							["learnedAt"] = 245,
							["maps"] = { MAP.FELWOOD },
						}),
						-- #endif
						-- ____________________________________________
						-- Tin
						o(1732, {	-- Tin Vein
							["learnedAt"] = 65,
							["maps"] = {
								MAP.ASHENVALE,
								MAP.HILLSBRAD_FOOTHILLS,
								MAP.STONETALON_MOUNTAINS,
								MAP.REDRIDGE_MOUNTAINS,
								MAP.THOUSAND_NEEDLES,
								MAP.WETLANDS,
							},
						}),
						o(103711, {	-- Tin Vein (The Barrens/Hillsbrad Foothills - Horde only)
							-- Note: This node get removed at an unknown point between MOP and TWW.
							["coords"] = {
								{ 27.5, 57.5, MAP.HILLSBRAD_FOOTHILLS },	-- Azureload Mine
								{ 47.9, 87.2, MAP.THE_BARRENS },	-- Bael Modan Excavation
							},
							["learnedAt"] = 65,
							["races"] = HORDE_ONLY,
						}),
						o(2054, {	-- Tin Vein (Redridge Mountains - Rethban Ore)
							-- Note: This node get replaced by o(1732) at an unknown point between MOP and TWW.
							["coord"] = { 20.7, 27.0, MAP.REDRIDGE_MOUNTAINS },	-- Rethban Caverns
							["learnedAt"] = 65,
						}),
						o(3764, {	-- Tin Vein (The Barrens - Blood Shard)
							-- Note: This node get replaced by o(1732) at an unknown point between MOP and TWW.
							["learnedAt"] = 65,
							["maps"] = {
								MAP.THE_BARRENS,
							},
						}),
						-- ____________________________________________
						-- Truesilver
						o(123309, {	-- Ooze Covered Truesilver Deposit
							["coords"] = {
								{ 76.8, 61.5, MAP.FERALAS },	-- The Writhing Deep - west
								{ 73.5, 63.5, MAP.FERALAS },	-- The Writhing Deep - east
								{ 50.0, 81.2, MAP.UNGORO_CRATER },	-- The Slithering Scar
							},
							["learnedAt"] = 230,
							["maps"] = { MAP.SILITHUS },
						}),
						o(2047, {	-- Truesilver Deposit
							["learnedAt"] = 230,
							["maps"] = {
								MAP.BADLANDS,
								MAP.BURNING_STEPPES,
								MAP.EASTERN_PLAGUELANDS,
								MAP.FERALAS,
								MAP.SEARING_GORGE,
								MAP.TANARIS,
								MAP.UNGORO_CRATER,
								MAP.WINTERSPRING,
								MAP.AZSHARA,
							},
						}),
						o(150081, {	-- Truesilver Deposit (Blasted Lands - Horde only)
							-- Note: This node get removed at an unknown point between MOP and TWW.
							["coord"] = { 50.4, 10.3, MAP.BLASTED_LANDS },	-- Nethergarde Mine
							["learnedAt"] = 230,
							["races"] = HORDE_ONLY,
						}),
						o(181108, {	-- Truesilver Deposit (Felwood)
							-- Note: This node get replaced by o(2047) at an unknown point between MOP and TWW.
							["learnedAt"] = 230,
							["maps"] = { MAP.FELWOOD },
						}),
					}),
					{
						-- ____________________________________________
						-- Ores
						i(2770, {	-- Copper Ore
							["maps_disp"] = {
								MAP.DARKSHORE,
								MAP.DUN_MOROGH,
								MAP.DUROTAR,
								MAP.ELWYNN_FOREST,
								MAP.LOCH_MODAN,
								MAP.MULGORE,
								MAP.SILVERPINE_FOREST,
								MAP.TIRISFAL_GLADES,
								MAP.WESTFALL,
								MAP.THE_BARRENS,
							},
							["provider"] = { "o", 1731 },	-- Copper Vein
						}),
						i(11370, {	-- Dark Iron Ore
							["maps_disp"] = {
								MAP.BLACKROCK_DEPTHS,
								MAP.MOLTEN_CORE,
								MAP.BURNING_STEPPES,
								MAP.SEARING_GORGE,
							},
							["provider"] = { "o", 165658 },	-- Dark Iron Deposit
						}),
						i(2776, {	-- Gold Ore
							["maps_disp"] = {
								MAP.ARATHI_HIGHLANDS,
								MAP.BADLANDS,
								MAP.BURNING_STEPPES,
								MAP.DESOLACE,
								MAP.FELWOOD,
								MAP.FERALAS,
								MAP.SEARING_GORGE,
								MAP.TANARIS,
								MAP.THOUSAND_NEEDLES,
								MAP.ALTERAC_MOUNTAINS,
								MAP.AZSHARA,
								MAP.STRANGLETHORN_VALE,
							},
							["providers"] = {
								{ "o", 1734 },	-- Gold Vein
								{ "o", 73941 },	-- Ooze Covered Gold Vein
							},
						}),
						i(2772, {	-- Iron Ore
							["maps_disp"] = {
								MAP.ARATHI_HIGHLANDS,
								MAP.BADLANDS,
								MAP.DESOLACE,
								MAP.ALTERAC_MOUNTAINS,
								MAP.STRANGLETHORN_VALE,
								MAP.THOUSAND_NEEDLES,
							},
							["provider"] = { "o", 1735 },	-- Iron Deposit
						}),
						applyclassicphase(PHASE_FIVE, i(22203, {	-- Large Obsidian Shard
							["maps_disp"] = {
								MAP.RUINS_OF_AHNQIRAJ,
								MAP.TEMPLE_OF_AHNQIRAJ,
								MAP.SILITHUS,
							},
							["providers"] = {
								{ "o", 181069 },	-- Large Obsidian Chunk
								{ "o", 181068 },	-- Small Obsidian Chunk
							},
						})),
						i(3858, {	-- Mithril Ore
							["maps_disp"] = {
								MAP.BADLANDS,
								MAP.BURNING_STEPPES,
								MAP.FELWOOD,
								MAP.FERALAS,
								MAP.SEARING_GORGE,
								MAP.TANARIS,
								MAP.AZSHARA,
							},
							["provider"] = { "o", 2040 },	-- Mithril Deposit
						}),
						i(2775, {	-- Silver Ore
							["description"] = "Silver Veins is a rare spawn in place of Tin Veins and Iron Deposits.",
							["maps_disp"] = {
								MAP.ARATHI_HIGHLANDS,
								MAP.ASHENVALE,
								MAP.BADLANDS,
								MAP.DESOLACE,
								MAP.DUSKWOOD,
								MAP.HILLSBRAD_FOOTHILLS,
								MAP.STONETALON_MOUNTAINS,
								MAP.WETLANDS,
								MAP.EASTERN_PLAGUELANDS,
								MAP.FERALAS,
								MAP.STRANGLETHORN_VALE,
								MAP.THE_BARRENS,
								MAP.THE_HINTERLANDS,
								MAP.WESTERN_PLAGUELANDS,
							},
							["providers"] = {
								{ "o", 73940 },	-- Ooze Covered Silver Vein
								{ "o", 1733 },	-- Silver Vein
							},
						}),
						applyclassicphase(PHASE_FIVE, i(22202, {	-- Small Obsidian Shard
							["maps_disp"] = {
								MAP.RUINS_OF_AHNQIRAJ,
								MAP.TEMPLE_OF_AHNQIRAJ,
								-- #if BEFORE CATA
								MAP.SILITHUS,
								-- #endif
							},
							["providers"] = {
								{ "o", 181069 },	-- Large Obsidian Chunk
								{ "o", 181068 },	-- Small Obsidian Chunk
							},
						})),
						i(10620, {	-- Thorium Ore
							["maps_disp"] = {
								MAP.UNGORO_CRATER,
								MAP.WINTERSPRING,
								-- #if AFTER CATA
								MAP.BLASTED_LANDS,
								MAP.SILITHUS,
								MAP.SWAMP_OF_SORROWS,
								-- #else
								MAP.AZSHARA,
								MAP.BURNING_STEPPES,
								MAP.EASTERN_PLAGUELANDS,
								MAP.FELWOOD,
								MAP.ZULGURUB,
								-- #endif
							},
							["providers"] = {
								-- #if BEFORE CATA
								{ "o", 180215 },	-- Hakkari Thorium Vein
								-- #endif
								{ "o", 177388 },	-- Ooze Covered Rich Thorium Vein
								{ "o", 123848 },	-- Ooze Covered Thorium Vein
								{ "o", 175404 },	-- Rich Thorium Vein
								{ "o", 324 },	-- Small Thorium Vein
							},
						}),
						i(2771, {	-- Tin Ore
							["maps_disp"] = {
								MAP.ASHENVALE,
								MAP.HILLSBRAD_FOOTHILLS,
								MAP.STONETALON_MOUNTAINS,
								MAP.REDRIDGE_MOUNTAINS,
								MAP.THOUSAND_NEEDLES,
								MAP.WETLANDS,
							},
							["provider"] = { "o", 1732 },	-- Tin Vein
						}),
						i(7911, {	-- Truesilver Ore
							["description"] = "Truesilver Deposits is a rare spawn in place of Mithril Deposits and Thorium Veins.",
							["maps_disp"] = {
								MAP.BADLANDS,
								MAP.BURNING_STEPPES,
								MAP.EASTERN_PLAGUELANDS,
								MAP.FELWOOD,
								MAP.FERALAS,
								MAP.SEARING_GORGE,
								MAP.TANARIS,
								MAP.UNGORO_CRATER,
								MAP.WINTERSPRING,
								MAP.AZSHARA,
							},
							["providers"] = {
								{ "o", 123309 },	-- Ooze Covered Truesilver Deposit
								{ "o", 2047 },	-- Truesilver Deposit
							},
						}),
						-- ____________________________________________
						-- Stones:
						i(2836, {	-- Coarse Stone
							["maps_disp"] = {
								MAP.ASHENVALE,
								MAP.DUSKWOOD,
								MAP.HILLSBRAD_FOOTHILLS,
								MAP.STONETALON_MOUNTAINS,
								MAP.REDRIDGE_MOUNTAINS,
								MAP.THOUSAND_NEEDLES,
								MAP.WETLANDS,
							},
							["provider"] = { "o", 1732 },	-- Tin Vein
						}),
						i(12365, {	-- Dense Stone
							["maps_disp"] = {
								MAP.UNGORO_CRATER,
								MAP.WINTERSPRING,
								MAP.AZSHARA,
								MAP.BURNING_STEPPES,
								MAP.EASTERN_PLAGUELANDS,
								MAP.FELWOOD,
								MAP.ZULGURUB,
							},
							["providers"] = {
								{ "o", 180215 },	-- Hakkari Thorium Vein
								{ "o", 177388 },	-- Ooze Covered Rich Thorium Vein
								{ "o", 123848 },	-- Ooze Covered Thorium Vein
								{ "o", 175404 },	-- Rich Thorium Vein
								{ "o", 324 },	-- Small Thorium Vein
							},
						}),
						i(2838, {	-- Heavy Stone
							["maps_disp"] = {
								MAP.ARATHI_HIGHLANDS,
								MAP.BADLANDS,
								MAP.DESOLACE,
								MAP.ALTERAC_MOUNTAINS,
								MAP.STRANGLETHORN_VALE,
								MAP.THOUSAND_NEEDLES,
							},
							["provider"] = { "o", 1735 },	-- Iron Deposit
						}),
						i(2835, {	-- Rough Stone
							["maps_disp"] = {
								MAP.DARKSHORE,
								MAP.DUN_MOROGH,
								MAP.DUROTAR,
								MAP.ELWYNN_FOREST,
								MAP.LOCH_MODAN,
								MAP.MULGORE,
								MAP.SILVERPINE_FOREST,
								MAP.TIRISFAL_GLADES,
								MAP.WESTFALL,
								MAP.THE_BARRENS,
							},
							["provider"] = { "o", 1731 },	-- Copper Vein
						}),
						i(7912, {	-- Solid Stone
							["maps_disp"] = {
								MAP.UNGORO_CRATER,
								MAP.WINTERSPRING,
								MAP.AZSHARA,
								MAP.BURNING_STEPPES,
								MAP.EASTERN_PLAGUELANDS,
								MAP.FELWOOD,
								MAP.ZULGURUB,
							},
							["provider"] = { "o", 2040 },	-- Mithril Deposit
						}),
						-- ____________________________________________
						--
						-- Not Ore --
						-- Elements with unviably low droprate:
						-- i(7067),	-- Elemental Earth
						-- i(7068),	-- Elemental Fire
						-- applyclassicphase(PHASE_FIVE, i(7076)),	-- Essence of Earth
						-- Misc:
						i(12363, {	-- Arcane Crystal
							["description"] = "Arcane Crystal is most reliably obtainable from mining Rich Thorium Veins, although the droprate is low.",
							["maps_disp"] = {
								MAP.UNGORO_CRATER,
								MAP.WINTERSPRING,
								MAP.AZSHARA,
								MAP.BURNING_STEPPES,
								MAP.EASTERN_PLAGUELANDS,
								MAP.FELWOOD,
								MAP.ZULGURUB,
							},
							["providers"] = {
								{ "o", 180215 },	-- Hakkari Thorium Vein
								{ "o", 177388 },	-- Ooze Covered Rich Thorium Vein
								{ "o", 123848 },	-- Ooze Covered Thorium Vein
								{ "o", 175404 },	-- Rich Thorium Vein
							},
						}),
						i(9262, {	-- Black Vitriol
							["description"] = "This gem is most reliably obtained from mining veins, although the droprate is 1%.",
							["providers"] = {
								{ "o", 2040 },	-- Mithril Deposit
								{ "o", 324 },	-- Small Thorium Vein
							},
						}),
						i(11382, {	-- Blood of the Mountain
							["maps_disp"] = {
								MAP.BLACKROCK_DEPTHS,
								MAP.MOLTEN_CORE,
								MAP.BURNING_STEPPES,
								MAP.SEARING_GORGE,
							},
							["provider"] = { "o", 165658 },	-- Dark Iron Deposit
						}),
						i(8150, {	-- Deeprock Salt
							["description"] = "Can drop from any highlevel earth elemental and construct creatures, and miners can get additional yield from mining the corpse.",
							["maps_disp"] = {
								MAP.BLACKROCK_DEPTHS,
								MAP.MARAUDON,
								MAP.ULDAMAN,
							},
						}),
						applyclassicphase(PHASE_FOUR, i(19774, {	-- Souldarite
							["provider"] = { "o", 180215 },	-- Hakkari Thorium Vein
							["timeline"] = { REMOVED_4_0_3 }
						})),
					},
					-- ____________________________________________
					-- Gems (obtainable from prospecting):
					-- Note: The gems are linked to respective ores with provider for prospecting in JEWELCRAFTING > Prospecting.
					sharedData({
						["description"] = "This gem is most reliably obtained from mining veins, although the droprate is low.",
					}, {
						i(7909, {	-- Aquamarine
							["maps_disp"] = {
								MAP.BADLANDS,
								MAP.BURNING_STEPPES,
								MAP.FELWOOD,
								MAP.FERALAS,
								MAP.SEARING_GORGE,
								MAP.TANARIS,
								MAP.AZSHARA,
							},
							["providers"] = {
								{ "o", 2040 },	-- Mithril Deposit
								{ "o", 2047 },	-- Truesilver Deposit
							},
						}),
						i(12800, {	-- Azerothian Diamond
							["maps_disp"] = {
								MAP.UNGORO_CRATER,
								MAP.WINTERSPRING,
								MAP.AZSHARA,
								MAP.BURNING_STEPPES,
								MAP.EASTERN_PLAGUELANDS,
								MAP.FELWOOD,
								MAP.ZULGURUB,
							},
							["providers"] = {
								{ "o", 180215 },	-- Hakkari Thorium Vein
								{ "o", 177388 },	-- Ooze Covered Rich Thorium Vein
								{ "o", 123848 },	-- Ooze Covered Thorium Vein
								{ "o", 175404 },	-- Rich Thorium Vein
								{ "o", 324 },	-- Small Thorium Vein
							},
						}),
						i(12361, {	-- Blue Sapphire
							["maps_disp"] = {
								MAP.UNGORO_CRATER,
								MAP.WINTERSPRING,
								MAP.AZSHARA,
								MAP.BURNING_STEPPES,
								MAP.EASTERN_PLAGUELANDS,
								MAP.FELWOOD,
								MAP.ZULGURUB,
							},
							["providers"] = {
								{ "o", 180215 },	-- Hakkari Thorium Vein
								{ "o", 177388 },	-- Ooze Covered Rich Thorium Vein
								{ "o", 123848 },	-- Ooze Covered Thorium Vein
								{ "o", 175404 },	-- Rich Thorium Vein
								{ "o", 324 },	-- Small Thorium Vein
							},
						}),
						i(3864, {	-- Citrine
							["maps_disp"] = {
								MAP.ARATHI_HIGHLANDS,
								MAP.BADLANDS,
								MAP.BURNING_STEPPES,
								MAP.DESOLACE,
								MAP.FELWOOD,
								MAP.FERALAS,
								MAP.SEARING_GORGE,
								MAP.TANARIS,
								MAP.THOUSAND_NEEDLES,
								MAP.ALTERAC_MOUNTAINS,
								MAP.AZSHARA,
								MAP.STRANGLETHORN_VALE,
							},
							["providers"] = {
								{ "o", 1735 },	-- Iron Deposit
								{ "o", 2040 },	-- Mithril Deposit
								{ "o", 1734 },	-- Gold Vein
								{ "o", 2047 },	-- Truesilver Deposit
							},
						}),
						i(12364, {	-- Huge Emerald
							["maps_disp"] = {
								MAP.UNGORO_CRATER,
								MAP.WINTERSPRING,
								MAP.AZSHARA,
								MAP.BURNING_STEPPES,
								MAP.EASTERN_PLAGUELANDS,
								MAP.FELWOOD,
								MAP.ZULGURUB,
							},
							["providers"] = {
								{ "o", 180215 },	-- Hakkari Thorium Vein
								{ "o", 177388 },	-- Ooze Covered Rich Thorium Vein
								{ "o", 123848 },	-- Ooze Covered Thorium Vein
								{ "o", 175404 },	-- Rich Thorium Vein
								{ "o", 324 },	-- Small Thorium Vein
							},
						}),
						i(1529, {	-- Jade
							["maps_disp"] = {
								MAP.ARATHI_HIGHLANDS,
								MAP.BADLANDS,
								MAP.DESOLACE,
								MAP.ALTERAC_MOUNTAINS,
								MAP.STRANGLETHORN_VALE,
								MAP.THOUSAND_NEEDLES,
							},
							["providers"] = {
								{ "o", 1735 },	-- Iron Deposit
								{ "o", 1734 },	-- Gold Vein
							},
						}),
						i(12799, {	-- Large Opal
							["maps_disp"] = {
								MAP.UNGORO_CRATER,
								MAP.WINTERSPRING,
								MAP.AZSHARA,
								MAP.BURNING_STEPPES,
								MAP.EASTERN_PLAGUELANDS,
								MAP.FELWOOD,
								MAP.ZULGURUB,
							},
							["providers"] = {
								{ "o", 180215 },	-- Hakkari Thorium Vein
								{ "o", 177388 },	-- Ooze Covered Rich Thorium Vein
								{ "o", 123848 },	-- Ooze Covered Thorium Vein
								{ "o", 175404 },	-- Rich Thorium Vein
								{ "o", 324 },	-- Small Thorium Vein
							},
						}),
						i(1705, {	-- Lesser Moonstone
							["maps_disp"] = {
								MAP.ARATHI_HIGHLANDS,
								MAP.ASHENVALE,
								MAP.BADLANDS,
								MAP.DESOLACE,
								MAP.DUSKWOOD,
								MAP.HILLSBRAD_FOOTHILLS,
								MAP.STONETALON_MOUNTAINS,
								MAP.WETLANDS,
								MAP.ALTERAC_MOUNTAINS,
								MAP.REDRIDGE_MOUNTAINS,
								MAP.STRANGLETHORN_VALE,
								MAP.THOUSAND_NEEDLES,
							},
							["providers"] = {
								{ "o", 1732 },	-- Tin Vein
								{ "o", 1735 },	-- Iron Deposit
								{ "o", 1733 },	-- Silver Vein
								{ "o", 1734 },	-- Gold Vein
							},
						}),
						i(774, {	-- Malachite
							["maps_disp"] = {
								MAP.DARKSHORE,
								MAP.DUN_MOROGH,
								MAP.DUROTAR,
								MAP.ELWYNN_FOREST,
								MAP.LOCH_MODAN,
								MAP.MULGORE,
								MAP.SILVERPINE_FOREST,
								MAP.TIRISFAL_GLADES,
								MAP.WESTFALL,
								MAP.THE_BARRENS,
							},
							["provider"] = { "o", 1731 },	-- Copper Vein
						}),
						i(1206, {	-- Moss Agate
							["maps_disp"] = {
								MAP.ASHENVALE,
								MAP.DUSKWOOD,
								MAP.HILLSBRAD_FOOTHILLS,
								MAP.STONETALON_MOUNTAINS,
								MAP.REDRIDGE_MOUNTAINS,
								MAP.THOUSAND_NEEDLES,
								MAP.WETLANDS,
							},
							["providers"] = {
								{ "o", 1732 },	-- Tin Vein
								{ "o", 1733 },	-- Silver Vein
							},
						}),
						i(1210, {	-- Shadowgem
							["maps_disp"] = {
								MAP.DARKSHORE,
								MAP.DUN_MOROGH,
								MAP.DUROTAR,
								MAP.ELWYNN_FOREST,
								MAP.LOCH_MODAN,
								MAP.MULGORE,
								MAP.SILVERPINE_FOREST,
								MAP.TIRISFAL_GLADES,
								MAP.WESTFALL,
								MAP.THE_BARRENS,
								MAP.ASHENVALE,
								MAP.DUSKWOOD,
								MAP.HILLSBRAD_FOOTHILLS,
								MAP.STONETALON_MOUNTAINS,
								MAP.REDRIDGE_MOUNTAINS,
								MAP.THOUSAND_NEEDLES,
								MAP.WETLANDS,
							},
							["providers"] = {
								{ "o", 1731 },	-- Copper Vein
								{ "o", 1732 },	-- Tin Vein
								{ "o", 1733 },	-- Silver Vein
							},
						}),
						i(7910, {	-- Star Ruby
							["maps_disp"] = {
								MAP.BADLANDS,
								MAP.BURNING_STEPPES,
								MAP.FELWOOD,
								MAP.FERALAS,
								MAP.SEARING_GORGE,
								MAP.TANARIS,
								-- #if AFTER CATA
								MAP.EASTERN_PLAGUELANDS,
								MAP.THOUSAND_NEEDLES,
								-- #else
								MAP.AZSHARA,
								-- #endif
								-- #if BEFORE TBC
								MAP.UNGORO_CRATER,
								MAP.WINTERSPRING,
								MAP.EASTERN_PLAGUELANDS,
								MAP.ZULGURUB,
								-- #endif
							},
							-- #if BEFORE TBC
							["providers"] = {
								{ "o", 2040 },	-- Mithril Deposit
								{ "o", 180215 },	-- Hakkari Thorium Vein
								{ "o", 177388 },	-- Ooze Covered Rich Thorium Vein
								{ "o", 123848 },	-- Ooze Covered Thorium Vein
								{ "o", 175404 },	-- Rich Thorium Vein
								{ "o", 324 },	-- Small Thorium Vein
								{ "o", 2047 },	-- Truesilver Deposit
							},
							-- #endif
						}),
						i(818, {	-- Tigerseye
							["maps_disp"] = {
								MAP.DARKSHORE,
								MAP.DUN_MOROGH,
								MAP.DUROTAR,
								MAP.ELWYNN_FOREST,
								MAP.LOCH_MODAN,
								MAP.MULGORE,
								MAP.SILVERPINE_FOREST,
								MAP.TIRISFAL_GLADES,
								MAP.WESTFALL,
								MAP.THE_BARRENS,
							},
							-- #if BEFORE TBC
							["provider"] = { "o", 1731 },	-- Copper Vein
							-- #endif
						}),
					})
				),
			}),
			filter(PROFESSION_EQUIPMENT, {
				i(2901, {	-- Mining Pick
					["collectible"] = false,
					["description"] = "Can be bought from Mining Suppliers, as well as some Trade vendors around the world",
				}),
			}),
			header(HEADERS.Spell, 2656, {	-- Smelting
				i(2841, {	-- Bronze Bar
					["cost"] = ClassicCost({
						{ "i", 2840, 1 },	-- Copper Bar
						{ "i", 3576, 1 },	-- Tin Bar
					}),
				}),
				i(2840, {	-- Copper Bar
					["cost"] = ClassicCost({ { "i", 2770, 1 } }),	-- Copper Ore
				}),
				i(11371, {	-- Dark Iron Bar
					["cost"] = ClassicCost({ { "i", 11370, 8 } }),	-- Dark Iron Ore
					["description"] = "Learning how to melt Dark Iron Ore from Gloom'rel costs 2 Star Ruby, 20 Gold Bars, and 10 Truesilver Bars.\n\nThe Black Forge can be found in Blackrock Depths, just past the Summoner's Tomb. Head right into The Molten Bridge, and the forge will be on the left side.\nThe Black Anvil can be found by Lord Incendius in the same dungeon.",
				}),
				applyclassicphase(PHASE_THREE, i(17771, {	-- Enchanted / Elementium Bar
					["cost"] = ClassicCost({
						{ "i", 18562, 1 },	-- Elementium Ore
						{ "i", 12360, 10 },	-- Arcanite Bar
						{ "i", 17010, 1 },	-- Fiery Core
						{ "i", 18567, 3 },	-- Elemental Flux
					}),
				})),
				-- #if AFTER 3.3.0
				i(12655, {	-- Enchanted Thorium Bar
					["timeline"] = { ADDED_3_3_3 },
					["cost"] = ClassicCost({
						{ "i", 12359, 1 },	-- Thorium Bar
						{ "i", 11176, 3 },	-- Dream Dust
					}),
				}),
				-- #endif
				i(3577, {	-- Gold Bar
					["cost"] = ClassicCost({ { "i", 2776, 1 } }),	-- Gold Ore
				}),
				i(3575, {	-- Iron Bar
					["cost"] = ClassicCost({ { "i", 2772, 1 } }),	-- Iron Ore
				}),
				i(3860, {	-- Mithril Bar
					["cost"] = ClassicCost({ { "i", 3858, 1 } }),	-- Mithril Ore
				}),
				-- #if SEASON_OF_DISCOVERY
				applyclassicphase(SOD_PHASE_SIX, i(234003, {	-- Obsidian-Infused Thorium Bar
					["timeline"] = { ADDED_1_15_5 },
					["cost"] = ClassicCost({
						{ "i", 12655, 2 },	-- Enchanted Thorium Bar
						{ "i", 22203, 2 },	-- Large Obsidian Shard
					}),
				})),
				-- #endif
				i(2842, {	-- Silver Bar
					["cost"] = ClassicCost({ { "i", 2775, 1 } }),	-- Silver Ore
				}),
				i(3859, {	-- Steel Bar
					["cost"] = ClassicCost({
						{ "i", 3575, 1 },	-- Iron Bar
						{ "i", 3857, 1 },	-- Coal
					}),
				}),
				i(12359, {	-- Thorium Bar
					["cost"] = ClassicCost({ { "i", 10620, 1 } }),	-- Thorium Ore
				}),
				i(3576, {	-- Tin Bar
					["cost"] = ClassicCost({ { "i", 2771, 1 } }),	-- Tin Ore
				}),
				i(6037, {	-- Truesilver Bar
					["cost"] = ClassicCost({ { "i", 7911, 1 } }),	-- Truesilver Ore
				}),
			}),
		},
	}),
	prof(POISONS, bubbleDownSelf({ ["timeline"] = { REMOVED_3_0_2 }, ["classes"] = { ROGUE }}, {
		-- #if SEASON_OF_DISCOVERY
		applyclassicphase(SOD_PHASE_THREE, i(217347, {	-- Atrophic Poison
			["timeline"] = { ADDED_1_15_2 },
		})),
		-- #endif
		i(5530, {["timeline"] = {REMOVED_2_0_1}}),	-- Blinding Powder
		i(3775),	-- Crippling Poison
		i(3776),	-- Crippling Poison II
		i(2892),	-- Deadly Poison
		i(2893),	-- Deadly Poison II
		i(8984),	-- Deadly Poison III
		i(8985),	-- Deadly Poison IV
		applyclassicphase(PHASE_FIVE, i(20844)),	-- Deadly Poison V
		i(6947),	-- Instant Poison
		i(6949),	-- Instant Poison II
		i(6950),	-- Instant Poison III
		i(8926),	-- Instant Poison IV
		i(8927),	-- Instant Poison V
		i(8928),	-- Instant Poison VI
		i(5237),	-- Mind-Numbing Poison
		i(6951),	-- Mind-Numbing Poison II
		i(9186),	-- Mind-Numbing Poison III
		-- #if SEASON_OF_DISCOVERY
		applyclassicphase(SOD_PHASE_THREE, i(217346, {	-- Numbing Poison
			["timeline"] = { ADDED_1_15_2 },
		})),
		applyclassicphase(SOD_PHASE_THREE, i(217345, {	-- Sebacious Poison
			["timeline"] = { ADDED_1_15_2 },
		})),
		-- #endif
		i(10918),	-- Wound Poison
		i(10920),	-- Wound Poison II
		i(10921),	-- Wound Poison III
		i(10922),	-- Wound Poison IV
	})),
	prof(SKINNING, {
		-- #if NOT ANYCLASSIC
		["description"] = "The following items can be gathered by skinning creatures out in the world.\n\nNote that although Light-/Medium-/Heavy-/Thick-/Rugged Leather is most common to get from skinning, which one you get is depending on two factors:\n\n* Your skill level in Skinning\n\n*The historic level bracket of the creature.\n\nYou will never be able to obtain Heavy Leather from skinning in Dun Morogh, and if you get Light Leather from skinning in Uldaman your skill level is way too low.",
		-- #else
		["description"] = "The following items can be gathered by skinning creatures out in the world.",
		-- #endif
		["groups"] = {
			n(COMMON_VENDOR_ITEMS, {
				i(7005, {	-- Skinning Knife
					["collectible"] = false,
					["description"] = "Can be bought from Leatherworking Suppliers, as well as some Trade vendors around the world.",
				}),
			}),
			spell(8613, {	-- Skinning
				-- Base leathers:
				i(4234, {	-- Heavy Leather
					["maps_disp"] = {
						MAP.DUSTWALLOW_MARSH,
						MAP.TANARIS,
						MAP.THE_HINTERLANDS,
						-- #if AFTER CATA
						MAP.WESTERN_PLAGUELANDS,
						-- #endif
					},
				}),
				i(2318, {	-- Light Leather
					["maps_disp"] = {
						MAP.DARKSHORE,
						MAP.LOCH_MODAN,
						MAP.SILVERPINE_FOREST,
						MAP.WESTFALL,
					},
				}),
				i(2319, {	-- Medium Leather
					["maps_disp"] = {
						MAP.ARATHI_HIGHLANDS,
						MAP.STONETALON_MOUNTAINS,
					},
				}),
				i(8170, {	-- Rugged Leather
					["maps_disp"] = {
						MAP.BLASTED_LANDS,
					},
				}),
				i(2934, {	-- Ruined Leather Scraps
					["maps_disp"] = {
						MAP.DUN_MOROGH,
						MAP.DUROTAR,
						MAP.ELWYNN_FOREST,
						MAP.MULGORE,
						MAP.TELDRASSIL,
						MAP.TIRISFAL_GLADES,
					},
				}),
				i(4304, {	-- Thick Leather
					["maps_disp"] = {
						MAP.BADLANDS,
						MAP.FELWOOD,
						MAP.THOUSAND_NEEDLES,
						MAP.UNGORO_CRATER,
						MAP.WINTERSPRING,
					},
				}),
				-- Base hides:
				i(4235, {	-- Heavy Hide
					["description"] = "Is a rare drop in place of Heavy Leather.",
					["maps_disp"] = {
						MAP.DUSTWALLOW_MARSH,
						MAP.TANARIS,
						MAP.THE_HINTERLANDS,
						-- #if AFTER CATA
						MAP.WESTERN_PLAGUELANDS,
						-- #endif
					},
					}),
				i(783, {	-- Light Hide
					["description"] = "Is a rare drop in place of Light Leather.",
					["maps_disp"] = {
						MAP.DARKSHORE,
						MAP.LOCH_MODAN,
						MAP.SILVERPINE_FOREST,
						MAP.WESTFALL,
					},
				}),
				i(4232, {	-- Medium Hide
					["description"] = "Is a rare drop in place of Medium Leather.",
					["maps_disp"] = {
						MAP.ARATHI_HIGHLANDS,
						MAP.STONETALON_MOUNTAINS,
					},
				}),
				i(8171, {	-- Rugged Hide
					["description"] = "Is a rare drop in place of Rugged Leather.",
					["maps_disp"] = {
						MAP.BLASTED_LANDS,
					},
				}),
				i(8169, {	-- Thick Hide
					["description"] = "Is a rare drop in place of Thick Leather.",
					["maps_disp"] = {
						MAP.BADLANDS,
						MAP.FELWOOD,
						MAP.THOUSAND_NEEDLES,
						MAP.UNGORO_CRATER,
						MAP.WINTERSPRING,
					},
				}),
				-- Special leathers
				i(15423, {	-- Chimera Leather
					["crs"] = {
						10807,	-- Brumeran
						7448,	-- Chillwind Chimaera
						7449,	-- Chillwind Ravager
						7447,	-- Fledgling Chillwind
						8764,	-- Mistwing Ravager
						8763,	-- Mistwing Rogue
					},
					["maps_disp"] = {
						MAP.AZSHARA,
						MAP.WINTERSPRING,
					},
					["timeline"] = { REMOVED_3_1_0 },
				}),
				i(17012, {	-- Core Leather
					["crs"] = {
						11673,	-- Ancient Core Hound (Molten Core) [Retail, namechanged sometimes between MOP and BfA] / Core Hound [Classic iterations]
						-- #if AFTER CATA
						53134,	-- Ancient Core Hound (Firelands)
						-- #endif
						11982,	-- Magmadar
					},
					["maps_disp"] = {
						-- #if AFTER CATA
						FIRELANDS,
						-- #endif
						MAP.MOLTEN_CORE,
					},
				}),
				applyclassicphase(PHASE_FOUR, i(19767, {["timeline"] = { REMOVED_4_0_3, ADDED_10_0_7 }})),	-- Primal Bat Leather (Sourced in Zul'gurub)
				applyclassicphase(PHASE_FOUR, i(19768, {["timeline"] = { REMOVED_4_0_3, ADDED_10_0_7 }})),	-- Primal Tiger Leather (Sourced in Zul'gurub)
				i(15419, {	-- Warbear Leather
					["crs"] = {
						7446,	-- Rabid Shardtooth
						7443,	-- Shardtooth Mauler
						-- #if AFTER CATA
						42336,	-- Tainted Black Bear
						-- #else
						8957,	-- Angerclaw Grizzly
						1815,	-- Diseased Black Bear
						1816,	-- Diseased Grizzly
						7445,	-- Elder Shardtooth
						7444,	-- Shardtooth Mauler
						-- #endif
					},
					-- #if AFTER BFA
					["description"] = "Can be skinned from bears in previously highlevel vanilla zones like shardtooths in Winterspring.",
					-- #else
					["description"] = "Can be skinned from bears in the level bracket 50-60 like shardtooths in Winterspring.",
					-- #endif
					["coords"] = {
						{ 55.1, 37.8, MAP.WINTERSPRING },
						{ 58.1, 89.4, MAP.WINTERSPRING },
					},
				}),
				-- Special hides
				i(7428, {	-- Shadowcat Hide
					["crs"] = {
						1713,	-- Elder Shadowmaw Panther
						768,	-- Shadow Panther
						684,	-- Shadowmaw Panther
					},
					["description"] = "Panthers can be found in central Stranglethorn Vale and eastern Swamp of Sorrows.",
					["maps_disp"] = {
						MAP.STRANGLETHORN_VALE,
						MAP.SWAMP_OF_SORROWS,
					},
					["timeline"] = { REMOVED_3_1_0 },
				}),
				i(8368, {	-- Thick Wolfhide
					["description"] = "Can be skinned from all wolfs in the level bracket 40-60 though the droprate is 3-5 %.",
					["maps_disp"] = { MAP.BURNING_STEPPES },
					["timeline"] = { REMOVED_3_1_0 },
				}),
				-- Scales
				i(15416, {	-- Black Dragonscale
					["description"] = "Can be skinned from elite creatures of the Black Dragonflight.",
					["maps_disp"] = {
						MAP.BLACKWING_LAIR,
						-- #if BEFORE WOD
						MAP.BLACKROCK_SPIRE,
						-- #endif
						-- #if BEFORE CATA
						MAP.BURNING_STEPPES,
						-- #endif
					},
				}),
				i(7286),	-- Black Whelp Scale (Sourced in Wetlands [CATA+] / Redridge Mountains)
				i(15415, {	-- Blue Dragonscale
					-- #if AFTER WOD
					["cr"] = 14020,	-- Chromaggus
					["description"] = "Blizzard being Blizzard, Blue Dragonscale is only obtainable from Chromaggus in Blackwing Lair. All other sources are removed.",
					["maps_disp"] = { MAP.BLACKWING_LAIR },
					-- #elseif AFTER CATA
					["crs"] = {
						14020,	-- Chromaggus
						10447,	-- Chromatic Dragonspawn
						10814,	-- Chromatic Elite Guard
						10442,	-- Chromatic Whelp
					},
					["description"] = "Can be skinned from creatures of the Chromatic Dragonflight, though is a pain to farm in regards to drop rate.",
					["maps_disp"] = { MAP.BLACKROCK_SPIRE },
					-- #else
					["description"] = "Can be skinned from elite creatures of the Blue Dragonflight, though is a pain to farm in regards to drop rate.",
					["coords"] = {
						{ 57.2, 65.9, MAP.WINTERSPRING },	-- Mazthoril
						{ 38.0, 75.0, MAP.AZSHARA },	-- Lake Mennar
					},
					-- #endif
				}),
				i(12607),	-- Brilliant Chromatic Scale (Sourced in Blackwing Lair [WOD+] / Blackwing Spire)
				applyclassicphase(PHASE_FOUR, i(20381, {	-- Dreamscale
					-- #if AFTER 10.1.5
					["description"] = "Can be skinned from corrupted creatures of the Green Dragonflight in Temple of Atal'hakkar. Can also be skinned from the Dragons of Nightmare during the Anniversary event.",
					["maps_disp"] = { MAP.TEMPLE_OF_ATALHAKKAR },
					-- #elseif AFTER 7.2.5
					["description"] = "Can be skinned from the Dragons of Nightmare during the Anniversary event.",
					-- #elseif AFTER 4.0.3
					["description"] = "Blizzard being blizzard, Dreamscale is no longer obtainable.",
					-- #else
					["description"] = "Can be skinned from the world bosses Dragons of Nightmare.",
					-- #endif
					["timeline"] = { REMOVED_4_0_3, ADDED_7_2_5 },
				})),
				i(15412, {	-- Green Dragonscale
					["description"] = "Can be skinned from elite creatures of the Green Dragonflight around the world.",
					["maps_disp"] = { MAP.TEMPLE_OF_ATALHAKKAR },
				}),
				i(15408, {	-- Heavy Scorpid Scale
					-- #if AFTER 4.0.3
					["description"] = "Can be skinned from scorpids in Silithus.",
					["maps_disp"] = { MAP.SILITHUS },
					-- #else
					["description"] = "Can be skinned from scorpids in the level bracket 50-60.",
					["maps_disp"] = {
						MAP.BURNING_STEPPES,
						MAP.SILITHUS
					},
					-- #endif
				}),
				i(15414, {	-- Red Dragonscale
					-- #if AFTER WOD
					["cr"] = 14020,	-- Chromaggus
					["description"] = "Blizzard being Blizzard, Red Dragonscale is only obtainable from Chromaggus in Blackwing Lair. All other sources are removed.",
					["maps_disp"] = { MAP.BLACKWING_LAIR },
					-- #elseif AFTER CATA
					["crs"] = {
						14020,	-- Chromaggus
						10447,	-- Chromatic Dragonspawn
						10814,	-- Chromatic Elite Guard
						10442,	-- Chromatic Whelp
					},
					["description"] = "Can be skinned from creatures of the Chromatic Dragonflight, though is a pain to farm in regards to drop rate.",
					["maps_disp"] = { MAP.BLACKROCK_SPIRE },
					-- #else
					["description"] = "Can be skinned from elite creatures of the Red Dragonflight around the world.",
					["coord"] = { 80.0, 48.0, MAP.WETLANDS },
					-- #endif
				}),
				i(8154, {	-- Scorpid Scale
					["maps_disp"] = { MAP.TANARIS },
					-- #if AFTER BFA
					["description"] = "Drops from scorpids in previously higher intermediate- to higher level vanilla zones like scorpids in Tanaris.",
					-- #elseif AFTER 4.0.3
					["description"] = "Drops from scorpids in higher intermediate- to higher level vanilla zones like scorpids in Tanaris.",
					-- #else
					["description"] = "Drops from scorpids in the level bracket 40-60 like scorpids in Tanaris.",
					-- #endif
				}),
				i(8167, {	-- Turtle Scale
					-- #if AFTER BFA
					["description"] = "Can be skinned from turtles in previously higher intermediate- to higher level vanilla zones like Tanaris and Thousand Needles.",
					-- #elseif AFTER 4.0.3
					["description"] = "Can be skinned from turtles in higher intermediate- to higher level vanilla zones like Tanaris and Thousand Needles.",
					-- #else
					["description"] = "Can be skinned from turtles in the level bracket 35-60 like Mudrock turtles in Dustwallow.",
					-- #endif
					["maps_disp"] = {
						-- #if AFTER CATA
						MAP.TANARIS,
						MAP.THOUSAND_NEEDLES,
						-- #else
						MAP.DUSTWALLOW_MARSH,
						-- #endif
					},
				}),
				i(8165, {	-- Worn Dragonscale
					["description"] = "Can be skinned from elite creatures of any Dragonflights around the world.",
					["maps_disp"] = { MAP.TEMPLE_OF_ATALHAKKAR },
				}),
			}),
		},
	}),
	prof(TAILORING, {
		n(ARMOR, {
			i(10030),	-- Admiral's Hat
			applyclassicphase(PHASE_THREE_RECIPES, i(19056)),	-- Argent Boots
			applyclassicphase(PHASE_THREE_RECIPES, i(19059)),	-- Argent Shoulders
			i(7060),	-- Azure Shoulders
			i(7052),	-- Azure Silk Belt
			i(7053),	-- Azure Silk Cloak
			i(4319),	-- Azure Silk Gloves
			i(7048),	-- Azure Silk Hood
			i(7046),	-- Azure Silk Pants
			i(4324),	-- Azure Silk Vest
			i(2578),	-- Barbaric Linen Vest
			applyclassicphase(PHASE_ONE_DIREMAUL, i(18405, {	-- Belt of the Archmage
				["timeline"] = {
					-- #if SEASON_OF_DISCOVERY
					REMOVED_1_15_3,
					-- #else
					REMOVED_4_0_3, ADDED_8_1_5,
					-- #endif
				},
			})),
			i(206500, {["timeline"] = { ADDED_10_1_5 }}),	-- Bindings of the Harvested Soul
			i(10026),	-- Black Mageweave Boots
			i(10003),	-- Black Mageweave Gloves
			i(10024),	-- Black Mageweave Headband
			-- #if SEASON_OF_DISCOVERY
			applyclassicphase(SOD_PHASE_TWO, i(217247, {["timeline"] = { ADDED_1_15_1 }})),	-- Black Mageweave Leggings
			i(9999, {["timeline"] = { REMOVED_1_15_1 }}),	-- Black Mageweave Leggings
			-- #else
			i(9999),	-- Black Mageweave Leggings
			-- #endif
			i(10001),	-- Black Mageweave Robe
			i(10027),	-- Black Mageweave Shoulders
			-- #if SEASON_OF_DISCOVERY
			applyclassicphase(SOD_PHASE_TWO, i(217246, {["timeline"] = { ADDED_1_15_1 }})),	-- Black Mageweave Vest
			i(9998, {["timeline"] = { REMOVED_1_15_1 }}),	-- Black Mageweave Vest
			-- #else
			i(9998),	-- Black Mageweave Vest
			-- #endif
			i(4336),	-- Black Swashbuckler's Shirt
			i(203796, {["timeline"] = { ADDED_10_0_7 }}),	-- Bloodlords Embrace
			applyclassicphase(PHASE_FOUR, i(19684, {["timeline"] = { REMOVED_4_0_3, ADDED_10_0_7 }})),	-- Bloodvine Boots
			applyclassicphase(PHASE_FOUR, i(19683, {["timeline"] = { REMOVED_4_0_3, ADDED_10_0_7 }})),	-- Bloodvine Leggings
			applyclassicphase(PHASE_FOUR, i(19682, {["timeline"] = { REMOVED_4_0_3, ADDED_10_0_7 }})),	-- Bloodvine Vest
			i(6242),	-- Blue Linen Robe
			i(2577),	-- Blue Linen Shirt
			i(6240),	-- Blue Linen Vest
			i(6263),	-- Blue Overalls
			-- #if SEASON_OF_DISCOVERY
			applyclassicphase(SOD_PHASE_TWO, i(217253, {["timeline"] = { ADDED_1_15_1 }})),	-- Boots of the Enchanter
			i(4325, {["timeline"] = { REMOVED_1_15_1 }}),	-- Boots of the Enchanter
			-- #else
			i(4325),	-- Boots of the Enchanter
			-- #endif
			i(4332),	-- Bright Yellow Shirt
			i(14103),	-- Brightcloth Cloak
			i(14101),	-- Brightcloth Gloves
			i(14104),	-- Brightcloth Pants
			i(14100),	-- Brightcloth Robe
			i(4343),	-- Brown Linen Pants
			i(6238),	-- Brown Linen Robe
			i(4344),	-- Brown Linen Shirt
			i(2568),	-- Brown Linen Vest
			i(10044),	-- Cindercloth Boots
			i(14044),	-- Cindercloth Cloak
			i(14043, {["timeline"] = { ADDED_1_11_1, REMOVED_4_0_3, ADDED_8_1_5 }}),	-- Cindercloth Gloves
			i(14045),	-- Cindercloth Pants
			i(10042),	-- Cindercloth Robe
			i(14042, {["timeline"] = { ADDED_1_11_1, REMOVED_4_0_3, ADDED_8_1_5 }}),	-- Cindercloth Vest
			i(14134),	-- Cloak of Fire
			applyclassicphase(PHASE_ONE_DIREMAUL, i(18413, {["timeline"] = { REMOVED_4_0_3, ADDED_8_1_5 }})),	-- Cloak of Warding
			i(10048),	-- Colorful Kilt
			-- #if SEASON_OF_DISCOVERY
			applyclassicphase(SOD_PHASE_TWO, i(217255, {["timeline"] = { ADDED_1_15_1 }})),	-- Crimson Silk Belt
			i(7055, {["timeline"] = { REMOVED_1_15_1 }}),	-- Crimson Silk Belt
			-- #else
			i(7055),	-- Crimson Silk Belt
			-- #endif
			i(7056),	-- Crimson Silk Cloak
			i(7064),	-- Crimson Silk Gloves
			i(7062),	-- Crimson Silk Pantaloons
			-- #if SEASON_OF_DISCOVERY
			applyclassicphase(SOD_PHASE_TWO, i(217245, {["timeline"] = { ADDED_1_15_1 }})),	-- Crimson Silk Robe
			i(7063, {["timeline"] = { REMOVED_1_15_1 }}),	-- Crimson Silk Robe
			-- #else
			i(7063),	-- Crimson Silk Robe
			-- #endif
			-- #if SEASON_OF_DISCOVERY
			applyclassicphase(SOD_PHASE_TWO, i(217250, {["timeline"] = { ADDED_1_15_1 }})),	-- Crimson Silk Shoulders
			i(7059, {["timeline"] = { REMOVED_1_15_1 }}),	-- Crimson Silk Shoulders
			-- #else
			i(7059),	-- Crimson Silk Shoulders
			-- #endif
			i(7058),	-- Crimson Silk Vest
			i(4333),	-- Dark Silk Shirt
			i(4314),	-- Double-stitched Woolen Shoulders
			-- #if SEASON_OF_DISCOVERY
			applyclassicphase(SOD_PHASE_SIX, i(234484, {["timeline"] = { ADDED_1_15_5 }})),	-- Dreamscale Bracers
			applyclassicphase(SOD_PHASE_SIX, i(234485, {["timeline"] = { ADDED_1_15_5 }})),	-- Dreamscale Mitts
			-- #endif
			i(10041),	-- Dreamweave Circlet
			i(10019),	-- Dreamweave Gloves
			i(10021),	-- Dreamweave Vest
			applyclassicphase(TBC_PHASE_THREE, i(6836, {["timeline"] = { ADDED_2_4_2 }})),	-- Dress Shoes
			-- #if SEASON_OF_DISCOVERY
			applyclassicphase(SOD_PHASE_TWO, i(217248, {["timeline"] = { ADDED_1_15_1 }})),	-- Earthen Silk Belt
			i(7061, {["timeline"] = { REMOVED_1_15_1 }}),	-- Earthen Silk Belt
			-- #else
			i(7061),	-- Earthen Silk Belt
			-- #endif
			-- #if SEASON_OF_DISCOVERY
			applyclassicphase(SOD_PHASE_TWO, i(217256, {["timeline"] = { ADDED_1_15_1 }})),	-- Earthen Vest
			i(7051, {["timeline"] = { REMOVED_1_15_1 }}),	-- Earthen Vest
			-- #else
			i(7051),	-- Earthen Vest
			-- #endif
			-- #if SEASON_OF_DISCOVERY
			applyclassicphase(SOD_PHASE_FOUR, i(228476, {["timeline"] = { ADDED_1_15_3 }})),	-- Embroidered Belt of the Archmage
			-- #endif
			-- #if SEASON_OF_DISCOVERY
			applyclassicphase(SOD_PHASE_TWO, i(217257, {["timeline"] = { ADDED_1_15_1 }})),	-- Enchanter's Cowl
			i(4322, {["timeline"] = { REMOVED_1_15_1 }}),	-- Enchanter's Cowl
			-- #else
			i(4322),	-- Enchanter's Cowl
			-- #endif
			-- #if SEASON_OF_DISCOVERY
			applyclassicphase(SOD_PHASE_ONE, i(210795, {	-- Extraplanar Spidersilk Boots
				["timeline"] = { ADDED_1_15_0 },
				["requireSkill"] = TAILORING,
			})),
			-- #endif
			i(14108),	-- Felcloth Boots
			applyclassicphase(PHASE_ONE_DIREMAUL, i(18407, {["timeline"] = { REMOVED_4_0_3, ADDED_8_1_5 }})),	-- Felcloth Gloves
			i(14111),	-- Felcloth Hood
			i(14107),	-- Felcloth Pants
			i(14106),	-- Felcloth Robe
			i(14112),	-- Felcloth Shoulders
			i(151771, {["timeline"] = { ADDED_7_3_5 }}),	-- Festival Dress
			i(21154, {["timeline"] = { REMOVED_7_3_5 }}),	-- Festival Dress
			i(151772, {["timeline"] = { ADDED_7_3_5 }}),	-- Festival Suit
			i(21542, {["timeline"] = { REMOVED_7_3_5 }}),	-- Festival Suit
			i(16979),	-- Flarecore Gloves
			i(16980),	-- Flarecore Mantle
			applyclassicphase(PHASE_THREE_RECIPES, i(19165)),	-- Flarecore Leggings
			applyclassicphase(PHASE_THREE_RECIPES, i(19156)),	-- Flarecore Robe
			i(18263),	-- Flarecore Wraps
			i(4334),	-- Formal White Shirt
			-- #if SEASON_OF_DISCOVERY
			applyclassicphase(SOD_PHASE_THREE, i(220750, {["timeline"] = { ADDED_1_15_2 }})),	-- Fractured Mind Pauldrons
			-- #endif
			i(13870),	-- Frostweave Gloves
			i(13871),	-- Frostweave Pants
			i(13868),	-- Frostweave Robe
			i(13869),	-- Frostweave Tunic
			applyclassicphase(PHASE_FIVE_CATCH_UP, i(22660)),	-- Gaea's Embrace
			i(14143),	-- Ghostweave Belt
			i(14142),	-- Ghostweave Gloves
			i(14144),	-- Ghostweave Pants
			i(14141),	-- Ghostweave Vest
			i(206429, {["timeline"] = { ADDED_10_1_5 }}),	-- Glacial Chapeau
			applyclassicphase(PHASE_SIX, i(22658, {["timeline"] = { ADDED_1_11_1, REMOVED_3_0_2,ADDED_10_1_5 }})),	-- Glacial Cloak
			i(206428, {["timeline"] = { ADDED_10_1_5 }}),	-- Glacial Epaulets
			i(206431, {["timeline"] = { ADDED_10_1_5 }}),	-- Glacial Footwear
			applyclassicphase(PHASE_SIX, i(22654, {["timeline"] = { ADDED_1_11_1, REMOVED_3_0_2,ADDED_10_1_5 }})),	-- Glacial Gloves
			i(206427, {["timeline"] = { ADDED_10_1_5 }}),	-- Glacial Leggings
			i(206430, {["timeline"] = { ADDED_10_1_5 }}),	-- Glacial Tether
			applyclassicphase(PHASE_SIX, i(22652, {["timeline"] = { ADDED_1_11_1, REMOVED_3_0_2,ADDED_10_1_5 }})),	-- Glacial Vest
			applyclassicphase(PHASE_SIX, i(22655, {["timeline"] = { ADDED_1_11_1, REMOVED_3_0_2,ADDED_10_1_5 }})),	-- Glacial Wrists
			i(4318),	-- Gloves of Meditation
			i(14146),	-- Gloves of Spell Mastery
			-- #if SEASON_OF_DISCOVERY
			applyclassicphase(SOD_PHASE_TWO, i(215111, {["timeline"] = { ADDED_1_15_1 }})),	-- Gneuro-Linked Arcano-Filament Monocle
			-- #endif
			i(2585),	-- Gray Woolen Robe
			i(2587),	-- Gray Woolen Shirt
			i(6264),	-- Greater Adept's Robe
			i(17723),	-- Green Holiday Shirt
			i(4308),	-- Green Linen Bracers
			i(2579),	-- Green Linen Shirt
			i(7065),	-- Green Silk Armor
			i(7057),	-- Green Silken Shoulders
			i(151792, {["timeline"] = { ADDED_7_3_5 }}),	-- Green Winter Clothes
			applyclassicphase(TBC_PHASE_ONE, i(34087, {["timeline"] = { ADDED_2_3_0, REMOVED_7_3_5 }})),	-- Green Winter Clothes
			i(2582),	-- Green Woolen Vest
			i(203820, {["timeline"] = { ADDED_10_0_7 }}),	-- Gurubashi Headdress
			i(203803, {["timeline"] = { ADDED_10_0_7 }}),	-- Gurubashi Tigerhide Cloak
			applyclassicphase(TBC_PHASE_THREE, i(38277, {["timeline"] = { ADDED_2_4_2 }})),	-- Haliscan Jacket
			applyclassicphase(TBC_PHASE_THREE, i(38278, {["timeline"] = { ADDED_2_4_2 }})),	-- Haliscan Pantaloons
			i(7047),	-- Hands of Darkness
			i(4309),	-- Handstitched Linen Britches
			i(4307),	-- Heavy Linen Gloves
			i(4311),	-- Heavy Woolen Cloak
			i(4310),	-- Heavy Woolen Gloves
			i(4316),	-- Heavy Woolen Pants
			i(4327),	-- Icy Cloak
			-- #if SEASON_OF_DISCOVERY
			applyclassicphase(SOD_PHASE_FOUR, i(227863, {["timeline"] = { ADDED_1_15_3 }})),	-- Incandescent Mooncloth Circlet
			applyclassicphase(SOD_PHASE_FOUR, i(227864, {["timeline"] = { ADDED_1_15_3 }})),	-- Incandescent Mooncloth Leggings
			applyclassicphase(SOD_PHASE_FOUR, i(227861, {["timeline"] = { ADDED_1_15_3 }})),	-- Incandescent Mooncloth Robe
			applyclassicphase(SOD_PHASE_FOUR, i(227860, {["timeline"] = { ADDED_1_15_3 }})),	-- Incandescent Mooncloth Vest
			-- #endif
			applyclassicphase(PHASE_ONE_DIREMAUL, i(18408, {["timeline"] = { REMOVED_4_0_3, ADDED_8_1_5 }})),	-- Inferno Gloves
			-- #if SEASON_OF_DISCOVERY
			applyclassicphase(SOD_PHASE_ONE, i(215366, {["timeline"] = { ADDED_1_15_0 }})),	-- Invoker's Cord
			applyclassicphase(SOD_PHASE_ONE, i(215365, {["timeline"] = { ADDED_1_15_0 }})),	-- Invoker's Mantle
			-- #endif
			i(10054),	-- Lavender Mageweave Shirt
			i(5766),	-- Lesser Wizard's Robe
			i(7026),	-- Linen Belt
			i(2569),	-- Linen Boots
			i(2570),	-- Linen Cloak
			-- #if SEASON_OF_DISCOVERY
			applyclassicphase(SOD_PHASE_TWO, i(217252, {["timeline"] = { ADDED_1_15_1 }})),	-- Long Silken Cloak
			i(4326, {["timeline"] = { REMOVED_1_15_1 }}),	-- Long Silken Cloak
			-- #else
			i(4326),	-- Long Silken Cloak
			-- #endif
			-- #if SEASON_OF_DISCOVERY
			applyclassicphase(SOD_PHASE_THREE, i(220749, {["timeline"] = { ADDED_1_15_2 }})),	-- Mantle of Insanity
			-- #endif
			applyclassicphase(PHASE_THREE_RECIPES, i(19050)),	-- Mantle of the Timbermaw
			i(15802),	-- Mooncloth Boots
			i(14140),	-- Mooncloth Circlet
			applyclassicphase(PHASE_ONE_DIREMAUL, i(18409, {["timeline"] = { REMOVED_4_0_3, ADDED_8_1_5 }})),	-- Mooncloth Gloves
			i(14137, {	-- Mooncloth Leggings
				-- #if SEASON_OF_DISCOVERY
				["timeline"] = { REMOVED_1_15_3 },
				-- #endif
			}),
			i(18486, {	-- Mooncloth Robe
				-- #if SEASON_OF_DISCOVERY
				["timeline"] = { REMOVED_1_15_3 },
				-- #endif
			}),
			i(14139, {	-- Mooncloth Shoulders
				-- #if SEASON_OF_DISCOVERY
				["timeline"] = { REMOVED_1_15_3 },
				-- #endif
			}),
			i(14138, {	-- Mooncloth Vest
				-- #if SEASON_OF_DISCOVERY
				["timeline"] = { REMOVED_1_15_3 },
				-- #endif
			}),
			i(206507, {["timeline"] = { ADDED_10_1_5 }}),	-- Necrotic Gown
			i(10056),	-- Orange Mageweave Shirt
			i(10052),	-- Orange Martial Shirt
			i(5542),	-- Pearl-Clasped Cloak
			i(206582, {["timeline"] = { ADDED_10_1_5 }}),	-- Peculiar Glacial Mantle
			-- #if SEASON_OF_DISCOVERY
			applyclassicphase(SOD_PHASE_ONE, i(210781, {["timeline"] = { ADDED_1_15_0 }})),	-- Phoenix Bindings
			-- #endif
			i(4331),	-- Phoenix Gloves
			i(4317),	-- Phoenix Pants
			i(10055),	-- Pink Mageweave Shirt
			-- #if SEASON_OF_DISCOVERY
			applyclassicphase(SOD_PHASE_SIX, i(233958, {["timeline"] = { ADDED_1_15_5 }})),	-- Qiraji Silk Cape
			applyclassicphase(SOD_PHASE_SIX, i(233959, {["timeline"] = { ADDED_1_15_5 }})),	-- Qiraji Silk Cloak
			applyclassicphase(SOD_PHASE_SIX, i(233960, {["timeline"] = { ADDED_1_15_5 }})),	-- Qiraji Silk Drape
			applyclassicphase(SOD_PHASE_SIX, i(233956, {["timeline"] = { ADDED_1_15_5 }})),	-- Qiraji Silk Scarf
			-- #endif
			i(2572),	-- Red Linen Robe
			i(2575),	-- Red Linen Shirt
			i(6239),	-- Red Linen Vest
			i(10018),	-- Red Mageweave Gloves
			i(10033),	-- Red Mageweave Headband
			i(10009),	-- Red Mageweave Pants
			i(10029),	-- Red Mageweave Shoulders
			i(10007),	-- Red Mageweave Vest
			i(6796),	-- Red Swashbuckler's Shirt
			i(151790, {["timeline"] = { ADDED_7_3_5 }}),	-- Red Winter Clothes
			applyclassicphase(TBC_PHASE_THREE, i(34085, {["timeline"] = { ADDED_2_3_0, REMOVED_7_3_5 }})),	-- Red Winter Clothes
			i(4313),	-- Red Woolen Boots
			i(2580),	-- Reinforced Linen Cape
			i(4315),	-- Reinforced Woolen Shoulders
			i(4335),	-- Rich Purple Silk Shirt
			i(203800, {["timeline"] = { ADDED_10_0_7 }}),	-- Ritualistic Legwarmers
			i(7054, {	-- Robe of Power
				["requireSkill"] = TAILORING,
			}),
			i(14152, {	-- Robe of the Archmage
				-- #if BEFORE WRATH
				["classes"] = { MAGE },
				-- #endif
				["requireSkill"] = TAILORING,
			}),
			i(14153, {	-- Robe of the Void
				["timeline"] = { REMOVED_5_0_4, ADDED_10_1_5 },
				-- #if BEFORE WRATH
				["classes"] = { WARLOCK },
				-- #endif
				["requireSkill"] = TAILORING,
			}),
			i(14136, {["timeline"] = { REMOVED_4_0_3,ADDED_8_1_5 }}),	-- Robe of Winter Night
			i(5770, {["timeline"] = { REMOVED_4_0_3,ADDED_8_1_5 }}),	-- Robes of Arcana
			i(13856),	-- Runecloth Belt
			i(13864),	-- Runecloth Boots
			i(13860),	-- Runecloth Cloak
			i(13863),	-- Runecloth Gloves
			i(13866),	-- Runecloth Headband
			i(13865),	-- Runecloth Pants
			i(13858),	-- Runecloth Robe
			i(13867),	-- Runecloth Shoulders
			i(13857),	-- Runecloth Tunic
			applyclassicphase(PHASE_THREE_SILITHUS_EXPEDITION_QUESTS, i(20539)),	-- Runed Stygian Belt
			applyclassicphase(PHASE_THREE_SILITHUS_EXPEDITION_QUESTS, i(20537)),	-- Runed Stygian Boots
			applyclassicphase(PHASE_THREE_SILITHUS_EXPEDITION_QUESTS, i(20538)),	-- Runed Stygian Leggings
			-- #if SEASON_OF_DISCOVERY
			applyclassicphase(SOD_PHASE_EIGHT, i(238267, {["timeline"] = { ADDED_1_15_7 }})),	-- Scarlet Augur's Cuffs
			applyclassicphase(SOD_PHASE_EIGHT, i(238264, {["timeline"] = { ADDED_1_15_7 }})),	-- Scarlet Augur's Hood
			applyclassicphase(SOD_PHASE_EIGHT, i(238270, {["timeline"] = { ADDED_1_15_7 }})),	-- Scarlet Augur's Leggings
			applyclassicphase(SOD_PHASE_EIGHT, i(238265, {["timeline"] = { ADDED_1_15_7 }})),	-- Scarlet Augur's Mantle
			applyclassicphase(SOD_PHASE_EIGHT, i(238268, {["timeline"] = { ADDED_1_15_7 }})),	-- Scarlet Augur's Mitts
			applyclassicphase(SOD_PHASE_EIGHT, i(238271, {["timeline"] = { ADDED_1_15_7 }})),	-- Scarlet Augur's Soles
			applyclassicphase(SOD_PHASE_EIGHT, i(238269, {["timeline"] = { ADDED_1_15_7 }})),	-- Scarlet Augur's Strap
			applyclassicphase(SOD_PHASE_EIGHT, i(238266, {["timeline"] = { ADDED_1_15_7 }})),	-- Scarlet Augur's Vestaments
			-- #endif
			i(4323),	-- Shadow Hood
			i(10031),	-- Shadoweave Boots
			i(10023),	-- Shadoweave Gloves
			i(10025, {	-- Shadoweave Mask
				-- #if AFTER 7.3.0
				["description"] = "Required for the |cff3399ffLucid Nightmare|r riddle mount.",
				-- #endif
				["timeline"] = { REMOVED_4_0_3, ADDED_7_3_0 },
			}),
			i(10002),	-- Shadoweave Pants
			i(10004),	-- Shadoweave Robe
			i(10028),	-- Shadoweave Shoulders
			-- #if SEASON_OF_DISCOVERY
			applyclassicphase(SOD_PHASE_THREE, i(220751, {["timeline"] = { ADDED_1_15_2 }})),	-- Shoulderpads of the Deranged
			-- #endif
			i(206562, {["timeline"] = { ADDED_10_1_5 }}),	-- Shroud of Forbidden Magic
			i(7050),	-- Silk Headband
			i(10053),	-- Simple Black Dress
			i(6786),	-- Simple Dress
			i(10047),	-- Simple Kilt
			i(10046),	-- Simple Linen Boots
			i(10045),	-- Simple Linen Pants
			i(4312),	-- Soft-Soled Linen Boots
			i(4328),	-- Spider Belt
			i(4321),	-- Spider Silk Slippers
			i(4320),	-- Spidersilk Boots
			applyclassicphase(WRATH_PHASE_ONE, i(45626, {["timeline"] = { ADDED_3_1_0 }})),	-- Spidersilk Drape
			i(4329),	-- Star Belt
			i(6384),	-- Stylish Blue Shirt
			i(6385),	-- Stylish Green Shirt
			i(4330),	-- Stylish Red Shirt
			-- #if SEASON_OF_DISCOVERY
			applyclassicphase(SOD_PHASE_SIX, i(234315, {["timeline"] = { ADDED_1_15_5 }})),	-- Sylvan Crown
			applyclassicphase(PHASE_FIVE_CATCH_UP, i(22757, {["timeline"] = { REMOVED_1_15_5 }})),	-- Sylvan Crown
			applyclassicphase(SOD_PHASE_SIX, i(234312, {["timeline"] = { ADDED_1_15_5 }})),	-- Sylvan Shoulders
			applyclassicphase(PHASE_FIVE_CATCH_UP, i(22758, {["timeline"] = { REMOVED_1_15_5 }})),	-- Sylvan Shoulders
			applyclassicphase(SOD_PHASE_SIX, i(234317, {["timeline"] = { ADDED_1_15_5 }})),	-- Sylvan Vest
			applyclassicphase(PHASE_FIVE_CATCH_UP, i(22756, {["timeline"] = { REMOVED_1_15_5 }})),	-- Sylvan Vest
			-- #else
			applyclassicphase(PHASE_FIVE_CATCH_UP, i(22757)),	-- Sylvan Crown
			applyclassicphase(PHASE_FIVE_CATCH_UP, i(22758)),	-- Sylvan Shoulders
			applyclassicphase(PHASE_FIVE_CATCH_UP, i(22756)),	-- Sylvan Vest
			-- #endif
			i(7049),	-- Truefaith Gloves
			i(14154, {	-- Truefaith Vestments
				["classes"] = { PRIEST },
				["requireSkill"] = TAILORING,
			}),
			i(10036),	-- Tuxedo Jacket
			i(10035),	-- Tuxedo Pants
			i(10034),	-- Tuxedo Shirt
			-- #if SEASON_OF_DISCOVERY
			applyclassicphase(SOD_PHASE_SIX, i(233826, {["timeline"] = { ADDED_1_15_5 }})),	-- Vampiric Cowl
			applyclassicphase(SOD_PHASE_SIX, i(233837, {["timeline"] = { ADDED_1_15_5 }})),	-- Vampiric Robe
			applyclassicphase(SOD_PHASE_SIX, i(233833, {["timeline"] = { ADDED_1_15_5 }})),	-- Vampiric Shawl
			-- #endif
			i(10008),	-- White Bandit Mask
			i(6241),	-- White Linen Robe
			i(2576),	-- White Linen Shirt
			i(6795),	-- White Swashbuckler's Shirt
			i(10040),	-- White Wedding Dress
			i(6787),	-- White Woolen Dress
			applyclassicphase(PHASE_THREE_RECIPES, i(19047)),	-- Wisdom of the Timbermaw
			i(14132),	-- Wizardweave Leggings
			i(14128),	-- Wizardweave Robe
			i(14130),	-- Wizardweave Turban
			i(2583),	-- Woolen Boots
			i(2584),	-- Woolen Cape
		}),
		filter(BAGS, {
			i(5765, {["timeline"] = { REMOVED_4_0_3, ADDED_10_1_7 }}),	-- Black Silk Pack
			-- #if SEASON_OF_DISCOVERY
			applyclassicphase(SOD_PHASE_FOUR, i(228994, {["timeline"] = { ADDED_1_15_3 }})),	-- Bottomless Bag
			i(14156, {["timeline"] = {REMOVED_1_15_3}}),	-- Bottomless Bag
			-- #else
			i(14156),	-- Bottomless Bag
			-- #endif
			i(21342),	-- Core Felcloth Bag
			-- #if SEASON_OF_DISCOVERY
			applyclassicphase(SOD_PHASE_EIGHT, i(239148, {["timeline"] = { ADDED_1_15_7 }})),	-- Crimson Dawnwoven Bag
			applyclassicphase(SOD_PHASE_EIGHT, i(239147, {["timeline"] = { ADDED_1_15_7 }})),	-- Crusader's Knapsack
			-- #endif
			i(22246),	-- Enchanted Mageweave Pouch
			i(21341, {["timeline"] = { ADDED_1_3_0 }}),	-- Felcloth Bag
			i(5764),	-- Green Silk Pack
			i(4241),	-- Green Woolen Bag
			-- #if SEASON_OF_DISCOVERY
			applyclassicphase(SOD_PHASE_FOUR, i(227844, {["timeline"] = { ADDED_1_15_3 }})),	-- Leather-Reinforced Runecloth Bag
			-- #endif
			i(4238),	-- Linen Bag
			i(10050),	-- Mageweave Bag
			i(14155),	-- Mooncloth Bag
			i(5762),	-- Red Linen Bag
			i(10051),	-- Red Mageweave Bag
			i(5763),	-- Red Woolen Bag
			i(14046),	-- Runecloth Bag
			i(4245),	-- Small Silk Pack
			i(21340),	-- Soul Pouch
			i(4240),	-- Woolen Bag
			applyclassicphase(PHASE_FIVE_RECIPES, i(22249)),	-- Big Bag of Enchantment
			applyclassicphase(PHASE_FIVE, i(22251)),	-- Cenarion Herb Bag
			applyclassicphase(PHASE_FIVE_RECIPES, i(22248)),	-- Enchanted Runecloth Bag
			applyclassicphase(PHASE_FIVE, i(22252)),	-- Satchel of Cenarius
		}),
		n(COMMON_VENDOR_ITEMS, {
			["groups"] = appendAllGroups(
				{	-- Danny Donkey: These are shared with Leatherworking.
					i(2325),	-- Black Dye
					i(6260),	-- Blue Dye
					i(2605),	-- Green Dye
					i(4340),	-- Grey Dye
					i(4342),	-- Purple Dye
					i(2604),	-- Red Dye
					i(2320),	-- Coarse Thread
					i(2321),	-- Fine Thread
					i(4291),	-- Silken Thread
					i(8343),	-- Heavy Silken Thread
					i(14341),	-- Rune Thread
				},
				sharedData({
					["description"] = "Can be bought from Tailoring Suppliers, as well as some Trade vendors around the world.",
					-- Danny Donkey: Disabling this for now, Common Vendor Items is being filled into Minilists when providers are given.
					--[[["providers"] = {
						{ "n", 1347},	-- Alexandra Bolero <Tailoring Supplies>
						{ "n", 3364},	-- Borya <Tailoring Supplies>
						{ "n", 4168},	-- Elynna <Tailoring Supplies>
						{ "n", 3005},	-- Mahu <Tailoring Supplies> [CATA+] / <Leatherworking & Tailoring Supplies>
						{ "n", 4577},	-- Millie Gregorian <Tailoring Supplies>
						{ "n", 8681},	-- Outfitter Eric <Speciality Tailoring Supplies>
						{ "n", 5154},	-- Poranna Snowbraid <Tailoring Supplies>
						-- #if AFTER TBC
						{ "n", 18749},	-- Dalinna <Tailoring Trainer>
						{ "n", 16638},	-- Deynna <Tailoring Supplies>
						{ "n", 19213},	-- Eiin <Specialty Tailoring Supplies>
						{ "n", 18772},	-- Hama <Tailoring Trainer>
						{ "n", 16767},	-- Neii <Tailoring Supplies>
						-- #endif
						-- #if AFTER WRATH
						{ "n", 28726},	-- Dominique Stefano <Tailoring Supplies>
						-- #endif
					},]]
				}, {
					i(2324),	-- Bleach (Only sold by Tailoring Suppliers)
					i(6261),	-- Orange Dye (Only used in Tailoring)
					i(10290),	-- Pink Dye (Only used in Tailoring)
					i(4341),	-- Yellow Dye (Only used in Tailoring)
				})
			)
		}),
		n(DECOR, sharedDataSelf({["timeline"] = { ADDED_11_2_7 }}, {
			i(246685),	-- Dwarven District Banner (DECOR!)
			i(243336),	-- Elder Rise Rug (DECOR!)
		})),
		filter(MISC, {
			applyclassicphase(PHASE_ONE_DIREMAUL, i(18258, {["timeline"] = { REMOVED_4_0_3, ADDED_10_1_5 }})),	-- Gordok Ogre Suit
			-- #if AFTER BFA
			i(2581),	-- Heavy Linen Bandage
			i(8545),	-- Heavy Mageweave Bandage
			i(14530),	-- Heavy Runecloth Bandage
			i(6451),	-- Heavy Silk Bandage
			i(3531),	-- Heavy Wool Bandage
			i(1251),	-- Linen Bandage
			i(8544),	-- Mageweave Bandage
			i(14529),	-- Runecloth Bandage
			i(6450),	-- Silk Bandage
			i(3530),	-- Wool Bandage
			-- #endif
		}),
		filter(REAGENTS, {
			i(2996),	-- Bolt of Linen Cloth
			i(4339),	-- Bolt of Mageweave
			i(14048),	-- Bolt of Runecloth
			i(4305),	-- Bolt of Silk Cloth
			i(2997),	-- Bolt of Woolen Cloth
			i(206645, {["timeline"] = { ADDED_10_1_5 }}),	-- Cursed Cloth
			i(14342, {	-- Mooncloth
				["description"] = "Coordinates are for select Moonwells around the world.",
				["coords"] = {
					{ 43.10, 80.27, MAP.DARNASSUS },	-- Temple of the Moon
					{ 21.0, 53.0, MAP.STORMWIND_CITY },	-- The Park
					{ 60.0, 72.0, MAP.ASHENVALE },	-- Moonwell of Cleansing
				},
			}),
		}),
	}),
});
