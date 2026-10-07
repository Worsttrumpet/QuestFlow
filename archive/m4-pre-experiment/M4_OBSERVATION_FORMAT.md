# Proposed observation/result format

For use once real-client data is available. Nothing here is filled in yet — this is the shape the
findings will be organized into, not a conclusion.

## Per-quest item-reward result

| Field | Meaning |
|---|---|
| `quest_id` | from `GetQuestID()` at the checkpoint |
| `known_item_reward` | what you independently confirmed the quest gives, from the normal quest UI (this is the ground truth the experiment checks against — without it, a `0` from `GetNumQuestRewards` can't be told apart from "no reward exists") |
| `quest_detail.rewards_seen` / `.choices_seen` | counts and `v1_is_nil` status at that checkpoint |
| `quest_complete_immediate.*` | same, at the immediate checkpoint |
| `quest_complete_delayed.*` | same, after the 1.5s delay |
| `retry_after_get_item_info_received.*` | same, if any retry fired; how many retries; whether `v1_is_nil` changed |
| `first_working_checkpoint` | whichever checkpoint first showed real, non-nil item data — or `"none"` |

## Per-quest gossip-API result

| Field | Meaning |
|---|---|
| `GetAvailableQuests.ok` / `.total_count` | whether the call succeeded and how many entries |
| `GetActiveQuests.ok` / `.total_count` | same |
| Sample field presence | which of the known fields (`questID`, `questLevel`, etc.) actually appeared |

## Evidence tagging for the eventual writeup

Following the same convention as M0–M3:
- `[V]` — a checkpoint that produced real, non-nil item data on this real client, this session.
- `[?]` — a checkpoint that produced nil/empty data; not proof it never works, just not observed working
  this session (small sample, per M4_PLAN.md's own standard of not overclaiming from limited data).
- Any full-zero result (`GetNumQuestRewards` reads `0`) on a quest independently confirmed to have an
  item reward is itself a real, reportable finding — not a "the experiment failed" case.

## What this format deliberately does not yet decide

Whether item-reward fields join the M4 harvest contract, and at which checkpoint — that decision comes
after real data, per M4_PLAN.md §3a ("outcome drives the schema, not the other way around"), and is
explicitly out of scope until you provide results and I'm asked to interpret them.
