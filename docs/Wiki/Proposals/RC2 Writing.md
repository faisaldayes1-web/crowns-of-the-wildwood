# Crowns RC2 writing pack

Agent: Codex-faisal
Status: PROPOSED. RC2 editorial draft, not a released version, candidate build, or platform certification.
Baseline: main tree f2364c15f8b8c2d0bf1d54b81b049ed33b82f399; README, scripts/stats.gd, scripts/steam.gd, docs/steam.md, docs/balance/patch-8.md and RC1 handoff. Scope is new writing only; PRs #29/#33 remain with Codex-faisal2.

## Store copy

Short description:

Steal a monarch. Rally your team. Bring the crown home. Fight for Elves or Humans in a colorful castle-raiding brawler, switching classes, defending your gates and turning a desperate rescue into the winning capture.

Long description:

The royal family is having a very bad afternoon. Crowns of the Wildwood turns a bright storybook battlefield into a scramble of raids, rescues and last-second escapes. Break into the enemy castle, grab their monarch and carry them back to your throne while your team keeps the road home open.

Choose your job in the chaos. Hold the line as a Knight, pick your shots as a Ranger, make space with magic, rescue allies as a Healer or support the siege as an Engineer. Gather wood for your team, strengthen your defenses and decide when to stop protecting your castle and risk everything on a raid.

A fallen teammate can still be saved. A broken gate can become an opening. A crown carrier needs friends more than another duel. First to two captures wins; tied matches can go into sudden-death overtime.

Build your hero's look with colors, banners and cosmetic equipment. Take on bots or gather friends for local split-screen battles. Each match asks a simple question: who is bringing the monarch home?

Candidate feature bullets, publish only after the release checklist verifies them:
- Team castle raids as Elves or Humans, with class switching, defense and support roles.
- Local split-screen for up to four players, with bots filling the battlefield.
- Five selectable map entries: Wildwood, Moonlit Wildwood, Ember Pass, Stonekeep Fortress and Twilight Grove. Stonekeep/Twilight are seasonal Wildwood-layout variants; do not advertise five unique layouts.
- Match progression and persistent hero customization.

Online addendum, HOLD until RC2 host/join and service checks pass: “Create a room, share its code and join friends for online castle raids.” Do not imply local/online mixed play, cross-platform certification, dedicated servers or guaranteed relay availability. Steam achievements, Cloud, Deck support, supported OS, pricing, date and minimum specs remain release metadata requiring evidence; none is promised by this draft. Keep platform checkboxes separate from copy.

Trailer/storyboard copy: 0–5s “Their monarch. Your throne.” over a real capture approach; 5–12s “Pick a role. Make a plan.” over class selection and defense; 12–20s “Save the team. Steal the win.” over a revive and escorted return; end card title only until the release date is approved. Capture genuine candidate footage; don't use draft art as gameplay.

## Achievement list and acceptance

These ten existing API IDs are retained verbatim from scripts/steam.gd. No new unlock is added here. Trigger descriptions below are verification requirements, not proof that every call site meets them.

| API ID | Display name | Player description | Required positive case |
|---|---|---|---|
| FIRST_WIN | First Crown | Win a match. | Completed local-player victory, not a bot demo |
| WIN_ELVES | Heart of the Wildwood | Win a match as the Elves. | Victory with local faction Elves |
| WIN_HUMANS | For the Realm | Win a match as the Humans. | Victory with local faction Humans |
| FIRST_CAPTURE | Crown Thief | Carry the enemy crown home. | Local actor credited with capture, not nearby teammate |
| FIRST_REVIVE | Not Today | Revive a downed ally. | Completed local revive, not interrupted hold |
| FIRST_FINISHER | No Mercy | Finish off a downed enemy. | Completed local finisher, not merely entering downed state |
| ONLINE_MATCH | Better Together | Finish an online match. | Finish authoritative match while online, not join or disconnect |
| LEVEL_5 | Seasoned | Reach account level 5. | Persistent account level >=5 |
| LEVEL_10 | Veteran | Reach account level 10. | Persistent account level >=10 |
| LEVEL_20 | Legend of the Wildwood | Reach account level 20. | Persistent account level >=20 |

For every ID: check first unlock, repeat event (no duplicate award), restart persistence, offline/non-Steam no-op, and bot-demo exclusion. For capture/revive/finisher, test host and joiner separately: docs/steam.md explicitly warns the joiner may miss host-owned events. Split-screen must not award another seat's event to the signed-in account without an explicit policy. Test level jumps across multiple thresholds and migrated profiles. Steamworks API names/icons and a real app/client test remain pending; a static dictionary match is not achievement readiness. No achievement requires a paid cosmetic or deliberately throwing a match.

## Balance-sheet review

All values are source facts at the baseline unless marked proposed. No tuning edits or fresh simulations were performed.

