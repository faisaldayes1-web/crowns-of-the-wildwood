PROPOSED — FOR PR REVIEW. Agent: Codex-faisal2. 2026-10-18. Faisal authorized normal release-copy PR updates and source-issue notes in this existing repository via the hub relay in this chat. This authorization does not publish a storefront, build, press kit or game release.

Source snapshot: crowns-of-the-wildwood main f2364c15f8b8c2d0bf1d54b81b049ed33b82f399. Source issue #32.

# Crowns of the Wildwood — candidate patch notes

Version/date: UNASSIGNED. PROPOSED RC notes for a future owner-approved release, not a claim that a release or tag exists.

## Player-facing draft

### More places to battle

- Added Stonekeep Fortress and Twilight Grove as winter and dusk variations built on the Wildwood layout.
- Updated the map selection cards and seasonal minimap presentation for these maps.

### Atmosphere and presentation

- Added drifting ambient particles across the map themes.
- Brightened the moon in Moonlit Wildwood.
- Updated seasonal scenery, lighting and ground presentation.

### Loading and rendering work

- Added static batching and loading-screen model/shader warm-up work.
- Reduced selected split-screen HUD/shadow and primitive rendering costs.
- Avoided rebuilding ambient particle presentation when the map theme has not changed.

## Internal provenance and limits

These bullets summarize changes reported in merged #31 and its handoff at ce6abfc; #34 adds RC1 build/evidence rather than another gameplay feature. New maps share Wildwood routes/colliders, so do not market them as wholly different layouts. The old central changelog still contains historical pending-PR labels; merge ancestry and int1 handoff govern this draft's scope.

Owner-reported import, combat selftest, map-switch and bot-match evidence is historical and versioned. Online new-map checks, iPad/web export, real controllers and cold-cache behavior remain unverified in the cited integration handoff. Four-player frame tails remain a known concern. Do not turn rendering work into a “lag eliminated” or minimum-FPS claim. Historical #4 castle changes are not silently included. #4 is closed at the later integration checkpoint; closure alone does not establish that those changes were integrated. Assign a final version, build identity and known-issues list only after candidate acceptance. No tag, storefront submission or game release performed here.
