---
status: PROPOSED
agent: Codex-faisal
task: CW-4
date: 2026-10-16
---
# CW-4 Release Plan — PROPOSED

Agent: Codex-faisal. This is a release checklist for review, not a release approval or a passed test report. No release date is committed. Faisal decides scope, price, platforms, spending and publication. Standing instruction: NEVER MERGE. Nothing in this plan authorizes uploads, account changes, asset generation or publication.

## 1. Evidence baseline

Codex-faisal verified [PR #31](https://github.com/faisaldayes1-web/crowns-of-the-wildwood/pull/31) is MERGED at `ce6abfcab3fe15a3682e956479983797c93c459a`, October 16, 2026, 11:22:58 PDT. This branch starts from that merge plus the already-pushed CW-4 claim `dfc4793`. Merge status establishes integration, not release quality. The Memory Brief and Task Board still contain older open-PR/version summaries; they are not current release evidence and were not edited here.

Source inspected at this baseline: `README.md`, `project.godot`, `export_presets.cfg`, `scripts/stats.gd`, `scripts/steam.gd`, `tools/steam/build_steam.sh`, `server/package.json`, `assets/CREDITS.md`, and the [CW-2 handoff](Handoffs/2026-10-16%20claude-faisallaptop%20int1.md). Sparse files were read with `git show HEAD:<path>`; absence on disk is not absence from the repository.

| Evidence | Status and limit |
|---|---|
| PR #31 merge | Independently verified by Codex-faisal using GitHub PR metadata and local Git history. |
| Import, combat self-test, map switching | Author-reported by claude-faisallaptop: no script errors, combat 0 failures, map switching 325 checks / 0 failures. Not independently reproduced by Codex-faisal. |
| Five map bot runs | Author-reported six-minute runs or earlier match completion: Wildwood 2–0 at 219s, Moonlit 0–0 at six minutes, Ember 0–2 at 200s, Stonekeep 0–2 at 234s, Twilight 1–0 at six minutes. Moonlit/Twilight runs do not prove full-match completion. |
| Batching and performance | Author-reported safety scans and renderer profiles. Four-player 1% lows reported at 26–29 fps; hardware and release thresholds must accompany fresh measurements. |
| Online/new maps, web/iPad, physical gamepads, cold shader cache | Explicitly untested in CW-2. Remain release gates; README feature descriptions are not test evidence. |
| CW-4 local import | Attempted with existing Godot `4.7.2.stable.official.ed1daf0bf`; failed validation because this docs-only sparse checkout lacks splash, autoload scripts and main scene. Import process exit 0 did not mean success. |
| CW-4 bot match | Launch attempted with README seed-7 command; main scene/autoloads missing, so no match or RESULT occurred. BLOCKED, not passed. |

The local engine differs from CW-2's reported Godot 4.3. No engine/templates/dependencies were installed, no checkout expansion performed, and no export produced. A complete candidate checkout and a pinned compatible engine are required for meaningful validation.

## 2. Platform decisions and gates

Proposed sequence: validate one Windows candidate, qualify Steam and itch separately, and qualify browser/iPad separately before advertising support. `docs/steam.md` records a Steam-first preference; Faisal must confirm the actual release sequence and scope.

| Target | Source evidence | Gate before release | Required evidence / proposed responsible role |
|---|---|---|---|
| Steam Windows x86_64 | `Windows Steam` preset; SteamHub; isolated-extension build script. `steam/app_id=0` is still a placeholder. | Actual App/depot IDs; compatible GodotSteam/runtime; account/store/build checklists; real-client launch/relaunch, overlay and all advertised achievements; tested save/cloud policy; approved price, copy and notices. No test App ID in production. | Build manifest, real-client test record, Steam review state, owner approval. Faisal handles account decisions; build/test owner to be assigned. |
| itch Windows download | `Windows Desktop` preset, embedded PCK, signing disabled. | Standalone launch without Steam; clean-machine extraction, save/restart, input and performance pass; approved signing/distribution choice; complete notices and requirements. | Hash of ZIP and executable, file list, clean-machine report; tester to be assigned. |
| Web / itch HTML5 | `Web` preset: threads/extensions off, desktop compression on, mobile compression off, PWA off. Project declares Forward Plus. | Prove actual exported renderer and shader fallback, compression/device support, HTTPS/WSS connectivity, browser storage, memory/loading, touch/audio/fullscreen and hosting behavior. Preset existence is not browser compatibility. | Desktop browser matrix plus physical iPad Safari results, export and console logs, approved hosting/relay owner. |
| Linux/macOS native / Steam Deck | No native Linux/macOS presets in inspected export configuration; Steam documentation proposes Proton. | Separate explicit scope and device qualification. | Do not claim support or Deck verification without evidence. |

Steam requires separate store-page and build/configuration checklists and review; check the actual account for outstanding timing and permission requirements before proposing a date ([Steam release process](https://partner.steamgames.com/doc/store/releasing), checked 2026-10-16). For itch HTML5, package an `index.html` and all referenced files with matching case; test the hosted iframe as well as a local export ([itch HTML5 guide](https://itch.io/docs/creators/html5), checked 2026-10-16). No hosting or upload is authorized by this document.

## 3. Reproducible build and evidence matrix

For a future authorized build, nominate a release commit SHA first; do not build from a moving branch. Use a complete clean checkout, pinned engine binary and matching export templates. Record their versions and SHA-256 hashes, OS/tool versions, export preset and renderer, extension/library versions, relay revision/configuration (no secrets), and all command arguments. Record generated inputs already tracked in Git; do not regenerate art or music implicitly.

| Candidate | Reproduction recipe after prerequisites | Evidence to retain |
|---|---|---|
| Shared import | `godot --headless --path . --import --editor --quit` | Full stdout/stderr, exit code, review for script/parse/resource errors, engine hash, commit. A zero exit code alone fails the gate. |
| Windows standalone | `godot --headless --path . --export-release "Windows Desktop" <absolute-new-output>/CrownsOfTheWildwood.exe` | Export log, executable and ZIP SHA-256, complete packaged-file inventory, notices, clean-machine launch log. |
| Steam Windows | Review and use `tools/steam/build_steam.sh --app-id=<approved-id> <new-output>` in a compatible existing Bash environment. | Script/runtime/template hashes, import/export logs retained outside its temporary directory, EXE and both required DLL hashes; verify no `steam_appid.txt` in shipping files. |
| Web | `godot --headless --path . --export-release "Web" <absolute-new-output>/index.html` | Hash each HTML/JS/WASM/PCK and support file, ZIP hash, renderer/configuration, browser/device versions, network/console logs. |

The Steam script copies tracked files into a temporary project, includes the GodotSteam extension and removes its selected output directory before building. It also writes `.godot/extension_list.cfg` and relies on a usable import cache. A future build owner must review those assumptions, use a new disposable output path, preserve logs, and record any approved tooling fix separately. Do not run this script casually against an existing output directory. CW-4 did not execute it.

Rebuild the same SHA with the same inputs in a second clean environment and compare file hashes; investigate differences and document whether artifacts are byte-identical or only functionally reproducible. Do not promise deterministic binaries before that comparison. Archive the exact tested candidate and previous approved package for recovery. Any later code, asset, preset or dependency change invalidates affected evidence.

Each result record must contain: test ID, agent/tester, timestamp, commit, artifact hash, engine/templates, OS/device/GPU/driver, renderer/resolution/quality, input devices, seed/map/player count, cache state, command/steps, expected versus actual result, log/screenshot links and PASS/FAIL/BLOCKED. Missing evidence means BLOCKED. Credentials and personal data stay out of logs.

## 4. Acceptance test pass — all pending on release candidate

Proposed roles below are responsibilities to assign, not new claims on another agent's work. Runtime tester performs the pass; build owner supplies immutable artifacts; Faisal approves scope and performance targets. Every shipped platform must pass its applicable rows. Deferring a feature requires an explicit scope decision and truthful store copy, plus separately authorized implementation work if disabling it is needed.

| ID | Test and acceptance condition | Coverage / evidence |
|---|---|---|
| T01 | Import/export has no script, parse or missing-resource errors; packaged game boots without editor or development dependencies. | All candidates, clean machine; full logs. |
| T02 | Headless seeded bot match completes with `RESULT` and sane `STAT` output; no script errors or stuck objective progress. | All five maps (`--map=0..4`), seed 7 plus another recorded seed; run to result, not merely six minutes. Baseline recipe: `godot --headless --path . --fixed-fps 60 --quit-after 45000 -- --demo --seed=7 --map=0`. |
| T03 | Fortify transitions to fight; capture/return/drop, gates, hats/classes, death/revive, scoring, timeout/overtime, summary and rematch obey source rules. | Manual play both factions; source has two captures, 600s clock, 120s overtime. Combat self-test supplements rather than replaces manual results. |
| T04 | All maps load, unlock behavior matches approved design, and repeated switching/rematches do not leak state or break navigation. | `tools/map_switch_test.gd`, five maps, repeated sessions; include seasonal maps sharing Wildwood layout. |
| T05 | Menu, settings, controls rebinding, save/restart, account unlocks, economy/store progression and upgrade behavior persist correctly. | New and existing profiles; recovery from invalid settings; no debug unlocks in shipping copy. |
| T06 | Keyboard/mouse and real Xbox/PlayStation controllers complete title-to-match-to-rematch; join/leave/reconnect, focus, prompts and independent controls work. | Physical 1/2/3/4-player couch versus/co-op where supported. Idle simulated players do not satisfy this row. |
| T07 | Host/join/mid-match join, leaving to bot takeover, map switch, disconnect/host loss and failure messaging work on every advertised online target. | ENet and relay separately, all five maps, two machines/browsers; existing `tools/net_smoke.sh`, `tools/net_map_switch_test.gd`, `tools/web_net_test.js` plus manual observation. Confirm relay availability, latency behavior and operating responsibility; do not assume the README endpoint is healthy. |
| T08 | Browser plays a complete match and persists intended progress; loading errors are recoverable; touch menus, audio activation, landscape/fullscreen, resume and memory use are acceptable. | Current Chrome/Edge desktop and actual iPad Safari; record exact versions/device. Private mode/storage failure and interrupted network; HTTPS-hosted iframe after separate hosting authorization. |
| T09 | Renderer is visually correct and meets approved frame-time/load-time targets at stated requirements. | All five maps, 1 and 4 local players, warm and genuinely cold shader cache. Use `tools/match_profile.gd` and batching safety checks. Record mean FPS, 1% lows, hitch counts, memory and load time. Proposed target for discussion: 60 fps solo and at least 30 fps four-player 1% low at the declared minimum setup; not approved. Reported 26–29 fps lows do not establish this proposed target. |
| T10 | Steam production App ID initializes, overlay behavior is correct, achievements credit the local host/joiner correctly, and agreed save/cloud behavior survives restart/conflict/offline use. | Real Steam client and approved test configuration; headless SteamHub explicitly skips initialization, so headless passes cannot cover this. |
| T11 | Credits/notices ship and can be found; supported-feature claims match observed behavior; HUD is readable at supported resolutions; audio/shake settings and non-color team cues are checked. | Every package, store copy and screenshot review. No unsupported accessibility or compatibility labels. |

Release acceptance requires all in-scope rows PASS with evidence, no unresolved crash/data-loss/progression blockers, documented remaining defects accepted by Faisal, and separate written publication approval identifying platform, candidate hashes, price, date and store assets. Documentation approval or PR merge is not that approval.

## 5. Store copy and screenshot package — PROPOSED

Short description draft (publish only after applicable gameplay tests):

> Raid the rival castle, steal its monarch and bring them home. Lead Elves or Humans through a bright woodland battlefield, switch classes and defend your own crown in a fast-moving capture contest.

Long description outline: explain the crown objective, class switching and team tactics; describe five selectable environments without calling the winter/dusk variants wholly new layouts; explain bots and progression. Add couch player counts, online rooms, browser/iPad support, Steam achievements and Cloud only after the corresponding tests pass. Do not promise a fixed ten-minute total match because overtime exists. Avoid comparisons implying another game's branding, affiliation or licensed art. Price, release date, languages, minimum/recommended hardware and support contact remain owner decisions backed by testing.

Proposed capture list: (1) clear crown capture, (2) both teams fighting with readable HUD, (3) castle/class interaction, (4) Ember Pass objective, (5) a seasonal environment, (6) genuine local split-screen after physical-pad validation. Capture the tested release candidate, record settings/version and show representative gameplay without debug overlays or fabricated scenes. Existing `docs/screenshots/int1/` images are integration evidence; before/after composites are not automatically store-ready screenshots. Check for reference-derived art clearance before using it in any marketing.

Prepare capsules, library assets, logo and achievement icons only after Faisal approves the art/provenance and current storefront specifications are checked. `docs/steam.md` is a starting inventory, not a guarantee its dimensions remain current. No images were created or purchased for CW-4.

## 6. Credits and licence audit gaps

This is an inventory of unresolved evidence, not a legal clearance. `assets/CREDITS.md` exists in Git but is omitted from this sparse checkout. Its opening “All of these are CC0” conflicts with its own Apache-2.0/OFL font entries. Have the authorized asset owner reconcile it before shipping; CW-4 does not edit assets.

| Asset/dependency group | Existing statement / evidence | Release gap to close |
|---|---|---|
| Six KayKit packs and recoloured derivatives | Credits name packs/versions and CC0; original palettes/derivatives described. | Retain pack-specific source/download and licence evidence, map every shipped model/texture to a pack, check extra/unlisted assets. A general author URL is not a file-level audit. |
| Luckiest Guy; Lilita One in both font directories | Apache 2.0 and OFL 1.1 named; licence paths are tracked. | Review exact licence texts and ensure required notices survive export and appear in distributed notices; correct blanket CC0 wording. |
| Owner-supplied logo/cards | “Own” art asserted in credits. | Record creator, source, commercial redistribution/marketing permission and any generation provenance; ownership assertion alone is incomplete evidence. |
| `assets/ui/skills/`, scoreboard faces, `assets/ui/topbar/topbar.png` | Explicitly cut from owner-supplied reference art. | Priority blocker: identify original rights holder and permission for shipped derivatives, or obtain separately authorized replacement work. Supplying a reference does not establish redistribution rights. |
| Procedural textures/icons/menu art/sounds | Scripts/original renders cited. | Inventory script inputs, fonts, source imagery and authorship; confirm no unidentified reference pixels or sampled material. |
| Music / VSCO 2 CE | Credits identify composed music rendered from CC0 samples, with upstream repository. | Preserve exact sample-library licence/version and composition provenance; reconcile README's broad synthesized-sound description with sampled-instrument music. |
| Godot, GodotSteam, Steam redistributables | Engine dependency; extension licence tracked under `tools/steam/godotsteam/license.txt`. | Build a packaged third-party notices inventory and confirm redistribution terms/version compatibility for actual binaries. Steam-specific content belongs only in its approved package. |
| Relay and `ws` 8.18.0 | `server/package.json` declares dependency and Node >=18. | Record deployed dependency inventory/licences, operator, privacy/logging/support policy and service costs if online ships. No install or relay deployment performed here. |

Acceptance: no shipped file with unknown provenance; reviewed licences and notices included in final package; reference-derived art cleared or replaced through separate work; marketing assets covered too. Assign audit owner and record evidence links rather than treating this checklist as clearance.

## 7. Age rating and content review

Faisal or an authorized publishing owner must review the actual release build and complete Steam's Content Survey before submitting store/build for review. The survey covers general and mature content and generates some regional ratings; existing official ratings can be recorded separately ([Steam Content Survey](https://partner.steamgames.com/doc/gettingstarted/contentsurvey), checked 2026-10-16). Do not invent an ESRB/PEGI age or label this game rated merely because it has cartoon art.

Prepare a content inventory with evidence of combat, downed/finisher behavior, death, weapons, text, chat/online interaction, progression/store mechanics and any purchased currency or randomized rewards actually present. Review all shipped content, including inaccessible files. Answer AI-content questions from the completed provenance audit, not assumptions about generation. Confirm target territories and any additional rating or disclosure steps in each storefront's current workflow; Steam outcomes are not assumed to transfer to itch/web. Retain submitted answers, resulting ratings/descriptors, date and reviewer, and recheck after content changes. No survey was submitted in CW-4.

## 8. Decisions and handoff

Decisions for Faisal, recorded here within the authorized CW-4 ownership scope:

- Confirm launch platforms/order, online inclusion, release version, price and date window; no public commitment yet.
- Assign build/test and asset-audit owners; choose pinned engine/templates and minimum hardware/performance thresholds.
- Resolve reference-art provenance and approve any replacement work separately.
- Confirm Steam account/App/depot readiness, achievements and Cloud scope; identify relay/hosting owner and support costs.
- Decide Stonekeep/Twilight unlock rules and disposition of #4's three castle commits reported outside #31; do not treat this plan as approval to integrate them.
- Approve the completed evidence package, store assets and rating submissions before separately authorizing publication. Codex-faisal will not merge.

Next authorized task should be candidate qualification on a complete checkout. Coordinator may reconcile older Memory/Task Board summaries from the signed handoff. CW-4 only changes this plan, Codex-faisal's own board row and its signed handoff.

## Superseding candidate evidence — 2026-10-18

Agent: Codex-faisal2. Owner transferred #33 in comment 6245577956. Historical baseline above remains dated, not the current release candidate. Current main f2364c15f8b8c2d0bf1d54b81b049ed33b82f399 was integrated locally without textual conflicts.

Claude 2's RC1 handoff now exists at docs/agents/Handoffs/2026-10-16 claude-faisallaptop rc1.md: Windows Desktop export of ce6abfc, Godot 4.3, embedded PCK, local build/rc1/CrownsOfTheWildwood.exe, screenshots from that executable in docs/screenshots/rc1/. It reports zero export errors and five map bot runs; Moonlit ended 2–0 at 192 seconds and the other four ran six minutes. Those are attributed results, not an independent pass and not evidence for later source. Steam, web, another machine, real pads and online remain explicitly untested in RC1.

Use that existing candidate for its recorded scope; do not claim its binary matches current main or rebuild merely to refresh documentation. A new candidate requires an exact source SHA, engine/template version, executable/archive hashes and applicable test evidence. Existing screenshots do not close later-version gameplay gates. No release approval, paid work or publication is inferred.

This replacement stays on local private branch codex/t4-cw33. Public repository prevents a private PR update under the current instruction; no push or public issue note was made.

Signed: Codex-faisal2.

### Push authorization — 2026-10-18

Agent: Codex-faisal2. Faisal, relayed in this chat by the hub: “Yes: Codex-faisal2 may push its PR updates and issue notes to the existing public crowns-of-the-wildwood and chief-auto repos. Normal PR work only; nothing else becomes public.” This supersedes the local-only hold above. Only this existing PR branch and signed issue note are being updated; no release, build upload or new repository.
