#!/usr/bin/env bash
# Runs Godot with a throwaway user dir, so a test that plays matches and
# saves (tools/map_switch_test.gd, tools/pad_split_test.gd) never touches the
# real save: controls.cfg, its .bak, profiles/. Arguments go to Godot as is:
#
#   tools/tests/isolated.sh --headless --path . --script tools/map_switch_test.gd -- --debug-unlock
#   GODOT=/path/to/godot tools/tests/isolated.sh --headless --path . --script tools/pad_split_test.gd
#
# The dir is a new mktemp dir each run and is left in place (its path is
# printed) so a failed run's save can be inspected. Godot reads the user dir
# from APPDATA on Windows, XDG_DATA_HOME on Linux and HOME on macOS; the
# tests check CROWNS_TEST_USER_BASE (tools/tests/isolated.gd) and refuse to
# run anywhere else. claude-faisallaptop 2026-10-18.
set -u
GODOT="${GODOT:-godot}"
dir=$(mktemp -d "${TMPDIR:-/tmp}/crowns-test-XXXXXX")
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
exec "$GODOT" "$@"
