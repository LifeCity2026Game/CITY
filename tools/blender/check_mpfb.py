import glob
import importlib
import os
import shutil
import sys

import bpy

module_name = "bl_ext.blender_org.mpfb"
module = importlib.import_module(module_name)
version = getattr(module, "VERSION", None)
if not version:
    raise RuntimeError("MPFB imported but did not expose a valid VERSION")

from bl_ext.blender_org.mpfb.services.assetservice import AssetService
from bl_ext.blender_org.mpfb.services.locationservice import LocationService

args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
if len(args) != 1:
    raise RuntimeError("Expected the downloaded MPFB asset-pack directory")

packs_dir = os.path.abspath(args[0])
user_data_dir = LocationService.get_user_data()
os.makedirs(user_data_dir, exist_ok=True)

zip_files = sorted(glob.glob(os.path.join(packs_dir, "*.zip")))
if len(zip_files) != 8:
    raise RuntimeError(f"Expected 8 downloaded asset packs, found {len(zip_files)}")

for zip_path in zip_files:
    error = AssetService.fix_and_extract_asset_pack_zip(zip_path, user_data_dir)
    if error:
        raise RuntimeError(f"Could not install {os.path.basename(zip_path)}: {error}")
    print("MPFB_ASSET_PACK_INSTALLED:", os.path.basename(zip_path))

AssetService.rescan_pack_metadata()
installed_packs = set(AssetService.get_pack_names())
expected_packs = {
    "makehuman_system_assets",
    "skins01",
    "skins02",
    "shirts01",
    "pants01",
    "shoes01",
    "hats01",
    "poses01",
}
missing = sorted(expected_packs - installed_packs)
if missing:
    raise RuntimeError("Missing MPFB pack metadata: " + ", ".join(missing))

required_categories = [
    "skins", "eyes", "teeth", "hair", "clothes",
    "proxymeshes", "poses", "packs"
]
category_counts = {}
for category in required_categories:
    folder = os.path.join(user_data_dir, category)
    count = 0
    if os.path.isdir(folder):
        for _, _, files in os.walk(folder):
            count += len(files)
    category_counts[category] = count
    if count == 0:
        raise RuntimeError(f"MPFB category is empty: {category}")

system_assets_ok, brown_eye_material_ok = AssetService.check_if_modern_makehuman_system_assets_installed()
if not system_assets_ok or not brown_eye_material_ok:
    raise RuntimeError("Modern MakeHuman system assets were not detected")

print("MPFB_MODULE:", module.__name__)
print("MPFB_VERSION:", ".".join(str(part) for part in version))
print("BLENDER_VERSION:", bpy.app.version_string)
print("MPFB_INSTALLED_PACKS:", ", ".join(sorted(expected_packs)))
print("MPFB_ASSET_COUNTS:", category_counts)
print("MPFB_SYSTEM_ASSETS_CHECK_PASS")
print("MPFB_ASSET_LIBRARY_SMOKE_TEST_PASS")

output_file = os.environ.get("GITHUB_OUTPUT")
if output_file:
    with open(output_file, "a", encoding="utf-8") as handle:
        handle.write(f"asset_data_dir={user_data_dir}\n")
