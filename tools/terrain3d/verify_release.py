#!/usr/bin/env python3
"""Verify the official Terrain3D release archive has the expected Godot plugin files."""
from pathlib import Path
import sys

root = Path(sys.argv[1])
if not root.is_dir():
    raise SystemExit(f"Release directory not found: {root}")

files = [p for p in root.rglob("*") if p.is_file()]
plugin_cfg = [p for p in files if p.name == "plugin.cfg"]
extension_cfg = [p for p in files if p.suffix == ".gdextension"]

if not plugin_cfg:
    raise SystemExit("Terrain3D plugin.cfg was not found in the official archive.")
if not extension_cfg:
    raise SystemExit("Terrain3D .gdextension descriptor was not found in the official archive.")

print(f"PLUGIN_CONFIG_FOUND: {plugin_cfg[0].relative_to(root)}")
print(f"GDEXTENSION_FOUND: {extension_cfg[0].relative_to(root)}")
print(f"ARCHIVE_FILES: {len(files)}")

platform_files = [
    p for p in files
    if any(token in str(p).lower() for token in ("android", "arm64", "aarch64"))
]
print(f"ANDROID_OR_ARM64_REFERENCES: {len(platform_files)}")
print("TERRAIN3D_ARCHIVE_STRUCTURE_VALID")
