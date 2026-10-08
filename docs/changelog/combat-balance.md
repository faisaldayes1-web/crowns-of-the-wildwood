# Combat & Balance changelog

Every commit from the Combat & Balance group gets an entry here, newest at the
bottom. Each entry says what changed in plain words, the files touched, every
tunable's old → new value (tunables live in `scripts/stats.gd`), the bot
batches that back it (seeds, map, result), and the line that undoes it.

A commit cannot contain its own hash, so each entry is written in the commit it
describes and its hash is filled in by the next commit on the branch.

Branch: `group/combat-balance-pjmygt`, cut from `claude/project-thread-hu6d1n`
(the combined build: PRs #1-#4 merged on top of `main` 29e5ea8), because
Ember Pass, the Fire forms and the batch tools in `tools/balance` exist only
there and not on `main` yet.

Checks: `tools/tests/run.sh` (headless combat tests, exit code = failures).
Batches: `MAP=<0 Wildwood | 2 Ember Pass> tools/balance/runbatch.sh <tag> <seeds>`,
then `python3 tools/balance/agg.py <tag>`.

---

## 1. Venom Fang slows again

- **When:** 2026-10-08 21:05 UTC
- **Commit:** `90af014`
- **What:** The Assassin Rogue's Venom Fang never slowed anyone. Melee base
  attacks only passed the fire-form burn to the target and dropped every other
  on-hit effect, so the `slow` on the attack did nothing (arrows and spells
  carried it fine). Melee swings now pass `slow` as well as `burn`. Added a
  headless test, `tests/combat_test.gd`, run by `tools/tests/run.sh`
  (`--demo --selftest`): Venom Fang hits and slows for its 0.8 s, the slow is
  still on halfway and gone after, a second cut refreshes rather than stacks,
  Knight and bare-fist swings do not slow, and dying clears the slow.
  Before the fix the test failed 3 of 9 checks (slows, lasts, no-stack);
  after it passes 9 of 9. `runbatch.sh` takes `MAP=` to pick the map.
- **Files:** `scripts/unit.gd` (`_attack`, melee branch), `scripts/game.gd`
  (`--selftest` hook), `tests/combat_test.gd` (new), `tools/tests/run.sh`
  (new), `tools/balance/runbatch.sh` (`MAP=`), `docs/changelog/combat-balance.md`.
- **Tunables:** none changed. Venom Fang `slow` stays 0.8 s (now actually applied;
  slowed units move at ×0.55).
- **Batches:** the six-seed baselines in entry 2 run with this fix in.
- **Revert:** `git revert 90af014`

## 2. Fire form shows up in the batch logs

- **When:** 2026-10-08 21:25 UTC
- **Commit:** `341a026`
- **What:** Logging only, no gameplay change. Demo `KILL` lines now end with
  `kfire=` (the killer was in Ember Pass fire form) and `burn=` (the killing
  heart was a fire-form burn going off). `agg.py` prints a "fire form" line:
  fire-form kills by class, share of all kills, burn finishers, and fire kills
  on base soldiers. Needed for the Fire form re-check.
- **Files:** `scripts/unit.gd` (`burn_tick`, KILL line), `tools/balance/agg.py`,
  `docs/changelog/combat-balance.md`.
- **Tunables:** none.
- **Batches:** none needed (log output only); `tools/tests/run.sh` 9/9 pass.
- **Revert:** `git revert 341a026`

## 3. Wildwood six-seed baseline

- **When:** 2026-10-08 21:28 UTC
- **Commit:** _filled in by the next commit_
- **What:** Results only, no gameplay change. Wildwood baseline, seeds
  1001-1006: Elves 3, Humans 3; captures E5 H6; kills E202 H195; 1 overtime;
  average 332 s; 0 script errors. Table and class numbers in
  `docs/balance/baselines-2026-10-08.md`. Ember Pass baseline, the Humans
  lean fix and the Fire form re-check are paused (Faisal 21:25 UTC: all focus
  on the iPad build; no further tasks without his input).
- **Files:** `docs/balance/baselines-2026-10-08.md` (new), `docs/changelog/combat-balance.md`.
- **Tunables:** none.
- **Batches:** tag `bwild`, MAP=0, seeds 1001-1006, at `90af014`.
- **Revert:** `git revert <hash>`
