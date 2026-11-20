#!/usr/bin/env python3
"""Validate the pinned ProtonScatter addon package used by LIFE CITY."""

from pathlib import Path
import sys

root = Path(sys.argv[1] if len(sys.argv) > 1 else "addons/proton_scatter")
required = [
    "plugin.cfg",
    "plugin.gd",
    "LICENSE",
    "src/scatter.gd",
    "src/scatter_item.gd",
    "src/scatter_shape.gd",
    "src/modifiers/create_inside_random.gd",
    "src/modifiers/project_on_geometry.gd",
]
missing = [name for name in required if not (root / name).is_file()]
if missing:
    raise SystemExit("Missing ProtonScatter files: " + ", ".join(missing))

config = (root / "plugin.cfg").read_text(encoding="utf-8")
if 'name="ProtonScatter"' not in config or 'version="4.2.0"' not in config:
    raise SystemExit("Unexpected ProtonScatter plugin metadata")

license_text = (root / "LICENSE").read_text(encoding="utf-8").lower()
if "mit license" not in license_text:
    raise SystemExit("ProtonScatter MIT license was not found")

print("PROTON_SCATTER_PACKAGE_VERIFICATION_PASS")
