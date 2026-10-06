-- ForeverCodex.Providers.Planned: the future systems, REGISTERED but inert.
--
-- Nothing here generates actions, and nothing here fakes data. Each entry exists so that (a) the UI can show the
-- toggle greyed out as "planned", (b) the engine's type/system plumbing is already in place, and (c) a real
-- provider can be added later by registering one with the same key and a generate() function, with no engine
-- change. Systems marked planned cannot be switched on until their provider ships (Preferences.SetSystem refuses).

local addonName, ns = ...
local C = ForeverCodex
local R = ns.Registry

C.RegisterActionType("TRAVEL", { label = "Travel" })

-- Active systems.
C.RegisterSystem({ key = "flight", label = "Suggest flight masters", desc = "Codex may suggest a flight master you pass. It cannot tell which flight paths you already have.", default = true })

-- Planned systems: no reliable data yet.
local planned = {
	{ key = "trainers", label = "Trainers", type = "TRAINER", desc = "Class and profession trainers that fit the route." },
	{ key = "professions", label = "Professions", type = "PROFESSION", desc = "Profession recommendations and skill-ups." },
	{ key = "gathering", label = "Gathering", type = "GATHER", desc = "Gathering opportunities along the route." },
	{ key = "camping", label = "Camping", type = "CAMP", desc = "Camp opportunities and camp utilities (optional)." },
	{ key = "dungeons", label = "Dungeons", type = "DUNGEON", desc = "Dungeon and dungeon-quest recommendations." },
	{ key = "pets", label = "Hunter pets", type = "PET_UPGRADE", desc = "Pet abilities, sources and detour cost." },
	{ key = "respawnSkips", label = "Respawn skips", type = "RESPAWN_SKIP", desc = "Optional shortcuts; never offered in Hardcore." },
	{ key = "classProgression", label = "Class progression", type = "CLASS_PROGRESSION", desc = "Class-specific progression systems." },
	{ key = "group", label = "Group optimization", type = "GROUP", desc = "Complement the group's professions, classes and camp utility." },
}
for _, s in ipairs(planned) do
	C.RegisterActionType(s.type, { label = s.label, planned = true, system = s.key })
	C.RegisterSystem({ key = s.key, label = s.label, desc = s.desc, planned = true })
	C.RegisterProvider({ key = s.key, type = s.type, system = s.key, label = s.label, planned = true })  -- no generate()
end
