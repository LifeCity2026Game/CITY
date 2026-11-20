#!/usr/bin/env python3
"""Fetch and validate free CC0 vehicle assets from 3DAssets.dev."""
import json
import struct
import sys
from pathlib import Path

import requests

API = "https://3dassets.dev/api/v1/packs/car-park-and-road-vehicle-fleet"
OUT = Path("assets/vehicles")
VEHICLES = [
    ("dena_plus", "Dena Plus", ["four-door saloon"], None),
    ("peugeot_207", "Peugeot 207", ["five-door hatchback"], None),
    ("land_cruiser_300", "Toyota Land Cruiser 300", ["large seven-seat suv"], None),
    ("lexus_rx_2023", "Lexus RX 2023", ["mid-size suv"], None),
    ("ferrari_f40", "Ferrari F40", ["grand touring coupe"], None),
    ("lamborghini_huracan", "Lamborghini Huracan", ["mid-engine sports car"], None),
    ("saipa_tiba", "Saipa Tiba", ["executive saloon"], None),
    ("saipa_tiba_2", "Saipa Tiba 2", ["hot hatch"], None),
    # Explicit standalone city-car asset; never use the pack's car-park starter scene.
    ("saipa_pride_131", "Saipa Pride 131", [], {
        "name": "City car (Car Park and Road Vehicle Fleet)",
        "url": "https://cdn.3dassets.dev/assets/32487/v1/model.glb",
        "page": "https://3dassets.dev/assets/car-park-and-road-vehicle-fleet-city-car-033e3215",
    }),
]

session = requests.Session()
session.headers.update({"User-Agent": "LIFE-CITY-free-vehicle-import/1.1"})

def walk_dicts(value):
    if isinstance(value, dict):
        yield value
        for child in value.values():
            yield from walk_dicts(child)
    elif isinstance(value, list):
        for child in value:
            yield from walk_dicts(child)

def all_strings(value):
    if isinstance(value, dict):
        for child in value.values():
            yield from all_strings(child)
    elif isinstance(value, list):
        for child in value:
            yield from all_strings(child)
    elif isinstance(value, str):
        yield value

def label_text(obj):
    return " ".join(
        value for key, value in obj.items()
        if isinstance(value, str) and key.lower() not in {"url", "model_url", "cdn_url", "download_url"}
    ).lower()

def find_record(data, aliases):
    candidates = []
    for obj in walk_dicts(data):
        label = label_text(obj)
        if any(alias in label for alias in aliases):
            urls = [value for value in all_strings(obj)
                    if "cdn.3dassets.dev/assets/" in value and value.endswith("/model.glb")]
            if urls:
                candidates.append((len(label), obj, urls[0]))
    if not candidates:
        return None
    candidates.sort(key=lambda item: item[0])
    _, record, url = candidates[0]
    return record, url

def read_glb_document(path):
    raw = path.read_bytes()
    if len(raw) < 20 or raw[:4] != b"glTF":
        raise RuntimeError(f"Invalid GLB header: {path}")
    version, declared_length = struct.unpack_from("<II", raw, 4)
    if version != 2 or declared_length != len(raw):
        raise RuntimeError(f"Unexpected GLB version/length: {path}")
    offset = 12
    while offset + 8 <= len(raw):
        chunk_length, chunk_type = struct.unpack_from("<II", raw, offset)
        offset += 8
        chunk = raw[offset:offset + chunk_length]
        offset += chunk_length
        if chunk_type == 0x4E4F534A:
            return json.loads(chunk.decode("utf-8").rstrip("\x00 "))
    raise RuntimeError(f"GLB JSON chunk missing: {path}")

