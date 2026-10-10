# Balance patch 5 (2026-10-10)

Faisal 2026-10-10: "lets get it going". Patch 4 left Elf Knights as the
weakest fighters in the game. Before this patch, Elf Vanguards and Wardens each
traded 0.50 kills per death, against 0.77 and 0.95 for their Human
counterparts.

## How it was measured

- **Build:** `release/v0.4.0-alpha` (fdad6d6) merged with Combat & Balance PR #8
  plus patches 3 and 4. Bots only.
- **Batches:** seeds 71-76 at 3v3/4v4/5v5 on both maps, plus seeds 77-82 at
  4v4 on both maps. Before (`p4a`, `p4c`) and after (`p5a`, `p5c`): 96
  matches, 0 script errors.

## What was wrong

- The Elf Glaive wore lighter plate than the Human sword: armour 0.32 against
  0.37. Elf Wardens inherit that plate.
- Wind Dash, the Elf Knight's charge, did one heart where Shield Bash does two.
- Vanguards (both sides, no shield) were the weakest promotion.

## The changes

| Tunable (`scripts/stats.gd`) | Old | New |
|---|---|---|
| Elf Knight (Glaive) `armour` | 0.32 | 0.37 |
| Elf Wind Dash `damage` | 1 | 2 |
| Elf Wind Dash `cooldown` | 3.5 s | 4.5 s |
| Vanguard `armour` (both sides) | 0.42 | 0.45 |

## After (48 matches each side)

| | Before | After |
|---|---|---|
| Wins (E-H) | 21-27 | 26-22 |
| Knight K/D, all | 0.64 | 0.70 |
| Elf Vanguard K/D | 0.50 | **0.77** |
| Elf Warden K/D | 0.50 | **0.85** |
| Human Vanguard K/D | 0.77 | 0.72 |
| Human Warden K/D | 0.95 | 0.69 |
| Mage / Ranger K/D | 1.07 / 1.31 | 1.03 / 1.27 |

| Size, map (seeds 71-76) | Wins E-H (before → after) | Avg length (before → after) |
|---|---|---|
| 3v3 Wildwood | 2-4 → 2-4 | 529 → 534 s |
| 3v3 Ember Pass | 3-3 → 1-5 | 416 → 596 s |
| 4v4 Wildwood | 2-4 → 3-3 | 465 → 482 s |
| 4v4 Ember Pass | 3-3 → 5-1 | 200 → 280 s |
| 5v5 Wildwood | 3-3 → 3-3 | 380 → 344 s |
| 5v5 Ember Pass | 2-4 → 4-2 | 220 → 302 s |

- **4v4 over seeds 77-82:** Wildwood 5-1 → 4-2, Ember Pass 1-5 → 4-2.
- **4v4 over all 24 matches:** Elves 11-13 → 16-8. Six-seed splits swing
  widely, so this is the number to watch in patch 6.
- Ember Pass matches got longer again (200-220 s → 280-300 s at 4v4/5v5)
  because sturdier knights hold the bridges longer.

## To watch in patch 6

- Elf healers still trade 1.73 against 0.93 for Human healers. Their heal
  output is also higher (89 against 75 per match).
- 4v4 now leans Elves 16-8 over 24 matches.

## Revert

`git revert <patch 5 commit>`
