import bpy
import importlib.util

# Rigify is distributed with Blender; it is not an extension-store package.
# Enable the bundled add-on by its built-in module name.
if importlib.util.find_spec("rigify") is None:
    raise RuntimeError("Rigify module is missing from this Blender distribution")

bpy.ops.preferences.addon_enable(module="rigify")
import rigify

if not hasattr(bpy.ops.object, "armature_human_metarig_add"):
    raise RuntimeError("Rigify human meta-rig operator is unavailable")

if bpy.context.object and bpy.context.object.mode != "OBJECT":
    bpy.ops.object.mode_set(mode="OBJECT")

bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)
bpy.ops.object.armature_human_metarig_add()
metarig = bpy.context.object
if metarig is None or metarig.type != "ARMATURE":
    raise RuntimeError("Rigify did not create a human armature")

bone_count = len(metarig.data.bones)
if bone_count < 50:
    raise RuntimeError(f"Human meta-rig looks incomplete: only {bone_count} bones")

if not hasattr(bpy.ops.pose, "rigify_generate"):
    raise RuntimeError("Rigify rig-generation operator is unavailable")

print("BLENDER_VERSION:", bpy.app.version_string)
print("RIGIFY_MODULE:", rigify.__name__)
print("RIGIFY_HUMAN_METARIG:", metarig.name)
print("RIGIFY_HUMAN_BONE_COUNT:", bone_count)
print("RIGIFY_GENERATION_OPERATOR_AVAILABLE")
print("RIGIFY_SMOKE_TEST_PASS")
