#!/usr/bin/env bash
# Codex-faisal: real host/joiner regression for reliable events after slow loading.
# GODOT=/path/to/godot TMPDIR=/short/path bash tools/net_loading_events.sh
# Each process gets a separate disposable save via the existing isolation wrapper.
# Nothing is removed. Keep stdout/stderr in files, not pipes.
set -u
cd "$(dirname "$0")/.."
export GODOT="${GODOT:-godot}"
STALL="${STALL:-25}"
PORT="${PORT:-25020}"
case "$STALL" in ''|*[!0-9]*) echo 'STALL must be an integer from 0 to 120'; exit 2 ;; esac
if [ "${#STALL}" -gt 3 ]; then echo 'STALL must be at most 120 seconds'; exit 2; fi
STALL=$((10#$STALL))
if [ "$STALL" -gt 120 ]; then echo 'STALL must be at most 120 seconds'; exit 2; fi
OUT="${OUT:-$(mktemp -d)}"
mkdir -p "$OUT"
hold=$((STALL + 55))
bash tools/tests/isolated.sh --headless --path . --script tools/net_event_probe.gd -- \
  --host="$PORT" --map=3 --net-test --net-test-hold="$hold" > "$OUT/host.log" 2>&1 &
host=$!
sleep 4
bash tools/tests/isolated.sh --headless --path . --script tools/net_event_probe.gd -- \
  --join="127.0.0.1:$PORT" --net-test --debug-slow-build="$STALL" \
  --event-latency-limit-ms=2000 > "$OUT/client.log" 2>&1
client_result=$?
wait "$host"
host_result=$?
printf 'host exit=%s client exit=%s\n' "$host_result" "$client_result" > "$OUT/results.txt"
if [ "$host_result" -ne 0 ] || [ "$client_result" -ne 0 ] \
  || ! grep -q 'NETTEST host PASS' "$OUT/host.log" \
  || ! grep -q 'NETTEST client PASS' "$OUT/client.log" \
  || ! grep -q 'EVENT_PROBE chat echo latency_ms=' "$OUT/client.log" \
  || grep -q 'SCRIPT ERROR\|EVENT_PROBE FAIL' "$OUT/host.log" "$OUT/client.log"; then
  echo "NET LOADING EVENTS FAIL: $OUT"
  exit 1
fi
echo "NET LOADING EVENTS PASS: $OUT (local transport only; inspect retained engine warnings)"
