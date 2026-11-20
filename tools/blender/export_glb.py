import bpy
import os
import sys

def argument_after_separator(name, default=None):
    args = sys.argv
    if "--" not in args:
        return default
    args = args[args.index("--") + 1:]
    for index, value in enumerate(args):
        if value == name and index + 1 < len(args):
            return args[index + 1]
    return default

output_path = argument_after_separator("--output")
if not output_path:
    raise RuntimeError("Missing --output path")

output_path = os.path.abspath(output_path)
os.makedirs(os.path.dirname(output_path), exist_ok=True)

# Export visible scene objects as a Godot-friendly glTF binary.
bpy.ops.export_scene.gltf(
    filepath=output_path,
    export_format="GLB",
    use_selection=False,
    export_apply=True,
)

if not os.path.isfile(output_path) or os.path.getsize(output_path) == 0:
    raise RuntimeError("GLB export failed or produced an empty file")

print("LIFE_CITY_BLENDER_EXPORT_OK:", output_path)
