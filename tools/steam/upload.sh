#!/usr/bin/env bash
# Uploads build/steam/windows to Steam with steamcmd (it does not go live:
# Faisal sets the build live on a branch in Steamworks > SteamPipe > Builds).
#
# Usage: STEAM_USER=<steam login> tools/steam/upload.sh <app_id> [depot_id] [--preview]
#   depot_id defaults to app_id + 1 (Steamworks' first depot).
#   --preview checks the files without uploading.
# steamcmd asks for the password and Steam Guard code the first time.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
APP_ID="${1:?app id}"; shift
DEPOT_ID="$APP_ID"; DEPOT_ID=$((APP_ID + 1)); PREVIEW=0
for a in "$@"; do
	case "$a" in
		--preview) PREVIEW=1 ;;
		*) DEPOT_ID="$a" ;;
	esac
done
: "${STEAM_USER:?set STEAM_USER to the Steamworks account login}"
CONTENT="$ROOT/build/steam/windows"
[ -f "$CONTENT/CrownsOfTheWildwood.exe" ] || { echo "run tools/steam/build_steam.sh --app-id=$APP_ID first"; exit 1; }
OUT="$ROOT/build/steam/output"; mkdir -p "$OUT"
VDF="$ROOT/build/steam/app_build_$APP_ID.vdf"
DESC="$(git -C "$ROOT" describe --always --dirty) $(date -u +%Y-%m-%d)"
sed -e "s|@APP_ID@|$APP_ID|" -e "s|@DEPOT_ID@|$DEPOT_ID|" -e "s|@DESC@|$DESC|" \
	-e "s|@CONTENT_ROOT@|$CONTENT|" -e "s|@BUILD_OUTPUT@|$OUT|" -e "s|@PREVIEW@|$PREVIEW|" \
	"$ROOT/tools/steam/app_build.vdf.in" > "$VDF"
steamcmd +login "$STEAM_USER" +run_app_build "$VDF" +quit
