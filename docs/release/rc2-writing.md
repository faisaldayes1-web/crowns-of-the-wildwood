---
agent: Codex-faisal
lane: T3 crowns-thornwood-writing
status: PROPOSED
source: f2364c15f8b8c2d0bf1d54b81b049ed33b82f399
---
# RC2 writing packet

Prepared 2026-10-17 by Codex-faisal. This is copy for review, not an RC2 build, release approval or Steamworks submission. It adds no gameplay changes. RC1 was built from ce6abfc; the inspected main includes its evidence via PR #34. No RC2 artifact or code delta beyond that evidence was identified.

## Store-page copy

### Short description

Steal a monarch. Defend your throne. Lead Elves or Humans through a colourful castle clash, switching classes, gathering supplies and rescuing allies. Play solo with bots or bring up to four players together in couch co-op or versus.

### About this game

The enemy monarch is waiting behind a castle gate. Getting in is only half the battle.

**Crowns of the Wildwood** is a colourful team-action game about daring raids and desperate returns. Choose the Elves or Humans, break into the opposing castle and carry their monarch back to your throne. Two captures win the match; if time runs out, the higher capture score wins. Ties head into sudden-death overtime.

**Find your place in the raid.** Take up a Knight's shield, a Ranger's bow, a Mage's spells, a Healer's support or an Engineer's tools. Switch roles at your castle's class stations and spend earned experience on upgrades and promotions.

**Keep the castle standing.** Gather wood, deliver it to the storehouse and help fund repairs, training and turrets. Revive a fallen ally or escort the crown carrier home. Winning takes more than chasing kills.

**Share the sofa.** Play alone alongside bots, or gather two to four local players for split-screen co-op or versus. Bots fill the remaining places in the fight.

**Fight through the seasons.** Raid the Wildwood, its moonlit variant and volcanic Ember Pass, then revisit Wildwood's layout in snowy Stonekeep Fortress and dusky Twilight Grove. Moonlit Wildwood is an account-level unlock.

### Editorial checks before publication

- Source basis: [README](../../README.md), [stats](../../scripts/stats.gd), [Steam setup](../steam.md). Verify every advertised feature on the final exported candidate.
- Five map choices are not five distinct layouts. Stonekeep and Twilight are seasonal Wildwood variants; Moonlit unlocks at account level 10.
- Default copy makes no online, cross-play, Steam Deck verification, frame-rate, release-date, price or system-requirement promise. Online room code exists, but host/join and Steam client qualification remain separate gates.
- Optional sentence, only after release-candidate online qualification: “Create a room and invite friends into a bot-filled castle battle online.” Do not imply local-plus-online combinations without testing them.
- Do not advertise ore gathering: ECONOMY.ore_on is false. Do not claim all unlocks are cosmetic: Rogue is a level-10 class unlock.
- Suggested discovery terms for owner review: team action, fantasy, local multiplayer, split screen, co-op, bots. These are editorial suggestions, not submitted platform categories.

## Achievement list and acceptance

Keep the ten existing API identifiers and display strings unchanged. This is an implementation-aligned list, not ten new achievements. Definitions are in [steam.gd](../../scripts/steam.gd); event hooks are in game.gd and unit.gd.

| API identifier | Display name | Player-facing description | Trigger to verify |
| --- | --- | --- | --- |
| FIRST_WIN | First Crown | Win a match. | Non-demo match ends with local player's team winning. |
| WIN_ELVES | Heart of the Wildwood | Win a match as the Elves. | Same winning-team check, Elves. |
| WIN_HUMANS | For the Realm | Win a match as the Humans. | Same winning-team check, Humans. |
| FIRST_CAPTURE | Crown Thief | Carry the enemy crown home. | Local player completes a capture; pickup alone must not count. |
| FIRST_REVIVE | Not Today | Revive a downed ally. | Local player completes a revive; starting or interrupting it must not count. |
| FIRST_FINISHER | No Mercy | Finish off a downed enemy. | Local player completes the finisher event. |
| ONLINE_MATCH | Better Together | Finish an online match. | Non-demo online match reaches its result; joining alone must not count. |
| LEVEL_5 | Seasoned | Reach account level 5. | Persistent account level reaches or exceeds 5. |
| LEVEL_10 | Veteran | Reach account level 10. | Persistent account level reaches or exceeds 10. |
| LEVEL_20 | Legend of the Wildwood | Reach account level 20. | Persistent account level reaches or exceeds 20. |

Account XP thresholds derived from stats.gd are 2,500 / 9,000 / 33,250 at levels 5 / 10 / 20. They are cumulative account XP, not in-match rank XP. No match-count or playtime estimate is justified by these thresholds alone.

Required Steam checks: fresh account, repeat event, restart persistence, loaded profile already above a threshold, loss/draw exclusions, bot-demo exclusion, Steam unavailable, host and joiner events, and couch-player attribution. A headless test cannot validate Steam because steam.gd intentionally skips initialization there. docs/steam.md explicitly flags that joiners may miss capture/revive/finisher awards. game.steam_unlock checks is_player, which alone is not proof that every network/couch action is attributed to the correct Steam account. Keep advertised Steam-achievement support gated on real-client evidence.

## Balance-sheet review

Static values below come from the pinned source. “Keep” is a proposal pending new candidate measurements, not a balance certification.

