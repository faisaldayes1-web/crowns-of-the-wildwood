#!/usr/bin/env bash
# Agent: Codex-faisal. Exercise build orchestration without exporting/uploading.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
FIXTURE="$(mktemp -d)"
# Only this test-created directory is removed.
trap '[[ -n "$FIXTURE" && -d "$FIXTURE" ]] && rm -rf -- "$FIXTURE"' EXIT
mkdir -p "$FIXTURE/tools/steam/godotsteam/"{win64,linux64}
cp "$ROOT/tools/steam/build_steam.sh" "$FIXTURE/tools/steam/"
printf '[steam]\napp_id=0\n' > "$FIXTURE/project.godot"
touch "$FIXTURE/tools/steam/godotsteam/"{license.txt,godotsteam.gdextension.in}
cat > "$FIXTURE/fake-godot" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail
[[ -z "${GODOT_CALL_LOG:-}" ]] || echo called >> "$GODOT_CALL_LOG"
case " $* " in
  *' --import '*)
    if [[ "${FAIL_PHASE:-}" == import ]]; then echo 'ERROR: fixture import failure' >&2; exit 0; fi
    [[ -d .godot ]]
    grep -qx 'res://addons/godotsteam/godotsteam.gdextension' .godot/extension_list.cfg
    [[ " $* " == *' --editor '* && " $* " == *' --quit '* ]]
    [[ ! -f .godot/warm-marker || "$(cat .godot/warm-marker)" == cached ]]
    ;;
  *' --export-release '*)
    out="${@: -1}"
    for file in "$out" "$(dirname "$out")/steam_api64.dll" \
      "$(dirname "$out")/libgodotsteam.windows.template_release.x86_64.dll"; do
      printf 'fixture' > "$file"
    done
    if [[ "${FAIL_PHASE:-}" == export ]]; then echo 'ERROR: fixture export failure' >&2; exit 0; fi
    if [[ "${FAIL_PHASE:-}" == empty ]]; then : > "$out"; fi
    ;;
  *) exit 90 ;;
esac
STUB
chmod +x "$FIXTURE/fake-godot"
git -C "$FIXTURE" init -q
git -C "$FIXTURE" add .
for cache in cold warm; do
  if [[ "$cache" == warm ]]; then
    mkdir -p "$FIXTURE/.godot"
    echo cached > "$FIXTURE/.godot/warm-marker"
  fi
  GODOT="$FIXTURE/fake-godot" bash "$FIXTURE/tools/steam/build_steam.sh" \
    --app-id=123456 "$FIXTURE/output-$cache" > "$FIXTURE/$cache.log" 2>&1 || {
      cat "$FIXTURE/$cache.log"; exit 1;
    }
  grep -q 'STEAM BUILD OK' "$FIXTURE/$cache.log"
  [[ ! -e "$FIXTURE/output-$cache/steam_appid.txt" ]]
  [[ -f "$FIXTURE/output-$cache.logs/import.log" && -f "$FIXTURE/output-$cache.logs/export.log" ]]
  echo "PASS: $cache cache bootstrap and terminating import"
done

export GODOT_CALL_LOG="$FIXTURE/godot-calls"
reject() {
  if GODOT="$FIXTURE/fake-godot" bash "$FIXTURE/tools/steam/build_steam.sh" "$@" > "$FIXTURE/reject.log" 2>&1; then
    echo "FAIL: expected rejection: $*"; exit 1
  fi
  [[ ! -e "$GODOT_CALL_LOG" ]]
}
for id in 0 -1 abc '12/34' ''; do
  reject "--app-id=$id" "$FIXTURE/invalid-output"
done
reject --app-id=480 "$FIXTURE/invalid-output"
reject --typo "$FIXTURE/invalid-output"
reject --app-id=123456 "$FIXTURE/one" "$FIXTURE/two"
echo preserve > "$FIXTURE/output-cold/sentinel"
reject --app-id=123456 "$FIXTURE/output-cold"
[[ "$(cat "$FIXTURE/output-cold/sentinel")" == preserve ]]
[[ ! -e "$FIXTURE/invalid-output" ]]
echo 'PASS: invalid inputs rejected before Godot; existing output preserved'

(cd "$FIXTURE" && GODOT="$FIXTURE/fake-godot" bash tools/steam/build_steam.sh \
  --dev --app-id=480 'relative output' > relative.log 2>&1) || {
    cat "$FIXTURE/relative.log"; exit 1;
  }
[[ -f "$FIXTURE/relative output/CrownsOfTheWildwood.exe" ]]
[[ "$(cat "$FIXTURE/relative output/steam_appid.txt")" == 480 ]]
echo 'PASS: relative output with spaces and explicit Spacewar development build'

for phase in import export empty; do
  if FAIL_PHASE="$phase" GODOT="$FIXTURE/fake-godot" bash "$FIXTURE/tools/steam/build_steam.sh" \
    --app-id=123456 "$FIXTURE/failure-$phase" > "$FIXTURE/failure-$phase.log" 2>&1; then
    echo "FAIL: accepted $phase failure"; exit 1
  fi
  [[ -f "$FIXTURE/failure-$phase.logs/import.log" ]]
  if [[ "$phase" == import ]]; then
    [[ ! -e "$FIXTURE/failure-$phase.logs/export.log" ]]
    grep -q 'fixture import failure' "$FIXTURE/failure-$phase.logs/import.log"
  else
    [[ -f "$FIXTURE/failure-$phase.logs/export.log" ]]
  fi
  echo "PASS: $phase failure rejected with logs retained"
done
