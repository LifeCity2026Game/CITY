# LIFE CITY Blender source assets

Place editable Blender project files (`.blend`) in this folder.

When a `.blend` file is pushed to the `godot-migration` branch, the
Blender Asset Pipeline workflow runs Blender in GitHub Actions, exports
each project to GLB, and publishes the exports as a downloadable workflow
artifact. No Blender API key or paid service is required.

Recommended organization:
- `cars/` for vehicle projects (body, doors, hood, trunk, wheels, cabin)
- `humans/` for character projects (mesh, armature, clothing)

Do not put generated exports or large temporary files here. Review the
GLB artifact before importing it into the Godot game.
