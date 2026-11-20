# LIFE CITY — Real Vehicle Asset Integration

## Acceptance standard
A vehicle is not considered integrated merely because its name, paint colour, or procedural trim is different. Each production vehicle must use its own authored/imported exterior mesh and its own matching cabin mesh, with PBR materials and real-world proportions.

For each model, the asset package should provide:
- Exterior body with model-specific hood, bumpers, grille, lamps, glass, mirrors, door seams and badges where permitted.
- Interior with model-specific dashboard, instrument cluster, steering wheel, seats, door cards, centre console and pedals.
- Four separately addressable wheel meshes/pivots.
- Separate door, hood and trunk meshes/pivots where practical.
- PBR textures (base colour, normal, roughness, metallic); mobile LODs and collision proxies.
- GLB/glTF export for Godot; source project retained in Blender or FBX.
- Asset provenance, license and attribution recorded in this directory.

## Required fleet

| Game vehicle | Asset status | Required visual identity |
|---|---|---|
| Dena | Awaiting approved model file | IKCO Dena exterior and matching cabin |
| Peugeot 207 | Awaiting approved model file | Peugeot 207 hatchback exterior and cabin |
| Land Cruiser | Awaiting approved model file | Correct Land Cruiser generation must be selected |
| Lexus RX | Awaiting approved model file | Correct RX generation must be selected |
| Ferrari | Awaiting approved model file | Exact Ferrari model/year must be selected |
| Lamborghini | Awaiting approved model file | Exact Lamborghini model/year must be selected |
| Tiba | Candidate located; not yet imported | Tiba exterior and interior |
| Tiba 2 | Awaiting approved model file | Tiba 2 hatchback exterior and matching cabin |
| Pride | Candidate sources located; not yet imported | Exact Pride body variant and cabin |

## Candidate source research (not yet integrated)
- Tiba: 3DExport lists a free Tiba model in OBJ/FBX/Maya formats and describes PBR maps and changed interior details. The file has not been downloaded, inspected, or imported. Verify the actual downloaded package and license before use: https://3dexport.com/3d-model-tiba-448720
- Dena: 3DCADBrowser lists an IKCO Dena model in FBX/OBJ/BLEND and other formats, but requires an account and its listed geometry is very heavy (804,250 polygons) with no textures. It needs optimization and license review: https://www.3dcadbrowser.com/3d-model/ikco-dena
- Pride: a free Pride model is listed on Free3D, but its page specifies a Personal Use License and no textures/materials; this is not approved for a commercial game without permission: https://free3d.com/3d-model/pride-54576.html
- Pride: 3D Warehouse also lists downloadable Pride models; license/redistribution rights and cabin completeness must be checked before use: https://embed-3dwarehouse-classic.sketchup.com/model/2c40fcf8-b74d-4b85-a76b-d17210db00db/Pride-Silver

## Free CC0 test asset source (selected; not yet downloaded/imported)
- Grab3D compact car: https://grab3d.com/models/vehicles/compact-car/
- Listed package: `compact-car.glb`, approximately 1.1 MB, 17,338 triangles, 2K PBR textures, stated dimensions 1.76 × 3.72 × 1.48 m. The page describes a visible cabin with front seats, rear bench and steering wheel, plus four independently rolling wheels.
- License: CC0 1.0; the source states free commercial use, no login and no attribution required. Preserve the source page and any included `LICENSE.txt` / `manifest.json` with the imported asset.
- Important limitation: this is a stylized generic compact car, not a Dena, Tiba, Pride or any other exact real-world model. It is approved only as a technical integration/test vehicle, not as a replacement for the named fleet.
- Current status: source identified and technical details recorded; direct file retrieval has not yet succeeded in the development environment. Do not mark it integrated until the GLB is committed and tested in Godot.

## Import layout
Place reviewed, licensed exports here:
- `assets/vehicles/dena/dena.glb`
- `assets/vehicles/peugeot_207/peugeot_207.glb`
- `assets/vehicles/land_cruiser/land_cruiser.glb`
- `assets/vehicles/lexus_rx/lexus_rx.glb`
- `assets/vehicles/ferrari/ferrari.glb`
- `assets/vehicles/lamborghini/lamborghini.glb`
- `assets/vehicles/tiba/tiba.glb`
- `assets/vehicles/tiba_2/tiba_2.glb`
- `assets/vehicles/pride/pride.glb`

## Status
This file records the production asset contract and sourcing research only. It does not claim that any external vehicle mesh has been added. The current procedural vehicle meshes remain temporary fallbacks until reviewed GLB assets are present and tested in-game.
