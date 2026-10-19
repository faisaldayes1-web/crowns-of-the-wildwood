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



| Game fix | Codex-faisal | Issue60: repair ENet joiner reliable-event loss; explicit Codex networking route in issue60; no competing claim/comment | scripts/net.gd reliable event delivery; new focused tools and evidence; scripts/game.gd net-test instrumentation only if needed. Exclude other agents' menu/input/timeout scopes | Implemented e406591; three acceptance groups PASS (delayed load, two normal maps, import/full bot). Branch Codex-faisal/60-enet-events stacked on PR61. Original reporter case confirmation and review/integration pending | issue60; acceptance: reliable effects/chat reach joiner, snapshots/gameplay continue, clean import and bot match |

| Menu performance | Codex-faisal | Crowns PM: owner directly authorized menu-lag fix, 2026-10-18; current main board confirms prior menu warm-up ownership complete | scripts/menu.gd, scripts/menu_stage.gd, scripts/hud.gd menu rendering only; scripts/game.gd menu warm-up only if measurements require; tools/menu_latency_probe.gd and scoped evidence/handoff | Implemented and tested on Codex-faisal/menu-lag atop PR62 5a5387b; first Ready Up 1891.5 ms to 26.4 ms; import/menu-flow/bot PASS; existing exit warnings remain; review pending | Acceptance: repeatable before/after rendered timings, menu navigation correctness, short video; clean import and bot match |

| Menu completion | Codex-faisal | Crowns PM direct owner request: finish all-menu responsiveness and deliver verified desktop build | scripts/menu_stage.gd model reuse; scripts/menu.gd and scripts/hud.gd menu rendering if profiling requires; tools/menu_latency_probe.gd; scoped evidence/build packaging | Continuing own PR64 on Codex-faisal/menu-lag; preserve PR61/62; no conflicting current main claims | Acceptance: all-menu navigation/latency coverage, packaged smoke, desktop shortcut plus video/timings |

| Map transitions | Codex-faisal | Crowns PM direct owner request: fix map switching lag; preserve menu and loading fixes | scripts/game.gd map selection/world construction; new tools/map_latency_probe.gd; existing map switching regression only as needed; own handoff/evidence | Claimed on Codex-faisal/map-transitions stacked on PR64 df0cb3f; desktop Godot 4.3 serialized | All 20 directed map pairs correct, measured stalls reduced, menu/loading regressions and bot pass |

| Codex-faisal | ACTIVE map-transition scope extension | Codex-faisal/map-transitions | Include scripts/menu_stage.gd and scripts/volcano.gd construction checkpoints; preserve menu hero cache and warm-up behavior. Serialized desktop Godot 4.3 validation. |

| Codex-faisal | ACTIVE map-transition scope extension | Codex-faisal/map-transitions | Include scripts/menu.gd immutable menu texture retention: profiling found approximately 1 second of repeated artwork loading per scene rebuild. No menu behavior changes. |
