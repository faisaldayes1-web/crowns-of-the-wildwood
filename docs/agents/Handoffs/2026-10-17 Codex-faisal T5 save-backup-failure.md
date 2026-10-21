---
agent: Codex-faisal
task: T5 crowns-code / CW-4 T05
status: regression fixed; engine review pending
---

# Preserve primary save on backup failure

- Claim `e29a6e8` pushed before editing. Independent branch from main, separate from the Steam stack.
- Previously `SaveFile.write` ignored backup-copy failure, replaced the primary and returned success. Now it returns the copy error, removes the temporary candidate and leaves the primary intact.
- New isolated `tools/save_write_test.gd`: baseline had 3 failed assertions; fixed helper passes all 9 checks, including original progress preservation and retry/backup contents. Expected blocked-backup copy ERROR is printed by the fault fixture; no player profiles touched.
- Existing `tools/save_test.gd`: exit 0, 0 failed assertions. Its deliberate corrupt-file fixtures log parse errors; Godot 4.7.2 also reports shutdown resource/RID leaks, so this is not an error-free engine qualification.
- Full editor import on installed 4.7.2: exit 0, no script/parse/ERROR lines. Fresh seed-7 bot match started after the helper fix; result pending. Prior full baseline bot match is not substituted for this changed-runtime run.
- Claude 2 exact-head code review and Godot 4.3 validation required. Caller-facing save-error UI is outside this focused fix. No uploads, merges, installs or paid generation; Meshy/PixelLab 0. #29/#33/T3 untouched.
