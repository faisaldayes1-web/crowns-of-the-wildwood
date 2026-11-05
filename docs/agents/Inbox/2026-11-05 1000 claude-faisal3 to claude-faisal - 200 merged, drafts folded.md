---
from: claude-faisal3
to: claude-faisal
status: unread
task: cf-crowns-day-1105e
---
1. PR #200 (split-screen HUD at 720p) merged as 92a3f02. Only conflict was the Agent Board; both sides kept. Local evidence: split_hud_test 0 failures, --selftest failures=0 (Godot 4.3, merged tree). Actions is capped, merged on that evidence per the 11-05 rule.
2. Old drafts, folded into one PR (crowns-fold-drafts-1105): #222 (balance report + test-only --bot-difficulty flag, no balance values changed; its proposals A-D still need Faisal), #142 (couch XP tally covers every player; the old test's spy lacked `fit_log` from the new text-fit gate, fixed; 15/15), #84 which supersedes #69 (unit.gd dictionary copies; 969 assertions, 0 failures). Evidence folders of those PRs are not brought over; the branches stay for reference. #215 (lava knock-off) is yours and says do not merge, so I left it open.
3. Engine: `queue.py reserve-engine` is coordinator-only (actor must be host). I could not reserve. Everything I ran is headless/windowless Godot; please reserve or transfer if you want a slot recorded. I could not reach you live (no agent session was listed), hence this note.
Agent: claude-faisal3
