# Downed & Revive log

Format: see [README.md](README.md). Newest first.

<!-- entries below -->

### 2026-10-09 12:03 UTC · `12521ed` · Finisher render hook lead time

- **What:** `--debug-finish-strike` sets the shot up early enough that the finisher blow lands on the screenshot.
- **Files:** scripts/game.gd
- **Tunables:** none
- **Revert:** `git revert 12521ed`

### 2026-10-09 11:38 UTC · `9e6acce` · Bots keep their posts and crown runs

- **What:** Wall and door guards only finish a body at their feet, and raiders only one in their path, instead of walking off to finish downed enemies. The first finisher batch had cut matches to 227 s on average because defenders left their posts.
- **Files:** scripts/unit.gd
- **Tunables:** none
- **Tested:** 12 seeds (3001-3012) Wildwood: Elves 9, Humans 3, average 419 s (main: Elves 7, Humans 5, 423 s). 879 downs: 158 revived (18%, 96 by Healers), 504 finished, 196 skipped, 17 bled out; downs, revives and finishes are even between the teams.
- **Revert:** `git revert 9e6acce`

### 2026-10-09 11:30 UTC · `9e34c93` · Finisher move and finisher UI

- **What:** Holding interact over a downed enemy now raises your weapon (class wind-up), then plays a locked 0.8 s finisher: the class's heavy strike with a short lunge, the blow landing at 0.38 s with a red burst, shock ring, dark pillar, screen shake, pad rumble and a FINISHED! popup. While it lands the body can't be revived, crawl or skip. A finished body stays on the ground instead of replaying the standing death. Bots walk up and use the finisher instead of swinging at bodies. UI: a crimson FINISH plate over the body with the key in a ring that fills while held (grey countdown during the 2 s grace) and crossed blades; a FINISHED! banner for the finisher; the downed player's screen turns to "BEING FINISHED!" with the finisher's name; the death card reads FINISHED BY; finishes show crossed red blades in the kill feed.
- **Files:** scripts/unit.gd, scripts/hud.gd, scripts/game.gd, scripts/stats.gd
- **Tunables:** new `FINISH_ANIM` 0.8, `FINISH_IMPACT` 0.38
- **Revert:** `git revert 9e34c93`

### 2026-10-09 10:52 UTC · `3b19863` · Downed screen layout fixes

- **What:** "YOU'RE DOWNED!" sits under the body instead of over it, the DOWNED BY card clears the top bar's hint strip, the duplicate "You are DOWN!" announcement is gone, and a downed body's name tag hides (the swirl and revive bar mark it).
- **Files:** scripts/hud.gd, scripts/unit.gd, scripts/game.gd
- **Tunables:** none
- **Revert:** `git revert 3b19863`

### 2026-10-09 09:42 UTC · `994b110` · Render hook for the finisher

- **What:** `--debug-finish` puts the player (a Knight) over a downed enemy holding interact, for renders.
- **Files:** scripts/game.gd
- **Tunables:** none
- **Revert:** `git revert 994b110`

### 2026-10-09 09:40 UTC · `1818c17` · Downed screen from Faisal's render; enemies hold interact to finish

- **What:** The downed screen now follows Faisal's render (game/reference-renders/downed-screen-target-2026-10-09.png): DOWNED BY card with the attacker's name, class, weapon and level; "YOU'RE DOWNED!" on a red paint splash with "You can still be revived by a teammate!"; a "Revive in N..." bar (gold, or green for a Healer, while someone revives you); a dizzy swirl and circling stars over every downed body; "Downed - Awaiting Revive" in the status panel. Under the bar: the nearest ally's distance and the hold-to-respawn key. An enemy standing over a downed player can hold interact to finish them (HOLD [F] FINISH prompt); the finisher also shows in the kill feed. The 3D green cross over the body is hidden (the swirl replaces it); the revive bar stays.
- **Files:** scripts/hud.gd, scripts/unit.gd, scripts/stats.gd
- **Tunables:** new `FINISH_HOLD` 0.8
- **Revert:** `git revert 1818c17`

### 2026-10-09 09:38 UTC · `2cc0b93` · Downed and revive

- **What:** Losing your last heart knocks you down instead of killing you. You crawl slowly, can't attack, and bleed out after 15 s (the clock stops while a teammate is reviving you). A teammate standing over you holds interact for 4 s to revive you with 2 of 4 hearts, your class, and the levels you lost back; a Healer revives in 1.5 s from 3 m (the Healer perk). Enemies finish you with any hit after a 2 s grace. Hold interact to skip to the normal respawn. Going down is the kill (feed, XP, streaks, levels lost, crown dropped); a revive gives the levels back. Overtime stays sudden death (no downed state). Bots: allies (Healers from further) revive when it is safe; enemies finish downed foes within 4 m once nobody standing is closer; a downed bot with no ally within 20 m skips after 3 s. Revives add score and appear on STAT lines; `--no-downed` turns the feature off.
- **Files:** scripts/unit.gd, scripts/hud.gd, scripts/game.gd, scripts/stats.gd, scripts/character_model.gd
- **Tunables:** new `DOWNED_TIME` 15, `DOWNED_GRACE` 2, `DOWNED_CRAWL` 0.22, `DOWNED_SKIP_HOLD` 1, `REVIVE_TIME` 4, `REVIVE_RANGE` 1.8, `HEALER_REVIVE_TIME` 1.5, `HEALER_REVIVE_RANGE` 3, `REVIVE_HEARTS` 2, `REVIVE_PROTECT` 1, `XP_REVIVE` 30, `XP_FINISH` 10, `SCORE_REVIVE` 8, `BOT_REVIVE_SEEK` 14, `BOT_HEALER_REVIVE_SEEK` 20, `BOT_DOWNED_TARGET_PENALTY` 8, `BOT_FINISH_RANGE` 4, `BOT_DOWNED_GIVE_UP` 3
- **Tested:** 12-seed Wildwood batches (3001-3012) before/after. Before: Elves 7, Humans 5, average match 423 s. After: Elves 8, Humans 4, average 377 s. 811 downs: 149 revived (18%, two thirds by Healers), 494 finished, 149 skipped, 14 bled out.
- **Revert:** `git revert 2cc0b93`
