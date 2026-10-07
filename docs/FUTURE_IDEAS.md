# Future ideas (not part of the first public release)

These came up during development. None of them is a release blocker, none is promised, and none was started for the release. The long, status-tagged list with reasons is `questflow/docs/CODEX_BACKLOG.md`.

- **Using quest items from the Quest Flow tracker.** Needs a decision about secure action buttons versus the "no protected functions" rule.
- **Smarter handling of quests with no known location** (a fallback built from quest description text), once the client's quest text API is proven on Forever.
- **Quest value and "gray quest" decisions** with a small, explainable model.
- **Quest-cap and quest-starting-item awareness** (full quest log warnings).
- **Smarter handling of overlapping objectives** (ALSO COMPLETE).
- **Spec-aware reward advice**, if a spec source is ever proven on the client and an explainable rule exists. The current advisor deliberately has no stat weights.
- **More classes in the "stats this class ignores" table** (currently Warrior and Rogue only).
- **Making the DUNGEON QUESTS rows clickable** (quest details).
- **Long-term planner routing** (look-ahead, travel costs, hub bundling).
- **Localised clients.** Non-English clients have not been tested.
- **Automatic CurseForge / GitHub release publishing** (the release ZIP is currently uploaded by hand).
