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

## 0.9.9: from the 0.9.8 screenshot

- The icon row was right, but the right-hand column of buttons runs to the edge of the game's scroll area, which clips what is drawn on it (the star and the last badge were cut). The row now stays 12 px in from the button's right edge (`RO.INSET`).
- The verdict (`CODEX: RECOMMENDED - CHOICE n` / `CODEX: TENTATIVE PICK - CHOICE n` / `CODEX: NO CLEAR PICK`) still covered "Choose your reward" because the text was wider than the free space on that line. It now sits one line higher, on the "Rewards" heading line whose right side is empty (`RO.VERDICT_RISE`), with room for the full wording; the "(evidence incomplete)" part stays in the tooltip and report.
- Tooltip: the hover hook ran and added lines, yet the game's tooltip showed none. Cause unproven; the likely one is that the game rebuilds the tooltip after our hook. While the mouse stays on a reward, Codex now checks (every 0.15 s) whether its lines are still in the game's tooltip and adds them again if not (at most 5 repairs per hover). The report has a `tooltip check:` line: whether GameTooltip was shown right after the hook, who its owner was, whether its line text is readable, and how often our lines were found or missing. If the lines are still absent after this, that report line says why.

## 0.10.0: the tooltip, from the 0.9.9 report (next patch after 0.9.9 is the next minor)

0.9.9's real-client report: the Codex lines appeared in the Hammer's tooltip, flickered, then the tooltip vanished; "our lines found 7 time(s), missing 92 time(s)". The game rebuilds that tooltip continuously, so adding lines afterwards (OnEnter, then a repair loop) can never win, and the repeated `Show` calls are the likeliest cause of the flicker and disappearance.

Fix: when the client has `TooltipDataProcessor.AddTooltipPostCall` and `Enum.TooltipDataType.Item`, Codex registers one build hook and adds its lines inside every item-tooltip build whose owner is one of its annotated reward buttons (no `Show` call). A rebuild therefore always contains them. In that mode the OnEnter hook adds nothing and the repair loop stays out. Without those APIs the 0.9.9 path (OnEnter plus the capped repair) remains. These two names are not proven on Forever: the report now has a `tooltip build hook` line (installed or unavailable, item tooltips built, builds that got our lines), so the next real-client report proves or disproves them.
