#!/usr/bin/env bash
# A joiner who joins a match already running, on a slow machine, keeps its
# link (review of #57: the host dropped such a joiner 60 s into its match
# start). A headless host holds a match on Ember Pass (--net-test-hold),
# joiner A plays it from the start, then joiner B joins mid-match and stalls
# its own match start by STALL seconds (--debug-slow-build). Passes when B is
# seated, its match runs, and the host keeps B's link until B's test ends.
# Each Godot gets its own throwaway user dir (APPDATA, XDG_DATA_HOME, HOME),
# so no real save is touched. Takes about 8 minutes.
# claude-faisallaptop 2026-10-18.
#
#   tools/net_midjoin.sh                    # uses $GODOT or `godot` on PATH
#   GODOT=/path/to/godot STALL=100 MAP=2 tools/net_midjoin.sh
set -u
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
STALL="${STALL:-100}"
MAP="${MAP:-2}"
PORT="${PORT:-24790}"
OUT="${OUT:-$(mktemp -d)}"
echo "net midjoin: stall ${STALL}s, map $MAP, logs in $OUT"
mkdir -p "$OUT/uh" "$OUT/ua" "$OUT/ub"

userdir() {
  # One throwaway user dir for one Godot, whatever the OS.
  local d="$1"
  local w="$d"
  command -v cygpath >/dev/null 2>&1 && w=$(cygpath -w "$d")
  echo "APPDATA=$w XDG_DATA_HOME=$d HOME=$d"
}

# Every Godot writes straight to its own log file. (Not through a pipe: a
# joiner's world build logs ~21,000 lines of headless-renderer errors, and
# under Git Bash on Windows each piped write waited, so the joiner sat
# blocked on its output for 3-4 minutes and timed out; with a file it builds
# in about 25 s. claude-faisallaptop 2026-10-18.) A watcher notes the second
# when B's test ends and when the host drops B.
env $(userdir "$OUT/uh") "$GODOT" --headless --path . -- --host=$PORT --map=$MAP --net-test --net-test-hold=400 >"$OUT/host.log" 2>&1 &
host=$!
sleep 4
env $(userdir "$OUT/ua") "$GODOT" --headless --path . -- --join=127.0.0.1:$PORT --net-test >"$OUT/a.log" 2>&1 &
for i in $(seq 1 240); do
  grep -q "NETTEST host: match running" "$OUT/host.log" 2>/dev/null && break
  sleep 1
done
sleep 5
t_join=$(date +%s)
env $(userdir "$OUT/ub") "$GODOT" --headless --path . -- --join=127.0.0.1:$PORT --net-test --debug-slow-build=$STALL >"$OUT/b.log" 2>&1 &
b=$!
t_end="" t_left="" t_ready=""
while kill -0 $host 2>/dev/null; do
  now=$(date +%s)
  # B's peer id is the second "connected" on the host.
  bid=$(grep -oE "NET peer [0-9]+ connected" "$OUT/host.log" | sed -n 2p | grep -oE "[0-9]+")
  [ -z "$t_ready" ] && [ -n "$bid" ] && grep -q "NET peer $bid ready" "$OUT/host.log" && t_ready=$now
  [ -z "$t_left" ] && [ -n "$bid" ] && grep -q "NET peer $bid left" "$OUT/host.log" && t_left=$now
  [ -z "$t_end" ] && grep -qE "NETTEST client (PASS|FAIL)" "$OUT/b.log" && t_end=$now
  sleep 1
done
wait

slot=$(grep -c "NET slot:" "$OUT/b.log")
running=$(grep -c "NETTEST client: match running" "$OUT/b.log")
errs=$(grep -h "SCRIPT ERROR" "$OUT/host.log" "$OUT/b.log" "$OUT/a.log" | sort | uniq -c)
rel() { [ -n "$1" ] && echo "$(( $1 - t_join )) s" || echo never; }
echo "B (after it joined): built and ready $(rel "$t_ready") | seated: $slot | match running: $running | test ended $(rel "$t_end") | host dropped B $(rel "$t_left")"
grep -hE "NETTEST client (PASS|FAIL)" "$OUT/b.log"
[ -n "$errs" ] && echo "script errors: $errs"
# The host may log B leaving once B's own test has quit (a second or two).
if [ "$slot" -ge 1 ] && [ "$running" -ge 1 ] && [ -n "$t_end" ] && [ -z "$errs" ] \
    && { [ -z "$t_left" ] || [ "$t_left" -ge $((t_end - 2)) ]; }; then
  echo "NET MIDJOIN PASS"
  exit 0
fi
echo "NET MIDJOIN FAIL"
exit 1
