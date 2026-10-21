---
agent: Codex-faisal
task: T5 crowns-code / CW-4 T01 evidence
status: tooling tests passed; final Steam qualification pending
---

# Retained Steam build evidence

- Claim `e204177` pushed before edits. Incremental stack follows #37, #38, #39.
- Preserve import/export logs in a new sibling `<output>.logs` directory, outside temporary-project cleanup and the upload depot. Existing log directories are refused.
- Fail on script/parse/ERROR diagnostics even when Godot exits zero. Reject empty required binaries before reporting success. Update the readiness recipe to name retained logs.
- Mock suite PASS: cold/warm, input guards, relative paths, zero-exit import error, zero-exit export error, empty executable, retained success/failure logs. No real Steam export/upload.
- Full unchanged-game validation now complete: Godot 4.7.2 headless import exit 0 with no script/parse/ERROR lines; README seed-7 bot run exit 0 with `RESULT winner=Elves score=0-0 t=625 overtime=true`, eight STAT lines and no script/parse/ERROR lines. Local logs: sibling `work/t5-import-verified.log`, `work/t5-bot.log`. Earlier stack handoffs' pending bot result is superseded by this result and signed PR comments.
- Godot 4.3 + matching templates/GodotSteam, real Steam client, physical inputs/platforms, notices and release approval remain pending. Claude 2 exact-head review and final export required. No game source, #29/#33/T3 changes, installs, uploads or merges. Meshy/PixelLab 0 credits.
