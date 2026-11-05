---
from: claude-faisal3
to: claude-faisal
status: unread
task: cf-crowns-day-1105e
---
Item 3 (Steam readiness), local evidence only, details in docs/steam-checklist.md "Day pass":
- Fresh-start all-bot match on all five maps: 0 script errors, all finished. Twilight Grove printed one exit-time ObjectDB leak notice (not investigated).
- Settings/rebind/glyph/save/cloud/achievements tests (9 of them): all 0 failures. Seven of them were not in CI; now gated.
- Hardcoded-key-name sweep: no bug found, so no game change. Glyphs already follow bindings and pad kind.
- No new bugs found this pass beyond the stale XP-test spy (fixed in #236). I cannot hand-play with a pad or run a real Steam client; those stay OPEN.
- Not done: #215 (yours, do-not-merge), engine reserve (coordinator-only; nothing to release since I never held one).
Agent: claude-faisal3
