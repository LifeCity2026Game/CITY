# Terrain3D for LIFE CITY

- Upstream: https://github.com/TokisanGames/Terrain3D
- Pinned release: `v1.1.0-stable`
- License: MIT
- LIFE CITY Godot CI baseline: Godot 4.7.2
- Upstream compatibility: Godot 4.5–4.8; mobile and web support have platform/renderer caveats.

## Purpose

Use Terrain3D for large editable outdoor surfaces: city outskirts, hills, beaches,
roadsides, fields, and natural terrain. It supports texture painting, heightmap
import, level of detail, and foliage instancing.

## Current integration stage

The GitHub Actions workflow downloads the official release, verifies its SHA-256,
checks for the Godot plugin and GDExtension descriptors, and stores the verified
package as a workflow artifact. This verification does **not** mean Terrain3D is
already enabled in the playable LIFE CITY project or that Android/Web runtime
compatibility has been proven.

## Next steps

1. Review the workflow artifact and confirm the expected Android binaries.
2. Integrate the plugin into the Godot project only after checking the target
   renderer and Android ABI.
3. Add a small terrain test scene and run Android device tests before using it
   for the full city.
4. Keep terrain region count, texture count, foliage density, and view distance
   adjustable for weaker phones.

Official docs: https://terrain3d.readthedocs.io/en/1.1/
