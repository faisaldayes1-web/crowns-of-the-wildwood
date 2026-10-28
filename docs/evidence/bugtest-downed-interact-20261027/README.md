# Downed give-up inherited interact regression

Agent: Codex-faisal3/bugtest

On main0963, holding interact before normal enemy damage knocks the player down also fills the new downed give-up timer. The player dies about1.3833s after the fall without releasing or making a fresh press. This contradicts the source comment that a press held over from before the fall must not cause give-up.

The exact native regression records standing4hearts/heldRightShoulder, normalenemy down15s/0hearts, inheritedskip.98333 at elapsed1.36667, then dead/respawn7s. At that time ordinary enemy hits cannot finish within the source2s grace, no execution is active, no finisher has progressed, no allied revive occurred, and bleedout is still above13s. No forced down, health/position/clock/AI writes or seed flags are used. Live menu hitregions select Normal4v4, one human/pad7; native stick events traverse the real collision map.

The isolated candidate adds a held-at-fall release latch in scripts/unit.gd, clears it when input is released, and resets it on recovery. Holding continuously now keeps skip0/downed/alive through1.6s. A separate normal release/repress test qualifies the latch-clear branch and intentional fullhold before enemy grace expires. Existing freshpress partialhold/release/pause90frames/full1s give-up/onefall/normal7s respawn passes with the EXACT same input fixture on main and candidate.

| Actual case | Checks | Functional failures | Engine ERROR lines |
|---|---:|---:|---:|
| main-freshpress | 13 | 0 | 289 |
| main-preheld-red | 5 | 1 | 217 |
| candidate-preheld-green | 5 | 0 | 224 |
| candidate-freshpress | 13 | 0 | 273 |
| candidate-release-repress | 7 | 0 | 212 |

Known Skeleton3D disconnect and resource shutdown errors remain in these headless runs, so EVERY native case retains overall diagnostic FAIL despite functional successes. No new error family appeared. Import and Windows export passed; see actual build logs. No rendered captures or visual/style/physical-controller/audio/network/fullmatch/performance/release acceptance is claimed. This bug is input correctness; existing issue68 is not fixed. One earlier external tester type-inference parse failure occurred before input and is retained separately; no game bug is inferred from it.

All native processes first ran an independent actual user:// path probe, then matched the path inside the bot. Genuine prior earned profiles were copied byte-identically; original and ordinary profiles, source and artifacts remained unchanged. Actual executed .gd fixtures/logs are copied byte-for-byte; results.json records hashes and observations. Cached imported art was tester-owned and identical, serialized by game/engine locks. No developer checkout, queue, art, scene or balance changes.

Repro with ordinary controls: start Normal4v4 on Wildwood; hold interact (F/right shoulder) while standing as enemies approach; keep holding through their normal knockdown. A fresh release is expected before a give-up hold counts. Raw headless logs are the available evidence, not fabricated screenshots. The exact same red/green .gd SHA and same positive-control SHA are recorded in results.json.

Draft review only. Never merged by Codex-faisal3/bugtest.
