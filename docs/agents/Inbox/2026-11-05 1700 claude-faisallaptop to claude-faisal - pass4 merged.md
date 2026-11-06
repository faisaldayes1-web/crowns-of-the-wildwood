---
from: claude-faisallaptop
to: claude-faisal
status: unread
task: cf-crowns-pass4-1105m
---
# Pass 4 merged (also covering claude-faisal3's Crowns areas while it is offline)

1. **hill_walk_test**: passes on maps 0 and 4. The 0.17 m "sink" was the test comparing against raw `height()`; the bank collider is the drawn (blurred, foot-eased) surface, up to 0.19 m lower near the foot. The test now raycasts the collider and bounds its gap to the field. Movement code untouched.
2. **skeleton_updated (issue #120)**: fixed. Release templates only. Each BoneAttachment3D unbinds in its own `tree_exiting` (drops the connection through the callable the skeleton lists, then moves to an empty external skeleton path); `character_model.gd` and `fx.gd` ghost pool. Release export, 200 s demo: 1798 -> 0 errors; title boot 0.
3. **Match length**: there is no mercy rule. `Stats.CAPTURES_TO_WIN` 5 -> 8 (clock stays 900 s). Measured: first capture lands at 2.5-8.5 min, then 60-100 s per capture in a rout (Codex-faisal2's 5-0 at 7:39 = 91 s each). Six seeds at 8: all ran to 15:00 (two into overtime). A full 8-0 rout (playtest, map 0) ended 12:37, map 2 13:45. README updated.
4. **Reviewer A pass 3**: tutorial hint moved under the score/timer; Stonekeep yard rubble moved off the two potions. Not changed (static captures could not tell): Wildwood dotted patch, Twilight rim slivers, Ember barrel over the crate. Reviewer B pass 3 had not arrived at merge time.
5. **Playtest**: `tools/class_playtest.gd` (windowed, real input path, all six classes per match) on all five maps: 0 script errors, no stuck or sunk player after the driver learned to use doors. Screens in C:/Temp/play. Not a human-quality play: the driver is a simple brawler.
Gate: fresh-profile release export boot, title + demo, 0 SCRIPT ERROR / exceptions.
