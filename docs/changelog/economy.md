# Economy group changelog

Branch `group/economy-whmjnc`, draft PR #13. Newest entry first. Format: [README.md](README.md).

### 2026-10-10 10:40 UTC · `7f14b25`, `8e6e877`, `b0a7325` · Late-game training, wood only (Faisal 09:36, 09:51)

- **What:** Hat machines no longer give the whole team a G move. Your class's machine, or the LEVEL UP strip once you're out of a fight, now sells **Veteran Training**. From 5:00 left in the match, it buys the experience (rank points) you still need to pick your class variant. It is personal, and it costs 14 wood. Ore is gone: the ore spots grow lumber trees, every price is wood only, and the ore counter and ore cart are hidden. Gathering stays on Wildwood and Moonlit, not Ember Pass. All-bot teams keep their one turret patched instead of filling every pad. An attacker gathers only while the pool is below the training price.
- **Files:** scripts/economy.gd (`train_check`, `train`, `train_remote`, `quick_tiles`, `offer`, `_bot_spend`, `plan_gatherers`, `_cost_text`, `draw_counter`, self-test), scripts/stats.gd (`ECONOMY`)
- **Tunables:** new `train_wood` 14, `train_ore` 0, `train_after` 300, `ore_on` false, `bot_attacker_until` 17. Repair 2+1 → 3 wood, raise door 4+2 → 6, turret 2+1 → 3, raise turret 1+1 → 2, patch 1 → 1, bot reserve 2+1 → 3.
- **Tested:** `--econ-test` 0 failed (branch and alpha). Six seeds per map on the alpha. First wood-only run: 3 captures, 4 overtime (bots filled every pad), fixed. Final run: Wildwood 14 captures, 0 overtime, 486 s; Moonlit 10 captures, 0 overtime, 532 s (before today: 13 / 0 / 327 s and 13 / 0 / 378 s). Bots promote through kills by 5:00 left, so they rarely buy training.
- **Revert:** `git revert b0a7325 8e6e877 7f14b25`

### 2026-10-10 09:20 UTC · `c888848`, `13c3762`, `637ae9b`, this commit · Game-style card, bare stock counter, one bot turret (Faisal 08:31, 08:32)

- **What:** The action card is drawn on the ability bar's wooden board: brass rim, gold corners, cream and gold text. It uses UI & Art's `hud.game_board` and `hud.game_button` where the build has them. The base stock under the minimap is now just a wood icon and a gold coin icon (ore) with the counts beside them, plus "+n" while you carry. All-bot teams build one turret, not two.
- **Files:** scripts/economy.gd (`draw_action_card`, `draw_counter`, `_wood_board`, `_wood_icon`, `_ore_icon`), scripts/stats.gd
- **Tunables:** `ECONOMY.bot_turrets` 2 → 1.
- **Tested:** Moonlit, six seeds, one bot turret: 13 captures, 0 overtime, 371 s; with two: 11 captures, 3 overtime, 481 s. Renders of the upgrade and repair cards.
- **Revert:** `git revert <this commit> 637ae9b 13c3762 c888848`

### 2026-10-10 08:10 UTC · `84522bd` · Turrets that hit

- **What:** Rampart turrets were wasting about 85% of their bolts on their own walkway, merlons and gatehouse. Now a turret only shoots enemies it has a clear line to, the bolt starts 0.7 m higher and drops straight onto the target, and downed bodies are skipped. Bots build on the yard pads first, which see the door. A "TURRET!" popup shows on a knock-down. The upgrade-ready hint mentions field upgrades.
- **Files:** scripts/turret.gd (`_clear_shot`, `_target`, `_fire`), scripts/projectile.gd (`drop_dist`), scripts/economy.gd (`_bot_turret`, hint, self-test uses pad 3), scripts/stats.gd
- **Tunables (new):** `TURRET.rampart_lift` 0.7.
- **Tested:** hit rate went from about 15% to about 70% (instrumented 3-match runs). Six seeds per map, two bot turrets: Wildwood 3.3 turrets and 2.0 turret kills a match, 14 captures, 0 overtime (no turrets: 13, 0); Moonlit 3.3 turrets, 1.2 kills, 11 captures, 3 overtime (13, 0), hence the change to one turret above. Self-test 22/22.
- **Revert:** `git revert 84522bd`

### 2026-10-10 07:40 UTC · `ce29b5f` · Turret kill tally counts knock-downs

- **What:** The demo's `turret_kills` only counted a unit going straight to dead; with Downed & Revive the kill credit is given at the knock-down, so turret kills read 0. Now a turret bolt that knocks someone down counts. Tally only, no gameplay change.
- **Files:** scripts/projectile.gd
- **Revert:** `git revert ce29b5f`

