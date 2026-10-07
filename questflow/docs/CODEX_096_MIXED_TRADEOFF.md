# 0.9.6: choosing between two MIXED rewards (advisor rule; no UI change)

Classification and recommendation are different questions. Classification: what kind of item is this compared with what I wear (Kris and Hammer are both MIXED, and stay MIXED). Recommendation: which of the rewards is the best choice. Before 0.9.6 two MIXED choices always ended in NO CLEAR PICK, because Codex does not weigh different stats against each other.

## The rule (one place: `mixedWinner` in RewardAdvisor.lua `RecommendDefault`)
Only when every viable choice is MIXED (the rest proven unusable or no gain), choice A is preferred to B when ALL hold:
1. same equipment slot, both fully compared;
2. the class is one whose weapons are about their own damage (`weaponDamage = true` in `A.IGNORED_STATS`: Warrior and Rogue only);
3. A's weapon-dps gain is clear (at least `A.THRESHOLDS.slightRelative`, 25%, of the worn weapon's dps) and B has no weapon-dps gain;
4. everything A loses, B loses as much or more.

B's own gains are not weighed against A's and the reason says so. No weights, no spec data, no external data. Anything unread, uncomparable or not gear among the choices means no pick. Unlisted classes keep NO CLEAR PICK.

State: RECOMMEND when the pick's usability is proven, otherwise TENTATIVE with the usability caveat. On Q5730 the client's two usability answers conflict (IsUsableItem false, dialog flag true), so the Hammer is a TENTATIVE pick, not a plain RECOMMEND: Codex does not turn unestablished usability into a firm recommendation.

## Q5730 now
Hammer: MIXED, TENTATIVE pick (+4.3 weapon dps, 53% of the Rapier, same -2 agility as Kris). Kris: MIXED. Axe, Staff: NOT USABLE + VENDOR.

## Tests
reward_tradeoff_tests.lua (new): the Q5730 case with the real character (rapier plus off-hand dagger), plain RECOMMEND when usability agrees, and the limits (other class, the faster weapon loses more, dps gain under 25%, both gain dps, an unread third choice). Six older assertions that pinned NO CLEAR PICK for this exact case were updated to the new result (advisor_tests.lua x2, reward_overlay_tests.lua x4, one replaced by a still-no-pick pair).
