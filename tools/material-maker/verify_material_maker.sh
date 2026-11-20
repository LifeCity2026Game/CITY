#!/usr/bin/env bash
set -euo pipefail

SOURCE_DIR="${1:-/tmp/material-maker}"

if [[ ! -f "$SOURCE_DIR/project.godot" ]]; then
  echo "Material Maker source project not found: $SOURCE_DIR" >&2
  exit 1
fi

if ! grep -q 'config/name=.*Material Maker' "$SOURCE_DIR/project.godot"; then
  echo "Unexpected project.godot; expected Material Maker project" >&2
  exit 1
fi

godot --headless --editor --path "$SOURCE_DIR" --quit

echo "MATERIAL_MAKER_GODOT_IMPORT_PASS"
