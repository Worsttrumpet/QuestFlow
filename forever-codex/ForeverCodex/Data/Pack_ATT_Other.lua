-- ForeverCodex/Data/Pack_ATT_Other.lua
-- GENERATED FILE -- do not hand-edit. Regenerate with forever-codex/generator/build_codex_data.py.
-- Generator: codex-data-1
-- input zones/zephras isle.lua sha256=981cc48d7c1b3c30141bf77cb840c4ea19b987a8fee001c91aed24fd6edb979a
--
-- PROVENANCE: src=att, verified=false. Source: ATT (AllTheThings, MIT) 'forever' database, commit 8e25511677df4ea5c3d0322009eafc18f203ffd3. Coordinates have unresolved upstream provenance; `req` is a REQUIRED level (ATT `lvl`), not a quest level. Nothing here is a confirmed Forever fact. Public redistribution of this file is a separate, undecided licensing question.

local _, ns = ...
ForeverCodex.RegisterPack("quests", "att:other-zones", {
  meta = {label = "ATT other zones", license = "MIT", priority = 10, quests = 5, source = "https://github.com/ATTWoWAddon/AllTheThings.git", sourceRef = "8e25511677df4ea5c3d0322009eafc18f203ffd3", src = "att", verified = false},
  zones = {
    {key = "zephras-isle", label = "Zephras Isle", map = 2521, noCoord = 0, quests = 5},
  },
  quests = {
  [92460] = { id = 92460, name = "Coming of Age", zone = "zephras-isle", giverNpc = 251362, giverName = "Ailee Farheart <Rangers of Thendal Grove>", map = 2521, x = 0.428, y = 0.234 },
  [92461] = { id = 92461, name = "Harmony in Balance", zone = "zephras-isle", giverNpc = 251361, giverName = "Rorian the Dayseeker", map = 2521, x = 0.421, y = 0.235, prereq = {92460} },
  [92462] = { id = 92462, name = "Infestation Investigation", zone = "zephras-isle", giverNpc = 251368, giverName = "Elatrell Featherlight <Rangers of Thendal Grove>", map = 2521, x = 0.434, y = 0.248, prereq = {92460} },
  [92465] = { id = 92465, name = "Agitators", zone = "zephras-isle", giverNpc = 249363, giverName = "Yala Windwatcher", map = 2521, x = 0.473, y = 0.219, prereq = {92460} },
  [92481] = { id = 92481, name = "A Student of the Arcane", zone = "zephras-isle", giverNpc = 251361, giverName = "Rorian the Dayseeker", map = 2521, x = 0.421, y = 0.235, prereq = {92461} },
  },
})
