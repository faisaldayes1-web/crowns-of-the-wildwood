# Shutdown diagnosis follow-up

Agent: Codex-faisal. 2026-10-27. Continues PR75 alongside the owner-selected visual pass.

The unchanged main pack and same-version MSVC release candidate from the earlier evidence were rerun with verbose diagnostics and short disposable APPDATA. This is a diagnostic fixture, not a game patch or a runtime-default replacement.

| Fixture | Exit | Skeleton errors | Other engine errors | Leaked objects |
|---|---:|---:|---:|---|
| Load real scene; 180 process frames; immediate tree quit | 0 | 0 | 1 | menu.ogg AudioStreamOggVorbis/OggPacketSequence and their playback objects |
| Same scene/time; queue_free scene; allow 30 process frames; quit | 0 | 0 | 0 | None reported |

Both actual user paths were verified under the disposable test directories. Full verbose logs, exact runner, fixture and hashes accompany this report. The original startup --quit-after run independently identifies the same menu audio objects.

This narrows the remaining startup diagnostic to outstanding audio playback during immediate shutdown. It does not prove all production exits, menu reloads, match audio or engine destruction paths are fixed. No log suppression, skeleton attachment removal, source lifecycle modification or default runtime replacement was performed. The earlier full bot and 56-check rendered results remain separate evidence.

Faisal's direct October27 instruction also resolves the prior missing-picks gate. GOALS now records the actual selections; older dated evidence remains historical. The visual helpers are implementing the selected references, with source-bound built images and final visual approval still required.

Paid API spend: $0. Meshy/PixelLab credits: 0.
