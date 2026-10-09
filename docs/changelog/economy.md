# Economy group changelog

Branch `group/economy-whmjnc`, draft PR #13. Newest entry first. Format: [README.md](README.md).

### 2026-10-09 09:56 UTC · `36585cb` · Wood, ore, hat machine upgrades, door repairs and base turrets

- **What:** Lumber trees and ore deposits (5 and 4 a side, mirrored) you chop or mine with F, one unit at a time. Carry up to 3 on your back to the storehouse in your castle yard, where they join the team pool shown under the minimap. Spend with F: upgrade a hat machine while wearing that class (5 wood, 5 ore), and every hat from it then adds the class's extra move on G for the whole team. You can also mend or raise your door, and build, patch or raise base turrets on the turret pads. A fallen soldier drops their load and anyone can pick it up. One bot per team gathers, and all-bot teams also spend (door first, then hats, then turrets).
- **Files:** scripts/economy.gd (new), scripts/resource_node.gd (new), scripts/stats.gd (new `ECONOMY`, `HAT_UPGRADES`, `hat_upgrade()`), scripts/unit.gd (`hat_upgraded`, third ability timer, G key, gather bot job, optional `color` on cleave/curse), scripts/game.gd (`economy` node, `ability_3` action, interact/planner/station hooks), scripts/hud.gd (two draw hooks), docs/changelog/README.md
- **Tunables (new):** `ECONOMY`: gather_time 2.6, carry_max 3, reach 2.2, tree_stock 4, ore_stock 3, regrow 45, depot_radius 2.6, drop_life 40, hat 5 wood / 5 ore, repair 2/1 for +50, rebuild 4/2 to 100, turret 3/3, turret raise 2/2, turret patch 1/1, door_reach 4, pad_reach 1.8, bot_gatherers 1, bot reserve 2 wood / 1 ore. `HAT_UPGRADES`: 12 moves, cooldowns 5–10 s, costs 30–50. No existing number changed.
- **Tested:** `--econ-test` self-test 17/17 pass; 3-minute bot matches on the Wildwood and the Moonlit Wildwood (doors under 200 by t=90 s on both); six-seed batch: see the next entry.
- **Revert:** `git revert 36585cb`
