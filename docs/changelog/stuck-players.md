# Stuck players changelog

Fixes for Faisal's 2026-10-14 report: "sometimes people get stuck", and
"the healer bots follow too closely ... they are on the same tile sometimes as
players". Branch `claude/fix-stuck-players-ksuiqt`, cut from the Steam beta
(Integration & Release `b0e261f`).

Checks: `tools/tests/run.sh` (headless tests, now with the stuck checks), a
7-minute `--demo` on both maps, and `tools/stuck_scan.gd` (below).

## Entry format

Newest entry at the top, as in [README.md](README.md).

---

### 2026-10-14 · `HASH` · Nobody stays stuck

- **What:**
  - **Frozen after a finisher (the main lock):** if the enemy finishing you
    off was knocked down or killed mid-move, you stayed on the ground,
    unable to crawl, give up or be revived, until they respawned and struck
    you from across the map. A striker who falls now lets the body go.
  - **Blink and Shadow Step** checked the way with one thin line at chest
    height, so they slipped over low walls, crates and fences and could drop
    you inside them or in a nook behind them. They now sweep your whole body
    and stop a step short of anything solid.
  - **iPad move stick could lock:** if the browser lost a finger's lift (a
    system swipe, the tab losing focus), the stick kept its slot, so a new
    thumb could not move you (or you kept walking). The newest touch on each
    half now takes the stick or aim pad over, and every held touch is let go
    when the game loses focus.
  - **Safety net:** anyone wedged inside something solid for half a second
    (a fence rebuilt round them, a turret dropped on them, a hard shove) is
    set down on the nearest free spot, and anyone who falls out of the world
    goes back to their spawn. Respawns also pick a free spot and clear any
    dash, shove or root left from the last life.
  - **Healer bots no longer stand on you:** bots that follow someone (Healers,
    crown escorts, "To me!") keep 2 to 3.2 m away, still well inside the
    Healer's 5 m Mend, and step back out if you walk into them.
  - New tool `tools/stuck_scan.gd`: flood-fills both maps with a player-sized
    body and lists any free floor you cannot walk out of. Both maps came back
    clean (the only unreached spots, under the rampart stairs, are walkable
    out of).
- **Files:** scripts/unit.gd, scripts/touch.gd, scripts/stats.gd,
  tests/combat_test.gd, tools/stuck_scan.gd
- **Tunables:** new `BOT_FOLLOW_MIN` 2.0 and `BOT_FOLLOW_MAX` 3.2 (before:
  followers stood anywhere 0 to 2.1 m from a Healer's buddy, 0 to 3.5 m from
  a crown carrier, 0 to 1.8 m from a "To me!" call)
- **Tested:** `tools/tests/run.sh` 0 failures (6 new checks: the finisher
  release, a downed body not frozen, Blink stopping short of a block, a
  wedged body freed, followers keeping distance); 7-minute demos, Wildwood
  seed 301 and Ember Pass seed 302: no STALL lines (the same seeds before
  the fix had two Rangers stalled at the Wildwood defence posts), no safety
  net triggers, no script errors.
- **Revert:** `git revert HASH`
