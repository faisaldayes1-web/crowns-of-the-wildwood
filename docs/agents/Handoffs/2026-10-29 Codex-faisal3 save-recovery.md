# Crowns save recovery: SAV-02 / SAV-01

Agent: Codex-faisal3. Direct Faisal takeover of crowns-push-1029 until about 07:50 Pacific, 2026-10-29. Base: main c654961. Consumer: claude-faisal hub, then claude-faisal3.

Empty/NUL/garbage ConfigFiles can parse successfully. They previously hid backups, reset the selected player, and replaced the embedded progress copy with an empty player file.

- Validate meaningful legacy content and player progress types; require player XP before applying a player file.
- New writes carry a first-section magic/version header and SHA-256 payload digest. The digest catches syntactically valid truncation/alteration; it is an integrity check, not authentication. Legacy formats remain readable.
- Validate the temporary file before replacement and rotate only a validated primary into `.bak`. An invalid primary leaves the existing backup intact.
- No game.gd, input, movement, controller, rendering or asset changes. Existing #69/#84/#88 untouched.

Validation: engine-free gdtoolkit parsing and git diff checks pass locally. CI now runs isolated save-write, standalone recovery and full-game progression regressions in addition to the existing clean Godot 4.3 import, combat self-test and full seed-7 bot match. Runtime result/link will be recorded in the PR after CI completes. Fixtures cover empty/NUL/garbage/unrelated/malformed files, missing/invalid XP, settings-only player files, bad metadata, truncation, alteration, invalid writes, legacy formats, recovery autosaves and restart persistence.

Limitations: no local Godot launch (coordinator reservation remains required); no new native screenshots or measured loading/performance claim. Existing before evidence: `C:/Games/ORY-Candidates/Crowns/bugtest-20261029/saves/shots/11_nul_controls.png` and `12_profile_corrupt.png`. The owner explicitly directed relying on CI and engine-free tests during this takeover. Corruption that destroys every copy cannot be recovered. A legacy file truncated at a valid key boundary has no historical digest; new saves detect this.

Next: hub reviews/merges this PR; only then branch from new main for loading/optimization. UI/gameplay/perf reports are incomplete and require source audits while engine access is gated. Features, boot, audio and saves reports already exist.
