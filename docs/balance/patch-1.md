# Balance patch 1 (2026-10-09)

Faisal 2026-10-09 11:38: "lets start building balance patches with test runs
as well". This is the first patch: one readable bundle, measured before and
after on the same seeds.

## How it was measured

- **Build:** the combined game (`release/v0.4.0-alpha` + Combat & Balance PR #8 +
  latest `group/downed-revive`), strict 4v4 bots, free basic attacks, downed
  and revive on.
- **Batches:** seeds 51-56 on Wildwood (`MAP=0`) and 51-56 on Ember Pass (`MAP=2`),
  before (`p1w0`, `p1e0`) and after (`p1w1`, `p1e1`).
  `JOBS=4 MAP=<0|2> tools/balance/runbatch.sh <tag> 51 52 53 54 55 56`, then
  `python3 tools/balance/agg.py <tag>`.
- 0 script errors in all 24 matches.

## What was wrong (before)

| | Wildwood | Ember Pass |
|---|---|---|
| Wins | Humans 4, Elves 2 | Elves 5, Humans 1 |
| Avg length | 516 s | 389 s |
| Melee K/D (Elves / Humans) | 0.65 / **0.39** | 0.70 / **0.51** |
| Ranged K/D | 1.24 / 0.94 | 1.19 / 0.93 |
| Support K/D | **2.85** / 0.96 | **2.14** / 0.92 |
| Revived / finished / skipped (% of downs, E / H) | 15/51/33 · 13/53/31 | 12/56/28 · 10/51/37 |

- **Melee loses:** knights on both sides trade badly (K/D 0.4-0.7) against
  archers and mages that kite them.
- **Humans lost their edge:** their faction perk is faster stamina and mana
  regen, but basic attacks became free (entry 7), so regen now only feeds
  skills. Human ranged and support trail the Elves on both maps. The Trapper
  is weakest because it keeps the slow 0.75 s crossbow.
- **Elf healers are too safe:** the Elf support K/D is 2.1-2.9 with few deaths.
  Grove Mend reaches 6 m against the Human Prayer's 5 m.

## Changes (`scripts/stats.gd`)

| Tunable | Old | New | Why |
|---|---|---|---|
| Humans `regen_mult` (FACTIONS) | 1.06 | 1.15 | Give back the faction perk now basic attacks are free |
| Knight `speed` (all Knight promotions) | 1.06 | 1.10 | Melee can close on kiting ranged |
| Warden Mace `range` | 2.0 | 2.2 | The shortest melee reach in the game |
| Human Ranger Crossbow `cooldown` (also the Human Trapper) | 0.75 s | 0.68 s | Human ranged trailing |
| Elf Healer Grove Mend `heal_radius` | 6.0 m | 5.0 m | Match the Human Prayer; Elf support too safe |

## After

| | Wildwood | Ember Pass |
|---|---|---|
| Wins | Elves 5, Humans 1 | Elves 3, Humans 3 |
| Avg length | 481 s | 225 s |
| Melee K/D (E / H) | 0.47 / **0.70** | 0.56 / **0.83** |
| Ranged K/D | 1.37 / 1.08 | 1.20 / 1.17 |
| Support K/D | **1.29** / 0.95 | **0.81** / 0.92 |
| Revived / finished / skipped (% of downs, E / H) | 11/65/19 · 15/47/35 | 4/56/38 · 8/54/31 |

- **What improved:** Human melee went from 0.39-0.51 to 0.70-0.83, Human
  ranged from 0.93 to 1.08-1.17, and Elf support from 2.1-2.9 down to
  0.8-1.3. Ember Pass came out level at 3-3.
- **What didn't:** Elf melee did not improve (0.47-0.56), so Elf knights stay
  the weakest group. Across both maps the faction split is Elves 8, Humans 4
  (it was 7-5). Six seeds per map is too few to call that lean, so patch 2
  starts with more seeds on it.
- **Not balance tunables:** revives are rare (4-15% of downs) and bots skip
  a third of downs. That is bot revive behaviour, so it was reported to the
  Downed & Revive group rather than tuned here.
- **Match length:** Ember Pass matches end fast (2-0 stomps) in both batches;
  its average swings with which seeds stomp.

## Revert

`git revert <hash>` (the commit that adds this file and the `stats.gd` changes).
