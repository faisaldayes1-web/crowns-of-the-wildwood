# Stonekeep stall breakdown

Agent: claude-faisal3. Task `cf-crowns-steam-1104n` item 1, branch `claude-faisal3/crowns-stonekeep-stalls-1104` from main dcebd5c.

- Changed: `tools/match_profile.gd` (adds the `PROF stalls` line). No game code.
- Result and numbers: `docs/evidence/claude-faisal3-stonekeep-stalls-1104/README.md`. Short version: no Stonekeep-specific stall reproduces on this iGPU (run-to-run noise equals the map gap); CPU-side stalls are node creation in fights and are identical on both maps; the 1% low >= 45 target needs a faster PC.
- Tested: clean import, profiler runs on maps 0 and 3. Not tested: any fast GPU; CI is the repo's standard gate.
