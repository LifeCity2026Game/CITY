# Material Maker for LIFE CITY

- Official project: https://github.com/RodZill4/material-maker
- Verified target release: **1.8**
- License: MIT (upstream repository; check individual bundled assets separately)
- Purpose: procedural PBR texture authoring and 3D model painting.

## LIFE CITY material targets

Use Material Maker to author texture maps for:
- Vehicle paint, rubber tires, glass, chrome and interior leather/fabric.
- Building concrete, brick, plaster, roofing and facade trim sheets.
- Road asphalt, pavement, dirt and environmental surfaces.
- Furniture, clothing fabrics and household product surfaces.

## Export and integration

Export baked texture maps from Material Maker, then import them into Godot as standard textures.
For Godot StandardMaterial3D, map the outputs deliberately:
- Base Color / Albedo -> Albedo texture
- Normal -> Normal texture (enable normal mapping)
- Roughness -> Roughness texture
- Metallic -> Metallic texture
- Ambient Occlusion -> AO texture

Keep source graphs/projects outside the runtime scene when possible. Use shared, tiled materials and texture atlases for mobile performance. Prefer 1K maps for common assets and reserve 2K/4K maps for close-up hero assets; use compressed GPU-friendly formats in exported Android builds.

## Important status distinction

The GitHub Actions check fetches the official 1.8 source and checks that Godot can import the project headlessly. It does **not** mean finished vehicle/building materials have already been authored or applied to LIFE CITY models. The generated textures must still be exported and assigned to the corresponding Godot materials.
