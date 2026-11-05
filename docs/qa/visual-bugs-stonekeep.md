Codex-faisal2 · cf-crowns-qa-1105f: independent visual bug review — Stonekeep Fortress.

Status: **supplementary frame only; 0/2 clean full passes**. No capture-grid set received. No Reviewer B list read. Source commit/camera/grid cell of this pre-existing local frame is unknown; findings require current recapture. This frame does not count as a release review pass.

Frame: `C:/Temp/crowns-stonekeep-pillars-faisal-1105.webp`, 1308x773. Coordinates are source pixels from top left. The original includes an unrelated desktop notification at bottom right; it is excluded from game findings and has not been copied into the repository.

- VA-SK-001 | Stonekeep Fortress | cell UNKNOWN (supplementary courtyard crop) | `crowns-stonekeep-pillars-faisal-1105.webp` | bbox (622,568)-(714,647) | P2 | **Suspected prop/pickup intersection:** foreground rubble cuts across and obscures the lower potion pedestal/ring. Request close ground view to verify whether rubble actually penetrates the pickup base; current-build status unknown.
- VA-SK-002 | Stonekeep Fortress | cell UNKNOWN (supplementary courtyard crop) | `crowns-stonekeep-pillars-faisal-1105.webp` | bbox (502,387)-(597,411) | P2 | **Visible world-label overlap:** white/green `ELF HEALER` lettering and gold `HEALER` lettering occupy the same horizontal band, reducing name/class readability. Capture the same two nearby units with HUD on, then separate them to identify which labels overlap; current-build status unknown.

No floating pillar or z-fighting is established from this still. The visible stone colours are not logged as geometry defects. The rear potion/rubble at (575,169)-(684,271) needs a side view, but the currently visible circular base is sufficiently distinct that intersection is not asserted. Snow caps appear supported in this view. Review the courtyard edges hidden by HUD/notification in the required clean world frames.

Next: capture owner identifies the grid cell and supplies 1080p clean courtyard and HUD views, including camera movement if flicker is suspected. Review the full grid and eight ground views before recording a full pass.
