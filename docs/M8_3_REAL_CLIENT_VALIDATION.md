# M8.3 Real-Client Validation Addendum

**M8.3 REAL-CLIENT VALIDATION: PASS, with one confirmed finding acted on.**

This addendum documents the operator's manual test of the ForeverQuestGuide route view on a real WoW Forever
client, following `docs/M8_3_COMPLETION_REPORT.md`'s test procedure, and the two fixes made as a direct
result. It is a validation record, not a replacement for the completion report.

## 1. Load and tab validation

The addon loaded with no Lua error and the QUESTS tab continued to work exactly as M8.1 validated it
(quest list, scroll, selection, detail panel, "Show on Map" placeholder — all unaffected by this milestone's
changes, confirmed directly in-game, not just by the unchanged self-test).

The **QUESTS**/**ROUTE** tab bar appeared and both tabs switched correctly with no error.

## 2. Route-step navigation

Clicking through the route on the real client:

| Step | Kind | What displayed | Matched expectation |
|---|---|---|---|
| 1/5 | ACCEPT | Quest 907, giver Jorn Skyseer, "Destination: not captured" | Yes |
| 2/5 | TRAVEL | Quest 907, "Head out to find Thunder Lizards...", "Destination: not captured" | Yes |
| 3/5 | OBJECTIVE | **"Objective: 0/3 Thunder Lizard Blood"** — the live lookup from `Data.lua`, not a duplicated copy | Yes |
| 4/5 | TURN_IN | **"Destination: map 1413 (0.449, 0.591) [M6-observed player position...]"** | Yes, matches M6 exactly |
| 5/5 | ACCEPT | Quest 959, giver Crane Operator Bigglefuzz, Next button reads "Route Complete" | Yes |

- **Next** advanced correctly through all 5 steps.
- **Previous** correctly walked back down 5→4→3→2→1.
- At step 5/5, the Next button read "Route Complete" and was confirmed not clickable/advancing further —
  this is the designed no-op behavior (there is no step 6), not a defect. The operator asked about this
  directly; the button's label change at the final step *is* the "you've reached the end" signal, not an
  interactive completion action.
- No quest was accepted, no travel occurred, and no gameplay of any kind was required to run this test — the
  operator raised this question directly and it's worth stating plainly here too: the route view is static
  display only, with no code path that reads or writes the player's actual quest state.
- No Lua error occurred at any point in the sequence.

## 3. Step-type glyph finding

**Confirmed: the ⭐/⚔/📍 Unicode glyphs render as blank/empty "tofu" boxes on Forever's default UI font,
on every step kind tested (ACCEPT, TRAVEL, OBJECTIVE, TURN_IN).** This was the one piece of M8.3 the
completion report explicitly flagged as unverified pending this test.

This is not a per-glyph issue — all three glyphs failed identically, consistent with Forever's font simply
lacking Unicode emoji coverage rather than any one code point being unsupported.

**Action taken:** `UI.lua`'s `USE_EMOJI_GLYPHS` switch was flipped from `true` to `false`, activating the
plain-text fallback vocabulary (`[*]` for ACCEPT/TALK/TURN_IN, `[X]` for OBJECTIVE, `[>]` for TRAVEL) that
was built into the original M8.3 implementation for exactly this outcome. This was a one-line change, as
designed; no other code was touched to make this fix. **This fallback has not itself been re-tested on the
real client yet** — it uses plain ASCII characters already confirmed to render correctly everywhere else in
this addon (every other piece of text in the window), so it is expected to work, but that expectation is
distinct from having actually re-run the test with the switch flipped.

## 4. Layout finding and fix

The section header above each panel ("Quests (96 guide-ready)" / the route equivalent) sat close enough to
the new tab bar to visually overlap it on the real client's actual font metrics — visible in the operator's
screenshots as the header text's top partially colliding with the tab buttons. This was not caught by the
Lua self-test, which has no real font or line-height to measure against (its FontString mock does not
compute or expose rendered dimensions).

**Action taken:** `PANEL_TOP_OFFSET` was increased from `-64` to `-78` (14px more clearance), which shifts
both the QUESTS and ROUTE headers down by the same amount, since both use the same anchor constant. The
QUESTS-tab header was not independently observed overlapping in this test session (no QUESTS-tab screenshot
was taken after the tab bar was added), but shares the identical layout code, so the fix was applied to both
rather than only patching the one instance actually seen. **This fix has not yet been re-verified on the real
client.**

While addressing this, the previously bare "Route" header label was also changed to
`"Routes (%d available)"`, matching the QUESTS tab's own "Quests (96 guide-ready)" style — a minor
consistency improvement made alongside the spacing fix, not a separate finding.

## 5. What remains to re-verify

Both fixes above are believed correct (parsed cleanly, pass the full self-test, and use only patterns
already proven on the real client elsewhere in this same window) but **neither has been confirmed in-game
yet**, since they were made in response to this test rather than before it. A short follow-up check is
recommended next login:

1. `/reload` (or reinstall the updated `ForeverQuestGuide` folder, now version `m8-guide-addon-0.3`) and
   confirm the login message reports the new version.
2. Open the ROUTE tab and confirm the header ("Routes (1 available)") no longer overlaps the tab buttons.
3. Confirm the step-type indicator now reads a plain bracket tag (e.g. `[*] ACCEPT`) instead of a blank box,
   on at least one step of each kind.
4. Re-check the QUESTS tab's own header for the same spacing, since it was never separately confirmed.

## 6. Conclusion

The route view's core functionality — data loading, live quest/objective lookup, forward and backward
navigation, boundary behavior, and honest destination labeling — all worked correctly on the first real-client
attempt with zero Lua errors. The two issues found were both presentation-layer (a font-coverage gap and a
spacing miscalculation), not logic defects, and both already have fixes in place pending the one remaining
confirmation pass above.

**M8.3 STATUS: REAL-CLIENT VALIDATED, WITH FOLLOW-UP FIXES PENDING RE-CONFIRMATION (addon updated to
`m8-guide-addon-0.3`)**
