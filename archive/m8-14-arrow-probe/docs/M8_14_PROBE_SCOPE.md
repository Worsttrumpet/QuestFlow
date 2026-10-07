# M8.14 Probe Scope: Guide Arrow and Draggable UI Evidence

**Status: probe v0.2 implemented and self-tested (111/111 stub checks). NOT yet run on the real client.**
Nothing below is evidence about Forever until the SavedVariables from the real-client run have been analysed.

## Purpose

M8.14's Guide Arrow (B7) and draggable minimap button (B6) rest on client behaviour no earlier milestone
verified. This disposable probe (`ForeverProbeM814`, `/fprobe814`) records that behaviour. It is read-only: no
quest, map, or waypoint calls, and no changes to the guide addon. **It does not implement the Guide Arrow.** The
D/M/B arrows in its window exist only to display, beside every intermediate number, which convention the client
reports.

## Why direction was never tested before

M8.10 validated the addon's own *distance* calculation (`GetBestMapForUnit` + `GetPlayerMapPosition` +
`GetWorldPosFromMapPos`). Distance is the same whichever way the world axes point, so M8.10 says nothing about
which axis is north. An arrow needs direction, so the axis convention and the facing convention must both be
measured, not assumed.

## Questions and what answers them

| # | Question | How the probe answers it | Recorded in `ForeverProbeM814DB.sessions[n].results` |
|---|---|---|---|
| Q1 | Does `GetPlayerFacing` exist, and does it return a number that tracks turning? | Live readout; range, sample count, nil/error counts, longest gap between valid samples | `facing` |
| Q2 | What is its convention: value at north, and does it grow counter-clockwise or clockwise? | `/fprobe814 face N\|E\|S\|W` while facing each compass direction | `faces`, `derived.facing` |
| Q3 | Which world component (x or y) is north / east, and with what sign? | `/fprobe814 mark start\|north\|east` around a ~30 yd walk north and ~30 yd walk east; derived for `C_Map` world coordinates and, separately and raw, for `UnitPosition`'s two components | `marks`, `derived.axes_world`, `derived.axes_unit` |
| Q4 | Do the candidate arrow textures load, which way does each point at rotation 0, and does `SetRotation` work? | Rest copy beside a copy rotated by raw facing; `rotation_ok` per texture; screenshot | `textures` |
| Q5 | Do the arrow glyphs (up/right/down arrows, check mark) render in the game font? | One glyph line with ASCII fallbacks; screenshot | (screenshot only) |
| Q6 | Does a right-button drag work on a plain frame? | Window right-drag; `GetPoint` read-back | `drag` |
| Q7 | Can one Button keep its left click while right-dragging (the minimap-button case)? | Test button counting left clicks, right clicks, drag starts/stops, `OnUpdate` samples while dragging | `button` |
| Q8 | What do `GetCursorPosition` and the Minimap geometry look like, and does the ring angle come out right? | Cursor and ring angle (degrees, counter-clockwise from east) at drag start, during, and at stop; Minimap centre/size/scale/shape; UIParent scale | `button`, `geometry` |
| Q9 | End to end: does an arrow built from the derived conventions point at a known destination? | Target = route step s4 (Jorn Skyseer, map 1413, 0.4487, 0.5909) or `target here`; arrows D (derived), M (mirrored), B (baseline, labelled as an assumption), with dx, dy, north/east components, compass bearing, player heading and relative angle printed | `bearing_last`, `bearing_log` (max 40 snapshots, one per 3 s) |

## How the bearing is built (so the numbers can be audited)

1. `dx, dy` = target world position minus player world position.
2. `north_comp`, `east_comp` = the derived axis and sign applied to `dx, dy` (Q3).
3. `compass` = `atan2(east_comp, north_comp)`, clockwise from north.
4. `player compass` = the live facing converted with the derived value-at-north and direction (Q2).
5. `rel` = `compass - player compass`, wrapped to (-pi, pi]: clockwise angle from where the player faces.
6. Arrow D rotates by `-rel` and arrow M by `+rel`. This assumes the art points up at rotation 0 and that
   `SetRotation` is counter-clockwise on screen. Both assumptions are what Q4 and the screenshot test; if D is
   wrong and M is right, the screenshot shows it, with no maths hidden.
7. Arrow B uses the retail-documented convention (north = +x, east = -y, facing zero at north, counter-clockwise).
   It is **an assumption, not evidence**, shown only for comparison with what was derived.

## Success criteria

- Q2 and Q3 each report `status = ok` (straight legs of at least 10 yd; quarter turns within 0.5 rad of pi/2).
- Q9: facing the target, one arrow points straight up; turning clockwise moves it counter-clockwise on screen.
- Q7: left-click count and right-drag count both increase on the same button.

## What each outcome means for the Guide Arrow (B7) and minimap button (B6)

| Result | Consequence |
|---|---|
| Facing works, a texture rotates, conventions derived | True relative arrow: rotation from the derived conventions |
| Facing works, no usable texture | Relative direction as text or glyphs that render |
| Facing absent or nil | Compass bearing only (N/NE/E ...), labelled as compass, not relative |
| Axes derive as `unclear` | No arrow; distance text only, until re-measured |
| Button right-drag works with left click intact | Free-position draggable minimap button (B6) |
| Button right-drag fails or kills the left click | Fixed-position button; reposition via Options only |
| Cursor/Minimap geometry unusable | Ring positioning dropped; free screen positioning instead |

## Not in this probe

The Guide Arrow itself, any change to `m8-13-progression/`, quest or waypoint calls, Options menu dropdown
templates (the plan builds that menu from plain buttons), and any database or ATT work.

## What the stub self-test does and does not prove

`tests/run_probe_selftest.lua` (Lua 5.1) drives the probe against a fake client whose conventions the test
chooses: a retail-like one, and a deliberately different one (north = -y, east = +x, facing clockwise with an
offset). It proves the probe derives the convention a client reports, computes bearings from it, refuses to guess
when legs are short or crooked, never raises on missing or hostile APIs, counts clicks and drags, and saves only
SavedVariables-safe values. It was also run against deliberately broken copies of the probe to confirm the tests
fail when they should. **It proves nothing about Forever's behaviour.**
