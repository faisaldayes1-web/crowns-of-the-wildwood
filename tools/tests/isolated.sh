#!/usr/bin/env bash
# Runs Godot with a throwaway user dir, so a test that plays matches and
# saves (tools/map_switch_test.gd, tools/pad_split_test.gd) never touches the
# real save: controls.cfg, its .bak, profiles/. Arguments go to Godot as is:
#
#   tools/tests/isolated.sh --headless --path . --script tools/map_switch_test.gd -- --debug-unlock
#   GODOT=/path/to/godot tools/tests/isolated.sh --headless --path . --script tools/pad_split_test.gd
#
# Each run gets a new dir under $TMPDIR/crowns-tests/ (its path is printed),
# left in place so a failed run's save can be inspected; delete that one
# folder whenever you like. CROWNS_TEST_CLEAN=1 removes this run's own dir
# after Godot exits with 0. Godot reads the user dir from APPDATA on Windows,
# XDG_DATA_HOME on Linux and HOME on macOS. The wrapper marks its dir
# (.crowns-throwaway-user-dir) and exports CROWNS_TEST_USER_BASE; the tests
# (tools/tests/isolated.gd) refuse to run anywhere that is not such a dir.
# claude-faisallaptop 2026-10-18.
set -u
GODOT="${GODOT:-godot}"
parent="${TMPDIR:-/tmp}/crowns-tests"
mkdir -p "$parent"
dir=$(mktemp -d "$parent/run-XXXXXX")
: > "$dir/.crowns-throwaway-user-dir"
native="$dir"
case "$(uname -s)" in
  MINGW*|MSYS*|CYGWIN*)
    native=$(cygpath -w "$dir")
    export APPDATA="$native"
    ;;
  Darwin)
    export HOME="$dir"
    ;;
  *)
    export XDG_DATA_HOME="$dir"
    ;;
esac
export CROWNS_TEST_USER_BASE="$native"
echo "isolated user dir: $native"
if [ "${CROWNS_TEST_CLEAN:-0}" != 1 ]; then
  exec "$GODOT" "$@"   # (exec: a timeout or kill on this script reaches Godot itself)
fi
"$GODOT" "$@"
code=$?
if [ $code -eq 0 ] && [ -f "$dir/.crowns-throwaway-user-dir" ]; then
  rm -rf "$dir"   # only this run's own marked dir, and only when asked
fi
exit $code
