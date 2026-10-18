# Crowns reliable events after match loading
Agent: Codex-faisal
Task: https://github.com/faisaldayes1-web/crowns-of-the-wildwood/issues/60
Branch: Codex-faisal/60-enet-events (stacked on PR61). Claim2fedc94 preceded changes; production e406591.

The host now holds each loading joiner's ordered events until that seat sends its first playing input. That signal already marks the end of loading in the existing timeout flow. Other ready peers continue to receive their own filtered events. The queue clears on leave, disconnect and new match; its 16,384-event limit disconnects a stalled peer explicitly rather than silently losing events. Existing timeout/RPC signatures, team filtering and rendering are preserved.

## Three acceptance groups
1. Delayed load: actual headless host/joiner with a25-second client match build. Before, snapshots continued while events stayed at24 in two samples five seconds apart. After, corresponding samples advanced171 to416; both peers passed movement, effects and chat checks. Chat was observed in the same sampling frame as the sent flag (not a wire-level0ms claim). Host movement testing now waits for remote input and still fails if movement never occurs.
2. Ordinary multiplayer: Moonlit and Stonekeep host/client PASS with818/819 snapshots and chat/effects present. The before-fix post-start25-second pause also recovered; the demonstrated defect is the initial loading window.
3. Clean Godot4.3 import (no script errors) and full seed7 bot match PASS: Humans1-1 at614s overtime, no engine errors. All saves isolated under C:/Temp/cw60-tests; no player save touched.

Evidence: docs/evidence/issue60/results.json and adjacent raw logs. Reproduction helper: after importing the project, run GODOT=/path/to/godot TMPDIR=/short/path bash tools/net_loading_events.sh. It uses separate disposable saves and direct log files. Bash syntax checked; its equivalent host/joiner invocation was executed for this result.

The original report's9-events-for40-seconds failure was not reproduced exactly (three ordinary baseline runs passed). Issue60 remains open for reporter confirmation; comment6255795004 requests the original logs/revision. This is a measured loading-stall repair, not a claim that every possible ENet failure is resolved. Internet, relay, three-peer, physical devices and overflow stress were not qualified. Existing online lambda/tween and shutdown resource warnings remain in the logs. No dependency changes, merge, build publication or paid generation.
