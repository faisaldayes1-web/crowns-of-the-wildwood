# Crowns settings redesign

Agent: Codex-faisal3. Task: cf-crowns-settings-1105e, assigned by Faisal in the
November 5 task chat from claude-faisal. Base: main `a93e5b4`.

Source candidate, pending native qualification. No PR or merge acceptance yet.
Faisal authorizes self-merge after local evidence while Actions is capped.

Implemented Gameplay, Video, Audio, Controls and Accessibility in a separate
native Control surface. Existing `hud.gd`, character, dialogue, class cards,
Veteran Training and customize/Armor source is unchanged. Reuse: existing
`frame_big`, wood buttons, leaf plaque and Lilita font; no generated assets.

Choices: settings save immediately except video; video edits use Apply followed
by Keep/Revert, with a 15-second automatic rollback. Reset applies to the current
tab and preserves account progress. Resolution selects a windowed size;
Borderless/Fullscreen use the native display, matching the established engine
implementation. Master80/Music60/SFX80 are defaults. Legacy intentional mute or
1% remains a valid saved preference; Audio Reset repairs an unwanted low setting.

Source inspection found existing SFX80/Music60 defaults, rather than a 0/1
initialization error. The old shared draw/poll input path remains archived in
place in the unmodified HUD. Native sliders avoid that shared hit-region path,
show integer percentages, and save drags once on release. Root-cause attribution
of the owner's screenshot's saved values remains unproven.

Source checks so far: gdtoolkit parse of all seven changed GDScripts and
`git diff --check` pass. These are not Godot semantic or rendered acceptance.

Native evidence runner (only inside an acquired laptop3:godot slot):

```powershell
& 'C:/Users/Faisal/AppData/Local/Programs/Python/Python312/python.exe' tools/run_options_qa.py --godot 'C:/Users/Faisal/Tools/godot-4.3/Godot_v4.3-stable_win64_console.exe' --stage all
```

The runner uses a separate `C:/Temp/c3cs-*` profile for every serial process,
records the exact candidate and full raw logs, and refuses error/leak output.
Stages can run separately: import, tests, captures, bot. Native fixtures cover
volume defaults/reload/reset, separate keyboard/pad rebinding, video staging,
Apply/Keep/Revert/timeout, preview-save safety, focus and container bounds.
Existing options/pad tests retain unrelated menu/gameplay assertions while
moving their settings assertions to native controls. A full seed7 bot match is
required, as are actual 720p/1080p before/after image inspection and 1440p fit.

`--before` captures the retained old HUD options at the same resolution with
the new overlay hidden; its source is byte-identical to the base. No screenshot
is claimed until that capture exists and has been inspected. The supplied
`C:/Temp/crowns-settings-faisal-1105.png` was inspected for the initial audit.

Coordination: ready-for-slot mail to claude-faisal3 `1793902397-480e69` was shown
at 18:16:37 UTC. Coordinator mail `1793902399-757cb7`; reply confirms the current
holder must agree the window. No foreign engine stopped or released, and no
Godot process launched by this task while the slot remains held.
