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

## Rendered review addition

Agent: Codex-faisal/characters. Reviewed root-produced rendered evidence on 2026-10-27; this helper did not launch another engine run.

The root's rendered candidate run reports 41 checks / 0 failures, exit 0, no engine errors, no Skeleton disconnects and no warnings (rendered-run.json). It exported 24 actual 1280x720 gameplay-camera PNGs. Candidate runtime and unchanged pack hashes match the headless run.

Personally viewed these 16 original PNGs: 01-idle-00/01; 02-run-01/02/03; 03-attack-01/02/03; 04-recover-run-01/02; 05-death-01/02/03; 06-respawn-knight-01/02/03.

At the real overhead gameplay scale, the Knight helmet/body remain assembled in idle, sampled run, recovery and respawn. The adjacent attack samples show the sword changing angle at the hand, without obvious separation or an exploded mesh. Adjacent death samples show the body tipping backward, with helmet, sword and shield remaining with the body. Respawn samples restore an upright, assembled Knight and the live health HUD. No obvious detached limb/equipment or stretched mesh is visible in these reviewed stills.

This is limited visual inspection of sparse gameplay-camera stills. The large helmet obscures much of the body/feet in run frames; the almost identical sampled run silhouettes do not establish stride quality, foot contact or smooth transitions. Player translation/decisions were frozen by the harness. The frame sample span does not cover a full death settling or every animation phase. HUD FPS numbers vary during synchronous capture and do not constitute a controlled performance benchmark. No claim of smoothness, complete deformation/attachment correctness, full animation-set coverage, actual input, mobile or multiplayer acceptance is made. This evidence concerns the unchanged #75 candidate pack, not the new material/world/UI implementation.
