# LIFE CITY — Next Version Visual Upgrade

## Scope
This branch is for the next visual-quality and functional-interaction milestone. It must not change or destabilize the current APK release branch.

## Building exteriors
- Replace repeated box-only public facades with distinct architectural profiles by building use.
- Add layered facade depth: recessed glazing, frames, columns/pilasters, cornices, parapets, entrance canopies, doors, signage and rooftop details.
- Use separate material presets for glass, concrete, stone, brick, painted metal and trim; avoid one flat material across a whole building.
- Vary proportions, window rhythm, floor heights, rooflines and entrance composition by building category.
- Keep collision geometry simple and use LOD/distance-based detail where possible for Android.
- Make entrances visually readable and ensure windows/interior visibility are handled intentionally: transparent/recessed glazing or a deliberate cutaway/interior-view mode, not opaque walls that hide all interior activity.
- When entering a building, place the player inside a properly lit, camera-accessible, furnished interior with a clear exit and functional service interaction.

## Functional organization buildings and service panels
Entering a building must open the actual service workflow for that building, not merely teleport the player or display a decorative label.
- Military General Staff HQ: open a command center panel; choose an eligible branch/unit, select a target area on the map, issue an operation/attack order, and view unit status, order acknowledgement and outcome. Enforce creator/authorized-rank permissions; do not expose creator-only controls to ordinary players.
- Banks: provide account creation/selection, balance and transaction history, transfers, and applicable banking services. Validate account ownership, PIN/authentication and sufficient funds on the authoritative game state.
- City Hall: provide city-service requests and municipal management actions appropriate to the player's office/rank, with visible results and status.
- Ministry of Intelligence: show authorized citizen dossiers and records according to role permissions; protect private/admin data from unauthorized players.
- Other service buildings (dealership, repair garage, real estate office, telecom, prison, marriage office, wedding hall, government and presidential palace) must each route to their own relevant usable panel/workflow.
- All visible buttons must invoke a real action, provide success/error feedback, and be covered by interaction smoke tests. Remove obsolete/duplicate controls instead of leaving old and new UI active together.

## Ownership document transfers between players
- Allow a player to select an owned property/vehicle asset and initiate a transfer to another player.
- Identify the recipient unambiguously (online player/account ID and displayed player name); show asset details and recipient confirmation before committing.
- On acceptance, atomically change the ownership ledger from the sender to the recipient; reject if the sender is not the current owner, the asset is locked, the recipient is invalid, or the transaction is already completed.
- Keep an auditable transfer record with asset ID, sender, recipient, timestamp and status; prevent duplicate/replayed transfers.
- Update inventories, property/vehicle panels and ownership certificates for both players after a successful transfer.
- In multiplayer, perform validation and commit on the authoritative host/server; a client must never be able to assign ownership to itself by editing local state.
- Test accepted, rejected, offline-recipient, duplicate-request and reconnect/persistence cases.

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
2. City exterior/interior entry/exit smoke tests pass; interiors are visible, lit, navigable and functional.
3. Each service building opens the correct panel and its key actions pass interaction tests; no obsolete/duplicate UI controls remain.
4. Military command orders are permission-checked, reflected in unit state and tested for valid/invalid targets.
5. Ownership transfers pass sender/recipient validation, confirmation, persistence, replay and multiplayer-authority tests.
6. Each of the nine vehicles can be selected, entered, driven, exited and repaired in smoke tests.
7. Verify that each catalogue entry has a distinct exterior profile and cabin profile; a different colour alone does not pass.
8. Test a low graphics preset and a high graphics preset; record frame-time/performance where the runner/device permits.
9. Android APK export and artifact upload succeed in GitHub Actions.
10. Visual review screenshots are required before calling the graphics work complete. CI success alone cannot certify visual fidelity.

## Honest completion rule
Do not describe the vehicles as exact photorealistic reproductions unless suitable high-quality, legally usable source assets have actually been integrated and reviewed. Procedural geometry is an interim solution, not a substitute for finished vehicle models. Do not mark a service feature complete merely because its panel opens; verify the underlying action and saved/multiplayer state.
