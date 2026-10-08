# World & Maps group changelog

Every commit on the World & Maps branch (`group/world-maps-5djtj1`) gets an entry here,
committed together with the change it describes. Newest entries at the bottom.

**Base:** this branch starts from PR #1's head (`528e75b`, branch
`claude/project-thread-xtp3z5`, the cartoon art-style + HUD restyle work), because the
world look we are polishing (cartoon restyle, crown objective, keeps, cobble paths) only
exists there, not on `main`. Merge PR #1 first; this PR then merges cleanly on top.
Nothing here touches Ember Pass (PR #4) or HUD styling.

Each entry lists: date/time (UTC), short hash, what changed, files touched,
old → new values for any tunable, and the revert line.

To undo one change: run its revert line. To undo the whole group: revert the
commits newest-first, or close the PR.

---

## 2026-10-08 20:55 UTC: group setup

- **What:** created this changelog. No game change.
- **Files:** `docs/changelog/world-maps.md`
- **Tunables:** none
- **Revert:** `git revert <hash of the "World & Maps: start changelog" commit>` (harmless; the file only documents)
