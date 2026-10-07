# M8.14 Probe Guide: Arrow, Facing and Drag Test

About 10-15 minutes. Outdoors, on open, fairly level ground, **on foot** (not mounted, no vehicle). You need room
to walk about 30-40 yards north and 30-40 yards east. No quests, no quest actions.

## Install

1. Exit WoW (or sit at character select).
2. Copy `addon/ForeverProbeM814` into `E:\World of Warcraft\_classic_beta_\Interface\AddOns\`.
   (Older probe folders can stay or go; they do not interact with this one.)
3. Log in with the same character as earlier probes. At character select confirm **Forever Probe M8.14 (Arrow and
   Drag)** is enabled.
4. Type `/console scriptErrors 1`. Note the login line `[FProbeM814] m8-14-probe-0.2 loaded.`
5. In the game's interface options, make sure **Rotate Minimap is OFF**, so "up" on the minimap is north and the
   little arrow on the minimap shows which way your character faces.

## Part 1 - the window

1. `/fprobe814` opens the test window.
2. Screenshot the whole window. It should show: four texture pairs A-D (left = at rest, right = turning with
   your facing), three labelled bearing arrows D / M / B, the numbers, the glyph line, and a blue test button.
3. Turn your character slowly in a full circle (A/D keys, or right-mouse-drag) and watch the facing number and the
   right-hand copies. Screenshot once while turning if anything looks wrong.

## Part 2 - which way is "facing" (about 2 minutes)

Use the minimap arrow to face each compass direction (up on the minimap = north). Roughly right is fine.
Stand still, face the direction, then type:

```
/fprobe814 face N
/fprobe814 face E
/fprobe814 face S
/fprobe814 face W
```

Each prints the value; after N plus E or W you will see a `facing: ... increases CCW/CW [ok]` line. Screenshot
the chat.

## Part 3 - which way is north in world coordinates (about 3 minutes)

1. Pick a spot. Face north (minimap up). Type `/fprobe814 mark start`.
2. Run **about 30-40 yards straight north** (keep the minimap arrow pointing up). Type `/fprobe814 mark north`.
3. Walk back to roughly where you started (within a few yards is fine). Do not re-mark start.
4. Face east (minimap right). Run **about 30-40 yards straight east**. Type `/fprobe814 mark east`.
5. The chat now shows `axes: north=+x east=-y (...) [ok]` (or whatever the client reports) and a separate
   `UnitPosition axes:` line. Screenshot it.
   - If it says `leg too short` or `leg not straight`, walk a longer / straighter leg and re-mark that one point.
   - `/fprobe814 calc` re-prints the derived values; `/fprobe814 clear` starts over.

## Part 4 - the test arrows (about 4 minutes)

The window now shows derived arrows. D and M are the same angle with opposite rotation signs; B is the
unverified retail-style assumption. Which of them is right is exactly what this part shows.

1. `/fprobe814 target here`, then run about 40 yards in any direction (the target is the spot you left).
2. Turn slowly to face the target. Screenshot the window when you are **facing the target** and again when you
   are **facing directly away**. One of D/M should point straight up when facing it; note which.
3. Turn 90 degrees to your right (clockwise) and screenshot: the correct arrow should now point to the left.
4. `/fprobe814 target jorn` points the arrows at Jorn Skyseer's turn-in spot (Barrens, 44.9, 59.1) if you are on
   Kalimdor. If you are near the Crossroads, walk toward it and screenshot the arrow once; otherwise skip.
5. Optional: `/fprobe814 tex B`, `tex C`, `tex D` change the texture the D/M/B arrows use. Screenshot whichever
   looks like a sensible arrow.

Keep the numbers visible in every screenshot (dx, dy, components, compass, me, rel).

## Part 5 - clicking and dragging (about 2 minutes)

1. Left-click the blue button 3 times, then right-click it once. The text beside it counts L and R.
2. **Right-drag the blue button** around the screen, then drop it. Do this twice, once near the minimap and once
   a larger drag in a circle around the minimap. Note the `ring=` angle that appears.
3. **Right-drag the whole window** (on the black area, not the button) and drop it.
4. Screenshot the window with the counters showing.

## Finish

1. `/fprobe814 report`. Screenshot all the chat lines.
2. `/reload` (this saves the data). Wait for the load line.
3. Close the window with `/fprobe814`.

## Send back

- The screenshots (Parts 1-5 and the report).
- `E:\World of Warcraft\_classic_beta_\WTF\Account\<YOUR ACCOUNT>\SavedVariables\ForeverProbeM814.lua`
- Whether any Lua error popped up.
- Anything that looked odd (an arrow pointing the wrong way, a missing texture, a blank-box glyph, a drag that
  also clicked).

## Afterwards

Once analysed, delete `ForeverProbeM814` from AddOns. It writes only its own SavedVariables file.
