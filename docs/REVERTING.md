# Reverting changes

Every change to Crowns of the Wildwood is recorded twice: in a group log under [changelog/](changelog/) (one entry per commit) and, once it ships, in [CHANGELOG.md](CHANGELOG.md) (one entry per release, with its tag). Each entry carries the exact command that undoes it.

`git revert` never deletes history. It adds a new commit that does the opposite of the old one, so a revert can itself be reverted if you change your mind.

You can also just ask Claude in the project: "revert the Venom Fang change" or "go back to v0.3.0" is enough. The steps below are what Claude (or you) runs.

## Undo one commit

1. Find the commit in the group log or with `git log --oneline`.
2. Run the revert line from its entry:

   ```sh
   git checkout main
   git pull
   git revert abc1234
   git push
   ```

3. Add an entry for the revert to the group log and CHANGELOG.md.

If git reports a conflict, a later commit changed the same lines. Fix the files it lists, `git add` them, then `git revert --continue`.

## Undo a whole group PR (a release)

Every PR is merged with a merge commit (never squashed or rebased), so one merge commit holds the whole PR. Revert it with `-m 1`, which means "keep main's side":

```sh
git checkout main
git pull
git revert -m 1 <merge-hash>
git push
```

The merge hash is listed in CHANGELOG.md under that release. Note that git then treats those commits as already merged: to bring the PR back later, revert the revert (`git revert <revert-hash>`) rather than merging the branch again.

## Go back to a release tag

Each release is tagged (`v0.3.0`, `v0.3.1`, ...) and also marked by a `release/v0.3.0`-style branch on the same commit. If a tag is missing, use the `release/` branch name instead.

- **Just look at or play an old version** without changing anything:

  ```sh
  git checkout v0.3.0      # look around, run it in Godot
  git checkout main        # come back
  ```

- **Make main match an old release again**, keeping all history:

  ```sh
  git checkout main
  git pull
  git revert --no-edit v0.3.0..HEAD   # undoes every commit after v0.3.0, newest first
  git push
  ```

  If that range holds merge commits, revert each release's merge commit instead, newest first, with `git revert -m 1 <merge-hash>` (the hashes are in CHANGELOG.md).

- **Start a fix from an old release** without touching main: `git checkout -b hotfix/v0.3.0 v0.3.0`.

Never use `git reset --hard` plus a force push on `main`: it erases history other groups' branches are built on.
