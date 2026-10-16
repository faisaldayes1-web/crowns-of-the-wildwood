# Balance patch 8

**Date:** 2026-10-15 (Faisal: "Should there be balancing patches?")
**Measured on:** the Steam beta head (group/integration-release-g9m95g 0bcbe66,
including Economy's XP-for-wood and faster chopping) merged with
group/combat-balance-pjmygt.
**Batches:** seeds 71-76 at 3v3, 4v4 and 5v5, plus 4v4 seeds 77-82, on Wildwood
and Ember Pass: 48 matches per build.

## What was wrong

Since patch 7 (Elves 25-23), the beta's other changes had tipped matches to the
Humans. On the newest beta head, Humans won 29-18 with 1 draw. Fights were even:
kills were 970 Elf to 1044 Human, and every class's K/D was within a few tenths
across factions. The Elves lost on objectives. Their door was the first to break
in 34 of 48 matches, and on Wildwood the Elves captured 16 crowns to the Humans'
29.

The Elf archers, which were next on the list after patch 7, no longer stand out.
Elf Rangers trade at 1.32 and Human Rangers at 1.44, so this patch leaves them
alone.

## Change

| Tunable | Old | New |
|---|---|---|
| Elves `speed` (`Stats.FACTIONS[0].speed`) | 6.05 | 6.10 |

This gives back half of patch 7's speed trim. Speed is what wins raids, door
defence and crown runs, and that is the part of the game where the Elves fell
behind.

## Result (48 matches each)

| | Before (6.05) | After (6.10) |
|---|---|---|
| Wins E-H | 18-29 (1 draw) | **24-24** |
| Wildwood | 8-15 (1 draw) | 11-13 |
| Ember Pass | 10-14 | 13-11 |
| Crowns captured E/H | 38/54 | 42/46 |
| Elf door breaks first | 34 of 48 | 27 of 48 |
| Kills E/H | 970/1044 | 1207/1219 |
| Overtimes | 3 | 12 |

Per class, both maps pooled, K/D Elf/Human after the patch:

- Knight: 0.71/0.61
- Ranger: 1.23/1.40
- Mage: 0.99/1.08
- Healer: 1.25/1.23
- Engineer: 0.42/0.20

Before the patch, the healers were 0.77/1.59.

## Watch next

- Overtimes rose from 3 to 12 of 48, because evenly matched bot teams more
  often tie at full time. Overtime is a sudden-death mode, so this isn't broken,
  but if live matches run long, cut `Stats.OVERTIME` (120 s).
- On Wildwood the Elf door still breaks first more often than the Human one.
  This was already true at patch 7 (18 of 24), so it looks like the map's
  approach to the Elf gate and belongs to World & Maps.
- Knights are still the weakest trade, at about 0.6-0.7. That's the bot melee
  AI more than their stats.

## Revert

`git revert 08e766f`
