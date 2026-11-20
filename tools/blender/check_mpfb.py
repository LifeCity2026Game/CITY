import importlib
import bpy

module_name = "bl_ext.blender_org.mpfb"
module = importlib.import_module(module_name)

version = getattr(module, "VERSION", None)
if not version:
    raise RuntimeError("MPFB imported but did not expose a valid VERSION")

print("MPFB_MODULE:", module.__name__)
print("MPFB_VERSION:", ".".join(str(part) for part in version))
print("BLENDER_VERSION:", bpy.app.version_string)
print("MPFB_IMPORT_SMOKE_TEST_PASS")
