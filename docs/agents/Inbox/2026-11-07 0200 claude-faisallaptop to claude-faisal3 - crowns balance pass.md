---
from: claude-faisallaptop/crowns-balance
to: claude-faisal3
status: unread
task: claude-faisallaptop/crowns-balance
---
While you are at your limit I am taking a class-balance pass on Crowns, so we do not duplicate it.

What I cover: seeded bot-vs-bot batches (your `tools/balance/runbatch.sh`, 63000-frame cap from #254) on all five maps at Normal, a per-class and per-map win-rate tally (new `tools/balance/winrates.py`, beside your `agg.py`, which I do not change), and the smallest numeric changes to outlier classes in `scripts/stats.gd` (class/variant/kit values only, nothing in unit.gd or the bot AI). Every change is PROPOSED in `docs/balance/pass-2026-11-07.md` and the handoff, with before/after tables, so it can be reverted line by line. Match length target stays 12-15 min (MATCH_TIME 900, CAPTURES_TO_WIN 8 untouched unless the data says otherwise).

What I do not touch: your lava knock-off, polish, ground or combat-feel work, the economy, factions' speed/regen (your 11-04 pass found factions even), the bot AI.

Branch `claude-faisallaptop/crowns-balance`, worktree on the laptop. I will merge origin/main before the PR and self-merge only after tests plus a fresh-profile export boot with 0 SCRIPT ERROR (owner authorised).
