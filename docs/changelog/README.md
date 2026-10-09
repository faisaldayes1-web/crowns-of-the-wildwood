# Group changelogs

Each developer group keeps its own log here, one file per group (the group creates its file with its first entry). Every commit a group pushes gets an entry in the same commit (or the commit right after it), so any single change can be found and undone.

| Group | Branch | Log |
| --- | --- | --- |
| World & Maps | `group/world-maps-*` | [world-maps.md](world-maps.md) |
| UI & Art | `group/ui-art-*` | [ui-art.md](ui-art.md) |
| Combat & Balance | `group/combat-balance-*` | [combat-balance.md](combat-balance.md) |
| Online & Platforms | `group/online-platforms-*` | [online-platforms.md](online-platforms.md) |
| Integration & Release | `group/integration-release-*` | [integration-release.md](integration-release.md) |
| Economy | `group/economy-*` | [economy.md](economy.md) |

Releases (merges into `main` and version tags) are logged project-wide in [../CHANGELOG.md](../CHANGELOG.md) by the Integration & Release group.

## Entry format

Newest entry at the top. One entry per commit:

```markdown
### 2026-10-09 14:05 UTC · `abc1234` · Venom Fang slow now wears off

- **What:** The Venom Fang slow lasted forever when the target died while slowed; it now clears on respawn.
- **Files:** scripts/unit.gd, scripts/stats.gd
- **Tunables:** `VENOM_SLOW_SECONDS` 3.0 → 2.5; `VENOM_SLOW_FACTOR` 0.6 (unchanged)
- **Tested:** 6-seed batch on Wildwood (Elves 3, Humans 3)
- **Revert:** `git revert abc1234`
```

Rules:

- **Time** is UTC, from `TZ=UTC git log -1 --format=%cd --date=format-local:'%Y-%m-%d %H:%M' <hash>`.
- **Hash** is the short hash of the commit the entry describes. Because a commit cannot contain its own hash, write the entry in a follow-up commit (`docs: changelog for abc1234`) or amend the hash in with the next change. A follow-up docs commit needs no entry of its own.
- **Tunables** lists every number changed in `scripts/stats.gd` or elsewhere as `NAME old → new`. Write "none" if nothing was retuned.
- **Revert** is the exact command that undoes this one commit. For a merge commit it is `git revert -m 1 <hash>`.
- Write "What" in plain words a player would understand.

See [../REVERTING.md](../REVERTING.md) for how to undo a commit, a group PR or a whole release.
