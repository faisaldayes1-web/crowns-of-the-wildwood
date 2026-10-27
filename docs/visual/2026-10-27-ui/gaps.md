# Picked UI implementation gaps
Agent: Codex-faisal/ui

| Screen | Before | Built candidate | Remaining qualification |
|---|---|---|---|
| Title D | Baked left buttons, corner profile | Independent right stack, top telemetry, bottom-left utilities | Native title scene supplied by world branch; visual comparison after integration |
| Map A | Short cards and two settings boxes | Tall cards, unified three-column command shelf | Native map imagery retained; fixed team size has no invented arrows |
| Ready A | Tags floating above heroes | Tags attached to larger information cards, full command footer | Character materials supplied separately |
| Spawn C | Single rectangular action strip | Radial action cluster, existing corner portrait/map and phase banner | Touch keeps native large thumb arc |
| Live C | Joined score banner | Separate corner team scores and centre clock, lowered minimap, radial actions | Desktop/mobile and split-screen captures |
| Pause C | Short horizontal tabs, small footer | Stacked glyph/title tabs and large centred leave/resume controls | Authoritative native map renderer retained |
| Knight C-v2 | Wide ribbon | Selected central class card with flank cards; separate perks access with block | Actual faction ability names retained, no generated invented abilities |

Capture harness stages deterministic states and calls menu handlers; screenshots prove rendered states, not physical input actions. Input and mobile validation must be reported separately. Existing headless/menu/bot checks and integrated screenshots remain required before PR.

## Validation before integration

Headless full import passed with no script errors (C:/ORY-Cache/qa/crowns-ui-import-final.log). Isolated menu_flow_test passed with 0 failures, including map/lobby actions, ready gating, two-player controller routing and split layout changes. Capture script check-only passed. Rendered hit geometry, native title, full bot match and side-by-side images remain integration checks. The live reference capture is explicitly a staged quiet courtyard in battle phase, not combat-action evidence. `--capture-touch` enables the native touch layout for an additional viewport run.
