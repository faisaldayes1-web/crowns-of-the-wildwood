# Agent Board: Crowns of the Wildwood

| Group | Agent | Current task | Files owned | State | Handoff |
|---|---|---|---|---|---|
| Coordination | `claude-cloud` | Repo joins the studio workflow: AGENTS.md, boards, inbox; CW-1..3 queued | `AGENTS.md`, `CLAUDE.md`, `docs/agents/` | Done 2026-10-16 | — |
| Integration | `claude-faisallaptop` | CW-2 integration (#8, #13, #9, #6, #17) + 2 new maps + visual pass + lag fix, one PR | branch `claude-faisallaptop/int1`; `scripts/game.gd`, `scripts/stats.gd`, map/visual/perf code, `docs/agents/Handoffs/2026-10-16 claude-faisallaptop int1.md` | Done: #31 merged | [handoff](Handoffs/2026-10-16%20claude-faisallaptop%20int1.md) |
| Release | `claude-faisallaptop` | RC1 build of main `ce6abfc` for CW-4: Windows build, a bot match and screenshots per map (local only, nothing published) | `build/` (ignored), `docs/screenshots/rc1/`, `docs/agents/Handoffs/2026-10-16 claude-faisallaptop rc1.md` | Done 2026-10-16 (local build only) | [handoff](Handoffs/2026-10-16%20claude-faisallaptop%20rc1.md) |
| Performance | `claude-faisallaptop` | 4-player split-screen hitches (CW-4 T09: >= 30 fps 1% low proposed) | `scripts/hud.gd` map pins, `scripts/character_model.gd` resource cache, pane shadows in `scripts/game.gd` | Done: #46 merged | — |
| Online | `claude-faisallaptop` | Online play on all five maps (ENet + relay), CW-4 T07 | `scripts/game.gd` (`_warm_up_menus`), test tools | Done: #45 and #57 merged (#57: stalled and mid-match joiners keep their link; `tools/net_midjoin.sh`) | — |
| Input | `claude-faisallaptop` | Gamepad split-screen checks, CW-4 T06 (simulated pads; physical pads need Faisal) | test tools, input fixes if found | Done: #47 merged (physical pads still need Faisal) | — |
| Tests | `claude-faisallaptop` | Every save-writing test runs only in a throwaway user dir (follow-up to #47's review) | `tools/tests/isolated.sh`, `tools/tests/isolated.gd`, the save-writing tests in `tools/` (`hitch_probe`, `kbm_move_test`, `menu_flow_test`, `options_menu_test`, `reload_menu_test`, `save_test`, `store_menu_test`, `touch_close_test`, `window_mode_test`) | Done: #58 merged | — |
| Release | `claude-faisallaptop` | Windows build of main `3ddbb2e` for Faisal's desktop (local only, nothing published) | `build/2026-10-18-main-3ddbb2e/` (ignored), zip in Faisal's OneDrive builds folder | Done 2026-10-18 (status on #53) | — |

**Adding a row:** append at the bottom; edit only your own rows.

Agent: Codex-faisal2. T2 claim: docs/playtests/T2_Morning_20_Minutes.md only; 20-minute morning playtest for Faisal; branch Codex-faisal2/t2-morning-playtest; 2026-10-18.

Overnight T3 claim 2026-10-18 — Agent: Codex-faisal2. T3 Crowns of the Wildwood Store Page. Own new `docs/agents/Proposals/T3 Store Page.md` and `docs/agents/Handoffs/2026-10-18 Codex-faisal2 T3 Store Page.md` only; writing PROPOSED; no runtime edits.

Agent: Codex-faisal2. T2 claim: docs/playtests/T2_Accessibility_Settings.md only; proposed accessibility and settings checklist; branch Codex-faisal2/t2-accessibility; 2026-10-18.

Agent: Codex-faisal. Owner-requested framework cutover, 2026-10-20. Claim: `AGENTS.md`, `CLAUDE.md`, NEW `ORY_WORKFLOW.md`, and this own appended board record only. Task: #66. Branch: `agent/Codex-faisal/66-framework-cutover`. No runtime/art/shared gameplay claims or reassignment. Status: documentation migration prepared for review; source execution/merge follows repository policy.
