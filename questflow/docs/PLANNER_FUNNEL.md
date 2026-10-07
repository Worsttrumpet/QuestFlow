# The planner funnel: available is not recommended (0.12.0)

## What the audit found

A level 16 character was being sent to "A Donation of Wool" and to level 6 quests. Nothing was wrong with the data's idea that those quests exist or could be taken. The planner simply had no stage that asked whether they were worth recommending.

Root causes, in the order a quest passes through the code:

1. **Quest value was level-blind.** `Planner.lua` BASE values are flat policy points (ACCEPT 20, OBJECTIVE 60, TURN_IN 40). Only an ACCEPT got a level-fit term, scaled by 0.5, and at six or more levels below the player it was a few points. A level 6 quest at level 16 was worth about 19.5 points against 23.9 for a perfect fit. Distance (0.3 points per second) was therefore the main discriminator, so the nearest available quest won.
2. **Eligibility let them in.** `Providers/Quest.lua` hides a quest only past the style's `maxGap` (Efficient 14, Fast 10, Completionist never). A quest 10 levels below passed.
3. **Over-level quests were rewarded.** `Engine.LevelFit` clamps a negative gap to zero, so a quest far above the player got the full level-fit bonus.
4. **Unknown availability was routable.** A pickup with no client offer evidence is only "possible" beyond 500 yards (`UNCONFIRMED_MAX_YD`). Within it, it scored at 0.9 of full value.
5. **No notion of a goal.** A dungeon quest in the log could not be NOW from outside (by design, since 0.8.6), but nothing made the dungeon's hand-ins, or the quests leading to them, matter more than a random pickup.
6. **Seasonal classification covered only QuestieDB data.** `view.event` comes from QuestieDB's negative quest sort against a fixed list of categories. A quest known only from ATT has no sort, so it cannot be classified.
7. **The ATT data pipeline drops the quest cost.** In ATT's source, "A Donation of Wool" is `lvl 12` with `cost = 60 x Wool Cloth`. Quest Flow's generator keeps `lvl` (as a required level) but not `cost`, so the data cannot say the quest needs 60 items. This is a data limitation, not something the planner can fix; see "Not solved" below.

How the sequencer works also matters: the value of a stop decides only *which* stops are in the best three-stop sequence and the order within it (travel cost and the hand-in-first rule). Boosting a value changes the result only when the plan is truncated or a stop would otherwise be net-negative. The tests use scenarios where that is the case.

## The funnel now

```
AVAILABILITY    Providers/Quest + OfferProbe (client offer evidence; UNKNOWN stays UNKNOWN)
ELIGIBILITY     faction / class / required level / repeatable / seasonal (unless opted in)
CLASSIFICATION  Progression.Band: current / low / gray / above / unknown
RELEVANCE       Progression.Goal + chain reasons
VALUE           Planner.valueOf x the classification multiplier
PRIORITY        Planner sequencing (value minus time and travel)
```

* **Bands** use the quest level only (QuestieDB's questLevel). gap = player - quest. CURRENT up to 5 below; LOW 6 to the green range; GRAY beyond it; ABOVE 5 over; ABOVE_FAR 8 over. The green range is the client's own `GetQuestGreenRange()` when it answers, else 8; the report states which. A quest with only a required level (ATT) is UNKNOWN: no band is invented and its value is unchanged.
* **A reason lets a bad band through**: PINNED (you added it), DUNGEON_QUEST (the game tags it), LEADS_TO_LOG, LEADS_TO_DUNGEON, LEADS_TO_FIT (a quest within three steps after it is held, a dungeon quest, or in the CURRENT band). With a goal, LOW quests need a reason too.
* **Quests you already hold are never rejected**; a gray one's objectives are worth half, its hand-in full value.
* **The goal** is only derived from dungeon quests in your log as the game tags them (`Dungeons.List`). No tag from the client means no goal, and the report says so. Goal quests count 2.5x; quests that lead to them 2x.
* **Seasonal** quests are not in the normal pool unless `/qflow seasonal on`; even then they are only routed when the game itself offers them (`SEASONAL_UNPROVEN` otherwise).
* `Planner.PROGRESSION = false` removes the stage (used by tests as a mutation check). The legacy one-action engine is unchanged.

## Answers to the confusions you listed

| Confusion | Before | Now |
|---|---|---|
| available vs recommended | same | separate stages; a game-offered gray quest is still rejected |
| nearby vs valuable | distance decided | band and reason first |
| low-level vs worthwhile | small level-fit term | gray excluded without a reason, low penalised |
| static data vs client state | partly (offer evidence) | unchanged; seasonal also needs a client offer |
| quest existence vs availability | separated by OfferProbe | unchanged |
| quest location vs useful objective location | not separated | not changed (still the data's location) |
| chain membership vs current progression | one-hop credit on hand-ins | chains to a held, dungeon or fitting quest are reasons |
| dungeon association vs relevance | dungeon objectives deferred | goal derived from the log; goal quests boosted |
| prerequisite vs optional | not separated | a prerequisite of fitting content is a reason |
| completion vs progression | not separated | a gray quest's objectives are discounted |

## Not solved (said plainly)

* **A Donation of Wool** passes the funnel if the data gives it no level, or a level in the CURRENT band. Its real distinguishing fact (it costs 60 Wool Cloth) is dropped by the generator. Carrying ATT's `cost` through `forever-db` and `build_codex_data.py` would let the planner treat "needs items you do not hold" as a reason to reject. That changes the shipped data files, so it is left for the owner to decide.
* The planner does not yet send you toward a dungeon entrance as an action of its own. The goal raises the value of the goal's hand-ins and lead-ins and removes junk; when nothing qualifies NOW is empty.
* Level data: only QuestieDB has a quest level. ATT-only quests are never judged by level.
* The bands are design values, not game facts, and are named in `Progression.lua` for tuning.
* Which quests the game tags as dungeon quests on Forever is unverified until a report shows `C_QuestLog.GetQuestTagInfo` answering.

## Real-client validation

`/qflow report`, section **PLANNER FUNNEL**: the green range and its source, seasonal status, the goal, the count of judged actions by band, every rejected / penalised / boosted quest with its reason, and NOW's band, basis, verdict and reasons. See Part I of `docs/release/RC_MANUAL_TEST_CHECKLIST.md` for the Ruins of Lordaeron test.
