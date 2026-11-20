#!/usr/bin/env python3
"""Fetch CC0 GLB vehicle assets from the 3DAssets.dev Car Park fleet."""
import json
import re
import sys
import time
from pathlib import Path

import requests

API = "https://3dassets.dev/api/v1/packs/car-park-and-road-vehicle-fleet"
OUT = Path("assets/vehicles")
VEHICLES = [
    ("dena_plus", "Dena Plus", ["four-door saloon"]),
    ("peugeot_207", "Peugeot 207", ["five-door hatchback"]),
    ("land_cruiser_300", "Toyota Land Cruiser 300", ["large seven-seat suv"]),
    ("lexus_rx_2023", "Lexus RX 2023", ["mid-size suv"]),
    ("ferrari_f40", "Ferrari F40", ["grand touring coupe"]),
    ("lamborghini_huracan", "Lamborghini Huracan", ["mid-engine sports car"]),
    ("saipa_tiba", "Saipa Tiba", ["executive saloon"]),
    ("saipa_tiba_2", "Saipa Tiba 2", ["hot hatch"]),
    ("saipa_pride_131", "Saipa Pride 131", ["city car"]),
]

session = requests.Session()
session.headers.update({"User-Agent": "LIFE-CITY-free-vehicle-import/1.0"})

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
    preferred = []
    for key, value in obj.items():
        if isinstance(value, str) and key.lower() not in {"url", "model_url", "cdn_url", "download_url"}:
            preferred.append(value)
    return " ".join(preferred).lower()

def find_record(data, aliases):
    candidates = []
    for obj in walk_dicts(data):
        label = label_text(obj)
        if any(alias in label for alias in aliases):
            urls = [s for s in all_strings(obj)
                    if "cdn.3dassets.dev/assets/" in s and s.endswith("/model.glb")]
            if urls:
                candidates.append((len(label), obj, urls[0]))
    if not candidates:
        return None
    # Prefer the smallest matching record, not the enclosing pack object.
    candidates.sort(key=lambda x: x[0])
    _, obj, url = candidates[0]
    return obj, url

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
        "note": "These are generic vehicle body classes mapped to LIFE CITY vehicle slots; they are not exact manufacturer-specific replicas.",
        "vehicles": []
    }
    failures = []
    for slug, display_name, aliases in VEHICLES:
        found = find_record(data, aliases)
        if not found:
            failures.append(f"{display_name}: no matching downloadable GLB record for {aliases}")
            continue
        record, url = found
        folder = OUT / slug
        folder.mkdir(parents=True, exist_ok=True)
        target = folder / f"{slug}.glb"
        if not target.exists() or target.stat().st_size < 12:
            r = session.get(url, timeout=90)
            r.raise_for_status()
            if not r.content.startswith(b"glTF"):
                raise RuntimeError(f"Downloaded file is not a GLB: {display_name} ({url})")
            target.write_bytes(r.content)
        if target.stat().st_size < 1024:
            raise RuntimeError(f"Unexpectedly small GLB for {display_name}")
        record_strings = list(all_strings(record))
        asset_page = next((s for s in record_strings if s.startswith("https://3dassets.dev/assets/")), "")
        metadata = {
            "vehicle_slot": display_name,
            "source_asset_name": next((v for k, v in record.items() if k.lower() in {"name", "title", "label"} and isinstance(v, str)), aliases[0]),
            "model_file": target.name,
            "model_url": url,
            "asset_page": asset_page,
            "license": "CC0 1.0 Universal",
            "license_url": "https://creativecommons.org/publicdomain/zero/1.0/",
            "source": "3DAssets.dev",
            "note": "Generic body-style placeholder, not an exact Dena/Peugeot/Toyota/Lexus/Ferrari/Lamborghini/Saipa replica. Requires in-engine inspection, collision setup, and vehicle physics integration."
        }
        (folder / "source_metadata.json").write_text(json.dumps(metadata, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        manifest["vehicles"].append(metadata)
        print(f"OK {display_name}: {target} ({target.stat().st_size:,} bytes) <- {url}")
    (OUT / "free_vehicle_manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    if failures:
        print("\nIMPORT INCOMPLETE:")
        for failure in failures:
            print(" - " + failure)
        sys.exit(2)
    print(f"\nImported {len(manifest['vehicles'])}/{len(VEHICLES)} CC0 vehicle GLBs.")

if __name__ == "__main__":
    main()
