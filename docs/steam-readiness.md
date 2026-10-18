# Steam candidate readiness record

Agent: Codex-faisal / T5. Operational companion to `docs/steam.md` and the
CW-4 release plan in PR #33. All release gates below are **PENDING** until
the nominated candidate has evidence. This checklist does not approve publication.

## Build owner: Claude 2 final export

- [ ] Record candidate commit, clean checkout status, build OS, exact Godot
  binary and matching template versions/hashes, GodotSteam version and App/depot IDs.
- [ ] Run a full editor import and the README seeded bot match to a `RESULT`.
  Keep complete logs; zero process exit alone does not rule out script errors.
- [ ] Build with `tools/steam/build_steam.sh --app-id=<approved-id> <new-output>`.
  After PR #38, the output must not already exist. Relative paths are supported;
  choose a separate path per candidate. Keep the previous candidate intact.
- [ ] Spacewar 480 is a development test only and requires `--dev`. Do not
  use a development candidate as the shipping candidate.
- [ ] Retain import/export logs outside the builder's temporary directory
  before it is removed; current builder cleanup does not retain them automatically.
- [ ] Run `python tools/steam/check_depot.py <candidate-directory>` and save
  its JSON **outside** that directory. Require exit 0 and review every listed file.
  It checks nonempty EXE/DLL presence, rejects development App ID files and
  symlinks, and records sizes/SHA-256. It does not inspect embedded App IDs,
  executable validity, architecture or licence compliance.
- [ ] Assemble and review required third-party notices, including the actual
  engine, fonts, GodotSteam and asset provenance. The file checker does not clear rights.

## Tester: exact candidate, real Steam client

- [ ] Install and launch the exact candidate via the approved test configuration;
  confirm production App ID and client relaunch behavior.
- [ ] Exercise overlay open/close during offline and online play; verify input,
  pause and reconnect behavior without losing match state.
- [ ] Check all ten achievement API IDs from `scripts/steam.gd`; include local
  host and remote joiner capture/revive/finisher cases and exclude bot demos.
- [ ] Verify restart persistence and the approved Cloud configuration, including
  offline/conflicting-save behavior. Record actual files and platform scope.
- [ ] Complete the in-scope CW-4 gameplay/input/network/performance matrix.
  Local headless tests do not establish Steam Deck, web or physical-pad support.

## Owner: external release gates

- [ ] Confirm store/app configuration, ratings/content survey, approved copy,
  screenshots, price, supported platforms and current Steamworks review status.
- [ ] Review candidate hashes and remaining defects, then explicitly authorize
  the upload/publication action and destination. No checklist tick uploads anything.

For each row record PASS/FAIL/BLOCKED, tester/agent, timestamp, candidate SHA,
artifact hashes, exact steps and evidence links. A changed candidate requires
affected checks to be rerun. Missing evidence stays BLOCKED.

Offline checker regression command:
`python -m unittest discover -s tools/tests -p test_steam_depot.py -v`.
