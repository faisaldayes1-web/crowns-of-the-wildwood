# Changelog

Every release of Crowns of the Wildwood, newest first. Each release is a PR merged into `main` with a merge commit and tagged. Per-commit detail lives in the group logs under [changelog/](changelog/README.md); how to undo anything is in [REVERTING.md](REVERTING.md).

Versioning: a new feature bumps the minor number (v0.3.0 → v0.4.0), a fix or polish-only release bumps the patch number (v0.3.0 → v0.3.1).

## Unreleased

Waiting to release, in this order:

| PR | What | Planned tag | Status |
| --- | --- | --- | --- |
| [#6](https://github.com/faisaldayes1-web/crowns-of-the-wildwood/pull/6) | Online & Platforms group | patch or minor | draft, off main |
| [#7](https://github.com/faisaldayes1-web/crowns-of-the-wildwood/pull/7) | World & Maps group | patch or minor | draft, was stacked on #1 (now in main): retarget to main |
| [#2](https://github.com/faisaldayes1-web/crowns-of-the-wildwood/pull/2) | Main menu rebuilt to match the mockup | not scheduled | needed before #4, which already contains it |
| [#4](https://github.com/faisaldayes1-web/crowns-of-the-wildwood/pull/4) | Ember Pass volcano map, Fire Objective, Fire classes | v0.4.0 | held until the Volcano map and Current build showcase threads finish |
| [#8](https://github.com/faisaldayes1-web/crowns-of-the-wildwood/pull/8) | Combat & Balance group | patch or minor | built on #1-#4 combined: after #4 |

## Version tags

Tag pushes from Claude's sessions are refused by GitHub (403), so every release is also marked by a `release/vX.Y.Z` branch pointing at the same commit. Treat those branches as read-only. Until the tags exist, use `release/v0.3.0` wherever this file or REVERTING.md says `v0.3.0`. To create the real tags yourself from a clone:

```sh
git tag v0.2.0 29e5ea8 && git tag v0.3.0 799a873 && git tag v0.3.1 d49bb86
git push origin --tags
```

## v0.3.1 · 2026-10-09 01:49 UTC · match summary and modern scoreboard

- **PR:** [#3](https://github.com/faisaldayes1-web/crowns-of-the-wildwood/pull/3) · **Merge:** `d49bb86` · **Marker:** `release/v0.3.1`
- **What:** End-of-match summary screen with accolades (replaces the live HUD at match end); new scoreboard with score first, then K, D, A, caps, damage; falling now costs 2 levels instead of all of them; extra XP for killing higher-level enemies; base attack reach no longer grows with rank; bows and staves 15% slower; class retune; batch balance tools in `tools/balance/`.
- **Tunables:** `DEATH_LEVEL_LOSS` new, 2 (was: back to level 1) · `XP_UPSET` new, 15 · `RANGED_ATTACK_SLOW` new, 1.15 · Human `regen_mult` 1.12 → 1.06 · Knight plate armour 0.40 → 0.37 · Siegewright Sledge armour 0.25 → 0.3 · Dark Priest Drain Bolt cost 27 → 21 · Engineer base armour 0.2 added · Knight Vanguard attack armour 0.42 added. Full list: `git diff 799a873 d49bb86 -- scripts/stats.gd`.
- **Conflict resolved:** `scripts/hud.gd` scoreboard, kept #3's `Scoreboard.draw_overlay` / `draw_table` over #1's inline table (merge `a3f2436` on the PR branch).
- **Tested:** headless import with no script errors; 6-minute bot match ran clean (Humans led 1-0); scoreboard rendered at 1080p in the new HUD style.
- **Revert:** `git revert -m 1 d49bb86`

## v0.3.0 · 2026-10-08 20:50 UTC · cartoon restyle and HUD restyle

- **PR:** [#1](https://github.com/faisaldayes1-web/crowns-of-the-wildwood/pull/1) · **Merge:** `799a873` · **Marker:** `release/v0.3.0`
- **What:** Fat Princess-style cartoon look (ink outlines, cel light, flagstone and cobble paths, sandstone and grey castles); stealable floating crown objective with the holding-crown banner; class room alcoves and round throne dais; readable overhead labels; round painted minimap; golden-hour light; HUD and top bar redrawn from Faisal's UI reference (in-match HUD signed off by Faisal 2026-10-08 10:52).
- **Tunables:** none in `scripts/stats.gd` beyond what the HUD needs; see the PR's commits.
- **Tested:** headless import with no script errors; 6-minute bot match ran clean (Elves won 2-0 at 138 s). One harmless "Invalid polygon data, triangulation failed" line in the log.
- **Revert:** `git revert -m 1 799a873`

## Docs · 2026-10-08 20:43 UTC · changelog scaffolding

- **PR:** [#5](https://github.com/faisaldayes1-web/crowns-of-the-wildwood/pull/5) · **Merge:** `3fb4fad`
- **What:** this file, [changelog/README.md](changelog/README.md) with the per-group entry format, and [REVERTING.md](REVERTING.md). Docs only.
- **Revert:** `git revert -m 1 3fb4fad`

## Note: the 2026-10-08 showcase build

The playable Windows build and renders shared on 2026-10-08 (`game/current-build/` in the project files) were built from a local branch that combined `main` (`29e5ea8`) with PRs #1, #2, #3 and #4. That branch was never pushed, so it exists only in `game/current-build/crowns-of-the-wildwood-source.zip`. To reproduce it from git, merge those four PRs onto `29e5ea8`. Conflicts were resolved then as follows: the HUD scoreboard takes #3's `Scoreboard.draw_*`; the Fire Objective line from #4 is drawn on #1's top-bar parchment strip; `assets/CREDITS.md` keeps both sides; `sun.shadow_blur` keeps #1's 0.3.

## v0.2.0 · 2026-10-07 · baseline

- **Tag:** `v0.2.0` on `29e5ea8` · **Marker:** `release/v0.2.0` (Modern graphics, 1080p scaling, graphics presets, main menu button, no beds or hanging lights).
- Everything built up to 2026-10-07 07:43 UTC: both factions and four classes, Wildwood map, crown objective, couch split-screen, PS5 / Xbox pads, remappable controls, settings, match summary basics. This tag is the point every later release can be reverted back to.
- **Go back to it:** see "Go back to a release tag" in [REVERTING.md](REVERTING.md).
