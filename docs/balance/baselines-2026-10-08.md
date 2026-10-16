# Six-seed baselines, 2026-10-08

Bot-vs-bot batches, six fixed seeds per map, 45000 frames at 60 fps, all
bots. Branch `group/combat-balance-pjmygt` at `90af014` (combined build
`claude/project-thread-hu6d1n` 2e9da63 + the Venom Fang fix). No bot lineup
picked the Rogue (0 Rogue kills), so the Venom Fang fix did not touch these
numbers.

Re-run: `MAP=0 JOBS=4 tools/balance/runbatch.sh bwild 1001 1002 1003 1004 1005 1006`
then `python3 tools/balance/agg.py bwild`.

## Wildwood (MAP=0), tag `bwild`, seeds 1001-1006

| Seed | Winner | Score (E-H) | Time | Overtime | Raid deaths (E/H) |
|------|--------|-------------|------|----------|-------------------|
| 1001 | Humans | 0-2 | 129 s | no | 0/2 |
| 1002 | Humans | 0-2 | 218 s | no | 0/3 |
| 1003 | Elves  | 1-1 | 612 s | yes | 9/5 |
| 1004 | Humans | 0-1 | 600 s | no | 1/4 |
| 1005 | Elves  | 2-0 | 218 s | no | 5/0 |
| 1006 | Elves  | 2-0 | 218 s | no | 4/0 |

**Elves 3, Humans 3.** Captures E5 H6, kills E202 H195, 1 overtime, average
match 332 s, 0 script errors.

- Level edge: the higher level won 209 of 341 level-mismatched kills (61%).
- Promoted (3+ points) v fresh: promoted won 31, fresh won 5.
- Deaths: 29% at level 1; 62% of all deaths fall in the first 220 s.
- Strongest K/D: Frostweaver 1.69 (E), Sharpshooter 1.66 (E) / 1.30 (H),
  Trapper 4.33 (H, 2 games). Weakest: Engineer 0.17 (E) / 0.42 (H),
  Siegewright 0.27 (H), Artificer 0.30 (H), Dark Priest 0.38 (H).
- Four of six matches ended inside 220 s on two quick captures; the batch
  does not show the Humans 5-1 lean seen in the Ember Pass p1 batch.

## Ember Pass (MAP=2)

Not run yet. Paused at 21:26 UTC on Faisal's word: all focus goes to the
playable iPad build, and no further tasks run without his input.
