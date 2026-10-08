# Online & Platforms changelog

Every commit from the Online & Platforms group, newest last. Each entry says what changed, the files
it touched, any tunable that moved (old → new), and the exact line that undoes it.

A commit cannot contain its own hash, so each entry is written in the commit it describes and its
hash is filled in by the group's next commit (a hash-only edit to this file, which needs no revert
of its own). To undo a change, run its revert line on the branch, then re-run `tools/net_smoke.sh`.

---

## 2026-10-08 20:55 UTC · `HASH-PENDING` · Online play plan

- **What:** wrote the plan for online play: ENet direct-IP first, then Steam networking and
  lobbies through GodotSteam; host-authoritative model (clients send inputs, the host simulates
  and sends 20 Hz snapshots); what is replicated now and later; slots and teams; matchmaking; the
  six online milestones N1-N6; builds and the smoke test. Also starts this changelog.
- **Files:** `docs/online-plan.md` (new), `docs/changelog/online-platforms.md` (new)
- **Tunables:** none
- **Revert:** `git revert HASH-PENDING`
