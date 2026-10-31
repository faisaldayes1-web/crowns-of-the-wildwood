Agent: Codex-faisal3/bugtest.

# Shared couch XP tally — issue #135

The EXPERIENCE category rows used only the primary player's ledger while the account banks XP earned by every local player. In the original actual Normal two-player match on main354b74e, the rows totaled1347XP while1951XP was earned and separately reloaded:604XP was absent from the tally. This was a display accounting defect; the reward was received.

Current main `7fddd5a3e379c81aff3487119f44064108488e63` reproduces the defect in six of15 synthetic production summary/panel-text checks, with nine controls passing. Its actual first cold import, private OSuserdir proof and strict API parse passed; the red is audited with26 checks. Candidate `2feaef30bf561ed18a1128581604f207974f998f` passes all15 API checks after its own first cold import/private path/strict parse, independently audited16 checks. These synthetic checks do not prove earned play or rendered text.

The production change aggregates the same existing five categories over `is_player` units. Primary stats/accolades, bot-demo fallback, current GP06 60second bonus eligibility, save/reward rules and layout stay intact. One production file and one regression test change. Run the synthetic regression with Godot4.3: `godot --headless --audio-driver Dummy --path . --script res://tools/bugtest_shared_xp_test.gd`.

## Actual candidate native qualification

Fresh Normal4v4, two local players on virtual pads7/0, ordinary Knight/Healer acquisition, queued InputEvents, natural engine time_scale1 and full20preparation/600match/120overtime horizon. The completed case produced55 passing native assertions, 4730 typed input events and30 state observations. Actual natural result: **loss**, score[0, 2], source clock293, actual match_played313.980481111161. Both actual player ledgers aggregate to775 sharedXP, plus40 primary-accoladeXP and100 eligible resultXP. The observed category tally, account gain and separate earned reload all equal **915XP**. Gold200, shards15, one chest. Result Continue and ordinary title EXIT completed; separate earned-profile restart passed5 checks. Independent input/clock/ledger/currentGP06/reward/source/profile audit: **57 checks pass**, raw status **FAIL**. Raw overall status remains FAIL: the separate reload printed `ERROR: 2 resources still in use at exit (run with --verbose for details).` and an ObjectDB leak warning after its five checks passed and process exited0. This is a retained shutdown diagnostic with cause unestablished; no clean-error acceptance is claimed. Exact errors/warnings remain in logs/audit.

Actual private Godot OSuserdir was proved before native input and before separate reload. No seed, fixed-fps, clock/time_scale, health/pose/RNG/outcome or save/reward grants. The final actual earned profile SHA256 is `e9f1145456052df8952296c0899e29e5fd7c7652ab3914bdb61816dce4f48555`. Only hashes/observations are published; no raw save files.

## Retained interruption and source scope

The preceding attempt on this exact candidate ended abruptly after2905 typed events with no fullmatch/result/exit record. All its exact runner/engine child identities were absent on resumption and its attached tool session was unavailable. Its original RUNNING record and raw logs/profile remain preserved locally; the classification and partial log are included here. It remains INTERRUPTED/unknown exit, not a game crash or pass. This new fresh-profile continuation completes the previously unqualified fullcase; no qualified green case was replayed. Earlier pre-engine sparse preparation and template admission failures remain preserved locally. Original main's wallet-map annotation false controller flags are explained separately, with raw numeric reward/reload observations intact.

Candidate Git tree contains2032 files; all1518 runtime/root/assets/scripts/scenes/tools files were independently matched to exact Git blobs. Only514 documentation files (206673672bytes) were omitted physically using sparse checkout for disk capacity. The complete2031-file main baseline is retained separately. No runtime source references the omitted docs. This evidence commit adds documentation only after qualification; runtime remains exactly `2feaef30bf561ed18a1128581604f207974f998f`.

No PNG or rendered visual acceptance: headless production data/API and queued virtual inputs only. Physical controller/OS-input, rendering/style/animation, audio, GPU/frame-time/performance, packaged export, online/mobile/device and full level20 remain unsupported. The separate `training` source category was not exercised and is outside this scoped fix. No asset restyle, shared queue edit, paid API, build upload, extra helper/supervisor or merge.

Agent: Codex-faisal3/bugtest.

Agent: Codex-faisal3/bugtest. The first evidence-packaging controller stopped before commit/push because the historical audit stores the tally as summary_lines rather than a tally_total field. Original failure and partial files were retained; this continuation independently sums those original rows and verifies every existing copied file before reuse. No source/game/native test was replayed.
