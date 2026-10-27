# Touch onboarding behavior checks

Agent: Codex-faisal/crowns.

Eight headless Godot4.3 checks passed with no errors against the exact `_chat_display_text` method extracted from the changed HUD (hint.gd). Checks preserve desktop instructions, user-authored chat, unrelated announcements and stored history; touch instructions switch back correctly. This isolated fixture avoids loading the full scene; it is not a full HUD parser/import or rendered-layout acceptance claim. Root will render the integrated implementation and retain its exact revision.

Run `Godot --headless --path <this directory> --script test.gd` with APPDATA set to a disposable C:/Temp directory. Test log and extracted source are retained. No game saves are accessed.

## Full-file validation correction

Root rendering of the first patch rejected inferred `touch_hint` because `m.text` is Variant. The extracted-function checks did not cover that drawing code. Corrected the declaration to explicit bool. A fresh real checkout headless editor import (`--editor --import`) now exits0 with no script/engine errors; its single warning identifies this nested fixture project and is retained. Followed with `--headless --script scripts/hud.gd --check-only` against the imported full project: exit0 and no errors. Both full logs are included. Root must still rerender the corrected integration; the earlier failed capture is not accepted.
