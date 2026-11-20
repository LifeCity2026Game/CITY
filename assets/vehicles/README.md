# LIFE CITY — Imported vehicle assets

## Current technical state

Nine standalone GLB files are committed under this directory and are mapped by scripts/vehicle_controller.gd. The GLBs are generic vehicle classes from 3DAssets.dev, not exact reproductions of the real-world manufacturers/models named by LIFE CITY. Do not describe the fleet as manufacturer-accurate.

All assets are CC0 1.0 Universal. They may be modified and used commercially without attribution:
https://creativecommons.org/publicdomain/zero/1.0/

Source pack:
https://3dassets.dev/packs/car-park-and-road-vehicle-fleet

## Current active vehicle: Dena Plus

The Dena Plus slot is the first vehicle in the one-at-a-time acceptance cycle. Its current imported GLB is still the generic CC0 four-door saloon from the source pack, not an exact Dena Plus replica. The Godot controller adds a Dena-specific trim overlay (grille, lower intake, emblem, hood creases, fog lamps, rear lamp accents, side chrome, door handles and trunk garnish) and uses the existing imported wheel/steering pivots.

A dedicated `tests/dena_plus_vehicle_test.gd` acceptance test now checks the Dena model load, visible trim, wheel/steering rig, simultaneous mobile steering buttons, automatic forward/reverse driving, braking, and manual clutch/first-gear behavior. The GitHub vehicle-assets workflow runs this test after GLB import.

**Not yet accepted as complete:** an exact Dena Plus body with a verified redistribution/game-use license is still required; hands-on Appetize device testing and a successful GitHub run are also still required. Do not label the generic saloon as a real Dena Plus model.

## Next vehicle: Peugeot 207

The Peugeot 207 is the second vehicle in the one-at-a-time acceptance cycle. Its mapped GLB is currently the generic CC0 five-door hatchback from the shared source pack, not a verified Peugeot 207 replica. The controller now adds a 207-inspired front fascia, swept headlamp accents, fog-lamp surrounds, bonnet creases, side mouldings, door handles, rear lamps, hatch garnish and spoiler. A dedicated `tests/peugeot_207_vehicle_test.gd` checks model loading, hatchback trim, wheel/steering rig, touch steering, forward/reverse drive, braking and manual clutch operation. The CI workflow runs the Dena and Peugeot acceptance tests before the nine-asset integration suite.

**Not yet accepted as complete:** the exact downloadable Peugeot 207 candidate is CC BY and requires attribution; its source file has not yet been obtained and inspected for cabin, materials, and game-ready rig. The generic CC0 hatchback remains a technical placeholder.

## Fleet mapping

| LIFE CITY slot | Imported generic body class | File |
|---|---|---|
| Dena Plus | Four-door saloon | dena_plus/dena_plus.glb |
| Peugeot 207 | Five-door hatchback | peugeot_207/peugeot_207.glb |
| Land Cruiser 300 | Large seven-seat SUV | land_cruiser_300/land_cruiser_300.glb |
| Lexus RX 2023 | Mid-size SUV | lexus_rx_2023/lexus_rx_2023.glb |
| Ferrari F40 | Grand touring coupe | ferrari_f40/ferrari_f40.glb |
| Lamborghini Huracan | Mid-engine sports car | lamborghini_huracan/lamborghini_huracan.glb |
| Saipa Tiba | Executive saloon | saipa_tiba/saipa_tiba.glb |
| Saipa Tiba 2 | Hot hatch | saipa_tiba_2/saipa_tiba_2.glb |
| Saipa Pride 131 | City car | saipa_pride_131/saipa_pride_131.glb |

The Pride slot intentionally uses the standalone City car asset (32487), not the multi-storey car-park starter-scene GLB (32562). The latter is an environment and must never be loaded as a car.

## Rig and scene assumptions

The source pack uses metre units, +Y up, +Z forward, wheel axles along X and tyre contact at y=0. Each vehicle asset is expected to include:
- Four separately named wheel pivots (wheel-front-left, wheel-front-right, wheel-rear-left, wheel-rear-right).
- An AnimationPlayer with door open/close, bonnet open/close, boot open/close, steering and wheel-roll clips.
- PBR materials and the cabin visible through the glazing.

The controller loads the matching GLB, hides procedural visuals, calculates mesh bounds, recentres the imported model to the road plane, creates a collision proxy from model dimensions, rotates named wheel pivots and uses imported clips for door, bonnet and boot interactions where available. Existing mobile controls, transmission, climate, lights, repair and driving logic are retained.

## Automated checks

tests/vehicle_asset_integration_test.gd checks all nine GLBs, visible meshes, required animation clips, wheel pivots, controller loading and collision proxies. The Android workflow runs this test after Godot imports the project.

tools/import_free_vehicles.py fetches the CC0 models and validates GLB JSON, animation clips and named wheel pivots before committing assets.

## Known limitations

- Generic body classes are not exact Dena, Peugeot, Toyota, Lexus, Ferrari, Lamborghini, Tiba or Pride designs. Manufacturer-specific accuracy requires dedicated licensed models or original modelling.
- The existing vehicle controller is a simplified arcade-style CharacterBody3D implementation, not a full tyre/suspension simulation.
- GLB clips and wheel pivots are used for visible interaction; collision proxies remain simplified boxes.
- Final visual fit, mobile frame rate, Android APK runtime and actual in-game handling still require automated build and hands-on device testing.