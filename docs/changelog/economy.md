# Economy group changelog

Branch `group/economy-whmjnc`, draft PR #13. Newest entry first. Format: [README.md](README.md).

### 2026-10-09 13:40 UTC · `eedf86f`, `8c9766b`, `29d5c26`, `8faa929` · Bots stop stalling matches with the economy

- **What:** The first six-seed batch with the economy had every match end 0-0 in overtime (no captures; without it: 11 captures, none in overtime). Two causes, found by switching parts off one at a time: the gathering bot was taken off the assault for the whole match (one of only three attackers), and bot teams topped their door up from anywhere, even mid-siege. Now: nobody can mend a door while the enemy is at it (the prompt says UNDER SIEGE: NO MENDING); a mend adds 35 instead of 50; all-bot teams mend only below 100 and at most every 45 s; the Engineer bot is the gatherer, and with no Engineer (4v4) an attacker gathers only until the team's first two hat upgrades.
- **Files:** scripts/economy.gd (`fix_door`, `_door_prompt`, `_bot_spend`, `plan_gatherers`, `bot_mended`), scripts/stats.gd (`ECONOMY`)
- **Tunables:** `repair_hits` 50 → 35; new `bot_repair_below` 100, `bot_repair_gap` 45, `bot_attacker_hats` 2; `bot_gatherers` 1 (no longer 2 while the pool is empty).
- **Tested:** six seeds (1001-1006) each, Wildwood. Main 5v5 without the economy: 11 captures, 0 overtime, average 387 s. With it, first version: 0 captures, 6 overtime, 634 s. With these fixes: 11 captures, 1 overtime, 403 s. Merged 4v4 build (World & Maps + UI & Art + Combat & Balance + Economy), `--no-economy`: 15 captures, 0 overtime, 336 s; with it: 10 captures, 1 overtime, 507 s. Self-test 17/17.
- **Revert:** `git revert eedf86f 8c9766b 29d5c26 8faa929`

### 2026-10-09 13:00 UTC · `b43393b` · `--no-economy` test flag

- **What:** `--no-economy` starts a match with no trees, deposits, storehouse or prices, for balance baselines on a branch that has the economy.
- **Files:** scripts/game.gd (`_build_world`)
- **Revert:** `git revert b43393b`

### 2026-10-09 11:50 UTC · `4b42b1f` · A small shove no longer cancels chopping

- **What:** Chopping or mining stopped if you moved 0.6 m; on the merged build a collider nudges you that far. Now it stops at 1.0 m or when you leave the tree's reach.
- **Files:** scripts/economy.gd (`_tick_work`)
- **Revert:** `git revert 4b42b1f`

### 2026-10-09 11:05 UTC · `5b275fd` · Prompts and storehouse sign

- **What:** The hat machine prompt sits on the floor in front of the pedestal with shorter text, so it no longer covers the class sign; the STOREHOUSE sign shows only while you carry a load; the storehouse moved to 3.8 m in from the gate side, 7.2 m back; tree and ore spots are placed in mirrored pairs and kept clear of the castle wall.
- **Files:** scripts/economy.gd
- **Revert:** `git revert 5b275fd`

### 2026-10-09 09:56 UTC · `36585cb` · Wood, ore, hat machine upgrades, door repairs and base turrets

- **What:** Lumber trees and ore deposits (5 and 4 a side, mirrored) you chop or mine with F, one unit at a time. Carry up to 3 on your back to the storehouse in your castle yard, where they join the team pool shown under the minimap. Spend with F: upgrade a hat machine while wearing that class (5 wood, 5 ore), and every hat from it then adds the class's extra move on G for the whole team. You can also mend or raise your door, and build, patch or raise base turrets on the turret pads. A fallen soldier drops their load and anyone can pick it up. One bot per team gathers, and all-bot teams also spend (door first, then hats, then turrets).
- **Files:** scripts/economy.gd (new), scripts/resource_node.gd (new), scripts/stats.gd (new `ECONOMY`, `HAT_UPGRADES`, `hat_upgrade()`), scripts/unit.gd (`hat_upgraded`, third ability timer, G key, gather bot job, optional `color` on cleave/curse), scripts/game.gd (`economy` node, `ability_3` action, interact/planner/station hooks), scripts/hud.gd (two draw hooks), docs/changelog/README.md
- **Tunables (new):** `ECONOMY`: gather_time 2.6, carry_max 3, reach 2.2, tree_stock 4, ore_stock 3, regrow 45, depot_radius 2.6, drop_life 40, hat 5 wood / 5 ore, repair 2/1 for +50, rebuild 4/2 to 100, turret 3/3, turret raise 2/2, turret patch 1/1, door_reach 4, pad_reach 1.8, bot_gatherers 1, bot reserve 2 wood / 1 ore. `HAT_UPGRADES`: 12 moves, cooldowns 5–10 s, costs 30–50. No existing number changed.
- **Tested:** `--econ-test` self-test 17/17 pass; 3-minute bot matches on the Wildwood and the Moonlit Wildwood (doors under 200 by t=90 s on both); six-seed batch: see the 13:40 entry above.
- **Revert:** `git revert 36585cb`
