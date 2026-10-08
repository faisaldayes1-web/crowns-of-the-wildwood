# Changelog

Every release of Crowns of the Wildwood, newest first. Each release is a PR merged into `main` with a merge commit and tagged. Per-commit detail lives in the group logs under [changelog/](changelog/README.md); how to undo anything is in [REVERTING.md](REVERTING.md).

Versioning: a new feature bumps the minor number (v0.3.0 → v0.4.0), a fix or polish-only release bumps the patch number (v0.3.0 → v0.3.1).

## Unreleased

- **Changelog scaffolding** (Integration & Release): this file, [changelog/README.md](changelog/README.md) with the per-group entry format, and [REVERTING.md](REVERTING.md).

Waiting to release, in this order:

| PR | What | Planned tag | Status |
| --- | --- | --- | --- |
| [#1](https://github.com/faisaldayes1-web/crowns-of-the-wildwood/pull/1) | Cartoon restyle and HUD restyle (in-match HUD signed off by Faisal 2026-10-08 10:52) | v0.3.0 | next |
| [#3](https://github.com/faisaldayes1-web/crowns-of-the-wildwood/pull/3) | End-of-match summary, modern scoreboard, balance pass | v0.3.1 | after #1 |
| [#2](https://github.com/faisaldayes1-web/crowns-of-the-wildwood/pull/2) | Main menu rebuilt to match the mockup | not scheduled | needed before #4, which already contains it |
| [#4](https://github.com/faisaldayes1-web/crowns-of-the-wildwood/pull/4) | Ember Pass volcano map, Fire Objective, Fire classes | v0.4.0 | held until the Volcano map and Current build showcase threads finish |

## Note: the 2026-10-08 showcase build

The playable Windows build and renders shared on 2026-10-08 (`game/current-build/` in the project files) were built from a local branch that combined `main` (`29e5ea8`) with PRs #1, #2, #3 and #4. That branch was never pushed, so it exists only in `game/current-build/crowns-of-the-wildwood-source.zip`. To reproduce it from git, merge those four PRs onto `29e5ea8`. Conflicts were resolved then as follows: the HUD scoreboard takes #3's `Scoreboard.draw_*`; the Fire Objective line from #4 is drawn on #1's top-bar parchment strip; `assets/CREDITS.md` keeps both sides; `sun.shadow_blur` keeps #1's 0.3.

## v0.2.0 · 2026-10-07 · baseline

- **Tag:** `v0.2.0` on `29e5ea8` (Modern graphics, 1080p scaling, graphics presets, main menu button, no beds or hanging lights).
- Everything built up to 2026-10-07 07:43 UTC: both factions and four classes, Wildwood map, crown objective, couch split-screen, PS5 / Xbox pads, remappable controls, settings, match summary basics. This tag is the point every later release can be reverted back to.
- **Go back to it:** see "Go back to a release tag" in [REVERTING.md](REVERTING.md).
