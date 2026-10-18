#!/usr/bin/env bash
# Online play on every map: for each map (0-4) a headless host and a headless
# joiner on this machine run the --net-test match (as tools/net_smoke.sh
# does), over ENet and through the room relay (server/relay.js, needs
# `npm ci` in server/ once). Prints one line per map and transport and
# exits non-zero if any fails. claude-faisallaptop 2026-10-17: the joiner runs
# in the foreground, because under Git Bash on Windows net_smoke.sh's two
# background jobs dropped the Wildwood joiner while it loaded.
#
#   tools/net_all_maps.sh                       # uses $GODOT or `godot` on PATH
#   GODOT=/path/to/godot MAPS="0 3" TRANSPORTS=enet tools/net_all_maps.sh
set -u
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
MAPS="${MAPS:-0 1 2 3 4}"
TRANSPORTS="${TRANSPORTS:-enet relay}"
OUT="${OUT:-$(mktemp -d)}"
BASE_PORT="${BASE_PORT:-24700}"
echo "net all maps: logs in $OUT"
FAIL=0
n=0
for tr in $TRANSPORTS; do
  for m in $MAPS; do
    n=$((n + 1))
    port=$((BASE_PORT + n))
    d="$OUT/${tr}_m$m"
    mkdir -p "$d"
    relay=""
    if [ "$tr" = enet ]; then
      host_args="--host=$port --map=$m"
      join_args="--join=127.0.0.1:$port"
    else
      PORT=$port node server/relay.js >"$d/relay.log" 2>&1 &
      relay=$!
      sleep 1
      url="ws://127.0.0.1:$port"
      host_args="--relay=$url --room-create --room-file=$d/room.code --map=$m"
      join_args="--relay=$url --room-join=@$d/room.code"
    fi
    "$GODOT" --headless --path . -- $host_args --net-test >"$d/host.log" 2>&1 &
    host=$!
    sleep 4
    "$GODOT" --headless --path . -- $join_args --net-test >"$d/client.log" 2>&1
    wait $host
    [ -n "$relay" ] && kill $relay 2>/dev/null
    h=$(grep -h "NETTEST host \(PASS\|FAIL\)" "$d/host.log")
    c=$(grep -h "NETTEST client \(PASS\|FAIL\)" "$d/client.log")
    errs=$(grep -h "SCRIPT ERROR" "$d/host.log" "$d/client.log" | sort | uniq -c)
    echo "map $m $tr | host: ${h:-none} | client: ${c:-none}${errs:+ | script errors: $errs}"
    case "$h$c" in *FAIL*|"") FAIL=1 ;; esac
    if [ -n "$errs" ] || ! echo "$h" | grep -q PASS || ! echo "$c" | grep -q PASS; then FAIL=1; fi
  done
done
if [ $FAIL -eq 0 ]; then
  echo "NET ALL MAPS PASS"
  exit 0
fi
echo "NET ALL MAPS FAIL"
exit 1
