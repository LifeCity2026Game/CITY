# LIFE CITY — Exact vehicle model sourcing audit

This file is the acceptance gate for replacing the generic vehicle placeholders. A model is **not approved for integration** until its geometry is visibly the named vehicle, the downloadable file is actually obtained, and its license permits use in a distributed game.

## Acceptance rules

- Exact body identity: correct model/year/variant, not merely the same body class.
- Exterior and interior must be inspected; missing cabin, wheels, glass, or major trim must be recorded.
- Downloadable source file must be obtainable without payment or account-only access for the current free-asset pass.
- License must explicitly allow game use. CC BY is acceptable with attribution; CC BY-NC, unclear terms, or redistributed GTA mods without source-author permission are rejected.
- Convert to Godot-compatible GLB, create/verify wheel pivots and door/hood/trunk animations, then run the vehicle integration test.
- Do not rename a generic model and present it as the named car.

## Candidate audit (20 Nov 2026)

| LIFE CITY vehicle | Exact candidate / source | Download & license evidence | Current decision |
|---|---|---|---|
| IKCO Dena Plus | [IKCO DENA — Qamk3Models](https://downloadfree3d.com/3d-models/vehicles/car/ikco-dena/) | 34 MB Blender ZIP is listed. Page credits Qamk3Models but does not state a redistribution/game license; also title says DENA, not confirmed Dena Plus. | **HOLD** — verify original creator license and Plus-specific body before importing. |
| Peugeot 207 | [Peugeot 207 — IggyPaz (Sketchfab)](https://sketchfab.com/3d-models/peugeot-207-3f21205aaeca44f2871e027e331b68d7) | Downloadable; CC Attribution. 365.2k triangles. Attribution required. | **CANDIDATE** — inspect exact body variant, cabin, and textures after obtaining file. |
| Toyota Land Cruiser 300 | [2022 Land Cruiser 300 VX.R — Ddiaz Design](https://sketchfab.com/3d-models/2022-toyota-land-cruiser-300-vxr-3dfcd7904cdb4e52afa3ce59fa59e1a5) | Downloadable; CC Attribution-NonCommercial-ShareAlike. | **REJECT for commercial-capable build** — non-commercial restriction. Find a permissive source or model it. |
| Lexus RX 2023 | [Lexus RX 2023 — CGTrader](https://www.cgtrader.com/3d-models/car/suv/lexus-rx-2023) | Exact model is listed at $149; not free. | **REJECT for free pass** — do not download or charge the user. |
| Ferrari F40 | [1987 Ferrari F40 — Ddiaz Design](https://sketchfab.com/3d-models/1987-ferrari-f40-80b0cdeb364b4223a006f3be12f16dc4) | Downloadable; CC Attribution. 145.9k triangles. Creator notes it is based on a CSR2 model and lists source credits. | **CANDIDATE** — inspect mesh/cabin and retain attribution and source-credit notes. |
| Lamborghini Huracan LP610-4 | [Huracan Black-Panther — SDC Performance](https://sketchfab.com/3d-models/huracan-black-panthertm-f61f211f21c442e68fb4a1fc0cc0d6ea) | Downloadable; CC Attribution. Free, 837.8k triangles; described as a heavily modified wide-body/twin-turbo design, not stock. | **HOLD** — exact base Huracan family, but modified body is not the requested stock LP610-4. Find/obtain stock model. |
| Saipa Tiba sedan | [Saipa Tiba — 3D Warehouse](https://embed-3dwarehouse-classic.sketchup.com/model/f54ce4eb-ed4e-4e42-99d8-48e374847c7e/Saipa-Tiba) | Exact Tiba 2008 is listed for download; 1,490 polygons. Search listing does not expose a game redistribution license. | **HOLD** — verify license and low-detail suitability. |
| Saipa Tiba 2 | [Saipa Tiba 2 — KUBSTER (Sketchfab)](https://sketchfab.com/3d-models/saipa-tiba-2-no-textures-and-wheels-d1b67cb314d84cce85418ca1990dec48) | Downloadable; CC Attribution; 281.6k triangles; explicitly has no textures and no wheels. | **CANDIDATE** — add wheels/materials and inspect cabin; attribution required. |
| Saipa Pride 131 | [Low Poly Car (Saipa 131) — Dara_mehr](https://sketchfab.com/3d-models/low-poly-coupe-car-saipa-131-a55dcf2069c947179bf2cf27be2f32d7) | Downloadable; CC Attribution; 3.7k triangles. | **HOLD** — exact inspiration is stated, but low-poly coupe and likely missing detailed cabin make it unsuitable for final high-detail fleet. |

## Dena follow-up search (20 Nov 2026)

Additional exact Dena leads were checked after the initial audit:

- [IKCO Dena — 3D CAD Browser](https://www.3dcadbrowser.com/3d-model/ikco-dena) advertises an exact Dena with 804,250 polygons and a royalty-free license, but download requires an account and its terms prohibit redistribution of the source model. It is not accepted for this freely distributable source-asset pipeline without a license review of packaged-game distribution.
- [IKCO Dena — GTAinside](https://www.gtainside.com/gta5/cars/149442-ikco-dena/) describes a detailed GTA V mod and credits the model to Second Gear, with conversion/edit credits to other creators. The page does not grant a game-asset redistribution license; rejected for integration.
- [IKCO Dena Plus — GTAinside](https://www.gtainside.com/gta4/cars/185320-ikco-dena-plus/) advertises a detailed interior/exterior mod, but likewise supplies no permission to reuse or redistribute the model in LIFE CITY; rejected.
- [IKCO DENA — DownloadFree3D](https://downloadfree3d.com/3d-models/vehicles/car/ikco-dena/) lists a free 34 MB Blender ZIP credited to Qamk3Models, but the listing does not establish a redistribution/game license; remains on HOLD pending creator permission.

No exact Dena/Dena Plus file from these sources has been imported. The current CC0 generic saloon remains the only legally documented file in the repository for automated controller testing.

## Current repository assets

The nine files currently under `assets/vehicles/` are generic CC0 body classes, not the exact cars in the table. They are technical placeholders only and must not be described as completed Dena, Peugeot, Toyota, Lexus, Ferrari, Lamborghini, Tiba, Tiba 2, or Pride models.

## Next integration steps

1. Obtain a permitted source file for each accepted candidate.
2. Preserve the source license and attribution in the corresponding vehicle folder.
3. Inspect front/rear/side/interior and remove unsupported candidates before integration.
4. Convert to Godot-compatible GLB, create a consistent rig, and validate wheel pivots and moving parts.
5. Replace the generic placeholder only after the exact-model asset test passes.
