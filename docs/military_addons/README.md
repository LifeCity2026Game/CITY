# LIFE CITY Military Add-ons

Five project-local Godot editor add-ons are enabled in the project:

1. **Military HQ** — validates the headquarters profile and seven command branches.
2. **Military Branches** — validates the ground, air, navy, coast guard, marines, space, and national guard registry.
3. **Military Ranks** — validates the rank ladder and permission matrix. Rank grants and sensitive overrides are creator-only; permission decisions must be checked by the host/server.
4. **Military Logistics** — validates non-weapon support inventory: service vehicles, emergency supplies, communications, and base provisions.
5. **Military Operations** — validates the audit-event schema and retention policy.

## Runtime integration

The existing MilitaryCommand system remains the in-game command interface. It now routes remote player commands to the host for permission checks before execution and writes a bounded operation audit to `user://military_operations_audit.json` on the authoritative host. Branch commanders are restricted to their assigned branch; the creator and authorized all-branch commander may access broader command functions.

All combat-like effects remain fictional game mechanics and visual simulation. These add-ons do not model real-world weapon operation or tactics.

## Limits

The editor add-ons validate and manage project data. They do not create realistic military vehicle assets, fully network-replicate every unit, or replace a dedicated production server. Online role and command persistence must ultimately live in trusted server-side storage.
