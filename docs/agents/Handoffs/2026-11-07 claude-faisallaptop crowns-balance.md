# Handoff: crowns-balance (class win rates from bot sims)

Agent: claude-faisallaptop/crowns-balance. Branch `claude-faisallaptop/crowns-balance`. Full write-up: [docs/balance/pass-2026-11-07.md](../../balance/pass-2026-11-07.md).

## What changed
- `scripts/stats.gd`: **Vanguard armour 0.45 -> 0.50. PROPOSED** (Faisal approves or reverts; one number).
- `tools/balance/winrates.py` (new): per-map faction win rate, match length against the 12-15 minute target, and per-class win rate of the side fielding it. `agg.py` and `runbatch.sh` untouched.
- `docs/evidence/crowns-balance-1107/`: RESULT/STAT lines of 150 bot matches (readable by `winrates.py`/`agg.py`), tallies, test logs; `post-merge/` has the tests, export log and fresh-profile boot log after merging main `273d655`.

## Results (50 matches each, every map, seeds 101-110, Normal)
| Class | Before win % (K/D) | After win % (K/D) |
|---|---|---|
| Vanguard | 40 (0.46) | 53 (0.57) |
| Warden | 60 (0.71) | 47 (0.64) |
| Cleric | 49 (1.06) | 64 (1.52) |
| Dark Priest | 51 (1.34) | 31 (1.04) |
| Frostweaver | 52 (0.96) | 44 (0.87) |
| Pyromancer | 48 (0.90) | 56 (1.12) |
| Sharpshooter | 45 (1.40) | 47 (1.20) |
| Trapper | 55 (1.28) | 53 (1.14) |

Elves win % per map before/after: Wildwood 70/20, Moonlit 70/30, Ember Pass 60/30, Stonekeep 35/35, Twilight 80/50; all 63/33, pooled over 150 matches 52. Faction totals swing between batches far more than chance (the demo reads the real clock in places), so no faction change. Stonekeep favours Humans in every batch (32% Elves pooled). Match length: 147/150 within 12 min to 15 min + 2 min overtime, average 15:01 before, 14:51 after.

A second change (Human Crossbow cooldown 0.62 -> 0.58) was tried in a middle batch, did nothing measurable and was dropped.

## Tests run
- Headless import, no script errors (before and after merging main).
- Combat self-test `TESTS DONE failures=0`, `COMBAT INPUT TEST: 0 failed`, `SMOKE: ok`, unit allocation 969 assertions 0 failures (before and after the merge); shared-XP bugtest 15 checks 0 failures, lava knock-off 0 failures (before the merge).
- 150 bot matches: 0 SCRIPT ERROR.
- Windows release export of merge `8dade48` + fresh-profile windowed boot (`--quit-after 2400`, shared fg lock): 0 SCRIPT ERROR (34 engine `Skeleton3D skeleton_updated` USER ERROR lines, the known engine warning from earlier passes).

## Not tested
Human play, couch/online, Easy/Hard, team sizes other than 4v4, Engineer and Rogue (not in 4v4 bot lineups), Team Deathmatch, a windowed look at the Vanguard.

## Next
- Faisal: approve or revert the Vanguard armour.
- Dark Priest is the next outlier (41% pooled v Cleric 57%): try Drain Bolt cost 21 -> 18 on 100 matches (command in the pass doc).
- Stonekeep side advantage: look at the map before numbers.
