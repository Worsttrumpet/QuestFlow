# M8.12 Guide: Startup-State Probe Test

About 3 minutes. No questing, no travel, no quest actions. The probe records everything automatically.

## Install

1. Exit WoW completely.
2. Delete `Interface\AddOns\ForeverProbeM810` (M8.10 is locked).
3. Copy `addon/ForeverProbeM812` into `E:\World of Warcraft\_classic_beta_\Interface\AddOns\`.
4. Start WoW. At character select, confirm **Forever Probe M8.12 (Startup State)** is enabled.
   Use the same character as the M8.7–M8.10 tests.

## Test

1. **Fresh login:** enter the world from character select.
2. Type `/console scriptErrors 1`.
3. Wait for `[FProbeM812] startup capture complete.` (a few seconds after login).
4. `/fprobe812` — screenshot the lines.
5. `/reload`. (This saves the login session and starts the reload session.)
6. Wait for `startup capture complete.` again, then `/fprobe812` — screenshot.
7. `/reload` once more. (This saves the reload session.)

## Optional

If you know a quest ID you've turned in, or one that's sitting in your log, you can check it directly:
`/fprobe812 q <questID>`. Not required.

## Send back

- The two screenshots.
- `E:\World of Warcraft\_classic_beta_\WTF\Account\<YOUR ACCOUNT>\SavedVariables\ForeverProbeM812.lua`.
- Whether any Lua error popped up.

## Afterwards

Once analysed, delete `ForeverProbeM812` from AddOns. It writes only its own SavedVariables file.
