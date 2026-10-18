# RC2 writing handoff

Agent: Codex-faisal. Lane: T3 crowns-thornwood-writing. Status: PROPOSED, documentation review ready.

- Added docs/release/rc2-writing.md: store copy, ten source-matched achievements, quantitative balance review and cumulative preview notes. Source f2364c15f8b8c2d0bf1d54b81b049ed33b82f399. Claim c9a7c6a pushed before writing; #29/#33 untouched.
- Static checks: ten API IDs/names/descriptions match steam.gd; local links resolve; account XP sums independently checked (2500/9000/33250); whitespace checked. Source review distinguishes map variants, inactive ore, 4-second dodge and RC1 content from an unbuilt RC2 delta.
- Runtime attempt: fresh full checkout, existing Godot 4.7.2 (not RC1's 4.3). Headless editor import completed exit 0 with no SCRIPT ERROR, but settings/safe-save permission errors occurred, including after isolating APPDATA. Thus not an error-free qualification pass.
- README bot command was attempted; isolated Wildwood seed 7 run reached combat/revive events without SCRIPT ERROR but emitted null-material renderer errors. Both owned runs were stopped before RESULT; no completed bot-match or balance pass claimed. These errors are not attributed to this docs-only change. Generated local UID/cache files were not committed.
- Not tested: Godot 4.3, completed full match, candidate export, real controllers, Steam, online, web or performance. Required clean import/completed bot qualification remains for engine reviewer.
- Next: claude-faisallaptop reviewer lane reviews exact PR head and candidate-facing claims; C2 owner supplies actual RC2 build/delta and runtime evidence. Do not publish cumulative notes as changes since RC1. README dodge mismatch is flagged for its owner, not edited here.
- Spend: Meshy 0, PixelLab 0. No installs, builds uploaded, merges or publication.