| Area | Current value | Review and proposed RC2 action |
| --- | --- | --- |
| Objective pacing | 2 captures; 600-second match; 120-second overtime | Keep initially. Report actual completed-match duration and overtime rate; do not promise a strict ten-minute maximum. |
| Faction movement | Elves 6.10; Humans 6.00 | Elf base speed advantage is about 1.67%. Preserve pending same-seed tests; role and carry modifiers also affect travel. |
| Faction recovery | Elves 1.00; Humans 1.22 regeneration multiplier | Human advantage is energy recovery, not 22% extra health or damage. Free basic attacks weaken any argument based only on regen-limited basic DPS. |
| Basic attacks / dodge | Basic attack cost 0; dodge cost 10, cooldown 4 seconds | README's control row still says 2-second recharge. Use source value 4 in candidate-facing instructions; runtime tuning is not changed here. |
| Carrier | Speed multiplier 0.8 | A 20% movement penalty before other modifiers; measure escort success and return times, not just kill/death ratios. |
| Downed / revive | 15 seconds downed; standard revive 4 seconds, Healer 1.5; returns 2 of 4 hearts | Keep. Measure saves under pressure; overtime bypasses the downed phase. A revive restores the levels lost on going down. |
| Gate / rebuild | 200 gate hits; 40-second rebuild timer; siege radius 9 | Separate passive rebuild, paid raise and repair when logging. Route geometry can bias first gate break even with equal stats. |
| Gathering | 2 seconds per wood; capacity 4; 45-second resource regrowth | Full load needs 8 seconds of uninterrupted gathering, excluding travel/deposit. Keep ore disabled. |
| Training | 12 wood, available after 300 match seconds | Three full loads, at least 24 gathering seconds before travel/competition. A four-minute match may never expose this feature. |
| Base spending | Repair 3 wood for 35 hits; raise 6 for 100; turret 3; turret level +1 costs 2; turret repair 1 | One 4-wood load cannot buy training or raise a gate. Log spending and reserve starvation separately from combat strength. |
| Support XP | 5 per delivered wood; 12 per build action | Full load grants 20 XP. Check repeated repair/build loops and whether gatherers reach useful ranks without displacing raids. |
| Match rewards | Gold: win 300, draw 250, loss 200 | Winning adds 100 gold over a loss. Distinguish persistent cosmetic-store gold from team wood and in-match XP. |

Historical evidence: [patch 8](../balance/patch-8.md) reports 48 matches before and after the Elf speed change on a prior beta: 18–29 with one draw became 24–24; captures 38/54 became 42/46; overtimes 3/48 became 12/48. These are recorded author results, not fresh RC2 runs. They cover Wildwood and Ember Pass, not all five choices. Even 24/48 is a small sample, not proof of faction parity.

Proposed next measurement: pin candidate SHA, Godot version, bot difficulty and team size; run the same twelve seeds at 4v4 on all five choices (60 completed matches), retaining draws. Add 3v3/5v5 on the two distinct layouts if those sizes are in release scope. Record wins, captures, first gate broken, duration, overtime, per-role damage/healing/revives and economy spending. Compare identical seeds before and after any single-variable change. Investigate repeated faction objective bias, 25%+ overtime or stuck raids; these are review triggers, not automatic nerfs. Human playtests must check controller usability and whether Knight/Engineer contributions are undercounted by K/D.

## Draft RC2 patch notes

### Player-facing candidate text

**A crown worth carrying home**

- Fight in snowy Stonekeep Fortress and dusky Twilight Grove: two seasonal versions of the Wildwood battlefield.
- Enjoy drifting pollen, embers, snow and twilight motes, with brighter lighting in Moonlit Wildwood.
- Scenery batching, model warm-up and split-screen rendering changes aim to reduce rendering work and first-use hitches.

**Balance carried into this candidate**

- Elves retain the patch-8 base movement speed of 6.10.
- Wood remains the active base resource. Delivering supplies and maintaining your base contribute experience.

### Publication boundary

The bullets describe work already present in the inspected baseline, documented in [int1](../changelog/int1-maps-perf.md), [patch 8](../balance/patch-8.md) and stats.gd. They are suitable as a cumulative preview for players who have not seen that work. They are **not changes from RC1 to RC2**. If RC2 is announced specifically as an update from RC1, replace this section with the verified RC1-to-RC2 code/build delta; the evidence-only PR #34 does not justify a new-fixes list.

The [RC1 handoff](../agents/Handoffs/2026-10-16%20claude-faisallaptop%20rc1.md) records a local Windows build and author-run map checks. It does not qualify Steam, online host/join, web, physical controllers or another PC. Before publishing these notes, add the actual RC2 source/build ID, tested platforms, confirmed fixes since RC1 and remaining known issues. Avoid “lag-free”, “fully balanced” and universal FPS promises.

## Handoff

Agent: Codex-faisal. Dedicated T3 writing scope; crowns #29/#33 untouched. Static source review, existing achievement-string cross-check and arithmetic review performed. Runtime validation is recorded in the accompanying T3 handoff, with engine version and limits. Reviewer requested: claude-faisallaptop reviewer lane. Owner decides wording and publication; this PR publishes nothing. Meshy: 0 credits. PixelLab: 0 credits.
