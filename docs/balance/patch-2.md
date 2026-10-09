# Balance patch 2 (2026-10-09)

Faisal 2026-10-09 11:39: "test out the balance with 3v3, 4v4, and 5v5". Integration
also reported Elves winning all 4 alpha bot matches on `release/v0.4.0-alpha`.
This patch fixes that Elf lean and compares the three team sizes.

## How it was measured

- **Build:** `release/v0.4.0-alpha` (3a17242: downed/revive, economy, store,
  music, web) merged with Combat & Balance PR #8 (patch 1 included). Bots only,
  free basic attacks.
- **Sizes:** `--team-size=3/4/5` (test-only flag, `TEAM=` in runbatch.sh). The
  live game stays strictly 4v4.
- **Batches:** seeds 61-66 on Wildwood (`MAP=0`) and Ember Pass (`MAP=2`) for
  each size, before (`p2t<size>m<map>`) and after (`p2a<size>m<map>`):
  72 matches, 0 script errors.
- Bots never use the new attack buffer (player input only), so the fluid-combat
  commit does not affect these numbers.

## Before: Elves won 27 of 36

| Size, map | Wins (E-H) | Caps (E-H) | Overtime | Avg length | First door | Stalls/match |
|---|---|---|---|---|---|---|
| 3v3 Wildwood | 5-1 | 1-0 | 5 | 613 s | 263 s | 14.3 |
| 3v3 Ember Pass | 3-3 | 7-3 | 1 | 383 s | 87 s | 2.3 |
| 4v4 Wildwood | 4-2 | 7-7 | 2 | 529 s | 94 s | 5.7 |
| 4v4 Ember Pass | **6-0** | 12-2 | 0 | 347 s | 85 s | 3.3 |
| 5v5 Wildwood | 5-1 | 8-2 | 0 | 483 s | 123 s | 10.0 |
| 5v5 Ember Pass | 4-2 | 9-6 | 0 | 342 s | 94 s | 3.2 |

Why: Elf archers won the ranged fight (Elf ranged K/D 1.5-1.8 against Human
0.9-1.2 in 4v4/5v5 Ember Pass). Moonbow archers and Elf Trappers outranged the
Human Crossbow (14 m) and kited on the faster Elf legs (6.3 against 6.0).

## The changes

| Tunable (`scripts/stats.gd`) | Old | New | Why |
|---|---|---|---|
| Elves `speed` | 6.3 | 6.15 | Still the quicker side, less free kiting |
| Human Crossbow `range` | 14.0 | 16.0 | Matches the Moonbow fight from the walls |
| Human Crossbow `shot_speed` | 36.0 | 42.0 | Heavy bolts land on moving targets |

## After: Humans 18, Elves 17, 1 draw

| Size, map | Wins (E-H) | Caps (E-H) | Overtime | Avg length | First door | Stalls/match |
|---|---|---|---|---|---|---|
| 3v3 Wildwood | 2-3, 1 draw | 0-0 | 6 | 634 s | 264 s | 10.3 |
| 3v3 Ember Pass | 3-3 | 4-4 | 1 | 528 s | 113 s | 4.7 |
| 4v4 Wildwood | 4-2 | 6-5 | 0 | 498 s | 98 s | 8.0 |
| 4v4 Ember Pass | **3-3** | 6-7 | 1 | 443 s | 137 s | 3.5 |
| 5v5 Wildwood | 3-3 | 7-4 | 1 | 490 s | 140 s | 7.7 |
| 5v5 Ember Pass | 2-4 | 6-8 | 0 | 257 s | 89 s | 2.0 |

- 4v4 overall: Elves 10-2 → 7-5. Ember Pass 4v4 went from 6-0 to 3-3; Human
  ranged K/D 0.87 → 1.21, now level with the Elves' 1.21.
- Wildwood 4v4 still leans Elves 4-2 on these seeds (captures nearly level,
  6-5). Watch it in patch 3 rather than push the same knobs further.

## Which size plays best

- **4v4 plays best.** Doors fall at about 1.5-2.5 min, captures come on both
  sides, overtime is rare and Ember Pass matches last a healthy 6-7 min.
- **3v3 plays worst.** On Wildwood almost nobody captures (0-1 total in 12
  matches), 11 of 12 matches go to overtime, the first door takes over 4 min
  and bots stall most. The Wildwood map is too big for 3 a side.
- **5v5 works but runs fast on Ember Pass** (257 s after the patch). The
  narrower map gets crowded and matches end quickly.
- **Does 4v4 need its own tuning?** No separate tuning: every value is tuned at
  4v4 already because that is the live size. Faction balance now holds across
  all three sizes. If 3v3 or 5v5 ever ship, they need map-size changes (smaller
  Wildwood for 3v3, longer respawns or extra doors for 5v5 Ember Pass), not
  stat changes.

## Revert

`git revert <patch 2 commit>` (see docs/changelog/combat-balance.md entry 15).
