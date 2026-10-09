#!/usr/bin/env bash
# Online smoke test: a headless host and a headless joiner on this machine.
# The host waits for the joiner, starts a match, both walk their player for
# 1.5 s, and each side checks that its own unit, the other player's unit and
# the bots all moved. Passes only if both sides print NETTEST ... PASS.
#
#   tools/net_smoke.sh                 # uses $GODOT or `godot` on PATH
#   GODOT=/path/to/godot tools/net_smoke.sh
set -u
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
PORT="${PORT:-24577}"
OUT="${OUT:-$(mktemp -d)}"
mkdir -p "$OUT"
echo "net smoke: logs in $OUT"
"$GODOT" --headless --path . -- --host="$PORT" --net-test >"$OUT/host.log" 2>&1 &
HOST=$!
sleep 2
"$GODOT" --headless --path . -- --join="127.0.0.1:$PORT" --net-test >"$OUT/client.log" 2>&1 &
CLIENT=$!
wait $CLIENT; C=$?
wait $HOST; H=$?
grep -h "^NET" "$OUT/host.log" | sed 's/^/host   | /'
grep -h "^NET" "$OUT/client.log" | sed 's/^/client | /'
ERRS=$(grep -h "SCRIPT ERROR" "$OUT/host.log" "$OUT/client.log" | sort | uniq -c)
[ -n "$ERRS" ] && { echo "script errors:"; echo "$ERRS"; }
if [ $H -eq 0 ] && [ $C -eq 0 ] && grep -q "NETTEST host PASS" "$OUT/host.log" && grep -q "NETTEST client PASS" "$OUT/client.log" && [ -z "$ERRS" ]; then
  echo "NET SMOKE PASS"
  exit 0
fi
echo "NET SMOKE FAIL (host exit $H, client exit $C)"
exit 1
