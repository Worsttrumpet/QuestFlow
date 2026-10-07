# 0.9.7: reward icons replace the text tags (presentation only)

The advisor's decisions, ItemProbe, eligibility and slot logic are untouched. The overlay (UI/RewardOverlay.lua) now draws a small icon set (UI/CodexIcons.lua) instead of `[TAG]` text. See `codex_icons_preview.png` (made by `generator/icon_preview.py`).

## The set (7 x 7 pixel glyphs, painted with plain colour textures: no image files, no new client API)
| icon | meaning | shape |
|---|---|---|
| UPGRADE | upgrade | heavy solid arrow up |
| SLIGHT_UPGRADE | slight upgrade | small solid arrow head, no stem |
| MIXED | gains and losses | one arrow up, one arrow down |
| TEMPORARY_UPGRADE | temporary upgrade | heavy arrow with a broken stem |
| FUTURE_UPGRADE | upgrade not usable yet | hollow arrow |
| COMBAT_UTILITY | combat use | bolt |
| FUTURE_USE | later use | hourglass |
| VENDOR | vendor | coin |
| NOT_USABLE | not usable | heavy X |
| UNKNOWN | usability unclear / unknown | question mark |
| RECOMMENDED | the advisor's pick | solid star, bright gold edge |
| TENTATIVE | a pick with incomplete evidence | hollow star, bright gold edge |

Language: the Codex box (dark fill, thin gold-brown edge, one small marker inside, as in Theme.lua). Shape carries meaning; colour (the advisor's own family) only supports it. A test makes sure no two glyphs share a bitmap.

## Where and how
A row of badges sits in the gap just under each Blizzard reward button (no covering of the item name, icon or stats), classifications from the left in the advisor's order, at most four. The recommendation is a star badge at the right end of that row plus the gold border on the button, never one of the classification shapes, so a MIXED item can be the pick and shows both. A `?` badge is added when usability is unclear. The one-line verdict (CODEX: RECOMMENDED / TENTATIVE PICK - CHOICE n, or NO CLEAR PICK) stays on the game's "Choose your reward" line. Hovering a reward adds the pick (in words), the advisor's reason, the stat comparison, and the existing detail to the game's tooltip.

## Removed
The text strips (`[MIXED] (usability unclear)` etc.) and `RO.StripText`. Replaced by `RO.Glyphs` (ids from the advisor's tag words) and `RO.StarGlyph`.

Geometry (badge size 12.5 px, the gap under each button) is judged from real-client screenshots; the tests check content, not pixels.

## 0.9.8: placement fixed (a correction)

The 0.9.4 and 0.9.7 notes above say the icon row / strips sit in the gap under each button. That was wrong: the edit that moved them did not apply (a string replace matched nothing and failed silently), so the row stayed at the old position, inside the button at its bottom edge, 44 px from the left, where it covered the lower line of the item name. The 0.9.7 real-client screenshot showed it. The same missed edit left the verdict line without its width cap, so it ran past the window edge and hid the game's "Choose your reward" text.

Fixed in 0.9.8, and this time checked:
- The icon row is anchored to the button's bottom-right corner, right-aligned and exactly as wide as its badges (the gap between rows is too small for a badge, and the second line of a wrapped name is the short one).
- The verdict uses a short form on screen (`CODEX: PICK - CHOICE 2`, `CODEX: TENTATIVE - CHOICE 2`, `CODEX: NO CLEAR PICK`), capped at 170 px, no wrap; the long form stays in the report, and the tooltip says "evidence incomplete". The short form is a new `verdict.short` field in the advisor's display data (wording only; no decision changed).
- New tests assert the anchors, the row width and the verdict width, so a missed move now fails.
