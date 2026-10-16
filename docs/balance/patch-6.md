# Balance patch 6 (2026-10-14)

Faisal 2026-10-14: "keep rebalancing and fixing the game and bug fixing". On
the latest alpha build, the Elves won two of every three bot matches, and they
were ahead in every class.

## How it was measured

- **Build:** `release/v0.4.0-alpha` (82a3d77: Economy, painted skill strips,
  split-screen and patches 1-5) merged with Combat & Balance PR #8. Bots only.
- **Batches:** seeds 71-76 at 3v3/4v4/5v5 on both maps, plus seeds 77-82 at
  4v4 on both maps: 48 matches per run.
  - Before (`p6b`, `p6c`).
  - First try (`p6a`, `p6e`).
  - Shipped bundle (`p6g`, `p6f`).
  - 144 matches in all, 0 script errors.

## What was wrong (before, 48 matches: Elves 32-16)

| Class | Elf K/D | Human K/D |
|---|---|---|
| Healers | **1.77** | 0.96 |
| Rangers | 1.45 | 1.23 |
| Mages | 1.12 | 0.86 |
| Knights | 0.87 | 0.58 |

- **Elf healers:** they mended and fired bolts every 0.7 s against the
  Human 0.8 s, and their promotions (Cleric, Dark Priest) inherit that pace.
  Spirit Bloom's speed-up also lasted 4 s against Blessing's 3 s.
- **Everyone else:** the lean shows in every class, so part of it is
  faction-wide. Elves move faster, and Humans refill stamina and mana faster.
  Since basic attacks went free, the faster refill buys less than it used to.

## The changes

| Tunable (`scripts/stats.gd`) | Old | New |
|---|---|---|
| Humans `regen_mult` | 1.15 | 1.22 |
| Elf Spirit Bloom `haste` | 4 s | 3 s |
| Elf Grove Mend `cooldown` | 0.7 s | 0.8 s |

## After

| | Before | First try (regen + Spirit Bloom) | Shipped (+ Grove Mend) |
|---|---|---|---|
| Wins (E-H, 48 matches) | 32-16 | 28-20 | 29-19 |
| Healer K/D (E / H) | 1.77 / 0.96 | 2.15 / 0.83 | **1.60 / 0.94** |
| Ranger K/D | 1.45 / 1.23 | 1.43 / 1.08 | 1.36 / 1.23 |
| Mage K/D | 1.12 / 0.86 | 1.09 / 0.98 | 1.10 / 0.97 |
| Knight K/D | 0.87 / 0.58 | 0.81 / 0.57 | 0.78 / 0.61 |
| Elf healing per match | 101.7 | 91.5 | 84.0 |

| Size, map (seeds 71-76) | Wins E-H (before → shipped) | Avg length |
|---|---|---|
| 3v3 Wildwood | 4-2 → 3-3 | 577 → 507 s |
| 3v3 Ember Pass | 4-2 → 3-3 | 432 → 496 s |
| 4v4 Wildwood | 4-2 → 5-1 | 491 → 482 s |
| 4v4 Ember Pass | 5-1 → 2-4 | 322 → 188 s |
| 5v5 Wildwood | 4-2 → 3-3 | 528 → 306 s |
| 5v5 Ember Pass | 6-0 → 4-2 | 326 → 314 s |

Every class gap narrowed, and the Elf healer edge roughly halved. The Elves
still win 29 of 48, with the lean spread over every class, so patch 7 tries
the faction-wide speed edge next (Elves 6.15 → 6.05). That run is already
going.

## Revert

`git revert a4c4786`