def validate_vehicle_glb(path, display_name):
    document = read_glb_document(path)
    animations = [str(item.get("name", "")).lower() for item in document.get("animations", [])]
    nodes = [str(item.get("name", "")).lower() for item in document.get("nodes", [])]
    required_clips = ["door-open", "door-close", "bonnet-open", "bonnet-close",
                      "boot-open", "boot-close", "steer", "wheel-roll"]
    missing_clips = [clip for clip in required_clips if not any(clip in name for name in animations)]
    required_pivots = ["wheel-front-left", "wheel-front-right", "wheel-rear-left", "wheel-rear-right"]
    missing_pivots = [pivot for pivot in required_pivots if not any(pivot in name for name in nodes)]
    if missing_clips:
        raise RuntimeError(f"{display_name}: missing GLB animation clips: {missing_clips}")
    if missing_pivots:
        raise RuntimeError(f"{display_name}: missing named wheel pivots: {missing_pivots}")
    if not any(name in {"steering", "steering-wheel", "steering_wheel"} for name in nodes):
        raise RuntimeError(f"{display_name}: missing named steering wheel pivot")
    if not document.get("meshes"):
        raise RuntimeError(f"{display_name}: GLB contains no meshes")
    return animations, nodes

def main():
    response = session.get(API, timeout=45)
    response.raise_for_status()
    data = response.json()
    OUT.mkdir(parents=True, exist_ok=True)
    manifest = {
        "source": "3DAssets.dev — Car Park and Road Vehicle Fleet",
        "source_manifest": API,
        "license": "CC0 1.0 Universal",
        "license_url": "https://creativecommons.org/publicdomain/zero/1.0/",
        "note": "Generic CC0 vehicle body classes mapped to LIFE CITY slots; not exact replicas of the named manufacturers/models.",
        "vehicles": [],
    }
    failures = []
    for slug, display_name, aliases, explicit in VEHICLES:
        if explicit:
            record = {"name": explicit["name"]}
            url = explicit["url"]
            asset_page = explicit["page"]
        else:
            found = find_record(data, aliases)
            if not found:
                failures.append(f"{display_name}: no matching downloadable GLB record for {aliases}")
                continue
            record, url = found
            record_strings = list(all_strings(record))
            asset_page = next((value for value in record_strings
                               if value.startswith("https://3dassets.dev/assets/")), "")
        folder = OUT / slug
        folder.mkdir(parents=True, exist_ok=True)
        target = folder / f"{slug}.glb"
        metadata_path = folder / "source_metadata.json"
        old_url = ""
        if metadata_path.exists():
            try:
                old_url = json.loads(metadata_path.read_text(encoding="utf-8")).get("model_url", "")
            except (ValueError, OSError):
                old_url = ""
        if not target.exists() or target.stat().st_size < 12 or old_url != url:
            download = session.get(url, timeout=90)
            download.raise_for_status()
            if not download.content.startswith(b"glTF"):
                raise RuntimeError(f"Downloaded file is not a GLB: {display_name} ({url})")
            target.write_bytes(download.content)
        if target.stat().st_size < 1024:
            raise RuntimeError(f"Unexpectedly small GLB for {display_name}")
        animations, node_names = validate_vehicle_glb(target, display_name)
        metadata = {
            "vehicle_slot": display_name,
            "source_asset_name": record.get("name", aliases[0] if aliases else "City car"),
            "model_file": target.name,
            "model_url": url,
            "asset_page": asset_page,
            "license": "CC0 1.0 Universal",
            "license_url": "https://creativecommons.org/publicdomain/zero/1.0/",
            "source": "3DAssets.dev",
            "animations": animations,
            "wheel_pivots": [name for name in node_names if "wheel-" in name],
            "note": "Generic CC0 vehicle body class, not an exact manufacturer-specific replica. Named wheel pivots and door/bonnet/boot/steering/wheel-roll clips are verified in the GLB. LIFE CITY supplies vehicle collision and physics.",
        }
        metadata_path.write_text(json.dumps(metadata, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        manifest["vehicles"].append(metadata)
        print(f"OK {display_name}: {target} ({target.stat().st_size:,} bytes), {len(animations)} animations, {len(metadata['wheel_pivots'])} wheel pivots <- {url}")
    (OUT / "free_vehicle_manifest.json").write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    if failures:
        print("\nIMPORT INCOMPLETE:")
        for failure in failures:
            print(" - " + failure)
        sys.exit(2)
    print(f"\nImported and rig-validated {len(manifest['vehicles'])}/{len(VEHICLES)} CC0 vehicle GLBs.")

if __name__ == "__main__":
    main()
