#!/usr/bin/env bash
# CI only (claude-faisal/crowns-gates 2026-11-04): the official Godot 4.3
# Linux build, checked against its published SHA-512, at $GODOT; with
# --xvfb also a virtual display and Mesa for the rendered gates.
set -euo pipefail
mkdir -p ci-logs /tmp/crowns-godot
release=https://github.com/godotengine/godot-builds/releases/download/4.3-stable
archive=Godot_v4.3-stable_linux.x86_64.zip
curl -fsSL --retry 3 "$release/$archive" -o "/tmp/crowns-godot/$archive"
expected=fd52bb4ba8acc30ca5accd1c566d470ad7282f891ccc0995dfafabcf92bcf76280ce182bf9d80ebd885f3ed2165d01e1fc3f2928436b15498dfbd98656c2a45a
echo "$expected  /tmp/crowns-godot/$archive" | sha512sum --check
unzip -q -o "/tmp/crowns-godot/$archive" -d /tmp/crowns-godot
chmod +x "$GODOT"
"$GODOT" --version | tee ci-logs/engine-version.log
if [ "${1:-}" = "--xvfb" ]; then
  sudo apt-get update -qq
  sudo apt-get install -y -qq xvfb libgl1-mesa-dri > /dev/null
fi
