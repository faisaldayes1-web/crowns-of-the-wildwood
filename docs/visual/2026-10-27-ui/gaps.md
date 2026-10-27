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

## Mathematical layout audit
Agent: Codex-faisal/ui

At 1280x720, the first radial arrangement put bottom labels at y724. The revised rows end at y714, with side labels ending y628 and the lower row starting y631. Lower action labels have 108-unit centre spacing. Pause board ends y698; action footer ends y684, central medallion y694, keyboard hint baseline y716. Map action rectangles end at y712 (start) and y710 (back); lobby cards end y614 desktop and y642 touch, clear of the command shelf starting y644.

At physical 844x390, native canvas_items/expand uses approximately 1558x720 logical units (scale 0.542); web KEEP uses a 1280x720 letterboxed canvas at the same height scale. Bounds fit both. Touch-ready faction and ready controls now use 80-unit rows (~43 physical pixels) instead of 22/28. Shield users get a distinct 96-unit Perks touch target (~52 physical pixels) separate from Block and the existing thumb arc. Ready text is vertically centred. Existing map difficulty/menu utility targets remain smaller than 44 physical pixels on this phone; this audit does not claim universal touch-target compliance. No engine run during root's rendered lane.

## Rendered review correction
Agent: Codex-faisal/ui

Viewed all seven desktop captures under C:/ORY-Cache/qa/crowns-visual-pass-Codex-faisal/desktop plus mobile-first map and knight. Native title, menu cards and pause structure are visible. Gameplay captures exposed a brown rectangular ability backing, overlapping training slot, empty class-card wings, and an oversized clock crown (scale was mistakenly treated as radius). Replaced the backing with a shallow dark slate/gold polygon arc, moved training into its own right-side space, rendered actual class portraits in smaller wings, and corrected crown scale. Separate score capsules now persist during fortify, class announcements and touch; touch score reserves space for pause controls. Economy counter follows the relocated minimap. Mobile map difficulty omits tiny descriptive prose and enlarges names. These corrections require root's next rendered check; no new screenshots or engine run claimed here.

Viewed desktop-second spawn/knight captures. The separated score geometry worked but lost the picked ornamental character. Reused native cloth score bands, actual shield texture rendering, ivy, Lilita bar typography and the source topbar clock/crown region (548,0,366,163), while retaining three independent screen positions. Grab raised six units for further bottom clearance. No new raster assets or engine run.
