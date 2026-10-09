# Online & Platforms changelog

Every commit from the Online & Platforms group, newest last. Each entry says what changed, the files
it touched, any tunable that moved (old → new), and the exact line that undoes it.

A commit cannot contain its own hash, so each entry is written in the commit it describes and its
hash is filled in by the group's next commit (a hash-only edit to this file, which needs no revert
of its own). To undo a change, run its revert line on the branch, then re-run `tools/net_smoke.sh`.

---

## 2026-10-08 20:55 UTC · `7953c44` · Online play plan

- **What:** wrote the plan for online play: ENet direct-IP first, then Steam networking and
  lobbies through GodotSteam; host-authoritative model (clients send inputs, the host simulates
  and sends 20 Hz snapshots); what is replicated now and later; slots and teams; matchmaking; the
  six online milestones N1-N6; builds and the smoke test. Also starts this changelog.
- **Files:** `docs/online-plan.md` (new), `docs/changelog/online-platforms.md` (new)
- **Tunables:** none
- **Revert:** `git revert 7953c44`

## 2026-10-09 01:50 UTC · `HASH-PENDING` · ENet host / join, step one

- **What:** online play over direct IP. New **ONLINE** row on the title screen (HOST / STOP,
  JOIN / LEAVE, and a box for the host's address). The host runs the whole match; a joiner's game
  rebuilds the host's world from the host's world seed, takes a bot's slot (first on the other
  side, then alternating), sends its stick, aim and buttons every physics frame, and draws the
  host's 20 Hz snapshots (units, hearts, energy, classes, deaths, monarchs, doors, vaults, score,
  clock, fortify timer, game over). Bots keep playing for the host; a joiner who leaves hands
  their unit back to a bot. Online matches do not pause. Command line: `-- --host[=port]`,
  `-- --join=ip[:port]`, `--net-test`. New headless smoke test `tools/net_smoke.sh` (passes:
  host and joiner each saw their own unit, the other player and the bots move). README has a
  new "Online play" paragraph. The world is now built from `Net.world_seed` (still random per
  run; `--seed=N` keeps its old meaning) so host and joiner build identical maps.
- **Files:** `scripts/net.gd` (new), `project.godot` (Net autoload), `scripts/game.gd`,
  `scripts/unit.gd`, `scripts/hud.gd`, `scripts/heal_orb.gd`, `tools/net_smoke.sh` (new),
  `README.md`, `docs/changelog/online-platforms.md`
- **Tunables (new, in `scripts/net.gd`):** `DEFAULT_PORT` 24560, `MAX_CLIENTS` 8,
  `SNAPSHOT_EVERY` 3 physics frames (20 Hz). Bot difficulty text on the title moved under the
  BOTS buttons (was to their right) to make room for the ONLINE row.
- **Revert:** `git revert HASH-PENDING`