### 2026-10-10 07:00 UTC · `0baddb5` · Cheaper turrets, bots build early, glowing pads (Faisal: "cheaper and smarter")

- **What:** Turrets cost less. All-bot teams put one turret up before their first hat upgrade and a second after it; a bot on a team with a human builds one. Empty pads glow and pulse gold for you when your base can afford a turret.
- **Files:** scripts/economy.gd (`_bot_spend`, `_bot_turret`, `_steward`, `_turrets_of`, `_build_pads`, `_process`), scripts/stats.gd (`ECONOMY`)
- **Tunables:** `turret_wood/ore` 3/3 → 2/1, `turret_up` 2/2 → 1/1, `turret_fix` 1/1 → 1/0; new `bot_turrets_early` 1, `bot_turrets` 2, `bot_turrets_with_human` 1.
- **Tested:** six seeds (2001-2006) per map, alpha build before and after. Turrets built per match 0 → 3.5 (Wildwood) and 0 → 3.5 (Moonlit). Captures 13 → 13 and 13 → 10 (see the thread for kills and match length). Self-test 22/22.
- **Revert:** `git revert 0baddb5`

### 2026-10-10 06:50 UTC · `7a7084e`, `e66cd61` · Quick hat upgrades from the field

- **What:** Out of combat for 3 s you can buy your class's hat upgrade from anywhere, paid from the base stock, through UI & Art's LEVEL UP strip (`quick_tiles()`). The machine in the base still works. An upgrade now also reaches everyone already wearing that class, not only hats taken afterwards.
- **Files:** scripts/economy.gd (`field_ok`, `field_hat_offers`, `buy_hat_remote`, `quick_tiles`, `upgrade_hat`, `_tick_calm`), scripts/stats.gd (`ECONOMY`)
- **Tunables (new):** `field_calm` 3.0 (uses `unit.calm_left()` / `Stats.QUICK_UPGRADE_CALM` where it exists), `field_foe_radius` 9.0.
- **Tested:** `--econ-test` 22/22 (2 new checks: a field upgrade gives a Ranger already out there its move; none straight after a fight).
- **Revert:** `git revert e66cd61 7a7084e`

### 2026-10-10 06:30 UTC · `4276911` · Upgrade card and base stock restyled, door bar raised (Faisal 06:02, 06:04)

- **What:** The action card now looks like the pause menu's UPGRADES rows: navy with gold rim and leaf corners, a hex tile with the painted icon, the move's name and description, price top right, and a big gold + button with its F key. The base stock is a navy pill under the minimap (like DEFENDING HOME) with wood, ore and three carry pips. The door's health bar sits 1.6 m higher.
- **Files:** scripts/economy.gd (`draw_action_card`, `draw_counter`, `_offer`, `_lift_door_bar`), scripts/stats.gd (`door_bar_lift` 1.6)
- **Tested:** renders of the upgrade, repair, gather and storehouse shots on a merge with release/v0.4.0-alpha.
- **Revert:** `git revert 4276911`

### 2026-10-09 21:30 UTC · `b13fe48`, `e920dee`, `a63d7b1` · Repair / upgrade button and resource monitor (Faisal 20:41)

- **What:** Standing at your door, a turret pad or your class's hat machine now brings up a card above the ability board: what it does, the door's or turret's health bar, the price in wood and ore (red when the base is short), and a big button (REPAIR, RAISE, UPGRADE, BUILD, PUT ON). Click or tap it, or press interact. When it can't be bought the button says why (NEED 1 ORE, UNDER SIEGE, FULL HEALTH, MAX LEVEL). The resource monitor under the minimap is now a BASE STOCK panel with big wood and ore numbers that flash when they change, and three ON YOUR BACK slots. The floating door and pad prompts are gone (the card replaces them). A left click on the button doesn't swing your weapon.
- **Files:** scripts/economy.gd (`offer`, `draw_action_card`, `draw_counter`, `mouse_on_button`, `_input`, `--econ-shot=upgrade`, 3 new self-test checks), scripts/hud.gd (one hook after `_draw_world_prompt`), scripts/unit.gd (attack ignores a click on the button)
- **Tunables:** none.
- **Tested:** `--econ-test` 20/20 on this branch and on a local merge with release/v0.4.0-alpha; renders of the card and monitor.
- **Revert:** `git revert a63d7b1 e920dee b13fe48`

### 2026-10-09 21:20 UTC · `40cdd34` · A downed soldier drops the load

- **What:** With Downed & Revive, a soldier is knocked down instead of dying; a load on their back now spills there too, and a downed soldier can't pick one up.
- **Files:** scripts/economy.gd (`_tick_cargo`, `_tick_drops`, self-test)
- **Revert:** `git revert 40cdd34`

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
