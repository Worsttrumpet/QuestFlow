# M8.11: Progression Architecture and Design

**Type: design only.** No production Lua, route data, route schema, ForeverRecorder, M8.7–M8.10 file, or
`M8_2_SCOPE.md` is created or modified. No client probe is run.

**Scope date:** 2026-09-30. Intended destination: `forever-db/docs/M8_11_SCOPE.md`.

## Purpose

Turn the real-client evidence from M8.7–M8.10 into an implementable progression architecture for
ForeverQuestGuide, grounded in the actual v0.6 code, without choosing the user-facing progression mode.

## Inputs

| Source | Used for |
|---|---|
| M8.7 report | ACCEPT signal `QUEST_ACCEPTED(questID)` |
| M8.8 report | TURN_IN signal `QUEST_TURNED_IN(questID, xp, money)`; `QUEST_REMOVED` unsuitable; state lag at turn-in |
| M8.9 report | OBJECTIVE detection at `UNIT_QUEST_LOG_CHANGED("player")`; turn-in reset trap; transient blank names; `objective_index` mapping open |
| M8.10 report | TRAVEL by addon-computed distance; navigation/arrow unsuitable; cross-continent unsupported; ~10 yd game radius |
| `M8_0_SCOPE.md` §2 (as cited in v0.6 source) | SavedVariables: `/reload` saves reliable, logout/character-select saves not |
| ForeverQuestGuide v0.6 source (`UI.lua`, `Core.lua`, `Preferences.lua`, `RouteData.lua`, `MapPin.lua`) | Current architecture, route state, persistence, `build()` upvalues |

## Questions (from the milestone brief)

1. Progression mode: concrete differences between manual, semi-automatic, and automatic (no ranking).
2. Step state machine and what to persist.
3. Event architecture: one controller, primary signals vs hints.
4. Startup reconciliation: what can be checked, labelled VERIFIED/UNVERIFIED.
5. Persistence: what is safe, what is not.
6. TRAVEL contract: client / route-data / schema / provenance, separated.
7. OBJECTIVE matching: index vs text vs type vs quest-level completion.
8. `build()` 60-upvalue problem: cause and minimal refactor.
9. Manual override and recovery controls.

## Deliverables

- `docs/M8_11_SCOPE.md` — this document
- `docs/PROGRESSION_DESIGN.md` — the design (sections 1–9)
- `docs/M8_11_COMPLETION_REPORT.md` — classification (VERIFIED on real client / VERIFIED by existing code /
  UNVERIFIED / DESIGN DECISION NEEDED / FUTURE DATA WORK) and readiness

## Out of scope

Implementation of any kind, the refactor itself, route/schema changes, choosing the progression mode, new client
probes, `M8_2_SCOPE.md` edits.
