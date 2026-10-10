#!/usr/bin/env bash
# Online smoke test: a headless host and a headless joiner on this machine.
# The host waits for the joiner, starts a match, both walk their player for
# 1.5 s, and each side checks that its own unit, the other player's unit and
# the bots all moved. Passes only if both sides print NETTEST ... PASS.
#
# Runs twice by default: over ENet (direct IP) and through the room relay
# (server/relay.js, started here with node). TRANSPORT=enet or relay runs one.
#
#   tools/net_smoke.sh                 # uses $GODOT or `godot` on PATH
#   GODOT=/path/to/godot TRANSPORT=relay tools/net_smoke.sh
#   RELAY_URL=wss://... TRANSPORT=relay tools/net_smoke.sh   # against a hosted relay
set -u
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
PORT="${PORT:-24577}"
RELAY_PORT="${RELAY_PORT:-8797}"
TRANSPORT="${TRANSPORT:-both}"
OUT="${OUT:-$(mktemp -d)}"
mkdir -p "$OUT"
echo "net smoke: logs in $OUT"

run_pair() {  # $1 = name, $2 = host args, $3 = client args
  local name=$1
  "$GODOT" --headless --path . -- $2 --net-test >"$OUT/$name-host.log" 2>&1 &
  local host=$!
  sleep 2
  "$GODOT" --headless --path . -- $3 --net-test >"$OUT/$name-client.log" 2>&1 &
  local client=$!
  wait $client; local c=$?
  wait $host; local h=$?
  grep -h "^NET" "$OUT/$name-host.log" | sed "s/^/$name host   | /"
  grep -h "^NET" "$OUT/$name-client.log" | sed "s/^/$name client | /"
  local errs
  errs=$(grep -h "SCRIPT ERROR" "$OUT/$name-host.log" "$OUT/$name-client.log" | sort | uniq -c)
  [ -n "$errs" ] && { echo "$name script errors:"; echo "$errs"; }
  if [ $h -eq 0 ] && [ $c -eq 0 ] && grep -q "NETTEST host PASS" "$OUT/$name-host.log" \
      && grep -q "NETTEST client PASS" "$OUT/$name-client.log" && [ -z "$errs" ]; then
    echo "$name: PASS"
    return 0
  fi
  echo "$name: FAIL (host exit $h, client exit $c)"
  return 1
}

FAIL=0
if [ "$TRANSPORT" = both ] || [ "$TRANSPORT" = enet ]; then
  run_pair enet "--host=$PORT" "--join=127.0.0.1:$PORT" || FAIL=1
fi
if [ "$TRANSPORT" = both ] || [ "$TRANSPORT" = relay ]; then
  rm -f "$OUT/room.code"
  RELAY=""
  if [ -n "${RELAY_URL:-}" ]; then
    URL="$RELAY_URL"   # a hosted relay, e.g. RELAY_URL=wss://crowns-of-the-wildwood.onrender.com
    : >"$OUT/relay.log"
  else
    [ -d server/node_modules ] || (cd server && npm install --no-audit --no-fund >/dev/null)
    PORT=$RELAY_PORT node server/relay.js >"$OUT/relay.log" 2>&1 &
    RELAY=$!
    sleep 1
    URL="ws://127.0.0.1:$RELAY_PORT"
  fi
  run_pair relay "--relay=$URL --room-create --room-file=$OUT/room.code" "--relay=$URL --room-join=@$OUT/room.code" || FAIL=1
  [ -n "$RELAY" ] && kill $RELAY 2>/dev/null
  sed 's/^/relay server | /' "$OUT/relay.log"
fi
if [ $FAIL -eq 0 ]; then
  echo "NET SMOKE PASS"
  exit 0
fi
echo "NET SMOKE FAIL"
exit 1
