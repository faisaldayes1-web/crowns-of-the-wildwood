# Agent Board: Crowns of the Wildwood

| Group | Agent | Current task | Files owned | State | Handoff |
|---|---|---|---|---|---|
| Coordination | `claude-cloud` | Repo joins the studio workflow: AGENTS.md, boards, inbox; CW-1..3 queued | `AGENTS.md`, `CLAUDE.md`, `docs/agents/` | Done 2026-10-16 | — |
| Integration | `claude-faisallaptop` | CW-2 integration (#8, #13, #9, #6, #17) + 2 new maps + visual pass + lag fix, one PR | branch `claude-faisallaptop/int1`; `scripts/game.gd`, `scripts/stats.gd`, map/visual/perf code, `docs/agents/Handoffs/2026-10-16 claude-faisallaptop int1.md` | PR #31 for review, 2026-10-16 | [handoff](Handoffs/2026-10-16%20claude-faisallaptop%20int1.md) |
| Release | `claude-faisallaptop` | RC1 build of main `ce6abfc` for CW-4: Windows build, a bot match and screenshots per map (local only, nothing published) | `build/` (ignored), `docs/screenshots/rc1/`, `docs/agents/Handoffs/2026-10-16 claude-faisallaptop rc1.md` | Done 2026-10-16 (local build only) | [handoff](Handoffs/2026-10-16%20claude-faisallaptop%20rc1.md) |
| Performance | `claude-faisallaptop` | 4-player split-screen hitches (CW-4 T09: >= 30 fps 1% low proposed) | `scripts/hud.gd` map pins, `scripts/character_model.gd` resource cache, pane shadows in `scripts/game.gd` | PR open 2026-10-17 | — |
| Online | `claude-faisallaptop` | Online play on all five maps (ENet + relay), CW-4 T07 | `scripts/game.gd` (`_warm_up_menus`), test tools | In progress 2026-10-17 | — |
| Input | `claude-faisallaptop` | Gamepad split-screen checks, CW-4 T06 (simulated pads; physical pads need Faisal) | test tools, input fixes if found | Queued 2026-10-17 | — |
| Tests | `claude-faisallaptop` | Every save-writing test runs only in a throwaway user dir (follow-up to #47's review) | `tools/tests/isolated.sh`, `tools/tests/isolated.gd`, the save-writing tests in `tools/` (`hitch_probe`, `kbm_move_test`, `menu_flow_test`, `options_menu_test`, `reload_menu_test`, `save_test`, `store_menu_test`, `touch_close_test`, `window_mode_test`) | In progress 2026-10-18 | — |

**Adding a row:** append at the bottom; edit only your own rows.

Agent: Codex-faisal2. T2 claim: docs/playtests/T2_Accessibility_Settings.md only; proposed accessibility and settings checklist; branch Codex-faisal2/t2-accessibility; 2026-10-18.

| Game fix | Codex-faisal | Issue59: reproduce and repair null-mesh spam during headless world construction; explicitly routed to Codex by Claude2 on issue59, no other claimant/comments | scripts/game.gd headless mesh-lifetime hook only; new scripts/headless_mesh_lifetime.gd and tools/null_mesh_probe.gd plus focused regression/evidence; exclude menu/network/input and static batching behavior | Implemented a7c8961, qualified126d1cc: target errors1742->0, identical world fingerprint, clean import, completed bot match with0engine errors; lifecycle regressionPASS. Branch Codex-faisal/59-headless-mesh, review/integration pending | issue59; acceptance: 0 matching null-mesh errors, no script errors on import, completed bot match; renderer behavior preserved |



| Game fix | Codex-faisal | Issue60: repair ENet joiner reliable-event loss; explicit Codex networking route in issue60; no competing claim/comment | scripts/net.gd reliable event delivery; new focused tools and evidence; scripts/game.gd net-test instrumentation only if needed. Exclude other agents' menu/input/timeout scopes | Claimed 2026-10-18; branch Codex-faisal/60-enet-events stacked on PR61/2f2dd02; reproduce before changing production | issue60; acceptance: reliable effects/chat reach joiner, snapshots/gameplay continue, clean import and bot match |
