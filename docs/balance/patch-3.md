# Balance patch 3 (2026-10-10)

Faisal 2026-10-10: "In game play, the mages feel more strong then the meelee,
lets balance out a bit". This patch brings Mages and Knights closer while
keeping the base attack at the centre of fights.

## How it was measured

- **Build:** `release/v0.4.0-alpha` (fdad6d6, already carrying patch 2) merged
  with Combat & Balance PR #8. Bots only, free basic attacks.
- **Batches:** seeds 71-76 on Wildwood (`MAP=0`) and Ember Pass (`MAP=2`) at
  3v3, 4v4 and 5v5, before (`p3b<size>m<map>`) and after (`p3a<size>m<map>`):
  72 matches, 0 script errors.
- Classes pooled across faction and promotion (Knight = Knight/Vanguard/Warden,
  Mage = Mage/Pyromancer/Frostweaver, and so on).

## What was wrong

Per class, all 36 baseline matches:

| Class | Kills/match | Deaths/match | Damage/match | K/D |
|---|---|---|---|---|
| Knight | 4.9 | 7.5 | 38.5 | **0.66** |
| Ranger | 9.3 | 6.9 | 75.7 | 1.35 |
| Mage | 8.0 | 7.3 | 76.7 | **1.09** |
| Healer | 4.5 | 3.4 | 54.8 | 1.35 |

Mages did twice the Knight's damage. From a melee player's side, two things
make it feel unfair:

- **The free bolt splashes.** The Arcane Bolt bursts 1.4 m wide (Pyromancer
  1.8 m, Elf Thorn Bolt 1.3 m), so a Knight who sidesteps the bolt still takes
  the heart. A whole group of melee closing in takes it together.
- **Blink outpaces the gap-closers.** Blink came back every 4 s (Frostweaver
  every 3 s, Fae Step 4 s), as often as Shield Bash (4 s) and more often than
  a dodge (4 s), so a Knight who reached a Mage was blinked away from each time.

## The changes

| Tunable (`scripts/stats.gd`) | Old | New |
|---|---|---|
| Mage Arcane Bolt `splash` | 1.4 | 1.0 |
| Pyromancer Ember Bolt `splash` | 1.8 | 1.3 |
| Elf Thorn Bolt `splash` | 1.3 | 1.0 |
| Mage Blink `cooldown` | 4 s | 5 s |
| Frostweaver Blink `cooldown` | 3 s | 4 s |
| Elf Fae Step `cooldown` | 4 s | 5 s |
| Knight `speed` | 1.10 | 1.14 |

Damage, range and the big spells (Fireball, Inferno, Ice Burst) are unchanged:
a Mage still wins at range, but a Knight who closes in now gets their swings.

## After

| Class | Kills/match | Deaths/match | Damage/match | K/D (before → after) |
|---|---|---|---|---|
| Knight | 5.2 | 7.0 | 37.3 | 0.66 → **0.73** |
| Ranger | 9.0 | 6.3 | 76.7 | 1.35 → 1.42 |
| Mage | 6.8 | 7.3 | 70.2 | 1.09 → **0.93** |
| Healer | 4.2 | 3.7 | 53.5 | 1.35 → 1.14 |

The Mage-to-Knight K/D gap fell from 1.65× to 1.27×, and it narrowed at every
size:

| Size | Knight K/D | Mage K/D |
|---|---|---|
| 3v3 | 0.62 → 0.64 | 0.95 → 0.85 |
| 4v4 | 0.60 → 0.69 | 0.94 → 0.86 |
| 5v5 | 0.76 → 0.98 | 1.50 → 1.22 |

## Matches

| Size, map | Wins E-H (before → after) | Avg length (before → after) | Stalls/match |
|---|---|---|---|
| 3v3 Wildwood | 2-4 → 4-2 | 537 → 470 s | 10.8 → 4.2 |
| 3v3 Ember Pass | 1-5 → 2-4 | 556 → 477 s | 3.8 → 5.0 |
| 4v4 Wildwood | 2-4 → 3-3 | 411 → 575 s | 7.3 → 7.3 |
| 4v4 Ember Pass | 4-2 → 5-1 | 377 → 381 s | 4.2 → 3.3 |
| 5v5 Wildwood | 4-2 → 3-3 | 422 → 376 s | 9.3 → 4.8 |
| 5v5 Ember Pass | 6-0 → 5-1 | 347 → 220 s | 2.2 → 2.0 |

Overall Elves 19-17 → 22-14. Ember Pass at 4v4 and 5v5 leaned Elves 10-2 both
before and after, so that lean is the map, not this patch. It is the target for
patch 4.

## Not covered by bots

The bots' melee still loses partly because they chase kiting targets badly
(noted 2026-10-07), so Knight K/D will not reach the Mage's from numbers alone.
The splash and Blink changes are aimed at what a player feels: dodging a bolt
now works, and a Mage can't escape every time.

## Revert

`git revert <patch 3 commit>`
