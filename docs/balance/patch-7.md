# Balance patch 7 (2026-10-14)

Follows patch 6 (Faisal 2026-10-14: "keep rebalancing and fixing the game and
bug fixing"). After patch 6 the Elves still won 29 of 48 matches, with a small
edge in every class. That points at something faction-wide, and the Elves'
faster legs are the main faction-wide difference.

## How it was measured

- **Build:** `release/v0.4.0-alpha` 82a3d77 merged with Combat & Balance PR #8,
  plus patch 6. Bots only.
- **Batches:** seeds 71-76 at 3v3/4v4/5v5 on both maps, plus 77-82 at 4v4 on
  both maps. Before is patch 6's shipped run (`p6g`, `p6f`); after is `p7a`,
  `p7c`. 96 matches, 0 script errors.

## The change

| Tunable (`scripts/stats.gd`) | Old | New |
|---|---|---|
| Elves `speed` | 6.15 | 6.05 (Humans stay at 6.0) |

## After

| | Patch 6 | Patch 7 |
|---|---|---|
| Wins (E-H, 48 matches) | 29-19 | **25-23** |
| Healer K/D (E / H) | 1.60 / 0.94 | **1.09 / 1.20** |
| Ranger K/D | 1.36 / 1.23 | 1.41 / 1.19 |
| Mage K/D | 1.10 / 0.97 | 1.07 / 0.95 |
| Knight K/D | 0.78 / 0.61 | 0.75 / 0.60 |

| Size, map (seeds 71-76) | Wins E-H (patch 6 → 7) | Avg length |
|---|---|---|
| 3v3 Wildwood | 3-3 → 1-5 | 507 → 582 s |
| 3v3 Ember Pass | 3-3 → 5-1 | 496 → 588 s |
| 4v4 Wildwood | 5-1 → 3-3 | 482 → 472 s |
| 4v4 Ember Pass | 2-4 → 4-2 | 188 → 292 s |
| 5v5 Wildwood | 3-3 → 2-4 | 306 → 313 s |
| 5v5 Ember Pass | 4-2 → 3-3 | 314 → 263 s |

4v4 over seeds 77-82: Wildwood 6-0 → 3-3, Ember Pass 3-3 → 4-2.

Elf healers no longer outlive Human healers; their edge came from escaping on
faster legs. Over patches 6 and 7 together, the Elves went from 32-16 to 25-23
on the same 48 seeds. The size and map splits swing a lot on six seeds, so
judge the patch by the 48-match total.

## Still open

- Elf Rangers still trade 1.41 against 1.19.
- Knights on both sides sit at 0.6-0.75 kills per death, the bots' melee
  weakness noted since patch 3.

## Revert

`git revert <patch 7 commit>`
