import importlib
import bpy

module_name = "bl_ext.blender_org.archimesh"
module = importlib.import_module(module_name)

print("ARCHIMESH_MODULE:", module.__name__)
print("BLENDER_VERSION:", bpy.app.version_string)
print("ARCHIMESH_IMPORT_SMOKE_TEST_PASS")
