#!/usr/bin/env bash
# Builds the Steam Windows depot: build/steam/windows/ holds
#   CrownsOfTheWildwood.exe (game data embedded), the GodotSteam library and
#   steam_api64.dll. steam_appid.txt is added only with --dev (testing outside
#   the Steam client; never ship it).
#
# The GodotSteam GDExtension lives in tools/steam/godotsteam (Godot ignores
# that folder). It is copied into a temporary copy of the project for this
# export only, because a fresh `godot --import` of a project that already
# carries a GDExtension stalls in headless mode, and the other builds (the
# standalone zip, the iPad web build) do not need it.
#
# Usage: tools/steam/build_steam.sh [--dev] [--app-id=N] [out_dir]
#   GODOT=<godot 4.3 binary> (default: godot on PATH)
set -euo pipefail

GODOT="${GODOT:-godot}"
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
DEV=0
APP_ID=""
OUT=""
for a in "$@"; do
	case "$a" in
		--dev) DEV=1 ;;
		--app-id=*) APP_ID="${a#--app-id=}" ;;
		--*) echo "unknown option: $a" >&2; exit 1 ;;
		*) [ -z "$OUT" ] || { echo "only one output directory is allowed" >&2; exit 1; }; OUT="$a" ;;
	esac
done
OUT="${OUT:-$ROOT/build/steam/windows}"
[ -z "$APP_ID" ] && APP_ID="$(sed -n 's/^app_id=\([0-9]*\)$/\1/p' "$ROOT/project.godot" | head -1)"
APP_ID="${APP_ID:-0}"
if [[ ! "$APP_ID" =~ ^[1-9][0-9]*$ ]]; then
	echo "provide a positive Steam App ID with --app-id=N" >&2; exit 1
fi
if [[ "$APP_ID" == 480 && "$DEV" != 1 ]]; then
	echo "Spacewar App ID 480 is allowed only with --dev" >&2; exit 1
fi
# Resolve relative paths before changing into the temporary project. Never
# delete an existing output: it may hold the previous qualified candidate.
OUT="$(realpath -m -- "$OUT")"
if [[ -e "$OUT" || -L "$OUT" ]]; then
	echo "output already exists; choose a new directory: $OUT" >&2; exit 1
fi

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
echo "== copying the project to $WORK"
(cd "$ROOT" && git ls-files -z | xargs -0 -I{} cp --parents {} "$WORK/")
# Reuse the imported assets so the export does not re-import everything.
[ -d "$ROOT/.godot" ] && cp -r "$ROOT/.godot" "$WORK/.godot"
mkdir -p "$WORK/.godot" "$WORK/addons/godotsteam"
cp -r "$ROOT/tools/steam/godotsteam/win64" "$ROOT/tools/steam/godotsteam/linux64" \
	"$ROOT/tools/steam/godotsteam/license.txt" "$WORK/addons/godotsteam/"
cp "$ROOT/tools/steam/godotsteam/godotsteam.gdextension.in" "$WORK/addons/godotsteam/godotsteam.gdextension"
printf 'res://addons/godotsteam/godotsteam.gdextension\n' > "$WORK/.godot/extension_list.cfg"
if [ "$APP_ID" != "0" ]; then
	sed -i "s/^app_id=.*/app_id=$APP_ID/" "$WORK/project.godot"
fi

echo "== importing (app id $APP_ID)"
(cd "$WORK" && timeout 1200 "$GODOT" --headless --path . --import --editor --quit >"$WORK/import.log" 2>&1) || {
	tail -20 "$WORK/import.log"; echo "import failed"; exit 1; }
if grep -qE "SCRIPT ERROR|Parse Error" "$WORK/import.log"; then
	grep -E "SCRIPT ERROR|Parse Error" "$WORK/import.log" | head; exit 1
fi

echo "== exporting Windows Steam to $OUT"
mkdir -p -- "$(dirname "$OUT")"
mkdir -- "$OUT"
(cd "$WORK" && timeout 1200 "$GODOT" --headless --path . --export-release "Windows Steam" "$OUT/CrownsOfTheWildwood.exe" >"$WORK/export.log" 2>&1) || {
	tail -20 "$WORK/export.log"; echo "export failed"; exit 1; }
[ "$DEV" = 1 ] && [ "$APP_ID" != "0" ] && echo "$APP_ID" > "$OUT/steam_appid.txt"
ls -la "$OUT"
for f in CrownsOfTheWildwood.exe steam_api64.dll libgodotsteam.windows.template_release.x86_64.dll; do
	[ -f "$OUT/$f" ] || { echo "missing $f"; exit 1; }
done
echo "STEAM BUILD OK"
