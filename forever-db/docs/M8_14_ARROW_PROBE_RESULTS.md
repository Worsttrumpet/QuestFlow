# M8.14 Arrow & Drag Probe — Results

**Real-client run:** 2026-09-30, build 70124. Probe `m8-14-probe-0.1`. Evidence: `evidence/ForeverProbeM814.lua`
(1630 bytes, SHA-256 `76a31192034a979595574766b5b2e446f05540a9ee486ce854c4837463b37487`) plus operator screenshots.

| Question | Result | Evidence |
|---|---|---|
| `GetPlayerFacing()` exists and tracks turning | **Yes** | 2,301 samples; range 0.0069–6.2830 rad (full 0–360°) while the operator turned in a circle |
| Built-in arrow textures load | **Yes, all four** | A `Interface\\Minimap\\MinimapArrow` (file 136431), B `Interface\\Minimap\\Rotating-MinimapGuideArrow` (136448), C `Interface\\Buttons\\UI-SpellbookIcon-NextPage-Up` (130866), D `Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Up` (130952) |
| `Texture:SetRotation` works | **Yes, all four** | `rotation_ok = true`; screenshot shows C (right-pointing art) rotated to point up at 85° |
| Arrow / check-mark glyphs (U+2191…U+2193, U+2197, U+2198, U+2713) in the game font | **No** — render as blank boxes | Screenshot; same class of failure as emoji in M8.3 |
| ASCII `^ > v <` | Render | Screenshot |
| Right-click drag (`SetMovable`, `RegisterForDrag("RightButton")`, `StartMoving`, `StopMovingOrSizing`, `GetPoint`) | **Works** | 7 drags started and stopped; last point read back (`BOTTOM`, -18.3, 124.2) |
| Left vs right click distinguishable | **Yes** | `OnMouseUp` recorded LeftButton 12, RightButton 2 |
| `GetCursorPosition`, `Minimap:GetCenter` | Present | API inventory (not exercised) |

## Design consequences for the Guide Arrow (M8.14 plan B7)

- **Relative arrow:** rotation = bearing to destination − `GetPlayerFacing()`.
- **Art:** texture B, the game's own guide-arrow image.
- **Arrival:** the word "Arrived", not a check-mark glyph.
- **Distance:** addon-computed (M8.10), never the game's navigation distance.
- **Moving the arrow and the minimap button:** right-button drag; left click stays a normal click.
