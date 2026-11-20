# LIFE CITY vehicle add-ons

Five project-local Godot 4 editor add-ons are enabled in project.godot:

1. Vehicle Modeling — adds a menu action to create a vehicle model root with editable profile metadata.
2. Vehicle Interior — creates cabin anchor nodes for front/rear seats, dashboard and center console.
3. Vehicle Rigging — creates four wheel pivot markers and a steering-wheel pivot.
4. Vehicle Physics — applies a baseline acceleration, braking, speed and steering preset as vehicle metadata.
5. Vehicle Damage and Audio — applies condition, impact and engine-pitch tuning metadata.

These are LIFE CITY editor integration tools, not third-party vehicle asset packs. They prepare vehicle scenes and metadata; they do not generate manufacturer-accurate Dena, Peugeot, Land Cruiser, Lexus, Ferrari, Lamborghini, Tiba or Pride meshes, recorded engine sounds, or a complete damage simulation by themselves. The current vehicle controller remains the runtime driving implementation. The CI smoke test checks that all five plugins are enabled, their configuration files parse, and their editor scripts load.
