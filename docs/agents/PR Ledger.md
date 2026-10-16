# CW-1 PR backlog ledger

Agent: Codex-faisal
Snapshot: 2026-10-16 (America/Los_Angeles)
Status: PROPOSED integration advice; Faisal approves all merges and supersedence closures.

Issue: [#25](https://github.com/faisaldayes1-web/crowns-of-the-wildwood/issues/25). Its scope-update comment reduces the old Task Board's 13-PR list to **#4, #6, #8, #9, #13, #17**. The supplied task dispatch authorizes `Codex-faisal/cw-1-pr-ledger` rather than the original `chatgpt/` branch. Claim `73e07979ac9656ee758fdbdc674a01cd28bab57e` was inspected before edits. Current main and claim-branch boards show no competing active CW-1 worker; CW-2 remains claude-faisallaptop's task.

## Decision summary

Do not merge these as six independent features based on their titles. All six share older menu/Ember work, and the four group/platform branches contain large integrated releases. No pair of the six heads is a strict ancestor of the other. That does **not** mean every branch still adds distinct behavior: cherry-picks and merge-only tips matter.

The two principal candidates are **#13 and #8**: their tip trees differ in only **25 paths**, of which just four are scripts (`economy.gd`, `stats.gd`, `store.gd`, `store_gear.gd`). Preserve #13's gathering/base-work XP and #8's patch-8 balance plus 16-item Wildwood collection together. Do not choose an entire side of `stats.gd` or `store.gd` merely to clear conflicts.

**#4 is not wholly superseded by #17.** It has three additional Ember visual commits touching `scripts/game.gd` and `assets/shaders/lava.gdshader`; the later branches also lack those exact commits. Preserve/reconcile their intent or explicitly ask Faisal to retire that appearance. A clean textual merge elsewhere is not visual or gameplay acceptance.

## Exact reviewed heads

The base below is the merge base with the recorded main, not a claim that the feature branch includes today's coordination commits. Changed-path counts use `git diff --name-only main...head`; rename detection uses this checkout's Git defaults. The complete path-to-PR index is at the end. GitHub CLI's embedded `files` arrays were incomplete for these large PRs, so they were **not** used as the ledger inventory.

Recorded main: `3baa2511745cd7c6e5ce2a5f7d3e33497d53554e`.

| PR | Head branch | Exact head | Base with main | Changed paths |
|---|---|---|---|---:|
| [#4](https://github.com/faisaldayes1-web/crowns-of-the-wildwood/pull/4) | `claude/project-thread-loxmcs` | `690a07e28a0c940c3e974ad97b9525820463acfc` | `df418fdca0e49d403cbc276b349878a2f9093e2f` | 125 |
| [#6](https://github.com/faisaldayes1-web/crowns-of-the-wildwood/pull/6) | `group/online-platforms-osscle` | `e5389cb4d90b60444c5bbfecc9bb8094704ec3d4` | `a7f4f681b21cc797174597f98ac269d1764cdfe9` | 475 |
| [#8](https://github.com/faisaldayes1-web/crowns-of-the-wildwood/pull/8) | `group/combat-balance-pjmygt` | `0c4a5b61c2083b72cd2c1cd17c2c1252b2b89e4a` | `a7f4f681b21cc797174597f98ac269d1764cdfe9` | 820 |
| [#9](https://github.com/faisaldayes1-web/crowns-of-the-wildwood/pull/9) | `claude/ipad-web-build-c1oo3k` | `ce8b67ad585ed2214631265ec84fdf933cf3df06` | `a7f4f681b21cc797174597f98ac269d1764cdfe9` | 606 |
| [#13](https://github.com/faisaldayes1-web/crowns-of-the-wildwood/pull/13) | `group/economy-whmjnc` | `1f1cd36bde68e9ab58a56eb72608cbfc34d3e636` | `a7f4f681b21cc797174597f98ac269d1764cdfe9` | 803 |
| [#17](https://github.com/faisaldayes1-web/crowns-of-the-wildwood/pull/17) | `claude/project-thread-hu6d1n` | `c6ce655c2b66e0f188aa58a9b95e9d09ad3f8c53` | `a7f4f681b21cc797174597f98ac269d1764cdfe9` | 141 |

## What each PR actually carries

### #4 — Ember Pass and late castle/lava appearance

Adds the volcano walkability/routes, Fire Objective and temporary Fire forms; menu map selection, map pins, and associated art ride with earlier menu/art merges. Primary code: `scripts/volcano.gd`, `scripts/game.gd`, `scripts/unit.gd`, `scripts/stats.gd`, `scripts/menu.gd`, `scripts/hud.gd`; shader: `assets/shaders/lava.gdshader`. Its late, still-distinct work is the three commits listed below. High conflict risk with every later world renderer, especially the game builder and lava shader. Retain pending visual adjudication; no unconditional close recommendation.

### #6 — Online/platform integration, not just a plan

Carries ENet host/join, authoritative snapshots, online UI and smoke testing (`scripts/net.gd`, `project.godot`, `scripts/game.gd`, `scripts/unit.gd`, `scripts/hud.gd`, `tools/net_smoke.sh`, `docs/online-plan.md`, platform changelog), plus substantial shared UI/art/economy history. Tip `e5389cb` merges `5423659` (deterministic test arrow) and `82a3d77` (release/UI integration). Against #13, the **only exclusive commit is that merge tip**; both its parents are already present. A pairwise merge with #13 conflicts only in `docs/changelog/online-platforms.md`, not runtime code. Against #8, `tests/combat_test.gd` also conflicts: preserve the newer stuck/impact checks and the downed-bot guard. Its PR body's desktop export checkbox is still unchecked; an old smoke-test claim does not certify the integrated candidate or feature-complete online play.

### #8 — Broad integrated build plus latest balance and collection

Contains combat/balance changes, imported visual overhaul, menu, online, economy, input, collision and store work, not merely the Venom Fang fix in its title. Key runtime surfaces include `scripts/game.gd`, `unit.gd`, `hud.gd`, `stats.gd`, `economy.gd`, `store.gd`, `store_gear.gd`, `net.gd`, visual/style code, and their art/tests/tools. Latest gameplay commit `08e766f9b512c4d364f50b1cef51a87e8c74941f` raises Elf speed 6.05 to 6.1; tip `0c4a5b6` records it. The integrated Wildwood collection adds 16 cosmetics and `STORE_NEW` markers. Keep its cosmetic tables, images, gear rendering and store UI together. #13's faster wood/XP delta is absent here. No supersedence closure recommended.

### #9 — Web/iPad fixes with shared integrated content

Includes web rendering, first-run letterboxing/quality caps, batching, touch and export configuration, plus UI/art and other shared branches. Primary surfaces: `project.godot`, `export_presets.cfg`, `scripts/game.gd`, `menu.gd`, `touch.gd`, `hud.gd` and render helpers. Its two commits not in #13 are `1c719b7` (latch a click between frames) and `ce8b67a` (changelog). `git cherry #13 #9` marks **both patch-equivalent**: #13 carries `73ac585` for the code and `680255a` for its log. Nevertheless a direct pairwise merge conflicts in `scripts/game.gd`; do not reintroduce an older `_input`/menu loop over later touch fixes. Candidate closure is conditional on integrated web/device validation, not strict head ancestry.

### #13 — Economy and later shared integration

Adds gathering, training, door repair and turret spending through `scripts/economy.gd`, `stats.gd`, `game.gd`, `unit.gd`, `hud.gd`, related art and tests. The title says wood and ore, but the reviewed code sets `ore_on: false`: current gameplay is wood-only. Latest gameplay commit `54d3557` changes gather time 2.6→2.0 s, carry capacity 3→4, training wood 14→12, adds 5 XP per delivered resource and 12 XP per base-work action, and attributes purchased turret damage/knockdowns to its builder. Tip `1f1cd36` logs it. Keep those changes with #8's newer balance/cosmetics. Relative to #8, only four script files differ; divergent commit counts overstate the actual content gap because shared work was cherry-picked. No supersedence closure recommended.

### #17 — Earlier combined menu/Ember/summary candidate

Contains menu flow, face/customization, Ember Pass, touch/web setup and the summary/scoreboard work, much of which is already main or present in the group branches. Main's v0.3.1 already includes summary/scoreboard release history, so its title is not a list of wholly new changes against current main. Its only exclusive commit relative to each of #6/#8/#9/#13 is `c6ce655`, a merge from main. Read-only merge-tree of #8 with #17 succeeds and yields **exactly #8's tree**, proving no extra file content in that combination. Treat as a conditional supersedence closure after the selected replacement passes CW-2; it does not absorb #4's three late commits.

## #4 versus #17: same lineage, divergent later work

Their merge base is `2bbe88ffa87fcb24c5936659881dd7910397992c`, with 3 commits only on #4 and 31 only on #17. This is shared history with later divergent work, not evidence of two independent rebuilds. #17 incorporates older Ember commits through the combined-build merges, then web/summary/main changes. The three #4-only commits are:

| Commit | Distinct intent |
|---|---|
| `13c6327` | Blackish dark-red lava crust with faint red smoulder |
| `bff5758` | Stone Elf Ember castle, extra wall torches and long courtyard runner |
| `690a07e` | Grey-green Elf stone, lighter Human stone and rampart/tower flames |

The two touched paths are `assets/shaders/lava.gdshader` and `scripts/game.gd`. The latter introduces `ember_castles`, modifies `_ashlar`, `_add_wall`, `_add_tower`, `_build_castle`, and toggles/reset material state in `_build_volcano`. Direct #4/#17 conflict: lava shader. Direct #4/#8 and #4/#13 conflicts: lava shader **and** game builder. Preserve the later style profile, batching, collision fixes, and correct reset when switching away from Ember Pass; decide the appearance with screenshots. Never replace the whole modern `game.gd` with #4's older copy.

## Pairwise history and conflicts

Every row was checked with exact fetched heads using `git rev-list --left-right --count` and `git merge-tree --write-tree --name-only`. The latter only creates temporary Git objects: no branch, index, or working-tree integration was performed. A pairwise clean result does not certify a cumulative six-way merge or semantic correctness. Shared-path counts are intersections of main-relative inventories, not conflict counts. Multi-base histories exist; merge-tree resolves its virtual base automatically. Do not infer the entire graph from one merge-base hash.

| Pair (A/B) | Commits only A / only B | Shared changed paths | Predicted textual conflicts |
|---|---:|---:|---|

| #4 / #6 | 3 / 408 | 125 | `assets/shaders/lava.gdshader`; `scripts/game.gd` |
| #4 / #8 | 3 / 552 | 125 | `assets/shaders/lava.gdshader`; `scripts/game.gd` |
| #4 / #9 | 3 / 449 | 125 | `assets/shaders/lava.gdshader`; `scripts/game.gd` |
| #4 / #13 | 3 / 525 | 125 | `assets/shaders/lava.gdshader`; `scripts/game.gd` |
| #4 / #17 | 3 / 31 | 125 | `assets/shaders/lava.gdshader` |
| #6 / #8 | 12 / 156 | 475 | `docs/changelog/integration-release.md`; `docs/changelog/online-platforms.md`; `tests/combat_test.gd` |
| #6 / #9 | 1 / 42 | 475 | `docs/changelog/online-platforms.md` |
| #6 / #13 | 1 / 118 | 475 | `docs/changelog/online-platforms.md` |
| #6 / #17 | 378 / 1 | 141 | None (textual only) |
| #8 / #9 | 130 / 27 | 606 | `docs/changelog/integration-release.md`; `scripts/game.gd` |
| #8 / #13 | 124 / 97 | 803 | `docs/changelog/combat-balance.md`; `docs/changelog/economy.md`; `docs/changelog/integration-release.md`; `docs/changelog/store.md`; `scripts/stats.gd`; `scripts/store.gd` |
| #8 / #17 | 522 / 1 | 141 | None (textual only) |
| #9 / #13 | 2 / 78 | 606 | `scripts/game.gd` |
| #9 / #17 | 419 / 1 | 141 | None (textual only) |
| #13 / #17 | 495 / 1 | 141 | None (textual only) |

### Resolution priorities

- **#13/#8:** retain #8's Elf speed 6.1, Wildwood collection arrays/`STORE_NEW`, matching 16 images and `store_gear.gd`; retain #13's faster wood loop, XP constants, delivery/build XP and turret ownership. Reconcile `store.gd` without dropping either collection or banner behavior. Append/preserve changelog evidence from both histories. There are five best merge bases for this pair; use actual three-way integration, not a hand-selected historical base.
- **#9 into later branches:** preserve the already-applied click latch once, plus touch tap suppression, panel close handling and later input fixes. Exercise press/release within a slow frame and touch/mouse emulation; duplicate handlers are a semantic risk even if a conflict is resolved.
- **#6:** keep authoritative networking and deterministic smoke behavior. Preserve the expanded combat test suite and its downed-unit guard. Resolve changelogs as history, not by dropping an agent's evidence.
- **#4 last:** isolate its two-path visual intent from the stale surrounding implementation. Test all map switches to detect lingering `ember_castles`/soot/texture state, and check additional flame cost in profiling.
- Broad shared surfaces are `game.gd`, `unit.gd`, `hud.gd`, `stats.gd`, menu/render/export configuration and binary art. Batching, collision, online state and input can regress without a Git conflict. Existing binary assets and export tooling in these feature histories were reviewed as scope evidence; this documentation task changes none of them and authorizes no publishing or dependency change.

## PROPOSED integration order for CW-2

For the Task Board's **merge-commit, no-rebase** workflow and a complete audit trail, claude-faisallaptop should start `claude-faisallaptop/int1` from freshly fetched main and process **#17 → #6 → #9 → #13 → #8 → #4** at the recorded heads, refreshing this assessment if any head moves.

1. #17 establishes the older common menu/Ember baseline; verify existing summary behavior is retained.
2. #6 brings the online/release lineage; validate import and host/join before adding later branches.
3. #9 brings the later web/UI lineage; retain deterministic online smoke behavior and exercise menu input.
4. #13 adds later integration and final economy changes. Resolve the duplicated #9 click patch by preserving one current implementation.
5. #8 layers the latest combat balance and collection. Resolve the explicit #13/#8 conflicts using the priorities above; run economy, combat, store, input and online regression tests.
6. #4 is the deliberate final visual reconciliation, **not** an automatic clean merge. Integrate its three commits' intent into the modern world builder/shader, with owner review of appearance. If Faisal explicitly retires that appearance, omit #4 and document that decision rather than claiming it was already included.

This order is a review plan, not a tested cumulative merge. No integration branch was built in CW-1. A lower-churn alternative, if Faisal accepts closing redundant wrappers, is **#13 → #8 → reconcile #4**, while closing #17/#6/#9 only after the conditions below. It avoids re-merging already-carried code but does not preserve all wrapper heads as ancestors. CW-2 must choose and record one approach; do not silently mix merge and replacement policies.

## Supersedence / closure recommendations (Faisal decides)

| PR | Recommendation and evidence |
|---|---|
| #4 | Keep open until its three unique visual commits are reconciled or explicitly retired. Not superseded merely by the presence of Ember Pass in #17. |
| #6 | Candidate to close as replaced by integrated #13/#8 after networking/smoke verification. #13 lacks only its merge wrapper; pairwise conflict is changelog-only. Do not describe the exact head as an ancestor. |
| #8 | Keep: latest balance/cosmetics distinct from #13. |
| #9 | Candidate to close after replacement's web/iPad input/render validation. Both exclusive commits are patch-equivalent in #13, but direct merge still conflicts in game input. |
| #13 | Keep: final wood-loop/XP changes distinct from #8. |
| #17 | Candidate to close after #8-containing integration is accepted; merging #17 with #8 produces #8's identical tree. |

Previously closed #2/#7/#10/#12/#15/#18 remain closed; issue #25's scope-update comment reports them as redundant and records #2/#7/#12/#15 in the four large branches and #10/#18 in #8. That is attributed prior coordination evidence, not a new exact-head re-audit of those six closed PRs. #2 versus #17 is older menu lineage carried forward; #10 versus #18 is prior visual-overhaul lineage carried into #8. Do not reopen or merge those closed wrappers from the stale Task Board list.

## Verification and next gate

Codex-faisal performed a fresh full clone, inspected AGENTS.md, the first 40 Memory Brief lines, both boards, all inbox files and issue #25's full discussion; read exact PR metadata; fetched all six head refs; verified hashes; compared histories, patch equivalence, key source diffs and full path inventories; and ran all 15 pairwise read-only merge-tree checks. These establish repository facts and textual conflict predictions only. Source histories and PR descriptions' historical test claims are not newly executed tests.

No Godot executable was found on PATH or in the searched Program Files tree. Godot import, bot matches, render screenshots, browser/iPad tests, online smoke and performance measurements were **not run by Codex-faisal**. No claim is made that Godot is absent everywhere on the machine. The repository's engine test gate remains outstanding for CW-2; this docs-only PR is not game acceptance. No game files/assets/dependencies changed, no branch merges, deletion, builds published or paid generation. Meshy/PixelLab spent: **0 credits**.

claude-faisallaptop: after integration, run `godot --headless --path . --editor --import --quit` and retain an error-free import log. For each current map index **0 Wildwood, 1 Moonlit Wildwood, 2 Ember Pass**, run at least six simulated minutes of seeded bots (for example `godot --headless --path . --fixed-fps 60 --quit-after 21600 -- --demo --seed=7 --map=0`, then 1 and 2). If a match ends earlier, record it and run additional coverage; do not label a short match six minutes. Record exact candidate SHA, command, seed, duration, errors, stalls and outcomes, and include graphical screenshots per map. Check objective capture/Fire form, economy XP/turret ownership, menu/map switching, touch quick clicks, online host/join and store cosmetics. Compare FPS/draw calls before and after on the same settings/device for the visual/performance queue; no FPS improvement is certified here. New maps remain a separate subsequent scoped task. Open one integration PR for Faisal; **owner merges only**.

## Complete changed-file index

Each row is an exact path appearing in at least one reviewed main-relative diff. Columns list every PR touching that path; absence means unchanged relative to that PR's merge base, not necessarily absent from its tree. This includes assets, tests, tools and documentation, so inherited changes are visible instead of being hidden by feature titles.

| Path | PRs touching path |
|---|---|

| `.gitignore` | #8, #9, #13 |
| `README.md` | #4, #6, #8, #9, #13, #17 |
| `assets/CREDITS.md` | #4, #6, #8, #9, #13, #17 |
| `assets/characters/faces/face_brows_bold.png` | #4, #6, #8, #9, #13, #17 |
| `assets/characters/faces/face_brows_bright.png` | #4, #6, #8, #9, #13, #17 |
| `assets/characters/faces/face_brows_fierce.png` | #4, #6, #8, #9, #13, #17 |
| `assets/characters/faces/face_brows_gentle.png` | #4, #6, #8, #9, #13, #17 |
| `assets/characters/faces/face_brows_noble.png` | #4, #6, #8, #9, #13, #17 |
| `assets/characters/faces/face_brows_sly.png` | #4, #6, #8, #9, #13, #17 |
| `assets/characters/faces/face_eyes_bold_amber.png` | #4, #6, #8, #9, #13, #17 |
| `assets/characters/faces/face_eyes_bold_blue.png` | #4, #6, #8, #9, #13, #17 |
| `assets/characters/faces/face_eyes_bold_brown.png` | #4, #6, #8, #9, #13, #17 |
| `assets/characters/faces/face_eyes_bold_green.png` | #4, #6, #8, #9, #13, #17 |
| `assets/characters/faces/face_eyes_bold_grey.png` | #4, #6, #8, #9, #13, #17 |
| `assets/characters/faces/face_eyes_bold_red.png` | #4, #6, #8, #9, #13, #17 |
| `assets/characters/faces/face_eyes_bright_amber.png` | #4, #6, #8, #9, #13, #17 |
| `assets/characters/faces/face_eyes_bright_blue.png` | #4, #6, #8, #9, #13, #17 |
| `assets/characters/faces/face_eyes_bright_brown.png` | #4, #6, #8, #9, #13, #17 |
| `assets/characters/faces/face_eyes_bright_green.png` | #4, #6, #8, #9, #13, #17 |
| `assets/characters/faces/face_eyes_bright_grey.png` | #4, #6, #8, #9, #13, #17 |
| `assets/characters/faces/face_eyes_bright_red.png` | #4, #6, #8, #9, #13, #17 |
| `assets/characters/faces/face_eyes_fierce_amber.png` | #4, #6, #8, #9, #13, #17 |
| `assets/characters/faces/face_eyes_fierce_blue.png` | #4, #6, #8, #9, #13, #17 |
| `assets/characters/faces/face_eyes_fierce_brown.png` | #4, #6, #8, #9, #13, #17 |
| `assets/characters/faces/face_eyes_fierce_green.png` | #4, #6, #8, #9, #13, #17 |
| `assets/characters/faces/face_eyes_fierce_grey.png` | #4, #6, #8, #9, #13, #17 |
| `assets/characters/faces/face_eyes_fierce_red.png` | #4, #6, #8, #9, #13, #17 |
| `assets/characters/faces/face_eyes_gentle_amber.png` | #4, #6, #8, #9, #13, #17 |
| `assets/characters/faces/face_eyes_gentle_blue.png` | #4, #6, #8, #9, #13, #17 |
| `assets/characters/faces/face_eyes_gentle_brown.png` | #4, #6, #8, #9, #13, #17 |
| `assets/characters/faces/face_eyes_gentle_green.png` | #4, #6, #8, #9, #13, #17 |
| `assets/characters/faces/face_eyes_gentle_grey.png` | #4, #6, #8, #9, #13, #17 |
| `assets/characters/faces/face_eyes_gentle_red.png` | #4, #6, #8, #9, #13, #17 |
| `assets/characters/faces/face_eyes_noble_amber.png` | #4, #6, #8, #9, #13, #17 |
| `assets/characters/faces/face_eyes_noble_blue.png` | #4, #6, #8, #9, #13, #17 |
| `assets/characters/faces/face_eyes_noble_brown.png` | #4, #6, #8, #9, #13, #17 |
| `assets/characters/faces/face_eyes_noble_green.png` | #4, #6, #8, #9, #13, #17 |
| `assets/characters/faces/face_eyes_noble_grey.png` | #4, #6, #8, #9, #13, #17 |
| `assets/characters/faces/face_eyes_noble_red.png` | #4, #6, #8, #9, #13, #17 |
| `assets/characters/faces/face_eyes_sly_amber.png` | #4, #6, #8, #9, #13, #17 |
| `assets/characters/faces/face_eyes_sly_blue.png` | #4, #6, #8, #9, #13, #17 |
| `assets/characters/faces/face_eyes_sly_brown.png` | #4, #6, #8, #9, #13, #17 |
| `assets/characters/faces/face_eyes_sly_green.png` | #4, #6, #8, #9, #13, #17 |
| `assets/characters/faces/face_eyes_sly_grey.png` | #4, #6, #8, #9, #13, #17 |
| `assets/characters/faces/face_eyes_sly_red.png` | #4, #6, #8, #9, #13, #17 |
| `assets/characters/faces/face_mark_claws.png` | #4, #6, #8, #9, #13, #17 |
| `assets/characters/faces/face_mark_freckles.png` | #4, #6, #8, #9, #13, #17 |
| `assets/characters/faces/face_mark_paint.png` | #4, #6, #8, #9, #13, #17 |
| `assets/characters/faces/face_mark_scar.png` | #4, #6, #8, #9, #13, #17 |
| `assets/characters/faces/face_mouth_bold.png` | #4, #6, #8, #9, #13, #17 |
| `assets/characters/faces/face_mouth_bright.png` | #4, #6, #8, #9, #13, #17 |
| `assets/characters/faces/face_mouth_fierce.png` | #4, #6, #8, #9, #13, #17 |
| `assets/characters/faces/face_mouth_gentle.png` | #4, #6, #8, #9, #13, #17 |
| `assets/characters/faces/face_mouth_noble.png` | #4, #6, #8, #9, #13, #17 |
| `assets/characters/faces/face_mouth_sly.png` | #4, #6, #8, #9, #13, #17 |
| `assets/music/battle_base.ogg` | #6, #8, #9, #13 |
| `assets/music/battle_drums.ogg` | #6, #8, #9, #13 |
| `assets/music/battle_tension.ogg` | #6, #8, #9, #13 |
| `assets/music/menu.ogg` | #6, #8, #9, #13 |
| `assets/music/sting_crown_captured.ogg` | #6, #8, #9, #13 |
| `assets/music/sting_crown_lost.ogg` | #6, #8, #9, #13 |
| `assets/music/sting_defeat.ogg` | #6, #8, #9, #13 |
| `assets/music/sting_match_start.ogg` | #6, #8, #9, #13 |
| `assets/music/sting_victory.ogg` | #6, #8, #9, #13 |
| `assets/props/dungeon/banner_blue.glb` | #8, #13 |
| `assets/props/dungeon/banner_green.glb` | #8, #13 |
| `assets/props/dungeon/banner_green_dungeon_texture.png` | #8, #13 |
| `assets/props/dungeon/banner_shield_blue.glb` | #8, #13 |
| `assets/props/dungeon/banner_shield_blue_dungeon_texture.png` | #8, #13 |
| `assets/props/dungeon/banner_shield_green.glb` | #8, #13 |
| `assets/props/dungeon/banner_shield_green_dungeon_texture.png` | #8, #13 |
| `assets/props/dungeon/barrel_large.glb` | #8, #13 |
| `assets/props/dungeon/barrel_large_decorated.glb` | #8, #13 |
| `assets/props/dungeon/barrel_large_decorated_dungeon_texture.png` | #8, #13 |
| `assets/props/dungeon/barrel_large_dungeon_texture.png` | #8, #13 |
| `assets/props/dungeon/barrel_small.glb` | #8, #13 |
| `assets/props/dungeon/barrel_small_dungeon_texture.png` | #8, #13 |
| `assets/props/dungeon/barrel_small_stack.glb` | #8, #13 |
| `assets/props/dungeon/barrel_small_stack_dungeon_texture.png` | #8, #13 |
| `assets/props/dungeon/barrier.glb` | #8, #13 |
| `assets/props/dungeon/barrier_dungeon_texture_src.png` | #8, #13 |
| `assets/props/dungeon/bed_decorated.glb` | #8, #13 |
| `assets/props/dungeon/bed_decorated_dungeon_texture.png` | #8, #13 |
| `assets/props/dungeon/bed_floor.glb` | #8, #13 |
| `assets/props/dungeon/bed_floor_dungeon_texture.png` | #8, #13 |
| `assets/props/dungeon/bed_frame.glb` | #8, #13 |
| `assets/props/dungeon/bed_frame_dungeon_texture.png` | #8, #13 |
| `assets/props/dungeon/bottle_A_brown.glb` | #8, #13 |
| `assets/props/dungeon/bottle_A_brown_dungeon_texture.png` | #8, #13 |
| `assets/props/dungeon/bottle_A_green.glb` | #8, #13 |
| `assets/props/dungeon/bottle_A_green_dungeon_texture.png` | #8, #13 |
| `assets/props/dungeon/bottle_A_labeled_brown.glb` | #8, #13 |
| `assets/props/dungeon/bottle_A_labeled_brown_dungeon_texture.png` | #8, #13 |
| `assets/props/dungeon/bottle_A_labeled_green.glb` | #8, #13 |
| `assets/props/dungeon/bottle_A_labeled_green_dungeon_texture.png` | #8, #13 |
| `assets/props/dungeon/bottle_B_brown.glb` | #8, #13 |
| `assets/props/dungeon/bottle_B_brown_dungeon_texture.png` | #8, #13 |
| `assets/props/dungeon/bottle_B_green.glb` | #8, #13 |
| `assets/props/dungeon/bottle_B_green_dungeon_texture.png` | #8, #13 |
| `assets/props/dungeon/bottle_C_brown.glb` | #8, #13 |
| `assets/props/dungeon/bottle_C_brown_dungeon_texture.png` | #8, #13 |
| `assets/props/dungeon/bottle_C_green.glb` | #8, #13 |
| `assets/props/dungeon/bottle_C_green_dungeon_texture.png` | #8, #13 |
| `assets/props/dungeon/box_large.glb` | #8, #13 |
| `assets/props/dungeon/box_large_dungeon_texture.png` | #8, #13 |
| `assets/props/dungeon/box_small.glb` | #8, #13 |
| `assets/props/dungeon/box_small_decorated.glb` | #8, #13 |
| `assets/props/dungeon/box_small_decorated_dungeon_texture.png` | #8, #13 |
| `assets/props/dungeon/box_small_dungeon_texture.png` | #8, #13 |
| `assets/props/dungeon/box_stacked.glb` | #8, #13 |
| `assets/props/dungeon/box_stacked_dungeon_texture.png` | #8, #13 |
| `assets/props/dungeon/candle.glb` | #8, #13 |
| `assets/props/dungeon/candle_dungeon_texture.png` | #8, #13 |
| `assets/props/dungeon/candle_lit.glb` | #8, #13 |
| `assets/props/dungeon/candle_lit_dungeon_texture.png` | #8, #13 |
| `assets/props/dungeon/candle_melted.glb` | #8, #13 |
| `assets/props/dungeon/candle_melted_dungeon_texture.png` | #8, #13 |
| `assets/props/dungeon/candle_thin.glb` | #8, #13 |
| `assets/props/dungeon/candle_thin_dungeon_texture.png` | #8, #13 |
| `assets/props/dungeon/candle_thin_lit.glb` | #8, #13 |
| `assets/props/dungeon/candle_thin_lit_dungeon_texture.png` | #8, #13 |
| `assets/props/dungeon/candle_triple.glb` | #8, #13 |
| `assets/props/dungeon/candle_triple_dungeon_texture.png` | #8, #13 |
| `assets/props/dungeon/chair.glb` | #8, #13 |
| `assets/props/dungeon/chair_dungeon_texture.png` | #8, #13 |
| `assets/props/dungeon/chest.glb` | #8, #13 |
| `assets/props/dungeon/chest_dungeon_texture.png` | #8, #13 |
| `assets/props/dungeon/chest_gold.glb` | #8, #13 |
| `assets/props/dungeon/chest_gold_dungeon_texture.png` | #8, #13 |
| `assets/props/dungeon/coin.glb` | #8, #13 |
| `assets/props/dungeon/coin_dungeon_texture.png` | #8, #13 |
| `assets/props/dungeon/coin_stack_large.glb` | #8, #13 |
| `assets/props/dungeon/coin_stack_large_dungeon_texture.png` | #8, #13 |
| `assets/props/dungeon/coin_stack_medium.glb` | #8, #13 |
| `assets/props/dungeon/coin_stack_medium_dungeon_texture.png` | #8, #13 |
| `assets/props/dungeon/coin_stack_small.glb` | #8, #13 |
| `assets/props/dungeon/coin_stack_small_dungeon_texture.png` | #8, #13 |
| `assets/props/dungeon/column.glb` | #8, #13 |
| `assets/props/dungeon/column_dungeon_texture.png` | #8, #13 |
| `assets/props/dungeon/column_dungeon_texture_src.png` | #8, #13 |
| `assets/props/dungeon/crates_stacked.glb` | #8, #13 |
| `assets/props/dungeon/crates_stacked_dungeon_texture.png` | #8, #13 |
| `assets/props/dungeon/dungeon_texture.png` | #8, #13 |
| `assets/props/dungeon/dungeon_texture_stone.png` | #8, #13 |
| `assets/props/dungeon/floor_wood_large.glb` | #8, #13 |
| `assets/props/dungeon/floor_wood_large_dungeon_texture.png` | #8, #13 |
| `assets/props/dungeon/keg.glb` | #8, #13 |
| `assets/props/dungeon/keg_decorated.glb` | #8, #13 |
| `assets/props/dungeon/keg_decorated_dungeon_texture.png` | #8, #13 |
| `assets/props/dungeon/keg_dungeon_texture.png` | #8, #13 |
| `assets/props/dungeon/key.glb` | #8, #13 |
| `assets/props/dungeon/key_dungeon_texture.png` | #8, #13 |
| `assets/props/dungeon/keyring.glb` | #8, #13 |
| `assets/props/dungeon/keyring_dungeon_texture.png` | #8, #13 |
| `assets/props/dungeon/keyring_hanging.glb` | #8, #13 |
| `assets/props/dungeon/keyring_hanging_dungeon_texture.png` | #8, #13 |
| `assets/props/dungeon/pillar.glb` | #8, #13 |
| `assets/props/dungeon/pillar_decorated.glb` | #8, #13 |
| `assets/props/dungeon/pillar_decorated_dungeon_texture.png` | #8, #13 |
| `assets/props/dungeon/pillar_dungeon_texture.png` | #8, #13 |
| `assets/props/dungeon/plate.glb` | #8, #13 |
| `assets/props/dungeon/plate_dungeon_texture.png` | #8, #13 |
| `assets/props/dungeon/plate_food_A.glb` | #8, #13 |
| `assets/props/dungeon/plate_food_A_dungeon_texture.png` | #8, #13 |
| `assets/props/dungeon/plate_food_B.glb` | #8, #13 |
| `assets/props/dungeon/plate_food_B_dungeon_texture.png` | #8, #13 |
| `assets/props/dungeon/plate_small.glb` | #8, #13 |
| `assets/props/dungeon/plate_small_dungeon_texture.png` | #8, #13 |
| `assets/props/dungeon/plate_stack.glb` | #8, #13 |
| `assets/props/dungeon/plate_stack_dungeon_texture.png` | #8, #13 |
| `assets/props/dungeon/rubble_half.glb` | #8, #13 |
| `assets/props/dungeon/rubble_half_dungeon_texture.png` | #8, #13 |
| `assets/props/dungeon/rubble_large.glb` | #8, #13 |
| `assets/props/dungeon/rubble_large_dungeon_texture.png` | #8, #13 |
| `assets/props/dungeon/rubble_large_dungeon_texture_src.png` | #8, #13 |
| `assets/props/dungeon/shelf_large.glb` | #8, #13 |
| `assets/props/dungeon/shelf_large_dungeon_texture.png` | #8, #13 |
| `assets/props/dungeon/shelf_small.glb` | #8, #13 |
| `assets/props/dungeon/shelf_small_candles.glb` | #8, #13 |
| `assets/props/dungeon/shelf_small_candles_dungeon_texture.png` | #8, #13 |
| `assets/props/dungeon/shelf_small_dungeon_texture.png` | #8, #13 |
| `assets/props/dungeon/shelves.glb` | #8, #13 |
| `assets/props/dungeon/shelves_dungeon_texture.png` | #8, #13 |
| `assets/props/dungeon/stairs.glb` | #8, #13 |
| `assets/props/dungeon/stairs_dungeon_texture.png` | #8, #13 |
| `assets/props/dungeon/stairs_wide.glb` | #8, #13 |
| `assets/props/dungeon/stairs_wide_dungeon_texture.png` | #8, #13 |
| `assets/props/dungeon/stairs_wood.glb` | #8, #13 |
| `assets/props/dungeon/stairs_wood_dungeon_texture.png` | #8, #13 |
| `assets/props/dungeon/stool.glb` | #8, #13 |
| `assets/props/dungeon/stool_dungeon_texture.png` | #8, #13 |
| `assets/props/dungeon/sword_shield.glb` | #8, #13 |
| `assets/props/dungeon/sword_shield_dungeon_texture.png` | #8, #13 |
| `assets/props/dungeon/sword_shield_gold.glb` | #8, #13 |
| `assets/props/dungeon/sword_shield_gold_dungeon_texture.png` | #8, #13 |
| `assets/props/dungeon/table_long.glb` | #8, #13 |
| `assets/props/dungeon/table_long_decorated_A.glb` | #8, #13 |
| `assets/props/dungeon/table_long_decorated_A_dungeon_texture.png` | #8, #13 |
| `assets/props/dungeon/table_long_dungeon_texture.png` | #8, #13 |
| `assets/props/dungeon/table_long_tablecloth.glb` | #8, #13 |
| `assets/props/dungeon/table_long_tablecloth_decorated_A.glb` | #8, #13 |
| `assets/props/dungeon/table_long_tablecloth_decorated_A_dungeon_texture.png` | #8, #13 |
| `assets/props/dungeon/table_long_tablecloth_dungeon_texture.png` | #8, #13 |
| `assets/props/dungeon/table_medium.glb` | #8, #13 |
| `assets/props/dungeon/table_medium_decorated_A.glb` | #8, #13 |
| `assets/props/dungeon/table_medium_decorated_A_dungeon_texture.png` | #8, #13 |
| `assets/props/dungeon/table_medium_dungeon_texture.png` | #8, #13 |
| `assets/props/dungeon/table_medium_tablecloth.glb` | #8, #13 |
| `assets/props/dungeon/table_medium_tablecloth_decorated_B.glb` | #8, #13 |
| `assets/props/dungeon/table_medium_tablecloth_decorated_B_dungeon_texture.png` | #8, #13 |
| `assets/props/dungeon/table_medium_tablecloth_dungeon_texture.png` | #8, #13 |
| `assets/props/dungeon/table_small.glb` | #8, #13 |
| `assets/props/dungeon/table_small_decorated_A.glb` | #8, #13 |
| `assets/props/dungeon/table_small_decorated_A_dungeon_texture.png` | #8, #13 |
| `assets/props/dungeon/table_small_dungeon_texture.png` | #8, #13 |
| `assets/props/dungeon/torch.glb` | #8, #13 |
| `assets/props/dungeon/torch_dungeon_texture.png` | #8, #13 |
| `assets/props/dungeon/torch_lit.glb` | #8, #13 |
| `assets/props/dungeon/torch_lit_dungeon_texture.png` | #8, #13 |
| `assets/props/dungeon/torch_lit_dungeon_texture_src.png` | #8, #13 |
| `assets/props/dungeon/torch_mounted.glb` | #8, #13 |
| `assets/props/dungeon/torch_mounted_dungeon_texture.png` | #8, #13 |
| `assets/props/dungeon/torch_mounted_dungeon_texture_src.png` | #8, #13 |
| `assets/props/dungeon/trunk_large_A.glb` | #8, #13 |
| `assets/props/dungeon/trunk_large_A_dungeon_texture.png` | #8, #13 |
| `assets/props/dungeon/trunk_medium_A.glb` | #8, #13 |
| `assets/props/dungeon/trunk_medium_A_dungeon_texture.png` | #8, #13 |
| `assets/props/dungeon/trunk_small_A.glb` | #8, #13 |
| `assets/props/dungeon/trunk_small_A_dungeon_texture.png` | #8, #13 |
| `assets/props/dungeon/wall_shelves.glb` | #8, #13 |
| `assets/props/dungeon/wall_shelves_dungeon_texture.png` | #8, #13 |
| `assets/props/gear/barbarian_texture.png` | #8, #13 |
| `assets/sfx/grab.wav` | #6, #8, #9, #13 |
| `assets/sfx/grab_miss.wav` | #6, #8, #9, #13 |
| `assets/sfx/heartbeat.wav` | #6, #8, #9, #13 |
| `assets/sfx/hit_heavy.wav` | #6, #8, #9, #13 |
| `assets/sfx/hit_magic.wav` | #6, #8, #9, #13 |
| `assets/sfx/hit_thud.wav` | #8, #13 |
| `assets/sfx/hit_tick.wav` | #6, #8, #9, #13 |
| `assets/sfx/kill.wav` | #6, #8, #9, #13 |
| `assets/sfx/theme.wav` | #6, #8, #9, #13 |
| `assets/shaders/ink_outline.gdshader` | #6, #8, #9, #13 |
| `assets/shaders/lava.gdshader` | #4, #6, #8, #9, #13, #17 |
| `assets/shaders/leaf.gdshader` | #6, #8, #9, #13 |
| `assets/shaders/leaf_soft.gdshader` | #8, #9, #13 |
| `assets/shaders/title_bg.gdshader` | #4, #6, #8, #9, #13, #17 |
| `assets/shaders/water.gdshader` | #8, #9, #13 |
| `assets/shaders/waterfall.gdshader` | #4, #6, #8, #9, #13, #17 |
| `assets/textures/elfbark_color.jpg` | #4, #6, #8, #9, #13, #17 |
| `assets/textures/elfbark_normal.jpg` | #4, #6, #8, #9, #13, #17 |
| `assets/textures/emblems/stag.png` | #6, #8, #9, #13 |
| `assets/textures/flagstone_color.jpg` | #6, #8, #9, #13 |
| `assets/textures/flagstone_elf_color.jpg` | #4, #6, #8, #9, #13, #17 |
| `assets/textures/flagstone_elf_normal.jpg` | #4, #6, #8, #9, #13, #17 |
| `assets/textures/flagstone_grey_color.jpg` | #6, #8, #9, #13 |
| `assets/textures/flagstone_grey_normal.jpg` | #6, #8, #9, #13 |
| `assets/textures/flagstone_moss_color.jpg` | #6, #8, #9, #13 |
| `assets/textures/flagstone_moss_normal.jpg` | #6, #8, #9, #13 |
| `assets/textures/flagstone_normal.jpg` | #6, #8, #9, #13 |
| `assets/textures/grass_color.jpg` | #6, #8, #9, #13 |
| `assets/textures/hedge_color.jpg` | #6, #8, #9, #13 |
| `assets/textures/hedge_normal.jpg` | #6, #8, #9, #13 |
| `assets/textures/path_color.png` | #6, #8, #9, #13 |
| `assets/textures/path_loose_color.png` | #6, #8, #9, #13 |
| `assets/textures/path_loose_normal.jpg` | #6, #8, #9, #13 |
| `assets/textures/path_loose_stones.png` | #6, #8, #9, #13 |
| `assets/textures/path_normal.jpg` | #6, #8, #9, #13 |
| `assets/textures/path_stones.png` | #6, #8, #9, #13 |
| `assets/textures/pavers_color.jpg` | #6, #8, #9, #13 |
| `assets/textures/pavers_normal.jpg` | #6, #8, #9, #13 |
| `assets/textures/stone_color.jpg` | #6, #8, #9, #13 |
| `assets/textures/stone_moss_color.jpg` | #6, #8, #9, #13 |
| `assets/textures/style/bark_color.jpg` | #8, #9, #13 |
| `assets/textures/style/bark_normal.jpg` | #8, #9, #13 |
| `assets/textures/style/cobble_color.jpg` | #8, #9, #13 |
| `assets/textures/style/cobble_normal.jpg` | #8, #9, #13 |
| `assets/textures/style/flagstone_color.jpg` | #8, #9, #13 |
| `assets/textures/style/flagstone_grey_color.jpg` | #8, #9, #13 |
| `assets/textures/style/flagstone_grey_normal.jpg` | #8, #9, #13 |
| `assets/textures/style/flagstone_moss_color.jpg` | #8, #9, #13 |
| `assets/textures/style/flagstone_moss_normal.jpg` | #8, #9, #13 |
| `assets/textures/style/flagstone_normal.jpg` | #8, #9, #13 |
| `assets/textures/style/grass_color.jpg` | #8, #9, #13 |
| `assets/textures/style/grass_normal.jpg` | #8, #9, #13 |
| `assets/textures/style/greystone_color.jpg` | #8, #9, #13 |
| `assets/textures/style/greystone_normal.jpg` | #8, #9, #13 |
| `assets/textures/style/path_color.png` | #8, #9, #13 |
| `assets/textures/style/path_loose_color.png` | #8, #9, #13 |
| `assets/textures/style/path_loose_normal.jpg` | #8, #9, #13 |
| `assets/textures/style/path_loose_stones.png` | #8, #9, #13 |
| `assets/textures/style/path_normal.jpg` | #8, #9, #13 |
| `assets/textures/style/path_stones.png` | #8, #9, #13 |
| `assets/textures/style/rock_color.jpg` | #8, #9, #13 |
| `assets/textures/style/rock_normal.jpg` | #8, #9, #13 |
| `assets/textures/style/rosette_color.png` | #8, #9, #13 |
| `assets/textures/style/rosette_normal.jpg` | #8, #9, #13 |
| `assets/textures/style/stone_color.jpg` | #8, #9, #13 |
| `assets/textures/style/stone_normal.jpg` | #8, #9, #13 |
| `assets/textures/style/wood_color.jpg` | #8, #9, #13 |
| `assets/textures/style/wood_dark_color.jpg` | #8, #9, #13 |
| `assets/textures/style/wood_dark_normal.jpg` | #8, #9, #13 |
| `assets/textures/style/wood_normal.jpg` | #8, #9, #13 |
| `assets/ui/banners/bg_aurora.png` | #8, #13 |
| `assets/ui/banners/bg_autumn_leaves.png` | #8, #13 |
| `assets/ui/banners/bg_checky.png` | #8, #13 |
| `assets/ui/banners/bg_chevron.png` | #8, #13 |
| `assets/ui/banners/bg_crystal.png` | #8, #13 |
| `assets/ui/banners/bg_dragonfire.png` | #8, #13 |
| `assets/ui/banners/bg_fae_lights.png` | #8, #13 |
| `assets/ui/banners/bg_golden_hoard.png` | #8, #13 |
| `assets/ui/banners/bg_moonlit_grove.png` | #8, #13 |
| `assets/ui/banners/bg_quartered.png` | #8, #13 |
| `assets/ui/banners/bg_royal_damask.png` | #8, #13 |
| `assets/ui/banners/bg_shadow.png` | #8, #13 |
| `assets/ui/banners/bg_starfall.png` | #8, #13 |
| `assets/ui/banners/bg_stone_keep.png` | #8, #13 |
| `assets/ui/banners/bg_storm.png` | #8, #13 |
| `assets/ui/banners/bg_thornweave.png` | #8, #13 |
| `assets/ui/cards/crest_elf.png` | #6, #8, #9, #13 |
| `assets/ui/cards/crest_human.png` | #6, #8, #9, #13 |
| `assets/ui/cards/elf_base.png` | #6, #8, #9, #13 |
| `assets/ui/cards/elf_base_blur.png` | #6, #8, #9, #13 |
| `assets/ui/cards/elf_engineer.png` | #6, #8, #9, #13 |
| `assets/ui/cards/elf_engineer_blur.png` | #6, #8, #9, #13 |
| `assets/ui/cards/elf_healer.png` | #6, #8, #9, #13 |
| `assets/ui/cards/elf_healer_blur.png` | #6, #8, #9, #13 |
| `assets/ui/cards/elf_knight.png` | #6, #8, #9, #13 |
| `assets/ui/cards/elf_knight_blur.png` | #6, #8, #9, #13 |
| `assets/ui/cards/elf_mage.png` | #6, #8, #9, #13 |
| `assets/ui/cards/elf_mage_blur.png` | #6, #8, #9, #13 |
| `assets/ui/cards/elf_ranger.png` | #6, #8, #9, #13 |
| `assets/ui/cards/elf_ranger_blur.png` | #6, #8, #9, #13 |
| `assets/ui/cards/elf_rogue.png` | #6, #8, #9, #13 |
| `assets/ui/cards/elf_rogue_blur.png` | #6, #8, #9, #13 |
| `assets/ui/cards/human_base.png` | #6, #8, #9, #13 |
| `assets/ui/cards/human_base_blur.png` | #6, #8, #9, #13 |
| `assets/ui/cards/human_engineer.png` | #6, #8, #9, #13 |
| `assets/ui/cards/human_engineer_blur.png` | #6, #8, #9, #13 |
| `assets/ui/cards/human_healer.png` | #6, #8, #9, #13 |
| `assets/ui/cards/human_healer_blur.png` | #6, #8, #9, #13 |
| `assets/ui/cards/human_knight.png` | #6, #8, #9, #13 |
| `assets/ui/cards/human_knight_blur.png` | #6, #8, #9, #13 |
| `assets/ui/cards/human_mage.png` | #6, #8, #9, #13 |
| `assets/ui/cards/human_mage_blur.png` | #6, #8, #9, #13 |
| `assets/ui/cards/human_ranger.png` | #6, #8, #9, #13 |
| `assets/ui/cards/human_ranger_blur.png` | #6, #8, #9, #13 |
| `assets/ui/cards/human_rogue.png` | #6, #8, #9, #13 |
| `assets/ui/cards/human_rogue_blur.png` | #6, #8, #9, #13 |
| `assets/ui/cards/logo_elves.png` | #6, #8, #9, #13 |
| `assets/ui/cards/logo_humans.png` | #6, #8, #9, #13 |
| `assets/ui/fonts/LilitaOne-Regular.ttf` | #4, #6, #8, #9, #13, #17 |
| `assets/ui/fonts/OFL-LilitaOne.txt` | #4, #6, #8, #9, #13, #17 |
| `assets/ui/icons/arrow.png` | #6, #8, #9, #13 |
| `assets/ui/icons/artificer.png` | #6, #8, #9, #13 |
| `assets/ui/icons/assassin.png` | #6, #8, #9, #13 |
| `assets/ui/icons/assist.png` | #6, #8, #9, #13, #17 |
| `assets/ui/icons/bash.png` | #6, #8, #9, #13 |
| `assets/ui/icons/blessing.png` | #6, #8, #9, #13 |
| `assets/ui/icons/blink.png` | #6, #8, #9, #13 |
| `assets/ui/icons/block.png` | #6, #8, #9, #13 |
| `assets/ui/icons/bolt.png` | #6, #8, #9, #13 |
| `assets/ui/icons/bramble.png` | #6, #8, #9, #13 |
| `assets/ui/icons/bubble.png` | #6, #8, #9, #13 |
| `assets/ui/icons/burst.png` | #6, #8, #9, #13, #17 |
| `assets/ui/icons/cape.png` | #6, #8, #9, #13 |
| `assets/ui/icons/chest.png` | #6, #8, #9, #13, #17 |
| `assets/ui/icons/class_elf.png` | #6, #8, #9, #13 |
| `assets/ui/icons/class_engineer.png` | #6, #8, #9, #13 |
| `assets/ui/icons/class_healer.png` | #6, #8, #9, #13 |
| `assets/ui/icons/class_human.png` | #6, #8, #9, #13 |
| `assets/ui/icons/class_knight.png` | #6, #8, #9, #13 |
| `assets/ui/icons/class_mage.png` | #6, #8, #9, #13 |
| `assets/ui/icons/class_ranger.png` | #6, #8, #9, #13 |
| `assets/ui/icons/class_rogue.png` | #6, #8, #9, #13 |
| `assets/ui/icons/cleave.png` | #6, #8, #9, #13 |
| `assets/ui/icons/cleric.png` | #6, #8, #9, #13 |
| `assets/ui/icons/clock.png` | #6, #8, #9, #13, #17 |
| `assets/ui/icons/coin.png` | #6, #8, #9, #13, #17 |
| `assets/ui/icons/crest_forest.png` | #6, #8, #9, #13 |
| `assets/ui/icons/crest_kingdom.png` | #6, #8, #9, #13 |
| `assets/ui/icons/crown.png` | #6, #8, #9, #13 |
| `assets/ui/icons/curse.png` | #6, #8, #9, #13 |
| `assets/ui/icons/dagger.png` | #6, #8, #9, #13 |
| `assets/ui/icons/darkpriest.png` | #6, #8, #9, #13 |
| `assets/ui/icons/dodge.png` | #6, #8, #9, #13 |
| `assets/ui/icons/drain.png` | #6, #8, #9, #13 |
| `assets/ui/icons/fireball.png` | #6, #8, #9, #13 |
| `assets/ui/icons/fist.png` | #6, #8, #9, #13 |
| `assets/ui/icons/flag.png` | #6, #8, #9, #13, #17 |
| `assets/ui/icons/frost.png` | #6, #8, #9, #13 |
| `assets/ui/icons/frostweaver.png` | #6, #8, #9, #13 |
| `assets/ui/icons/guard.png` | #6, #8, #9, #13 |
| `assets/ui/icons/hammer.png` | #6, #8, #9, #13 |
| `assets/ui/icons/lock.png` | #6, #8, #9, #13, #17 |
| `assets/ui/icons/mend.png` | #6, #8, #9, #13 |
| `assets/ui/icons/might.png` | #6, #8, #9, #13 |
| `assets/ui/icons/moon.png` | #6, #8, #9, #13 |
| `assets/ui/icons/nightrunner.png` | #6, #8, #9, #13 |
| `assets/ui/icons/overclock.png` | #6, #8, #9, #13 |
| `assets/ui/icons/pierce.png` | #6, #8, #9, #13 |
| `assets/ui/icons/potion.png` | #6, #8, #9, #13 |
| `assets/ui/icons/pyromancer.png` | #6, #8, #9, #13 |
| `assets/ui/icons/rank.png` | #6, #8, #9, #13, #17 |
| `assets/ui/icons/regen.png` | #6, #8, #9, #13 |
| `assets/ui/icons/shard.png` | #6, #8, #9, #13, #17 |
| `assets/ui/icons/sharpshooter.png` | #6, #8, #9, #13 |
| `assets/ui/icons/siegewright.png` | #6, #8, #9, #13 |
| `assets/ui/icons/skull.png` | #6, #8, #9, #13, #17 |
| `assets/ui/icons/smite.png` | #6, #8, #9, #13 |
| `assets/ui/icons/smoke.png` | #6, #8, #9, #13 |
| `assets/ui/icons/snipe.png` | #6, #8, #9, #13 |
| `assets/ui/icons/sword.png` | #6, #8, #9, #13 |
| `assets/ui/icons/takedown.png` | #6, #8, #9, #13, #17 |
| `assets/ui/icons/training.png` | #6, #8, #9, #13 |
| `assets/ui/icons/trap.png` | #6, #8, #9, #13 |
| `assets/ui/icons/trapper.png` | #6, #8, #9, #13 |
| `assets/ui/icons/turret.png` | #6, #8, #9, #13 |
| `assets/ui/icons/upgrade.png` | #6, #8, #9, #13 |
| `assets/ui/icons/vanguard.png` | #6, #8, #9, #13 |
| `assets/ui/icons/vigor.png` | #6, #8, #9, #13 |
| `assets/ui/icons/volley.png` | #6, #8, #9, #13 |
| `assets/ui/icons/warden.png` | #6, #8, #9, #13 |
| `assets/ui/icons/wave.png` | #6, #8, #9, #13 |
| `assets/ui/icons/wood.png` | #6, #8, #9, #13 |
| `assets/ui/icons/xp.png` | #6, #8, #9, #13 |
| `assets/ui/icons_clean/arrow.png` | #8, #9, #13 |
| `assets/ui/icons_clean/artificer.png` | #8, #9, #13 |
| `assets/ui/icons_clean/assassin.png` | #8, #9, #13 |
| `assets/ui/icons_clean/assist.png` | #8, #9, #13 |
| `assets/ui/icons_clean/bash.png` | #8, #9, #13 |
| `assets/ui/icons_clean/blessing.png` | #8, #9, #13 |
| `assets/ui/icons_clean/blink.png` | #8, #9, #13 |
| `assets/ui/icons_clean/block.png` | #8, #9, #13 |
| `assets/ui/icons_clean/bolt.png` | #8, #9, #13 |
| `assets/ui/icons_clean/bramble.png` | #8, #9, #13 |
| `assets/ui/icons_clean/bubble.png` | #8, #9, #13 |
| `assets/ui/icons_clean/burst.png` | #8, #9, #13 |
| `assets/ui/icons_clean/cape.png` | #8, #9, #13 |
| `assets/ui/icons_clean/chest.png` | #8, #9, #13 |
| `assets/ui/icons_clean/class_elf.png` | #8, #9, #13 |
| `assets/ui/icons_clean/class_engineer.png` | #8, #9, #13 |
| `assets/ui/icons_clean/class_healer.png` | #8, #9, #13 |
| `assets/ui/icons_clean/class_human.png` | #8, #9, #13 |
| `assets/ui/icons_clean/class_knight.png` | #8, #9, #13 |
| `assets/ui/icons_clean/class_mage.png` | #8, #9, #13 |
| `assets/ui/icons_clean/class_ranger.png` | #8, #9, #13 |
| `assets/ui/icons_clean/class_rogue.png` | #8, #9, #13 |
| `assets/ui/icons_clean/cleave.png` | #8, #9, #13 |
| `assets/ui/icons_clean/cleric.png` | #8, #9, #13 |
| `assets/ui/icons_clean/clock.png` | #8, #9, #13 |
| `assets/ui/icons_clean/coin.png` | #8, #9, #13 |
| `assets/ui/icons_clean/crest_forest.png` | #8, #9, #13 |
| `assets/ui/icons_clean/crest_kingdom.png` | #8, #9, #13 |
| `assets/ui/icons_clean/crown.png` | #8, #9, #13 |
| `assets/ui/icons_clean/curse.png` | #8, #9, #13 |
| `assets/ui/icons_clean/dagger.png` | #8, #9, #13 |
| `assets/ui/icons_clean/darkpriest.png` | #8, #9, #13 |
| `assets/ui/icons_clean/dodge.png` | #8, #9, #13 |
| `assets/ui/icons_clean/drain.png` | #8, #9, #13 |
| `assets/ui/icons_clean/fireball.png` | #8, #9, #13 |
| `assets/ui/icons_clean/fist.png` | #8, #9, #13 |
| `assets/ui/icons_clean/flag.png` | #8, #9, #13 |
| `assets/ui/icons_clean/frost.png` | #8, #9, #13 |
| `assets/ui/icons_clean/frostweaver.png` | #8, #9, #13 |
| `assets/ui/icons_clean/guard.png` | #8, #9, #13 |
| `assets/ui/icons_clean/hammer.png` | #8, #9, #13 |
| `assets/ui/icons_clean/lock.png` | #8, #9, #13 |
| `assets/ui/icons_clean/mend.png` | #8, #9, #13 |
| `assets/ui/icons_clean/might.png` | #8, #9, #13 |
| `assets/ui/icons_clean/moon.png` | #8, #9, #13 |
| `assets/ui/icons_clean/nightrunner.png` | #8, #9, #13 |
| `assets/ui/icons_clean/overclock.png` | #8, #9, #13 |
| `assets/ui/icons_clean/pierce.png` | #8, #9, #13 |
| `assets/ui/icons_clean/potion.png` | #8, #9, #13 |
| `assets/ui/icons_clean/pyromancer.png` | #8, #9, #13 |
| `assets/ui/icons_clean/rank.png` | #8, #9, #13 |
| `assets/ui/icons_clean/regen.png` | #8, #9, #13 |
| `assets/ui/icons_clean/shard.png` | #8, #9, #13 |
| `assets/ui/icons_clean/sharpshooter.png` | #8, #9, #13 |
| `assets/ui/icons_clean/siegewright.png` | #8, #9, #13 |
| `assets/ui/icons_clean/skull.png` | #8, #9, #13 |
| `assets/ui/icons_clean/smite.png` | #8, #9, #13 |
| `assets/ui/icons_clean/smoke.png` | #8, #9, #13 |
| `assets/ui/icons_clean/snipe.png` | #8, #9, #13 |
| `assets/ui/icons_clean/sword.png` | #8, #9, #13 |
| `assets/ui/icons_clean/takedown.png` | #8, #9, #13 |
| `assets/ui/icons_clean/training.png` | #8, #9, #13 |
| `assets/ui/icons_clean/trap.png` | #8, #9, #13 |
| `assets/ui/icons_clean/trapper.png` | #8, #9, #13 |
| `assets/ui/icons_clean/turret.png` | #8, #9, #13 |
| `assets/ui/icons_clean/upgrade.png` | #8, #9, #13 |
| `assets/ui/icons_clean/vanguard.png` | #8, #9, #13 |
| `assets/ui/icons_clean/vigor.png` | #8, #9, #13 |
| `assets/ui/icons_clean/volley.png` | #8, #9, #13 |
| `assets/ui/icons_clean/warden.png` | #8, #9, #13 |
| `assets/ui/icons_clean/wave.png` | #8, #9, #13 |
| `assets/ui/icons_clean/wood.png` | #8, #9, #13 |
| `assets/ui/icons_clean/xp.png` | #8, #9, #13 |
| `assets/ui/menu/banner_crown_blue.png` | #4, #6, #8, #9, #13, #17 |
| `assets/ui/menu/banner_crown_red.png` | #4, #6, #8, #9, #13, #17 |
| `assets/ui/menu/banner_lion.png` | #4, #6, #8, #9, #13, #17 |
| `assets/ui/menu/banner_tree.png` | #4, #6, #8, #9, #13, #17 |
| `assets/ui/menu/btn_green.png` | #4, #6, #8, #9, #13, #17 |
| `assets/ui/menu/btn_green_off.png` | #4, #6, #8, #9, #13, #17 |
| `assets/ui/menu/btn_play.png` | #4, #6, #8, #9, #13, #17 |
| `assets/ui/menu/btn_play_blue.png` | #4, #6, #8, #9, #13, #17 |
| `assets/ui/menu/btn_wood.png` | #4, #6, #8, #9, #13, #17 |
| `assets/ui/menu/btn_wood_hi.png` | #4, #6, #8, #9, #13, #17 |
| `assets/ui/menu/frame_big.png` | #4, #6, #8, #9, #13, #17 |
| `assets/ui/menu/icon_appearance.png` | #4, #6, #8, #9, #13, #17 |
| `assets/ui/menu/icon_arrow_left.png` | #4, #6, #8, #9, #13, #17 |
| `assets/ui/menu/icon_arrow_right.png` | #4, #6, #8, #9, #13, #17 |
| `assets/ui/menu/icon_body_broad.png` | #4, #6, #8, #9, #13, #17 |
| `assets/ui/menu/icon_body_slim.png` | #4, #6, #8, #9, #13, #17 |
| `assets/ui/menu/icon_body_sturdy.png` | #4, #6, #8, #9, #13, #17 |
| `assets/ui/menu/icon_book.png` | #4, #6, #8, #9, #13, #17 |
| `assets/ui/menu/icon_check.png` | #4, #6, #8, #9, #13, #17 |
| `assets/ui/menu/icon_crown.png` | #4, #6, #8, #9, #13, #17 |
| `assets/ui/menu/icon_emblem.png` | #4, #6, #8, #9, #13, #17 |
| `assets/ui/menu/icon_exit.png` | #4, #6, #8, #9, #13, #17 |
| `assets/ui/menu/icon_face.png` | #4, #6, #8, #9, #13, #17 |
| `assets/ui/menu/icon_gamepad.png` | #4, #6, #8, #9, #13, #17 |
| `assets/ui/menu/icon_gear.png` | #4, #6, #8, #9, #13, #17 |
| `assets/ui/menu/icon_hair.png` | #4, #6, #8, #9, #13, #17 |
| `assets/ui/menu/icon_lock.png` | #4, #6, #8, #9, #13, #17 |
| `assets/ui/menu/icon_palette.png` | #4, #6, #8, #9, #13, #17 |
| `assets/ui/menu/icon_skull.png` | #4, #6, #8, #9, #13, #17 |
| `assets/ui/menu/icon_stag.png` | #4, #6, #8, #9, #13, #17 |
| `assets/ui/menu/icon_swords.png` | #4, #6, #8, #9, #13, #17 |
| `assets/ui/menu/icon_trophy.png` | #4, #6, #8, #9, #13, #17 |
| `assets/ui/menu/icon_tunic.png` | #4, #6, #8, #9, #13, #17 |
| `assets/ui/menu/icon_wait.png` | #4, #6, #8, #9, #13, #17 |
| `assets/ui/menu/map_ember.png` | #4, #6, #8, #9, #13, #17 |
| `assets/ui/menu/map_moonlit.png` | #4, #6, #8, #9, #13, #17 |
| `assets/ui/menu/map_stonekeep.png` | #4, #6, #8, #9, #13, #17 |
| `assets/ui/menu/map_twilight.png` | #4, #6, #8, #9, #13, #17 |
| `assets/ui/menu/map_wildwood.png` | #4, #6, #8, #9, #13, #17 |
| `assets/ui/menu/panel_row.png` | #4, #6, #8, #9, #13, #17 |
| `assets/ui/menu/panel_slate.png` | #4, #6, #8, #9, #13, #17 |
| `assets/ui/menu/plaque.png` | #4, #6, #8, #9, #13, #17 |
| `assets/ui/menu/tag.png` | #4, #6, #8, #9, #13, #17 |
| `assets/ui/menu/title_bg.png` | #4, #6, #8, #9, #13, #17 |
| `assets/ui/menu/window_lead.png` | #4, #6, #8, #9, #13, #17 |
| `assets/ui/skills/shield_elf.png` | #6, #8, #9, #13 |
| `assets/ui/skills/shield_human.png` | #6, #8, #9, #13 |
| `assets/ui/store/cape_1.png` | #6, #8, #9, #13 |
| `assets/ui/store/cape_2.png` | #6, #8, #9, #13 |
| `assets/ui/store/cape_3.png` | #6, #8, #9, #13 |
| `assets/ui/store/cape_4.png` | #6, #8, #9, #13 |
| `assets/ui/store/cape_5.png` | #6, #8, #9, #13 |
| `assets/ui/store/cape_6.png` | #8 |
| `assets/ui/store/cape_7.png` | #8 |
| `assets/ui/store/cape_8.png` | #8 |
| `assets/ui/store/cape_9.png` | #8 |
| `assets/ui/store/hair_0.png` | #6, #8, #9, #13 |
| `assets/ui/store/hair_1.png` | #6, #8, #9, #13 |
| `assets/ui/store/hair_10.png` | #6, #8, #9, #13 |
| `assets/ui/store/hair_11.png` | #6, #8, #9, #13 |
| `assets/ui/store/hair_2.png` | #6, #8, #9, #13 |
| `assets/ui/store/hair_3.png` | #6, #8, #9, #13 |
| `assets/ui/store/hair_4.png` | #6, #8, #9, #13 |
| `assets/ui/store/hair_5.png` | #6, #8, #9, #13 |
| `assets/ui/store/hair_6.png` | #6, #8, #9, #13 |
| `assets/ui/store/hair_7.png` | #6, #8, #9, #13 |
| `assets/ui/store/hair_8.png` | #6, #8, #9, #13 |
| `assets/ui/store/hair_9.png` | #6, #8, #9, #13 |
| `assets/ui/store/hair_style_0.png` | #6, #8, #9, #13 |
| `assets/ui/store/hair_style_1.png` | #6, #8, #9, #13 |
| `assets/ui/store/hair_style_2.png` | #6, #8, #9, #13 |
| `assets/ui/store/hair_style_3.png` | #6, #8, #9, #13 |
| `assets/ui/store/hair_style_4.png` | #6, #8, #9, #13 |
| `assets/ui/store/hat_1.png` | #6, #8, #9, #13 |
| `assets/ui/store/hat_10.png` | #8 |
| `assets/ui/store/hat_11.png` | #8 |
| `assets/ui/store/hat_12.png` | #8 |
| `assets/ui/store/hat_2.png` | #6, #8, #9, #13 |
| `assets/ui/store/hat_3.png` | #6, #8, #9, #13 |
| `assets/ui/store/hat_4.png` | #6, #8, #9, #13 |
| `assets/ui/store/hat_5.png` | #6, #8, #9, #13 |
| `assets/ui/store/hat_6.png` | #6, #8, #9, #13 |
| `assets/ui/store/hat_7.png` | #6, #8, #9, #13 |
| `assets/ui/store/hat_8.png` | #8 |
| `assets/ui/store/hat_9.png` | #8 |
| `assets/ui/store/outfit_1.png` | #6, #8, #9, #13 |
| `assets/ui/store/outfit_2.png` | #6, #8, #9, #13 |
| `assets/ui/store/outfit_3.png` | #6, #8, #9, #13 |
| `assets/ui/store/outfit_4.png` | #6, #8, #9, #13 |
| `assets/ui/store/outfit_5.png` | #6, #8, #9, #13 |
| `assets/ui/store/outfit_6.png` | #6, #8, #9, #13 |
| `assets/ui/store/outfit_7.png` | #8 |
| `assets/ui/store/outfit_8.png` | #8 |
| `assets/ui/store/outfit_9.png` | #8 |
| `assets/ui/store/trim_0.png` | #6, #8, #9, #13 |
| `assets/ui/store/trim_1.png` | #6, #8, #9, #13 |
| `assets/ui/store/trim_10.png` | #6, #8, #9, #13 |
| `assets/ui/store/trim_11.png` | #6, #8, #9, #13 |
| `assets/ui/store/trim_2.png` | #6, #8, #9, #13 |
| `assets/ui/store/trim_3.png` | #6, #8, #9, #13 |
| `assets/ui/store/trim_4.png` | #6, #8, #9, #13 |
| `assets/ui/store/trim_5.png` | #6, #8, #9, #13 |
| `assets/ui/store/trim_6.png` | #6, #8, #9, #13 |
| `assets/ui/store/trim_7.png` | #6, #8, #9, #13 |
| `assets/ui/store/trim_8.png` | #6, #8, #9, #13 |
| `assets/ui/store/trim_9.png` | #6, #8, #9, #13 |
| `assets/ui/store/weapon_1.png` | #6, #8, #9, #13 |
| `assets/ui/store/weapon_10.png` | #8 |
| `assets/ui/store/weapon_2.png` | #6, #8, #9, #13 |
| `assets/ui/store/weapon_3.png` | #6, #8, #9, #13 |
| `assets/ui/store/weapon_4.png` | #6, #8, #9, #13 |
| `assets/ui/store/weapon_5.png` | #6, #8, #9, #13 |
| `assets/ui/store/weapon_6.png` | #6, #8, #9, #13 |
| `assets/ui/store/weapon_7.png` | #8 |
| `assets/ui/store/weapon_8.png` | #8 |
| `assets/ui/store/weapon_9.png` | #8 |
| `assets/ui/strips/arcane_bolt.png` | #6, #8, #9, #13 |
| `assets/ui/strips/backstab.png` | #6, #8, #9, #13 |
| `assets/ui/strips/ballista.png` | #6, #8, #9, #13 |
| `assets/ui/strips/barkskin.png` | #6, #8, #9, #13 |
| `assets/ui/strips/blessing.png` | #6, #8, #9, #13 |
| `assets/ui/strips/blink.png` | #6, #8, #9, #13 |
| `assets/ui/strips/bramble_burst.png` | #6, #8, #9, #13 |
| `assets/ui/strips/build_turret.png` | #6, #8, #9, #13 |
| `assets/ui/strips/bulwark.png` | #6, #8, #9, #13 |
| `assets/ui/strips/caltrops.png` | #6, #8, #9, #13 |
| `assets/ui/strips/charge.png` | #6, #8, #9, #13 |
| `assets/ui/strips/cleave.png` | #6, #8, #9, #13 |
| `assets/ui/strips/crossbow.png` | #6, #8, #9, #13 |
| `assets/ui/strips/curse.png` | #6, #8, #9, #13 |
| `assets/ui/strips/daggers.png` | #6, #8, #9, #13 |
| `assets/ui/strips/drain_bolt.png` | #6, #8, #9, #13 |
| `assets/ui/strips/ember_bolt.png` | #6, #8, #9, #13 |
| `assets/ui/strips/fae_step.png` | #6, #8, #9, #13 |
| `assets/ui/strips/fireball.png` | #6, #8, #9, #13 |
| `assets/ui/strips/flame_wave.png` | #6, #8, #9, #13 |
| `assets/ui/strips/fortify.png` | #6, #8, #9, #13 |
| `assets/ui/strips/frost_bolt.png` | #6, #8, #9, #13 |
| `assets/ui/strips/glaive.png` | #6, #8, #9, #13 |
| `assets/ui/strips/greatsword.png` | #6, #8, #9, #13 |
| `assets/ui/strips/grove_mend.png` | #6, #8, #9, #13 |
| `assets/ui/strips/hammer.png` | #6, #8, #9, #13 |
| `assets/ui/strips/heavy_bolt.png` | #6, #8, #9, #13 |
| `assets/ui/strips/holy_bubble.png` | #6, #8, #9, #13 |
| `assets/ui/strips/ice_burst.png` | #6, #8, #9, #13 |
| `assets/ui/strips/inferno.png` | #6, #8, #9, #13 |
| `assets/ui/strips/longbow.png` | #6, #8, #9, #13 |
| `assets/ui/strips/lunar_lance.png` | #6, #8, #9, #13 |
| `assets/ui/strips/mace.png` | #6, #8, #9, #13 |
| `assets/ui/strips/moonbow.png` | #6, #8, #9, #13 |
| `assets/ui/strips/overclock.png` | #6, #8, #9, #13 |
| `assets/ui/strips/piercing_shot.png` | #6, #8, #9, #13 |
| `assets/ui/strips/poison_arrow.png` | #6, #8, #9, #13 |
| `assets/ui/strips/prayer.png` | #6, #8, #9, #13 |
| `assets/ui/strips/punch.png` | #6, #8, #9, #13 |
| `assets/ui/strips/quick_blades.png` | #6, #8, #9, #13 |
| `assets/ui/strips/radiance.png` | #6, #8, #9, #13 |
| `assets/ui/strips/rapid_turret.png` | #6, #8, #9, #13 |
| `assets/ui/strips/root_maul.png` | #6, #8, #9, #13 |
| `assets/ui/strips/sanctuary.png` | #6, #8, #9, #13 |
| `assets/ui/strips/shadow_dash.png` | #6, #8, #9, #13 |
| `assets/ui/strips/shadow_step.png` | #6, #8, #9, #13 |
| `assets/ui/strips/shield_bash.png` | #6, #8, #9, #13 |
| `assets/ui/strips/shield_slam.png` | #6, #8, #9, #13 |
| `assets/ui/strips/shield_wall.png` | #6, #8, #9, #13 |
| `assets/ui/strips/sledge.png` | #6, #8, #9, #13 |
| `assets/ui/strips/smite.png` | #6, #8, #9, #13 |
| `assets/ui/strips/smoke_bomb.png` | #6, #8, #9, #13 |
| `assets/ui/strips/snipe.png` | #6, #8, #9, #13 |
| `assets/ui/strips/spanner.png` | #6, #8, #9, #13 |
| `assets/ui/strips/spirit_bloom.png` | #6, #8, #9, #13 |
| `assets/ui/strips/starfall.png` | #6, #8, #9, #13 |
| `assets/ui/strips/sword_strike.png` | #6, #8, #9, #13 |
| `assets/ui/strips/tend.png` | #6, #8, #9, #13 |
| `assets/ui/strips/thorn_bolt.png` | #6, #8, #9, #13 |
| `assets/ui/strips/thorn_totem.png` | #6, #8, #9, #13 |
| `assets/ui/strips/trap_line.png` | #6, #8, #9, #13 |
| `assets/ui/strips/tune_up.png` | #6, #8, #9, #13 |
| `assets/ui/strips/vanish.png` | #6, #8, #9, #13 |
| `assets/ui/strips/venom_fang.png` | #6, #8, #9, #13 |
| `assets/ui/strips/vigor.png` | #6, #8, #9, #13 |
| `assets/ui/strips/vine_snare.png` | #6, #8, #9, #13 |
| `assets/ui/strips/wind_dash.png` | #6, #8, #9, #13 |
| `assets/ui/topbar/topbar.png` | #6, #8, #9, #13 |
| `assets/ui/tutorial/topic_0.jpg` | #6, #8, #9, #13 |
| `assets/ui/tutorial/topic_1.jpg` | #6, #8, #9, #13 |
| `assets/ui/tutorial/topic_2.jpg` | #6, #8, #9, #13 |
| `assets/ui/tutorial/topic_3.jpg` | #6, #8, #9, #13 |
| `assets/ui/tutorial/topic_4.jpg` | #6, #8, #9, #13 |
| `assets/ui/tutorial/topic_5.jpg` | #6, #8, #9, #13 |
| `docs/CHANGELOG.md` | #6, #8, #9, #13 |
| `docs/balance/baselines-2026-10-08.md` | #6, #8, #9, #13 |
| `docs/balance/patch-1.md` | #6, #8, #9, #13 |
| `docs/balance/patch-2.md` | #6, #8, #9, #13 |
| `docs/balance/patch-3.md` | #6, #8, #9, #13 |
| `docs/balance/patch-4.md` | #6, #8, #9, #13 |
| `docs/balance/patch-5.md` | #6, #8, #9, #13 |
| `docs/balance/patch-6.md` | #8, #9, #13 |
| `docs/balance/patch-7.md` | #8, #9, #13 |
| `docs/balance/patch-8.md` | #8 |
| `docs/changelog/README.md` | #6, #8, #9, #13 |
| `docs/changelog/combat-balance.md` | #6, #8, #9, #13 |
| `docs/changelog/downed-revive.md` | #6, #8, #9, #13 |
| `docs/changelog/economy.md` | #6, #8, #9, #13 |
| `docs/changelog/file-bloat.md` | #8, #13 |
| `docs/changelog/integration-release.md` | #6, #8, #9, #13 |
| `docs/changelog/music.md` | #6, #8, #9, #13 |
| `docs/changelog/online-platforms.md` | #6, #8, #9, #13 |
| `docs/changelog/splitscreen.md` | #6, #8, #9, #13 |
| `docs/changelog/store.md` | #6, #8, #9, #13 |
| `docs/changelog/stuck-players.md` | #8, #13 |
| `docs/changelog/touch-menus.md` | #8, #13 |
| `docs/changelog/ui-art.md` | #6, #8, #9, #13 |
| `docs/changelog/visual-overhaul.md` | #8, #9, #13 |
| `docs/changelog/world-maps.md` | #6, #8, #9, #13 |
| `docs/online-plan.md` | #6, #8, #9, #13 |
| `docs/steam.md` | #8, #9, #13 |
| `docs/visual/style-spec.md` | #8, #9, #13 |
| `export_presets.cfg` | #6, #8, #9, #13, #17 |
| `project.godot` | #6, #8, #9, #13, #17 |
| `scripts/barricade.gd` | #6, #8, #9, #13 |
| `scripts/blessing.gd` | #6, #8, #9, #13 |
| `scripts/character_model.gd` | #4, #6, #8, #9, #13, #17 |
| `scripts/economy.gd` | #6, #8, #9, #13 |
| `scripts/face.gd` | #4, #6, #8, #9, #13, #17 |
| `scripts/fx.gd` | #6, #8, #9, #13 |
| `scripts/game.gd` | #4, #6, #8, #9, #13, #17 |
| `scripts/gate.gd` | #6, #8, #9, #13 |
| `scripts/guide.gd` | #6, #8, #9, #13 |
| `scripts/heal_orb.gd` | #4, #6, #8, #9, #13, #17 |
| `scripts/hud.gd` | #4, #6, #8, #9, #13, #17 |
| `scripts/match_summary.gd` | #6, #8, #9, #13, #17 |
| `scripts/menu.gd` | #4, #6, #8, #9, #13, #17 |
| `scripts/menu_stage.gd` | #4, #6, #8, #9, #13, #17 |
| `scripts/monarch.gd` | #6, #8, #9, #13 |
| `scripts/net.gd` | #6, #8, #9, #13 |
| `scripts/outfit_flair.gd` | #4, #6, #8, #9, #13, #17 |
| `scripts/projectile.gd` | #4, #6, #8, #9, #13, #17 |
| `scripts/relay_peer.gd` | #6, #8, #9, #13 |
| `scripts/resource_node.gd` | #6, #8, #9, #13 |
| `scripts/save_file.gd` | #6, #8, #9, #13 |
| `scripts/seal.gd` | #6, #8, #9, #13 |
| `scripts/sfx.gd` | #6, #8, #9, #13 |
| `scripts/skill_fx.gd` | #6, #8, #9, #13 |
| `scripts/stats.gd` | #4, #6, #8, #9, #13, #17 |
| `scripts/steam.gd` | #8, #9, #13 |
| `scripts/store.gd` | #6, #8, #9, #13 |
| `scripts/store_gear.gd` | #6, #8, #9, #13 |
| `scripts/title_diorama.gd` | #4, #6, #8, #9, #13, #17 |
| `scripts/touch.gd` | #6, #8, #9, #13, #17 |
| `scripts/trap.gd` | #6, #8, #9, #13 |
| `scripts/turret.gd` | #6, #8, #9, #13 |
| `scripts/unit.gd` | #4, #6, #8, #9, #13, #17 |
| `scripts/vault.gd` | #6, #8, #9, #13 |
| `scripts/visual/style_profile.gd` | #8, #9, #13 |
| `scripts/volcano.gd` | #4, #6, #8, #9, #13, #17 |
| `server/.gitignore` | #6, #8, #9, #13 |
| `server/Dockerfile` | #6, #8, #9, #13 |
| `server/package-lock.json` | #6, #8, #9, #13 |
| `server/package.json` | #6, #8, #9, #13 |
| `server/relay.js` | #6, #8, #9, #13 |
| `tests/combat_test.gd` | #6, #8, #9, #13 |
| `tests/fx_showcase.gd` | #6, #8, #9, #13 |
| `tools/__pycache__/make_music.cpython-313.pyc` | #6, #8, #9, #13 |
| `tools/balance/agg.py` | #6, #8, #9, #13 |
| `tools/balance/runbatch.sh` | #6, #8, #9, #13 |
| `tools/center_icons.py` | #8, #9, #13 |
| `tools/elves_green.py` | #6, #8, #9, #13 |
| `tools/frame_time_probe.gd` | #6, #8, #9, #13 |
| `tools/hitch_probe.gd` | #6, #8, #9, #13 |
| `tools/kbm_move_test.gd` | #8, #13 |
| `tools/make_banner_art.py` | #8, #13 |
| `tools/make_card_blur.py` | #6, #8, #9, #13 |
| `tools/make_econ_icons.py` | #6, #8, #9, #13 |
| `tools/make_emblems.py` | #6, #8, #9, #13 |
| `tools/make_faces.py` | #4, #6, #8, #9, #13, #17 |
| `tools/make_icons.py` | #6, #8, #9, #13 |
| `tools/make_menu_art.py` | #4, #6, #8, #9, #13, #17 |
| `tools/make_music.py` | #6, #8, #9, #13 |
| `tools/make_skill_strips.py` | #6, #8, #9, #13 |
| `tools/make_sounds.py` | #6, #8, #9, #13 |
| `tools/make_style_textures.py` | #8, #9, #13 |
| `tools/make_summary_icons.py` | #6, #8, #9, #13, #17 |
| `tools/make_textures.py` | #4, #6, #8, #9, #13, #17 |
| `tools/make_topbar.py` | #6, #8, #9, #13 |
| `tools/make_tutorial_images.py` | #6, #8, #9, #13 |
| `tools/map_switch_test.gd` | #8, #13 |
| `tools/menu_flow_test.gd` | #4, #6, #8, #9, #13, #17 |
| `tools/net_map_switch_test.gd` | #8, #13 |
| `tools/net_smoke.sh` | #6, #8, #9, #13 |
| `tools/options_menu_test.gd` | #6, #8, #9, #13 |
| `tools/perf_probe.gd` | #8, #9, #13 |
| `tools/reload_menu_test.gd` | #8, #13 |
| `tools/render_store_icons.gd` | #6, #8, #9, #13 |
| `tools/save_test.gd` | #6, #8, #9, #13 |
| `tools/slice_new_ui.py` | #6, #8, #9, #13 |
| `tools/slice_ui_v2.py` | #6, #8, #9, #13 |
| `tools/snag_scan.gd` | #8, #13 |
| `tools/steam/app_build.vdf.in` | #8, #9, #13 |
| `tools/steam/build_steam.sh` | #8, #9, #13 |
| `tools/steam/godotsteam/.gdignore` | #8, #9, #13 |
| `tools/steam/godotsteam/godotsteam.gdextension.in` | #8, #9, #13 |
| `tools/steam/godotsteam/license.txt` | #8, #9, #13 |
| `tools/steam/godotsteam/linux64/libgodotsteam.linux.template_debug.x86_64.so` | #8, #9, #13 |
| `tools/steam/godotsteam/linux64/libgodotsteam.linux.template_release.x86_64.so` | #8, #9, #13 |
| `tools/steam/godotsteam/linux64/libsteam_api.so` | #8, #9, #13 |
| `tools/steam/godotsteam/readme.md` | #8, #9, #13 |
| `tools/steam/godotsteam/win64/libgodotsteam.windows.template_debug.x86_64.dll` | #8, #9, #13 |
| `tools/steam/godotsteam/win64/libgodotsteam.windows.template_release.x86_64.dll` | #8, #9, #13 |
| `tools/steam/godotsteam/win64/steam_api64.dll` | #8, #9, #13 |
| `tools/steam/upload.bat` | #8, #9, #13 |
| `tools/steam/upload.sh` | #8, #9, #13 |
| `tools/store_menu_test.gd` | #6, #8, #9, #13 |
| `tools/store_test.gd` | #6, #8, #9, #13 |
| `tools/stuck_scan.gd` | #8, #13 |
| `tools/tests/run.sh` | #6, #8, #9, #13 |
| `tools/tex_census.gd` | #8, #13 |
| `tools/touch_close_test.gd` | #8, #13 |
| `tools/web_net_test.js` | #6, #8, #9, #13 |
| `tools/window_mode_test.gd` | #6, #8, #9, #13 |
| `tools/world_fingerprint.gd` | #8, #9, #13 |
| `tools/zfight_audit.gd` | #6, #8, #9, #13 |
