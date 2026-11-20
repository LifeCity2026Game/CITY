# LIFE CITY Building Assets

This folder is for editable Blender building scenes (`.blend`) that will be
exported to GLB for Godot.

## Free architecture tools

- **Archimesh** (GPL): Blender extension for rooms, doors, windows, cabinets,
  columns, stairs, roofs and decorative objects.
  Official listing: https://extensions.blender.org/add-ons/archimesh/
- **Bonsai** (GPL): Blender-based OpenBIM/IFC authoring. Useful for structured
  architectural data, but optional and not required for game-ready meshes.
  Official listing: https://extensions.blender.org/add-ons/bonsai/
- **Sweet Home 3D** (GPL): optional floor-plan and interior-layout planner.
  Export desktop projects to OBJ, then import into Blender for cleanup.
  Official site: https://www.sweethome3d.com/

## LIFE CITY asset workflow

1. Create or edit a building scene in Blender.
2. Keep separate objects for walls, floors, doors, windows, stairs, furniture,
   and other interactive pieces.
3. Save the `.blend` file under this folder.
4. Run the Blender 3D Asset Pipeline workflow.
5. Review the generated GLB artifact before importing it into Godot.

The Blender add-ons above are free/open-source, but third-party models and
textures used inside a scene may have their own licenses. Check each asset's
license before shipping it in LIFE CITY.

For Android performance, use simplified collision meshes, texture atlases,
LODs, and separate interior scenes where possible. A GLB export alone does
not implement enterable doors, elevators, or gameplay interactions; those
must be configured in Godot.
