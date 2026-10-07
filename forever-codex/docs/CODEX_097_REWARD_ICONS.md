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
