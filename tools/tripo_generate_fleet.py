#!/usr/bin/env python3
"""Generate the LIFE CITY vehicle fleet through the Tripo v3 API.

This script intentionally checks the account balance before creating tasks.
It generates one multiview set and one textured GLB per selected vehicle.
"""
import argparse
import json
import os
import pathlib
import sys
import time
import requests

BASE = "https://openapi.tripo3d.ai/v3"
ROOT = pathlib.Path(__file__).resolve().parents[1]
SOURCE_FILE = ROOT / "assets/vehicles/tripo_sources.json"
MODEL_VERSION = "v3.1-20260211"
CREDITS_PER_VEHICLE_ESTIMATE = 40  # 10 multiview-image + 30 textured multiview-to-model


def fail(message):
    raise RuntimeError(message)


def api(method, path, **kwargs):
    key = os.environ.get("TRIPO_API_KEY")
    if not key:
        fail("TRIPO_API_KEY GitHub Secret is missing.")
    headers = kwargs.pop("headers", {})
    headers["Authorization"] = f"Bearer {key}"
    headers.setdefault("Accept", "application/json")
    response = requests.request(method, BASE + path, headers=headers, timeout=90, **kwargs)
    try:
        payload = response.json()
    except Exception:
        fail(f"Tripo returned non-JSON HTTP {response.status_code}: {response.text[:500]}")
    if response.status_code >= 400 or payload.get("code", 0) != 0:
        fail(f"Tripo API error HTTP {response.status_code}: {json.dumps(payload)[:1200]}")
    return payload.get("data", {})


def wait_task(task_id, label, timeout_seconds=2400):
    deadline = time.time() + timeout_seconds
    while time.time() < deadline:
        data = api("GET", f"/tasks/{task_id}")
        status = data.get("status")
        print(f"[{label}] task={task_id} status={status} progress={data.get('progress')}", flush=True)
        if status == "success":
            return data
        if status in ("failed", "cancelled"):
            fail(f"{label} task {task_id} ended with status={status}: {json.dumps(data)[:1500]}")
        time.sleep(15)
    fail(f"Timed out waiting for {label} task {task_id}")


def generate(slug, item):
    name = item["display_name"]
    print(f"\n=== {name} ({slug}) ===", flush=True)

    mv = api("POST", "/generation/image-to-multiview", json={"input": item["image_url"]})
    mv_id = mv.get("task_id")
    if not mv_id:
        fail(f"No task_id returned for image-to-multiview: {mv}")
    mv_done = wait_task(mv_id, f"{slug} multiview")
    views = (mv_done.get("output") or {}).get("generate_multiview_image") or {}
    expected = ("front_view_url", "left_view_url", "back_view_url", "right_view_url")
    if not views.get("front_view_url"):
        fail(f"{slug}: Tripo did not return a front view: {json.dumps(mv_done)[:1200]}")

    model_task = api(
        "POST",
        "/generation/multiview-to-model",
        json={
            "inputs": [{"task_id": mv_id}],
            "model": MODEL_VERSION,
            "texture": True,
            "pbr": True,
            "texture_quality": "standard",
            "face_limit": 50000,
            "auto_size": True,
            "export_uv": True
        }
    )
    model_id = model_task.get("task_id")
    if not model_id:
        fail(f"No task_id returned for multiview-to-model: {model_task}")
    model_done = wait_task(model_id, f"{slug} model")
    output = model_done.get("output") or {}
    model_url = output.get("model_url")
    if not model_url:
        fail(f"{slug}: model task succeeded without model_url: {json.dumps(model_done)[:1200]}")

    target_dir = ROOT / "assets" / "vehicles" / slug
    target_dir.mkdir(parents=True, exist_ok=True)
    target_file = target_dir / f"{slug}.glb"
    download = requests.get(model_url, timeout=180)
    download.raise_for_status()
    content = download.content
    if len(content) < 1024 or content[:4] != b"glTF":
        fail(f"{slug}: downloaded output is not a valid GLB (size={len(content)}, magic={content[:8]!r})")
    target_file.write_bytes(content)

    metadata = {
        "vehicle": name,
        "generated_by": "Tripo API",
        "model_version": MODEL_VERSION,
        "image_to_multiview_task_id": mv_id,
        "multiview_to_model_task_id": model_id,
        "source_image_url": item["image_url"],
        "source_page": item["source_page"],
        "source_image_license": item["image_license"],
        "source_attribution": item["attribution"],
        "output_file": f"assets/vehicles/{slug}/{slug}.glb",
        "output_bytes": len(content),
        "triangle_budget": 50000,
        "notes": "AI-generated reconstruction from one reference image via Tripo-generated multiviews. Inspect geometry, interior, wheels, and commercial/IP permissions before production release."
    }
    (target_dir / "tripo_metadata.json").write_text(
        json.dumps(metadata, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8"
    )
    print(f"SUCCESS {slug}: {target_file} ({len(content)} bytes)", flush=True)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--vehicle", default="all", help="all or one vehicle slug")
    args = parser.parse_args()

    sources = json.loads(SOURCE_FILE.read_text(encoding="utf-8"))
    selected = list(sources.items()) if args.vehicle == "all" else [(args.vehicle, sources[args.vehicle])]
    if not selected:
        fail("No vehicles selected.")

    balance_data = api("GET", "/account/balance")
    balance = float(balance_data.get("balance", 0))
    frozen = float(balance_data.get("frozen", 0))
    estimate = len(selected) * CREDITS_PER_VEHICLE_ESTIMATE
    print(f"Tripo balance={balance:.2f}; frozen={frozen:.2f}; estimated required credits={estimate}", flush=True)
    if balance < estimate:
        fail(f"Insufficient Tripo API credits. Need approximately {estimate} available credits for {len(selected)} vehicle(s); current balance={balance:.2f}. No generation task was submitted.")

    failures = []
    for slug, item in selected:
        try:
            generate(slug, item)
        except Exception as exc:
            failures.append((slug, str(exc)))
            print(f"FAILED {slug}: {exc}", file=sys.stderr, flush=True)

    if failures:
        print("\nGeneration failures:", file=sys.stderr)
        for slug, error in failures:
            print(f"- {slug}: {error}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
