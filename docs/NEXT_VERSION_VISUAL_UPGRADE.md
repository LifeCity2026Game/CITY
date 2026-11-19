# LIFE CITY — Next Version Visual Upgrade

## Scope
This branch is for the next visual-quality milestone. It must not change or destabilize the current APK release branch.

## Building exteriors
- Replace repeated box-only public facades with distinct architectural profiles by building use.
- Add layered facade depth: recessed glazing, frames, columns/pilasters, cornices, parapets, entrance canopies, doors, signage and rooftop details.
- Use separate material presets for glass, concrete, stone, brick, painted metal and trim; avoid one flat material across a whole building.
- Vary proportions, window rhythm, floor heights, rooflines and entrance composition by building category.
- Keep collision geometry simple and use LOD/distance-based detail where possible for Android.

## Vehicle catalogue
Every catalogue entry must have its own exterior silhouette and signature parts, not only a different paint colour or scale:
- Dena: formal Iranian sedan proportions and distinct front/rear fascia.
- Peugeot 207: compact hatchback profile and short rear overhang.
- Land Cruiser: tall SUV body, upright greenhouse, roof rails and rugged bumpers.
- Lexus RX: luxury crossover profile, sculpted grille and refined trim.
- Ferrari: low mid-engine sports-car proportions, wide stance and sport aero.
- Lamborghini: low angular supercar silhouette and distinctive intake/aero treatment.
- Tiba: compact sedan proportions and simple fascia.
- Tiba 2: hatchback rear profile distinct from Tiba.
- Pride: narrow compact sedan proportions and simple trim.

Each model also needs a model-specific cabin layout/material treatment, steering wheel/dashboard, seats, instruments, mirrors, lights, wheels and readable controls. Vehicle physics values must be individually tuned and tested rather than inferred from appearance alone.

## Visual quality and performance
- PBR material tuning for paint, glass, rubber, metal, stone and concrete.
- Improved sun/ambient lighting, contact shadows and reflections where supported by the mobile renderer.
- Quality tiers for low-end Android; avoid expensive real-time effects on the lowest tier.
- Reuse materials/meshes and keep collision meshes low-poly.

## Acceptance gates
1. Godot project import/headless checks pass.
2. City exterior/interior entry/exit smoke tests pass.
3. Each of the nine vehicles can be selected, entered, driven, exited and repaired in smoke tests.
4. Verify that each catalogue entry has a distinct exterior profile and cabin profile; a different colour alone does not pass.
5. Test a low graphics preset and a high graphics preset; record frame-time/performance where the runner/device permits.
6. Android APK export and artifact upload succeed in GitHub Actions.
7. Visual review screenshots are required before calling the graphics work complete. CI success alone cannot certify visual fidelity.

## Honest completion rule
Do not describe the vehicles as exact photorealistic reproductions unless suitable high-quality, legally usable source assets have actually been integrated and reviewed. Procedural geometry is an interim solution, not a substitute for finished vehicle models.