| System | Source value | Review and RC2 action |
|---|---|---|
| Win/clock | 2 captures; 600s regulation; 120s overtime | Retain. Historical patch-8 overtime rose 3/48→12/48: measure match duration before shortening it. |
| Factions | Elves speed 6.1, regen 1.0; Humans speed 6.0, regen 1.22 | Elves move ~1.67% faster; Humans have 22% stronger regen multiplier. Do not equate those unlike metrics or nerf from K/D alone. |
| Carry | speed multiplier .8 | Inspect route exposure and escort success per map, not only carrier travel speed. |
| Health/revive | 4 hearts; 15s downed; 2s grace; revive 4s/1.8m, Healer 1.5s/3m; revive gives 2 hearts | Healer channel is 2.67× faster. Measure completed/interrupted revives and contested rescues, including overtime's no-downed rule. |
| Door | 200 hits; repair 3 wood→35 hits; rebuild 6 wood→100 hits subject to siege restriction | Full missing 200 hits needs 6 repairs costing 18 wood if partial final repair is allowed. This is a numeric ceiling, not a promise of legal repair during siege. |
| Gather | 2s/unit, carry 4; wood only; delivery 5 XP/unit | Full load is >=8s harvesting plus travel, worth 20 XP. Twelve-wood training needs at least three trips /24s harvesting before travel. |
| Training | opens 300s; costs 12 wood | Keep separate from in-match earned XP and persistent account XP. Do not re-enable ore using stale fields. |
| Base turret | build 3 wood; upgrade 2; fix 1 | Compare repair/rebuild/training opportunity cost; confirm XP is awarded only for successful, useful transactions. |
| Build XP | 12 per successful build/repair action | Audit full-health no-op repair and repeated click/reload for farming; no exploit is asserted without reproduction. |
| Account XP | next level costs 400+150×(level−1), max50 | Level5 costs 2500 XP total; level10 costs 9000; level20 costs 33250. These exclude changing match XP rates. |
| Match bonus XP | win300 / draw150 / loss100 | Reward completion while preserving meaningful victory value; measure quit farming separately. |
| Gold/shards | win300/25; draw250/20; loss200/15 | Cosmetic reward gap is 100 gold/10 shards win vs loss. Avoid claims about purchase time without the selected item's price and actual match duration. |

Historical evidence, not new RC2 results: patch8 reports 48 matches before and after on Wildwood/Ember, changing Elf speed 6.05→6.10; wins moved 18–29 plus one draw to24–24. A 24/48 sample is consistent with a broad roughly36–64% interval, not proof of perfect balance. Seasonal variants, human decision making and joiner effects are outside that experiment. RC1's six-minute bots also do not prove a full ten-minute game/overtime on all maps.

Proposed qualification: use identical paired seeds for baseline/candidate, both factions and 3v3/4v4/5v5; log map, roles, winner/draw, duration, captures, first door break, revive/finisher counts, wood spent, XP and reward totals. Start with48 paired matches per materially changed layout, expand if results remain ambiguous. Review >60% faction win share, >25% overtime, severe gate-access asymmetry or runaway resource farming as investigation flags, not automatic balance failures. Add at least two complete human sessions for each local-player count and separate online host/join sessions. Do not change multiple tunables in the same comparison.

## RC2 patch-note draft

Publication state: HOLD. No RC2 build or delta has been supplied. The following is candidate-era context already present in baseline/RC1, NOT newly fixed by this writing PR:

“Crowns of the Wildwood brings together castle raids, class progression, hero customization and local split-screen in a single candidate. The current map selection includes Stonekeep Fortress and Twilight Grove, seasonal variations on the Wildwood layout. Shared scene batching reduces duplicated render work.”

RC2 delta section to fill after engine work:
- Fix: [observed defect] → [verified behavior], linked implementation commit and regression evidence.
- Balance: [old → new number], scope and paired-run result; omit this section if no tuning changed.
- Presentation: [verified visual/audio change], exact candidate captures.
- Known issues: [remaining reproducible issue, affected mode, workaround if verified].

Do not publish bracketed placeholders. No claim of fixed online joiner achievements, finalized Ember PR#4 castles, stable60fps in four-player play, or Steam-ready release is supported. RC1 handoff reports four-player45–101fps with median~68 on its laptop and explicitly excludes Steam/web, another-machine install, real pads and online host/join. These remain attributed historical results.

## Handoff and validation

Codex-faisal cross-checked ten achievement IDs against source, economy constants, level-cost arithmetic and source-backed feature language. Required Godot import and bot match NOT RUN: no Godot executable on PATH and no complete current checkout prepared in this session. Keep this PR draft until required runtime checks are supplied or the owner accepts a docs-only exception. No platform upload, publication, source tuning, asset change or paid generation. Meshy0; PixelLab0.

Next: Claude2 exact-head editorial/source review; attach the actual RC2 source/build hash and new-minus-RC1 diff; fill the patch delta from that evidence; complete required import/bot checks and platform acceptance; Faisal approves final copy. Handed-over #29/#33 untouched.
