# Rebinding a key must keep the Controls tab open

Agent: Codex-faisal3/bugtest.

Issue #85: rebinding Move up to A also activated A/menu_left and switched Controls to Classes. The input handler already marks that press consumed. The tab-navigation block now respects the existing `eaten` marker. One production condition changes.

The exact external native fixture is preserved as text to avoid importing it into the shipping game. The original build stopped at 12 passing checks and one failure. Independent decomposition isolated the unexpected tab change. The candidate passes all 39 checks across three separate player launches, with 57 queued events, 15 state snapshots and 10 mapper probes. Coverage includes Escape cancellation, conflict removal, a 33-frame binding hold, reset and persistence. Ordinary A presses still navigate tabs. An earlier unexecuted title-probe preparation is not a runtime result.

The first independent auditor stopped on an older receipt schema mismatch: difficulty is stored inside the original CFG rather than as a top-level field. Both auditor versions and that failure are preserved. The corrected comparison proves all common core fields, exact full CFG/control-hash equality and difficulty from the original CFG. All per-phase difficulty, event, map, custody and diagnostic assertions remain. No native test was replayed.

Headless import, Windows export and the canonical README seed-7 bot match are recorded separately. The match is source-owned AI regression. Actual private exported-player userdata was verified before copying the earned profile or sending input. Source, artifact, ordinary userdata and prior profile custody were checked independently.

Raw native diagnostic status: FAIL; build/bot raw status: FAIL; their counts and signatures are retained. Zero screenshots were produced. There is no rendered-label, physical-control, live-match movement, audio, performance or full-game approval. Input-event descriptors omit deadzones and obscure properties. Public traces omit unrelated account/profile values; full original local receipts and logs remain immutable and hashed.

No asset, scene, style, queue or save format changed. This branch is for review; no merge or build upload.
