# LIFE CITY — MPFB character asset library

This workflow downloads and validates a starter library of official MakeHuman/MPFB asset packs. The packs are downloaded during GitHub Actions rather than committed as hundreds of megabytes of binary files into the Git repository.

## Included packs

All eight selected packs are shared under **CC0** by the official MakeHuman Community asset-pack catalogue:

- `makehuman_system_assets` — core proxy meshes, skin materials, eyes, teeth, hair, eyebrows, eyelashes and starter clothing.
- `skins01` and `skins02` — additional natural skin materials.
- `shirts01`, `pants01`, `shoes01`, and `hats01` — additional clothing and accessories.
- `poses01` — sitting poses.

The official system pack is required for a complete MPFB setup. The other packs expand the initial character wardrobe and pose library. More packs can be added later after checking their licenses and Android performance impact.

## Workflow

Run **MPFB Human Creator and Asset Library Check** from GitHub Actions. It installs MPFB into Blender 4.5 LTS, downloads the official CC0 ZIP packs, installs them into MPFB's own user-data directory using MPFB's asset-pack installer service, checks pack metadata and required categories, and uploads the reusable extracted library as the artifact:

`lifecity-mpfb-cc0-asset-library`

The artifact is retained for 30 days. Future Blender character-generation workflows can download that artifact instead of downloading the packs again.

## Important

- The asset packs are not copied into the Godot APK automatically.
- MPFB creates source characters in Blender. Characters still need retopology/LOD, rigging, animation, GLB export, and Godot integration.
- The selected starter packs are CC0. Keep checking individual licenses before adding other community packs; not every pack is CC0.
- The core system pack is about 267 MB; the complete selected starter set is roughly 567 MB before extraction.
