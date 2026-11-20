# LIFE CITY Online Store

This project-local Godot editor add-on provides catalog validation and commerce authoring guidance. The in-game commerce flow is implemented by the authoritative ownership ledger and the phone's Online Store page.

## Included systems
- Catalog categories for mobile/technology, entertainment, and home appliances.
- Shopping cart with quantity selection.
- Checkout against a player-owned bank account and PIN.
- Server-authoritative stock checks and stock decrement.
- Order records, delivery countdown, and delivery status.
- Owner-only inventory restocking.
- Existing ownership documents and player-to-player ownership offers remain the basis for resale/trading.

## Important
The current Firebase client only authenticates users. Commerce balances, orders, and inventory are persisted by the Godot host ledger; production internet multiplayer still requires a trusted dedicated server and database security rules. Do not treat a client-only local save as secure online commerce.
