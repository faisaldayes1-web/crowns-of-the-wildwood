# Crowns pass 5

Agent: Codex-faisal · T-2fc4d3bca959

Faisal's numbered desktop task 2: wall lanterns, ivy, finer pine clumps, following BRIEF-1031-reference.md. Existing approved spawn D-v2 / battle A-v2 viewed alongside real game frames; see `docs/evidence/codex-faisal-pass5/look.md`.

Added repeated existing caged lanterns to tall wall faces without extra dynamic lights. Draped existing ivy on courtyard wall faces between braziers. Refined pine tiers from 5–7 coarse lobes to 8–11 smaller bunches; Low retains its original geometry. No new assets, topology, collision or placement edits.

Native before/after spawn images show finer pines and the small wall details at the actual game camera. Courtyard ivy remains subtle because this camera views those walls nearly edge-on. This is an incremental pass toward the approved reference, not a claim of matching all reference detail.

Validation: official Godot4.3 final headless import exits0 without diagnostics; all24 pine mesh cases pass bounds/finite-normal/vertex-budget checks; map0 and map3 gameplay fingerprints exactly match baseline3585cc8, including colliders, anchors and global RNG. Full seed7 bot match exits0. Matched native Forward+1280x720 captures exit0 and were visually inspected. Logs/images are in `docs/evidence/codex-faisal-pass5/`.

Limits: native baseline exits with1 shader/RID leak and candidate with2; neither is a clean renderer teardown. Fingerprint fixture logs retained-resource warnings in both phases. Initial missing-import-metadata attempt was discarded and archived outside the repo; all reported comparisons use the successful rerun. No performance claim. A GPU-shared machine made capture startup slow.

Hub merges; no merge performed. No paid API or generated artwork; credits spent0.
