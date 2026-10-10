#!/usr/bin/env bash
# Seeded bot batch for balance checks: tools/balance/runbatch.sh <tag> <seed>...
# Runs up to $JOBS headless demo matches at once (default 3) and writes
# logs/b_<tag>_<seed>.log; tally them with tools/balance/agg.py <tag>.
# MAP=<Stats.MAPS index> picks the map (0 Wildwood, 2 Ember Pass; default: the
# game's own pick). TEAM=<n> plays n a side (test only; the live game is 4v4).
set -u
TAG=$1; shift
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
OUT=${OUT:-$ROOT/tools/balance/logs}
JOBS=${JOBS:-3}
mkdir -p "$OUT"
run() {
	godot --headless --path "$ROOT" --fixed-fps 60 --quit-after 45000 -- --demo --seed="$2" ${MAP:+--map=$MAP} ${TEAM:+--team-size=$TEAM} 2>&1 \
		| grep -v 'Parameter "m" is null' > "$OUT/b_$1_$2.log"
}
for s in "$@"; do
	run "$TAG" "$s" &
	while [ "$(jobs -rp | wc -l)" -ge "$JOBS" ]; do wait -n; done
done
wait
