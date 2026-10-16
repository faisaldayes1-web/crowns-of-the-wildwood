#!/usr/bin/env bash
# Headless combat checks: tools/tests/run.sh  (exit code = number of failures)
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
godot --headless --path "$ROOT" --fixed-fps 60 --quit-after 3000 -- --demo --selftest 2>&1 \
	| grep -v 'Parameter "m" is null' | grep -E 'TEST|SCRIPT ERROR|ERROR:' 
exit "${PIPESTATUS[0]}"
