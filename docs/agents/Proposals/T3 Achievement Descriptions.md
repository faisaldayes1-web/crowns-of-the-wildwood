PROPOSED — FOR PR REVIEW. Agent: Codex-faisal2. 2026-10-18. Faisal authorized normal release-copy PR updates and source-issue notes in this existing repository via the hub relay in this chat. This authorization does not publish a storefront, build, press kit or game release.

Source snapshot: crowns-of-the-wildwood main f2364c15f8b8c2d0bf1d54b81b049ed33b82f399. Source issue #32.

# Crowns of the Wildwood — achievement descriptions

Editorial candidates for the ten existing API IDs in scripts/steam.gd and docs/steam.md. Names and unlock intent are retained; this page does not create achievements or change triggers.

| Existing API ID | Existing name | Proposed description |
|---|---|---|
| FIRST_WIN | First Crown | Win a match. |
| WIN_ELVES | Heart of the Wildwood | Win a match as the Elves. |
| WIN_HUMANS | For the Realm | Win a match as the Humans. |
| FIRST_CAPTURE | Crown Thief | Carry the enemy monarch home for a capture. |
| FIRST_REVIVE | Not Today | Revive a downed ally. |
| FIRST_FINISHER | No Mercy | Finish off a downed enemy. |
| ONLINE_MATCH | Better Together | Finish an online match. |
| LEVEL_5 | Seasoned | Reach account level 5. |
| LEVEL_10 | Veteran | Reach account level 10. |
| LEVEL_20 | Legend of the Wildwood | Reach account level 20. |

## Internal adoption boundary

“Monarch” aligns the objective description with the README; it does not replace the stable FIRST_CAPTURE identifier. “Account level” remains distinct from life/match upgrades. Do not add win, no-death or difficulty requirements to the capture/revive/finisher descriptions.

The source Steam wrapper describes local-player-only unlock delivery and excludes bot demos. docs/steam.md explicitly leaves joiner capture/revive/finisher behavior and actual Steam-client acceptance open. Keep ONLINE_MATCH as a description candidate for the existing ID, not a claim that online or platform achievements are ready to market. An empty/no-op platform wrapper must not display a successful Steam unlock. No trigger, platform entry, icon, unlock, account or save edit occurs here. Owner verifies current host/joiner attribution, completion, restart and actual client behavior before publication.
