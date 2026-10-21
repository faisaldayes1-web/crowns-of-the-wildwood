#!/usr/bin/env bash
# Runs Godot with a throwaway user dir, so a test that plays matches and
# saves (tools/map_switch_test.gd, tools/pad_split_test.gd) never touches the
# real save: controls.cfg, its .bak, profiles/. Arguments go to Godot as is:
#
#   tools/tests/isolated.sh --headless --path . --script tools/map_switch_test.gd -- --debug-unlock
#   GODOT=/path/to/godot tools/tests/isolated.sh --headless --path . --script tools/pad_split_test.gd
#
# Each run gets a new dir under $TMPDIR/crowns-tests/ (its path is printed).
# Nothing is ever deleted: the dirs stay, so a failed run's save can be
# inspected, and a person clears $TMPDIR/crowns-tests/ by hand whenever they
# like (the repo's rule: agents never delete). Godot reads the user dir from APPDATA on Windows,
# XDG_DATA_HOME on Linux and HOME on macOS. The wrapper marks its dir
# (.crowns-throwaway-user-dir) and exports CROWNS_TEST_USER_BASE; the tests
# (tools/tests/isolated.gd) refuse to run anywhere that is not such a dir.
# claude-faisallaptop 2026-10-18.
set -u
GODOT="${GODOT:-godot}"
parent="${TMPDIR:-/tmp}/crowns-tests"
# Godot adds "Godot/app_userdata/Crowns of the Wildwood/profiles/..." (about
# 90 characters) to the user dir; past Windows' 260-character limit Godot 4.3
# crashed before the test's guard ran. Refuse a long base up front.
probe="$parent/run-XXXXXX"
case "$(uname -s)" in MINGW*|MSYS*|CYGWIN*) probe=$(cygpath -w "$probe" 2>/dev/null || echo "$probe") ;; esac
if [ ${#probe} -gt 150 ]; then
  echo "isolated.sh: the throwaway dir would be ${#probe} characters long ($probe);" >&2
  echo "isolated.sh: set TMPDIR to a shorter folder (150 at most, with crowns-tests/run-XXXXXX)." >&2
  exit 2
fi
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
echo "isolated user dir: $native (left in place; clear $parent by hand when you like)"
exec "$GODOT" "$@"   # (exec: a timeout or kill on this script reaches Godot itself)
