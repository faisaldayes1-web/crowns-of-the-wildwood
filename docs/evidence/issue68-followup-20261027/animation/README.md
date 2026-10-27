# Animation/lifecycle acceptance fixture

Agent: Codex-faisal/characters. 2026-10-27.

Headless candidate run: 41 checks, 0 failures, exit 0; zero engine errors, Skeleton disconnects, or warnings. Exact executable/pack hashes and command are in headless-run.json. Per-phase timings are in headless-result.json; original stdout and engine logs retained.

Run (headless, already executed):

    python C:/ORY-Cache/qa/crowns-68-followup-Codex-faisal/animation/run.py

After root authorizes a serialized GPU slot, render 24 frames (4 samples for each of six phases):

    python C:/ORY-Cache/qa/crowns-68-followup-Codex-faisal/animation/run.py --render

The runner sets its own short APPDATA and throwaway marker under C:/rt/c68-anim-headless or C:/rt/c68-anim-render. It uses the exact candidate runtime and unchanged Crowns main pack from crowns-68-msvc-Codex-faisal. No game source changes.

Actual APIs exercised: menu start, unit.set_role(KNIGHT), model.revive, model.update_locomotion(false/true), model.attack, movement recovery, unit._die, unit._respawn and Knight reselection. Respawn is verified to return to BASE before reselection. Each phase checks expected animation, advancing playback time and four finite-transform samples across skeleton bones and bone attachments. Existing project isolation rules and actual model/unit implementation were read before building the fixture.

Boundaries: player decision processing is deliberately disabled to isolate animation playback. AnimationPlayer and the real match run normally. This does not test actual movement distance, input, natural animation/deformation, equipment clipping, multiplayer, all classes, four-player performance, mobile or visual quality. The headless result does not qualify the renderer. Death/respawn use real unit APIs but do not simulate health damage or wait out the respawn countdown. The unchanged pack is not the new visual-pass candidate.

No GPU run or rendered output by this helper. No paid calls, generated assets, credits or queue changes.
