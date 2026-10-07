-- ForeverQuestGuide/RouteData.lua
-- GENERATED FILE -- do not hand-edit. Edit the *_route.json files under m8-guide-addon/routes/
-- instead, then re-run m8-guide-addon/routes/generate_route_data.py.
--
-- Every route here is HAND-AUTHORED data (see the *_route.json source files). No step's
-- existence, ordering, or instruction text was derived from quest ID, ATT, or any inferred
-- relationship -- provenance = 'route-authored' on every route and every step says so explicitly.
-- A step's quest_id/objective_index are references into ns.QuestData (Data.lua); no quest title,
-- giver name, or objective text is duplicated here -- the UI looks those up live.
-- 'why' and 'required' (M8.6-A) are also route-authored, optional (nil when the author omitted
-- them), and never inferred from quest data, ATT, or anything else.
-- M6 guide dataset SHA-256 this was validated against: 13999e906b802d73303bae5add24f75300602d9a0cd50f57fe80e86711173b93
-- Route 'thunder-lizards-test-route' source SHA-256: 9171e8ed7b79cc96d4b305eccdb63b24910d94dfa89110d4a296f6e67fd04bfb

local _, ns = ...

ns.Routes = {
  ["thunder-lizards-test-route"] = {
    id = "thunder-lizards-test-route",
    title = "Barrens Level 18 (M8.3 test route)",
    provenance = "route-authored",
    first_step = "s1",
    steps = {
      ["s1"] = {
        id = "s1",
        provenance = "route-authored",
        kind = "ACCEPT",
        quest_id = 907,
        objective_index = nil,
        npc = { name = "Jorn Skyseer", npc_id = 3387 },
        destination = nil,
        display_text = "Talk to Jorn Skyseer and accept the quest. (No offer-screen position was ever captured for this quest -- see M6 evidence; only its turn-in screen was observed.)",
        next_step_id = "s2",
        why = nil,
        required = true,
      },
      ["s2"] = {
        id = "s2",
        provenance = "route-authored",
        kind = "TRAVEL",
        quest_id = 907,
        objective_index = nil,
        npc = nil,
        destination = nil,
        display_text = "Head out to find Thunder Lizards. No objective-area coordinate exists anywhere in this project for this quest -- follow the objective text below.",
        next_step_id = "s3",
        why = nil,
        required = true,
      },
      ["s3"] = {
        id = "s3",
        provenance = "route-authored",
        kind = "OBJECTIVE",
        quest_id = 907,
        objective_index = 1,
        npc = nil,
        destination = nil,
        display_text = "Complete the objective shown below.",
        next_step_id = "s4",
        why = nil,
        required = true,
      },
      ["s4"] = {
        id = "s4",
        provenance = "route-authored",
        kind = "TURN_IN",
        quest_id = 907,
        objective_index = nil,
        npc = { name = "Jorn Skyseer", npc_id = 3387 },
        destination = {
          kind = "OBSERVED_PLAYER_POSITION",
          ui_map_id = 1413,
          x = 0.448696494102478,
          y = 0.5909364223480225,
        },
        display_text = "Return to Jorn Skyseer and turn in the quest. This position was M6-observed at this quest's own quest_complete_delayed checkpoint -- it is where a player was standing at turn-in, not a surveyed NPC location.",
        next_step_id = "s5",
        why = "Turn in Enraged Thunder Lizards here before moving on to the next quest.",
        required = true,
      },
      ["s5"] = {
        id = "s5",
        provenance = "route-authored",
        kind = "ACCEPT",
        quest_id = 959,
        objective_index = nil,
        npc = { name = "Crane Operator Bigglefuzz", npc_id = 3665 },
        destination = nil,
        display_text = "This route-author chose to continue with a different level-18 Barrens quest next. Nothing in M6 or ATT establishes that these two quests are related -- this transition is entirely route-authored. (No offer-screen position was captured for this quest either.)",
        next_step_id = nil,
        why = "Optional: a second level-18 Barrens quest to fill out the route once 907 is done. Skip it if you'd rather move on.",
        required = false,
      },
    },
    step_order = { "s1", "s2", "s3", "s4", "s5" },
  },
}

-- Deterministic route display order (the order route files were found in, sorted by filename).
ns.RouteOrder = { "thunder-lizards-test-route" }
