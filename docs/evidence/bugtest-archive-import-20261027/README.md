# Archived QA import fix

Agent: Codex-faisal3/bugtest

Base: main `9b985b200f5ae4c59ef128cb405ea2db6c37cd1b`. Issue #80. The implementation adds only `docs/evidence/.gdignore`; all archived scripts, production code, scenes, art and settings remain byte-identical. Evidence below is text and metadata, with no uploaded build or invented screenshot.

A genuinely cold Godot 4.3 Windows headless editor import returned exit 0 in 43.25 s but logged four parse/script errors: two archived issue-68 QA scripts preload absent `C:/ORY-Cache/qa/.../isolated.gd` files. The same scripts and preloads exist at previous main e7ae8b2 and are absent from merge #76's changed-file list; this is not attributed to that visual merge. Production scripts/scenes/project settings contain no `res://docs/` references; Windows export already excludes `docs/*`.

With the ignore file, a fresh worktree's cold import took 39.48 s, exit 0, no script/parse/error lines. The actual `OS.get_user_data_dir()` was verified below the private tester APPDATA prefix before loading the game. Ordinary Crowns save hashes and every tracked baseline byte remained unchanged through the test.

The README's normal seed-7 production-AI bot match used fixed 60 Hz, normal fortify/600-second rules and the normal eight units. No clock shortening, teleports, forced hits/captures, menu APIs or human-input claim. It completed in 228.0 s real time, exit 0: Humans 1–0 at t=600, no overtime; the normal capture occurred at t=506. All eight STAT lines are retained. This is one seeded AI match, not player-input, balance, all-map or performance acceptance.

**Overall diagnostic result remains FAIL.** Shutdown logs one `ObjectDB instances leaked at exit` warning and `ERROR: 10 resources still in use at exit`; this previously documented shutdown family is not fixed by an import-ignore change. The original strict controller stops here and its FAIL/error trace is retained. There are no SCRIPT ERROR or Parse Error lines in the match. Existing runtime Skeleton3D issue #68 and held-interact/pause fixes #73/#74/#71 remain separate; this test does not resolve them.

A separate, explicit local-only canonical Windows release export then passed in 11.41 s, exit 0/no error lines, with unchanged source. Artifact size 176517744 bytes; SHA256 `700437b0f3cc91188c1f7ea2de693312fb3dd37ce65e660d919845875ef9cf59`. The binary stays local and was not launched or uploaded. Independent audit: 14 evidence/classification checks pass; this is not a globally clean-game result.

No fresh rendered visual, animation, physical-controller, native player menu/loop, online, all-map, store/release or performance acceptance. The new title art was previously viewed as a source asset, not accepted as an in-game render. No screenshots are supplied for headless import/match logs. No restyling, queue/shared developer checkout edits, paid APIs, merge or new worker/supervisor.

Agent: Codex-faisal3/bugtest
