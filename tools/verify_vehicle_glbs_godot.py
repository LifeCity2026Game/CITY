#!/usr/bin/env python3
"""Verify dequantized CC0 GLBs are compatible with Godot's built-in glTF importer."""
import json
import struct
from pathlib import Path

ROOT = Path("assets/vehicles")
VEHICLE_DIRS = [
    "dena_plus", "peugeot_207", "land_cruiser_300", "lexus_rx_2023",
    "ferrari_f40", "lamborghini_huracan", "saipa_tiba", "saipa_tiba_2",
    "saipa_pride_131",
]
REQUIRED_CLIPS = [
    "door-open", "door-close", "bonnet-open", "bonnet-close",
    "boot-open", "boot-close", "steer", "wheel-roll",
]
REQUIRED_WHEELS = [
    "wheel-front-left", "wheel-front-right",
    "wheel-rear-left", "wheel-rear-right",
]
STEERING_NAMES = {"steering", "steering-wheel", "steering_wheel"}

def read_document(path):
    raw = path.read_bytes()
    if len(raw) < 20 or raw[:4] != b"glTF":
        raise RuntimeError(f"Invalid GLB: {path}")
    version, length = struct.unpack_from("<II", raw, 4)
    if version != 2 or length != len(raw):
        raise RuntimeError(f"Invalid GLB version/length: {path}")
    offset = 12
    while offset + 8 <= len(raw):
        chunk_length, chunk_type = struct.unpack_from("<II", raw, offset)
        offset += 8
        chunk = raw[offset:offset + chunk_length]
        offset += chunk_length
        if chunk_type == 0x4E4F534A:
            return json.loads(chunk.decode("utf-8").rstrip("\x00 "))
    raise RuntimeError(f"Missing JSON chunk: {path}")

def main():
    checked = 0
    for folder in VEHICLE_DIRS:
        path = ROOT / folder / f"{folder}.glb"
        doc = read_document(path)
        required = doc.get("extensionsRequired", [])
        used = doc.get("extensionsUsed", [])
        if "KHR_mesh_quantization" in required or "KHR_mesh_quantization" in used:
            raise RuntimeError(f"KHR_mesh_quantization remains after conversion: {path}")
        accessors = doc.get("accessors", [])
        position_accessors = []
        for mesh in doc.get("meshes", []):
            for primitive in mesh.get("primitives", []):
                position_index = primitive.get("attributes", {}).get("POSITION")
                if position_index is not None:
                    position_accessors.append(accessors[position_index])
        if not position_accessors or any(item.get("componentType") != 5126 for item in position_accessors):
            raise RuntimeError(f"POSITION attributes are not float32: {path}")
        animations = [str(item.get("name", "")).lower() for item in doc.get("animations", [])]
        nodes = [str(item.get("name", "")).lower() for item in doc.get("nodes", [])]
        missing_clips = [clip for clip in REQUIRED_CLIPS if not any(clip in name for name in animations)]
        missing_wheels = [pivot for pivot in REQUIRED_WHEELS if not any(pivot == name for name in nodes)]
        if missing_clips or missing_wheels:
            raise RuntimeError(f"Rig validation failed for {path}: clips={missing_clips}, wheels={missing_wheels}")
        if not any(name in STEERING_NAMES for name in nodes):
            raise RuntimeError(f"Steering pivot missing: {path}")
        print(f"GODOT_GLB_PASS {folder}: {len(animations)} clips, float32 positions, 4 wheel pivots, steering pivot, {path.stat().st_size:,} bytes")
        checked += 1
    print(f"GODOT_GLB_VALIDATION_PASS {checked}/{len(VEHICLE_DIRS)}")

if __name__ == "__main__":
    main()
