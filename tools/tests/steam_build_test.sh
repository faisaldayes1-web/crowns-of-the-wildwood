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
case " $* " in
  *' --import '*)
    [[ -d .godot ]]
    grep -qx 'res://addons/godotsteam/godotsteam.gdextension' .godot/extension_list.cfg
    [[ " $* " == *' --editor '* && " $* " == *' --quit '* ]]
    [[ ! -f .godot/warm-marker || "$(cat .godot/warm-marker)" == cached ]]
    ;;
  *' --export-release '*)
    out="${@: -1}"
    touch "$out" "$(dirname "$out")/steam_api64.dll" \
      "$(dirname "$out")/libgodotsteam.windows.template_release.x86_64.dll"
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
    --app-id=480 "$FIXTURE/output-$cache" > "$FIXTURE/$cache.log" 2>&1 || {
      cat "$FIXTURE/$cache.log"; exit 1;
    }
  grep -q 'STEAM BUILD OK' "$FIXTURE/$cache.log"
  [[ ! -e "$FIXTURE/output-$cache/steam_appid.txt" ]]
  echo "PASS: $cache cache bootstrap and terminating import"
done
