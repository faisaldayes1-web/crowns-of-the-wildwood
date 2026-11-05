# Two notes for Faisal (claude-faisal3, 2026-11-04)

## 1. Balance PR #222 (waiting on you): what it changes, and my recommendation

**It changes no balance values.** It adds a test-only `--bot-difficulty=` flag (`scripts/game.gd`, 4 lines), a `DIFF=` option in `tools/balance/runbatch.sh`, and the report `docs/balance/pass-2026-11-04.md`. Merging it is safe for players; it is a draft only because the report holds proposals that AGENTS.md rule 6 says you approve.

**What the 40 bot matches showed:** factions are even (20-20 in wins, kills within 2%); matches last about 6.5 minutes and only 4 of 40 needed overtime; no script errors. Melee trails ranged (K/D 0.67 to 0.91 against 1.0 to 1.1), the one pattern that held on both teams.

**Recommendation**
- Merge #222 as is (tool and report, no game change).
- A (melee uplift): not yet. Per-class samples are 13 to 27 matches' worth, so most gaps are noise. If you want to act, nudge only the Human Warden (33 to 43 damage a match against 65 to 84 for ranged), then run the six-seed batch per map before merging.
- B (difficulty): needs you or a tester to play one match each on Easy, Normal and Hard. Bot-versus-bot runs cannot judge it.
- C (Ember Pass is about 220 s): fine unless the store page promises 10-minute matches. Your call.
- D (Stonekeep wood is a third lower): look at where its wood nodes sit before touching any cost.

## 2. Team Deathmatch (#221): bugs and tuning proposals (PROPOSED)

**Data:** 6 seeded bot-only 4v4 TDM matches (seeds 31 to 36, default map), no script errors. Results: Elves won 4 (30-18, 30-25, 30-28, 29-21), Humans 2 (30-20 twice). Five of six reached 30 kills at 366 to 491 s; one was decided on the clock at 600 s (29-21). Average about 470 s.

**Possible issue (design call):** a knock-down scores the point at once (`unit._fall` calls `tdm_kill`), and a revive does not take it back. A team that keeps reviving a downed mate gives the enemy a point on each knock-down, so "30 kills" really means 30 knock-downs. Options: leave it (simple, fast), or refund the point when the revive completes (fairer, a few lines in `unit.gd`). I did not change it.

**Tuning proposals (not applied)**
- **Kill target 30:** keep it. Matches end in 6 to 8 minutes, close, and the clock decided only 1 in 6. If a shorter mode is wanted, 25 gives about 6 minutes; 40 would mostly run into the 10-minute clock.
- **Respawn waves (6 s, never under 4 s):** keep. Waiting 4 to 10 s feels fine on paper, but bots cannot say how it feels to a person: please play one match and check that a death is not a long stare at the death screen.
- **Humans lost 2 of 6 by the same 20-30:** too few matches to read; rerun 12 seeds across two maps before touching anything.

Not covered: human play, split screen in TDM, online, and maps other than the default.
