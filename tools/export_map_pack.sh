#!/bin/sh
# Exports custom/<map>/ as a map pack (build/map_packs/<map>.zip).
# Usage: tools/export_map_pack.sh my_map   (GODOT=/path/to/godot if it isn't on your PATH)
[ -z "$1" ] && { echo "Usage: tools/export_map_pack.sh <map folder in custom/>"; exit 1; }
"${GODOT:-godot}" --headless --path "$(dirname "$0")/.." --script res://tools/export_map_pack.gd -- "$@"
