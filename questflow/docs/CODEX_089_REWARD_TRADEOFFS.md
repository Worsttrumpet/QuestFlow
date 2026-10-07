# 0.8.9: reward advisor, stat trade-offs

The advisor (ItemProbe -> Items -> Eligibility -> Gear comparison -> Advisor.Classify -> Advisor.Recommend, report-only) already existed. This change fixes how it reads stat differences. No weights, no score.

## Rules added (RewardAdvisor.lua `judge`, `A.IGNORED_STATS`, `A.THRESHOLDS.dpsNoise`)
1. **Unused stats are left out.** For a Warrior or Rogue a difference in intellect or spirit is neither a gain nor a loss, and the reason says so ("not counted for a Rogue: spirit"). PROPOSED table of two classes, from how their resources work in Classic (not read from the client); every other class keeps the plain "every stat counts" comparison. Add a class to `A.IGNORED_STATS` only when it is unambiguous.
2. **A weapon dps difference under 3% of the equipped weapon's dps is noise** (not a gain, not a loss, not mentioned).
3. Unchanged: any loss in a stat that counts keeps an item MIXED and Codex names no pick; a gain of 25% or more is an UPGRADE, less is SLIGHT; usability, eligibility, unknown and unloaded handling.

## Effect (real Q5730, level 15 Rogue, equipped Defias Rapier 8.125 dps, +2 agility)
- Kris of Orgrimmar (-0.125 dps is noise; +4 stamina; -2 agility): still a trade-off (agility is a stat a Rogue uses).
- Hammer of Orgrimmar (+4.3 dps, +3 strength, +3 spirit, -2 agility): still a trade-off; spirit is no longer listed as a gain.
- Axe / Staff: NOT USABLE (both client answers say false), as before.
- Recommendation stays NO_CLEAR_RECOMMENDATION. A choice that is better in stats that count with no loss (e.g. more dps and agility) is an UPGRADE and is picked.
- Cloth items whose only gain is spirit or intellect are no longer a "mixed" item for a Rogue: no improvement (Q93320 slippers).

## Not done
No per-class stat priorities, no weapon-type preferences (a Rogue's dagger for backstab), no spec logic, no future-use data. Weapon proficiency still comes only from client evidence.

Tests: `advisor_tests.lua` (new 0.8.9 section, one Q93320 expectation updated). No planner golden changed.
