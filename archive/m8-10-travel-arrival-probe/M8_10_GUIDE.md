# M8.10 Guide: Travel & Arrival Probe Test

About 5 minutes. The only movement is a ~30-yard walk. No travel between zones.

Do this outdoors in an ordinary zone (not a dungeon, not a city interior).

## Install

1. Exit WoW (or sit at character select).
2. Delete `Interface\AddOns\ForeverProbeM89` (M8.9 is locked).
3. Copy `addon/ForeverProbeM810` into `E:\World of Warcraft\_classic_beta_\Interface\AddOns\`.
4. Log in; confirm **Forever Probe M8.10 (Travel & Arrival)** is enabled.
5. If you have a map pin from Show on Map, that's fine; the probe will read it.

## Part A — standing still

1. Type `/console scriptErrors 1`.
2. Note the login line (orange `[FProbeM810]`): APIs present/absent counts and whether
   `NAVIGATION_DESTINATION_REACHED` is `registered`.
3. `/fprobe810 state` — screenshot the four lines. (Baseline, probably with no waypoint.)
4. `/fprobe810 near` — sets a waypoint ~30 yards north of you. Confirm the pin and arrow appear.
5. `/fprobe810 state` again — screenshot. This shows whether the waypoint can be **read back** and what distances
   are available while you stand still.

## Part B — the short walk

6. Walk slowly toward the pin (north). Every 3 s a line like
   `nav=24.0 yd | world=24.1 yd | mapsize=24.1 yd | frac=0.0080 | same map=true` appears. Screenshot two or three.
7. Stand **on** the pin for about 5 seconds. Watch for `NAVIGATION_DESTINATION_REACHED fired` and/or
   `waypoint is GONE (...)`. Screenshot whatever appears (or note that nothing did).
8. If the waypoint is still there: walk about 10 yards past it, then `/fprobe810 state` and screenshot.
9. *Optional, only if the waypoint vanished on its own in step 7:* `/fprobe810 near` once more and repeat
   steps 6–7 to see if it happens the same way.

## Part C — other maps, standing still

10. **Another zone on your continent.** If you're in Silverpine Forest or elsewhere in the Eastern Kingdoms:
    `/fprobe810 pin 1420 0.61 0.52` (Tirisfal Glades, near Brill). If you're in Kalimdor instead:
    `/fprobe810 pin 1411 0.516 0.417` (Durotar, Razor Hill).
    The reply names the map; if the name doesn't match, tell me — the map ID was a guess for that zone.
    Then `/fprobe810 state` and screenshot.
11. **Another continent.** In the Eastern Kingdoms: `/fprobe810 pin 1413 0.449 0.591` (The Barrens). In Kalimdor:
    `/fprobe810 pin 1420 0.61 0.52`. Then `/fprobe810 state` and screenshot.
12. `/fprobe810 clear`.

## Finish

13. `/fprobe810` — screenshot the summary.
14. `/reload` (before logging out).

## Send back

- The screenshots from steps 3, 5, 6, 7 (and 8 if done), 10, 11, 13.
- `E:\World of Warcraft\_classic_beta_\WTF\Account\<YOUR ACCOUNT>\SavedVariables\ForeverProbeM810.lua`.
- Which zone you were in, and whether any Lua error popped up.

## Afterwards

Once analysed, delete `ForeverProbeM810` from AddOns. It writes only its own SavedVariables file. Your map
waypoint is left cleared by step 12.
