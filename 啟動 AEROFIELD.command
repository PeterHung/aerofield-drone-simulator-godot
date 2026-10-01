#!/bin/zsh
set -e
cd "$(dirname "$0")"
if [[ -d "builds/macos/AEROFIELD.app" ]]; then
  open "builds/macos/AEROFIELD.app"
  exit
fi
if [[ -f "builds/macos/AEROFIELD-macOS.zip" ]]; then
  unzip -q -o "builds/macos/AEROFIELD-macOS.zip" -d "builds/macos"
  open "builds/macos/AEROFIELD.app"
  exit
fi
if [[ -n "${GODOT:-}" ]]; then
  exec "$GODOT" --path "$PWD"
fi
if command -v godot >/dev/null; then
  exec godot --path "$PWD"
fi
if [[ -x "/Applications/Godot.app/Contents/MacOS/Godot" ]]; then
  exec "/Applications/Godot.app/Contents/MacOS/Godot" --path "$PWD"
fi
print "請安裝 Godot 4.7.2，或先從 GitHub Releases 下載 macOS 執行版。"
read -k 1 "?按任意鍵關閉…"
