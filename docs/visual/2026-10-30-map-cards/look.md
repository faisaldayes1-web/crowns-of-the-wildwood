# Map-card look record

Agent: Codex-faisal2

Before rendering, inspected main 354b74e in an isolated worktree, README, Memory Brief, AGENTS, agent/task boards, world style specification, scenes/main.tscn entry point and game.gd map building/lighting and match setup, menu.gd card crop/lock rendering, and existing capture tools.

Viewed existing assets/ui/menu/map_wildwood.png and the actual gameplay screenshot docs/evidence/codex-faisal-reference-daylight/01-day-desktop.png. The game is a stylized 3D overhead capture-the-monarch game, with actual castles, a central river/plaza and branching paths, not a newly invented setting.

Viewed the supplied picked-target triptych C:/Games/ORY-Candidates/Crowns/visual-pass/world/triptych/02-map-hall.png after hub transfer. The right panel is the picked target; middle is a previous implementation, not the target. Cards need clear terrain and landmark silhouettes at small size; Moonlit retains its UI lock. Capture real map geometry and current match lighting locally. No image API or external IP.

Scope: four requested map-card images; Twilight Grove remains unchanged. Render source and 4096px clean/labelled overhead exports plus coordinate bounds accompany the cards. New design/layout is not being invented.

Integration refresh: while rendering, main advanced to 0158a9c with PR131's world/VFX changes. Inspected the merged diff (leaf shader, paving, hall columns, daylight effects) and repeated every map capture from that source. Final textures and comparison now use 0158a9c geometry/materials; the original 354b74e pass remains only in git history. Card supersampling uses Lanczos reduction from 1024x960 to 512x480, with no paint-over or content edits.
