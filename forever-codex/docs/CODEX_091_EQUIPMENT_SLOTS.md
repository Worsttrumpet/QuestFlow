# 0.9.1: the reward advisor respects where an item can legally go

Uses only what ItemProbe already proves: the reward's and the worn items' equip locations (`Gear.SLOTS_FOR`) and what is worn in each slot. No item names, no scores, no new stat rules; every 0.8.9 expectation passes unchanged.

## Slot rules (RewardAdvisor.lua `compareOutcome`, `entryRank`, `chooseEntry`)
| equip location | legal slots | compared with |
|---|---|---|
| main-hand-only | main hand | the main hand, never the off hand |
| off-hand-only / shield / holdable | off hand | the off hand, never the main hand |
| one-hand / either hand (`INVTYPE_WEAPON`) | both hands | the item in EACH hand; the legal slot where it does best is used (empty slot first; then a clear gain, a slight gain, mixed, no gain; the larger relative gain breaks a tie between two gains) |
| two-hand | main hand | compared only when the off hand is READ AND EMPTY; with an off-hand item worn (or the off hand unread) the result is UNKNOWN and says it would replace both hands |
| any off-hand slot while a two-hander is wielded | - | not "free": that entry is UNKNOWN ("your main hand holds a two-handed weapon") |
Other armor slots are unchanged. A worn item is only ever the thing a reward REPLACES in its own slot: Codex never moves a worn item to another slot, so a main-hand-only weapon is never an off-hand candidate.

## What changed in behaviour
- When no legal slot is a gain, the old code reported the first slot (main hand); it now reports the best-ranked one (a trade-off in the off hand is reported as MIXED, not as "no gain" from the main hand).
- A two-hander is no longer called an upgrade over the main hand while it would also remove an off-hand item.
- An empty off hand is no longer a free slot while a two-hander is wielded.
- An either-hand weapon that is better than the off-hand item (but not the main hand) was already recognised as an upgrade; a test now pins it.

## Unique items
No change. The item facts carry no Unique metadata, the game already offers only selectable rewards, and eligibility stays in `Eligibility`.

Tests: `advisor_tests.lua` (0.9.1 section: main-hand-only, off-hand-only, either-hand, worn main-hand-only item, two-handers, multi-scenario, the real Q5730 setup). No golden changed.
