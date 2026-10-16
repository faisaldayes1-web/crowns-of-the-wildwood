# Task Board: Crowns of the Wildwood

State on 2026-10-16: `main` is **v0.3.1** (2026-10-08). **13 PRs are open and unmerged** (#2, #4, #6–#10, #12, #13, #15, #17, #18), some overlapping (two main-menu PRs, two Ember Pass PRs, two visual-overhaul PRs). Getting them integrated is the first job.

## Open
- [ ] **CW-1 PR backlog ledger** (`chatgpt`, read-only): for every open PR list what it changes, files touched, overlaps/conflicts with other PRs, which ones supersede others (#2 vs #17, #4 vs #17, #10 vs #18), and a recommended merge order. → `docs/agents/PR Ledger.md`. GitHub issue labeled `chatgpt-task`.
- [ ] **CW-2 Integration branch** (`claude-faisallaptop`, after CW-1): one branch `claude-faisallaptop/int1` merging the PRs in CW-1's order (merge commits, no rebase), resolving conflicts, then a headless import with no script errors and a 6-minute bot match per map; screenshots. One PR to `main` for Faisal to approve. Same approach as DualFront's INT1.
- [ ] **CW-3 v0.4 backlog proposal** (`chatgpt`, PROPOSED): from the README rules and the open PRs, a ranked list of the next 10 tasks (balance, maps, online, iPad/web build), each with acceptance criteria.

## Done
- v0.2.0 baseline, v0.3.0 cartoon + HUD restyle, v0.3.1 match summary + scoreboard (see `docs/CHANGELOG.md`).
